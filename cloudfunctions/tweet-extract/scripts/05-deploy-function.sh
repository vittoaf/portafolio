#!/bin/bash
# 05-deploy-function.sh - Despliega Cloud Function

#Carga las variables de entorno desde el archivo .env
source .env

echo "🚀 Desplegando Cloud Function..."

SA_EMAIL="${GCP_SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

# Construir string de variables de entorno
ENV_VARS="GCP_PROJECT=${GCP_PROJECT_ID}"
ENV_VARS="${ENV_VARS},TWITTER_ACCOUNTS=${TWITTER_ACCOUNTS}"
ENV_VARS="${ENV_VARS},MIN_CHARACTERS=${MIN_CHARACTERS}"
ENV_VARS="${ENV_VARS},MIN_LIKES=${MIN_LIKES}"

gcloud functions deploy $FUNCTION_NAME \
    --gen2 \
    --runtime=python311 \
    --region=$GCP_REGION \
    --source=./function \
    --entry-point=twitter_poller \
    --trigger-http \
    --service-account=$SA_EMAIL \
    --set-env-vars="${ENV_VARS}" \
    --timeout=$FUNCTION_TIMEOUT \
    --memory=$FUNCTION_MEMORY \
    --max-instances=$FUNCTION_MAX_INSTANCES \
    --no-allow-unauthenticated \
    --project=$GCP_PROJECT_ID

echo "✅ Cloud Function desplegada"

# Obtener URL
FUNCTION_URL=$(gcloud functions describe $FUNCTION_NAME \
    --region=$GCP_REGION \
    --gen2 \
    --project=$GCP_PROJECT_ID \
    --format="value(url)")

echo "🔗 URL: $FUNCTION_URL"

# Guardar URL
echo $FUNCTION_URL > .function-url

# ★★★ AGREGAR PERMISO INVOKER ★★★
echo ""
echo "🔐 Agregando permisos de invocación..."

gcloud functions add-invoker-policy-binding $FUNCTION_NAME \
    --region=$GCP_REGION \
    --member="serviceAccount:${SA_EMAIL}" \
    # --role="roles/cloudfunctions.invoker" \
    # --gen2 \
    --project=$GCP_PROJECT_ID \
    --quiet

echo "✅ Permisos configurados"

echo ""
echo "📋 Variables de entorno configuradas:"
echo "   GCP_PROJECT: $GCP_PROJECT_ID"
echo "   TWITTER_ACCOUNTS: $TWITTER_ACCOUNTS"
echo "   MIN_CHARACTERS: $MIN_CHARACTERS"
echo "   MIN_LIKES: $MIN_LIKES"

echo ""
echo "📋 Function info:"
gcloud functions describe $FUNCTION_NAME \
    --region=$GCP_REGION \
    --gen2 \
    --project=$GCP_PROJECT_ID