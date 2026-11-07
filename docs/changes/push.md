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

**Sessiz saat ve tercihler:** ana bayrak + alt tür her `NotificationService.send*` yolunda uygulanır; sessiz saatte kutu yazılır, push gitmez. `SYSTEM` (hesap güvenliği, moderasyon, destek yanıtı) sessiz saati ve ana bayrakları AŞAR ve askıdaki hesaba da gider; diğer türler askıdaki/silinmiş hesaba gitmez (`RecipientGuard`). Toplu yollar (`broadcast`, `sendBulk`, kampanya) sessiz saati SQL'de uygular. Önizleme kararı (V1252): push gövdesi her zaman mesaj metninin ilk 100 karakteridir (tercih kaldırıldı); kutu tablosuna metin ASLA yazılmaz.

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

**Mesaj önizlemesi (V1252, KALDIRILDI):** kullanıcı tercihi `messagePreview` (`notification_pref.message_preview`, V896) ve `app.push.message-preview` / `message-preview-optin` ayarları silindi; push gövdesi mesaj metninin ilk 100 karakteridir (yalnız görsel mesajda simge, birleşen mesajda "N yeni mesaj"). Kutu tablosuna metin yine ASLA yazılmaz. Android `chat` kanalı `visibility=PUBLIC`; iOS `mutable-content` zaten açık. Hukuki metinlerdeki "varsayılan olarak mesaj metni gösterilmez" ifadesi (V290/V370/V480/V620/V820 sözleşme metinleri, `docs/legal/*`) GÜNCELLENMEDİ: sürümlü hukuki metin kararı kullanıcıya aittir.

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
6. (Kaldırıldı, V1252) "Mesaj önizlemesi" anahtarı artık yok; sunucu önizlemeyi her zaman gönderir.
7. Pil/otomatik başlatma: Xiaomi/Oppo/Huawei/Vivo'da kaydırarak kapatma uygulamayı "zorla durdurur" ve FCM hiç teslim edilmez (sunucudan çözülemez); ilk açılışta üreticiye özel "otomatik başlat / pil kısıtlamasız" yönlendirmesi önerilir.
8. iOS: `UIBackgroundModes=remote-notification` ve APNs anahtarı Firebase'de olmalı (aksi halde kuyrukta `THIRD_PARTY_AUTH_ERROR` birikir).

## W1-I: mobil yerel güvenlik ve native katman (T-098..T-101)

- **Yerel hatırlatma yükü güvenilmez kaynaktır (T-098).** `MainActivity` launcher olduğu için dışa açıktır; `bu_reminder_payload` ekstrasını artık yalnız `ReminderReceiver`'ın HMAC-SHA256 ile imzaladığı (`bu_reminder_sig`, kurulum başına rastgele anahtar, `bu_reminder_auth` tercih dosyası) yük geçer, imzasız/bozuk ekstra yok sayılır. İmzalı olsa bile Kotlin `toMap` ve Dart `sanitizeLocalReminderPayload` yalnız hedef anahtarlarını (`targetType`, `targetId`, `conversationId`, `eventId`, `postId`, `communityId`, `newsId`, `ticketId`, `pollId`, `userId`, `announcementId`; değer <= 200 karakter) geçirir. `type`/`event` (ör. `CONVERSATION_CLOSED`) yalnız sunucudan gelen FCM yükünde etkilidir: `PushRouter.open(data, localReminder: true)` sohbet durumunu işlemez. Ölü `session_replaced` push dalı kaldırıldı (sunucu böyle bir push göndermez; oturum iptali 401 `SESSION_REPLACED` / WS olayıyla gelir).
- **KVKK dışa aktarma panoya yazılmaz (T-099).** `GET /users/me/export` yanıtı önbellek altındaki `export/` dizinine JSON dosyası olarak yazılır ve sistem paylaşım sayfasıyla verilir (`bu_kampus/share` kanalı: Android `FileProvider` `ExportFileProvider`, yalnız `cache/export/`; iOS `UIActivityViewController`). Dosya, kullanıcı uygulamaya döndüğünde (paused -> resumed), sayfa kapanınca, sonraki sayfa açılışında ve en geç `kExportFileTtl` (10 dk) sonra silinir. `kExportClipboardTtl` kaldırıldı.
- **Android kanal adları (T-100).** Varsayılan kanal adları/açıklamaları `res/values{,-en,-ar}/strings.xml`'den okunur (doğru Türkçe diyakritik; ARB ile aynı metin); uygulama açılmadan gelen ilk push cihaz diliyle kanal kurar, açılışta Dart seçilen dile günceller.
- **BootReceiver `exported=false` (T-101).** Sistem yayınları (BOOT_COMPLETED vb.) yine iletilir.

## Sınav hatırlatması (2 sa önce) - EXAM-PUSH

Kullanıcının **kendi girdiği** sınavlar (`tt_exam`) için sınavdan 2 saat önce sunucudan gerçek push (FCM; uygulama kapalıyken de) + uygulama içi bildirim kutusu kaydı. Resmi sınav programı (`exam_schedule`) bu hatırlatmayı üretmez.

- **Görev:** `academic/ExamReminderJob` (`@Scheduled`, `app.exam-reminder.poll-ms` varsayılan 60000, `app.exam-reminder.initial-delay-ms` 45000; `SchedulerLock` adı `exam-reminder`, TTL 2 dk; Redis erişilemezse tur atlanır, sonraki dakika denenir; `JobMonitor` otomatik izler).
- **Pencere:** `starts_at` in `[şimdi + 30 dk, şimdi + 2 sa]`. Üst sınır asıl hedeftir (sınav 1 sa 59 dk kala olanlar dahil, 2 sa 01 dk olanlar dışarıda). Alt sınır kaçırma güvenliğidir: sunucu/görev kapalı kaldıysa sınava >= 30 dk varken geç de olsa gönderilir; 29 dk ve altı ile başlamış/geçmiş sınavlar ASLA gönderilmez. Bir turda en çok 10 x 500 sınav (sorgular `LIMIT 500`), kalanı sonraki dakikaya kalır.
- **Tekrar önleme:** `tt_exam.reminded_starts_at` (**V1010**, `exr9_exam_starts_idx` indeksi). Gönderimden önce kosullu `UPDATE ... SET reminded_starts_at = starts_at WHERE ... (reminded_starts_at IS NULL OR reminded_starts_at <> starts_at)` ile sahiplenilir (çok örnekte de tek gönderim). Gönderim istisna atarsa iz geri alınır. Sınav saati düzenlenirse (`starts_at` değişir) iz ayrışır ve sınav yeniden hatırlatılabilir; yalnız not/salon düzenlemesi yeniden hatırlatmaz. Silinen sınav satırla birlikte gider. `ExamService.create/update`: sınav zaten 2 saat içinde (ya da geçmiş) girildiyse/saatine taşındıysa iz hemen işaretlenir (kullanıcı bunu bilerek girdi, anında push gelmez).
- **Tür/tercih:** `NotificationType.ANNOUNCEMENT` + yeni alt tür `NotificationSubtype.EXAM_REMINDER` (bayrak destekli: `notification_pref.academic_announcements` bayrağını "Akademik duyurular" ile PAYLAŞIR; ayrı sütun/migration yok). Gönderim koşulu = `announcements` VE `academic_announcements` açık; sessiz saat ve askıdaki hesap kuralları `NotificationService`'te aynen uygulanır. `GET /api/notifications/preferences` alt tür listesinde `EXAM_REMINDER` görünür (değeri akademik bayrağın aynası); `PUT ... {"subtypes":{"EXAM_REMINDER":false}}` akademik bayrağı kapatır (duyuruları da).
- **Push yükü:** `data.target=EXAM`, `value=<sınav id>`, `examId` (=> `targetType=EXAM`, `targetId`); `subtype=EXAM_REMINDER`; Android kanalı **`academic`** (HIGH; istemci kanalı oluşturur; eski sürümde yoksa FCM varsayılan kanalına düşer), `threadId=academic`, `tag/collapseKey=exam:<id>:<başlangıç epoch sn>`, yüksek öncelik, FCM TTL 1 sa. Mobil `push_targets.dart` `EXAM` -> Sınavlar ekranı.
- **Metin (alıcının dilinde, tr/en/ar):** `notif.academic.examReminder[.Room].title|body` (`messages*.properties`): başlık "Sınav hatırlatması", gövde "<başlık> sınavına 2 saat kaldı (SS:dd[, salon])"; saat `Europe/Istanbul`; sınav başlığı kullanıcı girdisidir, çevrilmez.
- **Mobil:** yerel `examHourBefore` (1 saat önce) hatırlatması artık kurulmaz (çift bildirim olmasın); 1 gün önceki yerel hatırlatma kalır. Ayarlar sayfasındaki satır "Sınavdan 2 saat önce (bildirim)" sunucu push'unu anlatır ve Profil > Bildirim tercihleri'ne (Akademik duyurular) götürür. Eski yerel saatlik alarmlar bir sonraki yeniden planlamada (`replaceGroup('academic')`) silinir.
- **Dağıtım notu:** V1010 uygulanmadan yeni sürüm açılmamalı (entity yok, düz SQL; kolon yoksa görev sorgusu hata verir ve tur atlanır, sınav CRUD'u `reminded_starts_at` yazdığı için create de 500 verir). Sıra: migration + backend birlikte.


## FCM gonderim hatasi: "Not in GZIP format" (2026-10-31)

Belirti: yonetici panelinde dead-letter push kayitlari `FirebaseMessagingException; errorCode=UNKNOWN; msg=Unknown error while making a remote service call: Not in GZIP format; cause=ZipException`.
Kok neden: firebase-admin 9.4.1 varsayilan aktarimi `ApacheHttp2Transport`; Spring Boot BOM'u httpclient5'i 5.6.x / httpcore5'i 5.4.x'e yukseltince (SDK 5.3.1 / 5.2.4 ile derli) gzip'li FCM yaniti iki kez acilmaya calisiliyor. Her deneme ayni hatayi verdigi icin kayitlar DEAD oldu. Yerelde birebir uretildi (gzip yanitli sahte sunucu: varsayilan aktarim ZipException, NetHttpTransport sorunsuz).
Duzeltme: `FirebaseFcmSender` aktarimi acikca `NetHttpTransport` (JDK) olarak sabitler (FirebaseOptions + OAuth belirteci istegi), baglanti 10 sn / okuma 30 sn zaman asimi. Test: `FcmTransportGzipTest`.
Dagitimdan sonra: yonetici panelinde dead-letter push kayitlarini "yeniden dene" (`/api/admin/push/outbox/*`); eski kayitlar eski hata koduyla DEAD kalmistir. Gercek FCM ile dogrulama dagitim sonrasi bir test push'uyla yapilir (yerelde FCM kimligi yok).

## W2-C: Android tag, moderasyon hedefi, kampanya yarışı, FCM kapalı (T-076..T-079)

- **Android `tag` yalnız birleşmesi istenen yerde (T-076, A13-01).** FCM/Android aynı `tag` + aynı kimlikteki bildirimi YENİSİYLE DEĞİŞTİRİR. Eskiden `tag`, `collapseKey` yoksa tür/thread adıydı (`announcement`, `news`, `system`, `poll`, `event-<id>`...): farklı duyuru/anket/destek/moderasyon bildirimleri tepside birbirini siliyor, SYSTEM sohbet bildirimi (`conversationId` taşır) sohbetin `conv:<id>` etiketiyle mesaj bildirimini siliyordu. Şimdi `FirebaseFcmSender.android()` etiketi YALNIZ `collapseKey` varsa koyar (`conv:<id>`, `follow:..`, `postlike:..`, `commpost:..`, `exam:<id>:<epoch>`); aksi halde etiket YOKTUR (Android her bildirime ayrı satır verir). `PushMessages.of` yükteki `data.tag` alanını da yalnız `collapseKey` varken yazar (eskiden thread adı). `threadId` yalnız iOS `thread-id` gruplaması içindir, değişmedi. Testler: `FirebaseFcmPayloadTest` (tersine çevrildi), `PushMessagesTagTest`. Gerçek cihaz doğrulaması H-09: kilitliyken art arda iki farklı duyuru -> tepside 2 satır.
- **Moderasyon `MESSAGE` hedefi (T-077, A13-05).** `ModerationNotifier` mesaj hedefinde `targetType=MESSAGE, targetId=<mesaj id>` GÖNDERMEZ (mobil bunu sohbet kimliği sanıp yanlış sohbeti/404'ü açıyordu). Mesajın sohbet kimliği bulunursa yük `conversationId` + `messageId` taşır; `PushPayload` hedefi `CONVERSATION/<sohbet id>` üretir (mobilde değişiklik gerekmez: `CONVERSATION` zaten sohbet açar). Mesaj bulunamazsa hedef hiç gönderilmez (bildirim listesi açılır). Diğer türler (POST, COMMUNITY, EVENT...) değişmedi. Test: `ModerationNotifierTargetTest`. Mobil savunma önerisi (W2 mobil ajanı): `_destOf('MESSAGE')` yalnız `conversationId` varken sohbet olsun, yoksa listeye düşsün.
- **Kampanya çift gönderim yarışı (T-078, A14-09).** `CampaignService.create` "say, sonra kaydet" olduğundan iki eşzamanlı aynı istek ikisi de 0 sayıp iki kampanya yazıyordu. Şimdi sayma + kayıt `CampaignCreateGuard` kilidiyle (yönetici + SHA-256(başlık, gövde, kitle türü, kitle değeri)) atomik: kilidi alamayan eşzamanlı istek beklemeden 409 `CAMPAIGN_DUPLICATE` alır; kilit kayıt commit olunca bırakılır (sıralı tekrarlar eskisi gibi `countRecentDuplicates` ile 2 dk pencerede yakalanır, iptal/başarısız kampanya engellemez). İki katman: JVM içi `ConcurrentHashMap` + Redis `SET NX PX 30s` (`app.campaign.redis-lock`, env `CAMPAIGN_REDIS_LOCK`, prod varsayılan true; Redis hatasında yalnız JVM kilidi, yönetici işlemi bloke olmaz). `validateTarget` (https kuralı) artık tekrar kontrolünden ÖNCE: geçersiz URL 409 ile maskelenmez, 400 alır. İstemci tarafı: `Idempotency-Key` başlığı `IdempotencyFilter` ile zaten desteklenir (yönetici web istemcisi gönderirse aynı anahtarlı yeniden denemeler tek sonuç alır; web W2-K/W2-* işi). Test: `CampaignAdminSendTest.concurrentIdenticalCampaignsCreateExactlyOne`, `invalidHttpTargetIsRejectedBeforeDuplicateCheck`.
- **FCM kapalıyken kuyruk (T-079, A13-14, K-30).** Mekanizma zaten vardır: `app.push.outbox.hold-when-disabled` (`PUSH_OUTBOX_HOLD_WHEN_DISABLED`, varsayılan `false`) ve `PushDispatcherOutboxTest` (tutma açık/kapalı) buna testlidir. K-30 ÖNERİSİ uygulandı: varsayılan **kapalı (a)** kalır (kimlik yokken push birikmez, `outbox.skipped` sayılır). FCM kimliği 1-2 gün içinde girilecekse yalnız ortam değişkeni `PUSH_OUTBOX_HOLD_WHEN_DISABLED=true` (bekleme ömrü `app.push.outbox.max-age-hours`=24 sa). Görünürlük: kimlik yokken açılışta artık WARN (`NO_CREDENTIALS`, eskiden INFO), başlatma hatasında ERROR (`FCM BASLATILAMADI`) korunur; nedeni `GET /api/admin/push/fcm/status` `error` alanı ve `pushQueue` göstergesi `disabledReason` zaten verir (panelde gösterim web işi). Üretim FCM durumu (H-08) bu çalışmada görülemedi.


## FOLLOWREQ: sohbet mesajı artık bildirim kutusuna yazılmaz (yalnız push)

- **Karar (proje sahibi):** iki kullanıcı mesajlaşınca mesajlar uygulama içi Bildirimler listesine DÜŞMEZ; liste takip istekleri ve diğer bildirimler içindir. Mesaj PUSH'u gitmeye devam eder.
- **Yazma:** `NotificationService.doSend` ve toplu yol `messageChunk`, `NotificationType.MESSAGE` için `notification` satırı yazmaz (`upsertUnread`/`save` yok). Tercih, alt tur (MESSAGE_DIRECT/GROUP), sessiz saat, `PushGate`, mesaj isteği PENDING (alıcıya hiç gönderilmez), önizleme izni ve push `collapseKey`/`threadId` kuralları AYNEN korunur. "N yeni mesaj" birleşik gövdesi için kutudaki sayaç artık yok: push tek mesaj gövdesiyle gider (FCM `collapseKey` önceki bildirimi değiştirir).
- **Okuma:** `NotificationRepository.page/pageFiltered/unreadCountsOf/markAllReadAt` ve yeni `countUnreadInbox` `type <> MESSAGE` süzer; `NotificationInboxService` (liste, `unread-count`, "tümünü okundu", tür filtresi, toplu silme) ve `MeSummaryService` (`unreadNotifications`) aynı tanımı kullanır. `type=MESSAGE` isteği geçerlidir ama boş liste döner (400 değil). Mobil sözleşme değişmez; yalnız `MESSAGE` türü artık dönmez.
- **Rozet (push `badge`):** eskiden bildirim satırı sayısıydı (MESSAGE satırları dahil). Şimdi tek alıcılı yolda `countUnreadInbox` + `ConversationPrefsService.unreadBadge` (sessize alınmamış sohbet okunmamışı; `/api/me/summary` `unreadMessages` ile aynı kaynak). Toplu (grup/oda) yolda pahalı alıcı başı sayım yapılmaz: kutu okunmamışı (MESSAGE hariç) + 1; kesin sayıyı istemci açılışta `/api/me/summary` ile düzeltir.
- **Temizlik:** `DbMaintenanceJob` görevi `notification_message` eski MESSAGE satırlarını parçalı siler (gece 03:00; tamamı boşalana dek). KVKK dışa aktarım (`NotificationExporters`) ve hesap silme (`DELETE FROM notification WHERE user_id`) etkilenmez; i18n değişmez (`notif.message.*` push için kullanılır).
- **Testler:** `MessageNoInboxPushTest` (satır yok + push var + diğer türler satır yazar + rozet), `InboxHidesMessagesTest` (liste/sayfalama/sayı/okundu/filtre/gece işi), `NotificationServiceTest`/`NotificationSmartPushTest`/`NotificationMessageBatchTest` güncellendi (beklenti "satır yazılır" → "satır yazılmaz, push gider").

## FIX-P04: bildirim fan-out, kampanya dayanıklılığı, küçük düzeltmeler

- **Toplu şablonlu bildirim API'si (diğer modüller için).** `NotificationService.sendTemplatedBulk(Collection<Long> userIds, NotificationTemplates.Template t, Map<String,String> data, String collapseKey, String... args)` ve alıcı başına farklı anahtar gerekirse `sendTemplatedBulkBy(..., Function<Long,String> collapseKeyFn, String... args)`. `sendTemplate` ile AYNI karar tablosu (aktiflik, tür/alt tür tercihi, sessiz saat, `PushGate`, alıcı dili, birleşme anahtarı) ama 250'lik parça başına sabit sayıda sorgu (aktiflik+dil, tercih, alt tür, satır yazımı, token, rozet). PostgreSQL'de tek `INSERT .. SELECT unnest` (anahtarsız) ya da `ON CONFLICT` upsert (anahtarlı); H2/diğerinde alıcı başına eski yola düşer. `MESSAGE` türü desteklenmez (`sendNewMessageBatch`). Çağıran istek/tx dışında (afterCommit + sınırlı havuz) çağırmalıdır; exception sızdırmaz. Dönüş: uygulama içi kaydı yazılan kişi sayısı. Rozet = kutu okunmamışı (sohbet payı eklenmez; istemci açılışta `/api/me/summary` ile düzeltir). `sendBulk` artık PostgreSQL'de tek ifadelik INSERT yazar ve `sendBulkDetailed` → `BulkResult(recipients, chunks, failedChunks)` döner.
- **Genel yayın (`broadcast`/`broadcastLocalized`).** Kullanıcı kimliği aralıklarıyla (1000'lik, anahtar-kümeli): her aralık kendi kısa ifadesinde `BroadcastWriter` ile hem `notification` hem `push_outbox` satırlarını `INSERT .. SELECT` yazar (token bellekte tutulmaz; cihaz kimliği + SHA-256 özeti). Satır yazımı ve push AYRI try: bir aralıkta `statement_timeout` aşılırsa push da düşmez, sonraki aralıklar sürer. H2/outbox kapalıyken eski yol.
- **Kampanya (`CampaignService.dispatch`).** Gönderim kullanıcı kimliği sırasıyla 500'lük parçalarla; her parçadan sonra `push_campaign.last_user_id` + `last_progress_at` (V1102). Hiçbir parça gitmezse `FAILED` (eskiden `SENT, 0 kişi`); kısmi başarısızlıkta durum `SENT` kalır, `error` alanı `Kısmi: n/m parça gönderilemedi.` yazar (durum kümesi değişmedi). `recoverStale()` (60 sn): 30 dk (`app.push.campaign-stale-minutes`) ilerlemeyen `SENDING` → `FAILED` ("yarıda kesildi"); çift gönderim riski için otomatik SCHEDULED'e dönmez. **Yeni uç:** `POST /api/admin/push/campaigns/{id}/resend` (yalnız `FAILED`, `COMMS_SEND` izni, 409 `CAMPAIGN_NOT_RESENDABLE`): kampanyayı SCHEDULED yapar, ilerleme işaretinden sonraki kişilere devam eder (gidenlere ikinci kez gitmez). Web paneli düğmesi istemci işi.
- **Kuyruk.** Kampanya/yayın `existsActive` N+1 yerine `activeDeviceIds` (parça başına tek sorgu). `retry-dead` (`PushOutboxService.retryDead`) kalıcı kodları (`UNREGISTERED`, `DEVICE_MISSING`, `PAYLOAD_UNREADABLE`, `EXPIRED`) ve 24 saatten eski satırları yeniden kuyruğa almaz. `ntf1101_push_sent_idx` (V1101) "son 24 saat gönderilen" sayımını indeksler; `pushQueue`/`mailQueue` sağlık göstergeleri 30 sn önbellekli (mail göstergesi SENT saymaz).
- **`PushGate`.** INCR + TTL tek Lua betiğinde (`INCR_WITH_TTL`); TTL'siz kalan anahtar kendini onarır.
- **API (istemci etkisi).** `POST /api/notifications/read` `ids` en çok 200 (aşılırsa 400 doğrulama hatası; mobil zaten küçük gruplar yollar). `DELETE /api/devices/{idOrToken}`: yalnız rakamdan oluşan (≤18 hane) değer cihaz KİMLİĞİ (`GET /api/devices` yanıtındaki `id`), aksi hâlde eski gibi FCM token'ı — iki biçim de çalışır; yeni istemci kimlik kullanmalı (token erişim günlüklerine düşmesin).
- **Kitle (`AudienceResolver`).** `DEPARTMENT`/`FACULTY` duyuru/anket ile aynı `AudienceKey` eşleşmesi (büyük-küçük harf, İ/I); `CLASS_YEAR` hem eski `class_year` hem `grade` kataloğuna bakar (0 hazırlık, 7 yüksek lisans, 8 doktora) — aynı kitle artık iki yerde aynı kişileri verir (davranış genişler: yalnız `grade` dolu kullanıcılar da eklenir).
- **Saklama (K10).** `NotificationRetentionJob` kod varsayılanları 90/365 → 30/90 (properties ve `DbMaintenanceJob` ile aynı); asıl temizlik 03:00 parçalı iştedir, bu görev emniyet ağı.
- **Ertelenen:** Brevo webhook (K11), `push_payload` normalizasyonu, `PushOutboxWorker` `sendEach` toplu FCM (FCM adaptör arayüzü değişir), gated indeks düşürme (V1102 ayrılan aralıkta gated numara kullanılmadı: gerçek ilerleme sütunları için kullanıldı), bildirim istatistik önbelleği (A04#16).

## Tek gosterimlik aciklama push'a girmez (2026-11-05)
View-once medyali mesajin aciklamasi push govdesine ASLA yazilmaz: govde `📷` (foto) ya da `🎬` (video) simgesidir (`MessageService.previewOf`). Normal medya aciklamasi ve duz metin onizlemesi (ilk 100 karakter) her zaman gider. Ayrinti: `docs/changes/messaging.md` "Tek gosterimlik aciklamasi sizdirilmaz".


## Bildirim tasarımı yük sözleşmesi (2.1.4, NB-BE; 2026-11-05)

Tasarım: `bildirim-ekranlari/` (kart dili: kaynak etiketi, rozet/çip, avatar/küçük resim, kritik şerit, bağlamsal aksiyon). Sunucu tarafı BU sözleşmeyi üretir; Android/iOS/Dart bunu okur. Tüm yeni anahtarlar **isteğe bağlı** ve **geriye uyumludur** (eski istemci yok sayar; değerler düz metin). Mevcut anahtarlar (`type`, `subtype`, `target*`, `count`, `category`, `channelId`, `threadId`, `tag`, kimlik anahtarları, sohbet için `senderName`/`conversationTitle`) değişmez. FCM data toplamı 4 KB: sığmazsa önce `imageUrl`/`senderAvatarUrl`, sonra sözleşme dışı anahtarlar atılır.

**1. `style` (her push'ta, TÜM platformlarda, yalnız sunucu belirler).** Eskiden yalnız Android zengin yolunda vardı; artık `PushPayload.build` her yüke yazar (iOS ve ön plan şeridi de okur). İstemciden gelen `style` yok sayılır. Değerler: `CHAT_DIRECT`, `CHAT_GROUP`, `CHAT_MEDIA`, `EVENT_REMINDER`, `EVENT_ADMISSION`, `EVENT_UPDATE`, `EVENT_CANCELLED` (YENİ), `POLL`, `EXAM`, `ACADEMIC`, `FOLLOW_REQUEST`, `FOLLOW_ACCEPTED`, `FOLLOW`, `LIKE` (YENİ: gönderi beğenisi), `SOCIAL` (yorum/bahsetme vb.), `SUPPORT`, `MEAL` (YENİ üretici), `SECURITY` (yalnız `securityKind` olan SYSTEM), `MODERATION` (YENİ: moderasyon bildirimi), `SYSTEM` (YENİ: diğer SYSTEM; eskiden hepsi `SECURITY` sayılıyordu), `ANNOUNCEMENT` (haber, duyuru, kulüp). APNs `aps.category` = `BU_` + `style` (iOS dahil tüm cihazlar; eski `MESSAGE`/`EVENT` biçimi kalktı). Kayıtlı olmayan kategori iOS'ta yalnız aksiyonsuz karttır (güvenli).

**2. Görsel/kaynak alanları (hepsi isteğe bağlı):**

| Anahtar | Anlam | Üretildiği yer |
|---|---|---|
| `sourceName` | kulüp / etkinlik düzenleyicisi / kaynak adı (≤ 60 karakter, içerik kaynaklı, çevrilmez). Yoksa istemci stilden etiket üretir | etkinlik hatırlatma/güncelleme/iptal/başvuru sonucu (düzenleyen kulüp adı). Diğer türlerde yok: istemci stilden etiket üretir. Gelen kutusunda `sourceName` ayrıca istek anında `communityId`/`eventId`'den çözülür |
| `imageUrl` | küçük resim: haber görseli, gönderi küçük resmi (beğeni), menü görseli, sohbet fotoğrafı. Mutlak `https`; yalnız `PUBLIC_WEB_URL` ana makinesi **ya da** `bingol.edu.tr` alt alanları kabul edilir, diğerleri sunucuda atılır; istemci de aynı kuralı uygular | haber (kaynak sitenin mutlak https adresi), menü, sohbet. Beğeni küçük resmi YOK (bölüm 6e) |
| `senderAvatarUrl` | kişi avatarı (beğeni, takip, takip isteği, kabul, sohbet; `PostNotifier` avatarı yalnız `AvatarVisibility` izin veriyorsa koyar). Alıcının `AvatarVisibility` süzgecinden geçmeden ve engel ilişkisi yokken konmaz; kalıcı bildirim `data`'sına YAZILMAZ | sosyal + sohbet |
| `eventStartsAt` | ISO-8601 UTC an (`2026-11-06T11:00:00Z`); istemci kendi saat diliminde ("Yarın 14:00") biçimler. Sınavda da aynı anahtar | etkinlik hatırlatma/güncelleme/kabul, sınav |
| `location` | düz metin (≤ 80): etkinlik yeri, sınav salonu | etkinlik, sınav |
| `oldStartsAt` / `newStartsAt` | ISO-8601 UTC; YALNIZ başlangıç saati gerçekten değiştiğinde (`EVENT_UPDATE`); `newStartsAt` = `eventStartsAt` | etkinlik güncelleme |
| `badgeText` | alıcının dilinde kısa rozet/çip metni: `Yarın`, `Saat Revizesi`, `İptal`, `Son 24 saat` (en/ar karşılıkları sunucuda çevrilir) | etkinlik yarın/revize/iptal, anket kapanıyor |
| `important` | `1` = "ÖNEMLİ" duyuru. ŞU AN ÜRETİLMİYOR (kaynak verisinde önem alanı yok); istemci varsa gösterir | - |
| `severity` | `critical` yalnız güvenlik için AYRILMIŞTIR (`NEW_DEVICE`, `PASSWORD_CHANGED`); bu iki olay ŞU AN ÜRETİLMİYOR (bkz. bölüm 6), dolayısıyla şu an hiçbir push `severity` taşımaz. İstemci geldiğinde kırmızı üst şerit çizer, iOS `time-sensitive` olur | güvenlik (ayrılmış) |
| `securityKind` | Şu an üretilenler: `TWOFA_ENABLED`, `TWOFA_DISABLED`, `TWOFA_LOCKED` (kalıcı `data`'da da bulunur) ve `NEW_DEVICE` (çoklu oturum: yeni cihaz girişi; `target=SECURITY`, `value=devices`, `sessionId`; `severity` taşımaz; bkz. `docs/changes/auth.md` "Çoklu oturum + Cihazlarım"). Ayrılmış: `PASSWORD_CHANGED`. İstemci aksiyonu buna göre seçer | 2FA, yeni cihaz |
| `eventChange` | `TIME` (başlangıç saati değişti), `PLACE`, `CANCELLED`; `style` bunu okur (`EVENT_CANCELLED`) | etkinlik güncelleme/iptal |
| `moderation` | `1` = kullanıcıya dönük moderasyon bildirimi (`style=MODERATION`) | moderasyon |
| `broadcast` | `1` = genel yayın zengin yükü (haber, herkese açık anket): `recipientId` YOKTUR; Android oturumu açık herhangi bir hesapta çizer (içerik herkese açık ve aynı) | haber/anket yayını |
| `actorId` | beğeni bildiriminde son beğenenin kimliği (kalıcı `data`'da; gelen kutusu avatar projeksiyonu için) | beğeni |
| `totalKcal` | yalnız menü kalorisi EKSİKSİZSE (`kcalComplete`); tam sayı metni. Yoksa çip çizilmez | menü |
| `mealDate` | `yyyy-MM-dd` | menü |

**3. Aksiyon** sunucudan gelmez; istemci `style` + `securityKind` + hedef anahtarlarından türetir ve yalnız karşılığında gerçek işlev olanı gösterir (`PushActions`). Veri yoksa öğe çizilmez (uydurma yok): ders QR yoklaması, ödev/Moodle, not/ÖBS, ortak arkadaş, cihaz modeli/konum, bilet iadesi, cüzdan, giriş belgesi, öğün ayrımı üretilmez.

**3b. Uygulama kapalıyken ve arka plandayken** bkz. aşağıdaki "Uygulama kapalıyken davranış" bölümü.

**4. Gelen kutusu (`GET /api/notifications`).** Her satıra isteğe bağlı `actorAvatarUrl` (aktör avatarı, istek anında `AvatarVisibility` + engel süzgeciyle) ve `sourceName` (kulüp/etkinlik düzenleyicisi) eklenir; ikisi de istek anı projeksiyonudur, kalıcı `data` JSON'una yazılmaz. Mevcut alanlar aynen korunur (`category` dahil).

**5. Cihaz kaydı.** `POST /api/devices` gövdesine isteğe bağlı `richNotifications` (Android zengin çizici yeteneği, V1270 `device.rich_notifications`). Eski kayıtlar `false` kalır ve standart FCM kartı alır.

**6. Yeni üreticiler (yalnız veri/işlev VAR olanlar).** (a) **Günlük menü bildirimi (VAR):** `MealMenuNotifier`, her gün 10:30 (`app.push.meal-cron`, `Europe/Istanbul`; `app.push.meal-enabled=false` kapatır), yalnız o gün menü varsa, gün başına bir kez (`SchedulerLock` 20 sa). Yeni tercih `notification_pref.meal_menu` (V1271, **varsayılan KAPALI, açıkça seçilir**): `GET/PUT /api/notifications/preferences` gövdesinde `mealMenu` (ya da `subtypes.MEAL_MENU`), yanıtta `mealMenu`. Yük: `target=MEAL`, `mealDate`, `totalKcal` YALNIZ tüm yemeklerin kalorisi girilmişse, `imageUrl` YALNIZ içeriğe bağlı menü görseli varsa. Mobilde tercih anahtarı gerekir. (b) **Yeni cihazdan giriş push'u ÜRETİLMİYOR:** tek mobil cihaz kuralı gereği yeni girişte eski cihazın FCM kaydı silinir (`SessionDeviceCleaner`); push yalnız girişi yapan YENİ cihaza (saldırgan dahil) gidebilirdi ve kalıcı kuyruk satırı da cihaz silinince düşer. E-posta bildirimi (`NewLoginNotifier`) devam eder. (c) **Şifre değiştirildi push'u ÜRETİLMİYOR:** şifre değişimi tüm oturumları kapatır ve tüm cihaz kayıtlarını siler (aynı neden); e-posta var. Çözüm ürün kararıdır (cihazı silmek yerine "oturumsuz" işaretlemek + giriş ekranında güvenlik bildirimi). (d) Birim/akademik duyuru (`unitnews`): bildirim türü ve tercihi SİSTEMDE YOK (bölüm duyuruları V1251'de kaldırıldı) → ÜRETİLMİYOR. (e) Gönderi beğenisi küçük resmi (`imageUrl`) ÜRETİLMİYOR: gönderi medyası kimlik doğrulamalı uçtan sunulur, imzalı adres yalnız CDN açıkken ve farklı ana makinede olabilir (medya kuralını aşar).

## Uygulama kapalıyken davranış (2.1.4, NB-BE)

Tasarlanan kart, uygulama AÇIKKEN olduğu kadar KAPALIYKEN / arka plandayken de (sistem bildirimi olarak) görünmelidir. Sunucu tarafı:

- **Android (zengin çizici, `device.rich_notifications=true`):** TÜM stiller (sohbet, etkinlik, anket, sosyal, sınav, destek, haber...) **yalnız `data`** içeren FCM mesajıyla gider: `notification` bloğu YOKTUR, `android.priority=HIGH` (zengin mesajda stile bakmadan; normal öncelikli veri mesajı Doze'da ertelenir, `FirebaseFcmSender.android`), TTL stile göre (`PushMessages.ttlSeconds`: etkinlik hatırlatma 6 sa, sınav 1 sa, sohbet/sistem 7 gün...). Böylece uygulama kapalıyken bile `FirebaseMessagingService.onMessageReceived` çalışır ve yerel zengin kart çizilir (`notification` bloğu olsaydı Android arka planda düz sistem kartı çizerdi). Başlık/gövde ve tüm zengin alanlar `data`dadır (`richNotification=1`, `title`, `body`, `style`, `locale`, `recipientId`, görsel/rozet alanları). Alıcıya özel yük (`recipientId`) `PushDispatcher.dispatch` ile kişi+dil başına üretilir. **Genel yayınlar** (haber, herkese açık anket; `broadcastRanges` -> `push_outbox`) artık iki ayrı yükle yazılır: zengin cihazlara `enrichBroadcast` (`recipientId` yok, `broadcast=1`), diğerlerine standart yük (`BroadcastWriter.DEVICES_RICH/STANDARD`). **NB-AND notu:** `broadcast=1` olan yükte `recipientId` aranmaz.
- **Eski istemci / yeteneği bildirmeyen cihaz** (`richNotifications` yok ya da `false`; sürüm tek başına yetenek sayılmaz): geriye uyum için düz FCM `notification` bloğu (başlık+gövde) + `data`; Android'de `imageUrl` varsa standart karta büyük resim (`AndroidNotification.image`, yalnız https + medya kuralı).
- **iOS:** `aps.alert` (FCM `notification` bloğundan) + `mutable-content:1` + `aps.category=BU_<style>` + `thread-id`; zengin veri alanları `aps` DIŞINDA üst düzey anahtarlardadır (Notification Service/Content uzantıları okur). `interruption-level`: `critical` önem ve `EXAM` için `time-sensitive` (uygulama yetkisi/entitlement gerekir), sosyal için `passive`.
- **Boyut (APNs 4 KB / FCM data 4 KB):** `PushMessages.of` başlığı 200, gövdeyi 600 karakterle kırpar ve veri bütçesini `4096 - 384 - len(başlık) - len(gövde)` bayta indirir; aşılırsa önce en büyük sözleşme-dışı anahtarlar (`imageUrl`, `senderAvatarUrl`, `location`...) atılır. Zengin Android yükü kendi döngüsünde (title/body veriye kopyalandığı için) aynı sınırı korur; sığmazsa düz FCM'e düşer.
- **Testler:** `NotifDesignContractTest` (Android hedefte `notification` bloğu yok + HIGH öncelik + zengin alanlar; eski cihaz düz yol; iOS aps yapısı/kategori/thread/mutable-content/time-sensitive; bütçe; broadcast yükü), `FirebaseFcmPayloadTest`, `RichPushPayloadTest`.

### Gönderi etiketi bildirimi (`POST_MENTION`, 2026-11-05)
Gönderide etiketlenene: `type=POST_MENTION`, alt tür `POST_MENTION` (gelen kutusu "Sosyal"), kanal `social`, `style=SOCIAL` (APNs `BU_SOCIAL`), başlık "Yeni etiket", gövde `{ad} seni bir gönderide etiketledi` (tr/en/ar, alıcı dilinde). `data`: `target=POST`, `value`/`postId`, `userId` (etiketleyen; kutu avatar projeksiyonu), `senderName`. Yalnız push yükü: `senderAvatarUrl` (`AvatarVisibility` süzgeci), `imageUrl` (gönderi küçük resmi; kalıcı `data`ya yazılmaz). `collapseKey=postmention:<postId>`: aynı (gönderi, kişi) için ömür boyu bir bildirim. Tercih: "communities" bayrağı + alt tür `POST_MENTION` (mevcut `subtypes` ucuyla kapatılır). Üretici: `PostNotifier.onMention`; ayrıntı `docs/changes/post.md` bölüm 11.

## Günlük menü bildirimi varsayılan AÇIK (2026-11-06)

`notification_pref.meal_menu` varsayılanı açık oldu (V1461: sütun varsayılanı TRUE + mevcut satırlar TRUE yapıldı; `NotificationPref.mealMenu=true`). `MealMenuNotifier` artık tercih satırı hiç olmayan aktif kullanıcıları da kapsar (yalnız `meal_menu=FALSE` olanlar atlanır). Kullanıcı Ayarlar > Bildirimler'den kapatabilir. **Dağıtım sırası:** oauth dalı (V1450) ve çoklu oturum dalı (V1460, `deploy/multisession-20261106`) bu migration'dan ÖNCE canlıya gitmeli (`out-of-order=false`).

## Sohbet bildirimi: pes pese mesaj artik birbirini silmiyor (2026-11-07)

Kok neden: `PushMessages.of` mesajin `collapseKey`ini (`conv:<id>`) hem Android bildirim `tag`ine hem `apns-collapse-id`ye yaziyordu; ayni sohbetin her yeni mesaji (standart FCM karti ve tum iOS) oncekini tepsiden degistiriyordu. Duzeltme (`FirebaseFcmSender.perMessage`): sohbet (`chat` kanali / `type=MESSAGE`) icin FCM duzeyinde `tag` ve `apns-collapse-id` GONDERILMEZ; her mesaj kendi `messageId`siyle ayri bildirimdir. Gruplama: iOS `aps.thread-id=conv:<id>` (farkli sohbet ayri baslik), zengin Android `data.tag=conv:<id>` ile istemci MessagingStyle birikimi (mesaj kimligiyle tekil). Takip/begeni/gonderi gibi turlerde bilincli birlesme (`follow:`, `postlike:`...) aynen surer. FCM `collapse_key` hala gonderilmez.

Aciklamasiz medya mesaji onizlemesi alicinin dilinde: `chat.preview.PHOTO|VIDEO` ("Fotograf gonderdi", "Sent a photo", "أرسل صورة"); push yukunde `mediaKind`. Tek gosterimlik medya hala dil bagimsiz simge (aciklama sizmaz). Testler: `FirebaseFcmPayloadTest`, `MessageNoInboxPushTest`, `MediaPreviewKindTest`.
- **Ayarlar ekranı** (`notification_prefs_page.dart`): `GET/PUT /api/notifications/preferences` alanları AYNEN kullanılır. Yeni satırlar yalnız sunucu yanıtında anahtar varsa çizilir (eski sunucuda gizli, çökme yok): `academicAnnouncements` (Duyurular kapalıyken pasif), "Sosyal etkileşimler" kartı (`subtypes`: POST_LIKE, POST_COMMENT, COMMENT_REPLY, POST_MENTION, USER_FOLLOW, FOLLOW_REQUEST, FOLLOW_ACCEPTED), "Önizleme" (`hideMessagePreview`), "Sistem bildirim ayarları" satırı (Android kanal ayarı / iOS uygulama ayarı) ve güvenlik bildirimlerinin tercihten bağımsız olduğu notu.
- **Sosyal alt türler ve `communities`:** sunucuda üst bayrakları `communities`'tir (`NotificationType.POST_LIKE("communities")`). Ekran "fiilen açık" (`communities` VE alt tür) gösterir; `communities` kapalıyken bir sosyal tür açılırsa aynı PUT'ta `communities:true` + saklı değeri `true` olan diğer kulüp/sosyal alt türler `false` gönderilir (kullanıcının görmediği tür kendiliğinden açılmasın). Kulüp anketi bildirimi `communities`'e bağlı olduğundan bu açış onu da etkiler.
- **Kayıt:** iyimser + hatada geri alma; PUT'lar sıralı gider (hızlı ardışık dokunuşlar birbirinin yanıtını ezmez); ön plana dönüşte sessiz yenileme.
- **"Mesaj içeriğini gizle" (`hideMessagePreview`, sunucu P-BE):** sunucu push gövdesini "Yeni mesaj"a çevirir. Android kilit ekranı için değer yerel koda `bu_kampus/notify` kanalı `setHidePreview {hide: bool}` ile iletilir (yükleme/kayıt/oturum açılışında; çıkışta `false`); yerel kod bunu paylaşılan tercihlerde `bu.pref.hide_preview` (boolean) anahtarına yazmalıdır (Android paketi). Yerel kod yoksa çağrı sessiz yok sayılır.
- **Yönlendirme:** oturum yokken dokunulan bildirim (FCM dokunuşu, native "aç" eylemi) `PushRouter`da saklanır (30 dk) ve oturum açılınca (`PushService.onSignedIn` → `flushPending`) açılır; FCM dokunuş aboneliği çıkışta kapanmaz. `messageId`/`nid`/`notificationId` taşıyan yük 8 sn içinde ikinci kez işlenmez (LRU 50). `recipientId` oturumdakinden farklıysa yük yok sayılır. Gezgin hazır değilken (soğuk açılış) 3 kare yeniden denenir.
- **Cihaz kaydı:** `onTokenRefresh` yeni jetonu kaydeder ve eski jetonun kaydını siler (çift bildirim olmasın); bildirim izni sistem ayarından geri alınırsa kayıt sunucudan silinir, izin verilince yeniden kaydedilir; çıkışta `DELETE /devices/{token}` (+ `deleteToken`) zaten çağrılır.
- **Testler:** `test/notif2_prefs_test.dart`, `notif2_lifecycle_test.dart`, `notif2_signout_test.dart`, `test/support/fake_notif_prefs.dart`.

## Canlı Etkinlik / Canlı Güncellemeler (iOS ActivityKit + Android 16), V1590

**Kapsam (kesin):** yalnız kullanıcının kendi başlattığı gerçek süreçler: katıldığı etkinliğin (RSVP `GOING`, etkinlik `ACTIVE`) ya da kendi girdiği sınavın (`tt_exam`) geri sayımı. Sohbet, arkadaşlık, duyuru ASLA. Başka kullanıcının etkinliği/sınavı için kayıt açılmaz (404 `LIVE_ACTIVITY_REF_INVALID`).

- **Uçlar (`notification.live`, JWT gerekli, hız sınırlı):**
  - `GET /api/live-activities/status` -> `{apnsConfigured, maxActive}` (istemci durumu dürüst gösterir).
  - `PUT /api/live-activities/{activityId}` gövde `{kind: EVENT|EXAM, refId, pushToken?}` -> 204. İdempotent (aynı `activityId` jeton günceller, sınıra takılmaz). Kullanıcı başına en çok 5 etkin kayıt, aşımda 422 `LIVE_ACTIVITY_LIMIT`.
  - `DELETE /api/live-activities/{activityId}` -> 204 (olmayan kayıt sessizce başarı).
- **Veri:** `live_activity` tablosu (V1590); jeton bildirim yüküne konmaz, log'a yazılmaz; en çok 12 sa (ya da etkinlik/sınav bitişi + 1 sa) yaşar; saatlik temizlik. KVKK: hesap silmede `AccountDataPurger.DELETES`, dışa aktarımda `liveActivities` bölümü (jeton verilmez, yalnız `hasToken`).
- **APNs (`ApnsLiveActivitySender`):** `apns-push-type: liveactivity`, topic `<bundle>.push-type.liveactivity`, HTTP/2 + ES256 JWT (.p8). Ortam: `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`, `APNS_KEY_BASE64` ya da `APNS_KEY_FILE`, `APNS_PRODUCTION` (`app.apns.*`). **Yapılandırma yoksa tamamen devre dışı** (hiçbir ağ çağrısı yok). Tek sunucu tetikleyicisi: etkinlik iptal edilince (`EventService.cancelInternal`) o etkinliğin etkin canlı etkinlikleri APNs `end` ile bitirilir; sınav için sunucu tetikleyicisi yok. Push-to-start desteklenmez (yalnız uygulamadan, kullanıcı dokunuşuyla başlar).
- **Hata kodları (3 dil):** `LIVE_ACTIVITY_REF_INVALID`, `LIVE_ACTIVITY_LIMIT` (`i18n/push*.properties`).
- **Test:** `LiveActivityServiceTest` (yetki, bitmiş/iptal reddi, idempotans, sınır, bitirme, APNs yapılandırmasızken devre dışı).

### Bildirimden eylemler: denetim özeti (2026-11-07)
Zaten çalışan ve testli (`push_actions.dart`, `test/push_actions_test.dart`): hızlı yanıt (iOS `UNTextInputNotificationAction`, Android `RemoteInput` + `ReplyDispatcher` + başlıksız Dart motoru, `clientId` idempotans), okundu işaretle, 1 saat sessize al, takip isteği kabul/reddet (`FollowRequestController`: idempotent, `FollowRequestFlowTest`), takip et, takvime ekle/harita/QR yoklama, güvenlik eylemleri. **Eklenmedi (backend'de güvenli karşılığı yok):** kulüp üyelik daveti Kabul/Reddet (kulüp davetleri yalnız kodludur, `ClubInviteService`), etkinlik daveti Katıl (kullanıcıya yönelik davet kaydı yok; "Detay" zaten açılır), forum/gönderi yorumundan satır içi "Yanıtla" (Keşfet yorumları kaldırıldı; satır içi yanıt ucu yok, "Gönderiye Git" derin bağlantı olarak çalışır).

## Iki ayri bildirim merkezi: Hareketler (kalp) ve Bildirimler (zil) (2026-11-07)

Bir bildirim YALNIZCA tek kapsama aittir; kapsam tek yerde (sunucu) belirlenir, istemci buna uyar.

| Kapsam | Merkez | Icerik |
|---|---|---|
| `SOCIAL` | Kalp / **Hareketler** | `POST_LIKE`, `POST_COMMENT`, `COMMENT_REPLY`, `POST_MENTION`, `USER_FOLLOW`, `FOLLOW_REQUEST`, `FOLLOW_ACCEPTED`, `FORUM` (konu/yorum begeni ve yanitlari), kulup uyelik basvurusu ve sonucu (`COMMUNITY` + alt tur `COMMUNITY_JOIN`) |
| `INFORMATION` | Zil / **Bildirimler** | etkinlik, duyuru, haber, akademik (sinav/ders programi), anket, kulup duyurusu/rolu, sistem/hesap guvenligi |
| `CHAT` | Sohbet sistemi | `MESSAGE`: kutuda YOK (yalniz push), okunmamis sayaci Sohbet sekmesinde |

Tek kaynak: `NotificationPresentation.category/scope` (Java), SQL karsiligi `NotificationRepository.SOCIAL_COND`
ve `MeSummaryService.SOCIAL_COUNT_SQL`; `NotificationScopeSplitTest` uc tanimin uyustugunu denetler. Push yuku `category`
alanini tasimaya devam eder (kulup uyelik basvurusu artik `SOCIAL`).

- `GET /api/notifications?scope=SOCIAL|INFORMATION` (yeni, opsiyonel): kapsama gore liste (sayfalama sunucuda; zil
  sosyal/sohbet icermez). `scope` yoksa eski davranis (tum kutu, MESSAGE haric). Gecersiz deger 400 `VALIDATION_ERROR`.
- `category` artik virgullu liste kabul eder (`ANNOUNCEMENT,ACADEMIC,POLL` = Duyurular cipi). Kapsamla celisen kategori bos liste.
- `kind=LIKES|COMMENTS|FOLLOWS` (yalniz `scope=SOCIAL`): Hareketler alt suzgecleri (Begeniler, Yorumlar, Takip ve Istekler).
- Her `NotificationView`: yeni `scope` alani (`getScope`), mevcut `category` aynen.
- `GET /api/notifications/unread-counts` (yeni): `{social, information, unreadCount, pendingFollowRequests, pendingMembershipRequests}`.
  `social`/`information` bagimsiz sunucu sayaclari (zil rozeti = `information`; kalp = `social` + bekleyen istekler).
  `unreadCount` eski toplamdir; `GET /notifications/unread-count` ve sayfadaki `unreadCount` degismedi.
  `pendingMembershipRequests` yalniz `MANAGE_MEMBERS` yetkili oldugu kuluplerdeki bekleyen basvurulari sayar.
- `GET /api/me/summary`: yeni `unreadSocial`, `unreadInformation`; `unreadNotifications` eski toplam olarak kalir.
- `POST /api/notifications/read`: `{"all":true,"scope":"SOCIAL|INFORMATION"}` yalniz o merkezi okundu yapar; `scope` yoksa
  eski davranis (tum kutu). `ids` ile tek tek okundu degismedi.
- Kulup katilma istegi bildirimi (`notif.community.joinRequest`) artik basvuran kimligini `data.userId` ile tasir
  (avatar projeksiyonu + Onayla/Reddet icin). Onay/ret mevcut uclar: `POST /api/communities/{id}/requests/{userId}/approve|reject`
  (yetki sunucuda, `MANAGE_MEMBERS`; bekleyen yoksa 404 `REQUEST_NOT_FOUND`). Takip istegi: `POST /api/users/me/follow-requests/{id}/accept|decline`.
- Cift kayit: ayni olay ayni kullanici icin tek satir (mevcut `collapseKey` + V940 kismi benzersiz indeks yazma yolu); bir olay
  iki listeye kopyalanmaz (kapsam satirdan turetilir, kopya yok).
- Bilinen sinir: bitmis/iptal etkinlik bildirimleri okunmamis sayacindan SUNUCUDA dusurulmez (liste `eventState` ile
  "Sona erdi/Iptal edildi" gosterir; sayac okunana/silinene kadar kalir).

## Kulup/etkinlik sessize alma, Sikayetlerim, kisi+forum arama (be3, V1630)
- `notification_mute` (V1630): `PUT|GET /api/communities/{id}/notification-mute`, `/api/events/{id}/notification-mute` (govde `{muted}`), `GET /api/me/notification-mutes`. Sessize alinan kaynak (bildirim verisinde `communityId`/`eventId`) kaynakli bildirimler kutuya ve push'a gitmez. KRITIK olanlar susmaz: SYSTEM, etkinlik iptali (`eventChange=CANCELLED`), EVENT_ADMISSION, COMMUNITY_JOIN, COMMUNITY_ROLE. Kulup icin ACTIVE uyelik sart; kaldirma her zaman serbest; kullanici basina 500 sinir.
- `GET /api/reports/mine?cursor=&limit=`: yalniz kendi raporlarim; `{id,targetType,reason,status(OPEN|RESOLVED),createdAt,resolvedAt}`; hedef kimligi/karar/not yok.
- Genel arama: `SearchType` USER ve FORUM_TOPIC eklendi; `GET /api/search/suggest?q=` en fazla 8 onek onerisi (arama gecmisi sunucuda tutulmaz).
