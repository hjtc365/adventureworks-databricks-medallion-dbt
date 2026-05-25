{{ config(materialized="view") }}

-- Sales.Customer is small (~20k rows) and never updated in place.
-- A view is sufficient; downstream snapshot handles SCD2.
with
    src as (select * from {{ source("sales", "Customer") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src",
                partition_by="customerid",
                order_by="modifieddate desc",
            )
        }}
    )
select
    cast(customerid as int) as customer_bk,
    cast(personid as int) as person_bk,
    cast(storeid as int) as store_bk,
    cast(territoryid as int) as sales_territory_bk,
    accountnumber as account_number,
    case
        when personid is not null and storeid is null
        then 'Individual'
        when storeid is not null and personid is null
        then 'Store'
        when personid is not null and storeid is not null
        then 'StoreContact'
        else 'Unknown'
    end as customer_type,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
