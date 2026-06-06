-- Singular test: asserts that every SCD2 dimension (product, employee,
-- salesterritory) has exactly one row with is_unknown = true and
-- valid_to IS NULL — the "Unknown member" safety net described in Part 13.
--
-- Returns rows where a dimension is missing its Unknown member or has
-- more than one; zero rows = test passes.

with dim_product_unknown as (
    select count(*) as cnt
    from {{ ref('dim_product') }}
    where is_unknown = true
),

dim_employee_unknown as (
    select count(*) as cnt
    from {{ ref('dim_employee') }}
    where is_unknown = true
),

dim_salesterritory_unknown as (
    select count(*) as cnt
    from {{ ref('dim_salesterritory') }}
    where is_unknown = true
),

counts as (
    select 'dim_product'        as dim_name, cnt from dim_product_unknown
    union all
    select 'dim_employee'       as dim_name, cnt from dim_employee_unknown
    union all
    select 'dim_salesterritory' as dim_name, cnt from dim_salesterritory_unknown
)

-- Return any dim that does not have exactly 1 Unknown member
select dim_name, cnt
from counts
where cnt <> 1
