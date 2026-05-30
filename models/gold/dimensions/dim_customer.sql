{{ config(materialized="table") }}

-- Type 1 customer dimension.
--
-- AdventureWorks customer attributes that change over time (territory, sales
-- rep) are tracked elsewhere: territory is resolved at order time via
-- dim_salesterritory (point-in-time join in the fact), so dim_customer itself
-- carries only current-state attributes. This keeps the BI model simple:
-- a single equi-join on customer_bk, no version semantics for report authors
-- to reason about.
--
-- Surrogate key is derived from customer_bk so it is stable across rebuilds
-- and unique per customer.
with
    customers as (select * from {{ ref("stg_customer") }}),

    persons as (select * from {{ ref("stg_person") }}),

    stores as (select * from {{ ref("stg_store") }}),

    addresses as (select * from {{ ref("int_customer_addresses") }}),

    enriched as (
        select
            {{ dbt_utils.generate_surrogate_key(["c.customer_bk"]) }} as customer_sk,
            c.customer_bk,
            c.account_number,
            c.customer_type,

            -- person attributes (populated for Individual / StoreContact rows)
            c.person_bk,
            p.title as person_title,
            p.first_name as person_first_name,
            p.middle_name as person_middle_name,
            p.last_name as person_last_name,
            p.suffix as person_suffix,
            p.full_name as person_full_name,
            p.person_type,
            p.email_promotion_flag,

            -- store attributes (populated for Store / StoreContact rows)
            c.store_bk,
            s.store_name,
            s.sales_person_bk as store_sales_person_bk,

            -- unified label so BI users have one customer_name to slice by
            -- regardless of customer_type.
            coalesce(s.store_name, p.full_name) as customer_name,

            -- current address (Type 1)
            a.address_line_1 as current_address_line_1,
            a.address_line_2 as current_address_line_2,
            a.city as current_city,
            a.state_province_code as current_state_province_code,
            a.state_province_name as current_state_province_name,
            a.country_region_code as current_country_region_code,
            a.postal_code as current_postal_code,

            c.row_guid,
            c.modified_at,
            false as is_unknown
        from customers c
        left join persons p on p.person_bk = c.person_bk
        left join stores s on s.store_bk = c.store_bk
        left join addresses a on a.customer_bk = c.customer_bk
    ),

    -- Inferred-member row so fact FKs never dangle. Keys chosen so the
    -- surrogate (`-1`) and business key (`-1`) are obviously synthetic.
    unknown_member as (
        select
            '-1' as customer_sk,
            cast(-1 as int) as customer_bk,
            cast(null as string) as account_number,
            'Unknown' as customer_type,
            cast(null as int) as person_bk,
            cast(null as string) as person_title,
            cast(null as string) as person_first_name,
            cast(null as string) as person_middle_name,
            cast(null as string) as person_last_name,
            cast(null as string) as person_suffix,
            cast(null as string) as person_full_name,
            cast(null as string) as person_type,
            cast(null as int) as email_promotion_flag,
            cast(null as int) as store_bk,
            cast(null as string) as store_name,
            cast(null as int) as store_sales_person_bk,
            'Unknown' as customer_name,
            cast(null as string) as current_address_line_1,
            cast(null as string) as current_address_line_2,
            cast(null as string) as current_city,
            cast(null as string) as current_state_province_code,
            cast(null as string) as current_state_province_name,
            cast(null as string) as current_country_region_code,
            cast(null as string) as current_postal_code,
            cast(null as string) as row_guid,
            cast(null as timestamp) as modified_at,
            true as is_unknown
    )

select * from enriched
union all
select * from unknown_member
