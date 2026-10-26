#!/usr/bin/env bash
# Sohbet QA: REST + WebSocket matrisleri. Kullanim: COMPOSE_PROJECT_NAME=wt_t2 BASE=http://localhost:8102 ./scripts/qa-chat-all.sh
# SLOW=1 ile token suresi / kalp atisi / bosta baglanti testleri de calisir.
set -u
cd "$(dirname "$0")/.."
RC=0
docker compose exec -T redis redis-cli flushall >/dev/null
node scripts/qa-chat-rest.js || RC=1
docker compose exec -T redis redis-cli flushall >/dev/null
node scripts/qa-chat-ws.js || RC=1
exit $RC
