{{ config(materialized="view") }}

with
    src as (select * from {{ source("sales", "Store") }}),

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
    cast(businessentityid as int) as store_bk,
    name as store_name,
    cast(salespersonid as int) as sales_person_bk,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
