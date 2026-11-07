-- Gunluk menu bildirimi tercihi: VARSAYILAN KAPALI (kullanici acikca acar); mevcut kullanicilarin davranisi degismez.
ALTER TABLE notification_pref ADD COLUMN IF NOT EXISTS meal_menu BOOLEAN NOT NULL DEFAULT FALSE;
