# RAPOR op3 (Stitch operatoru op3)

Stitch projesi: "BU Kampus Mobile C" (Stitch'in verdigi ilk ad "BU Kampus Club Management UI" idi, yeniden adlandirildi). Adres: https://stitch.withgoogle.com/projects/5802123275765710897
PNG klasoru (repo disi): C:\bu_design\stitch\27-kulup-yonetimi ... 32-anket-detay-oy-turleri (Stitch zip yerine, ekran HTML'i ayri sayfada render edilip 390 px genislikte tam sayfa PNG alindi; en az PNG kurali saglandi, zip yok).
Kapsam: 27-39. Tamamlanan: 27-31 (duzeltmeli). 32 uretildi ama duzeltme yapilamadi. 33-39 baslanmadi. Neden: Stitch "Generation limited, check your credits in settings" (kota) hatasi verdi; OPERATOR.md geregi durdum.

## 27 Kulup yonetimi (6 ekran)
Uretilen: uyeler listesi, uye islem sheet + onay diyaloglari, basvurular, bos/hata durumlari, kulup kur, kulubu duzenle. Duzeltilen (1 tur): ASCII bozuk basliklar (Kulup Yonetimi, Etkinlik Olustur, Ilan Duzenle, Duyuru Yayimla, Moderasyon Paneli) -> Uyeler/Basvurular/Kulup kur/Kulubu duzenle; Eduroam metni, davet/filtre seritleri, logo yerine resmi arma gorseli kaldirildi; yasaklama diyaloglari eklendi. Halusinasyon: baslikta uydurma ekran adlari, Eduroam, kapak fotografi dolu "bos" yukleme alani. Kalan eksik: bolum adlari kisaltma ("2...."), kategori yer tutucusu kesik, "Gizli" ipucu yalniz secili durumda, arka plandaki liste filtre cipleri.

## 28 Kulup detay uyelik durumlari (6 ekran)
Ziyaretci acik/onayli, istek bekliyor, uye, yonetici (amber banner + acilir menu), yasakli/kullanilamiyor. Duzeltilen: "RESMI TOPLULUK"/"Resmi Kulup" rozetleri, @bu.robotik, yorum sayisi/kaydet ikonu, "+12%" sahte istatistik, 482 uye -> 86. Kalan eksik: yonetici ekraninda banner ust cubukla ust uste biniyor; yasakli ekranda Katilamazsin dugmesi var, uye menusu sade.

## 29 Kulup sheet ve diyaloglar (6 ekran)
Katilma istegi sheet (hata durumlu), kulupten ayril, sahip ayrilamaz, kulubu sil (ad dogrulamali), onay bekleme diyalogu, gonderi islemleri. Duzeltilen: "resmi universite kulubu", "Resmi Ogrenci Toplulugu", sahte istatistik kutulari, "12 yorum". Kalan eksik: gonderi islemlerinde "Sikayet et" (Sikayet, a-sapkasiz), "Gonderi silindi" toast'u gorunmuyor.

## 30 Kuluplerim (3 ekran)
Liste, satir islem sheet, bos+hata. Duzeltilen: baslik "My Clubs" -> "Kuluplerim", ozet karti/SKS Daire Baskanligi notlari, SISTEM DURUMU kartlari, hata kodu. Kalan eksik: yok onemli.

## 31 Anket liste/olustur (6 ekran)
Acik liste, kapanan+katildiklarim, bos/hata + kulup varyanti, anket olustur ust/alt, tarih-saat secici. Duzeltilen: "Anketler Listesi" -> "Anketler", "Anket Olustur" -> "Anket olustur", POPULER rozeti, "Merkezi/Merkez Kutuphane", 3 sekmenin bos metinleri eklendi, dogrulama metinleri. Kalan eksik: tarih/saat secici diyaloglarinda "Iptal/Tamam" dugmeleri ve takvimin alt satiri kesik; 26. ekranda yayinla cubugu kismen icerigi ortuyor olabilir.

## 32 Anket detay oy turleri (6 ekran) - duzeltme yapilmadi
Uretildi: tek secim, coklu secim, puanlama, sirali secim, kulup anketleri sekmesi, oyu degistir. Tespit edilen ve duzeltilmeyen (kota): basliklar Ingilizce "Poll Details"/"Club Poll Vote" (dogrusu "Anket"), "Genel Kampus" cipi, puanlama ekraninda kapak foto + "BINGOL UNIVERSITESI / Merkezi Kutuphane Kompleksi" + "452 oy" + "Ogrenci Konseyi Bilgilendirmesi" karti, not metninde "rektorluk/kulup temsilcisi", kullanici avatar ikonu. Hazir duzeltme istemleri: .playwright-mcp/op3/t_q28..t_q33 (repo disinda calisma dosyasi, commit yok).

## 33-39
Baslanmadi (kota).

## Teknik notlar (sonraki operator icin)
- Stitch'te yeni uretim sonrasi canvas sanallastirilir; ekran sirasi sayfa yenilenince karisir. Ekrani basligiyla bul. Ekran HTML'i iframe srcdoc'tan okunup ayri sayfada render edilerek PNG alinabilir (390 px).
- Ekran secimi icin kucuk (11%) canvas'ta ilk tiklama bazen secmiyor; iki kez tikla, ekran 'chip'inin ciktigini dogrula. Alttaki satirlar istem kutusunun altinda kalabilir; wheel ile kaydir.
- Istem gonderimi sessizce basarisiz olabilir (Enter yutulur, kota); gonderimden sonra 'Thinking' gorundugunu dogrula.
- Duzeltmeler sunucuya kaydediliyor; sayfa yenilemesiz canvas'ta eski surum gorunebilir (yenile ve yeniden oku).
