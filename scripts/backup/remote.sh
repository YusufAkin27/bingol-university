#!/usr/bin/env bash
# Uzak kopya (rclone: Google Drive, S3, SFTP...) ortak islevleri. lib.sh'DEN SONRA kaynaklanir (dogrudan calistirilmaz).
# Env (hepsi istege bagli): BACKUP_REMOTE (rclone hedefi, ornek "gdrive:BU-Kampus-Yedek"),
#   BACKUP_REMOTE_KEEP_DAILY/WEEKLY/MONTHLY (7/4/6), BACKUP_REMOTE_MAX_DELETE (20, bir kosuda en cok silinecek uzak dizin),
#   BACKUP_RCLONE_DRIVE_CHUNK (64M), BACKUP_RCLONE_TIMEOUT (5m), BACKUP_RCLONE_RETRIES (3), BACKUP_REMOTE_BWLIMIT (bos = sinirsiz),
#   BACKUP_REMOTE_MAX_SECONDS (14400: tek yukleme icin ust sure), BACKUP_REMOTE_VERIFY (hash | size), BACKUP_REMOTE_VERIFY_DOWNLOAD (0/1)
# shellcheck shell=bash

REMOTE_BASE="${BACKUP_REMOTE%/}"
RK_DAILY="${BACKUP_REMOTE_KEEP_DAILY:-7}"
RK_WEEKLY="${BACKUP_REMOTE_KEEP_WEEKLY:-4}"
RK_MONTHLY="${BACKUP_REMOTE_KEEP_MONTHLY:-6}"
RC_ERR="${RC_ERR:-$(mktemp /tmp/rclone-err.XXXXXX 2>/dev/null || echo /tmp/rclone-err.$$)}"

# retention_validate: uzak saklama degerlerini dogrular (B2). Gecersiz bir deger (0, bos, sayi olmayan) GFS'yi "hicbir sey
# tutma" hale getirir ve yeni yedek disinda TUM uzak yedekleri siler. Kural: ucu de sayi; gunluk >= 2 (yukleme sirasinda
# bir onceki iyi yedek kalsin); toplam >= 1; BACKUP_REMOTE_MAX_DELETE sayi. Gecersizse 1 + RET_ERR (sirsiz kisa metin); cagiran
# SILMEYI ATLAR ve hata raporlar. Gecerliyse degiskenler 10'luk sayiya normallestirilir (08 -> 8).
RET_ERR=""
retention_validate() {
  local name v
  RET_ERR=""
  for name in RK_DAILY RK_WEEKLY RK_MONTHLY; do
    v="${!name}"
    case "$v" in ''|*[!0-9]*) RET_ERR="$name sayi degil"; return 1;; esac
    [ "${#v}" -le 6 ] || { RET_ERR="$name cok buyuk"; return 1; }
  done
  RK_DAILY=$((10#$RK_DAILY)); RK_WEEKLY=$((10#$RK_WEEKLY)); RK_MONTHLY=$((10#$RK_MONTHLY))
  if [ "$RK_DAILY" -lt 2 ]; then RET_ERR="BACKUP_REMOTE_KEEP_DAILY en az 2 olmali"; return 1; fi
  if [ $((RK_DAILY + RK_WEEKLY + RK_MONTHLY)) -lt 1 ]; then RET_ERR="toplam uzak saklama 0"; return 1; fi
  case "${BACKUP_REMOTE_MAX_DELETE:-20}" in ''|*[!0-9]*) RET_ERR="BACKUP_REMOTE_MAX_DELETE sayi degil"; return 1;; esac
  return 0
}

# remote_target_validate: BACKUP_REMOTE bir KLASOR gostermeli (B6). "gdrive:" ya da "gdrive:/" Drive'in KOKUNU hedef yapar
# (rclone purge/lsf kokte calisir); ".." iceren yol da reddedilir. Gecersizse 1 + TARGET_ERR.
TARGET_ERR=""
remote_target_validate() {
  local p
  TARGET_ERR=""
  case "${BACKUP_REMOTE:-}" in *:*) ;; *) TARGET_ERR="BACKUP_REMOTE 'uzakadi:klasor' bicimde olmali"; return 1;; esac
  p="${BACKUP_REMOTE#*:}"; p="${p#/}"; p="${p%/}"
  if [ -z "$p" ]; then TARGET_ERR="BACKUP_REMOTE klasor icermiyor (kok dizin hedef olamaz): 'uzakadi:KLASOR' kullanin"; return 1; fi
  case "/$p/" in */../*|*/./*) TARGET_ERR="BACKUP_REMOTE yolunda '.' veya '..' olamaz"; return 1;; esac
  return 0
}

# rclone ortak bayraklari. --drive-* bayraklari baska saglayicilarda etkisizdir. Yeniden deneme + dusuk seviye yeniden deneme +
# G/C zaman asimi: gecici ag kesintisi yuklemeyi dusurmesin. --drive-stop-on-upload-limit: Drive 750 GB/gun siniri asilinca
# bosuna denemeyi birakir. Silmeler ayrica --drive-use-trash=false ile (cop kutusu kotadan dusmez, bkz. docs/BACKUP_GDRIVE.md).
RC_OPTS=(--retries "${BACKUP_RCLONE_RETRIES:-3}" --low-level-retries 10 --timeout "${BACKUP_RCLONE_TIMEOUT:-5m}"
         --contimeout 60s --log-level NOTICE --stats 0
         --drive-chunk-size "${BACKUP_RCLONE_DRIVE_CHUNK:-64M}" --drive-stop-on-upload-limit)
[ -z "${BACKUP_REMOTE_BWLIMIT:-}" ] || RC_OPTS+=(--bwlimit "$BACKUP_REMOTE_BWLIMIT")

# rc <rclone-alt-komutu...>: rclone calistirir, hata cikisini $RC_ERR'e toplar (stdout'a dokunmaz)
rc() { rclone "${RC_OPTS[@]}" "$@" 2>>"$RC_ERR"; }

# Hata metnini KISA ve SIRSIZ bir cumleye cevirir (durum dosyasi + panel + webhook). Belirtec, hedef yolu, dosya adi yazilmaz.
classify_error() {
  local t; t="$(tail -n 40 "$RC_ERR" 2>/dev/null | tr -d '\r')"
  case "$t" in
    *invalid_grant*|*"Token has been expired or revoked"*|*"couldn't fetch token"*|*"token expired and there's no refresh token"*)
      echo "Google yetkisi gecersiz veya suresi dolmus (invalid_grant); rclone authorize ile belirteci yenileyin"; return;;
    *storageQuotaExceeded*|*"storage quota"*|*"quotaExceeded"*) echo "Drive depolama kotasi dolu"; return;;
    *"Upload limit"*|*dailyLimitExceeded*|*uploadLimit*) echo "Drive gunluk yukleme siniri asildi"; return;;
    *rateLimitExceeded*|*userRateLimitExceeded*|*"Rate Limit"*) echo "Drive hiz siniri (rate limit); sonraki denemede yeniden"; return;;
    *"didn't find section in config file"*|*"not found in config"*) echo "rclone uzak adi rclone.conf icinde yok"; return;;
    *"no such host"*|*"dial tcp"*|*"i/o timeout"*|*"connection refused"*|*"TLS handshake"*) echo "uzak hedefe ag baglantisi kurulamadi"; return;;
    # "403" tek basina eslesmez (bayt sayisi/dosya adi/yol icinde gecebilir): yalniz HTTP 403 kaliplari (B4)
    *"permission denied"*|*"insufficientPermissions"*|*"Error 403"*|*"403 Forbidden"*|*"status code 403"*|*"HTTP 403"*)
      echo "uzak hedefte izin hatasi (403)"; return;;
  esac
  local last; last="$(printf '%s\n' "$t" | grep -iE 'error|failed' | tail -1)"
  [ -n "$last" ] || last="rclone hatasi"
  # hedef yolu / belirtec / dosya adi sizmasin
  last="$(printf '%s' "$last" | sed -E 's#(ya29|1//)[A-Za-z0-9_.-]+#[gizli]#g; s#[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+#[yol]#g' | cut -c1-160)"
  printf '%s' "$last"
}

# remote_stamps: uzaktaki damga dizinleri (eskiden yeniye). Liste alinamazsa 1; dizin henuz yoksa bos + 0.
remote_stamps() {
  local out rcode=0
  out="$(rc lsf --dirs-only "$REMOTE_BASE")" || rcode=$?
  if [ "$rcode" -ne 0 ]; then
    [ "$rcode" -eq 3 ] && return 0   # dizin bulunamadi: ilk calisma
    return 1
  fi
  printf '%s\n' "$out" | sed 's#/$##' | grep -E "$STAMP_RE" | sort || true
}

# dir_size_json <yol> -> {"count":N,"bytes":B}; yerel yol da uzak yol da olabilir
dir_size_json() { rc size --json "$1" | jq -c '{count:.count, bytes:.bytes}'; }

# verify_remote_copy <yerel-dizin> <uzak-dizin>: indirmeden dogrular (boyut + hash + SHA256SUMS/manifest icerigi).
# Cikis: 0 = ayni; 1 = KESIN fark (boyut/dosya sayisi/hash/icerik uyusmuyor: kopya gercekten bozuk/eksik);
#        2 = DOGRULANAMADI (ag/okuma hatasi, zaman asimi: kopya hakkinda bir sey bilinmiyor). Cagiranlar yalniz 1'de kopyayi
#        silip yeniden yukleyebilir; 2'de SILMEZ (gecici ag hatasi dogru kopyayi yok etmesin, B3). VERIFY_MSG kisa neden.
VERIFY_MSG=""
verify_remote_copy() {
  local src="$1" dst="$2" a b f tmp mark
  VERIFY_MSG=""
  a="$(dir_size_json "$src")" || { VERIFY_MSG="yerel boyut okunamadi"; return 2; }
  b="$(dir_size_json "$dst")" || { VERIFY_MSG="uzak boyut okunamadi"; return 2; }
  [ "$a" = "$b" ] || { VERIFY_MSG="uzak kopya boyutu/dosya sayisi farkli (yerel $a, uzak $b)"; return 1; }
  # hash: Drive/S3/B2 sunucu tarafi MD5 verir -> indirmeden; hash'siz saglayicida (crypt) rclone yalniz boyut karsilastirir
  local chk=(check "$src" "$dst" --one-way)
  [ "${BACKUP_REMOTE_VERIFY:-hash}" != size ] || chk+=(--size-only)
  [ "${BACKUP_REMOTE_VERIFY_DOWNLOAD:-0}" != 1 ] || chk+=(--download)
  mark="$(wc -c < "$RC_ERR" 2>/dev/null || echo 0)"
  if ! rc "${chk[@]}" >/dev/null; then
    # yalniz BU cagrinin ciktisinda "fark bulundu" kalibi varsa kesin fark; yoksa ag/okuma hatasi
    if tail -c +"$((mark + 1))" "$RC_ERR" 2>/dev/null | grep -qiE 'differences found|sizes differ|hashes? differ|md5 differ|sha-?1 differ|file not in|missing on'; then
      VERIFY_MSG="rclone check farki buldu"; return 1
    fi
    VERIFY_MSG="rclone check tamamlanamadi (ag/okuma hatasi)"; return 2
  fi
  # kucuk dosyalar: SHA256SUMS ve manifest.json birebir (dosya adlari/ozetler uzakta bozulmamis olsun)
  for f in SHA256SUMS manifest.json; do
    [ -e "$src/$f" ] || continue
    tmp="$(mktemp /tmp/rverify.XXXXXX)" || { VERIFY_MSG="gecici dosya olusturulamadi"; return 2; }
    if ! rc cat "$dst/$f" > "$tmp"; then rm -f "$tmp"; VERIFY_MSG="$f uzaktan okunamadi"; return 2; fi
    if ! cmp -s "$tmp" "$src/$f"; then rm -f "$tmp"; VERIFY_MSG="$f uzakta farkli"; return 1; fi
    rm -f "$tmp"
  done
  return 0
}

# --- saklama (GFS): tek dizinde, kopya OLUSTURMADAN ---
# days_from_civil <yil> <ay> <gun> -> 1970-01-01'den beri gun sayisi (tarih aritmetigi; date(1) surumune bagli degil)
days_from_civil() {
  local y=$((10#$1)) m=$((10#$2)) d=$((10#$3)) era yoe doy doe
  [ "$m" -gt 2 ] || y=$((y - 1))
  era=$(( (y >= 0 ? y : y - 399) / 400 ))
  yoe=$(( y - era * 400 ))
  doy=$(( (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1 ))
  doe=$(( yoe * 365 + yoe / 4 - yoe / 100 + doy ))
  echo $(( era * 146097 + doe - 719468 ))
}
# week_key <YYYYmmdd> -> pazartesi baslangicli hafta numarasi (1970-01-01 persembe)
week_key() { echo $(( ($(days_from_civil "${1:0:4}" "${1:4:2}" "${1:6:2}") + 3) / 7 )); }

# gfs_keep_list <gunluk> <haftalik> <aylik>   (stdin: damga adlari) -> korunacaklar (stdout, yeniden eskiye)
#  - gunluk : en yeni <gunluk> FARKLI gunun her birinin en yeni yedegi
#  - haftalik: en yeni <haftalik> FARKLI haftanin en yeni yedegi (pazartesi baslangicli)
#  - aylik  : en yeni <aylik> FARKLI ayin en yeni yedegi
# Katmanlar ust uste binebilir (bugunun yedegi hem gunluk hem haftalik sayilir). Bir deger 0 ise o katman kapali.
gfs_keep_list() {
  local kd="$1" kw="$2" km="$3" n day wk mon nd=0 nw=0 nm=0
  declare -A seen_d seen_w seen_m keep
  local names; names="$(grep -E "$STAMP_RE" | sort -r || true)"
  for n in $names; do
    day="${n:0:8}"; mon="${n:0:6}"; wk="$(week_key "$day")"
    if [ -z "${seen_d[$day]:-}" ]; then seen_d[$day]=1; if [ "$nd" -lt "$kd" ]; then keep[$n]=1; nd=$((nd + 1)); fi; fi
    if [ -z "${seen_w[$wk]:-}" ]; then seen_w[$wk]=1; if [ "$nw" -lt "$kw" ]; then keep[$n]=1; nw=$((nw + 1)); fi; fi
    if [ -z "${seen_m[$mon]:-}" ]; then seen_m[$mon]=1; if [ "$nm" -lt "$km" ]; then keep[$n]=1; nm=$((nm + 1)); fi; fi
  done
  for n in $names; do [ -z "${keep[$n]:-}" ] || echo "$n"; done
}

# gfs_delete_list <gunluk> <haftalik> <aylik> (stdin: damgalar) -> silinecekler, EN ESKI ONCE
gfs_delete_list() {
  local all keep n
  all="$(grep -E "$STAMP_RE" | sort || true)"
  [ -n "$all" ] || return 0
  keep="$(printf '%s\n' "$all" | gfs_keep_list "$1" "$2" "$3")"
  for n in $all; do printf '%s\n' "$keep" | grep -qx "$n" || echo "$n"; done
}

# newest_valid_local [dizin]: en yeni GECERLI (SHA256SUMS + db.dump.age var ve sha256 tutuyor) yerel yedegin damgasi
newest_valid_local() {
  local d n
  d="${1:-$BACKUP_DIR/daily}"
  for n in $(ls -1 "$d" 2>/dev/null | grep -E "$STAMP_RE" | sort -r); do
    [ -s "$d/$n/SHA256SUMS" ] && [ -s "$d/$n/db.dump.age" ] || continue
    if (cd "$d/$n" && sha256sum -c SHA256SUMS >/dev/null 2>&1); then echo "$n"; return 0; fi
    log "uyari: yerel yedek $n sha256 dogrulamasini GECEMEDI; atlandi"
  done
  return 1
}
