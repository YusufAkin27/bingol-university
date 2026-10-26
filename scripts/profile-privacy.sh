#!/usr/bin/env bash
# T11 uctan uca: profil gizliligi, tamamlama, ad dogrulama, avatar raporu. ASCII, tekrar calistirilabilir.
# Kullanim: BASE=http://localhost:8111 COMPOSE_PROJECT_NAME=wt_t11 ./scripts/profile-privacy.sh
# Oncesinde: docker compose exec -T redis redis-cli flushall
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
SFX=$(date +%s)
PASS=Sifre1234
FAIL=0
ok() { echo "OK   $1"; }
bad() { echo "FAIL $1"; FAIL=1; }
check() { # ad beklenen gercek
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (beklenen=$2 gercek=$3)"; fi
}
has() { case "$3" in *"$2"*) ok "$1";; *) bad "$1 (yok: $2)";; esac; }
hasnot() { case "$3" in *"$2"*) bad "$1 (var: $2)";; *) ok "$1";; esac; }

mk() { # eposta ad -> token
  "$(dirname "$0")/make-user.sh" "$1" "$2" $PASS >/dev/null 2>&1
  curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"$PASS\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}
id_of() { curl -s -H "Authorization: Bearer $1" $A/users/me | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
api() { tok=$1; shift; curl -s -H "Authorization: Bearer $tok" -H "$H" "$@"; }

TA=$(mk "pp-a-$SFX@bingol.edu.tr" "Alice Owner")
TB=$(mk "pp-b-$SFX@bingol.edu.tr" "Bob Stranger")
TC=$(mk "pp-c-$SFX@bingol.edu.tr" "Carol Friend")
[ -z "$TA" ] || [ -z "$TB" ] || [ -z "$TC" ] && { echo "kullanici hazirlanamadi"; exit 1; }
IA=$(id_of "$TA"); IB=$(id_of "$TB"); IC=$(id_of "$TC")

# Profil doldur (avatar yuklemesi T1'in isi: avatarUrl bu betikte test edilmez, alanlar edilir)
api "$TA" -X PATCH $A/users/me -d '{"bio":"gizli bio","department":"Bilgisayar","classYear":3}' >/dev/null

# 1) Varsayilan: herkes gorur
has "default bio gorunur" "gizli bio" "$(api "$TB" $A/users/$IA)"

# 2) bio ONLY_ME, department SHARED_CONTEXT
R=$(api "$TA" -X PATCH $A/users/me/privacy -d '{"bio":"ONLY_ME","department":"SHARED_CONTEXT","avatar":"SHARED_CONTEXT"}')
has "privacy guncellendi" '"bio":"ONLY_ME"' "$R"
P=$(api "$TB" $A/users/$IA)
hasnot "yabanci bio goremez" "gizli bio" "$P"
hasnot "yabanci bolum goremez" "Bilgisayar" "$P"
has "sinif hala gorunur" '"classYear":3' "$P"
has "sahibi kendi bio'sunu gorur" "gizli bio" "$(api "$TA" $A/users/me)"
hasnot "arama sonucunda da gizli" "gizli bio" "$(api "$TB" "$A/users/search?q=Alice")"

# 3) ortak sohbet -> SHARED_CONTEXT alanlari acilir
api "$TC" -X POST $A/conversations -d "{\"userId\":$IA}" >/dev/null
has "ortak sohbetle bolum gorunur" "Bilgisayar" "$(api "$TC" $A/users/$IA)"
hasnot "ortak sohbetle ONLY_ME hala gizli" "gizli bio" "$(api "$TC" $A/users/$IA)"

# 4) gecersiz deger
check "gecersiz audience 400" 400 "$(code -X PATCH -H "Authorization: Bearer $TA" -H "$H" $A/users/me/privacy -d '{"bio":"NOBODY"}')"

# 5) tamamlama
C=$(api "$TA" $A/users/me/completeness)
has "completeness percent" '"percent"' "$C"
has "completeness missing avatar" '"field":"avatar"' "$C"
C2=$(curl -s -H "Authorization: Bearer $TA" -H "Accept-Language: en" -H "$H" $A/users/me/completeness)
has "oneri ingilizce" "Add a profile photo" "$C2"

# 6) gorunen ad dogrulama
check "bidi override reddi" 400 "$(code -X PATCH -H "Authorization: Bearer $TB" -H "$H" $A/users/me -d '{"displayName":"Bob‮Evil"}')"
check "zero-width reddi" 400 "$(code -X PATCH -H "Authorization: Bearer $TB" -H "$H" $A/users/me -d '{"displayName":"Bo​b Test"}')"
check "admin taklidi reddi" 400 "$(code -X PATCH -H "Authorization: Bearer $TB" -H "$H" $A/users/me -d '{"displayName":"Adm1n"}')"
check "normal ad kabul" 200 "$(code -X PATCH -H "Authorization: Bearer $TB" -H "$H" $A/users/me -d '{"displayName":"Bob Stranger"}')"

# 7) avatar raporu (avatari olmayan hesap raporlanamaz -> 404; kendi avatarini raporlayamaz)
check "avatarsiz rapor 404" 404 "$(code -X POST -H "Authorization: Bearer $TB" -H "$H" $A/reports -d "{\"targetType\":\"USER_AVATAR\",\"targetId\":$IA,\"reason\":\"INAPPROPRIATE\"}")"

# 8) KVKK export gizlilik bolumunu icerir
has "export profilePrivacy" '"profilePrivacy"' "$(api "$TA" $A/users/me/export)"

# 9) engel -> 404
api "$TB" -X POST $A/blocks/$IA >/dev/null 2>&1
echo "(engel ucu duman betiklerinde dogrulanir)"

# 10) hesap silme sonrasi profil 404
check "silinen hesap 404" 204 "$(code -X DELETE -H "Authorization: Bearer $TC" -H "$H" $A/users/me -d "{\"password\":\"$PASS\"}")"
check "silinmis kullanici profili 404" 404 "$(code -H "Authorization: Bearer $TB" $A/users/$IC)"

[ $FAIL = 0 ] && echo "TUMU GECTI" || { echo "BAZI KONTROLLER BASARISIZ"; exit 1; }
