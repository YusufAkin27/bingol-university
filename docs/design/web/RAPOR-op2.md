# RAPOR op2 (web Stitch: 04, 05, 06)

Not: Web modu; istemler ORTAK KURALLAR + sayfa istemi (İngilizce görsel referans cümlesi + "tasarım şartnamesi paneli/sürüm etiketi/uydurma sayı ekleme" uyarısı eklendi). Bu üç sayfada telefon maketi yok, "telefon içi boş yer tutucu" düzeltmesi gerekmedi.

## 04 Haberler + haber detayı
- Proje: https://stitch.withgoogle.com/projects/13464417772234733164 | Klasör: `C:\bu_design\web\04-haberler\` (code.html + screen.png; liste için render.png)
- Üretilen: masaüstü 3 (liste, detay, yükleniyor/boş), mobil 3 (aynı üçü).
- Düzeltmeler (6+ tur): kırık logo görseli -> metin logo; "Bağımsız Topluluk Projesi", "Doğrulanmış Üniversite Akışı", "Senkronizasyon 09:42", "Resmî Veri Eşitleme", uydurma telefon, "Ücretsiz", filtre sayıları, "Tasarım ve Durum Spesifikasyonu v2.4" paneli, "Durum Matrisi" çubuğu, mobilde uygulama tarzı alt sekme çubuğu kaldırıldı; başlık bloğu liste ekranında 3 kez tekrarlanmıştı, tek kopyaya indirildi.
- Halüsinasyonlar: uydurma "Durum Kodu/UI Durum Matrisi" paneli, sahte sayılar, sürüm etiketi; üretilen haber başlıkları/tarihleri örnek metindir (2025 tarihleri). Haber görselleri Stitch'in ürettiği stok fotoğraftır (kampüs binası yazılı görsel kopyası dahil), kodlamada gerçek haber görselleriyle değişecek.
- Kalan eksikler: yükleniyor/boş ekranında başlıkta h1 yok (iskelet), detay ekranı üstünde son tur üst şerit yinelenmesi doğrulanmadı; "Haberi Oku / Kaynağı İncele" düğmesi "Kaynağı aç" yerine "Kaynağı İncele" yazıyor (liste hero kartında); detayda kaynak bağlantısı var. Mobil detayda "TL" geçmiyor (kontrol edildi, yalnız kelime içi eşleşme).

## 05 Yemek listesi
- Proje: https://stitch.withgoogle.com/projects/15682237468776892221 | Klasör: `C:\bu_design\web\05-yemek\`
- Üretilen: masaüstü 2 (yemek listesi; menü yok/bakım durumları), mobil 2.
- Düzeltmeler (4 tur): "Tabldot Ücreti 20 TL", 4.2/5 puan, "1.482 öğrenci puanladı", %88 onay, besin dengesi/alerjen kartı, P/K/Y değerleri, alerjen etiketleri, "Bakiye Yükle/Turnike", "Sunucu Durumu", bozuk "FITBIT_JUMPING_JACKS" metni, "Cafeteria Menu" başlığı, v2.4.0 etiketi kaldırıldı; puanlama kartı "uygulamada puanla" CTA'sına çevrildi (sayısız). Günlük ve toplam kalori görünür.
- Halüsinasyonlar: ödeme/bakiye, puan/oy sayıları, "Merkez/İlçe Yemekhaneleri", tabldot kodu. Örnek yemek adları istemdeki listeden.
- Kalan eksikler: "Merkez Kampüs Yemekhanesi" seçici ve Öğle/Akşam sekmesi (uygulamada yok olabilir, kodlamada çıkarılabilir); takvim "Ekim 2024" sabit metin; mobil "menü yok" ekranında 435 px taşma tespit edildi (örnek: durum geçişi satırı, son turda ölçüm 435>390 iken düzeltme istemi gönderildi, yeniden ölçülmedi: kodlamada kontrol edin); mobil üst şerit metni sağdan kesiliyor; mobilde sayfa başlığı "Yemek Listesi" iki kez.

## 06 Yardım merkezi + SSS + destek talebi
- Proje: https://stitch.withgoogle.com/projects/3363918731761244058 | Klasör: `C:\bu_design\web\06-yardim\`
- Üretilen: masaüstü 3 (Yardım Merkezi, SSS, Destek Talebi Aç: e-posta/konu/mesaj + 6 haneli kod adımı + "Talebiniz alındı" önizlemesi), mobil 3. Ek olarak Stitch kendiliğinden 3 koyu tema ekranı da üretti (`*_koyu_tema`; istenmemişti, referans olarak tutuldu; koyu varyantlarda düzeltilmemiş uydurma metinler var: makale sayıları, "24 saat", SSL notu, Talep No).
- Düzeltmeler (1 tur, iki ekran): "Toplam 30 makale", makale sayıları, "Ortalama Yanıt 24 Saat" kutusu, "Doğrulanmış İletişim Masası", Talep No/Öncelik/Birim alanları, SSL notu, "Acil Durum" kutusu kaldırıldı; koyu kart "Destek Talebi Aç" CTA'sına çevrildi.
- Halüsinasyonlar: makale sayıları, 24 saat yanıt sözü, talep numarası, "Doğu Anadolu" altbilgi metni, "Geliştirici & Katkı Rehberi" bağlantısı.
- Kalan eksikler (açık düzeltme turu yapılmadı): SSS ekranında "Talepler genellikle 24 saat içinde yanıtlanır" ve "Faydalı Kaynaklar: Geliştirici & Katkı Rehberi"; üç ekranda altbilgide "Doğu Anadolu • Bingöl"; "Hâlâ yardıma mı ihtiyacınız var?" metni dilbilgisi olarak doğru. Üst şerit kullanılmamış (Yardım sayfaları). Kodlama aşamasında bu metinler elle temizlenmeli.

## Genel gözlemler
- Stitch her projede "Ana Sayfa/Özellikler/..." üst gezinmesini tutarlı üretti; logo olarak kırmızı kare + "BÜ Kampüs" kullanıldı (bazı ekranlarda elmas/kare simge, tutarsız).
- Mobil üretimde bazı ekranlar çok uzun/dar önizleme veriyor (PNG kırpık); doğru görünüm için `render.png` (HTML 390 px'te çekilmiş tam sayfa) kullanın.
- Export zip'leri `screen.png` Stitch önizlemesidir (düşük çözünürlüklü/kırpık olabilir; mobilde 153-237 px genişlik), referans olarak `render.png` ve `code.html` esas alınmalı.
