-- Birebir mesaj bilgisi (MI-BE): alicinin iletildi / okundu aninin GERCEK zamani.
-- Geri doldurma YOK: conversation_member yalniz imlec (son iletilen/okunan mesaj kimligi) tutar, zaman tutmaz;
-- eski mesajlarin zamani bilinmez ve uydurulmaz. NULL = "kayit bulunmuyor" (API 200, deliveredAt/readAt null).
ALTER TABLE message ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;
ALTER TABLE message ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;
-- Mesaja verilen yanitlari sayfalamak icin (bilgi ekrani "yanitlar" listesi, id'ye gore azalan)
CREATE INDEX IF NOT EXISTS mi_msg_reply_idx ON message (reply_to_message_id, id DESC)
    WHERE reply_to_message_id IS NOT NULL;
