-- K-33 ONAYI BEKLER -- BU DOSYA BILEREK Flyway konumunun (db/migration) DISINDADIR; uygulanmaz.
--
-- W2-A / T-073 (A2-12): kullanilmayan / yazma maliyeti yuksek indeksler ve HOT'u engelleyen indeks.
-- Denetimin olcumu yerel yuk karisimindandir (idx_scan=0); URETIMDE 2 hafta pg_stat_user_indexes izlenmeden
-- DUSURULMEZ (H-08, K-33 oneri (a)). Onay + dogrulama sonrasi:
--   1) Bu dosyayi V961__prf9_drop_unused_indexes.sql olarak db/migration altina TASIYIN
--      (yanina V961__prf9_drop_unused_indexes.sql.conf dosyasini da: executeInTransaction=false),
--   2) yalniz idx_scan'i gercekten 0 kalanlari birakin (asagidaki dogrulama sorgusu), digerlerini silin,
--   3) yeni gece oncesi yazma yukunu (INSERT/DELETE ms) once/sonra olcun (docs/PERFORMANCE.md).
-- Uygulanmis migration'a dokunulmaz: bu yeni bir surumdur (V960-V969 W2-A araligi).
--
-- DOGRULAMA SORGUSU (uretimde, izleme baslangicindan >= 14 gun sonra; sayaclar pg_stat_reset ile sifirlanmamis olmali):
--   SELECT s.relname AS tablo, s.indexrelname AS indeks, s.idx_scan, pg_size_pretty(pg_relation_size(s.indexrelid)) AS boyut
--   FROM pg_stat_user_indexes s
--   WHERE s.indexrelname IN ('idx_perf_message_unread', 'idx_perf_message_visible_created', 'ntf73_user_type',
--                            'p14_notif_created', 'idx_app_user_last_seen', 'post310_score_idx')
--   ORDER BY s.idx_scan, pg_relation_size(s.indexrelid) DESC;
--   -- statistik baslangici: SELECT stats_reset FROM pg_stat_database WHERE datname = current_database();
--
-- RISK NOTLARI (kod taramasi; denetim olcumunde idx_scan=0 olsa bile uretimde kullanilabilir):
--   * idx_perf_message_unread (V59): MessageRepository.unreadCounts icin yazildi (kapsayan kismi indeks); planlayici
--     rcp230_message_conv_sender'i secmis olabilir. Dusurmeden once o sorguyu EXPLAIN (ANALYZE, BUFFERS) ile bakin.
--   * idx_perf_message_visible_created (V59): yonetici raporu "gunluk mesaj sayisi" (messagesPerDay).
--   * idx_app_user_last_seen (V40): yonetici kullanici listesinde lastSeenAt siralamasi (AdminUserRepository beyaz listesi);
--     dusunce o siralama tarama + sort olur (admin, nadir). KAZANC: ActivityTracker "UPDATE app_user SET last_seen_at"
--     HOT olabilir (V520 fillfactor=85 simdi bu indeks yuzunden etkisiz).
--   * post310_score_idx (V310): PostRepository "popular" kapsami (score DESC) kullanir; kapsam kullaniliyorsa TUTUN
--     (asagida yorum satiri). PostRankService rank_score ayri; HOT icin rank_score indeksi ayrica degerlendirilmeli.
--   * ntf73_user_type (V73), p14_notif_created (V760): bildirim tablosunda 8 indeks, silme ~1 ms/satir (A2-08).
--
-- idx_analytics_event_user (133 MB, tablonun %32'si) BURADA YOK: KVKK silme/disa aktarma (DELETE ... WHERE user_id)
-- icin gerekli; kismi/BRIN gecisi tasarim karari ister (kullanici bazli silme yolu, ham olay 45 gun). Sonraki is.

DROP INDEX CONCURRENTLY IF EXISTS idx_perf_message_unread;
DROP INDEX CONCURRENTLY IF EXISTS idx_perf_message_visible_created;
DROP INDEX CONCURRENTLY IF EXISTS ntf73_user_type;
DROP INDEX CONCURRENTLY IF EXISTS p14_notif_created;
DROP INDEX CONCURRENTLY IF EXISTS idx_app_user_last_seen;
-- Popular kapsami kullaniliyorsa AKTIF ETMEYIN:
-- DROP INDEX CONCURRENTLY IF EXISTS post310_score_idx;
