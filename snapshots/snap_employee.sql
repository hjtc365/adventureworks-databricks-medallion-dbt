{% snapshot snap_employee %}

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
