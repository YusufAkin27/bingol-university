#!/usr/bin/env bash
# TASLAK: docs/openapi.json -> Dart modelleri (yalniz modeller; istemci uretilmez). Bkz. docs/MOBILE_CODEGEN.md
# Varsayilan: komutu yazdirir. Calistirmak icin RUN=1 (Docker gerekir). Cikti: mobile/lib/generated/models (elle duzenlenmez).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${OUT:-mobile/lib/generated}"
CMD=(docker run --rm -v "$(pwd -W 2>/dev/null || pwd):/local" openapitools/openapi-generator-cli:v7.10.0 generate
  -i /local/docs/openapi.json -g dart-dio -o "/local/$OUT"
  --global-property models,supportingFiles=false
  --additional-properties=pubName=bu_api_models,nullSafe=true,serializationLibrary=json_serializable)
if [ "${RUN:-0}" = 1 ]; then
  MSYS_NO_PATHCONV=1 "${CMD[@]}"
  echo "Modeller: $OUT (sonra: flutter pub run build_runner build, C:\\bu_mobile yolundan)"
else
  echo "${CMD[*]}"
  echo "(calistirmak icin RUN=1)"
fi
