# Etkinlik modülü API değişiklikleri

Tüm değişiklikler geriye uyumludur (yalnızca alan/uç ekleme). Yeni hata kodu yoktur; yeni çeviri anahtarı yoktur.

## GET /api/events/calendar?month=YYYY-MM

Gövde yine `CalendarItem[]`. Yeni alanlar (sona eklendi):

| Alan | USER | OFFICIAL |
|---|---|---|
| `myRsvp` (`GOING`/`INTERESTED`/null) | dolu | null |
| `goingCount`, `interestedCount`, `capacity` | dolu (`capacity` null = sınırsız) | null |
| `status` (`ACTIVE`...) | dolu | null |
| `communityName` | topluluk etkinliğinde dolu | null |

`endsAt` USER öğelerinde zaten vardı.

- Önceki aydan süren çok günlü etkinlikler ay içinde görünür; `date` ay içinde kalır (başlangıç ay dışındaysa ayın ilk günü). `startsAt` gerçek başlangıcı verir.
- Kullanıcı etkinlikleri için 300, resmi öğeler için 200 sınırı vardır. Sınıra çarpılırsa yanıtta `X-Truncated: true` başlığı döner (her yanıtta `true`/`false` gönderilir). Tarayıcıdan okunacaksa CORS `exposed-headers` listesine `X-Truncated` eklenmelidir.
- RSVP, sayaç ve topluluk adları toplu sorgularla çekilir (öğe başına sorgu yok).
- OFFICIAL `date` = haberin **yayın tarihi** (`NewsItem.publishedDate`). Kaynak sitede ayrı bir etkinlik tarihi alanı ve bunu ayrıştıran bir mantık yoktur; takvimde resmi öğe "duyuru günü"nde görünür. Gerçek etkinlik tarihi ancak haber metninden ayrıştırılırsa (news modülü işi) iyileşir.

## GET /api/events/{id}/attendees/preview (yeni)

Etkinliği görebilen her giriş yapmış kullanıcı. Rate limit: 120/dk/kullanıcı.

```json
{ "goingCount": 42, "interestedCount": 7,
  "avatars": [ { "userId": 3, "displayName": "Ayşe K.", "avatarUrl": "/files/..." } ] }
```

- En çok 8 avatar; yalnızca GOING katılımcılar, profil gizlilik ayarı (`AVATAR` alanı, `AvatarVisibility`) izin verenler, engel ilişkisi olmayanlar, aktif hesaplar ve avatarı olanlar.
- `GET /api/events/{id}/attendees` organizatöre kısıtlı kalır.
- Hatalar: `EVENT_NOT_FOUND` (görünmeyen etkinlik), `RATE_LIMITED`.

## Etkinlik sohbet odası

- Oda, etkinlik bittikten `app.chat.event-room-close-days` (varsayılan 7) gün sonra `EventChatMaintenance` ile kapanır (zaten vardı; değişmedi).
- Yeni: kulüp etkinliğinde kulüpten yasaklanan ya da gizli kulübün aktif üyesi olmayan katılımcılar odadan düşürülür (organizatör/ortak organizatör hariç). Bakım görevi `app.chat.room-purge-ms` (5 dk) aralığıyla çalıştığından anlık değil, en geç bu aralıkta uygulanır.
- Katılım isteği reddedilen kişi zaten GOING olmadığı için odada değildir; kabul edilip sonra çıkarılan kişi `releaseSeat` -> `EventChatHooks.onLeft` ile düşer (değişiklik gerekmedi).
- `GET /api/events/{id}/chat-room` yan etkisizdir (yalnızca okur); girmek için `POST /api/events/{id}/chat-room/join` (kimlikli, rate limitli) zaten vardır. Görevdeki `/api/events/{id}/chat` yolu kod tabanında yoktur, yeni uç eklenmedi.

## Diğer

- Liste görünümlerinde `canManage` ve `interestedCount` artık toplu hesaplanır (davranış aynı).
- `cursor` ile verilen kayıt silinmişse liste artık başa dönmek yerine boş sayfa döner (`items: []`, `nextCursor: null`).

## Kapak fotoğrafı ve öne çıkan etkinlik

- `PUT /api/events/{id}/cover` ana sözleşme (eski `POST` takma adı duruyor); `DELETE /api/events/{id}/cover` -> 204. Kapak artık `MediaService` (`ImageKind.COVER`: doğrulama, yeniden kodlama, EXIF, en çok 1600 px, küçük resim) hattından geçer; eski dosya referans yoksa `release` ile silinir. Etkinlik iptalinde `coverUrl` temizlenir ve dosya bırakılır. İptal/reddedilmiş etkinlikte 409 `EVENT_NOT_EDITABLE` (çeviriler zaten mevcut). Yeni hata kodu yok.
- `GET /api/events/featured`: ACTIVE, `endsAt >= şimdi`, görünürlük kuralı `GET /events` ile aynı; `ORDER BY goingCount DESC, startsAt, id LIMIT 1`; yoksa 204. `goingCount` denormalize sayaç olduğundan engellenen kullanıcılar sayıyı etkilemez (toplulaştırılmış). ETag filtresine eklendi, `Cache-Control: private, max-age=30`, dakikada 60.
## Kayıt kapatma, iptal, Etkinliklerim (V250)

- V250: `user_event.registration_closed BOOLEAN NOT NULL DEFAULT FALSE`, `idx_uev_creator_ends (created_by, ends_at DESC)`.
- `POST /api/events/{id}/close` ve `/reopen` -> 200 `EventView` (idempotent; organizatör: oluşturan/ortak organizatör/kulüp `MANAGE_EVENTS`/ADMIN; saatte 60). `EventView.registrationClosed` eklendi (`canManage` zaten vardı). Kapalıyken yeni RSVP ve onaylı-etkinlik başvurusu `409 EVENT_REGISTRATION_CLOSED` (yeni kod; tr/en/ar eklendi); `INTERESTED -> GOING` geçişi de engellenir; mevcut RSVP'ler ve geri çekilme etkilenmez.
- İptal: `DELETE /api/events/{id}` (mevcut) + eşdeğer `POST /api/events/{id}/cancel` (204). PATCH/DELETE/cancel/close/reopen `event-manage` limitine (saatte 60) bağlandı.
- RSVP değişikliği: kullanıcı+etkinlik başına dakikada 5 (`event-rsvp-change`, PUT+DELETE toplam) -> 429 `Retry-After`; genel 30/dk kalır.
- `GET /api/me/events` (+ takma ad `GET /api/events/me`): `mode=upcoming|going|past|created` eklendi; `attending` (varsayılan) ve `organizing` korunur, bilinmeyen mod `attending` gibi davranır. `past` bitmiş ACTIVE etkinlikler (RSVP'li + oluşturduklarım), `startsAt DESC, id DESC`, imleç = son kaydın `id`'si.
- Kulüp silinince bitmemiş kulüp etkinlikleri iptal edilir (`EventClubDeletedListener`); bkz. community.md bölüm 6.

- V220: `idx_event_featured_going` (kısmi indeks, `status='ACTIVE'`; PostgreSQL). Duman: `scripts/smoke-events-featured.sh`.

## Uygunsuz ifade filtresi (V300)

- `EventService.create/update` (başlık, açıklama, mekân), `AnnouncementService.send` (başlık, mesaj), `EventAdmissionService.setConfig` (yeni/değişen başvuru soruları) `ContentGuard` ile denetlenir: `422 CONTENT_PROFANITY` + `field`. PATCH yalnızca değişen alanı denetler. Etkinlik sohbet odası mesajları filtrelenmez.
