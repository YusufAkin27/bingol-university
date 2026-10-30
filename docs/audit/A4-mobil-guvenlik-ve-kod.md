# A4 - Mobil güvenlik ve kod hatası denetimi (mobile/, Flutter `bu_kampus`)

Tarih: 2026-10-31. Kapsam: yalnız `mobile/` (Android + iOS). Aşama: DENETİM (kod değiştirilmedi).
Yöntem: statik inceleme (manifest, gradle, Info.plist, Dart kaynağı), `git archive HEAD mobile` kopyasında
`flutter pub get/outdated`, katı lint kümesiyle `flutter analyze`, tam `flutter test`. Dinamik test YAPILMADI:
`C:\bu_qa\QA-STACK.txt` içeriği `BUILDING` idi (READY değil), gerçek cihaz yok, üretim sunucusuna erişilmedi.

## Özet

| Şiddet | Adet |
|---|---|
| KRITIK | 0 |
| YUKSEK | 0 |
| ORTA | 9 |
| DUSUK | 12 |
| DOGRULANAMADI | 5 |

Olumlu doğrulananlar (bulgu değil): `allowBackup=false` + `fullBackupContent`/`dataExtractionRules` her şeyi dışlıyor
(Android'de jeton/önbellek yedeğe girmez); jetonlar `flutter_secure_storage` (Keystore/Keychain), düz metin değil;
release'te `usesCleartextTraffic=false` (yalnız `ALLOW_INSECURE_API` ile açılır), `debuggable=false`, `minify+shrinkResources`,
dokümante edilen `--obfuscate --split-debug-info`; release'te `FLAG_SECURE` (ekran görüntüsü/son uygulamalar gizli);
`apiConfigValid` release'te http'yi reddeder (10.0.2.2 varsayılanı release'e gömülemez, açılışta `ConfigErrorApp`);
URL açma yalnız `https` (announcements/home/news/gate); push `target=URL` yalnız `https://`; arama sorguları `encodeQueryComponent`;
sırlar yok (`grep`: api key/secret/password/özel anahtar bulunmadı; `google-services.json` istemci anahtarı kabul edilebilir);
tek gösterimlik ek `MessageCache.sanitizeMessage` ve `persistentNetworkImage(persist:false)` ile diske yazılmıyor;
mesaj bildirimi sunucuda sabit gövdeyle saklanıyor (önizleme diske/`/notifications` önbelleğine girmiyor);
CrashReporter maskeleme (e-posta/JWT/Bearer/UUID/uzun sayı/ev dizini) ve ErrorLog kişisel veri taşımıyor;
oturum kapanışında bellek+ETag+`api_cache`+`msg_cache`+`img_cache`+Outbox(+`outbox_media`)+yerel hatırlatma alarmları temizleniyor.
`use_build_context_synchronously`, `cancel_subscriptions`, `close_sinks` kuralları (projede açık) temiz.

---

## ORTA

### A4-01 - Dışa açık MainActivity, harici `bu_reminder_payload` ekstrasını güvenmeden PushRouter'a veriyor (zorla çıkış / yönlendirme)
- Dosya: `mobile/android/app/src/main/AndroidManifest.xml:35` (`MainActivity exported=true`), `.../MainActivity.kt:33,36-40` (`getStringExtra(EXTRA_PAYLOAD)` -> `onTap`/`takeLaunchPayload`), `lib/core/push/push_service.dart:182-186,407`, `lib/core/push/push_targets.dart:101`, `lib/core/push/push_router.dart:34-38`.
- Senaryo: aynı cihazdaki kötü niyetli uygulama `Intent(component=tr.com.bukampus.app/edu.bingol.bu_kampus.MainActivity).putExtra("bu_reminder_payload", "{\"type\":\"session_replaced\"}")` gönderir. Yük, FCM/yerel hatırlatma yüküyle aynı yola girer; `resolvePushTarget` `type=session_replaced` için `PushDest.signOut` döner ve `PushRouter.open` `forceSignOut(reason: replaced)` çağırır: kullanıcı oturumdan atılır, "başka cihazda giriş" bandı görür (hedefli hizmet reddi / sosyal mühendislik). `{"event":"CONVERSATION_CLOSED","conversationId":N}` ile `ClosedConversations` durumu (sohbet yazma alanı kapanır) elle değiştirilebilir; `conversationId/postId...` ile rastgele ekran açılır (yetki kazanımı yok, sunucu yetkisi geçerli).
- Kanıt: kodda ekstranın kaynağını (kendi `PendingIntent`i mi, dışarıdan mı) ayırt eden bir denetim yok; `PendingIntent` sadece uygulamanın kendi yerel bildirimi için kuruluyor.
- Öneri: (1) `session_replaced`/`CONVERSATION_*` gibi durum değiştiren anahtarları yerel hatırlatma/intent yolundan geçirme (yalnız `targetType/targetId/...` listesi kabul et, `type`/`event` süz); (2) intent ekstrasını imzalayın (reminder kurulurken üretilen rastgele nonce, `ReminderReceiver`-> `MainActivity` ekstrasında doğrula) ya da launcher dışı girişi yok say; (3) yük sınırlarını (anahtar beyaz listesi, uzunluk) uygula.
- Regresyon testi: `resolvePushTarget` için "yerel hatırlatma kaynaklı yük `type=session_replaced` içerse signOut üretmez" birim testi; Android araçlı test (adb `am start -n ... --es bu_reminder_payload ...`) oturumun kapanmadığını doğrular.

### A4-02 - Çıkıştan sonra oturum "dirilebilir": uçuştaki refresh `setTokens(t)` ile jetonları geri yazar; `_persist` serileştirilmemiş
- Dosya: `lib/core/api.dart:492-512` (`_doRefresh` -> `setTokens(t)`), `api.dart:516-528` (`setTokens`: `tokens = t` koşulsuz), `lib/core/session.dart:310-340,348-360` (`signOut`/`_persist`: iki ayrı `write`/`delete`, kuyruk yok).
- Senaryo: Kullanıcı çıkış yaparken (ya da `forceSignOut`) aynı anda uçuşta bir refresh vardır (ör. 401 sonrası). Çıkış `tokens=null` yapar; refresh yanıtı gelince `_doRefresh` `setTokens(yeniÇift)` çağırır: `tokens` yeniden dolar ve Keystore'a yazılır, ama `Session.state` `signedOut` kalır. Sonraki açılışta `restore()` kullanıcıyı geri alır (veya kimliksiz ekranlardaki istekler yetkili gider). Ek olarak `_persist(yeni)` ile `_persist(null)` eşzamanlı çalışırsa (`write access / delete access / delete refresh / write refresh` serpiştirmesi) iki jeton da Keystore'da kalabilir. Sunucu `logout` eski refresh'i iptal ettiği için çoğu zaman yeni çift de geçersizleşir; yine de yarış istemcide kapatılmalı.
- Kanıt: `_doRefresh` sonunda "oturum hâlâ aynı mı?" denetimi yok; `onTokensChanged` çağrıları sıraya alınmıyor.
- Öneri: `_doRefresh` başında oturum nesil sayacı (`_epoch`) al, sonunda `epoch` değişmişse sonucu at; `_persist`'i tek `Future` zincirine al (`_persistQueue = _persistQueue.then(...)`).
- Regresyon testi: `ApiClient` testi: refresh uçuşta iken `setTokens(null)` -> refresh tamamlanınca `tokens` null kalır ve `onTokensChanged(yeni)` çağrılmaz.

### A4-03 - `Outbox.drain` anlık görüntü listesini kullanıyor; çıkış/hesap değişiminde eski kullanıcının kuyruğu yeni oturumla gönderilebilir
- Dosya: `lib/core/outbox/outbox.dart:578-620` (özellikle `for (final it in List.of(_items))` ve üyelik kontrolünün yalnız hata dalında olması, satır 604), `outbox.dart:565-575` (`clear`), `lib/core/api.dart:518-523`.
- Senaryo: A kullanıcısının kuyruğunda 2+ bekleyen metin mesajı var, `drain` ilkini gönderirken (await) A çıkış yapar -> `setTokens(null)` -> `outbox.clear()` `_items`'ı boşaltır. Drain döngüsü anlık görüntüdeki 2. öğeye geçer (artık `_items`'ta değil) ve `send(it)`'i çağırır. B kullanıcısı hızlıca giriş yapmışsa `Authorization` B'nin jetonuyla gider ve A'nın taslağı B adına (B'nin üyesi olduğu bir sohbete) yazılır; B üye değilse 403 alır. Medya öğeleri `MEDIA_LOST` ile düşer, metinler düşmez.
- Öneri: döngü başında `if (!_items.any((e) => identical(e, it))) continue;` ve `clear()` içinde `_generation++` ile uçuştaki drain'i iptal et.
- Regresyon testi: `Outbox` testi: ilk gönderim sürerken `clear()` çağır, ikinci öğenin `sender`'a hiç gitmediğini doğrula.

### A4-04 - Silinen / yönetici kaldırması / engellenen içeriğin önceden diske yazılmış kalıntıları temizlenmiyor
- Dosya: `lib/core/cache/message_cache.dart:191-212` (`markGone` yalnız o sohbetin mesaj satırını iskelete indirir), `message_cache.dart:249-283` (`list.json` `lastMessage` önizlemesi), `lib/core/cache/image_disk_cache.dart:89-92` (`remove` hiçbir üretim kodunda çağrılmıyor; `grep ImageDiskCache.instance.remove` sonuçsuz), `lib/main.dart:163,168` (`onBlockedUser` yalnız `MessageCache.clear`).
- Senaryo/etki: (a) Bir fotoğraf mesajı görüntülendi (küçük resim `img_cache/<sha1(url)>` olarak diske yazıldı), sonra gönderen "herkes için sil" yaptı ya da yönetici kaldırdı: `markGone` sadece JSON iskeletini bırakır, görsel baytları LRU/150 MB dolana ya da çıkışa kadar cihazda kalır (silinen içerik KVKK/yönetici kaldırma amacına aykırı). (b) Silinen mesaj bir yanıtın `replyTo` önizlemesi olarak başka mesajda (`c<id>.json`) ve sohbet listesindeki `lastMessage.text` olarak `list.json`'da düz metin kalır (`markGone` bunlara dokunmuyor; liste ancak bir sonraki çevrimiçi liste çekiminde yenilenir). (c) Engelleme `ImageDiskCache`i temizlemiyor.
- Öneri: `markGone` önce silinecek mesajın `attachments[].url/thumbUrl`'lerini toplayıp `ImageDiskCache.remove` çağırmalı; `replyTo.id == messageId` olan mesajlarda `replyTo.text=''`; `list.json`'da `lastMessage.id == messageId` ise önizlemeyi sıfırlamalı; `onBlockedUser`a `ImageDiskCache.clear` (en azından o kullanıcının avatar/ek URL'leri) ekle.
- Regresyon testi: `MessageCache`+`ImageDiskCache` birim testi: görsel yaz, `markGone`, dosyanın silindiğini ve `list.json`/`replyTo` içinde metin kalmadığını doğrula.

### A4-05 - Kamera/seçici/sıkıştırma geçici dosyaları (tek gösterimlik dahil) hiçbir yerde silinmiyor; çıkışta da temizlenmiyor
- Dosya: `lib/features/chat/media_camera_page.dart:163-164,209-225` (`takePicture`/`stopVideoRecording` çıktısı uygulama önbellek dizininde kalır; yalnız baytlar okunur, dosya silinmez), `lib/core/platform/video_service.dart` (sıkıştırılmış video/poster dosyaları), `lib/core/outbox/outbox.dart:459` (kopya alınır, kaynak dosyaya dokunulmaz). `grep getTemporaryDirectory|getApplicationCacheDirectory` -> hiçbir temizlik/süpürme kodu yok.
- Etki: Kameradan çekilen "tek gösterimlik" fotoğrafın/videonun orijinali `cache/` altında düz dosya olarak kalır (OS yer daralınca siler); çıkış/hesap değişiminde kalır; sonraki kullanıcı kök olmadan da erişemez ama KVKK "gösterimden sonra yok" vaadini zayıflatır. Android'de `camera` eklentisi önbellek dizinine `CAP*.jpg/mp4` yazar.
- Öneri: gönderim/kuyruğa kopyalama sonrası (ve `dispose`'ta) kaynak dosyayı sil; çıkışta (`onUserDataCleared`) `getTemporaryDirectory()` altını (kamera, picker, video_compress alt dizinleri) süpür; açılışta artık dosya süpürmesi.
- Regresyon testi: sahte `path_provider` dizinine dosya koy, `signOut` sonrası boş olduğunu doğrula.

### A4-06 - iOS: Application Support altındaki kullanıcı verisi (iCloud/iTunes yedeği) yedekten hariç tutulmamış
- Dosya: `lib/core/cache/message_cache.dart:42-45` (`msg_cache`), `disk_cache.dart:112-115` (`api_cache`), `image_disk_cache.dart:37-40` (`img_cache`, 150 MB), `outbox.dart:251-254` (`outbox_media`), `photo_autosave.dart:43`; `grep isExcludedFromBackup|NSURLIsExcludedFromBackupKey ios lib` sonuçsuz; `ios/Runner/AppDelegate.swift` içinde hariç tutma yok.
- Etki: Android'de yedek kapalı, ama iOS'ta `getApplicationSupportDirectory()` varsayılan olarak yedeğe girer: son 20 mesaj/sohbet (düz JSON), profil/akademik önbellek (`/users/me`, `/timetable`, `/exams`, `/bookmarks`), bekleyen medya ve 150 MB görsel önbelleği iCloud/Finder yedeğine (şifresiz yedekte okunabilir) yazılır; ayrıca yedeği şişirir. Android `data_extraction_rules` tutarlılığı iOS'ta yok.
- Öneri: bu dizinlere `NSURLIsExcludedFromBackupKey=true` uygulayın (`AppDelegate`'te MethodChannel ya da `Library/Caches` altına taşıyın: `getApplicationCacheDirectory`); mesaj/outbox için ek olarak `NSFileProtectionComplete`.
- Regresyon testi: iOS araçlı test: dizinlerin `isExcludedFromBackup` değerini oku.

### A4-07 - iOS Keychain'deki jetonlar uygulama silinse bile kalıyor (ve şifreli yedeğe girer)
- Dosya: `lib/core/session.dart:55,348-360` (`const FlutterSecureStorage()` varsayılan seçenekler; `IOSOptions` yok), ayrıca `outbox.dart:201-214`, `device_identity.dart:28-41`.
- Etki: iOS Keychain öğeleri uygulama silinip yeniden kurulunca da durur: eski oturum (refresh jetonu) ve bekleyen mesaj kuyruğu (`outbox_v1`) yeniden kurulumda geri gelir (paylaşılan/satılan cihazda önceki kullanıcının oturumu). Varsayılan erişilebilirlik `unlocked` iken öğe şifreli cihaz yedeğiyle yeni cihaza taşınabilir (`..._this_device` değil).
- Öneri: ilk açılışta (`SharedPreferences`/`UserDefaults` işareti yoksa) Keychain'i temizle; `IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device)` kullan.
- Regresyon testi: ilk-açılış temizliği için birim testi (işaret yokken `deleteAll` çağrılır).

### A4-08 - KVKK dışa aktarma verisinin panodan silinmesi güvenilir değil
- Dosya: `lib/features/profile/profil2_my_data_page.dart:17-26,52-56`.
- Senaryo: `/users/me/export` JSON'u (tüm kişisel veri) panoya konur; temizleme 30 sn'lik bir Dart `Timer` ile `Clipboard.getData` okuyup eşitse siler. Android 10+'da uygulama arka plandayken (kullanıcı verileri başka uygulamaya yapıştırmak için gider) panoyu okuyamaz/yazamaz, iOS'ta arka planda zamanlayıcı durur: veri panoda kalır; Android 12-13+ ve iOS bu panoya diğer uygulamaların erişimini bildirir ama engellemez. Kullanıcı uygulamaya dönmezse zamanlayıcı hiç çalışmaz. Çok büyük metin Android pano sınırını (~1 MB binder) aşabilir.
- Öneri: panoya kişisel veriyi koyma; `share`/dosya (ör. `path_provider` + sistem paylaşım) kullan ya da `ClipDescription.EXTRA_IS_SENSITIVE` ile yerel köprüden yaz ve yaşam döngüsü (`resumed`) olayında da temizle.
- Regresyon testi: `kExportClipboardTtl` ve `AppLifecycleState.paused/resumed` ile temizlemeyi doğrulayan widget testi.

### A4-09 - Sohbet fotoğrafları varsayılan olarak galeriye otomatik kaydediliyor (opt-out), ayar hesaplar arası paylaşılıyor
- Dosya: `lib/features/chat/photo_autosave.dart:105-106` (`enabled()`: `!= false` yani varsayılan AÇIK), `:177-214` (alınan fotoğraflar `Gal.putImageBytes` ile "BU Kampus" albümüne), `:37-65` (`photo_autosave.json` çıkışta silinmiyor).
- Etki: Varsayılan açık olduğundan, izin verilmişse üçüncü kişilerden gelen fotoğraflar kullanıcının onayı olmadan genel galeriye ve (açıksa) Google Foto/iCloud bulut yedeğine girer; bu, "silinen/tek gösterimli" korumasının dışında kalır (gönderen sonradan silse bile kopya kalır). Ayar ve kaydedilen ek kimlikleri (`saved` listesi) çıkışta temizlenmediği için ikinci hesap önceki hesabın tercihini devralır.
- Öneri: varsayılanı KAPALI yap (açıkça etkinleştirilsin) ya da ilk fotoğrafta bilgilendirme+onay; `photo_autosave.json` için `onUserDataCleared` kancası ekle.
- Regresyon testi: yeni kurulumda `enabled()==false` ve çıkıştan sonra `saved` listesinin boş olduğu birim testi.

---

## DUSUK

### A4-10 - `BootReceiver exported=true` gereksiz
- `AndroidManifest.xml:62`. `BOOT_COMPLETED`, `TIME_SET`, `TIMEZONE_CHANGED`, `MY_PACKAGE_REPLACED` sistem yayınlarıdır, `exported=false` alıcılar da bunları alır. `true` iken başka uygulamalar alıcıyı serbestçe tetikleyip `rearmAll`'ı (disk+alarm yeniden kurma) çalıştırabilir (pil/gürültü). Öneri: `exported="false"`. Test: `dumpsys`/manifest lint.

### A4-11 - STOMP: `UNAUTHORIZED` döngüsünde geri çekilme yok; `CONNECTED`'da `_attempt` sıfırlanıyor
- `lib/core/realtime/stomp_client.dart:265-271` (`refreshToken()` sonrası hemen `_open()`, `_attempt` artmıyor), `:207` (`_attempt = 0` her CONNECTED'da). Sunucu bağlantıyı kabul edip hemen düşürüyorsa (proxy zaman aşımı, kalıcı `UNAUTHORIZED`, sunucu kapanış döngüsü) ~1 sn'lik yeniden bağlanma + (UNAUTHORIZED'da) her turda bir refresh çağrısı (jeton rotasyonu) fırtınası olur. Öneri: `_attempt`'i bağlantı en az 30 sn kararlı kaldıysa sıfırla; `UNAUTHORIZED` yolunda en fazla 2 ardışık denemeden sonra `sessionExpired`. Test: sahte kanalla arka arkaya `ERROR UNAUTHORIZED` -> deneme sayısı sınırı.

### A4-12 - Yetkili medya isteklerinde ana makine denetimi yok; `Image.network` başlığında 15 dk ömürlü jeton
- `lib/features/chat/chat_media.dart:10`, `lib/features/posts/post_models.dart:11` (`path.startsWith('http') ? path : apiOrigin+path`), `chat_media_viewer.dart:66,107`, `photo_autosave.dart:74` (başlıkla `http.get`); `chatlist_widgets.dart:186`, `chat_detail_page.dart:1301`. Sunucu mutlak/harici URL döndürürse `Authorization: Bearer` o ana makineye gider; ayrıca `http://` kabul edilir. Başlık, widget kurulurken alınan erişim jetonudur (15 dk); jeton değiştikten sonra açılan eski widget'lar 401 alıp görsel hatası gösterebilir (yenileme tetiklenmez). Öneri: Bearer'ı yalnız `apiOrigin` ile aynı ana makinede ekle (https zorunlu), başlığı istek anında üret. Test: `chatMediaUrl`/başlık yardımcıları için "yabancı host'ta Authorization yok".

### A4-13 - `Session.signOut` jeton silme hatasını yutuyor
- `lib/core/session.dart:348-360`. Keystore/Keychain `delete` hatası sessizce geçilir; `state=signedOut` olur ama jetonlar depoda kalabilir ve `restore()` oturumu geri açar. Öneri: silme başarısızsa yeniden dene (kısa), `restore()`'da `signedOut` işaretini ayrıca saklayıp dikkate al. Test: `delete` atan sahte depo ile çıkış -> yeniden açılışta oturum açılmaması.

### A4-14 - Kişisel veri içeren yanıtlar `api_cache`'te düz JSON (sandbox)
- `lib/core/cache/cache_policy.dart:309-329` (`/users/me`, `/me/summary`, `/timetable`, `/exams`, `/bookmarks`, `/notifications`, `/posts`, `/discover`) 1-7 gün diskte, uygulama kutusunda şifresiz. Kök/ADB yedeksiz cihazda okunabilir; çıkışta temizleniyor (doğrulandı). Not: A4-06 ile birlikte iOS yedeğine girer. Öneri: kişisel uçları (`/users/me`, `/me/summary`, `/timetable`, `/exams`, `/bookmarks`) belleğe indirgeyin ya da dosya şifreleme anahtarını Keystore'da tutun.

### A4-15 - Rehber eşleme özeti tuzsuz SHA-256; ilk girişte rehber izni isteniyor
- `lib/core/contacts/contacts_service.dart:36-37`, `lib/features/auth/permissions_page.dart:77`. Yalnız `@bingol.edu.tr` adresleri ve tuzsuz SHA-256: alan adı sabit, e-posta/öğrenci numarası uzayı küçük, sunucu (veya trafiği çözen taraf) özetleri kolayca tersine çevirir; ürün kararı olarak not. Rehber izni "ilk giriş" sayfasında kullanım anından önce isteniyor (Play/App Store "bağlamsal izin" ilkesi); `READ_MEDIA_IMAGES/VIDEO` (manifest satır 16-17) Play'in fotoğraf/video izni politikası beyanı gerektirir. Öneri: izni özelliğin ilk kullanımında iste; sunucuyla paylaşılan tuz/HMAC anahtarı (rotasyonlu) düşün; Play beyanını hazırla.

### A4-16 - `launchUrl` için hata yakalama yok
- `lib/features/home/home_tab.dart:244-249` (`_openUrl`): `launchUrl` `PlatformException` fırlatırsa (işleyici yok) yakalanmaz; `PlatformDispatcher.onError` genel hata olarak raporlanır. Öneri: `try/catch` + toast. Test: sahte `UrlLauncherPlatform` hata atınca widget'ın çökmemesi.

### A4-17 - Saat dilimi: etkinlik/mesaj saatleri cihaz dilimine, menü "bugün" cihaz saatine bağlı
- `lib/features/events/events_page.dart:25,35`, `event_detail_page.dart:705`, `lib/features/menu/menu_page.dart:44,106` (`DateTime.now()`), `lib/core/api.dart:216` (günlük taze önbellek yerel gün sınırı). Yurt dışındaki/yanlış saatli cihazda "bugünün menüsü", etkinlik başlangıç saati ve "bugün" etiketi Europe/Istanbul'dan sapar (akademik modül `academic_models.dart` doğru: sabit +03:00). Öneri: kampüs günü/saati için sabit +03:00 yardımcısı kullanın. Test: `TZ` farkıyla `menu today` seçimi.

### A4-18 - RTL: tek yönlü (`left`) dolgu
- `lib/features/events/events_page.dart:1723` (`EdgeInsets.only(bottom: 8, left: 4)`), `lib/features/profile/notification_prefs_page.dart:363` (`only(left: ...)`), `lib/widgets/academic_picker.dart:144` (`only(top: 6, left: 4)`), `lib/features/posts/post_actions.dart:501` (`Positioned(left: left)` - RTL için hesaplanmış, yerinde doğrulanmalı). Arapça arayüzde dolgu yanlış tarafa düşer. Sabit `Alignment.topLeft/bottomRight` kullanımlarının çoğu dekoratif gradyan (zararsız). Öneri: `EdgeInsetsDirectional.only(start: ...)`. Test: `Directionality.rtl` golden/ölçüm testi.

### A4-19 - Test kalitesi: 29 `*_shots_test.dart` dosyası koşulsuz `skip`, doğrulama (expect) içermiyor
- `test/redesign/*_shots_test.dart` (ör. `k10_shots_test.dart:569-591`): `STORE_SHOTS_OUT` yoksa tüm sahneler `skip` (rapordaki ~864 atlanan test), çalıştırılsa bile yalnız "istisna yok" denetler ve PNG yazar. Bu yüzden "atlanan" sayısı gerçek kapsama açığı değildir ama sahneler regresyon da yakalamaz. Öneri: `dart_test.yaml` etiketiyle (`store-shots`) hariç tut (skip yerine), gerçek ekran koruması için seçili sahnelere golden/semantik `expect` ekle.

### A4-20 - Lint: katı kümede 390 bilgi (228 `discarded_futures`, 75 `unawaited_futures`, 54 `strict_raw_type`)
- Hepsi `info`; `use_build_context_synchronously`, `cancel_subscriptions`, `close_sinks` sıfır. Çoğu `unawaited(...)`'sız fire-and-forget (ör. `lib/features/profile/profile_tab.dart:79-180`, `clubs_tab.dart:123-210`, `chat_detail_page.dart:488-491,1042,1859`). Asıl risk: fırlatan Future'ın yakalanmaması (`PlatformDispatcher.onError` genel hata raporlar). Öneri: kritik yollarda (`chat_detail_page`, `stomp_client.dart:140,248,268`) açık `unawaited` + `catchError`. Test: lint CI'da `unawaited_futures` açılsın (kademeli).

---

## DOGRULANAMADI

- A4-D1 `Authorization` başlığı `dart:io HttpClient` yönlendirmelerinde (`image_disk_cache.dart:179-198`) farklı ana makineye giderken sıyrılıyor mu? Dart sürümüne bağlı, çalıştırılamadı.
- A4-D2 Mesaj düzeyinde `removed/deleted` iken ek `thumbUrl` alanının sunucu yanıtında dolu gelip gelmediği (`message_bubble.dart:777` `persist` yalnız ek düzeyi `removed`/`viewOnce`'a bakıyor): sunucu sözleşmesi + canlı yanıt gerekir.
- A4-D3 Firebase `AIzaSyA6...` API anahtarının (commit'li `google-services.json`) Firebase konsolunda paket adı/SHA-1 ve API kısıtlamasıyla sınırlandırılıp sınırlandırılmadığı.
- A4-D4 Erişilebilirlik: ~790 `Semantics(` var, `GestureDetector` yalnız ~66; 48 dp altı hedefler ve ekran okuyucu sırası kod taramasıyla tam çıkarılamadı (TalkBack/VoiceOver cihazı gerekir).
- A4-D5 Dinamik akışlar (kayıt/giriş/refresh/mesaj/sessiz kuyruk/yoklama): A7 yığını `BUILDING` olduğu için denenmedi.

## Notlar (bulgu değil, kayıt)
- SSL pinning yok (Let's Encrypt/ortak CA'ya güven); ürün kararı. iOS'ta ekran görüntüsü engeli yok (Android'de `FLAG_SECURE` var): tek gösterimlik içerik iOS'ta ekran görüntüsüyle kopyalanabilir.
- `proguard-rules.pro` `com.google.firebase.**`/`gms.**` için geniş `-keep` kullanıyor (boyut, güvenlik etkisi yok).
- Bağımlılıklar güncel; `flutter pub outdated`: yalnız `camera 0.12.1->0.12.2`, `flutter_svg 2.3.0->2.3.2`, `flutter_lints 4->6` (dev) geride; bilinen CVE'li veya terk edilmiş doğrudan bağımlılık görülmedi (CVE veritabanı sorgusu yapılamadı).
- `google-services.json` git'te izleniyor (istemci anahtarı; kabul edilebilir). `key.properties`/keystore git'te yok.
- Yorum/PII: `debugPrint` çağrıları yalnız hata türü yazıyor; kimlik/jeton yazan log bulunmadı.

## Test sonucu (HEAD `git archive` kopyası, `--concurrency=4`)
`flutter test`: 3952 geçti, 864 atlandı (hepsi A4-19'daki `*_shots_test.dart` sahneleri), 1 başarısız.
Başarısız: `test/push_foreground_test.dart:164` "ViewingSignaler: ac -> PUT, periyodik..." (`greaterThanOrEqualTo(3)` beklenen, 1 gelen).
Tek başına koşunca GEÇTİ: gerçek saate bağlı (50 ms aralık / 180 ms bekleme) FLAKY test; paralel yükte düşüyor.

### A4-21 (DUSUK) - Zamana bağlı flaky test
- `test/push_foreground_test.dart:160-170`: gerçek `Future.delayed` ile zamanlayıcı sayımı. Öneri: `fakeAsync` / enjekte edilen saat kullan. CI'da paralel koşuda aralıklı kırmızı üretir.

(Özet tablosundaki DUSUK sayısı A4-21 ile 12'dir.)
