-- Grain: one row per sales-order line.
--
-- Materialization: incremental merge keyed on sales_order_line_sk.
-- New columns added to the source are automatically appended without
-- requiring a full refresh (on_schema_change="append_new_columns").
-- A 7-day lookback window catches late-arriving or corrected rows on
-- incremental runs.
--
-- SCD2 point-in-time joins: customer, product, employee, and territory
-- dimension FKs are resolved against order_date so each line references
-- the dimension version that was active when the order was placed.
-- dim_customer is Type 1 (current-state only) and uses a simple equi-join.
--
-- FK nullability: all dimension FKs are coalesced to the conformed Unknown
-- member ('-1' for string SKs, -1 for date SKs) so the fact table never
-- carries NULL foreign keys.
--
-- Measures:
-- Additive      — order_qty, unit_price, unit_price_discount, line_total,
-- discount_amount. Safe to SUM across any dimension slice.
-- Semi-additive — allocated_freight, allocated_tax, line_total_with_overhead.
-- Prorated from the order header to the line level; SUM carefully.
{{
    config(
        materialized="incremental",
        incremental_strategy="merge",
        unique_key="sales_order_line_sk",
        on_schema_change="append_new_columns",
    )
}}

with
    line as (
        -- Enriched order lines from the silver intermediate layer.
        -- On incremental runs, only lines whose order_date falls within the
        -- 7-day lookback window are processed to handle late arrivals and
        -- corrections. Full runs process all rows.
        select *
        from {{ ref("int_sales_order_line_enriched") }}

        {% if is_incremental() %}
            where
                order_date >= (select dateadd(day, -7, max(order_date)) from {{ this }})
        {% endif %}

    ),

    -- Dimension CTEs: scoped here so the optimiser can push the point-in-time
    -- predicates down into each join rather than scanning the full tables
    -- multiple times.
    dim_customer as (select * from {{ ref("dim_customer") }}),
    dim_product as (select * from {{ ref("dim_product") }}),
    dim_employee as (select * from {{ ref("dim_employee") }}),
    dim_salesterritory as (select * from {{ ref("dim_salesterritory") }}),
    dim_date as (select * from {{ ref("dim_date") }}),  -- role-played via integer date keys
    dim_special_offer as (select * from {{ ref("dim_special_offer") }}),
    dim_sales_order_junk as (select * from {{ ref("dim_sales_order_junk") }})  -- low-cardinality flag/descriptor combos

select
    -- Surrogate key: hashed from the natural business key of the order line.
    {{ dbt_utils.generate_surrogate_key(["line.sales_order_line_bk"]) }}
    as sales_order_line_sk,

    -- Degenerate dimensions: order identifiers carried directly on the fact row;
    -- no separate dimension table is warranted for these.
    line.sales_order_bk,
    line.sales_order_detail_bk,
    line.sales_order_line_bk,

    -- Date FKs (role-played x3 — order / due / ship): each date is stored as
    -- both a raw date for readability and an integer in yyyyMMdd format for
    -- joining to dim_date. Missing dates default to -1 (the Unknown member)
    -- so fact FKs are never NULL.
    line.order_date,
    coalesce(
        cast(date_format(line.order_date, 'yyyyMMdd') as int), -1
    ) as order_date_sk,
    line.due_date,
    coalesce(cast(date_format(line.due_date, 'yyyyMMdd') as int), -1) as due_date_sk,
    line.ship_date,
    coalesce(cast(date_format(line.ship_date, 'yyyyMMdd') as int), -1) as ship_date_sk,

    -- Point-in-time SCD2 FKs: resolved via order_date in the joins below.
    -- Each FK coalesces to '-1' (the conformed Unknown member) so the fact
    -- table never carries NULL foreign keys.
    coalesce(dc.customer_sk, '-1') as customer_sk,
    coalesce(dp.product_sk, '-1') as product_sk,
    coalesce(de.employee_sk, '-1') as employee_sk,
    coalesce(dt.sales_territory_sk, '-1') as sales_territory_sk,
    coalesce(dso.special_offer_sk, '-1') as special_offer_sk,
    coalesce(dj.sales_order_junk_sk, '-1') as sales_order_junk_sk,

    -- Additive measures: safe to SUM across any dimension slice.
    line.order_qty,
    line.unit_price,
    line.unit_price_discount,
    line.line_total,
    -- discount_amount: reduction from unit_price_discount applied to the committed
    -- unit price. Formula: (unit_price * order_qty) - line_total, which equals
    -- unit_price * order_qty * unit_price_discount. Always >= 0.
    -- Note: unit_price is the negotiated/committed price at order time, not the
    -- product's list_price — so this captures line-level discount only.
    (line.unit_price * line.order_qty) - line.line_total as discount_amount,

    -- Semi-additive (allocated) measures: freight and tax are prorated from
    -- the order header to the line level. Avoid double-counting when aggregating
    -- across lines that belong to the same order.
    line.allocated_freight,
    line.allocated_tax,
    -- line_total_with_overhead: fully-loaded line revenue including freight and tax.
    line.line_total
    + line.allocated_freight
    + line.allocated_tax as line_total_with_overhead,

    line.modified_at as updated_at
from line

-- Point-in-time SCD2 joins
-- Each join matches the dimension row whose effective range (valid_from / valid_to)
-- contains order_date. Open-ended rows have valid_to = NULL, handled by the
-- "or dp.valid_to is null" predicate.
-- dim_customer is Type 1 (current-state only): a simple equi-join on customer_bk
-- is sufficient. The customer's territory at order time is captured separately
-- via the dim_salesterritory point-in-time join.
left join dim_customer dc on dc.customer_bk = line.customer_bk

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

-- Non-SCD2 joins: no temporal predicate needed for these dimensions.
left join dim_special_offer dso on dso.special_offer_bk = line.special_offer_bk

-- Junk dimension: resolved by the full combination of low-cardinality flags
-- and descriptor attributes. All five attributes must match to locate the
-- correct junk row for this order line.
left join
    dim_sales_order_junk dj
    on dj.order_status = line.order_status
    and dj.is_online_order = line.is_online_order
    and dj.revision_number = line.revision_number
    and dj.ship_method_name = line.ship_method_name
    and dj.card_type = line.card_type
