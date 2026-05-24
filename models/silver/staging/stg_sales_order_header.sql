{{
    config(
        materialized="incremental",
        incremental_strategy="merge",
        unique_key="sales_order_bk",
        on_schema_change="append_new_columns",
    )
}}

with
    src as (

        select *
        from {{ source("sales", "SalesOrderHeader") }}

        {% if is_incremental() %}
            -- Pull only rows changed since the last run + 1-day grace
            where
                modifieddate
                >= (select dateadd(day, -1, max(modified_at)) from {{ this }})
        {% endif %}

    ),

    deduped as (

        {{
            deduplicate(
                relation="src",
                partition_by="SalesOrderID",
                order_by="ModifiedDate desc",
            )
        }}

    )

select
    cast(salesorderid as int) as sales_order_bk,
    cast(revisionnumber as int) as revision_number,
    cast(orderdate as timestamp) as order_date,
    cast(duedate as timestamp) as due_date,
    cast(shipdate as timestamp) as ship_date,
    cast(status as int) as order_status_code,
    case
        cast(status as int)
        when 1
        then 'In process'
        when 2
        then 'Approved'
        when 3
        then 'Backordered'
        when 4
        then 'Rejected'
        when 5
        then 'Shipped'
        when 6
        then 'Cancelled'
        else 'Unknown'
    end as order_status,
    cast(onlineorderflag as boolean) as is_online_order,
    salesordernumber as sales_order_number,
    purchaseordernumber as purchase_order_number,
    accountnumber as account_number,
    cast(customerid as int) as customer_bk,
    cast(salespersonid as int) as sales_person_bk,
    cast(territoryid as int) as sales_territory_bk,
    cast(billtoaddressid as int) as bill_to_address_bk,
    cast(shiptoaddressid as int) as ship_to_address_bk,
    cast(shipmethodid as int) as ship_method_bk,
    cast(creditcardid as int) as credit_card_bk,
    creditcardapprovalcode as credit_card_approval_code,
    cast(currencyrateid as int) as currency_rate_bk,
    cast(subtotal as decimal(19, 4)) as sub_total,
    cast(taxamt as decimal(19, 4)) as tax_amount,
    cast(freight as decimal(19, 4)) as freight,
    cast(totaldue as decimal(19, 4)) as total_due,
    comment as comment,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduped
