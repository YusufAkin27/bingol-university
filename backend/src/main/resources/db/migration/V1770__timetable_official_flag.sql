-- V1770: resmi programdan kopyalanan derslerin isareti. Sinif/bolum degisince yalniz bu dersler yeni profile gore
-- yenilenir; ogrencinin elle ekledigi dersler korunur. Onek: tt1770_
ALTER TABLE tt_course ADD COLUMN official BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX tt1770_course_official_idx ON tt_course (user_id) WHERE official;

-- Eski tohumlamalar: tohum isaretinin zamanina yakin (+-2 dk), kodsuz dersleri resmi kopya say (seeder kod yazmaz).
UPDATE tt_course c
   SET official = TRUE
  FROM tt_official_seed s
 WHERE c.user_id = s.user_id
   AND c.code IS NULL
   AND c.created_at BETWEEN s.seeded_at - INTERVAL '2 minutes' AND s.seeded_at + INTERVAL '2 minutes';
