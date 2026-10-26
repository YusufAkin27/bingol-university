-- Push: cihaz bilgisi (surum, dil) ve son gorulme; 60 gun kullanilmayan token temizligi last_seen_at'e bakar.
ALTER TABLE device ADD COLUMN app_version VARCHAR(32);
ALTER TABLE device ADD COLUMN locale VARCHAR(16);
ALTER TABLE device ADD COLUMN last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now();
CREATE INDEX idx_push_device_last_seen ON device (last_seen_at);
