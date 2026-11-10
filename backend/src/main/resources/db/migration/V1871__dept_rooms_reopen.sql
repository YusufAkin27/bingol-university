-- Bolum sohbet odalari artik KAPATILAMAZ: eski kapali kayitlar acilir (uyeler otomatik donmez; kullanici katilinca eklenir).
-- Kapali durum yalniz chat_room_link.closed sutununda tutulur.
UPDATE chat_room_link SET closed = FALSE WHERE kind = 'DEPARTMENT' AND closed = TRUE;
