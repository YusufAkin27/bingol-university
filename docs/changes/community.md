# Topluluk (community) API degisiklikleri

Yalnizca ekleme / uyumlu degisiklik. Migration: `V140__community_discover_index.sql` (kesfet kategori indeksi).

## 1. Kategori listesi

`GET /api/communities/categories` (kimlik dogrulamali)

```json
[{"category":"Spor","count":3},{"category":"Sanat","count":1}]
```

Yalnizca ACTIVE + PUBLIC kulupler sayilir (ozel, bekleyen, reddedilen, gizli kulup sizmaz); kalabaliktan aza sirali.
`category` degeri `GET /api/communities?category=Spor` filtresinde aynen kullanilir (tam eslesme). `q` ad/aciklamada arar;
her ikisi de `cursor` (kulup id, azalan) ile birlikte calisir.

## 2. Katilim istekleri

`GET /api/communities/{id}/requests?cursor=&size=&include=answers` (MANAGE_MEMBERS; saatte 240 istek)

`include=answers` verilmezse yanit eskisiyle aynidir (`answers` alani hic gonderilmez). Verilirse her satira yanitlar eklenir
(sayfa basina tek sorgu, N+1 yok):

```json
{"items":[{"userId":9,"displayName":"Ayse","avatarUrl":null,"role":"MEMBER","joinedAt":null,
  "answers":[{"questionId":1,"question":"Neden katilmak istiyorsun?","answer":"...","answeredAt":"2026-10-01T10:00:00Z"}]}],
 "nextCursor":null}
```

Mevcut `GET /api/communities/{id}/requests/{userId}/answers` korunur.

Akis (mobil):
1. `GET /api/communities/{id}/join-questions` -> `[{"id":1,"question":"..."}]` (onayli/ozel kulupte soru varsa).
2. `POST /api/communities/{id}/join` govde: `{"answers":[{"questionId":1,"answer":"..."}]}`. Acik (OPEN + PUBLIC)
   kulupte govde gerekmez/yok sayilir; onayli veya ozel kulupte soru varsa tumu yanitlanmali, aksi halde
   `400 ANSWERS_REQUIRED`. Yanit: `{"status":"ACTIVE"|"PENDING"}`.
3. Yoneticiler istekleri `include=answers` ile listeler; onay/ret sonrasi yanitlar silinir (KVKK).

## 3. Kulup sohbet odasi

Kod tabaninda tek hizmet var (`ClubChatRoomService`); yinelenen `ClubChatService` yok, birlestirme gerekmedi.
Uclar: `GET /api/communities/{id}/chat-room` (durum; yan etki: oda yoksa kurulur), `POST /api/communities/{id}/chat-room/join`.
Ek takma ad: `POST /api/communities/{id}/chat/join` ayni islemi yapar (saatte 30 istek). Not: `GET .../chat` ucu hic
olmadi; sohbet durumu `GET .../chat-room` ucundadir.

## 4. Uyelik olayi (event modulu icin)

`edu.bingol.backend.community.ClubMemberLeftEvent(Long communityId, Long userId)` Spring `ApplicationEvent` olarak
yayinlanir; ayrilma, cikarma, ban ve istek reddinde (`ClubExtrasHooks.onMemberGone`) kulup odasindan dusurmeden sonra
senkron ve uyelik islemiyle ayni islemde yayinlanir. Dinleyici hatasi uyelik islemini bozmaz (loglanir). Event modulu
`@EventListener` ile kulube bagli etkinlik odalarindan kullaniciyi dusurebilir.

## 5. Icerik moderasyonu (dogrulandi, degisiklik yok)

- `POST /api/reports` icin `POST` ve `COMMUNITY` hedef turleri `CommunityReportHandlers` ile kayitli.
- Sabitleme: `PUT/DELETE /api/communities/{id}/posts/{postId}/pin` (MANAGE_POSTS, en fazla 3); kaldirma:
  `DELETE /api/communities/{id}/posts/{postId}` (yazar veya MANAGE_POSTS).

## Hata kodlari

Yeni hata kodu eklenmedi.
