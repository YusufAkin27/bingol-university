# A6 - Mobil tasarım/UI QA denetimi (ekranlar arası tutarlılık, global kalite, son değişikliklerin etkisi)

Tarih: 2026-10-31. Dal `feature/mobil-uygulama`, HEAD `b405782`. Kapsam: `mobile/` (Flutter). Denetim aşaması: kod DEĞİŞTİRİLMEDİ; yalnız bu rapor yazıldı. Üretim sunucusuna erişilmedi. Gerçek cihaz yok: tüm görüntüler `flutter test` ile üretildi.

Önceki 19 denetim ekranları tek tek referans tasarımla (Stitch) karşılaştırdı; bu denetim farklıdır: ekranlar arası tutarlılık, global kalite (kontrast, dokunma hedefi, tipografi, RTL, dar ekran, büyük yazı) ve N4/Q1/P3/M1/I2/P2 değişikliklerinin etkisi.

## 0. Yöntem ve kapsam (dürüst sayılar)

Temiz `git archive HEAD mobile` kopyası `C:\bu_qa\a6src` (ASCII yol, `PUB_CACHE=C:\pubcache`, `C:\src\flutter`). Kopyada (repo dışı) şunlar yapıldı: `test/redesign/*_shots_test.dart` dosyalarının hepsi `STORE_SHOTS_OUT/K1_OUT/N4_OUT` ile açıldı (varsayılan olarak atlanan test grubu), dar ekran için `QA_W` ortam değişkeni eklendi, her sahneye `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline` çağrısı eklendi (`qa_a11y.dart`). Çalışma ağacında izlenmeyen 5 shots testi (`p08/p11/p13/p14/p18`) ve `media_source_sheet.dart` de kopyaya alındı. P2 yardım/tercih/ayarlar ekranları için shots testi yoktu: `qa_p2_shots_test.dart` ile üretildi. Testler her sahnede `takeException` ile taşmayı (`A RenderFlex overflowed`) yakalar.

| Koşu | Dil / genişlik / varyant | Üretilen PNG | Benzersiz sahne |
|---|---|---|---|
| tr390 | tr, 390 dp, açık + koyu + 1.3x yazı | 1904 | 720 |
| ar390 | ar (RTL), 390 dp, açık + 1.3x | 1292 | ~650 |
| tr320 | tr, 320 dp, açık + 1.3x | 1312 | ~650 |
| p2_* | P2 ekranları (5 ekran x açık/koyu/1.3x) x tr390, ar390, tr320 | 45 | 5 |
| en390 | en, 390 dp, açık | kısmi (koşu bu rapor yazılırken sürüyordu, ~470 PNG) | - |

Toplam üretilen PNG: yaklaşık 4600. Taşma/dokunma/etiket denetimi bunların hepsinde otomatik koştu. Gözle (contact sheet ile) incelenen: yaklaşık 130 görüntü, 28 sayfa (sekmeler, sohbet listesi/balonlar/medya, tüm onay diyalogları, kimlik akışı, akademik, ayarlar/bildirim tercihleri/yardım, kamera, ar ve 320 örnekleri). Yani "her ekran gözle bakıldı" iddiası YOKTUR; otomatik tarama tam, gözle bakış örneklemedir.

Üretilemeyen sahneler (test çürümesi, UI hatası değil; ayrıca bkz. A6-30): `_tapText` Türkçe metni bulamayıp "Bad state: No element" veriyor: p11 `45_anket_tarih_secici`, p11 `18_detay_gonderi_menu_x1.3`, p13 `31_talep_kapat_diyalog`, p17 `12_ders_formu_cakisma`, p17 `21_sinav_formu_hata`, p18 `04_kabuk_profil`, n3 `05_cikar_onay_x1.3` (tr390: 18 test; ar390: 37; tr320: 15 + 3 taşma). p18 `07_profil_yukleniyor`: bekleyen Timer. `docs/MOBILE_PAGES.md` envanterindeki 101 satırın (E75/K5/D11/Z5/T5) yaklaşık tamamı bu sahnelerle kapsanıyor; `ui_matrix` adlı bir dosya/araç repoda YOK (grep boş).

Taşma sonucu: tr390 ve ar390'da (açık/koyu/1.3x) HİÇ `RenderFlex overflowed` yok. 320 dp'de 3 test taşma verdi (A6-12, A6-31).

Kontrast hesabı `C:\bu_qa\contrast.py` ile token değerlerinden yapıldı (WCAG göreli parlaklık). Flutter `textContrastGuideline` çıktısı gürültülü (110 uyarı; örn. `t.mut` 6.1:1 olan metni 3.02 raporluyor, gerçek renk koddan doğrulandı) ve bulgu sayılmadı; yalnız şüphe listesi olarak kullanıldı.

Bakılamayan şeyler: gerçek cihaz/OEM yazı tipi (Arapça testte Arial ikamesi kullanıldı, Inter'da Arapça glif yok), emoji glifleri (test ortamında kutu çıkıyor, uygulama hatası sayılmadı), yatay mod, klavye açıkken `viewInsets` taşması (yalnız kod okundu), iPhone alt güvenli alan 34 dp (testler 16 dp ile koştu), animasyon/geçiş kalitesi, VoiceOver/TalkBack gerçek davranışı (yalnız Semantics ağacı kuralları), "animasyonları azalt" görseli (yalnız kod okundu: bkz. A6-33 olumlu), en390 koşusunun tamamı.

## 1. Özet

| Şiddet | Adet |
|---|---|
| KRITIK | 0 |
| YUKSEK | 7 |
| ORTA | 18 |
| DUSUK | 7 (A6-26..A6-32; A6-33 olumlu gözlem) |
| ONERI (özneldir, hata sayılmadı) | 8 |

Taşma/okunamaz ekran yok (KRITIK 0). En büyük riskler: bileşen kopyalarının yarattığı tutarsızlık (onay diyalogları 6 farklı düzen, 3 farklı seçili çip stili), I2 sonrası açık temada giriş alanı/kart ayrışımının WCAG 1.4.11 altında kalması, dar ekranda sohbet başlığı ve ayar açıklamalarının kırpılması, `kNavInset=100` sabitinin gerçek alt çubuk yüksekliğiyle uyuşmaması.

## 2. Bulgular

Görüntü yolları `C:\bu_qa\shots\a6\` altındadır (repo dışı). Kısaltma: tr390b = en eksiksiz tr390 klasörü (`tr390b`), `tr390` = ilk koşu.

### YUKSEK

**A6-01 - YUKSEK - Onay diyaloglarının 6 farklı düzeni (modal stil tutarsızlığı)**
Ekranlar: sohbet mesaj silme, profil çıkış, etkinlik iptal, kulüp silme, gönderi silme, gönderi vazgeç; tr390 açık (ar'da da aynı).
Görüntü: `tr390\21_05_silme_onayi_tr.png`, `09_profil_cikis_onayi_tr.png`, `37e_iptal_diyalogu_tr.png`, `29_04_kulup_sil_tr.png`, `g11_04_sil_tr.png`, `g10_04_vazgec_tr.png`.
Gerçek: (1) sohbet: simge solda rozetli, başlık yanında, iki eşit düğme (gri + kırmızı); (2) çıkış: ortalı çıplak simge, düğmeler sağda (metin "Vazgeç" + küçük kırmızı hap); (3) etkinlik iptal: ortalı kırmızı rozet, iki tam genişlik düğme; (4) kulüp sil: ortalı rozet + doğrulama alanı; (5) gönderi sil: soldan rozet, sağda küçük hap; (6) vazgeç: simge yok, tam genişlik kırmızı + metin bağlantı. Ayrıca 1., 2. ve 3. diyalogda kalın koyu lacivert dış çerçeve görünüyor, diğerlerinde yok (kaynak koddan doğrulanamadı; odak halkası/test yapıntısı olabilir, kontrol edin).
Beklenen: tek `BuDialog` (simge konumu, düğme biçimi/hizası, çerçeve aynı).
Kod: `widgets/bu_overlays.dart:225` `BuDialog` yalnız `features/events/event_form_page.dart` içinde 2 yerde kullanılıyor. Kopyalar: `features/chat/chat_detail_page.dart:3053 _ChatConfirmDialog`, `features/chat/chat_info_parts.dart:533 ChatDialogButton`, `features/events/event_parts.dart:155 _EventConfirmDialog`, `features/events/etkinlik2_settings_page.dart:554 _CancelDialog`, `features/events/event_form_page.dart:1660 _SubmittedDialog`, `features/clubs/club_ref_widgets.dart:191 ClubDialogCard`, `features/clubs/club_detail_sheets.dart:101 ClubDeleteDialog`, `features/posts/post_actions.dart:87 _DialogShell`, `features/posts/compose_post_page.dart:543 _DiscardDialog`, `features/chat/chat_sheet_parts.dart:258 _RenameDialog`, `features/academic/semester_sheet.dart:289 _NewSemesterDialog`, `features/chat/chat_detail_page.dart:46 _VideoPrepareDialog`.
Düzeltme: `BuDialog.confirm` etrafında tek bir onay bileşeni (simge, başlık, mesaj, tehlikeli düğme) ve diğerlerini ona taşıyın; kopyaları silin.

**A6-02 - YUKSEK - I2 sonrası açık tema: giriş alanı çerçevesi ve kart ayrışımı WCAG 1.4.11 (3:1) altında**
Ekran: tüm açık tema; tr390 `02_giris_hatali_alanlar_tr.png`, `01_dolu_tr.png`, `06_profil_dolu_uzun_tr.png`.
Hesap (token): çerçeve `bd #E7E8EB` / alan `sf #FFFFFF` = 1.23:1; `bd` / `bg #F8F9FC` = 1.16:1; `sf` / `bg` = 1.05:1; `sf2` / `bg` = 1.10:1. Koyu: `bd` / `sf` = 1.28:1, `sf3` / `sf` = 1.19:1, ilet sheet'te seçilmemiş halka `bd` / `sf3` = 1.07:1.
Gerçek: alanları ve kartları yalnız 1.2 dp soluk çizgi + yumuşak gölge ayırıyor; metin alanının sınırı 3:1'in çok altında (yalnız çerçeve alanı tanımlıyor). Gözle bakınca kartlar okunur ama zayıf; düşük görüşlü/parlak güneşte ayrım kayboluyor.
Kod: `core/theme.dart` `BuTokens.light` (`bd`), `core/theme/bu_component_themes.dart:247-260` (`InputDecorationTheme` `border(t.bd)`).
Düzeltme: giriş alanı çerçevesine ayrı, ~#8B90A1 (≥3:1) bir `bdStrong` token'ı; kartlarda kenar ya da gölgeden en az biri 3:1'e yaklaşsın veya `sf2` dolgusu verin.

**A6-03 - YUKSEK - "Seçili çip/segment" stili üç ayrı biçimde**
Ekranlar: Keşfet, Sohbet, Kulüpler, Akademik (Ders programı günleri, Sınavlar süzgeci), Etkinlikler.
Görüntü: `tr390\01_dolu_tr.png` (Keşfet "Tümü" dolu kırmızı), `L01_liste_dolu_tr.png` ve `04_kulupler_tr` (Tümü: açık pembe dolgu + kırmızı çerçeve/yazı), `01_ders_programi_tr.png` (seçili gün: lacivert dolu; koyu temada beyaz dolu), `14_sinavlar_koyu_tr.png` (seçili: beyaz dolu).
Beklenen: tek seçili çip tonu (örn. `soft` + `onSoft` + kenar), tek bileşen.
Kod: `features/discover/discover_tab.dart` `_Chip`, `features/chat/chat_tab.dart` süzgeç, `features/academic/timetable_parts.dart:77 TtDayPills`, `features/academic/akad_widgets.dart:129 AkadPill`, `features/events/etkinlik_parts.dart:79 EtkinlikPill`.
Düzeltme: `BuChip` (zaten var) kullanımını zorunlu kılın; selected renkleri tek yerden gelsin.

**A6-04 - YUKSEK - Dar ekranda (320 dp, 1.3x) sohbet listesi başlıkları 3 harfe iniyor**
Ekran: Sohbet sekmesi, tr320 1.3x: "Zeynep De…", "Fot…", "Kariy…" (zaman + susturma simgesi + tür çipi genişliği yiyor). 390 dp 1.0x'te de "Fotoğrafçılık Kul…" kırpılıyor.
Görüntü: `tr320\L01_liste_dolu_x1.3_tr.png`, `tr390\L01_liste_dolu_tr.png`.
Beklenen: sohbet adı en az 2 satır ya da çip adın altına/sağına bir kerede sığsın; tür çipi küçük ekranda gizlenip simgeye insin.
Kod: `features/chat/chat_tab.dart:878` civarı satır düzeni, `features/chat/chatlist_widgets.dart:154 ChatlistAvatar` komşusu satır.
Düzeltme: başlık satırını `Row[Expanded(title), meta]` yapın; çip ve saat ikinci satıra düşsün; 1.3x ve 320 dp'de `maxLines: 2`.

**A6-05 - YUKSEK - Ayarlar > "Fotoğrafları galeriye kaydet" açıklamasındaki asıl uyarı kırpılıyor**
Ekran: Ayarlar; tr 390, 1.3x, 320 (açık/koyu). Açıklama `maxLines 3` ile "...tek gösterimlik fotoğraflar kaydedilm…" diye bitiyor; 1.3x/320'de "tek g…" ye kadar kesiliyor. Asıl uyarı (tek gösterimlik fotoğrafların kaydedilmemesi) okunamıyor. Alt not "Galerin bulut yedeklemesi açıksa..." ayrı ve görünür.
Görüntü: `p2_tr390\qa_ayarlar_tr.png`, `qa_ayarlar_x1.3_tr.png`, `p2_tr320\qa_ayarlar_x1.3_tr.png`.
Kod: `features/profile/settings_page.dart:350` (`desc`, `maxLines: 2/3, ellipsis`); anahtar `p22SaveGallery*`.
Düzeltme: satır açıklamasında kırpmayın (satır serbestçe uzasın) ya da uyarıyı alt nota taşıyın.

**A6-06 - YUKSEK (hesap; cihazda doğrulanamadı) - `kNavInset = 100` sabiti gerçek alt çubuk yüksekliğiyle uyuşmuyor**
Çubuk yüksekliği = 68 dp (1.15x ölçekte 70.4) + `max(alt güvenli alan, 16)`. iPhone (34 dp) = 102-104 dp; Android 3 tuşlu gezinme (48 dp) = 116 dp. Sekmeler alt dolguyu `kNavInset` sabitiyle veriyor (`MediaQuery` okumuyor): son öğe 2-16 dp çubuğun altında kalır. Testler alt güvenli alanı 16 dp aldığı için gözle yakalanmadı.
Kod: `widgets/bu_widgets.dart:926`, kullanım: `features/chat/chat_tab.dart:595,602`, `features/clubs/clubs_tab.dart:354,364`, `features/discover/discover_masonry.dart:228`, `features/home/home_tab.dart:312`, `features/home/home_parts.dart:303`, `features/profile/profile_tab.dart:228`; `core/app_gate.dart:242` aynı sabitten `-8 + padding.bottom` türetiyor (farklı formül, tutarsız).
Düzeltme: `kNavInset` yerine `FloatingNav.height + FloatingNav.gap + MediaQuery.viewPadding.bottom` hesaplayan tek yardımcı; klavye açıkken (çubuk gizli) dolgu da küçülsün.

**A6-07 - YUKSEK (tasarım kararı kaynaklı okunabilirlik) - Yazı ölçeği %10 küçültülmüş; iki paralel tip sistemi**
`core/typography.dart` `BuType`: gövde 13.5, etiket 11.7, açıklama 10.8, mikro 9.9; `core/theme/bu_text_theme.dart`: gövde 13.5, `bodySmall` 12, `labelSmall` 11; simge teması 21.6 (24'ün %90'ı); bazı yerlerde `fontSize: 10` (`features/chat/media_picker_page.dart:711,726`, `media_preview_page.dart:524`). Alt çubuk etiketleri, bölüm başlıkları (UYGULAMA TERCİHLERİ), çip metinleri 11 sp. Android'de ≥12 sp, iOS'ta ≥11 pt önerilir; 9.9/10.8 aşağıda. İki sistemin sayıları farklı (etiket 11.7 vs 12; açıklama 10.8 vs 12).
Beklenen: tek tip ölçeği, en küçük metin 11-12 sp; ayrı `BuType` ile `TextTheme` birleşsin.
Düzeltme: `BuType.micro/caption`'ı kullanımdan kaldırın (9 kullanım) ya da en az 11'e çekin; "büyük yazı" testleri 1.3x'te korunuyor (taşma yok) ama temel boyut küçük.

### ORTA

**A6-08 - ORTA - P3 sabit kare görsel: 3 fotoğraflı ızgarada boş 4. hücre balon rengiyle doluyor**
Ekran: sohbet balonu, 3 görsel (gönderilen); tr390 açık/koyu, 320. Dördüncü hücre düz kırmızı (koyuda somon) kare olarak görünüyor; saat çipi o boşlukta duruyor.
Görüntü: `tr390\02_balon_medya_tr.png`, `tr320\02_balon_medya_koyu_x1.3_tr.png`, `tr390b\B3_balon_medya_tr.png`.
Beklenen: 3 görsel için 1 büyük + 2 küçük (ya da boş hücrenin görsel hücre gibi nötr ya da hiç olmaması).
Kod: `features/chat/message_bubble.dart` `_LocalGrid` ve sunucu grid yerleşimi (`_MediaGrid`, ~230-240 satırları çağrısı).

**A6-09 - ORTA - P3: "+4" katmanı ile saat çipi çakışıyor (1.3x)**
`tr320\02_balon_medya_koyu_x1.3_tr.png`: altıncı karede "+4" yazısının alt yarısı saat çipi "02:29" ile kesişiyor. Kod: `features/chat/message_bubble.dart` (+N katmanı), `DurationPill` `:561`.

**A6-10 - ORTA - M1 gönderiliyor göstergesi: video balonunda ilerleme halkası içindeki "%65" halkayla çakışıyor**
`tr390\B3_balon_medya_tr.png` (tr), `ar390\B3_balon_medya_ar.png` (ar): yükleme oku/halkası ve altındaki %65 çipi üst üste biniyor. Metin balonlarında saat simgesi ve zaman hizası doğru (tr/ar, `B1_balon_metin`, `B5_balon_hata_kuyruk`), RTL'de de tutarlı. "Gönderilemedi · Yeniden dene" bağlantısı 11 sp, yüksekliği ~16 dp (A6-14).

**A6-11 - ORTA - Tek gösterimlik kartta kritik metin kırpılıyor**
`tr390\B4_balon_tek_gosterimlik_tr.png`: "Fotoğraf · Açmak için do…" ve 320 1.3x'te "Fotoğraf · Açm…" / "Yalnızca bir kez görünt…" (`tr320\04_balon_tek_gosterimlik_koyu_x1.3_tr.png`). Yönerge ("dokun") kırpılıyor. Kod: `features/chat/message_bubble.dart:972 ViewOnceCard`.

**A6-12 - ORTA - Arama > Kulüp sonucu satırı 320 dp + 1.3x yazıda 4.4 px taşıyor**
Test: `k3 s3_arama_kulup_x1.3_tr` (tr320) `A RenderFlex overflowed by 4.4 pixels on the right`. Büyük olasılıkla kulüp kartı `_clubCard` içindeki üye sayısı/durum düğmesi satırı. Kod: `features/search/search_page.dart:911-960`. Görüntü yok (test düştü); 390 1.3x'te taşma yok.

**A6-13 - ORTA - Avatar şekli tutarsız (N4 sonrası kare/daire)**
Sohbet listesi ve konuşma menüsünde kişi/grup avatarı yuvarlatılmış kare (`radius = size*.34`), sohbet başlığı, üyeler, yeni sohbet, profil, alt çubuk dairesel (`circle: true`). Aynı kişi iki şekilde görünüyor (`tr390\L01_liste_dolu_tr.png` vs `05_yanit_seridi_tr.png`, `N01_yeni_sohbet_tr.png`). Kod: `features/chat/chatlist_widgets.dart:216`, `features/chat/conversation_actions.dart:29` (varsayılan kare), diğerleri `circle: true`. Karar: kişi=daire, kulüp/etkinlik=yuvarlak kare gibi tek kural.

**A6-14 - ORTA - Dokunma hedefi 48 dp altı (Android) / 44 dp altı (iOS)**
Otomatik tarama (tr390, etkinlik adı sahne sayısı):
- Beğen düğmesi 44x44 (`tr390\01_begenilmemis_tr.png`, 31 sahne; `features/posts/like_button.dart:349`).
- Sekme/segment 44 yüksekliği: Keşfet/Etkinliklerim/Oluşturduklarım 116.7x44 (`k9e 36a_kesfet_gun`), Gönderiler/Etkinlikler/Üyeler/Anketler 85.5x44 (kulüp detay), Açık/Kapanan 114x44, Katıldıklarım 175x44; filtre çipleri Tümü 60.8x44, Popüler 72.8x44.
- Takvim "Önceki ay/Sonraki ay" 44-52x44-48; gün hücreleri 47.7 genişlik (<48).
- Sohbet balonu yanındaki gönderen avatarı 28x28, etiketsiz `tap` (36 sahne): `features/chat/chat_new_parts.dart:154`.
- Ders formu renk örnekleri 32.6x48, hafta günü çipleri 46.6x50 (`p17 09_ders_formu_yeni`).
- "Paylaş" 75x40, "Tüm medyayı gör" 108x40, "Logo ekle" 78x32 / 101x42 (kulüp kur), "Gönderilemedi · Yeniden dene" ~16 dp, "Tümünü Gör" 66x44.
- Arama kutusu semantiği 288x20 (metin alanı düğümü; büyük olasılıkla yanlış pozitif).
Beklenen: 48x48 etkin alan (görsel küçük kalabilir; `Material.tapTargetSize` padded zaten açık, ama özel `GestureDetector`/hap bileşenleri yok sayıyor).
Düzeltme: `BuPressable`/çip/segment bileşenlerine `minHeight: 48`; 28 dp avatarı `SizedBox(48)` ile sarıp `Semantics(label: ad)`.

**A6-15 - ORTA - Etiketsiz dokunulabilir düğümler**
`labeledTapTargetGuideline`: 126 uyarının büyük çoğunluğu sohbet balonu gönderen avatarı (28x28, A6-14) ve diyalog/menü bariyeri (tam ekran `tap`, anlamsal olarak sorun değil). `n3 01_birebir` 75.5x75.5 ve `n3 02_grup_yonetici` 100.7x100.7 etiketsiz `tap` (sohbet bilgisi büyük avatar: `features/chat/chat_info_page.dart:573`) ekran okuyucuya "düğme" olarak etiketsiz çıkıyor. `ChatSheetCheck`/`ChatSheetRadio` (`features/chat/chat_sheet_parts.dart:12,39`) `ExcludeSemantics`; seçili bilgisi yalnız üst satırın semantiğine bağlı.

**A6-16 - ORTA - Seçim dairesi yalnız renkle durum veriyor ve seçilmemiş hali görünmez (İlet / Üye ekle)**
`tr390\07_ilet_koyu_tr.png`: seçili = dolu kırmızı daire, TİK YOK; seçilmemiş = 2 dp halka `bd` (koyu 1.07:1, açık 1.2:1). Kod: `features/chat/chat_sheet_parts.dart:12-36`. Düzeltme: seçili halde ✓ glifi, seçilmemiş halka `mut` tonunda.

**A6-17 - ORTA - Bildirim tercihlerinde pasif satır metni düşük kontrast; koyu temada açık/kapalı ayrımı zayıf**
`p2_tr390\qa_bildirim_tercihleri_tr.png` / `_koyu_tr.png`: izin kapalıyken (I4) Haberler/Duyurular satırlarının başlık+açıklaması ~2.5:1 (alfa ile soluk), anahtarlar hâlâ "açık" (somon) görünüyor; koyuda açık anahtar koyu bordo iz üstünde neredeyse siyah başparmak. Pasif satırın neden pasif olduğu satır üstünde yazmıyor, yalnız en üstte "Anlık bildirimler Kapalı". Kod: `features/profile/notification_prefs_page.dart` (~363: ayrıca `EdgeInsets.only(left: ...)` RTL'de aynalanmaz, A6-26). Düzeltme: pasif satıra kilit/"Duyurular'a bağlı" ipucu metni, başlık metni ≥4.5:1, anahtar kapalı görünsün.

**A6-18 - ORTA - Üstbilgi (header) biçimi tutarsız**
Ayarlar sayfası büyük başlık + yuvarlak çerçeveli geri düğmesi (`BuHeader`), Bildirim tercihleri / Bildirimler çalışmıyor mu? / Üyeler / Yeni sohbet ise düz ok + orta başlık + alt çizgi. Görüntü: `p2_tr390\qa_ayarlar_tr.png` ile `qa_bildirim_tercihleri_tr.png` yan yana. Kod: `features/profile/settings_page.dart` vs `features/profile/notification_prefs_page.dart`, `features/notifications/push_help_page.dart`. Ayarlar > alt sayfa geçişinde başlık stili değişiyor.

**A6-19 - ORTA - Ikon seti karışımı (N4 sonrası)**
Alt çubuk 8 `Icons.*_rounded` (Material dolgu/çizgi çiftleri), uygulamanın geri kalanı 1339 `LucideIcons.*` çizgi simgesi. Ek olarak 38 kaçak Material simgesi: `features/discover/discover_tab.dart:173` (`Icons.dynamic_feed` "Öğrenci Akışı" başlığında soluk/ince görünüyor, `tr390\01_dolu_tr.png`), `post_actions.dart`, `like_button.dart` (Icons.favorite), `poll_parts.dart`, `qr_scan_page.dart`, `permissions_page.dart`, `crop_page.dart`, `search_page.dart`, `common.dart`, `gate_views.dart`. Karar: alt çubuk Material kalacaksa kasıtlı ve belgelenmeli (şu an `floating_nav.dart` açıklamasında yalnız "seçili dolgulu").

**A6-20 - ORTA - Kopya bileşen yoğunluğu (bakım borcu, tutarsızlık kaynağı)**
- Hap/çip/etiket sınıfları (en az 25): `_WhitePill`, `AkadPill`, `_StatusPill`, `_TonalPill` (x2), `_LangPill`, `RefPill`, `ChatdPill`, `ChatdBarPill`, `NcPillButton`, `_ActionPill`, `DurationPill`, `_CountPill`, `_PinnedPill`, `KulupPillButton`, `EtkinlikPill`, `_HeaderPill`, `_TorchPill`, `AnketPill`, `_DotPill`, `_Pill` (my_clubs), `_GoingPill`, `P2Pill`.
- Banner: `RefBanner`, `Et2Banner`, `AnketErrorBanner`, `ClubRequestsBanner`.
- Diyalog: A6-01 listesi; alt sayfa: `SohbetySheetFrame`, `ChatSheetHeader`, `ClubSheetRow`, `_CoverSheet`, `_ClubPickerSheet`, `_ApplySheet`, `_JoinQuestionsSheet`, `_AlbumSheet`, `ForwardSheet`, `AddMembersSheet`, `DeleteConfirmSheet`; `BuBottomSheet` (`widgets/bu_overlays.dart:11`) yalnız 2 yerde.
- Toast: `BuToast.show` 67 yerde, ama ham `SnackBar` 6 yerde (`features/clubs/clubs_tab.dart:160`, `features/home/home_tab.dart:254`, `features/posts/compose_post_page.dart:169`, `features/profile/blocked_users_page.dart:96`, `features/profile/privacy_data_page.dart:55`, `features/events/event_form_page.dart:62`): simgesiz/başlık metinsiz farklı görünüm.
- Yarıçap: `BuRadius` token 465 kullanım, ama elle `BorderRadius.circular(x)` 252; token dışı değerler (token: 8/12/16/20/28/999): 14 (39), 24 (11), 18 (4), 23 (3), 10 (2), 22 (2), 19 (2), 30 (2), 11, 15, 25, 26 ~ 70 yer.
- Sabit renk: `features/academic/academic_models.dart:100-109` ders renkleri tema duyarsız (koyu temada kontrast hesaplanmadı), `features/shell/floating_nav.dart:98,106`, `features/chat/sohbety_widgets.dart:13`, `widgets/sistem_widgets.dart:16`, `core/theme/bu_color_scheme.dart:29-34`.

**A6-21 - ORTA - Kulüp logosu yer tutucuları baş harfli (bilinen), ve ölü `SohbetyAvatar`**
Kulüp listesi/profil kulüpleri/kulüp detayı baş harf kutusu kullanıyor (`features/clubs/club_detail_page.dart:640`, `features/profile/my_clubs_page.dart:576`); aynı kulüp sohbet listesinde varsayılan grup avatarı görüyor (`tr390\04_kulupler_tr.png` "SK/RV/MT/FK" vs `L01_liste_dolu_tr.png`). `features/chat/sohbety_widgets.dart:256 SohbetyAvatar` (baş harfli) hiçbir yerde kullanılmıyor (ölü kod). `initialsOf` yalnız bu 2 yerde kaldı.

**A6-22 - ORTA - Segment etiketi font boyutu tutarsız (320 dp)**
Etkinlikler üst sekmesi: "Keşfet/Etkinliklerim" 12 sp, "Oluşturduklarım" FittedBox ile ~8 sp'ye iniyor (`tr320\01_kesfet_dolu_tr.png`, sağ üst). Kod: `features/events/events_page.dart` segment satırı.

**A6-23 - ORTA - Seçili/pasif hint metinleri alfa ile düşük kontrast**
`t.mut` %60-70 alfa hesabı: açık tema 2.6-3.3:1 (hint, `features/auth/widgets/auth_ref.dart:691` %70 = 3.2:1; `features/events/event_detail_page.dart:1124` %60 = 2.6:1; `features/events/event_form_page.dart:1337` pasif etiket %60). Temadaki varsayılan hint doğru (`t.mut` 6.1:1). Anket sonuç çubukları `mut` %45 (`features/polls/poll_detail_page.dart:874,951`) 2:1 (çubuk, metin değil).

**A6-24 - ORTA - Kamera izin yok ekranı çıkmaz sokak (Q1)**
`tr390b\05e_kamera_izin_yok_tr.png`: siyah zemin, kilit çizimi, "Kamera kullanılamıyor.", yalnız "Kapat". "Ayarlardan aç" eylemi/neden yok (galeri izni yok sahnesinde de aynı: `02b_galeri_izin_yok_tr.png` kontrol edin). Kamera normal/kayıt/flaş durumları sade ve tutarlı (`05_kamera`, `05b_kamera_kayit`, `05c_kamera_flas_otomatik`); kare görüntü önizlemesinde "Açıklama ekle…" beyaz alanı koyu zeminde farklı yüzey (ONERI).

**A6-25 - ORTA - Takvim/akademik: koyu temada ders renk örnekleri ve rozetler sabit renk**
`features/academic/academic_models.dart:100-109` (10 sabit renk) aynı renk açık ve koyu temada kullanılıyor; kart üzeri rozet/serit kontrastı koyu temada hesaplanmadı (örnekler `tr390\01_ders_programi_koyu_tr.png` görsel olarak okunur ama token'dan geçmiyor).

### DUSUK

**A6-26 - DUSUK - RTL: `left/right` sabit dolgu ve yön duyarsız simgeler (kod okuması)**
`EdgeInsets.only(left/right)`: `features/profile/notification_prefs_page.dart:363`, `features/events/events_page.dart:1723`, `widgets/academic_picker.dart:144,206`, `features/clubs/club_detail_sheets.dart:162`, `features/clubs/club_detail_page.dart:702`, `features/academic/academic_calendar_page.dart:113`. `buDirIcon` uygulanmayan yön simgeleri: `features/events/events_page.dart:1408 (arrowRight)`, `features/media_crop/media_crop.dart:81 (chevronRight)`, `features/home/home_parts.dart:414` ve `features/academic/academic_hub_page.dart:344` (BuButton `icon: arrowRight`; `BuButton` simgeyi aynalamıyor, `widgets/bu_widgets.dart:508`), `logOut` simgesi (10+ yer) aynalanmaz. ar390'da kontrol edilen sahnelerde (kimlik "Devam", takvim, hub "خطة الجلسة", profil, bildirim tercihleri) yön doğru; bu liste ekrana bakılmamış yerler için.

**A6-27 - DUSUK - Arapça: Inter'da glif yok, sistem yedek yazı tipi**
`pubspec.yaml` yalnız Inter (Latin); Arapça glifler cihaz yazı tipine düşüyor (ağırlık/boyut ölçüsü Inter'la uyumsuz olabilir; testte Arial ikamesi). Latin rakam her yerde (`18 نوفمبر 2026`, `01:42`) tutarlı ama Arapça-Hint rakamı beklentisi ONERI.

**A6-28 - DUSUK - Karma yönlü metin**
`ar390\02_giris_hatali_alanlar_ar.png`: e-posta alanı LTR kalıyor (doğru), hata cümlesi içindeki `bingol.edu.tr` doğru sıralanıyor; "name.surname@bingol.edu.tr أو 226051015" ipucunda sıra karışık okunuyor (e-posta ve numara bidi ayrı `Directionality.ltr` içinde değil). ORTA/DUSUK sınırı.

**A6-29 - DUSUK - Koyu tema pasif anahtar iz/başparmak**
Bkz. A6-17; ayrıca `p2_tr390\qa_bildirim_tercihleri_koyu_tr.png`: açık anahtar başparmağı `#1A0907` ton, iz bordo (3:1 altı).

**A6-30 - DUSUK - Shots testi çürümesi (varsayılan olarak atlanan test grubu)**
`_tapText` Türkçe sabit metinleri yeni l10n ile eşleşmiyor: p11 (3), p13 (1), p17 (2), n3 (1), p18 (2 + Timer), k8/k9/k10 ar sahneleri (37). Bu sahneler üretilemedi; denetim kapsamında kalıyor. Öneri: CI'ya `STORE_SHOTS_OUT` koşusu + `finder` kırılımları.

**A6-31 - DUSUK - `p00_gallery` "Girdiler" panosu 320 dp'de 32 px taşıyor**
`galeri 03_girdiler_tr/x1.3`: 2 Switch + 2 Checkbox + 2 Radio tek `Row` (`test/redesign/p00_gallery_shots_test.dart:300-307`). Gösterim panosu, uygulama ekranı değil.

**A6-32 - DUSUK - Ölü kod**
`widgets/bu_motion_widgets.dart:210 BuPageRoute` kullanılmıyor (112 `MaterialPageRoute`, tema geçişi `BuPageTransitions` tutarlı: olumlu).

**A6-33 - OLUMLU gözlemler (hata değil, tutarlılığı korumak için not)**
"Animasyonları azalt" 15 yerde `BuMotion.reduced/of` ve `disableAnimationsOf` ile uygulanıyor (iskelet, splash, QR tarama, kayan gösterge, basma ölçeği): sürekli animasyonların hepsi (`repeat`) koşullu. Sayfa geçişi tek tema (`BuPageTransitions`). `IconButton`'ların hepsi `tooltip`/semantik etiketli (kod taraması: eksik yok, `auth_ref.dart:55` Semantics ile sarılı). N4 alt çubuk (ad+rozet semantiği, RTL'de gösterge aynalanıyor, klavyede gizleniyor), varsayılan avatar paleti 6 renk/grup/kare çalışıyor. tr390/ar390'da taşma yok.

### ONERI (özneldir, hata sayılmadı)

- O-1 "Kulüp sohbeti" düğmesi lacivert (`nav` rengi) ve "Katıl/Takip Et" kırmızı: birincil eylem rengi iki aileden (`tr390\16_detay_kaydirilmis_tr.png`).
- O-2 Alt çubuk "Sohbet" rozeti seçiliyken gizleniyor (`floating_nav.dart` `n > 0 && !selected`): sohbet sekmesindeyken toplam okunmamış görünmüyor.
- O-3 Açık tema kartları gölge+çizgi+köşe 20; koyu tema `sf`/`sf3` farkı 1.19:1: yükseklik hiyerarşisi için üçüncü yüzey tonu ayrışsın.
- O-4 Yükleme/boş/hata durumları: `LoadingView/ErrorView/EmptyView` (`widgets/common.dart`), `BuState` (`widgets/bu_state.dart`), özel iskeletler birlikte var; sekmeler arası aynı bileşenin kullanımı örnek denetimde tutarlı ama doğrulanmadı.
- O-5 Etkinlikler ve Akademik sayfalarında seçili gün/çip lacivert-beyaz ters çevrilen stil; marka kırmızısıyla birleştirilebilir (A6-03).
- O-6 Mikro metin büyük harf başlıklar (UYGULAMA TERCİHLERİ 11 sp, harf aralıklı): okunurluk için 12 sp ve sentence case.
- O-7 Arapça için Noto Naskh/IBM Plex Arabic gibi paketlenmiş yazı tipi.
- O-8 `kNavInset` yerine `Scaffold(extendBody)`'nin zaten verdiği `MediaQuery.padding.bottom`'u okuyan `BuScrollPadding`.

## 3. Kontrol listesi sonucu (özet)

| Madde | Sonuç |
|---|---|
| Taşma/kırpılma | tr390 + ar390: 0 taşma. 320: 1 gerçek (A6-12) + 1 pano. Metin kırpılması: A6-04, A6-05, A6-11, A6-22 |
| Tipografi hiyerarşisi | A6-07 (iki sistem, küçük punto); segment A6-22 |
| Ikon seti | A6-19 |
| Yarıçap/gölge | A6-20 (token dışı ~70) |
| Renk/kontrast | A6-02, A6-16, A6-17, A6-23, A6-29; durum renkleri (başarı/uyarı/hata) tutarlı: push yardımı ve ayarlarda ikon+renk birlikte (olumlu) |
| Dokunma hedefi | A6-14, A6-15 |
| Boş/yükleniyor/hata | örnek denetimde tutarlı (O-4) |
| Modal/sheet/diyalog | A6-01, A6-20 |
| Toast | A6-20 (6 ham SnackBar) |
| Animasyon/geçiş | tutarlı (A6-33) |
| Safe area / alt çubuk | A6-06 (hesap) |
| Klavye `viewInsets` | bakılamadı (alt çubuk klavyede gizleniyor, olumlu) |
| Yatay mod | bakılamadı |
| Ekran okuyucu | A6-15; IconButton tooltip eksiği yok |
| Büyük yazı + RTL | taşma yok (ar390 1.3x) |
| RTL simge/dolgu | A6-26 |
| Çoklu dil | en390 kısmi örnek: taşma yok; ar: A6-27/28 |

## 4. Yeniden üretme

```bash
# kopya: git archive HEAD mobile | tar -x -C C:/bu_qa/a6src ; cd C:/bu_qa/a6src/mobile && flutter pub get
export PUB_CACHE='C:\pubcache' PATH="/c/src/flutter/bin:$PATH"
STORE_SHOTS_OUT=C:/bu_qa/shots/a6/tr390 K1_OUT=... N4_OUT=... K2_MODES=light,dark,x13 ... \
  flutter test test/redesign/*_shots_test.dart test/store_shots_test.dart --no-pub -j 6
# ar: <ÖN>_LANG=ar ; dar: QA_W=320 ; a11y: QA_A11Y=1 QA_A11Y_OUT=<dosya>
```
`QA_W`, `qa_a11y.dart`, `qa_p2_shots_test.dart` repoda YOK (yalnız `C:\bu_qa\a6src` kopyasında). Düzeltme sırasında kalıcı yapmak istenirse (shots testlerine genişlik/erişilebilirlik kancası) ayrı iş olarak alınmalı.
