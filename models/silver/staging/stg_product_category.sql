{{ config(materialized="view") }}

with src as (select * from {{ source("production", "ProductCategory") }})

select
    cast(productcategoryid as int) as product_category_bk,
    name as category_name,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from src
