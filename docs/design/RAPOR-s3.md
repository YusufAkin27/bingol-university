# RAPOR s3 (Stitch istemleri 25, 26, 33, 34, 35)

Hesap: yalniz /u/1/ (avatar 'a'). /u/2/ gecisi izin sistemi tarafindan reddedildi, yapilmadi.
Aktarma klasoru: `C:\bu_design\stitch\<NN>-<ad>\` (export.zip + her ekran icin code.html + screen.png; Stitch'in kendi screen.png dosyasi cogu ekranda "FIFE Image failed to fetch" metni dondu, bu yuzden screen.png code.html'den render edilerek uretildi, render.png ile ayni).

## 25 - Sohbet medya secici (7 ekran, `C:\bu_design\stitch\25-sohbet-medya-secici\`)
- Proje: **BU Kampus S3-25-26** - https://stitch.withgoogle.com/u/1/projects/17487025770066145257
- Uretilen: galeri secici, gonderim oncesi onizleme, izin durumlari (sinirli/yok), album sheet, kamera (hazir), video hazirlama + hata toast'lari; istenen "kayit halinde" durumu icin ek 7. ekran (kamera kayit 0:12/1:00).
- Duzeltilen (2 tur + onizleme icin 2 ek istem): avatar ve Ingilizce basliklar (Media Gallery Picker / Create Post Sheet), "Merkez Kampus Meydani", "Canli Simulasyon", "Mod Ozeti", "Sistem Bildirimi", "Yeni album olustur", dosya adi/H.264/SISTEM UYARILARI, kirmizi hata notu (gri bilgiye cevrildi), cift ust satir, ikon adlarinin metin olarak gorunmesi (onizleme ekrani SVG ikonlara cevrildi), eski kopyalar silindi. Yanlislikla tetiklenen "Yeni Album Olustur" ekrani silindi.
- Halusinasyonlar: avatar, ingilizce baslik, kampus adi, uydurma "mod/durum" kartlari, ikon fontu metin olarak.
- Kalan eksik: video penceresinde ilerleme %45 degil (animasyonlu, %81 gorunuyor); album sheet'te "4 album" cipi; "Son Eklenenler" buyuk harf; izin ekraninda iki blok tek ekranda (istem boyle istiyor).

## 26 - Sohbet goruntuleyiciler (6 ekran, `C:\bu_design\stitch\26-sohbet-goruntuleyiciler\`)
- Proje: **BU Kampus S3-26-33** - https://stitch.withgoogle.com/u/1/projects/17489771455933385551 (33 de bu projeye eklenecek)
- Uretilen: gorsel goruntuleyici (2/5, Indir), kaydetme geri bildirimi + 4 hata metni (yakinlastirilmis), video posteri (Videoyu oynat, 0:42), oynatilan video (0:18/0:42), oynatma hatasi (Yeniden dene), tek gosterimlik fotograf (3 durum metni; indir/paylas yok).
- Duzeltilen (1 tur): "Media Overlay Viewer" basligi, paylas dugmesi, avatar, kulup/sarki adlari, "Kampus Kayitlari" listesi, Wi-Fi karti, hata kodu, "Sorun Bildir", "Canli Kayit"/"Aktif Onizleme" etiketleri, ikon adlari metin olarak, ekstra kartlar silindi.
- Halusinasyonlar: ingilizce baslik, paylas/avatar, kulup adlari, Wi-Fi/ag karti, hata kodu, ikon fontu metni.
- Kalan eksik: tek gosterimlik rozetinde "1" yerine "!" benzeri simge; gorsel ekranda yan oklar + nokta seridi; yalniz tuval ve render ile denetlendi.

## 33 - Anket detay durumlari (6 ekran, `C:\bu_design\stitch\33-anket-detay-durumlari\`)
- Proje: **BU Kampus S3-26-33** (26 ile ayni) - https://stitch.withgoogle.com/u/1/projects/17489771455933385551
- Uretilen: oy verildi/sonuclar acik, sonuclar gizli, henuz acilmadi, kapandi + puanlama ozeti, oy verilemez (3 kart), oyu geri cek diyalogu + eski veri + snackbar. Gizli oy: kimlik/avatar hicbir yerde yok.
- Duzeltilen (1 tur, 6 ekrana birden): paylas ikonu + avatar, "Anket Detayi" basliklari, kulup rozet/adlari, "Resmi Ogrenci Anketi", Rektorluk, kutuphane/kampus adlari, kapak gorselleri, "Yorumlar (19)" baglantisi, "Kriter" satirlari, "Ornek Anket Formu" karti, yildiz dagilim tablosu, bildirim anahtari; soru ve secenekler tum ekranlarda yemek anketine sabitlendi.
- Halusinasyonlar: uydurma anket konulari (Bahar gezisi, Tiyatro, Kutuphane saatleri), kulup/rektorluk etiketleri, yorum sayaci, avatar+paylas.
- Kalan eksik: gizli oy notunun basliginda "Gizli ve Dogrulanmis Oy" ifadesi; kapanan ekranda yuzdeler/oy sayilari (68/22/10, 87+28+13) istemdeki "128 katilim" ile ayni degil, "12 Mayis 2024" dipnotu; amber bayat bant diyalog ekraninda bulanik.

## 34 - Destek talepler (6 ekran, `C:\bu_design\stitch\34-destek-talepler\`)
- Proje: **BU Kampus S3-34-35** - https://stitch.withgoogle.com/u/1/projects/2091958414762298808 (35 koordinator karariyla S1'e devredildi, bu projede uretilmedi)
- Uretilen: destek ana sayfasi (SSS arama/cipler/akordeon, taleplerim durum haplari, Destek talebi olustur, Geri bildirim + Oneri panosu), bos/hata/hiz siniri durumlari, yeni talep formu (+ dogrulama + toast), acik talep sohbeti, kapali talep, talebi kapat diyalogu.
- Duzeltilen (1 tur, 6 ekrana birden): avatar + (i) simgesi, "Sikca Sorulan Sorular"/"Destek Talebi Olustur"/"Talep Detayi" basliklari, "Nasil yardimci olabiliriz? 7/24 Kampus Masasi" karti, cagri merkezi telefon numarasi, "Bilgi Islem Daire Baskanligi" dipnotu, bilet kodlari (#TK-...), ataç simgesi, "Cozumlendi" karti, ikon adlarinin metin gorunmesi, bildirim/e-posta bilgi kutusu.
- Halusinasyonlar: telefon/cagri merkezi, 7/24 hero karti, bilet kodlari, ataç (dosya eki), kurum dipnotu, ikon fontu metni.
- Kalan eksik: acik talepte "Talebi kapat" menusu acik cizilmedi; bos durum aciklamalari "..." ile kesik; yalniz render ile denetlendi.
