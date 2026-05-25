{{ config(materialized="view") }}

with
    src as (select * from {{ source("sales", "SalesTerritory") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src",
                partition_by="territoryid",
                order_by="modifieddate desc",
            )
        }}
    )

select
    cast(territoryid as int) as sales_territory_bk,
    name as territory_name,
    countryregioncode as country_region_code,
    `Group` as territory_group,
    cast(salesytd as decimal(19, 4)) as sales_ytd,
    cast(saleslastyear as decimal(19, 4)) as sales_last_year,
    cast(costytd as decimal(19, 4)) as cost_ytd,
    cast(costlastyear as decimal(19, 4)) as cost_last_year,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
