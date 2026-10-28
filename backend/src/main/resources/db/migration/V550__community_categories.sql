-- Kulup kategorileri (V550-V559): yonetici panelinden yonetilen sinirli liste.
-- community.category (varchar 40) serbest metin olarak kalir ve artik bu tablonun category_key degerini tasir
-- (FK yok: eski/yetim degerler veri kaybi olmadan okunur; yazma yolunda servis dogrular).
CREATE TABLE community_category (
    id           BIGSERIAL PRIMARY KEY,
    category_key VARCHAR(40) NOT NULL,
    name_tr      VARCHAR(80) NOT NULL,
    name_en      VARCHAR(80) NOT NULL,
    name_ar      VARCHAR(80) NOT NULL,
    icon         VARCHAR(40),
    sort_order   INT         NOT NULL DEFAULT 0,
    active       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ccat550_key_uq ON community_category (category_key);
CREATE INDEX ccat550_active_sort ON community_category (active, sort_order, id);

-- 1) Mevcut kulupler kategorilerini kaybetmesin: kullanilan degerler oldugu gibi anahtar olur
--    (en kalabaliktan baslayarak ilk 20'si aktif, kalani pasif).
INSERT INTO community_category (category_key, name_tr, name_en, name_ar, sort_order, active)
SELECT cat, cat, cat, cat, rn * 10, rn <= 20
FROM (SELECT TRIM(category) AS cat,
             ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC, TRIM(category)) AS rn
      FROM community
      WHERE category IS NOT NULL AND TRIM(category) <> ''
      GROUP BY TRIM(category)) t;

-- 2) Tablo hala bossa (yeni kurulum) varsayilan kategoriler
INSERT INTO community_category (category_key, name_tr, name_en, name_ar, icon, sort_order, active)
SELECT v.k, v.tr, v.en, v.ar, v.ic, v.so, TRUE
FROM (VALUES
    ('akademik', 'Akademik', 'Academic', 'أكاديمي', 'school', 10),
    ('spor', 'Spor', 'Sports', 'رياضة', 'sports', 20),
    ('sanat', 'Sanat', 'Arts', 'فنون', 'palette', 30),
    ('kultur', 'Kültür', 'Culture', 'ثقافة', 'theater', 40),
    ('teknoloji', 'Teknoloji', 'Technology', 'تقنية', 'code', 50),
    ('bilim', 'Bilim', 'Science', 'علوم', 'science', 60),
    ('sosyal-sorumluluk', 'Sosyal Sorumluluk', 'Social Responsibility', 'مسؤولية اجتماعية', 'volunteer', 70),
    ('girisimcilik', 'Girişimcilik', 'Entrepreneurship', 'ريادة الأعمال', 'rocket', 80)
) AS v(k, tr, en, ar, ic, so)
WHERE NOT EXISTS (SELECT 1 FROM community_category);
