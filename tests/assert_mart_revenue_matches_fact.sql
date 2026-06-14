-- Singular test: asserts that mart_sales_summary and fct_sales_detail
-- agree on total gross_revenue (within a rounding tolerance of 1 cent).
-- A discrepancy would indicate the mart's aggregation logic has drifted
-- from the fact, or that a GROUP BY column was silently dropped.
--
-- Returns one row if the totals diverge; zero rows = test passes.

with fact_total as (
    select sum(line_total) as total
    from {{ ref('fct_sales_detail') }}
),

mart_total as (
    select sum(net_revenue) as total
    from {{ ref('mart_sales_summary') }}
)

select
    fact_total.total  as fact_net_revenue,
    mart_total.total  as mart_net_revenue,
    abs(fact_total.total - mart_total.total) as delta
from fact_total
cross join mart_total
where abs(fact_total.total - mart_total.total) > 0.01
