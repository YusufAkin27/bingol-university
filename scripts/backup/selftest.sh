#!/usr/bin/env bash
# Yedek hattinin KENDI KENDINE testi: gecici postgres + gecici volume'lar + yeni age anahtari kullanir.
# Calisan yigina, canli veritabanina ve volume'lara DOKUNMAZ (tum kaynaklar "bu-bk-selftest-*" adli ve sonunda silinir).
# Kullanim (repo kokunden, Docker gerekir): bash scripts/backup/selftest.sh
# Dogrulananlar: --dry-run, gercek yedek, sha256, verify-restore (gecici sunucuya geri yukleme + sayim karsilastirma),
# restore.sh (yeni veritabani + uploads cikarma), bozuk yedegin REDDI, canli veritabani hedefinin REDDI.
# A4 eklentileri: anahtar GERCEK kurulum gibi root sahipli 0600 (entrypoint postgres icin kopyalar); durum JSON'u UTC 'Z' bicimi
# (BackupStatusProvider); --overwrite-live: yanlis anahtarda canli DB DEGISMEZ, dogru anahtarda canli DB silinmez (<ad>_prev_*);
# root olarak cagrilan betik postgres'e gecer (root sahipli dizin kalmaz, prune calisir); webhook JSON kacisi.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
export MSYS_NO_PATHCONV=1

NET=bu-bk-selftest-net; PG=bu-bk-selftest-pg
V_UP=bu-bk-selftest-up; V_BK=bu-bk-selftest-bk; V_KEY=bu-bk-selftest-key
IMG=bu-backup:selftest
step() { printf '\n== %s\n' "$*"; }
cleanup() {
  docker rm -f "$PG" >/dev/null 2>&1 || true
  docker volume rm -f "$V_UP" "$V_BK" "$V_KEY" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
OUT="$(mktemp)"; OUT2="$(mktemp)"
trap 'cleanup; rm -f "$OUT" "$OUT2"' EXIT
cleanup

step "imaj derleniyor"
docker build -q -t "$IMG" scripts/backup >/dev/null

docker network create "$NET" >/dev/null
for v in "$V_UP" "$V_BK" "$V_KEY"; do docker volume create "$v" >/dev/null; done

step "gecici postgres + ornek veri"
docker run -d --name "$PG" --network "$NET" -e POSTGRES_USER=bingol -e POSTGRES_PASSWORD=selftest -e POSTGRES_DB=bingol \
  postgres:16-alpine >/dev/null
for _ in $(seq 1 40); do docker exec "$PG" pg_isready -U bingol -d bingol -q && break; sleep 1; done
sleep 2
docker exec -i "$PG" psql -v ON_ERROR_STOP=1 -q -U bingol -d bingol <<'SQL'
create table flyway_schema_history(installed_rank int, version varchar(20), success boolean);
insert into flyway_schema_history values (1,'1',true),(2,'310',true),(3,'360',true);
create table app_user(id serial primary key, email text not null);
insert into app_user(email) select 'u' || g || '@bingol.edu.tr' from generate_series(1,500) g;
create table post_media(id serial primary key, storage_key text, wrapped_dek text);
insert into post_media(storage_key, wrapped_dek) select g || '.mp4', 'k1:xyz' from generate_series(1,40) g;
SQL
docker run --rm -v "$V_UP":/d alpine sh -c 'mkdir -p /d/post /d/avatars && for i in $(seq 1 25); do head -c 4096 /dev/urandom > /d/post/f$i.bin; done && echo ok > /d/avatars/a.txt && chmod -R a+rX /d' >/dev/null

step "age anahtari uretiliyor (yalniz bu test icin; root sahipli 0600: uid 70 dogrudan OKUYAMAZ)"
PUB="$(docker run --rm --entrypoint sh -v "$V_KEY":/k "$IMG" -c 'age-keygen -o /k/verify.key 2>&1 | sed -n "s/^Public key: //p"; chmod 600 /k/verify.key; age-keygen -o /k/wrong.key >/dev/null 2>&1; chmod 600 /k/wrong.key')"
case "$PUB" in age1*) echo "alici: ${PUB:0:12}...";; *) echo "anahtar uretilemedi" >&2; exit 1;; esac

RUN=(docker run --rm --network "$NET" -e PGHOST="$PG" -e PGUSER=bingol -e PGDATABASE=bingol -e PGPASSWORD=selftest
     -e BACKUP_AGE_RECIPIENT="$PUB" -e BACKUP_VERIFY_AGE_RECIPIENT="$PUB"
     -e BACKUP_AGE_IDENTITY_SRC=/run/backup/verify.key -e BACKUP_AGE_IDENTITY_FILE=/run/age-key/age.key
     -v "$V_UP":/data/uploads:ro -v "$V_BK":/var/backups -v "$V_KEY":/run/backup:ro "$IMG")

step "1) --dry-run (hicbir sey yazmaz)"
"${RUN[@]}" backup.sh --dry-run
docker run --rm -v "$V_BK":/b alpine sh -c 'test -z "$(ls /b/daily)" && echo "daily bos: dry-run yazmadi"'

step "2) gercek yedek"
"${RUN[@]}" backup.sh
docker run --rm -v "$V_BK":/b alpine sh -c 'ls -l /b/daily/*; cat /b/last_success; echo; cat /b/metrics/backup.prom | grep -v "^#"; cat /b/last-success.json'
# BackupStatusProvider "lastSuccessAt" alanini ISO-8601 UTC ('Z') okur (aksi halde panel hep UNKNOWN)
docker run --rm -v "$V_BK":/b alpine sh -c 'grep -Eq "\"lastSuccessAt\":\"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z\"" /b/last-success.json' \
  && echo "durum JSON: lastSuccessAt UTC 'Z' biciminde"

step "3) verify-restore (gecici sunucuda geri yukleme; 0600 root anahtar entrypoint kopyasiyla okunur)"
"${RUN[@]}" verify-restore.sh --latest

step "3b) anahtar okunamiyorsa net hata + metrik 0 (sessiz degil)"
# entrypoint'i atlayip postgres olarak dogrudan cagir: 0600 root anahtari OKUYAMAZ
if docker run --rm --entrypoint su-exec --network "$NET" -e BACKUP_VERIFY_AGE_RECIPIENT="$PUB" -v "$V_BK":/var/backups -v "$V_KEY":/run/backup:ro "$IMG" \
     postgres /opt/backup/verify-restore.sh --latest >"$OUT" 2>&1; then
  echo "HATA: okunamayan anahtarla dogrulama basarili sayildi" >&2; exit 1
fi
grep -q "OKUNAMIYOR" "$OUT" && echo "okunamayan anahtar acik hata verdi"
docker run --rm -v "$V_BK":/b alpine sh -c 'grep -q "^backup_verify_last_status 0" /b/metrics/backup.prom' && echo "backup_verify_last_status=0 yazildi (uyari kurali bunu yakalar)"
# metrigi tekrar basarili yap
"${RUN[@]}" verify-restore.sh --latest >/dev/null

step "4) restore.sh: yeni veritabani + uploads (anahtar: entrypoint'in postgres icin hazirladigi kopya)"
LATEST="$(docker run --rm -v "$V_BK":/b alpine sh -c 'ls /b/daily | sort | tail -1')"
"${RUN[@]}" restore.sh "/var/backups/daily/$LATEST" --target-db bingol_restore --uploads-to /tmp/up
docker exec "$PG" psql -U bingol -d bingol_restore -Atc "select count(*) from app_user" | grep -qx 500 && echo "geri yuklenen app_user = 500"

step "5) canli veritabani hedefi reddedilir"
if "${RUN[@]}" restore.sh "/var/backups/daily/$LATEST" --target-db bingol >/dev/null 2>&1; then
  echo "HATA: canli veritabanina geri yukleme reddedilmedi" >&2; exit 1
fi
echo "reddedildi (beklenen)"

step "5b) --overwrite-live: yanlis anahtarla canli DB DEGISMEZ (kuru dogrulama once)"
docker exec "$PG" psql -U bingol -d bingol -qc "insert into app_user(email) values ('canli-ek@bingol.edu.tr')"
if "${RUN[@]}" restore.sh "/var/backups/daily/$LATEST" --identity /run/backup/wrong.key --target-db bingol --overwrite-live >/dev/null 2>&1; then
  echo "HATA: yanlis anahtarla --overwrite-live basarili sayildi" >&2; exit 1
fi
docker exec "$PG" psql -U bingol -d bingol -Atc "select count(*) from app_user" | grep -qx 501 \
  && echo "yanlis anahtar reddedildi; canli DB (501 satir) DOKUNULMADI"

step "5c) --overwrite-live: dogru anahtarla canli DB SILINMEZ (bingol_prev_*), yedek yerine konur"
"${RUN[@]}" restore.sh "/var/backups/daily/$LATEST" --target-db bingol --overwrite-live
docker exec "$PG" psql -U bingol -d bingol -Atc "select count(*) from app_user" | grep -qx 500 && echo "canli DB yedekten geri yuklendi (500)"
PREV="$(docker exec "$PG" psql -U bingol -d postgres -Atc "select datname from pg_database where datname like 'bingol_prev_%'")"
[ -n "$PREV" ] || { echo "HATA: eski canli veritabani saklanmadi" >&2; exit 1; }
echo "eski canli veritabani saklandi: $PREV"

step "6) bozuk yedek reddedilir"
docker run --rm -v "$V_BK":/b alpine sh -c "printf 'X' | dd of=/b/daily/$LATEST/db.dump.age bs=1 seek=300 conv=notrunc 2>/dev/null"
if VERIFY_NO_METRICS=1 "${RUN[@]}" verify-restore.sh --latest >/dev/null 2>&1; then
  echo "HATA: bozuk yedek dogrulamayi gecti" >&2; exit 1
fi
echo "bozuk yedek reddedildi (beklenen)"

step "7) root olarak cagrilan betik postgres'e gecer; root sahipli dizin KALMAZ, prune calisir (H2)"
docker run --rm -v "$V_BK":/b alpine sh -c 'rm -rf /b/daily/*'
docker run --rm --network "$NET" -e PGHOST="$PG" -e PGUSER=bingol -e PGDATABASE=bingol -e PGPASSWORD=selftest \
  -e BACKUP_AGE_RECIPIENT="$PUB" -e BACKUP_KEEP_DAILY=1 -v "$V_UP":/data/uploads:ro -v "$V_BK":/var/backups --entrypoint bash "$IMG" \
  -c 'id -u; /opt/backup/backup.sh && sleep 1 && /opt/backup/backup.sh' >/dev/null
docker run --rm -v "$V_BK":/b alpine sh -c 'ls /b/daily | wc -l | grep -qx 1 && echo "prune calisti (KEEP=1 -> 1 dizin)"; ls -ln /b/daily; ! find /b/daily -mindepth 1 -maxdepth 1 ! -user 70 | grep -q . && echo "tum yedek dizinleri uid 70 (postgres) sahipli"'

step "8) webhook JSON kacisi (tirnak ve ters egik cizgi)"
docker run --rm --entrypoint bash "$IMG" -c '
  printf "#!/bin/sh\nprintf %%s \"\$*\" > /tmp/curl.out\n" > /usr/local/bin/curl; chmod +x /usr/local/bin/curl
  . /opt/backup/lib.sh
  BACKUP_WEBHOOK_URL=http://x notify "hata \"x\" \\ y"
  cat /tmp/curl.out; echo' | tee "$OUT2"
grep -q 'hata \\"x\\" \\\\ y' "$OUT2" && echo "webhook JSON dogru kacirildi"

printf '\nSELFTEST BASARILI\n'
