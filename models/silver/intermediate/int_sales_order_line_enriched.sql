{{ config(materialized="view") }}

-- Joins each order line back to its header to expose header-level
-- attributes (dates, customer, territory, ship/payment) needed by
-- fct_sales_detail without requiring a re-join in every downstream model.
-- Also computes allocated semi-additive measures for header-level amounts
-- (freight, tax) so they can be summed at line grain without double-counting.
with
    d as (select * from {{ ref("stg_sales_order_detail") }}),
    h as (select * from {{ ref("stg_sales_order_header") }}),
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
    h.credit_card_bk,
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
