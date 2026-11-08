-- Gorunen begeni eki (kullanici karari 2026-11-08, secenek A): mevcut her gonderi/reels icin gorunen toplam 50-350
-- araligina cekilir. Gercek sayac (post.like_count) ve post_like satirlari DEGISMEZ; PostCounterRepairJob gercek
-- sayimi korur. Arayuze giden sayi = like_count + like_boost. Yeni gonderilerde ek 0'dir.
ALTER TABLE post ADD COLUMN like_boost INT NOT NULL DEFAULT 0;

UPDATE post
   SET like_boost = GREATEST((50 + floor(random() * 301))::int - like_count, 0)
 WHERE like_boost = 0;
