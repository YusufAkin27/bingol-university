#!/usr/bin/env bash
# Uzak kopya (remote-sync.sh, prune-local-after-remote.sh, GFS saklama, durum JSON'u) KENDI KENDINE testi.
# Gercek Drive GEREKMEZ: rclone `alias` ile YEREL bir dizini "uzak" olarak kullanir; DB/age/docker-compose gerekmez.
# Gereken: bash, rclone, jq, coreutils (backup imajinda hepsi var). Calistirma (yerelde):
#   docker run --rm --user 70:70 -v "$PWD/scripts/backup:/opt/t:ro" <backup-imaji-veya-alpine+rclone+jq+bash> bash /opt/t/selftest-remote.sh
# Not: BACKUP_DIR'e (mktemp) dokunur, gercek yedek dizinine DOKUNMAZ.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export BACKUP_DIR="$T/b" BACKUP_STATUS_FILE="$T/b/metrics/last-success.json" BACKUP_METRICS_DIR="$T/b/metrics"
export RCLONE_CONFIG="$T/rclone.conf" BACKUP_REMOTE_LOCK="$T/remote.lock" BACKUP_LOCK="$T/backup.lock"
export BACKUP_REMOTE="fake:yedek" BACKUP_REMOTE_KEEP_DAILY=3 BACKUP_REMOTE_KEEP_WEEKLY=2 BACKUP_REMOTE_KEEP_MONTHLY=2
mkdir -p "$BACKUP_DIR"/{daily,weekly,monthly,metrics} "$T/remote"
cat > "$RCLONE_CONFIG" <<CONF
[fake]
type = alias
remote = $T/remote
[gd]
type = drive
scope = drive.file
token = {"access_token":"AAA","token_type":"Bearer","refresh_token":"BBB","expiry":"2020-01-01T00:00:00Z"}
[gdalias]
type = alias
remote = gd:BU
CONF
fail=0
ok()  { printf 'OK    %s\n' "$*"; }
bad() { printf 'FAIL  %s\n' "$*"; fail=1; }
chk() { # chk <aciklama> <komut...>
  local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi
}

mkbackup() { # mkbackup <damga> [tier]  (rastgele icerikli sahte yedek; SHA256SUMS gecerli)
  local d="$BACKUP_DIR/${2:-daily}/$1"; mkdir -p "$d"
  head -c 70000 /dev/urandom > "$d/db.dump.age"; head -c 130000 /dev/urandom > "$d/uploads.tar.zst.age"
  printf '{"stamp":"%s","tables":{}}\n' "$1" > "$d/manifest.json"
  (cd "$d" && sha256sum db.dump.age uploads.tar.zst.age manifest.json > SHA256SUMS)
}

# ---------------------------------------------------------------------------------------------------------------------
# 1) GFS saklama saf fonksiyon
# shellcheck source=lib.sh
. "$HERE/lib.sh" 2>/dev/null
# shellcheck source=remote.sh
. "$HERE/remote.sh" 2>/dev/null

LIST="$(for d in 20261010 20261011 20261012 20261013 20261014 20261015 20261016 20261017 20261018 20261019 20261020 20261021 \
  20261022 20261023 20261024 20261025 20261026 20261027 20261028 20261029 20261030 20261031 20261101; do echo "${d}T033500"; done)"
KEEP="$(printf '%s\n' "$LIST" | gfs_keep_list 7 4 6 | tr '\n' ' ')"
# gunluk 7: 1101..1026; haftalik (pzt baslangic): 1101(pazar) haftasi=1026-1101 -> 1101; onceki hafta 1019-1025 -> 1025; 1012-1018 -> 1018; 1005-1011 -> 1011;
# aylik: 202611 -> 1101 ; 202610 -> 1031
for want in 20261101T033500 20261031T033500 20261030T033500 20261029T033500 20261028T033500 20261027T033500 20261026T033500 20261025T033500 20261018T033500 20261011T033500; do
  case " $KEEP" in *" $want "*) ;; *) bad "GFS: $want korunmaliydi (keep=$KEEP)";; esac
done
[ "$(printf '%s\n' "$KEEP" | wc -w | tr -d ' ')" = 10 ] && ok "GFS 7/4/6: 10 yedek korunur (7 gunluk + 3 haftalik; aylik ust uste biner)" || bad "GFS sayisi: $KEEP"
DEL="$(printf '%s\n' "$LIST" | gfs_delete_list 7 4 6 | head -1)"
[ "$DEL" = 20261010T033500 ] && ok "silme listesi EN ESKI once" || bad "silme sirasi: $DEL"
[ -z "$(printf '%s\n' "$LIST" | gfs_delete_list 99 99 99)" ] && ok "buyuk saklama -> hicbir sey silinmez" || bad "buyuk saklama sildi"
[ -z "$(printf 'not-a-stamp\n../etc\n' | gfs_delete_list 1 1 1)" ] && ok "damga olmayan adlar listeye girmez (silinemez)" || bad "yabanci ad listede"
[ "$(week_key 20261025)" = "$(week_key 20261019)" ] && [ "$(week_key 20261026)" != "$(week_key 20261025)" ] && ok "hafta anahtari pazartesi baslangicli" || bad "week_key"

# ---------------------------------------------------------------------------------------------------------------------
# 2) yukleme + dogrulama + durum JSON'u
mkbackup 20261030T030500; mkbackup 20261031T030500; mkbackup 20261101T030500
"$HERE/remote-sync.sh" > "$T/out1.log" 2>&1; rcode=$?
chk "remote-sync basarili (cikis 0)" test "$rcode" = 0
chk "uzakta damga dizini var" test -s "$T/remote/yedek/20261101T030500/SHA256SUMS"
chk "uzakta .partial kalmadi" test -z "$(ls -a "$T/remote/yedek" | grep partial)"
chk "yalniz EN YENI yedek yuklendi (saatlik/gunluk tek kopya)" test "$(ls "$T/remote/yedek" | wc -l | tr -d ' ')" = 1
chk "uzak dosyalar yerelle ayni (cmp)" cmp -s "$T/remote/yedek/20261101T030500/db.dump.age" "$BACKUP_DIR/daily/20261101T030500/db.dump.age"
S="$BACKUP_STATUS_FILE"
chk "durum JSON gecerli" jq -e . "$S" >/dev/null
chk "remote.configured=true, kind=other, name=fake" test "$(jq -r '[.remote.configured,.remote.kind,.remote.name]|join(",")' "$S")" = "true,other,fake"
chk "remote.lastSuccessAt ve lastVerifiedAt dolu (ISO Z)" test "$(jq -r '.remote.lastSuccessAt,.remote.lastVerifiedAt' "$S" | grep -cE 'Z$')" = 2
chk "remote.lastError null" test "$(jq -r '.remote.lastError' "$S")" = null
chk "remote.count=1, bytes>0" test "$(jq -r '.remote.count' "$S")" = 1 -a "$(jq -r '.remote.bytes' "$S")" -gt 200000
chk "local.count=3, oldestAt dolu" test "$(jq -r '.local.count' "$S")" = 3 -a "$(jq -r '.local.oldestAt' "$S")" != null
chk "schedule/retention nesneleri var" test "$(jq -r '.retention.remoteMonthly,.retention.localDaily' "$S" | tr '\n' ,)" = "2,3,"
chk "Prometheus: backup_remote_last_status 1 ve count 1" bash -c "grep -q '^backup_remote_last_status 1' '$BACKUP_METRICS_DIR/backup_remote.prom' && grep -q '^backup_remote_count 1' '$BACKUP_METRICS_DIR/backup_remote.prom'"
chk "durum dosyasinda hedef yolu SIZMIYOR" test -z "$(grep -F "$T" "$S" || true)"

"$HERE/remote-sync.sh" > "$T/out2.log" 2>&1
chk "ikinci calisma: 'zaten var' ve yeniden yuklemez" grep -q "zaten var" "$T/out2.log"

# 3) bozulma: ayni boyutta bir bayt degistir -> dogrulama yakalar ve kendini onarir
printf 'X' | dd of="$T/remote/yedek/20261101T030500/db.dump.age" bs=1 seek=100 conv=notrunc 2>/dev/null
verify_remote_copy "$BACKUP_DIR/daily/20261101T030500" "$REMOTE_BASE/20261101T030500"; v=$?
chk "bozulmus (ayni boyut) uzak kopya dogrulamada YAKALANIR" test "$v" = 1
"$HERE/remote-sync.sh" > "$T/out3.log" 2>&1
chk "bozuk uzak kopya yeniden yuklenip onarildi" cmp -s "$T/remote/yedek/20261101T030500/db.dump.age" "$BACKUP_DIR/daily/20261101T030500/db.dump.age"
rm -f "$T/remote/yedek/20261101T030500/manifest.json"
verify_remote_copy "$BACKUP_DIR/daily/20261101T030500" "$REMOTE_BASE/20261101T030500"; chk "eksik uzak dosya yakalanir" test "$?" = 1
"$HERE/remote-sync.sh" --force > "$T/out3b.log" 2>&1

# ---------------------------------------------------------------------------------------------------------------------
# 4) uzak saklama: eski damgalar, yalniz dogrulanmis yeni yedek varken silinir
for d in 20261001 20261002 20261003 20261004 20261005 20261006 20261007 20261020 20261021 20261022; do
  mkdir -p "$T/remote/yedek/${d}T033500"; echo old > "$T/remote/yedek/${d}T033500/SHA256SUMS"
done
mkbackup 20261102T030500
"$HERE/remote-sync.sh" > "$T/out4.log" 2>&1
REMAIN="$(ls "$T/remote/yedek" | tr '\n' ' ')"
chk "saklama sonrasi en yeni 3 gun + hafta/ay yedekleri kaldi, en yeni var" bash -c "echo '$REMAIN' | grep -q 20261102T030500 && echo '$REMAIN' | grep -q 20261101T030500"
chk "20261001 (en eski) silindi" bash -c "! echo '$REMAIN' | grep -q 20261001T033500"
chk "uzak sayisi <= 3 + 2 + 2" test "$(ls "$T/remote/yedek" | wc -l | tr -d ' ')" -le 7
chk "durum: remote.count uzak dizin sayisina esit" test "$(jq -r '.remote.count' "$S")" = "$(ls "$T/remote/yedek" | wc -l | tr -d ' ')"
# silme siniri
for d in 20260901 20260902 20260903 20260904 20260905; do mkdir -p "$T/remote/yedek/${d}T033500"; echo old > "$T/remote/yedek/${d}T033500/SHA256SUMS"; done
BACKUP_REMOTE_MAX_DELETE=2 "$HERE/remote-sync.sh" --force > "$T/out5.log" 2>&1
chk "BACKUP_REMOTE_MAX_DELETE=2: bir kosuda en cok 2 silme" test "$(grep -c 'uzak saklama: siliniyor' "$T/out5.log")" = 2

# 5) kuru calisma uzaga hicbir sey yazmaz
mkbackup 20261103T030500
BEFORE="$(ls "$T/remote/yedek" | md5sum)"
"$HERE/remote-sync.sh" --dry-run > "$T/out6.log" 2>&1
chk "--dry-run uzakta degisiklik yapmaz" test "$BEFORE" = "$(ls "$T/remote/yedek" | md5sum)"
chk "--dry-run plani yazdi" grep -q "KURU CALISMA tamam" "$T/out6.log"
"$HERE/remote-sync.sh" > "$T/out7.log" 2>&1

# ---------------------------------------------------------------------------------------------------------------------
# 6) yerel azaltma: yalniz uzakta dogrulanmis kopyasi olanlar, en yeni N korunur
# yerelde: 20261030 20261031 20261101 20261102 20261103 ; uzakta (dogrulanmis): 20261103 (yeni), 20261102, 20261101 (saklamaya bagli)
LOCAL_BEFORE="$(ls "$BACKUP_DIR/daily" | tr '\n' ' ')"
"$HERE/prune-local-after-remote.sh" --keep 2 > "$T/p1.log" 2>&1
chk "prune-local varsayilan KURU CALISMA: hicbir sey silmez" test "$LOCAL_BEFORE" = "$(ls "$BACKUP_DIR/daily" | tr '\n' ' ')"
chk "kuru calisma 'SILINIRDI' listeler" grep -q "SILINIRDI" "$T/p1.log"
chk "uzakta kopyasi olmayan yedek KORUNUR" grep -q "KORUNDU (uzakta kopyasi yok): daily/20261030T030500" "$T/p1.log"
"$HERE/prune-local-after-remote.sh" --apply --keep 2 > "$T/p2.log" 2>&1
chk "en yeni 2 yerelde kaldi" test -d "$BACKUP_DIR/daily/20261103T030500" -a -d "$BACKUP_DIR/daily/20261102T030500"
chk "uzakta dogrulanmis eski yerel yedek silindi (20261101)" test ! -d "$BACKUP_DIR/daily/20261101T030500"
chk "uzakta OLMAYAN yerel yedek (20261030) silinmedi" test -d "$BACKUP_DIR/daily/20261030T030500"
# uzak kopya bozulursa yerel silinmez
mkbackup 20261104T030500; "$HERE/remote-sync.sh" > "$T/out8.log" 2>&1
mkbackup 20261105T030500; mkbackup 20261106T030500
printf 'Z' | dd of="$T/remote/yedek/20261104T030500/db.dump.age" bs=1 seek=50 conv=notrunc 2>/dev/null
"$HERE/prune-local-after-remote.sh" --apply --keep 2 > "$T/p3.log" 2>&1
chk "uzak kopyasi BOZUK yerel yedek silinmez" test -d "$BACKUP_DIR/daily/20261104T030500"
chk "bozuk olan nedeniyle log 'DOGRULANAMADI'" grep -q "DOGRULANAMADI" "$T/p3.log"
# yedek dizini disina cikma / sembolik bag
mkdir -p "$T/outside/20260101T000000"; ln -s "$T/outside/20260101T000000" "$BACKUP_DIR/daily/20260101T000000"
"$HERE/prune-local-after-remote.sh" --apply --keep 1 > "$T/p4.log" 2>&1
chk "sembolik bag izlenmez, hedef dizin silinmedi" test -d "$T/outside/20260101T000000"
BACKUP_REMOTE="" "$HERE/prune-local-after-remote.sh" --apply > "$T/p5.log" 2>&1; pr=$?
chk "BACKUP_REMOTE bos -> hicbir sey silmez (cikis 2)" test "$pr" = 2

# ---------------------------------------------------------------------------------------------------------------------
# 7) hata yolu: erisilemeyen uzak -> cikis 1, KISA ve sirsiz hata, durum + metrik 0
BACKUP_REMOTE="yokuzak:sirli/yol" "$HERE/remote-sync.sh" > "$T/out9.log" 2>&1; er=$?
chk "gecersiz uzak: cikis 1" test "$er" = 1
chk "remote.lastError dolu ve kisa" test "$(jq -r '.remote.lastError|length' "$S")" -gt 0 -a "$(jq -r '.remote.lastError|length' "$S")" -le 200
chk "hata metninde hedef yolu YOK" test -z "$(jq -r '.remote.lastError' "$S" | grep -E 'sirli' || true)"
chk "backup_remote_last_status 0" grep -q '^backup_remote_last_status 0' "$BACKUP_METRICS_DIR/backup_remote.prom"
"$HERE/remote-sync.sh" > "$T/out10.log" 2>&1
chk "sonraki basarili calisma hatayi temizler" test "$(jq -r '.remote.lastError' "$S")" = null

# 8) Drive turu tespiti: yalniz uzak ADI gorunur, alias zinciri izlenir
BACKUP_REMOTE="gdalias:x" bash -c ". '$HERE/lib.sh'; echo \"\$(remote_kind) \$(remote_name)\"" > "$T/kind.txt" 2>/dev/null
chk "kind=drive (alias zinciri), name=gdalias" test "$(cat "$T/kind.txt")" = "drive gdalias"
chk "durum JSON'unda belirtec YOK" test -z "$(grep -E 'refresh_token|AAA|BBB' "$S" || true)"

# 9) eski biçimli durum dosyasi (remote alani yok) korunur, alanlar eklenir
printf '{"lastSuccessAt":"2026-10-28T10:52:20Z","time":"2026-10-28T10:52:20Z","file":"20261028T135217","sizeBytes":485280}\n' > "$S"
BACKUP_REMOTE="" status_enrich
chk "eski alanlar korunur" test "$(jq -r '.lastSuccessAt,.file' "$S" | tr '\n' ' ')" = "2026-10-28T10:52:20Z 20261028T135217 "
chk "BACKUP_REMOTE bos -> remote.configured=false" test "$(jq -r '.remote.configured' "$S")" = false
chk "ilk anahtar hala lastSuccessAt (regex okuyucular icin)" test "$(jq -r 'keys_unsorted[0]' "$S")" = lastSuccessAt

exit "$fail"
