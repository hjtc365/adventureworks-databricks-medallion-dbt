{{ config(materialized="view") }}

with src as (select * from {{ source("person", "PersonPhone") }})

select
    cast(businessentityid as int) as person_bk,
    cast(phonenumbertypeid as int) as phone_type_id,
    phonenumber as phone_number,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from src
