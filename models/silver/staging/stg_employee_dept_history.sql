{{ config(materialized="view") }}

with
    src as (select * from {{ source("humanresources", "EmployeeDepartmentHistory") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src",
                partition_by="businessentityid, departmentid, shiftid, startdate",
                order_by="modifieddate desc",
            )
        }}
    )

select
    cast(businessentityid as int) as employee_bk,
    cast(departmentid as int) as department_bk,
    cast(shiftid as int) as shift_bk,
    cast(startdate as date) as start_date,
    cast(enddate as date) as end_date,  -- null = currently active in this dept/shift
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
