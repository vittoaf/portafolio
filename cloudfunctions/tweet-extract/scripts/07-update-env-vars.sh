#!/bin/bash
# 07-update-env-vars.sh - Actualiza solo variables de entorno

#Carga las variables de entorno desde el archivo .env
source .env

echo "🔧 Actualizando variables de entorno..."

# Construir string de variables
ENV_VARS="GCP_PROJECT=${GCP_PROJECT_ID}"
ENV_VARS="${ENV_VARS},TWITTER_ACCOUNTS=${TWITTER_ACCOUNTS}"
ENV_VARS="${ENV_VARS},MIN_CHARACTERS=${MIN_CHARACTERS}"
ENV_VARS="${ENV_VARS},MIN_LIKES=${MIN_LIKES}"

# Actualizar solo env vars (más rápido que re-deploy completo)
gcloud functions deploy $FUNCTION_NAME \
    --gen2 \
    --region=$GCP_REGION \
    --update-env-vars="${ENV_VARS}" \
    --project=$GCP_PROJECT_ID

echo "✅ Variables actualizadas"

echo ""
echo "📋 Nuevas variables:"
echo "   TWITTER_ACCOUNTS: $TWITTER_ACCOUNTS"
echo "   MIN_CHARACTERS: $MIN_CHARACTERS"
echo "   MIN_LIKES: $MIN_LIKES"

echo ""
echo "ℹ️  Los cambios se aplicarán en la próxima ejecución"