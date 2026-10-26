-- T21 Asama 2 (genislet): mesaj govdesi sifreli saklanir. Eski `body` sutunu gecis bitene kadar kalir (NULL olabilir).
-- Gecis isi uygulama icinde calisir (MessageEncryptionMigrator); daraltma icin db/contract/V69_1 (docs/ENCRYPTION.md &sect;8.1).

ALTER TABLE message ADD COLUMN body_ciphertext BYTEA;
ALTER TABLE message ADD COLUMN body_nonce      BYTEA;
ALTER TABLE message ADD COLUMN key_version     INT;
ALTER TABLE message ALTER COLUMN body DROP NOT NULL;

-- Her satirda duz metin ya da tam sifreli govde bulunmali (buyuk tabloda kilit kisa kalsin diye NOT VALID)
ALTER TABLE message ADD CONSTRAINT message_body_present CHECK (
    body IS NOT NULL OR (body_ciphertext IS NOT NULL AND body_nonce IS NOT NULL AND key_version IS NOT NULL)) NOT VALID;

-- Gecis isinin taradigi satirlar (kismi indeks; is bitince bos kalir)
CREATE INDEX idx_message_unencrypted ON message (id) WHERE body_ciphertext IS NULL;
