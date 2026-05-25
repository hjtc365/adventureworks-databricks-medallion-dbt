{{ config(materialized="view") }}

with
    src as (select * from {{ source("production", "ProductListPriceHistory") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src",
                partition_by="productid, startdate",
                order_by="modifieddate desc",
            )
        }}
    )

select
    cast(productid as int) as product_bk,
    cast(startdate as timestamp) as start_at,
    cast(enddate as timestamp) as end_at,
    cast(listprice as decimal(19, 4)) as list_price,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
