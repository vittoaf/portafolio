-- ====================================================================
-- Silver Layer: Deduplicacion e Idempotencia (BigQuery View)
-- Resuelve reintentos de red y entregas 'at-least-once' de Pub/Sub
-- ====================================================================
WITH ranked_events AS (
  SELECT
    order_id,
    customer_id,
    event_timestamp,
    published_at,
    status,
    total_amount,
    currency,
    items,
    raw_metadata,
    ROW_NUMBER() OVER (
      PARTITION BY order_id 
      ORDER BY event_timestamp DESC, published_at DESC
    ) AS row_num
  FROM
    `${project_id}.${dataset_id}.${table_id}`
)
SELECT
  order_id,
  customer_id,
  event_timestamp,
  published_at,
  status,
  total_amount,
  currency,
  items,
  raw_metadata
FROM
  ranked_events
WHERE
  row_num = 1;
