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
