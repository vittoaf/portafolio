import json
import os
import sys
from datetime import datetime, timezone
import pandas as pd
from google.cloud import bigquery
from google.oauth2 import service_account

# Localizacion de rutas de configuracion y claves
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
TERRAFORM_DIR = os.path.join(PROJECT_ROOT, "terraform")
VARIABLES_JSON = os.path.join(TERRAFORM_DIR, "variables.tf.json")
KEY_JSON = os.path.join(TERRAFORM_DIR, "pipeline-service-account-key.json")

def load_tf_variables(filepath: str) -> dict:
    """Lee y parsea las variables por defecto de Terraform JSON."""
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Archivo de variables no encontrado: {filepath}")
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)
    variables = data.get("variable", {})
    return {k: v.get("default") for k, v in variables.items()}

def get_bq_client(project_id: str, location: str, key_path: str) -> bigquery.Client:
    """Instancia cliente BigQuery priorizando Service Account Key."""
    if os.path.exists(key_path):
        print(f"[AUTH] Autenticado mediante Service Account Key: {key_path}")
        creds = service_account.Credentials.from_service_account_file(key_path)
        return bigquery.Client(project=project_id, credentials=creds, location=location)
    print("[AUTH] Key local no encontrada. Utilizando Application Default Credentials (ADC)...")
    return bigquery.Client(project=project_id, location=location)

def ingest_table_to_bronze(client: bigquery.Client, project_id: str, csv_path: str, table_name: str):
    """Carga idempotente (WRITE_TRUNCATE) agregando columna de auditoria processed_at."""
    print(f"--> Ingestando archivo [{os.path.basename(csv_path)}] -> bronze_layer.{table_name}")
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"Archivo CSV no existe: {csv_path}")

    df = pd.read_csv(csv_path)

    # Inyeccion de metadato de auditoria UTC
    df["processed_at"] = datetime.now(timezone.utc)

    table_id = f"{project_id}.bronze_layer.{table_name}"

    # Idempotencia: WRITE_TRUNCATE garantiza que volver a ejecutar no duplica registros
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        autodetect=True
    )

    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()  # Espera activa hasta terminar carga

    table = client.get_table(table_id)
    print(f"    [OK] {table.num_rows} filas cargadas exitosamente en {table_id}")

def main():
    print("================================================================")
    print(" INGESTA AUTOMATIZADA A CAPA BRONZE (BIGQUERY)")
    print("================================================================")

    vars_dict = load_tf_variables(VARIABLES_JSON)
    project_id = vars_dict.get("project_id")
    region = vars_dict.get("region", "us-central1")

    print(f"[CONFIG] GCP Project ID : {project_id}")
    print(f"[CONFIG] GCP Region     : {region}")

    if not project_id or project_id == "tu-gcp-project-id":
        print("[ADVERTENCIA] project_id aun tiene el placeholder por defecto.")
        print("Actualiza 'default' en terraform/variables.tf.json antes de continuar.")

    client = get_bq_client(project_id, region, KEY_JSON)

    data_dir = os.path.join(SCRIPT_DIR, "data")
    tables_map = {
        "raw_customers": os.path.join(data_dir, "customers.csv"),
        "raw_products": os.path.join(data_dir, "products.csv"),
        "raw_orders": os.path.join(data_dir, "orders.csv")
    }

    for tbl_name, file_path in tables_map.items():
        ingest_table_to_bronze(client, project_id, file_path, tbl_name)

    print("================================================================")
    print(" INGESTA A BRONZE CULMINADA CON EXITO")
    print("================================================================")

if __name__ == "__main__":
    main()
