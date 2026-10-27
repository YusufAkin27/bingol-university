#!/usr/bin/env bash
# Onceki surume doner (update.sh'in kaydettigi .deploy/previous_ref). Kullanim:
#   bash scripts/deploy/rollback.sh [--auto] [--ref <git-etiket/commit>]
# NOT: Flyway migration'lari geri SARILMAZ. Sema degisikligi iceren surumden donuste veri uyumsuzlugu varsa
# yedekten geri yukleyin (docs/BACKUP_RESTORE.md). Migration'lar geriye uyumlu yazilir (ekle-kullan-kaldir).
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

ENV_FILE="${ENV_FILE:-.env.prod}"
PROJECT="${PROJECT:-bu}"
COMPOSE_FILES="${COMPOSE_FILES:--f docker-compose.prod.yml}"
REF=""; AUTO=0
while [ $# -gt 0 ]; do
  case "$1" in
    --auto) AUTO=1; shift;;
    --ref) REF="$2"; shift 2;;
    *) echo "bilinmeyen arguman: $1" >&2; exit 2;;
  esac
done
DC=(docker compose -p "$PROJECT" $COMPOSE_FILES --env-file "$ENV_FILE")
log() { printf '%s [rollback] %s\n' "$(date '+%F %T')" "$*"; }

[ -n "$REF" ] || REF="$(cat .deploy/previous_ref 2>/dev/null || true)"
[ -n "$REF" ] && [ "$REF" != none ] || { echo "geri alinacak surum bilinmiyor: --ref verin" >&2; exit 1; }

CUR="$(git rev-parse HEAD)"
if [ "$AUTO" = 0 ]; then
  echo "Mevcut: ${CUR:0:8}  ->  Geri alinacak: ${REF:0:8}"
  read -r -p "Devam? (evet yazin) " ans
  [ "$ans" = evet ] || { echo "iptal"; exit 1; }
fi

git checkout "$REF"
"${DC[@]}" build
"${DC[@]}" up -d --remove-orphans

t=0
while [ "$t" -lt 240 ]; do
  cid="$("${DC[@]}" ps -q backend | head -1)"
  st="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || echo none)"
  if [ "$st" = healthy ]; then
    log "TAMAM: ${REF:0:8} calisiyor (onceki: ${CUR:0:8}; git HEAD ayrik, duzeltme sonrasi 'git checkout <dal>')"
    exit 0
  fi
  sleep 5; t=$((t+5))
done
log "geri alinan surum de saglikli degil"
"${DC[@]}" logs --tail=60 backend || true
exit 1
