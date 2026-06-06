-- Singular test: asserts that line_total_with_overhead is never less than
-- line_total on any fact row. Overhead (freight + tax) is always >= 0,
-- so the sum must be >= the base line_total.
--
-- Returns rows that violate the invariant; zero rows = test passes.

select
    sales_order_line_sk,
    sales_order_line_bk,
    line_total,
    line_total_with_overhead,
    line_total_with_overhead - line_total as overhead_delta
from {{ ref('fct_sales_detail') }}
where line_total_with_overhead < line_total
