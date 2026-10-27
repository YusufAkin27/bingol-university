-- Rehber eslestirme: e-postanin SHA-256'si (kucuk harf, hex) ile indeksli arama. Silinmis hesaplarda NULL (KVKK).
ALTER TABLE app_user ADD COLUMN email_sha256 VARCHAR(64);
UPDATE app_user SET email_sha256 = encode(sha256(convert_to(lower(trim(email)), 'UTF8')), 'hex')
 WHERE status <> 'DELETED' AND deleted_at IS NULL;
CREATE INDEX usr240_email_sha256 ON app_user (email_sha256);
