USE SalesReport;
GO

SET NOCOUNT ON;

DELETE FROM OrderItems;
DELETE FROM Orders;
DELETE FROM Products;

INSERT INTO Products (Sku, Name, Category, Price, StockQuantity, ReorderLevel)
VALUES
    ('KB-001', 'Mechanical Keyboard',   'Peripherals',  89.90,  42, 10),
    ('MS-001', 'Wireless Mouse',        'Peripherals',  34.50,   8, 15),
    ('WC-001', 'HD Webcam',             'Peripherals',  39.90,  18,  6),
    ('HS-001', 'USB-C Headset',         'Audio',        59.00,  25, 10),
    ('SP-001', 'Bluetooth Speaker',     'Audio',        45.00,  30,  8),
    ('MN-001', '27-inch Monitor',       'Displays',    249.99,  12,  5),
    ('MN-002', '24-inch Monitor',       'Displays',    179.90,   3,  5),
    ('CB-001', 'USB-C to HDMI Cable',   'Accessories',  14.90, 120, 30),
    ('CH-001', '65W USB-C Charger',     'Accessories',  29.90,  60, 20),
    ('DK-001', 'USB-C Docking Station', 'Accessories', 119.00,   9,  4);

DECLARE @Today DATE = CAST(GETDATE() AS DATE);
DECLARE @Yesterday DATE = DATEADD(DAY, -1, @Today);
DECLARE @DaysOfHistory INT = 60;

CREATE TABLE #Days (
    SaleDate DATE NOT NULL PRIMARY KEY,
    OrdersCount INT NOT NULL
);

INSERT INTO #Days (SaleDate, OrdersCount)
SELECT
    d.SaleDate,
    CASE
        WHEN d.SaleDate = @Yesterday THEN 10
        ELSE 25 + ABS(CHECKSUM(NEWID())) % 16
             + CASE WHEN DATEDIFF(DAY, '19000101', d.SaleDate) % 7 IN (5, 6) THEN 15 ELSE 0 END
    END
FROM (
    SELECT TOP (@DaysOfHistory)
        DATEADD(DAY, -CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT), @Today) AS SaleDate
    FROM sys.all_objects
) AS d;

INSERT INTO Orders (OrderedAt, Channel, Status)
SELECT
    DATEADD(MINUTE, 480 + ABS(CHECKSUM(NEWID())) % 720, CAST(d.SaleDate AS DATETIME2(0))),
    CASE WHEN ABS(CHECKSUM(NEWID())) % 10 < 6 THEN 'Online' ELSE 'Store' END,
    CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 5 THEN 'Cancelled' ELSE 'Completed' END
FROM #Days AS d
CROSS APPLY (
    SELECT TOP (d.OrdersCount) 1 AS N
    FROM sys.all_objects
) AS t;

CREATE TABLE #OrderPlan (
    OrderId INT NOT NULL PRIMARY KEY,
    ItemsCount INT NOT NULL
);

INSERT INTO #OrderPlan (OrderId, ItemsCount)
SELECT Id, 1 + ABS(CHECKSUM(NEWID())) % 3
FROM Orders;

INSERT INTO OrderItems (OrderId, ProductId, Quantity, UnitPrice)
SELECT
    op.OrderId,
    p.Id,
    1 + ABS(CHECKSUM(NEWID())) % 3,
    p.Price
FROM #OrderPlan AS op
CROSS APPLY (
    SELECT TOP (op.ItemsCount) Id, Price
    FROM Products
    WHERE IsActive = 1
    ORDER BY CHECKSUM(NEWID(), op.OrderId)
) AS p;

UPDATE o
SET Total = i.Total
FROM Orders AS o
INNER JOIN (
    SELECT OrderId, SUM(Quantity * UnitPrice) AS Total
    FROM OrderItems
    GROUP BY OrderId
) AS i ON i.OrderId = o.Id;

DROP TABLE #OrderPlan;
DROP TABLE #Days;

SELECT
    CAST(OrderedAt AS DATE) AS SaleDate,
    COUNT(*) AS Orders,
    SUM(Total) AS Revenue
FROM Orders
WHERE Status = 'Completed'
  AND OrderedAt >= DATEADD(DAY, -8, @Today)
GROUP BY CAST(OrderedAt AS DATE)
ORDER BY SaleDate DESC;