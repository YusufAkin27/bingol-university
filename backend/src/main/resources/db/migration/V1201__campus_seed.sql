-- Kampus haritasi tohumu: ADLAR, KONUMLAR ve WEB ADRESLERI universitenin kendi haritasindan (harita.bingol.edu.tr,
-- 2026-11-02, tek seferlik okuma; 44 birim). Kampus siniri poligonu OpenStreetMap'ten (way/370957632,
-- amenity=university; ODbL, (c) OpenStreetMap contributors); 39 ana yerleske biriminin tamami bu poligonun icindedir.
-- Idempotent: yerler source_ref ile ON CONFLICT DO NOTHING, ayar yalniz sinir bos kaldiysa yazilir (yoneticinin sonraki
-- duzenlemeleri ezilmez). remote = ana yerleske disindaki birimler (harita sinirlari ana yerleskeyi kapsar).
-- Sitedeki Google Maps anahtari ve baska sirlar kullanilmadi/yazilmadi.

UPDATE campus_config
   SET boundary_json = '[[38.901199,40.473759],[38.901329,40.473701],[38.901469,40.473756],[38.901993,40.474177],[38.902292,40.474598],[38.903592,40.477917],[38.900704,40.479899],[38.901045,40.480944],[38.902036,40.480902],[38.902958,40.481001],[38.904454,40.481121],[38.905025,40.481214],[38.905155,40.481482],[38.905921,40.481518],[38.905974,40.481658],[38.905531,40.483675],[38.905494,40.483703],[38.905136,40.483579],[38.904744,40.483379],[38.904145,40.483151],[38.904067,40.483113],[38.903909,40.483075],[38.903201,40.482946],[38.901943,40.482834],[38.901097,40.482753],[38.9012,40.483064],[38.901281,40.487517],[38.901378,40.488867],[38.901883,40.489546],[38.899927,40.491543],[38.898757,40.491185],[38.898739,40.491507],[38.898708,40.494091],[38.898759,40.495637],[38.898788,40.496656],[38.898023,40.496684],[38.896317,40.496808],[38.896268,40.495545],[38.896004,40.491136],[38.895812,40.488178],[38.896164,40.487781],[38.895807,40.487366],[38.895854,40.487115],[38.896033,40.486831],[38.89655,40.486341],[38.896752,40.485979],[38.896836,40.485363],[38.896686,40.484853],[38.896184,40.484585],[38.896049,40.483839],[38.896449,40.48232],[38.897552,40.480022],[38.898938,40.477562]]',
       center_lat = 38.900891, center_lng = 40.485254,
       bound_south = 38.894282, bound_west = 40.47139, bound_north = 38.907499, bound_east = 40.499119,
       data_version = data_version + 1, updated_at = now()
 WHERE id = 1 AND boundary_json = '[]';

INSERT INTO campus_place (name, name_key, category, lat, lng, web_url, remote, sort_key, source_ref)
VALUES
    ('Diş Hekimliği Fakültesi', 'dis hekimligi fakultesi', 'faculty', 38.904314, 40.482522, 'https://dis.bingol.edu.tr', FALSE, 10, 'harita:14'),
    ('Fen Edebiyat Fakültesi', 'fen edebiyat fakultesi', 'faculty', 38.89797, 40.486896, 'https://fef.bingol.edu.tr', FALSE, 20, 'harita:15'),
    ('Fizik Tedavi Ve Rehabilitasyon Fakültesi', 'fizik tedavi ve rehabilitasyon fakultesi', 'faculty', 38.900028, 40.481121, 'https://ftr.bingol.edu.tr', FALSE, 30, 'harita:16'),
    ('İktisadi Ve İdari Bilimler Fakültesi', 'iktisadi ve idari bilimler fakultesi', 'faculty', 38.900178, 40.485215, 'https://iibf.bingol.edu.tr', FALSE, 40, 'harita:17'),
    ('İlahiyat Fakültesi', 'ilahiyat fakultesi', 'faculty', 38.899742, 40.481213, 'https://ilahiyat.bingol.edu.tr', FALSE, 50, 'harita:18'),
    ('Mühendislik Fakültesi', 'muhendislik fakultesi', 'faculty', 38.899348, 40.484807, 'https://mmf.bingol.edu.tr', FALSE, 60, 'harita:19'),
    ('Sağlık Bilimleri Fakültesi', 'saglik bilimleri fakultesi', 'faculty', 38.897633, 40.486617, 'https://sbf.bingol.edu.tr', FALSE, 70, 'harita:20'),
    ('Spor Bilimleri Fakültesi', 'spor bilimleri fakultesi', 'faculty', 38.899411, 40.491226, 'https://sporbilimleri.bingol.edu.tr', FALSE, 80, 'harita:21'),
    ('Veteriner Fakültesi', 'veteriner fakultesi', 'faculty', 38.899832, 40.488266, 'https://veteriner.bingol.edu.tr', FALSE, 90, 'harita:22'),
    ('Ziraat Fakültesi', 'ziraat fakultesi', 'faculty', 38.899808, 40.487771, 'https://ziraat.bingol.edu.tr', FALSE, 100, 'harita:23'),
    ('Fen Bilimleri Enstitüsü', 'fen bilimleri enstitusu', 'institute', 38.896523, 40.490457, 'https://fbe.bingol.edu.tr', FALSE, 110, 'harita:24'),
    ('Kur''an-ı Kerim Araştırmaları ve Kıraat İlmi Enstitüsü', 'kur''an-i kerim arastirmalari ve kiraat ilmi enstitusu', 'institute', 38.896362, 40.490486, 'https://kie.bingol.edu.tr', FALSE, 120, 'harita:25'),
    ('Sağlık Bilimleri Enstitüsü', 'saglik bilimleri enstitusu', 'institute', 38.896527, 40.490797, 'https://sabe.bingol.edu.tr', FALSE, 130, 'harita:26'),
    ('Sosyal Bilimler Enstitüsü', 'sosyal bilimler enstitusu', 'institute', 38.896373, 40.490834, 'https://sbe.bingol.edu.tr', FALSE, 140, 'harita:27'),
    ('Yaşayan Diller Enstitüsü', 'yasayan diller enstitusu', 'institute', 38.896461, 40.490632, 'https://yde.bingol.edu.tr', FALSE, 150, 'harita:28'),
    ('Yabancı Diller Yüksekokulu', 'yabanci diller yuksekokulu', 'school', 38.897272, 40.486912, 'https://ydyo.bingol.edu.tr', FALSE, 160, 'harita:29'),
    ('Bilişim Teknolojileri Meslek Yüksekokulu', 'bilisim teknolojileri meslek yuksekokulu', 'vocational', 38.905132, 40.482529, 'https://btmyo.bingol.edu.tr', FALSE, 170, 'harita:30'),
    ('Genç Meslek Yüksekokulu', 'genc meslek yuksekokulu', 'vocational', 38.749475, 40.536118, 'https://gencmyo.bingol.edu.tr', TRUE, 180, 'harita:31'),
    ('Gıda, Tarım Ve Hayvancılık Meslek Yüksekokulu', 'gida, tarim ve hayvancilik meslek yuksekokulu', 'vocational', 38.899784, 40.487287, 'https://gthmyo.bingol.edu.tr', FALSE, 190, 'harita:32'),
    ('Sağlık Hizmetleri Meslek Yüksekokulu', 'saglik hizmetleri meslek yuksekokulu', 'vocational', 38.904696, 40.482492, 'https://shmyo.bingol.edu.tr', FALSE, 200, 'harita:33'),
    ('Solhan Sağlık Hizmetleri Meslek Yüksekokulu', 'solhan saglik hizmetleri meslek yuksekokulu', 'vocational', 38.958767, 41.040582, 'https://sshmyo.bingol.edu.tr', TRUE, 210, 'harita:34'),
    ('Sosyal Bilimler Meslek Yüksekokulu', 'sosyal bilimler meslek yuksekokulu', 'vocational', 38.905467, 40.482654, 'https://sbmyo.bingol.edu.tr', FALSE, 220, 'harita:35'),
    ('Teknik Bilimler Meslek Yüksekokulu', 'teknik bilimler meslek yuksekokulu', 'vocational', 38.904957, 40.482197, 'https://tbmyo.bingol.edu.tr', FALSE, 230, 'harita:36'),
    ('Merkezi Kafeterya', 'merkezi kafeterya', 'dining', 38.897974, 40.488778, 'https://sks.bingol.edu.tr/birimler/beslenme-hizmetleri', FALSE, 240, 'harita:4'),
    ('Kütüphane', 'kutuphane', 'library', 38.898377, 40.485695, 'https://kutuphane.bingol.edu.tr', FALSE, 250, 'harita:2'),
    ('Halı Saha', 'hali saha', 'sports', 38.900519, 40.490527, NULL, FALSE, 260, 'harita:43'),
    ('Spor Salonu', 'spor salonu', 'sports', 38.900811, 40.48649, NULL, FALSE, 270, 'harita:6'),
    ('Aile Sağlığı Merkezi', 'aile sagligi merkezi', 'health', 38.896493, 40.489117, 'https://www.bingol.edu.tr/tr/kampuste-yasam/saglik', FALSE, 280, 'harita:42'),
    ('Diş Hekimliği Fakültesi Hastanesi', 'dis hekimligi fakultesi hastanesi', 'health', 38.902421, 40.476273, 'https://dis.bingol.edu.tr', FALSE, 290, 'harita:40'),
    ('Hayvan Hastanesi', 'hayvan hastanesi', 'health', 38.919696, 40.469437, 'https://hayvanhastanesi.bingol.edu.tr', TRUE, 300, 'harita:12'),
    ('İdari Birimler', 'idari birimler', 'admin', 38.896532, 40.489576, 'https://www.bingol.edu.tr', FALSE, 310, 'harita:44'),
    ('Merkezi Laboratuvar', 'merkezi laboratuvar', 'admin', 38.900718, 40.488468, 'https://bumlab.bingol.edu.tr', FALSE, 320, 'harita:5'),
    ('Rektörlük', 'rektorluk', 'admin', 38.896413, 40.489337, 'https://www.bingol.edu.tr/tr/universitemiz/yonetim/rektor', FALSE, 330, 'harita:1'),
    ('Arı Ürünleri Tanıtım Ofisi', 'ari urunleri tanitim ofisi', 'service', 38.896669, 40.482927, 'https://ariurunleritanitimofisi.bingol.edu.tr', FALSE, 340, 'harita:39'),
    ('Ilıcalar Termal Tesis', 'ilicalar termal tesis', 'service', 38.987914, 40.672833, 'https://ilicalar.bingol.edu.tr', TRUE, 350, 'harita:11'),
    ('Modern Arıcılık Kompleksi', 'modern aricilik kompleksi', 'service', 38.919692, 40.471551, 'https://pikom.bingol.edu.tr', TRUE, 360, 'harita:13'),
    ('PİKOM (Pilot Üniversite Koordinasyon Merkez Birimi)', 'pikom (pilot universite koordinasyon merkez birimi)', 'service', 38.896212, 40.488222, 'https://pikom.bingol.edu.tr', FALSE, 370, 'harita:38'),
    ('Teknoloji Transfer Ofisi', 'teknoloji transfer ofisi', 'service', 38.900359, 40.47594, 'https://tto.bingol.edu.tr', FALSE, 380, 'harita:41'),
    ('Erkek Öğrenci Yurdu', 'erkek ogrenci yurdu', 'dorm', 38.896754, 40.495514, NULL, FALSE, 390, 'harita:7'),
    ('Kız Öğrenci Yurdu', 'kiz ogrenci yurdu', 'dorm', 38.900776, 40.484003, NULL, FALSE, 400, 'harita:8'),
    ('Konuk Evi', 'konuk evi', 'dorm', 38.897174, 40.494025, 'https://sks.bingol.edu.tr/sosyal-tesisler/konukevi', FALSE, 410, 'harita:10'),
    ('Cami', 'cami', 'social', 38.900818, 40.485714, NULL, FALSE, 420, 'harita:9'),
    ('Kongre Merkezi', 'kongre merkezi', 'social', 38.897775, 40.490205, NULL, FALSE, 430, 'harita:3'),
    ('Yaşam Merkezi', 'yasam merkezi', 'social', 38.898621, 40.488352, NULL, FALSE, 440, 'harita:37')
ON CONFLICT (source_ref) DO NOTHING;

UPDATE campus_config SET data_version = data_version + 1, updated_at = now() WHERE id = 1;
