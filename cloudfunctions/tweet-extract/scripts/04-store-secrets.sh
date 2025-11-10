#!/bin/bash
# 04-store-secrets.sh - Guarda Bearer Token en Secret Manager

#Carga las variables de entorno desde el archivo .env
source .env

echo "🔒 Guardando secrets en Secret Manager..."

SA_EMAIL="${GCP_SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

# Verificar si secret ya existe
if gcloud secrets describe twitter-bearer-token --project=$GCP_PROJECT_ID 2>/dev/null; then
    echo "ℹ️  Secret ya existe, actualizando versión..."
    echo -n "$TWITTER_BEARER_TOKEN" | gcloud secrets versions add twitter-bearer-token \
        --data-file=- \
        --project=$GCP_PROJECT_ID
else
    echo "📝 Creando secret..."
    echo -n "$TWITTER_BEARER_TOKEN" | \
        gcloud secrets create twitter-bearer-token \
        --data-file=- \
        --replication-policy="automatic" \
        --labels="app=twitter-poller,env=production" \
        --project=$GCP_PROJECT_ID
fi

echo "🔐 Dando acceso a Service Account..."

gcloud secrets add-iam-policy-binding twitter-bearer-token \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/secretmanager.secretAccessor" \
    --project=$GCP_PROJECT_ID

echo "✅ Secret guardado y acceso configurado"

echo "📋 Secret info:"
gcloud secrets describe twitter-bearer-token --project=$GCP_PROJECT_ID