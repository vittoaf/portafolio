import json
import os
import sys
from datetime import datetime, timezone
import pandas as pd
from google.cloud import bigquery
from google.oauth2 import service_account

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
TERRAFORM_DIR = os.path.join(PROJECT_ROOT, "terraform")
VARIABLES_JSON = os.path.join(TERRAFORM_DIR, "variables.tf.json")
KEY_JSON = os.path.join(TERRAFORM_DIR, "pipeline-service-account-key.json")

def load_tf_variables(filepath: str) -> dict:
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"No se encontro el archivo de variables: {filepath}")
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)
    variables = {}
    for k, v in data.get("variable", {}).items():
        variables[k] = v.get("default")
    return variables

def get_bigquery_client(project_id: str, key_path: str) -> bigquery.Client:
    if os.path.exists(key_path):
        print(f"[INFO] Autenticando mediante clave de cuenta de servicio: {key_path}")
        credentials = service_account.Credentials.from_service_account_file(key_path)
        return bigquery.Client(project=project_id, credentials=credentials)
    print("[INFO] Autenticando mediante Application Default Credentials (ADC)...")
    return bigquery.Client(project=project_id)

def ingest_table(client: bigquery.Client, project_id: str, dataset_id: str, table_name: str, csv_filename: str):
    csv_path = os.path.join(SCRIPT_DIR, "data", csv_filename)
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"Archivo de datos no encontrado: {csv_path}")

    print(f"--- Ingestando {csv_filename} -> {project_id}.{dataset_id}.{table_name} ---")
    df = pd.read_csv(csv_path, dtype=str)
    now_utc = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    df["processed_at"] = now_utc

    table_id = f"{project_id}.{dataset_id}.{table_name}"
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        autodetect=True,
        source_format=bigquery.SourceFormat.CSV
    )

    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()

    dest_table = client.get_table(table_id)
    print(f"[OK] Carga finalizada: {dest_table.num_rows} filas cargadas con processed_at={now_utc}")

def main():
    print("Iniciando Ingesta Idempotente de Capa Bronze...")
    tf_vars = load_tf_variables(VARIABLES_JSON)
    project_id = tf_vars.get("project_id")
    dataset_id = "bronze_layer"

    if not project_id:
        print("[ERROR] 'project_id' no esta definido en variables.tf.json")
        sys.exit(1)

    client = get_bigquery_client(project_id, KEY_JSON)

    tables = [
        ("raw_customers", "customers.csv"),
        ("raw_products", "products.csv"),
        ("raw_orders", "orders.csv"),
        ("raw_order_items", "order_items.csv"),
        ("raw_payments", "payments.csv")
    ]

    for table_name, csv_file in tables:
        ingest_table(client, project_id, dataset_id, table_name, csv_file)

    print("[SUCCESS] Las 5 tablas de la capa Bronze han sido ingestadas exitosamente.")

if __name__ == "__main__":
    main()
