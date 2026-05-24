{{ config(materialized="view") }}

with src as (select * from {{ source("humanresources", "EmployeeDepartmentHistory") }})

select
    cast(businessentityid as int) as employee_bk,
    cast(departmentid as int) as department_bk,
    cast(shiftid as int) as shift_bk,
    cast(startdate as date) as start_date,
    cast(enddate as date) as end_date,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from src
