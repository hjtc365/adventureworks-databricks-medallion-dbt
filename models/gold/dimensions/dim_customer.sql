{{ config(materialized="table") }}

-- Gold view over the dim_customer snapshot.
-- Exposes the SCD2 history with surrogate key (customer_sk) for fact joins.
with
    cust_snap as (select * from {{ ref("snap_customer") }}),

    addresses as (select * from {{ ref("int_customer_addresses") }}),

    persons as (select * from {{ ref("stg_person") }}),

    stores as (select * from {{ ref("stg_store") }}),

    territories as (select * from {{ ref("stg_sales_territory") }})

select
    {{ dbt_utils.generate_surrogate_key(["cust_snap.dbt_scd_id"]) }} as customer_sk,
    cust_snap.customer_bk,

    -- person attributes
    cust_snap.person_bk,
    p.full_name as person_full_name,
    p.first_name as person_first_name,
    p.last_name as person_last_name,

    -- store attributes
    cust_snap.store_bk,
    s.store_name,

    -- territory attributes
    cust_snap.sales_territory_bk,
    t.territory_name,
    t.territory_group,

    cust_snap.account_number,
    cust_snap.customer_type,

    -- current address (Type 1 attributes layered on Type 2 dim)
    addr.address_line_1,
    addr.address_line_2,
    addr.city,
    addr.state_province_code,
    addr.state_province_name,
    addr.country_region_code,
    addr.postal_code,

    -- SCD2 metadata
    cust_snap.dbt_valid_from as valid_from,
    cust_snap.dbt_valid_to as valid_to,
    case when cust_snap.dbt_valid_to is null then true else false end as is_current
from cust_snap
left join addresses addr on addr.customer_bk = cust_snap.customer_bk
left join persons p on p.person_bk = cust_snap.person_bk
left join stores s on s.store_bk = cust_snap.store_bk
left join territories t on t.sales_territory_bk = cust_snap.sales_territory_bk
