{% snapshot snap_product %}

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
