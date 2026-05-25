{{ config(materialized="view") }}

-- Returns each sales person's CURRENT territory assignment plus the
-- territory's KPIs. Used as the basis for dim_salesterritory.
with
    t as (select * from {{ ref("stg_sales_territory") }}),
    h as (select * from {{ ref("stg_sales_territory_history") }}),
    current_assignments as (
        select
            sales_territory_bk,
            sales_person_bk,
            row_number() over (
                partition by sales_territory_bk order by start_at desc
            ) as _rn
        from h
        where end_at is null
    )

select
    t.sales_territory_bk,
    t.territory_name,
    t.country_region_code,
    t.territory_group,
    t.sales_ytd,
    t.sales_last_year,
    t.cost_ytd,
    t.cost_last_year,
    ca.sales_person_bk as current_sales_person_bk,
    t.modified_at
from t
left join
    current_assignments ca
    on ca.sales_territory_bk = t.sales_territory_bk
    and ca._rn = 1
