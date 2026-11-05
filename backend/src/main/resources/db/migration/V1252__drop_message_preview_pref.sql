-- Mesaj onizleme tercihi kaldirildi: push govdesinde mesaj metni onizlemesi artik herkes icin her zaman gider.
-- V896 ile eklenen sutun duser (eski tercih satirlari sutunla birlikte temizlenir).
ALTER TABLE notification_pref DROP COLUMN IF EXISTS message_preview;
