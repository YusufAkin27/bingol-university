-- P04: mail kampanya iptali kuyruktaki postalari da durdurabilsin diye kuyruk satirina kampanya bagi.
-- Nullable: islemsel postalar ve eski satirlar bos kalir. Indeks yalniz kampanyali satirlari kapsar (kucuk, kismi).
ALTER TABLE mail_outbox ADD COLUMN campaign_id BIGINT;

CREATE INDEX ntf1100_mail_campaign_idx ON mail_outbox (campaign_id, status) WHERE campaign_id IS NOT NULL;
