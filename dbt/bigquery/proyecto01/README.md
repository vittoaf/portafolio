# Proyecto Medallion con BigQuery, dbt y Terraform (proyecto01)

Este proyecto implementa la arquitectura Medallion (**Bronze**, **Silver** y **Gold**) ubicado en la ruta `./bigquery/proyecto01/`.

---

## Modificaciones Implementadas:
1. **Configuracion unificada en `variables.tf.json`:**
   - Terraform admite sintaxis JSON (`.tf.json`).
   - El script de Python `load_bronze.py` lee directamente `terraform/variables.tf.json` para obtener `project_id` y `region`, eliminando la necesidad de duplicar variables en un `.env`.
2. **Carga automatica de credenciales:**
   - `load_bronze.py` busca directamente `terraform/dbt-service-account-key.json`. Si existe, la utiliza automaticamente sin necesidad de exportar `GOOGLE_APPLICATION_CREDENTIALS` manualmente.
3. **Ajuste en `.gitignore`:**
   - Se ignora `*.json` pero se asegura una excepcion con `!variables.tf.json` para no subir claves secretas pero si mantener la definicion de variables de Terraform en el repositorio.

---

## Estructura del Proyecto:
```text
bigquery/
└── proyecto01/
    ├── .gitignore
    ├── README.md
    ├── setup_directories.sh
    ├── terraform/
    │   ├── variables.tf.json           # Declaracion y valores por defecto (project_id, region)
    │   ├── main.tf                     # Service Account y descarga de clave JSON
    │   └── outputs.tf
    ├── ingestion/
    │   ├── requirements.txt
    │   ├── load_bronze.py              # Lee variables.tf.json y key automaticamente
    │   └── data/
    │       ├── customers.csv
    │       └── orders.csv
    └── dbt_project/
        ├── dbt_project.yml
        ├── models/
        │   ├── staging/
        │   │   ├── _sources.yml
        │   │   ├── stg_customers.sql
        │   │   ├── stg_orders.sql
        │   │   └── _staging_models.yml
        │   └── marts/
        │       ├── fct_customer_orders_summary.sql
        │       └── _marts_models.yml
        └── tests/
            └── assert_no_negative_order_amounts.sql
```

---

## Paso a Paso:

### 1. Configurar tus variables en `terraform/variables.tf.json`
Edita `./bigquery/proyecto01/terraform/variables.tf.json` y coloca tu `project_id` de GCP:
```json
{
  "variable": {
    "project_id": {
      "type": "string",
      "default": "TU_PROJECT_ID_REAL"
    },
    "region": {
      "type": "string",
      "default": "us-central1"
    }
  }
}
```

### 2. Desplegar la Service Account con Terraform
```bash
cd bigquery/proyecto01/terraform
terraform init
terraform apply -auto-approve
# Generara automaticamente: dbt-service-account-key.json
cd ..
```

### 3. Ejecutar Ingesta a Bronze con Python
```bash
cd ingestion
python -m venv venv
source venv/bin/activate  # En Windows: venv\Scripts\activate
pip install -r requirements.txt

# Ejecutas directamente; leera variables.tf.json y la key JSON generada:
python load_bronze.py
cd ..
```

### 4. Configurar dbt Cloud
1. Sube tu proyecto a GitHub (o conecta la carpeta `dbt_project`).
2. En dbt Cloud, en la configuracion de conexion a BigQuery:
   - Sube el archivo `terraform/dbt-service-account-key.json`.
   - Dataset de desarrollo: `silver_layer`.
   - Ubicacion: `us-central1`.
3. Ejecuta en dbt Cloud:
   ```bash
   dbt run
   dbt test
   ```
