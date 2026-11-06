-- Etkinlik: bulusma noktasi (etkinlik yerinden ayri) + opsiyonel harita koordinati; degisiklik bildirimi kisma zamani (10 dk).
ALTER TABLE user_event ADD COLUMN meeting_point VARCHAR(200);
ALTER TABLE user_event ADD COLUMN meeting_lat DOUBLE PRECISION;
ALTER TABLE user_event ADD COLUMN meeting_lng DOUBLE PRECISION;
ALTER TABLE user_event ADD COLUMN update_notified_at TIMESTAMPTZ;
