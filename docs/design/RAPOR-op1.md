# RAPOR - operator op1 (Stitch 01-07)

Stitch projesi: https://stitch.withgoogle.com/projects/7201355476070945525 ("BU Kampus Mobile App"). Disa aktarma: `C:\bu_design\stitch\<NN>-<ad>\` (zip + acilmis `x/<ekran>/screen.png` + `code.html`). Dogrulama: `code.html` metni yasak ifadelere (boun, Guney/Merkez Kampus, eduroam, e-Devlet, Hava, Resmi, Bingol Univ., v2.4, Login...) karsi taranir + ekran goruntusu incelenir.

## 01 Karsilama ve giris durumlari (5 ekran)
- Uretildi: Welcome + 4 Giris varyanti (hatali alanlar, istek siniri, dogrulama bekliyor, oturum kapatildi + ag hatasi).
- Stitch halusinasyonlari (duzeltildi, 1. tur ile 5 ekranda): sahte ust cubuk ("Login" basligi, geri oku, profil avatari), "Bingol Universitesi/Dijital Portal" etiketleri, "Canli Kampus Agi" karti, "OBS & E-Posta Yardimi" karti, Yemekhane/Kutuphane/Ulasim kisayol karolari, "BU Ag" rozeti, "Ogrenci Isleri ile gorusun" metni.
- 2. tur: istek siniri ekraninda "42 sn sonra tekrar deneyin." eksikti, eposta alaninda onay isareti ve "resmi ogrenci hesabi" metni vardi; duzeltildi.
- Kontrol listesi: tum maddeler gorunur (dil hapi TR/EN/AR, sonek + 226051015 yardim metni, alan hatalari, goz, mesgul dugme + geri sayim, dogrulama bandi, baska cihaz bildirimi, ag hatasi, Sifremi unuttum/Kayit ol). Eksik yok.

## 02 Kayit adimlari (6 ekran)
- Uretildi: Adim 1/2/3, e-posta dogrulama (OTP), bolum secici, sinif secici. Klasor: `C:\bu_design\stitch\02-kayit\`.
- Halusinasyon (duzeltildi): her ekranda ortada ust cubuk basligi ("Kayit Adim 1", "E Posta Dogrulama Kodu"...) + sag ustte kirmizi profil avatari; OTP ekraninda "BINGOL UNIVERSITESI GIRIS" hapi, "Yardim" baglantisi, "Bingol Universitesi Bilgi Islem Daire Baskanligi" dipnotu; sinif secicide listede olmayan "Secimi Tamamla" dugmesi.
- Duzeltme turu 1 temizlerken OTP'den "Yeniden gonder (42 sn)" ve "E-postayi degistir" satirini da silmisti; tur 2'de geri eklendi. Bolum seciciye "Bolum" basligi eklendi.
- Kontrol listesi: tam (ilerleme + "Adim n/3", sonek + yardimci metin + "+ etiketi" hatasi, sifre gucu Orta + 2 kural, OTP 6 kutu/Yapistir/hata/sayac/spam ipucu, fakulte gruplari, secili isaret, bos sonuc, yukleme hatasi + Yeniden dene, Hazirlik..Doktora).

## 03 Sifre sifirlama (5 ekran)
- Uretildi: sifremi unuttum (+ "Kod gonderildi" notu), kodu girin (OTP + sayac + E-postayi degistir), yeni sifre (guc "Guclu", iki alan, kurallar, hata), basari, hata durumlari (Sure doldu / Cok fazla deneme + 60 sn / Sunucuya ulasilamadi). Klasor: `C:\bu_design\stitch\03-sifre-sifirlama\`.
- Ek "Strict" cumlesi (ust cubuk/kurum etiketi/ekstra kart ekleme) istemlere eklendigi icin 02'deki ust cubuk halusinasyonu bu grupta cikmadi; yalniz "Ogrenci Bilgi ve Dogrulama Sistemi" dipnotu eklenmisti, silindi (silerken "Kod gonderildi." notu da gitti, 2. turda geri eklendi).
- Kontrol listesi: tam. Eksik yok.

## 04 Sistem tam ekran (5 ekran)
- Uretildi: Splash, Guncelleme gerekli (Yuklu 2.0.3 / Gerekli 2.1.0), Sistem bakimda (+ amber serit), Baglanti yok, Erisim kapatildi (ACCESS_BLOCKED). Klasor: `C:\bu_design\stitch\04-sistem-tam-ekran\`.
- Kontrol: HTML metni tarandi, yasak ifade yok; tum ogeler var. Halusinasyon yok (Strict cumlesi isi gordu).
- Splash'te kirmizi zemin altta ~40 px beyaz serit birakiyordu; 2 duzeltme turuyla tam yukseklik oldu (logo ortada, PNG 390x884). Not: Stitch tuval onizlemesi duzeltmeden sonra bir sure eski gorunur; dogrusu disa aktarilan screen.png/code.html.

## 05 Sistem seritler ve hata (6 ekran)
- Uretildi: Ana Sayfa uzerinde cevrimdisi seritleri, bakim + duyuru seritleri, guncelleme karti, on plan push banner (+2 mesaj birlesik); render hatasi; yapilandirma hatasi (API_BASE). Klasor: `C:\bu_design\stitch\05-sistem-seritler-hata\`.
- Halusinasyon (4 Ana Sayfa ekraninda, 1 tur ile duzeltildi): "Bogazici Kampus" baslik (BOUN), "Guney/Kuzey Kampus", hava sicakligi (18/14 C), "Bakiye / Bakiye Yukle / 48,50 TL / 28.50 TL", "Ring Servis", "Kutuphane Doluluk", "Kampusten Canli", "Ogrenci Isleri" ogesi. Hizli erisim 4 karoya (Yemek/Haberler/Kulupler/Etkinlikler) sabitlendi, baslik "BU Kampus + Bagimsiz ogrenci uygulamasi".
- Kalan kucuk eksik: menu kartlarindaki "Toplam 740 kcal" satiri yemek kalorileriyle tutarsiz (Stitch ayni toplami her ekrana yazdi); ust cubukta zil + profil simgesi var (referans Ana Sayfa'dan miras).
- Ayrica: istem kutusuna yapistirilan metindeki "bingol.edu.tr" Stitch'te otomatik "web sitesi" cipi olusturuyor ve Enter'i yutabiliyor; gonderim sonrasi ekranda cevrimi dogrulamak gerekir.

## 06 Izinler ve QR tarama (6 ekran)
- Uretildi: izin tanitimi (Adim 1/3), karisik izin durumlari (Adim 3/3), kamera izni alt sayfasi, QR tarayici, kamera reddedildi, manuel giris sonuclari. Klasor: `C:\bu_design\stitch\06-izinler-qr\`.
- Halusinasyon (1 tur ile duzeltildi): QR ekranlarinda "Qr Turnstile Scanner" / "Dining Hall Meal Pass Modal" ust cubugu + profil avatari; alt sayfanin arka planinda "Yemekhane Turnikesi", "Kuzey Kampus Kafeterya", "Bakiye 48,50 TL", "Hizli QR Gecis / temassiz gecis" (odeme/gecis kartina benziyordu; silindi, arka plan koyu QR tarayici oldu); "Kurulum" etiketi, "Gizlilik Oncelikli" hapi, ilk ekranda "Izin verildi" rozetleri (kodda gizli, gorunmuyor).
- Kontrol listesi: tam (3 izin karti + her birinde Izin ver/Simdi degil, Basla/Devam, Verildi/Reddedildi + Tekrar dene/Ayarlardan ac, alt sayfa, tarayici + el feneri + elle kod, kamera reddi, hata + basari geri bildirimi).

## 07 Sozlesmeler (6 ekran) - URETILDI, DUZELTMELER UYGULANAMADI
- Uretildi: zorunlu yeniden onay, ertelenebilir onay, red alt sayfasi, sozlesme listesi, belge okuyucu, bos/hata listesi. Klasor: `C:\bu_design\stitch\07-sozlesmeler\` (zip + png + code.html; uretilen ilk hali).
- Duzeltme istemleri (ust cubuk/kurum etiketi temizligi) uc kez gonderildi; ilk ikisi (uzun metin) hic gonderilmedi, ucuncusu (kisa) "Thinking..." gosterdi ama tuvalde ekranlar degismedi, ajan gunlugunde yeni yanit olusmadi. Stitch bu oturumda duzenleme istemlerini sessizce dusuruyor olabilir; sonraki operator once tek ekrana kisa bir duzeltme deneyip dogrulamali.
- 07'de HALA GECERLI eksikler (INDEX'te "eksik" yazildi): (1) 4 ekranda sahte ust cubuk "Event Detail Sheet"/"Emergency Assistance Modal" + kirmizi profil avatari; (2) red alt sayfasinin arka plani yanlis ("v2.4 Guncellemesi", "Tumunu Kabul Et", "Detaylari Incele", 14 Nisan 2025) - olmasi gereken: silikles tirilmis zorunlu onay ekrani; (3) ertelenebilir onayda "Hukuki Bildirim / Kampus Bilgi Guvenligi" ust etiketi; (4) liste ekraninda istenmeyen aciklama, e-posta bildirimi paragrafi ve "(c) 2026" dipnotu; (5) bos/hata ekraninda "0 Belge", "Arsivler senkronize edildi", alt paragraf; (6) okuyucuda altta "Resmi Dijital Yururluk Belgesi / Bingol Universitesi Hukuk Musavirligi" blogu, PDF indir ve "Okudum ve Anladim" satirlari, e-postali dipnot. Kontrol listesi ana ogeleri (4 belge satiri, onay kutusu + Kabul et/Kabul etmiyorum/Daha sonra, bos+hata satiri, markdown okuyucu) mevcut.
- Operasyon notlari: (a) istem kutusuna yapistirilan "bingol.edu.tr" Stitch'te web-sitesi cipi uretip Enter'i yutabiliyor; (b) coklu secim icin once bos tuvale tikla, sonra marquee surukle (shift+tik de calisir ama `keyboard.down('Shift')` ile); (c) disa aktarma: Export -> .zip -> Export dugmesi; zip icinde her ekranin `screen.png` + `code.html` + `DESIGN.md` var, yasak ifade taramasi `code.html` metniyle yapilabilir (`C:\bu_design\_tmp\scan.py`); (d) onizleme duzeltme sonrasi eski gorunebilir, dogrusu export'tur; (e) tuval yaklasik 33% yakinlastirmada; yeni uretilen satir otomatik gorunuma gelir.
