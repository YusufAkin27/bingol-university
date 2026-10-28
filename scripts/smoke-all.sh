#!/usr/bin/env bash
# Tum duman betiklerini (scripts/smoke*.sh) sirayla kosar, aralarinda Redis flushall yapar, ozet tablo basar.
# Kullanim:
#   BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ADMIN_PASSWORD=... ./scripts/smoke-all.sh
#   ONLY="smoke-poll smoke-search" ./scripts/smoke-all.sh        # yalniz secilenler (ad, .sh'siz)
#   SKIP="smoke-admin-verify" ./scripts/smoke-all.sh             # secilenleri atla
#   LOG_DIR=./smoke-logs ./scripts/smoke-all.sh                  # betik ciktilarinin yazilacagi klasor
# Onkosul: calisan yigin (docker compose up -d), MAIL_ENABLED=false (dogrulama kodu log'dan okunur),
#   ADMIN_EMAILS=$ADMIN_EMAIL ve ADMIN_PASSWORD (.env ile ayni), LEGAL_ENFORCE_REACCEPT=false.
# Betikler "docker compose logs backend" ve "docker compose exec -T redis|postgres ..." kullanir: repo kokunden
#   (ya da compose projesinin bulundugu dizinden) calistirin; farkli bir yigin icin FLUSH_CMD ile ezin.
# Cikis kodu: herhangi bir betik basarisizsa 1 (cikis kodu 2 = ATLANDI sayilir, basarisizlik degildir), aksi 0.
set -u
cd "$(dirname "$0")/.." || exit 1

export BASE=${BASE:-http://localhost:8080}
export ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
export ADMIN_PASSWORD=${ADMIN_PASSWORD:-}
export SKIP_REMINDER=${SKIP_REMINDER:-1} # smoke-communities-events: ~3 dk'lik hatirlatma adimini atla
FLUSH_CMD=${FLUSH_CMD:-docker compose exec -T redis redis-cli flushall}
LOG_DIR=${LOG_DIR:-$(mktemp -d)}
mkdir -p "$LOG_DIR"
ONLY=${ONLY:-}
SKIP=${SKIP:-}

# Sira: cekirdek once, sonra modul betikleri alfabetik. smoke-all.sh kendisini atlar.
SCRIPTS=()
[ -f scripts/smoke.sh ] && SCRIPTS+=("smoke")
for f in scripts/smoke-*.sh; do
  n=$(basename "$f" .sh)
  [ "$n" = "smoke-all" ] && continue
  SCRIPTS+=("$n")
done

want() { # ad -> ONLY/SKIP'e gore kosulsun mu
  local n=$1
  if [ -n "$ONLY" ]; then case " $ONLY " in *" $n "*) ;; *) return 1 ;; esac; fi
  case " $SKIP " in *" $n "*) return 1 ;; esac
  return 0
}

ROWS=()
TOTAL_OK=0
TOTAL_FAIL=0
ANY_FAIL=0
START=$(date +%s)

for n in "${SCRIPTS[@]}"; do
  want "$n" || continue
  $FLUSH_CMD >/dev/null 2>&1 || echo "uyari: Redis flushall calismadi ($FLUSH_CMD)" >&2
  echo ">> $n"
  t0=$(date +%s)
  bash "scripts/$n.sh" >"$LOG_DIR/$n.log" 2>&1
  rc=$?
  dt=$(( $(date +%s) - t0 ))
  # Sayim: "ok" ile baslayan satirlar basarili, "FAIL" iceren satirlar basarisiz adimdir.
  ok=$(grep -aEc '^[[:space:]]*(ok|OK|PASS)([[:space:]]|:|$)' "$LOG_DIR/$n.log")
  fail=$(grep -aEc '(^|[[:space:]])(FAIL|FAILED)([[:space:]:]|$)' "$LOG_DIR/$n.log")
  if [ "$rc" = "2" ]; then
    status="ATLANDI"
  elif [ "$rc" != "0" ] || [ "$fail" != "0" ]; then
    status="BASARISIZ"
    ANY_FAIL=1
  else
    status="TAMAM"
  fi
  TOTAL_OK=$((TOTAL_OK + ok))
  TOTAL_FAIL=$((TOTAL_FAIL + fail))
  ROWS+=("$(printf '%-34s %6s %6s %5s %5ss  %s' "$n" "$ok" "$fail" "$rc" "$dt" "$status")")
  [ "$status" = "BASARISIZ" ] && echo "   -> BASARISIZ (cikis=$rc, FAIL=$fail); son satirlar:" && tail -n 5 "$LOG_DIR/$n.log" | sed 's/^/      /'
done

echo
echo "================ DUMAN OZETI ================"
printf '%-34s %6s %6s %5s %6s  %s\n' "betik" "ok" "fail" "cikis" "sure" "durum"
for r in "${ROWS[@]}"; do echo "$r"; done
echo "---------------------------------------------"
printf '%-34s %6s %6s\n' "TOPLAM (${#ROWS[@]} betik)" "$TOTAL_OK" "$TOTAL_FAIL"
echo "gecen sure: $(( $(date +%s) - START )) sn; betik ciktilari: $LOG_DIR"
if [ "$ANY_FAIL" = "0" ]; then echo "SONUC: TUMU GECTI"; exit 0; fi
echo "SONUC: BASARISIZ BETIK VAR"
exit 1
