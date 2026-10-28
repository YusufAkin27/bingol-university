-- P14 yonetici push altyapisi: kuyruk kaydina kampanya bagi, mesaj turu ve FCM hata kodu (yuk/token tutulmaz).
-- campaign_id: yukteki data.campaignId'den doldurulur; eski kayitlarda bos. error_code: UNREGISTERED, UNAVAILABLE,
-- QUOTA_EXCEEDED, EXPIRED, DEVICE_MISSING, ADMIN_CANCELLED ... (kisa kod; mesaj icerigi degil).
ALTER TABLE push_outbox ADD COLUMN campaign_id BIGINT;
ALTER TABLE push_outbox ADD COLUMN msg_type VARCHAR(24);
ALTER TABLE push_outbox ADD COLUMN error_code VARCHAR(40);

-- Kampanya hata listesi (yalniz kampanyali kayitlar)
CREATE INDEX p14_pso_campaign ON push_outbox (campaign_id, status) WHERE campaign_id IS NOT NULL;
-- Yonetici liste suzgeci (durum + sirali kimlik)
CREATE INDEX p14_pso_status_id ON push_outbox (status, id DESC);
-- Genel bildirim kutusu istatistikleri: gun bazli aralik sayimi
CREATE INDEX p14_notif_created ON notification (created_at);
