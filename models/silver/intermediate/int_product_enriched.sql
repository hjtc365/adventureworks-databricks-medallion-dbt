{{ config(materialized="view") }}

-- Denormalises Product → ProductSubcategory → ProductCategory.
-- This is the single source for dim_product (snapshot).
with
    p as (select * from {{ ref("stg_product") }}),
    s as (select * from {{ ref("stg_product_subcategory") }}),
    c as (select * from {{ ref("stg_product_category") }})

select
    p.product_bk,
    p.product_name,
    p.product_number,
    p.is_make,
    p.is_finished_good,
    p.color,
    p.product_line,
    p.product_class,
    p.product_style,
    p.size,
    p.size_uom_code,
    p.weight,
    p.weight_uom_code,
    p.standard_cost,
    p.list_price,
    p.days_to_manufacture,
    p.product_subcategory_bk,
    coalesce(s.subcategory_name, 'Unassigned') as subcategory_name,
    s.product_category_bk,
    coalesce(c.category_name, 'Unassigned') as category_name,
    p.sell_start_at,
    p.sell_end_at,
    p.discontinued_at,
    case
        when p.discontinued_at is not null
        then 'Discontinued'
        when p.sell_end_at is not null and p.sell_end_at < current_timestamp()
        then 'Inactive'
        else 'Active'
    end as product_status,
    p.modified_at
from p
left join s on s.product_subcategory_bk = p.product_subcategory_bk
left join c on c.product_category_bk = s.product_category_bk
