import os
from pathlib import Path
from google.cloud import dataform_v1beta1
import google.auth

_, project_id = google.auth.default()

client = dataform_v1beta1.DataformClient()

LOCATION = "us-central1"
REPOSITORY = "medallion-dataform-repo"
WORKSPACE = "workspace-dev"
LOCAL_DIR = Path("includes")

workspace_path = client.workspace_path(project_id, LOCATION, REPOSITORY, WORKSPACE)

for file_path in LOCAL_DIR.rglob("*"):
    if file_path.is_file():
        rel_path = file_path.as_posix()
        contents = file_path.read_bytes()
        
        request = dataform_v1beta1.WriteFileRequest(
            workspace=workspace_path,
            path=rel_path,
            contents=contents
        )
        client.write_file(request=request)
        print(f"Subido: {rel_path}")

print("Todos los archivos fueron cargados exitosamente.")