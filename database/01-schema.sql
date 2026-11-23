IF DB_ID('SalesReport') IS NULL
    CREATE DATABASE SalesReport;


GO
USE SalesReport;


GO
CREATE TABLE Products (
    Id            INT             IDENTITY (1, 1) NOT NULL CONSTRAINT PK_Products PRIMARY KEY,
    Sku           VARCHAR (50)    NOT NULL CONSTRAINT UQ_Products_Sku UNIQUE,
    Name          NVARCHAR (100)  NOT NULL,
    Category      NVARCHAR (50)   NOT NULL,
    Price         DECIMAL (18, 2) NOT NULL CONSTRAINT CK_Products_Price CHECK (Price >= 0),
    StockQuantity INT             NOT NULL CONSTRAINT CK_Products_StockQuantity CHECK (StockQuantity >= 0),
    ReorderLevel  INT             NOT NULL CONSTRAINT CK_Products_ReorderLevel CHECK (ReorderLevel >= 0),
    IsActive      BIT             CONSTRAINT DF_Products_IsActive DEFAULT (1) NOT NULL
);

CREATE TABLE Orders (
    Id        INT             IDENTITY (1, 1) NOT NULL CONSTRAINT PK_Orders PRIMARY KEY,
    OrderedAt DATETIME2 (0)   NOT NULL,
    Channel   VARCHAR (20)    NOT NULL CONSTRAINT CK_Orders_Channel CHECK (Channel IN (
                                           'Online',
                                           'Store'
                                       )),
    Status    VARCHAR (20)    CONSTRAINT DF_Orders_Status DEFAULT ('Completed') NOT NULL CONSTRAINT CK_Orders_Status CHECK (Status IN (
                                                                                             'Completed',
                                                                                             'Cancelled'
                                                                                         )),
    Total     DECIMAL (18, 2) CONSTRAINT DF_Orders_Total DEFAULT (0) NOT NULL CONSTRAINT CK_Orders_Total CHECK (Total >= 0)
);

CREATE TABLE OrderItems (
    Id        INT             IDENTITY (1, 1) NOT NULL CONSTRAINT PK_OrderItems PRIMARY KEY,
    OrderId   INT             NOT NULL,
    ProductId INT             NOT NULL,
    Quantity  INT             NOT NULL CONSTRAINT CK_OrderItems_Quantity CHECK (Quantity > 0),
    UnitPrice DECIMAL (18, 2) NOT NULL CONSTRAINT CK_OrderItems_UnitPrice CHECK (UnitPrice >= 0),
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (OrderId) REFERENCES Orders (Id),
    CONSTRAINT FK_OrderItems_Products FOREIGN KEY (ProductId) REFERENCES Products (Id)
);

CREATE NONCLUSTERED INDEX IX_Orders_OrderedAt
    ON Orders(OrderedAt)
    INCLUDE(Status, Total);

CREATE NONCLUSTERED INDEX IX_OrderItems_OrderId
    ON OrderItems(OrderId);

CREATE NONCLUSTERED INDEX IX_OrderItems_ProductId
    ON OrderItems(ProductId);


GO