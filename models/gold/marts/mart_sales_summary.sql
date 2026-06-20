{{ config(materialized="table") }}

-- Pre-aggregated sales summary by territory + product category + sales person + month.
-- Powers BI dashboards directly without re-computing aggregations.
--
-- Attribute timing rules:
--   * Territory attributes (territory_name, country_region_code, territory_group)
--     and product attributes (category_name, subcategory_name) are recorded
--     **as of the sale** via the SCD2 _sk joins. If a territory is renamed or a
--     category re-labelled mid-month, sales before the change attribute to the
--     old version and sales after to the new version — producing two rows for
--     that month at the affected slice. These attributes participate in the
--     grain.
--   * Employee full_name is resolved **from the current SCD2 version** after
--     aggregation. A rep rename mid-month does NOT split their slice into two
--     rows; the latest name is shown against the combined totals.
--
-- Grain:
--   (year_number, quarter_number, month_number,
--    sales_territory_bk, territory_name, country_region_code, territory_group,
--    product_category_bk, category_name,
--    product_subcategory_bk, subcategory_name,
--    employee_bk)
with
    f as (select * from {{ ref("fct_sales_detail") }}),
    dt as (select * from {{ ref("dim_date") }}),
    dp as (select * from {{ ref("dim_product") }}),
    dst as (select * from {{ ref("dim_salesterritory") }}),
    dem as (select * from {{ ref("dim_employee") }}),

    -- ── Current-version employee labels (one row per employee_bk) ─────────────
    dem_current as (
        select employee_bk, full_name
        from dem
        where is_current = true
    ),

    -- ── Aggregate at version-correct grain for territory + product ────────────
    -- Territory and product descriptive attributes are included in the GROUP BY
    -- so SCD2 changes split slices correctly (point-in-time attribution).
    -- Employee identity is carried by employee_bk only; the display name is
    -- joined in afterwards from the current version.
    agg as (
        select
            -- dates
            dt.year_number as year_number,
            dt.quarter_number as quarter_number,
            dt.month_number as month_number,
            dt.month_name as month_name,

            -- territory (version-correct via SCD2 _sk join)
            dst.sales_territory_bk as sales_territory_bk,
            dst.territory_name as territory_name,
            dst.country_region_code as country_region_code,
            dst.territory_group as territory_group,

            -- product (version-correct via SCD2 _sk join)
            -- Coalesce BKs to -1 so the unknown product member (which carries
            -- null category/subcategory BKs) stays consistent with the project's
            -- -1 unknown-member convention and never violates not_null.
            coalesce(dp.product_category_bk, -1) as product_category_bk,
            coalesce(dp.category_name, 'Unknown') as category_name,
            coalesce(dp.product_subcategory_bk, -1) as product_subcategory_bk,
            coalesce(dp.subcategory_name, 'Unknown') as subcategory_name,

            -- employee grain key (display name resolved post-agg)
            em.employee_bk as employee_bk,

            -- order counts
            count(distinct f.sales_order_bk) as order_count,
            count(f.sales_order_line_bk) as line_count,

            -- volume
            sum(f.order_qty) as units_sold,
            sum(f.order_qty)
            / nullif(count(distinct f.sales_order_bk), 0) as avg_units_per_order,
            count(f.sales_order_line_bk)
            / nullif(count(distinct f.sales_order_bk), 0) as avg_lines_per_order,

            -- ── Revenue waterfall ─────────────────────────────────────────────
            -- gross_revenue : committed unit price × qty before any discount
            --                 = sum(unit_price * order_qty)
            sum(f.unit_price * f.order_qty) as gross_revenue,

            -- discount_amount : reduction from UnitPriceDiscount on the committed
            --                   price = gross_revenue - net_revenue  (always >= 0)
            sum(f.discount_amount) as discount_amount,

            -- net_revenue : actual recognised revenue after discounts
            --               = line_total = unit_price * order_qty * (1 - discount)
            --               = gross_revenue - discount_amount
            sum(f.line_total) as net_revenue,

            -- ── Overhead (semi-additive) ──────────────────────────────────────
            -- allocated_freight / allocated_tax are prorated from the order header
            -- to each line by (line_total / order_line_total). Safe to SUM within
            -- a single order slice; avoid summing lines that span multiple orders
            -- without grouping by sales_order_bk to prevent double-counting.
            sum(f.allocated_freight) as freight_allocated,
            sum(f.allocated_tax) as tax_allocated,

            -- ── Profitability ─────────────────────────────────────────────────
            -- total_cost   : COGS at standard cost for units sold
            --                = standard_cost × order_qty
            sum(dp.standard_cost * f.order_qty) as total_cost,

            -- gross_profit : net_revenue minus COGS only (before freight and tax)
            --                = net_revenue - total_cost
            --                = line_total - (standard_cost × order_qty)
            sum(f.line_total - (dp.standard_cost * f.order_qty)) as gross_profit,

            -- ── Averages ──────────────────────────────────────────────────────
            -- avg_order_value : net_revenue per distinct order
            sum(f.line_total)
            / nullif(count(distinct f.sales_order_bk), 0) as avg_order_value,

            -- avg_line_value  : mean net revenue per individual order line
            avg(f.line_total) as avg_line_value

        from f
        left join dt on dt.date_sk = f.order_date_sk
        left join dp on dp.product_sk = f.product_sk
        left join dst on dst.sales_territory_sk = f.sales_territory_sk
        left join dem on dem.employee_sk = f.employee_sk
        group by
            dt.year_number,
            dt.quarter_number,
            dt.month_number,
            dt.month_name,
            dst.sales_territory_bk,
            dst.territory_name,
            dst.country_region_code,
            dst.territory_group,
            coalesce(dp.product_category_bk, -1),
            coalesce(dp.category_name, 'Unknown'),
            coalesce(dp.product_subcategory_bk, -1),
            coalesce(dp.subcategory_name, 'Unknown'),
            dem.employee_bk
    )

select
    -- dates
    agg.year_number as year_number,
    agg.quarter_number as quarter_number,
    agg.month_number as month_number,
    agg.month_name as month_name,

    -- territory (version-correct)
    agg.sales_territory_bk as sales_territory_bk,
    agg.territory_name as territory_name,
    agg.country_region_code as country_region_code,
    agg.territory_group as territory_group,

    -- product (version-correct)
    agg.product_category_bk as product_category_bk,
    agg.category_name as category_name,
    agg.product_subcategory_bk as product_subcategory_bk,
    agg.subcategory_name as subcategory_name,

    -- employee (BK is grain; name is current)
    agg.employee_bk as employee_bk,
    coalesce(dem_current.full_name, 'Unknown') as employee_name,

    -- measures
    agg.order_count,
    agg.line_count,
    agg.units_sold,
    agg.avg_units_per_order,
    agg.avg_lines_per_order,
    agg.gross_revenue,
    agg.discount_amount,
    agg.net_revenue,
    agg.freight_allocated,
    agg.tax_allocated,
    agg.total_cost,
    agg.gross_profit,
    agg.avg_order_value,
    agg.avg_line_value

from agg
left join dem_current on dem_current.employee_bk = agg.employee_bk