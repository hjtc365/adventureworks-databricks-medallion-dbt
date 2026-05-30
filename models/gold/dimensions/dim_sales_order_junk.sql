{{ config(materialized="table") }}

-- Junk dimension — Kimball pattern for collapsing multiple low-cardinality
-- flags into a single surrogate key. Holds the 5 attributes:
-- order_status, is_online_order, revision_number, ship_method_name, card_type
with combos as (select * from {{ ref("int_sales_order_flag_combinations") }})

select
    {{
        dbt_utils.generate_surrogate_key(
            [
                "order_status",
                "is_online_order",
                "revision_number",
                "ship_method_name",
                "card_type",
            ]
        )
    }} as sales_order_junk_sk,
    order_status,
    is_online_order,
    revision_number,
    ship_method_name,
    card_type,
    false as is_unknown
from combos

union all

-- Conformed Unknown member (sk = '-1') for outer-join misses or unmatched
-- combinations. Keeps the convention used across all dimensions.
select
    '-1' as sales_order_junk_sk,
    'Unknown' as order_status,
    cast(null as boolean) as is_online_order,
    cast(null as int) as revision_number,
    'Unknown' as ship_method_name,
    'Unknown' as card_type,
    true as is_unknown
