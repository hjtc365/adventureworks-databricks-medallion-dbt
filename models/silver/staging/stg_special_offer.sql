{{ config(materialized="view") }}

with
    src as (select * from {{ source("sales", "SpecialOffer") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src",
                partition_by="specialofferid",
                order_by="modifieddate desc",
            )
        }}
    )

select
    cast(specialofferid as int) as special_offer_bk,
    description as offer_description,
    cast(discountpct as decimal(10, 4)) as discount_pct,
    type as offer_type,
    category as offer_category,
    cast(left(startdate, 19) as timestamp) as start_at,
    cast(left(enddate, 19) as timestamp) as end_at,
    cast(minqty as int) as min_qty,
    cast(maxqty as int) as max_qty,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
