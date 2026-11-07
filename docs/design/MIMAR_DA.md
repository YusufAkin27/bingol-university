# MIMAR DA: kök, kapılar, sistem durumları ve kimlik akışı (MOBILE_PAGES bölüm A ve B)

Kapsam: ekran 1-19 (Splash, ConfigError, hata görünümü, AppGate, güncelleme/bakım/çevrimdışı/erişim engeli, şeritler, PushBanner, izinler, yeniden onay, sözleşmeler, QR tarama) ve 20-27 (Karşılama, Giriş, Kayıt, doğrulama, şifre sıfırlama). Davranış, rota, API ve ağ katmanı DEĞİŞMEDİ; yalnız görünüm ve hareket. Renk yalnız `context.bu`, hareket yalnız ortak BuMotion parçaları (`BuStaggerScope/BuStaggerItem`, `BuSharedAxis`, `BuFadeThrough`), "animasyonları azalt" açıkken anında.

Önce/sonra görüntüleri: `C:\bu_qa\shots\tasarim\da\onceki|sonra\` (tr390 açık + koyu, ar390, tr390 x1.3). 320 dp + 1.3x yazı + RTL taşma denetimi `test/redesign/da_auth_system_test.dart` içinde 52 ekran/tema/yön kombinasyonu ile otomatik.

| No | Ekran | Bulgu | Öneri / uygulama | Durum |
|---|---|---|---|---|
| 5 | UpdateRequiredScreen | Simge Material `Icons.system_update`, 96 dp; diğer durum ekranları Lucide 88 dp: dört ekran tutarsız | Ortak `_GateIcon` (88 dp, Lucide `smartphone`, marka tonu) | uygulandı |
| 6 | MaintenanceScreen | Üstten akan düzen, düğme ortada asılı, yatay boşluk 16 (diğerleri 24); iç içe gri/beyaz simge karosu | Ortak düzen (içerik ortada, düğme altta, 24 dp), `_GateIcon` nötr ton, Lucide `wrench` | uygulandı |
| 7 | OfflineScreen | Kırmızı soluk karo + nokta rozeti: "alarm" hissi, "sakin" hedefiyle çelişir | Nötr (gri) karo, rozet kaldırıldı, bakım ekranıyla aynı dil | uygulandı |
| 8 | AccessBlockedScreen | Üstten akan düzen (farklı yerleşim) | Ortak düzen; düğme (maks. 320 dp) altta | uygulandı |
| 5-8 | Dört ekran ortak | Girişte anlık beliriyor | `BuStaggerItem` sırası: simge, başlık+metin, ek hap, düğme (40 ms aralık, 400 ms); azalt açıkken anında | uygulandı |
| 1 | SplashScreen | Splash her kök değişiminde yeniden kurulur (Splash -> `_SignedOutRoot` Splash); giriş animasyonu eklenirse titrer | Dokunulmadı (halka sürekli döner, sıçrama yok) | uygulanmadı: gerekçe yanda |
| 1 -> ilk ekran | Splash -> AppShell geçişi | `main.dart` `home` anahtarı anında değişiyor (kesme). Çözüm `main.dart` içinde `AnimatedSwitcher`/`BuFadeThrough` | `main.dart` kapsam dışı: öneri olarak rapora yazıldı | ertelendi |
| 20 | WelcomePage | Üç özellik satırında `>` oku var ama satırlar dokunulmaz (yanlış beklenti); dil hapı dokunma hedefi 24 dp; giriş anlık | Ok kaldırıldı; dil hapı >= 44x40 dp, seçili dilim 150 ms yumuşak geçiş; hero, üç satır, not, düğmeler sırayla belirir | uygulandı |
| 21 | LoginPage | Klavye açılınca marka bloğu ve alt bağlantılar aniden kayboluyor (düzen sıçraması); giriş anlık | Marka bloğu ve alt blok `AnimatedSize` ile yumuşakça daralır; kart ve alt blok aşamalı belirir | uygulandı |
| 22 | RegisterPage | Adım geçişi yalnız solma; yön yok; yükseklik farkı adımda sıçrıyor | `BuSharedAxis` (ileri/geri yönlü kayma + solma, RTL aynalı) + `AnimatedSize`; hata ile adım 1'e dönüşte yön doğru | uygulandı |
| 23/25 | OtpCodeBoxes (doğrulama + sıfırlama kodu) | `hasError` parametresi hiç çizilmiyordu (yanlış kodda kutular normal); ilk kutu 8 dp geniş çiziliyordu (dolgu Expanded içinde); odak halkası yok | Kutular eşit genişlik (boşluk SizedBox), hata: hafif kırmızı dolgu + 1.5 dp çerçeve + kırmızı rakam; odakta marka çerçevesi (alan diliyle aynı); sarsıntı korunur | uygulandı |
| 23 | VerifyCodePage | "Yeniden gönder" ve "E-postayı değiştir" iki satıra sarıldığında sol kenarları hizasız (RefLink 10 dp dolgulu) | Her ikisi `compact` (dolgu yok, dokunma alanı 48 dp korunur): sarıldığında hizalı, tek satırda sağ kenar kart dolgusuna oturur | uygulandı |
| 22 | AuthPasswordGuide | "Orta" güç hata gibi kırmızı gösteriliyordu | Zayıf kırmızı, orta kehribar (metin `onWarnSoft`, AA >= 4.5 testle doğrulandı), güçlü yeşil | uygulandı |
| 17/18 | LegalListPage / LegalDocPage | Satır dokunma dalgası görünmüyordu (InkWell, dolgusu olan Container altında kalıyordu); yükleme -> içerik geçişi anlık | Dolgu `Material`'e taşındı (dalga görünür, köşe kırpma korunur); durum gövdeleri `BuFadeThrough` ile yumuşak geçer | uygulandı |
| 19 | QrScanPage | Alt panel içerik yüksekliğinde bitiyor: uzun ekranlarda altta zemin renginde boşluk şeridi | Panel kalan yüksekliği doldurur (`minHeight`) | uygulandı |
| 9/11 | TopStrip, GateNoticeStrip, UpdateNotice | İncelendi: tutarlı ton, dokunma hedefleri yeterli | Değişiklik gerekmedi | uygulanmadı: sorun yok |
| 12 | PushBanner | İncelendi: kaydırarak kapatma, 220 ms giriş, birleşik kart; azalt desteği var | Değişiklik gerekmedi | uygulanmadı: sorun yok |
| 3 | Hata görünümü / ConfigError | Nötr simge, sakin; ayrı MaterialApp'te | Değişiklik gerekmedi | uygulanmadı |
| 13/14 | PermissionsPage | İncelendi; kart/rozet dili tutarlı, dar ekranda kayar | Değişiklik gerekmedi | uygulanmadı |
| 15/16 | LegalReaccept | İncelendi (onay kartı Material + InkWell doğru) | Değişiklik gerekmedi | uygulanmadı |
| 11 | OfflineBanner/StaleLabel | `core/connectivity/offline_banner.dart` artık yok (envanter eski); çevrimdışı şeridi `TopStrip` ile | Belge güncellemesi önerilir | not |

Uygulanmayanlar ve ortak dosya önerileri:
- Welcome: "check-in" sözcüğünün tireden bölünmesi (`p02WelcomeClubsSub`, EN) metin kaynağında (ARB) çözülür (bölünmez tire); ARB kilidi/arkadaş ajanlar nedeniyle dokunulmadı.
- `main.dart`: oturum durumu değişiminde (`loading -> signedIn`) `home` anahtarının `AnimatedSwitcher` ile solması splash -> ilk ekran geçişini pürüzsüzleştirir (dosya kapsam dışı).
- `widgets/*` ortak dosyalar değiştirilmedi.

## Tur 2 (P2-DA): ince detay + animasyon

Kural: yalnız transform/opacity, 150-300 ms, sürekli döngü yok, "animasyonları azalt" açıkken anında, renk yalnız `context.bu`, bir ekranda en çok iki vurgu tonu. Test: `test/redesign/p48_da_motion_test.dart`.

| Ekran | Eklenen | Not |
|---|---|---|
| Kayıt adım çubuğu | `AuthStepBar`: her parça soldan (RTL'de sağdan) dolar, geri gidince boşalır (ScaleX, 250 ms) | eski renk değişimi yerine; çubuk Semantics dışı |
| Tüm kimlik alanları (`RefTextField`) | Hata ilk kez belirince alan hafif sarsılır (`AuthShake`); hata metni solarak belirir, kalkarken anında kalkar; çerçeve/dolgu geçişi azalt'a saygılı | düzelten kullanıcı beklemez |
| `RefButton` | Etiket <-> yükleniyor içeriği 150 ms çapraz solar (busy iken dokunma kapalı) | |
| Giriş / Kayıt | Sunucu hatası bandı yumuşak açılır + yeni hatada sarsılır; hata `AnimatedSize` süresi azalt'a saygılı | |
| OTP kutuları | Yeni rakam 0,6 -> 1 yaylanır (tekrar oynamaz); rakamlar tabular; `success`: kutular yeşil dolgu + yeşil çerçeve + hafif pop | doğrulama/şifre sıfırlama kodu sayfaları başarıda 260 ms yeşil gösterir (azalt: beklemez) + hafif titreşim |
| Parola göstergesi, kural satırı, yeniden gönder | Süreler `BuMotion` + azalt'a saygılı | |
| Bakım / Çevrimdışı | Simge karosunda ince "nefes" (1 -> 1,06), yalnız 2 nefes (6,4 sn) sonra durur | sürekli döngü yok; azalt: hiç yok; güncelleme/erişim engeli: yok |
| QR tarama | Çerçeve 1,08 -> 1 oturur; tarama çizgisi 3 gidiş-dönüşle sınırlı; başarıda çerçeve 0,92'ye daralır, köşeler yeşile döner, ortada onay dairesi belirir, çizgi gizlenir, hafif titreşim | |
| Karşılama | Üç özellik satırı tek vurgu tonu (marka yumuşak zemini); önceki üç farklı ton sadeleşti | |
| Sözleşmeler (liste + yeniden onay) | Dört belge rengi (mavi/aqua/yeşil/gri) tek tona (mavi) indi | |

Uygulanmayanlar: Splash -> kök geçişi ve Splash giriş animasyonu (main.dart M0'a ait; öneri: `home` anahtarı değişince `BuFadeThrough`); OTP imleç yanıp sönmesi (sürekli döngü yasağı); sözleşme listesi -> metin Hero/özel rota (platform geçişi ve geri hareketi korunur, gövde zaten `BuFadeThrough`); PushBanner/AppGate (incelendi, değişiklik gerekmedi).

## Tur 3 (minimal) + Stitch v3 (P3-AUTH)

Kural: ekranda nötr + en çok tek vurgu (marka kırmızısı), kart içinde kart/bilgi kutusu/süs simgesi yok, kenar 20 dp, tek birincil düğme. Kimlik ekranları ayrıca `C:\bu_design\stitch\v3_open\` (SARTNAME.md) Stitch PNG'lerine yaklaştırıldı. Önce/sonra: `C:\bu_qa\shots\tasarim\p3\da\onceki|sonra\`. Test: `test/redesign/p65_da_minimal_test.dart`.

| Ekran | Kaldırılan / sadeleşen | Renk (önce -> sonra) |
|---|---|---|
| Karşılama (Stitch 01) | Koyu gradyan hero + logo karosu + alt başlık, üç özellik KARTI (ikon dairesi + alt metin), mavi bilgi kutusu; yerine iki satırlı başlık, tek açıklama, nokta-metin üç satır, kırmızı tek düğme, düz metin "Kayıt ol", kayıt notu, sürüm. Dil seçici: seçili = soft zemin | 4 -> 2 |
| Giriş (02/03/04) | Kart sarmalı, logo + rozet + "Bağımsız öğrenci uygulaması" etiketi, alan simgeleri, düğme oku; "Şifremi unuttum" alanın altında sağda; hata satırı kutusuz danger metin; bekleyen doğrulama = ikonsuz warnSoft not + iki metin düğmesi | 4 -> 2 |
| Kayıt 1/3-3/3 (05/06/07) | Bölüm etiketi + ikon, ampul/bilgi kutuları (tek muted satır), seçici kartı (üstte etiket + beyaz alan + düz chevron), "Adım n/3" üst çubukta sağda, 4 dp çubuk; şifre gücü nötr (ink doluluk + kelime), kural satırları ink tik/boş halka | 5 -> 2 |
| Doğrulama kodu (08), şifre kodu (10) | Kart ve üst etiket yok, OTP kutuları beyaz + bdStrong, odak pr, hata danger çerçeve (pembe dolgu yok), Yapıştır kutuların altında sağda, durum metni kutusuz | 4 -> 2 |
| Şifremi unuttum (09), yeni şifre (11) | Anahtar simgesi, kart sarmalı, düğme oku; alanlar beyaz | 3 -> 2 |
| Şifre güncellendi (12) | Çift halka + gölgeli onay + kart; 56 dp okSoft daire + ok onay, alta sabit tek düğme | 3 -> 2 |
| İzinler (13/14) | Adım çubuğu, üç kart, simge karoları, durum hapları; düz satırlar + ince ayırıcı, sağ üstte outlined "İzin ver" / Verildi / Reddedildi, alt birincil + "Şimdi değil" (yalnız ilk durumda) | 4 -> 2 (+durum) |
| Yeniden onay (15), sözleşme listesi (16), okuyucu (17) | Satır simge karoları (mavi), kart, gölge; düz satırlar + ayırıcı, okuyucuda kartsız metin; boş/hata tek muted cümle (+ metin düğmesi) | 3 -> 2 |
| Güncelleme / bakım / çevrimdışı / erişim engeli | Sürüm hapı, hata kodu hapı, bakım üst şeridi (başlıkla tekrar), 24 -> 20 dp kenar; tek simge + başlık + tek cümle + tek düğme; metinler kısaldı (ARB) | 3 -> 2 |
| QR tarama | Bilgi kutusu ve "veya" ayracı, izin yok ekranında çift karo + rozet noktası + kart içinde kart; kenar 20 | 4 -> 3 |

Uygulanmayanlar: Splash -> ilk ekran yumuşak geçişi (`main.dart` ortak: `home` anahtarı değişince `BuFadeThrough` önerisi sürüyor); splash (tek sürekli halka yükleme göstergesidir, dokunulmadı).
