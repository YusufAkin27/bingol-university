#!/usr/bin/env bash
# BU Kampus sunucu disk temizligi: eski Docker imajlari, build onbellegi ve eski surum dizinleri.
# Kullanim: docker-cleanup.sh [--dry-run]
#   --dry-run  Hicbir sey silmez; neyin silinecegini yazar (varsayilan DEGIL: bayraksiz calisinca gercekten siler).
# Calisma yeri: sunucuda /opt/bukampus/bin/docker-cleanup.sh (systemd: bu-docker-cleanup.timer, gunluk 04:30; deploy.sh de cagirir).
# Kullanici: deploy (docker grubunda). sudo gerekmez.
#
# !!! KESIN YASAK: `docker volume rm`, `docker volume prune`, `docker system prune --volumes` BU BETIKTE ASLA KULLANILMAZ !!!
# pgdata (PostgreSQL), uploads (kullanici dosyalari), backups (yedekler) ve caddy_data (TLS sertifikalari) KALICI VERIDIR;
# silinirse geri donusu yoktur. Bu betik yalnizca imaj / build onbellegi / durmus konteyner / surum dizini siler.
#
# Korunanlar (ASLA silinmez): calisan (ya da durmus olsa da bir konteynerin kullandigi) imajlar, `:previous` etiketli imajlar
# (geri alma), `:local`/`:latest` etiketli imajlar (compose bunlari kullanir), `current` ve `.previous_release` surum dizinleri,
# sunucudaki ucuncu taraf imajlar (caddy/postgres/redis: yalniz proje imajlari "bu-*" ele alinir).
#
# Ortam (hepsi istege bagli):
#   BASEDIR=/opt/bukampus  IMAGE_MIN_AGE_DAYS=7  KEEP_RELEASES=2  BUILDER_RESERVED=2GB  BUILDER_UNTIL=72h
#   STOPPED_MIN_AGE_HOURS=24  WARN_PERCENT=85  LOCK_FILE=/run/lock/bu-docker-cleanup.lock  STEPS="a b c d e" (test icin daraltma)
# Cikis kodu: 0 tamam; 1 en az bir adim hata verdi (digerleri yine de calisir); 2 kullanim hatasi; 3 baska ornek calisiyor.
set -euo pipefail

BASEDIR="${BASEDIR:-/opt/bukampus}"
RELDIR="$BASEDIR/releases"
IMAGE_MIN_AGE_DAYS="${IMAGE_MIN_AGE_DAYS:-7}"
KEEP_RELEASES="${KEEP_RELEASES:-2}"
BUILDER_RESERVED="${BUILDER_RESERVED:-2GB}"
BUILDER_UNTIL="${BUILDER_UNTIL:-72h}"
STOPPED_MIN_AGE_HOURS="${STOPPED_MIN_AGE_HOURS:-24}"
WARN_PERCENT="${WARN_PERCENT:-85}"
LOCK_FILE="${LOCK_FILE:-/run/lock/bu-docker-cleanup.lock}"
STEPS="${STEPS:-a b c d e}"             # test icin daraltilabilir (ornek: STEPS="b")
PROJECT_REPO_RE='^bu-[a-z0-9._-]+$'     # yalniz proje imajlari: bu-backend, bu-web, bu-backup...

DRY=0
case "${1:-}" in
  "") ;;
  --dry-run) DRY=1;;
  -h|--help) sed -n '2,22p' "$0"; exit 0;;
  *) echo "bilinmeyen arguman: $1" >&2; exit 2;;
esac
case "$KEEP_RELEASES$IMAGE_MIN_AGE_DAYS$STOPPED_MIN_AGE_HOURS$WARN_PERCENT" in *[!0-9]*) echo "sayisal ayar gecersiz" >&2; exit 2;; esac

FAILS=0
log()  { printf '%s [docker-cleanup] %s\n' "$(date '+%F %T')" "$*"; }
warn() { printf '%s [docker-cleanup] UYARI: %s\n' "$(date '+%F %T')" "$*" >&2; }
do_rm() { # do_rm "<aciklama>" komut... : dry-run'da yalniz yazar
  local what="$1"; shift
  if [ "$DRY" = 1 ]; then log "[dry-run] silinecek: $what"; return 0; fi
  if "$@" >/dev/null 2>&1; then log "silindi: $what"; else warn "silinemedi: $what"; return 1; fi
}

# --- tek ornek (flock) ---
mkdir -p "$(dirname "$LOCK_FILE")" 2>/dev/null || true
{ exec 9>"$LOCK_FILE"; } 2>/dev/null || { LOCK_FILE="/tmp/bu-docker-cleanup.lock"; exec 9>"$LOCK_FILE"; }
if ! flock -n 9; then log "baska bir temizlik calisiyor; cikiliyor"; exit 3; fi

command -v docker >/dev/null || { warn "docker bulunamadi"; exit 1; }
docker info >/dev/null 2>&1 || { warn "docker daemon'a erisilemiyor (docker grubunda misiniz?)"; exit 1; }

used_bytes() { df -PB1 / | awk 'NR==2{print $3}'; }
human() { numfmt --to=iec --suffix=B --format=%.2f "${1:-0}" 2>/dev/null || echo "${1:-0}B"; }
freed() { local d=$(( $1 )); [ "$d" -gt 0 ] || d=0; human "$d"; }   # negatif (aradaki yazmalar) 0 sayilir
docker_df() { docker system df --format '{{.Type}}: toplam={{.Size}} geri-kazanilabilir={{.Reclaimable}}' 2>/dev/null | sed 's/^/    /' || true; }
step_begin() { STEP_NAME="$1"; STEP_START="$(used_bytes)"; log "--- $1 (once: disk kullanimi $(human "$STEP_START"))"; }
step_end()   { local now; now="$(used_bytes)"; log "--- $STEP_NAME bitti (sonra: $(human "$now"); fark: $(freed "$STEP_START - now") bosaldi)"; }

log "basladi$([ "$DRY" = 1 ] && echo ' (DRY-RUN: hicbir sey silinmez)') BASEDIR=$BASEDIR"
log "baslangic diski:"; df -h / | sed 's/^/    /'
log "baslangic docker:"; docker_df
DISK_BEFORE="$(used_bytes)"

# --- korunan imaj kimlikleri ---
# 1) herhangi bir konteynerin (calisan/durmus) kullandigi, 2) :previous / :local / :latest etiketli imajlar
protected_ids() {
  {
    docker ps -aq 2>/dev/null | xargs -r docker inspect -f '{{.Image}}' 2>/dev/null || true
    docker images --no-trunc --format '{{.Tag}} {{.ID}}' 2>/dev/null | awk '$1=="previous"||$1=="local"||$1=="latest"{print $2}' || true
  } | sort -u
}

# --- (a) dangling imajlar ---
step_a() {
  step_begin "(a) dangling imajlar"
  local n; n="$(docker images -f dangling=true -q 2>/dev/null | wc -l | tr -d ' ')"
  log "dangling imaj sayisi: $n"
  if [ "$n" -gt 0 ]; then
    if [ "$DRY" = 1 ]; then docker images -f dangling=true --format '    [dry-run] silinecek: {{.ID}} {{.Size}} ({{.CreatedSince}})'
    else docker image prune -f 2>&1 | sed 's/^/    /' || return 1; fi
  fi
  step_end
}

# --- (b) kullanilmayan, korumasiz, eski proje imajlari ---
step_b() {
  step_begin "(b) eski proje imajlari (>${IMAGE_MIN_AGE_DAYS} gun, kullanilmayan, :previous/:local degil)"
  local prot cutoff repo tag id ref created ts rc=0
  prot="$(protected_ids)"
  cutoff=$(( $(date +%s) - IMAGE_MIN_AGE_DAYS * 86400 ))
  while IFS=' ' read -r repo tag id; do
    [ -n "$repo" ] || continue
    [[ "$repo" =~ $PROJECT_REPO_RE ]] || continue                 # yalniz bu-* depolari
    [ "$tag" != "<none>" ] || continue                            # etiketsizler (a) adiminda
    case "$tag" in previous|local|latest) continue;; esac         # etiket korumasi
    if printf '%s\n' "$prot" | grep -qxF "$id"; then continue; fi # kimlik korumasi (calisan imaj baska etiketle de bulunabilir)
    created="$(docker image inspect -f '{{.Created}}' "$id" 2>/dev/null || true)"
    ts="$(date -d "$created" +%s 2>/dev/null || echo 0)"
    if [ "$ts" -le 0 ] || [ "$ts" -gt "$cutoff" ]; then continue; fi   # tarih okunamadi ya da yeterince eski degil: dokunma
    ref="$repo:$tag"
    do_rm "imaj $ref ($created)" docker rmi "$ref" || rc=1
  done < <(docker images --no-trunc --format '{{.Repository}} {{.Tag}} {{.ID}}' 2>/dev/null)
  step_end
  return "$rc"
}

# --- (c) build onbellegi ---
step_c() {
  step_begin "(c) build onbellegi (>${BUILDER_UNTIL} eski, ${BUILDER_RESERVED} ayrilir)"
  local flag="--keep-storage"
  docker builder prune --help 2>&1 | grep -q -- '--reserved-space' && flag="--reserved-space"   # Docker 29+: --keep-storage kalkti
  if [ "$DRY" = 1 ]; then
    log "[dry-run] calisacak: docker builder prune $flag $BUILDER_RESERVED --filter until=$BUILDER_UNTIL -f"
    docker buildx du 2>/dev/null | tail -n 3 | sed 's/^/    /' || true
  else
    docker builder prune "$flag" "$BUILDER_RESERVED" --filter "until=$BUILDER_UNTIL" -f 2>&1 | tail -n 3 | sed 's/^/    /'
  fi
  step_end
}

# --- (d) eski surum dizinleri ---
step_d() {
  step_begin "(d) eski surum dizinleri ($RELDIR; current + previous haric en yeni $KEEP_RELEASES tutulur)"
  [ -d "$RELDIR" ] || { log "surum dizini yok; atlandi"; step_end; return 0; }
  local rel_real keep=" " f name tgt n=0 d rc=0
  rel_real="$(readlink -f "$RELDIR")"
  # Korunacak adlar: current (sembolik bag hedefi, dereference), .current_release, .previous_release, .next_release (derleme suruyor olabilir)
  tgt="$(readlink -f "$BASEDIR/current" 2>/dev/null || true)"
  [ -n "$tgt" ] && [ "$(dirname "$tgt")" = "$rel_real" ] && keep="$keep$(basename "$tgt") "
  for f in .current_release .previous_release .next_release; do
    name="$(tr -d '\r\n ' < "$BASEDIR/$f" 2>/dev/null || true)"
    [[ "$name" =~ ^[0-9a-f]{10}$ ]] && keep="$keep$name "
  done
  log "korunan (current/previous/next): $keep"
  case "$keep" in *" "[0-9a-f]*) ;; *) warn "current surumu belirlenemedi; surum dizinleri SILINMEDI"; step_end; return 1;; esac
  # en yeni -> eski (mtime); korunanlar sayima girmez
  while IFS= read -r d; do
    name="$(basename "$d")"
    [[ "$name" =~ ^[0-9a-f]{10}$ ]] || continue            # .tmp, baska adlar: dokunma
    [ -d "$d" ] && [ ! -L "$d" ] || continue                # sembolik bag / dosya: dokunma
    case "$keep" in *" $name "*) continue;; esac
    n=$((n+1))
    if [ "$n" -le "$KEEP_RELEASES" ]; then log "tutuluyor (yeni): $name"; continue; fi
    # yol gecisi korumasi: gercek yol tam olarak RELDIR/<ad> olmali
    [ "$(readlink -f "$d")" = "$rel_real/$name" ] || { warn "yol dogrulanamadi, atlandi: $d"; continue; }
    du_h="$(du -sh "$d" 2>/dev/null | cut -f1)"
    do_rm "surum dizini $name ($du_h)" rm -rf -- "$rel_real/$name" || rc=1
  done < <(ls -1dt "$RELDIR"/*/ 2>/dev/null | sed 's:/$::')
  step_end
  return "$rc"
}

# --- (e) durmus konteynerler (yalniz proje disi: ad "bu-" ile baslamayan; compose projesi "bu" dokunulmaz) ---
step_e() {
  step_begin "(e) durmus proje-disi konteynerler (>${STOPPED_MIN_AGE_HOURS} saat)"
  local cutoff cid name fin ts proj rc=0
  cutoff=$(( $(date +%s) - STOPPED_MIN_AGE_HOURS * 3600 ))
  while IFS= read -r cid; do
    [ -n "$cid" ] || continue
    name="$(docker inspect -f '{{.Name}}' "$cid" 2>/dev/null | sed 's:^/::')"
    proj="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$cid" 2>/dev/null || true)"
    case "$name" in bu-*) continue;; esac
    [ "$proj" != "bu" ] || continue
    fin="$(docker inspect -f '{{.State.FinishedAt}}' "$cid" 2>/dev/null || true)"
    case "$fin" in 0001-*|"") fin="$(docker inspect -f '{{.Created}}' "$cid" 2>/dev/null || true)";; esac   # hic baslamamis (created)
    ts="$(date -d "$fin" +%s 2>/dev/null || echo 0)"
    if [ "$ts" -le 0 ] || [ "$ts" -gt "$cutoff" ]; then continue; fi
    do_rm "konteyner $name ($cid, bitis $fin)" docker rm "$cid" || rc=1
  done < <(docker ps -aq --filter status=exited --filter status=created --filter status=dead 2>/dev/null)
  step_end
  return "$rc"
}

for s in $STEPS; do
  "step_$s" || { warn "$s hata verdi; sonraki adima geciliyor"; FAILS=$((FAILS+1)); }
done

# --- (g) ozet ve disk uyarisi ---
log "=== OZET ==="
log "sonuc docker:"; docker_df
log "sonuc disk:"; df -h / | sed 's/^/    /'
DISK_AFTER="$(used_bytes)"
log "toplam bosalan: $(freed "DISK_BEFORE - DISK_AFTER")$([ "$DRY" = 1 ] && echo ' (dry-run: 0 beklenir)')"
PCT="$(df -P / | awk 'NR==2{gsub("%","",$5); print $5}')"
if [ "${PCT:-0}" -ge "$WARN_PERCENT" ]; then
  MSG="bu-docker-cleanup: disk kullanimi %$PCT (esik %$WARN_PERCENT); temizlik sonrasi hala yuksek, elle inceleyin"
  warn "$MSG"
  logger -p user.warning -t bu-docker-cleanup "$MSG" 2>/dev/null || true
fi
log "bitti (hatali adim: $FAILS)"
[ "$FAILS" -eq 0 ] || exit 1
