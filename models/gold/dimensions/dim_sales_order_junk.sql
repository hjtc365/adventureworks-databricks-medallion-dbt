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
    card_type
from combos

union all

-- explicit Unknown row for outer-join misses
select
    {{
        dbt_utils.generate_surrogate_key(
            ["'Unknown'", "false", "0", "'Unknown'", "'No Card'"]
        )
    }} as sales_order_junk_sk,
    'Unknown' as order_status,
    false as is_online_order,
    0 as revision_number,
    'Unknown' as ship_method_name,
    'No Card' as card_type
