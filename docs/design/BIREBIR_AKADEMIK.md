# BİREBİR: Akademik (Stitch v3, 9 ekran)

Kaynak: `C:\bu_design\stitch\v3_club\akademik\01..09_*_light.png` (01-06: 390x884-989 px, ölçek 1.0 = dp; 07-09: 706x1600 px,
ölçek 1.81 = dp) + `SARTNAME.md` "AKADEMİK". Uygulama: `mobile/lib/features/academic/*` (AcademicHubPage, TimetablePage,
ExamsPage, ExamFormPage, AcademicCalendarPage, AnnouncementsPage + AnnouncementDetailPage, ReminderSettingsPage).
Ortak yeni dosya: `acad_ref_widgets.dart` (`AcadRule`, `AcadTabs`, `AcadTextAction`, `AcadRow`, `AcadLabeled/AcadTextField/AcadPicker`,
`AcadAmberNote`, `AcadStateText`, `AcadRowsSkeleton`, `AcadDot`).

Ekran görüntüsü üretimi: `mobile/test/redesign/p69_akademik_shots_test.dart` (390 x referans yüksekliği, dpr 2, üst güvenli alan 0:
Stitch çerçevesi durum çubuğunsuz). Yan yana PNG'ler (sol referans, sağ uygulama, ikisi de 2 px/dp):
`C:\bu_qa\shots\tasarim\acad\birebir_akademik\yan_yana_01..09.png`. Ölçüm: aynı klasördeki betikle (satır bantları, y0-y1 dp).

Ölçüm notu: testlerde `Inter` yerine Roboto yüklüdür (sahte yazı tipi); satır genişlikleri %3-5 sapabilir, boy/konum ölçüleri
güvenilirdir. Gerçek cihazda Inter ile ölçülmedi (doğrulanamadı). Referans zemini lavanta (#FAF8FF), uygulama zemini RENK-1
`bg`: renk farkı bilinçlidir (yeni renk yok).

## Ölçü tablosu (dp)

| Ekran / öğe | Referans | Uygulama | Fark | Not |
|---|---|---|---|---|
| Tüm ekranlar: üst çubuk | geri oku merkezi (36, 27), başlık x=64, 18 sp/700, gölgesiz | aynı (`_AkadHeader`: zemin `bg`, gölge/ayraç yok, 56 dp) | 0 | eski yüzey renkli gölgeli çubuk kalktı |
| 01 Dönem satırı / "SIRADAKİ SINAV" etiketi (y merkezi) | 65 / 98 | 66 / 99.5 | <=1.5 | 13 sp muted / 12 sp, harf aralığı .6 (Türkçe İ doğru büyütülür; referans "I" yazmış) |
| 01 Sınav adı / alt satır (y merkezi) | 123 / 147.5 | 124 / 149 | <=1.5 | 20 sp/700, 13 sp muted; sağda geri sayım 14 sp/500 muted |
| 01 Ayraç / satır adımı | 180 / 77 | 180 / 77 | 0 | 4 kartsız satır (17 sp/600 + 13 sp muted + chevron 20), kart/simge karosu/rozet yok |
| 01 "Aktif Dönem" rozeti | var | yok | - | UYGULANMAZ.md yasağı; "Hatırlatmalar" `pr` metin sağ üstte (şartname) |
| 02 Hafta / dönem hapı (y merkezi) | 78 / 78 | 78 / 78 | 0 | 48 dp dokunma kutusu üste hizalı; hap 32 dp, "+" 30 dp `soft` daire |
| 02 Gün şeridi seçili hap / ayraç (y) | 110-175 / 192 | 110-175 / 192 | 0 | 5 gün (Cmt/Paz yalnız dersi varsa), seçili `soft` + `pr`, bugün altında nokta |
| 02 Ders satırı (çubuk y) | 225-269, 341-409 | 225-269, 341-409 | 0 | saat sütunu sağa yaslı (x=68), 3 dp çubuk x=85, ders adı 17 sp/600 |
| 02 "Şimdi · 11:20" çizgisi (y merkezi) | 306 | 306 | 0 | `pr` nokta + metin + ayraç; ders sürmüyorken de ilk yaklaşanın üstünde |
| 02 3. ders satırı (çubuk y) / özet satırı (y merkezi) | 450-518 / 667 | 450-494 / 643 | -24 | referansın 3. satırında "Uygulama oturumu" 3. satırı var (veride oturum türü yok): satır 24 dp kısa, sonrası aynı oranda yukarıda |
| 03 Başlık 28 sp (y merkezi) / "+" | 81 / (358, 80) | 80 / (358, 80) | <=1 | üst çubukta yalnız geri oku (başlık yinelenmez, bkz. sapmalar) |
| 03 Sekme yazısı / alt çizgi (y) | 128 / 148-150 | 129 / 148-150 | 0-1 | ink kalın + 2 dp `pr`, 20 dp girintili 1 dp ayraç |
| 03 Satır adımı (ayraç y) / sağ metin | 226, 303, 380 / 14 sp | 226, 303, 380 / 14 sp | 0 | en yakın sınav `pr`, diğerleri muted (hepsi 600) |
| 04 Etiket-alan adımı / alan yüksekliği | 90 / 48 | 90 / 48 | 0 | etiket 13.5 sp/600 ink, alan 48 dp, 16 dp köşe, 1 dp `bdStrong` (hatada 1.5 dp `danger`) |
| 04 Satır içi hata (y) | 139-153 | 140.5-152.5 | 1.5 | "Sınav adı gerekli." (ikonsuz) |
| 04 Kaydet | tam genişlik 48 dp | 48 dp | 0 | `pr` dolu |
| 05 Dönem etiketi / "Güne Dön" (y merkezi) | 72.5 | 72.5 | 0 | etiket büyük harf, harf aralıklı |
| 05 Ay başlığı / hafta günleri (y) | 127.5 / 175 | 128 / 174 | <=1 | `<` `>` 48 dp dokunma, ay adına dokununca tarih seçici |
| 05 Tarih ızgarası adımı | 44 | 48 | +4 | a11y: dokunma hücresi >= 48 dp (referans 44); ayraç/liste ~+14 dp aşağıda (ayraç ref 474, uyg. 489; olay satırları ref 541/614/687/760, uyg. +13) |
| 05 Seçili gün / nokta | `soft` daire 32x34, nokta +15 | 34x38, nokta +16 | <=3 | sınav günü `pr`, diğer `ink` nokta |
| 05 Olay satırı adımı (ayraç y) | 73 | 73 | 0 | tarih+gün adı solda (sınavda `pr`), olay adı sağda, chevron; dokununca o gün seçilir |
| 06 Sekme yazısı / alt çizgi (y) | 77 / 98-100 | 77.5 / 98-100 | <=1 | |
| 06 Satır adımı (ayraç y) | 174, 249, 324, 399 | 174, 249, 324, 399 | 0 | okunmamış: `pr` nokta + kalın başlık; okunmuş: normal; sağda "Sabitlenmiş" ya da chevron |
| 07 Bölüm başlığı "Sınavlar" (y merkezi) | 76 | 76 | 0 | 18 sp/700 |
| 07 Satır başlığı + alt metin (y) | 116 / 141-159 | 115 / 140-157 | 1 | 16 sp + 13 sp muted; anahtar 48 dp genişlik (sağ kenar x=370) |
| 07 Süre çipleri | 34 dp, r8, x=20/85/156 | 34 dp, r8, aynı | 0 | 5 / 15 / 30 dk (+ kayıtlı değer bunların dışındaysa o da) |
| 08 Kehribar not | y 56-159 (103 dp), ikonsuz | ~56-158 (görsel kıyas) | ~1 | "Ayarlardan aç" `pr` kalın metin; anahtarlar/çipler pasif (opaklık .55) |
| 09 Başlık 24 sp/700 (y) | 81-105 | 81-104 | 0 | |
| 09 Ayraç / ilk gövde satırı | 150.5 / 172 | 151 / 173 | <=1 | 16 sp/1.6, boş satırla paragraf (16 dp), "- " satırları madde (8 dp aralık) |
| 09 "Ekli belgeyi aç" | `pr` kalın metin | `pr` kalın 16 sp, altı çizgisiz | - | şartname |

## Davranış korunan sapmalar / eklenenler
- **Sınavlar başlığı**: referans hem üst çubukta küçük "Sınavlar" hem 28 sp "Sınavlar" çizdi (Stitch çift başlık artefaktı, UYGULANMAZ.md
  "çift başlık" ile aynı sınıf). Uygulamada üst çubukta yalnız geri oku, başlık 28 sp (şartname 03).
- **Ders programı**: "Derslerim" ızgarası ve yüzen "Ders ekle" düğmesi referansta yok; ders düzenleme satıra dokunarak, ekleme
  "+" ile yapılır. `.ics` dışa aktarma referansta yok: alta muted metin bağlantı olarak korundu. Özet satırı sağında "Sınav Takvimi"
  (Sınavlar sayfasına gider).
- **Sınav ekle**: referanstaki 6 alana ek olarak "Bitiş (ops.)" (Saat satırında yan yana) ve "Not" alanı korundu (API alanları);
  tür çipleri model türleri kadar (Vize, Final, Bütünleme, Quiz, Ödev, Diğer; referans ilk 4'ü çizdi); Ders alanı yalnız ders varsa
  görünür. Hata metinleri alan altında satır içi (üst hata şeridi kalktı); sunucu hatası Kaydet üstünde `danger` metin.
- **Sınavlar**: tür süzgeci yalnız en az iki farklı tür varsa görünür (referans örneği tek tür, süzgeçsiz); geçmiş sınavlar "Geçmiş" etiketi
  altında muted + "Geçti"; "Okul programı" sekmesinde Bölümüm/Tümü kapsam çipleri (ürün kararı) ve profil bölümü yoksa kehribar not.
- **Akademik takvim**: seçili gün listeyi süzmez (referansta seçili 18 ile 4 kayıt görünür), gün olaysızsa üstte "Bu günde önemli tarih
  yok."; "Sınav Programı Hatırlatması" mavi kutusu uygulanmadı (şartname); takvim açıklama/bölüm bilgisi olay adının altında muted.
- **Hub**: "Yaklaşan tarihler" şeridi ve ilgili ek ağ çağrısı (`nextEvents`) kaldırıldı (referansta yok); sıradaki sınav yoksa blok gizli.
- **Bölüm duyuruları**: "Tümünü okundu işaretle" üst çubukta tik-tik simgesi (tooltip/semantics etiketi aynı metin); referans tek
  satırlık "bir hafta önce" biçimi için `p69WeeksAgo`.
- **Hatırlatmalar**: "Sınavdan 2 saat önce (bildirim)" bilgi satırı (sunucu push'u, Bildirim tercihleri'ne gider) mantığı DEĞİŞMEDİ;
  referanstaki "Sınav hatırlatması" satırının altında ikonsuz, kartsız satır olarak durur. İzin kapalıyken (08) referansın süre
  etiketi/çipleri tek satırda (Stitch artefaktı); uygulama 07 ile aynı yerleşimi kullanır (izin değişince kayma olmasın).
- Anahtar (Switch) boyutu tema anahtarıdır (52x32), 0.92 ölçekle 48x29; kapalı iz çizgisi tema gereği (referans çerçevesiz).
- `Cts` yerine `Cmt` (mevcut çeviri); "Aktif Dönem", "Sınav Programı Hatırlatması", simge karoları, rozetler uygulanmadı.

## Yeni metinler (ARB p69, tr/en/ar)
Haftalık Akış, {n}. Hafta, Tamamlandı, Son oturum, {h} saat, Bugün toplam {n} oturum ({hours}), Sınav Takvimi, Şimdi, Sınav adı (+ ipucu
+ hata), Ders seçin, Tarih, Saat, sınav hatırlatma notu, {name} yarıyılı, Güne Dön, Akademik Olaylar, {n} Kayıt, Ekli belgeyi aç, Sınav
hatırlatması (+ alt metin), Dersten {n} dakika önce, Süre, Dersler, Hatırlatmalar bu telefonda oluşturulur, bildirim izni notu, Henüz
sınav eklemedin, {unit} · {date}, Okul programı, {n} hafta önce.

## Doğrulama
- `test/redesign/p69_akademik_test.dart`: 3 dil x açık/koyu x 1.0/1.3 x 320/390 taşma matrisi (9 ekran/durum), davranış testleri,
  48 dp + etiket + kontrast (8 sayfa x açık/koyu). Güncellenen: `academic_features_test`, `akad_design_test`, `notif_design_test`,
  `p17_academic_test`, `p2_dd_test`, `dd_test` (yalnız ders programı satırı).
- Ekran görüntüleri: `p69_akademik_shots_test.dart` (tr 390 açık; koyu/ar/x1.3 için `P69_MODES=dark,x13`, `P69_LANG=ar`).
- Emülatör gezisi ve gerçek cihaz akıcılığı bu turda yapılmadı (doğrulanamadı).
