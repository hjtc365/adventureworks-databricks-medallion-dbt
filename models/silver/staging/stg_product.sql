{{ config(materialized="view") }}

with
    src as (select * from {{ source("production", "Product") }}),

    deduplicated as (
        {{
            dbt_utils.deduplicate(
                relation="src", partition_by="productid", order_by="modifieddate desc"
            )
        }}
    )

select
    cast(productid as int) as product_bk,
    name as product_name,
    productnumber as product_number,
    cast(makeflag as boolean) as is_make,
    cast(finishedgoodsflag as boolean) as is_finished_good,
    color as color,
    cast(safetystocklevel as int) as safety_stock_level,
    cast(reorderpoint as int) as reorder_point,
    cast(standardcost as decimal(19, 4)) as standard_cost,
    cast(listprice as decimal(19, 4)) as list_price,
    size as size,
    sizeunitmeasurecode as size_uom_code,
    weightunitmeasurecode as weight_uom_code,
    cast(weight as decimal(8, 2)) as weight,
    cast(daystomanufacture as int) as days_to_manufacture,
    trim(productline) as product_line,
    trim(class) as product_class,
    trim(style) as product_style,
    cast(productsubcategoryid as int) as product_subcategory_bk,
    cast(productmodelid as int) as product_model_bk,
    cast(sellstartdate as timestamp) as sell_start_at,
    cast(sellenddate as timestamp) as sell_end_at,
    cast(discontinueddate as timestamp) as discontinued_at,
    rowguid as row_guid,
    cast(left(modifieddate, 19) as timestamp) as modified_at
from deduplicated
