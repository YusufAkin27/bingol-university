#!/usr/bin/env bash
# V69_1 (duz metin sutununu dusurme) icin on kontrol: kalan duz metin satir sayisini gosterir.
# 0 ise: yedek alin (pg_dump), sonra SPRING_FLYWAY_LOCATIONS=classpath:db/migration,classpath:db/contract ve
# SPRING_FLYWAY_OUT_OF_ORDER=true ile bir kez baslatin; ardindan bu iki ayari kaldirin. (docs/ENCRYPTION.md 8.1)
# Kullanim: COMPOSE_PROJECT_NAME=wt_t21 ./scripts/crypto-contract.sh
set -u
PSQL="docker compose exec -T postgres psql -U bingol -d bingol -tA"
HAS=$($PSQL -c "select count(*) from information_schema.columns where table_name='message' and column_name='body'")
if [ "$HAS" = "0" ]; then echo "body sutunu zaten yok (daraltma uygulanmis)"; exit 0; fi
N=$($PSQL -c "select count(*) from message where body_ciphertext is null")
P=$($PSQL -c "select count(*) from message where body is not null")
echo "sifrelenmemis satir: $N ; body dolu satir: $P"
[ "$N" = "0" ] && echo "HAZIR: daraltma guvenle uygulanabilir" || { echo "HAZIR DEGIL: gecis isi bitmeli"; exit 1; }
