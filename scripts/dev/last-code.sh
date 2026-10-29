#!/usr/bin/env bash
# Yerel gelistirme: son dogrulama / sifre sifirlama kodunu ve e-postasini backend loguna bakarak yazar.
# Yalniz YEREL yigin icindir (MAIL_ENABLED=false iken kod log'a duser; uretimde log'a yazilmaz, sir degildir).
# Kullanim: ./scripts/dev/last-code.sh [compose-proje-adi] [kac-satir]     (varsayilan: auth1, 3)
#   Ornek cikti:  2026-10-29T16:17:12  seed.yeni@bingol.edu.tr  KOD=482913
set -eu
PROJECT="${1:-auth1}"
COUNT="${2:-3}"
cd "$(dirname "$0")/../.."
docker compose -p "$PROJECT" logs --no-color --tail 2000 backend 2>/dev/null \
  | grep -F '[DEV]' \
  | grep -E '[0-9]{6}' \
  | tail -n "$COUNT" \
  | while IFS= read -r line; do
      when=$(printf '%s' "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}' | head -1 || true)
      body=${line#*\[DEV\]}
      mail=$(printf '%s' "$body" | grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+' | head -1 || true)
      code=$(printf '%s' "$body" | grep -oE '[0-9]{6}' | head -1 || true)
      printf '%s  %s  KOD=%s\n' "${when:--}" "${mail:--}" "${code:--}"
    done
