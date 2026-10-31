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
