-- Yonetici bildirim gonderimi: yeni kitle turleri (fakulte, dil), duraklatma, sayaclar, kaynak (kampanya/hizli/test)

ALTER TABLE push_campaign DROP CONSTRAINT campaign_audience_check;
ALTER TABLE push_campaign ADD CONSTRAINT campaign_audience_check
    CHECK (audience_type IN ('ALL', 'DEPARTMENT', 'CLASS_YEAR', 'USERS', 'ADMINS', 'SELF', 'FACULTY', 'LANGUAGE'));

ALTER TABLE push_campaign DROP CONSTRAINT campaign_status_check;
ALTER TABLE push_campaign ADD CONSTRAINT campaign_status_check
    CHECK (status IN ('SCHEDULED', 'SENDING', 'SENT', 'CANCELLED', 'FAILED', 'PAUSED'));

-- 500 kullanici kimligi 2000 karakteri asabilir
ALTER TABLE push_campaign ALTER COLUMN audience_value TYPE VARCHAR(10000);

-- audience_size: cozumlenen tekil kitle; recipient_count: tercihe saygi sonrasi uygulama ici bildirim yazilan kisi
ALTER TABLE push_campaign ADD COLUMN audience_size INTEGER;
ALTER TABLE push_campaign ADD COLUMN source VARCHAR(12) NOT NULL DEFAULT 'CAMPAIGN';
ALTER TABLE push_campaign ADD CONSTRAINT campaign_source_check CHECK (source IN ('CAMPAIGN', 'QUICK', 'TEST'));

CREATE INDEX npc450_campaign_dedupe ON push_campaign (created_by, created_at DESC);
