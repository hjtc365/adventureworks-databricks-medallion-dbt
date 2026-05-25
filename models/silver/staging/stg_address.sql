{{ config(materialized="view") }}

with
    src as (select * from {{ source("person", "Address") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src", partition_by="addressid", order_by="modifieddate desc"
            )
        }}
    )

select
    cast(addressid as int) as address_bk,
    addressline1 as address_line_1,
    addressline2 as address_line_2,
    city as city,
    cast(stateprovinceid as int) as state_province_bk,
    postalcode as postal_code,
    cast(spatiallocation as string) as spatial_location_raw,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
