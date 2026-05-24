{{ config(materialized="view") }}

with src as (select * from {{ source("person", "EmailAddress") }})

select
    cast(businessentityid as int) as person_bk,
    cast(emailaddressid as int) as email_address_bk,
    lower(trim(emailaddress)) as email_address,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from src
