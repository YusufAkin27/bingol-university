-- Bildirim tercihleri: "Anketler" ve "Akademik duyurular" icin ayri bayraklar (ana tur bayragindan bagimsiz).
-- Mevcut kullanicilar icin varsayilan acik (eski davranis: bu bildirimler zaten geliyordu).
ALTER TABLE notification_pref ADD COLUMN polls BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE notification_pref ADD COLUMN academic_announcements BOOLEAN NOT NULL DEFAULT TRUE;
