# Twitter Poller GCP

Sistema automático de extracción de tweets usando Google Cloud Platform.

## 🎯 Objetivo

Extraer automáticamente tweets de cuentas específicas que cumplan criterios:
- Más de 200 caracteres
- Más de 1000 likes
- Actualización de métricas en tweets existentes

## 📊 Características

- ✅ Extracción automática cada 2 horas (Dom-Vie hasta 5pm)
- ✅ Almacenamiento en Firestore
- ✅ Prevención de duplicados
- ✅ Actualización de métricas (likes, retweets)
- ✅ Secrets seguros con Secret Manager
- ✅ Logging y monitoreo integrado
- ✅ Scale to zero (solo paga cuando ejecuta)

## 🏗️ Arquitectura
```
Cloud Scheduler (cron)
    ↓
Cloud Function (Python 3.11)
    ├─> Twitter API v2
    ├─> Secret Manager
    └─> Firestore
```

## 💰 Costos Estimados

**Con Free Tier de GCP: $0/mes**

- Cloud Functions: 360 invocaciones/mes (dentro de 2M gratis)
- Firestore: ~5K docs (dentro de 1GB gratis)
- Secret Manager: 1 secret (dentro de 6 gratis)
- Cloud Build: ~15 min/mes (dentro de 120 min/día gratis)
- Cloud Scheduler: 1 job (dentro de 3 gratis)

## 📦 Requisitos Previos

### 1. Cuenta de Google Cloud Platform
- Crear cuenta en https://cloud.google.com
- Crear proyecto nuevo
- Habilitar facturación (requerido para Cloud Functions)

### 2. Twitter Developer Account
1. Ir a https://developer.twitter.com
2. Aplicar para developer access
3. Crear una App
4. Generar Bearer Token (Essential access es suficiente)

### 3. Herramientas locales
- gcloud CLI: https://cloud.google.com/sdk/docs/install
- git (para clonar el repo)

## 🚀 Instalación Rápida
```bash
# 1. Navegar a la carpeta del proyecto
cd cloudfunctions/tweet-extract

# 2. Configurar variables de entorno
cp .env.example .env
nano .env  # Editar con tus valores

# 3. Autenticarse en GCP
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# 4. Ejecutar instalación completa
chmod +x setup.sh
./setup.sh
```

## 📖 Documentación Completa

- [Instalación desde CERO](INSTALL_FROM_ZERO.md) - Paso a paso completo
- [Desinstalación COMPLETA](UNINSTALL_COMPLETE.md) - Eliminación total
- [Instalación](docs/INSTALLATION.md) - Detalles técnicos
- [Configuración](docs/CONFIGURATION.md) - Personalización
- [Arquitectura](docs/ARCHITECTURE.md) - Diseño del sistema

## 📊 Monitoreo

### Ver logs
```bash
gcloud functions logs read twitter-poller \
    --region=us-central1 \
    --gen2 \
    --limit=50
```

### Ver datos en Firestore
```bash
# Consola web
https://console.cloud.google.com/firestore/data

# CLI
gcloud firestore documents list tweets --limit=10
```

### Ejecutar manualmente
```bash
gcloud scheduler jobs run twitter-poller-job --location=us-central1
```

## 🔧 Configuración

### Cuentas de Twitter monitoreadas
Editar en `.env`:
```bash
TWITTER_ACCOUNTS="InvictosSomos;Juezcentral;2010MisterChip"
```

### Filtros
```bash
MIN_CHARACTERS=200
MIN_LIKES=1000
```

### Schedule (cron)
```bash
SCHEDULER_CRON=0 6-22/2 * * 0-4  # Dom-Jue cada dos horas desde 6am-10pm
SCHEDULER_CRON_02=0 5-17/2 * * 5  # Vie cada dos horas desde 5am-5pm
SCHEDULER_TIMEZONE=America/Bogota  # UTC-5
```

## 🛠️ Comandos Útiles
```bash
# Pausar ejecuciones
gcloud scheduler jobs pause twitter-poller-job --location=us-central1

# Reanudar ejecuciones
gcloud scheduler jobs resume twitter-poller-job --location=us-central1

# Actualizar código
bash scripts/05-deploy-function.sh

# Ver estado del scheduler
gcloud scheduler jobs describe twitter-poller-job --location=us-central1
```

## 🗑️ Desinstalación
```bash
chmod +x teardown.sh
./teardown.sh
```

Ver [UNINSTALL_COMPLETE.md](UNINSTALL_COMPLETE.md) para instrucciones detalladas.

## 🔒 Seguridad

- ✅ Bearer Token en Secret Manager (encriptado)
- ✅ Service Account con permisos mínimos
- ✅ Cloud Function privada (no pública)
- ✅ Audit logs habilitados
- ✅ Sin credenciales en código

## 🐛 Troubleshooting

### Error: "API not enabled"
```bash
bash scripts/01-enable-apis.sh
```

### Error: "Permission denied"
```bash
bash scripts/03-create-service-account.sh
```

### Error: "Secret not found"
```bash
bash scripts/04-store-secrets.sh
```

### Función no ejecuta
```bash
gcloud functions logs read twitter-poller \
    --region=us-central1 \
    --gen2 \
    --limit=100 | grep ERROR
```

## 📄 Licencia

MIT License - ver [LICENSE](LICENSE.md)

## 👤 Autor

- Linkedin: [Vitto Alcántara](https://www.linkedin.com/in/vittoalcantara/)
- Email: vitto.alcantara@gmail.com

## 🎥 PRÓXIMAMENTE!!! — Ver el tutorial en YouTube

Si prefieres seguir el paso a paso en video, puedes verlo aquí:  
👉 [Ver en YouTube](https://www.youtube.com/@leiaf2004)