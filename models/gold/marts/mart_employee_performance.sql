{{ config(materialized="table") }}

-- Sales-person performance vs. quota, with attainment %.
-- Uses the most recent (current) version of dim_employee for display
-- attributes, but resolves ALL historical fact rows via the full dim
-- so that gross_revenue reflects the rep's lifetime sales.
with
    f as (select * from {{ ref("fct_sales_detail") }}),
    dt as (select * from {{ ref("dim_date") }}),

    -- Full (unfiltered) dim: maps every historical SK back to a BK.
    all_emp as (
        select employee_sk, employee_bk
        from {{ ref("dim_employee") }}
    ),

    -- Current version only: supplies today's job title and name.
    de as (
        select *
        from {{ ref("dim_employee") }}
        where is_current_version = true
    ),

    sp as (select * from {{ ref("stg_sales_person") }}),
    dst as (select * from {{ ref("dim_salesterritory") }} where is_current = true)

select
    dt.fiscal_year,
    dt.year_number,
    dt.quarter_number,
    de.employee_bk,
    de.full_name as sales_person_name,
    de.job_title,
    dst.territory_name,
    dst.country_region_code,

    sp.sales_quota,

    count(distinct f.sales_order_bk) as order_count,
    sum(f.line_total) as gross_revenue,
    sum(f.line_total_with_overhead) as net_revenue,
    sum(f.discount_amount) as discount_given,

    case
        when sp.sales_quota > 0 then sum(f.line_total) / sp.sales_quota
    end as quota_attainment_ratio,

    case
        when sp.sales_quota is null
        then 'No Quota Set'
        when sum(f.line_total) >= sp.sales_quota
        then 'Met'
        when sum(f.line_total) >= sp.sales_quota * 0.8
        then 'Near'
        else 'Below'
    end as quota_status
from f
-- Step 1: resolve every historical SK in the fact to a business key.
inner join all_emp ae on ae.employee_sk = f.employee_sk
-- Step 2: join the BK to the current dim row for display attributes.
inner join de on de.employee_bk = ae.employee_bk
left join sp on sp.sales_person_bk = de.employee_bk
left join dst on dst.sales_territory_sk = f.sales_territory_sk
left join dt on dt.date_sk = f.order_date_sk
group by
    dt.fiscal_year,
    dt.year_number,
    dt.quarter_number,
    de.employee_bk,
    de.full_name,
    de.job_title,
    dst.territory_name,
    dst.country_region_code,
    sp.sales_quota
