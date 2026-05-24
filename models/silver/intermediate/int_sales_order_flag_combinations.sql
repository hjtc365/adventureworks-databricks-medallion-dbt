{{ config(materialized="view") }}

-- Builds the deduplicated combination set that backs dim_sales_order_junk.
-- The junk dim collapses 5 low-cardinality flag attributes that don't fit
-- naturally as standalone dimensions (per the Kimball junk-dim pattern).
with
    src as (
        select
            soh.order_status,
            soh.is_online_order,
            soh.revision_number,
            sm.ship_method_name,
            cc.card_type
        from {{ ref("stg_sales_order_header") }} soh
        left join
            {{ ref("stg_ship_method") }} sm on sm.ship_method_bk = soh.ship_method_bk
        left join
            {{ ref("stg_credit_card") }} cc on cc.credit_card_bk = soh.credit_card_bk
    )

select distinct
    coalesce(order_status, 'Unknown') as order_status,
    coalesce(is_online_order, false) as is_online_order,
    coalesce(revision_number, 0) as revision_number,
    coalesce(ship_method_name, 'Unknown') as ship_method_name,
    coalesce(card_type, 'No Card') as card_type
from src
