{{ config(materialized="table") }}

with snap as (select * from {{ ref("snap_product") }})

select
    {{ dbt_utils.generate_surrogate_key(["dbt_scd_id"]) }} as product_sk,
    product_bk,
    product_name,
    product_number,
    is_make,
    is_finished_good,
    color,
    product_line,
    product_class,
    product_style,
    size,
    weight,
    standard_cost,
    list_price,
    days_to_manufacture,
    product_subcategory_bk,
    subcategory_name,
    product_category_bk,
    category_name,
    product_status,
    sell_start_at,
    sell_end_at,
    discontinued_at,
    dbt_valid_from as valid_from,
    dbt_valid_to as valid_to,
    case when dbt_valid_to is null then true else false end as is_current
from snap
