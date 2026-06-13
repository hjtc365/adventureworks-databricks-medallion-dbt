{{ config(materialized="view") }}

-- Denormalises the three-level product hierarchy into a single flat row
-- per product for use as the source of the dim_product snapshot.
--
-- Join path:
--   stg_product -> stg_product_subcategory (via product_subcategory_bk)
--              -> stg_product_category     (via product_category_bk)
--
-- Note: LEFT JOINs are used because not all products are assigned a
-- subcategory or category (e.g. raw materials, internal components).
-- Missing names default to 'Unassigned' via COALESCE rather than
-- dropping the product row.
--
-- product_status is a derived field computed here once so dim_product
-- does not need to re-implement the logic:
--   'Discontinued' — discontinued_at IS NOT NULL
--   'Inactive'     — sell_end_at is set and in the past
--   'Active'       — all other products
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
