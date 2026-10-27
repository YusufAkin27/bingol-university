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
