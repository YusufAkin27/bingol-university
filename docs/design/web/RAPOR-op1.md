# RAPOR op1 (web: 01 Ana sayfa, 02 Özellikler, 03 İndir)

Genel not: Stitch web modu ekranları 1280 px genişliğinde üretiyor; masaüstü PNG'ler `code.html` dosyasının 1440 px'te Playwright ile tam sayfa render edilmiş halidir (`desktop-1440.png`), mobil olanlar 390 px (`mobile-390.png`). Stitch istemdeki "başka sayfa üretme" yazmazsa kendiliğinden ek sayfalar (Özellikler, Haberler...) üretir; ek ekranlar silindi.

## 01 Ana sayfa
- Üretilen: masaüstü 1 ekran (hero + 4 özellik + 3 adım + güven + CTA + alt bilgi), mobil 1 ekran ("Mobil Ana Sayfa", 390).
- Düzeltmeler: başlıkta marka çift görünüyordu (tek kilit), "ücretsiz/reklamsız/sıfır reklam/%100/lisanslı/açık kaynak", ₺ fiyat, "12 Yorum", "v2.4", OBS eşitleme iddiası, Protein/Karb/Yağ çubuğu, "~18 MB", mobilde alt sekme çubuğu ve "Ring Programı" metni kaldırıldı; hero telefonları yan yana kesilmeden büyütüldü; telefon içleri kullanıcı kuralıyla düz #F3ECE7 yer tutucuya çevrildi (mobilde telefon çerçevesi yerine düz yer tutucu kutu).
- Stitch halüsinasyonları: uydurma fiyat/kalori/yorum, "Sağlık, Kültür ve Spor Daire Başkanlığı tarafından sunulan" ifadesi (menü kaynağı iddiası, kodlamada gözden geçirilmeli), "Bağımsız Topluluk Yayını" rozeti, adım 1'de telefon yer tutucusunun hizası hafif kayık.
- Kalan eksikler: koyu tema/RTL görünümü üretilmedi; "Kurum" sütunu alt bilgide ayrı başlık yerine marka bloğu.
- Proje: https://stitch.withgoogle.com/projects/3281734432137744514
- Klasör: `C:\bu_design\web\01-ana-sayfa\` (desktop/, mobile/: code.html, screen.png, DESIGN.md, PNG)

## 02 Özellikler
- Üretilen: masaüstü 1 ekran (hero + 8 modül özet ızgarası + 8 dönüşümlü satır + CTA bandı + alt bilgi), mobil 1 ekran ("Özellikler - BÜ Kampüs (Mobil)", 390, 2 sütun özet ızgarası, tek sütun satırlar, katlanır alt bilgi).
- Düzeltme turu 1: başlık menüsü iki satıra kırılıyordu, logo görseli kırık (Stitch dışı render), "Resmî Duyurular", takvim senkronizasyonu ve kurum adı iddiaları, hero ağırlığı için iki boş telefon çerçevesi eklendi. Başlangıçtan itibaren telefon içleri düz #F3ECE7 yer tutucu ("Uygulama ekran görüntüsü").
- Stitch notu: istemde "başka sayfa üretme" denince ek sayfa üretmedi; yine de Stitch'in önerdiği sonraki sayfa çipleri var (tıklanmadı).
- Kalan eksikler: "Kategoriye göre kulüp rehberi (Bilim, Kültür, Spor, Sanat)", "Ara sınav" gibi ayrıntı maddeleri uydurma olabilir, kodlamada gerçek özelliklere göre gözden geçirilmeli; Sohbet bölümünde "Bölüm ve ders bazlı grup odaları" iddiası doğrulanmalı. Alt bilgide başlıklar mobilde akordeon.
- Proje: https://stitch.withgoogle.com/projects/9625536679340214837
- Klasör: `C:\bu_design\web\02-ozellikler\` (desktop/, mobile/)

## 03 İndir
- Üretilen: masaüstü 1 ekran (başlık + iOS/Android durum rozetleri + mağaza düğmeleri + QR yer tutucu + uyarı + iki telefon çerçevesi + sistem gereksinimleri + 3 adım + 3 soruluk SSS + destek şeridi + alt bilgi), mobil 1 ekran ("İndir (Mobil) - BÜ Kampüs", 390). Bonus: Stitch, önerilen çip nedeniyle kendiliğinden koyu tema masaüstü ekranı üretti (`dark-extra/`, düzeltme almadı, "Nocturne Campus" tasarım sistemi; resmî kural ihlali var mı denetlenmedi, yalnız referans).
- Düzeltme (1 tur): hero telefonları üst üste biniyordu (yan yana, kesilmeden), logo karesi kırmızıydı (lacivert), rozetler ("iOS — Yakında" / "Android — Yayında"; gerçek durum yönetim ayarından gelmeli), "Teknik destek ekibimiz..." iddiası ve alt bilgideki "Murat Vadisi & Bingöl Kampüs Bilgi Hizmeti" kaldırıldı.
- Stitch halüsinasyonları / kalan eksikler: mobil alt bilgide "Ring & Otobüs Saatleri", "Geliştirici Ekip", "Basın Kiti" bağlantıları (uygulamada yok; kodlamada alt bilgi bağlantıları mevcut siteden alınmalı); "iOS 15.0 / Android 8.0 (Oreo)" sistem gereksinimi değerleri uydurma (gerçek `minSdk`/iOS hedefi ile doğrulanmalı); SSS yanıtlarında "lisans, ön lisans, lisansüstü" ifadesi; hero ikinci telefonda kamera noktası/ada farkı (küçük). Hero telefonları içerik sütunundan hafif taşıyor (masaüstü 1302 px sağ kenar).
- Not: QR yer tutucusu Stitch'in çizdiği sahte QR; kodlamada gerçek mağaza QR'ı veya yer tutucu kullanılmalı.
- Proje: https://stitch.withgoogle.com/projects/14142581341705821748
- Klasör: `C:\bu_design\web\03-indir\` (desktop/, mobile/, dark-extra/)
