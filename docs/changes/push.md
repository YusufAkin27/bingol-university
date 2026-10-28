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
