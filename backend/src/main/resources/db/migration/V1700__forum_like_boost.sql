-- V1700 (Kampus Forum): gorunen begeni eki (kullanici karari 2026-11-08, gonderiler icin V1680 ile ayni yontem).
-- Arayuze like_count + like_boost gider; gercek sayac (siralama, begeni satirlari, onarim) degismez.
-- Mevcut tum konu ve yorumlarin GORUNEN toplami 50-350 arasina cekilir; sonradan acilanlar 0 ekle baslar.
ALTER TABLE forum_topic ADD COLUMN like_boost INT NOT NULL DEFAULT 0;
ALTER TABLE forum_comment ADD COLUMN like_boost INT NOT NULL DEFAULT 0;

UPDATE forum_topic
   SET like_boost = GREATEST((50 + floor(random() * 301))::int - like_count, 0)
 WHERE like_boost = 0;

UPDATE forum_comment
   SET like_boost = GREATEST((50 + floor(random() * 301))::int - like_count, 0)
 WHERE like_boost = 0;
