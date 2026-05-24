-- =============================================================================
-- AdventureWorks Bronze — Step 1 of 2: Bootstrap (DDL)
-- =============================================================================
-- PURPOSE : Create the Unity Catalog hierarchy and empty Delta table shells.
-- RUN WHEN: Once per environment, BEFORE uploading any CSV files.
-- NEXT    : Upload all 24 CSVs to /Volumes/${catalog}/landing/csv/,
--           then run bronze_load.sql (Step 2).
--
-- DESIGN  : All columns are STRING.
--           Bronze is a raw landing zone — no type casting, no business logic.
--           Type casting and transformations happen in Silver (dbt stg_* models).
--
-- Every statement uses IF NOT EXISTS — safe to re-run at any time.
-- =============================================================================
--
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │  DATABRICKS JOB SETUP                                                   │
-- └─────────────────────────────────────────────────────────────────────────┘
--
-- Task type  : Notebook
-- Path       : /Shared/adventureworks/bronze_bootstrap
-- Cluster    : any cluster or serverless SQL warehouse
-- Parameter  : catalog = adventureworks_dev  (or adventureworks_prod)
--
--   JSON: "base_parameters": { "catalog": "adventureworks_prod" }
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Widget: set 'catalog' to switch between dev and prod.
-- ---------------------------------------------------------------------------
CREATE WIDGET TEXT catalog DEFAULT 'adventureworks_dev';


-- =============================================================================
-- CATALOG / SCHEMA / VOLUME BOOTSTRAP
-- =============================================================================

CREATE CATALOG IF NOT EXISTS ${catalog};

CREATE SCHEMA IF NOT EXISTS ${catalog}.bronze;
CREATE SCHEMA IF NOT EXISTS ${catalog}.silver;
CREATE SCHEMA IF NOT EXISTS ${catalog}.gold;

-- Volume where CSV uploads will land (referenced by bronze_load.sql)
CREATE VOLUME IF NOT EXISTS ${catalog}.bronze.landing;


-- =============================================================================
-- SALES DOMAIN — table shells (all columns STRING)
-- =============================================================================

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.Customer (
    CustomerID      STRING,
    PersonID        STRING,
    StoreID         STRING,
    TerritoryID     STRING,
    AccountNumber   STRING,   -- computed column, present verbatim in CSV
    rowguid         STRING,
    ModifiedDate    STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.SalesOrderHeader (
    SalesOrderID            STRING,
    RevisionNumber          STRING,
    OrderDate               STRING,
    DueDate                 STRING,
    ShipDate                STRING,
    Status                  STRING,
    OnlineOrderFlag         STRING,
    SalesOrderNumber        STRING,   -- computed column, present verbatim in CSV
    PurchaseOrderNumber     STRING,
    AccountNumber           STRING,
    CustomerID              STRING,
    SalesPersonID           STRING,
    TerritoryID             STRING,
    BillToAddressID         STRING,
    ShipToAddressID         STRING,
    ShipMethodID            STRING,
    CreditCardID            STRING,
    CreditCardApprovalCode  STRING,
    CurrencyRateID          STRING,
    SubTotal                STRING,
    TaxAmt                  STRING,
    Freight                 STRING,
    TotalDue                STRING,   -- computed column, present verbatim in CSV
    Comment                 STRING,
    rowguid                 STRING,
    ModifiedDate            STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.SalesOrderDetail (
    SalesOrderID          STRING,
    SalesOrderDetailID    STRING,
    CarrierTrackingNumber STRING,
    OrderQty              STRING,
    ProductID             STRING,
    SpecialOfferID        STRING,
    UnitPrice             STRING,
    UnitPriceDiscount     STRING,
    LineTotal             STRING,   -- computed column, present verbatim in CSV
    rowguid               STRING,
    ModifiedDate          STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.SalesTerritory (
    TerritoryID         STRING,
    Name                STRING,
    CountryRegionCode   STRING,
    `Group`             STRING,
    SalesYTD            STRING,
    SalesLastYear       STRING,
    CostYTD             STRING,
    CostLastYear        STRING,
    rowguid             STRING,
    ModifiedDate        STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.SalesTerritoryHistory (
    BusinessEntityID    STRING,
    TerritoryID         STRING,
    StartDate           STRING,
    EndDate             STRING,
    rowguid             STRING,
    ModifiedDate        STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.SalesPerson (
    BusinessEntityID    STRING,
    TerritoryID         STRING,
    SalesQuota          STRING,
    Bonus               STRING,
    CommissionPct       STRING,
    SalesYTD            STRING,
    SalesLastYear       STRING,
    rowguid             STRING,
    ModifiedDate        STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.SpecialOffer (
    SpecialOfferID  STRING,
    Description     STRING,
    DiscountPct     STRING,
    Type            STRING,
    Category        STRING,
    StartDate       STRING,
    EndDate         STRING,
    MinQty          STRING,
    MaxQty          STRING,
    rowguid         STRING,
    ModifiedDate    STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.SpecialOfferProduct (
    SpecialOfferID  STRING,
    ProductID       STRING,
    rowguid         STRING,
    ModifiedDate    STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.CurrencyRate (
    CurrencyRateID      STRING,
    CurrencyRateDate    STRING,
    FromCurrencyCode    STRING,
    ToCurrencyCode      STRING,
    AverageRate         STRING,
    EndOfDayRate        STRING,
    ModifiedDate        STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.ShipMethod (
    ShipMethodID    STRING,
    Name            STRING,
    ShipBase        STRING,
    ShipRate        STRING,
    rowguid         STRING,
    ModifiedDate    STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.CreditCard (
    CreditCardID    STRING,
    CardType        STRING,
    CardNumber      STRING,
    ExpMonth        STRING,
    ExpYear         STRING,
    ModifiedDate    STRING
) USING DELTA;


-- =============================================================================
-- HUMANRESOURCES DOMAIN — table shells (all columns STRING)
-- =============================================================================

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.Employee (
    BusinessEntityID    STRING,
    NationalIDNumber    STRING,
    LoginID             STRING,
    OrganizationNode    STRING,   -- source type: hierarchyid
    OrganizationLevel   STRING,   -- computed column, present verbatim in CSV
    JobTitle            STRING,
    BirthDate           STRING,
    MaritalStatus       STRING,
    Gender              STRING,
    HireDate            STRING,
    SalariedFlag        STRING,
    VacationHours       STRING,
    SickLeaveHours      STRING,
    CurrentFlag         STRING,
    rowguid             STRING,
    ModifiedDate        STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.EmployeePayHistory (
    BusinessEntityID    STRING,
    RateChangeDate      STRING,
    Rate                STRING,
    PayFrequency        STRING,
    ModifiedDate        STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.EmployeeDepartmentHistory (
    BusinessEntityID    STRING,
    DepartmentID        STRING,
    ShiftID             STRING,
    StartDate           STRING,
    EndDate             STRING,
    ModifiedDate        STRING
) USING DELTA;


-- =============================================================================
-- PERSON DOMAIN — table shells (all columns STRING)
-- (Person, PersonPhone, EmailAddress are pipe-delimited in CSV — handled in Step 2)
-- =============================================================================

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.Person (
    BusinessEntityID        STRING,
    PersonType              STRING,
    NameStyle               STRING,
    Title                   STRING,
    FirstName               STRING,
    MiddleName              STRING,
    LastName                STRING,
    Suffix                  STRING,
    EmailPromotion          STRING,
    AdditionalContactInfo   STRING,   -- source type: XML
    Demographics            STRING,   -- source type: XML
    rowguid                 STRING,
    ModifiedDate            STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.PersonPhone (
    BusinessEntityID    STRING,
    PhoneNumber         STRING,
    PhoneNumberTypeID   STRING,
    ModifiedDate        STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.EmailAddress (
    BusinessEntityID    STRING,
    EmailAddressID      STRING,
    EmailAddress        STRING,
    rowguid             STRING,
    ModifiedDate        STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.Address (
    AddressID           STRING,
    AddressLine1        STRING,
    AddressLine2        STRING,
    City                STRING,
    StateProvinceID     STRING,
    PostalCode          STRING,
    SpatialLocation     STRING,   -- source type: geography
    rowguid             STRING,
    ModifiedDate        STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.StateProvince (
    StateProvinceID             STRING,
    StateProvinceCode           STRING,
    CountryRegionCode           STRING,
    IsOnlyStateProvinceFlag     STRING,
    Name                        STRING,
    TerritoryID                 STRING,
    rowguid                     STRING,
    ModifiedDate                STRING
) USING DELTA;


-- =============================================================================
-- PRODUCTION DOMAIN — table shells (all columns STRING)
-- =============================================================================

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.Product (
    ProductID               STRING,
    Name                    STRING,
    ProductNumber           STRING,
    MakeFlag                STRING,
    FinishedGoodsFlag       STRING,
    Color                   STRING,
    SafetyStockLevel        STRING,
    ReorderPoint            STRING,
    StandardCost            STRING,
    ListPrice               STRING,
    Size                    STRING,
    SizeUnitMeasureCode     STRING,
    WeightUnitMeasureCode   STRING,
    Weight                  STRING,
    DaysToManufacture       STRING,
    ProductLine             STRING,
    Class                   STRING,
    Style                   STRING,
    ProductSubcategoryID    STRING,
    ProductModelID          STRING,
    SellStartDate           STRING,
    SellEndDate             STRING,
    DiscontinuedDate        STRING,
    rowguid                 STRING,
    ModifiedDate            STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.ProductSubcategory (
    ProductSubcategoryID    STRING,
    ProductCategoryID       STRING,
    Name                    STRING,
    rowguid                 STRING,
    ModifiedDate            STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.ProductCategory (
    ProductCategoryID   STRING,
    Name                STRING,
    rowguid             STRING,
    ModifiedDate        STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.ProductListPriceHistory (
    ProductID       STRING,
    StartDate       STRING,
    EndDate         STRING,
    ListPrice       STRING,
    ModifiedDate    STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS ${catalog}.bronze.ProductInventory (
    ProductID       STRING,
    LocationID      STRING,
    Shelf           STRING,
    Bin             STRING,
    Quantity        STRING,
    rowguid         STRING,
    ModifiedDate    STRING
) USING DELTA;
