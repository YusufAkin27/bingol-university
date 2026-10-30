# A13: Push / bildirim uçtan uca denetimi

Tarih: 2026-10-31. Denetlenen HEAD: `b405782` (P1 `81fdfb3` + P2 `7f8e287..76da90e` dahil). Kod DEĞİŞTİRİLMEDİ; yalnız bu rapor eklendi.

## 0. Yöntem ve sınırlar (ÖNCE OKUYUN)

- Statik inceleme: `backend/.../notification/**` (NotificationService, PushDispatcher, PushGate, PushPayload, PushMessages, FirebaseFcmSender, PushOutbox*, DeviceService, SessionDeviceCleaner, QuietHours/QuietSql, kampanya), `messaging/MessageService.notifyOffline`, `PresenceService`, `auth/token/SessionService`; mobil `lib/core/push/*`, `features/notifications/*`, `features/profile/notification_prefs_page.dart`, `session.dart`, Android `LocalReminders.kt`, `MainActivity.kt`, `AndroidManifest.xml`, iOS `AppDelegate.swift`/`Info.plist`; belgeler `docs/changes/push.md`, `docs/MOBILE_PUSH.md`.
- Canlı: A7 test yığını (`http://localhost:18081`, FCM KAPALI: `NO_CREDENTIALS`). Betik: yalnız test yığınına karşı API + `psql` (DB'ye yalnız test yığınında bakıldı). Üretim sunucusuna/loglarına HİÇ erişilmedi.
- Android küçük ikon PNG'leri piksel düzeyinde analiz edildi.
- **GERÇEK FCM/APNs TESLİMİ ÖLÇÜLEMEDİ.** Gerçek cihaz ve gerçek FCM kimliği yok. FCM kapalıyken `NotificationService.doSend` `dispatcher.enabled()` false ile push adımından önce döner; `push_outbox`'a satır YAZILMAZ (canlı doğrulandı: 3 mesaj sonrası `push_outbox` = 0 satır; yalnız `notification` kutu satırı oluştu). Bu yüzden "mesaj -> outbox satırı -> yük" zinciri test yığınında GÖZLENEMEDİ (`app.push.outbox.hold-when-disabled=true` ile yığını yeniden başlatmak A7'nin yığınına müdahale olurdu, yapılmadı). Yük içeriği yalnız birim testlerin (`FirebaseFcmPayloadTest`, `NotificationSmartPushTest`) ve kodun okunmasıyla doğrulandı.
- Backend birim testleri bu denetimde koşturulmadı (yığın makinesi yoğun; testler HEAD'de yeşil varsayıldı).

## 1. Özet

| Şiddet | Adet |
|---|---|
| Kritik | 0 |
| Yüksek | 0 |
| Orta | 5 (A13-01 ... A13-05) |
| Düşük | 12 (A13-06 ... A13-17) |
| Bilgi | 2 (A13-18, A13-19) |

En önemli 5: A13-01 (Android `tag` ile farklı bildirimler birbirinin yerini alıyor), A13-02 (`logout-all`/şifre sıfırlama cihaz kaydını silmiyor), A13-03 (bildirim kutusu "Okunmamış" süzgeci eksik liste gösteriyor), A13-04 (iOS ikon rozeti ve Android tepsisi okunsa da temizlenmiyor), A13-05 (moderasyon bildirimi `MESSAGE` hedefi yanlış sohbete gidiyor).

P1 (sunucu) ve P2 (mobil) sözleşmesi çekirdekte uyumlu: kanal kimlikleri (`chat/event/announcement/poll/social`) sunucu `PushMessages.CHANNEL_*` ile mobil `push_channels.dart` + Kotlin `Channels` birebir aynı; `default_notification_channel_id=announcement`; `academic` kanalı yalnız yerel hatırlatma (sunucu göndermiyor, mobil `BuApplication.onCreate` + `MainActivity.onCreate` ile oluşturuyor); `targetType/targetId` ve doğrudan anahtarlar `resolvePushTarget` ile çözülüyor; `messageId` tekilleştirmesi, `fcmToken` ile çıkış, token'ı her girişten sonra yeniden kaydetme (registrar `reset()`), 15sn/1/5/15dk yeniden deneme uygulanmış.

## 2. Sözleşme uyumu tablosu (olay -> sunucu -> mobil)

Sunucu `PushPayload.build` her yüke `type`, `subtype`, `target/value`, `targetType/targetId` (TARGETS sırası: postId, pollId, conversationId, eventId, communityId, newsId, ticketId, feedbackId), `PushMessages.of` ise `channelId`, `threadId`, `tag`, `collapseKey`, `badge` ekler. Mobil `resolvePushTarget` doğrudan anahtarları önceliklendirir.

| Olay | Tür / alt tür | Kanal (sunucu) | Öncelik / TTL | Yük anahtarları | Android `tag` | Mobil yönlendirme | Uyum |
|---|---|---|---|---|---|---|---|
| Sohbet mesajı (birebir/grup) | MESSAGE / MESSAGE_DIRECT\|GROUP | chat | HIGH / 7 gün | conversationId, messageId, conversationType, senderName, [conversationTitle, senderAvatarUrl], badge | `conv:<id>` | ChatDetailPage; ön planda messageId tekilleştirme + açık sohbet bastırma | Tamam. `senderAvatarUrl/conversationTitle/badge` mobilde okunmuyor (A13-12) |
| Etkinlik hatırlatma (1 gün/1 sa) | EVENT / EVENT_REMINDER | event | normal / 6 sa | eventId | `event-<id>` | EventDetailPage | Tamam |
| Etkinlik katılım sonucu/başvuru | EVENT / EVENT_ADMISSION | event | HIGH / 1 gün | eventId, applicationId | `event-<id>` | EventDetailPage | Tamam |
| Etkinlik onay/ret/güncelleme/iptal | EVENT / EVENT_UPDATE | event | normal / 1 gün | eventId | `event-<id>` | EventDetailPage | Tamam (tag: A13-01) |
| Kulüp başvuru/onay/rol | COMMUNITY / COMMUNITY_JOIN\|ROLE | announcement | normal / 3 gün | communityId | `community-<id>` | ClubDetailPage | Tamam (tag: A13-01) |
| Kulüp gönderisi | COMMUNITY / COMMUNITY_POST | announcement | normal / 3 gün | communityId (+postId), collapse `commpost:<id>` | collapseKey | post/kulüp | Tamam |
| Anket (genel, yayın) | ANNOUNCEMENT / POLL (prefColumn `polls`) | poll | normal / 3 gün | pollId | `announcement` | openPollDetail | Tamam (tag: A13-01) |
| Anket (kulüp/hedefli) | COMMUNITY\|ANNOUNCEMENT / POLL | poll | normal / 3 gün | pollId, communityId | `community-<id>` | openPollDetail | Tamam |
| Bölüm/akademik duyuru | ANNOUNCEMENT (alt tür yok, prefColumn `academic_announcements`) | announcement | normal / 3 gün | target=ANNOUNCEMENT, value, announcementId | `announcement` | `announcementId` dalı -> AnnouncementDetailPage (target ANNOUNCEMENT haber sanılmaz, doğrudan anahtar önce) | Tamam |
| Haber (tek) | NEWS (veya kaynak ETKİNLİK ise EVENT) | announcement\|event | normal / 3 gün\|1 gün | newsId | `news` | NewsDetailPage | Tamam. Kaynak etkinlik haberi `events` bayrağına ve `event` kanalına bağlı (tasarım gereği?) |
| Haber (çoklu "3 yeni haber") | NEWS | announcement | normal | yok (boş data) | `news` | Bildirimler listesi | Tamam |
| Takip | USER_FOLLOW | social | normal / 1 gün, iOS passive | target=USER, value, userId | `follow:<id>` | openUserProfile | Tamam |
| Beğeni | POST_LIKE | social | normal / 1 gün | postId | `postlike:<post>:<pencere>` | openPostDetail | Tamam |
| Destek yanıtı/kapanış | SYSTEM | announcement | HIGH / 7 gün | ticketId | `system` | SupportTicketPage | Tamam (tag: A13-01) |
| Moderasyon (gizlendi/kaldırıldı/geri) | SYSTEM | announcement | HIGH | targetType, targetId | `system` | `_destOf(targetType)` | `MESSAGE` hatalı (A13-05) |
| Sohbet kapatıldı/yeniden açıldı/kaldırıldı | SYSTEM | announcement | HIGH | conversationId, targetType=CONVERSATION, event | `conv:<id>` (sohbet tag'iyle çakışır, A13-01) | ClosedConversations + sohbet / sohbet listesi | Tamam |
| Yönetici kampanyası | seçilen tür | tür kanalı (poll yok) | tür | target (NEWS/EVENT/COMMUNITY/POLL/TICKET/URL), value, campaignId | tür adı | `URL` HARİÇ hepsi | URL desteklenmiyor (A13-07) |
| signOut (başka cihaz girişi) | - | - | - | - | - | mobil `type=session_replaced` dalı var | Sunucu böyle bir push GÖNDERMİYOR (401 `SESSION_REPLACED` ile öğrenilir); mobil dal ölü kod (A13-13) |

Not: `PushMessages.channel(...)` yalnız 5 kimlik üretir; `academic`/`community`/`system` kanalı sunucudan hiç gelmiyor (`docs/changes/push.md` ile uyumlu). Mobil `academic` kanalını yerel hatırlatma için oluşturuyor; `community`/`system` kanalı mobilde de yok (gerek yok).

## 3. Bulgular

### A13-01 [Orta] Android `tag` varsayılanı tür adı/thread: farklı bildirimler tepside birbirinin yerini alıyor
- Yer: `FirebaseFcmSender.java` `android()` (`else if (m.threadId() != null) n.setTag(m.threadId())`), `PushMessages.threadId()` (`type.name().toLowerCase()` varsayılanı; `community-<id>`, `event-<id>`, `post-<id>`), `PushMessages.of` (`data.put("tag", collapseKey != null ? collapseKey : thread)`). Test `FirebaseFcmPayloadTest.java:46` bu davranışı doğru kabul ediyor (`tag == "news"`).
- Tekrar: aynı kullanıcıya iki bölüm duyurusu / iki anket / bir destek yanıtı + bir moderasyon bildirimi / bir etkinlik güncellemesi + hatırlatması gönder (telefon kilitliyken).
- Beklenen: her bildirim ayrı satır. Gerçek (kod okumasıyla): FCM/Android aynı `tag` + aynı kimliği taşıyan bildirimi YENİSİYLE DEĞİŞTİRİR. Duyuru/anket/kulüp/sistem/haber için `tag` sabit (`announcement`, `news`, `system`) olduğundan tepside yalnız sonuncu kalır; öncekiler tepsiden kaybolur (kutuda durur). Şikâyet "bazı bildirimler gelmiyor" ile doğrudan ilişkili olabilir. SYSTEM sohbet bildirimi (`conversationId` taşır) sohbetin `conv:<id>` etiketini paylaşır: mesaj bildirimi ile sistem bildirimi birbirini siler.
- Etki: kaçan duyuru/ödev/sistem uyarısı; yalnız Android (iOS `thread-id` gruplar, değiştirmez; `apns-collapse-id` yalnız collapseKey varken).
- Öneri: `tag` yalnız gerçekten birleştirilmesi istenen yerde (sohbet `conv:<id>`, `follow:`, `postlike:`, `commpost:`) gönderilsin; diğerlerinde `tag` hiç konulmasın (FCM her biri için benzersiz etiket üretir) ya da `campaignId`/bildirim kimliği gibi benzersiz değer kullanılsın. `threadId` iOS gruplaması için kalabilir. Testi buna göre güncelleyin.
- GERÇEK CİHAZDA DOĞRULANMALI (bkz. bölüm 6).

### A13-02 [Orta] `logout-all`, şifre sıfırlama/değişimi cihaz push kaydını SİLMİYOR
- Yer: `SessionDeviceCleaner.onSessionsRevoked` (`!e.newLogin() || !"mobile".equals(e.client())` ise çıkar); `SessionService.revokeAll` olayı `(userId, null, false, ...)` yayınlar. Test `SessionDeviceCleanerTest.otherRevocationsKeepDevices` bunu bilerek sabitliyor.
- Tekrar (test yığınında yapıldı): kullanıcıya 2 cihaz kaydı ekle -> `POST /api/auth/logout-all` -> `device` tablosunda 2 kayıt duruyor (yeniden girişe kadar). Yeni mobil girişte ise 0'a iniyor (doğru).
- Beklenen: "tüm cihazlardan çık" ve şifre sıfırlama sonrası oturumu kapanan cihazlara bildirim gitmemeli. Gerçek: diğer cihazlar (uygulamayı açıp 401 almadıkça) mesaj bildirimini (gönderen adı + "Yeni mesaj"; önizleme açıksa metin) kilit ekranında almaya devam eder. Hesap ele geçirilip şifre sıfırlandıysa saldırganın telefonu da bildirim alır.
- Etki: gizlilik/güvenlik (KVKK), gereksiz gönderim.
- Öneri: `revokeAll` (client == null) olayında da `deleteAllByUser`; aktif cihaz girişten sonra kendini yeniden kaydeder (mevcut akış). Test güncellenmeli.

### A13-03 [Orta] Bildirim kutusu "Okunmamış" süzgeci yalnız yüklenmiş ilk sayfayı süzüyor
- Yer: `notifications_page.dart` `shown = _unreadOnly ? _items.where(...)`, `_scroll` dinleyicisi yalnız kaydırmada `_loadMore` çağırır. Sunucu `GET /api/notifications?unread=true` destekliyor, kullanılmıyor.
- Tekrar: 20+ bildirimi olan, okunmamışları ilk 20'den eski olan kullanıcı; "Okunmamış" çipine bas.
- Beklenen: tüm okunmamışlar. Gerçek: ilk sayfada okunmamış yoksa "Okunmamış bildirim yok" boş durumu çıkar (üstte sayaç N>0 olsa da); az öğe varsa liste kaydırılmadığı için sonraki sayfa hiç yüklenmez.
- Öneri: süzgeç `unread=true` ile sunucudan çekilsin (cursor ayrı), ya da süzgeç sonucu ekranı doldurmuyorsa otomatik `_loadMore`.

### A13-04 [Orta] Okunan sohbetin tepsi bildirimi / iOS ikon rozeti temizlenmiyor
- Yer: mobilde `applicationIconBadgeNumber`, `cancelAll`/`NotificationManager.cancel` ya da rozet eklentisi YOK (`grep`: yalnız uygulama içi `AppBadges`). `docs/MOBILE_PUSH.md` "Sınırlar" bu konuyu hiç anmıyor.
- Etki iOS: sunucu her push'ta `aps.badge` = okunmamış bildirim sayısını yollar; kullanıcı sohbeti uygulamada okuyunca/uygulamayı açınca ikon rozeti bir sonraki push'a kadar eski sayıda KALIR (iOS rozeti uygulama temizlemedikçe silmez).
- Etki Android: kullanıcı sohbeti simgeden açıp okuyunca `conv:<id>` etiketli bildirim tepside kalır (yalnız bildirime dokununca otomatik kapanır).
- Öneri: ön plana dönüşte/okunduğunda iOS'ta rozeti `unreadCount` ile eşitle (`UNUserNotificationCenter.setBadgeCount` ya da `flutter_app_badger`), Android'de `NotificationManager.cancel(tag="conv:<id>", id=0)` için küçük platform kanalı ve `getActiveNotifications` ile temizlik.

### A13-05 [Orta/Düşük] Moderasyon bildirimi `targetType=MESSAGE` mobilde sohbet kimliği sanılıyor
- Yer: `ModerationNotifier.data(...)` (`targetType=MESSAGE`, `targetId=<mesaj kimliği>`) -> mobil `push_targets.dart` `_destOf('MESSAGE')` = conversation; `PushRouter._go` `GET /conversations/<mesajId>`.
- Beklenen: mesaj kaldırma bildirimi bildirim listesine ya da ilgili sohbete gitmeli. Gerçek: mesaj kimliği başka bir konuşmanın kimliğiyse (kullanıcı üyeyse) YANLIŞ sohbet açılır; değilse 404 -> listeye düşer. `MESSAGE_IMAGE`, `USER_AVATAR` doğru şekilde listeye düşüyor.
- Öneri: sunucu mesaj hedefinde `conversationId` da göndersin (ya da `targetType` göndermesin); mobilde `MESSAGE` eşlemesi yalnız `conversationId` varsa kullanılsın.

### A13-06 [Düşük] Bildirim kutusu satırı: sayaç ve tür görünümü eksik
- `notifications_page.dart`: sunucu `count`/`groupKey` döndürüyor; mobil hiç kullanmıyor. Canlı: 3 mesajlık sohbet satırı başlık "A13 Ali", gövde "Yeni mesaj" (sayaç 3 görünmez). Push gövdesi "N yeni mesaj" olsa da kutuda 57 mesaj da "Yeni mesaj" görünür.
- `_icon/_typeLabel/_tone`: `USER_FOLLOW`, `SYSTEM`, `POST_MENTION` tanımsız -> genel zil ikonu + "Diğer" etiketi (destek yanıtı, moderasyon, takip hep "Diğer").
- Öneri: `count>1` için "N yeni mesaj" metni (l10n), `USER_FOLLOW` (kullanıcı+), `SYSTEM` (kalkan/yardım) ikon ve etiketleri.

### A13-07 [Düşük] Kampanya `URL` hedefi mobilde açılmıyor
- `PushService._open` https'i doğruluyor ama `resolvePushTarget` `URL` için `notifications` döndürür; tarayıcı açan kod yok. Yönetici panelinde "URL" seçilebilir ve https zorunlu kılınmıştır; kullanıcı dokununca yalnız Bildirimler listesi açılır.
- Öneri: `url_launcher` ile https açma ya da panelde URL seçeneğini mobil destek verene kadar uyar.

### A13-08 [Düşük] Test yığınında doğrulanan: token sahipliği ve tek-cihaz davranışı (BİLGİ NİTELİKLİ DOĞRULAMA)
- İki kullanıcı aynı token'ı kaydederse son kaydeden kazanır (`device.fcm_token` benzersiz; sahiplik taşınır); eski kullanıcı kaydı kaybeder. Normal akışta çakışma yok (çıkışta `deleteToken` + `fcmToken` ile silme). Aynı fiziksel telefonda hesap değişimi: yeni hesap token'ı devralır, eski hesap push almaz (beklenen).
- Yeni mobil giriş kullanıcının TÜM kayıtlarını siler (2 -> 0, doğrulandı); mobil giriş sonrası `onSignedIn -> _register` ile yeniden kaydediyor (registrar `reset()` + token değişimi nedeniyle atlama yok). Yarış: giriş isteği (silme) biter bitmez mobil kaydeder; sıra bozulmaz.
- Cihaz sınırı 10 (en eski `updatedAt` düşer); 60 gün temizliği aktif kullanıcıyı (`app_user.last_seen_at` taze) korur. Sorun yok.

### A13-09 [Düşük] Anket tercih satırı kilitleme mantığı sunucu kuralıyla tam örtüşmüyor; beğeni/takip ayrı kapatılamıyor
- Sunucu: genel anket = `announcements AND polls`; kulüp anketi = `communities AND polls` (`doSend` COMMUNITY türü). Mobil `_lockedByParent`: `polls` satırı yalnız `announcements` kapalıyken pasif. `announcements` kapalı + `communities` açık + `polls` açık iken kulüp anketi bildirimleri GELMEYE devam eder ama satır pasif/dokunulamaz (kullanıcı kapatamaz). Not metni ("Duyurular veya Kulüpler kapalıysa ilgili anket bildirimleri gelmez") doğru; kilit ise eksik.
- `communities` bayrağı beğeni/takip/yorum türlerini de kapsar (`NotificationService.enabled`); mobil tercih ekranı bu alt türleri çizmiyor (kaldırıldı) -> "Kulüpler" anahtarı takip/beğeni push'unu da susturur, kullanıcı bunu bilmez. Öneri: açıklamaya ekleyin ya da bu alt türleri tercihe ekleyin.

### A13-10 [Düşük] "Bildirimler çalışmıyor mu?" ekranı sunucudaki kaydı doğrulamıyor
- `push_health.dart`: `registration` yalnız yerel `PushRegistrar` durumudur. Sunucu kaydı silinmişse (başka cihaz girişi, `UNREGISTERED` temizliği, cihaz sınırı, erişim engeli) ekran "kayıtlı" der; düzelme ancak 6 saatlik tazelemeyle olur. `GET /api/devices` ile token son-6 haneli karşılaştırma yapılabilir. Kritik kanal listesi `chat/event/announcement`; `poll/social` kapatılması bilerek yok sayılıyor (doğru).
- Pil ipucu yalnız üretici listesine bakıyor (`samsung` dahil); ölçülemez, doğru.

### A13-11 [Düşük] Sessiz bastırma noktaları görünmez
- `PushGate`: mesaj dışı türler kullanıcı başına dakikada 10, mesaj 60 (sınır aşan push SESSİZCE düşer; kutu satırı kalır; sayaç/metric yok). `docs/changes/push.md` P14 bunu bilinen sınır olarak yazıyor.
- `viewing:` (45 sn) + canlı WS birlikteyse push YOK ve kutu satırı da YOK (kasıtlı). Uygulama arka plana alınırken `DELETE viewing` ağ yüzünden gitmezse, WS donmuş soket olarak ~30 sn "çevrimiçi" kaldığından bu pencerede o sohbetin mesajları hiç bildirilmez (dar pencere, ≤45 sn).
- Sessiz saatte gelen mesajlar için sonradan özet/gecikmeli push yok (kutu satırı kalır).
- Öneri: bastırılan push'ları Micrometer sayacına yazın (`push.suppressed{reason}`); sessiz saat bitiminde özet bildirimi düşünülebilir.

### A13-12 [Düşük] Sunucunun hesapladığı yük alanları mobilde tüketilmiyor
- `senderAvatarUrl` (gizlilik sorgusuyla her mesaj alıcısı için hesaplanıyor), `conversationTitle`, `senderName`, `badge`, `tag`, `channelId` mobilde okunmuyor (`grep`). Ön plan şeridi `BuAvatar(name: title)` baş harf gösteriyor; avatar URL'i yük boyutunu ve sorgu maliyetini artırıyor ama kullanılmıyor.
- Öneri: şeritte avatar URL'ini kullanın ya da sunucudan çıkarın.

### A13-13 [Düşük] Mobilde ölü/yanıltıcı kodlar ve belge sürüklenmesi
- `resolvePushTarget` `type=session_replaced` dalı: sunucu böyle push göndermiyor (`SESSION_REPLACED` 401 koduyla yürüyor).
- `push_registrar.dart` yorumu ve `docs/MOBILE_PUSH.md` "sunucu hız sınırı 30/saat" der; P1 ile 120/saat oldu. `build.gradle.kts` yorumu "google-services.json git'te değildir" der, dosya izleniyor (`git ls-files`). `NotificationPref.java` yorumu `messagePreview` için V890 der, migration V896.
- `_appVersion` `String.fromEnvironment('APP_VERSION', defaultValue: '2.0.3')`: derleme `--dart-define` verilmezse sunucuya hep 2.0.3 gider (yönetici cihaz özeti yanlış sürüm gösterir).

### A13-14 [Düşük] FCM kimliği yok/kapalıyken bildirimler kalıcı kuyruğa yazılmıyor
- `PushDispatcher.enabled()` = `fcm.enabled() || outbox.holdWhenDisabled()`; `hold-when-disabled` varsayılan `false`. FCM kapalıyken (kimlik yok ya da `INIT_FAILED`) yalnız kutu satırı yazılır, push SİLİNİR; kimlik sonradan girilince geçmiş bildirimler gitmez. Üretimin gerçek durumu BU DENETİMDE GÖRÜLEMEDİ (üretime erişim yasak).
- Öneri: üretimde `GET /api/admin/push/fcm/status` (`enabled`, `projectId`, `error`) ve `actuator/health` `fcm`/`pushQueue` ayrıntısını kullanıcı elle doğrulasın; açılışta `FCM BASLATILAMADI` ERROR log'u var.

### A13-15 [Düşük] Android sistem bildirimi görünümü
- Küçük ikon: `res/drawable-{m,h,xh,xxh,xxxh}dpi/ic_stat_bu.png` boyutlar 24/36/48/72/96, RGBA, görünen tüm pikseller beyaz (254/255), geri kalanı tam saydam (örn. xhdpi: 1810 saydam, 157 opak, 337 yarı saydam): TEK RENK + ŞEFFAF, beyaz kare riski YOK. Glif "BÜ"; Ü'nün nokta işaretleri mdpi'de ~1-2 px (küçük boyutta okunmayabilir). Vurgu rengi `#F73B2E` (manifest `default_notification_color`).
- Sistemin çizdiği bildirimde büyük ikon, eylem düğmesi, BigText/gruplama özelleştirmesi yok (belgede kabul edilmiş). Sistem FCM gövdesini otomatik genişletir. Kanal adları/açıklamaları tr/en/ar tam (12 anahtar x 3 dil). iOS: bildirim servis eklentisi yok (`mutable-content=1` etkisiz), `thread-id` ile gruplama var.
- Kanal önemi (chat HIGH, event/announcement/poll DEFAULT, social LOW, academic HIGH) P2'den önce de aynıydı (git geçmişi): mevcut kurulumlarda önem değişikliği sorunu YOK.

### A13-16 [Düşük] Derleme koruması
- `app/build.gradle.kts`: `google-services.json` yoksa yalnız Gradle uyarısı verir ve push'suz derleme üretir (sessiz). Dosya şu an izleniyor ve paket `tr.com.bukampus.app` ile eşleşiyor; yine de sürüm derleme betiğinde dosya varlığı zorunlu kılınmalı.

### A13-17 [Düşük] Ön plan sayaçları
- `PushService.handleForeground`: MESSAGE push'u `notifications` rozetini artırmaz (kutu satırı oluşur), non-MESSAGE her ön plan push'u artırır (sunucu kuralıyla düşen/birleşen satırlarda sayaç kayabilir). Bir sonraki `GET /notifications` ile düzelir.

### A13-18 [Bilgi] iOS: APNs anahtarı yok
- Biliniyor (proje notu): APNs anahtarı yüklenene kadar iOS kullanıcıları push ALMAZ; sunucuda `THIRD_PARTY_AUTH_ERROR` -> outbox DEAD (cihaz kaydı silinmez, `retry-dead` ile tekrar). iOS `fetchPushToken` APNs'i en çok 10 sn bekler. "Bazı kullanıcılara gitmiyor" şikâyetinin iOS bölümü BUDUR; kod değişikliğiyle çözülmez. `Runner.entitlements` içinde `aps-environment` bulunuyor; belge push yetkisinin yalnız `BuPush.xcconfig` ile bağlandığını söylüyor (xcross imzalamasında doğrulanmadı).

### A13-19 [Bilgi] Yük ve kuyruk tarafı doğrulananlar (sorun yok)
- Yük 4096 B sınırı `PushPayload.fit`; reserved (`google*`, `gcm*`, `from`) anahtarlar atılıyor. TTL: mesaj/SYSTEM 7 gün, haber/duyuru/kulüp 3 gün, etkinlik/sosyal 1 gün, hatırlatma 6 sa; APNs `apns-expiration` gönderim anında hesaplanıyor. FCM `collapse_key` gönderilmiyor. Kalıcı hata -> DEAD + `error_code`, `UNREGISTERED/SENDER_ID_MISMATCH` -> cihaz silinir, `INVALID_ARGUMENT` yalnız "token" geçiyorsa token hatası. Outbox: SKIP LOCKED + 5 dk kira, geri çekilme, 24 sa ömür, 6 deneme. `SendResult` her kayıt için ayrı sonuç (çok cihazlı kullanıcıda bir cihazın hatası diğerini etkilemez, token bazlı `byToken`). Sessiz saat: tekil yolda `QuietHours` (saat dilimi NOT NULL varsayılan İstanbul), toplu yolda `QuietSql` COALESCE İstanbul: tutarlı. `muted/mutedUntil`, yapışkan arşiv, engel (`hiddenFrom`), gölge engel (yalnız gönderene WS), askı/silinmiş (`RecipientGuard`) mesaj push'unda uygulanıyor. Kampanya hedef kitlesi (bölüm/fakülte/sınıf/dil/e-posta) yalnız ACTIVE + e-posta doğrulanmış; her dil kendi metniyle.

## 4. "Bazı kullanıcılara gitmiyor" senaryo kontrol listesi

| Senaryo | Sonuç |
|---|---|
| Kayıt yarışı: giriş sonrası kayıt | Sıra güvenli; yeniden kayıt zorunlu ve yapılıyor |
| Kayıt başarısız (ağ/5xx/429) | 15 sn/1/5/15 dk yeniden deneme; hak bitince `failed`, sonraki ön plana dönüşte tekrar |
| 4xx kayıt hatası | Kalıcı sayılır (400 örn. token > 500 karakter: FCM token ~160, risk yok) |
| İzin reddi | Token kaydedilmez, ayardan açınca ön plana dönüşte kaydedilir |
| Android 13 `POST_NOTIFICATIONS` | Manifestte + `requestPermission` |
| iOS APNs | Anahtar yok: hiç gelmez (A13-18) |
| Başka cihaz girişi | Eski cihaz kaydı silinir (kasıtlı) |
| `logout-all` / şifre sıfırlama | Kayıt KALIR (A13-02) |
| Çıkış | `fcmToken` ile silme + `deleteToken` |
| 10 cihaz sınırı, 60 gün | Sorun yok |
| Sessiz saat / alt tür / ana bayrak / anket+akademik AND kuralı | Sunucu uyumlu; mobil metni doğru, kilit eksik (A13-09) |
| `message_preview` | Varsayılan kapalı, gövde "Yeni mesaj" |
| Tepside kaybolma | A13-01 |
| Dakikalık sınır (10 genel, 60 mesaj) | Sessiz düşer (A13-11) |
| OEM pil kısıtı | Sunucudan çözülemez; ekran ipucu veriyor |
| Çok cihazlı (4-5 kayıt) kullanıcı | Her cihaz ayrı outbox satırı; token bazlı sonuç |

## 5. Test boşlukları (P1/P2 testlerinin KAPSAMADIĞI)

1. Uçtan uca zincir yok: `MessageServiceTest` `NotificationService`'i taklit ediyor; `NotificationSmartPushTest` sahte FCM ile ama presence/kanal/outbox olmadan. "mesaj -> `notifyOffline` -> `doSend` -> `PushOutboxService` -> `PushOutboxWorker` -> `FcmSender.deliver` -> yük" tek testte doğrulanmıyor. Bu denetimde canlıda FCM kapalı olduğundan yalnız kutu satırı kısmı doğrulandı.
2. Tepsi birleşme semantiği (A13-01) testle doğru kabul edilmiş; ters yönde test yok.
3. `logout-all` / şifre sıfırlama sonrası cihaz kaydı (A13-02): test tersini onaylıyor.
4. Sunucu `PushMessages.CHANNEL_*` ile mobil `push_channels.dart` / Kotlin `Channels` kimlik eşitliği için sözleşme testi yok (elle eşleştirildi, şimdilik uyumlu).
5. Moderasyon yükü -> `resolvePushTarget` (A13-05) test edilmiyor.
6. Bildirim kutusu "Okunmamış" süzgeci için sayfalama senaryosu testi yok (`notif_design_test` yalnız basit süzme).
7. Android `Channels.ensure`, `pushDiagnostics`, FCM sistem gösterimi: otomatik test yok (cihaz gerektirir).
8. Çoklu cihazlı kullanıcıda kısmi başarı (bir token UNREGISTERED, diğeri başarılı) için `PushOutboxWorkerTest` içeriği bu denetimde satır satır incelenmedi.
9. Mobil `PushService` yaşam döngüsü (gerçek `FirebaseMessaging` olmadan) kısmen sahteyle; `onTokenRefresh`, `getInitialMessage` yolları birim testte yok.

## 6. GERÇEK CİHAZDA DOĞRULANMALI (kullanıcının elle yapacağı adımlar)

1. Üretimde `GET /api/admin/push/fcm/status` `enabled=true` ve `projectId=bu-kamp` mi; `actuator/health` içinde `pushQueue.details.errorCodes` ve yönetici paneli Push Ops: DEAD/FAILED var mı (üretime erişmedim).
2. Android 13+ gerçek cihaz: yeni kurulum, izin ver; giriş yap; panelde `GET /api/admin/users/{id}/push-devices` kaydı görünüyor mu.
3. A13-01: telefonu kilitle; yönetici panelinden aynı kullanıcıya art arda 2 farklı duyuru (kampanya, tür ANNOUNCEMENT) gönder: tepside 2 ayrı satır mı, 1 mi?
4. Uygulamayı kaydırıp kapat (force-stop OLMADAN) + ekranı kilitle: mesaj geliyor mu (başlık üstü banner, ses, ikon, renk, kilit ekranında "Yeni mesaj"). Ardından Doze'da (ekran kapalı 30+ dk) tekrar dene.
5. Xiaomi/Oppo/Huawei/Vivo cihazda kaydırarak kapat: mesaj gelmiyorsa "otomatik başlat" ayarı; yardım ekranı bağlantıları doğru ayar sayfasını açıyor mu.
6. Sohbet kanalını sistem ayarından kapat: yardım ekranı uyarısı çıkıyor mu.
7. Bildirime dokunma: arka planda, tamamen kapalıyken (soğuk açılış `getInitialMessage`), ön planda şerit; sohbet/etkinlik/anket/duyuru/destek hedefleri doğru ekran mı; moderasyon "mesaj kaldırıldı" bildirimi (A13-05).
8. Aynı hesapla ikinci telefondan gir: ilk telefon bildirim almamalı; ikinci cihazda "Tüm cihazlardan çık" sonrası diğer telefona mesaj at: bildirim GELİYORSA A13-02 doğrulanır.
9. iOS (APNs kurulunca): ön plan/arka plan/kapalı, ikon rozeti sohbeti okuyunca sıfırlanıyor mu (A13-04), Odak/özet ayarları.
10. Bildirim kutusu: 25+ bildirim, okunmamışlar eskide iken "Okunmamış" süzgeci (A13-03); mesaj satırında sayaç.
11. Mesaj önizleme anahtarı: aç/kapat; kilit ekranında metin görünüyor/gizleniyor.
12. Sessiz saat: kapsayan aralıkta mesaj/duyuru: bildirim gelmez, kutuda görünür; `SYSTEM` (destek yanıtı) sessiz saati aşar.
13. Android küçük ikonun gerçek cihazda göründüğü boyut (A13-15), açık/koyu durum çubuğu.
14. Dil değişimi (tr/en/ar): kanal adları sistem ayarlarında güncelleniyor mu, push metni kayıtlı dilde mi.
