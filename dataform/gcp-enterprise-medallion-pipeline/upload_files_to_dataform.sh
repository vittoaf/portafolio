PROJECT_ID=$(gcloud config get-value project)
LOCATION="us-central1"
REPOSITORY="medallion-dataform-repo"
WORKSPACE="workspace-dev"
DIRECTORIO_LOCAL="definitions"

ACCESS_TOKEN=$(gcloud auth print-access-token)

find "$DIRECTORIO_LOCAL" -type f | while read -r file; do
  echo "Subiendo: $file..."
  
  # La API de Dataform requiere el contenido codificado en Base64
  BASE64_CONTENT=$(base64 -w 0 "$file")
  
  curl -s -X POST \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"contents\": \"$BASE64_CONTENT\"}" \
    "https://dataform.googleapis.com/v1beta1/projects/${PROJECT_ID}/locations/${LOCATION}/repositories/${REPOSITORY}/workspaces/${WORKSPACE}:writeFile?path=${file}" > /dev/null

done

echo "¡Carga completa!"