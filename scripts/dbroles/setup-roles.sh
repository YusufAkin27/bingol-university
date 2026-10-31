#!/usr/bin/env bash
# T-149 (A8-12): PostgreSQL rol ayrimini kurar / dogrular. ASCII, tekrar calistirilabilir.
#
#   OWNER_PASSWORD=... APP_PASSWORD=... BACKUP_PASSWORD=... bash scripts/dbroles/setup-roles.sh apply
#   bash scripts/dbroles/setup-roles.sh verify
#
# Baglanti: varsayilan olarak PSQL ortam degiskeni; yoksa `psql` (PGHOST/PGUSER/PGPASSWORD/PGDATABASE ile).
# Compose icindeki PostgreSQL icin:
#   PSQL='docker compose -f docker-compose.prod.yml exec -T postgres psql -U bingol -d bingol' bash scripts/dbroles/setup-roles.sh apply
# Parolalar komut satirina YAZILMAZ (stdin ile gider); yalniz [A-Za-z0-9_-] ve >=16 karakter kabul edilir.
# ONCE STAGING (K-28). Uretimde: yedek al, bakim penceresi, uygulamayi durdur -> apply -> .env'yi guncelle -> baslat.
set -euo pipefail

MODE="${1:-}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PSQL="${PSQL:-psql}"
DBNAME="${DBNAME:-bingol}"

check_pw() {
  local name="$1" val="${!1:-}"
  if [[ ! "$val" =~ ^[A-Za-z0-9_-]{16,}$ ]]; then
    echo "HATA: $name en az 16 karakter ve yalniz [A-Za-z0-9_-] olmali (bos/kisa/ozel karakterli olamaz)" >&2
    exit 2
  fi
}

case "$MODE" in
  apply)
    check_pw OWNER_PASSWORD
    check_pw APP_PASSWORD
    check_pw BACKUP_PASSWORD
    if [[ "$OWNER_PASSWORD" == "$APP_PASSWORD" || "$APP_PASSWORD" == "$BACKUP_PASSWORD" || "$OWNER_PASSWORD" == "$BACKUP_PASSWORD" ]]; then
      echo "HATA: uc rolun parolasi birbirinden farkli olmali" >&2
      exit 2
    fi
    {
      printf "\\\\set owner_pw '%s'\n" "$OWNER_PASSWORD"
      printf "\\\\set app_pw '%s'\n" "$APP_PASSWORD"
      printf "\\\\set backup_pw '%s'\n" "$BACKUP_PASSWORD"
      printf "\\\\set dbname '%s'\n" "$DBNAME"
      cat "$DIR/roles.sql"
    } | $PSQL -v ON_ERROR_STOP=1 -X -q
    echo "rol ayrimi uygulandi; simdi dogrulayin: bash scripts/dbroles/setup-roles.sh verify"
    ;;
  verify)
    cat "$DIR/verify-roles.sql" | $PSQL -v ON_ERROR_STOP=1 -X -q
    ;;
  *)
    echo "kullanim: [OWNER_PASSWORD=.. APP_PASSWORD=.. BACKUP_PASSWORD=..] $0 apply|verify" >&2
    exit 64
    ;;
esac
