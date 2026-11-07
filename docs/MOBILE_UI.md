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

- `features/shell/app_shell.dart` alt sekmeli kabuktur. Sekmeler: **Ana Sayfa** (`HomeTab`), **Keşfet** (`DiscoverTab`), **Sohbet** (`ChatTab`), **Kulüpler** (`ClubsTab`), **Profil** (`ProfileTab`). Sekme dizinleri `AppTab` içindedir; Sohbet sekmesinde okunmamış rozeti gösterilir. **Keşfet** iki sütun masonry'dir (`features/discover/masonry_layout.dart` paketsiz tembel `SliverGrid`; kutu `DiscoverPostBox`: foto + sol altta yazar, sağ altta beğeni, yalnız küçük resim yüklenir); kutuya dokununca gönderi sayfası (`PostDetailPage` + `PostStreamSeed`) o gönderiden başlayan aynı akışı dikey ve sonsuz kaydırmalı gösterir (ölçüler: `docs/design/BIREBIR_FEED.md` "Keşfet v2").
- **Keşfet v4 (KE-MB, kullanıcı kararı 2026-11-05):** filtre/kapsül YOK (Senin İçin/Popüler/Reels/En Yeni/Takip kalktı); başlık satırı (Keşfet, yuvarlak arama = `GlobalSearchScreen.route`, vurgulu + paylaş) akışla birlikte kayar. **TEK karma akış** `GET /api/feed?scope=foryou`: fotoğraf ve video gönderileri iki sütun masonry ızgarada karışık (`discover_tab.dart` → `DiscoverMasonryFeed`). **Her yenilemede** (aşağı çekme, sekmeye 3 dk+ sonra dönüş, hata sonrası yeniden deneme) imleçsiz ilk sayfa ağdan gelir (yeni tohum; sunucu görülmemişleri önce verir); `FeedSeenReporter` görünen kimlikleri 2 sn gecikmeyle `POST /feed/seen` ile bildirir. **Bitmeyen akış** (`posts/feed_pager.dart` `FeedPager`): imleç zinciri bitince (`nextCursor==null`) sonraki istek yine imleçsiz yapılır (görülmüşler baştan karıştırılır, `exhausted:true`); "tükendi" ekranı/uyarısı YOK; aynı gönderi ekranda iki kez çıkmaz (kimliğe göre tekilleştirme); yalnız tekrardan oluşan sayfa gelirse en çok 3 deneme sonra durur. **Kutu** (`discover_box.dart`): foto/poster + sol altta yazar, sağ altta açık yüzey hapı içinde kalp+sayı: beğenmemiş BOŞ çizgi kalp (`ink`), beğenmiş DOLU KIRMIZI (`pr`); beyaz kalp yok; dokunma hedefi >= 44 dp, iyimser + 250 ms birleştirme; video kutusunda yalnız sağ üstte süre hapı. **Kutuya basınca dikey gönderi akışı** (`PostDetailPage` + `posts/post_pager.dart` `PostPager`): `CustomScrollView.center` tekniği: basılan gönderi AKIŞIN ORTASINDA ekranın başında; ÜSTÜNDE ızgarada ondan önce gelenler (yukarı kaydırınca), ALTINDA sonrakiler ve ızgara bittikten sonra sunucudan YENİ oturum tohumuyla rastgele sayfalar (`PostStreamSeed{before,items}`); popülerlik puanı/sayacı yok; video kutusu da fotoğraf gibi bu akışı açar (tam ekran Reels AÇILMAZ; `reels_feed.dart` Keşfet'ten erişilmez, profil Reels sekmesi `onOpenReel` bağlanırsa kullanılır). **Akışta video** satır içi (`PostVideoView`): alanın %60'ı görününce SESSİZ ve döngülü oynar, çıkınca durur ve oynatıcı atılır (bellek); dokununca oynat/duraklat (ikon kısa görünüp solar), ses AYRI düğme (oturum boyunca ortak `postVideoMuted`), tam ekran düğmesi yok. **Önyükleme** (kullanıcı bakmadan ÖNCE; `discover/discover_prefetch.dart`): sayfa geldiği an yakın ~16 kutunun küçük resmi diske (`DiskNetworkImage.warm`), sıradaki ≤6 videonun DOSYASI yerel diske (`core/cache/video_prefetch.dart` `VideoPrefetcher`: `<tmp>/video_prefetch/<anahtar>.mp4`, `.part` + yeniden adlandırma, eşzamanlılık 2, dosya <= 50 MB, toplam LRU 300 MB, başarısızlıkta 2 dk geri çekilme, mobil veride yalnız ilk 2 video (arayüz adlarından ölçülü ağ tahmini), arka planda durur, çıkışta `registerUserDataCleaners` ile silinir); oynatıcı önce yerel dosyayı kullanır (hazır değilse POSTER kalır, kısa bekleme sonrası ağdan). **Video gönderi** modeli: `Post.video` (`video{url,posterUrl,durationMs,width,height}`; eski `media[kind=VIDEO]` da okunur). **Paylaş (+):** menü Fotoğraf paylaş | Video / Reels paylaş (metin-only gönderi yok); video: `VideoService(limitBytes: 50 MB)` (60 sn; Android'de 720p sıkıştırma), yerel sessiz ön izleme, **kapak karesi şeridi**, hazırlama + yükleme ilerlemesi, `POST /posts/media` (`file` + `poster`) sonra `POST /posts {mediaIds}`. **Yorum paneli** (`reels_comments.dart`) ve Reels oynatıcısı kodu duruyor (şu an Keşfet'ten açılmaz).
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

#### Oturum nesli, kuyruk ve önbellek sağlamlığı (W1-G, 2026-10-31)

- **Oturum nesli** (`ApiClient.sessionGen`): çıkış ve ilk giriş (belirteç yok <-> var) her seferinde artar, belirteç yenilemede artmaz. Her istek başlangıçta nesli yakalar; yanıt geldiğinde nesil değiştiyse yanıt önbelleğe YAZILMAZ ve çağırana `ApiError(0, 'SESSION_CHANGED')` döner. `_doRefresh` sonucu da nesil değiştiyse atılır (çıkış yapılmış oturum geri yazılmaz). `SESSION_CHANGED` `status == 0` olduğundan ekranlarda ağ hatası gibi görünür; çıkış sırasında zaten ekran kapanır. `Session._persist` belirteç yazma/silmeyi TEK Future zincirine alır; silme başarısızsa 3 kez yeniden dener, yine olmazsa `signed_out` işareti bırakır (sonraki açılış otomatik giriş yapmaz). `Outbox.clear` ve `MessageCache.clear` kendi kuşak sayaçlarına sahiptir: süren drain eski hesabın kalan mesajlarını göndermez, temizlemeyle yarışan disk yüklemesi eski veriyi belleğe geri koymaz.
- **Tek uçuşlu GET**: aynı oturum nesli + dil + yol için eşzamanlı GET'ler tek ağ isteğini paylaşır (`force` ayrı istektir). `/app/info` 2 dk taze (açılış kapısı ile ana sayfa aynı bilgiyi çekmez); kapı bağlantı dönüşünde/öne gelişte `force` ile yeniler.
- **JSON olmayan 2xx** (captive portal, proxy HTML'i) `ApiError(0, 'BAD_RESPONSE')` olur: önbelleğe/diske yazılmaz, bağlantı "çevrimiçi" sayılmaz. 502/503/504 ve 5xx yanıtları `reportSuccess` çağırmaz.
- **Kuyruk (`Outbox`)**: depo OKUNAMAZSA (Keychain/Keystore geçici hatası) hiçbir şey silinmez/yazılmaz, yükleme sonra yeniden denenir; JSON BOZUKSA ham değer `outbox_v1_corrupt` anahtarına yedeklenir ve tam kayıtlar tek tek kurtarılır; artık medya dosyaları yalnız başarılı+bozulmamış yüklemeden sonra süpürülür. 502/503/504 ve `Retry-After`'lı 5xx ağ yokluğu gibi ele alınır (kuyruk durur, mesaj "Gönderilemedi" olmaz); gerçek 5xx beş kez VE mesaj 30 dk'dan eskiyse kalıcı hata. Mesaj kaydı (`MessageCache`) şema sürümü (`v == 1`) ve her öğede `id is num` doğrular, aksi halde dosyayı siler; `upsertMessage`/`markGone` hata sızdırmaz.
- **Açılış**: `main` cihaz kimliği, iOS yeniden-kurulum temizliği, çökme raporlayıcı, tema ve dil okumalarını PARALEL başlatır; `ApiClient` cihaz kimliği hazır olmadan HİÇBİR istek atmaz (`DeviceIdentity.ready`). Belirteç varsa `Session.restore` kabuğu HEMEN açar (state `signedIn`), `/auth/me` arka planda yenilenir; oturum yalnız kesin yetki reddinde kapanır. Profil dili (`PATCH /users/me`) yalnız değişince gönderilir (`LanguageSync`).
- **Görseller**: `DiskNetworkImage` tek paylaşımlı `HttpClient` kullanır (keep-alive, sunucu başına 6 bağlantı, 15 sn boşta); baytlar yalnız görsel olarak çözülebildiyse diske yazılır; tavan yazılan baytın %10'unda ya da her 40 yazmada uygulanır. Keşfet gönderi fotoğrafı, etkinlik kapağı, haber küçük resmi, menü fotoğrafı ve profil fotoğrafı görüntüleyicisi `persistentNetworkImage` ile diske yazılır (menü fotoğrafı ekran genişliğine göre küçültülerek çözülür).
- **Galeriye otomatik kaydetme** (`PhotoAutoSave`): VARSAYILAN KAPALI (açıkça açılmadıysa, eski sürümden kalan anahtarsız kayıt dahil, kapalı sayılır); anahtar CANLI Profil > Gizlilik ve veriler sayfasındadır (açarken rıza metni); yalnız birebir sohbet (`direct` parametresi, varsayılan true — grup/kulüp/etkinlik odası çağıranı `direct: false` geçmelidir); çıkışta ayar ve kaydedilen ek kimlikleri silinir.

#### Çıkış temizliği envanteri

Çıkış / hesap silme / oturum iptali / başka cihazda giriş: `ApiClient.setTokens(null)` (nesil artar) belirteçleri, ETag/disk önbelleğini, kuyruğu ve `registerUserDataCleaners` (`core/user_data.dart`) kancalarını çalıştırır. **Kural: kullanıcıya özel veri tutan her yeni yerel depo bu kayıt noktasına bir temizleyici ekler ve `test/a15/a15_cache_test.dart` S2.9/S2.9b envanterine girer.**

| Depo | Konum | Çıkışta |
|---|---|---|
| Oturum belirteçleri `access`/`refresh` | güvenli depo | silinir (`Session._persist`, 3 deneme + `signed_out` işareti) |
| Bekleyen mesaj kuyruğu `outbox_v1` (+ `outbox_v1_corrupt`) ve `outbox_media/` | güvenli depo + dosya | silinir (`Outbox.clear`); iOS yeniden kurulumda da silinir (`FreshInstallGuard`) |
| ETag/JSON önbelleği `api_cache` | dosya | silinir |
| Mesaj kaydı `msg_cache` | dosya | silinir |
| Görsel önbelleği `img_cache` | dosya | silinir |
| Arama geçmişi `recent_searches` | güvenli depo | silinir (`RecentSearches.clear`) |
| Galeriye otomatik kayıt `photo_autosave.json` (ayar + kaydedilen ek kimlikleri) | dosya + bellek | silinir (`PhotoAutoSave.reset`) |
| Ders hatırlatıcı ayarı `academic_reminders` + kurulu yerel hatırlatmalar | güvenli depo + OS alarmları | silinir (`ReminderService.clearUserData`) |
| Son eşitlenen profil dili `synced_language` | güvenli depo | silinir (`LanguageSync.clear`) |
| Sözleşme "sonra" işareti `legal_later` | güvenli depo | silinir |
| Cihaza özel: `device_id`, `welcome_seen`, `perms_onboarded`, `theme_mode`, `app_language`, `crash_reports_enabled`, `update_notice_shown`, `pending_verification` | güvenli depo | KALIR (hesaptan bağımsız) |

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


## 12. Gizli hesap, takip istekleri ve mesaj istekleri (FOLLOWREQ-MB)

Kural: takip isteği YALNIZ gizli hesaplar içindir; herkese açık hesap istek almaz, doğrudan takip edilir (Instagram gibi). Sözleşme: `followState` (`NONE|REQUESTED|FOLLOWING|SELF`) tek kaynaktır; `isPrivate` ve `locked` profil/liste/öneri/arama satırlarında gelir. Eski yanıtta alan yoksa `followedByMe` bayrağından türetilir (`followStateOf`).

- **Tek takip düğmesi:** `features/follow/follow_button.dart` `FollowStateButton` (görünümler `FollowLook.block|row|pill|chip`). Profil, takipçi/takip listesi, öneriler (liste + Keşfet kartı) ve arama kişi satırı aynı sınıfı kullanır; eski `FollowRowButton`/`ProfilyFollowButton`/`FollowButton` ince sarmalayıcıdır. Akış: "Takip et" -> (gizli hesapta) "İstek gönderildi" -> "Takiptesin"; iyimser güncelleme, hata olursa geri alma, sunucunun `followState` yanıtı iyimser tahminin yerini alır. "İstek gönderildi" -> "İsteği geri çek" onayı, "Takiptesin" -> "Takibi bırak" onayı (gizli hesapta "yeniden istek göndermen gerekir" uyarısı); `follow_sheets.dart`, ortak `BuConfirmSheet`. Arama satırında düğme yalnız sunucu `followState` verdiyse çizilir.
- **Kilitli profil:** `UserProfilePage` `locked` iken gönderi ızgarası yerine `LockedProfileBlock` ("Bu hesap gizli"), gönderi/takipçi/takip sayıları "–" ve listeler açılmaz; ad, avatar, bölüm/bio ve Mesaj gönder aynen. İstek onaylanınca (kilit açılınca) profil yeniden yüklenir.
- **Gizli hesap anahtarı:** Ayarlar > Gizlilik ve veriler, `PATCH /users/me/privacy {privateAccount}` (mevcut uç PATCH). Açarken onay yok; kapatırken "bekleyen istekler otomatik kabul edilir" onay sayfası.
- **Takip istekleri ekranı:** `follow_requests_page.dart` (`GET /users/me/follow-requests`, `.../count`, `POST .../{userId}/accept|decline`). Satırda Onayla (birincil) / Sil (çizgili), dar ekran/büyük yazıda düğmeler adın altına iner; kabul/red sonrası satır kayarak kalkar. Girişler: Bildirimler üstü `FollowRequestsEntry` ("Takip istekleri (n)", n>0), Profil sekmesi İçeriğim kutusunda sayı metinli satır (n>0, rozet yok), push/bildirim `targetType=FOLLOW_REQUESTS` -> bu ekran (`PushDest.followRequests`), `USER` -> profil. Bildirim türleri `FOLLOW_REQUEST`/`FOLLOW_ACCEPTED` listede "Takip" etiketi alır.
- **Mesaj istekleri:** `features/chat/message_requests_page.dart` (`GET /conversations/requests`, `.../requests/count`, `POST /conversations/{id}/accept|decline`). Sohbet listesinin üstünde "Mesaj istekleri (n)" satırı (n>0); ekranda PENDING birebir istekleri ve grup davetleri (grup silme = gruptan ayrılma, onay ister). Satıra dokunmak sohbeti okumaya açar; yanıt yazınca istek kendiliğinden kabul edilir. Açıklama metni `docs/changes/messaging.md` ile tutarlıdır (okundu bilgisi PENDING iken gitmez).
- **Bildirimler ve mesajlar:** sohbet mesajları uygulama içi Bildirimler listesine düşmez (sunucu `MESSAGE` döndürmez; push gider ve dokunuş `targetType` sohbetle ilgili sohbeti açar). Eski sürüm/önbellekten `MESSAGE` satırı gelirse ekran gizler (`NotificationsPage._inbox`). Zil rozeti yalnız kutu okunmamışıdır (`/me/summary unreadNotifications`), sohbet okunmamışı Sohbet sekmesi rozetindedir; iOS simge rozeti sunucunun push rozeti gibi ikisinin toplamıdır (`IconBadge.attach(extra:)`). Bildirim tercihlerindeki "Mesaj bildirimleri (push)" anahtarı yalnız push anlamındadır.
- Testler: `test/followreq_test.dart`, `test/msg_requests_test.dart` (3 dil x açık/koyu x 1.0/1.3 x 320/390 taşma matrisi dahil).

## 13. İkonlar (ICONS-MIGRATE)

Tüm ikonlar `BuIcons` üzerinden (`lib/core/icons/bu_icons.dart`; `widgets/bu.dart` dışa aktarır). Glifler Hugeicons 4.4.0 (MIT) verisinden üretilmiş `assets/fonts/BuIcons.ttf` yazı tipindedir; `Icon(BuIcons.x)` Lucide ile aynı maliyetli, `IconData` tipi değişmez. **Yeni ikon = `BuIcons`** (doğrudan `LucideIcons`/`Icons` yok; `delete` ve `keyboard` Lucide'e işaret eden iki istisnadır). Ekleme/yeniden üretim: `mobile/tools/icons/README.md`; karar ve kalite ölçümleri: `docs/design/IKON_HUGEICONS.md` bölüm 11-12. Yerel test: `flutter test test/bu_icons_test.dart`.

## 14. Sohbet güvenliği bildirimi ve sayfası (CHATENC)

- **Konuşma başında sistem bildirimi** (`ChatEncryptionNotice`, `features/chat/chat_security_page.dart`): kilit simgesi + "Mesajların aktarım sırasında ve sunucuda şifrelenir. Daha fazla bilgi". Ters listenin son öğesi olarak (görsel olarak en üst) çizilir; yalnız geçmişin başına inildiğinde (`_beforeCursor == null`) görünür, daha eski sayfa varken görünmez. Boş konuşmada da görünür. Alt metin türe göre: birebir / grup ("tüm üyeler görebilir") / kulüp-etkinlik odası. Dokununca `ChatSecurityPage`.
- **Sohbet güvenliği sayfası** (`ChatSecurityPage`): büyük kilit, doğrulanmış koruma maddeleri (aktarımda TLS/WSS, sunucuda AES-256-GCM, yönetici erişimi kayıtlı, engelle/şikâyet, tek gösterimlik fotoğraf, herkes için sil, fotoğraf EXIF temizliği, KVKK indirme/silme, satılmaz), dürüst "Bilmen gerekenler" (uçtan uca şifreli DEĞİL; silinen içerik saklanabilir; gruplarda herkes görür; ekran görüntüsü engellenemez; hesap silince mesajlar anonim kalır), şikâyet/engel nasıl yapılır ve Gizlilik Politikası / Topluluk Kuralları bağlantıları. Sohbet bilgisi sayfasında "Şifreleme ve güvenlik" satırı (`info-security`); boş sohbet listesinde ve yeni sohbet ekranında gürültüsüz tek satır alt bilgi (`ChatEncryptionFootnote`).
- **Dürüstlük kuralı:** uygulama uçtan uca şifreli DEĞİLDİR (`docs/ENCRYPTION.md` bölüm 1). "Uçtan uca şifreli", "kimse okuyamaz", "yalnızca siz ve alıcı" gibi iddialar hiçbir metne yazılmaz; `test/chat_encryption_test.dart` `chatEnc*` anahtarlarını üç dilde tarar ("uçtan uca" yalnız "değildir/not/غير" ile anılabilir). Ekran görüntüsü koruması iddia edilmez. Anahtarlar `chatEnc*` (tr/en/ar).
- Test: `flutter test test/chat_encryption_test.dart` (DM/grup/kulüp/etkinlik, boş, dokunma, 320/390 dp, x1.3, tr/en/ar, açık/koyu).


## 15. Paylaş (+): galeri seçici (2026-11-06)

Alt çubuktaki ortadaki "+" (ve Keşfet "+", Profil/Kullanıcı gönderileri "Gönderi ekle", Keşfet boş durum düğmesi: hepsi `openComposePost`) artık "Fotoğraf paylaş / Video paylaş" seçenek sayfasını AÇMAZ; doğrudan **galeri seçici** (`features/posts/post_gallery_picker_page.dart`, tam ekran rota `post_gallery`) açılır. Eski seçenek sayfası koddan silindi (`kesComposeMenuPhoto/Video` ARB anahtarları kullanılmıyor, silinmedi).

- **Izgara:** cihazın en yeni fotoğraf ve videoları, kare küçük resimler, 2 dp aralık; sütun sayısı 320 dp altı 3, telefonda 4, 600 dp üstü 5. **İlk (mantıksal baş) kare kamera karosu**: Türkçede sol üst, Arapçada (RTL) sağ üst. Küçük resim 300 px, kare başına tembel (`MediaLibrary.thumb`, `Image.memory cacheWidth: 300`); ilk 60 öğe, kaydırınca 60'ar sayfa (`pageSize`); videolarda poster karesi + süre rozeti (0:15 / 1:02:05). Seçim göstergesi yok, basılı kare hafif küçülür (`BuPressable`, hareket azaltılmışsa anında).
- **Dokun = seç + ilerle (karar):** önizleme/onay adımı ve "İleri" düğmesi YOK (WhatsApp/Instagram benzeri tek dokunuş; tek öğe kuralı). Fotoğraf: baytlar `MediaLibrary.imageBytes` (uzun kenar 2048 px JPEG, HEIC dönüşür) -> `ComposePostPage(initialPhoto)` açılır açılmaz kırpma düzenleyicisi; video: dosya yolu -> `ComposePostPage(initialVideoPath)`: süre sınırı (`PostVideoLimits`, 60 sn) aşılıyorsa zorunlu kırpma, değilse hazırlama + kapak karesi + paylaş. Süre/boyut/gönderi kuralları aynen korunur (hiçbiri değişmedi).
- **Geri dönüş:** seçici rotası oluşturucunun altında kalır. Oluşturucuda kırpmadan vazgeçmek, "Değiştir", video "X" ve "Başka bir video seç" galeriye döner (yazılı metin varsa önce vazgeçme onayı). Paylaşılınca `Post` seçiciden de çıkıp çağırana döner (AppShell Keşfet'e geçer). Doğrudan `ComposePostPage()` / `openComposePost(kind: ..)` / `menu: false` yolu (boş oluşturucu + Galeri/Kamera/Video düğmeleri) eski testler ve olası başka girişler için duruyor.
- **Kamera karosu:** uygulama içi kamera (`openMediaCamera(hint: ..)`, chat'tekiyle aynı `MediaCameraPage`): dokun = fotoğraf, **basılı tut = video** (en çok 60 sn, halka ilerleme). Kullanım ipucu "Fotoğraf için dokun, video için basılı tut" yalnız bu akışta deklanşörün üstünde görünür (`postPickerCameraHint`; sohbet kamerası ipucusuz kalır). Çekilen öğe seçilmiş gibi aynı akışa girer. Kamera/mikrofon reddi kameranın kendi "kullanılamıyor" ekranını gösterir.
- **Başlık kararı:** üst çubukta "Yeni gönderi" başlığı GÖRÜNMEZ (sayfa adı başlığı gizleme kuralı; yalnız ekran okuyucu başlığı). Görünen tek başlık albüm hapı ("Son eklenenler"; birden çok albüm varsa ▾ ile albüm listesi, `GalleryAlbumSheet`). Solda kapat (X); alt eylem çubuğu yok.
- **İzin akışı:** `ensurePermission(photos, direct: true)` (uygulamanın kendi gerekçe penceresi atlanır, yalnız TEK sistem istemi) -> `photo_manager.requestPermissionExtend`. Tam / sınırlı (iOS 14+ ve Android 14 "seçili fotoğraflar") / reddedildi. Sınırlı: üstte kısa bilgi + "Daha fazla seç" (`presentLimited`) + "Ayarlar". Reddedildi: açıklama + "Ayarlardan aç" + **"Sistem galerisini kullan"** (`image_picker.pickMedia`, Android Photo Picker / iOS PHPicker; izin gerektirmez) + "Kamera". Ayarlar'dan izin verip dönünce ızgara kendiliğinden dolar (`AppLifecycleState.resumed`). Boş galeri: kamera karosu kalır + "Galeride fotoğraf ya da video yok."
- **Paket:** yeni bağımlılık YOK; `photo_manager` (3.12, sohbet seçicisiyle ortak `MediaLibrary`/`PhotoManagerLibrary`), `camera`, `image_picker`, `permission_handler` zaten pubspec'te (iOS SwiftPM ile zaten çözülüyor). Sohbet dosyalarına yalnız: `GalleryAlbumSheet` herkese açıldı, kamera sayfasına isteğe bağlı `hint`.
- **Android izinleri:** `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO` zaten vardı; `READ_MEDIA_VISUAL_USER_SELECTED` eklendi (Android 14 kısmi erişim; bkz. `docs/ANDROID_RELEASE.md`, Play "Foto ve Video İzinleri" uyarısı `docs/audit/A8-altyapi-kvkk-uyum.md` A8-06). iOS: `NSPhotoLibraryUsageDescription` zaten gönderiyi sayıyordu; `NSCameraUsageDescription`/`NSMicrophoneUsageDescription` (tr/en/ar) "gönderi" eklenerek güncellendi (`docs/IOS_RELEASE.md`).
- **Test:** `flutter test test/post_gallery_picker_test.dart` (sahte `FakeMediaLibrary`: ilk karo kamera, sıralama, süre rozeti, 4 sütun + sayfalama, dokun = ilerle, vazgeçme, video, kamera foto/video, boş, izin reddi + sistem seçicisi, sınırlı, albüm, gerçek oluşturucu akışları, ar RTL, 320/390 dp x1.3 açık/koyu); eski seçenek sayfası beklentileri `back_navigation_test`, `k4_states_test`, `kesfet_ks2_test` içinde güncellendi.

## 16. Gönderide yakınlaştırma (iki parmakla aç, 2026-11-06)

Gönderi fotoğrafı/videosunda iki parmağı birbirinden uzaklaştırınca görsel yakınlaşır. Paket eklenmedi; tek bileşen: `widgets/pinch_zoomable.dart` (`PinchZoomable`).

- **Karar (Instagram benzeri):** görsel akıştaki yerinde büyümez; kök `Overlay`'e (alt çubuk dahil her şeyin üstüne) yükselir, arka plan en çok %60 kararır, ölçek 1x-4x, iki parmakla kaydırmak (pan) yakınlaşmış görselde gezdirir. Parmaklar kalkınca (biri kalksa bile) kopya kritik sönümlü yayla ~250 ms'de eski yerine oturur; "animasyonları azalt" açıksa anında kalkar. Eşik geçişinde (~%10) hafif titreşim. Yakınlaştırma KALICI değildir; kalıcı pinch/pan/çift dokunuşla yakınlaştırma yalnız tam ekran görüntüleyicide (`PostPhotoViewer`, `InteractiveViewer`) kalır ve akıştan açılmaz.
- **Jest çakışmasızlığı:** `ScaleGestureRecognizer` kullanılmaz (tek parmak pan'ini de kapardı). Özel `_TwoFingerRecognizer` (`OneSequenceGestureRecognizer`) tek parmakta hiçbir şey talep etmez, parmak kalkınca kendini reddeder (dokunma/çift dokunuş normal kazanır); **ikinci parmak inince** arena'yı kazanır, böylece o dokunuş için liste/`PageView`/carousel sürükleme tanıyıcıları reddedilir (kaydırma geçici kilit). Çift dokunuş = beğeni (kırmızı kalp patlaması) ve tek dokunuş tam ekran AÇMAMA kuralları aynen korunur.
- **Kopya:** fotoğraf: `PostPhoto(zoomLayer: true)` (anahtarlar `zoom-post-photo-<id>`; kart çözünürlüğü anında bellek önbelleğinden, üstüne 2048 px katman `zoom-hires-<id>` aynı disk önbelleğinden biner; ek ağ isteği yok, Hero yok). Video: oynatıcı ikinci kez kurulmaz, o anki kare `RepaintBoundary.toImage` ile alınır (`RawImage`). Kopya `ExcludeSemantics` içindedir; kartın anlamsal etiketi değişmez, `RepaintBoundary` içinde çizilir.
- **Uygulandığı yerler:** `PostCard` (gönderi detayı/akışı: fotoğraf + video; liste kartı fotoğrafı) ve Reels (`reels_feed.dart`, tam ekran video, dikey `PageView` ile birlikte). Keşfet masonry küçük resimleri uygulanmadı (dokunuş detaya gider).
- **Bilinen sınır:** tek parmak sürükleme eşiği (~18 dp) geçildikten SONRA inen ikinci parmak aynı anda hem kaydırmayı hem yakınlaştırmayı sürdürebilir (Flutter'da bir tanıyıcı kazanılmış sürüklemeyi geri alamaz); iki parmak birlikte inince kilit tam çalışır. Gerçek cihazda ince ayar gerekebilir.
- **Test:** `flutter test test/pinch_zoom_test.dart` (iki parmak: ölçek/pan/yay dönüşü, 4x sınırı, tek parmak kaydırma yakınlaştırmaz, çift dokunuş beğeni, tek dokunuş yalnız `onTap`, geç inen ikinci parmak, hareket azaltma, video anlık görüntü yolu, carousel çakışması, `PostCard` detayı 390 açık + 320 koyu x1.3).

## Çoklu hesap (cihazda en çok 5)

- `lib/core/accounts/account_store.dart` (`AccountStore`): hesap dizini (`acct_index`: kimlik, ad, kullanıcı adı, avatar, MASKELİ e-posta) ve belirteçler (`acct_tokens`) güvenli depoda; ham e-posta/parola saklanmaz, belirteç hiçbir `toString`/loga girmez. `FreshInstallGuard.sessionKeys` iki anahtarı da siler.
- `Session.switchAccount` sunucuda çıkış YAPMAZ: `beforeSignOut` kancaları (push cihaz kaydı ESKİ hesaptan silinir) -> gerçek zamanlı kapat -> `api.setTokens(null)` (ETag/disk önbelleği, giden kutusu, tüm `registerUserDataCleaners`) -> yeni belirteç -> `accountEpoch++` (kabuk `ValueKey` ile yeniden kurulur; `AppLifecycleHooks` eski hesap için signedOut, yeni için signedIn kancalarını oynatır: push kaydı yeni hesaba, widget snapshot, dil eşitleme).
- `signOut` yalnız etkin hesabı çıkarır (başka hesap varsa ona geçer); `signOutAll` Ayarlar'da. 401/geçersiz refresh: hesap "Oturum süresi doldu" olur (`forceSignOut`), geçilebilir hesap varsa ona geçilir. Yalnız etkin hesaba push gider.
- Arayüz: profil başlığı `@kullanıcıadı ▾` ve Ayarlar > Hesap değiştir -> `features/accounts/account_sheet.dart`; "Hesap ekle" `AuthLandingPage(addAccount: true)`.
