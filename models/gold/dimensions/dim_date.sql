{{ config(materialized="table") }}

{# ─── Fiscal calendar config ────────────────────────────────────────────────
   Centralised here so a fiscal-year change never requires touching logic below.
   AdventureWorks fiscal year starts July 1.
#}
{% set fiscal_year_start_month = 7 %}

-- Conformed date dimension (SCD0 — never changes).
-- Range is derived dynamically from stg_sales_order_header
with
    date_spine as (
        select
            explode(
                sequence(
                    -- start: first day of the earliest calendar year across all date
                    -- columns
                    (
                        select
                            to_date(
                                date_trunc(
                                    'year',
                                    min(
                                        least(
                                            order_date,
                                            coalesce(ship_date, order_date),
                                            coalesce(due_date, order_date)
                                        )
                                    )
                                )
                            )
                        from {{ ref("stg_sales_order_header") }}
                    ),
                    -- end: last day of the latest calendar year (sequence end is
                    -- INCLUSIVE)
                    (
                        select
                            to_date(
                                dateadd(
                                    day,
                                    -1,
                                    dateadd(
                                        year,
                                        1,
                                        date_trunc(
                                            'year',
                                            max(
                                                greatest(
                                                    order_date,
                                                    coalesce(ship_date, order_date),
                                                    coalesce(due_date, order_date)
                                                )
                                            )
                                        )
                                    )
                                )
                            )
                        from {{ ref("stg_sales_order_header") }}
                    ),
                    interval 1 day
                )
            ) as date_day
    ),

    -- Pre-compute fiscal attributes once so the month threshold and quarter
    -- logic are defined in a single place and reused in the final SELECT.
    spine_with_fiscal as (
        select
            date_day,
            case
                when month(date_day) >= {{ fiscal_year_start_month }}
                then year(date_day) + 1
                else year(date_day)
            end as fiscal_year,
            case
                when month(date_day) in (7, 8, 9)
                then 1
                when month(date_day) in (10, 11, 12)
                then 2
                when month(date_day) in (1, 2, 3)
                then 3
                when month(date_day) in (4, 5, 6)
                then 4
                else null  -- unreachable; all 12 months are covered above
            end as fiscal_quarter
        from date_spine
    )

select
    -- ── Surrogate key
    -- ───────────────────────────────────────────────────────
    cast(date_format(date_day, 'yyyyMMdd') as int) as date_sk,
    date_day as full_date,

    -- ── Calendar year attributes
    -- ────────────────────────────────────────────
    year(date_day) as year_number,
    quarter(date_day) as quarter_number,
    concat('Q', cast(quarter(date_day) as string)) as quarter_label,
    concat(
        'Q', cast(quarter(date_day) as string), ' ', cast(year(date_day) as string)
    ) as quarter_name,
    month(date_day) as month_number,
    date_format(date_day, 'MMMM') as month_name,
    date_format(date_day, 'MMM') as month_short_name,
    weekofyear(date_day) as week_of_year,
    dayofyear(date_day) as day_of_year,
    dayofmonth(date_day) as day_of_month,
    -- Databricks/Spark: 1 = Sunday, 2 = Monday, …, 7 = Saturday
    dayofweek(date_day) as day_of_week,
    date_format(date_day, 'EEEE') as day_name,
    date_format(date_day, 'EEE') as day_short_name,
    dayofweek(date_day) in (1, 7) as is_weekend,

    -- ── Fiscal year attributes
    -- ──────────────────────────────────────────────
    fiscal_year,
    fiscal_quarter,
    concat('FQ', cast(fiscal_quarter as string)) as fiscal_quarter_label,
    concat(
        'FY', cast(fiscal_year as string), '-FQ', cast(fiscal_quarter as string)
    ) as fiscal_year_quarter,

    -- ── Period boundaries
    -- ───────────────────────────────────────────────────
    -- NOTE: date_trunc returns TIMESTAMP in Databricks/Spark SQL even when the
    -- input is a DATE. to_date() is used here as a cleaner alternative to
    -- cast(date_trunc(...) as date) to avoid the same rendering issues.
    to_date(date_trunc('month', date_day)) as month_start_date,
    last_day(date_day) as month_end_date,
    to_date(date_trunc('quarter', date_day)) as quarter_start_date,
    last_day(
        dateadd(month, 2, to_date(date_trunc('quarter', date_day)))
    ) as quarter_end_date,
    to_date(date_trunc('year', date_day)) as year_start_date,
    to_date(
        dateadd(day, -1, dateadd(year, 1, date_trunc('year', date_day)))
    ) as year_end_date,

    -- ── Convenience flags
    -- ───────────────────────────────────────────────────
    date_day = last_day(date_day) as is_last_day_of_month,
    month(date_day) = 12 and dayofmonth(date_day) = 31 as is_last_day_of_year

from spine_with_fiscal
