{{ config(materialized="view") }}

-- Enriches each employee with personal details, current pay rate, and current
-- department for use in dim_employee.
--
-- Join path:
--   stg_employee -> stg_person (via person_bk = employee_bk)
--               -> stg_employee_pay_history  (via employee_bk)
--               -> stg_employee_dept_history (via employee_bk)
--
-- Current pay rate: one row per employee via ROW_NUMBER().
--   Priority — rate_change_at DESC (most recent rate wins)
--
-- Current department: one row per employee via ROW_NUMBER().
--   Filter  — end_date IS NULL (open-ended assignments only)
--   Priority — start_date DESC (most recent open assignment wins)
--
-- Note: LEFT JOINs are used throughout because:
--   - stg_person: contractors or test employees may lack a Person record
--   - stg_employee_pay_history: new employees may not yet have a pay record
--   - stg_employee_dept_history: employees may not yet be assigned a department
--   Missing records produce NULLs in the respective fields rather than
--   dropping the employee row.
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
    e.is_active_employee,
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
