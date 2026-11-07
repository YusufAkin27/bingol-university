-- V1650 (Kampus Forum): V1600 ile eklenen baslangic konu/yorumlarini da ogrenci agzina cevirir (kullanici istegi:
-- "diger yorum ve forumlari da bu dilde duzenle"). Yalnizca idem_key 'seed-v1600-%' konularini ve onlarin yorumlarini
-- gunceller; kullanicilarin kendi yazdigi icerige DOKUNMAZ. Konu/yorum sirasi V1600 ile ayni (konu basina 3 ust duzey
-- yorum sira numarasiyla + 1 yanit). Idempotent: ayni metinleri tekrar yazar. Gunluk dil ve yazim hatalari BILEREK.

UPDATE forum_topic ft SET title = v.title, body = v.body, edited_at = NULL
  FROM (VALUES
    (1,  'hafta sonu hava nasil olcak bi bilen var mi',
         'hafta sonu bi yerlere cikmayi dusunuyom ama hava belli degil. plani olan var mi yoksa beraber bi seyler yapalim mi. gezi onerisi de olabilir'),
    (2,  'yemekhanede en sevdiginiz yemek hangisi yaw',
         'bu ay menuye baktim bazi gunler valla iyi gorunuyo. sizin icin en iyi yemek ne, hangi gunu kacirmiyosunuz'),
    (3,  'final haftasi nasil calisiyonuz bende hic duzen yok',
         'finaller yaklasiyo ama duzenli calisamiyorum bi turlu. pomodoro mu grup calismasi mi sabah erken kalkmak mi. sizde ne ise yaradiysa yazin'),
    (4,  'kampuste sessiz calisilcak yer var mi kutuphane hep dolu',
         'kutuphane bazen cok kalabalik oluyo. kampuste sessiz ve rahat ders calisilabilcek baska yer bilen var mi'),
    (5,  'yurda yeni gelenlere tavsiyeler lutfen',
         'bu donem yurda yeni yerlesenler icin aklinizda kalan tavsiyeler neler. oda duzeni camasirhane saatleri falan kucuk ama ise yarar seyler'),
    (6,  'hangi kulup etkinligine gittiniz iyi miydi',
         'yeni donemde bi kulube katilmak istiyom. gittiginiz etkinliklerden hangisi size en cok sey katti yazin da ben de bakayim'),
    (7,  'en son hangi kitabi okudunuz oneri var mi',
         'ders disinda kitap okumaya zaman bulabilenler. son okudugunuz ve baskalarina onerebilcegniz bi kitap var mi'),
    (8,  'servis saatleri icin bi onerim var',
         'aksam gec saatlerde kampusten sehir merkezine donmek cok zor oluyo. servis saatlerine ek sefer konulmasi hakkinda ne dusunuyonuz'),
    (9,  'bu aralar ne izliyonuz dizi film',
         'sinav arasinda kafa dinlemek icin izlenecek bi seyler ariyom. en son izleyip begendiginiz yapimlar neler'),
    (10, 'telefonu nasil biraktiniz bende 6 saati geciyo',
         'ekran suresi gunde 6 saati gecti. telefonu birakip daha verimli zaman gecirmek icin denediginiz ise yarar bi sey var mi'),
    (11, 'staj icin cv yazarken nelere dikkat ediyosunuz',
         'yaz stajina basvuru icin cv hazirliyom. tek sayfa mi olmali proje ve kulup deneyimleri nasil yazilir. tecrubesi olan paylasir mi'),
    (12, 'bingolde misafir gelince nereye goturuyonuz',
         'disaridan arkadaslarim ziyarete gelcek. bingolde mutlaka gosterilmesi gereken yerler ve yemek onerileri neler'),
    (13, 'spor yapmaya baslayip birakiyom nasil devam edilir',
         'baslayip birakiyom hep. duzenli spor yapabilenler nasil basardiniz. kampuste kullanilabilecek yerler icin de onerilere acigim'),
    (14, 'yapay zeka araclarini ders icin nasil kullaniyonuz',
         'konu ozeti cikarmak soru cozmek ya da fikir uretmek icin kullanan var mi. nerde ise yariyo nerde dikkat etmek lazim')
  ) AS v(ix, title, body)
 WHERE ft.idem_key = 'seed-v1600-' || v.ix;

UPDATE forum_comment fc SET body = v.body, edited_at = NULL
  FROM (
    SELECT c.id, ft.idem_key, row_number() OVER (PARTITION BY c.topic_id ORDER BY c.id) AS rn
      FROM forum_comment c
      JOIN forum_topic ft ON ft.id = c.topic_id
     WHERE ft.idem_key LIKE 'seed-v1600-%' AND c.parent_comment_id IS NULL
  ) o
  JOIN (VALUES
    (1, 1, 'ben de bunu merak ediyodum cevap verenlere simdiden sagolun'),
    (1, 2, 'hafta sonu kampus civarinda yuruyus yapmayi dusunuyom katilmak isteyen olursa yazsin'),
    (1, 3, 'havaya bakip son anda karar vermek en iyisi ama yagmurluk almayi unutmayin'),
    (2, 1, 'mercimek corbali gunler benim icin vazgecilmez yaninda pilav falan cok iyi gidiyo'),
    (2, 2, 'izgara kofte olan gunleri kacirmiyom porsiyonlar da yeterli bence'),
    (2, 3, 'tatli cikan gunler ayri bi mutluluk menuye onceden bakmak ise yariyo'),
    (3, 1, 'sabah erkenden 25 dk lik kisa bloklarla calismak bende cok ise yaradi'),
    (3, 2, 'eski sinav sorularini cozmek en verimlisi sadece konu okumak yetmiyo'),
    (3, 3, 'arkadaslarla soru cozup birbirimize anlatmak hem eglenceli hem kalici oluyo'),
    (4, 1, 'fakulte binalarinin ust kat koridorlari ogleden sonra cok sakin oluyo'),
    (4, 2, 'hava guzelken kampustaki agacli yerler kitap okumak icin super'),
    (4, 3, 'kutuphanenin grup odalari bossa tek basina da calisilir'),
    (5, 1, 'camasirhane icin hafta ici sabah saatlerini dene daha az kalabalik oluyo'),
    (5, 2, 'odaya saglam bi uzatma kablosu ve kucuk raf getirmek hayat kurtariyo'),
    (5, 3, 'oda arkadasinla bastan kurallari konusmak sonra sorun cikmasini onluyo'),
    (6, 1, 'gecen ay katildigim fotograf gezisi cok keyifliydi herkese tavsiye ederim'),
    (6, 2, 'kariyer gunleri etkinlikleri sektorden insanlarla tanismak icin iyi firsat'),
    (6, 3, 'ilk etkinlige tek basima gittim ama kisa surede yeni arkadaslar edindim'),
    (7, 1, 'sefiller okuyom uzun ama surukleyici tavsiye ederim'),
    (7, 2, 'kisa hikayeler sinav doneminde okumak icin ideal ben bu aralar onlara yoneldim'),
    (7, 3, 'atomik aliskanliklar duzen kurmak isteyenler icin guzel bi baslangic'),
    (8, 1, 'aksam gec saatte bi ek sefer gercekten cok ise yarar yetkililere iletilse iyi olur'),
    (8, 2, 'sefer saatleri uygulamada gorunse planlamasi kolay olur'),
    (8, 3, 'sinav haftalarinda kutuphane cikisina yakin bi ek saat cok yararli olur'),
    (9, 1, 'bu aralar belgesel izliyom kisa bolumler halinde olmasi da guzel'),
    (9, 2, 'eski bi komedi dizisini bastan izlemeye basladim sinav stresinden uzaklasmak icin birebir'),
    (9, 3, 'hafta sonu arkadaslarla film gecesi yapmak en iyisi'),
    (10, 1, 'bildirimleri kapatmak ve ana ekrani sadelestirmek ilk adim olarak cok ise yaradi'),
    (10, 2, 'ders calisirken telefonu baska odaya birakiyom ilk gunler zor ama aliniyo'),
    (10, 3, 'ekran suresi siniri koymak ve haftalik rapora bakmak motive edici'),
    (11, 1, 'tek sayfa net ve sade bi cv olsun projelerine baglanti ver yeter'),
    (11, 2, 'kulup ve gonulluluk deneyimlerini mutlaka yaz isverenler bunlara onem veriyo'),
    (11, 3, 'basvuru yapcagin pozisyona gore cv yi her seferinde azicik da olsa degistir'),
    (12, 1, 'genc golu cevresi ve sehrin yoresel yemekleri ilk gosterilecek yerler olmali'),
    (12, 2, 'kahvalti icin sehir merkezindeki yoresel mekanlar misafirlere hep cok guzel geliyo'),
    (12, 3, 'hava uygunsa yakin doga yuruyusu rotalari da cok sevilir'),
    (13, 1, 'haftada uc gun 20 dk ile basla sonra artir surdurulebilir olmasi onemli'),
    (13, 2, 'arkadasla sozlesip gitmek devamliligi cok artiriyo'),
    (13, 3, 'kampustaki acik alanlarda sabah yuruyusu ve kosu ile baslamak yeterli'),
    (14, 1, 'konu ozeti cikarmak icin kullaniyom ama kaynagi mutlaka kendim dogruluyom'),
    (14, 2, 'odevi onun yerine yaptirmak yerine anlamadigim yeri actirmak icin kullanmak daha dogru'),
    (14, 3, 'verdigi bilgileri hep ders notlari ve kitapla karsilastirmak lazim')
  ) AS v(ix, ord, body) ON o.idem_key = 'seed-v1600-' || v.ix AND o.rn = v.ord
 WHERE fc.id = o.id;

UPDATE forum_comment fc SET body = CASE (substring(ft.idem_key from 12))::int % 3
        WHEN 0 THEN 'sagol cok faydali oldu'
        WHEN 1 THEN 'guzel fikir deneyip yazarim'
        ELSE 'katiliyom diger onerileri de merak ediyom' END,
    edited_at = NULL
  FROM forum_topic ft
 WHERE ft.id = fc.topic_id AND ft.idem_key LIKE 'seed-v1600-%' AND fc.parent_comment_id IS NOT NULL;
