{% snapshot snap_product %}

    -- Type-2 slowly changing dimension (SCD2) snapshot of product records.
    -- Source: int_product_enriched (product + subcategory + category).
    --
    -- Strategy: check
    -- Monitored cols — product_name, list_price, standard_cost,
    -- product_subcategory_bk, product_category_bk, subcategory_name,
    -- category_name, product_status, color, size.
    -- A new row is inserted and the previous row is closed whenever any
    -- monitored column changes. Columns not in check_cols (e.g. product_number,
    -- weight, days_to_manufacture, sell_start_at) are carried forward silently
    -- without triggering a new version.
    --
    -- unique_key: product_bk
    -- Identifies the product across snapshot versions. dbt uses this to
    -- match incoming rows to existing open records before diffing.
    --
    -- invalidate_hard_deletes: true
    -- If a product disappears from int_product_enriched (e.g. removed from
    -- the source system), the open snapshot row is closed by setting
    -- dbt_valid_to to the current timestamp rather than being left open
    -- indefinitely.
    --
    -- Note: subcategory_name, category_name, and the _bk hierarchy columns
    -- are resolved in int_product_enriched (not raw staging) so that the
    -- snapshot captures business-meaningful label changes rather than raw
    -- FK changes.
    {{
        config(
            unique_key="product_bk",
            strategy="check",
            check_cols=[
                "product_name",
                "list_price",
                "standard_cost",
                "product_subcategory_bk",
                "product_category_bk",
                "subcategory_name",
                "category_name",
                "product_status",
                "color",
                "size",
            ],
            invalidate_hard_deletes=true,
        )
    }}

    select
        product_bk,
        product_name,
        product_number,
        is_make,
        is_finished_good,
        color,
        product_line,
        product_class,
        product_style,
        size,
        weight,
        standard_cost,
        list_price,
        days_to_manufacture,
        product_subcategory_bk,
        subcategory_name,
        product_category_bk,
        category_name,
        product_status,
        sell_start_at,
        sell_end_at,
        discontinued_at
    from {{ ref("int_product_enriched") }}

{% endsnapshot %}
