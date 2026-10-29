# RAPOR s5 (Stitch istemleri 47-51)

Hesaplar: 47 /u/1/ (avatar "a"), 48-51 /u/3/ (avatar "y", yonetici talimatiyla yeni projeler). Aktarma klasoru: `C:\bu_design\stitch\<NN>-<ad>\` (zip icinden HTML + DESIGN.md; Stitch'in `screen.png` dosyalari "FIFE Image failed to fetch" stub'i geldigi icin her `code.html` yerelde 390x844 pencerede render edilip `screen.png` olarak kaydedildi).
Genel gozlem: /u/1/ projesinde ekran cercevesi 1280x1024 (masaustu boyutu) cikti, /u/3/ projelerinde 390 genislikli dikey cerceve; ilk istemde "Visual reference" cumlesi her iki hesapta da kullanildi.

## 48 - Takipci listeleri, onerilen kisiler, profili duzenle (6 ekran)
- Proje: "BU Kampus Profile Screens" https://stitch.withgoogle.com/u/3/projects/17703697681011840391 ; PNG/HTML: `C:\bu_design\stitch\48-takipciler-profil-duzenle\`
- Uretilen: takipci listesi, takip edilenler + bos/hata durumlari, onerilen kisiler, profili duzenle, hata/yukleme, degisiklikleri at diyalogu.
- Duzeltilen (2 tur): her ekranda sahte "Duyuru Detay" ust cubugu + avatar -> dogru basliklar; @elif.yildiz kullanici adi, dogrulama rozeti, "Bingol Universitesi Ogrenci Toplulugu" alt bilgisi, "Prototip Onizleme"/"Durum Gorunumleri"/"Topluluk Agi"/"3 Yeni" etiketleri, ogrenci numarasi alani, "Ogrenci isleri sisteminden..." satiri silindi; tekrar eden profil basligi kaldirildi.
- Halusinasyonlar: sahte ust cubuk+avatar, kullanici adi (@handle), universite adi etiketi, uydurma durum etiketleri.
- Kalan eksik: takipci listesinde sekmeler ust cubuga cok yakin (tuvalde kismen kesik); "Takip Edilenler" ekraninda "Takipciler Sekmesi"/"Takip Edilenler Sekmesi" kucuk etiketleri ve ek "Aramayi Temizle" dugmesi var; profil duzenle HTML'inde Bolum/Sinif listeleri acik secenek metinleriyle geliyor (gorsel dogrulanmadi).

## 50 - Bildirim tercihleri (5 ekran)
- Proje: "BU Kampus Notification Preferences" https://stitch.withgoogle.com/u/3/projects/18223965491906364984 ; PNG/HTML: `C:\bu_design\stitch\50-bildirim-tercihleri\`
- Uretilen: ana tercihler (push acik), push kapali, ayrintili tercihler (ust anahtar kapaliyken alt anahtarlar pasif), sessiz saatler + saat secici, hata satiri + "Bu cihazda: Ders ve sinav hatirlatmalari".
- Duzeltilen (2 tur): sahte avatar ust cubuk, "rektorluk / acil durum ... SMS ve e-posta ile iletilir" notlari, "Rektorluk Acil Duyurulari" karti, "Bulut Esitleme/Cevrimdisi", "Cihaz bildirim gecmisi", "Yemekhane menu bildirimi", "Tekrarlama Gunleri", "Kampus Bilgi Sistemi" alt bilgisi, "6/7 Aktif" sayaci silindi; ilk turda silinen "Sessiz saatleri ac" anahtari ikinci turda geri getirildi.
- Halusinasyonlar: rektorluk/SMS/e-posta mesajlari, yemekhane/cihaz gecmisi satirlari, avatar.
- Kalan eksik: beklenen "Neler bildirilsin" listesinde Anketler/Akademik duyurular dahil tum satirlar var; yukleniyor/hata ekraninda uyarı satiri ile cihaz bolumu tek ekranda; sessiz saatler ekraninda saat secici acikken arka plan donuk oldugundan anahtar satiri soluk gorunuyor.

## 51 - Ortak sheet ve diyaloglar (6 ekran)
- Proje: "BU Kampus Modal Overlays" https://stitch.withgoogle.com/u/3/projects/1533949826162683044 ; PNG/HTML: `C:\bu_design\stitch\51-ortak-sheetler\`
- Uretilen: kullanici sikayet sheet'i (5 neden + ek aciklama + Gonder), mesaj sikayet sheet'i + "Sikayetiniz alindi. Tesekkurler." toast'i, cikis diyalogu, tum cihazlardan cikis diyalogu, engelleme diyalogu (kullanici + gonderi metni + toast), tema sheet'i (Sistem/Acik/Koyu + onizleme kartlari).
- Duzeltilen (1 tur): arka planlardaki yasak icerik temizlendi: "Bakiye 142.50 / Yemek Hak / Ring Izni", SMS ile iki adimli dogrulama + cihaz listesi, @kullanici adlari ve dogrulama rozeti, "Kampus Haritasi Tam Ekran" sahte ust cubugu + avatar, "Kampus Entegrasyonlari / Yemekhane Bakiye / Ring Otobusu"; tema sheet'inden Aktif etiketi, Vazgec/Uygula ve X kaldirildi.
- Halusinasyonlar: bakiye/ring (odeme/servis uydurmalari), iki adimli dogrulama, cihaz listesi, kullanici adi (@handle), sahte ust cubuk.
- Kalan eksik: yok (sikayet sheet'i "Taciz veya zorbalik" secili; mesaj sheet'inde 5 neden gorunuyor). Arka plan ekranlari sade tutuldu.

## 49 - Ayarlar, hesap, gizlilik, engellenenler, dil sheet (6 ekran)
- Proje: "BU Kampus Settings Screens" https://stitch.withgoogle.com/u/3/projects/16713373544331066654 ; PNG/HTML: `C:\bu_design\stitch\49-ayarlar-hesap-gizlilik\`
- Uretilen: Ayarlar, Hesap ve guvenlik, Gizlilik ve engellenenler, Engellenenler listesi, bos/yukleniyor/hata, Dil sheet'i.
- Duzeltilen (2 tur): "Account Settings" ust cubugu+avatar+uc nokta -> Turkce basliklar; "Ogrenci Bilgi Sistemi (OBS)", cihaz listesi (iPhone 14 Pro), "Bingol Universitesi Bilgi Islem..." alt bilgisi, "Kontrol Sende" karti, "Topluluk Guvenligi" karti, "Hata Kodu: 503", "Kampus Karti" metni, Kaydet/Vazgec ve "Varsayilan" etiketi silindi; ilk duzeltmede yanlislikla silinen sifre alanlari ikinci turda geri getirildi.
- Halusinasyonlar: sahte ust cubuk, cihaz yonetimi, kurumsal alt bilgi, OBS entegrasyonu, kampus karti.
- Kalan eksik: dil sheet'inin arka plani bulanik/gri ve eski satir artiklari iceriyor; bos durum ekraninda "Yukleniyor Iskeleti / 2 Oge" ve "Hata Bildirim Satiri" kucuk etiketleri kaldi; sifre basari toast'u render'da gorunmuyor (Stitch tuvalinde var).
