{{ config(materialized="view") }}

-- Enriches each sales territory with its current assigned sales person
-- for use as the source of dim_sales_territory.
--
-- Join path:
--   stg_sales_territory -> stg_sales_territory_history (via sales_territory_bk)
--
-- Current assignment: one row per territory via ROW_NUMBER().
--   Filter   — end_at IS NULL (open-ended assignments only)
--   Priority — start_at DESC (most recent open assignment wins on tie)
--
-- Note: LEFT JOIN to current_assignments because not all territories have
-- an active sales person assigned (e.g. newly created or retired territories).
-- Such territories are retained with current_sales_person_bk = NULL rather
-- than being dropped from the dimension.
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
