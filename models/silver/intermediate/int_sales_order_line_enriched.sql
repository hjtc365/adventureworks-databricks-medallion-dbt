{{ config(materialized="view") }}

-- Enriches each order line with its parent header attributes and allocated
-- semi-additive measures for use in fct_sales_detail.
--
-- Join path:
--   stg_sales_order_detail -> stg_sales_order_header (via sales_order_bk)
--                          -> stg_ship_method        (via ship_method_bk)
--                          -> stg_credit_card        (via credit_card_bk)
--                          -> lt (line total CTE)    (via sales_order_bk)
--
-- Header attributes brought to line grain:
--   Dates       — order_date, due_date, ship_date
--   Flags       — order_status, is_online_order, revision_number
--   FKs         — customer_bk, sales_person_bk, sales_territory_bk,
--                 ship_method_bk, credit_card_bk, currency_rate_bk
--   Amounts     — header_sub_total, header_tax_amount, header_freight,
--                 header_total_due (prefixed to signal header grain)
--
-- Semi-additive allocation (freight and tax):
--   freight and tax_amount are header-level amounts that would double-count
--   if summed naively across lines. Both are allocated proportionally to
--   each line's share of header_line_total:
--     allocated = header_amount * (line_total / header_line_total)
--   Edge case: if header_line_total = 0 (fully discounted order), allocated
--   values default to 0 to avoid division by zero.
--
-- Note: INNER JOIN to stg_sales_order_header since a detail row without a
-- header is an orphan and should not reach the fact table. All other joins
-- are LEFT to preserve lines where ship method or credit card is not set
-- (e.g. cash orders, internally fulfilled lines).
with
    d as (select * from {{ ref("stg_sales_order_detail") }}),
    h as (select * from {{ ref("stg_sales_order_header") }}),
    sm as (select * from {{ ref("stg_ship_method") }}),
    cc as (select * from {{ ref("stg_credit_card") }}),
    lt as (
        select sales_order_bk, sum(line_total) as header_line_total
        from d
        group by sales_order_bk
    )

select
    d.sales_order_line_bk,
    d.sales_order_bk,
    d.sales_order_detail_bk,
    d.product_bk,
    d.special_offer_bk,
    d.order_qty,
    d.unit_price,
    d.unit_price_discount,
    d.line_total,

    -- header attributes
    h.order_date,
    h.due_date,
    h.ship_date,
    h.order_status,
    h.is_online_order,
    h.revision_number,
    h.customer_bk,
    h.sales_person_bk,
    h.sales_territory_bk,
    h.ship_method_bk,
    coalesce(sm.ship_method_name, 'Unknown') as ship_method_name,
    h.credit_card_bk,
    coalesce(cc.card_type, 'No Card') as card_type,
    h.currency_rate_bk,
    h.sub_total as header_sub_total,
    h.tax_amount as header_tax_amount,
    h.freight as header_freight,
    h.total_due as header_total_due,

    -- allocated semi-additive measures (proportional to line_total)
    case
        when lt.header_line_total > 0
        then h.freight * (d.line_total / lt.header_line_total)
        else 0
    end as allocated_freight,
    case
        when lt.header_line_total > 0
        then h.tax_amount * (d.line_total / lt.header_line_total)
        else 0
    end as allocated_tax,

    d.modified_at
from d
inner join h on h.sales_order_bk = d.sales_order_bk
left join lt on lt.sales_order_bk = d.sales_order_bk
left join sm on sm.ship_method_bk = h.ship_method_bk
left join cc on cc.credit_card_bk = h.credit_card_bk
