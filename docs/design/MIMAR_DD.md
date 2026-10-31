# MIMAR DD: Kulüpler, Anketler, Destek, Etkinlikler, Akademik

Kapsam: `docs/MOBILE_PAGES.md` G, H, I, J bölümleri (ekran 58-88) ve alt sayfa/diyalog/seçiciler.
Yöntem: mevcut shot testleriyle (p11, p13, p14, p16, p17, k7, k9, k9_detail, k10) "önceki" görüntüler alındı
(`C:\bu_qa\shots\tasarim\dd\onceki`), incelendi, uygulandı, "sonra" görüntüler `...\dd\sonra`.
Kapaksız kulüp/etkinlik için yeni `test/redesign/dd_cover_shots_test.dart` (tr390 açık/koyu/x1.3).

Önceki paketler (P11-P17) bu alanları büyük ölçüde cilalamıştı; bulgular o yüzden az ama somut. Davranış, API ve ağ
katmanı değişmedi; yeni renk ve yeni metin (ARB) eklenmedi.

| # | Ekran | Bulgu | Öneri | Durum |
|---|---|---|---|---|
| 1 | Etkinlik detayı (74), Kulüp detayı (58) kapağı | Kapak yokken düz marka kırmızısı vitrin (gradyan + daire/dalga): sayfanın en gürültülü, en baskın yüzeyi; fotoğraflı kapaklarla ve palet "sakin" dili ile uyumsuz | Yeni `CalmCover`: `t.tint(seed)` ailesinden (kulüp/topluluk kimliğiyle kararlı) yumuşak zemin, hafif iki daire, silik büyük simge. Yeni renk yok | Uygulandı (`features/events/calm_cover.dart`; eski `EventCoverFallback` silindi) |
| 2 | Etkinlik formu (75) hızlı çipler | Tarih/saat/süre çiplerinde seçili durum KOYU LACİVERT dolgu; uygulamanın tek "seçili çip" stili (BuChip: yumuşak zemin + onSoft + ince marka çerçevesi) ile çelişiyordu; "Tarih seç" eylem çipi seçili çiple karışıyordu | Seçili = BuChip stili + onay işareti; eylem çipi (Tarih seç) çerçeveli nötr; çerçeve her zaman var (seçince zıplama yok) | Uygulandı |
| 3 | Anket detayı sonuç satırı (66) | Açık ve oy verilmiş ankette yüzde iki kez: sağ üstte `%48`, altta `%48 · 14 oy` | Alt satır yalnız oy sayısı | Uygulandı (p13 testi güncellendi: oy sayıları + " · " yok) |
| 4 | Öneri panosu (71) kartı | Oy düğmesi kartın en alt satırında tek başına, kart ~%25 daha uzun, boş alan | Dikey oy düğmesi (ok üstte, sayı altta; min 56x64) başlık/metin satırında sağda; boş durum CTA'sı düz marka düğmesi (hero gradyanı kalktı) | Uygulandı (`VotePill.vertical`) |
| 5 | Ders programı (80) günlük akış | Gelecekteki HER derste "Bekliyor" hapı (gürültü; saat zaten hapta); tüm sol çubuklar aynı koyu mürekkep | "Bekliyor" kaldırıldı (durum yalnız Şimdi/Bitti); sol çubuk dersin kendi rengi (bitti: soluk, süren: marka) | Uygulandı |
| 6 | Kulüp listesi, Kulüplerim, kulüp yönetimi, anket formu/liste, destek talebi/geri bildirim, QR/yoklama, akademik takvim/sınav/duyuru | İncelendi: hiyerarşi, boşluk ritmi, durumlar tutarlı; basma geri bildirimi/giriş animasyonu mevcut | Değişiklik gerekmedi | Uygulanmadı (gerekçe: kilitli arayüz, somut iyileşme yok) |
| 7 | Destek ana ekranı (67): SSS ve Taleplerim kartı içinde gri iç kartlar | Çift katman hissi | Önerildi, uygulanmadı: ekranın iki bölümü ortak `BuCard`/liste bileşenine bağlı, ortak dosya değişikliği gerekir | Uygulanmadı |
| 8 | Talep sohbeti (69) kendi mesajı dolu marka kırmızısı | Büyük kırmızı yüzeyler | Sohbet baloncuk dili ile aynı (tutarlılık için bırakıldı) | Uygulanmadı |

Ortak dosyalarda gereken değişiklik: yok. (Öneri: `BuGradientHero` yalnız Ana Sayfa/karşılama/profil başlığında
kalsın; kulüp/etkinlik kapağı artık kullanmıyor, dokümandaki "etkinlik/kulüp kapağı" ibaresi güncellenmeli.)

Notlar: Duyuru kapsamı (W1-F: "Tümü" yalnız kapsamsız duyurular) için ekran metinlerine dokunulmadı; davranış
değişmedi.

---

## Tur 2: ince detay + animasyon (P2-DD)

Kural: yalniz transform/opacity, 150-400 ms, surekli dongu yok, kaydirirken yok, "animasyonlari azalt" acikken aninda.
Renk (yonetici karari): ekranda en cok 2 vurgu rengi (marka + en cok bir ikincil); kategori basina renk kalkti, durum
renkleri (ok/uyari/hata) kaldi; amber yalniz uyari.

| Ekran | Eklenen animasyon / detay | Dosya |
|---|---|---|
| Kulupler listesi | Kesfet <-> Kuluplerim icerigi `BuFadeThrough`; iskelet -> icerik `BuSwapIn`; ilk 8 kart `BuStaggeredList` (yenilemede tekrar yok); kart `BuPressable` (basinca 0.985) | clubs_tab.dart, clubs_widgets.dart |
| "Katil" dugmesi | Durum degisince (Katil -> Uyesin / Istek gonderildi) dugme `BuFadeThrough` + `BuPop`; Uyesin'de onay simgesi; katilinca hafif titresim; yukleniyor = BuButton.busy | clubs_widgets.dart, clubs_tab.dart |
| Kulup karti -> detay | Logo `BuHero` (etiket `bu-hero-club-<id>`, kose 18 -> daire), detayda iskelet asamasinda da varis noktasi + listeden gelen ad/logo (`previewName/previewLogoUrl`) ile gercek logo ucar | club_detail_page.dart |
| Kulup detayi | Kapak paralaks (kaydirmanin %60'i hizinda; yalniz transform); baslik cubugu belirmesi ve sekme gostergesi (BuSegmented) zaten vardi | club_detail_parts.dart |
| Etkinlik takvimi | Ay gecisi `BuSharedAxis` (ileri/geri yone gore yatay); gun secimi dolu daire 0.6 -> 1 olcek + solma; etkinlik noktasi 0 -> 1 olcek; gun yazisi renk gecisi | events_page.dart |
| Etkinlik detayi | Eylem cubugu durum gecisi (`BuFadeThrough`); yoklama blogu gecisi; "geldi" onay dairesi yaylanarak belirir | event_detail_page.dart |
| CalmCover | Simge tek seferlik solma + %90 -> %100 (daireler statik); tek sakin ton (soft/onSoft) | calm_cover.dart |
| Anket | Yuzde sayaci `BuCountUp` (tabular rakam); secenek dokunusunda `selectionClick`; yildiz = marka rengi (amber yalniz uyari) | poll_parts.dart, poll_detail_page.dart, anket_style.dart |
| Destek | SSS oku 180 derece doner + renk gecisi, cevap solarak acilir; talep karti `BuPressable`; talep durum hapi gecisi | support_page.dart, support_ticket_page.dart |
| Akademik: ders programi | Gun degisince akis `BuSharedAxis`; "Simdi" cizgisi (gecmis/yaklasan arasi, tek seferlik belirme); kalan dakika sayaci kayarak degisir; sol cubuk ve kod hapi notr | timetable_page.dart, timetable_parts.dart |
| Akademik: takvim | Ay gecisi `BuSharedAxis` + baslik `BuFadeThrough`; gun hucresi renk/yazi gecisi, `BuPressable`, nokta olcekle belirir | academic_calendar_page.dart |
| Akademik: sinavlar | Sekme icerigi `BuSharedAxis` | exams_page.dart |
| Renk sadelestirme | Anket kapsam rozetleri, etkinlik tarih karosu, CalmCover, akademik takvim tur renkleri (yalniz vize/final/but vurgulu), ders cubugu/kodu: tek notr + tek vurgu; "ilgileniyorum" ve "kayit kapali" amber degil notr | ilgili dosyalar |

Uygulanmayanlar / gerekce: (1) Etkinlik karti -> detay kapak Hero: liste kartlarinda kapak gorseli yok (tarih blogu var), uydurma ucus anlamsiz. (2) Ders gun seridinde kayan tek hap: hap genislikleri degisken ("bugun" etiketi), olcum gerektirir; mevcut renk/cerceve gecisi + icerik kaymasi yeterli. (3) Sinav sayaci pill gecisi: sayac yalniz yenilemede degisir. (4) QR yoklama tarama sayfasi `platform/` altinda (kapsam disi); ogrencinin "yoklama alindi" blogu animasyonlandi.
Ortak dosya onerisi: `BuSegmented` kayan hap zaten var; sinavlar sekmesi icin ayni bilesenin "soft" varyanti istenirse M0.
