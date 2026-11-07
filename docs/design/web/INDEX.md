# Web (bukampus.com.tr) Stitch istem paketi

Kullanım: Stitch'te **Web** modunu seçin, aşağıdaki **ORTAK KURALLAR** metnini her istemin başına yapıştırın, sonra ilgili sayfa istemini ekleyin. Her sayfa için **masaüstü (1440)** ve **mobil (390)** çıktı isteyin. Çıktıları `C:\bu_design\web\<NN>-<ad>\` altına (PNG + "Export code" HTML) kaydedin. Kod uygulaması bu dosyaları birebir referans alır (bkz. `docs/WEB_DESIGN_SYSTEM.md`).

## ORTAK KURALLAR (her istemin başına)

Bingöl Üniversitesi öğrenci ve personeli için **BÜ Kampüs** adlı mobil uygulamanın tanıtım sitesi (bukampus.com.tr). Dil: Türkçe (arayüz metinleri Türkçe yazılacak; site ayrıca İngilizce ve Arapça/RTL sunar, düzen RTL'de bozulmayacak). Uygulama **resmî değildir**, bağımsız bir öğrenci uygulamasıdır; yalnızca `bingol.edu.tr` e-postalarıyla kullanılır.

Görsel kimlik: Bingöl dağları ve Murat Nehri'nden gelen **soğuk lacivert** (#171E33), **kar beyazı sıcak yüzey** (#FAF6F3, kartlar #FFFFFF), **tek kırmızı vurgu** (eylem #C62A20, logo/hero #F73A2E). Yazı tipi Inter. Köşe yarıçapı kart 20, düğme/girdi 14, çip 10 px. Gölge neredeyse yok; ayrım ince çizgi (#E8DFD8) ve yüzey tonlarıyla. Koyu temada lacivert yüzeyler.

Karakter: modern, minimal, premium, profesyonel, sade; güçlü görsel hiyerarşi; bol ama dengeli boşluk; **jenerik SaaS/yapay zekâ şablonu görünümünden kaçın** (rastgele mor-mavi gradient, cam efekti, dolgun gölge, emoji ikon yok). Ikonlar tek aile, ince çizgi. Gövde yazısı ≥ 16 px, ikincil ≥ 13 px, kontrast WCAG AA, dokunma hedefi ≥ 44 px.

Yasaklar: ödeme/fiyat, uydurma kullanıcı sayısı/yorum/ödül, ünlü kişi, resmî üniversite logosu taklidi, QR-ödeme, hikâye/yorum/video özelliği (uygulamada yok). Uygulama özellikleri: haber-duyuru-etkinlik, yemek listesi (kaloriyle), kulüpler, sohbet, etkinlik QR yoklama, ders programı ve sınavlar, anketler, Keşfet (1 fotoğraf + kısa metin + beğeni).

Ortak kabuk: üstte sabit başlık (logo, Ana sayfa / Özellikler / Haberler / Yemek listesi / Yardım / Hakkımızda, kırmızı "İndir" düğmesi, dil, tema), altta 4 sütunlu alt bilgi (Kurum, Ürün, Destek, Yasal). Kurumsal e-posta ve adres alanı yer tutucu olsun (`iletisim@bukampus.com.tr`).

## Sayfa istemleri (10 ajan = 10 grup)

**01 — Ana sayfa (`/tr`)**: Hero: büyük başlık "Kampüs hayatı tek uygulamada", alt metin, Google Play + App Store düğmeleri, "Yalnızca bingol.edu.tr hesaplarıyla kullanılır" notu, sağda büyük ve **kesilmemiş** iki telefon maketi (Ana sayfa + Keşfet). Altında 4 özelliği büyük ekran görüntüleriyle (okunur boyutta) tanıtan bölüm, "Üç adımda başlayın" (görsel güçlü, numaralı), "Verileriniz size ait" güven bölümü (4 madde, dengeli ızgara), son CTA bandı. Mevcut sorunlar: hero boş ve zayıf hiyerarşi, telefonlar küçük, özellik görselleri ~140 px, güven kartları dengesiz.

**02 — Özellikler (`/tr/features`)**: Her özellik (Haberler, Yemek, Etkinlik+QR, Kulüpler, Sohbet, Ders programı, Anketler, Keşfet) için sol-sağ dönüşümlü satır: başlık, 2 cümle, madde listesi, telefon ekranı. Üstte kısa özet ızgarası, altta CTA.

**03 — İndir (`/tr/download`)**: Mağaza düğmeleri, QR kodu yer tutucusu, sistem gereksinimi, kurulum 3 adım, "Android/iOS durumu" rozetleri, sık sorulan 3 soru.

**04 — Haberler (`/tr/news`) + haber detayı**: Filtre çipleri (Haber, Duyuru, Etkinlik), kart ızgarası (görsel/başlık/tarih/kaynak), sayfalama; detay: başlık, tarih, kaynak bağlantısı ("Kaynağı aç"), içerik, benzer haberler. Boş ve yükleniyor durumları.

**05 — Yemek listesi (`/tr/menu`)**: Ay takvim şeridi, günün menüsü kartı (yemekler, kalori, toplam), seçili gün ayrıntısı, hafta özeti, "uygulamada puanla" CTA. Menü yok / bakım durumu.

**06 — Yardım merkezi + SSS (`/tr/help`, `/tr/faq`)**: Arama kutusu, kategori kartları, akordeon soru-cevap, "Destek talebi aç" formuna yönlendirme, form (e-posta, konu, mesaj, doğrulama kodu adımı).

**07 — Hakkımızda + İletişim (`/tr/about`, `/tr/contact`)**: Misyon, "bağımsız öğrenci uygulaması" açıklaması, ilkeler (gizlilik, güvenlik, erişilebilirlik), ekip/iletişim kartı, iletişim formu, kurumsal bilgi yer tutucuları.

**08 — Marka kiti + Sürüm notları (`/tr/brand`, `/tr/changelog`)**: Logo kullanımı (açık/koyu, boşluk kuralları), renkler (kodlarıyla), yazı tipi, indirilebilir varlıklar; sürüm notları zaman çizelgesi (sürüm rozeti, tarih, madde listesi).

**09 — Hukuki ve bilgi sayfaları**: Hukuki liste (`/tr/legal`: kart listesi, sürüm/tarih), belge okuma düzeni (sol içindekiler, sağ metin, sürüm seçici), Çerez, Topluluk kuralları, Çocuk güvenliği, Erişilebilirlik, Güvenlik, Site haritası, Veri talebi formu, Hesap silme adımları. Okunabilir uzun metin tipografisi.

**10 — Ortak kabuk ve durum ekranları**: Başlık (masaüstü + mobil çekmece menü), alt bilgi, çerez banner'ı, dil/tema anahtarı, 404, sunucu hatası, bakım, yükleniyor iskeleti, boş durum. Hem açık hem koyu tema.
