#!/usr/bin/env bash
# Uretim guncellemesi: (yedek) -> kod/imaj cek -> yeniden baslat -> saglik kontrolu -> basarisizsa onceki surume don.
# NOT: URETIMDE dogru yol yerelden `scripts/deploy.sh`'tir (docs/DEPLOY.md bolum 0); bu betik sunucu icinde elle/staging icindir.
# Kullanim: bash scripts/deploy/update.sh [--first] [--ref <git-etiket/dal>] [--no-backup] [--env-file .env.prod]
#   Ortam: HEALTH_WAIT_BACKEND (sn, varsayilan 600) backend saglik bekleme suresi.
#   Staging: COMPOSE_FILES="-f docker-compose.prod.yml -f docker-compose.staging.yml" PROJECT=bu-staging ENV_FILE=.env.staging
# Geri alma durumu scripts/deploy/rollback.sh ile paylasilir: .deploy/previous_ref ve .deploy/previous_images
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

ENV_FILE="${ENV_FILE:-.env.prod}"
PROJECT="${PROJECT:-bu}"
# Soguk acilis (Flyway + Hibernate dogrulama) 262-465 sn surebilir: eski 240 sn bekleme yetmezdi. docker-compose.prod.yml
# healthcheck start_period (BACKEND_START_PERIOD, 360s) ile birlikte ayarlayin.
HEALTH_WAIT_BACKEND="${HEALTH_WAIT_BACKEND:-600}"
case "$HEALTH_WAIT_BACKEND" in ''|*[!0-9]*) echo "HEALTH_WAIT_BACKEND yalniz rakam (saniye) olmali" >&2; exit 2;; esac
COMPOSE_FILES="${COMPOSE_FILES:--f docker-compose.prod.yml}"
REF=""; FIRST=0; BACKUP=1
while [ $# -gt 0 ]; do
  case "$1" in
    --first) FIRST=1; shift;;
    --ref) REF="$2"; shift 2;;
    --no-backup) BACKUP=0; shift;;
    --env-file) ENV_FILE="$2"; shift 2;;
    *) echo "bilinmeyen arguman: $1" >&2; exit 2;;
  esac
done
# docker-compose.yml (kok dosya) ile birlestirme YASAK: backend:8080 ve web:8090 internete duz HTTP yayinlanir (Caddy atlanir).
case " $COMPOSE_FILES " in
  *" docker-compose.yml "*) echo "COMPOSE_FILES kok docker-compose.yml iceriyor: yalniz docker-compose.prod.yml (+ staging/monitoring bindirmeleri) kullanin" >&2; exit 2;;
esac
[ -f "$ENV_FILE" ] || { echo "$ENV_FILE yok (bash scripts/ops/gen-secrets.sh)" >&2; exit 1; }
DC=(docker compose -p "$PROJECT" $COMPOSE_FILES --env-file "$ENV_FILE")
mkdir -p .deploy
log() { printf '%s [deploy] %s\n' "$(date '+%F %T')" "$*"; }

wait_healthy() { # wait_healthy <servis> <saniye>
  local svc="$1" limit="$2" t=0 cid st
  while [ "$t" -lt "$limit" ]; do
    cid="$("${DC[@]}" ps -q "$svc" 2>/dev/null || true)"
    if [ -n "$cid" ]; then
      st="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || echo none)"
      if [ "$st" = healthy ]; then return 0; fi
    fi
    sleep 5; t=$((t+5))
  done
  return 1
}

check_site() { # disaridan HTTPS ve API sagligi
  local domain; domain="$(grep -E '^DOMAIN=' "$ENV_FILE" | cut -d= -f2-)"
  [ -n "$domain" ] || return 0
  curl -fsS -m 15 "https://$domain/api/status" >/dev/null 2>&1 || curl -fsS -m 15 "https://$domain/" >/dev/null 2>&1
}

# --- yapilandirma dogrulama ---
"${DC[@]}" config -q || { echo "compose yapilandirmasi gecersiz (eksik degisken?)" >&2; exit 1; }

# --- onceki durumu kaydet (geri alma icin) ---
PREV_REF="$(git rev-parse HEAD 2>/dev/null || echo none)"
echo "$PREV_REF" > .deploy/previous_ref
"${DC[@]}" images --format json 2>/dev/null > .deploy/previous_images.json || true
BACKEND_PREV_IMAGE="$(docker inspect -f '{{.Image}}' "$("${DC[@]}" ps -q backend 2>/dev/null | head -1)" 2>/dev/null || true)"
if [ -n "$BACKEND_PREV_IMAGE" ]; then
  docker tag "$BACKEND_PREV_IMAGE" bu-backend:previous 2>/dev/null || true
  echo "$BACKEND_PREV_IMAGE" > .deploy/previous_backend_image
fi

# --- yedek (Flyway geri sarilmaz: sema degisikliginden once) ---
if [ "$FIRST" = 0 ] && [ "$BACKUP" = 1 ]; then
  log "guncelleme oncesi yedek"
  "${DC[@]}" exec -T -u postgres backup /opt/backup/backup.sh || { echo "yedek basarisiz: --no-backup ile gecilebilir (onerilmez)" >&2; exit 1; }
fi

# --- kod cek ---
if [ -d .git ]; then
  git fetch --tags --prune
  if [ -n "$REF" ]; then git checkout "$REF"; else git pull --ff-only; fi
fi
NEW_REF="$(git rev-parse HEAD 2>/dev/null || echo none)"
log "surum: ${PREV_REF:0:8} -> ${NEW_REF:0:8}"

# --- imajlari derle/cek ve yeniden baslat ---
"${DC[@]}" pull --ignore-buildable --quiet 2>/dev/null || "${DC[@]}" pull --quiet 2>/dev/null || true
"${DC[@]}" build
"${DC[@]}" up -d --remove-orphans

# --- saglik ---
OK=1
wait_healthy backend "$HEALTH_WAIT_BACKEND" || { log "backend saglikli olmadi (${HEALTH_WAIT_BACKEND} sn)"; OK=0; }
if [ "$OK" = 1 ]; then
  sleep 5
  wait_healthy caddy 60 || { log "caddy saglikli degil"; OK=0; }
fi
if [ "$OK" = 1 ]; then check_site || { log "disaridan HTTPS kontrolu basarisiz (DNS/sertifika ilk kurulumda zaman alabilir)"; [ "$FIRST" = 1 ] || OK=0; }; fi

if [ "$OK" = 1 ]; then
  log "TAMAM: guncelleme basarili ($NEW_REF)"
  docker image prune -f >/dev/null 2>&1 || true
  exit 0
fi

# --- basarisiz: geri al ---
log "BASARISIZ. Son backend gunlugu:"
"${DC[@]}" logs --tail=40 backend || true
if [ "$FIRST" = 1 ]; then
  log "ilk kurulum: otomatik geri alma yok. Gunlukleri inceleyin: docker compose -p $PROJECT $COMPOSE_FILES logs"
  exit 1
fi
log "otomatik geri alma baslatiliyor"
ENV_FILE="$ENV_FILE" PROJECT="$PROJECT" COMPOSE_FILES="$COMPOSE_FILES" bash scripts/deploy/rollback.sh --auto || {
  log "GERI ALMA DA BASARISIZ: elle mudahale gerekli (docs/RUNBOOK.md 'Geri alma')"; exit 2; }
exit 1
