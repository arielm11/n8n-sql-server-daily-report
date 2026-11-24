USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'n8n_report')
    CREATE LOGIN n8n_report WITH PASSWORD = 'ChangeMe#Report2026', CHECK_POLICY = ON;
GO

USE SalesReport;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'n8n_report')
    CREATE USER n8n_report FOR LOGIN n8n_report;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'report_executor' AND type = 'R')
    CREATE ROLE report_executor;
GO

GRANT EXECUTE ON dbo.usp_GetDailySalesSummary TO report_executor;
GRANT EXECUTE ON dbo.usp_GetTopProducts TO report_executor;
GRANT EXECUTE ON dbo.usp_GetDailyAlerts TO report_executor;

ALTER ROLE report_executor ADD MEMBER n8n_report;
GO