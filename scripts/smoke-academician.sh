#!/usr/bin/env bash
# Akademisyen alani + doner QR ile yoklama: GERCEK yigina karsi HTTP duman testi (docs/changes/academician.md).
# Kullanim:  BASE=http://localhost:18080 PROJECT=bu_fresh ./scripts/smoke-academician.sh
# Onkosul:   yigin SEED profiliyle calisiyor (./scripts/reset-dev-db.sh) ve MAIL_ENABLED=false (kod log'dan okunur).
#            Araclar: bash, curl, node (JSON ayristirma), sha256sum, docker compose. Tohum sifresi docs/DEV_SEED.md.
# Ortam:     BASE (varsayilan http://localhost:8080), PROJECT (compose proje adi; bos = varsayilan proje),
#            SEED_PASSWORD (varsayilan docs/DEV_SEED.md'deki DEV sifresi), SEED_ADMIN (varsayilan seed.admin@bingol.edu.tr),
#            FLUSH_REDIS=0 (baslangicta Redis flushall'u atla; kayit ucu IP basina saatte 10 ile sinirlidir).
# Cikti:     her adim icin "PASS ..." ya da "FAIL ..." satiri + ozet; herhangi bir FAIL varsa cikis kodu 1.
# Sure:      yaklasik 1-2 dk (kod penceresini gecirmek icin 11 sn bekleme vardir). Tekrar calistirilabilir (rastgele hesaplar).
set -u
cd "$(dirname "$0")/.." || exit 1

BASE=${BASE:-http://localhost:8080}
A=$BASE/api
PROJECT=${PROJECT:-}
DC=${DC:-docker compose${PROJECT:+ -p $PROJECT}}
SEED_PASSWORD=${SEED_PASSWORD:-DevSeed-2026!}
SEED_ADMIN=${SEED_ADMIN:-seed.admin@bingol.edu.tr}
NEWUSER_PW=${NEWUSER_PW:-Zk7-Qmv-Lpx92w}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

TOTAL=0; PASSED=0; FAILED=0; FAILED_LIST=""
ST=""; BD=""

# ---------------------------------------------------------------- yardimcilar
ck() { # ad kosul-sonucu(0=gecti) [ayrinti]
  TOTAL=$((TOTAL + 1))
  if [ "$2" = "0" ]; then PASSED=$((PASSED + 1)); echo "PASS $1"
  else FAILED=$((FAILED + 1)); FAILED_LIST="$FAILED_LIST|$1"; echo "FAIL $1 ${3:-}"; fi
}
eq()   { if [ "$2" = "$3" ]; then ck "$1 ($3)" 0; else ck "$1" 1 "(beklenen '$2', gelen '$3'; govde: $(printf '%s' "$BD" | head -c 220))"; fi; }
st()   { eq "$1" "$2" "$ST"; }                                   # durum kodu denetimi
code() { local g; g=$(J 'd.code'); if [ "$g" = "$2" ]; then ck "$1 (kod $2)" 0; else ck "$1 (kod)" 1 "(beklenen $2, gelen '$g'; durum $ST)"; fi; }
yes()  { if [ "$2" = "true" ] || [ "$2" = "1" ]; then ck "$1" 0; else ck "$1" 1 "(deger '$2'; govde: $(printf '%s' "$BD" | head -c 220))"; fi; }

J() { # ifade -> $BD uzerinde JS ifadesi (d = ayristirilmis JSON); nesne/dizi JSON, bos = yok
  printf '%s' "$BD" | node -e 'let s="";process.stdin.on("data",c=>s+=c).on("end",()=>{let d=null;try{d=JSON.parse(s)}catch(e){}try{const v=eval(process.argv[1]);process.stdout.write(v==null?"":(typeof v==="object"?JSON.stringify(v):String(v)))}catch(e){}})' "$1"
}

winp() { cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; }

api() { # YONTEM YOL JETON [GOVDE-JSON]  -> ST, BD
  local m=$1 p=$2 t=$3 b=${4-} extra=()
  [ -n "$t" ] && extra+=(-H "Authorization: Bearer $t")
  if [ -n "$b" ]; then printf '%s' "$b" > "$TMP/req.json"; extra+=(-H 'Content-Type: application/json' --data-binary @"$TMP/req.json"); fi
  local r; r=$(curl -s -m 40 -w '\n%{http_code}' -X "$m" "${extra[@]}" "$A$p")
  ST=$(printf '%s' "$r" | tail -n 1)
  BD=$(printf '%s' "$r" | sed '$d')
}

login() { # eposta sifre -> TOK
  api POST /auth/login "" '{"email":"'"$1"'","password":"'"$2"'","client":"web"}'
  TOK=$(J 'd.accessToken')
}

read_code() { # eposta -> log'dan 6 haneli dogrulama kodu (en cok 25 sn)
  local i c
  for i in $(seq 1 25); do
    c=$($DC logs --no-color --tail 600 backend 2>&1 | grep -F "$1 icin dogrulama" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
    if [ -n "$c" ]; then printf '%s' "$c"; return 0; fi
    sleep 1
  done
  return 1
}

register_verified() { # eposta gorunen-ad -> TOK (kayit + e-posta dogrulama), ST son adimin durumu
  api POST /auth/register "" '{"email":"'"$1"'","password":"'"$NEWUSER_PW"'","displayName":"'"$2"'","acceptTerms":true,"language":"tr"}'
  local reg=$ST rc
  rc=$(read_code "$1") || rc=""
  api POST /auth/verify-email "" '{"email":"'"$1"'","code":"'"$rc"'","password":"'"$NEWUSER_PW"'","client":"web"}'
  TOK=$(J 'd.accessToken')
  [ "$reg" = "202" ] || echo "  (kayit durumu $reg)"
}

live_code() { # oturum-id jeton -> CODE (su anki adimin kodu)
  api GET "/academician/sessions/$1/live" "$2"
  CODE=$(J '(d.codes.find(c=>c.fromMs<=d.serverNowMs&&d.serverNowMs<c.untilMs)||d.codes[0]).code')
}

scan() { api POST /attendance/scan "$1" '{"code":"'"$2"'"}'; }

dl() { # YOL JETON DOSYA -> ST, $TMP/h (basliklar), DOSYA (govde)
  ST=$(curl -s -m 60 -D "$TMP/h" -o "$3" -w '%{http_code}' -H "Authorization: Bearer $2" "$A$1")
  BD=$(head -c 200 "$3" 2>/dev/null | tr -d '\000')
}
hdr() { grep -i "^$1:" "$TMP/h" | head -1 | tr -d '\r'; }

echo "== hazirlik: yigin, tohum hesaplari"
if ! curl -s -m 10 -o /dev/null "$BASE/api/catalog/academic"; then echo "HATA: $BASE erisilemiyor" >&2; exit 2; fi
if [ "${FLUSH_REDIS:-1}" = "1" ]; then $DC exec -T redis redis-cli flushall >/dev/null 2>&1 || echo "uyari: Redis flushall calismadi (kayit/tarama sinirlari etkileyebilir)"; fi
RND=$(LC_ALL=C tr -dc 'a-z' </dev/urandom | head -c 6)
NUM=9$(printf '%08d' $(( (RANDOM * 32768 + RANDOM) % 100000000 )))

login "$SEED_ADMIN" "$SEED_PASSWORD"; TADM=$TOK
if [ -z "$TADM" ]; then echo "HATA: tohum yonetici girisi yapilamadi (yigin seed profiliyle mi? ./scripts/reset-dev-db.sh)" >&2; exit 2; fi
login seed.ayse@bingol.edu.tr "$SEED_PASSWORD";   TA=$TOK
login seed.mehmet@bingol.edu.tr "$SEED_PASSWORD"; TB=$TOK
login seed.zeynep@bingol.edu.tr "$SEED_PASSWORD"; TZ=$TOK
login seed.emre@bingol.edu.tr "$SEED_PASSWORD";   TE=$TOK
login seed.selin@bingol.edu.tr "$SEED_PASSWORD";  TS=$TOK
login seed.ozan@bingol.edu.tr "$SEED_PASSWORD";   TO=$TOK
ck "tohum ogrenci girisleri" "$([ -n "$TA$TB$TZ$TE$TS$TO" ] && [ -n "$TA" ] && [ -n "$TB" ] && [ -n "$TZ" ] && [ -n "$TE" ] && [ -n "$TS" ] && [ -n "$TO" ] && echo 0 || echo 1)"

# ================================================================ 1. basvuru ve onay
echo "== akademisyen A: universite disi adres, kayit + dogrulama + basvuru -> PENDING"
MAIL_A=akad.$RND@example.org
register_verified "$MAIL_A" "Smk Hoca A$RND"; TLA=$TOK
ck "A kayit+dogrulama (jeton alindi)" "$([ -n "$TLA" ] && echo 0 || echo 1)"
api GET /academician/me "$TLA"; st "A me (basvurusuz)" 200; eq "A me durumu NONE" NONE "$(J d.status)"
api POST /academician/apply "$TLA" '{"title":"Dr.","firstName":"Smk","lastName":"A'"$RND"'","unit":"Test Birimi"}'
st "A apply" 200; eq "A apply -> PENDING" PENDING "$(J d.status)"
api GET /academician/me "$TLA"; eq "A me -> PENDING" PENDING "$(J d.status)"
api GET /academician/courses "$TLA"; st "A bekleyen: dersler 403" 403; code "A bekleyen: dersler" ACADEMICIAN_NOT_APPROVED
api POST /academician/courses "$TLA" '{"name":"X","term":"2026 Guz","department":"Matematik"}'; st "A bekleyen: ders olusturma 403" 403
api GET "/academician/students?q=ayse" "$TLA"; st "A bekleyen: ogrenci rehberi 403" 403; code "A bekleyen: rehber" ACADEMICIAN_NOT_APPROVED
api GET /my-courses "$TLA"; st "A (akademisyen) /my-courses bos liste" 200

echo "== yonetici: bekleyenleri listeler, A'yi onaylar"
api GET "/admin/academicians?status=PENDING&q=A$RND&size=50" "$TADM"; st "admin liste PENDING" 200
UID_A=$(J "(d.items.find(x=>x.lastName==='A$RND')||{}).userId")
ck "admin listede A var" "$([ -n "$UID_A" ] && echo 0 || echo 1)" "(govde: $(printf '%s' "$BD" | head -c 200))"
api GET /admin/academicians "$TLA"; st "akademisyen yonetici ucuna giremez (403)" 403
api GET "/admin/academicians/$UID_A" "$TADM"; st "admin detay" 200; eq "admin detay durum" PENDING "$(J d.status)"
api POST "/admin/academicians/$UID_A/approve" "$TADM"; st "admin approve" 200; eq "approve -> APPROVED" APPROVED "$(J d.status)"; eq "approve modu ADMIN" ADMIN "$(J d.approvalMode)"
api POST "/admin/academicians/$UID_A/approve" "$TADM"; st "ikinci approve 409" 409; code "ikinci approve" ACADEMICIAN_BAD_STATE
api GET /academician/me "$TLA"; eq "A me -> APPROVED" APPROVED "$(J d.status)"
api GET /academician/courses "$TLA"; st "A onayli: dersler 200" 200

echo "== otomatik onay kurali (gercek yigin)"
MAIL_B=smk.$RND@bingol.edu.tr
register_verified "$MAIL_B" "Smk Hoca B$RND"; TLB=$TOK
api POST /academician/apply "$TLB" '{"title":"Prof. Dr.","firstName":"Smk","lastName":"B'"$RND"'"}'
st "B (isim-tipi @bingol.edu.tr) apply" 200; eq "B -> APPROVED" APPROVED "$(J d.status)"
api GET /academician/me "$TLB"; eq "B approvalMode AUTO" AUTO "$(J d.approvalMode)"
api GET "/admin/academicians?status=APPROVED&approvalMode=AUTO&q=B$RND" "$TADM"; st "admin liste AUTO" 200
eq "admin: B listede, reviewedBy bos" "true" "$(J "(function(){var x=d.items.find(i=>i.lastName==='B$RND');return !!x&&x.reviewedBy==null&&x.approvalMode==='AUTO'})()")"
MAIL_C=$NUM@bingol.edu.tr
register_verified "$MAIL_C" "Smk Hoca C$RND"; TLC=$TOK
api POST /academician/apply "$TLC" '{"title":"Ars. Gor.","firstName":"Smk","lastName":"C'"$RND"'"}'
st "C (<rakam>@bingol.edu.tr) apply" 200; eq "C -> PENDING (ogrenci kalibi)" PENDING "$(J d.status)"

echo "== reddet / yeniden basvur / onayla / iptal et (C) ve iptalli hesap paneli"
UID_C=$(J d.userId); api GET "/admin/academicians?status=PENDING&q=C$RND" "$TADM"; UID_C=$(J "(d.items.find(x=>x.lastName==='C$RND')||{}).userId")
api POST "/admin/academicians/$UID_C/reject" "$TADM" '{"reason":"Test: belge eksik"}'; st "reject" 200; eq "reject -> REJECTED" REJECTED "$(J d.status)"
api GET /academician/me "$TLC"; eq "C me REJECTED + gerekce" "REJECTED|Test: belge eksik" "$(J d.status)|$(J d.rejectReason)"
api POST /academician/apply "$TLC" '{"title":"Ars. Gor.","firstName":"Smk","lastName":"C'"$RND"'"}'; eq "reddedilen yeniden basvurur -> PENDING" PENDING "$(J d.status)"
api POST "/admin/academicians/$UID_C/approve" "$TADM"; eq "C approve -> APPROVED" APPROVED "$(J d.status)"
api GET /academician/courses "$TLC"; st "C onayli: dersler 200" 200
api POST "/admin/academicians/$UID_C/revoke" "$TADM" '{"reason":"Test: iptal"}'; st "revoke" 200; eq "revoke -> REVOKED" REVOKED "$(J d.status)"
api GET /academician/courses "$TLC"; st "iptalli C: panel 403" 403
echo "   (iptalli panel hata kodu: $(J d.code))"
api POST /academician/apply "$TLC" '{"title":"Ars. Gor.","firstName":"Smk","lastName":"C'"$RND"'"}'; st "iptalli yeniden basvuramaz 403" 403; code "iptalli apply" ACADEMICIAN_REVOKED

# ================================================================ 2. ders, program, rehber, kayit
echo "== ders olusturma + program"
api POST /academician/courses "$TLA" '{"code":"SMK101","name":"Smoke Dersi '"$RND"'","term":"2026 Guz","faculty":"M\u00fchendislik Fak\u00fcltesi","department":"Bilgisayar M\u00fchendisli\u011fi"}'
st "ders olustur" 201
CID=$(J d.id); ck "ders kimligi" "$([ -n "$CID" ] && echo 0 || echo 1)"
api POST /academician/courses "$TLA" '{"name":"Hatali","term":"2026 Guz","department":"Uydurma Bolum"}'; st "katalog disi bolum reddedilir (4xx)" 400
api PUT "/academician/courses/$CID/slots" "$TLA" '[{"dayOfWeek":1,"startTime":"09:00","endTime":"11:00","room":"D-101"},{"dayOfWeek":3,"startTime":"13:00","endTime":"15:00"}]'
st "slotlar" 200; eq "slot sayisi" 2 "$(J d.length)"
api PUT "/academician/courses/$CID/slots" "$TLA" '[{"dayOfWeek":1,"startTime":"11:00","endTime":"09:00"}]'; st "bitis<baslangic slot reddedilir" 400
api GET "/academician/courses/$CID" "$TLA"; st "ders detay" 200; eq "ders detay slot sayisi (hatali istek degistirmedi)" 2 "$(J d.slots.length)"

echo "== ogrenci rehberi (e-posta yok), kayit, toplu kayit"
api GET "/academician/students?q=Ayse" "$TLA"; st "rehber arama" 200
ck "rehber yanitinda e-posta alani/adresi yok" "$(printf '%s' "$BD" | grep -qiE 'e-?mail|@' && echo 1 || echo 0)" "(govde: $(printf '%s' "$BD" | head -c 200))"
ID_A=$(J "(d.items.find(x=>x.displayName==='Ayse Demir')||{}).id")
ck "rehberde Ayse Demir" "$([ -n "$ID_A" ] && echo 0 || echo 1)"
idof() { api GET "/academician/students?q=$1&size=20" "$TLA"; J "(d.items.find(x=>x.displayName==='$2')||{}).id"; }
ID_B=$(idof Mehmet "Mehmet Kaya"); ID_Z=$(idof Zeynep "Zeynep Arslan"); ID_E=$(idof Emre "Emre Yildiz"); ID_S=$(idof Selin "Selin Aydin"); ID_O=$(idof Ozan "Ozan Polat")
ck "rehber: tum ogrenci kimlikleri" "$([ -n "$ID_B$ID_Z$ID_E$ID_S$ID_O" ] && [ -n "$ID_B" ] && [ -n "$ID_Z" ] && [ -n "$ID_E" ] && [ -n "$ID_S" ] && [ -n "$ID_O" ] && echo 0 || echo 1)"
api GET "/academician/students?q=Smk" "$TLA"; eq "akademisyenler rehberde yok (q=Smk)" 0 "$(J d.items.length)"
api POST "/academician/courses/$CID/enrollments" "$TLA" '{"studentIds":['"$ID_A"','"$ID_B"']}'; st "kayit (A,B)" 200; eq "added=2" 2 "$(J d.added)"
api POST "/academician/courses/$CID/enrollments" "$TLA" '{"studentIds":['"$ID_A"']}'; eq "tekrar kayit added=0" 0 "$(J d.added)"
api POST "/academician/courses/$CID/enrollments/bulk" "$TLA" '{"department":"Fizik"}'; st "toplu kayit (Fizik)" 200; eq "toplu added=1 (Selin)" 1 "$(J d.added)"
api GET "/academician/courses/$CID/enrollments" "$TLA"; st "kayit listesi" 200; eq "kayitli sayisi 3" 3 "$(J d.length)"

# ================================================================ 3. oturum ve doner QR
echo "== oturum ac, canli, kod"
api POST "/academician/courses/$CID/sessions" "$TLA" '{}'; st "oturum ac" 201
SID=$(J d.id); eq "oturum OPEN" OPEN "$(J d.status)"
api GET "/academician/sessions/$SID/live" "$TLA"; st "live" 200
eq "live: adim 5 sn, 3 kod, enrolled=3, present=0" "5|3|3|0" "$(J 'd.stepSeconds+"|"+d.codes.length+"|"+d.enrolledCount+"|"+d.presentCount')"
live_code "$SID" "$TLA"; ck "gecerli kod alindi (bingol-lesson:)" "$(printf '%s' "$CODE" | grep -q '^bingol-lesson:' && echo 0 || echo 1)" "($CODE)"
OLD=$CODE
scan "$TA" "$CODE"; st "A okutur" 200; eq "A -> MARKED" MARKED "$(J d.status)"; yes "yanit dersAdi+tarih" "$(J 'd.courseName.indexOf("Smoke")===0&&/^\d{4}-\d{2}-\d{2}$/.test(d.lessonDate)')"
scan "$TA" "$CODE"; st "A tekrar okutur" 200; eq "A -> ALREADY" ALREADY "$(J d.status)"
scan "$TB" "bingol-lesson:$SID.1.AAAAAAAAAAAAAAAAAAAAAA"; st "uydurma MAC 422" 422; code "uydurma MAC" ATTENDANCE_CODE_INVALID
scan "$TB" "garbage"; st "bozuk bicim 422" 422; code "bozuk bicim" ATTENDANCE_CODE_INVALID
api GET "/academician/sessions/$SID/live" "$TLA"
FUT1=$(J 'd.codes[1].code'); FUT2=$(J 'd.codes[2].code')
scan "$TB" "$FUT1"; st "bir SONRAKI adimin kodu 422 (yalniz guncel+onceki kabul)" 422; code "sonraki adim" ATTENDANCE_CODE_INVALID
scan "$TB" "$FUT2"; st "iki sonraki adimin kodu 422" 422
live_code "$SID" "$TLA"
TAMP="${CODE%?}$( [ "${CODE: -1}" = "A" ] && echo B || echo A )"
scan "$TB" "$TAMP"; st "kurcalanmis kod 422" 422; code "kurcalanmis kod" ATTENDANCE_CODE_INVALID
api GET "/academician/sessions/$SID/live" "$TLA"; eq "gecersiz taramalar kayit yaratmadi: present=1" 1 "$(J d.presentCount)"
echo "   (kodun suresinin dolmasi icin 11 sn bekleniyor)"
sleep 11
scan "$TB" "$OLD"; st "ESKI kod (>10 sn) 422" 422; code "eski kod" ATTENDANCE_CODE_INVALID

echo "== kayitli olmayan ogrenci: PENDING, kabul / yok say"
live_code "$SID" "$TLA"
scan "$TZ" "$CODE"; st "Zeynep (kayitsiz) okutur" 200; eq "Zeynep -> PENDING" PENDING "$(J d.status)"
scan "$TZ" "$CODE"; st "Zeynep tekrar" 200; eq "Zeynep tekrar -> PENDING (idempotent)" PENDING "$(J d.status)"
scan "$TE" "$CODE"; eq "Emre (kayitsiz) -> PENDING" PENDING "$(J d.status)"
api GET "/academician/sessions/$SID/live" "$TLA"
eq "live: pendingScans 2 kisi, present/enrolled degismedi" "2|1|3" "$(J 'd.pendingScans.length+"|"+d.presentCount+"|"+d.enrolledCount')"
yes "pendingScans Zeynep'i icerir (ad+bolum, e-posta yok)" "$(J "d.pendingScans.some(p=>p.studentId===$ID_Z&&p.displayName==='Zeynep Arslan'&&!('email' in p))")"
api GET "/academician/sessions/$SID" "$TLA"; eq "oturum detayi da pendingScans listeler" 2 "$(J d.pendingScans.length)"
api POST "/academician/sessions/$SID/pending/$ID_Z/accept" "$TLA"; st "Zeynep kabul" 200; eq "kabul -> QR kaydi" QR "$(J d.method)"
api POST "/academician/sessions/$SID/pending/$ID_Z/accept" "$TLA"; st "kabul tekrar (idempotent)" 200
api POST "/academician/sessions/$SID/pending/$ID_E/dismiss" "$TLA"; eq "Emre yok say 204" 204 "$ST"
api POST "/academician/sessions/$SID/pending/$ID_E/dismiss" "$TLA"; eq "yok say tekrar 204" 204 "$ST"
api POST "/academician/sessions/$SID/pending/999999999/accept" "$TLA"; st "bilinmeyen istek 404" 404
live_code "$SID" "$TLA"
scan "$TE" "$CODE"; st "reddedilen Emre tekrar okutur 403" 403; code "reddedilen" ATTENDANCE_NOT_ENROLLED
scan "$TLB" "$CODE"; st "akademisyen B okutur 403" 403; code "akademisyen okutma" ATTENDANCE_NOT_ENROLLED
api GET "/academician/sessions/$SID/live" "$TLA"
eq "kabulden sonra: pending 0, present 2, enrolled 4" "0|2|4" "$(J 'd.pendingScans.length+"|"+d.presentCount+"|"+d.enrolledCount')"
api GET /my-courses "$TZ"; yes "Zeynep artik derse kayitli (/my-courses)" "$(J "d.some(c=>c.courseId===$CID)")"
live_code "$SID" "$TLA"
scan "$TZ" "$CODE"; eq "Zeynep kabul sonrasi okutur -> ALREADY" ALREADY "$(J d.status)"

echo "== hocanin son sozu: kaldir / geri al / elle"
api DELETE "/academician/sessions/$SID/records/$ID_A" "$TLA"; eq "A kaydi kaldir 204" 204 "$ST"
api GET "/academician/sessions/$SID/live" "$TLA"
yes "live: A revoked=true" "$(J "d.newRecords.some(r=>r.studentId===$ID_A&&r.revoked===true)")"; eq "live present 1" 1 "$(J d.presentCount)"
live_code "$SID" "$TLA"
scan "$TA" "$CODE"; st "A kaldirildiktan sonra okutur 403" 403; code "A revoked" ATTENDANCE_REVOKED
api PUT "/academician/sessions/$SID/records/$ID_A" "$TLA"; st "A geri al (PUT)" 200; eq "geri alinan MANUAL" MANUAL "$(J d.method)"; eq "revoked=false" false "$(J d.revoked)"
api PUT "/academician/sessions/$SID/records/$ID_B" "$TLA"; st "B elle isaretle" 200; eq "B MANUAL" MANUAL "$(J d.method)"
api PUT "/academician/sessions/$SID/records/$ID_B" "$TLA"; st "B elle (idempotent)" 200
api DELETE "/academician/sessions/$SID/records/$ID_O" "$TLA"; eq "kaydi olmayan DELETE no-op 204" 204 "$ST"
api PUT "/academician/sessions/$SID/records/$ID_O" "$TLA"; ck "kayitsiz ogrenciye elle isaret reddedilir (4xx)" "$([ "${ST:0:1}" = "4" ] && echo 0 || echo 1)" "(durum $ST)"

echo "== kapat / ac / kapali iken duzenleme"
live_code "$SID" "$TLA"; CLOSECODE=$CODE
api POST "/academician/sessions/$SID/close" "$TLA"; st "kapat" 200; eq "CLOSED" CLOSED "$(J d.status)"
scan "$TS" "$CLOSECODE"; st "kapali oturumda taze gorunen kod 422" 422; code "kapali oturum" ATTENDANCE_CODE_INVALID
api POST "/academician/sessions/$SID/reopen" "$TLA"; st "yeniden ac" 200; eq "OPEN" OPEN "$(J d.status)"
live_code "$SID" "$TLA"
scan "$TS" "$CODE"; st "Selin acilan oturumda okutur" 200; eq "Selin -> MARKED" MARKED "$(J d.status)"
api POST "/academician/sessions/$SID/close" "$TLA"; eq "tekrar kapat" CLOSED "$(J d.status)"
api DELETE "/academician/sessions/$SID/records/$ID_S" "$TLA"; eq "kapali oturumda Selin kaydini kaldir 204" 204 "$ST"
api POST "/academician/sessions/$SID/pending/$ID_E/accept" "$TLA"; ck "reddedilen istek kapali oturumda kabul edilebilir (200)" "$([ "$ST" = "200" ] && echo 0 || echo 1)" "(durum $ST, govde $(printf '%s' "$BD" | head -c 120))"
api DELETE "/academician/courses/$CID/enrollments/$ID_E" "$TLA"; eq "Emre'yi dersten cikar 204" 204 "$ST"

echo "== ikinci oturum (dun), bildirimli acilis"
YDAY=$(date -d yesterday +%F 2>/dev/null || date -v-1d +%F)
api POST "/academician/courses/$CID/sessions" "$TLA" '{"lessonDate":"'"$YDAY"'","notify":true}'; st "ikinci oturum (notify=true)" 201
SID2=$(J d.id); eq "ikinci oturum tarihi" "$YDAY" "$(J d.lessonDate)"
live_code "$SID2" "$TLA"
scan "$TA" "$CODE"; eq "A ikinci oturumda MARKED" MARKED "$(J d.status)"
api POST "/academician/sessions/$SID2/close" "$TLA"; st "ikinci oturumu kapat" 200

echo "== devamsizlik matrisi, sinir, /my-courses"
api GET "/academician/courses/$CID/attendance" "$TLA"; st "matris" 200
eq "matris: 2 oturum, 4 ogrenci" "2|4" "$(J 'd.sessions.length+"|"+d.students.length')"
mark() { J "(d.students.find(s=>s.studentId===$1)||{marks:{}}).marks['$2']"; }
eq "oturum1 A PRESENT_MANUAL" PRESENT_MANUAL "$(mark "$ID_A" "$SID")"
eq "oturum1 B PRESENT_MANUAL" PRESENT_MANUAL "$(mark "$ID_B" "$SID")"
eq "oturum1 Zeynep PRESENT_QR" PRESENT_QR "$(mark "$ID_Z" "$SID")"
eq "oturum1 Selin REVOKED" REVOKED "$(mark "$ID_S" "$SID")"
eq "oturum2 A PRESENT_QR" PRESENT_QR "$(mark "$ID_A" "$SID2")"
eq "oturum2 B ABSENT" ABSENT "$(mark "$ID_B" "$SID2")"
eq "oturum2 Selin ABSENT" ABSENT "$(mark "$ID_S" "$SID2")"
api PATCH "/academician/courses/$CID" "$TLA" '{"absenceLimitType":"COUNT","absenceLimitValue":2}'; st "devamsizlik siniri COUNT 2" 200
api GET "/academician/courses/$CID/attendance" "$TLA"
row() { J "(function(){var s=d.students.find(s=>s.studentId===$1);return s.absentCount+'|'+s.atRisk+'|'+s.overLimit})()"; }
eq "A: devamsiz 0, risk yok" "0|false|false" "$(row "$ID_A")"
eq "B: devamsiz 1, atRisk" "1|true|false" "$(row "$ID_B")"
eq "Selin: devamsiz 2 (REVOKED+ABSENT), overLimit" "2|false|true" "$(row "$ID_S")"
eq "matris limit COUNT/2" "COUNT|2" "$(J 'd.limit.type+"|"+d.limit.value')"
for pair in "$ID_A|$TA" "$ID_B|$TB" "$ID_Z|$TZ" "$ID_S|$TS"; do
  sid=${pair%%|*}; tok=${pair##*|}
  api GET "/academician/courses/$CID/attendance" "$TLA"; want=$(row "$sid")
  api GET /my-courses "$tok"; st "my-courses ($sid)" 200
  got=$(J "(function(){var c=d.find(c=>c.courseId===$CID);return c?c.absentCount+'|'+c.atRisk+'|'+c.overLimit:''})()")
  eq "my-courses ogrenci $sid = matris" "$want" "$got"
done
api GET /my-courses "$TS"; eq "Selin my-courses: present 0, session 2, limit COUNT/2" "0|2|COUNT|2" "$(J "(function(){var c=d.find(c=>c.courseId===$CID);return c.presentCount+'|'+c.sessionCount+'|'+c.limit.type+'|'+c.limit.value})()")"
api GET /my-courses "$TA"; eq "A my-courses: akademisyen adi dolu" true "$(J "(function(){var c=d.find(c=>c.courseId===$CID);return !!c.academicianName})()")"

notif_has() { # jeton bildirim-veri-turu -> 0/1 (en cok 6 sn bekler; bildirimler asenkron dagitilir)
  local i
  for i in 1 2 3 4 5 6; do
    api GET "/notifications?size=60" "$1"
    [ "$(J "d.items.some(n=>{var x={};try{x=JSON.parse(n.data||'{}')}catch(e){}return String(x.courseId||x.value)==='$CID'&&x.noticeType==='$2'})")" = "true" ] && { echo 0; return; }
    sleep 1
  done
  echo 1
}
ck "Selin: ABSENCE_EXCEEDED bildirimi (derse bagli)" "$(notif_has "$TS" ABSENCE_EXCEEDED)"
ck "Mehmet: ABSENCE_WARNING bildirimi" "$(notif_has "$TB" ABSENCE_WARNING)"
ck "Ayse: ENROLLED bildirimi" "$(notif_has "$TA" ENROLLED)"
ck "Ayse: ATTENDANCE_STARTED bildirimi (notify=true)" "$(notif_has "$TA" ATTENDANCE_STARTED)"
ck "Ayse: Selin'in uyarisi yok (baskasinin bildirimi sizmaz)" "$(api GET "/notifications?size=60" "$TA"; [ "$(J "d.items.some(n=>/ABSENCE_/.test(n.data||''))")" = "true" ] && echo 1 || echo 0)"
echo "== CSV disa aktarim"
dl "/academician/courses/$CID/attendance.csv" "$TLA" "$TMP/att.csv"; eq "CSV 200" 200 "$ST"
eq "CSV BOM (EF BB BF)" "ef bb bf" "$(head -c 3 "$TMP/att.csv" | od -An -tx1 | tr -d '\n' | sed 's/^ *//')"
eq "CSV 5 satir (baslik + 4 ogrenci)" 5 "$(grep -c . "$TMP/att.csv")"
ck "CSV durum metinleri" "$(grep -q 'Var (QR)' "$TMP/att.csv" && grep -q 'Var (elle)' "$TMP/att.csv" && grep -q 'Silindi' "$TMP/att.csv" && grep -q 'Yok' "$TMP/att.csv" && echo 0 || echo 1)"
echo "   (CSV Content-Type: $(hdr content-type))"

# ================================================================ 4. duyurular ve dosyalar
echo "== duyurular: yedi tur"
FUT=$(date -u -d '+3 days' +%Y-%m-%dT%H:%M:%SZ)
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"LESSON_STARTED"}'; st "LESSON_STARTED" 201
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"LESSON_STARTED"}'; st "LESSON_STARTED tekrar 429" 429; code "tekrar" NOTICE_TOO_FREQUENT
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"ATTENDANCE_STARTED"}'
st "ATTENDANCE_STARTED: notify=true oturumdan sonra 10 dk icinde 429" 429; code "ATTENDANCE_STARTED tekrar" NOTICE_TOO_FREQUENT
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"EXAM","title":"Vize","eventAt":"'"$FUT"'","note":"Salon D-101"}'; st "EXAM" 201; EXAM_ID=$(J d.id)
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"MATERIAL","title":"Hafta 1 notlari"}'; st "MATERIAL" 201
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"LESSON_CANCELLED","eventAt":"'"$FUT"'","note":"Hoca raporlu"}'; st "LESSON_CANCELLED" 201
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"ROOM_CHANGED","title":"B-204"}'; st "ROOM_CHANGED" 201
echo "== duyuru: zorunlu alan eksik -> 4xx"
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"EXAM","title":"Eksik tarih"}'; st "EXAM eventAt eksik 400" 400; code "EXAM eksik" AC_FIELD_INVALID
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"ASSIGNMENT","eventAt":"'"$FUT"'"}'; st "ASSIGNMENT title eksik 400" 400
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"LESSON_CANCELLED","note":"tarihsiz"}'; st "LESSON_CANCELLED eventAt eksik 400" 400
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"ROOM_CHANGED"}'; st "ROOM_CHANGED title eksik 400" 400
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"LESSON_STARTED","title":"olmamali"}'; st "alansiz turde title 400" 400
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"UYDURMA"}'; ck "bilinmeyen tur 4xx" "$([ "${ST:0:1}" = "4" ] && echo 0 || echo 1)" "(durum $ST)"

echo "== dosya yukleme (PDF), uzanti/icerik uyumsuzlugu"
printf '%%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%%%EOF\n' > "$TMP/odev.pdf"
printf 'MZ\x90\x00\x03\x00\x00\x00PE\x00\x00 not a pdf' > "$TMP/evil.pdf"
printf '<html><script>alert(1)</script></html>' > "$TMP/page.html"
SHA_PDF=$(sha256sum "$TMP/odev.pdf" | cut -d' ' -f1)
upload() { # dosya jeton ders ad tur
  local r; r=$(curl -s -m 30 -w '\n%{http_code}' -H "Authorization: Bearer $2" -F "file=@$(winp "$1");filename=$4;type=$5" "$A/academician/courses/$3/notice-files")
  ST=$(printf '%s' "$r" | tail -n 1); BD=$(printf '%s' "$r" | sed '$d')
}
upload "$TMP/odev.pdf" "$TLA" "$CID" odev.pdf application/pdf; st "PDF yukle" 201; FID=$(J d.id)
eq "PDF: sunucu turu application/pdf, boyut" "application/pdf|$(wc -c < "$TMP/odev.pdf" | tr -d ' ')" "$(J 'd.contentType+"|"+d.sizeBytes')"
upload "$TMP/evil.pdf" "$TLA" "$CID" evil.pdf application/pdf; st "exe baytlari .pdf adiyla 422" 422; code "exe/.pdf" NOTICE_FILE_TYPE_NOT_ALLOWED
upload "$TMP/page.html" "$TLA" "$CID" page.html text/html; st "html 422" 422; code "html" NOTICE_FILE_TYPE_NOT_ALLOWED
upload "$TMP/odev.pdf" "$TLA" "$CID" odev.exe application/octet-stream; st "pdf baytlari .exe adiyla 422" 422
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"ASSIGNMENT","title":"Odev 1","eventAt":"'"$FUT"'","note":"PDF ekte","fileIds":['"$FID"']}'
st "ASSIGNMENT + dosya" 201; NID=$(J d.id); eq "duyuruda 1 dosya" 1 "$(J d.files.length)"
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"ROOM_CHANGED","title":"C-1","fileIds":['"$FID"']}'; ck "dosya izinsiz turde (ROOM_CHANGED) 4xx" "$([ "${ST:0:1}" = "4" ] && echo 0 || echo 1)" "(durum $ST)"

echo "== ogrenci tarafi: liste, yaklasan, indirme"
api GET "/my-courses/$CID/notices" "$TA"; st "A duyurular" 200
eq "A duyuru listesinde ASSIGNMENT + dosya" 1 "$(J "d.items.filter(n=>n.type==='ASSIGNMENT'&&n.files.length===1).length")"
api GET "/my-courses/$CID/notices" "$TE"; st "Emre (cikarildi) duyuru listesi 403" 403; code "kayitsiz liste" ATTENDANCE_NOT_ENROLLED
api GET /my-courses/upcoming "$TA"; st "upcoming" 200
yes "upcoming: sinav + odev (gelecek)" "$(J "d.some(u=>u.type==='EXAM'&&u.courseId===$CID)&&d.some(u=>u.type==='ASSIGNMENT'&&u.courseId===$CID)")"
dl "/my-courses/$CID/notices/$NID/files/$FID" "$TA" "$TMP/got.pdf"; eq "A dosya indirir 200" 200 "$ST"
eq "indirilen bayt = yuklenen (sha256)" "$SHA_PDF" "$(sha256sum "$TMP/got.pdf" | cut -d' ' -f1)"
ck "Content-Disposition: attachment" "$(hdr content-disposition | grep -qi '^content-disposition: *attachment' && echo 0 || echo 1)" "($(hdr content-disposition))"
ck "X-Content-Type-Options: nosniff" "$(hdr x-content-type-options | grep -qi nosniff && echo 0 || echo 1)" "($(hdr x-content-type-options))"
echo "   (indirme basliklari: $(hdr content-type) | $(hdr cache-control) | $(hdr content-disposition))"
dl "/my-courses/$CID/notices/$NID/files/$FID" "$TE" "$TMP/x1"; eq "kayitsiz ogrenci indirme 404" 404 "$ST"
dl "/academician/notices/$NID/files/$FID" "$TLB" "$TMP/x2"; eq "ikinci akademisyen indirme 404" 404 "$ST"
dl "/academician/notices/$NID/files/$FID" "$TLA" "$TMP/x3"; eq "sahip hoca indirir 200" 200 "$ST"
eq "sahip hoca baytlari ayni" "$SHA_PDF" "$(sha256sum "$TMP/x3" | cut -d' ' -f1)"
dl "/admin/academicians/notices/$NID/files/$FID" "$TADM" "$TMP/x4"; eq "yonetici indirir 200" 200 "$ST"
dl "/academician/notices/$NID/files/$FID" "" "$TMP/x5"; ck "jetonsuz indirme 401/403" "$([ "$ST" = "401" ] || [ "$ST" = "403" ] && echo 0 || echo 1)" "(durum $ST)"

# ================================================================ 5. sahiplik (ikinci akademisyen)
echo "== sahiplik: B, A'nin dersine/oturumuna/duyurusuna dokunamaz (404)"
for p in "GET /academician/courses/$CID" "PATCH /academician/courses/$CID" "DELETE /academician/courses/$CID" \
         "GET /academician/courses/$CID/enrollments" "GET /academician/courses/$CID/sessions" "GET /academician/courses/$CID/attendance" \
         "GET /academician/courses/$CID/attendance.csv" "GET /academician/courses/$CID/notices" \
         "GET /academician/sessions/$SID" "GET /academician/sessions/$SID/live" "POST /academician/sessions/$SID/close" \
         "POST /academician/sessions/$SID/reopen" "PUT /academician/sessions/$SID/records/$ID_A" "DELETE /academician/sessions/$SID/records/$ID_A" \
         "POST /academician/sessions/$SID/pending/$ID_E/accept" "POST /academician/sessions/$SID/pending/$ID_E/dismiss" \
         "DELETE /academician/notices/$NID"; do
  m=${p%% *}; path=${p#* }
  body=""; [ "$m" = "PATCH" ] && body='{"name":"ele gecirildi"}'
  api "$m" "$path" "$TLB" "$body"; eq "B $m $path -> 404" 404 "$ST"
done
api POST "/academician/courses/$CID/sessions" "$TLB" '{}'; st "B baskasinin dersinde oturum acamaz 404" 404
api POST "/academician/courses/$CID/enrollments" "$TLB" '{"studentIds":['"$ID_O"']}'; st "B baskasinin dersine kayit ekleyemez 404" 404
api POST "/academician/courses/$CID/notices" "$TLB" '{"type":"LESSON_STARTED"}'; st "B baskasinin dersine duyuru atamaz 404" 404
upload "$TMP/odev.pdf" "$TLB" "$CID" x.pdf application/pdf; st "B baskasinin dersine dosya yukleyemez 404" 404
api GET "/academician/courses" "$TLB"; eq "B ders listesinde A'nin dersi yok" false "$(J "d.some(c=>c.id===$CID)")"

echo "== yetki bosluklari: baska derse bagli duyuru/dosya, baskasinin bekleyen dosyasi"
api POST /academician/courses "$TLA" '{"name":"Ikinci Ders '"$RND"'","term":"2026 Guz","department":"Matematik"}'; st "A ikinci ders" 201; CID2=$(J d.id)
api POST "/academician/courses/$CID2/enrollments" "$TLA" '{"studentIds":['"$ID_O"']}'; eq "Ozan yalniz 2. derse kayitli" 1 "$(J d.added)"
dl "/my-courses/$CID2/notices/$NID/files/$FID" "$TO" "$TMP/y1"; eq "ogrenci: baska dersin duyurusunun dosyasi (yol-kimlik uyumsuz) 404" 404 "$ST"
dl "/my-courses/$CID/notices/$NID/files/$FID" "$TO" "$TMP/y2"; eq "ogrenci: kayitli olmadigi dersin dosyasi 404" 404 "$ST"
api GET "/my-courses/$CID2/notices" "$TO"; st "Ozan 2. ders duyuru listesi" 200; eq "2. derste duyuru yok (1. dersinkiler sizmaz)" 0 "$(J d.items.length)"
upload "$TMP/odev.pdf" "$TLA" "$CID" bekleyen.pdf application/pdf; st "A bekleyen dosya yukler" 201; PF=$(J d.id)
api DELETE "/academician/notice-files/$PF" "$TLB"; ck "B, A'nin bekleyen dosyasini silemez (404)" "$([ "$ST" = "404" ] && echo 0 || echo 1)" "(durum $ST)"
api POST /academician/courses "$TLB" '{"name":"B Dersi '"$RND"'","term":"2026 Guz","department":"Matematik"}'; st "B kendi dersini olusturur" 201; BCID=$(J d.id)
api POST "/academician/courses/$BCID/notices" "$TLB" '{"type":"MATERIAL","title":"Calinti","fileIds":['"$PF"']}'
ck "B, A'nin bekleyen dosyasini kendi duyurusuna BAGLAYAMAZ (4xx; gelen $ST)" "$([ "${ST:0:1}" = "4" ] && echo 0 || echo 1)" "(durum $ST: baskasinin dosyasi calinabiliyor)"
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"MATERIAL","title":"Gecersiz dosya","fileIds":[999999999]}'; ck "var olmayan fileId 4xx" "$([ "${ST:0:1}" = "4" ] && echo 0 || echo 1)" "(durum $ST)"
api DELETE "/academician/notice-files/$PF" "$TLA"; eq "A kendi bekleyen dosyasini siler 204" 204 "$ST"
api GET "/academician/students?q=Seed%20Yonetici" "$TLA"; eq "yonetici hesabi ogrenci rehberinde yok" 0 "$(J d.items.length)"
api GET "/academician/students?q=%25&size=100" "$TLA"; ck "rehber q=% joker: tum liste donmez (bos ya da sinirli)" "$([ "$(J d.items.length)" -lt 5 ] && echo 0 || echo 1)" "($(J d.items.length) kayit)"
api GET /academician/me ""; st "jetonsuz me 401" 401
api GET /academician/courses "$TA"; st "ogrenci (akademisyen degil) panel 403" 403
echo "== dosya turleri ve sinirlar"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' | base64 -d > "$TMP/pix.png" 2>/dev/null
upload "$TMP/pix.png" "$TLA" "$CID" pix.png image/png; st "PNG kabul" 201; PNGID=$(J d.id); eq "PNG sunucu turu" image/png "$(J d.contentType)"
upload "$TMP/odev.pdf" "$TLA" "$CID" makro.docm application/vnd.ms-word.document.macroEnabled.12; st "docm reddedilir 422" 422; code "docm" NOTICE_FILE_TYPE_NOT_ALLOWED
upload "$TMP/pix.png" "$TLA" "$CID" sahte.pdf application/pdf; st "PNG baytlari .pdf adiyla 422" 422
printf 'Merhaba ders notu\n' > "$TMP/not.txt"; upload "$TMP/not.txt" "$TLA" "$CID" "../../etc/not.txt" text/plain
echo "   (yol gecisli ad: durum $ST, kayitli ad: $(J d.name))"
ck "yol gecisli dosya adi temizlenir (ad '/' ve '..' icermez)" "$(printf '%s' "$(J d.name)" | grep -qE '/|\\|\.\.' && echo 1 || echo 0)"
TXTID=$(J d.id)
{ printf '%%PDF-1.4\n'; head -c 21000000 /dev/zero; } > "$TMP/big.pdf"
upload "$TMP/big.pdf" "$TLA" "$CID" buyuk.pdf application/pdf; ck "21 MB dosya 413 ile reddedilir (ya da sunucu govdeyi okumadan baglantiyi kapatir; gelen $ST)" "$([ "$ST" = "413" ] || [ "$ST" = "100" ] || [ "$ST" = "000" ] && echo 0 || echo 1)"
echo "   (21 MB: kod '$(J d.code)'; beklenen NOTICE_FILE_TOO_LARGE, genel sinir filtresi PAYLOAD_TOO_LARGE verir)"
{ printf '%%PDF-1.4\n'; head -c 204800 /dev/zero; } > "$TMP/k200.pdf"
upload "$TMP/k200.pdf" "$TLA" "$CID" k200.pdf application/pdf; eq "200 KB PDF kabul 201 (gercek odev dosyasi boyutu)" 201 "$ST"; K200=$(J d.id)
echo "   (200 KB yukleme: durum $ST kod '$(J d.code)')"
for f in $PNGID $TXTID $K200; do [ -n "$f" ] && api DELETE "/academician/notice-files/$f" "$TLA"; done
IDS=""
for i in 1 2 3 4 5; do upload "$TMP/odev.pdf" "$TLA" "$CID" "ek$i.pdf" application/pdf; [ "$ST" = "201" ] || echo "   (ek$i yukleme: durum $ST kod '$(J d.code)')"; IDS="$IDS${IDS:+,}$(J d.id)"; done
upload "$TMP/odev.pdf" "$TLA" "$CID" ek6.pdf application/pdf; st "6. bekleyen dosya 422 (en cok 5)" 422; code "6. dosya" NOTICE_FILE_LIMIT
api POST "/academician/courses/$CID/notices" "$TLA" '{"type":"MATERIAL","title":"Bes dosya","fileIds":['"$IDS"']}'; st "5 dosyali MATERIAL" 201; eq "5 dosya baglandi" 5 "$(J d.files.length)"

echo "== yonetici salt okunur uclar"
api GET "/admin/academicians/$UID_A/courses" "$TADM"; st "admin: A'nin dersleri" 200; yes "listede ders var" "$(J "d.some(c=>c.id===$CID)")"
api GET "/admin/academicians/courses/$CID" "$TADM"; st "admin ders detay" 200
api GET "/admin/academicians/courses/$CID/attendance" "$TADM"; st "admin matris" 200; eq "admin matris 4 ogrenci" 4 "$(J d.students.length)"
api GET "/admin/academicians/courses/$CID/notices" "$TADM"; st "admin duyurular" 200; yes "admin: dosyali duyuru" "$(J "d.items.some(n=>n.id===$NID&&n.files.length===1)")"
api GET "/admin/academicians?status=APPROVED,REVOKED&q=$RND" "$TADM"; st "admin cok durumlu liste" 200; ck "admin liste >=3 (A,B,C)" "$([ "$(J d.items.length)" -ge 3 ] && echo 0 || echo 1)"
api GET "/admin/academicians/999999999" "$TADM"; st "admin bilinmeyen akademisyen 404" 404
api GET "/admin/academicians/courses/999999999" "$TADM"; st "admin bilinmeyen ders 404" 404

echo "== duyuru silme -> indirme 404; ders silme"
api DELETE "/academician/notices/$NID" "$TLA"; eq "duyuru sil 204" 204 "$ST"
dl "/my-courses/$CID/notices/$NID/files/$FID" "$TA" "$TMP/x6"; eq "silinen duyurunun dosyasi 404" 404 "$ST"
dl "/academician/notices/$NID/files/$FID" "$TLA" "$TMP/x7"; eq "silinen duyurunun dosyasi (sahip) 404" 404 "$ST"

# ================================================================ 6. hiz siniri (en sonda: Ozan'in 1 dakikalik penceresi)
echo "== hiz siniri: tek kullanici 10 tarama/dk (gercek Redis)"
FIRST429=0; GOT422=0
for i in $(seq 1 14); do
  scan "$TO" "bingol-lesson:$SID.1.AAAAAAAAAAAAAAAAAAAAAA"
  [ "$ST" = "422" ] && GOT422=$((GOT422 + 1))
  if [ "$ST" = "429" ] && [ "$FIRST429" = "0" ]; then FIRST429=$i; fi
done
ck "10 tarama sonrasi 429 tetiklendi (ilk 429: istek #$FIRST429, 422 sayisi $GOT422)" "$([ "$FIRST429" != "0" ] && echo 0 || echo 1)" "(14 istekte 429 yok: sinirlayici calismiyor)"
eq "429 tam 11. istekte (10 izinli)" 11 "$FIRST429"
RETRY=$(curl -s -D - -o /dev/null -X POST -H "Authorization: Bearer $TO" -H 'Content-Type: application/json' -d '{"code":"x"}' "$A/attendance/scan" | grep -i '^retry-after' | tr -d '\r')
echo "   (429 yaniti: ${RETRY:-Retry-After basligi yok})"
api DELETE "/academician/courses/$CID" "$TLA"; st "ders sil 204" 204
api GET "/academician/courses/$CID" "$TLA"; st "silinen ders 404" 404
api GET /my-courses "$TA"; eq "silinen ders A'nin listesinde yok" false "$(J "d.some(c=>c.courseId===$CID)")"

echo
echo "================ OZET ================"
echo "Ozet: toplam=$TOTAL gecen=$PASSED basarisiz=$FAILED"
if [ "$FAILED" != "0" ]; then echo "Basarisiz adimlar:"; echo "${FAILED_LIST#|}" | tr '|' '\n' | sed 's/^/  - /'; exit 1; fi
echo "TAMAM"
