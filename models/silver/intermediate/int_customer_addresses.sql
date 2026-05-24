{{ config(materialized="view") }}

-- Joins customers to their primary address for use in dim_customer.
-- Uses Person.BusinessEntityAddress to resolve PersonID -> AddressID.
-- Address type ordering: Billing (1) preferred, then by most recently modified.
with
    customers as (select * from {{ ref("stg_customer") }}),

    addresses as (select * from {{ ref("stg_address") }}),

    state_province as (select * from {{ ref("stg_state_province") }}),

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
        from customers c
        left join business_entity_address bea on bea.person_bk = c.person_bk
        left join addresses a on a.address_bk = bea.address_bk
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
