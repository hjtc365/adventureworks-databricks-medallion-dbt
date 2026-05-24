{{ config(materialized="view") }}

with src as (select * from {{ source("person", "BusinessEntityAddress") }})

select
    cast(businessentityid as int) as person_bk,
    cast(addressid as int) as address_bk,
    cast(addresstypeid as int) as address_type_id,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from src
