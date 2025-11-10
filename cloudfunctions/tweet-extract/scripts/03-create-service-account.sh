#!/bin/bash
# 03-create-service-account.sh - Crea Service Account y asigna permisos

#Carga las variables de entorno desde el archivo .env
source .env

echo "👤 Creando Service Account..."

SA_EMAIL="${GCP_SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

# Verificar si ya existe
if gcloud iam service-accounts describe $SA_EMAIL --project=$GCP_PROJECT_ID 2>/dev/null; then
    echo "ℹ️  Service Account ya existe, saltando creación"
else
    gcloud iam service-accounts create $GCP_SERVICE_ACCOUNT_NAME \
        --display-name="Twitter Poller Service Account" \
        --description="Service account para Cloud Function de extracción de tweets" \
        --project=$GCP_PROJECT_ID
    
    echo "✅ Service Account creada"
    # ★★★ ESPERAR A QUE SE PROPAGUE ★★★
    echo "⏳ Esperando propagación (15 segundos)..."
    sleep 15
fi

echo "🔐 Asignando permisos..."

# Firestore
echo "   → Firestore (datastore.user)"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/datastore.user" \
    --condition=None

# Secret Manager
echo "   → Secret Manager (secretAccessor)"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/secretmanager.secretAccessor" \
    --condition=None

# Logging
echo "   → Logging (logWriter)"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/logging.logWriter" \
    --condition=None

echo "✅ Permisos asignados"

echo "📋 Service Account info:"
gcloud iam service-accounts describe $SA_EMAIL --project=$GCP_PROJECT_ID