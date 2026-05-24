{# 
  Returns SQL that deduplicates `relation` by `partition_by`,
  keeping the row with the maximum value of `order_by` (typically
  ModifiedDate). Used in staging models to harden against
  Bronze duplicates introduced by re-imports.

  Args:
    relation     : a {{ ref('...') }} or {{ source('...') }} expression
    partition_by : column or comma-separated columns forming the natural key
    order_by     : ORDER BY clause (column + direction) for tie-breaking

  Example:
    {{ deduplicate(
         relation=source('sales', 'SalesOrderHeader'),
         partition_by='SalesOrderID',
         order_by='ModifiedDate desc'
    ) }}
#}
{% macro deduplicate(relation, partition_by, order_by) %}

    with
        _dedup_numbered as (
            select
                *,
                row_number() over (
                    partition by {{ partition_by }} order by {{ order_by }}
                ) as _dedup_rn
            from {{ relation }}
        )
    select * except (_dedup_rn)
    from _dedup_numbered
    where _dedup_rn = 1

{% endmacro %}
