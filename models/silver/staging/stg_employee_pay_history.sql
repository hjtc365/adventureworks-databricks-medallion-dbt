{{ config(materialized="view") }}

with
    src as (select * from {{ source("humanresources", "EmployeePayHistory") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src",
                partition_by="businessentityid, ratechangedate",
                order_by="modifieddate desc",
            )
        }}
    )

select
    cast(businessentityid as int) as employee_bk,
    cast(left(ratechangedate, 19) as timestamp) as rate_change_at,
    cast(rate as decimal(19, 4)) as pay_rate,
    cast(payfrequency as int) as pay_frequency,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
