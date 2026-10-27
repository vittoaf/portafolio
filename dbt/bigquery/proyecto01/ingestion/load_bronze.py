import json
import os
import sys
from datetime import datetime, timezone
import pandas as pd
from google.cloud import bigquery
from google.oauth2 import service_account

# Determinacion dinamica de rutas relativas a ./bigquery/proyecto01/...
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(BASE_DIR)
TERRAFORM_DIR = os.path.join(PROJECT_ROOT, "terraform")
VARIABLES_JSON_PATH = os.path.join(TERRAFORM_DIR, "variables.tf.json")
KEY_JSON_PATH = os.path.join(TERRAFORM_DIR, "dbt-service-account-key.json")

def load_terraform_variables(file_path: str) -> dict:
    """Lee el archivo variables.tf.json y extrae los valores por defecto."""
    if not os.path.exists(file_path):
        raise FileNotFoundError(
            f"No se encontro el archivo de variables de Terraform en: {file_path}"
        )
    
    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    variables = data.get("variable", {})
    extracted = {}
    for var_name, var_def in variables.items():
        extracted[var_name] = var_def.get("default")
        
    return extracted

def get_bigquery_client(project_id: str, location: str, key_path: str) -> bigquery.Client:
    """Instancia el cliente de BigQuery priorizando la clave generada por Terraform."""
    if os.path.exists(key_path):
        print(f"[AUTH] Usando Service Account Key generada por Terraform: {key_path}")
        credentials = service_account.Credentials.from_service_account_file(key_path)
        return bigquery.Client(project=project_id, credentials=credentials, location=location)
    else:
        print("[AUTH] Clave local de Service Account no detectada. Usando Application Default Credentials (ADC)...")
        return bigquery.Client(project=project_id, location=location)

def load_csv_to_bronze(client: bigquery.Client, project_id: str, file_path: str, table_name: str):
    """Carga un CSV en bronze_layer de forma idempotente con metadata de auditoria."""
    print(f"--> Ingestando tabla: bronze_layer.{table_name}")
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Archivo de datos no encontrado: {file_path}")

    df = pd.read_csv(file_path)

    # Inyeccion de columna de auditoria UTC requerida
    df["processed_at"] = datetime.now(timezone.utc)

    table_id = f"{project_id}.bronze_layer.{table_name}"

    # Idempotencia: WRITE_TRUNCATE garantiza que re-ejecutar reemplace limpiamente
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        autodetect=True,
    )

    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()  # Bloqueante hasta finalizar carga en BigQuery

    destination_table = client.get_table(table_id)
    print(f"    [OK] {destination_table.num_rows} filas cargadas exitosamente en {table_id}")

def main():
    print("=== INICIO DE INGESTA A CAPA BRONZE ===")
    
    # 1. Cargar configuracion desde variables.tf.json
    tf_vars = load_terraform_variables(VARIABLES_JSON_PATH)
    project_id = tf_vars.get("project_id")
    region = tf_vars.get("region", "us-central1")

    print(f"[CONFIG] GCP Project ID : {project_id}")
    print(f"[CONFIG] GCP Region     : {region}")

    if not project_id or project_id == "tu-gcp-project-id":
        print("[ADVERTENCIA] 'project_id' tiene el valor por defecto ('tu-gcp-project-id').")
        print("Asegurate de actualizar 'default' en terraform/variables.tf.json con tu ID real.")

    # 2. Inicializar cliente BigQuery
    client = get_bigquery_client(project_id=project_id, location=region, key_path=KEY_JSON_PATH)

    # 3. Cargar datasets
    customers_csv = os.path.join(BASE_DIR, "data", "customers.csv")
    orders_csv = os.path.join(BASE_DIR, "data", "orders.csv")

    load_csv_to_bronze(client, project_id, customers_csv, "raw_customers")
    load_csv_to_bronze(client, project_id, orders_csv, "raw_orders")

    print("=== INGESTA A BRONZE CULMINADA CON EXITO ===")

if __name__ == "__main__":
    main()
