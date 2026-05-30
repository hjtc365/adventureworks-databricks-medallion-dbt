{% test test_scd2_no_date_overlap(
    model, business_key, valid_from, valid_to, is_unknown_col="is_unknown"
) %}

    -- Returns one row per overlapping version pair (failures).
    -- An overlap exists when two distinct versions of the same business_key have
    -- date ranges that intersect. Open-ended rows (valid_to IS NULL) are treated
    -- as closing at the far-future sentinel '9999-12-31' to allow comparison.
    -- Rows where `is_unknown_col` is true are excluded — the synthetic Unknown
    -- member has a deliberately wide range ('1900-01-01' to NULL) that would
    -- produce false positives against all real versions.
    with
        source_data as (
            select
                {{ business_key }} as business_key,
                {{ valid_from }} as valid_from,
                -- Coalesce open-ended rows so NULL comparisons don't silently miss
                -- overlaps.
                coalesce({{ valid_to }}, cast('9999-12-31' as timestamp)) as valid_to
            from {{ model }}
            -- Exclude the synthetic Unknown member so its open range doesn't
            -- falsely overlap every real version.
            where {{ is_unknown_col }} = false
        ),

        overlaps as (
            select
                a.business_key,
                a.valid_from,
                a.valid_to,
                b.valid_from as overlap_valid_from,
                b.valid_to as overlap_valid_to
            from source_data a
            inner join
                source_data b
                on a.business_key = b.business_key
                -- Exclude the row joining to itself.
                and a.valid_from <> b.valid_from
                -- Overlap condition: [a.valid_from, a.valid_to) intersects
                -- [b.valid_from, b.valid_to)
                and a.valid_from < b.valid_to
                and a.valid_to > b.valid_from
        )

    -- Each row returned is a test failure.
    select *
    from overlaps

{% endtest %}
