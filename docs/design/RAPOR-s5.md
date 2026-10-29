# RAPOR s5 (Stitch istemleri 47-51)

Hesaplar: 47 /u/1/ (avatar "a"), 48-51 /u/3/ (avatar "y", yonetici talimatiyla yeni projeler). Aktarma klasoru: `C:\bu_design\stitch\<NN>-<ad>\` (zip icinden HTML + DESIGN.md; Stitch'in `screen.png` dosyalari "FIFE Image failed to fetch" stub'i geldigi icin her `code.html` yerelde 390x844 pencerede render edilip `screen.png` olarak kaydedildi).
Genel gozlem: /u/1/ projesinde ekran cercevesi 1280x1024 (masaustu boyutu) cikti, /u/3/ projelerinde 390 genislikli dikey cerceve; ilk istemde "Visual reference" cumlesi her iki hesapta da kullanildi.

## 48 - Takipci listeleri, onerilen kisiler, profili duzenle (6 ekran)
- Proje: "BU Kampus Profile Screens" https://stitch.withgoogle.com/u/3/projects/17703697681011840391 ; PNG/HTML: `C:\bu_design\stitch\48-takipciler-profil-duzenle\`
- Uretilen: takipci listesi, takip edilenler + bos/hata durumlari, onerilen kisiler, profili duzenle, hata/yukleme, degisiklikleri at diyalogu.
- Duzeltilen (2 tur): her ekranda sahte "Duyuru Detay" ust cubugu + avatar -> dogru basliklar; @elif.yildiz kullanici adi, dogrulama rozeti, "Bingol Universitesi Ogrenci Toplulugu" alt bilgisi, "Prototip Onizleme"/"Durum Gorunumleri"/"Topluluk Agi"/"3 Yeni" etiketleri, ogrenci numarasi alani, "Ogrenci isleri sisteminden..." satiri silindi; tekrar eden profil basligi kaldirildi.
- Halusinasyonlar: sahte ust cubuk+avatar, kullanici adi (@handle), universite adi etiketi, uydurma durum etiketleri.
- Kalan eksik: takipci listesinde sekmeler ust cubuga cok yakin (tuvalde kismen kesik); "Takip Edilenler" ekraninda "Takipciler Sekmesi"/"Takip Edilenler Sekmesi" kucuk etiketleri ve ek "Aramayi Temizle" dugmesi var; profil duzenle HTML'inde Bolum/Sinif listeleri acik secenek metinleriyle geliyor (gorsel dogrulanmadi).

## 49 - Ayarlar, hesap, gizlilik, engellenenler, dil sheet (6 ekran)
- Proje: "BU Kampus Settings Screens" https://stitch.withgoogle.com/u/3/projects/16713373544331066654 ; PNG/HTML: `C:\bu_design\stitch\49-ayarlar-hesap-gizlilik\`
- Uretilen: Ayarlar, Hesap ve guvenlik, Gizlilik ve engellenenler, Engellenenler listesi, bos/yukleniyor/hata, Dil sheet'i.
- Duzeltilen (2 tur): "Account Settings" ust cubugu+avatar+uc nokta -> Turkce basliklar; "Ogrenci Bilgi Sistemi (OBS)", cihaz listesi (iPhone 14 Pro), "Bingol Universitesi Bilgi Islem..." alt bilgisi, "Kontrol Sende" karti, "Topluluk Guvenligi" karti, "Hata Kodu: 503", "Kampus Karti" metni, Kaydet/Vazgec ve "Varsayilan" etiketi silindi; ilk duzeltmede yanlislikla silinen sifre alanlari ikinci turda geri getirildi.
- Halusinasyonlar: sahte ust cubuk, cihaz yonetimi, kurumsal alt bilgi, OBS entegrasyonu, kampus karti.
- Kalan eksik: dil sheet'inin arka plani bulanik/gri ve eski satir artiklari iceriyor; bos durum ekraninda "Yukleniyor Iskeleti / 2 Oge" ve "Hata Bildirim Satiri" kucuk etiketleri kaldi; sifre basari toast'u render'da gorunmuyor (Stitch tuvalinde var).
