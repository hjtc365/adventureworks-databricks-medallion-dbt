{{ config(materialized="view") }}

with
    src as (select * from {{ source("person", "BusinessEntity") }}),

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
    cast(businessentityid as int) as business_entity_bk,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
