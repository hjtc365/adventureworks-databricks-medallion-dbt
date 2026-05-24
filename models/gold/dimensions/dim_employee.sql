{{ config(materialized="table") }}

with snap as (select * from {{ ref("snap_employee") }})

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
    case when dbt_valid_to is null then true else false end as is_current_version
from snap
