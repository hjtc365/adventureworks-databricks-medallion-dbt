{{ config(materialized="view") }}

-- Joins Employee → Person → current pay rate for use in dim_employee.
with
    e as (select * from {{ ref("stg_employee") }}),
    p as (select * from {{ ref("stg_person") }}),
    pay_current as (
        select
            employee_bk,
            pay_rate,
            pay_frequency,
            row_number() over (
                partition by employee_bk order by rate_change_at desc
            ) as _rn
        from {{ ref("stg_employee_pay_history") }}
    ),
    dept_current as (
        select
            employee_bk,
            department_bk,
            row_number() over (partition by employee_bk order by start_date desc) as _rn
        from {{ ref("stg_employee_dept_history") }}
        where end_date is null
    )

select
    e.employee_bk,
    p.first_name,
    p.middle_name,
    p.last_name,
    p.full_name,
    e.login_id,
    e.national_id_number,
    e.job_title,
    e.organization_node,
    e.organization_level,
    e.birth_date,
    e.marital_status,
    e.gender,
    e.hire_date,
    e.is_salaried,
    e.is_current,
    e.vacation_hours,
    e.sick_leave_hours,
    pay.pay_rate,
    pay.pay_frequency,
    dept.department_bk,
    e.modified_at
from e
left join p on p.person_bk = e.employee_bk
left join pay_current pay on pay.employee_bk = e.employee_bk and pay._rn = 1
left join dept_current dept on dept.employee_bk = e.employee_bk and dept._rn = 1
