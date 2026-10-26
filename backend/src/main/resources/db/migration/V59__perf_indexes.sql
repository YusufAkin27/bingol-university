-- Performans indeksleri (T6). Her indeks docs/PERF.md'de EXPLAIN (ANALYZE, BUFFERS) oncesi/sonrasi ile kanitlidir.
-- Yalnizca EK indeks: tablo/sutun degismez. Adlar "idx_perf_" onekli (sema genelinde benzersiz).
-- Buyuk tablolarda uretimde canli eklemek icin CREATE INDEX CONCURRENTLY (Flyway disinda) tercih edilir.

-- Haber liste sayfasi: count(*) WHERE type=? AND hidden=false seq scan'di (874 tampon) -> index-only scan.
-- Siralama sutunlari (published_date DESC, id DESC) de ayni indekste: findByTypeAndHiddenFalse sayfa sorgusuna uyar.
CREATE INDEX idx_perf_news_type_hidden_date ON news_item (type, hidden, published_date DESC, id DESC);
-- Ayni, type filtresi olmayan liste (findByHiddenFalse) ve count(*) WHERE hidden=false.
CREATE INDEX idx_perf_news_hidden_date ON news_item (hidden, published_date DESC, id DESC);

-- Konusma listesindeki okunmamis sayaci (MessageRepository.unreadCounts): m.id > son_okunan AND sender_id <> uid
-- AND hidden_at IS NULL. uq_message_client uzerinden gezip yigin okuyordu; kapsayan kismi indeks index-only scan yapar.
CREATE INDEX idx_perf_message_unread ON message (conversation_id, id) INCLUDE (sender_id) WHERE hidden_at IS NULL;

-- Yonetici raporu "gunluk mesaj sayisi" (messagesPerDay): hidden_at IS NULL filtresi yigina gitmeyi gerektiriyordu.
CREATE INDEX idx_perf_message_visible_created ON message (created_at) WHERE hidden_at IS NULL;

-- Yonetici kullanici aramasi: display_name ILIKE '%q%' OR email ILIKE '%q%' seq scan'di (pg_trgm V30'da kurulu).
CREATE INDEX idx_perf_user_name_trgm ON app_user USING GIN (display_name gin_trgm_ops);
CREATE INDEX idx_perf_user_email_trgm ON app_user USING GIN (email gin_trgm_ops);

-- Yonetici kullanici listesi varsayilan sirasi: ORDER BY created_at DESC NULLS LAST, id DESC (siralama adimini kaldirir).
CREATE INDEX idx_perf_user_created_desc ON app_user (created_at DESC NULLS LAST, id DESC);
