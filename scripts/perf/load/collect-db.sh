#!/usr/bin/env bash
# PostgreSQL/Redis sonuc toplayici.
# Kullanim: PSQL_CMD="docker exec -i bu_ld_pg psql -U bingol -d bingol" collect-db.sh <etiket> <cikti-klasoru>
# Yazar: <klasor>/<etiket>.db.txt (en yavas/en cok cagrilan 15 sorgu, seq scan, onbellek, kilit, WAL/disk, Redis)
set -u
LABEL="${1:-run}"; OUT="${2:-.}"
PSQL="${PSQL_CMD:-docker exec -i bu_ld_pg psql -U bingol -d bingol}"
REDIS="${REDIS_CMD:-docker exec bu_ld_redis redis-cli}"
F="$OUT/$LABEL.db.txt"; mkdir -p "$OUT"
p() { echo "$1" | $PSQL -P pager=off 2>&1; }
{
echo "### en yavas 15 sorgu (toplam sure)"
p "SELECT calls, round(total_exec_time::numeric,0) AS total_ms, round(mean_exec_time::numeric,2) AS mean_ms, round(max_exec_time::numeric,0) AS max_ms, rows, left(regexp_replace(query, '\s+', ' ', 'g'), 160) AS query FROM pg_stat_statements WHERE query NOT ILIKE '%pg_stat_statements%' ORDER BY total_exec_time DESC LIMIT 15;"
echo "### en cok cagrilan 15 sorgu"
p "SELECT calls, round(total_exec_time::numeric,0) AS total_ms, round(mean_exec_time::numeric,2) AS mean_ms, rows, left(regexp_replace(query, '\s+', ' ', 'g'), 160) AS query FROM pg_stat_statements WHERE query NOT ILIKE '%pg_stat_statements%' ORDER BY calls DESC LIMIT 15;"
echo "### en yuksek ortalama sureli 10 sorgu (calls>=20)"
p "SELECT calls, round(mean_exec_time::numeric,2) AS mean_ms, round(max_exec_time::numeric,0) AS max_ms, left(regexp_replace(query, '\s+', ' ', 'g'), 160) AS query FROM pg_stat_statements WHERE calls>=20 AND query NOT ILIKE '%pg_stat_statements%' ORDER BY mean_exec_time DESC LIMIT 10;"
echo "### tablo basina seq scan (seq_tup_read en yuksek 10)"
p "SELECT relname, seq_scan, seq_tup_read, idx_scan, round(100.0*idx_scan/NULLIF(idx_scan+seq_scan,0),1) AS idx_pct, n_live_tup, n_dead_tup FROM pg_stat_user_tables ORDER BY seq_tup_read DESC LIMIT 10;"
echo "### onbellek isabet orani"
p "SELECT round(100.0*sum(heap_blks_hit)/NULLIF(sum(heap_blks_hit+heap_blks_read),0),2) AS table_hit_pct FROM pg_statio_user_tables;"
p "SELECT round(100.0*sum(idx_blks_hit)/NULLIF(sum(idx_blks_hit+idx_blks_read),0),2) AS index_hit_pct FROM pg_statio_user_indexes;"
p "SELECT datname, xact_commit, xact_rollback, deadlocks, temp_files, pg_size_pretty(temp_bytes) AS temp_bytes, round(blk_read_time::numeric) AS read_ms FROM pg_stat_database WHERE datname='bingol';"
echo "### kilit beklemeleri (an itibariyla)"
p "SELECT count(*) FILTER (WHERE NOT granted) AS waiting_locks, count(*) AS locks FROM pg_locks;"
p "SELECT state, wait_event_type, count(*) FROM pg_stat_activity WHERE datname='bingol' GROUP BY 1,2 ORDER BY 3 DESC;"
echo "### WAL / disk"
p "SELECT pg_size_pretty(pg_database_size('bingol')) AS db_size, pg_size_pretty(pg_current_wal_lsn() - '0/0'::pg_lsn) AS wal_total;"
p "SELECT checkpoints_timed, checkpoints_req FROM pg_stat_bgwriter;" || true
echo "### Redis"
$REDIS info memory 2>/dev/null | grep -E "used_memory_human|maxmemory_human|evicted"
$REDIS info stats 2>/dev/null | grep -E "instantaneous_ops_per_sec|total_commands_processed|evicted_keys|rejected_connections"
$REDIS dbsize 2>/dev/null
} > "$F" 2>&1
echo "$F"
