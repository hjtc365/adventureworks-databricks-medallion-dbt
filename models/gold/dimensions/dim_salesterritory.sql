{{ config(materialized="table") }}

with
    snap as (select * from {{ ref("snap_salesterritory") }}),

    versions as (
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
            case when dbt_valid_to is null then true else false end as is_current,
            false as is_unknown
        from snap
    ),

    unknown_member as (
        select
            '-1' as sales_territory_sk,
            cast(-1 as int) as sales_territory_bk,
            'Unknown' as territory_name,
            cast(null as string) as country_region_code,
            cast(null as string) as territory_group,
            cast(null as int) as current_sales_person_bk,
            cast(null as decimal(19, 4)) as sales_ytd,
            cast(null as decimal(19, 4)) as sales_last_year,
            cast(null as decimal(19, 4)) as cost_ytd,
            cast(null as decimal(19, 4)) as cost_last_year,
            cast('1900-01-01' as timestamp) as valid_from,
            cast(null as timestamp) as valid_to,
            true as is_current,
            true as is_unknown
    )

select * from versions
union all
select * from unknown_member
