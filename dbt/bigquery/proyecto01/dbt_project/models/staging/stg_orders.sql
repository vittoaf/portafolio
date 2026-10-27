{{ config(
    materialized='table',
    schema='silver_layer'
) }}

select
    cast(order_id as int64) as order_id,
    cast(customer_id as int64) as customer_id,
    cast(order_date as timestamp) as order_date,
    cast(order_amount as numeric) as order_amount,
    upper(trim(order_status)) as order_status,
    current_timestamp() as processed_at
from {{ source('bronze', 'raw_orders') }}
