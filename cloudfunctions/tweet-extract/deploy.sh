#!/bin/bash
# deploy.sh - Re-deploy rápido

#Si algún comando falla, termina el script inmediatamente.
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Re-desplegando...${NC}\n"

if [ ! -f .env ]; then
    echo "❌ .env no encontrado"
    exit 1
fi

#Carga las variables de entorno desde el archivo .env
source .env

bash scripts/05-deploy-function.sh

echo -e "\n${GREEN}✅ Re-deploy completado${NC}"