# RAPOR s4 (Stitch istemleri 36-39, 46) - hesap /u/1/

Not: Stitch kok adresleri `https://stitch.withgoogle.com/u/1/projects/<ID>`. Aktarma klasoru `C:\bu_design\stitch\<NN>-<ad>\` (export.zip + her ekran icin screen.png + code.html). Export'ta PNG'ler ilk denemede "FIFE Image failed to fetch" (gecersiz) geldi; ikinci export gecerli PNG verdi.

## 36 - Etkinlik listeleri (6 ekran, `C:\bu_design\stitch\36-etkinlik-listeleri\`)
- Proje: "BU Kampus Event Management UI" - https://stitch.withgoogle.com/u/1/projects/10712957761678149545
- Uretilen: Keşfet (takvim + 2 kart), Keşfet bos gun + kesinti notu + Kayit kapali/Iptal/Kontenjan doldu etiketleri, Etkinliklerim Yaklasan, Gecmis, Olusturduklarim (Acik/Onay bekliyor/Reddedildi + secenek menusu + bos durum), Profil > Etkinliklerim.
- Duzeltilen (1 tur, 6 ekran birden): baslik "Etkinlik Detay" -> "Etkinlikler"/"Etkinliklerim"; paylas/yer imi ikonlari; Keşfet'e Yoklama + "+" dugmeleri; "Güz Dönemi", "KAMPÜS TAKVİMİ", "Arşiv Kayıtları", "Kulüp Lideri Paneli", "Yönetim Masası", "Bilet & Giriş Kartı", "Bilet Hazır", "Katılım QR Kodu", "Sertifika Alındı", "UI Durumu", "BOŞ DURUM ÖNİZLEMESİ", "Yedek Listeye Yaz", "Kayıt Ol", "resmi kampüs" silindi; kesinti notu kirmizidan amber'e.
- Stitch halusinasyonlari: yanlis baslik (X Detay kalibi), paylas/bookmark, bilet/sertifika, "Yönetim Masası"/panel kartlari, "UI Durumu" etiketleri; ayrica oneri chip'ine istemeden tiklamayla ekstra "Etkinlik Oluştur" ekrani + tasarim sistemi uretildi (ekran silindi; "Academic Community Pulse" tasarim sistemi tuvalde kaldi).
- Kalan eksik: Olusturduklarim'da "Düzelt ve Yeniden Gönder" dugmesi ve "Henüz bir etkinlik oluşturmadın mı?" metni fazla/farkli; açık menü kartın üstüne biniyor; Keşfet'te "Yaklaşan Diğer Günler / Önemli duyuru ve durum bildirimleri" ek başlık; Gecmis'te "Tamamlandı" etiketi; Profil ekraninda "2 bekleyen istek" yalniz Olusturduklarim sekmesi gosterilmediginden gorunmuyor; Yaklasan ekraninda bos durum karti listeyle ayni ekranda.

## 37 - Etkinlik listesi durumlari + diyaloglar (6 ekran, `C:\bu_design\stitch\37-etkinlik-liste-durumlari-diyaloglar\`)
- Proje: ayni proje (36 ile) https://stitch.withgoogle.com/u/1/projects/10712957761678149545
- Uretilen: Yukleniyor iskeleti, Bos durumlar + "kulubun yoneticisi olmalisin" karti (Kuluplere goz at), Cevrimdisi seridi + "Yuklenemedi, tekrar dene" + "Bu etkinligin kayitlari kapali." toast'i, "Katilimdan ayril" diyalogu + "Katilimdan ayrildin." toast, "Etkinligi iptal et" diyalogu, "Onaya gonderildi" diyalogu.
- Duzeltilen (2 tur): "Kampus etkinlikleri hazirlaniyor/Senkronize ediliyor", "DURUM OZETI/3 Durum Onizlemesi", "Yetki Durumu", "Hemen Basla", "Yetki Talep Et", sahte onbellek etkinlik listesi (2025 tarihli), "Ortalama onay suresi ~2 saat" silindi; 2. turda ilk duzeltmede dusen hata toast'i geri eklendi.
- Halusinasyonlar: ek etiketler/durum ozeti, sahte onbellek kartlari, onay suresi; Stitch duzeltmede istenen ogeyi (toast) dusurebiliyor.
- Kalan eksik: iptal diyalogu ardindaki "Kayitlar kapatildi/yeniden acildi/iptal edildi" toast ornekleri arka planda bulanik ve okunmaz; hata ekraninda toast soluk (animasyon ani); katilimdan ayril arka plani uydurma "Kayitli Etkinlikler Kasim 2024" listesi.
- Not: duzenlenmemis ekranlarin (iki diyalog) export PNG'si "FIFE Image failed to fetch" geldi; screen.png olarak code.html'in yerel render goruntusu kaydedildi (duzenlenen ekranlarda export PNG'si gecerli geliyor).

## 38 - Etkinlik detay durumlari (6 ekran, `C:\bu_design\stitch\38-etkinlik-detay-durumlari\`)
- Proje: "BU Kampus Event States" - https://stitch.withgoogle.com/u/1/projects/5552475487246307951
- Uretilen: Kayitlar acik (Katil + Ilgileniyorum), Katiliyor (Etkinliklerimde + Katilimdan ayril + Yoklama kutusu), Ilgileniyor, Kontenjan dolu (Katil gri, Ilgileniyorum aktif), Kayitlar kapali, Iptal edildi (kirmizi hap, buton/sohbet yok). Her ekranda "Duzenleyen: Muzik Kulubu", kontenjan 34/50 (dolu ekranda 50/50), sayac, sohbet satiri.
- Duzeltilen (2 tur + ekran yeniden uretimi): baslik "Event Detail" -> "Etkinlik"; "Merkez Kampus/Rektorluk Arkasi", "Canli Muzik & Sahne", "Ucretsiz Etkinlik", "1.2k Goruntulenme", "Zorunlu/Aktif/Resmi Kulup", #etiketler, harita kartlari, "Yedek Sira Kapali", hava durumu metni silindi; kapak fotosundaki afis/yazi kaldirildi; QR kartı sade "Yoklama" kartina cevrildi.
- Halusinasyonlar: kapak fotosunda afis ("SPRING JAM 24"), "Merkez Kampus", hashtag, harita karti, "Zorunlu" etiketi, "Resmi Kulup", goruntulenme sayaci, hava metni, QR kapi gorevlisi metni.
- Kalan eksik: "Kayitlar acik" ve "Katiliyor" ekranlarinda kapak gorseli yuklenmedi (gri "img" yer tutucu); Katiliyor'da "Katilimdan ayril" dugmesi sayfa sonunda (sticky degil); Kayitlar kapali ekraninda iki pasif dugme yerine tek "Kayitlar Kapandi", "Kontenjan Dolu/Doldu" etiketi (34/50) tutarsiz, uydurma "kapilar 13:30" bilgi kutusu; Iptal edildi'de "Duzenleyen" satiri kirik, "Program Bilgileri" bolumu; Kayitlar kapali ve Kontenjan dolu ekranlarinda "⋯" rapor menusu yalniz ikon (acik menu gosterilmedi).
- Not: ilk export'ta (duzeltmeden once) PNG'ler gecersiz geldi; son export (g38b) gecerli PNG + code.html.
