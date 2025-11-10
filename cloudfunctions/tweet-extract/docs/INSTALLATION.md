# Guía de Instalación

## Requisitos Previos

- Cuenta de Google Cloud Platform con facturación habilitada
- Twitter Developer Account con Bearer Token
- gcloud CLI instalado y configurado
- Proyecto de GCP creado

## Instalación Paso a Paso

### 1. Preparar el entorno
```bash
# Clonar o descargar el proyecto
cd twitter-poller-gcp

# Configurar variables
cp .env.example .env
nano .env  # Editar con tus valores
```

### 2. Autenticarse en GCP
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### 3. Ejecutar instalación
```bash
chmod +x setup.sh
./setup.sh
```

### 4. Verificar instalación
```bash
# Ejecutar manualmente
gcloud scheduler jobs run twitter-poller-job --location=us-central1

# Ver logs
gcloud functions logs read twitter-poller --region=us-central1 --gen2 --limit=50

# Ver datos
gcloud firestore documents list tweets --limit=10
```

## Configuración Post-Instalación

### Personalizar filtros

Editar `.env`:
```bash
MIN_CHARACTERS=200
MIN_LIKES=1000
```

### Cambiar schedule

Editar `.env`:
```bash
SCHEDULER_CRON=0 6-22/2 * * 0-4  # Dom-Jue cada dos horas desde 6am-10pm
SCHEDULER_CRON_02=0 5-17/2 * * 5  # Vie cada dos horas desde 5am-5pm
```

Luego:
```bash
bash scripts/06-setup-scheduler.sh
```

### Agregar/quitar cuentas

Editar `.env`:
```bash
TWITTER_ACCOUNTS=Cuenta1,Cuenta2,Cuenta3
```

Luego:
```bash
bash scripts/05-deploy-function.sh
```

## Troubleshooting

### Error: "API not enabled"
```bash
bash scripts/01-enable-apis.sh
```

### Error: "Permission denied"
```bash
bash scripts/03-create-service-account.sh
```

### Función no ejecuta
```bash
gcloud functions logs read twitter-poller --region=us-central1 --gen2 --limit=100 | grep ERROR
```