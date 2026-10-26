#!/usr/bin/env bash
# Performans verisi tohumlama. Kullanim (repo kokunden, compose yigini calisirken):
#   COMPOSE_PROJECT_NAME=wt_t6 ./scripts/load/seed.sh          # tohumla (varsa atlar)
#   COMPOSE_PROJECT_NAME=wt_t6 ./scripts/load/seed.sh --clean  # yalnizca demoperf kayitlarini siler
#   ... seed.sh --psql "SQL"                                    # yardimci: tek sorgu calistir
set -eu
DIR=$(cd "$(dirname "$0")" && pwd)
psqlc() { docker compose exec -T postgres psql -U bingol -d bingol -v ON_ERROR_STOP=1 "$@"; }

case "${1:-}" in
  --clean)
    psqlc < "$DIR/clean-perf.sql"
    psqlc -c "VACUUM ANALYZE"
    echo "temizlendi"
    ;;
  --psql)
    psqlc -c "$2"
    ;;
  *)
    N=$(psqlc -Atc "SELECT count(*) FROM app_user WHERE email LIKE 'demoperf.%@bingol.edu.tr'")
    if [ "$N" != "0" ]; then echo "zaten tohumlanmis ($N kullanici); once --clean"; exit 0; fi
    START=$(date +%s)
    psqlc < "$DIR/seed-perf.sql"
    # Tohumdan sonra istatistik: planlayici gercek boyutlari gorsun
    psqlc -c "VACUUM ANALYZE"
    echo "bitti: $(( $(date +%s) - START )) sn"
    psqlc -Atc "SELECT 'users', count(*) FROM app_user WHERE email LIKE 'demoperf.%'
                UNION ALL SELECT 'messages', count(*) FROM message WHERE client_id LIKE 'demoperf-%'
                UNION ALL SELECT 'conversations', count(*) FROM conversation
                UNION ALL SELECT 'notifications', count(*) FROM notification WHERE title LIKE 'demoperf%'
                UNION ALL SELECT 'rsvp', count(*) FROM event_rsvp
                UNION ALL SELECT 'news', count(*) FROM news_item
                UNION ALL SELECT 'communities', count(*) FROM community WHERE slug LIKE 'demoperf-c-%'
                UNION ALL SELECT 'members', count(*) FROM community_member"
    ;;
esac
