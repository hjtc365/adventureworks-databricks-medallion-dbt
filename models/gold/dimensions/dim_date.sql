{{ config(materialized="table") }}

-- Conformed date dimension (SCD0 — never changes).
-- Spans 2010-01-01 through 2030-12-31, covering AdventureWorks history
-- with 5 years of forward dates for budgeting use cases.
with
    date_spine as (

        {{
            dbt_utils.date_spine(
                datepart="day",
                start_date="cast('2010-01-01' as date)",
                end_date="cast('2031-01-01' as date)",
            )
        }}

    )

select
    -- Surrogate key as YYYYMMDD integer (industry standard for date dims)
    cast(date_format(date_day, 'yyyyMMdd') as int) as date_sk,
    date_day as full_date,

    year(date_day) as year_number,
    quarter(date_day) as quarter_number,
    concat(
        'Q', cast(quarter(date_day) as string), ' ', cast(year(date_day) as string)
    ) as quarter_name,
    month(date_day) as month_number,
    date_format(date_day, 'MMMM') as month_name,
    date_format(date_day, 'MMM') as month_short_name,
    weekofyear(date_day) as week_of_year,
    dayofmonth(date_day) as day_of_month,
    dayofweek(date_day) as day_of_week,
    date_format(date_day, 'EEEE') as day_name,
    date_format(date_day, 'EEE') as day_short_name,

    case when dayofweek(date_day) in (1, 7) then true else false end as is_weekend,

    case
        when month(date_day) in (1, 2, 3)
        then 'Q1'
        when month(date_day) in (4, 5, 6)
        then 'Q2'
        when month(date_day) in (7, 8, 9)
        then 'Q3'
        else 'Q4'
    end as quarter_label,

    -- AdventureWorks fiscal year starts July 1
    case
        when month(date_day) >= 7 then year(date_day) + 1 else year(date_day)
    end as fiscal_year,

    last_day(date_day) as month_end_date,
    date_trunc('month', date_day) as month_start_date,
    date_trunc('quarter', date_day) as quarter_start_date,
    date_trunc('year', date_day) as year_start_date
from date_spine
