-- FIX-P03 (A10#16): MessageEncryptionMigrator her dakika "body_ciphertext IS NULL AND body IS NOT NULL" arar.
-- idx_message_unencrypted (V69) yalniz body_ciphertext IS NULL'u kapsar; admin kalici silmesiyle olusan (govdesi
-- bos) satirlari da tarar. Bu kismi indeks yalniz gercek sifrelenecek satirlari tutar (cogu zaman bos).
-- Duz metin `body` sutunu elle dusurulduyse (db/contract/V69_1) indeks kurulmaz; migration yine basarili sayilir.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = current_schema() AND table_name = 'message' AND column_name = 'body') THEN
        EXECUTE 'CREATE INDEX chat1092_message_plain_pending ON message (id) '
             || 'WHERE body_ciphertext IS NULL AND body IS NOT NULL';
    END IF;
END
$$;
