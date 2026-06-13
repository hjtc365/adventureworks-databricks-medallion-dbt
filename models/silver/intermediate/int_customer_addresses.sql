{{ config(materialized="view") }}

-- Resolves each customer's single best address for use in dim_customer.
--
-- Join path:
-- stg_customer -> stg_person (via person_bk)
-- -> stg_business_entity (via business_entity_bk)
-- -> stg_business_entity_address (via business_entity_bk)
-- -> stg_address (via address_bk)
-- -> stg_state_province (via state_province_bk)
--
-- Address selection: one row per customer via ROW_NUMBER().
-- Priority 1 — address_type_id ASC (Billing = 1 ranked first)
-- Priority 2 — modified_at DESC (most recently updated wins on tie)
--
-- Note: LEFT JOINs are used throughout because not all customers have
-- a linked Person or registered address (e.g. B2B store-only customers).
-- Such customers will produce a single row with all address fields NULL.
with
    customer as (select * from {{ ref("stg_customer") }}),

    person as (select * from {{ ref("stg_person") }}),

    addr as (select * from {{ ref("stg_address") }}),

    state_province as (select * from {{ ref("stg_state_province") }}),

    business_entity as (select * from {{ ref("stg_business_entity") }}),

    business_entity_address as (select * from {{ ref("stg_business_entity_address") }}),

    customer_address as (
        select
            c.customer_bk,
            a.address_bk,
            a.address_line_1,
            a.address_line_2,
            a.city,
            sp.state_province_code,
            sp.state_province_name,
            sp.country_region_code,
            a.postal_code,
            row_number() over (
                partition by c.customer_bk
                order by bea.address_type_id asc, a.modified_at desc nulls last
            ) as _rn
        from customer c
        left join person p on p.person_bk = c.person_bk
        left join business_entity be on be.business_entity_bk = p.person_bk
        left join
            business_entity_address bea
            on bea.business_entity_bk = be.business_entity_bk
        left join addr a on a.address_bk = bea.address_bk
        left join state_province sp on sp.state_province_bk = a.state_province_bk
    )

select
    customer_bk,
    address_bk,
    address_line_1,
    address_line_2,
    city,
    state_province_code,
    state_province_name,
    country_region_code,
    postal_code
from customer_address
where _rn = 1
