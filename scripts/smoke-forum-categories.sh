#!/usr/bin/env bash
# Kampus Forum kategori genisletme (V1480) duman testi: >= 50 kategori + gruplar, kategori aramasi (q=, Turkce karakter
# duyarsiz), yeni kategoride konu acma, konu aramasinin kategori adiyla eslesmesi. GERCEK PostgreSQL gerekir.
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-forum-categories.sh
# Onkosul: compose'ta MAIL_ENABLED=false (dogrulama kodu log'dan okunur); forum surumu (V1400-V1480) birlesmis.
# Betik tekrar calistirilabilir. Betikler arasinda: docker compose exec -T redis redis-cli flushall (kayit ucu IP basina saatte 10).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0

check() { # ad beklenen gercek
  if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
jid() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
expect_has() { # ad metin govde
  if printf '%s' "$3" | grep -q -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(printf '%s' "$3" | cut -c1-300)"; FAIL=1; fi
}
expect_not() { # ad metin govde
  if printf '%s' "$3" | grep -q -- "$2"; then echo "  FAIL $1 (olmamaliydi: $2)"; FAIL=1; else echo "  ok   $1"; fi
}
count_ids() { grep -o '"slug":"' | wc -l | tr -d ' '; }

register() { # email ad
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Zk7-Qmv-Lpx92w\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Zk7-Qmv-Lpx92w\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}

SFX=$RANDOM
TA=$(register "fcat$SFX@bingol.edu.tr" "Kategori Yazar")
[ -n "$TA" ] || { echo "kayit basarisiz"; exit 1; }
AA="Authorization: Bearer $TA"

echo "== liste: en az 50 kategori, gruplar, uc dil"
check "girissiz kategori listesi 401" 401 "$(code $A/forum/categories)"
ALL=$(curl -s -H "$AA" $A/forum/categories)
N=$(printf '%s' "$ALL" | count_ids)
if [ "$N" -ge 50 ]; then echo "  ok   kategori sayisi $N (>= 50)"; else echo "  FAIL kategori sayisi $N (< 50)"; FAIL=1; fi
expect_has "eski kategori Gundem korundu" '"slug":"gundem"' "$ALL"
expect_has "eski kategori Oneri ve Sikayet korundu" '"slug":"oneri-sikayet"' "$ALL"
expect_has "yeni kategori Muzik" '"slug":"muzik"' "$ALL"
expect_has "grup anahtari" '"groupKey":"hobi"' "$ALL"
expect_has "grup adi (tr)" '"groupName":"Hobi & E' "$ALL"
expect_has "grup sirasi" '"groupOrder":70' "$ALL"
EN=$(curl -s -H "$AA" -H 'Accept-Language: en' $A/forum/categories)
expect_has "ingilizce kategori adi" '"name":"Music"' "$EN"
expect_has "ingilizce grup adi" '"groupName":"Hobbies & Fun"' "$EN"
AR=$(curl -s -H "$AA" -H 'Accept-Language: ar' $A/forum/categories)
expect_not "arapca liste ingilizce ad tasimaz" '"name":"Music"' "$AR"
# ilk kategoriler (cip satiri) eski 8'li: Gundem ilk sirada
FIRST=$(printf '%s' "$ALL" | grep -o '"slug":"[a-z0-9-]*"' | head -1)
check "ilk sirada Gundem" '"slug":"gundem"' "$FIRST"

echo "== kategori aramasi (q=)"
Q1=$(curl -s -H "$AA" "$A/forum/categories?q=M%C3%9CZ%C4%B0K")
expect_has "buyuk harf + Turkce karakter: MUZIK -> muzik" '"slug":"muzik"' "$Q1"
Q2=$(curl -s -H "$AA" -G --data-urlencode "q=muzik" $A/forum/categories)
expect_has "noktasiz: muzik -> Muzik" '"slug":"muzik"' "$Q2"
expect_not "muzik aramasi yurtlari getirmez" '"slug":"yurtlar"' "$Q2"
Q3=$(curl -s -H "$AA" -G --data-urlencode "q=ogrenci isleri" $A/forum/categories)
expect_has "cok sozcuk + ogrenci isleri" '"slug":"ogrenci-isleri-idari"' "$Q3"
Q4=$(curl -s -H "$AA" -G --data-urlencode "q=hobi" $A/forum/categories)
expect_has "grup adiyla arama (hobi) gruptaki kategoriyi getirir" '"slug":"film-dizi"' "$Q4"
Q5=$(curl -s -H "$AA" -G --data-urlencode "q=music" $A/forum/categories)
expect_has "ingilizce adla arama" '"slug":"muzik"' "$Q5"
Q6=$(curl -s -H "$AA" -G --data-urlencode "q=zzzyokboyle" $A/forum/categories)
check "eslesme yok -> bos dizi" "[]" "$Q6"
Q7=$(curl -s -H "$AA" -G --data-urlencode "q=%" $A/forum/categories)
check "LIKE ozel karakteri literal (% hepsini getirmez)" "[]" "$Q7"
Q8=$(curl -s -H "$AA" -G --data-urlencode "q=   " $A/forum/categories)
N8=$(printf '%s' "$Q8" | count_ids)
check "bos q tum liste" "$N" "$N8"
check "q'lu istek 200" 200 "$(code -H "$AA" -G --data-urlencode "q=ders" $A/forum/categories)"

echo "== yeni kategoride konu + konu aramasi"
CATM=$(printf '%s' "$Q2" | grep -o '"id":[0-9]*,"slug":"muzik"' | head -1 | grep -o '[0-9]*' | head -1)
[ -n "$CATM" ] || { echo "  FAIL muzik kategori kimligi okunamadi"; exit 1; }
W="gitarakordu$SFX"
RT=$(curl -s -w ' %{http_code}' -X POST -H "$AA" -H "$H" -H "Idempotency-Key: fcat-$SFX-1" $A/forum/topics \
  -d "{\"title\":\"Gitar akordu $W sorusu\",\"body\":\"Baslangic icin hangi akorlar $W\",\"categoryId\":$CATM,\"anonymous\":false,\"imageIds\":[]}")
check "muzik kategorisine konu 201" 201 "${RT##* }"
TID=$(echo "$RT" | jid)
sleep 1
S1=$(curl -s -H "$AA" "$A/forum/search?q=$W&categoryId=$CATM")
expect_has "kategori filtreli arama konuyu buldu" "\"id\":$TID" "$S1"
S2=$(curl -s -H "$AA" -G --data-urlencode "q=muzik" --data-urlencode "sort=NEWEST" $A/forum/search)
expect_has "kategori adi (muzik) ile konu aramasi: konu geldi" "\"id\":$TID" "$S2"
TL=$(curl -s -H "$AA" "$A/forum/topics?categoryId=$CATM&sort=NEWEST")
expect_has "kategori filtreli konu listesi" "\"id\":$TID" "$TL"

echo
if [ "$FAIL" = 0 ]; then echo "TUM ADIMLAR GECTI"; else echo "BAZI ADIMLAR BASARISIZ"; exit 1; fi
