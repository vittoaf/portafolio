# Configuración

## Variables de Entorno

### GCP Configuration

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `GCP_PROJECT_ID` | ID del proyecto GCP | `my-project-123` |
| `GCP_REGION` | Región de deployment | `us-central1` |
| `GCP_SERVICE_ACCOUNT_NAME` | Nombre de la SA | `twitter-poller-sa` |
| `TWITTER_ACCOUNTS` | Cuentas a monitorear (sin @, sin espacios) | `InvictosSomos;Juezcentral;2010MisterChip` |

### Twitter API

| Variable | Descripción | Requerido |
|----------|-------------|-----------|
| `TWITTER_BEARER_TOKEN` | Bearer Token de Twitter API | ✅ Sí |
| `TWITTER_ACCOUNTS` | Cuentas a monitorear (sin @) | ✅ Sí |

### Cloud Function

| Variable | Valores | Default |
|----------|---------|---------|
| `FUNCTION_MEMORY` | 128MB-8GB | `512MB` |
| `FUNCTION_TIMEOUT` | 1s-540s | `540s` |
| `FUNCTION_MAX_INSTANCES` | 1-100 | `1` |

### Cloud Scheduler

| Variable | Descripción | Default |
|----------|-------------|---------|
| `SCHEDULER_CRON` | Expresión cron | `0 6-22/2 * * 0-4` |
| `SCHEDULER_CRON_02` | Expresión cron | `0 5-17/2 * * 5` |
| `SCHEDULER_TIMEZONE` | Zona horaria | `America/Bogota` |

### Filtros

| Variable | Descripción | Default |
|----------|-------------|---------|
| `MIN_CHARACTERS` | Mínimo de caracteres | `200` |
| `MIN_LIKES` | Mínimo de likes | `1000` |

## Ejemplos de Cron
```bash
# Cada 30 minutos
SCHEDULER_CRON="*/30 * * * *"

# Cada hora
SCHEDULER_CRON="0 * * * *"

# Solo a las 9am, Lun-Vie
SCHEDULER_CRON="0 9 * * 1-5"

# Cada 2 horas de 6am-10pm, Dom-Jue
SCHEDULER_CRON="0 6-22/2 * * 0-4"

# Cada 2 horas de 6am-5pm, Vie
SCHEDULER_CRON="0 6-17/2 * * 5"

# Cada 15 minutos, solo Lunes
SCHEDULER_CRON="*/15 * * * 1"
```

## Zonas Horarias
```bash
# UTC-5 (Colombia, Perú, Ecuador)
SCHEDULER_TIMEZONE=America/Bogota

# UTC-6 (México)
SCHEDULER_TIMEZONE=America/Mexico_City

# UTC-5/-4 (USA East)
SCHEDULER_TIMEZONE=America/New_York

# UTC-3 (Argentina)
SCHEDULER_TIMEZONE=America/Argentina/Buenos_Aires
```

Ver lista completa: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones