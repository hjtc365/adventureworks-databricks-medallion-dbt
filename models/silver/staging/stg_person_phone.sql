{{ config(materialized="view") }}

with
    src as (select * from {{ source("person", "PersonPhone") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src",
                partition_by="businessentityid, phonenumber, phonenumbertypeid",
                order_by="modifieddate desc",
            )
        }}
    )

select
    cast(businessentityid as int) as person_bk,
    cast(phonenumbertypeid as int) as phone_type_id,
    phonenumber as phone_number,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
