{{ config(materialized="table") }}

-- Promoted to a proper dimension (NOT a junk dim) because:
-- • discount_pct drives revenue calculations and is high-cardinality
-- • it has its own attributes (description, type, category, validity dates)
-- • it has a meaningful surrogate-key relationship to fact rows
with
    so as (select * from {{ ref("stg_special_offer") }}),
    sop as (select * from {{ ref("stg_special_offer_product") }}),

    enriched as (
        select
            {{ dbt_utils.generate_surrogate_key(["so.special_offer_bk"]) }}
            as special_offer_sk,
            so.special_offer_bk,
            so.offer_description,
            so.offer_type,
            so.offer_category,
            so.discount_pct,

            case
                when so.discount_pct = 0
                then 'No Discount'
                when so.discount_pct < 0.05
                then 'Low (<5%)'
                when so.discount_pct < 0.15
                then 'Medium (5-15%)'
                when so.discount_pct < 0.30
                then 'High (15-30%)'
                else 'Deep (30%+)'
            end as discount_tier,

            so.start_at,
            so.end_at,
            so.min_qty,
            so.max_qty,
            case
                when current_timestamp() between so.start_at and so.end_at
                then true
                else false
            end as is_active,
            coalesce(opc.product_count, 0) as eligible_product_count,
            false as is_unknown
        from so
        left join
            (
                select special_offer_bk, count(*) as product_count
                from sop
                group by special_offer_bk
            ) opc
            on opc.special_offer_bk = so.special_offer_bk
    ),

    unknown_member as (
        select
            '-1' as special_offer_sk,
            cast(-1 as int) as special_offer_bk,
            'Unknown' as offer_description,
            cast(null as string) as offer_type,
            cast(null as string) as offer_category,
            cast(0 as decimal(10, 4)) as discount_pct,
            'No Discount' as discount_tier,
            cast(null as timestamp) as start_at,
            cast(null as timestamp) as end_at,
            cast(null as int) as min_qty,
            cast(null as int) as max_qty,
            false as is_active,
            cast(0 as bigint) as eligible_product_count,
            true as is_unknown
    )

select * from enriched
union all
select * from unknown_member
