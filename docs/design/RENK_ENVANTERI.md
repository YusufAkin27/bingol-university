# Mobil renk envanteri ve sadeleştirme (RENK-1)

Kullanıcı isteği: "mobil uygulamada çok fazla renk var; sabit renklere çevir, göz yormasın ama orada olduğunu bilelim, kafa karıştırmasın, temiz renkler olsun."

Karar: **tek, küçük, anlamlı palet = sakin marka kırmızısı + 4 anlam ailesi (koyu mavi, su mavisi, yeşil, amber) + sıcak-nötr yüzeyler.** Kategori ayrımı renkten çok **simge + etiketle** yapılır. Mor, pembe, turkuaz-yeşil karışımları, çivit, turuncu ve sarı ayrı renk olarak kaldırıldı. Tasarım KİLİTLİ olduğu için yalnız renk değişti; düzen, boyut, imza değişmedi.

## 1. Son palet (tek kaynak: `mobile/lib/core/theme.dart` -> `BuTokens`)

Her anlam ailesi 3 tondur: **ana** (simge/çizgi/vurgu yazısı), **yumuşak zemin**, **zemin üstü yazı**.

### Yüzey ve yazı (nötr, sıcak)

| Belirteç | Açık | Koyu | Not |
|---|---|---|---|
| `bg` sayfa | #F7F5F2 kırık beyaz | #171819 yumuşak kömür | saf siyah/beyaz yok |
| `sf` kart | #FFFFFF | #202123 | |
| `sf2` ikincil | #EEEBE6 | #2A2B2E | segment, yer tutucu, iskelet |
| `sf3` üst katman | #FFFFFF | #313235 | diyalog, alt sayfa, menü |
| `bd` çizgi | #DAD5CD | #3A3B3F | kart/ayraç (dekoratif); kart ayrımı çizgi + gölge |
| `bdStrong` | #8A857E | #7D8087 | kontrol çerçevesi (giriş, arama, seçilmemiş halka, outlined düğme); tüm yüzeylere >= 3:1 (A6-02) |
| `ink` / `mut` | #171E33 / #5C5A56 | #F2EFEA / #A9A7A2 | ink = lacivert mürekkep (marka) |
| `nav` / `onNav` | #171E33 / #FFFFFF | #35373B / #F2EFEA | yüzen/koyu hap |

### Marka (yalnız ana eylem, seçili durum, vurgu)

| Belirteç | Açık | Koyu |
|---|---|---|
| `pr` / `onPr` | #C0392B / #FFFFFF | #F0766A / #2A0B07 |
| `soft` / `onSoft` | #FBE9E6 / #8A2A20 | #3B2321 / #FFBBB2 |
| `h1` -> `h2` (hero, neredeyse düz) | #C8402F -> #BB3628 | #B5362B -> #992E24 |

Simge kırmızısı #F73B2E (`BuColors.red600`) değişmedi; arayüz eylem kırmızısı simge tonundan (ton 4 derece, doygunluk %72 -> %63) türetilerek sakinleştirildi, simgeyle uyumlu kalır. Splash (#C62A20) ve bildirim vurgusu (#F73B2E) yerel Android kaynaklarında olduğu gibi duruyor.

### Anlam aileleri

| Aile | Anlam | `ana` açık / koyu | `yumuşak` açık / koyu | `üstündeki yazı` açık / koyu |
|---|---|---|---|---|
| Mavi (`info`) | bilgi, haber, duyuru, kişisel/hesap | #1F4E96 / #8DB4F0 | #E4ECF8 / #1B2B45 | #173F7B / #B9D2FA |
| Su mavisi (`aqua`) | ikincil vurgu (etkinlik, topluluk, duyuru rozeti) | #0B6E86 / #6CCBE0 | #DDF1F6 / #11323B | #0A5468 / #A6E3F0 |
| Yeşil (`ok`) | başarı, onay, yemek | #1E7A50 / #6FD0A0 | #E0F2E8 / #16301F | #0F5132 / #9BE3BE |
| Amber (`warn`) | uyarı, hatırlatma, bekleyen | #9A5700 / #F2B24A | #FFF1D6 / #3A2B0E | #6B3E00 / #FFD98F |
| Hata (`danger`) | hata, yıkıcı eylem | #A3162E / #FF8FA0 | #FBE4E8 / #3D1D24 | `danger` kendisi |
| Nötr (`tints[5]`) | sistem, ayar | - | #EAE8E4 / #2E2F32 | #45423E / #C9C7C2 |

`danger` marka kırmızısıyla karışmasın diye daha koyu ve pembeye yakın tonda (ton farkı >= 10 derece, testle denetlenir).

### Kategori listesi `tints` (indeks API'si korunur; adlı indeksler `BuTintId`)

| İndeks | Ad | Önce (açık) | Sonra (açık) |
|---|---|---|---|
| 0 | `BuTintId.brand` | kırmızı #FDE7E4/#8E1B13 | #FBE9E6/#8A2A20 |
| 1 | `BuTintId.blue` | mavi #E3EDFB/#1B4E96 | #E4ECF8/#173F7B |
| 2 | `BuTintId.green` | yeşil #DFF3E8/#1B6B43 | #E0F2E8/#0F5132 |
| 3 | `BuTintId.amber` | kehribar #FDEFD2/#7A4A00 | #FFF1D6/#6B3E00 |
| 4 | `BuTintId.aqua` | **mor** #EDE6FA/#55359A | **su mavisi** #DDF1F6/#0A5468 |
| 5 | `BuTintId.slate` | **turkuaz** #D9F1F1/#115E5E | **nötr** #EAE8E4/#45423E |

## 2. Envanter: önce / sonra

Tarama: `grep "Color(0x"`, `Colors.`, `tint(`, gradyan, avatar, ders rengi, rozet/çip. Sayılar `mobile/lib` içindir.

| Alan | Önce | Sonra |
|---|---|---|
| `Color(0x..)` literali (`theme.dart` dışı) | 25 satır, 7 dosya | yalnız: avatar paleti (painter, bağlamsız), ders rengi tabanı (`academic_models.dart`), sabit sohbet gölgesi, bir şeffaf başlangıç değeri. Test (`renk_paleti_test.dart`) izinli dosya listesi dışına çıkışı engeller |
| `Colors.white/black/red...` | 7 kullanım (floating_nav 2, kamera 1, avatar 4) | yalnız avatar painter'ında `Colors.white` (parlama). Kalan hepsi `onMedia`/`scrim` |
| `ColorScheme` sabit hex'leri (`onTertiary`, `onError`, `errorContainer`...) | 5 sabit | 0: tümü belirteçten (`onPr`, `onOkSoft`, `dangerSoft`) |
| Radyo "kapalı" halkası | iki sabit soğuk hex | `mut` %70 |
| Ana tema ailesi | kırmızı, mavi, yeşil, kehribar, mor, turkuaz + 10 ders rengi + 6 avatar rengi | marka + mavi + su mavisi + yeşil + amber + nötr |
| Gradyan | hero (kırmızı, belirgin), karşılama (lacivert), fotoğraf karartmaları | hero iki ucu neredeyse eş (luminans farkı < .04, testli); fotoğraf karartmaları ve karşılama aynı (anlamlı) |
| `tint(...)` çağrısı | 144 satır | aynı yerler, ama değerler 4 aileden; yanlış eşlemeler düzeltildi (aşağıda) |

### Ekran bazında eşleme değişiklikleri

| Yer | Önce | Sonra |
|---|---|---|
| Ana Sayfa hızlı erişim karoları | haber kırmızı, yemek yeşil, etkinlik kırmızı, kulüp mavi, akademik kırmızı (enum adı ile renk ters eşleşiyordu) | haber mavi, yemek yeşil, etkinlik su mavisi, kulüp su mavisi, akademik mavi (`HomeTone.aqua` eklendi) |
| Bildirim türleri | kırmızı/mavi->kırmızı/yeşil->mavi/amber->yeşil (ters eşleme) | beğeni marka, kulüp su mavisi, mesaj/anket mavi, diğer nötr (`NotifTone.aqua/slate` eklendi) |
| Haber/duyuru/etkinlik rozeti | duyuru kehribar, etkinlik yeşil, haber kırmızı | haber mavi, duyuru su mavisi, etkinlik amber |
| Arama sonucu karoları | haber kırmızı, kulüp mavi, etkinlik yeşil, gönderi mor, kişi turkuaz, duyuru kehribar | haber mavi, kulüp yeşil, etkinlik amber, gönderi/duyuru su mavisi, kişi nötr |
| Anket kapsamı | genel mavi, kulüp yeşil, yemek kehribar | genel mavi, kulüp su mavisi, yemek yeşil |
| Etkinlik tarih karosu (id'ye göre) | kırmızı/mavi/yeşil | amber/mavi/su mavisi |
| Profil sekmesi ayar satırları | 5 farklı renk (mor, yeşil, kehribar, turkuaz, mavi) | yalnız mavi (kişisel/hesap) + nötr (sistem) |
| Sözleşme türleri | kırmızı/mavi dönüşümlü | sözleşme mavi, gizlilik/KVKK su mavisi, kurallar yeşil, diğer nötr |
| Sohbet etiketi (kulüp/etkinlik) | kulüp kırmızı, etkinlik mavi | kulüp yeşil, etkinlik mavi |
| Takipçi/takip özeti | kırmızı/mavi | su mavisi/mavi |
| Sınav türü final | mor | su mavisi |
| Akademik ders rengi seçici | 10 renk (kırmızı, turuncu, sarı, yeşil, turkuaz, mavi, çivit, mor, pembe, gri) | 6 renk: mavi, su mavisi, yeşil, amber, kırmızı, gri; eski sunucu anahtarları (orange/indigo/purple/pink) en yakın aileye eşlenir. Sarı (#E5A400) beyaz üstünde AA geçmiyordu, amber #9A5700 oldu |
| Akademik takvim türleri | mavi, yeşil, kırmızı, mavi, mor, turuncu, turkuaz, gri | mavi, yeşil, kırmızı, mavi, amber, su mavisi, su mavisi, gri |
| Varsayılan avatar paleti | kırmızı, lacivert, kum, turkuaz, mor, mavi | kırmızı (sakin), lacivert, kum, su mavisi, yeşil, mavi (mor kalktı) |
| Seçili çip/segment | 3 stil: dolu kırmızı (Keşfet), pembe+kırmızı çerçeve (Sohbet/Kulüp), lacivert/beyaz ters (Akademik, Etkinlik, Arama, Bildirim, Destek) | TEK stil: `soft` + `onSoft` + `selectedBorder` (A6-03); 11 yerde |
| Giriş alanı / seçim halkası çerçevesi | `bd` (1.2:1 açık, 1.07:1 koyu) | `bdStrong` (>= 3:1) (A6-02/16); seçili sohbet dairesinde onay işareti |
| Durum çubuğu | tema otomatik | `AppBar.systemOverlayStyle` açık/koyu için açıkça verildi (Android `statusBarIconBrightness`, iOS `statusBarBrightness`) |
| iOS Cupertino | varsayılan mavi tema | `cupertinoOverrideTheme`: aynı `pr`, `bg`, `sf3` belirteçleri |

## 3. Koruma (testler)

`mobile/test/redesign/renk_paleti_test.dart`:
- Tüm metin/zemin çiftleri (ink/mut/pr/ok/info/aqua/warn/danger + ailelerin yumuşak zeminleri + 6 tint + ders renkleri + hero) açık ve koyu temada WCAG AA >= 4.5; metin olmayan ögeler >= 3.
- Aileler tutarlı: `tints[1]` = `info` ailesi, `tints[2]` = `ok` ailesi, vb.
- Mor/pembe/turkuaz karışımı yok: tüm paletin tonu yalnız kırmızı-amber, yeşil, mavi/su mavisi aralıklarında.
- `danger` ile `pr` ton farkı >= 10 derece; yüzeyler düşük doygunluk; koyu tema saf siyah değil.
- `lib/` taraması: izinli dosyalar dışında `Color(0x..)` ve `Colors.white/black/...` yok.

## 4. Yeni kod için kural

- Renk yalnız `context.bu`; kategori için `context.bu.tint(BuTintId.xxx)`; durum için `ok/warn/danger/info/aqua` aileleri.
- Yeni renk eklenmez; gerekiyorsa mevcut aileye ton eklenir ve bu belge + `renk_paleti_test.dart` güncellenir.
- Ayrım için önce simge + etiket; renk ikinci sırada.
