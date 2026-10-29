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
