-- Kulup kategorileri genisletildi (38 yeni kategori, tr/en/ar). Mevcut kategorilere ve yonetici duzenlemelerine DOKUNMAZ:
-- anahtar zaten varsa (yonetici ayni anahtari acmis olabilir) satir atlanir; yeni satirlar mevcut en buyuk sirayi izler.
-- Simge degerleri mobil `ClubCategory.iconFor` eslemesiyle birebir (bilinmeyen simge varsayilan etikete duser).
INSERT INTO community_category (category_key, name_tr, name_en, name_ar, icon, sort_order, active)
SELECT v.k, v.tr, v.en, v.ar, v.ic,
       (SELECT COALESCE(MAX(sort_order), 0) FROM community_category) + v.o * 10, TRUE
FROM (VALUES
    (1,  'muzik',              'Müzik',                      'Music',                        'موسيقى',                    'music'),
    (2,  'tiyatro',            'Tiyatro',                    'Theatre',                      'مسرح',                      'theatre'),
    (3,  'sinema',             'Sinema',                     'Cinema',                       'سينما',                     'cinema'),
    (4,  'fotograf',           'Fotoğrafçılık',              'Photography',                  'تصوير',                     'photo'),
    (5,  'dans',               'Dans',                       'Dance',                        'رقص',                       'music'),
    (6,  'edebiyat',           'Edebiyat ve Yazarlık',       'Literature & Writing',         'أدب وكتابة',                'literature'),
    (7,  'kitap',              'Kitap Okuma',                'Book Club',                    'نادي الكتاب',               'library'),
    (8,  'tarih',              'Tarih',                      'History',                      'تاريخ',                     'history'),
    (9,  'felsefe',            'Felsefe',                    'Philosophy',                   'فلسفة',                     'bulb'),
    (10, 'yabanci-dil',        'Yabancı Dil',                'Languages',                    'اللغات',                    'language'),
    (11, 'munazara',           'Münazara ve Hitabet',        'Debate & Public Speaking',     'مناظرة وخطابة',             'debate'),
    (12, 'medya',              'Medya ve Gazetecilik',       'Media & Journalism',           'إعلام وصحافة',              'media'),
    (13, 'yazilim',            'Yazılım',                    'Software',                     'برمجة',                     'software'),
    (14, 'robotik',            'Robotik',                    'Robotics',                     'روبوتات',                   'robotics'),
    (15, 'yapay-zeka',         'Yapay Zekâ ve Veri',         'AI & Data',                    'ذكاء اصطناعي وبيانات',      'ai'),
    (16, 'oyun',               'Oyun ve E-Spor',             'Gaming & Esports',             'ألعاب ورياضة إلكترونية',    'gaming'),
    (17, 'muhendislik',        'Mühendislik',                'Engineering',                  'هندسة',                     'engineering'),
    (18, 'saglik',             'Sağlık',                     'Health',                       'صحة',                       'health'),
    (19, 'psikoloji',          'Psikoloji',                  'Psychology',                   'علم النفس',                 'bulb'),
    (20, 'doga-cevre',         'Doğa ve Çevre',              'Nature & Environment',         'طبيعة وبيئة',               'nature'),
    (21, 'doga-yuruyusu',      'Doğa Yürüyüşü ve Kamp',      'Hiking & Camping',             'رحلات ومخيمات',             'hiking'),
    (22, 'futbol',             'Futbol',                     'Football',                     'كرة القدم',                 'football'),
    (23, 'voleybol-basketbol', 'Voleybol ve Basketbol',      'Volleyball & Basketball',      'كرة الطائرة والسلة',        'volleyball'),
    (24, 'fitness',            'Fitness ve Dövüş Sporları',  'Fitness & Martial Arts',       'لياقة وفنون قتالية',        'fitness'),
    (25, 'satranc',            'Satranç ve Zekâ Oyunları',   'Chess & Mind Games',           'شطرنج وألعاب ذكاء',         'bulb'),
    (26, 'gonulluluk',         'Gönüllülük',                 'Volunteering',                 'تطوع',                      'volunteer'),
    (27, 'hayvan-haklari',     'Hayvan Hakları',             'Animal Welfare',               'رفاه الحيوان',              'health'),
    (28, 'gezi',               'Gezi ve Keşif',              'Travel & Exploration',         'سفر واستكشاف',              'travel'),
    (29, 'gastronomi',         'Yemek ve Gastronomi',        'Food & Gastronomy',            'طعام وفنون الطهي',          'food'),
    (30, 'el-sanatlari',       'El Sanatları ve Tasarım',    'Crafts & Design',              'حرف وتصميم',                'craft'),
    (31, 'mimari',             'Mimari ve Şehircilik',       'Architecture & Urbanism',      'عمارة وعمران',              'architecture'),
    (32, 'hukuk-siyaset',      'Hukuk ve Siyaset',           'Law & Politics',               'قانون وسياسة',              'politics'),
    (33, 'ekonomi',            'Ekonomi ve Finans',          'Economics & Finance',          'اقتصاد ومالية',             'finance'),
    (34, 'kariyer',            'Kariyer ve Mentorluk',       'Career & Mentoring',           'مهن وإرشاد',                'career'),
    (35, 'uluslararasi',       'Uluslararası Öğrenciler',    'International Students',       'طلاب دوليون',               'language'),
    (36, 'astronomi',          'Astronomi ve Uzay',          'Astronomy & Space',            'فلك وفضاء',                 'space'),
    (37, 'matematik',          'Matematik',                  'Mathematics',                  'رياضيات',                   'science'),
    (38, 'mizah',              'Mizah ve Eğlence',           'Humor & Entertainment',        'ترفيه وفكاهة',              'fun')
) AS v(o, k, tr, en, ar, ic)
ON CONFLICT (category_key) DO NOTHING;
