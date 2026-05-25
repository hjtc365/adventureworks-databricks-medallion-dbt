{{
    config(
        materialized="incremental",
        incremental_strategy="merge",
        unique_key=["product_bk", "location_bk"],
        on_schema_change="append_new_columns",
    )
}}

with
    src as (

        select *
        from {{ source("production", "ProductInventory") }}

        {% if is_incremental() %}
            where
                modifieddate
                >= (select dateadd(day, -1, max(modified_at)) from {{ this }})
        {% endif %}

    ),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src",
                partition_by="productid, locationid",
                order_by="modifieddate desc",
            )
        }}
    )

select
    cast(productid as int) as product_bk,
    cast(locationid as int) as location_bk,
    shelf as shelf,
    cast(bin as int) as bin,
    cast(quantity as int) as quantity,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
