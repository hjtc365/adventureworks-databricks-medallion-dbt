-- Incremental merge keyed on the surrogate key of each sales-order line.
-- new_columns added to the source are automatically appended (no full refresh needed).
-- A 7-day lookback window is used to catch late-arriving or updated rows.
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
    line as (
        -- Enriched order lines from the silver intermediate layer.
        -- On incremental runs, only process lines whose order_date falls within
        -- the 7-day lookback window to handle late arrivals and corrections.
        select *
        from {{ ref("int_sales_order_line_enriched") }}

        {% if is_incremental() %}
            where
                order_date >= (select dateadd(day, -7, max(order_date)) from {{ this }})
        {% endif %}

    ),

    -- Dimension CTEs: pull full snapshots into the query scope so the
    -- optimiser can push the point-in-time predicates down into each join.
    dim_customer as (select * from {{ ref("dim_customer") }}),
    dim_product as (select * from {{ ref("dim_product") }}),
    dim_employee as (select * from {{ ref("dim_employee") }}),
    dim_salesterritory as (select * from {{ ref("dim_salesterritory") }}),
    dim_date as (select * from {{ ref("dim_date") }}),           -- role-played via integer date keys
    dim_special_offer as (select * from {{ ref("dim_special_offer") }}),
    dim_sales_order_junk as (select * from {{ ref("dim_sales_order_junk") }})  -- low-cardinality flag/descriptor combos

select
    -- Surrogate key: hash of the natural business key for the order line.
    {{ dbt_utils.generate_surrogate_key(["line.sales_order_line_bk"]) }}
    as sales_order_line_sk,

    -- Degenerate dimensions: business keys carried directly on the fact row
    -- (no separate dimension table required).
    line.sales_order_bk,
    line.sales_order_detail_bk,
    line.sales_order_line_bk,

    -- Date FKs (role-played x3): stored as both a raw date (for readability)
    -- and an integer in yyyyMMdd format (for joining to dim_date).
    line.order_date,
    cast(date_format(line.order_date, 'yyyyMMdd') as int) as order_date_sk,
    line.due_date,
    cast(date_format(line.due_date, 'yyyyMMdd') as int) as due_date_sk,
    line.ship_date,
    cast(date_format(line.ship_date, 'yyyyMMdd') as int) as ship_date_sk,

    -- Point-in-time SCD2 FKs: resolved via the joins below using order_date
    -- so each line always references the dimension row that was active at
    -- the time the order was placed.
    dc.customer_sk,
    dp.product_sk,
    -- Sales person is optional; default to '_unknown' when no rep is assigned.
    coalesce(de.employee_sk, '_unknown') as employee_sk,
    dt.sales_territory_sk,
    dso.special_offer_sk,
    dj.sales_order_junk_sk,

    -- Additive measures: safe to SUM across any dimension slice.
    line.order_qty,
    line.unit_price,
    line.unit_price_discount,
    line.line_total,
    -- discount_amount: difference between the full list price and the actual line total.
    line.line_total - (line.unit_price * line.order_qty) as discount_amount,

    -- Semi-additive (allocated) measures: freight and tax have been prorated
    -- from the order header down to the line level; SUM carefully.
    line.allocated_freight,
    line.allocated_tax,
    -- line_total_with_overhead: fully-loaded line revenue including freight & tax.
    line.line_total
    + line.allocated_freight
    + line.allocated_tax as line_total_with_overhead,

    line.modified_at as updated_at
from line

-- ── Point-in-time SCD2 joins ────────────────────────────────────────────────
-- Each join matches the dimension row whose effective range (valid_from / valid_to)
-- contains the order_date.  open-ended rows have valid_to = NULL, handled by
-- the "or dc.valid_to is null" predicate.

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

-- ── Non-SCD2 joins ───────────────────────────────────────────────────────────
-- Special offers and junk dimensions are matched on business key / attribute
-- values only; no temporal predicate needed.

left join dim_special_offer dso on dso.special_offer_bk = line.special_offer_bk

-- Junk dimension: resolved by the full combination of low-cardinality flags
-- and descriptor attributes captured at order time.
left join
    dim_sales_order_junk dj
    on dj.order_status = line.order_status
    and dj.is_online_order = line.is_online_order
    and dj.revision_number = line.revision_number
    and dj.ship_method_name = line.ship_method_name
    and dj.card_type = line.card_type
