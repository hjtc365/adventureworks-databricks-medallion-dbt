{{ config(materialized="view") }}

with src as (select * from {{ source("sales", "SalesTerritoryHistory") }})

select
    cast(businessentityid as int) as sales_person_bk,
    cast(territoryid as int) as sales_territory_bk,
    cast(startdate as timestamp) as start_at,
    cast(enddate as timestamp) as end_at,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from src
