
# 🧩 API CSV Local con FastAPI

Una mini API hecha con **FastAPI** que permite consultar un archivo **CSV local** por:
- `ID` individual,
- `Ciudad`,
- o varios `IDs` a la vez (consulta masiva).

Incluye un script Python (`consultar-api.py`) para probar todos los endpoints desde tu máquina.

---

## 🚀 1. Requisitos previos

- Tener instalado **Python 3.10 o superior**
- Tener instalado **pip** (viene con Python)
- Tener instalado **Git** (para clonar el proyecto)

---

## ⚙️ 2. Instalación paso a paso

### 🧱 Paso 1 — Abrir la terminal (bash, PowerShell o CMD)

- En **Windows**, presiona `Inicio` → escribe “cmd” o “PowerShell” → presiona `Enter`
- En **Mac/Linux**, abre la app **Terminal**

Una vez abierta, muévete a la carpeta donde quieres guardar el proyecto, por ejemplo:

```bash
cd Documentos
```

---

### 🪣 Paso 2 — Clonar el repositorio desde GitHub

Ejecuta el siguiente comando (reemplaza con tu URL real del repositorio):

```bash
git clone https://github.com/tu-usuario/api-csv-fastapi-local.git
cd api-csv-fastapi-local
```

Si no tienes Git o prefieres hacerlo manualmente:
1. Entra a tu repositorio en GitHub.
2. Haz clic en **Code → Download ZIP**.
3. Extrae el ZIP y abre la carpeta extraída desde la terminal.

---

### 🐍 Paso 3 — Crear y activar entorno virtual

**Windows (PowerShell):**
```powershell
python -m venv venv
venv\Scripts\Activate
```

**Mac / Linux:**
```bash
python -m venv venv
source venv/bin/activate
```

> Para salir del entorno virtual:  
> `deactivate`

---

### 📦 Paso 4 — Instalar dependencias

Con el entorno activado, ejecuta:

```bash
pip install -r requirements.txt
```

---

### ⚡ Paso 5 — Ejecutar la API en local

Lanza el servidor de desarrollo con:

```bash
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000 --app-dir src
```

- `--reload`: reinicia automáticamente si cambias el código  
- `--app-dir src`: indica que el paquete principal está dentro de `src/`

📍 Luego abre tu navegador y entra en:  
👉 **http://127.0.0.1:8000/docs**

Allí verás la interfaz interactiva de Swagger con todos los endpoints.

---

### 💻 Paso 6 — Probar la API con el script `consultar-api.py`

Ejecuta el script cliente para probar los endpoints fácilmente:

```bash
python consultar-api.py
```

---

### 🧹 Paso 7 — Detener o limpiar

Para detener el servidor:  
`Ctrl + C`  

Para desactivar el entorno virtual:
```bash
deactivate
```

---

## ✅ Resumen rápido

| Acción | Comando |
|--------|----------|
| Clonar repositorio | `git clone https://github.com/vittoaf/portafolio.git` |
| Crear entorno virtual | `python -m venv venv` |
| Activar entorno | `venv\Scripts\Activate` *(Windows)* |
| Instalar dependencias | `pip install -r requirements.txt` |
| Ejecutar API | `uvicorn app.main:app --reload --app-dir src` |
| Probar endpoints | `python consultar-api.py` |
| Desactivar entorno | `deactivate` |

---

👨‍💻 **Listo para ejecutar localmente.**  
Tu API ya está completamente funcional, sin dependencias externas, y con ejemplo de cliente incluido.

---

## 🎥 Paso 8 — Ver el tutorial en YouTube

PRÓXIMAMENTE!!! Si prefieres seguir el paso a paso en video, puedes verlo aquí:  
👉 [Ver en YouTube](https://www.youtube.com/@leiaf2004)

En el video aprenderás:
- Cómo abrir la terminal y crear el entorno virtual  
- Cómo ejecutar la API con `uvicorn`  
- Cómo probar los endpoints desde el navegador y con `consultar-api.py`  
- Tips para subir tu proyecto a GitHub correctamente  

---
