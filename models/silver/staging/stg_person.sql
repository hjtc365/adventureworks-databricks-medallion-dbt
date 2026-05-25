{{ config(materialized="view") }}

with
    src as (select * from {{ source("person", "Person") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src",
                partition_by="businessentityid",
                order_by="modifieddate desc",
            )
        }}
    )

select
    cast(businessentityid as int) as person_bk,
    persontype as person_type,
    cast(namestyle as boolean) as is_eastern_name_style,
    title as title,
    firstname as first_name,
    middlename as middle_name,
    lastname as last_name,
    suffix as suffix,
    concat_ws(
        ' ', firstname, nullif(middlename, ''), lastname, nullif(suffix, '')
    ) as full_name,
    cast(emailpromotion as int) as email_promotion_flag,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
