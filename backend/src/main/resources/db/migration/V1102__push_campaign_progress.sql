-- P04: push kampanyasi ilerleme isareti. Gonderim kullanici kimligi sirasiyla parca parca ilerler; her parcadan sonra
-- last_user_id/last_progress_at yazilir. Sunucu yeniden baslayip kampanya FAILED isaretlenirse yonetici "yeniden gonder"
-- dediginde yalniz last_user_id'den SONRAKI kisilere gider (cift bildirim olmaz).
ALTER TABLE push_campaign ADD COLUMN last_user_id BIGINT;
ALTER TABLE push_campaign ADD COLUMN last_progress_at TIMESTAMPTZ;
