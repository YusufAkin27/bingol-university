#!/usr/bin/env bash
# Medya hatti (T1) saldiri + avatar akisi duman betigi. Tekrar calistirilabilir.
# Kullanim: BASE=http://localhost:8101 COMPOSE_PROJECT_NAME=wt_t1 ./scripts/media-attacks.sh
# Onkosul: compose yigini ayakta, MAIL_ENABLED=false (dogrulama kodu log'dan okunur), node kurulu.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
TMP="$WORK/body.out"
SFX=$(date +%s)$RANDOM

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
win() { cygpath -m "$1" 2>/dev/null || echo "$1"; }

docker compose exec -T redis redis-cli flushall >/dev/null 2>&1
node "$HERE/media-fixtures.js" "$WORK/fx" >/dev/null || { echo "fixture uretilemedi"; exit 1; }
FX="$WORK/fx"
cp "$HERE/fixtures/media/exif-gps.jpg" "$HERE/fixtures/media/tiny.webp" "$FX/"

register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$t"
}

# up TOKEN DOSYA TUR [DIL] -> HTTP kodu; govde $TMP'de
up() {
  # avatar yukleme limiti (10/saat/kullanici) cok sayida saldiri denemesini engellemesin
  docker compose exec -T redis redis-cli --scan --pattern 'rl:avatar*' | while read -r k; do docker compose exec -T redis redis-cli del "$k" >/dev/null; done
  curl -s -o "$TMP" -w '%{http_code}' -X POST -H "Authorization: Bearer $1" ${4:+-H "Accept-Language: $4"} \
    -F "file=@$(win "$FX/$2");type=$3" $A/users/me/avatar
}
avatar_of() { curl -s -H "Authorization: Bearer $1" $A/users/me | grep -o '"avatarUrl":"[^"]*' | cut -d'"' -f4; }
errcode() { grep -o '"code":"[^"]*' "$TMP" | cut -d'"' -f4; }

T1=$(register "media1$SFX@bingol.edu.tr" "Medya Bir")
T2=$(register "media2$SFX@bingol.edu.tr" "Medya Iki")
T3=$(register "media3$SFX@bingol.edu.tr" "Medya Uc")
T4=$(register "media4$SFX@bingol.edu.tr" "Medya Dort")
[ -z "$T1$T2$T3$T4" ] && { echo "kullanici hazirlanamadi"; exit 1; }

echo "== gecerli yukleme (PNG, JPEG+EXIF, WebP)"
check "png avatar" 200 "$(up "$T1" unique-a.png image/png)"
URL=$(avatar_of "$T1")
echo "  url: $URL"
check "url icerik ozetli (40 hex .jpg)" 1 "$(echo "$URL" | grep -cE '^/files/avatars/[0-9a-f]{40}\.jpg$')"
check "avatar servis 200" 200 "$(curl -s -o "$WORK/a.jpg" -w '%{http_code}' "$BASE$URL")"
check "Content-Type image/jpeg" "image/jpeg" "$(curl -sI "$BASE$URL" | tr -d '\r' | grep -i '^content-type' | cut -d' ' -f2)"
check "nosniff basligi" 1 "$(curl -sI "$BASE$URL" | grep -ci '^x-content-type-options: nosniff')"
THUMB=$(echo "$URL" | sed 's/\.jpg$/-t.jpg/')
check "kucuk resim 200" 200 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE$THUMB")"
check "JPEG sihirli bayt" "ffd8ff" "$(head -c 3 "$WORK/a.jpg" | od -An -tx1 | tr -d ' \n')"

check "EXIF/GPS'li jpeg kabul" 200 "$(up "$T1" exif-gps.jpg image/jpeg)"
EURL=$(avatar_of "$T1")
curl -s -o "$WORK/exif-out.jpg" "$BASE$EURL"
check "cikti SECRETGPS icermez" 0 "$(grep -c 'SECRETGPS' "$WORK/exif-out.jpg")"
check "cikti Exif icermez" 0 "$(grep -c 'Exif' "$WORK/exif-out.jpg")"
check "webp kabul" 200 "$(up "$T1" tiny.webp image/webp)"
check "octet-stream + gercek png kabul" 200 "$(up "$T1" unique-b.png application/octet-stream)"

echo "== sikistirma (avatar max-stored-bytes varsayilan 150 KB)"
check "gurultulu 600x600 png kabul" 200 "$(up "$T2" noise.png image/png)"
NURL=$(avatar_of "$T2")
SZ=$(curl -s -o /dev/null -w '%{size_download}' "$BASE$NURL")
echo "  saklanan boyut: $SZ bayt"
[ "$SZ" -le 153600 ] && check "saklanan <= 150 KB" ok ok || check "saklanan <= 150 KB" ok "$SZ"
check "icerik ayni ise ayni url (tekrar yazmaz)" "$NURL" "$( up "$T2" noise.png image/png >/dev/null; avatar_of "$T2")"

echo "== saldirilar (hepsi reddedilmeli)"
check "svg (image/svg+xml)" 400 "$(up "$T3" evil.svg image/svg+xml)"
check "svg + sahte image/png" 400 "$(up "$T3" evil.svg image/png)"
check "html .png adi + image/png" 400 "$(cp "$FX/evil.html" "$FX/fake.png"; up "$T3" fake.png image/png)"
check "html text/html" 400 "$(up "$T3" evil.html text/html)"
check "polyglot gif" 400 "$(up "$T3" polyglot.gif image/gif)"
check "polyglot gif + sahte image/png" 400 "$(up "$T3" polyglot.gif image/png)"
check "gercek png ama .gif uzantisi" 400 "$(cp "$FX/unique-c.png" "$FX/x.gif"; up "$T3" x.gif image/png)"
check "bos dosya" 400 "$(up "$T3" empty.png image/png)"
check "bozuk png" 400 "$(up "$T3" corrupt.png image/png)"
check "bozuk png kodu IMAGE_CORRUPT" IMAGE_CORRUPT "$(errcode)"
check "boyut bombasi 20000x20000" 400 "$(up "$T3" bomb.png image/png)"
check "boyut bombasi kodu" IMAGE_TOO_MANY_PIXELS "$(errcode)"
check "36 MP png" 400 "$(up "$T3" bigdim.png image/png)"
check "3 MB dosya (avatar siniri 2 MB)" 413 "$(up "$T3" huge.png image/png)"
check "413 kodu" FILE_TOO_LARGE "$(errcode)"
check "cevirili hata (en)" 1 "$(up "$T4" corrupt.png image/png en >/dev/null; grep -c 'could not be read' "$TMP")"
check "cevirili hata (ar)" 1 "$(up "$T4" corrupt.png image/png ar >/dev/null; LC_ALL=C grep -c -P '"message":"\xd8' "$TMP")"
check "yetkisiz yukleme" 401 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -F "file=@$(win "$FX/unique-c.png");type=image/png" $A/users/me/avatar)"
check "sonuclar profilde avatar degismedi" "$NURL" "$(avatar_of "$T2")"

echo "== artik veri atilir"
check "png + sonuna betik kabul (temizlenir)" 200 "$(up "$T3" png-trailing.png image/png)"
PURL=$(avatar_of "$T3")
curl -s -o "$WORK/p.jpg" "$BASE$PURL"
check "cikti <script icermez" 0 "$(grep -c '<script' "$WORK/p.jpg")"
check "cikti <?php icermez" 0 "$(grep -c '<?php' "$WORK/p.jpg")"

echo "== ozel depo disaridan erisilemez"
check "/files/_private" 404 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/files/_private/chat/a.jpg")"
check "imzasiz /files/p" 404 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/files/p/chat/00000000-0000-0000-0000-000000000000.jpg")"
check "sahte imza" 404 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/files/p/chat/00000000-0000-0000-0000-000000000000.jpg?exp=9999999999&sig=abc")"
check "yol gezintisi" 404 "$(curl -s -o /dev/null -w '%{http_code}' --path-as-is "$BASE/files/avatars/../../etc/passwd")"

echo "== eszamanli yukleme (6 paralel, ayni dosya)"
for i in 1 2 3 4 5 6; do
  curl -s -o "$WORK/par$i.out" -w '%{http_code}\n' -X POST -H "Authorization: Bearer $T4" \
    -F "file=@$(win "$FX/unique-a.png");type=image/png" $A/users/me/avatar > "$WORK/par$i.code" &
done
wait
OKN=$(cat "$WORK"/par*.code | grep -c '^200$')
check "6 paralel yukleme 200" 6 "$OKN"
check "paralel sonrasi tek url" 1 "$(cat "$WORK"/par*.out | grep -o '"avatarUrl":"[^"]*' | sort -u | wc -l | tr -d ' ')"
curl -s -o "$WORK/par.jpg" "$BASE$(avatar_of "$T4")"
check "paralel sonrasi dosya saglam (JPEG)" "ffd8ff" "$(head -c 3 "$WORK/par.jpg" | od -An -tx1 | tr -d ' \n')"

echo "== avatar degistirme / silme (eski dosya temizligi)"
RA=$(register "media5$SFX@bingol.edu.tr" "Medya Bes")
up "$RA" unique-b.png image/png >/dev/null
OLD=$(avatar_of "$RA")
echo "  eski: $OLD  (graceSeconds dolana kadar bekleniyor)"
sleep 12
check "yeni avatar" 200 "$(up "$RA" unique-c.png image/png)"
NEW=$(avatar_of "$RA")
check "url degisti" 1 "$([ "$OLD" != "$NEW" ] && echo 1 || echo 0)"
check "eski dosya silindi (baska yerde kullanilmiyor)" 404 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE$OLD")"
check "yeni dosya duruyor" 200 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE$NEW")"
sleep 11
check "DELETE avatar" 200 "$(curl -s -o "$TMP" -w '%{http_code}' -X DELETE -H "Authorization: Bearer $RA" $A/users/me/avatar)"
check "avatarUrl null" 1 "$(grep -c '"avatarUrl":null' "$TMP")"
check "profilde avatar yok" "" "$(avatar_of "$RA")"
check "silinen dosya 404" 404 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE$NEW")"
check "DELETE tekrar (idempotent)" 200 "$(curl -s -o /dev/null -w '%{http_code}' -X DELETE -H "Authorization: Bearer $RA" $A/users/me/avatar)"
check "DELETE yetkisiz" 401 "$(curl -s -o /dev/null -w '%{http_code}' -X DELETE $A/users/me/avatar)"

rm -rf "$WORK"
[ "$FAIL" = 0 ] && echo "TUMU GECTI" || { echo "BASARISIZ"; exit 1; }
