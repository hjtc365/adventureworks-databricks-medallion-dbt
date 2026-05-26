{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}

    {%- if target.name == "prod" -%}
        {{ custom_schema_name | default(default_schema) | trim }}

    {%- elif target.name == "ci" -%}
        {{ "pr_" ~ env_var("PR_NUMBER", "0") ~ "_" ~ (custom_schema_name | default(default_schema) | trim) }}

    {%- else -%}
        {{ env_var("DBT_USER") ~ "_" ~ (custom_schema_name | default(default_schema) | trim) }}

    {%- endif -%}
{%- endmacro %}
