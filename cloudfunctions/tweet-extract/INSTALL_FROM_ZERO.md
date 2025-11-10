# Instalación Desde CERO - Guía Completa

Esta guía asume que **NO TIENES NADA** configurado.

---

## 📋 REQUISITOS PREVIOS

- [ ] Cuenta de email
- [ ] Tarjeta de crédito/débito (solo para verificar GCP)
- [ ] Computadora con internet
- [ ] Terminal/Command Prompt

---

## PARTE 1: CREAR CUENTA DE GOOGLE CLOUD

### Paso 1.1: Registrarse en GCP

1. Ir a: https://cloud.google.com
2. Click en "Get started for free"
3. Iniciar sesión con Google
4. Completar información personal y de tarjeta
5. Aceptar términos
6. Click en "Start my free trial"

**Resultado:** $300 USD gratis por 90 días + Free Tier permanente

---

### Paso 1.2: Crear Proyecto

1. Ir a: https://console.cloud.google.com
2. Click en selector de proyecto (barra superior)
3. Click en "NEW PROJECT"
4. Configurar:
   - Project name: `twitter-poller-production`
   - Project ID: (se genera automático, ejemplo: `twitter-poller-12345`)
5. Click en "CREATE"
6. Seleccionar el proyecto

**Guardar el Project ID:**
```
Project ID: ________________________
```

✅ **Listo:** Tienes proyecto de GCP

---

## PARTE 2: OBTENER TWITTER BEARER TOKEN

### Paso 2.1: Crear Twitter Developer Account

1. Ir a: https://developer.twitter.com/en/portal/dashboard
2. Sign up si no tienes cuenta
3. Aplicar para developer access:
   - Type: "Hobbyist" → "Exploring the API"
   - App name: "Twitter Poller"
   - Description: "Automated tweet extraction"
4. Aceptar términos
5. Verificar email

---

### Paso 2.2: Crear App y Obtener Token

1. En dashboard: Click "Projects & Apps"
2. Click "Create App"
3. Configurar:
   - App name: `twitter-poller-app`
   - Environment: Development
4. **COPIAR BEARER TOKEN INMEDIATAMENTE**
```
Bearer Token: ________________________
```

⚠️ **Importante:** No se mostrará de nuevo. Si lo pierdes, regenerar en "Keys and tokens".

✅ **Listo:** Tienes Bearer Token

---

## PARTE 3: INSTALAR HERRAMIENTAS

### Paso 3.1: Instalar gcloud CLI

#### macOS:
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud --version
```

#### Linux:
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud --version
```

#### Windows:
1. Descargar: https://cloud.google.com/sdk/docs/install#windows
2. Ejecutar instalador
3. Abrir "Google Cloud SDK Shell"
4. Verificar: `gcloud --version`

✅ **Listo:** gcloud CLI instalado

---

### Paso 3.2: Autenticar
```bash
# Login
gcloud auth login

# Configurar proyecto (usar tu Project ID)
gcloud config set project twitter-poller-12345

# Verificar
gcloud config list
```

Deberías ver tu email y project ID.

✅ **Listo:** Autenticado

---

## PARTE 4: DESCARGAR E INSTALAR PROYECTO

### Paso 4.1: Descargar proyecto

**Opción A: Con Git**
```bash
git clone https://github.com/tu-usuario/twitter-poller-gcp.git
cd twitter-poller-gcp
```

**Opción B: Sin Git**
1. Descargar ZIP del repositorio
2. Descomprimir
3. Abrir terminal en esa carpeta

---

### Paso 4.2: Configurar variables
```bash
# Copiar archivo de ejemplo
cp .env.example .env

# Editar
nano .env     # Linux/macOS
notepad .env  # Windows
```

**Llenar estos valores:**
```bash
# TU PROJECT ID (del Paso 1.2)
GCP_PROJECT_ID=twitter-poller-12345

# Región (dejar us-central1)
GCP_REGION=us-central1

# TU BEARER TOKEN (del Paso 2.2)
TWITTER_BEARER_TOKEN=AAAAAAAAAAAAAAAAAAAAAFsKqwEAAAAA...

# Cuentas a monitorear (sin @, separadas por comas)
TWITTER_ACCOUNTS=InvictosSomos,Juezcentral,2010MisterChip

# Los demás valores déjalos como están
```

**Guardar el archivo**

✅ **Listo:** Configuración completa

---

### Paso 4.3: Hacer scripts ejecutables (Linux/macOS)
```bash
chmod +x setup.sh
chmod +x deploy.sh
chmod +x teardown.sh
chmod +x scripts/*.sh
```

*En Windows, saltar este paso*

---

## PARTE 5: INSTALAR

### Paso 5.1: Ejecutar instalación
```bash
./setup.sh
```

Preguntará: `¿Continuar? (y/n)`

Escribir `y` y Enter.

**Duración:** 5-10 minutos

Verás:
```
═══════════════════════════════════════════
Paso 1/6: Habilitando APIs...
═══════════════════════════════════════════
✅ APIs habilitadas

═══════════════════════════════════════════
Paso 2/6: Configurando Firestore...
═══════════════════════════════════════════
✅ Firestore configurado

... (continúa hasta 6/6)
```

---

### Paso 5.2: Verificar instalación

Al final verás:
```
╔════════════════════════════════════════════╗
║  ✅ INSTALACIÓN COMPLETADA                ║
╚════════════════════════════════════════════╝
```

✅ **Listo:** Sistema instalado

---

## PARTE 6: VERIFICAR FUNCIONAMIENTO

### Paso 6.1: Ejecutar manualmente
```bash
gcloud scheduler jobs run twitter-poller-job --location=us-central1
```

Esperar 30 segundos.

---

### Paso 6.2: Ver logs
```bash
gcloud functions logs read twitter-poller \
    --region=us-central1 \
    --gen2 \
    --limit=50
```

Buscar:
```
✅ Cliente de Twitter creado
🔍 Buscando tweets de @InvictosSomos
✅ Guardado InvictosSomos_123456789
📊 RESUMEN FINAL
```

---

### Paso 6.3: Ver datos en Firestore

**Opción A: Web Console**
https://console.cloud.google.com/firestore

Ver collection "tweets"

**Opción B: CLI**
```bash
gcloud firestore documents list tweets --limit=10
```

✅ **Listo:** Sistema funcionando

---

## 🎉 SISTEMA ACTIVO

Tu sistema extraerá tweets automáticamente:
- **Cuándo:** Lun-Vie, cada hora de 12am-5pm (UTC-5)
- **Qué:** Tweets con >200 caracteres y >1000 likes
- **Dónde:** Firestore

---

## 🐛 TROUBLESHOOTING

### Error: "gcloud: command not found"
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

### Error: "API not enabled"
```bash
bash scripts/01-enable-apis.sh
```

### Error: "Permission denied"
```bash
gcloud auth login
```

### Error: "Invalid Bearer Token"
1. Verificar token en .env
2. Regenerar en Twitter Developer Portal
3. Actualizar .env
4. `bash scripts/04-store-secrets.sh`

### Función no encuentra tweets
- Verificar que cuentas existen
- Verificar filtros (MIN_CHARACTERS, MIN_LIKES)
- Las cuentas pueden no tener tweets que cumplan criterios

### Ver errores detallados
```bash
gcloud functions logs read twitter-poller \
    --region=us-central1 \
    --gen2 \
    --limit=100 | grep ERROR
```

---

## 📞 SOPORTE

Si tienes problemas:
1. Revisar logs
2. Verificar .env
3. Abrir issue en GitHub