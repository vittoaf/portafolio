#!/bin/bash
# 01-enable-apis.sh - Habilita todas las APIs necesarias

#Carga las variables de entorno desde el archivo .env
source .env

echo "🔌 Habilitando APIs de GCP..."

gcloud config set project $GCP_PROJECT_ID

gcloud services enable \
    run.googleapis.com \
    cloudfunctions.googleapis.com \
    cloudscheduler.googleapis.com \
    firestore.googleapis.com \
    secretmanager.googleapis.com \
    cloudbuild.googleapis.com \
    logging.googleapis.com \
    cloudresourcemanager.googleapis.com \
    --project=$GCP_PROJECT_ID

echo "✅ APIs habilitadas"

echo "📋 Verificando APIs habilitadas:"
gcloud services list --enabled --project=$GCP_PROJECT_ID | grep -E "cloudfunctions|scheduler|firestore|secretmanager|cloudbuild"