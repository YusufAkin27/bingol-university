# 00 - Ortak kurallar (Stitch istemleri için)

Bu belge Google Stitch'e yapıştırılacak tüm istemlerin ortak parçasıdır. Her `NN-*.md` dosyasındaki "İstem" bloğunun başına, aşağıdaki **ORTAK ÖNSÖZ** bloğunu yapıştırın (önsöz 1500 karakteri aşmaz). Stitch bir turda en çok 6 ekran üretir; her dosya tek bir tur içindir.

Yöntem: Önce ORTAK ÖNSÖZ, hemen altına ilgili dosyanın İstem bloğu. Sonuç geldiğinde dosyanın "Özellik kontrol listesi" bölümüyle karşılaştırın; eksik maddeleri aynı oturumda "Add: ..." diye isteyin. Referans tasarım zaten üretilmiştir (Ana Sayfa, Keşfet, Sohbet, Kulüpler, Profil, Etkinlik Detayı, Giriş, Yemek Listesi, Haber Detayı, Sohbet Konuşması, Kulüp Detayı, Anket Detayı, Bildirimler); bu paket yalnızca geri kalan ekranları ve referans ekranların durum/özellik varyantlarını kapsar.

## ORTAK ÖNSÖZ

```text
BU Kampus: independent mobile app for Bingol University students and staff (not official). Mobile 390x844, Material 3, light theme. Brand: navy #171E33, red #F73A2E, action buttons #C62A20, soft red tint #FDE7E4, page background #F6F7FA, white cards with 20px radius, Inter font, rounded 16px buttons and fields. Only the 5 main tab screens have a floating pill bottom navigation with exactly these tabs in this order: Ana Sayfa, Keşfet, Sohbet, Kulüpler, Profil. Detail, form, sheet and dialog screens have NO bottom navigation.
All UI text is Turkish with correct characters (ç ğ ı İ ö ş ü Ç Ğ Ş Ö Ü). No fake phone status bar, no device frame. If a version is shown: "Sürüm 2.0.3". Sample email: ad.soyad@bingol.edu.tr (only bingol.edu.tr emails exist).
NEVER show: payments, balance, wallet, pay-by-QR; stories, comments, #hashtags, @mentions, video posts, saved posts (a post is exactly 1 photo + max 7 words + likes); e-Devlet, eduroam, weather, fake statistics; other campuses (Guney/Merkez Kampus); official university logo or the word "Resmi" in branding. Events always belong to a club. QR is only for event attendance. Menu dishes show kcal set by an admin.
Use realistic Turkish names, clubs, departments. Draw every listed state and element, not only the happy path.
```

## Stitch'in önceki turlarda yaptığı tipik hatalar

Mevcut Stitch çıktısında görülen ve her turda yeniden çıkabilen hatalar. Çıktıyı bunlara karşı tarayın; görürseniz "Remove X, replace with Y" diye düzeltin.

| Hata | Doğrusu |
|---|---|
| Ödeme kartı, bakiye, cüzdan, "QR ile öde" | Hiçbiri yok. QR yalnızca etkinlik yoklaması içindir. |
| `boun.edu.tr` ya da başka üniversite alan adı | Yalnızca `bingol.edu.tr`; örnek `ad.soyad@bingol.edu.tr` |
| "Güney Kampüs", "Merkez Kampüs" gibi kampüs seçimi | Kampüs ayrımı yok, tek üniversite |
| eduroam / Wi-Fi kartı | Uygulamada yok |
| Hava durumu kartı (sıcaklık, simge) | Yok |
| e-Devlet girişi/butonu | Yok; giriş yalnızca okul e-postası + şifre |
| "Bingöl Üniv." gibi kısaltılmış, resmî görünen başlıklar; resmî logo | Başlıkta uygulama adı "BÜ Kampüs"; uygulama bağımsızdır, resmî logo ve "Resmi" ibaresi marka alanında yok |
| `v2.4.0` ya da başka sürüm | "Sürüm 2.0.3" |
| Sahte telefon durum çubuğu (saat, pil), cihaz çerçevesi | Yok |
| Gönderide yorum sayısı/yorum alanı, hikâye halkaları, #etiket, @bahsetme, video, "kaydet" yer imi | Gönderi = 1 fotoğraf + en çok 7 kelime + beğeni (kalp) |
| Etkinliğin kulüpsüz olması, "Resmi etkinlik" rozeti | Etkinlik her zaman bir kulüp adına; "Düzenleyen: <kulüp>" gösterilir |
| Uydurma istatistik ("12.480 öğrenci", "98% memnuniyet") | Gösterme; yalnız ekrandaki gerçek alanlar |
| Yemek kalorisinin olmaması ya da tek toplam sayı | Her yemek satırında kcal; altta toplam (eksikse "en az") |
| ASCII'ye bozulmuş Türkçe ("Kulupler", "Gonder") | Doğru karakterler: Kulüpler, Gönder |
| Alt gezinmenin detay/form/sheet ekranlarında da görünmesi | Yalnız 5 sekme ekranında |
| Alt gezinmede 5'ten fazla/farklı sekme | Tam olarak: Ana Sayfa, Keşfet, Sohbet, Kulüpler, Profil |
| Arapça/İngilizce karışık arayüz metni | Hepsi Türkçe |
