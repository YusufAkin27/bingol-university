-- Yeni ve tercihsiz hesaplarda onizleme acik; mevcut FALSE secimleri korunur.
ALTER TABLE notification_pref ALTER COLUMN message_preview SET DEFAULT TRUE;
