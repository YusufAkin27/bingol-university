-- V690: etkinlik derin yonetimi (P07). Sertifika iptali: satir silinmez (kullanici ayni kodu yeniden uretemesin),
-- iptal bilgisi kolonlarda tutulur. Mevcut satirlar degismez (yeni kolonlar NULL'a izinli).
-- Indeks adlari p07_ onekli ve tum semada benzersizdir.

ALTER TABLE event_certificate ADD COLUMN revoked_at    TIMESTAMPTZ;
ALTER TABLE event_certificate ADD COLUMN revoked_by    BIGINT;
ALTER TABLE event_certificate ADD COLUMN revoke_reason VARCHAR(300);

-- Yonetici sertifika listesi: etkinlik + id imeci
CREATE INDEX p07_cert_event_id ON event_certificate (event_id, id);
