# Stitch raporu - op2 (istemler 14-20)

Stitch projesi: **BU Kampus Mobile B** - https://stitch.withgoogle.com/projects/9129019669928618679
PNG/zip klasoru: `C:\bu_design\stitch\<NN>-<ad>\` (zip + acilmis `screen.png`/`code.html`; her ekran ayri klasorde). Gruplar: 14-arama, 15-ana-yemek-bildirim, 16-haber-detay-bildirim, 17-gonderi-karti, 18-sohbet-liste, 19-sohbet-baloncuklar, 20-sohbet-baslik-yazma.

Yontem notu: Stitch istemleri kendi ozetine cevirip uygular; her grupta ilk uretim sonrasi 1-2 duzeltme turu yapildi (tum ekranlar secilip "Apply to all selected screens" istemi). Tum zip'ler duzeltmeden SONRA alindi. Her tur gonderi sonrasi yeniden uretilen ekranlar bekleyerek dogrulandi.

## 14 Arama (6 ekran) - tamamlandi
- Uretilen: bos sorgu+son aramalar, Tumu sonuclari (gruplu), Kisi, Kulup, Gonderi (2 sutun), yukleniyor/bos/hata/toast durumlari.
- Duzeltilen: "Campus Search" -> "Ara"; kisi satirindan e-posta ve "Bingol Universitesi" rozeti, #populer aramalar, "Kampusu Kesfet 84 Kulup/12 Etkinlik" sahte istatistigi, "Canli Indeks" rozeti, kulup alt baglantisi silindi; bos ekrandaki kirmizi hata seridi nötr ipucu yapildi.
- Halusinasyon: "Campus Search" Ingilizce baslik, #etiket, sahte istatistik, e-posta.
- Eksik: yok (kontrol listesi maddeleri gorunur).

## 15 Ana Sayfa/Yemek/Bildirim durumlari (6 ekran) - tamamlandi
- Duzeltilen: "Kuzey & Guney Yemekhanesi", "Merkez/Ana Yemekhane" (kampus ayrimi) ve "Ana Menu/Ozel Menu/Yogunluk" etiketleri, baslik "Yemekhane Menu Detayi" -> "Yemek listesi"/"Bildirimler", "Bingol Universitesi Kampus Rehberi", "Cevrimdisi" etiketi, "Besin Degeri Toplami" -> "Toplam", uydurma ortalama puan metni, "318 oy".
- Eksik/not: ikinci hizli erisim etiketi "Ders Pro..." kisaltilmis gorunuyor; bildirim ekraninda uc sutun tur etiketleri kucuk.
- Not: ayrica uretim sirasinda gelen tek basina yemek gorseli ekran degil, silindi.

## 16 Haber detay/Bildirim bos-hata (5 ekran) - tamamlandi
- Duzeltilen: "Announcement It..." basligi (Haber/Bildirimler), "Onizleme Modu v-2.4", ERR_CONN_TIMEOUT, Bogazici Universitesi Kampus Servisleri v3.4 alt bilgisi, otomatik yeniden baglanma karti, "Onerilen Bildirim Ayarlari", "Ilgili baglantilar", senkronizasyon satirlari, bildirim ekranlarindaki paylas/uc nokta simgeleri.
- Halusinasyon: baska universite adi + surum no, hata kodu, "simulasyon" etiketleri.
- Eksik: kapak gorselinin altinda "ITU Kongre & Kultur" yazisi; Duyuru ekraninin PNG'sinde serif yazi tipi (HTML ciktisinda yazi tipi yuklenmemis); haber metni uzun.

## 17 Gonderi karti/begeni (6 ekran) - tamamlandi
- Duzeltilen: "Post Details" -> "Gonderi"; "Abdullah Gul Universitesi" konum satiri silindi.
- Eksik: ornek foto uzerinde bina tabelasinda "ABDULLAH GUL UNIVERSITY KUTUPHANE" yazisi goruluyor (Stitch uretilmis gorsel, metinle kaldirilamadi).

## 18 Sohbet liste durumlari (6 ekran) - tamamlandi
- Duzeltilen: "Kampus Agi Aktif" seridi, "BU Kampus Ag Modu", "DURUM/ARAMA SIMULASYONU" etiketleri, "Bogazici Eduroam" baglantisi ve "Bogazici Universitesi" alt bilgisi (eduroam + baska universite), "Mesajlar 0 Aktif" -> "Sohbetler".
- Eksik: arsiv ekraninda hem uygulama basligi hem "Arsiv" ust cubugu gorunuyor; uzun basma menusunde fazladan "Okunmamis/Ders Gruplari" cipleri.

## 19 Sohbet baloncuklari (6 ekran) - tamamlandi
- Duzeltilen: "Chat Conversation"/"Study Group Chat" -> kisi/grup adi, "Merkez Kutuphane Wi-Fi" mesaji (Wi-Fi) normal mesaja, "AKTIF OTURUM" etiketi.
- Eksik: medya ekraninda mesaj altinda beğeni/yanit alt cubugu (listede yok); ust cubukta "Cevrimici" noktasi kirmizi.

## 20 Sohbet baslik/yazma alani (6 ekran) - tamamlandi
- Duzeltilen: ekranlar "ozellik tablosu/spec sheet" gibi uretilmisti (Mod 1/Durum 1 etiketleri, ornek kartlar); etiketler silindi, "Sohbet Detay" -> gercek ad, etkinlik odasindaki "Giris Icin QR Kod" bileti kaldirildi.
- Eksik: arama modu ekraninda baslik "Ali Kaya" (diger ekranlar Elif Yildiz); "yaziyor" bilgisi ust cubukta profil dugmesiyle ust uste biniyor; etkinlik odasinda "Merkez Amfi Tiyatro" konum satiri.

## Genel
- Tekrar eden halusinasyonlar: Ingilizce basliklar (Campus Search, Post Details, Chat Conversation), baska universite adlari (Bogazici, Abdullah Gul, ITU), eduroam/Wi-Fi/ag durumu, "simulasyon/onizleme" etiketleri, surum numaralari, kampus/yemekhane ayrimi.
- Stitch bir tur sonunda ayrica tek basina yan gorsel (stock fotograf) ekrani uretebiliyor; bunlar silindi.
- Kalan: 21-26 op6'ya devredildi/yapilmadi. Her grup en fazla 2 duzeltme turu aldi; yukaridaki "Eksik" notlari INDEX'e ayrica yazilmadi.
