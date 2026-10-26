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
