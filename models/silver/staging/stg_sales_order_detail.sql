{{
    config(
        materialized="incremental",
        incremental_strategy="merge",
        unique_key="sales_order_line_bk",
        on_schema_change="append_new_columns",
    )
}}

with
    src as (

        select *
        from {{ source("sales", "SalesOrderDetail") }}

        {% if is_incremental() %}
            where
                modifieddate
                >= (select dateadd(day, -1, max(modified_at)) from {{ this }})
        {% endif %}

    )

select
    -- Composite business key: header + detail
    concat(
        cast(salesorderid as string), '-', cast(salesorderdetailid as string)
    ) as sales_order_line_bk,
    cast(salesorderid as int) as sales_order_bk,
    cast(salesorderdetailid as int) as sales_order_detail_bk,
    cast(productid as int) as product_bk,
    cast(specialofferid as int) as special_offer_bk,
    carriertrackingnumber as carrier_tracking_number,
    cast(orderqty as int) as order_qty,
    cast(unitprice as decimal(19, 4)) as unit_price,
    cast(unitpricediscount as decimal(19, 4)) as unit_price_discount,
    cast(linetotal as decimal(38, 6)) as line_total,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from src
