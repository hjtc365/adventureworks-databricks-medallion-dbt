{{ config(materialized="table") }}

-- Gold view over the dim_customer snapshot.
-- Exposes the SCD2 history with surrogate key (customer_sk) for fact joins.
with
    snap as (select * from {{ ref("snap_customer") }}),

    addresses as (select * from {{ ref("int_customer_addresses") }})

select
    {{ dbt_utils.generate_surrogate_key(["snap.dbt_scd_id"]) }} as customer_sk,
    snap.customer_bk,
    snap.person_bk,
    snap.store_bk,
    snap.sales_territory_bk,
    snap.account_number,
    snap.customer_type,

    -- current address (Type 1 attributes layered on Type 2 dim)
    addr.address_line_1,
    addr.address_line_2,
    addr.city,
    addr.state_province_code,
    addr.state_province_name,
    addr.country_region_code,
    addr.postal_code,

    -- SCD2 metadata
    snap.dbt_valid_from as valid_from,
    snap.dbt_valid_to as valid_to,
    case when snap.dbt_valid_to is null then true else false end as is_current
from snap
left join addresses addr on addr.customer_bk = snap.customer_bk
