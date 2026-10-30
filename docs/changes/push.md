# Push değişiklikleri (modül: push)

Tüm değişiklikler geriye uyumludur (yalnızca ekleme).

## Cihaz kaydı

`POST /api/devices` (JWT, 30/saat)

```json
{ "fcmToken": "…", "platform": "ios", "appVersion": "1.4.0", "locale": "tr" }
```

- `platform`: `ios | android | web` (büyük/küçük harf fark etmez; sunucu büyük harfe çevirir).
- `appVersion` (en çok 32), `locale` (en çok 16) isteğe bağlı.
- Upsert: aynı token başka kullanıcıdaysa yeni kullanıcıya devredilir. Her çağrı `lastSeenAt` değerini yeniler;
  uygulama her açılışta (ve token yenilenince) çağırmalıdır. Kullanıcı başına en çok 10 cihaz; fazlası en eskiden silinir.
- 60 gün (`app.push.device-ttl-days`) görülmeyen token'lar gece 04:00'te silinir.
- `DELETE /api/devices/{token}`: çıkışta çağrılmalıdır. `GET /api/devices` yanıtına `appVersion`, `locale`, `lastSeenAt` eklendi.
- Yanıt: 204. Doğrulama hatası: 400 (`platform` geçersiz vb.).

## Push `data` yükü (mobil yönlendirme sözleşmesi)

Tüm değerler string'dir.

| Anahtar | Açıklama |
|---|---|
| `type` | NEWS, ANNOUNCEMENT, EVENT, MESSAGE, COMMUNITY, SYSTEM |
| `subtype` | varsa alt tür |
| `targetType` | NEWS, EVENT, COMMUNITY, POST, CONVERSATION, TICKET, FEEDBACK, URL |
| `targetId` | hedefin kimliği (URL için adres) |
| `target`, `value` | `targetType`/`targetId` ile aynı (eski adlar, korunur) |
| `conversationId`, `eventId`, `communityId`, `newsId`, `postId`, `ticketId` | türe göre ilgili kimlik |
| `count` | gruplanmış bildirimde birleşen adet (>1 ise) |

Toplam boyut 4096 bayt ile sınırlıdır.

## Platform ayarları

- Android kanal kimlikleri (uygulama bu kanalları oluşturmalıdır): `chat` (MESSAGE), `event` (EVENT),
  `announcement` (NEWS, ANNOUNCEMENT, COMMUNITY, SYSTEM). Mesaj ve sistem: yüksek öncelik.
- iOS: `apns-push-type: alert`, `apns-priority` (mesaj/sistem 10, diğerleri 5), `sound: default`,
  `mutable-content: 1`, `category` = `type`, `thread-id` (`conv-<id>`, `community-<id>`, `event-<id>` ya da tür adı),
  `apns-collapse-id` (gruplanan bildirimlerde, en çok 64 bayt).
- Rozet (`badge`): tek kullanıcıya giden bildirimlerde okunmamış bildirim sayısı. Toplu gönderimlerde rozet değişmez;
  uygulama açılınca `GET /api/notifications/unread-count` ile günceller.

## Dayanıklılık

- Gönderim istek thread'ini bloklamaz (arka plan kuyruğu, 500'lük parçalar).
- Geçici hatalarda (UNAVAILABLE, INTERNAL, QUOTA_EXCEEDED, ağ) 5 sn, 20 sn, 80 sn üstel geri çekilmeyle en çok 3 yeniden deneme.
- UNREGISTERED / gecersiz token yanıtında cihaz kaydı silinir.
- Firebase kimliği yoksa uygulama ici bildirim kutusu yazılır, push atlanır.
- Sessiz saatler ve tercihler aynen geçerlidir. Süreç yeniden başlarsa kuyruktaki (henüz gönderilmemiş) push kaybolabilir;
  uygulama içi kutu kalıcıdır.

## Sağlık

`GET /actuator/health` içinde `fcm` bileşeni: `{ "status": "UP", "details": { "enabled": false, "delivered": 0, "failures": 0, "retries": 0, "lastFailureAt": "…" } }`.
FCM kapalı olmak sağlığı bozmaz.

## Ayarlar

- `FCM_CREDENTIALS_JSON` (ham JSON ya da base64) veya `FCM_CREDENTIALS_FILE` (dosya yolu); ayrıntı: `docs/PUSH_SETUP.md`.
- `app.push.device-ttl-days` (varsayılan 60), `app.push.device-cleanup-cron` (varsayılan `0 0 4 * * *`); tanımlamak şart değildir.

## Migration

`V120__push_device_meta.sql`: `device.app_version`, `device.locale`, `device.last_seen_at` + `idx_push_device_last_seen`.


## Kalıcı push kuyruğu (V350, `push_outbox`)

Sorun: `PushDispatcher` bellek kuyruğu (`LinkedBlockingQueue(2000)`) süreç yeniden başlayınca bekleyen/yeniden denenecek push'ları kaybediyordu.

**Yol:** `NotificationService` / kampanyalar (`sendBulk`) → `PushDispatcher.dispatch(tokens, message)` → (kalıcı kuyruk açıksa) `PushOutboxService.enqueueTokens` → `push_outbox` (cihaz başına bir satır) → `PushOutboxWorker` → `FcmSender.deliver`. Eski doğrudan çağrı kalmadı; `PushDispatcher` yalnız outbox kapalı (`app.push.outbox.enabled=false`), kuyruk yazımı hata verir ya da testlerdeki dört argümanlı kurucu kullanıldığında eski bellek yoluna düşer (`PushDeliveryTest` davranışı korunur). Kullanıcı tercihi, alt tür, sessiz saat ve kategori mantığı değişmedi (kuyruğa yazmadan önce `NotificationService`/`DeviceRepository` sorgularında uygulanır).

- **Tablo:** `id, user_id, device_id, fcm_token_hash (SHA-256; ham token YOK), payload_json (PushMessage), priority (1 = yüksek), status PENDING|SENDING|SENT|FAILED|DEAD, attempts, next_attempt_at, lease_until, created_at, sent_at, last_error (maskeli: yalnız hata türü), dedupe_key`. Token gönderim anında `device_id` ile çözülür; cihaz silindiyse kayıt DEAD olur.
- **İşleyici:** `claimDue` = `FOR UPDATE SKIP LOCKED` + 5 dk kira (`SENDING`, `lease_until`); kirası dolmuş `SENDING` kayıtlar yeniden alınır; açılışta (`ApplicationReadyEvent`) `recoverStale` bunları PENDING'e geri alır. Yeni kayıtta commit sonrası hemen uyanır, ayrıca `app.push.outbox.poll-ms` (5 sn) ile yoklar. Aynı yüke sahip kayıtlar 500'lük gruplar halinde tek FCM çağrısıyla gider.
- **Geri çekilme:** 30 sn, 2 dk, 10 dk, 1 sa, 6 sa; `app.push.outbox.max-attempts` (6) sonra DEAD. UNREGISTERED/geçersiz token → cihaz kaydı silinir + DEAD (yeniden denenmez). `app.push.outbox.max-age-hours` (24) saatten eski mesaj gönderilmez (DEAD, "süresi doldu").
- **FCM kimliği yokken:** `app.push.outbox.hold-when-disabled=false` (varsayılan) → kayıt yazılmaz, `push.outbox.skipped` sayacı artar (birikmez); `true` → kayıtlar PENDING'de bekler, kimlik gelince gider.
- **Temizlik:** her gece 03:20 (`SchedulerLock "push-outbox-cleanup"`): SENT 7 gün, DEAD 30 gün, takılmış PENDING/FAILED/SENDING 30 gün sonra silinir. Hesap silinince kullanıcının kayıtları silinir (`AccountDataPurger`).
- **Metrikler (Micrometer):** `push.outbox.enqueued|sent|failed|dead|skipped` sayaçları, `push.outbox.pending` ölçeri (PENDING + FAILED). **Sağlık:** `pushQueue`. **Yönetici:** `GET /api/admin/push/outbox/stats`, `POST /api/admin/push/outbox/retry-dead` (bkz. `docs/ADMIN_API.md`).
- **Ayarlar:** `app.push.outbox.enabled|poll-ms|batch-size|max-attempts|max-age-hours|hold-when-disabled|cleanup-cron` (env: `PUSH_OUTBOX_*`).
- **Migration:** `V350__push_outbox.sql` (`pso350_due`, `pso350_lease`, `pso350_status_created`, `pso350_user`, `pso350_dedupe`).
- **Not:** `FcmHealthIndicator` artık `enabled` için gerçek FCM kimliğine bakar (`PushDispatcher.fcmEnabled()`); `PushDispatcher.enabled()` "gönderim kabul ediliyor mu" (hold modu dahil) anlamına gelir. Anket bildirim yükünde `pollId` → `target=POLL` eşlemesi `PushPayload`'a eklendi.

## Akıllı bildirim: sohbetteyken bastırma, yığılma önleme (V440 aralığı kullanılmadı; migration yok)

**Karar tablosu (yeni sohbet mesajı, alıcı başına):** gönderen kendisi, sessize alınmış (`muted`/`mutedForever`), yapışkan arşivde (`archiveSticky`), engel ilişkisi olan, askıdaki/silinmiş hesap -> bildirim YOK. Alıcı çevrimiçi (WS bağlı) -> yalnız canlı WS olayı. Alıcı o sohbeti görüntülüyor (`viewing:<uid>` = sohbet kimliği, TTL 45 sn) -> hiçbir şey (kutu satırı da yok). Uygulaması ön planda (`fg:<uid>`, TTL 90 sn) ama WS düşmüş -> yalnız uygulama içi kutu satırı, push yok. Aksi halde push: sohbet başına 20 sn pencere (`app.push.message-window-seconds`) içinde ikinci push yok (kutu satırı birleşir, sayaç artar); pencere sonrası ilk push "N yeni mesaj" (alıcı dilinde `notif.message.many`); kullanıcı başına dakikada en çok 10 push (`app.push.max-per-minute`, tüm türler; SYSTEM hariç). Redis erişilemezse hepsi "açık" (push gider).

**Uçlar (JWT, hız sınırlı):**
- `PUT /api/conversations/{id}/viewing` -> 204. Sohbet açıkken 30 sn'de bir. Üye değilse 404. Ön planı da ima eder.
- `DELETE /api/conversations/{id}/viewing` -> 204 (idempotent; yalnız kayıtlı sohbet aynıysa siler). Sohbetten çıkınca/arka plana geçince.
- `PUT /api/devices/{fcmToken}/state` gövde `{"foreground":true|false}` -> 204. Token kullanıcıya ait değilse 404. (`PUT /api/devices/state` de gövdeyle aynı işi görür.) `false` hem `fg` hem `viewing` anahtarını siler. Ön plandayken 45 sn'de bir yenilenmeli. Durum kullanıcı bazlıdır (çok cihazda herhangi biri ön plandaysa push bastırılır; "yalnız uygulama içi kutu" yolu).

**Push yükü (`data`) ek alanları:** `collapseKey` (örn. `conv:5`, `follow:7`, `postlike:3:<pencere>`), `threadId` (`conv:5`, `community-3`, `event-9`, `post-4`, yoksa tür adı), `channelId`, mevcut `type/subtype/targetType/targetId/count`. FCM: `collapse_key` + Android `tag` = collapseKey, APNs `thread-id` = threadId ve `apns-collapse-id` = collapseKey (<=64 bayt). (Not: `threadId` önceki `conv-<id>` yerine `conv:<id>` oldu.) Ek `conversationType` (`DIRECT|GROUP`) mesaj bildirim verisindedir; alt tür `MESSAGE_DIRECT`/`MESSAGE_GROUP` artık bunlardan atanır (alt tür tercihleri mesajlarda ilk kez gerçekten uygulanır).

**Android kanalları (istemci oluşturur):** `chat` YÜKSEK (mesaj; push önceliği yüksek), `event` YÜKSEK, `announcement` VARSAYILAN (haber, duyuru, kulüp, sistem/moderasyon, ticket yanıtı), `poll` VARSAYILAN (yükte `pollId` varsa), `social` DÜŞÜK (beğeni, yorum, yanıt, etiket, takip). Yüksek öncelikli push: MESSAGE, SYSTEM, EVENT_ADMISSION alt türü.

**Birleştirme ve tekrar:** beğeni: gönderi başına 10 dk'lık pencere, ilk beğeni push'lanır, devamı yalnız kutuda ("X ve N kişi"); takip: aynı kişi için ömür boyu tek bildirim (bırak-al spam yok); kulüp gönderisi: `commpost:<id>` anahtarıyla okunmamışlar tek satır, alt tür `COMMUNITY_POST` (artık tercihle kapatılabilir). Kutu görünümü (`GET /api/notifications`) yeni alan: `groupKey`; `count` zaten vardı.

**Sessiz saat ve tercihler:** ana bayrak + alt tür her `NotificationService.send*` yolunda uygulanır; sessiz saatte kutu yazılır, push gitmez. `SYSTEM` (hesap güvenliği, moderasyon, destek yanıtı) sessiz saati ve ana bayrakları AŞAR ve askıdaki hesaba da gider; diğer türler askıdaki/silinmiş hesaba gitmez (`RecipientGuard`). Toplu yollar (`broadcast`, `sendBulk`, kampanya) sessiz saati SQL'de uygular. Önizleme kararı: push gövdesi varsayılan "Yeni mesaj" + gönderen (grupta "Grup - Gönderen") adıdır; kutu tablosuna metin ASLA yazılmaz; mesaj metni önizlemesi yalnız `app.push.message-preview=true` iken (100 karakter) push gövdesine girer (şifreli saklamayı bozmamak için varsayılan kapalı).

**FCM doğrulama (yönetici):** `GET /api/admin/push/fcm/status` (ağ çağrısı yok: `enabled`, `projectId`), `POST /api/admin/push/fcm/validate` (Firebase `validateOnly` konu mesajı; hiçbir cihaza gitmez; `validated`, `error` yalnız kod; dakikada 5). Açılışta etkinse log: `FCM etkin: Firebase proje kimligi=<id>`; sağlık `fcm` detayında `projectId`. Anahtar hiçbir yerde yazılmaz.

## P14: Yönetici push altyapısı (V760; `notification.admin`)

Yönetici panelinde (`/admin/push/ops`) FCM durumu, kuyruk, cihaz özeti, bildirim kutusu istatistikleri ve kampanya hata grupları. **Hiçbir uç push yükünü (başlık/gövde/veri), ham FCM token'ını ya da tam kullanıcı kimliğini döndürmez**; hedef maskelidir (`targetRef` = token özetinin ilk 8 hanesi + `...`, `userRef` = `1***5`). Hepsi `/api/admin/**` (yalnız ADMIN); yazmalar denetlenir (`AuditContext.target("PUSH_OUTBOX", id)`), hız sınırı ve sebep kuralı `AdminGuardInterceptor` / `AdminGuardPolicy`'de (iptal ve toplu işlem sebep ister, saatlik yıkıcı sınır).

**Uçlar** (mevcut `fcm/status`, `fcm/validate`, `outbox/stats`, `outbox/retry-dead` değişmedi):
- `GET /api/admin/push/outbox?status=&type=&campaignId=&from=&to=&page=&size=` (sayfa tabanlı, en çok 100; `from`/`to` `YYYY-MM-DD` İstanbul günü, ikisi dahil). Satır: `id, status, type, campaignId, targetRef, userRef, attempts, errorCode, nextAttemptAt, createdAt, sentAt`. Geçersiz süzgeç 400 `PUSHADMIN_FILTER_INVALID`.
- `GET /api/admin/push/outbox/{id}`: + `maxAttempts, lastError, priority, leaseUntil, canRetry, canCancel` (yük YOK). 404 `PUSHADMIN_OUTBOX_NOT_FOUND`.
- `POST /api/admin/push/outbox/{id}/retry`: `DEAD|FAILED|CANCELLED` -> `PENDING` (deneme sayacı sıfırlanır, `createdAt` yenilenir: 24 saatlik gönderim ömrü yeniden başlar, aksi halde eski kayıt hemen "süresi doldu" olurdu). Diğer durumlar 409 `PUSHADMIN_STATE_CONFLICT` (gönderilmiş mesaj yeniden gönderilmez).
- `POST /api/admin/push/outbox/{id}/cancel` (sebep zorunlu): `PENDING|FAILED` -> `CANCELLED` (`errorCode=ADMIN_CANCELLED`); `SENDING`/`SENT`/`DEAD` 409. Durum geçişleri koşullu (atomik) UPDATE'tir: işleyiciyle yarışta kayıt bozulmaz.
- `POST /api/admin/push/outbox/bulk` `{action: RETRY|CANCEL, ids (1..200), reason}` (sebep zorunlu): kısmi başarı, `{requested, succeeded, failed:[{id, code: NOT_FOUND|INVALID_STATE}]}`; tekrarlı kimlikler tek sayılır; 1..200 dışı 400 `PUSHADMIN_BULK_INVALID`.
- `GET /api/admin/push/devices/summary`: `{totalTokens, usersWithDevice, byPlatform{android,ios,web,other}, byAppVersion (ilk 10; sürümü olmayan "unknown"), activeLast7d, staleOver30d}` (yalnız toplu).
- `GET /api/admin/push/campaigns/{id}/failures`: `{campaignId, linked, totals{durum->sayı}, groups[{errorCode, status DEAD|FAILED, count, lastAt}] (en çok 200, sayıya göre azalan), truncated}`; alıcı kimliği yok. Olmayan kampanya 404 `CAMPAIGN_NOT_FOUND`. `linked=false`: bağlı kuyruk kaydı yok (V760 öncesi kampanyalar bağlanmamıştır; SENT 7, DEAD 30 gün saklanır).
- `GET /api/admin/notifications/stats?days=14` (1..30): gün bazında (İstanbul) `series[{date, created, read}]`, `readRate` (0..1 ya da null), `byType`, `totalRows`, `unreadRows`. Toplu; kullanıcı yok. Okunmuş bildirimler saklama süresi sonunda silindiğinden eski günlerde okunma oranı düşük görünebilir.

**Şema (V760):** `push_outbox.campaign_id` (yükteki `data.campaignId`'den), `msg_type` (`PushMessage.category`), `error_code` (FCM hata kodu: `UNREGISTERED`, `INVALID_ARGUMENT`, `QUOTA_EXCEEDED`, `UNAVAILABLE`, `INTERNAL`, `SENDER_ID_MISMATCH`...; dahili: `EXPIRED`, `DEVICE_MISSING`, `PAYLOAD_UNREADABLE`, `SEND_ERROR`, `ADMIN_CANCELLED`); indeksler `p14_pso_campaign`, `p14_pso_status_id`, `p14_notif_created`. Yeni durum `CANCELLED` (30 gün sonra gece temizliğinde silinir). `SendResult` üçüncü bileşen `codes` (token -> FCM hata kodu) taşır; iki argümanlı kurucu korunur. Kalıcı hata kodu (`PERMANENT`: örn. kota dışı reddedilen mesaj) davranışı değişmedi (kayıt SENT sayılır; yalnız geçersiz token ve geçici hatalar kodlanır).

**Yeni hata kodları** (`i18n/pushadmin*.properties`, tr/en/ar): `PUSHADMIN_OUTBOX_NOT_FOUND`, `PUSHADMIN_STATE_CONFLICT`, `PUSHADMIN_BULK_INVALID`, `PUSHADMIN_FILTER_INVALID`.

**Kapsam dışı / bilinen sınırlar:** PushGate bastırma sayaçları Redis'te tutulur (kalıcı değil), bu yüzden bildirim istatistiklerinde "bastırılan" alanı yoktur. Kampanya alıcı bazında hata kaydı tutulmadığından hata listesi outbox hata koduna göre toplulaştırılır. Duman: `scripts/smoke-admin-pushops.sh`.

**FCM1 (dogrulama tanisi):** `POST /api/admin/push/fcm/validate` cevabi (`FcmCheck`) yeni `detail` alani tasir: basarisizsa maskeli tani metni (hata sinifi, `errorCode`, `fcmCode`, `http`, kisa `msg` <= 200 karakter, neden zinciri sinif adlari); jeton/anahtar/e-posta maskelenir (`FcmErrorDetail`), ayni metin `log.warn("FCM dogrulama basarisiz: ...")` olarak yazilir. `projectId` servis hesabi JSON `project_id` alanindan okunur (`FirebaseOptions.setProjectId`). `ProdSettingsValidator` FCM uyarisi artik `FCM_CREDENTIALS_JSON`/`app.fcm.credentials-json` kimligini de sayar.

## B1: anket ve akademik duyuru tercihleri (V880)

- **Şema:** `notification_pref.polls` ve `notification_pref.academic_announcements` (BOOLEAN NOT NULL DEFAULT TRUE; mevcut kullanıcılar açık). Migration yalnız ekleme.
- **API:** `PrefsView`/`PrefsUpdate` yeni `polls`, `academicAnnouncements` (güncellemede null = değişmez; 7 alanlı eski kurucu korunur). `NotificationSubtype` yeni `POLL` ve `ACADEMIC_ANNOUNCEMENT` (`flagBacked()`): alt tur satırı tutulmaz, değer sütundan okunur/yazılır; `PrefsView.subtypes` bunları yansıtır.
- **Gönderim:** koşul **ana tür bayrağı VE kendi bayrağı**dır (tekil: `doSend`; toplu: `CASE` ifadesinde `polls` = `p.polls AND p.announcements`, `academic_announcements` = `p.academic_announcements AND p.announcements`; kulüp anketi tekil yolda `communities` + `polls`). Bu sayede sütunların DEFAULT TRUE olması ana bayrağı önceden kapatmış kullanıcıların davranışını değiştirmez, V880'de geri doldurma (UPDATE) gerekmez. Toplu yollar (`broadcastLocalized`, `sendBulk`) yeni `prefColumn` parametresi alır; `insertForAll/insertForLang/tokensForBroadcast*/allowing` sorgularının `CASE`i bu iki sütunu tanır. Test: `PollAcademicPrefsTest`.
- **Sohbet push avatarı:** `sendNewMessage(..., pushExtra)`: `senderAvatarUrl` yalnız push yüküne eklenir, `notification.data` JSON'una yazılmaz. `AvatarVisibility.viewersAmong` SHARED_CONTEXT için tek toplu sorgu (`SharedContextRepository.viewersSharingWith`) kullanır. `PollNotifier` (genel anket `"polls"`, tekil/kulüp anketi `POLL` alt türü) ve `AnnouncementNotifier` (`"academic_announcements"`) buna geçti. Bildirim `type`ı değişmedi (`ANNOUNCEMENT`/`COMMUNITY`), mobil gösterimi etkilenmez.

## P1: "bildirim gelmiyor / anlık gelmiyor" düzeltmeleri + bildirim tasarımı sunucu tarafı (V896)

**Kök nedenler (kod okunarak):**
1. Mesaj push'u, alıcı "çevrimiçi" (WS bağlı) ya da `fg:` (90 sn) / `viewing:` (45 sn) anahtarı varsa gönderilmiyordu; arka plana alınan/öldürülen uygulamada bu bayat anahtarlar ve donmuş soket yüzünden 30-90 sn mesaj push'suz kalıyordu.
2. Sohbet başına 20 sn pencere (`message-window-seconds`) içindeki 2. mesaja push yoktu; tüm türlerle paylaşılan dakikada 10 push sınırı sohbet mesajlarını sessizce düşürüyordu.
3. FCM `collapse_key` her sohbet için `conv:<id>` gönderiliyordu: FCM çevrimdışı cihazda en çok 4 farklı anahtara izin verir, fazlası tanımsızdır (telefon kapalıyken biriken mesajlar düşebilir).
4. Kalıcı FCM hatası (`THIRD_PARTY_AUTH_ERROR` = APNs anahtarı yok/yanlış, `INVALID_ARGUMENT`) yalnız log'lanıp kayıt "SENT" sayılıyordu: iOS kullanıcıları için push hiç gitmese bile panelde başarılı görünürdü.
5. Sohbet okununca bildirim satırı hiç okunmuyordu: sayaç ömür boyu büyüyor, push gövdesi sürekli "57 yeni mesaj" oluyor, rozet şişiyordu.
6. Çıkışta `DELETE /api/devices/{token}` erişim jetonu bitmişse 401 verip sessizce başarısız olabiliyordu; `POST /api/devices` ile aynı saatte-30 sayacını paylaşıyordu (429 = kayıt düşer = push yok).
7. Push yükünde TTL yoktu.

**Mesaj push karar tablosu (alıcı başına, `MessageService.notifyOffline`):**
- gönderen, sessize alınmış (`muted`), yapışkan arşiv, engel ilişkisi, askıdaki/silinmiş hesap -> bildirim yok (değişmedi);
- sohbeti görüntülüyor (`viewing:`) **VE** canlı WS bağlantısı var -> hiçbir şey (mesaj zaten ekranda). `viewing:` tek başına yetmez (uygulama sohbet açıkken öldürülürse 45 sn bayat kalır);
- diğer **her** durumda push GİDER: çevrimiçi/ön plan/arka plan fark etmez. Ön plandaki istemci push'u kendisi bastırır ya da gösterir (aşağıda "Mobil için gerekenler"). Eski davranışa dönmek için `app.push.message-skip-foreground=true` (yalnız ön planda + WS bağlıyken push atlanır, kutu satırı yazılır). Bayat `fg:` bayrağına WS yokken asla güvenilmez.
- `app.push.message-window-seconds` varsayılanı **0** (pencere yok; her mesaj kendi push'unu alır, Android `tag` / iOS `apns-collapse-id` aynı sohbetin bildirimini cihazda tek satıra indirir). Kutu satırı sayacı ve "N yeni mesaj" gövdesi korunur. Mesajlara ayrı dakikalık sınır: `app.push.max-messages-per-minute` (60); genel `max-per-minute` (10) sayacını artık tüketmez.
- Sohbet sonuna kadar okununca (`POST /api/conversations/{id}/read` imleci son mesaja ulaşınca) o sohbetin `conv:<id>` kutu satırı okundu olur; sonraki mesaj yeni satır (sayaç 1, gövde "Yeni mesaj") açar.

**FCM yükü (`FirebaseFcmSender`):**
- Android: `notification` bloğu + `data`; `priority=HIGH` (mesaj, SYSTEM, EVENT_ADMISSION), notification `priority=HIGH`, `channel_id`, `tag` (= `collapseKey` ya da `threadId`), `notification_count` (= rozet), **`ttl`**; FCM `collapse_key` **artık gönderilmez** (madde 3). Yalnız `data` mesajı gönderilmez: `notification` bloğu sayesinde uygulama öldürülmüşken de Google Play Hizmetleri bildirimi kendisi gösterir.
- APNs: `apns-push-type=alert`, `apns-priority` 10/5, **`apns-expiration`** (= şimdi + TTL), `apns-collapse-id` (<=64 bayt), `thread-id`, `category`, `mutable-content=1`, `sound=default`, rozet; sosyal bildirimlerde (beğeni/takip) `interruption-level=passive`.
- TTL: mesaj/SYSTEM 7 gün, haber/duyuru/kulüp 3 gün, etkinlik ve sosyal 1 gün, etkinlik hatırlatması 6 saat.
- Yük 4096 bayt sınırı `PushPayload.fit` ile korunur (sözleşme anahtarları kırpılmaz).
- Kalıcı hata (THIRD_PARTY_AUTH_ERROR, INVALID_ARGUMENT yük hatası, PERMISSION_DENIED...) artık `SendResult.permanent`: kuyruk kaydı **DEAD + `error_code`** olur (cihaz kaydı SİLİNMEZ), sağlık `pushQueue.details.errorCodes` ve yönetici hata listesinde görünür; düzeltme (ör. APNs anahtarı yüklendi) sonrası `POST /api/admin/push/outbox/retry-dead` ile yeniden denenir. (Yukarıdaki "kalıcı hata SENT sayılır" notu geçersizdir.)
- Kuyruk işleyicisi farklı yüklü grupları (alıcı başına farklı sohbet bildirimi) 4 iş parçacığıyla eşzamanlı gönderir (500 üyeli grupta ardışık gönderim dakikalar sürerdi).

**Yeni push `data` anahtarları (hepsi isteğe bağlı, eskiler aynı):**

| Anahtar | Açıklama |
|---|---|
| `tag` | Android bildirim etiketi (= `collapseKey`, yoksa `threadId`). Yerel bildirim kuran istemci aynı etiketi kullanmalıdır |
| `badge` | okunmamış bildirim sayısı (string; tek kullanıcıya giden bildirimlerde) |
| `senderName` | (MESSAGE) gönderenin görünen adı |
| `conversationTitle` | (MESSAGE, grup/oda) grup adı; başlık "Grup - Gönderen" biçimindedir |
| `senderAvatarUrl` | (MESSAGE) mevcut: gizlilik izin veriyorsa; yalnız push yükünde, kutu `data`'sında yok |
| `messageId`, `conversationType` | mevcut; ön plan tekilleştirmesi için `messageId` kullanın |

Android kanal kimlikleri **değişmedi** (`chat`, `event`, `announcement`, `poll`, `social`; tek yerde `PushMessages.CHANNEL_*`). Daha ince kanal ayrımı (ör. `academic`, `community`, `system`) için istemci yeni kanalları önce yayınlamalıdır; eski sürümde olmayan kanal kimliği Android'de "Diğer" varsayılan kanalına düşer (başlık üstü bildirim kaybolur). Bu yüzden sunucu şimdilik yalnız yukarıdaki beş kimliği gönderir.

**Mesaj önizlemesi (KVKK):** varsayılan DEĞİŞMEDİ: push gövdesi sabit "Yeni mesaj" + gönderen adı; kutu tablosuna metin asla yazılmaz. Yeni: kullanıcı tercihi `messagePreview` (`GET/PUT /api/notifications/preferences`, `notification_pref.message_preview`, **V896**, varsayılan false). Açıksa o kullanıcının push gövdesine mesajın ilk 100 karakteri girer (metin Google/Apple push sunucularından geçer; bu yüzden yalnız kullanıcı isterse). `app.push.message-preview=true` (global) eski davranıştır ve tercihi aşar; `app.push.message-preview-optin=false` tercih yolunu kapatır. Görsel-yalnız mesaj "📷".

**Cihaz kaydı / çıkış:**
- `POST /api/devices` sınırı saatte 120 (eski 30; 429 kaydı düşürüp push'suz bırakabilirdi), `DELETE` ayrı sayaç (saatte 60).
- `POST /api/auth/logout` gövdesine isteğe bağlı **`fcmToken`** eklendi: `{"refreshToken":"…","fcmToken":"…"}`. Verilirse sunucu o cihazın push kaydını (yalnız o kullanıcıya aitse) siler; erişim jetonu süresi dolmuş olsa bile çıkış yapan kullanıcının bildirimi telefonda kalmaz. Eski istemci (yalnız `refreshToken`) aynen çalışır.
- Yeni mobil girişte kullanıcının TÜM cihaz kayıtları silinir (tek cihaz kuralı, mevcut davranış): giriş sonrası istemci token'ı **mutlaka yeniden kaydetmelidir**, "daha önce kaydettim" önbelleği kullanmamalıdır.
- `QuietSql` saat dilimi boşsa `Europe/Istanbul` varsayar (NULL saat dilimi toplu sorguda satırı sessizce eliyordu).

**Yönetici teşhisi:** `GET /api/admin/users/{id}/push-devices` her cihaz için son kuyruk kaydını gösterir: `lastPushStatus` (SENT/DEAD/FAILED/PENDING/...), `lastPushErrorCode` (UNREGISTERED, THIRD_PARTY_AUTH_ERROR...), `lastPushAt`; yük/token yok (SENT 7, DEAD 30 gün saklanır). "Cihaz kaydı hiç yok" = istemci kaydolmuyor; "DEAD + UNREGISTERED" = token geçersizleşmiş; "DEAD + THIRD_PARTY_AUTH_ERROR" = APNs anahtarı sorunu. Süreç başından beri hata kodu sayaçları: `GET /actuator/health` içinde `pushQueue.details.errorCodes`.

**Mobil için gerekenler (P2'ye):**
1. Her açılışta, her `onTokenRefresh`'te **ve her girişten sonra** `POST /api/devices` çağırın (başarısızsa sonra yeniden deneyin; 204 dışını yutmayın). Giriş sunucuda eski kayıtları siler.
2. Çıkışta `POST /api/auth/logout` gövdesine `fcmToken` ekleyin (ve eskisi gibi `DELETE /api/devices/{token}` deneyin).
3. Ön plandayken gelen MESSAGE push'u (`onMessage`): `conversationId` açık sohbetse yok sayın; değilse mesaj kimliğiyle (`data.messageId`) WS'ten gelenle tekilleştirip uygulama içi şerit gösterin. Sunucu artık WS bağlı/ön planda olanlara da push gönderir (güvenlik ağı).
4. Android kanallarını (`chat`, `event`, `announcement`, `poll`, `social`) uygulama açılışında oluşturun (kanal yoksa bildirim "Diğer" kanalına düşer, başlık üstü olmaz) ve `default_notification_channel_id` meta-verisini `announcement` yapın. Android 13+ `POST_NOTIFICATIONS` izni.
5. Yerel bildirim kurarsanız `tag` olarak `data.tag` kullanın; sohbet dokunuşu `conversationId` ile açılır. Rozet için `data.badge` okunabilir.
6. Bildirim ayarlarına "Mesaj önizlemesi" anahtarı: `PUT /api/notifications/preferences {"messagePreview":true|false}` (varsayılan kapalı; açıklama: "mesaj metni kilit ekranında görünür, Google/Apple sunucularından geçer").
7. Pil/otomatik başlatma: Xiaomi/Oppo/Huawei/Vivo'da kaydırarak kapatma uygulamayı "zorla durdurur" ve FCM hiç teslim edilmez (sunucudan çözülemez); ilk açılışta üreticiye özel "otomatik başlat / pil kısıtlamasız" yönlendirmesi önerilir.
8. iOS: `UIBackgroundModes=remote-notification` ve APNs anahtarı Firebase'de olmalı (aksi halde kuyrukta `THIRD_PARTY_AUTH_ERROR` birikir).
