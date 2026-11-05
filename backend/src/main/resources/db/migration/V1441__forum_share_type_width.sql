-- Kampus Forum paylasimi (E): message.share_type artik FORUM_TOPIC / FORUM_COMMENT de tasir (VARCHAR(8) dar kaliyordu).
-- Sutun genisletme PostgreSQL'de yalniz meta veri degisikligidir (tablo yeniden yazilmaz).
ALTER TABLE message ALTER COLUMN share_type TYPE VARCHAR(16);
