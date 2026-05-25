{{ config(materialized="view") }}

with
    src as (select * from {{ source("sales", "SpecialOfferProduct") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src",
                partition_by="specialofferid, productid",
                order_by="modifieddate desc",
            )
        }}
    )

select
    cast(specialofferid as int) as special_offer_bk,
    cast(productid as int) as product_bk,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
