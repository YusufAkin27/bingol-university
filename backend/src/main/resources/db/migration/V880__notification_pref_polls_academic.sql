-- Bildirim tercihleri: "Anketler" ve "Akademik duyurular" icin ayri bayraklar.
-- Gonderim kosulu = ana tur bayragi (announcements / communities) VE bu bayrak (NotificationService.doSend ve toplu sorgular).
-- Bu yuzden DEFAULT TRUE mevcut kullanicilarin davranisini degistirmez: ana bayragi kapatmis olan zaten almiyordu, almamaya
-- devam eder; geri doldurma (UPDATE) gerekmez ve kasitli olarak yapilmaz (polls = announcements AND communities denenirse
-- communities kapali olan kullanici genel anketleri de kaybederdi).
ALTER TABLE notification_pref ADD COLUMN polls BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE notification_pref ADD COLUMN academic_announcements BOOLEAN NOT NULL DEFAULT TRUE;
