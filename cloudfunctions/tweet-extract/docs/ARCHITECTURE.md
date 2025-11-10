# Arquitectura del Sistema

## Diagrama de Componentes
```
┌──────────────────┐
│ Cloud Scheduler  │ ← Trigger (cron)
└────────┬─────────┘
         │ HTTP POST (cada hora)
         ↓
┌────────────────────────────────┐
│ Cloud Function (Python 3.11)   │
│ - twitter_poller()             │
└────┬────────────────────┬──────┘
     │                    │
     │ Bearer Token       │ Guardar tweets
     ↓                    ↓
┌──────────────┐    ┌─────────────┐
│Secret Manager│    │  Firestore  │
│              │    │             │
│Bearer Token  │    │tweets/      │
└──────────────┘    │polling_state│
                    └─────────────┘
         │
         │ Buscar tweets
         ↓
    ┌─────────────┐
    │ Twitter API │
    │   (v2)      │
    └─────────────┘
```

## Flujo de Datos

1. **Cloud Scheduler** envía HTTP POST cada dos horas (Dom-Jue, 6am-10pm y Vie, 5am-5pm )
2. **Cloud Function** se activa:
   - Obtiene Bearer Token desde Secret Manager
   - Para cada cuenta en `TWITTER_ACCOUNTS`:
     - Busca tweets en Twitter API v2
     - Filtra por MIN_CHARACTERS y MIN_LIKES
     - Verifica duplicados en Firestore
     - Guarda tweets nuevos
     - Actualiza métricas de tweets existentes
3. **Firestore** almacena:
   - Collection `tweets`: Tweets guardados
   - Collection `polling_state`: Estado del último polling

## Colecciones de Firestore

### Collection: `tweets`

Document ID: `{username}_{tweet_id}`
```json
{
  "tweet_id": "1234567890",
  "text": "Texto del tweet...",
  "text_length": 250,
  "author_username": "InvictosSomos",
  "author_name": "Invictos Somos",
  "verified": true,
  "likes": 1500,
  "retweets": 234,
  "replies": 45,
  "quotes": 12,
  "created_at": "2025-11-09T14:30:00Z",
  "discovered_at": "2025-11-09T15:00:00Z",
  "updated_at": "2025-11-09T15:00:00Z",
  "last_check_at": "2025-11-09T16:00:00Z",
  "schema_version": "1.0"
}
```

### Collection: `polling_state`

Document ID: `{username}`
```json
{
  "username": "InvictosSomos",
  "last_check_at": "2025-11-09T15:00:00Z",
  "last_stats": {
    "saved": 2,
    "updated": 1,
    "skipped": 0
  },
  "total_tweets_saved": 150,
  "total_tweets_updated": 45
}
```

## Seguridad

- **Bearer Token**: Encriptado en Secret Manager
- **Service Account**: Permisos mínimos (least privilege)
- **Cloud Function**: No accesible públicamente
- **Firestore**: Reglas de seguridad por defecto

## Escalabilidad

- **max-instances=1**: Una ejecución a la vez (evita rate limits)
- **Scale to zero**: Se apaga cuando no ejecuta
- **Firestore**: Escala automáticamente

## Costos

- **Cloud Functions**: $0 (dentro de 2M invocaciones gratis)
- **Firestore**: $0 (dentro de 1GB gratis)
- **Scheduler**: $0 (dentro de 3 jobs gratis)
- **Secret Manager**: $0 (dentro de 6 secrets gratis)
- **Total**: $0/mes ✅