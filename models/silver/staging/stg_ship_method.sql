{{ config(materialized="view") }}

with
    src as (select * from {{ source("sales", "ShipMethod") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src",
                partition_by="shipmethodid",
                order_by="modifieddate desc",
            )
        }}
    )

select
    cast(shipmethodid as int) as ship_method_bk,
    name as ship_method_name,
    cast(shipbase as decimal(19, 4)) as ship_base_cost,
    cast(shiprate as decimal(19, 4)) as ship_rate,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
