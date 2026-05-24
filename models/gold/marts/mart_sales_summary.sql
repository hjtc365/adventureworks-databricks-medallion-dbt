{{ config(materialized="table") }}

-- Pre-aggregated sales summary by territory + product category + month.
-- Powers BI dashboards directly without re-computing aggregations.
with
    f as (select * from {{ ref("fct_sales_detail") }}),
    dt as (select * from {{ ref("dim_date") }}),
    dp as (select * from {{ ref("dim_product") }}),
    dst as (select * from {{ ref("dim_salesterritory") }})

select
    dt.year_number,
    dt.quarter_number,
    dt.month_number,
    dt.month_name,
    dst.territory_name,
    dst.country_region_code,
    dst.territory_group,
    dp.category_name,
    dp.subcategory_name,

    count(distinct f.sales_order_bk) as order_count,
    sum(f.order_qty) as units_sold,
    sum(f.line_total) as gross_revenue,
    sum(f.discount_amount) as discount_amount,
    sum(f.allocated_freight) as freight_allocated,
    sum(f.allocated_tax) as tax_allocated,
    sum(f.line_total_with_overhead) as net_revenue,

    avg(f.line_total) as avg_line_value,
    sum(f.line_total) / nullif(count(distinct f.sales_order_bk), 0) as avg_order_value
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
