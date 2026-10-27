#!/usr/bin/env bash
set -e

echo "Creando estructura de directorios bajo ./bigquery/proyecto01/..."

mkdir -p bigquery/proyecto01/terraform
mkdir -p bigquery/proyecto01/ingestion/data
mkdir -p bigquery/proyecto01/dbt_project/models/staging
mkdir -p bigquery/proyecto01/dbt_project/models/marts
mkdir -p bigquery/proyecto01/dbt_project/tests
mkdir -p bigquery/proyecto01/dbt_project/macros

echo "Estructura creada exitosamente en ./bigquery/proyecto01"
