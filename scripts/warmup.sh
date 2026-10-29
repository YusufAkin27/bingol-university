#!/usr/bin/env bash
# Dagitim sonrasi SOGUK JVM isitma: birkac yuz HAFIF, SALT-OKUR istek (JIT, Hikari havuzu, Hibernate/Jackson onbellekleri,
# Caddy->backend baglantilari). Gercek kullanici trafigi gelmeden ONCE (ya da dusuk trafikte) calistirin; veri DEGISTIRMEZ.
# Soguk JVM'de ilk dakikalar 10-20 kat yavastir (CLAUDE.md, docs/PERFORMANCE.md): isitmadan olcum/alarm esiklerine guvenmeyin.
#
# Kullanim:  BASE=https://bukampus.com.tr bash scripts/warmup.sh
#   Ortam:   BASE (varsayilan http://localhost:8080)   N=toplam istek (300)   PAR=es zamanli istek (4, kucuk VPS icin dusuk)
#            PAUSE_MS=istekler arasi bekleme (50)   TOKEN=erisim jetonu (verilirse oturumlu okuma uclari da isitilir)
#            MAX_FAIL_PCT=izin verilen hata yuzdesi (2)
# Cikis kodu: 0 = tamam; 1 = hata orani esigi asildi (dagitimi dogrulayin); 2 = kullanim/baglanti hatasi.
# Yalnizca GET; kimlik/e-posta gonderen, yazan, rate-limit'e takilacak yogunlukta istek YOKTUR (PAR*N/PAUSE dusuk tutulur).
set -u
BASE="${BASE:-http://localhost:8080}"; BASE="${BASE%/}"
N="${N:-300}"; PAR="${PAR:-4}"; PAUSE_MS="${PAUSE_MS:-50}"; MAX_FAIL_PCT="${MAX_FAIL_PCT:-2}"
TOKEN="${TOKEN:-}"
command -v curl >/dev/null || { echo "curl gerekli" >&2; exit 2; }

PUBLIC_PATHS=(
  /api/status /api/app/info "/api/app/version?platform=ANDROID&version=1.0.0"
  "/api/news?size=10" "/api/menu/today" /api/menu
  /api/faq /api/legal /api/legal/PRIVACY /api/legal/TERMS
  /api/catalog/academic /api/catalog/departments /api/faculties
)
AUTH_PATHS=(
  /api/auth/me "/api/users/me" "/api/feed?size=10" /api/conversations /api/conversations/unread-count
  "/api/notifications?size=10" /api/notifications/unread-count
)

# Saglik ucunu bekle (en cok 120 sn): backend henuz aciliyor olabilir
echo "baglanti bekleniyor: $BASE/api/status"
ok=0
for _ in $(seq 1 60); do
  c="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$BASE/api/status" || true)"
  if [ "$c" = 200 ]; then ok=1; break; fi
  sleep 2
done
[ "$ok" = 1 ] || { echo "HATA: $BASE/api/status 120 sn icinde 200 vermedi (son kod: ${c:-yok})" >&2; exit 2; }

PATHS=("${PUBLIC_PATHS[@]}")
[ -n "$TOKEN" ] && PATHS+=("${AUTH_PATHS[@]}")
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT

one() { # yol -> "kod sure_ms yol"
  local p="$1" out
  if [ -n "$TOKEN" ]; then
    out="$(curl -s -o /dev/null -m 20 -H "Authorization: Bearer $TOKEN" -H 'Accept-Language: tr' -w '%{http_code} %{time_total}' "$BASE$p" || echo '000 0')"
  else
    out="$(curl -s -o /dev/null -m 20 -H 'Accept-Language: tr' -w '%{http_code} %{time_total}' "$BASE$p" || echo '000 0')"
  fi
  echo "$out $p"
  [ "$PAUSE_MS" -gt 0 ] && sleep "0.$(printf '%03d' "$PAUSE_MS")"
}
export -f one; export BASE TOKEN PAUSE_MS

echo "isitma: $N istek, ${PAR} es zamanli, ${#PATHS[@]} farkli yol$( [ -n "$TOKEN" ] && echo ' (oturumlu dahil)')"
t0=$(date +%s)
i=0
while [ "$i" -lt "$N" ]; do
  printf '%s\n' "${PATHS[$((i % ${#PATHS[@]}))]}"
  i=$((i+1))
done | xargs -P "$PAR" -I{} bash -c 'one "$@"' _ {} > "$TMP"
t1=$(date +%s)

total="$(wc -l < "$TMP" | tr -d ' ')"
# 2xx/3xx/304 basari; 401/403/404 de "uc ayakta" sayilir ama oturumsuz oturumlu uc cagrilmaz; 5xx ve 000 hata
bad="$(awk '$1 ~ /^(5|0)/ {n++} END {print n+0}' "$TMP")"
echo "tamamlandi: $total istek, $((t1-t0)) sn, hata (5xx/baglanti): $bad"
echo "yol basina ortalama ms (her yolun ilk ucte biri vs son ucte biri; isinma sonrasi dusmeli):"
awk '{print $3, $2*1000}' "$TMP" | awk '
  { n[$1]++; v[$1,n[$1]]=$2 }
  END { for (p in n) {
      c=n[p]; k=int(c/3); if (k<1) k=1; a=0; b=0
      for (i=1;i<=k;i++) { a+=v[p,i]; b+=v[p,c-i+1] }
      printf "  %-38s ilk %7.0f ms   son %7.0f ms   (%d istek)\n", p, a/k, b/k, c } }' | sort
echo "2xx/3xx disi yanitlar (404 = veri yok, 4xx = beklenmeyen):"
awk '$1 !~ /^(2|3)/ {c[$1" "$3]++} END {for (k in c) print "  ! " k " x" c[k]}' "$TMP" | sort | head -20

pct=$(( bad * 100 / (total > 0 ? total : 1) ))
if [ "$pct" -gt "$MAX_FAIL_PCT" ]; then echo "BASARISIZ: hata orani %$pct > %$MAX_FAIL_PCT" >&2; exit 1; fi
echo "TAMAM (hata orani %$pct). Soguk baslangic bitti; gercek trafige acabilirsiniz."
