-- Golge engel: engel iliskisi varken birebir sohbette atilan mesaj hata vermez, kaydedilir ama karsi tarafa HICBIR
-- yerde ulasmaz (kalici bayrak; engel sonradan kalksa da gizli kalir).
ALTER TABLE message ADD COLUMN suppressed BOOLEAN NOT NULL DEFAULT FALSE;
-- Konusmada en az bir bastirilmis mesaj var: gecmis / liste sorgulari gorunurluk suzgecini kullanir
ALTER TABLE conversation ADD COLUMN shadowed BOOLEAN NOT NULL DEFAULT FALSE;
-- Bastirilmamis (herkese gorunur) son mesaj; liste sirasi ve onizleme icin
ALTER TABLE conversation ADD COLUMN last_visible_message_id BIGINT;
UPDATE conversation SET last_visible_message_id = last_message_id;
-- Uyenin kendi bastirilmis son mesaji (gonderen kendi mesajini listede gorur)
ALTER TABLE conversation_member ADD COLUMN last_own_suppressed_message_id BIGINT NOT NULL DEFAULT 0;
CREATE INDEX shd260_message_suppressed ON message (conversation_id, sender_id, id) WHERE suppressed;
