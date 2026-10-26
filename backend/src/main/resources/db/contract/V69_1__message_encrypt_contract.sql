-- T21 Asama 2 (daralt): duz metin `body` sutununu dusurur. VARSAYILAN OLARAK UYGULANMAZ.
-- Yalnizca gecis isi bittikten (kalan duz metin = 0) ve veritabani yedegi alindiktan sonra, Flyway konumuna
-- `classpath:db/contract` eklenerek calistirilir (V73/V90 zaten uygulandigindan 69.1 "sira disi" sayilir):
--   SPRING_FLYWAY_LOCATIONS=classpath:db/migration,classpath:db/contract  SPRING_FLYWAY_OUT_OF_ORDER=true
-- Uyguladiktan sonra ikisini de kaldirin (script: scripts/crypto-contract.sh yalnizca on kontrol yapar).
-- Duz metin satir kalmissa ISTISNA firlatir (uygulama acilmaz, veri degismez). Geri alma: yalnizca yedekten.

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM message WHERE body_ciphertext IS NULL AND deleted_at IS NULL) THEN
        RAISE EXCEPTION 'plaintext messages remain; wait for the encryption job to finish (see docs/ENCRYPTION.md)';
    END IF;
END $$;

ALTER TABLE message DROP CONSTRAINT message_body_present;
DROP INDEX idx_message_unencrypted;
ALTER TABLE message DROP COLUMN body;
-- T13: silinmis (tombstone) mesajlarda sifreli govde yoktur; NOT NULL yerine kisit kullanilir
ALTER TABLE message ADD CONSTRAINT message_body_present CHECK (
    deleted_at IS NOT NULL OR (body_ciphertext IS NOT NULL AND body_nonce IS NOT NULL AND key_version IS NOT NULL));
