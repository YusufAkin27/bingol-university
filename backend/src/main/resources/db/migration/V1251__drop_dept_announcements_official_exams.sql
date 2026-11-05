-- Akademik "bolum duyurulari" ve "resmi sinav programi" ozellikleri kaldirildi (V320'de olusturulan tablolar).
-- V320 canlida uygulanmistir, degistirilmez. Kisisel sinavlar (tt_exam) ve akademik takvim (academic_event) KALIR.
-- announcement_read, department_announcement'a bagli oldugundan once dusurulur; acd320_* indeksleri tabloyla gider.
DROP TABLE IF EXISTS announcement_read CASCADE;
DROP TABLE IF EXISTS department_announcement CASCADE;
DROP TABLE IF EXISTS exam_schedule CASCADE;

-- Bolum duyurusu bildirimleri (alt tur ACADEMIC_ANNOUNCEMENT) ve bu alt tura ait kullanici tercih satirlari.
-- SINAV hatirlatmalari (EXAM_REMINDER) ve notification_pref.academic_announcements bayragi KALIR.
DELETE FROM notification WHERE subtype = 'ACADEMIC_ANNOUNCEMENT';
DELETE FROM notification_subtype_pref WHERE subtype = 'ACADEMIC_ANNOUNCEMENT';
