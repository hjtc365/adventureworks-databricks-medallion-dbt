{{ config(materialized="table") }}

with snap as (select * from {{ ref("snap_salesterritory") }})

select
    {{ dbt_utils.generate_surrogate_key(["dbt_scd_id"]) }} as sales_territory_sk,
    sales_territory_bk,
    territory_name,
    country_region_code,
    territory_group,
    current_sales_person_bk,
    sales_ytd,
    sales_last_year,
    cost_ytd,
    cost_last_year,
    dbt_valid_from as valid_from,
    dbt_valid_to as valid_to,
    case when dbt_valid_to is null then true else false end as is_current
from snap
