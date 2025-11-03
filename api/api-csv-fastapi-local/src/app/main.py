from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.services.csv_loader import load_csv_as_dict

app = FastAPI(title="API CSV Local", version="1.0.0")

# Cargamos una vez al inicio (para recarga automática usar uvicorn --reload)
data_by_id = load_csv_as_dict()

class BulkRequest(BaseModel):
    ids: list[str]

@app.get("/items/{item_id}")
def get_item(item_id: str):
    item = data_by_id.get(item_id)
    if not item:
        raise HTTPException(status_code=404, detail="ID no encontrado")
    return item

@app.post("/items/bulk")
def get_items_bulk(payload: BulkRequest):
    result = []
    not_found = []
    for _id in payload.ids:
        row = data_by_id.get(_id)
        if row:
            result.append(row)
        else:
            not_found.append(_id)
    return {
        "found": result,
        "not_found": not_found,
        "total_requested": len(payload.ids),
        "total_found": len(result),
    }

@app.get("/search/items")
def search_items(ciudad: Optional[str] = None):
    """
    Filtra los registros por ciudad (ejemplo: /search/items?ciudad=Lima)
    """
    if not ciudad:
        raise HTTPException(status_code=400, detail="Debes indicar el parámetro 'ciudad'")

    # Filtramos (ignorando mayúsculas/minúsculas)
    coincidencias = [
        item for item in data_by_id.values()
        if item["ciudad"].lower() == ciudad.lower()
    ]

    if not coincidencias:
        raise HTTPException(status_code=404, detail=f"No se encontraron registros para la ciudad '{ciudad}'")

    return {
        "ciudad": ciudad,
        "total_encontrados": len(coincidencias),
        "resultados": coincidencias
    }

@app.get("/")
def root():
    return {"msg": "API CSV OK", "endpoints": ["/items/{id}", "/items/bulk"]}

@app.get("/meta/routes")
def list_routes():
    rutas = []
    for route in app.routes:
        # route.methods es un set, lo convertimos a lista
        rutas.append({
            "path": route.path,
            "methods": list(route.methods),
            "name": route.name,
        })
    # si quieres excluir los de FastAPI (docs, openapi), filtra aquí
    return {
        "total": len(rutas),
        "routes": rutas,
    }