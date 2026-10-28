-- V520: veritabani olcek/saklama duzenlemesi (20 bin kullanici hedefi). Ayrinti: docs/DATABASE.md
-- Uygulanmis hicbir migration degistirilmedi; yalniz yeni nesneler, indeks degisikligi ve autovacuum ayari.
-- Indeks adlari onekli (dbs520_) ve tum semada benzersizdir.

-- 1) Analitik: ham olay (varsayilan 45 gun) + kalici gunluk toplulastirma.
--    Raporlar tamamlanmis gunleri bu tablodan okur (AnalyticsReportRepository); dbmaint.AnalyticsRollupJob her gece doldurur.
--    "users" = o gunun tekil kullanici sayisi; araliklarda toplanirsa "gun-kullanici" olur (tekil kisi sayisi degil).
CREATE TABLE analytics_event_daily (
    day    DATE         NOT NULL,
    name   VARCHAR(40)  NOT NULL,
    screen VARCHAR(60)  NOT NULL DEFAULT '',
    events INTEGER      NOT NULL,
    users  INTEGER      NOT NULL,
    PRIMARY KEY (day, name, screen)
);

-- Mevcut ham olaylardan geri doldurma (bugun haric tamamlanmis Istanbul gunleri)
INSERT INTO analytics_event_daily (day, name, screen, events, users)
SELECT CAST(created_at AT TIME ZONE 'Europe/Istanbul' AS date), name, COALESCE(screen, ''), count(*), count(DISTINCT user_id)
FROM analytics_event
WHERE created_at < (date_trunc('day', now() AT TIME ZONE 'Europe/Istanbul')) AT TIME ZONE 'Europe/Istanbul'
GROUP BY 1, 2, 3
ON CONFLICT DO NOTHING;

-- created_at yalnizca eklemeyle artar: BRIN (B-agaca gore ~1000 kat kucuk) saklama silmesi ve aralik taramasi icin yeter.
DROP INDEX IF EXISTS idx_analytics_event_created;
-- (name, created_at): ham tabloda yalniz son ~45 gun var; ad bazli raporlar ozetten okunur, ham taramaya gerek kalmadi
DROP INDEX IF EXISTS idx_analytics_event_name;
CREATE INDEX dbs520_analytics_event_created_brin ON analytics_event USING brin (created_at) WITH (pages_per_range = 32);

-- 2) Yinelenen indeks: adm270_message_created (created_at, id) idx_message_created (created_at) onekini zaten kapsar.
--    Mesaj tablosu en cok yazilan tablodur; her indeks yazma maliyetidir.
DROP INDEX IF EXISTS idx_message_created;

-- 3) Eksik indeksler (saklama silmeleri ve kullanici bazli sorgular)
-- hic okunmamis bildirimlerin yasa gore silinmesi (readAt IS NULL AND createdAt < x)
CREATE INDEX dbs520_notification_unread_created ON notification (created_at) WHERE read_at IS NULL;
-- bildirim kutusu ust siniri: kullanici basina en yeni N disindakileri silme (user_id, id DESC zaten var)
-- yoklama: "benim katildigim etkinlikler" ve kullanici silme CASCADE (UNIQUE(event_id,user_id) ikinci kolonu kapsamaz)
CREATE INDEX dbs520_attendance_user ON event_attendance (user_id);
-- denetim tablolari: tarihe gore parcali silme
CREATE INDEX dbs520_message_access_audit_created_brin ON message_access_audit USING brin (created_at) WITH (pages_per_range = 32);
CREATE INDEX dbs520_club_audit_created_brin ON club_audit USING brin (created_at) WITH (pages_per_range = 32);
-- mail kuyrugu: SENT/DEAD temizligi kismi indeksle (PENDING/FAILED satirlari hic girmez)
CREATE INDEX dbs520_mail_sent_at ON mail_outbox (sent_at) WHERE status = 'SENT';
CREATE INDEX dbs520_mail_dead_created ON mail_outbox (created_at) WHERE status = 'DEAD';

-- 4) Cok guncellenen tablolar: HOT guncelleme icin bos alan + daha erken autovacuum
ALTER TABLE conversation_member SET (fillfactor = 85, autovacuum_vacuum_scale_factor = 0.05, autovacuum_analyze_scale_factor = 0.05);
ALTER TABLE conversation        SET (fillfactor = 85, autovacuum_vacuum_scale_factor = 0.05, autovacuum_analyze_scale_factor = 0.05);
ALTER TABLE app_user            SET (fillfactor = 85, autovacuum_vacuum_scale_factor = 0.05, autovacuum_analyze_scale_factor = 0.05);
ALTER TABLE device              SET (fillfactor = 85, autovacuum_vacuum_scale_factor = 0.05, autovacuum_analyze_scale_factor = 0.05);
ALTER TABLE activity_daily      SET (autovacuum_vacuum_scale_factor = 0.05, autovacuum_analyze_scale_factor = 0.05);
ALTER TABLE user_device_log     SET (fillfactor = 90, autovacuum_vacuum_scale_factor = 0.05, autovacuum_analyze_scale_factor = 0.05);
-- kuyruk/bildirim tablolari: surekli ekleme + silme -> olu satir hizli birikir
ALTER TABLE mail_outbox         SET (autovacuum_vacuum_scale_factor = 0.02, autovacuum_analyze_scale_factor = 0.02, autovacuum_vacuum_cost_limit = 1000);
ALTER TABLE push_outbox         SET (autovacuum_vacuum_scale_factor = 0.02, autovacuum_analyze_scale_factor = 0.02, autovacuum_vacuum_cost_limit = 1000);
ALTER TABLE notification        SET (autovacuum_vacuum_scale_factor = 0.02, autovacuum_analyze_scale_factor = 0.02, autovacuum_vacuum_cost_limit = 1000);
-- yalniz-ekleme log tablolari: PG13+ insert tabanli vacuum (gorunurluk haritasi/dondurma) erken tetiklensin
ALTER TABLE analytics_event     SET (autovacuum_vacuum_scale_factor = 0.05, autovacuum_vacuum_insert_scale_factor = 0.05, autovacuum_analyze_scale_factor = 0.05);
ALTER TABLE message             SET (autovacuum_vacuum_scale_factor = 0.05, autovacuum_vacuum_insert_scale_factor = 0.05, autovacuum_analyze_scale_factor = 0.05);
ALTER TABLE admin_audit         SET (autovacuum_vacuum_insert_scale_factor = 0.05);

-- 5) Sorgu izleme: pg_stat_statements (sunucu shared_preload_libraries ile yuklemis olmali; yoksa/yetki yoksa atlanir)
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_stat_statements etkinlestirilemedi: %', SQLERRM;
END $$;
