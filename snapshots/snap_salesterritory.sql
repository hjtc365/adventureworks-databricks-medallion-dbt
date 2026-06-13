{% snapshot snap_salesterritory %}

    -- Type-2 slowly changing dimension (SCD2) snapshot of sales territory records.
    -- Source: int_territory_current (territory + current salesperson assignment).
    --
    -- Strategy: check
    -- Monitored cols — territory_name, country_region_code, territory_group,
    -- current_sales_person_bk.
    -- A new row is inserted and the previous row is closed whenever any
    -- monitored column changes. Columns not in check_cols (e.g. sales_ytd,
    -- sales_last_year, cost_ytd, cost_last_year) are carried forward silently
    -- without triggering a new version.
    --
    -- unique_key: sales_territory_bk
    -- Identifies the territory across snapshot versions. dbt uses this to
    -- match incoming rows to existing open records before diffing.
    --
    -- invalidate_hard_deletes: true
    -- If a territory disappears from int_territory_current (e.g. removed from
    -- the source system), the open snapshot row is closed by setting
    -- dbt_valid_to to the current timestamp rather than being left open
    -- indefinitely.
    --
    -- Note: current_sales_person_bk is resolved in int_territory_current
    -- (not raw staging) so that the snapshot captures the active salesperson
    -- assignment as a business-meaningful change rather than a raw FK change.
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
