-- Kampus Forum: kategori genisletme (kullanici istegi: "kategorileri arttir, cok fazla olsun").
-- Eklemeli ve idempotent: mevcut 8 kategorinin kimligi/slug'i/siralamasi DEGISMEZ (konular bagli); yalniz grup atanir.
-- forum_category_group: kategori secicide bolum basligi (tr/en/ar). Yeni kategoriler sort_order 100'den baslar
-- (ilk 8 sirayi koruyan eski kategoriler yatay cip satirinda onde kalir). Indeks/kisit adlari onekli (fc148_).

CREATE TABLE IF NOT EXISTS forum_category_group (
    group_key  VARCHAR(30) PRIMARY KEY,
    name_tr    VARCHAR(80) NOT NULL,
    name_en    VARCHAR(80) NOT NULL,
    name_ar    VARCHAR(80) NOT NULL,
    sort_order INT         NOT NULL DEFAULT 0
);

ALTER TABLE forum_category ADD COLUMN IF NOT EXISTS group_key VARCHAR(30);
ALTER TABLE forum_category ADD CONSTRAINT fc148_category_group_fk FOREIGN KEY (group_key)
    REFERENCES forum_category_group (group_key);
CREATE INDEX IF NOT EXISTS fc148_category_group_idx ON forum_category (group_key, sort_order);

INSERT INTO forum_category_group (group_key, name_tr, name_en, name_ar, sort_order) VALUES
    ('genel', 'Genel', 'General', 'عام', 10),
    ('akademik', 'Akademik', 'Academic', 'أكاديمي', 20),
    ('kampus', 'Kampüs Yaşamı', 'Campus Life', 'الحياة الجامعية', 30),
    ('kariyer', 'Kariyer & Gelişim', 'Career & Growth', 'المسار المهني والتطور', 40),
    ('alanlar', 'Fakülte & Alanlar', 'Faculties & Fields', 'الكليات والمجالات', 50),
    ('bingol', 'Bingöl', 'Bingöl', 'بينغول', 60),
    ('hobi', 'Hobi & Eğlence', 'Hobbies & Fun', 'الهوايات والترفيه', 70),
    ('yasam', 'Yaşam', 'Life', 'الحياة', 80)
ON CONFLICT (group_key) DO NOTHING;

-- Mevcut 8 kategori: yalniz grup (kimlik/slug/ad/sira aynen kalir)
UPDATE forum_category SET group_key = 'genel' WHERE group_key IS NULL AND slug IN ('gundem', 'serbest-kursu', 'oneri-sikayet');
UPDATE forum_category SET group_key = 'akademik' WHERE group_key IS NULL AND slug IN ('dersler');
UPDATE forum_category SET group_key = 'kampus' WHERE group_key IS NULL AND slug IN ('yemekhane', 'kampus-yasami', 'yurtlar', 'etkinlikler');

-- Yeni kategoriler
INSERT INTO forum_category (slug, name_tr, name_en, name_ar, sort_order, group_key) VALUES
    ('duyurular', 'Duyurular', 'Announcements', 'الإعلانات', 100, 'genel'),
    ('soru-cevap', 'Soru & Cevap', 'Q&A', 'أسئلة وأجوبة', 110, 'genel'),
    ('tanisma-selam', 'Tanışma & Selam', 'Meet & Greet', 'تعارف وسلام', 120, 'genel'),
    ('yeni-ogrenci-rehberi', 'Yeni Öğrenci Rehberi', 'New Student Guide', 'دليل الطالب الجديد', 130, 'genel'),
    ('sinavlar-notlar', 'Sınavlar & Notlar', 'Exams & Grades', 'الامتحانات والدرجات', 140, 'akademik'),
    ('ders-notlari-kaynaklar', 'Ders Notları & Kaynaklar', 'Course Notes & Resources', 'ملاحظات ومصادر المقررات', 150, 'akademik'),
    ('cikmis-sorular', 'Çıkmış Sorular', 'Past Exam Questions', 'أسئلة الامتحانات السابقة', 160, 'akademik'),
    ('hocalar-ders-secimi', 'Hocalar & Ders Seçimi', 'Instructors & Course Selection', 'الأساتذة واختيار المقررات', 170, 'akademik'),
    ('bolum-tavsiyeleri', 'Bölüm Tavsiyeleri', 'Program Advice', 'نصائح حول الأقسام', 180, 'akademik'),
    ('akademik-takvim-kayit', 'Akademik Takvim & Kayıt', 'Academic Calendar & Registration', 'التقويم الأكاديمي والتسجيل', 190, 'akademik'),
    ('yaz-okulu', 'Yaz Okulu', 'Summer School', 'المدرسة الصيفية', 200, 'akademik'),
    ('cift-anadal-yandal', 'Çift Anadal & Yandal', 'Double Major & Minor', 'التخصص المزدوج والفرعي', 210, 'akademik'),
    ('erasmus-degisim', 'Erasmus & Değişim', 'Erasmus & Exchange', 'إيراسموس والتبادل', 220, 'akademik'),
    ('yuksek-lisans-akademik', 'Yüksek Lisans & Akademik Kariyer', 'Graduate Studies & Academic Career', 'الدراسات العليا والمسار الأكاديمي', 230, 'akademik'),
    ('odev-tez-proje', 'Ödev, Tez & Proje', 'Assignments, Theses & Projects', 'الواجبات والأطروحات والمشاريع', 240, 'akademik'),
    ('kutuphane', 'Kütüphane', 'Library', 'المكتبة', 250, 'kampus'),
    ('ulasim-servis', 'Ulaşım & Servis', 'Transport & Shuttle', 'النقل والحافلات', 260, 'kampus'),
    ('kantin-kafeler', 'Kantin & Kafeler', 'Canteens & Cafes', 'الكافتيريات والمقاهي', 270, 'kampus'),
    ('spor-fitness', 'Spor & Fitness', 'Sports & Fitness', 'الرياضة واللياقة', 280, 'kampus'),
    ('kulupler-topluluklar', 'Kulüpler & Topluluklar', 'Clubs & Communities', 'الأندية والمجتمعات', 290, 'kampus'),
    ('gonulluluk', 'Gönüllülük', 'Volunteering', 'العمل التطوعي', 300, 'kampus'),
    ('saglik-rehberlik', 'Sağlık & Rehberlik', 'Health & Counseling', 'الصحة والإرشاد', 310, 'kampus'),
    ('kayip-buluntu', 'Kayıp & Buluntu', 'Lost & Found', 'المفقودات', 320, 'kampus'),
    ('ikinci-el-ucretsiz', 'İkinci El & Ücretsiz', 'Second-Hand & Free', 'مستعمل ومجاني', 330, 'kampus'),
    ('ev-arkadasi-kiralik', 'Ev Arkadaşı & Kiralık', 'Roommates & Rentals', 'شريك سكن وإيجار', 340, 'kampus'),
    ('guvenlik-acil', 'Güvenlik & Acil', 'Safety & Emergency', 'الأمن والطوارئ', 350, 'kampus'),
    ('ogrenci-isleri-idari', 'Öğrenci İşleri & İdari', 'Student Affairs & Admin', 'شؤون الطلاب والإدارة', 360, 'kampus'),
    ('staj', 'Staj', 'Internships', 'التدريب', 370, 'kariyer'),
    ('kariyer-is-ilanlari', 'Kariyer & İş İlanları', 'Careers & Job Postings', 'الوظائف والفرص المهنية', 380, 'kariyer'),
    ('burs-destekler', 'Burs & Destekler', 'Scholarships & Grants', 'المنح والدعم', 390, 'kariyer'),
    ('cv-mulakat', 'CV & Mülakat', 'CV & Interviews', 'السيرة الذاتية والمقابلات', 400, 'kariyer'),
    ('kpss-ales-yds', 'KPSS, ALES & YDS', 'KPSS, ALES & YDS', 'KPSS وALES وYDS', 410, 'kariyer'),
    ('girisimcilik', 'Girişimcilik', 'Entrepreneurship', 'ريادة الأعمال', 420, 'kariyer'),
    ('mezunlar', 'Mezunlar', 'Alumni', 'الخريجون', 430, 'kariyer'),
    ('yazilim-programlama', 'Yazılım & Programlama', 'Software & Programming', 'البرمجة والتطوير', 440, 'alanlar'),
    ('muhendislik', 'Mühendislik', 'Engineering', 'الهندسة', 450, 'alanlar'),
    ('ziraat-tarim', 'Ziraat & Tarım', 'Agriculture', 'الزراعة', 460, 'alanlar'),
    ('saglik-bilimleri', 'Sağlık Bilimleri', 'Health Sciences', 'العلوم الصحية', 470, 'alanlar'),
    ('egitim-bilimleri', 'Eğitim Bilimleri', 'Education Sciences', 'العلوم التربوية', 480, 'alanlar'),
    ('hukuk-siyaset', 'Hukuk & Siyaset', 'Law & Politics', 'القانون والسياسة', 490, 'alanlar'),
    ('iktisat-isletme', 'İktisat & İşletme', 'Economics & Business', 'الاقتصاد وإدارة الأعمال', 500, 'alanlar'),
    ('fen-edebiyat', 'Fen & Edebiyat', 'Science & Literature', 'العلوم والآداب', 510, 'alanlar'),
    ('ilahiyat', 'İlahiyat', 'Theology', 'الإلهيات', 520, 'alanlar'),
    ('spor-bilimleri', 'Spor Bilimleri', 'Sport Sciences', 'علوم الرياضة', 530, 'alanlar'),
    ('guzel-sanatlar', 'Güzel Sanatlar', 'Fine Arts', 'الفنون الجميلة', 540, 'alanlar'),
    ('sehir-rehberi', 'Şehir Rehberi', 'City Guide', 'دليل المدينة', 550, 'bingol'),
    ('gezilecek-yerler', 'Gezilecek Yerler', 'Places to Visit', 'أماكن للزيارة', 560, 'bingol'),
    ('yeme-icme-bingol', 'Yeme-İçme', 'Food & Drink', 'المطاعم والمشروبات', 570, 'bingol'),
    ('bingol-hava-durumu', 'Hava Durumu', 'Weather', 'الطقس', 580, 'bingol'),
    ('bingol-ulasim', 'Bingöl Ulaşım', 'Getting Around Bingöl', 'المواصلات في بينغول', 590, 'bingol'),
    ('yerel-etkinlikler', 'Yerel Etkinlikler', 'Local Events', 'الفعاليات المحلية', 600, 'bingol'),
    ('muzik', 'Müzik', 'Music', 'الموسيقى', 610, 'hobi'),
    ('film-dizi', 'Film & Dizi', 'Movies & TV', 'الأفلام والمسلسلات', 620, 'hobi'),
    ('kitap-okuma', 'Kitap & Okuma', 'Books & Reading', 'الكتب والقراءة', 630, 'hobi'),
    ('oyun', 'Oyun', 'Gaming', 'الألعاب', 640, 'hobi'),
    ('teknoloji-gadget', 'Teknoloji & Gadget', 'Tech & Gadgets', 'التقنية والأجهزة', 650, 'hobi'),
    ('fotograf', 'Fotoğraf', 'Photography', 'التصوير', 660, 'hobi'),
    ('sanat-tasarim', 'Sanat & Tasarım', 'Art & Design', 'الفن والتصميم', 670, 'hobi'),
    ('mizah-meme', 'Mizah & Meme', 'Humor & Memes', 'الفكاهة والميمز', 680, 'hobi'),
    ('anime-manga', 'Anime & Manga', 'Anime & Manga', 'الأنمي والمانغا', 690, 'hobi'),
    ('seyahat', 'Seyahat', 'Travel', 'السفر', 700, 'hobi'),
    ('yemek-tarifleri', 'Yemek Tarifleri', 'Recipes', 'وصفات الطعام', 710, 'hobi'),
    ('moda-stil', 'Moda & Stil', 'Fashion & Style', 'الموضة والأناقة', 720, 'hobi'),
    ('otomobil', 'Otomobil', 'Automotive', 'السيارات', 730, 'hobi'),
    ('psikoloji-motivasyon', 'Psikoloji & Motivasyon', 'Psychology & Motivation', 'علم النفس والتحفيز', 740, 'yasam'),
    ('saglikli-yasam', 'Sağlıklı Yaşam', 'Healthy Living', 'الحياة الصحية', 750, 'yasam'),
    ('finans-tasarruf', 'Finans & Tasarruf', 'Finance & Saving', 'المال والادخار', 760, 'yasam'),
    ('yabanci-ogrenciler', 'Yabancı Öğrenciler', 'International Students', 'الطلاب الدوليون', 770, 'yasam'),
    ('engelsiz-kampus', 'Engelsiz Kampüs', 'Accessible Campus', 'حرم جامعي ميسّر', 780, 'yasam'),
    ('kadin-ogrenciler', 'Kadın Öğrenciler', 'Women Students', 'الطالبات', 790, 'yasam'),
    ('dini-sohbet', 'Dini Sohbet', 'Religious Talk', 'حوار ديني', 800, 'yasam')
ON CONFLICT (slug) DO NOTHING;
