{{ config(materialized="view") }}

with
    src as (select * from {{ source("person", "StateProvince") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src",
                partition_by="stateprovinceid",
                order_by="modifieddate desc",
            )
        }}
    )

select
    cast(stateprovinceid as int) as state_province_bk,
    stateprovincecode as state_province_code,
    countryregioncode as country_region_code,
    cast(isonlystateprovinceflag as boolean) as is_only_state_province,
    name as state_province_name,
    cast(territoryid as int) as sales_territory_bk,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
