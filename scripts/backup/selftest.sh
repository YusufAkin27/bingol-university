#!/usr/bin/env bash
# Yedek hattinin KENDI KENDINE testi: gecici postgres + gecici volume'lar + yeni age anahtari kullanir.
# Calisan yigina, canli veritabanina ve volume'lara DOKUNMAZ (tum kaynaklar "bu-bk-selftest-*" adli ve sonunda silinir).
# Kullanim (repo kokunden, Docker gerekir): bash scripts/backup/selftest.sh
# Dogrulananlar: --dry-run, gercek yedek, sha256, verify-restore (gecici sunucuya geri yukleme + sayim karsilastirma),
# restore.sh (yeni veritabani + uploads cikarma), bozuk yedegin REDDI, canli veritabani hedefinin REDDI.
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
trap cleanup EXIT
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

step "age anahtari uretiliyor (yalniz bu test icin)"
PUB="$(docker run --rm --entrypoint sh -v "$V_KEY":/k "$IMG" -c 'age-keygen -o /k/verify.key 2>&1 | sed -n "s/^Public key: //p"; chmod 644 /k/verify.key')"
case "$PUB" in age1*) echo "alici: ${PUB:0:12}...";; *) echo "anahtar uretilemedi" >&2; exit 1;; esac

RUN=(docker run --rm --network "$NET" -e PGHOST="$PG" -e PGUSER=bingol -e PGDATABASE=bingol -e PGPASSWORD=selftest
     -e BACKUP_AGE_RECIPIENT="$PUB" -v "$V_UP":/data/uploads:ro -v "$V_BK":/var/backups -v "$V_KEY":/run/backup:ro "$IMG")

step "1) --dry-run (hicbir sey yazmaz)"
"${RUN[@]}" backup.sh --dry-run
docker run --rm -v "$V_BK":/b alpine sh -c 'test -z "$(ls /b/daily)" && echo "daily bos: dry-run yazmadi"'

step "2) gercek yedek"
"${RUN[@]}" backup.sh
docker run --rm -v "$V_BK":/b alpine sh -c 'ls -l /b/daily/*; cat /b/last_success; echo; cat /b/metrics/backup.prom | grep -v "^#"'

step "3) verify-restore (gecici sunucuda geri yukleme)"
"${RUN[@]}" verify-restore.sh --latest

step "4) restore.sh: yeni veritabani + uploads"
LATEST="$(docker run --rm -v "$V_BK":/b alpine sh -c 'ls /b/daily | sort | tail -1')"
"${RUN[@]}" restore.sh "/var/backups/daily/$LATEST" --identity /run/backup/verify.key --target-db bingol_restore --uploads-to /tmp/up
docker exec "$PG" psql -U bingol -d bingol_restore -Atc "select count(*) from app_user" | grep -qx 500 && echo "geri yuklenen app_user = 500"

step "5) canli veritabani hedefi reddedilir"
if "${RUN[@]}" restore.sh "/var/backups/daily/$LATEST" --identity /run/backup/verify.key --target-db bingol >/dev/null 2>&1; then
  echo "HATA: canli veritabanina geri yukleme reddedilmedi" >&2; exit 1
fi
echo "reddedildi (beklenen)"

step "6) bozuk yedek reddedilir"
docker run --rm -v "$V_BK":/b alpine sh -c "printf 'X' | dd of=/b/daily/$LATEST/db.dump.age bs=1 seek=300 conv=notrunc 2>/dev/null"
if VERIFY_NO_METRICS=1 "${RUN[@]}" verify-restore.sh --latest >/dev/null 2>&1; then
  echo "HATA: bozuk yedek dogrulamayi gecti" >&2; exit 1
fi
echo "bozuk yedek reddedildi (beklenen)"

printf '\nSELFTEST BASARILI\n'
