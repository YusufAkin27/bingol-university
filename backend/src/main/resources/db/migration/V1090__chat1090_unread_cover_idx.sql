-- FIX-P03 (A02#5, A09#5): okunmamis sayaci (MessageRepository.unreadCounts, LIMIT 100 ile kesilir) icin kapsayan
-- kismi indeks. Eski idx_perf_message_unread (V59) created_at / suppressed kolonlarini kapsamadigindan her eslesen
-- satir icin heap erisimi gerekiyordu; burada sorgunun tum suzgecleri indeks icinde degerlendirilir (index-only scan).
-- Predicate (hidden_at/deleted_at IS NULL) sorgudaki kosullardan cikarilir. Eski indeks DUSURULMEZ (diger sorgular
-- kullaniyor olabilir; dusurme ancak pg_stat_user_indexes kanitiyla ayri migration'da).
-- Buyuk tabloda canli kurulum icin: ayni adla CREATE INDEX CONCURRENTLY elle yapilip bu dosya "repair" edilebilir.
CREATE INDEX chat1090_unread_cover ON message (conversation_id, id) INCLUDE (sender_id, created_at, suppressed)
    WHERE hidden_at IS NULL AND deleted_at IS NULL;
