select
    order_id,
    order_amount
from {{ ref('stg_orders') }}
where order_amount < 0
