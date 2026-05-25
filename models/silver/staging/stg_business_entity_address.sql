{{ config(materialized="view") }}

with
    src as (select * from {{ source("person", "BusinessEntityAddress") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src",
                partition_by="businessentityid, addressid, addresstypeid",
                order_by="modifieddate desc",
            )
        }}
    )

select
    cast(businessentityid as int) as business_entity_bk,
    cast(addressid as int) as address_bk,
    cast(addresstypeid as int) as address_type_id,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
