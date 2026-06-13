{{ config(materialized="view") }}

-- Builds the distinct combination set of low-cardinality order attributes
-- that back dim_sales_order_junk (Kimball junk dimension pattern).
--
-- Attributes included (5 low-cardinality flags/descriptors):
--   order_status      — fulfilment state of the order
--   is_online_order   — channel flag (web vs sales rep)
--   revision_number   — number of times the order was amended
--   ship_method_name  — resolved from stg_ship_method via ship_method_bk
--   card_type         — resolved from stg_credit_card via credit_card_bk
--
-- Join path:
--   stg_sales_order_header -> stg_ship_method  (via ship_method_bk)
--                          -> stg_credit_card  (via credit_card_bk)
--
-- Note: LEFT JOINs are used because ship_method_bk and credit_card_bk are
-- nullable on stg_sales_order_header (e.g. cash orders have no credit card).
-- NULLs are defaulted via COALESCE before DISTINCT so that NULL variants
-- do not create spurious extra combinations in the junk dim:
--   order_status     NULL -> 'Unknown'
--   is_online_order  NULL -> false
--   revision_number  NULL -> 0
--   ship_method_name NULL -> 'Unknown'
--   card_type        NULL -> 'No Card'
with
    soh as (select * from {{ ref("stg_sales_order_header") }}),
    sm as (select * from {{ ref("stg_ship_method") }}),
    cc as (select * from {{ ref("stg_credit_card") }}),
    sales_order_flags_combos as (
        select
            soh.order_status,
            soh.is_online_order,
            soh.revision_number,
            sm.ship_method_name,
            cc.card_type
        from soh
        left join sm on sm.ship_method_bk = soh.ship_method_bk
        left join cc on cc.credit_card_bk = soh.credit_card_bk
    )

select distinct
    coalesce(order_status, 'Unknown') as order_status,
    coalesce(is_online_order, false) as is_online_order,
    coalesce(revision_number, 0) as revision_number,
    coalesce(ship_method_name, 'Unknown') as ship_method_name,
    coalesce(card_type, 'No Card') as card_type
from sales_order_flags_combos
