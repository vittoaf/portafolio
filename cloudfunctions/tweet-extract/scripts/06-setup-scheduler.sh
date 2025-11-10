#!/bin/bash
# 06-setup-scheduler.sh - Configura Cloud Scheduler

#Carga las variables de entorno desde el archivo .env
source .env

echo "⏰ Configurando Cloud Scheduler..."

SA_EMAIL="${GCP_SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

# Leer URL de la función
if [ -f .function-url ]; then
    FUNCTION_URL=$(cat .function-url)
else
    FUNCTION_URL=$(gcloud functions describe $FUNCTION_NAME \
        --region=$GCP_REGION \
        --gen2 \
        --project=$GCP_PROJECT_ID \
        --format="value(url)")
fi

echo "🔗 Function URL: $FUNCTION_URL"

# Verificar si job ya existe
if gcloud scheduler jobs describe $SCHEDULER_JOB_NAME \
    --location=$GCP_REGION \
    --project=$GCP_PROJECT_ID 2>/dev/null; then
    
    echo "ℹ️  Scheduler job ya existe, actualizando..."
    
    gcloud scheduler jobs update http $SCHEDULER_JOB_NAME \
        --location=$GCP_REGION \
        --schedule="$SCHEDULER_CRON" \
        --time-zone="$SCHEDULER_TIMEZONE" \
        --uri="$FUNCTION_URL" \
        --http-method=POST \
        --oidc-service-account-email=$SA_EMAIL \
        --oidc-token-audience="$FUNCTION_URL" \
        --project=$GCP_PROJECT_ID
else
    echo "📅 Creando scheduler job..."
    
    gcloud scheduler jobs create http $SCHEDULER_JOB_NAME \
        --location=$GCP_REGION \
        --schedule="$SCHEDULER_CRON" \
        --time-zone="$SCHEDULER_TIMEZONE" \
        --uri="$FUNCTION_URL" \
        --http-method=POST \
        --oidc-service-account-email=$SA_EMAIL \
        --oidc-token-audience="$FUNCTION_URL" \
        --description="Extrae tweets cada dos horas de Dom-Jue desde 6am-10pm UTC-5" \
        --attempt-deadline=600s \
        --project=$GCP_PROJECT_ID
fi

if gcloud scheduler jobs describe $SCHEDULER_JOB_NAME_02 \
    --location=$GCP_REGION \
    --project=$GCP_PROJECT_ID 2>/dev/null; then
    
    echo "ℹ️  Scheduler job ya existe, actualizando..."
    
    gcloud scheduler jobs update http $SCHEDULER_JOB_NAME_02 \
        --location=$GCP_REGION \
        --schedule="$SCHEDULER_CRON_02" \
        --time-zone="$SCHEDULER_TIMEZONE" \
        --uri="$FUNCTION_URL" \
        --http-method=POST \
        --oidc-service-account-email=$SA_EMAIL \
        --oidc-token-audience="$FUNCTION_URL" \
        --project=$GCP_PROJECT_ID
else
    echo "📅 Creando scheduler job..."
    
    gcloud scheduler jobs create http $SCHEDULER_JOB_NAME_02 \
        --location=$GCP_REGION \
        --schedule="$SCHEDULER_CRON_02" \
        --time-zone="$SCHEDULER_TIMEZONE" \
        --uri="$FUNCTION_URL" \
        --http-method=POST \
        --oidc-service-account-email=$SA_EMAIL \
        --oidc-token-audience="$FUNCTION_URL" \
        --description="Extrae tweets cada dos horas del Vie desde 5am-5pm UTC-5" \
        --attempt-deadline=600s \
        --project=$GCP_PROJECT_ID
fi

echo "✅ Cloud Scheduler configurado"

echo "📋 Schedule info:"
gcloud scheduler jobs describe $SCHEDULER_JOB_NAME \
    --location=$GCP_REGION \
    --project=$GCP_PROJECT_ID

gcloud scheduler jobs describe $SCHEDULER_JOB_NAME_02 \
    --location=$GCP_REGION \
    --project=$GCP_PROJECT_ID