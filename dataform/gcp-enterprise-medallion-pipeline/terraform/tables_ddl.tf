# ------------------------------------------------------------------------------
# SILVER: stg_customers (Truncate & Insert)
# ------------------------------------------------------------------------------
resource "google_bigquery_table" "stg_customers" {
  dataset_id          = google_bigquery_dataset.silver.dataset_id
  table_id            = "stg_customers"
  deletion_protection = false

  description = "Dimension de clientes depurada, saneada y deduplicada. Grano: un registro por customer_id."

  schema = jsonencode([
    { name = "customer_id", type = "STRING", mode = "REQUIRED", description = "Identificador maestro del cliente (PK)." },
    { name = "first_name", type = "STRING", mode = "NULLABLE", description = "Nombre propio con formato InitCap." },
    { name = "last_name", type = "STRING", mode = "NULLABLE", description = "Apellido con formato InitCap." },
    { name = "full_name", type = "STRING", mode = "NULLABLE", description = "Nombre y apellido concatenados para inferencia LLM." },
    { name = "email", type = "STRING", mode = "REQUIRED", description = "Email saneado en minusculas." },
    { name = "phone", type = "STRING", mode = "NULLABLE", description = "Numero de telefono en formato internacional." },
    { name = "country", type = "STRING", mode = "REQUIRED", description = "Codigo de pais ISO-3166 (ej. PE, US, BR)." },
    { name = "registration_date", type = "TIMESTAMP", mode = "NULLABLE", description = "Fecha original de alta." },
    { name = "processed_at", type = "TIMESTAMP", mode = "REQUIRED", description = "Timestamp UTC de la ultima ejecucion." }
  ])

  table_constraints {
    primary_key {
      columns = ["customer_id"]
    }
  }
}

# ------------------------------------------------------------------------------
# SILVER: stg_products (Truncate & Insert)
# ------------------------------------------------------------------------------
resource "google_bigquery_table" "stg_products" {
  dataset_id          = google_bigquery_dataset.silver.dataset_id
  table_id            = "stg_products"
  deletion_protection = false

  description = "Catalogo maestro de productos saneado, margen unitario y categorias estandarizadas. Grano: un registro por product_id."

  schema = jsonencode([
    { name = "product_id", type = "STRING", mode = "REQUIRED", description = "Identificador unico de producto (PK)." },
    { name = "product_name", type = "STRING", mode = "REQUIRED", description = "Nombre comercial del producto." },
    { name = "category", type = "STRING", mode = "REQUIRED", description = "Categoria analitica en mayusculas." },
    { name = "unit_cost", type = "NUMERIC", mode = "REQUIRED", description = "Costo base unitario de adquisicion." },
    { name = "unit_price", type = "NUMERIC", mode = "REQUIRED", description = "Precio de lista de venta." },
    { name = "unit_margin", type = "NUMERIC", mode = "REQUIRED", description = "Margen unitario nominal (unit_price - unit_cost)." },
    { name = "is_active", type = "BOOLEAN", mode = "REQUIRED", description = "Flag de disponibilidad comercial activa." },
    { name = "processed_at", type = "TIMESTAMP", mode = "REQUIRED", description = "Timestamp UTC de auditoria." }
  ])

  table_constraints {
    primary_key {
      columns = ["product_id"]
    }
  }
}

# ------------------------------------------------------------------------------
# SILVER: stg_orders (Incremental por order_date)
# ------------------------------------------------------------------------------
resource "google_bigquery_table" "stg_orders" {
  dataset_id          = google_bigquery_dataset.silver.dataset_id
  table_id            = "stg_orders"
  deletion_protection = false

  description = "Cabeceras de ordenes transaccionales procesadas de forma incremental. Particionada por dia."

  time_partitioning {
    type  = "DAY"
    field = "order_date"
  }

  clustering = ["customer_id", "order_status"]

  schema = jsonencode([
    { name = "order_id", type = "STRING", mode = "REQUIRED", description = "Identificador unico de orden (PK)." },
    { name = "customer_id", type = "STRING", mode = "REQUIRED", description = "FK referenciando stg_customers.customer_id." },
    { name = "order_timestamp", type = "TIMESTAMP", mode = "REQUIRED", description = "Marca temporal exacta del pedido." },
    { name = "order_date", type = "DATE", mode = "REQUIRED", description = "Campo de particionamiento diario." },
    { name = "order_status", type = "STRING", mode = "REQUIRED", description = "Estado: COMPLETED, PENDING, CANCELLED." },
    { name = "shipping_city", type = "STRING", mode = "NULLABLE", description = "Ciudad destino de despacho." },
    { name = "promo_code", type = "STRING", mode = "NULLABLE", description = "Codigo de promocion aplicado." },
    { name = "processed_at", type = "TIMESTAMP", mode = "REQUIRED", description = "Timestamp UTC de procesamiento." }
  ])

  table_constraints {
    primary_key {
      columns = ["order_id"]
    }
    foreign_keys {
      name = "fk_orders_customer"
      referenced_table {
        project_id = var.project_id
        dataset_id = google_bigquery_dataset.silver.dataset_id
        table_id   = google_bigquery_table.stg_customers.table_id
      }
      column_references {
        referencing_column = "customer_id"
        referenced_column  = "customer_id"
      }
    }
  }
}

# ------------------------------------------------------------------------------
# SILVER: stg_order_items (Incremental por order_date)
# ------------------------------------------------------------------------------
resource "google_bigquery_table" "stg_order_items" {
  dataset_id          = google_bigquery_dataset.silver.dataset_id
  table_id            = "stg_order_items"
  deletion_protection = false

  description = "Lineas de items vendidas, calculo de ingresos brutos y netos incrementales."

  time_partitioning {
    type  = "DAY"
    field = "order_date"
  }

  clustering = ["order_id", "product_id"]

  schema = jsonencode([
    { name = "order_item_id", type = "STRING", mode = "REQUIRED", description = "PK unica de linea de orden." },
    { name = "order_id", type = "STRING", mode = "REQUIRED", description = "FK a stg_orders.order_id." },
    { name = "product_id", type = "STRING", mode = "REQUIRED", description = "FK a stg_products.product_id." },
    { name = "order_date", type = "DATE", mode = "REQUIRED", description = "Fecha de particion." },
    { name = "quantity", type = "INTEGER", mode = "REQUIRED", description = "Unidades vendidas." },
    { name = "unit_price", type = "NUMERIC", mode = "REQUIRED", description = "Precio unitario facturado." },
    { name = "discount", type = "NUMERIC", mode = "REQUIRED", description = "Descuento total en la linea." },
    { name = "gross_amount", type = "NUMERIC", mode = "REQUIRED", description = "Subtotal (quantity * unit_price)." },
    { name = "net_amount", type = "NUMERIC", mode = "REQUIRED", description = "Total neto final pagado." },
    { name = "processed_at", type = "TIMESTAMP", mode = "REQUIRED", description = "Auditoria UTC." }
  ])

  table_constraints {
    primary_key {
      columns = ["order_item_id"]
    }
    foreign_keys {
      name = "fk_items_orders"
      referenced_table {
        project_id = var.project_id
        dataset_id = google_bigquery_dataset.silver.dataset_id
        table_id   = google_bigquery_table.stg_orders.table_id
      }
      column_references {
        referencing_column = "order_id"
        referenced_column  = "order_id"
      }
    }
    foreign_keys {
      name = "fk_items_products"
      referenced_table {
        project_id = var.project_id
        dataset_id = google_bigquery_dataset.silver.dataset_id
        table_id   = google_bigquery_table.stg_products.table_id
      }
      column_references {
        referencing_column = "product_id"
        referenced_column  = "product_id"
      }
    }
  }
}

# ------------------------------------------------------------------------------
# SILVER: stg_payments (Incremental por payment_date)
# ------------------------------------------------------------------------------
resource "google_bigquery_table" "stg_payments" {
  dataset_id          = google_bigquery_dataset.silver.dataset_id
  table_id            = "stg_payments"
  deletion_protection = false

  description = "Transacciones de pago liquidadas o en proceso, control de estados y montos."

  time_partitioning {
    type  = "DAY"
    field = "payment_date"
  }

  clustering = ["order_id", "payment_status"]

  schema = jsonencode([
    { name = "payment_id", type = "STRING", mode = "REQUIRED", description = "PK unica de la transaccion financiera." },
    { name = "order_id", type = "STRING", mode = "REQUIRED", description = "FK a stg_orders.order_id." },
    { name = "payment_timestamp", type = "TIMESTAMP", mode = "REQUIRED", description = "Marca temporal del pago." },
    { name = "payment_date", type = "DATE", mode = "REQUIRED", description = "Fecha de particion diaria." },
    { name = "payment_method", type = "STRING", mode = "REQUIRED", description = "Metodo de pago: CREDIT_CARD, BANK_TRANSFER, etc." },
    { name = "payment_status", type = "STRING", mode = "REQUIRED", description = "Estado: SETTLED, PENDING, FAILED." },
    { name = "amount", type = "NUMERIC", mode = "REQUIRED", description = "Monto monetario recibido." },
    { name = "processed_at", type = "TIMESTAMP", mode = "REQUIRED", description = "Auditoria UTC." }
  ])

  table_constraints {
    primary_key {
      columns = ["payment_id"]
    }
    foreign_keys {
      name = "fk_payments_orders"
      referenced_table {
        project_id = var.project_id
        dataset_id = google_bigquery_dataset.silver.dataset_id
        table_id   = google_bigquery_table.stg_orders.table_id
      }
      column_references {
        referencing_column = "order_id"
        referenced_column  = "order_id"
      }
    }
  }
}

# ------------------------------------------------------------------------------
# GOLD: fct_sales_daily_performance (Incremental)
# ------------------------------------------------------------------------------
resource "google_bigquery_table" "fct_sales_daily_performance" {
  dataset_id          = google_bigquery_dataset.gold.dataset_id
  table_id            = "fct_sales_daily_performance"
  deletion_protection = false

  description = "Resumen diario incremental de rendimiento de ventas por producto y categoria."

  time_partitioning {
    type  = "DAY"
    field = "sale_date"
  }

  clustering = ["category", "product_id"]

  schema = jsonencode([
    { name = "sale_date", type = "DATE", mode = "REQUIRED", description = "Fecha analitica de venta." },
    { name = "category", type = "STRING", mode = "REQUIRED", description = "Categoria del producto." },
    { name = "product_id", type = "STRING", mode = "REQUIRED", description = "ID del producto analizado." },
    { name = "product_name", type = "STRING", mode = "REQUIRED", description = "Nombre descriptivo comercial." },
    { name = "total_orders", type = "INTEGER", mode = "REQUIRED", description = "Conteo diario de ordenes." },
    { name = "units_sold", type = "INTEGER", mode = "REQUIRED", description = "Unidades efectivas vendidas." },
    { name = "gross_revenue", type = "NUMERIC", mode = "REQUIRED", description = "Ingreso bruto acumulado." },
    { name = "total_discounts", type = "NUMERIC", mode = "REQUIRED", description = "Monto total descontado." },
    { name = "net_revenue", type = "NUMERIC", mode = "REQUIRED", description = "Ingreso neto facturado." },
    { name = "total_cost", type = "NUMERIC", mode = "REQUIRED", description = "Costo agregado de mercancia." },
    { name = "total_margin", type = "NUMERIC", mode = "REQUIRED", description = "Margen de ganancia bruto (net_revenue - total_cost)." },
    { name = "profit_margin_pct", type = "NUMERIC", mode = "NULLABLE", description = "Porcentaje de rentabilidad operativa." },
    { name = "processed_at", type = "TIMESTAMP", mode = "REQUIRED", description = "Auditoria UTC." }
  ])

  table_constraints {
    primary_key {
      columns = ["sale_date", "product_id"]
    }
  }
}

# ------------------------------------------------------------------------------
# GOLD: fct_customer_daily_activity (Incremental)
# ------------------------------------------------------------------------------
resource "google_bigquery_table" "fct_customer_daily_activity" {
  dataset_id          = google_bigquery_dataset.gold.dataset_id
  table_id            = "fct_customer_daily_activity"
  deletion_protection = false

  description = "Actividad diaria transaccional y pagos por cliente consolidada de forma incremental."

  time_partitioning {
    type  = "DAY"
    field = "activity_date"
  }

  clustering = ["country", "customer_id"]

  schema = jsonencode([
    { name = "activity_date", type = "DATE", mode = "REQUIRED", description = "Fecha del evento de compra." },
    { name = "customer_id", type = "STRING", mode = "REQUIRED", description = "ID unico del cliente." },
    { name = "full_name", type = "STRING", mode = "NULLABLE", description = "Nombre del cliente." },
    { name = "country", type = "STRING", mode = "REQUIRED", description = "Pais del cliente." },
    { name = "total_orders", type = "INTEGER", mode = "REQUIRED", description = "Ordenes creadas en el dia." },
    { name = "completed_orders", type = "INTEGER", mode = "REQUIRED", description = "Ordenes completadas con exito." },
    { name = "total_amount_paid", type = "NUMERIC", mode = "REQUIRED", description = "Monto total cobrado via pasarela." },
    { name = "payment_methods_used", type = "STRING", mode = "NULLABLE", description = "Medios de pago utilizados concatenados." },
    { name = "processed_at", type = "TIMESTAMP", mode = "REQUIRED", description = "Auditoria UTC." }
  ])

  table_constraints {
    primary_key {
      columns = ["activity_date", "customer_id"]
    }
  }
}

# ------------------------------------------------------------------------------
# GOLD: dim_customers_rfm (Truncate & Insert)
# ------------------------------------------------------------------------------
resource "google_bigquery_table" "dim_customers_rfm" {
  dataset_id          = google_bigquery_dataset.gold.dataset_id
  table_id            = "dim_customers_rfm"
  deletion_protection = false

  description = "Dimension analitica RFM de clientes enriquecida con resumenes semanticos para Gemini."

  clustering = ["rfm_segment", "country"]

  schema = jsonencode([
    { name = "customer_id", type = "STRING", mode = "REQUIRED", description = "ID unico del cliente (PK)." },
    { name = "full_name", type = "STRING", mode = "NULLABLE", description = "Nombre formateado." },
    { name = "email", type = "STRING", mode = "REQUIRED", description = "Correo electronico verificado." },
    { name = "country", type = "STRING", mode = "REQUIRED", description = "Pais de residencia." },
    { name = "first_order_date", type = "DATE", mode = "NULLABLE", description = "Fecha de su primera compra." },
    { name = "last_order_date", type = "DATE", mode = "NULLABLE", description = "Fecha de su ultima orden (Recency)." },
    { name = "days_since_last_order", type = "INTEGER", mode = "REQUIRED", description = "Dias transcurridos sin compras." },
    { name = "lifetime_completed_orders", type = "INTEGER", mode = "REQUIRED", description = "Volumen de compras (Frequency)." },
    { name = "lifetime_monetary_spent", type = "NUMERIC", mode = "REQUIRED", description = "Gasto total acumulado (Monetary)." },
    { name = "avg_ticket_value", type = "NUMERIC", mode = "REQUIRED", description = "Ticket promedio de compra." },
    { name = "rfm_segment", type = "STRING", mode = "REQUIRED", description = "Segmento: CHAMPIONS_VIP, LOYAL_RETENTION, NEW_ACTIVE, AT_RISK_CHURN, PROSPECT." },
    { name = "ai_context_summary", type = "STRING", mode = "REQUIRED", description = "Contexto en lenguaje natural para agentes LLM." },
    { name = "processed_at", type = "TIMESTAMP", mode = "REQUIRED", description = "Auditoria UTC." }
  ])

  table_constraints {
    primary_key {
      columns = ["customer_id"]
    }
  }
}
