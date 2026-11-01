#!/usr/bin/env bash
# CI plani (CD1): hangi agir isler kosmali? Cikti GITHUB_OUTPUT'a (yoksa stdout'a) "anahtar=true|false" satirlari.
#
# Girdi (ortam): EVENT (push|pull_request|workflow_dispatch), REF_NAME, REF_TYPE (branch|tag), PROD_BRANCH,
#                BEFORE (push: onceki uc), SHA (hedef commit). PR'da calisma agaci birlestirme commit'i olmalidir
#                (actions/checkout varsayilani, fetch-depth >= 2): degisiklik = HEAD^1..HEAD.
#
# Kural ozeti:
#   - elle tetikleme / v* etiketi            -> hepsi true
#   - uretim dalina push                     -> backend+web+docker+infra true (dagitimin kapisi), mobile yalniz mobile/** degistiyse
#   - pull_request                           -> dosya yoluna gore (backend/**, web/** + docs/openapi.json, mobile/**, infra)
#   - diger dallara push (feature)           -> hepsi false: yalniz hafif kapi (sir taramasi + is akisi sozdizimi) kosar
# Degisen dosya listesi bulunamazsa guvenli taraf: ilgili is KOSAR (true).
set -euo pipefail

EVENT="${EVENT:?EVENT gerekli}"; REF_NAME="${REF_NAME:-}"; REF_TYPE="${REF_TYPE:-branch}"
PROD_BRANCH="${PROD_BRANCH:-main}"; BEFORE="${BEFORE:-}"; SHA="${SHA:-HEAD}"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"

backend=false; web=false; mobile=false; infra=false; docker=false; heavy=false

emit() {
  {
    echo "backend=$backend"; echo "web=$web"; echo "mobile=$mobile"; echo "infra=$infra"
    echo "docker=$docker"; echo "heavy=$heavy"
  } >> "$OUT"
  echo "plan: event=$EVENT ref=$REF_NAME backend=$backend web=$web mobile=$mobile infra=$infra docker=$docker"
}

all_true() { backend=true; web=true; mobile=true; infra=true; docker=true; heavy=true; }

# Degisen dosyalar -> bayraklar
apply_files() { # stdin: dosya yollari
  local f
  while IFS= read -r f; do
    case "$f" in
      backend/*) backend=true;;
    esac
    case "$f" in
      web/*|docs/openapi.json) web=true;;
    esac
    case "$f" in
      mobile/*) mobile=true;;
    esac
    case "$f" in
      docker-compose*.yml|deploy/*|scripts/ci/*|scripts/test-ci-deploy.sh|.github/*|scripts/backup/*|scripts/warmup.sh) infra=true;;
    esac
  done
}

if [ "$EVENT" = workflow_dispatch ] || [ "$REF_TYPE" = tag ]; then
  all_true; emit; exit 0
fi

if [ "$EVENT" = pull_request ]; then
  if files="$(git diff --name-only HEAD^1 HEAD 2>/dev/null)" && [ -n "$files" ]; then
    printf '%s\n' "$files" | apply_files
    # Imaj derlemesi: uygulama kodu ya da Dockerfile/compose degistiyse
    if [ "$backend" = true ] || [ "$web" = true ] || [ "$infra" = true ]; then docker=true; fi
  else
    all_true
  fi
  [ "$backend" = true ] || [ "$web" = true ] || [ "$mobile" = true ] || [ "$infra" = true ] && heavy=true
  emit; exit 0
fi

if [ "$EVENT" = push ] && [ "$REF_NAME" = "$PROD_BRANCH" ]; then
  backend=true; web=true; infra=true; docker=true; heavy=true
  zero='0000000000000000000000000000000000000000'
  if [ -n "$BEFORE" ] && [ "$BEFORE" != "$zero" ] \
     && { git cat-file -e "$BEFORE^{commit}" 2>/dev/null || git fetch --no-tags --depth=1 origin "$BEFORE" 2>/dev/null; } \
     && files="$(git diff --name-only "$BEFORE" "$SHA" 2>/dev/null)"; then
    if printf '%s\n' "$files" | grep -q '^mobile/'; then mobile=true; fi
  else
    mobile=true   # aralik bilinmiyor: guvenli taraf
  fi
  emit; exit 0
fi

# feature dali ya da baska olay: yalniz hafif kapi
emit
