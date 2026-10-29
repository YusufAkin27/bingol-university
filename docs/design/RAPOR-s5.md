# RAPOR s5 (Stitch istemleri 47-51)

Hesap: yonetici talimatiyla 47-51 yeni Google hesabinda uretildi: https://stitch.withgoogle.com/u/3/ (avatar "y"). 47'nin ilk denemesi /u/1/ (avatar "a") hesabindaydi; ekran cercevesi 1280x1024 (masaustu boyutu) ciktigi icin /u/3/'te yeniden uretildi (390 genislikli dikey cerceve).
Aktarma klasoru: `C:\bu_design\stitch\<NN>-<ad>\` (Stitch .zip: her ekran icin `code.html`, ayrica `DESIGN.md`/tasarim sistemi klasoru). Stitch'in `screen.png` dosyalari "FIFE Image failed to fetch" stub'i geldigi icin her `code.html` yerelde 390x844 pencerede render edilip `screen.png` olarak kaydedildi (ilk ekran goruntusu; uzun ekranlarda alt kisim kesik olabilir, tam icerik HTML'de).
Ortak halusinasyonlar (tum gruplarda tekrar etti): "Profile Details"/"Account Settings"/"Duyuru Detay" gibi sahte ust cubuk + avatar; @kullanici adlari; "Bingol Universitesi ..." alt bilgileri; uydurma durum etiketleri ("Prototip Onizleme", "Hata Kodu: 503"); bakiye/ring/cihaz listesi/SMS dogrulama. Duzeltme turlarinda Stitch bazen fazla siler (49'da sifre alanlari, 50'de sessiz saat anahtari silindi; ikinci turda geri istendi).

## 47 - Baskasinin profili durumlari (6 ekran)
- Proje: "BU Kampus Profile Screens" https://stitch.withgoogle.com/u/3/projects/1802281722617654656 ; PNG/HTML: `C:\bu_design\stitch\47-profil-baskasi-durumlari\`
- Uretilen: takip edilmeyen profil (96px avatar, cevrimici, sayaclar, Takip et / Mesaj gonder, Hakkinda/Fakulte/Bolum/Sinif/E-posta, gonderi izgarasi), takip durumlari (Takipte + Takiplesiyorsunuz, Son gorulme bugun 14:20, Seni takip ediyor + Takip et), engellenen kullanici (Kullanici engellendi bandi, Engeli kaldir, islemler sheet'i, toast), tam ekran avatar goruntuleyici, gizli alanlar + kendi profilim (Gizli kilitli satirlar, harf avatari, Profili duzenle + moderasyon notu), iskelet + "Kullanici bulunamadi" / Geri don.
- Duzeltilen (1 tur, 6 ekran): "Profile Details" ust cubugu + avatar -> "Profil"; @kullanici adlari, "Alternatif Takip Durumu/Onizleme", "ring otobusu/ders notu" metni, "Kisitli Profil / Engelleme Tarihi" bloklari, avatar goruntuleyicideki dogrulama rozeti/indir dugmesi/toast, "Ogrenci Rehberi" karti, "Hata Kodu: 404", sekmeler silindi; ilk /u/1/ denemesinde ise "Bingol Universitesi" etiketi, "Animasyonlu/404" rozetleri 2 turda silinmisti.
- Kalan eksik: engellenen ekranda "Engelle" (engelli degilken) menu varyanti cizilmedi, yalniz "Engeli kaldir + Kullaniciyi sikayet et" sheet'i var (acilir menu yerine alt sheet); engellenen ekranda avatar gorseli bozuk/ic ice gorunuyor ve toast ust bandi ortuyor; kendi profil ekraninda "Profili duzenle" ve moderasyon notu ekranin ikinci blogunda (render'da alt kisim kesik).

## 48 - Takipci listeleri, onerilen kisiler, profili duzenle (6 ekran)
- Proje: "BU Kampus Profile Screens" https://stitch.withgoogle.com/u/3/projects/17703697681011840391 ; PNG/HTML: `C:\bu_design\stitch\48-takipciler-profil-duzenle\`
- Uretilen: takipci listesi, takip edilenler + bos/eslesme yok/hata durumlari, onerilen kisiler (+ iskelet, bos), profili duzenle, hata/yukleme, degisiklikleri at diyalogu.
- Duzeltilen (2 tur): sahte "Duyuru Detay" ust cubugu + avatar -> dogru basliklar; @elif.yildiz, dogrulama rozeti, "Bingol Universitesi Ogrenci Toplulugu" alt bilgisi, "Prototip Onizleme/Durum Gorunumleri/Topluluk Agi/3 Yeni", ogrenci numarasi alani, "Ogrenci isleri sisteminden..." satiri silindi; tekrar eden profil basligi kaldirildi.
- Kalan eksik: takipci listesinde sekmeler ust cubuga cok yakin; "Takip Edilenler" ekraninda "Takipciler Sekmesi/Takip Edilenler Sekmesi" kucuk etiketleri ve ek "Aramayi Temizle" dugmesi var; profili duzenle HTML'inde Bolum/Sinif listeleri acik secenek metinleriyle geliyor (gorsel dogrulanmadi).

## 49 - Ayarlar, hesap, gizlilik, engellenenler, dil sheet (6 ekran)
- Proje: "BU Kampus Settings Screens" https://stitch.withgoogle.com/u/3/projects/16713373544331066654 ; PNG/HTML: `C:\bu_design\stitch\49-ayarlar-hesap-gizlilik\`
- Uretilen: Ayarlar, Hesap ve guvenlik, Gizlilik ve engellenenler, Engellenenler listesi, bos/yukleniyor/hata, Dil sheet'i.
- Duzeltilen (2 tur): "Account Settings" ust cubugu+avatar+uc nokta -> Turkce basliklar; "Ogrenci Bilgi Sistemi (OBS)", cihaz listesi (iPhone 14 Pro), "Bingol Universitesi Bilgi Islem..." alt bilgisi, "Kontrol Sende", "Topluluk Guvenligi", "Hata Kodu: 503", "Kampus Karti", Kaydet/Vazgec ve "Varsayilan" etiketi silindi; yanlislikla silinen sifre alanlari ikinci turda geri getirildi.
- Kalan eksik: dil sheet'inin arka plani bulanik/gri ve eski satir artiklari iceriyor; bos durum ekraninda "Yukleniyor Iskeleti / 2 Oge" ve "Hata Bildirim Satiri" kucuk etiketleri kaldi; sifre basari toast'u render'da gorunmuyor (Stitch tuvalinde var).

## 50 - Bildirim tercihleri (5 ekran; sonradan S2'ye devredildi, ben zaten tamamlamistim)
- Proje: "BU Kampus Notification Preferences" https://stitch.withgoogle.com/u/3/projects/18223965491906364984 ; PNG/HTML: `C:\bu_design\stitch\50-bildirim-tercihleri\`
- Uretilen: ana tercihler (push acik), push kapali (Ayarlardan ac), ayrintili tercihler (ust anahtar kapaliyken alt anahtarlar pasif), sessiz saatler + saat secici, hata satiri + "Bu cihazda: Ders ve sinav hatirlatmalari".
- Duzeltilen (2 tur): sahte avatar ust cubuk, "rektorluk/acil durum ... SMS ve e-posta ile iletilir" notlari ve karti, "Bulut Esitleme", "Cihaz bildirim gecmisi", "Yemekhane menu bildirimi", "Tekrarlama Gunleri", "Kampus Bilgi Sistemi" alt bilgisi, "6/7 Aktif" sayaci silindi; birinci turda silinen "Sessiz saatleri ac" anahtari ikinci turda geri getirildi.
- Kalan eksik: sessiz saatler ekraninda saat secici acikken arka plan donuk, "Bitis" alani kismen ortuluyor; diger maddeler gorunur.

## 51 - Ortak sheet ve diyaloglar (6 ekran; sonradan S2'ye devredildi, ben zaten tamamlamistim)
- Proje: "BU Kampus Modal Overlays" https://stitch.withgoogle.com/u/3/projects/1533949826162683044 ; PNG/HTML: `C:\bu_design\stitch\51-ortak-sheetler\`
- Uretilen: kullanici sikayet sheet'i (5 neden + ek aciklama + Gonder), mesaj sikayet sheet'i + "Sikayetiniz alindi. Tesekkurler." toast'i, cikis diyalogu, tum cihazlardan cikis diyalogu, engelleme diyalogu (kullanici + gonderi metni + toast), tema sheet'i (Sistem/Acik/Koyu + onizleme kartlari).
- Duzeltilen (1 tur): arka planlardaki yasak icerik temizlendi: "Bakiye 142.50 / Yemek Hak / Ring Izni", SMS ile iki adimli dogrulama + cihaz listesi, @kullanici adlari ve dogrulama rozeti, "Kampus Haritasi Tam Ekran" sahte ust cubugu + avatar, "Yemekhane Bakiye / Ring Otobusu" satirlari; tema sheet'inden Aktif etiketi, Vazgec/Uygula ve X kaldirildi.
- Kalan eksik: yok (engelleme diyalogunda kullanici ve gonderi metni ayni ekranda iki satir halinde).
