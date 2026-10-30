-- Bildirim tercihi: sohbet mesaj metni onizlemesi push govdesinde gorunsun mu (KVKK: varsayilan KAPALI, kullanici acar).
-- Kapaliyken push govdesi sabit "Yeni mesaj" + gonderen adidir. Yalniz ekleme; mevcut kullanicilar kapali kalir.
ALTER TABLE notification_pref ADD COLUMN message_preview BOOLEAN NOT NULL DEFAULT FALSE;
