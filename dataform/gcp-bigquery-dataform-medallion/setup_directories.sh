#!/usr/bin/env bash
set -e

echo "================================================================="
echo " Creando estructura de directorios profesional para GitHub..."
echo " Proyecto: gcp-bigquery-dataform-medallion"
echo "================================================================="

mkdir -p terraform
mkdir -p ingestion/data
mkdir -p dataform/definitions/bronze
mkdir -p dataform/definitions/silver
mkdir -p dataform/definitions/gold

echo "[OK] Directorios creados exitosamente."
