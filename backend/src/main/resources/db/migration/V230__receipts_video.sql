-- Iletildi makbuzu (WhatsApp tik mantigi) + video mesaj.
-- last_delivered_message_id: uyenin "iletildi" imleci (okundu >= iletildi). Mevcut okunmuslar iletilmis sayilir.
ALTER TABLE conversation_member ADD COLUMN last_delivered_message_id BIGINT NOT NULL DEFAULT 0;
UPDATE conversation_member SET last_delivered_message_id = last_read_message_id WHERE last_read_message_id > 0;
-- Mesaj sayfasinin durum hesabi: konusmanin aktif uyeleri ve imlecleri tek indeks taramasiyla gelir
CREATE INDEX rcp230_member_conv_active ON conversation_member (conversation_id, user_id)
    INCLUDE (last_read_message_id, last_delivered_message_id, joined_at) WHERE left_at IS NULL;
-- Bir ack araliginda hangi gonderenlerin mesaji var (grup toplulastirma)
CREATE INDEX rcp230_message_conv_sender ON message (conversation_id, sender_id, id);

-- Video ek: poster olmayabilir (thumb_key bos), sure ms.
ALTER TABLE message_attachment ALTER COLUMN thumb_key DROP NOT NULL;
ALTER TABLE message_attachment ADD COLUMN duration_ms INTEGER;
ALTER TABLE message_attachment DROP CONSTRAINT chi95_att_kind_ck;
ALTER TABLE message_attachment ADD CONSTRAINT vid230_att_kind_ck CHECK (kind IN ('IMAGE', 'VIDEO'));
-- Gunluk video kotasi / kullanici sorgulari icin
CREATE INDEX vid230_att_video_uploader ON message_attachment (uploader_id, created_at) WHERE kind = 'VIDEO';
