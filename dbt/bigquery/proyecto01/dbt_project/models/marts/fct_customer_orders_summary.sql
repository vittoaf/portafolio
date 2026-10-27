{{ config(
    materialized='table',
    schema='gold_layer'
) }}

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customer_aggregations as (
    select
        c.customer_id,
        c.full_name,
        c.email,
        count(o.order_id) as total_orders,
        count(case when o.order_status = 'COMPLETED' then 1 end) as completed_orders,
        coalesce(sum(case when o.order_status = 'COMPLETED' then o.order_amount else 0 end), 0) as total_spent,
        coalesce(round(avg(case when o.order_status = 'COMPLETED' then o.order_amount end), 2), 0) as avg_order_value,
        max(o.order_date) as last_order_date
    from customers c
    left join orders o
        on c.customer_id = o.customer_id
    group by 1, 2, 3
)

select
    *,
    current_timestamp() as processed_at
from customer_aggregations
