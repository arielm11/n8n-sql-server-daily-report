USE SalesReport;
GO

CREATE OR ALTER FUNCTION dbo.fn_DailySalesSummary (@ReportDate DATE)
RETURNS TABLE
AS
RETURN
WITH Periods AS (
    SELECT
        CASE WHEN o.OrderedAt >= @ReportDate THEN 1 ELSE 0 END AS IsReportDay,
        o.Status,
        o.Channel,
        o.Total
    FROM dbo.Orders AS o
    WHERE (o.OrderedAt >= @ReportDate AND o.OrderedAt < DATEADD(DAY, 1, @ReportDate))
       OR (o.OrderedAt >= DATEADD(DAY, -7, @ReportDate) AND o.OrderedAt < DATEADD(DAY, -6, @ReportDate))
),
Totals AS (
    SELECT
        ISNULL(SUM(CASE WHEN IsReportDay = 1 AND Status = 'Completed' THEN Total ELSE 0 END), 0) AS Revenue,
        ISNULL(SUM(CASE WHEN IsReportDay = 1 AND Status = 'Completed' THEN 1 ELSE 0 END), 0) AS OrdersCount,
        ISNULL(SUM(CASE WHEN IsReportDay = 1 AND Status = 'Cancelled' THEN 1 ELSE 0 END), 0) AS CancelledOrders,
        ISNULL(SUM(CASE WHEN IsReportDay = 1 AND Status = 'Completed' AND Channel = 'Online' THEN Total ELSE 0 END), 0) AS OnlineRevenue,
        ISNULL(SUM(CASE WHEN IsReportDay = 1 AND Status = 'Completed' AND Channel = 'Store' THEN Total ELSE 0 END), 0) AS StoreRevenue,
        ISNULL(SUM(CASE WHEN IsReportDay = 0 AND Status = 'Completed' THEN Total ELSE 0 END), 0) AS ComparisonRevenue,
        ISNULL(SUM(CASE WHEN IsReportDay = 0 AND Status = 'Completed' THEN 1 ELSE 0 END), 0) AS ComparisonOrdersCount
    FROM Periods
)
SELECT
    @ReportDate AS ReportDate,
    DATEADD(DAY, -7, @ReportDate) AS ComparisonDate,
    CAST(Revenue AS DECIMAL(18, 2)) AS Revenue,
    OrdersCount,
    CAST(ISNULL(Revenue / NULLIF(OrdersCount, 0), 0) AS DECIMAL(18, 2)) AS AverageTicket,
    CancelledOrders,
    CAST(OnlineRevenue AS DECIMAL(18, 2)) AS OnlineRevenue,
    CAST(StoreRevenue AS DECIMAL(18, 2)) AS StoreRevenue,
    CAST(ComparisonRevenue AS DECIMAL(18, 2)) AS ComparisonRevenue,
    ComparisonOrdersCount,
    CAST((Revenue - ComparisonRevenue) * 100.0 / NULLIF(ComparisonRevenue, 0) AS DECIMAL(9, 1)) AS RevenueChangePercent
FROM Totals;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetDailySalesSummary
    @ReportDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ReportDate,
        ComparisonDate,
        Revenue,
        OrdersCount,
        AverageTicket,
        CancelledOrders,
        OnlineRevenue,
        StoreRevenue,
        ComparisonRevenue,
        ComparisonOrdersCount,
        RevenueChangePercent
    FROM dbo.fn_DailySalesSummary(@ReportDate);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetTopProducts
    @ReportDate DATE,
    @Top INT = 5
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Top)
        p.Sku,
        p.Name,
        SUM(i.Quantity) AS UnitsSold,
        CAST(SUM(i.Quantity * i.UnitPrice) AS DECIMAL(18, 2)) AS Revenue
    FROM dbo.OrderItems AS i
    INNER JOIN dbo.Orders AS o ON o.Id = i.OrderId
    INNER JOIN dbo.Products AS p ON p.Id = i.ProductId
    WHERE o.Status = 'Completed'
      AND o.OrderedAt >= @ReportDate
      AND o.OrderedAt < DATEADD(DAY, 1, @ReportDate)
    GROUP BY p.Sku, p.Name
    ORDER BY Revenue DESC, UnitsSold DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetDailyAlerts
    @ReportDate DATE,
    @RevenueDropThresholdPercent DECIMAL(9, 1) = -30.0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CAST('RevenueDrop' AS VARCHAR(20)) AS AlertType,
        CAST(N'Daily revenue' AS NVARCHAR(100)) AS Item,
        CAST(s.Revenue AS DECIMAL(18, 2)) AS CurrentValue,
        CAST(s.ComparisonRevenue AS DECIMAL(18, 2)) AS ReferenceValue,
        CAST(CONCAT(N'Revenue changed ', s.RevenueChangePercent, N'% compared to ',
            CONVERT(CHAR(10), s.ComparisonDate, 23)) AS NVARCHAR(200)) AS Detail
    FROM dbo.fn_DailySalesSummary(@ReportDate) AS s
    WHERE s.RevenueChangePercent <= @RevenueDropThresholdPercent

    UNION ALL

    SELECT
        CAST('LowStock' AS VARCHAR(20)),
        p.Name,
        CAST(p.StockQuantity AS DECIMAL(18, 2)),
        CAST(p.ReorderLevel AS DECIMAL(18, 2)),
        CAST(CONCAT(p.Sku, N': ', p.StockQuantity, N' in stock, minimum is ', p.ReorderLevel) AS NVARCHAR(200))
    FROM dbo.Products AS p
    WHERE p.IsActive = 1
      AND p.StockQuantity < p.ReorderLevel;
END;
GO