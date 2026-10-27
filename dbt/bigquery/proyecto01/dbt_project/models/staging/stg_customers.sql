{{ config(
    materialized='table',
    schema='silver_layer'
) }}

with source_data as (
    select
        cast(id as int64) as customer_id,
        trim(full_name) as full_name,
        lower(trim(email)) as email,
        cast(created_at as timestamp) as created_at
    from {{ source('bronze', 'raw_customers') }}
),

deduplicated as (
    select
        *,
        row_number() over (partition by customer_id order by created_at desc) as rn
    from source_data
)

select
    customer_id,
    full_name,
    email,
    created_at,
    current_timestamp() as processed_at
from deduplicated
where rn = 1
