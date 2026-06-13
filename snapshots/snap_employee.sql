{% snapshot snap_employee %}

    -- Type-2 slowly changing dimension (SCD2) snapshot of employee records.
    -- Source: int_employee_details (employee + person + current pay + current
    -- department).
    --
    -- Strategy: check
    -- Monitored cols — job_title, department_bk, organization_node,
    -- organization_level, pay_rate, pay_frequency,
    -- is_salaried, is_current, marital_status
    -- A new row is inserted and the previous row is closed whenever any
    -- monitored column changes. Columns not in check_cols (e.g. first_name,
    -- gender, birth_date) are carried forward silently without triggering
    -- a new version.
    --
    -- unique_key: employee_bk
    -- Identifies the employee across snapshot versions. dbt uses this to
    -- match incoming rows to existing open records before diffing.
    --
    -- invalidate_hard_deletes: true
    -- If an employee disappears from int_employee_details (e.g. terminated
    -- and removed from the source), the open snapshot row is closed by
    -- setting dbt_valid_to to the current timestamp rather than being left
    -- open indefinitely.
    --
    -- Note: pay_rate and department_bk are resolved in int_employee_details
    -- (not raw staging) so that the snapshot captures business-meaningful
    -- changes rather than raw FK changes.
    {{
        config(
            unique_key="employee_bk",
            strategy="check",
            check_cols=[
                "job_title",
                "department_bk",
                "organization_node",
                "organization_level",
                "pay_rate",
                "pay_frequency",
                "is_salaried",
                "is_current",
                "marital_status",
            ],
            invalidate_hard_deletes=true,
        )
    }}

    select
        employee_bk,
        first_name,
        middle_name,
        last_name,
        full_name,
        login_id,
        national_id_number,
        job_title,
        organization_node,
        organization_level,
        department_bk,
        birth_date,
        marital_status,
        gender,
        hire_date,
        is_salaried,
        is_current,
        pay_rate,
        pay_frequency
    from {{ ref("int_employee_details") }}

{% endsnapshot %}
