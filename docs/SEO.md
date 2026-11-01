# SEO stratejisi: anahtar kelime, içerik, sayfa dışı kurulum

Site: <https://bukampus.com.tr> (BÜ Kampüs, Bingöl Üniversitesi öğrencileri için **bağımsız, resmî olmayan** uygulamanın tanıtım sitesi). Hazırlanma: 2026-11-01. Kod/metin tarafındaki teknik SEO işleri (meta, JSON-LD, sitemap) ayrı ajanlardadır; bu belge strateji + kullanıcı kontrol listesidir.

> Yöntem sınırı: arama aracı yalnız ABD sonuçları ve hacim verisi vermedi; "rekabet" ve "şans" sütunları sitelerin yapısına (resmî alt siteler, mağaza uygulamaları) ve alan bilgisine dayanan **tahmindir**. 30. günde Search Console sorgu verisiyle bu belgedeki tabloları güncelleyin; kelime hacmi için Google Keyword Planner / Trends kullanın.

## 1. Özet

**Durum (canlıda doğrulandı, 2026-11-01).**
- Var: `robots.txt` (admin/api/files kapalı, Sitemap satırı), `sitemap.xml` (81 URL, her sayfada tr/en/ar + `x-default` hreflang), derleme zamanı prerender (başlık, açıklama, canonical, hreflang, BreadcrumbList, noscript özeti), `site.webmanifest`, soft-404 çözümü, tr/en/ar önekli URL'ler (`/tr/menu`).
- Eksik/yanlış: (a) `/.well-known/assetlinks.json` ve `apple-app-site-association` istekleri **200 + SPA HTML** dönüyor (gerçek dosya yok; yanlış içerik tipi, doğrulama başarısız olur). (b) `apple-itunes-app` meta yok; Android `intent-filter` (App Links) ve iOS Associated Domains yok. (c) Mağaza bağlantıları "Yakında". (d) Haber ve yemek içeriği **istemci tarafında** yüklenir; prerender yalnız kabuk + genel açıklama yazar, JS çalıştırmayan tarayıcılar (Bing, Yandex, sosyal önizleme, çoğu yapay zekâ tarayıcısı) boş görür. (e) Haber detay sayfaları sitemap'te yok. (f) `sameAs` yönetici ayarındaki sosyal bağlantılardan dolar; hesaplar açılana dek boştur.
- **Marka riski (kodda düzeltilmeli):** `web/src/pages/site/components/jsonLd.ts` içinde `MobileApplication.publisher` = "Bingöl Üniversitesi" ve kuruluş türü `EducationalOrganization`. Bu, arama motoruna uygulamanın üniversite tarafından yayımlandığını söyler. `Organization` + yayıncı = gerçek geliştirici/uygulama adı olmalı (bkz. bölüm 7).
- Sitenin çerez politikası "izleme/analiz yok" diyor; **Google Analytics eklenirse politika ve banner değişmek zorunda** (bölüm 8, madde 17).

**En değerli beş hamle (sırayla).**
1. Search Console + Bing kurulumu ve sitemap (1-2 saat, kullanıcı).
2. Yemek listesi sayfasını arama için güçlendir: başlıkta "Bingöl Üniversitesi", bugün/hafta/ay, kalori toplamı, "son güncelleme", gecelik yeniden prerender (rakip: resmî SKS sayfası yalnız güncel ayı gösteriyor, kalori çoğu günde yok).
3. Akademik takvim 2026-2027 sayfası (HTML tablo + .ics) **Ocak 2027 öncesi**; resmî kaynak yalnız PDF bağlantı listesi.
4. Mağaza sayfaları (ASO) ve mağaza bağlantılarının siteye bağlanması; ASO ile web aynı kelime dilini kullanır.
5. Etik geri bağlantılar: SKS/Öğrenci İşleri/öğrenci topluluklarının "öğrenci geliştirmesi bağımsız uygulama" bağlantısı (önce yazılı bilgi/izin, bölüm 7).

**Hedeflemeyin:** taban puan/tercih/sıralama (çok güçlü yayıncılar, niyet aday öğrenci), "OBS/UBYS giriş" (navigasyonel, resmî sitenin; oltalama karışıklığı riski).

## 2. Hedef kelimeler tablosu

Şans = bizim ilk sayfada görünme olasılığımız (kısa-orta vadede). "Resmî" = `bingol.edu.tr` ve alt siteleri (alan otoritesi çok yüksek).

| # | Grup | Örnek sorgular | Niyet | Rekabet (tahmin) | Şans | Neden |
|---|---|---|---|---|---|---|
| 1 | Yemek listesi | bingöl üniversitesi yemek listesi / yemekhane menüsü / bugün yemekte ne var / yemek listesi kalori | Bilgi (günlük, tekrar eden) | `sks.bingol.edu.tr/yemek-listesi` (yalnız güncel ay; kalori yalnız bazı günlerde), `bingol.edu.tr`, genel menü uygulamaları (ÜniMenüm, Kampüs Yemek, YeYe, Kampüs Lezzet: mağaza odaklı) | **Orta-yüksek** (uzun kuyruk: bugün, hafta, kalori, geçmiş ay) | Tazelik + kalori + arşiv + mobil okunaklılık bizde var; "yemek listesi" tek başına resmî siteyi geçmek zor |
| 2 | Duyuru/haber | bingöl üniversitesi duyuruları / haberleri / son dakika | Bilgi | Resmî ana site + 23 alt site, yerel haber siteleri | Düşük (genel), orta (tekil duyuru başlığı uzun kuyruğu) | Kaynak resmî; bizdeki metin özet + kopya riski taşır (bölüm 4, P5) |
| 3 | Akademik takvim | bingöl üniversitesi akademik takvim 2026-2027 / güz dönemi başlangıç / final tarihleri | Bilgi (mevsimsel: Ağu-Eyl, Oca, May) | `oidb.bingol.edu.tr/akademik-takvim` (PDF bağlantı listesi, 2013-14..2026-27), üniversite sıralama siteleri | **Orta** | Resmî sonuç PDF; okunur HTML tablo + .ics ile fark yaratılır |
| 4 | Sınav takvimi/programı | vize/final/bütünleme tarihleri, sınav programı | Bilgi | Fakülte/bölüm alt siteleri (duyuru PDF'leri) | Düşük-orta | Birim bazlı resmî duyuru; ortak takvimle birleştirip bağlantı verilebilir |
| 5 | Marka | bü kampüs, bu kampüs uygulaması, bukampus | Marka | "BÜ" kısaltması başka üniversiteleri (Bilecik, Bartın, Bursa vb.) çağrıştırır; "kampüs" genel | **Yüksek** (kendi adımız) ama başlangıç hacmi ~0 | Mağaza sayfası + site + `sameAs` + tutarlı ad ile ilk sıra alınır; marka bilinirliği olmadan hacim oluşmaz |
| 6 | Öğrenci uygulaması | bingöl üniversitesi öğrenci uygulaması / mobil uygulama / app | İşlem/keşif | Düşük (arama sonuçlarında resmî mobil uygulama doğrulanamadı) | **Yüksek** | Rekabet az; hacim küçük; ASO ile birlikte çalışır |
| 7 | Ders programı | bingöl üniversitesi ders programı | İşlem/bilgi | Bölüm alt siteleri, OBS | Düşük | Kişiye özel/resmî; sayfa kurmayın, SSS'te anlatın |
| 8 | Kulüpler/etkinlik | bingöl üniversitesi öğrenci kulüpleri / topluluklar / etkinlikler | Bilgi | SKS kulüp listesi, kulüp sosyal medya | Orta | Kulüp rehberi (izinli) + etkinlik takvimi özgün olabilir |
| 9 | OBS/UBYS/öğrenci işleri | obs giriş, ubys, öğrenci işleri | Navigasyonel | Resmî site | **Hedeflemeyin** | Niyet resmî siteye gidiş; yanıltma/oltalama karışıklığı riski |
| 10 | Fakülte/bölüm | [fakülte] duyuruları, [bölüm] ders programı | Bilgi/navigasyonel | Alt siteler (`<kod>.bingol.edu.tr`) | Düşük | Alt site otoritesi; hub sayfası yalnız iç bağlantı ve rehber değeri |
| 11 | Yeni öğrenci | bingöl üniversitesi kayıt / ders kaydı / yurt / barınma / ulaşım | Bilgi (mevsimsel Ağu-Eyl, Şub) | Resmî duyurular, rehber siteler | Orta | Yerel, güncel, öğrenci bakışlı rehber; editoryal emek ister |
| 12 | Aday öğrenci | taban puan, sıralama, tercih | Aday | Çok güçlü yayıncılar | **Hedeflemeyin** | Uygulamanın hedef kitlesi dışında |
| 13 | Uluslararası (EN/AR) | Bingöl University international students / cafeteria menu; جامعة بينغول (ayrıca بنغول) | Bilgi | Resmî `/en` ve `erasmus.bingol.edu.tr`, danışmanlık siteleri | Orta (hacim çok düşük) | Üniversite ~1.200 uluslararası öğrenci/48 ülke diyor (tarihsiz); Arapça içerik az |

Rakip uygulama gözlemi: Kampüs Yemek, ÜniMenüm, YeYe, Kampüs Lezzet gibi uygulamalar **mağaza sayfaları üzerinden** keşfedilir, çok üniversiteli menü sunar ("20+/100+ üniversite"); tek üniversiteye odaklı, kalori ve topluluk içeren bir uygulama kendini "Bingöl'e özgü" konumlayarak ayrışır. Bu uygulamaların web SEO sayfa yapısı doğrulanamadı; tipik beklenen sayfa türleri: üniversite başına günlük/haftalık menü, kalori, yemekhane saatleri/ücret.

## 3. Sayfa/kelime eşleme haritası

Başlıklar 60 karakter altı hedeflenir (aşağıdakiler ölçüldü). Başlık/H1 değişiklikleri kod ajanlarının işidir; **"Bingöl Üniversitesi" geçen her başlık için açıklamada "resmî olmayan, bağımsız" ibaresi ve hukuk kontrolü** (bölüm 7).

| Rota (tr) | Birincil kelime | İkincil | Önerilen title | Not |
|---|---|---|---|---|
| `/tr` | bü kampüs, bingöl üniversitesi öğrenci uygulaması | kampüs uygulaması | `BÜ Kampüs · Bingöl Üniversitesi Öğrenci Uygulaması` (50) | Açıklamada "bağımsız, resmî değil"; Organization JSON-LD düzelt |
| `/tr/menu` | bingöl üniversitesi yemek listesi | yemekhane menüsü, bugün, kalori, aylık | `Bingöl Üniversitesi Yemek Listesi · Bugün ve Bu Ay` (50) | H1 aynı kelime; üstte "Bugün" bloğu + "Son güncelleme" |
| `/tr/news` | bingöl üniversitesi duyuruları / haberleri | etkinlikler | `Bingöl Üniversitesi Haber ve Duyurular · BÜ Kampüs` (50) | Kaynak bağlantısı belirgin (bölüm 4, P5) |
| `/tr/features` | bü kampüs özellikleri | yemek listesi, kulüp, qr yoklama | `BÜ Kampüs Özellikleri: Yemek Listesi, Duyuru, Kulüp, QR` (55) | |
| `/tr/download` | bü kampüs indir | android, ios | `BÜ Kampüs İndir · Android ve iOS` | Mağaza bağlantıları yayında olunca JSON-LD `installUrl` |
| `/tr/faq` | bü kampüs sss | resmî mi, kayıt, yemek listesi | `Sık Sorulan Sorular · BÜ Kampüs` | Soru kalıpları: bölüm 4, P4 |
| `/tr/about` | bağımsız öğrenci uygulaması | kim geliştirdi | mevcut | "Biz kimiz" bölümü marka güvenini taşır; gerçek geliştirici adı/iletişim |
| `/tr/help`, `/tr/contact` | bü kampüs destek | | mevcut | Destek e-postası görünür kalsın |
| Yasal, çerez, güvenlik, çocuk güvenliği, hesap silme | (hedef yok) | | mevcut | Mağaza politikaları için gerekli; indekslenebilir kalsın, sitemap önceliği düşük |
| `/tr/support/track` | - | | noindex (mevcut) | |

Not: URL yolları İngilizce (`/menu`). Türkçe slug (`/tr/yemek-listesi`) küçük bir sinyaldir; `routeMeta` tek-yol yapısını bozacağı için **değer/efor düşük**, yapmayın. Başlık, H1 ve içerik kelimeleri belirleyicidir.

## 4. Yeni içerik önerileri (öncelik sırasıyla)

Değer = arama + kullanıcı kazanımı; Efor = geliştirme + editoryal.

### P1. Yemek listesi sayfasını arama için derinleştir (`/tr/menu`)
- **Başlık / H1:** `Bingöl Üniversitesi Yemek Listesi · Bugün ve Bu Ay` / `Bingöl Üniversitesi Yemek Listesi`.
- **Açıklama (≤155):** "Bingöl Üniversitesi yemekhanesinin bugünkü, haftalık ve aylık yemek listesi; yemek bazında kalori. Bağımsız BÜ Kampüs uygulaması, resmî kaynak SKS'dir."
- **Anahat:** (1) "Bugün" kartı (tarih, 4 yemek, toplam kcal, "kalori tamam/eksik") (2) Bu hafta tablosu (3) Aylık tablo (4) Önceki aylar bağlantıları (5) Kalori nasıl hesaplanıyor + "değerler yönetici tarafından girilir, tahminidir" (6) Yemekhane saatleri/ücret/kart: **kaynaktan doğrulayıp** yazın (SKS sayfası, `/birimler/beslenme-hizmetleri/`), (7) SSS (5 soru), (8) Uygulamaya çağrı.
- **Kelime:** yemek listesi + kalori + bugün. **Veri:** var (`GET /api/menu`, `/api/menu/today`, `dishes[{name,kcal}]`, `totalKcal`). Aylık arşiv için geçmiş ayların DB'de tutulduğunu doğrulayın; tutuluyorsa `/tr/menu?month=2026-10` yerine ayrı indekslenebilir `/tr/menu/2026-10` yolu (günlük URL üretmeyin: ince içerik).
- **Değer:** yüksek. **Efor:** orta (prerender tazeliği dahil, bölüm 5).

### P2. Akademik takvim 2026-2027 (`/tr/academic-calendar`)
- **Başlık / H1:** `Bingöl Üniversitesi Akademik Takvim 2026-2027` / aynı.
- **Açıklama:** "2026-2027 güz ve bahar dönemi başlangıç, vize, final, bütünleme ve tatil tarihleri tabloda; takviminize ekleyin (.ics). Resmî kaynak: Öğrenci İşleri."
- **Anahat:** özet kutusu (dönem başı/sonu) → Güz tablosu → Bahar tablosu → Yaz okulu → ".ics indir / uygulamada ekle" → "Resmî takvim PDF'i: [bağlantı]" (`bingol.edu.tr/media/57058/2026-2027-egitim-ogretim-yili-akademik-takvimi.pdf`) → önceki yıllar (resmî PDF bağlantıları) → uyarı: "Çelişkide resmî takvim esastır; son kontrol tarihi".
- **Veri:** `academic_event` tablosu (yönetici girişi) ve resmî PDF; **tarihleri PDF'den insan girer ve ikinci kişi doğrular** (yanlış tarih en pahalı hata). PDF içeriğini bu belge hazırlanırken okuyamadık; tarihler elle alınmalı.
- **Değer:** yüksek (mevsimsel). **Efor:** orta. **Tarih hedefi:** 31 Aralık 2026 (Ocak final/yarıyıl tatili, Şubat bahar kayıt).

### P3. Yeni öğrenci rehberi (`/tr/guide/new-students`)
- **Başlık / H1:** `Bingöl Üniversitesi Yeni Öğrenci Rehberi: Kayıt, Yurt, Ulaşım` / `Yeni öğrenci rehberi`.
- **Anahat:** kesin kayıt ve ders kaydı (resmî duyuruya bağlantı; örnek: 2026-2027 güz kayıt yenileme ve ders kaydı duyurusu 8 Eylül 2026), öğrenci kimlik/OBS e-posta (bingol.edu.tr hesabı → uygulamaya kayıt), yemekhane, kulüpler, uygulama kurulumu, önemli resmî bağlantılar, kampüste ilk hafta. Yurt/ulaşım bölümünü **yalnız doğrulanan** bilgiyle yazın (KYK, belediye) ve kaynağa bağlayın.
- **Veri:** editoryal (bizde yok). **Değer:** orta-yüksek (Ağu-Eyl, Şubat). **Efor:** orta-yüksek. **Hedef:** Haziran 2027 (yayın), Temmuz'da güncelle.

### P4. SSS genişletme
Mevcut 13 yeni soru üzerine ~15 soru ekleyin (soru kalıbı = arama kalıbı):
- "BÜ Kampüs resmî Bingöl Üniversitesi uygulaması mı?" (hayır, bağımsız)
- "Bingöl Üniversitesi yemek listesi nerede, ne zaman güncellenir?" / "Yemek kalorileri doğru mu?"
- "Uygulamaya kimler kayıt olabilir, bingol.edu.tr olmadan olur mu?" / "Doğrulama kodu gelmiyor"
- "OBS şifremi unuttum, uygulamadan sıfırlanır mı?" (hayır; resmî sistem, yönlendirme)
- "Akademik takvim/ders programı uygulamada var mı?" / "Duyurular nereden geliyor, gecikme olur mu?"
- "Kulüp nasıl açılır / etkinliğe nasıl katılırım / QR yoklama nasıl çalışır?"
- "Verilerim satılıyor mu / hesabımı nasıl silerim?" / "Hangi telefonlarda çalışır?" / "Ücretsiz mi?"
- **Not:** Google FAQ zengin sonucunu 2023'ten beri yalnız tanınmış devlet/sağlık sitelerine gösteriyor; `FAQPage` JSON-LD **görünür zengin sonuç getirmez**, zararı yok, yatırım yapmayın. Değer SSS metninin kendisindedir. **Değer:** orta. **Efor:** düşük.

### P5. Haber/duyuru dizin politikası (karar)
- Liste sayfası indekslenebilir; **detay sayfalarında** içerik üniversite sitesinden alınan özettir (kopya/ince içerik riski, telif).
- Öneri (başlangıç): detay sayfaları `noindex, follow`, canonical kendisine; yalnız liste + "Orijinali aç" bağlantısı. 90. günde GSC'de liste sayfasının performansına bakın; ek değer (kategori, ilgili birim, takvim bağlantısı) eklenirse seçilmiş içerikleri indeksleyin.
- Haber en/ar sayfalarının metni Türkçe kalıyorsa canonical → `/tr/...` veya noindex (bölüm 6). Görseller hotlink; CSP `img-src` bingol.edu.tr'ye izin veriyor, telif için küçük önizleme + atıf.
- **Değer:** düşük-orta, **risk:** orta. **Efor:** düşük.

### P6. Fakülteler ve bölümler rehberi (`/tr/faculties`)
- 10 fakülte, 5 enstitü, 7 MYO, YDYO (23 resmî alt site; kod: `unitnews` kaynak kataloğu). Hub: birim kartı + resmî alt site bağlantısı + "bu birimin duyurularını uygulamada takip et".
- **Veri sınırı:** kullanıcıya özel birim duyuruları `JWT` ister (`/api/news/unit`); herkese açık veri yalnız birim adları/bağlantılar (elle). **Değer:** orta-düşük (iç bağlantı/rehber). **Efor:** orta. Sıra: 90. gün.

### P7. Kulüpler rehberi (`/tr/clubs`)
Herkese açık özet (kulüp adı, kısa açıklama, kategori; üye bilgisi YOK). Kulüp yönetiminden izin; veri `community` modülü, herkese açık uç yoksa yönetici onaylı statik liste. **Değer:** orta, **efor:** orta. 90. gün.

### P8. Uluslararası öğrenci sayfası (EN; Arapça koşullu)
Koşul: GSC'de 60 günde en/ar gösterim eşiği (bölüm 6). İçerik: "Bingöl University cafeteria menu", "International students app", resmî International Student Center bağlantıları.

### P9. Resmî bağlantılar sayfası (isteğe bağlı, düşük öncelik)
OBS, e-posta, kütüphane, SKS, Öğrenci İşleri bağlantı listesi. **Yalnız bağlantı**; giriş formu/parola alanı yok; üstte "resmî değiliz, bu bağlantılar resmî sitelere gider". Oltalama sınıflandırması riski nedeniyle son sıraya bırakın.

### P10. "Bingöl'de öğrenci yaşamı"
Rekabet yüksek (gezi/tatil siteleri), editoryal yük büyük, uygulama niyetinden uzak. **Değer düşük-orta, efor yüksek: ertele** (180+ gün, yalnız veri/yerel işletme ortaklığı olursa).

## 5. Tazelik stratejisi

**Sorun.** `scripts/prerender.mjs` derleme anında yalnız kabuk + genel açıklama + noscript özeti yazar. Menü (`/api/menu`) ve haber (`/api/news`) tarayıcıda yüklenir. Statik prerender "bayat" kalır: dün/geçen ayın menüsü gömülürse yanlış bilgi, hiçbir şey gömülmezse içerik görünmez.

| Seçenek | Nasıl | Artı | Eksi |
|---|---|---|---|
| **A. Gecelik yeniden prerender (öneri)** | Haber senkronundan (00:00) sonra 00:15 ve aylık menü senkronundan sonra; küçük betik `GET /api/menu`, `/api/news` ile yalnız `menu` ve `news` rotalarının `index.html` gövdesini (bugün/hafta tablosu, ilk 20 haber başlığı) ve `dateModified`'ı yeniden yazar; tüm derleme gerekmez | Dağıtım yok, statik hız, JS'siz tarayıcı içeriği görür; en fazla 1 gün bayat | Betik/cron bakımı; istemci yine API ile günceller (hidrasyon uyumu gerekir) |
| B. nginx SSI parçası | Backend `/_fragment/menu-today` küçük HTML döndürür; nginx `ssi on` ile sayfaya gömer, 5 dk önbellek | Her zaman taze | nginx yapılandırması, hata durumunda yedek parça |
| C. Tam SSR (Node/Spring) | Bot veya tüm istekler için sunucuda render | En taze | En karmaşık; Google "dynamic rendering"i çözüm olarak önermiyor |
| D. Yalnız istemci (bugün) | Hiçbir şey | Sıfır iş | Bing/Yandex/yapay zekâ botları için boş içerik; sosyal önizleme genel |

**Öneri:** A'yı 30 gün içinde uygula; yetersiz kalırsa B. Ek kurallar:
- Görünür "Son güncelleme: GG.AA.YYYY HH:mm" ve sayfada `dateModified`; bakım modunda eski veri sunuluyorsa bunu yazın (CLAUDE.md "bakımda" mekanizması).
- Sitemap `lastmod` gerçek veri tarihi olsun (menü: son senkron; haber: son haber); yapay güncelleme yapmayın (Google güvenini düşürür).
- Güncellemeden sonra **IndexNow** (Bing/Yandex) ile URL gönderimi isteğe bağlı; Google sitemap "ping" ucunu kaldırdı, Google için yalnız sitemap + doğal tarama.
- Günlük URL üretmeyin (`/menu/2026-11-03` binlerce ince sayfa olur). Kalıcı sayfalar: `/menu` (bugün+hafta+ay) ve ayda bir arşiv `/menu/YYYY-MM`.
- Menü ay içinde sabit (ayın son günü çekilir); asıl bayatlama "bugün" bloğu ve haberlerdir.

## 6. Çok dilli notlar

- **Talep:** Üniversite resmî sayfasında yaklaşık 1.200 uluslararası öğrenci / 48 ülke (tarihsiz), Arapça konuşan oranı yayımlanmamış. Google'da "Bingöl University cafeteria menu", "جامعة بينغول" tipi sorgu hacmi büyük olasılıkla çok düşük; uluslararası öğrenciler çoğunlukla WhatsApp/Telegram grupları ve mağaza aramasıyla ulaşır. Gerçek talep GSC'den ölçülmeli.
- **Eşik kuralı:** 60. günde GSC'de en/ar sayfalarda 28 günlük ≥100 gösterim veya ≥5 tık yoksa yeni EN/AR içerik üretmeyin; yalnız arayüz ve mağaza metni.
- **hreflang:** sitemap zaten tr/en/ar + `x-default` veriyor. Sorun: haber/yasal sayfaların en/ar sürümü Türkçe metin gösteriyorsa "çeviri değil, kopya" olur. Çözüm: yerelleştirilmemiş içerikli en/ar URL'lerini sitemap hreflang kümesinden çıkarın ve canonical → tr yapın veya noindex. Search Console'un eski hreflang/uluslararası hedefleme raporu kaldırıldı (2022); doğrulama için URL Denetimi + sitemap hreflang tutarlılığı (karşılıklı bağlantı, kendine referans).
- **Arapça:** üniversite adı için iki yazım ("بينغول", "بنغول") ve Arapça rakam/RTL; Arapça title'larda iki yazımı da doğal geçirin; ana kazanç ar-SA mağaza lokalizasyonudur (ASO), web SEO ikincil. Yerel konuşur incelemesi şart (CLAUDE.md "Arapça çeviriler anadil incelemesi ister").
- **İngilizce:** önce `en` menü ve ana sayfa başlığı ("Bingöl University Cafeteria Menu · BÜ Kampüs") yeterli; uzun içerik yazmayın.

## 7. Marka/hukuk uyarıları (hukuki görüş DEĞİLDİR; avukata danışın)

1. **Ad ve logo.** Üniversitenin logosu/kurumsal kimliği hiçbir yerde (site, mağaza simgesi, ekran görüntüsü, sosyal avatar) kullanılmamalı (`docs/store/README.md` ilke 1 ile aynı). "Bingöl Üniversitesi" adı yalnız **tanımlayıcı** ("... öğrencileri için") kullanılır; yanına "bağımsız / resmî olmayan" ibaresi gelir (hero altı, footer, mağaza açıklaması, meta açıklama). "Resmî", "T.C.", "BÜ resmî uygulaması" ifadesi yok.
2. **Yapılandırılmış veri.** `publisher: Bingöl Üniversitesi` ve `EducationalOrganization` türünü kaldırın; `Organization`/`SoftwareApplication` + gerçek yayıncı (geliştirici adı veya uygulama adı). Aksi hâlde Google bilgi paneli üniversiteyle karışabilir.
3. **Mağaza kuralları.** Play "Taklit/yanıltıcı davranış" ve Apple 5.2 (fikrî mülkiyet) başlığa üniversite adı koymayı ve üniversiteyi anahtar kelime yapmayı riske sokar. Mevcut `BÜ Kampüs` başlığı doğru. Kısa açıklama önerisi (63 karakter; sonuna ". Resmî değildir" eklenirse 79): `Bingöl Üniversitesi öğrencileri için bağımsız kampüs uygulaması`. **Uygulama başlığı/kısa açıklamada üniversite adı kararı kullanıcıya aittir**; riski sıfırlamak için üniversiteden yazılı bilgi/izin alın.
4. **Haksız rekabet / marka karışıklığı** (TTK m. 54-55, Sınai Mülkiyet Kanunu): üniversitenin adını taşıyan alan adı/hesap adı (ör. `bingolunikampus`) açmayın; mevcut `bukampus.com.tr` ve "BÜ Kampüs" adı, "BÜ" kısaltması nedeniyle yine de karışabilir: marka tescil/benzerlik araştırmasını (TÜRKPATENT) lansmandan önce yaptırın.
5. **İçerik telifi ve scraping.** Haber/duyuru metni ve görselleri üniversiteye aittir (FSEK). Özet + atıf + "orijinali aç" bağlantısı; tam metin/görsel kopyalama yok. Scraping yalnız zamanlayıcıyla (CLAUDE.md bölüm 5). Menü/takvim olgusal veridir ama kaynağı belirtin.
6. **Yanlış bilgi sorumluluğu.** Akademik takvim, sınav tarihi, yemek listesi için "resmî kaynak esastır", son kontrol tarihi, hata bildirme bağlantısı.
7. **Oltalama karışıklığı.** OBS/e-posta giriş sorgularını hedeflemeyin; bağlantı sayfası yalnız bağlantı içerir, form/parola isteği asla.
8. **Sosyal hesap adları:** `bukampus` / `bu_kampus` benzeri; biyografide "bağımsız" ve site bağlantısı.
9. **Kişisel geliştirici bilgisi:** Play kişisel hesapta ad/adres herkese açık; bkz. `docs/LEGAL_NOTES.md`. "Hakkımızda"da gerçek geliştirici/iletişim, marka güveni (E-E-A-T) için de gerekli.

## 8. Kullanıcının yapması gerekenler (sıralı kontrol listesi)

Sıra bağımlılıklara göredir (DNS → Search Console → Bing → mağazalar → bağlantı → ölçüm).

**A. Önkoşullar (hazırlık)**
1. DNS yönetim paneline erişimi doğrulayın (`bukampus.com.tr`; `docs/LAUNCH_CHECKLIST.md` Aşama 1). Canlı kontrol: `curl -I https://www.bukampus.com.tr` → 301 ile `https://bukampus.com.tr`; `http://` → https. İkisi de yoksa Caddy/DNS'i düzeltin (`WWW_DOMAIN`).
2. Yedek bir Google hesabı hazırlayın (Search Console ikinci sahip); mümkünse siteye özel bir Google hesabı kullanın, kişisel hesabı değil.

**B. Search Console (Google)**
3. <https://search.google.com/search-console> → "Mülk ekle" → **Alan (Domain)** → `bukampus.com.tr` (alt alanları ve www/http'yi kapsar).
4. Verilen `google-site-verification=...` değerini DNS'e **TXT, ad `@`** olarak ekleyin; yayılmayı `nslookup -type=TXT bukampus.com.tr` ile bekleyin (48 saate kadar sürebilir) → "Doğrula". **TXT kaydını silmeyin** (doğrulama düşer).
5. Sol menü "Site haritaları" → `https://bukampus.com.tr/sitemap.xml` ekleyin (durum "Başarılı"; 81 URL beklenir).
6. "URL Denetimi" ile `/tr`, `/tr/menu`, `/tr/news` için "Dizine eklenmesini iste" (günlük kota küçük; sitemap zaten yeterli, bu hızlandırıcıdır).
7. 3-7 gün sonra "Sayfalar" raporunu açın: "Dizine eklendi / Dizine eklenmedi" kırılımı; "Alternatif sayfa (canonical)" ve "Taranmış-şu an dizine eklenmedi" satırlarını not edin (hedef: sitemap sayfalarının çoğu dizinde).
8. Kontrol edin: "Kullanıcı deneyimi → Core Web Vitals" (veri birikince), "Tarama istatistikleri", e-posta bildirimlerini açın. Eski hreflang raporu yok; kapsam için "Sayfalar" ve URL Denetimi yeterli.

**C. Bing**
9. <https://www.bing.com/webmasters> → "Search Console'dan içe aktar" (adım 4'ten sonra, saniyeler). Sitemap görünür; "IndexNow" için anahtar dosyasını istemeniz yeterli (dosyayı `web/public`'e koymak geliştirici işi).

**D. Mağaza sayfaları (ASO) ve web bağlantıları**
10. Google Play: `docs/store/PLAY_CONSOLE_STEPS.md` sırası (12 test kullanıcısı, 14 gün). Listeleme: başlık `BÜ Kampüs`; kısa açıklama bölüm 7 madde 3 (üniversite adı kararınıza göre); uzun açıklamada ilk 2 cümlede "Bingöl Üniversitesi öğrencileri için bağımsız kampüs uygulaması: yemek listesi, haber ve duyuru, kulüpler, etkinlikler, QR yoklama" geçsin (Play uzun açıklamayı dizine alır; doğal tekrar, anahtar kelime yığma yok). Ekran görüntüleri: ilk 2 ekranda yemek listesi ve duyurular (arama niyeti #1 ve #2); altyazılara kelime koyun. Web sitesi alanı `https://bukampus.com.tr`. `ar` ve `en` mağaza lokalizasyonu ekleyin (başlık aynı, açıklama yerel).
11. App Store Connect: ad `BÜ Kampüs`; alt başlık (≤30) örn. `Yemek listesi, haber, kulüp`; **anahtar kelime alanı** (≤100 karakter, virgülle, boşluksuz; örnek `kampüs,yemek listesi,yemekhane,duyuru,kulüp,etkinlik,öğrenci,sohbet,qr yoklama` 83 karakter). Üniversite adını anahtar kelimeye koymayın (Apple 5.2). Ayrıntı: `docs/IOS_RELEASE.md`, `docs/ios-store/store_tr.md`.
12. Yayın sonrası yönetici panelinden (Ayarlar → uygulama bilgisi) Play ve App Store bağlantılarını girin: sitede "Yakında" kalkar, JSON-LD `installUrl` dolar. Web'den mağazaya giden bağlantılara ölçüm parametresi ekleyin: Play `&referrer=utm_source%3Dbukampus_web%26utm_medium%3Dsite`, App Store `?pt=<sağlayıcı>&ct=web&mt=8` (çerezsiz kaynak ölçümü).
13. **Akıllı uygulama afişi:** App Store kimliği (`id...`) çıkınca `web/index.html` içine `<meta name="apple-itunes-app" content="app-id=<ID>">` (geliştirici işi; Safari'de otomatik afiş). Android'de eşdeğer meta yoktur: sitede kendi kapatılabilir "Uygulamayı aç/indir" bandı yeterli (`getInstalledRelatedApps` gerekmez).
14. **App Links / Universal Links** (derin bağlantı; arama sıralamasını doğrudan değiştirmez, paylaşılan haber/etkinlik bağlantısı uygulamada açılır). Önce hangi yolların uygulamada açılacağına karar verin (öneri: `/tr/news/*`, etkinlik). Sonra: (a) Android: Play Console → Uygulama bütünlüğü → Play App Signing **SHA-256** parmak izini alın → `https://bukampus.com.tr/.well-known/assetlinks.json` (paket `tr.com.bukampus.app`) → manifest'e `android:autoVerify="true"` `intent-filter`; (b) iOS: Apple **Team ID** + bundle `tr.com.bukampus.app` → `/.well-known/apple-app-site-association` (uzantısız, `Content-Type: application/json`, yönlendirme yok) → Associated Domains `applinks:bukampus.com.tr`. nginx şu an bu yollara SPA HTML döndürüyor; dosyalar `web/public/.well-known/` altına konunca ve `default_type application/json` ile sunulunca çalışır (geliştirici işi). Doğrulama: Google "Digital Asset Links" test aracı, Apple için `curl -I` ile içerik tipi. Lansman sonrasına bırakılabilir (öncelik düşük).

**E. Geri bağlantılar ve sosyal (etik, doğal yollar)**
15. Önce yazılı bilgilendirme/izin: Bingöl Üniversitesi Öğrenci İşleri / SKS / Bilgi İşlem'e kısa e-posta ("bağımsız öğrenci uygulaması, resmî kaynaklara atıf verir, yemek listesi/duyuru kaynağı sizsiniz; bağlantı verirseniz sevinirim"). Ardından: öğrenci konseyi, fakülte öğrenci temsilcileri, kulüp sayfaları ve sosyal medya hesapları (nofollow olsa da marka sinyali), yerel haber siteleri (Bingöl yerel basını: "öğrenci geliştirdi" haberi), Türkiye girişim/yerli uygulama dizinleri. Satın alınmış bağlantı, yorum/forum spam'i, link çiftlikleri YOK. Wikipedia hedeflenmez. Her bağlantıda marka adı "BÜ Kampüs" ve ana sayfa/menü URL'si kullanılsın.
16. **Sosyal profiller:** Instagram (en önemli: öğrenciler orada), X, YouTube (isteğe bağlı), LinkedIn (kişisel proje için isteğe bağlı). Ad `BÜ Kampüs`, kullanıcı adı `bukampus`/`bu_kampus`, biyografi "Bingöl Üniversitesi öğrencileri için bağımsız kampüs uygulaması · resmî değildir · bukampus.com.tr". Hesap açılınca yönetici panelinden sosyal bağlantıları girin (JSON-LD `sameAs` otomatik dolar). Google Business Profile **uygun değil** (fiziksel işletme/adres yok; üniversite adına profil açmayın), atlayın.
17. **Analitik ve çerez/KVKK kararı:** Şu an site "analiz/izleme çerezi yok" diyor ve backend analitiği toplulaştırılmış. **Google Analytics (GA4) eklemeyin**: eklerseniz çerez politikası + açık rıza bandı + gizlilik metni (yeni sürüm) gerekir (Kişisel Verileri Koruma Kurumu çerez rehberi: zorunlu olmayan çerez için açık rıza). Önerilen yol: (i) Search Console (sitede etiket/çerez yok), (ii) Play Console ve App Store Connect istatistikleri, (iii) mağaza bağlantılarındaki `referrer`/`ct` parametreleri, (iv) isteğe bağlı çerezsiz, IP saklamayan kendi sunucunuzdaki ölçüm (Plausible/Umami self-host; yine de gizlilik metnine eklenir). Çerez bandı bu durumda **gerekmez** (yalnız zorunlu depolama).
18. **E-posta/marka güveni:** `docs/LAUNCH_CHECKLIST.md` Aşama 1 ve `docs/MAIL_DELIVERABILITY.md` bölüm 9: `bukampus.online` için SPF + DKIM (Brevo) + DMARC `p=none` (2-4 hafta rapor) → `quarantine` → `reject`; `bukampus.com.tr` posta göndermiyorsa null SPF (`v=spf1 -all`) ve `p=reject` DMARC. Google Postmaster Tools'ta `bukampus.online` ekleyin. Amaç: doğrulama/destek e-postasının spam'e düşmemesi ve kimlik taklidine karşı koruma.

**F. Ölçüm planı (ücretsiz araçlarla)**

| Metrik | Araç | Sıklık | Hedef (90. gün) |
|---|---|---|---|
| Dizindeki sayfa / sitemap sayfası | GSC → Sayfalar | Haftalık | ≥ %80 |
| Gösterim, tık, CTR, ort. konum (sorgu grupları: `yemek`, `duyuru`, `takvim`, `bü kampüs`) | GSC → Performans, regex filtre | Haftalık | "yemek listesi" grubunda ort. konum ≤ 10 |
| Marka sorgusu (bü kampüs / bukampus) | GSC | Aylık | Artan eğilim |
| Core Web Vitals (LCP/INP/CLS) | GSC + PageSpeed | Aylık | Tüm URL'ler "İyi" |
| Geri bağlantı sayısı/alan adı | GSC → Bağlantılar | Aylık | ≥ 5 kaliteli alan adı (SKS/öğrenci/yerel) |
| Mağaza ziyaret → yükleme, kaynak=web | Play Console, App Store Connect | Haftalık | Web kaynaklı yükleme > 0 ve artan |
| İçerik doğruluğu (menü/takvim) | Elle kontrol | Aylık (Ocak, Şubat, Eylül öncesi yoğun) | Sıfır yanlış tarih |
| Yorum/puan, mağaza dönüşüm oranı | Mağaza konsolu | Aylık | ≥ 4,3 puan |

## 9. 30/60/90 günlük yol haritası

Bugün 2026-11-01. Mevsimsel tepe noktaları: Ocak (final/bütünleme, yarıyıl tatili), Şubat (bahar dönemi kayıt), Mayıs-Haziran (final, yaz), Ağustos-Eylül (tercih, kayıt).

**0-30 gün (kurulum + hızlı kazanımlar, bitiş ~1 Aralık)**
- Kullanıcı: bölüm 8 madde 1-9 (Search Console, sitemap, Bing, DNS), sosyal hesaplar ve `sameAs`, DMARC `p=none`.
- Kod/metin: menü/ana sayfa/haber başlık-açıklama (bölüm 3), JSON-LD yayıncı düzeltmesi, bölüm 5 seçenek A (gecelik yeniden prerender + "Son güncelleme"), SSS +15 soru, haber detayları `noindex` kararı, en/ar'da Türkçe içerikli sayfalar için hreflang düzeltmesi.
- Mağaza: Play listeleme metni (kapalı test), App Store alanları taslağı.
- Ölçüm: GSC taban çizgisi (ilk veri 7-10 günde gelir).

**31-60 gün (içerik, bitiş ~31 Aralık)**
- **Akademik takvim sayfası** (+.ics) Ocak öncesi; menü arşivi `/menu/YYYY-MM`.
- İlk 30 günlük GSC verisiyle bölüm 2 tablosunu güncelle; hangi sorguların gerçekten geldiğini işle.
- Üniversite birimlerine yazılı bilgi/izin e-postası; ilk 2-3 etik bağlantı (öğrenci toplulukları).
- Mağaza yayınlandıysa siteye bağlantılar, referrer parametreleri, `apple-itunes-app`.
- Bölüm 6 eşik kararı (EN/AR içerik var/yok).

**61-90 gün (genişleme, bitiş ~1 Ocak-1 Şubat)**
- Fakülteler hub'ı (P6), kulüpler rehberi (P7, izinle), isteğe bağlı bağlantılar sayfası (P9).
- Haber dizin politikası değerlendirmesi (P5): liste performansı iyiyse seçili haberlere ek değer ekleyip indeksle.
- Mağaza ASO denemeleri (ekran görüntüsü sırası, kısa açıklama varyantı); varsa App Links.
- Geri bağlantı dalgası 2 (yerel haber, girişim dizinleri); 90. gün raporu: dizin kapsamı, marka sorgusu, mağaza dönüşümü, içerik öncelik listesi.

**Sonraki dönem:** Haziran-Temmuz 2027 yeni öğrenci rehberi (P3) + akademik takvim 2027-2028'i resmî PDF çıkar çıkmaz güncelle; "yaşam" içeriği (P10) ancak veri/ortaklık varsa.

## Kaynaklar (araştırmada bakılanlar)
- Resmî yemek listesi: <https://sks.bingol.edu.tr/yemek-listesi> (Kasım 2026 aylık tablo; kalori yalnız 10, 23, 24, 25 Kasım'da bazı yemeklerde).
- Resmî akademik takvim: <https://oidb.bingol.edu.tr/akademik-takvim/> (PDF listesi; 2026-2027: `https://www.bingol.edu.tr/media/57058/2026-2027-egitim-ogretim-yili-akademik-takvimi.pdf`).
- Search Console alan doğrulama: <https://support.google.com/webmasters/answer/9008080>, alan mülkü: <https://support.google.com/webmasters/answer/10431861>.
- Play kapalı test koşulu ve hedef API: `docs/store/PLAY_CONSOLE_STEPS.md` bölüm 0 (Google Play Console Yardım bağlantılarıyla).
- Uluslararası öğrenci verisi: <https://www.bingol.edu.tr/en/news/international-student-center-opens-at-bingol-university> (sayı beyanı, tarihsiz).
