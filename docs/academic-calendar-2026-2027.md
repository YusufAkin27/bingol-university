# Bingöl Üniversitesi 2026-2027 akademik takvimi (PDF doğrulama raporu)

Kaynak: <https://oidb.bingol.edu.tr/akademik-takvim/> → `/media/57058/2026-2027-egitim-ogretim-yili-akademik-takvimi.pdf` (Word 2013 çıktısı, 1 sayfa, 17.08.2026; indirildi 2026-11-01). Sayfada bu takvim için 'güncel/değişiklik' duyurusu yoktur.

**Durum:** Bu takvim uygulamada ZATEN yüklüdür: `backend/src/main/resources/db/migration/V380__academic_calendar_2026_2027.sql` (herkese açık, yayında, tüm gün, bitiş 23:59 İstanbul). Bu belge V380'i PDF ile satır satır karşılaştırır: **59 olay, V380'de 59 satır, tarih/tür/başlık farkı YOK (birebir)**.

## Yöntem ve Türkçe karakter notu

- `pdftotext -enc UTF-8` ile çıkarıldığında ş, ğ, İ, ı, Ö, Ü, Ç kayıpsız gelir (önceki araştırmadaki bozulma Windows konsol kod sayfası kaynaklıdır; PDF'in kendisi sağlam). Yine de her satır PDF'in görüntüsüyle (render) elle karşılaştırıldı.
- PDF'in metin katmanında iki tablo (resmî tatiller, yaz okulu) etiket/tarih sütunlarını bir satır kaydırır; doğru eşleme görüntüden alındı (yaz okulu tarihleri kronolojik; tatil günleri hafta günü sütunuyla doğrulandı). Bu kayma yüzünden otomatik metin ayrıştırma bu iki tabloda YANLIŞ eşleme verir; yeniden üretilirken görüntüyle kontrol edin.
- Güven düzeyi: yüksek = metin + görüntü + hafta günü tutarlı; orta = tablo kayması/yazım hatası nedeniyle görüntüden eşlendi; düşük = dış kaynakla çelişiyor.

## Tür eşlemesi (mevcut modül: `AcademicCalendarService.KINDS`)

`DONEM_BASLANGIC` (derslerin başlaması), `DERS_KAYIT` (kayıt/ödeme/danışman onayı/yaz okulu müracaatı), `VIZE`, `FINAL`, `BUT`, `TATIL` (kullanılmadı), `RESMI_TATIL`, `DIGER` (ders ekleme-bırakma, tek ders, ek sınav, yatay geçiş, mezuniyet, dönem sonu). Dönem (güz/bahar/yaz) ayrı alan DEĞİL, başlık önekidir (`Güz:`, `Bahar:`, `Yaz okulu:`); bölüm kapsamı (`scope_department`) boş = herkes.

## Olaylar (tarih sırasına göre)

| # | Dönem | Tür | Uygulama başlığı | Başlangıç | Bitiş | PDF ham metni (etiket — tarih) | Güven | Not |
|---|---|---|---|---|---|---|---|---|
| 1 | Yatay geçiş | `DIGER` | Ek madde-1 yatay geçiş (güz): Başvuru | 2026-08-01 Cum | 2026-08-15 Cum | Ek madde-1 yatay geçiş (güz, lisans-ön lisans) / Başvuru — 01.08.2026 - 15.08.2026 | yüksek | Tablo; sütun eşlemesi görüntüden doğrulandı. |
| 2 | Yatay geçiş | `DIGER` | Kurumlar arası yatay geçiş (güz): Başvuru | 2026-08-03 Paz | 2026-08-07 Cum | Kurumlar arası yatay geçiş (güz, lisans-ön lisans) / Başvuru — 03.08.2026 - 07.08.2026 | yüksek | Tablo; sütun eşlemesi görüntüden doğrulandı. |
| 3 | Yatay geçiş | `DIGER` | Kurumlar arası yatay geçiş (güz): Sonuçların ilanı | 2026-08-17 Paz | — | Kurumlar arası yatay geçiş (güz, lisans-ön lisans) / Sonuçların İlanı — 17.08.2026 | yüksek | Tabloda iki sütuna yayılan hücre. |
| 4 | Yatay geçiş | `DIGER` | Kurumlar arası yatay geçiş (güz): Asıl kayıt | 2026-08-19 Çar | 2026-08-20 Per | Kurumlar arası yatay geçiş (güz, lisans-ön lisans) / Asıl Kayıt — 19.08.2026 - 20.08.2026 | yüksek | Tablo; sütun eşlemesi görüntüden doğrulandı. |
| 5 | Yatay geçiş | `DIGER` | Ek madde-1 yatay geçiş (güz): Sonuçların ilanı | 2026-08-21 Cum | — | Ek madde-1 yatay geçiş (güz, lisans-ön lisans) / Sonuçların İlanı — 21.08.2026 | yüksek | Tabloda iki sütuna yayılan hücre. |
| 6 | Güz | `DERS_KAYIT` | Güz: Yeni kayıtlar | 2026-08-24 Paz | 2026-08-28 Cum | Yeni Kayıtlar — 24-28 Ağustos 2026 | yüksek |  |
| 7 | Yatay geçiş | `DIGER` | Kurumlar arası yatay geçiş (güz): Yedek kayıt | 2026-08-25 Sal | — | Kurumlar arası yatay geçiş (güz, lisans-ön lisans) / Yedek Kayıt — 25.08.2026 | yüksek | Tablo; sütun eşlemesi görüntüden doğrulandı. |
| 8 | Yatay geçiş | `DIGER` | Ek madde-1 yatay geçiş (güz): Asıl kayıt | 2026-08-25 Sal | 2026-08-26 Çar | Ek madde-1 yatay geçiş (güz, lisans-ön lisans) / Asıl Kayıt — 25.08.2026 - 26.08.2026 | yüksek | Tablo; sütun eşlemesi görüntüden doğrulandı. |
| 9 | Yatay geçiş | `DIGER` | Ek madde-1 yatay geçiş (güz): Yedek kayıt | 2026-08-28 Cum | — | Ek madde-1 yatay geçiş (güz, lisans-ön lisans) / Yedek Kayıt — 28.08.2026 | yüksek | Tablo; sütun eşlemesi görüntüden doğrulandı. |
| 10 | Güz | `DERS_KAYIT` | Güz: Ders kayıtları | 2026-09-14 Paz | 2026-09-18 Cum | Ders Kayıtları — 14-18 Eylül 2026 | yüksek |  |
| 11 | Güz | `DERS_KAYIT` | Güz: Katkı payı ve öğrenim ücretlerinin ödenmesi | 2026-09-14 Paz | 2026-09-18 Cum | Katkı Payları ve Öğrenim Ücretlerinin Ödenmesi — 14-18 Eylül 2026 | yüksek |  |
| 12 | Güz | `DERS_KAYIT` | Güz: Danışmanların ders kayıtlarını onaylaması | 2026-09-14 Paz | 2026-09-21 Paz | Danışmanların Ders Kayıtlarını Onaylaması — 14-21 Eylül 2026 | yüksek |  |
| 13 | Güz | `DIGER` | Yabancı dil muafiyet sınavı | 2026-09-18 Cum | — | Yabancı Dil Muafiyet Sınavı — 18 Eylül 2026 | yüksek |  |
| 14 | Güz | `DONEM_BASLANGIC` | Güz: Derslerin başlaması | 2026-09-21 Paz | — | Derslerin Başlaması — 21 Eylül 2026 | yüksek |  |
| 15 | Güz | `DIGER` | Güz: Ders ekleme-bırakma (danışman gözetiminde) | 2026-10-02 Cum | — | Ders Ekleme- Bırakma (Danışmanlar Gözetiminde Yapılacaktır) — 02 Ekim 2026 | yüksek |  |
| 16 | Resmî tatil | `RESMI_TATIL` | Cumhuriyet Bayramı | 2026-10-28 Çar | 2026-10-29 Per | 29 Ekim Cumhuriyet Bayramı — 28-29 Ekim 2026 (Çarşamba-Perşembe; 1,5 Gün) | yüksek | 28 Ekim yarım gün (arife). |
| 17 | Güz | `VIZE` | Güz: Ara sınavlar | 2026-11-07 Cum | 2026-11-15 Paz | Ara Sınavlar — 07-15 Kasım 2026 | yüksek | Aralık hafta sonlarını (7-8, 14-15 Kasım) içerir; PDF'te böyle. |
| 18 | Resmî tatil | `RESMI_TATIL` | Yılbaşı tatili | 2027-01-01 Cum | — | Yılbaşı Tatili — 01 Ocak 2027 (Cuma; 1 Gün) | yüksek |  |
| 19 | Güz | `DIGER` | Güz: Derslerin sona ermesi | 2027-01-03 Paz | — | Derslerin Sona Ermesi — 03 Ocak 2027 | yüksek | Pazar günü; PDF'te böyle. |
| 20 | Güz | `FINAL` | Güz: Yarıyıl sonu sınavları | 2027-01-04 Paz | 2027-01-15 Cum | Yarıyıl Sonu Sınavları — 04-15 Ocak 2027 | yüksek |  |
| 21 | Yatay geçiş | `DIGER` | Ek madde-1 yatay geçiş (bahar): Başvuru | 2027-01-11 Paz | 2027-01-15 Cum | Ek madde-1 yatay geçiş (bahar, lisans-ön lisans) / Başvuru — 11.01.2027 - 15.01.2027 | yüksek | Tablo; sütun eşlemesi görüntüden doğrulandı. |
| 22 | Yatay geçiş | `DIGER` | Kurumlar arası yatay geçiş (bahar, ön lisans): Başvuru | 2027-01-18 Paz | 2027-01-22 Cum | Kurumlar arası yatay geçiş (bahar, yalnız ön lisans) / Başvuru — 18.01.2027 - 22.01.2027 | yüksek | Tablo; sütun eşlemesi görüntüden doğrulandı. |
| 23 | Yatay geçiş | `DIGER` | Ek madde-1 yatay geçiş (bahar): Sonuçların ilanı | 2027-01-22 Cum | — | Ek madde-1 yatay geçiş (bahar, lisans-ön lisans) / Sonuçların İlanı — 22.01.2027 | yüksek | Tabloda iki sütuna yayılan hücre. |
| 24 | Güz | `BUT` | Güz: Bütünleme sınavları | 2027-01-25 Paz | 2027-01-29 Cum | Bütünleme Sınavları — 25-29 Ocak 2027 | yüksek |  |
| 25 | Yatay geçiş | `DIGER` | Ek madde-1 yatay geçiş (bahar): Asıl kayıt | 2027-01-26 Sal | 2027-01-27 Çar | Ek madde-1 yatay geçiş (bahar, lisans-ön lisans) / Asıl Kayıt — 26.01.2027 - 27.01.2027 | yüksek | Tablo; sütun eşlemesi görüntüden doğrulandı. |
| 26 | Yatay geçiş | `DIGER` | Ek madde-1 yatay geçiş (bahar): Yedek kayıt | 2027-01-29 Cum | — | Ek madde-1 yatay geçiş (bahar, lisans-ön lisans) / Yedek Kayıt — 29.01.2027 | yüksek | Tablo; sütun eşlemesi görüntüden doğrulandı. |
| 27 | Yatay geçiş | `DIGER` | Kurumlar arası yatay geçiş (bahar, ön lisans): Sonuçların ilanı | 2027-01-29 Cum | — | Kurumlar arası yatay geçiş (bahar, yalnız ön lisans) / Sonuçların İlanı — 29.01.2027 | yüksek | Tabloda iki sütuna yayılan hücre. |
| 28 | Yatay geçiş | `DIGER` | Kurumlar arası yatay geçiş (bahar, ön lisans): Asıl kayıt | 2027-02-02 Sal | 2027-02-03 Çar | Kurumlar arası yatay geçiş (bahar, yalnız ön lisans) / Asıl Kayıt — 02.02.2027 - 03.02.2027 | yüksek | Tablo; sütun eşlemesi görüntüden doğrulandı. |
| 29 | Güz | `DIGER` | Güz: Tek ders sınavı başvurusu son gün | 2027-02-03 Çar | — | Tek Ders Sınavı İçin Başvuruların Son Günü — 03 Şubat 2027 | yüksek |  |
| 30 | Güz | `DIGER` | Güz: Tek ders sınavı | 2027-02-05 Cum | — | Tek Ders Sınavı — 05 Şubat 2027 | yüksek |  |
| 31 | Yatay geçiş | `DIGER` | Kurumlar arası yatay geçiş (bahar, ön lisans): Yedek kayıt | 2027-02-05 Cum | — | Kurumlar arası yatay geçiş (bahar, yalnız ön lisans) / Yedek Kayıt — 05.02.2027 | yüksek | Tablo; sütun eşlemesi görüntüden doğrulandı. |
| 32 | Bahar | `DERS_KAYIT` | Bahar: Ders kayıtları | 2027-02-08 Paz | 2027-02-12 Cum | Ders Kayıtları — 08-12 Şubat 2027 | yüksek |  |
| 33 | Bahar | `DERS_KAYIT` | Bahar: Katkı payı ve öğrenim ücretlerinin ödenmesi | 2027-02-08 Paz | 2027-02-12 Cum | Katkı Payları ve Öğrenim Ücretlerinin Ödenmesi — 08-12 Şubat 2027 | yüksek |  |
| 34 | Bahar | `DERS_KAYIT` | Bahar: Danışmanların ders kayıtlarını onaylaması | 2027-02-08 Paz | 2027-02-15 Paz | Danışmanların Ders Kayıtlarını Onaylaması — 08-15 Şubat 2027 | yüksek |  |
| 35 | Bahar | `DONEM_BASLANGIC` | Bahar: Derslerin başlaması | 2027-02-15 Paz | — | Derslerin Başlaması — 15 Şubat 2027 | yüksek |  |
| 36 | Bahar | `DIGER` | Bahar: Ders ekleme-bırakma (danışman gözetiminde) | 2027-02-26 Cum | — | Ders Ekleme-Bırakma (Danışmanlar Gözetiminde Yapılacaktır) — 26 Şubat 2027 | yüksek |  |
| 37 | Resmî tatil | `RESMI_TATIL` | Ramazan Bayramı | 2027-03-08 Paz | 2027-03-11 Per | Ramazan Bayramı — 08-11 Mart 2027 (Pazartesi-Perşembe; 3,5 Gün) | yüksek | 8 Mart arife (yarım gün), bayram 9-11 Mart; Diyanet takvimiyle uyumlu. |
| 38 | Bahar | `VIZE` | Bahar: Ara sınavlar | 2027-04-10 Cum | 2027-04-18 Paz | Ara Sınavlar — 10-18 Nisan 2027 | yüksek | Aralık hafta sonunu (17-18 Nisan) içerir; PDF'te böyle. |
| 39 | Resmî tatil | `RESMI_TATIL` | Ulusal Egemenlik ve Çocuk Bayramı | 2027-04-23 Cum | — | Ulusal Egemenlik ve Çocuk Bayramı — 23 Nisan 2027 (Cuma; 1 Gün) | yüksek |  |
| 40 | Resmî tatil | `RESMI_TATIL` | Emek ve Dayanışma Günü | 2027-05-01 Cum | — | Emek ve Dayanışma Günü — 01 Mayıs 2027 (Cumartesi; 1 Gün) | yüksek |  |
| 41 | Resmî tatil | `RESMI_TATIL` | Kurban Bayramı | 2027-05-15 Cum | 2027-05-18 Sal | Kurban Bayramı — 15-18 Mayıs 2027 (Cumartesi-Salı; 4,5 Gün) | düşük | UYUŞMAZLIK: Diyanet takvimine göre arife 15 Mayıs Cumartesi (yarım gün), bayram 16-19 Mayıs (Pazar-Çarşamba). PDF '15-18' diyor ama 4,5 gün süresi 15 (yarım)+16+17+18+19 ile uyumlu; 19 Mayıs ayrı satırda zaten tatil. Üniversiteden teyit gerekli. |
| 42 | Resmî tatil | `RESMI_TATIL` | Atatürk'ü Anma, Gençlik ve Spor Bayramı | 2027-05-19 Çar | — | Atatürk'ü Anma Gençlik ve Spor Günü — 19 Mayıs 2027 (Çarşamba; 1 Gün) | yüksek | Kurban Bayramı'nın son gününe denk gelir (Diyanet). |
| 43 | Bahar | `DIGER` | Mezuniyet törenleri | 2027-05-31 Paz | 2027-06-04 Cum | Mezuniyet Törenleri — 31 Mayıs-04 Haziran 2027 | yüksek |  |
| 44 | Bahar | `DIGER` | Bahar: Derslerin sona ermesi | 2027-06-06 Paz | — | Derslerin Sona Ermesi — 06 Haziran 2027 | yüksek | Pazar günü; PDF'te böyle. |
| 45 | Bahar | `FINAL` | Bahar: Yarıyıl sonu sınavları | 2027-06-07 Paz | 2027-06-18 Cum | Yarıyıl Sonu Sınavları — 07-18 Haziran 2027 | yüksek |  |
| 46 | Bahar | `BUT` | Bahar: Bütünleme sınavları | 2027-06-28 Paz | 2027-07-02 Cum | Bütünleme Sınavları — 28 Haziran-02 Temmuz 2027 | yüksek |  |
| 47 | Yaz okulu | `DERS_KAYIT` | Yaz okulu: Müracaat | 2027-07-05 Paz | 2027-07-06 Sal | Yaz Okulu Müracaatı — 05-06 Temmuz 2027 | orta | PDF metin katmanında etiket-tarih satırları bir satır kaymış; görüntüden satır eşlemesi doğrulandı (tarihler kronolojik). |
| 48 | Bahar | `DIGER` | Bahar: Tek ders sınavı başvurusu son gün | 2027-07-07 Çar | — | Tek Ders Sınavı İçin Başvuruların Son Günü — 07 Temmuz 2027 | yüksek |  |
| 49 | Yaz okulu | `DERS_KAYIT` | Yaz okulu: Kesin ders kaydı ve ücret yatırılması | 2027-07-08 Per | 2027-07-09 Cum | Kesin Ders Kaydı ve Ücret Yatırılması — 08-09 Temmuz 2027 | orta | Aynı kayma notu. |
| 50 | Bahar | `DIGER` | Bahar: Tek ders sınavı | 2027-07-09 Cum | — | Tek Ders Sınavı — 09 Temmuz 2027 | yüksek |  |
| 51 | Yaz okulu | `DONEM_BASLANGIC` | Yaz okulu: Derslerin başlaması | 2027-07-12 Paz | — | Derslerin Başlaması — 12 Temmuz 2027 | orta | Aynı kayma notu. |
| 52 | Bahar | `DIGER` | 1. ek sınavlar (azami öğrenim süresini dolduranlar) | 2027-07-12 Paz | 2027-07-16 Cum | 1. Ek Sınavlar (Azami öğrenim süresini tamamlayan öğrenciler için) — 12-16 Temmuz 2027 | yüksek | 15 Temmuz (resmî tatil, Perşembe) aralığın içinde; PDF'te ayrıca belirtilmemiş. |
| 53 | Resmî tatil | `RESMI_TATIL` | 15 Temmuz Demokrasi ve Milli Birlik Günü | 2027-07-15 Per | — | 15 Temmuz Demokrasi ve Milli Birlik Günü — 15 Temmuz 2027 (Perşembe; 1 Gün) | yüksek |  |
| 54 | Bahar | `DIGER` | 2. ek sınavlar (azami öğrenim süresini dolduranlar) | 2027-07-26 Paz | 2027-07-30 Cum | 2. Ek Sınavlar (Azami öğrenim süresini tamamlayan öğrenciler için) — 26-30 Temmuz 2027 | yüksek |  |
| 55 | Yaz okulu | `DIGER` | Yaz okulu: Derslerin bitişi | 2027-08-27 Cum | — | Derslerin Bitişi — 27 Ağustos 2027 | orta | Aynı kayma notu. |
| 56 | Resmî tatil | `RESMI_TATIL` | Zafer Bayramı | 2027-08-30 Paz | — | Zafer Bayramı — 30 Ağustos 2027 (Pazartesi; 1 Gün) | yüksek |  |
| 57 | Yaz okulu | `FINAL` | Yaz okulu: Yarıyıl sonu sınavları | 2027-08-31 Sal | 2027-09-02 Per | Yarıyıl Sonu Sınavları — 31 Ağustos 02 Eylül 2027 | orta | PDF'te '31 Ağustos 02 Eylül' (tire eksik) yazılmış; aralık 31 Ağustos-2 Eylül olarak okundu. |
| 58 | Yaz okulu | `DIGER` | Yaz okulu: Tek ders sınavı başvurusu son gün | 2027-09-06 Paz | — | Tek Ders Sınavı İçin Başvuruların Son Günü — 06 Eylül 2027 | orta | Aynı kayma notu. |
| 59 | Yaz okulu | `DIGER` | Yaz okulu: Tek ders sınavı | 2027-09-08 Çar | — | Tek Ders Sınavı — 08 Eylül 2027 | orta | Aynı kayma notu. |

## Doğrulama sonuçları

- Hafta günü tutarlılığı: resmî tatil tablosundaki 9 satırın PDF'teki gün adları gerçek takvimle HEPSİ UYUŞUYOR. Diğer tablolarda gün adı yazmaz.
- Her etiket ve ham tarih dizgisi PDF metin katmanında bulundu; ayrıştırılan ISO tarihler elle yazılanla çapraz kontrol edildi: sorun yok.
- Bilinen: güz ara sınavı 07-15 Kasım 2026 ✔ (PDF, V380). Bahar ara sınavı 10-18 Nisan 2027 ✔.
- Sıra kontrolü (kayıt < ders başlangıcı < ara sınav < ders bitişi < final < bütünleme; yaz okulu): ihlal yok.
- Resmî tatille kesişen etkinlikler (PDF'in kendi içinde; hata olmayabilir, bilgi): 
  - ÇAKIŞMA: '1. ek sınavlar (azami öğrenim süresini dolduranlar)' (2027-07-12..2027-07-16) resmî tatil '15 Temmuz Demokrasi ve Milli Birlik Günü' (2027-07-15..2027-07-15) ile kesişiyor
- Hafta sonuna denk gelen başlangıç/bitişler (PDF'te böyle; uygulama olduğu gibi gösterir): Güz: Ara sınavlar başlangıç 2026-11-07 Cumartesi; Güz: Ara sınavlar bitiş 2026-11-15 Pazar; Güz: Derslerin sona ermesi başlangıç 2027-01-03 Pazar; Güz: Derslerin sona ermesi 2027-01-03 Pazar; Bahar: Ara sınavlar başlangıç 2027-04-10 Cumartesi; Bahar: Ara sınavlar bitiş 2027-04-18 Pazar; Bahar: Derslerin sona ermesi başlangıç 2027-06-06 Pazar; Bahar: Derslerin sona ermesi 2027-06-06 Pazar.
- Yıl hatası: yok (tüm yarıyıl tarihleri 2026-08 … 2027-09 aralığında).

## Dış kaynakla uyuşmazlıklar

1. **Kurban Bayramı (düşük güven).** PDF: `15-18 Mayıs 2027 Cumartesi-Salı`, süre `4,5 Gün`. Diyanet 2027 takvimine göre (haber sitelerinin aktardığı): arife 15 Mayıs Cumartesi (yarım gün), bayram 16-19 Mayıs (Pazar-Çarşamba); 19 Mayıs bayramın son günü ve aynı zamanda Atatürk'ü Anma bayramı. 4,5 gün süre ancak 15 (yarım) + 16-19 ile tutar, yani PDF'in aralığı büyük olasılıkla bir gün erken bitiyor. Etki: V380'deki Kurban satırı 15-18, ayrı satır olan 19 Mayıs zaten tatil; kullanıcıya görünen fark küçük ama doğru ifade `15-19 Mayıs` olmalı. Üniversiteden/İdari ve Mali İşler'den teyit edin; teyit gelmeden V380'i değiştirmeyin (yeni migration ya da panelden PATCH).
2. Ramazan Bayramı 08-11 Mart: Diyanet ile uyumlu (8 Mart arife, 9-11 bayram). Cumhuriyet Bayramı 28-29 Ekim: 28 Ekim yarım gün, uyumlu.
3. Resmî duyuru taraması: oidb sayfasında 2026-2027 için güncelleme/değişiklik notu yok (bingol.edu.tr haber akışında çelişen duyuru bulunmadı; takvim idari karar ile değişebilir, tarih-bazlı geri sayım kartı bu yüzden `/calendar/next` sunucu verisinden beslenmelidir).

## Yönetici paneline girmeden önce kullanıcının PDF ile karşılaştırması gereken kontrol listesi (iki kişi doğrulaması)

Veri V380 ile zaten canlıdır; yeni giriş yapılacaksa ya da V380'i denetlemek için, panelde `Akademik takvim` listesini PDF ile yan yana açın ve ikinci bir kişi aynı listeyi bağımsız işaretlesin:

- [ ] Güz ders kayıtları 14-18 Eylül, danışman onayı 14-21 Eylül, derslerin başlaması 21 Eylül 2026.
- [ ] Güz ara sınavı 07-15 Kasım 2026; derslerin sonu 03 Ocak; final 04-15 Ocak; bütünleme 25-29 Ocak 2027.
- [ ] Bahar ders kayıtları 08-12 Şubat, ders başlangıcı 15 Şubat; ara sınav 10-18 Nisan; final 07-18 Haziran; bütünleme 28 Haziran-02 Temmuz 2027.
- [ ] Yaz okulu satırlarını (müracaat 05-06 Temmuz, kesin kayıt 08-09 Temmuz, başlama 12 Temmuz, bitiş 27 Ağustos, final 31 Ağustos-02 Eylül, tek ders 06/08 Eylül) PDF'teki ALT tabloya (görüntüde) bakarak doğrulayın; metin katmanı kayık.
- [ ] Resmî tatil tablosunda gün sayısı (1,5 / 3,5 / 4,5) ve tarih sütunlarını satır satır okuyun; özellikle Kurban Bayramı 15-18 mi 15-19 mu (yukarıdaki uyuşmazlık).
- [ ] Yatay geçiş iki tablosu (başvuru/ilan/asıl/yedek, güz ve bahar sütunları) yalnızca geri sayımda kullanılacaksa önemlidir; sütun kaymasına dikkat.
- [ ] Tüm satırlarda yıl (2026/2027) ve 'yayında' durumu; bölüm kapsamı boş (herkes).
- [ ] Panelde başlıkta Türkçe karakter (ş, ğ, İ, ı) bozulmadığını bir mobil cihazda ve webde görün.

## Ek: geri sayım kartı tasarım önerisi (≤10 satır)

- Uç: mevcut `GET /api/academic/calendar/next?limit=20` yeterli; isteğe bağlı `kinds=DERS_KAYIT,VIZE,FINAL,BUT,DONEM_BASLANGIC` süzgeci eklemek yükü azaltır (`AcademicCalendarService.next`'e `kind IN (?)`; yeni uç gerekmez, docs/openapi.json yeniden üretilir).
- Ekran: Akademik Merkez (`academic_hub_page.dart`) içinde `AcadhubNextExam` benzeri 'Takvim geri sayımı' kartı; Ana Sayfa'da yalnız en yakın 1-2 olay.
- Metin: `countdownTextL(l, startsAt, academicClock())` zaten var; bitiş aralıksa başladıysa 'X gün kaldı' yerine bitişe geri sayım ('Ders kayıtları: son X gün').
- Gün farkı İstanbul takvim gününe göre hesaplanmalı (tüm gün olaylar 00:00 İstanbul başlar, bitiş 23:59); sunucu `next` bitmemiş olayları da döndürür.
- Etiketler 'Güz:'/'Bahar:' önekli başlıktan gelir; i18n yok (içerik metni), yalnız 'kaldı/gün' kalıpları l10n.
- Veri değişirse kart sunucudan beslendiği için mobil sürüm gerekmez; ETag/304 önbelleği mevcut `api.dart` katmanında.
- Test: `academic_features_test.dart`'a sabit saatli (`academicClock`) geri sayım testi + `smoke-academic.sh`'ye `next` kind süzgeci adımı.
