-- Profil/arama performansi (pg_trgm V30'da kurulu; yeni extension gerekmez).

-- Haber aramasindaki "title ILIKE '%q%'" yedek kolu seq scan yapmasin.
CREATE INDEX prf160_news_title_trgm ON news_item USING GIN (title gin_trgm_ops);

-- GET /api/me/summary okunmamis bildirim sayimi: yalnizca okunmamis satirlari tutan kucuk kismi indeks.
CREATE INDEX prf160_notification_unread ON notification (user_id) WHERE read_at IS NULL;
