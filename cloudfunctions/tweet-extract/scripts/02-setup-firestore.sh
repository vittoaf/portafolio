#!/bin/bash
# 02-setup-firestore.sh - Configura Firestore database

#Carga las variables de entorno desde el archivo .env
source .env

echo "🗄️  Configurando Firestore..."

# Verificar si ya existe
if gcloud firestore databases list --project=$GCP_PROJECT_ID 2>&1 | grep -q "(default)"; then
    echo "ℹ️  Firestore ya existe, saltando creación"
else
    echo "📦 Creando Firestore database..."
    gcloud firestore databases create \
        --location=$GCP_REGION \
        --type=firestore-native \
        --project=$GCP_PROJECT_ID
    
    echo "✅ Firestore creado"
fi

echo "📋 Firestore databases:"
gcloud firestore databases list --project=$GCP_PROJECT_ID