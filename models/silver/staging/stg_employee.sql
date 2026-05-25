{{ config(materialized="view") }}

-- Note: OrganizationLevel is INT (computed in CSV from OrganizationNode.GetLevel()).
-- It is NULL for the root node (CEO).
with
    src as (select * from {{ source("humanresources", "Employee") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src",
                partition_by="businessentityid",
                order_by="modifieddate desc",
            )
        }}
    )

select
    cast(businessentityid as int) as employee_bk,
    nationalidnumber as national_id_number,
    loginid as login_id,
    organizationnode as organization_node,  -- hierarchyid -> string
    cast(organizationlevel as int) as organization_level,
    jobtitle as job_title,
    cast(birthdate as date) as birth_date,
    maritalstatus as marital_status,
    gender as gender,
    cast(hiredate as date) as hire_date,
    cast(salariedflag as boolean) as is_salaried,
    cast(vacationhours as int) as vacation_hours,
    cast(sickleavehours as int) as sick_leave_hours,
    cast(currentflag as boolean) as is_current,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
