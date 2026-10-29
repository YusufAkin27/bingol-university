# Referans tasarımlarda UYGULANMAYAN (Stitch halüsinasyonu) öğeler

Referans PNG kanundur (IMPLEMENT.md); ancak aşağıdaki öğeler Stitch'in uydurduğu hatalardır ve uygulamada YAPILMAZ. Listede olmayan bir hata görürseniz DUR, `docs/design/SORULAR.md`'ye yazın ve o öğeyi referansta olduğu gibi bırakın.

## Her ekranda geçerli (yasaklar)
- Üniversite logosu/adı etiketi, "Resmî", "Resmi", "Canlı", "Aktif" rozetleri, kampüs adları (Merkez/Güney/Kuzey/Boğaziçi/İTÜ/Abdullah Gül), eduroam, e-Devlet, hava durumu, bakiye/ödeme/turnike, "Simülasyon/Önizleme" etiketleri, sürüm v2.4/v3.4 (doğrusu "Sürüm 2.0.3"), sahte durum çubuğu, sahte üst çubuk/avatar, uydurma istatistik/görüntülenme sayısı, "Adım 1/3" gibi uydurma adım göstergeleri, İngilizce başlıklar (tüm başlıklar Türkçe, l10n tr/en/ar).
- Üst başlık "BU Kampüs" + alt başlık "Bağımsız öğrenci uygulaması"; alt gezinme: yüzen hap, 5 sekme (Ana Sayfa, Keşfet, Sohbet, Kulüpler, Profil).

## Ekran/grup bazında bilinen kusurlar
- 05: "Toplam 740 kcal" satırı yemek kalorileriyle tutarsız. Menüde gerçek `dishes[].kcal`/`totalKcal`/`kcalComplete` kullanılır (docs/MOBILE_API_GUIDE.md 11.1).
- 07: sahte "Event Detail Sheet" üst çubuğu + avatar, "Resmî Dijital Yürürlük Belgesi" bloğu, liste/boş ekrandaki fazla metinler, reddetme sayfasının yanlış arka planı. Mevcut sözleşme ekranlarının işlevi korunur.
- 16: kapak görselindeki İTÜ yazısı. 17: fotoğraf üstündeki üniversite adı. 18: arşiv ekranındaki çift başlık ve fazla çipler. 19: kırmızı çevrimiçi noktası (tema rengi kullanılır). 20: "Ali Kaya" başlık uyuşmazlığı, üst üste binme, "Merkez Amfi Tiyatro".
- 27-31: küçük artıklar (kurum etiketi, fazla çip); 40: sayaç uyuşmazlığı; 41: kesik banner.
- 32: İngilizce başlıklar (Poll Details...), "Genel Kampüs" çipi, kütüphane stok görseli, "452 oy", "rektörlük".
- 45: "Akademik Takvim Durum", "Ders Detay" tipi başlıklar, kırmızı avatar, uydurma öğeler ("Test Gönder", "Güncel Akış", görüntülenme sayıları), "Resmi Fakülte Duyurusu".

## Ürün kuralları (değişmez)
Ödeme/bakiye/QR-ile-öde yok; hikâye, yorum, #etiket, @bahsetme, video gönderi, kaydet yok; gönderi = 1 fotoğraf + en çok 7 kelime/60 karakter + beğeni (çift dokunuşla beğeni mevcut); yalnız bingol.edu.tr; etkinlik her zaman kulüp adına; QR yalnız etkinlik yoklaması için.
