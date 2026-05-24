{{ config(materialized="view") }}

with src as (select * from {{ source("sales", "SalesPerson") }})

select
    cast(businessentityid as int) as sales_person_bk,
    cast(territoryid as int) as sales_territory_bk,
    cast(salesquota as decimal(19, 4)) as sales_quota,
    cast(bonus as decimal(19, 4)) as bonus,
    cast(commissionpct as decimal(10, 4)) as commission_pct,
    cast(salesytd as decimal(19, 4)) as sales_ytd,
    cast(saleslastyear as decimal(19, 4)) as sales_last_year,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from src
