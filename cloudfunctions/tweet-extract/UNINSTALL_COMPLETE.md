# Desinstalación Completa

Guía para eliminar **TODO** el sistema.

---

## ⚠️ ADVERTENCIA

Esto elimina PERMANENTEMENTE:
- ✅ Cloud Function
- ✅ Cloud Scheduler
- ✅ Service Account
- ✅ Secrets
- ✅ Datos de Firestore
- ✅ APIs (opcional)
- ✅ Proyecto (opcional)

**Los datos NO se pueden recuperar.**

---

## OPCIÓN 1: DESINSTALACIÓN RÁPIDA

Elimina recursos pero mantiene proyecto y APIs.
```bash
./teardown.sh
```

Escribir `DELETE` para confirmar.

**Elimina:**
- ✅ Cloud Function
- ✅ Scheduler
- ✅ Service Account
- ✅ Secret
- ❌ APIs (quedan)
- ❌ Proyecto (queda)

---

## OPCIÓN 2: DESINSTALACIÓN COMPLETA

### Paso 1: Ejecutar teardown
```bash
./teardown.sh
```

Escribir `DELETE`.

---

### Paso 2: Eliminar Firestore
```bash
gcloud firestore databases delete \
    --database='(default)' \
    --project=TU_PROJECT_ID
```

Confirmar escribiendo el nombre del database.

⚠️ **Elimina TODOS los datos.**

---

### Paso 3: Deshabilitar APIs
```bash
source .env

gcloud services disable cloudfunctions.googleapis.com --project=$GCP_PROJECT_ID
gcloud services disable cloudscheduler.googleapis.com --project=$GCP_PROJECT_ID
gcloud services disable firestore.googleapis.com --project=$GCP_PROJECT_ID
gcloud services disable secretmanager.googleapis.com --project=$GCP_PROJECT_ID
gcloud services disable cloudbuild.googleapis.com --project=$GCP_PROJECT_ID
gcloud services disable run.googleapis.com --project=$GCP_PROJECT_ID
gcloud services disable artifactregistry.googleapis.com --project=$GCP_PROJECT_ID
```

⚠️ **Puede tomar varios minutos.**

---

### Paso 4: Eliminar Proyecto (Opcional)

⚠️ **IRREVERSIBLE - Elimina TODO el proyecto**
```bash
gcloud projects delete TU_PROJECT_ID
```

Confirmar escribiendo el Project ID.

El proyecto se marca para eliminación por 30 días, luego se borra permanentemente.

---

## VERIFICACIÓN

### Verificar recursos eliminados
```bash
# Functions
gcloud functions list --project=TU_PROJECT_ID
# Esperado: "Listed 0 items."

# Scheduler
gcloud scheduler jobs list --location=us-central1
# Esperado: "Listed 0 items."

# Service Accounts
gcloud iam service-accounts list | grep twitter-poller
# Esperado: (vacío)

# Secrets
gcloud secrets list
# Esperado: "Listed 0 items."
```

---

### Verificar en Console

1. **Functions:** https://console.cloud.google.com/functions
   - Debe decir: "No functions found"

2. **Scheduler:** https://console.cloud.google.com/cloudscheduler
   - Debe decir: "No jobs found"

3. **Firestore:** https://console.cloud.google.com/firestore
   - Debe decir: "No database"

4. **IAM:** https://console.cloud.google.com/iam-admin/serviceaccounts
   - NO debe aparecer "twitter-poller-sa"

---

## LIMPIAR ARCHIVOS LOCALES
```bash
# Eliminar archivos sensibles
rm .env
rm .function-url
rm -rf logs/

# Eliminar proyecto completo (opcional)
cd ..
rm -rf cloudfunctions/tweet-extract/
```

---

## CANCELAR FACTURACIÓN (Opcional)

⚠️ **Cierra TODA tu cuenta de facturación de GCP**

1. Ir a: https://console.cloud.google.com/billing
2. Seleccionar cuenta de facturación
3. Click en "Close billing account"
4. Confirmar

---

## CHECKLIST DE DESINSTALACIÓN

- [ ] Ejecutado `./teardown.sh`
- [ ] Firestore database eliminado
- [ ] APIs deshabilitadas
- [ ] Proyecto eliminado (opcional)
- [ ] Archivo .env eliminado
- [ ] Carpeta eliminada (opcional)
- [ ] Facturación cerrada (opcional)

---

## VERIFICAR COSTOS

Después de eliminar, verificar que no hay cargos:

1. Ir a: https://console.cloud.google.com/billing/reports
2. Filtrar por proyecto
3. Verificar últimos 7 días
4. Debe mostrar: **$0.00**

Si ves cargos:
- Verificar que eliminaste TODOS los recursos
- Esperar 24-48 horas (pueden aparecer cargos retrasados)
- Si continúa, contactar soporte

---

## 🎉 DESINSTALACIÓN COMPLETA

Tu cuenta de GCP está limpia.

**Costos:** $0.00/mes ✅