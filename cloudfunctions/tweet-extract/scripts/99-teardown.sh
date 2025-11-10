#!/bin/bash
# 99-teardown.sh - Elimina todos los recursos

#Carga las variables de entorno desde el archivo .env
source .env

SA_EMAIL="${GCP_SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

echo "1/5 Eliminando Cloud Scheduler..."
if gcloud scheduler jobs describe $SCHEDULER_JOB_NAME \
    --location=$GCP_REGION \
    --project=$GCP_PROJECT_ID 2>/dev/null; then
    gcloud scheduler jobs delete $SCHEDULER_JOB_NAME \
        --location=$GCP_REGION \
        --project=$GCP_PROJECT_ID \
        --quiet
    echo "✅ Scheduler eliminado"
else
    echo "ℹ️  Scheduler no existe"
fi

if gcloud scheduler jobs describe $SCHEDULER_JOB_NAME_02 \
    --location=$GCP_REGION \
    --project=$GCP_PROJECT_ID 2>/dev/null; then
    gcloud scheduler jobs delete $SCHEDULER_JOB_NAME_02 \
        --location=$GCP_REGION \
        --project=$GCP_PROJECT_ID \
        --quiet
    echo "✅ Scheduler 02 eliminado"
else
    echo "ℹ️  Scheduler 02 no existe"
fi

echo ""
echo "2/5 Eliminando Cloud Function..."
if gcloud functions describe $FUNCTION_NAME \
    --region=$GCP_REGION \
    --gen2 \
    --project=$GCP_PROJECT_ID 2>/dev/null; then
    gcloud functions delete $FUNCTION_NAME \
        --region=$GCP_REGION \
        --gen2 \
        --project=$GCP_PROJECT_ID \
        --quiet
    echo "✅ Cloud Function eliminada"
else
    echo "ℹ️  Cloud Function no existe"
fi

echo ""
echo "3/5 Eliminando Secret..."
if gcloud secrets describe twitter-bearer-token --project=$GCP_PROJECT_ID 2>/dev/null; then
    gcloud secrets delete twitter-bearer-token \
        --project=$GCP_PROJECT_ID \
        --quiet
    echo "✅ Secret eliminado"
else
    echo "ℹ️  Secret no existe"
fi

echo ""
echo "4/5 Eliminando permisos de Service Account..."
for role in "roles/datastore.user" "roles/secretmanager.secretAccessor" "roles/logging.logWriter"; do
    gcloud projects remove-iam-policy-binding $GCP_PROJECT_ID \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="$role" \
        --project=$GCP_PROJECT_ID \
        --quiet 2>/dev/null || true
done
echo "✅ Permisos removidos"

echo ""
echo "5/5 Eliminando Service Account..."
if gcloud iam service-accounts describe $SA_EMAIL --project=$GCP_PROJECT_ID 2>/dev/null; then
    gcloud iam service-accounts delete $SA_EMAIL \
        --project=$GCP_PROJECT_ID \
        --quiet
    echo "✅ Service Account eliminada"
else
    echo "ℹ️  Service Account no existe"
fi

echo ""
echo "🗑️  Eliminando repositorios de Artifact Registry..."

# Listar y eliminar repositorios (sin gcf-artifacts que es especial)
gcloud artifacts repositories list \
    --project=$GCP_PROJECT_ID \
    --format="value(name)" | while read REPO; do
    
    # Extraer nombre y ubicación del path completo
    # Format: projects/PROJECT/locations/LOCATION/repositories/NAME
    LOCATION=$(echo $REPO | cut -d'/' -f4)
    REPO_NAME=$(echo $REPO | cut -d'/' -f6)
    
    echo "   Borrando: $REPO_NAME (location: $LOCATION)"
    
    gcloud artifacts repositories delete $REPO_NAME \
        --location=$LOCATION \
        --project=$GCP_PROJECT_ID \
        --quiet 2>/dev/null || echo "      ⚠️  No se pudo eliminar $REPO_NAME"
done

echo "✅ Artifact Registry limpiado"

echo ""
echo " Eliminando Contenido de Cloud Build..."
# Obtener IDs de builds
BUILD_IDS=$(gcloud builds list \
    --project=$GCP_PROJECT_ID \
    --format="value(id)" \
    --limit=100)

if [ -z "$BUILD_IDS" ]; then
    echo "ℹ️  No hay builds para eliminar"
else
    BUILD_COUNT=$(echo "$BUILD_IDS" | wc -l)
    echo "   Encontrados: $BUILD_COUNT builds"
    
    echo "$BUILD_IDS" | while read BUILD_ID; do
        if [ ! -z "$BUILD_ID" ]; then
            echo "   Borrando build: $BUILD_ID"
            gcloud builds cancel "$BUILD_ID" \
                --project=$GCP_PROJECT_ID \
                --quiet 2>/dev/null || true
        fi
    done
    
    echo "✅ Cloud Build limpiado"
fi

echo ""
echo "6/5 Datos de Firestore..."
read -p "¿Eliminar TODOS los datos de Firestore? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "⚠️  Para eliminar Firestore, ejecuta manualmente:"
    echo "   gcloud firestore databases delete --database='(default)' --project=$GCP_PROJECT_ID"
else
    echo "ℹ️  Datos de Firestore conservados"
fi

rm -f .function-url

echo ""
echo "✅ Desinstalación de recursos completada"

echo ""
echo "🗑️  Eliminación rápida de Cloud Storage..."

# Confirmación única
read -p "⚠️  ¿Eliminar TODOS los buckets? (y/n): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelado"
    exit 0
fi

# Eliminar todos los buckets en paralelo
gsutil ls -p $GCP_PROJECT_ID | \
    xargs -P 10 -I {} sh -c 'gsutil -m rm -r {}** && gsutil rb {}'

echo "✅ Eliminación completada"

echo ""
echo "✅ Deshabilitar APIS"
gcloud services disable cloudfunctions.googleapis.com --project=$GCP_PROJECT_ID
gcloud services disable cloudscheduler.googleapis.com --project=$GCP_PROJECT_ID
gcloud services disable firestore.googleapis.com --project=$GCP_PROJECT_ID
gcloud services disable secretmanager.googleapis.com --project=$GCP_PROJECT_ID
gcloud services disable cloudbuild.googleapis.com --project=$GCP_PROJECT_ID
gcloud services disable run.googleapis.com --project=$GCP_PROJECT_ID
gcloud services disable artifactregistry.googleapis.com --project=$GCP_PROJECT_ID
#gcloud services disable logging.googleapis.com --project=$GCP_PROJECT_ID