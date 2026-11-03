#!/usr/bin/env bash
# T5 guvenlik denetimi: avatar yukleme (POST /api/users/me/avatar) saldiri testleri.
# Kullanim: BASE=http://localhost:8105 ./scripts/security/upload-attacks.sh
# Tekrar calistirilabilir; test dosyalarini gecici dizine yazar, sunucuda kendi avatarini degistirir.
set -u
BASE=${BASE:-http://localhost:8105}
A=$BASE/api
PASS=Sifre1234
RUN=$(date +%s)
# mktemp Windows/MSYS yol donusumunde curl ile sorun cikarabilir; depo icinde sabit, gocidnore'lu bir
# gecici klasor kullanilir (betik sonunda silinir).
FIX="$(dirname "$0")/.fixtures-tmp"
rm -rf "$FIX"; mkdir -p "$FIX"

pass() { echo "[OK]      $1"; }
fail() { echo "[FINDING] $1"; }
info() { echo "[info]    $1"; }

node "$(dirname "$0")/make-upload-fixtures.js" "$FIX" >/dev/null

mk_user() {
  local email=$1 name=$2
  curl -s -o /dev/null -X POST -H 'Content-Type: application/json' "$A/auth/register" \
    -d "{\"email\":\"$email\",\"password\":\"$PASS\",\"displayName\":\"$name\",\"acceptTerms\":true}"
  sleep 1
  local code
  code=$(docker compose logs backend 2>&1 | grep "$email icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  [ -n "$code" ] && curl -s -o /dev/null -X POST -H 'Content-Type: application/json' "$A/auth/verify-email" \
    -d "{\"email\":\"$email\",\"code\":\"$code\",\"password\":\"$PASS\"}"
}
login() {
  curl -s -X POST -H 'Content-Type: application/json' "$A/auth/login" \
    -d "{\"email\":\"$1\",\"password\":\"$PASS\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}

EMAIL="sec-t5-upload-$RUN@bingol.edu.tr"
mk_user "$EMAIL" "Upload Tester"
TOKEN=$(login "$EMAIL")
if [ -z "$TOKEN" ]; then
  echo "[HATA] test kullanicisi hazirlanamadi (olasi rate limit; redis flushall deneyin)" >&2
  exit 1
fi

upload() { # file declared-content-type
  curl -s -o /tmp/t5_upload_resp.json -w '%{http_code}' -X POST -H "Authorization: Bearer $TOKEN" \
    -F "file=@$1;type=$2" "$A/users/me/avatar"
}

echo "=== 1) Sahte Content-Type: duz metin/JS dosyasini 'image/jpeg' olarak yukle ==="
CODE=$(upload "$FIX/fake-text-as-jpeg.bin" "image/jpeg")
if [ "$CODE" = "200" ] || [ "$CODE" = "201" ]; then
  fail "ORTA/YUKSEK: gercek bir JPEG olmayan dosya, Content-Type basligi 'image/jpeg' olarak sahte beyan edilince kabul edildi (HTTP $CODE) -> $(cat /tmp/t5_upload_resp.json). Sihirli bayt/ImageIO dogrulamasi YOK; LocalFileStorage.save yalnizca MultipartFile.getContentType() basligina guveniyor."
else
  pass "sahte Content-Type'li dosya reddedildi (HTTP $CODE)"
fi

echo "=== 2) Gercek SVG (XSS yuku), gercek Content-Type ile ==="
CODE=$(upload "$FIX/xss.svg" "image/svg+xml")
if [ "$CODE" = "200" ] || [ "$CODE" = "201" ]; then
  fail "KRITIK: image/svg+xml kabul edildi (SVG icinde <script> XSS calistirilabilir) -> $(cat /tmp/t5_upload_resp.json)"
else
  pass "image/svg+xml turu reddedildi (izinli tur degil, HTTP $CODE)"
fi

echo "=== 3) SVG icerigi ama Content-Type 'image/png' olarak sahte beyan ==="
CODE=$(upload "$FIX/xss.svg" "image/png")
if [ "$CODE" = "200" ] || [ "$CODE" = "201" ]; then
  URL=$(grep -o '"avatarUrl":"[^"]*' /tmp/t5_upload_resp.json | cut -d'"' -f4)
  fail "KRITIK: SVG/XSS icerigi 'image/png' olarak sahte beyan edilip kabul edildi -> $URL. Sunucudan nasil sunuldugunu kontrol edin:"
  if [ -n "$URL" ]; then
    SERVED_CT=$(curl -s -D - -o /tmp/t5_served.bin "$BASE$URL" | grep -i '^content-type')
    SERVED_BODY=$(head -c 100 /tmp/t5_served.bin)
    info "sunucudan donen Content-Type: $SERVED_CT ; govde baslangici: $SERVED_BODY"
    if echo "$SERVED_CT" | grep -qi 'image/png' && ! echo "$SERVED_BODY" | grep -qi '<svg\|<script'; then
      info "azaltici etken: FileController dosya UZANTISINA gore sabit Content-Type + X-Content-Type-Options: nosniff ile sunuyor; tarayici SVG/HTML olarak yorumlamiyor olabilir. Buna karsin kaynak dosya diskte zararli icerik olarak duruyor."
    fi
  fi
else
  pass "sahte beyanli SVG/PNG de reddedildi (HTTP $CODE)"
fi

echo "=== 4) GIF/HTML polyglot, 'image/webp' olarak sahte beyan ==="
CODE=$(upload "$FIX/polyglot.gif" "image/webp")
if [ "$CODE" = "200" ] || [ "$CODE" = "201" ]; then
  fail "ORTA: GIF/HTML polyglot dosyasi 'image/webp' olarak sahte beyan edilip kabul edildi -> $(cat /tmp/t5_upload_resp.json)"
else
  pass "polyglot dosya reddedildi (HTTP $CODE)"
fi

echo "=== 5) EXIF/GPS metaverisi temizleniyor mu? ==="
CODE=$(upload "$FIX/exif-gps.jpg" "image/jpeg")
if [ "$CODE" = "200" ] || [ "$CODE" = "201" ]; then
  URL=$(grep -o '"avatarUrl":"[^"]*' /tmp/t5_upload_resp.json | cut -d'"' -f4)
  if [ -n "$URL" ]; then
    curl -s -o /tmp/t5_exif_served.bin "$BASE$URL"
    if grep -q "GPSLatitude\|TEST-GPS-MARKER" /tmp/t5_exif_served.bin; then
      fail "ORTA (KVKK/gizlilik): yuklenen gorseldeki EXIF/GPS metaverisi sunucuda TEMIZLENMIYOR; sunulan dosyada orijinal GPS metni hala mevcut -> $URL"
    else
      pass "EXIF/GPS metaverisi sunulan dosyada bulunamadi (temizlenmis olabilir)"
    fi
  fi
else
  info "exif-gps.jpg kabul edilmedi (HTTP $CODE); EXIF testi atlandi"
fi

echo "=== 6) Boyut siniri (avatar icin 2 MB): 3 MB dosya ==="
CODE=$(upload "$FIX/oversized.bin" "image/jpeg")
if [ "$CODE" = "413" ] || [ "$CODE" = "400" ]; then
  pass "asiri buyuk dosya reddedildi (HTTP $CODE)"
else
  fail "ORTA: 3 MB (2 MB sinirinin uzerinde) dosya reddedilmedi (HTTP $CODE)"
fi

echo "=== 7) Bos dosya ==="
: > "$FIX/empty.jpg"
CODE=$(upload "$FIX/empty.jpg" "image/jpeg")
if [ "$CODE" = "400" ]; then pass "bos dosya reddedildi (HTTP $CODE)"; else fail "DUSUK: bos dosya reddedilmedi (HTTP $CODE)"; fi

echo "=== 8) Dosya adinda yol gezintisi denemesi (sunucu adi kendi uretir; dogrulama amacli) ==="
CODE=$(upload "$FIX/..-..-..-etc-passwd.jpg" "image/jpeg")
info "yol-gezintisi-benzeri dosya adiyla yukleme -> HTTP $CODE (sunucu UUID adi uretir, istemci adi guvenilmez; FINDING degilse risksiz)"

echo "=== 9) Esanli (concurrent) yukleme: yaris durumu / hiz limiti kontrolu ==="
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  upload "$FIX/exif-gps.jpg" "image/jpeg" > /tmp/t5_rl_$i.txt &
done
wait
RL_429=$(grep -l "429\|RATE_LIMITED" /tmp/t5_rl_*.txt 2>/dev/null | wc -l)
info "12 esanli yukleme sonrasi rate-limit sinyali gorulen istek sayisi (saatlik 10 siniri): $RL_429 (saat basi limit varsa bazilari 429 donmeli)"
rm -f /tmp/t5_rl_*.txt /tmp/t5_upload_resp.json /tmp/t5_served.bin /tmp/t5_exif_served.bin

rm -rf "$FIX"
echo "=== bitti ==="
