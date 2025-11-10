#!/bin/bash
# setup.sh - Instalación completa

#Si algún comando falla, termina el script inmediatamente.
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $1"                                                   ║
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header "TWITTER POLLER GCP - INSTALACIÓN AUTOMÁTICA"

if [ ! -f .env ]; then
    print_error "Archivo .env no encontrado"
    echo "Pasos:"
    echo "  1. cp .env.example .env"
    echo "  2. nano .env"
    echo "  3. ./setup.sh"
    exit 1
fi

#Carga las variables de entorno desde el archivo .env
source .env

if [ -z "$GCP_PROJECT_ID" ]; then
    print_error "GCP_PROJECT_ID no configurado en .env"
    exit 1
fi

if [ -z "$TWITTER_BEARER_TOKEN" ]; then
    print_error "TWITTER_BEARER_TOKEN no configurado en .env"
    exit 1
fi

print_success "Variables cargadas"
echo "   Proyecto: $GCP_PROJECT_ID"
echo "   Región: $GCP_REGION"


# read -p "¿Continuar? (y/n) " -n 1 -r
# read → lee algo que el usuario escribe en la terminal.
# -p "¿Continuar? (y/n) " → muestra ese mensaje como prompt antes de leer.
# -n 1 → solo lee 1 carácter (no espera Enter para más texto).
# -r → lee el texto “crudo” (sin interpretar \ como carácter especial).
# Como no se indica nombre de variable, lo que el usuario teclea se guarda en la variable especial $REPLY.

read -p "¿Continuar? (y/n) " -n 1 -r
echo
#Si la respuesta NO coincide con exactamente una y o Y, entonces sal del script con código 1 y se aborta todo.
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

mkdir -p logs

print_header "Paso 1/6: Habilitando APIs"
bash scripts/01-enable-apis.sh 2>&1 | tee logs/01-enable-apis.log
print_success "APIs habilitadas"

print_header "Paso 2/6: Configurando Firestore"
bash scripts/02-setup-firestore.sh 2>&1 | tee logs/02-setup-firestore.log
print_success "Firestore configurado"

print_header "Paso 3/6: Creando Service Account"
bash scripts/03-create-service-account.sh 2>&1 | tee logs/03-create-service-account.log
print_success "Service Account creada"

print_header "Paso 4/6: Guardando secrets"
bash scripts/04-store-secrets.sh 2>&1 | tee logs/04-store-secrets.log
print_success "Secrets guardados"

print_header "Paso 5/6: Desplegando Cloud Function"
bash scripts/05-deploy-function.sh 2>&1 | tee logs/05-deploy-function.log
print_success "Cloud Function desplegada"

print_header "Paso 6/6: Configurando Scheduler"
bash scripts/06-setup-scheduler.sh 2>&1 | tee logs/06-setup-scheduler.log
print_success "Scheduler configurado"

print_header "✅ INSTALACIÓN COMPLETADA"

echo -e "${GREEN}📊 Resumen:${NC}"
echo "   ✅ APIs habilitadas"
echo "   ✅ Firestore creado"
echo "   ✅ Service Account configurada"
echo "   ✅ Secrets almacenados"
echo "   ✅ Cloud Function desplegada"
echo "   ✅ Scheduler configurado"

echo -e "\n${GREEN}🔗 Enlaces:${NC}"
echo "   Functions: https://console.cloud.google.com/functions?project=$GCP_PROJECT_ID"
echo "   Firestore: https://console.cloud.google.com/firestore?project=$GCP_PROJECT_ID"
echo "   Scheduler: https://console.cloud.google.com/cloudscheduler?project=$GCP_PROJECT_ID"

echo -e "\n${GREEN}📝 Comandos:${NC}"
echo "   Ver logs: gcloud functions logs read $FUNCTION_NAME --region=$GCP_REGION --gen2 --limit=50"
echo "   Ejecutar: gcloud scheduler jobs run $SCHEDULER_JOB_NAME --location=$GCP_REGION"