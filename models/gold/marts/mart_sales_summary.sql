{{ config(materialized="table") }}

-- Pre-aggregated sales summary by territory + product category + month.
-- Powers BI dashboards directly without re-computing aggregations.
with
    f as (select * from {{ ref("fct_sales_detail") }}),
    dt as (select * from {{ ref("dim_date") }}),
    dp as (select * from {{ ref("dim_product") }}),
    dst as (select * from {{ ref("dim_salesterritory") }})

select
    -- dates
    dt.year_number as year_number,
    dt.quarter_number as quarter_number,
    dt.month_number as month_number,
    dt.month_name as month_name,

    -- territory
    dst.territory_name as territory_name,
    dst.country_region_code as country_region_code,
    dst.territory_group as territory_group,

    -- product
    dp.category_name as category_name,
    dp.subcategory_name as subcategory_name,

    -- order counts
    count(distinct f.sales_order_bk) as order_count,
    count(f.sales_order_line_bk) as line_count,

    -- volume
    sum(f.order_qty) as units_sold,
    sum(f.order_qty)
    / nullif(count(distinct f.sales_order_bk), 0) as avg_units_per_order,
    count(f.sales_order_line_bk)
    / nullif(count(distinct f.sales_order_bk), 0) as avg_lines_per_order,

    -- ── Revenue waterfall ────────────────────────────────────────────────────
    -- gross_revenue : committed unit price × qty before any discount is applied
    --                 = sum(unit_price * order_qty)
    sum(f.unit_price * f.order_qty) as gross_revenue,

    -- discount_amount : reduction from UnitPriceDiscount on the committed price
    --                   = gross_revenue - net_revenue  (always >= 0)
    sum(f.discount_amount) as discount_amount,

    -- net_revenue : actual recognised revenue after discounts
    --               = line_total = unit_price * order_qty * (1 - unit_price_discount)
    --               = gross_revenue - discount_amount
    sum(f.line_total) as net_revenue,

    -- ── Overhead (semi-additive) ──────────────────────────────────────────────
    -- allocated_freight / allocated_tax are prorated from the order header to
    -- each line by (line_total / order_line_total). Safe to SUM within a single
    -- order slice; avoid summing lines that span multiple orders without grouping
    -- by sales_order_bk to prevent double-counting.
    sum(f.allocated_freight) as freight_allocated,
    sum(f.allocated_tax) as tax_allocated,

    -- ── Profitability ─────────────────────────────────────────────────────────
    -- total_cost   : COGS at standard cost for units sold
    --                = standard_cost × order_qty
    sum(dp.standard_cost * f.order_qty) as total_cost,

    -- gross_profit : net_revenue minus COGS only (before freight and tax)
    --                = net_revenue - total_cost
    --                = line_total - (standard_cost × order_qty)
    sum(f.line_total - (dp.standard_cost * f.order_qty)) as gross_profit,

    -- ── Averages ──────────────────────────────────────────────────────────────
    -- avg_order_value : net_revenue per distinct order
    sum(f.line_total) / nullif(count(distinct f.sales_order_bk), 0) as avg_order_value,

    -- avg_line_value  : mean net revenue per individual order line
    avg(f.line_total) as avg_line_value

from f
left join dt on dt.date_sk = f.order_date_sk
left join dp on dp.product_sk = f.product_sk
left join dst on dst.sales_territory_sk = f.sales_territory_sk
group by
    dt.year_number,
    dt.quarter_number,
    dt.month_number,
    dt.month_name,
    dst.territory_name,
    dst.country_region_code,
    dst.territory_group,
    dp.category_name,
    dp.subcategory_name
