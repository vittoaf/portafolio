#!/bin/bash
# teardown.sh - Elimina todos los recursos

#Si algún comando falla, termina el script inmediatamente.
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║${NC}     DESINSTALACIÓN COMPLETA                                ${RED}║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}\n"

if [ ! -f .env ]; then
    echo -e "${RED}❌ .env no encontrado${NC}"
    exit 1
fi

#Carga las variables de entorno desde el archivo .env
source .env

echo -e "${RED}⚠️  Esto eliminará PERMANENTEMENTE:${NC}"
echo "   🗑️  Cloud Function: $FUNCTION_NAME"
echo "   🗑️  Scheduler: $SCHEDULER_JOB_NAME"
echo "   🗑️  Service Account"
echo "   🗑️  Secret"
echo "   🗑️  Datos de Firestore"

read -p "Escribe 'DELETE' para confirmar: " -r
echo

if [ "$REPLY" != "DELETE" ]; then
    echo "Cancelado"
    exit 0
fi

echo -e "${YELLOW}Iniciando desinstalación...${NC}\n"

bash scripts/99-teardown.sh

echo -e "\n${GREEN}✅ DESINSTALACIÓN COMPLETADA${NC}"