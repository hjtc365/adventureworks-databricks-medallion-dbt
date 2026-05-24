{% snapshot snap_customer %}

    {{
        config(
            target_schema="gold",
            unique_key="customer_bk",
            strategy="check",
            check_cols=["sales_territory_bk", "customer_type", "account_number"],
            invalidate_hard_deletes=true,
        )
    }}

    select
        customer_bk,
        person_bk,
        store_bk,
        sales_territory_bk,
        account_number,
        customer_type
    from {{ ref("stg_customer") }}

{% endsnapshot %}
