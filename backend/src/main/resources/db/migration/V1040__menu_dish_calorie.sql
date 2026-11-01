-- Yemek adina bagli "son bilinen kalori". Yonetici bir gunun yemegine kalori girince deger buraya da yazilir; ayni
-- isimli yemek baska bir tarihte (ornegin gelecek ayin menusu) kendi satiri yoksa bu degerle gosterilir.
-- Tarihe ozel satir (menu_item_calorie) her zaman onceliklidir. Anahtar: MenuItemKey.of (normalize yemek adi).
-- Indeks oneki: mc_. Kalori silmek = satiri silmek.
CREATE TABLE menu_dish_calorie (
    item_key   VARCHAR(300) PRIMARY KEY,
    item_name  VARCHAR(300) NOT NULL,
    kcal       INT          NOT NULL,
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by VARCHAR(80),
    CONSTRAINT mc_dish_ck_kcal CHECK (kcal >= 0 AND kcal <= 5000)
);

-- Mevcut girislerden geri doldurma: her yemek icin en son tarihli deger.
INSERT INTO menu_dish_calorie (item_key, item_name, kcal, updated_at, updated_by)
SELECT DISTINCT ON (item_key) item_key, item_name, kcal, updated_at, updated_by
FROM menu_item_calorie
ORDER BY item_key, menu_date DESC, updated_at DESC;

-- Menu gorseli ICERIGE baglidir: content_hash = menunun yemek listesinin (normalize, siralamasiz) SHA-256 ozeti.
-- Birebir ayni menu ayni gorseli alir; menude en ufak degisiklik ozeti degistirir ve gorsel dusup "yeni gorsel bekliyor"
-- olur. menu_day.image_url eski alandir: acilista bu tabloya tasinir ve bosaltilir.
CREATE TABLE menu_content_image (
    content_hash VARCHAR(64)  PRIMARY KEY,
    image_url    VARCHAR(500) NOT NULL,
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);
