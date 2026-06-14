{{ config(materialized="table") }}

with
    snap as (select * from {{ ref("snap_product") }}),

    versions as (
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
            case when dbt_valid_to is null then true else false end as is_current,
            false as is_unknown
        from snap
    ),

    -- Unknown member: SCD2 valid_from = '1900-01-01', valid_to = NULL so the
    -- fact's point-in-time predicate matches it for any order_date when the
    -- caller coalesces the FK to '-1'.
    unknown_member as (
        select
            '-1' as product_sk,
            cast(-1 as int) as product_bk,
            'Unknown' as product_name,
            'Unknown' as product_number,
            cast(null as boolean) as is_make,
            cast(null as boolean) as is_finished_good,
            'Unknown' as color,
            'Unknown' as product_line,
            'Unknown' as product_class,
            'Unknown' as product_style,
            'Unknown' as size,
            cast(null as decimal(8, 2)) as weight,
            cast(0 as decimal(19, 4)) as standard_cost,
            cast(0 as decimal(19, 4)) as list_price,
            cast(null as int) as days_to_manufacture,
            cast(null as int) as product_subcategory_bk,
            'Unknown' as subcategory_name,
            cast(null as int) as product_category_bk,
            'Unknown' as category_name,
            'Unknown' as product_status,
            cast(null as timestamp) as sell_start_at,
            cast(null as timestamp) as sell_end_at,
            cast(null as timestamp) as discontinued_at,
            cast('1900-01-01' as timestamp) as valid_from,
            cast(null as timestamp) as valid_to,
            true as is_current,
            true as is_unknown
    )

select *
from versions
union all
select *
from unknown_member
