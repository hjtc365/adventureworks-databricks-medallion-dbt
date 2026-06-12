{{ config(materialized="table") }}

with
    snap as (select * from {{ ref("snap_employee") }}),

    versions as (
        select
            {{ dbt_utils.generate_surrogate_key(["dbt_scd_id"]) }} as employee_sk,
            employee_bk,
            first_name,
            middle_name,
            last_name,
            full_name,
            login_id,
            job_title,
            organization_node,
            organization_level,
            department_bk,
            birth_date,
            marital_status,
            gender,
            hire_date,
            is_salaried,
            pay_rate,
            pay_frequency,
            is_current,
            dbt_valid_from as valid_from,
            dbt_valid_to as valid_to,
            case
                when dbt_valid_to is null then true else false
            end as is_current_version,
            false as is_unknown
        from snap
    ),

    -- Unknown member: SCD2 valid_from = '1900-01-01', valid_to = NULL so the
    -- fact's point-in-time predicate matches it for any order_date when the
    -- caller coalesces the FK to '-1' (e.g., orders without an assigned rep).
    unknown_member as (
        select
            '-1' as employee_sk,
            cast(-1 as int) as employee_bk,
            cast(null as string) as first_name,
            cast(null as string) as middle_name,
            cast(null as string) as last_name,
            'Unknown' as full_name,
            cast(null as string) as login_id,
            cast(null as string) as job_title,
            cast(null as string) as organization_node,
            cast(null as int) as organization_level,
            cast(null as int) as department_bk,
            cast(null as date) as birth_date,
            cast(null as string) as marital_status,
            cast(null as string) as gender,
            cast(null as date) as hire_date,
            cast(null as boolean) as is_salaried,
            cast(null as decimal(19, 4)) as pay_rate,
            cast(null as int) as pay_frequency,
            cast(null as boolean) as is_current,
            cast('1900-01-01' as timestamp) as valid_from,
            cast(null as timestamp) as valid_to,
            true as is_current_version,
            true as is_unknown
    )

select *
from versions
union all
select *
from unknown_member
