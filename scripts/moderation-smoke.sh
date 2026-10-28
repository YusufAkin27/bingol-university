#!/usr/bin/env bash
# T12 moderasyon altyapisi duman testi: oncelikli kuyruk, otomatik gizleme esigi, onizleme, itiraz, toplu karar,
# karar nedeni sablonlari, tekrarlayan ihlal -> askiya alma onerisi, rapor kisiti, yasakli ozet listesi, KVKK disa aktarim.
# Kullanim (kendi yiginin; override sahte EVENT_COVER handler'ini ve dusuk esikleri acar):
#   export COMPOSE_PROJECT_NAME=wt_t12 BACKEND_PORT=8112
#   docker compose -f docker-compose.yml -f scripts/moderation-compose.override.yml up -d --build postgres redis backend
#   docker compose exec -T redis redis-cli flushall
#   BASE=http://localhost:8112 ./scripts/moderation-smoke.sh
# Esikler (override): otomatik gizleme 3, ihlal onerisi 2, rapor kisiti 2 reddedilen. Idempotent: benzersiz kullanicilar;
# kayit ucu IP basina saatte 10 ile sinirli (8 kullanici acar) -> tekrar calistirmadan once redis flushall.
set -u
BASE=${BASE:-http://localhost:8112}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 400)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamali: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true,\"language\":\"${3:-tr}\"}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$t"
}
uid() { curl -s -H "Authorization: Bearer $1" $A/users/me | idof; }
report() { # token type target reason
  code -X POST -H "$H" -H "Authorization: Bearer $1" $A/reports -d "{\"targetType\":\"$2\",\"targetId\":$3,\"reason\":\"$4\"}"
}

SFX=$RANDOM
echo "== hazirlik"
TA=$(register "$ADMIN_EMAIL" "Mod Admin" en)
TO=$(register "modo$SFX@bingol.edu.tr" "Sahip" en)
T1=$(register "modr1$SFX@bingol.edu.tr" "Rapor1")
T2=$(register "modr2$SFX@bingol.edu.tr" "Rapor2")
T3=$(register "modr3$SFX@bingol.edu.tr" "Rapor3")
T4=$(register "modr4$SFX@bingol.edu.tr" "Rapor4")
TO2=$(register "modo2$SFX@bingol.edu.tr" "Sahip2" en)
TO3=$(register "modo3$SFX@bingol.edu.tr" "Sahip3" en)
for t in "$TA" "$TO" "$T1" "$T2" "$T3" "$T4" "$TO2" "$TO3"; do [ -z "$t" ] && { echo "  FAIL kullanici hazirlanamadi (redis flushall?)"; exit 1; }; done
AUTHA="Authorization: Bearer $TA"; AUTHO="Authorization: Bearer $TO"
O=$(uid "$TO"); O2=$(uid "$TO2"); O3=$(uid "$TO3")

echo "== yetki"
check "anonim admin 401" 401 "$(code $A/admin/moderation/appeals)"
check "normal kullanici admin 403" 403 "$(code -H "Authorization: Bearer $T1" $A/admin/moderation/appeals)"
check "normal kullanici blocklist 403" 403 "$(code -H "Authorization: Bearer $T1" $A/admin/moderation/blocklist)"

echo "== karar nedeni sablonlari (3 dil)"
R=$(curl -s -H "$AUTHA" -H "Accept-Language: en" $A/admin/reports/reason-templates)
has "SPAM sablonu" '"code":"SPAM"' "$R"
has "en metin" 'Spam or unwanted content' "$R"
has "uc dil" '"ar":' "$R"

echo "== oncelikli kuyruk + otomatik gizleme (esik 3)"
check "rapor 1" 201 "$(report "$T1" EVENT_COVER $O SPAM)"
check "rapor 2" 201 "$(report "$T2" EVENT_COVER $O INAPPROPRIATE)"
check "tekrar rapor 409" 409 "$(report "$T1" EVENT_COVER $O SPAM)"
check "kendi icerigi 400" 400 "$(report "$TO" EVENT_COVER $O SPAM)"
check "desteklenmeyen tur 400" 400 "$(report "$T1" USER_AVATAR $O SPAM)"
Q=$(curl -s -H "$AUTHA" "$A/admin/reports?order=priority&targetType=EVENT_COVER")
has "iki farkli raporlayici" '"openReporters":2' "$Q"
has "onizleme" '"kind":"IMAGE"' "$Q"
has "henuz gizli degil" '"hidden":false' "$Q"
check "rapor 3 (esik)" 201 "$(report "$T3" EVENT_COVER $O HARASSMENT)"
Q=$(curl -s -H "$AUTHA" "$A/admin/reports?order=priority&targetType=EVENT_COVER")
has "otomatik gizlendi" '"hiddenBy":"AUTO"' "$Q"
has "oncelik 130" '"priority":130' "$Q"
N=$(curl -s -H "$AUTHO" $A/notifications)
has "sahibe bildirim (en)" 'temporarily hidden' "$N"
Qf=$(curl -s -H "$AUTHA" "$A/admin/reports?targetType=MESSAGE")
hasnt "tur filtresi" 'EVENT_COVER' "$Qf"

echo "== itiraz"
check "baskasi itiraz 404" 404 "$(code -X POST -H "$H" -H "Authorization: Bearer $T4" $A/appeals -d "{\"targetType\":\"EVENT_COVER\",\"targetId\":$O,\"message\":\"deneme itiraz\"}")"
check "gizli olmayan icerik 404" 404 "$(code -X POST -H "$H" -H "Authorization: Bearer $TO2" $A/appeals -d "{\"targetType\":\"EVENT_COVER\",\"targetId\":$O2,\"message\":\"deneme itiraz\"}")"
check "sahip itiraz 201" 201 "$(code -X POST -H "$H" -H "$AUTHO" $A/appeals -d "{\"targetType\":\"EVENT_COVER\",\"targetId\":$O,\"message\":\"Bu gorsel kurallara uygun\"}")"
check "tekrar itiraz 409" 409 "$(code -X POST -H "$H" -H "$AUTHO" $A/appeals -d "{\"targetType\":\"EVENT_COVER\",\"targetId\":$O,\"message\":\"Bu gorsel kurallara uygun\"}")"
has "kendi itirazlari" '"status":"OPEN"' "$(curl -s -H "$AUTHO" $A/appeals/mine)"
AP=$(curl -s -H "$AUTHA" "$A/admin/moderation/appeals?status=OPEN")
has "admin itiraz listesi" "\"userId\":$O" "$AP"
APID=$(echo "$AP" | idof)
check "itiraz kabul" 204 "$(code -X POST -H "$H" -H "$AUTHA" $A/admin/moderation/appeals/$APID/decide -d '{"accept":true,"note":"hata olmus"}')"
check "tekrar karar 409" 409 "$(code -X POST -H "$H" -H "$AUTHA" $A/admin/moderation/appeals/$APID/decide -d '{"accept":false}')"
Q=$(curl -s -H "$AUTHA" "$A/admin/reports?order=priority&targetType=EVENT_COVER")
has "yeniden gorunur" '"hidden":false' "$Q"
has "sahibe itiraz bildirimi (en)" 'appeal was accepted' "$(curl -s -H "$AUTHO" $A/notifications)"

echo "== toplu karar + ihlal -> askiya alma onerisi (esik 2)"
RID1=$(echo "$Q" | idof)
check "USER raporu (ayni sahip)" 201 "$(report "$T4" USER $O SPAM)"
QU=$(curl -s -H "$AUTHA" "$A/admin/reports?targetType=USER")
RID2=$(echo "$QU" | idof)
BR=$(curl -s -X POST -H "$H" -H "$AUTHA" $A/admin/reports/bulk-resolve -d "{\"ids\":[$RID1,$RID1,99999999],\"action\":\"HIDE\",\"reasonCode\":\"SPAM\"}")
has "toplu: basarili" '"ok":true' "$BR"
has "toplu: zaten cozulmus" '"error":"ALREADY_RESOLVED"' "$BR"
has "toplu: bulunamadi" '"error":"REPORT_NOT_FOUND"' "$BR"
check "gecersiz neden kodu 400" 400 "$(code -X POST -H "$H" -H "$AUTHA" $A/admin/reports/bulk-resolve -d "{\"ids\":[1],\"action\":\"HIDE\",\"reasonCode\":\"YOK\"}" -o /dev/null)"
has "sahibe kaldirma bildirimi (en)" 'was removed' "$(curl -s -H "$AUTHO" $A/notifications)"
check "ikinci ihlal: uyari" 204 "$(code -X POST -H "$H" -H "$AUTHA" $A/admin/reports/$RID2/resolve -d '{"action":"WARN","reasonCode":"HARASSMENT"}')"
SR=$(curl -s -H "$AUTHA" "$A/admin/moderation/suspend-recommendations")
has "askiya alma onerisi" "\"userId\":$O" "$SR"
SRID=$(echo "$SR" | idof)
check "oneriyi kabul = askiya al" 204 "$(code -X POST -H "$AUTHA" $A/admin/moderation/suspend-recommendations/$SRID/accept)"
check "askidaki kullanici reddedilir" 401 "$(code -H "$AUTHO" $A/users/me)"
check "oneri tekrar 409" 409 "$(code -X POST -H "$AUTHA" $A/admin/moderation/suspend-recommendations/$SRID/dismiss)"

echo "== reddedilen rapor -> rapor kisiti (esik 2)"
check "T2 rapor (O2 EVENT_COVER)" 201 "$(report "$T2" EVENT_COVER $O2 SPAM)"
check "T2 rapor (O2 USER)" 201 "$(report "$T2" USER $O2 SPAM)"
for rid in $(curl -s -H "$AUTHA" "$A/admin/reports?targetType=EVENT_COVER" | grep -o '"id":[0-9]*,"reporterId":[0-9]*' | cut -d: -f2 | cut -d, -f1) $(curl -s -H "$AUTHA" "$A/admin/reports?targetType=USER" | grep -o '"id":[0-9]*,"reporterId":[0-9]*' | cut -d: -f2 | cut -d, -f1); do
  code -X POST -H "$H" -H "$AUTHA" $A/admin/reports/$rid/resolve -d '{"action":"DISMISS"}' > /dev/null
done
check "kisitli raporlayan 403" 403 "$(report "$T2" EVENT_COVER $O3 SPAM)"
has "kisit mesaji (en)" 'cannot submit reports' "$(curl -s -X POST -H "$H" -H "Authorization: Bearer $T2" -H 'Accept-Language: en' $A/reports -d "{\"targetType\":\"EVENT_COVER\",\"targetId\":$O3,\"reason\":\"SPAM\"}")"
check "kisitsiz raporlayan 201" 201 "$(report "$T3" EVENT_COVER $O3 SPAM)"
has "KVKK disa aktarim" '"reportsFiled"' "$(curl -s -H "Authorization: Bearer $T2" $A/users/me/export)"

echo "== yasakli ozet listesi"
HASH=$(printf 'a%.0s' $(seq 1 63))$((SFX % 10))
check "gecersiz ozet 400" 400 "$(code -X POST -H "$H" -H "$AUTHA" $A/admin/moderation/blocklist -d '{"sha256":"abc"}')"
check "ozet ekle 201" 201 "$(code -X POST -H "$H" -H "$AUTHA" $A/admin/moderation/blocklist -d "{\"sha256\":\"$HASH\",\"note\":\"duman\"}")"
check "ozet tekrar (idempotent) 201" 201 "$(code -X POST -H "$H" -H "$AUTHA" $A/admin/moderation/blocklist -d "{\"sha256\":\"$HASH\"}")"
has "listede" "$HASH" "$(curl -s -H "$AUTHA" $A/admin/moderation/blocklist?size=50)"
check "ozet sil 204" 204 "$(code -X DELETE -H "$AUTHA" $A/admin/moderation/blocklist/$HASH)"
check "ozet tekrar sil 404" 404 "$(code -X DELETE -H "$AUTHA" $A/admin/moderation/blocklist/$HASH)"

echo "== denetim kaydi"
has "yonetici islemleri denetlendi" '/api/admin/reports/bulk-resolve' "$(curl -s -H "$AUTHA" "$A/admin/audit?size=50")"

[ $FAIL -eq 0 ] && echo "TAMAM: moderasyon duman testi gecti" || { echo "BASARISIZ"; exit 1; }
