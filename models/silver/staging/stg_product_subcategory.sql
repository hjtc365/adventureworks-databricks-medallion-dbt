{{ config(materialized="view") }}

with
    src as (select * from {{ source("production", "ProductSubcategory") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src",
                partition_by="productsubcategoryid",
                order_by="modifieddate desc",
            )
        }}
    )

select
    cast(productsubcategoryid as int) as product_subcategory_bk,
    cast(productcategoryid as int) as product_category_bk,
    name as subcategory_name,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
