#!/usr/bin/env bash
# Guvenli rastgele sirlarla .env.prod (veya .env.staging) taslagi uretir. CIKTIYI EKRANA YAZMAZ; dosya izni 600.
# Kullanim: bash scripts/ops/gen-secrets.sh [--env prod|staging] [--out dosya] [--force]
# Uretilen: DB_PASSWORD, JWT_SECRET, ADMIN_PASSWORD, CRYPTO_MASTER_KEYS (k1), DEVICE_HMAC_KEY.
# Elle doldurulacaklar (DOMAIN, ACME_EMAIL, MAIL_*, FCM, BACKUP_AGE_RECIPIENT...) YER_TUTUCU olarak kalir.
# Uretilen sirlari HEMEN yedekleyin (docs/KEY_MANAGEMENT.md): CRYPTO_MASTER_KEYS kaybi = sifreli veri kaybi.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

ENVNAME=prod; OUT=""; FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --env) ENVNAME="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    --force) FORCE=1; shift;;
    *) echo "bilinmeyen arguman: $1" >&2; exit 2;;
  esac
done
case "$ENVNAME" in prod|staging) ;; *) echo "--env prod|staging" >&2; exit 2;; esac
TEMPLATE=".env.$ENVNAME.example"
[ -f "$TEMPLATE" ] || { echo "sablon yok: $TEMPLATE" >&2; exit 1; }
OUT="${OUT:-.env.$ENVNAME}"
if [ -e "$OUT" ] && [ "$FORCE" = 0 ]; then
  echo "$OUT zaten var; ezmek icin --force (mevcut sirlari KAYBETMEYIN)" >&2; exit 1
fi
command -v openssl >/dev/null || { echo "openssl gerekli" >&2; exit 1; }

# URL/env-guvenli: base64'ten + / = karakterleri ayiklanir (parola, JWT, HMAC); CRYPTO anahtari standart base64 kalir
rnd_alnum() { openssl rand -base64 "$(( $1 * 2 ))" | tr -dc 'A-Za-z0-9' | head -c "$1"; }
KEYID="k1"; [ "$ENVNAME" = staging ] && KEYID="s1"
DB_PASSWORD="$(rnd_alnum 32)"
JWT_SECRET="$(rnd_alnum 64)"
ADMIN_PASSWORD="$(rnd_alnum 24)"
DEVICE_HMAC_KEY="$(rnd_alnum 48)"
MASTER="$KEYID:$(openssl rand -base64 32)"

umask 077
TMP="$(mktemp "${OUT}.XXXXXX")"
chmod 600 "$TMP"
# sed yerine awk: degerler ozel karakter icermez ama base64 anahtar '/' ve '+' icerir
awk -v dbp="$DB_PASSWORD" -v jwt="$JWT_SECRET" -v adm="$ADMIN_PASSWORD" -v hm="$DEVICE_HMAC_KEY" \
    -v mk="$MASTER" -v kid="$KEYID" '
  /^DB_PASSWORD=/        { print "DB_PASSWORD=" dbp; next }
  /^JWT_SECRET=/         { print "JWT_SECRET=" jwt; next }
  /^ADMIN_PASSWORD=/     { print "ADMIN_PASSWORD=" adm; next }
  /^DEVICE_HMAC_KEY=/    { print "DEVICE_HMAC_KEY=" hm; next }
  /^CRYPTO_MASTER_KEYS=/ { print "CRYPTO_MASTER_KEYS=" mk; next }
  /^CRYPTO_ACTIVE_KEY_ID=/ { print "CRYPTO_ACTIVE_KEY_ID=" kid; next }
  { print }
' "$TEMPLATE" > "$TMP"
mv "$TMP" "$OUT"
chmod 600 "$OUT"

echo "Yazildi: $OUT (izin 600). Ekrana sir yazilmadi."
echo "Siradaki adimlar:"
echo "  1. $OUT icinde YER_TUTUCU/example degerlerini doldurun (DOMAIN, ACME_EMAIL, CORS_ORIGINS, PUBLIC_WEB_URL, MAIL_*, BACKUP_AGE_RECIPIENT)."
echo "  2. CRYPTO_MASTER_KEYS ve diger sirlari sifre yoneticisine + cevrimdisi kasaya YEDEKLEYIN (docs/KEY_MANAGEMENT.md)."
echo "  3. Yedek anahtari: age-keygen -o backup.age.key  (ozel anahtar sunucuda KALMASIN; genel anahtari BACKUP_AGE_RECIPIENT'e yazin)."
