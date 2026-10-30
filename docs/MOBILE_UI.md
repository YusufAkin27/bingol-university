# Mobil arayüz (Flutter) — mimari ve çalıştırma

Paket adı `bu_kampus`; kaynak `mobile/` altındadır. Arka uç sözleşmesi için bkz. [MOBILE_API_GUIDE.md](MOBILE_API_GUIDE.md).

## 1. Klasör haritası (`mobile/lib/`)

| Yol | İçerik |
|---|---|
| `main.dart` | `BingolApp`: tema (açık/koyu/sistem) + oturum durumuna göre `LoginPage` / `AppShell` |
| `core/api.dart` | Tek HTTP katmanı: `ApiClient`, `ApiError`, `Tokens`; taban adres `apiOrigin`/`apiBase` |
| `core/session.dart` | `Session` (ChangeNotifier): oturum durumu, giriş/kayıt/çıkış, token'lar Keychain/Keystore'da (`flutter_secure_storage`) |
| `core/theme.dart` | `BuColors`, `BuTokens` (ThemeExtension), `BuTheme.light()/dark()`, `context.bu` |
| `core/theme_controller.dart`, `core/badges.dart` | Tema modu seçimi; alt gezinme/çan rozet sayaçları |
| `widgets/bu_widgets.dart` | Ortak bileşenler: `BuHeader`, `BuButton`, `BuChip`, `BuBadge`, `BuSegmented`, `BuCard`, `BuAvatar`, `BuSearchField`, `BuGroup`/`BuMenuRow`, `BuHeroCard` …; `initialsOf`, `fileUrl` |
| `widgets/common.dart` | Yükleniyor/hata/boş görünümleri, `StaleBanner`, tarih biçimleyiciler (`fmtDate`, `longDate`, `niceDate`, `relativeTime`) |
| `core/app_gate.dart`, `core/analytics.dart`, `core/app_hooks.dart`, `core/nav.dart` | Açılış kapısı (sürüm/bakım), analitik kuyruğu, oturum açma/kapama kancaları, gezinme anahtarı (ayrıntı bölüm 5) |
| `core/realtime/`, `core/push/`, `core/platform/` | STOMP istemcisi + sohbet gerçek zamanlı katmanı; FCM servisi + yönlendirici; görsel seçme/hazırlama |
| `features/<alan>/` | Özellik başına sayfalar: `auth`, `home`, `discover`, `chat`, `clubs`, `events`, `news`, `notifications`, `profile`, `search`, `support`, `menu`, `system` (kapı ekranları), `shell` |

Yeni ekran yalnızca kendi `features/<alan>/` klasöründe yazılır; ortak bileşen `widgets/` altında paylaşılır.

## 2. Tasarım dosyaları ve tema belirteçleri

- Tasarım kaynakları: `mobile/design/*.dc.html` (örn. `P-Chat.dc.html`, koyu karşılığı `P-Chat-Dark.dc.html`; kimlik doğrulama için `A-*`, ana sayfa varyantları `B-/C-/D-Home`).
- `BuTokens`, bu dosyalardaki CSS değişkenlerinin birebir karşılığıdır: `bg, sf, sf2, ink, mut, bd, pr, onPr, soft, onSoft, nav, onNav, h1, h2, ok, okSoft, danger`. Kullanım: `final t = context.bu;`.
- Örnek değerler: `pr` açık `#C62A20`, koyu `#FF6A5F`. `onPr` her iki temada `pr` üstünde en az 4.5:1 kontrastlıdır (`test/theme_test.dart` doğrular).
- Renk elle yazılmaz; her zaman `BuTokens` kullanılır (koyu tema otomatik çalışsın diye).

## 3. Gezinme yapısı

- `features/shell/app_shell.dart` alt sekmeli kabuktur. Sekmeler: **Ana Sayfa** (`HomeTab`), **Keşfet** (`DiscoverTab`), **Sohbet** (`ChatTab`), **Kulüpler** (`ClubsTab`), **Profil** (`ProfileTab`). Sekme dizinleri `AppTab` içindedir; Sohbet sekmesinde okunmamış rozeti gösterilir.
- Diğer ekranlar sekme üstüne `Navigator.push` ile açılır (push sayfaları): haber/etkinlik/kulüp detayı, sohbet detayı, yeni sohbet, arama, bildirimler, yemek listesi, etkinlikler, kayıtlı haberler, profil düzenleme, ayarlar, destek, sözleşmeler, engellenenler vb.

## 4. API katmanı ve oturum kuralı

- Tüm istekler `ApiClient` üzerinden geçer; sayfalar `http` ile doğrudan istek atmaz. Kaynak (bingol.edu.tr) sitelerine mobilden istek atılmaz.
- Her istekte `Accept-Language` (`ApiClient.lang`, varsayılan `tr`) ve girişliyse `Authorization: Bearer <access>` gönderilir. Zaman aşımı 20 sn.
- Hata: sunucunun `{code,message}` gövdesi `ApiError(status, code, message)` olur; mantık `code` üzerine kurulur. Gövdesiz hata `HTTP_<durum>` koduna düşer. Ağ/zaman aşımı: `status == 0`, `isNetwork == true`.
- **401 kuralı:** 401 gelirse `refresh()` çağrılır ve istek bir kez tekrarlanır. Refresh token tek kullanımlık olduğu için eşzamanlı çağrılar **aynı tek uçuşlu** `/auth/refresh` isteğini paylaşır. Yeni çift önce yazılır (`onTokensChanged`), sonra istek tekrarlanır.
- Refresh de reddedilirse (ağ hatası dışında) `onSessionExpired` çağrılır ve oturum kapatılır. **Ağ hatası oturumu silmez**; hem refresh sırasında hem açılışta (`Session._loadMe`) oturum korunur.
- Testler: `mobile/test/api_test.dart` (MockClient ile).

### 4.1 ETag önbelleği

`ApiClient`, kimlikli/kimliksiz GET yanıtlarını bellekte **LRU** (en çok 100 kayıt) önbelleğe alır; anahtar = dil + yetkili mi + yol, yani kullanıcıya ve dile özeldir. Sonraki istekte `If-None-Match` gönderilir; `304` gelirse önbellekteki gövde kullanılır (aynı yanıt başlıklarıyla, örn. `X-Next-Cursor`). Çıkışta `clearCache()` çağrılır. Test: `test/api_cache_test.dart`.

### 4.2 Çevrimdışı deneyim ve önbellek tavanları (M1, 2026-10-30)

Kullanıcı kararı: çevrimdışıyken **pasif bilgi şeritleri YOK** ("İnternet bağlantısı yok", "Kayıtlı veriler gösteriliyor", "N mesaj gönderilecek", "Son güncelleme"). Kayıtlı veri sessizce gösterilir, arka planda yenilenir, yenilenemezse sessiz kalınır; kayıt yoksa mevcut hata ekranı ("Yüklenemedi, tekrar dene") kalır. Bakım ve güncelleme şeritleri (sunucu kaynaklı) kalır. Yalnız kullanıcı eylemi anında kısa toast ("İnternet bağlantısı yok": düzenle/sil/tepki).

| Veri | Taze süre (ağa gidilmez) | Sonra | Tavan |
|---|---|---|---|
| Akademik katalog, SSS, sözleşmeler (`/legal*`, onay durumu hariç), kulüp kategorileri | 24 sa | ETag/304 | disk 30 gün |
| Menü, haber/duyuru, etkinlik listesi/takvimi/öne çıkan, kulüp listesi | 20 dk (aynı takvim günü) | ETag/304 | disk 1-7 gün |
| Sohbet, bildirim, özet, profil, ders programı, sınav, favori | yok (her açılışta doğrulanır, 304 ucuz) | ETag/304 | disk (beyaz liste) |

- `force: true` (çekip yenile) taze süreyi yok sayar; POST/PUT/PATCH/DELETE ilgili kaynak grubunun (ilk yol parçası) taze süresini sıfırlar. Çıkışta (`setTokens(null)`) bellek + JSON diski + mesaj kaydı + görsel diski + kuyruk silinir.
- Tavanlar: ETag LRU bellek 100 kayıt / 3 MB; JSON disk önbelleği 16 MB, kayıt başına 512 KB, 400 kayıt; görsel disk önbelleği (`DiskNetworkImage`, `BuImage`) 150 MB (açılışta ve her 40 yazmada budama, zamanlayıcı yok); çözümlenmiş görsel belleği 200 adet / 80 MB; 256 KB üstü JSON ayrı izolatta çözülür.
- **Mesaj kaydı** (`core/cache/message_cache.dart`): sohbet başına son 20 mesaj (`c<id>.json`) + sohbet listesi ilk 50 satır (`list.json`), toplam 50 sohbet / 3 MB. Yazma 1,5 sn geciktirilir ve toplanır; arka plana giderken boşaltılır (`CacheLifecycleFlusher`). Sohbet açılışı: önce kayıt (anlık), sonra ağ sayfası ile birleşir (id/clientId tekilleştirme; düzenlenen/silinen sunucudan). Tek gösterimlik ekin URL'si/içeriği hiç yazılmaz; silinen/kaldırılan mesaj iskelet olarak yazılır; engelleme/ayrılma/silmede sohbet kaydı silinir; okunmamış sayacı kayda yazılmaz. Dosyalar uygulama sandbox'ındadır, ayrıca şifrelenmez (bkz. `docs/design/SORULAR.md` M1).
- **Sessiz gönderme kuyruğu** (`core/outbox/`): metin ve fotoğraf/video mesajı çevrimdışıyken normal "gönderiliyor" (saat) görünür; ekler `outbox_media/` altına kopyalanır (200 MB tavan). Tetikleyiciler: bağlantı geri gelince, STOMP yeniden bağlanınca, uygulama öne gelince, geri çekilme zamanlayıcısı. Aynı `clientId` ile gönderildiği için çift mesaj olmaz. Kalıcı hata (4xx, 5 sunucu hatası, 24 sa) → balonda "Gönderilemedi · Yeniden dene". Testler: `test/m1_*.dart`.

## 5. Gerçek zamanlı özellikler ve cihaz yetenekleri

- **Gerçek zamanlı sohbet:** `core/realtime/` (`stomp_client.dart`, `stomp_frame.dart`, `chat_realtime.dart`) ham WebSocket üzerinden STOMP konuşur (`web_socket_channel`). CONNECT'te Bearer gönderilir; mesaj/okundu/yazıyor/mesaj-olayı/hata kuyruklarına abone olunur, kopmada üstel geri çekilmeyle yeniden bağlanır ve boşluk `?after=` ile kapatılır. Sohbet ekranı yanıt, düzenleme, silme, tepki, sessize alma/arşiv ve okunmamış rozetini destekler (`features/chat/`). Sözleşme: [MOBILE_API_GUIDE.md](MOBILE_API_GUIDE.md) bölüm 4.
- **Görsel yükleme:** `core/platform/image_service.dart` (`image_picker` + `image`): tür ve boyut istemcide doğrulanır, gerekirse küçültülüp sıkıştırılır; avatar, kapak ve sohbet görseli (`/api/conversations/{cid}/media`) bu yoldan yüklenir.
- **QR yoklama:** organizatör ekranı kodu `features/events/qr_painter.dart` (saf Dart QR üretici) ile çizer; katılımcı `mobile_scanner` ile kamerayı okur (iOS `NSCameraUsageDescription` tanımlıdır).
- **Açılış kapısı:** `core/app_gate.dart` + `features/system/gate_views.dart`. Açılışta `GET /api/app/version` ve `/api/app/info` okunur; `updateRequired` → kapatılamaz güncelleme ekranı, `updateAvailable` → kapatılabilir ileti (günde bir), bakım → bakım bandı/ekranı. Mağaza bağlantısı yalnızca `https` ise açılır.
- **Analitik:** `core/analytics.dart` olayları kuyruğa alır (en çok 50/istek, 20 olayda ya da 20 sn'de gönderir) ve `POST /api/analytics/events` ile yollar. `@` içeren değer kişisel veri sayılır ve olay istemcide atılır; sunucu PII'yi ayrıca reddeder.
- **Push hazırlığı:** `core/push/` (`push_service.dart`, `push_router.dart`) FCM jetonunu `POST /api/devices` ile (`platform`, `appVersion`, `locale`) kaydeder, çıkışta siler ve `targetType`/`targetId` yüküne göre yönlendirir. Firebase yapılandırması yoksa servis sessizce kapalı kalır. Firebase/APNs bilgisi bekleniyor: [MOBILE_PUSH.md](MOBILE_PUSH.md), [PUSH_SETUP.md](PUSH_SETUP.md).
- **Başlatıcı simgesi:** `flutter_launcher_icons` yapılandırması `pubspec.yaml` içindedir (kaynaklar `assets/branding/`); xcross akışı simge işlemediğinden iOS'ta etkisi doğrulanmadı.

## 6. Testler

`mobile/test/`: `auth_test.dart`, `theme_test.dart`, `bu_widgets_test.dart`, `api_test.dart`, `api_cache_test.dart`, `app_gate_test.dart`, `stomp_frame_test.dart`, `format_test.dart`. Çalıştırma (yalnızca ilgili dosyalar): `flutter test test/api_test.dart` vb.; hepsi için `flutter test`. **Statik analiz:** `flutter analyze --no-fatal-infos` (CI `dart analyze` kullanır ve bilgi düzeyi bulguları hata saymaz; `flutter analyze` varsayılanı ise info'ları da başarısız sayar). Hedef: 0 hata, 0 uyarı; mevcut info'lar (`prefer_const_*`, test dosyalarında `__` adlı parametreler) bilinçli olarak kabul edilmiştir. **Zamana bağlı testler:** `DateTime.now()` ile varsayılan değer üreten ekranlar test için `now` (`DateTime Function()`) parametresi alır (örn. `EventFormPage.now`); testlerde sabit saat verin, gerçek saate (örn. 21:00 sonrası gece yarısı taşması, ayın 29-31. günü) bağlı beklenti yazmayın. Ağ gerektiren testler `MockClient` kullanır; gerçek sunucuya karşı ölçüm için `scripts/perf/perf-api.js` ([PERFORMANCE.md](PERFORMANCE.md)).

## 7. Derleme ve çalıştırma (Windows)

Bu makinede Flutter `C:\src\flutter` altındadır; Java/Docker gibi araçlar için bkz. kök `CLAUDE.md`.

- **Türkçe karakterli yol sorunu:** Depo yolu (`...\Masaüstü\...`) araçları bozduğundan `mobile/` klasörüne ASCII bir bağlantı (junction) vardır: **`C:\bu_mobile`**. Flutter komutlarını her zaman bu yoldan çalıştırın.
- `PUB_CACHE=C:\pubcache` (ASCII pub önbelleği).
- PowerShell oturumu:

```powershell
$env:PUB_CACHE='C:\pubcache'
$env:PATH='C:\src\flutter\bin;C:\Program Files\Git\cmd;'+$env:PATH
Set-Location C:\bu_mobile
flutter test
```

- API adresi derleme anında verilir: `--dart-define=API_BASE=http://<adres>:8080`. Varsayılan `http://10.0.2.2:8080` Android emülatörü içindir; gerçek iPhone için bilgisayarın LAN IP'si gerekir (arka uç aynı ağdan erişilebilir olmalı).

### iPhone (xcross akışı)

Windows'ta iOS derlemesi `xcross` ile yapılır:

1. `xcross auth` ile oturum açın.
2. Tüneli **yönetici** PowerShell'inde başlatın (tunnel).
3. Çalıştırma: `xcross flutter run --dart-define=API_BASE=http://<LAN-IP>:8080`
4. `APPDATA`, `LOCALAPPDATA` ve `TEMP` ortam değişkenlerini ASCII bir klasöre yönlendirin (Türkçe karakterli kullanıcı profili yolu aracı bozar).

Notlar:
- Simge (app icon) desteği yoktur (xcross).
- Push için `GoogleService-Info.plist` paketleme ve APNs anahtarı bekleniyor (bkz. MOBILE_PUSH.md).
- Debug sürüm ana ekrandaki simgeden açılmaz; uygulamayı `xcross flutter run` oturumu üzerinden başlatın.

## 8. Android üretim derlemesi

İmzalama (`android/key.properties`), https zorunluluğu (`API_BASE`; yerel test için `ALLOW_INSECURE_API=true`), R8, izinler, Play veri güvenliği listesi ve komutlar: [ANDROID_RELEASE.md](ANDROID_RELEASE.md).

## 9. Oturum dayanıklılığı, hata kodları ve hata günlüğü (B2)

- **Oturum yalnız kesin yetki hatasında kapanır:** `ApiError.isAuthRejected` (401; 400/403 + `INVALID_REFRESH_TOKEN`/`TOKEN_REUSED`/`SESSION_REVOKED`/`ACCOUNT_SUSPENDED`). 5xx, 429, 408 ve ağ hatasında token'lar korunur (`isTransient`): refresh iki kez kısa gecikmeyle yeniden denenir, açılışta `/auth/me` geçici hatada oturumu `signedIn` bırakıp arka planda tekrar dener (çevrimdışı mod).
- **Hata kodları:** `errorText`/`knownErrorText` (core/session.dart) `EMAIL_ALIAS_NOT_ALLOWED`, `PASSWORD_TOO_LONG`, `PAYLOAD_TOO_LARGE` (ve kodsuz 413), `UPLOAD_BUSY`, `UPLOAD_QUOTA_EXCEEDED`, `MAIL_QUOTA_EXHAUSTED`, `DB_TIMEOUT`, `LEGAL_REACCEPT_REQUIRED` kodlarını tr/en/ar yerel metne çevirir; 429/503'te `Retry-After` "N sn / N dk sonra tekrar deneyin" olarak eklenir. Kayıtta `+` etiketi istemcide ve sunucu yanıtında e-posta alanının altında gösterilir; şifre sınırı 72 BAYT'tır. `LEGAL_REACCEPT_REQUIRED` (herhangi bir yazma isteğinde) ve açılıştaki `GET /legal/acceptance-status` tam ekran "Sözleşmeler güncellendi" ekranını (`features/legal/`, `Session.legal` + `LegalReacceptGate`) açar; ağ/5xx hatasında kapı açılmaz, `enforced=false` iken "Daha sonra" ile geçilir. Genel `errLegalReaccept` metni yalnız yedek olarak kalır. Kayıt doğrulamasında kayıt şifresi `verify-email` gövdesine `password` olarak eklenir (parola kanıtı; bellekte yoksa doğrulama ekranı şifreyi ister).
- **Hata izleme (Crashlytics/Sentry yok):** `core/error_log.dart` — `FlutterError.onError`/`PlatformDispatcher.onError` yerel günlüğe (bellek 50 kayıt + `error_log.jsonl`, 64 KB) yazar; oturum açıksa mevcut analitik hattıyla anonim `app_error` olayı gider (`type`, `source`, `version` + `screen`; mesaj/yığın/kişisel veri yok; aynı hata 60 sn'de bir, saatte en çok 10). Ayrı bir kullanıcı analitik anahtarı henüz yoktur: olay, mevcut analitik toplamasıyla (gizlilik politikasında anılır) aynı kapsamdadır.

## 10. Yeni sunucu sözleşmeleri (B4: P06/P07/P08/B1)

- **Kapalı sohbet (P08):** `ConversationView` "kapalı" alanı taşımaz; durum `core/closed_conversations.dart` (`ClosedConversations`, bellek içi, 12 sa TTL) içinde `409 CONVERSATION_CLOSED` (REST/STOMP `errors`/çevrimdışı kuyruk kalıcı hatası) ve SYSTEM bildirimi `data.event = CONVERSATION_CLOSED|CONVERSATION_REOPENED` ile tutulur. Kapalıyken `ChatDetailPage` yazma alanı yerine "Bu sohbet yönetici tarafından kapatıldı." bandını (`chatClosedBanner`) gösterir; sebep ASLA gösterilmez. Kapalı sohbette canlı yeni mesaj gelirse ya da yeniden açma bildirimi gelirse bant kalkar. Bildirim durumu `PushService.handleForeground` (sohbet açıkken şerit bastırılsa da) ve `PushRouter.open` içinde uygulanır.
- **Yönetici gizlemesi yer tutucusu (P08):** `removed=true` mesajlarda sunucunun sabit Türkçe metni (`Bu mesaj yönetici tarafından kaldırıldı` / `Bu mesaj kaldırıldı` / `Bu mesaj silindi`) `features/chat/message_placeholder.dart` ile uygulama diline çevrilir (balon, yanıt önizlemesi, sohbet listesi önizlemesi). Düzenle/yanıtla/tepki/kopyala menüsü bu mesajlarda açılmaz. STOMP `message-events` `deleted` olayı (`ChatRealtime.deletedMessages`) açık sohbette son sayfayı yeniden çeker; geri gösterme (unhide) olayı yoktur, açılışta/yenilemede taze çekilir.
- **Push yönlendirme:** `data.event = CONVERSATION_REMOVED` -> `PushDest.chatList` (açık rotalar kapanır, `shellTabRequest` ile kabuk Sohbet sekmesine geçer). CLOSED/REOPENED hedef sohbeti açar (kapalıysa bantla). Kulüp kapatma/otomatik devir bildirimleri yalnız `communityId` taşır -> kulüp ayrıntısı.
- **Kulüp kapatma (P06):** kapatılmış (HIDDEN) ya da silinmiş kulüpte ayrıntı 404 -> `ClubDetailPage` "Kulüp şu an kullanılamıyor." boş durumunu gösterir (yeniden deneme yok); `COMMUNITY_NOT_FOUND` her yerde aynı yerel metne çevrilir (kulüp sohbet odası dahil).
- **Sertifika iptali (P07):** mobilde sertifika ekranı yoktur; `CERTIFICATE_REVOKED` (409) `knownErrorText` ile yerel metne çevrilir. Doğrulama (`valid:false`) uçta iptal bilgisi vermez.
- **Hesap silme (B1):** silme sayfasına "cihaz/IP/kullanım kayıtları anında silinir" ve "sahibi olduğun kulüpler yönetici üyeye devredilir; aday yoksa kapatılır" maddeleri eklendi (tr/en/ar).
- Testler: `test/b4_server_contracts_test.dart`.

## 11. Kimlik akışı yeniden tasarımı (AUTH1)

Karşılama, giriş, kayıt (3 adım), e-posta doğrulama, şifremi unuttum (e-posta -> kod -> yeni şifre -> başarı), sözleşme yeniden onayı ve izin sayfası ortak bir "kimlik kiti" ile yenilendi. Davranış/API/güvenlik aynıdır.

- **Kit:** `lib/features/auth/widgets/` — `auth_shell.dart` (iskelet: üstte geri/marka + adım noktaları, kaydırılan gövde `body`, klavyeyle yükselen sabit alt çubuk `bottom`, aşamalı giriş), `auth_fields.dart` (`AuthTextField`: etiket kutunun içinde yüzer, odak halkası, alandan çıkınca doğrulama + hata görününce anında düzelme, doğru tik; `AuthPasswordField`, `AuthIdentifierField`), `auth_controls.dart` (ana düğme, banner + sarsıntı, adım noktaları, halka geri sayımlı `AuthResendRow`, parola gücü + tek tek tik atan kurallar, güven notu), `auth_art.dart` (kodla çizilmiş illüstrasyonlar, başarı tiki + konfeti, parıltı, kırmızı sahne boyacısı), `auth_motion.dart` (tek saat `AuthClockHost`, `AuthAmbient` arka plan, `AuthShake`, `authHaptic`), `auth_sheets.dart` (sürüklenebilir arama destekli seçici sayfa + dil sayfası), `auth_academic.dart` (kayıtta bölüm/sınıf).
- **Tek ticker ilkesi:** ekran başına tek döngülü saat (24 sn); arka plan lekeleri, illüstrasyon süzülmesi, kırmızı sahne dalgaları ve yükleme noktaları aynı saati okur. Döngü, `MediaQuery.disableAnimations` açıkken ve `flutter test` altında çalışmaz (`AuthMotion`); sınırlı girişler (500-1500 ms) her zaman oynar.
- **Eski ortak bileşenler** (`auth_widgets.dart`: `PasswordField`, `AuthButton`, `Notice`, `PasswordStrength`) profil ekranları için olduğu gibi kaldı; kimlik ekranları yeni kiti kullanır.
- **Başarı ekranı:** `reset_success_page.dart` (şifre sıfırlama sonunda; geri tuşu girişe döner).
- **Görsel inceleme:** `AUTH_SHOTS_OUT=<klasör> flutter test test/auth_shots_test.dart` (`AUTH_SHOTS_LANG=tr,en,ar`, `AUTH_SHOTS_DARK=0|1|both`, `AUTH_SHOTS_SCALE=1.3`, `AUTH_SHOTS_ONLY=02,03`). Arapça yerleşim için Windows Arial yedeği yüklenir. Testler: `test/auth_redesign_test.dart` (3 dil x 2 tema x 2 boyut x 2 yazı ölçeği taşma matrisi + davranışlar).
- **Yerel kod okuma:** `scripts/dev/last-code.sh [proje]` (MAIL_ENABLED=false yığınında son doğrulama/sıfırlama kodunu ve e-postasını backend logundan yazar).
- **Android debug derlemesi:** `MainActivity` yalnız debuggable DEĞİLKEN `FLAG_SECURE` uygular (release'te ekran görüntüsü/kayıt engeli aynen sürer). Gradle, Türkçe karakterli yolda (`jni` CMake) derlenemez: ASCII bir kopyadan derleyin (`robocopy ... /XD build .dart_tool ios`).

