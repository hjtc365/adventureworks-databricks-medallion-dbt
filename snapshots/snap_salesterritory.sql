{% snapshot snap_salesterritory %}

    {{
        config(
            unique_key="sales_territory_bk",
            strategy="check",
            check_cols=[
                "territory_name",
                "country_region_code",
                "territory_group",
                "current_sales_person_bk",
            ],
            invalidate_hard_deletes=true,
        )
    }}

    select
        sales_territory_bk,
        territory_name,
        country_region_code,
        territory_group,
        current_sales_person_bk,
        sales_ytd,
        sales_last_year,
        cost_ytd,
        cost_last_year
    from {{ ref("int_territory_current") }}

{% endsnapshot %}
