#!/usr/bin/env bash
# Yonetim paneli API'leri icin uctan uca duman testi: kullanici yonetimi, rol/token, CSV, fakulte, kullanim takibi,
# analitik sayilari (bilinen test verisiyle), denetim kaydi, sozlesme/haber yonetimi, CORS, yetki kontrolleri.
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/smoke-admin.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL, calisan postgres/redis konteynerleri.
# Idempotent: her calistirmada benzersiz kullanici/fakulte adlari kullanilir, sonunda test verisi temizlenir.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-adminpw123}
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamali: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
# Yikici yonetici uclari sebep ister (app.admin.require-reason): her istege varsayilan sebep eklenir; sebepsiz davranis smoke-admin-*.sh betiklerinde sinanir.
curl() { command curl -H 'X-Admin-Reason: smoke testi duman betigi' "$@"; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
num() { grep -o "\"$1\":[0-9.]*" | head -1 | cut -d: -f2; }   # ilk "alan":sayi

# kayit + dogrulama -> access token (hesap varsa giris)
register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true,\"language\":\"${3:-tr}\"}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" |
      grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$t"
}

SFX=$RANDOM
FA="SmokeFakA$SFX"; FB="SmokeFakB$SFX"
E1="smk1x$SFX@bingol.edu.tr"; E2="smk2x$SFX@bingol.edu.tr"; E3="smk3x$SFX@bingol.edu.tr"; E4="smk4x$SFX@bingol.edu.tr"

echo "== yonetici ve baslangic degerleri"
TA=$(register "$ADMIN_EMAIL" "Yonetici" tr)
[ -n "$TA" ] || { echo "admin token yok (ADMIN_EMAILS ayarli mi? hesap farkli sifreyle mi?)"; exit 1; }
AAD="Authorization: Bearer $TA"
IDA=$(curl -s -H "$AAD" $A/admin/me | idof)
check "admin me" 200 "$(code -H "$AAD" $A/admin/me)"
has "admin me alanlari" "\"email\":\"$ADMIN_EMAIL\"" "$(curl -s -H "$AAD" $A/admin/me)"
sleep 2
OV0=$(curl -s -H "$AAD" $A/admin/analytics/overview)
TOTAL0=$(echo "$OV0" | num totalUsers); NEW0=$(echo "$OV0" | num today); DAU0=$(echo "$OV0" | num dau)
FB0=$(curl -s -H "$AAD" "$A/admin/analytics/engagement" | grep -o '"name":"screen_view","count":[0-9]*' | head -1 | cut -d: -f3)
FB0=${FB0:-0}
echo "  baslangic: toplam=$TOTAL0 bugun-yeni=$NEW0 dau=$DAU0 screen_view=$FB0"

echo "== fakulte listesi (yonetici ayari)"
check "fakulteler herkese acik" 200 "$(code $A/faculties)"
check "ayar: fakulte listesi" 204 "$(code -X PUT -H "$H" -H "$AAD" $A/admin/settings/faculties -d "{\"value\":\" $FA ;$FB;; $FA\"}")"
has "liste normalize (tekrarsiz, kirpilmis)" "[\"$FA\",\"$FB\"]" "$(curl -s $A/faculties)"
check "ayar: fazla uzun liste" 400 "$(code -X PUT -H "$H" -H "$AAD" $A/admin/settings/faculties -d "{\"value\":\"$(printf 'x%.0s' $(seq 1 1001))\"}")"
check "ayar: fakulte >120 karakter" 400 "$(code -X PUT -H "$H" -H "$AAD" $A/admin/settings/faculties -d "{\"value\":\"$(printf 'y%.0s' $(seq 1 121))\"}")"

echo "== kullanicilar (4 kayit)"
T1=$(register "$E1" "Smoke Bir" tr); T2=$(register "$E2" "Smoke Iki" tr); T3=$(register "$E3" "Smoke Uc" en); T4=$(register "$E4" "Smoke Dort" ar)
[ -n "$T1" ] && [ -n "$T2" ] && [ -n "$T3" ] && [ -n "$T4" ] || { echo "kayit basarisiz"; exit 1; }
A1="Authorization: Bearer $T1"; A2="Authorization: Bearer $T2"; A3="Authorization: Bearer $T3"; A4="Authorization: Bearer $T4"
ID1=$(curl -s -H "$A1" $A/users/me | idof); ID2=$(curl -s -H "$A2" $A/users/me | idof)
ID3=$(curl -s -H "$A3" $A/users/me | idof); ID4=$(curl -s -H "$A4" $A/users/me | idof)

echo "== profil: fakulte"
# Profil fakulte/bolum/sinifi artik akademik katalogla dogrulanir (ACADEMIC_INVALID); serbest metin yalniz API'de reddedilir.
# Eski (katalog oncesi) veriyi taklit etmek icin dagilim/suzgec/CSV testleri degerleri dogrudan veritabanina yazar.
check "serbest fakulte reddedilir (katalog)" 400 "$(code -X PATCH -H "$H" -H "$A1" $A/users/me -d "{\"faculty\":\"$FA\"}")"
SQLX() { docker compose exec -T postgres psql -U "${DB_USER:-bingol}" -d "${DB_NAME:-bingol}" -c "$1" >/dev/null 2>&1; }
SQLX "UPDATE app_user SET faculty='$FA', department='Bilgisayar', class_year=2 WHERE id=$ID1"
SQLX "UPDATE app_user SET faculty='$FA' WHERE id=$ID2"
SQLX "UPDATE app_user SET faculty='$FB', department='=SUM(1+1)' WHERE id=$ID3"
R=$(curl -s -X PATCH -H "$H" -H 'Accept-Language: en' -H "$A4" $A/users/me -d '{"faculty":"Uydurma Fakulte"}')
has "gecersiz fakulte kodu" '"code":"ACADEMIC_INVALID"' "$R"
has "gecersiz fakulte EN mesaji" "Invalid faculty" "$R"
check "gecersiz fakulte 400" 400 "$(code -X PATCH -H "$H" -H "$A4" $A/users/me -d '{"faculty":"Uydurma Fakulte"}')"
check "fakulte > 120 karakter" 400 "$(code -X PATCH -H "$H" -H "$A4" $A/users/me -d "{\"faculty\":\"$(printf 'z%.0s' $(seq 1 121))\"}")"
has "profilde fakulte" "\"faculty\":\"$FA\"" "$(curl -s -H "$A1" $A/users/me)"
has "baskasinin profilinde fakulte" "\"faculty\":\"$FA\"" "$(curl -s -H "$A2" $A/users/$ID1)"
# u3 bolumu formul benzeri (CSV enjeksiyonu testi; gorunen ad politikasi =,+,@ karakterlerini reddeder)
check "bolum formul API'de reddedilir (katalog)" 400 "$(code -X PATCH -H "$H" -H "$A3" $A/users/me -d '{"department":"=SUM(1+1)"}')"
check "gorunen ad formul reddi" 400 "$(code -X PATCH -H "$H" -H "$A3" $A/users/me -d '{"displayName":"=SUM(1+1)"}')"

echo "== yetki: anonim 401, normal kullanici 403"
for P in admin/me admin/users admin/users/$ID1 admin/users/export.csv admin/audit admin/news admin/legal/terms/versions admin/legal/acceptance-stats \
  admin/analytics/overview admin/analytics/registrations admin/analytics/active-users "admin/analytics/breakdown?dimension=faculty" \
  admin/analytics/engagement admin/analytics/retention admin/analytics/support admin/analytics/push admin/analytics/content; do
  check "anonim $P" 401 "$(code "$A/$P")"
  check "kullanici $P" 403 "$(code -H "$A1" "$A/$P")"
done
check "anonim rol 401" 401 "$(code -X PATCH -H "$H" $A/admin/users/$ID2/role -d '{"role":"ADMIN"}')"
check "kullanici rol 403" 403 "$(code -X PATCH -H "$H" -H "$A1" $A/admin/users/$ID2/role -d '{"role":"ADMIN"}')"
check "kullanici silme 403" 403 "$(code -X DELETE -H "$A1" $A/admin/users/$ID2)"
check "kullanici haber gizleme 403" 403 "$(code -X PATCH -H "$H" -H "$A1" $A/admin/news/1 -d '{"hidden":true}')"
check "anonim olay gonderme 401" 401 "$(code -X POST -H "$H" $A/analytics/events -d '{"events":[]}')"

echo "== kullanim olaylari"
check "olay gonder" 204 "$(code -X POST -H "$H" -H "$A1" $A/analytics/events -d '{"events":[{"name":"screen_view","screen":"home"},{"name":"screen_view","screen":"news","props":{"tab":"haber"}},{"name":"app_open"},{"name":"search","props":{"q_len":5}}]}')"
check "bos liste" 204 "$(code -X POST -H "$H" -H "$A1" $A/analytics/events -d '{"events":[]}')"
R=$(curl -s -X POST -H "$H" -H 'Accept-Language: en' -H "$A1" $A/analytics/events -d '{"events":[{"name":"Bad-Name"}]}')
has "gecersiz olay adi" '"code":"INVALID_EVENT"' "$R"
check "6 props 400" 400 "$(code -X POST -H "$H" -H "$A1" $A/analytics/events -d '{"events":[{"name":"x","props":{"a":"1","b":"2","c":"3","d":"4","e":"5","f":"6"}}]}')"
check "uzun deger 400" 400 "$(code -X POST -H "$H" -H "$A1" $A/analytics/events -d "{\"events\":[{\"name\":\"x\",\"props\":{\"a\":\"$(printf 'q%.0s' $(seq 1 101))\"}}]}")"
check "e-posta degeri 400" 400 "$(code -X POST -H "$H" -H "$A1" $A/analytics/events -d '{"events":[{"name":"x","props":{"who":"a@b.com"}}]}')"
EV51=$(printf '{"name":"e"},%.0s' $(seq 1 51)); EV51="[${EV51%,}]"
check "51 olay 400" 400 "$(code -X POST -H "$H" -H "$A1" $A/analytics/events -d "{\"events\":$EV51}")"
check "govde eksik 400" 400 "$(code -X POST -H "$H" -H "$A1" $A/analytics/events -d '{}')"
# u2 de ekran goruntuler (benzersiz kullanici sayisi)
check "olay u2" 204 "$(code -X POST -H "$H" -H "$A2" $A/analytics/events -d '{"events":[{"name":"screen_view","screen":"home"}]}')"
check "cihaz kaydi (platform dagilimi)" 204 "$(code -X POST -H "$H" -H "$A1" $A/devices -d "{\"fcmToken\":\"smoke-device-token-$SFX\",\"platform\":\"ANDROID\"}")"
sleep 3   # arka plan aktiflik yazimi

echo "== analitik: bilinen verilerle sayilar"
OV1=$(curl -s -H "$AAD" $A/admin/analytics/overview)
check "toplam kullanici +4" $((TOTAL0 + 4)) "$(echo "$OV1" | num totalUsers)"
check "bugun yeni +4" $((NEW0 + 4)) "$(echo "$OV1" | num today)"
check "dau +4 (u1..u4)" $((DAU0 + 4)) "$(echo "$OV1" | num dau)"
for K in verifiedUsers suspendedUsers newUsers activeUsers stickiness messages communities events openReports openTickets newFeedback pushCampaignsSent30d bookmarks devices; do
  has "overview.$K" "\"$K\"" "$OV1"
done
REG=$(curl -s -H "$AAD" $A/admin/analytics/registrations)
check "registrations: son gun = bugun yeni" "$((NEW0 + 4))" "$(echo "$REG" | grep -o '"count":[0-9]*' | tail -1 | cut -d: -f2)"
check "registrations: 30 nokta" 30 "$(echo "$REG" | grep -o '"date":' | wc -l | tr -d ' ')"
has "registrations: kumulatif son = toplam kayit" "\"cumulative\":" "$REG"
REG2=$(curl -s -H "$AAD" "$A/admin/analytics/registrations?from=2020-01-01&to=2020-01-03")
check "bos gunler 0 ile dolu (3 gun)" 3 "$(echo "$REG2" | grep -o '"count":0,' | wc -l | tr -d ' ')"
BF=$(curl -s -H "$AAD" "$A/admin/analytics/breakdown?dimension=faculty")
has "breakdown faculty A=2" "\"key\":\"$FA\",\"label\":\"$FA\",\"count\":2" "$BF"
has "breakdown faculty B=1" "\"key\":\"$FB\",\"label\":\"$FB\",\"count\":1" "$BF"
has "breakdown unknown anahtari" '"key":"unknown"' "$BF"
has "breakdown boyut adi" '"dimension":"faculty"' "$BF"
for D in department classYear language role status platform; do
  check "breakdown $D" 200 "$(code -H "$AAD" "$A/admin/analytics/breakdown?dimension=$D")"
done
has "breakdown platform ANDROID" '"key":"ANDROID"' "$(curl -s -H "$AAD" "$A/admin/analytics/breakdown?dimension=platform")"
has "breakdown language ar" '"key":"ar"' "$(curl -s -H "$AAD" "$A/admin/analytics/breakdown?dimension=language")"
check "breakdown gecersiz boyut" 400 "$(code -H "$AAD" "$A/admin/analytics/breakdown?dimension=password")"
check "breakdown boyut eksik" 400 "$(code -H "$AAD" "$A/admin/analytics/breakdown")"
AU=$(curl -s -H "$AAD" $A/admin/analytics/active-users)
check "active-users: bugunku dau" "$((DAU0 + 4))" "$(echo "$AU" | grep -o '"dau":[0-9]*' | tail -1 | cut -d: -f2)"
has "active-users wau/mau" '"wau":' "$AU"
EN=$(curl -s -H "$AAD" $A/admin/analytics/engagement)
FB1=$(echo "$EN" | grep -o '"name":"screen_view","count":[0-9]*' | head -1 | cut -d: -f3)
check "engagement: screen_view +3" $((FB0 + 3)) "${FB1:-0}"
has "engagement: ekranlar" '"screen":"home"' "$EN"
has "engagement: gunluk seri" '"searches":' "$EN"
for S in registered verified profileCompleted joinedCommunity sentMessage; do has "funnel $S" "\"step\":\"$S\"" "$EN"; done
check "funnel registered >= 4" 1 "$([ "$(echo "$EN" | grep -o '"step":"registered","count":[0-9]*' | cut -d: -f3)" -ge 4 ] && echo 1 || echo 0)"
RT=$(curl -s -H "$AAD" $A/admin/analytics/retention)
check "retention: 12 kohort" 12 "$(echo "$RT" | grep -o '"weekStart"' | wc -l | tr -d ' ')"
has "retention d1/d7/d30" '"d30":' "$RT"
has "support" '"avgFirstResponseMinutes":' "$(curl -s -H "$AAD" $A/admin/analytics/support)"
has "push" '"totals":{"campaigns":' "$(curl -s -H "$AAD" $A/admin/analytics/push)"
CT=$(curl -s -H "$AAD" $A/admin/analytics/content)
has "content daily" '"announcements":' "$CT"
has "content kaynak durumu" '"sources":{' "$CT"
echo "== tarih araligi dogrulamasi"
check "from>to" 400 "$(code -H "$AAD" "$A/admin/analytics/registrations?from=2026-10-24&to=2026-10-23")"
check "bozuk tarih" 400 "$(code -H "$AAD" "$A/admin/analytics/registrations?from=23.10.2026")"
check "367 gun" 400 "$(code -H "$AAD" "$A/admin/analytics/engagement?from=2026-01-01&to=2027-01-02")"
check "366 gun" 200 "$(code -H "$AAD" "$A/admin/analytics/engagement?from=2026-01-01&to=2027-01-01")"
check "retention/support ek parametre" 200 "$(code -H "$AAD" "$A/admin/analytics/retention?from=bozuk")"
R=$(curl -s -H 'Accept-Language: en' -H "$AAD" "$A/admin/analytics/active-users?from=2026-10-24&to=2026-10-23")
has "INVALID_RANGE kodu" '"code":"INVALID_RANGE"' "$R"
has "INVALID_RANGE EN" "Invalid date range" "$R"
has "INVALID_RANGE AR" "$(printf '\xd9\x86\xd8\xb7\xd8\xa7\xd9\x82')" "$(curl -s -H 'Accept-Language: ar' -H "$AAD" "$A/admin/analytics/active-users?from=2026-10-24&to=2026-10-23")"

echo "== kullanici listesi ve filtreler"
L=$(curl -s -H "$AAD" "$A/admin/users?q=smk1x$SFX")
check "q ile ara" 1 "$(echo "$L" | num totalItems)"
has "satir alanlari" '"emailVerified":true' "$L"
has "lastSeenAt dolu" '"lastSeenAt":"20' "$L"
check "LIKE joker kacisi (%)" 0 "$(curl -s -H "$AAD" "$A/admin/users?q=%25smk$SFX" | num totalItems)"
check "LIKE joker kacisi (_)" 0 "$(curl -s -H "$AAD" "$A/admin/users?q=smk_x$SFX" | num totalItems)"
check "SQL enjeksiyonu denemesi guvenli" 200 "$(code -H "$AAD" "$A/admin/users?q=%27%3B%20DROP%20TABLE%20app_user%3B%20--")"
check "faculty=A" 2 "$(curl -s -H "$AAD" "$A/admin/users?faculty=$FA" | num totalItems)"
check "faculty=B" 1 "$(curl -s -H "$AAD" "$A/admin/users?faculty=$FB" | num totalItems)"
check "faculty=A&status=ACTIVE&verified=true" 2 "$(curl -s -H "$AAD" "$A/admin/users?faculty=$FA&status=ACTIVE&verified=true" | num totalItems)"
check "faculty=A&role=ADMIN" 0 "$(curl -s -H "$AAD" "$A/admin/users?faculty=$FA&role=ADMIN" | num totalItems)"
check "department+classYear" 1 "$(curl -s -H "$AAD" "$A/admin/users?department=Bilgisayar&classYear=2&faculty=$FA" | num totalItems)"
check "language=en" 1 "$(curl -s -H "$AAD" "$A/admin/users?language=en&faculty=$FB" | num totalItems)"
check "sayfalama: size=1" 2 "$(curl -s -H "$AAD" "$A/admin/users?faculty=$FA&size=1" | num totalPages)"
check "sort displayName,asc" 200 "$(code -H "$AAD" "$A/admin/users?sort=displayName,asc")"
check "sort lastSeenAt,desc" 200 "$(code -H "$AAD" "$A/admin/users?sort=lastSeenAt,desc")"
check "sort beyaz liste disi" 400 "$(code -H "$AAD" "$A/admin/users?sort=password_hash,asc")"
check "sort yon gecersiz" 400 "$(code -H "$AAD" "$A/admin/users?sort=createdAt,sideways")"
check "gecersiz status" 400 "$(code -H "$AAD" "$A/admin/users?status=NOPE")"
D=$(curl -s -H "$AAD" $A/admin/users/$ID1)
has "detay fakulte" "\"faculty\":\"$FA\"" "$D"
has "detay sayaclar" '"counts":{"feedback":' "$D"
has "detay onaylar" '"consents":[{"type":' "$D"
has "detay platform" '"platforms":["ANDROID"]' "$D"
has "detay cihaz sayisi" '"deviceCount":1' "$D"
has "detay gunluk aktiflik" '"recentActivity":[{"day":' "$D"
check "detay bulunamadi" 404 "$(code -H "$AAD" $A/admin/users/999999999)"

echo "== rol degistirme ve eski token"
check "rol: admin yap" 204 "$(code -X PATCH -H "$H" -H "$AAD" $A/admin/users/$ID2/role -d '{"role":"ADMIN"}')"
check "eski token reddedilir (rol degisti)" 401 "$(code -H "$A2" $A/users/me)"
LG=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$E2\",\"password\":\"Sifre1234\"}")
RT2=$(echo "$LG" | grep -o '"refreshToken":"[^"]*' | cut -d'"' -f4)
NT2=$(curl -s -X POST -H "$H" $A/auth/refresh -d "{\"refreshToken\":\"$RT2\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
check "yeni token yeni rolde calisir" 200 "$(code -H "Authorization: Bearer $NT2" $A/admin/me)"
check "gecersiz rol" 400 "$(code -X PATCH -H "$H" -H "$AAD" $A/admin/users/$ID2/role -d '{"role":"ROOT"}')"
sleep 1   # iat saniye hassasiyeti: degisim ile token ayni saniyede olmasin
check "rol: geri al" 204 "$(code -X PATCH -H "$H" -H "$AAD" $A/admin/users/$ID2/role -d '{"role":"USER"}')"
check "geri alinan admin token'i reddedilir" 401 "$(code -H "Authorization: Bearer $NT2" $A/admin/me)"
check "kendi rolunu dusuremez" 400 "$(code -X PATCH -H "$H" -H "$AAD" $A/admin/users/$IDA/role -d '{"role":"USER"}')"
has "kendi rolu kodu" '"code":"CANNOT_MODIFY_SELF"' "$(curl -s -X PATCH -H "$H" -H "$AAD" $A/admin/users/$IDA/role -d '{"role":"USER"}')"
check "kendini silemez" 400 "$(code -X DELETE -H "$AAD" $A/admin/users/$IDA)"
check "rol: bulunamadi" 404 "$(code -X PATCH -H "$H" -H "$AAD" $A/admin/users/999999999/role -d '{"role":"ADMIN"}')"
ADMINS=$(curl -s -H "$AAD" "$A/admin/users?role=ADMIN&status=ACTIVE" | num totalItems)
if [ "$ADMINS" = "1" ]; then
  R=$(curl -s -u "admin:$ADMIN_PASSWORD" -X PATCH -H "$H" $A/admin/users/$IDA/role -d '{"role":"USER"}' -w ' [%{http_code}]')
  # ADMIN_EMAILS'teki (sabitlenmis) tek yonetici icin ADMIN_EMAIL_PINNED, degilse LAST_ADMIN doner; ikisi de 409 korumasidir.
  if echo "$R" | grep -qF '"code":"ADMIN_EMAIL_PINNED"'; then PINNED_OR_LAST='"code":"ADMIN_EMAIL_PINNED"'; else PINNED_OR_LAST='"code":"LAST_ADMIN"'; fi
  has "son yonetici dusurulemez (409)" "$PINNED_OR_LAST" "$R"
  has "son yonetici 409 durumu" '[409]' "$R"
  check "son yonetici silinemez" 409 "$(code -u "admin:$ADMIN_PASSWORD" -X DELETE $A/admin/users/$IDA)"
  check "admin hala admin" 200 "$(code -H "$AAD" $A/admin/me)"
else
  echo "  atlandi: birden fazla aktif yonetici var ($ADMINS), LAST_ADMIN denenmedi"
fi

echo "== CSV disa aktarim"
curl -s -H "$AAD" -D /tmp/smk_h_$SFX.txt -o /tmp/smk_b_$SFX.csv "$A/admin/users/export.csv?faculty=$FB"
check "csv 200" "HTTP/1.1 200" "$(head -1 /tmp/smk_h_$SFX.txt | tr -d '\r' | cut -c1-12)"
has "csv icerik turu" "text/csv" "$(cat /tmp/smk_h_$SFX.txt)"
has "csv dosya adi" "users.csv" "$(cat /tmp/smk_h_$SFX.txt)"
check "csv UTF-8 BOM" "ef bb bf" "$(od -An -tx1 -N3 /tmp/smk_b_$SFX.csv | sed 's/^ *//')"
has "csv baslik" "id,email,displayName,faculty" "$(cat /tmp/smk_b_$SFX.csv)"
check "csv satir sayisi (baslik+1)" 2 "$(wc -l < /tmp/smk_b_$SFX.csv | tr -d ' ')"
has "csv formul kacisi" "\"'=SUM(1+1)\"" "$(cat /tmp/smk_b_$SFX.csv)"
hasnt "csv ham formul yok" ",=SUM" "$(cat /tmp/smk_b_$SFX.csv)"
curl -s -H "$AAD" -o /tmp/smk_b2_$SFX.csv "$A/admin/users/export.csv?faculty=$FA&sort=displayName,asc"
check "csv A fakultesi (baslik+2)" 3 "$(wc -l < /tmp/smk_b2_$SFX.csv | tr -d ' ')"
check "csv gecersiz sort" 400 "$(code -H "$AAD" "$A/admin/users/export.csv?sort=x,asc")"
rm -f /tmp/smk_h_$SFX.txt /tmp/smk_b_$SFX.csv /tmp/smk_b2_$SFX.csv

echo "== veri disa aktarimi (KVKK)"
EX=$(curl -s -H "$A1" $A/users/me/export)
has "export: activity" '"activity":' "$EX"
has "export: analyticsEvents" '"analyticsEvents":' "$EX"
has "export: olay icerigi" '"name":"screen_view"' "$EX"
has "export: profil fakultesi" "\"faculty\":\"$FA\"" "$EX"

echo "== denetim kaydi"
AU=$(curl -s -H "$AAD" "$A/admin/audit?method=PATCH&q=/role&size=100")
has "audit: PATCH rol kaydi" "\"path\":\"/api/admin/users/$ID2/role\"" "$AU"
has "audit: yonetici e-postasi" "\"adminEmail\":\"$ADMIN_EMAIL\"" "$AU"
has "audit: durum 204" '"status":204' "$AU"
has "audit: ip" '"ip":"' "$AU"
has "audit: 403 denemesi (normal kullanici)" '"status":403' "$(curl -s -H "$AAD" "$A/admin/audit?adminId=$ID1&size=100")"
check "audit: GET kaydedilmez" 0 "$(curl -s -H "$AAD" "$A/admin/audit?q=/api/admin/analytics" | num totalItems)"
has "audit: CSV disa aktarimi kaydi" '"method":"GET","path":"/api/admin/users/export.csv"' "$(curl -s -H "$AAD" "$A/admin/audit?q=export.csv&size=5")"
has "audit: ayar degisikligi" '"path":"/api/admin/settings/faculties"' "$(curl -s -H "$AAD" "$A/admin/audit?method=put&q=faculties&size=5")"
check "audit: gecersiz method filtresi bos" 0 "$(curl -s -H "$AAD" "$A/admin/audit?method=ZZZ" | num totalItems)"
check "audit: sayfalama" 200 "$(code -H "$AAD" "$A/admin/audit?page=1&size=2")"

echo "== sozlesme yonetimi"
LV=$(curl -s -H "$AAD" $A/admin/legal/terms/versions)
has "surumler: aktif tr" '"lang":"tr"' "$LV"
has "surumler: alanlar" '"requireReaccept":' "$LV"
has "surumler: aktif bayragi" '"active":true' "$LV"
has "surumler: icerik" '"content":"' "$LV"
check "surumler: bilinmeyen tur" 404 "$(code -H "$AAD" $A/admin/legal/nope/versions)"
AS=$(curl -s -H "$AAD" $A/admin/legal/acceptance-stats)
for T in TERMS PRIVACY KVKK COMMUNITY_RULES; do has "kabul istatistigi $T" "\"type\":\"$T\"" "$AS"; done
has "kabul istatistigi alanlari" '"totalActiveUsers":' "$AS"
ACC=$(echo "$AS" | grep -o '"type":"TERMS","version":[0-9]*,"accepted":[0-9]*' | head -1 | grep -o 'accepted":[0-9]*' | cut -d: -f2)
TOT=$(echo "$AS" | num totalActiveUsers)
check "kabul <= toplam aktif kullanici" 1 "$([ "${ACC:-0}" -le "${TOT:-0}" ] && [ "${ACC:-0}" -ge 3 ] && echo 1 || echo 0)"

echo "== haber yonetimi (gizleme)"
NID=$(docker compose exec -T postgres psql -U bingol -d bingol -tA -c "INSERT INTO news_item (type, url, title, summary, published_date, fetched_at) VALUES ('HABER', 'https://smoke.invalid/n/$SFX', 'Smokehaber$SFX deneme basligi', 'ozet', CURRENT_DATE, now()) RETURNING id" 2>/dev/null | head -1 | tr -d '\r ')
if [ -z "$NID" ]; then
  echo "  atlandi: test haberi eklenemedi (postgres konteynerine erisilemiyor)"
else
  check "admin haber listesi" 200 "$(code -H "$AAD" "$A/admin/news")"
  has "admin haber: q filtresi" "\"id\":$NID" "$(curl -s -H "$AAD" "$A/admin/news?q=smokehaber$SFX")"
  has "admin haber: hidden=false" '"hidden":false' "$(curl -s -H "$AAD" "$A/admin/news?q=smokehaber$SFX&hidden=false")"
  check "admin haber: type filtresi" 1 "$(curl -s -H "$AAD" "$A/admin/news?q=smokehaber$SFX&type=HABER" | num totalItems)"
  check "admin haber: LIKE kacisi" 0 "$(curl -s -H "$AAD" "$A/admin/news?q=%25smokehaber$SFX" | num totalItems)"
  check "gorunur: detay" 200 "$(code $A/news/$NID)"
  has "gorunur: liste" "\"id\":$NID," "$(curl -s "$A/news?q=smokehaber$SFX")"
  check "gorunur: favori ekle" 204 "$(code -X PUT -H "$A1" $A/bookmarks/news/$NID)"
  has "gorunur: favorilerde" "\"targetId\":$NID," "$(curl -s -H "$A1" $A/bookmarks)"
  has "gorunur: arama" "\"targetId\":$NID," "$(curl -s -H "$A1" "$A/search?q=smokehaber$SFX&type=NEWS")"
  check "haberi gizle" 204 "$(code -X PATCH -H "$H" -H "$AAD" $A/admin/news/$NID -d '{"hidden":true}')"
  check "gizli: detay 404" 404 "$(code $A/news/$NID)"
  hasnt "gizli: liste" "\"id\":$NID," "$(curl -s "$A/news?q=smokehaber$SFX")"
  hasnt "gizli: liste (tum)" "\"id\":$NID," "$(curl -s "$A/news?size=50")"
  hasnt "gizli: favorilerde" "\"targetId\":$NID," "$(curl -s -H "$A1" $A/bookmarks)"
  hasnt "gizli: arama" "\"targetId\":$NID," "$(curl -s -H "$A1" "$A/search?q=smokehaber$SFX&type=NEWS")"
  check "gizli: favori eklenemez" 404 "$(code -X PUT -H "$A3" $A/bookmarks/news/$NID)"
  has "admin: hidden=true listesi" "\"id\":$NID" "$(curl -s -H "$AAD" "$A/admin/news?hidden=true&q=smokehaber$SFX")"
  check "haberi goster" 204 "$(code -X PATCH -H "$H" -H "$AAD" $A/admin/news/$NID -d '{"hidden":false}')"
  check "gosterilen: detay 200" 200 "$(code $A/news/$NID)"
  check "haber: bulunamadi" 404 "$(code -X PATCH -H "$H" -H "$AAD" $A/admin/news/999999999 -d '{"hidden":true}')"
  check "haber: govde eksik" 400 "$(code -X PATCH -H "$H" -H "$AAD" $A/admin/news/$NID -d '{}')"
  curl -s -o /dev/null -X DELETE -H "$A1" $A/bookmarks/news/$NID
  docker compose exec -T postgres psql -U bingol -d bingol -c "DELETE FROM news_item WHERE id = $NID" >/dev/null 2>&1
fi

echo "== CORS"
PF=$(curl -s -i -X OPTIONS "$A/app/info" -H 'Origin: http://localhost:5173' -H 'Access-Control-Request-Method: GET')
has "preflight izinli koken" "Access-Control-Allow-Origin: http://localhost:5173" "$PF"
PF2=$(curl -s -i -X OPTIONS "$A/admin/users/1/role" -H 'Origin: http://localhost:3000' -H 'Access-Control-Request-Method: PATCH' -H 'Access-Control-Request-Headers: authorization,content-type')
has "preflight PATCH" "PATCH" "$PF2"
has "preflight basliklar" "authorization" "$PF2"
GE=$(curl -s -i "$A/app/info" -H 'Origin: http://localhost:5173')
has "app/info CORS basligi" "Access-Control-Allow-Origin: http://localhost:5173" "$GE"
hasnt "cerez/kimlik bilgisi izni yok" "Access-Control-Allow-Credentials: true" "$GE"
check "izinsiz koken reddedilir" 403 "$(code "$A/app/info" -H 'Origin: https://evil.example')"
hasnt "actuator icin CORS yok" "Access-Control-Allow-Origin" "$(curl -s -i $BASE/actuator/health -H 'Origin: http://localhost:5173')"
has "files yolu CORS" "Access-Control-Allow-Origin: http://localhost:5173" "$(curl -s -i -X OPTIONS "$BASE/files/x.png" -H 'Origin: http://localhost:5173' -H 'Access-Control-Request-Method: GET')"
check "faculties CORS" 200 "$(code "$A/faculties" -H 'Origin: http://localhost:5173')"

echo "== hesap silme (yonetici) ve temizlik"
check "u4 sil" 204 "$(code -X DELETE -H "$AAD" $A/admin/users/$ID4)"
D4=$(curl -s -H "$AAD" $A/admin/users/$ID4)
has "silinen: durum" '"status":"DELETED"' "$D4"
has "silinen: anonim e-posta" "deleted-$ID4@deleted.invalid" "$D4"
check "silinen kullanicinin token'i gecersiz" 401 "$(code -H "$A4" $A/users/me)"
check "silinen kullanici girisi" 401 "$(code -X POST -H "$H" $A/auth/login -d "{\"email\":\"$E4\",\"password\":\"Sifre1234\"}")"
check "tekrar silme 404" 404 "$(code -X DELETE -H "$AAD" $A/admin/users/$ID4)"
has "audit: DELETE kaydi" "\"path\":\"/api/admin/users/$ID4\"" "$(curl -s -H "$AAD" "$A/admin/audit?method=DELETE&size=20")"
# test kullanicilarini anonimlestir: sayimlar ve dagilimlar baslangica doner
for I in $ID1 $ID2 $ID3; do curl -s -o /dev/null -X DELETE -H "$AAD" $A/admin/users/$I; done
check "fakulte A kullanicisi kalmadi" 0 "$(curl -s -H "$AAD" "$A/admin/users?faculty=$FA" | num totalItems)"
check "ayar: fakulte listesini temizle" 204 "$(code -X PUT -H "$H" -H "$AAD" $A/admin/settings/faculties -d '{"value":""}')"
check "bos listede de serbest metin reddedilir (katalog)" 400 "$(code -X PATCH -H "$H" -H "$AAD" $A/users/me -d '{"faculty":"Serbest Fakulte"}')"
check "fakulteyi temizle" 200 "$(code -X PATCH -H "$H" -H "$AAD" $A/users/me -d '{"faculty":""}')"

[ $FAIL -eq 0 ] && echo "TUMU GECTI" || echo "HATA VAR"
exit $FAIL
