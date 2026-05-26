{{
    config(
        materialized="incremental",
        incremental_strategy="merge",
        unique_key="sales_order_line_sk",
        on_schema_change="append_new_columns",
    )
}}

-- Grain: one row per sales-order line.
-- Joins to all four SCD2 dimensions are point-in-time using order_date,
-- so each line references the version of customer/product/employee/territory
-- that was current when the order was placed.
with
    {% if is_incremental() %}
        max_date as (select max(order_date) as max_order_date from {{ this }}),
    {% endif %}

    line as (

        select *
        from {{ ref("int_sales_order_line_enriched") }}

        {% if is_incremental() %}
            where order_date >= (select dateadd(day, -7, max_order_date) from max_date)
        {% endif %}

    ),

    dim_customer as (select * from {{ ref("dim_customer") }}),
    dim_product as (select * from {{ ref("dim_product") }}),
    dim_employee as (select * from {{ ref("dim_employee") }}),
    dim_salesterritory as (select * from {{ ref("dim_salesterritory") }}),
    dim_date as (select * from {{ ref("dim_date") }}),
    dim_special_offer as (select * from {{ ref("dim_special_offer") }}),
    dim_sales_order_junk as (select * from {{ ref("dim_sales_order_junk") }})

select
    {{ dbt_utils.generate_surrogate_key(["line.sales_order_line_bk"]) }}
    as sales_order_line_sk,

    -- Degenerate dimensions
    line.sales_order_bk,
    line.sales_order_detail_bk,
    line.sales_order_line_bk,

    -- Date FKs (role-played x3)
    line.order_date,
    cast(date_format(line.order_date, 'yyyyMMdd') as int) as order_date_sk,
    line.due_date,
    cast(date_format(line.due_date, 'yyyyMMdd') as int) as due_date_sk,
    line.ship_date,
    cast(date_format(line.ship_date, 'yyyyMMdd') as int) as ship_date_sk,

    -- Point-in-time SCD2 FKs
    dc.customer_sk,
    dp.product_sk,
    coalesce(de.employee_sk, '_unknown') as employee_sk,
    dt.sales_territory_sk,
    dso.special_offer_sk,
    dj.sales_order_junk_sk,

    -- Additive measures
    line.order_qty,
    line.unit_price,
    line.unit_price_discount,
    line.line_total,
    line.line_total - (line.unit_price * line.order_qty) as discount_amount,

    -- Semi-additive (allocated) measures
    line.allocated_freight,
    line.allocated_tax,
    line.line_total
    + line.allocated_freight
    + line.allocated_tax as line_total_with_overhead,

    line.modified_at as updated_at
from line

left join
    dim_customer dc
    on dc.customer_bk = line.customer_bk
    and line.order_date >= dc.valid_from
    and (line.order_date < dc.valid_to or dc.valid_to is null)

left join
    dim_product dp
    on dp.product_bk = line.product_bk
    and line.order_date >= dp.valid_from
    and (line.order_date < dp.valid_to or dp.valid_to is null)

left join
    dim_employee de
    on de.employee_bk = line.sales_person_bk
    and line.order_date >= de.valid_from
    and (line.order_date < de.valid_to or de.valid_to is null)

left join
    dim_salesterritory dt
    on dt.sales_territory_bk = line.sales_territory_bk
    and line.order_date >= dt.valid_from
    and (line.order_date < dt.valid_to or dt.valid_to is null)

left join dim_special_offer dso on dso.special_offer_bk = line.special_offer_bk

left join
    dim_sales_order_junk dj
    on dj.order_status = line.order_status
    and dj.is_online_order = line.is_online_order
    and dj.revision_number = line.revision_number
    and dj.ship_method_name = line.ship_method_name
    and dj.card_type = line.card_type
