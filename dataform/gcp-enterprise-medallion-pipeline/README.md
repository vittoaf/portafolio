# Enterprise Medallion Data Architecture en Google Cloud Platform (GCP)

Arquitectura de ingeniería de datos gobernada de extremo a extremo basada en el patrón **Medallion (Bronze -> Silver -> Gold)**, desplegada de forma automatizada mediante **Terraform**, orquestada y modelada con **Dataform**, ingesta vía **Python (BigQuery API)** y gobernanza activa con **Dataplex** y **Data Lineage**.

---

## 1. Arquitectura del Proyecto

```
[Fuentes CSV] 
       │
       ▼  (Extracción y Carga Idempotente vía Python + BigQuery API)
┌────────────────────────────────────────────────────────────────────────┐
│ Capa Bronze: Raw Ingestion (`bronze_layer`)                            │
│  - raw_customers, raw_products, raw_orders, raw_order_items, raw_paym │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼  (Dataform: Limpieza, Truncate/Merge, PK/FK)
┌────────────────────────────────────────────────────────────────────────┐
│ Capa Silver: Staging Normalizado (`silver_layer`)                      │
│  - stg_customers       (TRUNCATE & INSERT, deduplicado con QUALIFY)   │
│  - stg_products        (TRUNCATE & INSERT, margen unitario)            │
│  - stg_orders          (INCREMENTAL con MERGE, partición diaria)       │
│  - stg_order_items     (INCREMENTAL con MERGE, cálculo importes)       │
│  - stg_payments        (INCREMENTAL con MERGE, control transaccional)  │
│  * Aserciones modulares reutilizables JS en `dataform_assertions`      │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼  (Dataform: Cruces relacionales, RFM e IA)
┌────────────────────────────────────────────────────────────────────────┐
│ Capa Gold: Curated & Analytics (`gold_layer`)                          │
│  - fct_sales_daily_performance (INCREMENTAL MERGE: ventas y márgenes)  │
│  - fct_customer_daily_activity (INCREMENTAL MERGE: pagos y órdenes)    │
│  - dim_customers_rfm           (TRUNCATE & INSERT: RFM + Resumen LLM)  │
│  * Gobernanza, Linaje por columna y Metadatos en Dataplex Lake        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Estructura Completa del Repositorio

```text
gcp-enterprise-medallion-pipeline/
├── README.md
├── terraform/
│   ├── variables.tf.json            # Configuración de proyecto, región y operador
│   ├── main.tf                      # APIs, Datasets, IAM, Service Accounts y Workspace
│   ├── tables_ddl.tf                # DDL BigQuery (Esquemas, PK/FK NOT ENFORCED, Particiones)
│   ├── dataplex.tf                  # Lago Dataplex, Zonas Raw/Curated y Assets
│   └── outputs.tf                   # Identificadores de recursos creados
├── ingestion/
│   ├── requirements.txt             # Dependencias Python (google-cloud-bigquery, pandas, pyarrow)
│   ├── load_bronze.py               # Ingesta idempotente con metadatos de auditoría
│   └── data/                        # 5 fuentes CSV simuladas
│       ├── customers.csv
│       ├── products.csv
│       ├── orders.csv
│       ├── order_items.csv
│       └── payments.csv
└── dataform/
    ├── workflow_settings.yaml       # Configuración global del proyecto Dataform
    ├── includes/
    │   └── assertions_helpers.js    # Generadores genéricos de aserciones en JavaScript
    └── definitions/
        ├── bronze/
        │   └── declarations.js      # Declaraciones de las 5 tablas crudas
        ├── stg/                     # Modelos modulares Silver por dominio
        │   ├── stg_customers/
        │   │   ├── stg_customers.sqlx
        │   │   └── assertions/
        │   │       ├── pk_unique.sqlx
        │   │       └── not_null.sqlx
        │   ├── stg_products/
        │   │   ├── stg_products.sqlx
        │   │   └── assertions/
        │   │       ├── pk_unique.sqlx
        │   │       └── price_margin_check.sqlx
        │   ├── stg_orders/
        │   │   ├── stg_orders.sqlx
        │   │   └── assertions/
        │   │       ├── pk_unique.sqlx
        │   │       └── fk_customer.sqlx
        │   ├── stg_order_items/
        │   │   ├── stg_order_items.sqlx
        │   │   └── assertions/
        │   │       ├── pk_unique.sqlx
        │   │       ├── fk_orders.sqlx
        │   │       └── fk_products.sqlx
        │   └── stg_payments/
        │       ├── stg_payments.sqlx
        │       └── assertions/
        │           ├── pk_unique.sqlx
        │           └── fk_orders.sqlx
        ├── gold/                    # Modelos analíticos Gold
        │   ├── fct_sales_daily_performance/
        │   │   ├── fct_sales_daily_performance.sqlx
        │   │   └── assertions/
        │   │       ├── pk_unique.sqlx
        │   │       └── revenue_positive.sqlx
        │   ├── fct_customer_daily_activity/
        │   │   ├── fct_customer_daily_activity.sqlx
        │   │   └── assertions/
        │   │       └── pk_unique.sqlx
        │   └── dim_customers_rfm/
        │       ├── dim_customers_rfm.sqlx
        │       └── assertions/
        │           └── pk_unique.sqlx
        └── tests/                   # Pruebas unitarias de Dataform
            ├── test_customer_cleaning.sqlx
            └── test_product_margin.sqlx
```

---

## 3. Guía de Implementación Paso a Paso

### Prerrequisitos
- Google Cloud SDK (`gcloud`) instalado y autenticado (`gcloud auth login` y `gcloud auth application-default login`).
- Terraform `>= 1.5.0`.
- Python `>= 3.9`.
- Proyecto activo en GCP con facturación asociada.

### Paso 1: Configurar Variables de Terraform
Abre `terraform/variables.tf.json` y valida tus parámetros:
```json
{
  "variable": {
    "project_id": { "default": "prj-cicd-user-17177" },
    "gcp_region": { "default": "us-central1" },
    "admin_user_email": { "default": "leiafperu@gmail.com" }
  }
}
```

### Paso 2: Desplegar Infraestructura Base con Terraform
Navega a la carpeta de Terraform y ejecuta:
```bash
cd terraform
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```
Este paso:
1. Activa las APIs requeridas (`bigquery`, `dataform`, `dataplex`, `datacatalog`, `datalineage`).
2. Crea los datasets en `us-central1` con `delete_contents_on_destroy = true`.
3. Crea las 8 tablas físicas de Silver y Gold con sus claves primarias y foráneas (`NOT ENFORCED`), descripciones de columnas y particiones.
4. Asigna permisos al usuario operador y crea la Service Account de ingesta (`sa-medallion-ingestion`) descargando su clave JSON.
5. Crea el repositorio de Dataform y el workspace `dev-workspace`.
6. Configura el Data Lake en Dataplex con sus activos sincronizados.

### Paso 3: Ingestar la Capa Bronze con Python
Regresa a la raíz y entra a la carpeta `ingestion`:
```bash
cd ../ingestion
python -m venv venv
# En Linux/macOS:
source venv/bin/activate
# En Windows:
.\venv\Scripts\activate

pip install -r requirements.txt
python load_bronze.py
```
El script cargará las 5 tablas crudas en `bronze_layer` agregando el timestamp UTC `processed_at`.

### Paso 4: Cargar Código y Ejecutar en Dataform
1. En Google Cloud Console, ve a **BigQuery** -> **Dataform**.
2. Entra al repositorio `medallion-dataform-repo` y abre el workspace `dev-workspace`.
3. Carga o commitea los archivos de la carpeta `dataform/` del repositorio.
4. En el panel superior, haz clic en **Start Execution** -> **All actions**.
5. Dataform ejecutará las transformaciones (Truncate/Insert para maestros, Merge para incrementales), validará las pruebas unitarias y ejecutará las aserciones de calidad sin colisiones de claves ni problemas de cuotas.

### Paso 5: Consultar Linaje y Dataplex
1. En Google Cloud Console, ve a **Dataplex** -> **Search**.
2. Busca la tabla `dim_customers_rfm` o `fct_sales_daily_performance`.
3. Abre la pestaña **Linaje (Lineage)** para explorar el grafo interactivo desde Bronze hasta Gold a nivel de tabla y columna.

---

## 4. Guía de Desinstalación Limpia (Teardown)

Para destruir toda la infraestructura sin bloqueos de dependencias anidadas de Dataform:

1. **Eliminar el Workspace de Dataform:**
   ```bash
   gcloud dataform workspaces delete dev-workspace \
     --project=prj-cicd-user-17177 \
     --location=us-central1 \
     --repository=medallion-dataform-repo \
     --quiet
   ```

2. **Destruir con Terraform:**
   ```bash
   cd terraform
   terraform destroy -auto-approve
   ```
Al tener `delete_contents_on_destroy = true`, Terraform vaciará y borrará todos los datasets de BigQuery sin errores.
