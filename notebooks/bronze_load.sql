-- =============================================================================
-- AdventureWorks Bronze — Step 2 of 2: Load CSVs (COPY INTO)
-- =============================================================================
-- PURPOSE : Idempotently load all 24 AdventureWorks CSVs into Delta tables.
-- RUN WHEN: After bronze_bootstrap.sql (Step 1) has succeeded AND all 24 CSV
--           files have been uploaded to /Volumes/${catalog}/landing/csv/.
--
-- COPY INTO tracks processed files — re-running this notebook is safe and
-- will not duplicate data.  Use COPY_OPTIONS ('force' = 'true') only if you
-- need to force a full reload.
--
-- Format legend:
--   • Most tables                       → tab-delimited (\t), no header
--   • Person, PersonPhone, EmailAddress → field '+|'  row '&|\n'  (XML-safe)
--   • All target columns are STRING — no date/timestamp parsing needed
-- =============================================================================
--
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │  DATABRICKS JOB SETUP                                                   │
-- └─────────────────────────────────────────────────────────────────────────┘
--
-- Task type  : Notebook
-- Path       : /Shared/adventureworks/bronze_load
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
-- PRE-FLIGHT CHECK
-- Compares the 24 expected filenames against what is actually present in the
-- Volume.  Reports EXACTLY which files are missing rather than a generic count.
-- Fails fast with a descriptive error rather than a mid-run FileNotFoundException.
-- Requires: Databricks Runtime 13+ or Serverless SQL Warehouse.
-- =============================================================================
WITH expected AS (
    SELECT explode(array(
        -- Sales (11)
        'Customer.csv', 'SalesOrderHeader.csv', 'SalesOrderDetail.csv',
        'SalesTerritory.csv', 'SalesTerritoryHistory.csv', 'SalesPerson.csv',
        'SpecialOffer.csv', 'SpecialOfferProduct.csv', 'CurrencyRate.csv',
        'ShipMethod.csv', 'CreditCard.csv',
        -- HumanResources (3)
        'Employee.csv', 'EmployeePayHistory.csv', 'EmployeeDepartmentHistory.csv',
        -- Person (5)
        'Person.csv', 'PersonPhone.csv', 'EmailAddress.csv',
        'Address.csv', 'StateProvince.csv',
        -- Production (5)
        'Product.csv', 'ProductSubcategory.csv', 'ProductCategory.csv',
        'ProductListPriceHistory.csv', 'ProductInventory.csv'
    )) AS filename
),
found AS (
    SELECT name AS filename
    FROM   (LIST '/Volumes/${catalog}/landing/csv/')
    WHERE  name LIKE '%.csv'
),
missing AS (
    SELECT e.filename
    FROM   expected e
    LEFT   JOIN found f ON e.filename = f.filename
    WHERE  f.filename IS NULL
    ORDER  BY e.filename
)
SELECT
    CASE
        WHEN count(*) = 0
            THEN 'Pre-flight passed — all 24 CSV files found. Starting COPY INTO...'
        ELSE raise_error(concat(
            'Pre-flight failed: ', count(*), ' of 24 CSV files are MISSING from\n',
            '  /Volumes/${catalog}/landing/csv/\n\n',
            'Missing files:\n',
            concat_ws('\n', collect_list(concat('  - ', filename))),
            '\n\n',
            'ACTION REQUIRED:\n',
            '  1. Download the AdventureWorks OLTP CSV exports:\n',
            '     https://github.com/microsoft/sql-server-samples/tree/master/\n',
            '     samples/databases/adventure-works/oltp-install-script\n\n',
            '  2. Upload the missing .csv files to:\n',
            '     /Volumes/${catalog}/landing/csv/\n',
            '     (UI: Catalog → ${catalog} → bronze → landing → Upload)\n\n',
            '  3. Re-run this notebook.'
        ))
    END AS preflight_status
FROM missing;


-- =============================================================================
-- SALES DOMAIN
-- =============================================================================

-- ---------------------------------------------------------------------------
-- sales.Customer
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.Customer
FROM '/Volumes/${catalog}/landing/csv/Customer.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- sales.SalesOrderHeader
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.SalesOrderHeader
FROM '/Volumes/${catalog}/landing/csv/SalesOrderHeader.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- sales.SalesOrderDetail
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.SalesOrderDetail
FROM '/Volumes/${catalog}/landing/csv/SalesOrderDetail.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- sales.SalesTerritory
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.SalesTerritory
FROM '/Volumes/${catalog}/landing/csv/SalesTerritory.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- sales.SalesTerritoryHistory
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.SalesTerritoryHistory
FROM '/Volumes/${catalog}/landing/csv/SalesTerritoryHistory.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- sales.SalesPerson
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.SalesPerson
FROM '/Volumes/${catalog}/landing/csv/SalesPerson.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- sales.SpecialOffer
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.SpecialOffer
FROM '/Volumes/${catalog}/landing/csv/SpecialOffer.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- sales.SpecialOfferProduct
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.SpecialOfferProduct
FROM '/Volumes/${catalog}/landing/csv/SpecialOfferProduct.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- sales.CurrencyRate
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.CurrencyRate
FROM '/Volumes/${catalog}/landing/csv/CurrencyRate.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- sales.ShipMethod
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.ShipMethod
FROM '/Volumes/${catalog}/landing/csv/ShipMethod.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- sales.CreditCard
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.CreditCard
FROM '/Volumes/${catalog}/landing/csv/CreditCard.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');


-- =============================================================================
-- HUMANRESOURCES DOMAIN
-- =============================================================================

-- ---------------------------------------------------------------------------
-- humanresources.Employee
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.Employee
FROM '/Volumes/${catalog}/landing/csv/Employee.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- humanresources.EmployeePayHistory
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.EmployeePayHistory
FROM '/Volumes/${catalog}/landing/csv/EmployeePayHistory.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- humanresources.EmployeeDepartmentHistory
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.EmployeeDepartmentHistory
FROM '/Volumes/${catalog}/landing/csv/EmployeeDepartmentHistory.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');


-- =============================================================================
-- PERSON DOMAIN
-- Person, PersonPhone, EmailAddress → pipe-delimited: field '+|'  row '&|\n'
-- Address, StateProvince            → tab-delimited
-- =============================================================================

-- ---------------------------------------------------------------------------
-- person.Person  (pipe-delimited — XML in AdditionalContactInfo/Demographics)
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.Person
FROM '/Volumes/${catalog}/landing/csv/Person.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '+|',
    'lineSep'   = '&|\n',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- person.PersonPhone  (pipe-delimited)
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.PersonPhone
FROM '/Volumes/${catalog}/landing/csv/PersonPhone.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '+|',
    'lineSep'   = '&|\n',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- person.EmailAddress  (pipe-delimited)
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.EmailAddress
FROM '/Volumes/${catalog}/landing/csv/EmailAddress.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '+|',
    'lineSep'   = '&|\n',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- person.Address
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.Address
FROM '/Volumes/${catalog}/landing/csv/Address.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- person.StateProvince
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.StateProvince
FROM '/Volumes/${catalog}/landing/csv/StateProvince.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');


-- =============================================================================
-- PRODUCTION DOMAIN
-- =============================================================================

-- ---------------------------------------------------------------------------
-- production.Product
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.Product
FROM '/Volumes/${catalog}/landing/csv/Product.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- production.ProductSubcategory
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.ProductSubcategory
FROM '/Volumes/${catalog}/landing/csv/ProductSubcategory.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- production.ProductCategory
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.ProductCategory
FROM '/Volumes/${catalog}/landing/csv/ProductCategory.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- production.ProductListPriceHistory
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.ProductListPriceHistory
FROM '/Volumes/${catalog}/landing/csv/ProductListPriceHistory.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');

-- ---------------------------------------------------------------------------
-- production.ProductInventory
-- ---------------------------------------------------------------------------
COPY INTO ${catalog}.bronze.ProductInventory
FROM '/Volumes/${catalog}/landing/csv/ProductInventory.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header'    = 'false',
    'delimiter' = '\t',
    'encoding'  = 'UTF-8',
    'nullValue' = ''
)
COPY_OPTIONS ('mergeSchema' = 'false');
