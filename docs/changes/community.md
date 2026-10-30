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

## 6. Kulup kurma (auto-approve), silme, ayrilma (V250)

- **`app.community.auto-approve`** (env `APP_COMMUNITY_AUTO_APPROVE`, varsayilan `true`): `POST /api/communities` kulubu hemen `ACTIVE` yapar,
  sohbet odasi kurulur, yanit **201** (eski onay akisi: `false` -> **202** + `PENDING_REVIEW`). Olusturan `OWNER`. Kota: 3 sahip olunan kulup (`COMMUNITY_LIMIT`).
- **`DELETE /api/communities/{id}`** (yeni, 204; yalniz sahip/ADMIN, `403 FORBIDDEN`; saatte 10): yumusak silme, `Community.Status.DELETED`
  (V250: `ck_community_status` kisitina `DELETED` eklendi). `CommunityService.load/loadVisible` DELETED'i herkese 404 verir. Etkileri:
  `ClubExtrasHooks.onCommunityDeleted` -> sohbet odasi kapanir (`RoomConversations.closeRoom`: herkes `leftAt` ile cikar) ve `ClubDeletedEvent`
  yayinlanir; `event.EventClubDeletedListener` (AFTER_COMMIT, REQUIRES_NEW) kulubun bitmemis etkinliklerini iptal eder (`notif.event.cancelled`,
  etkinlik odalari kapanir); aktif uyelere `notif.community.deleted` (tr/en/ar); kapak/logo `media.release`; denetim `COMMUNITY_DELETED`.
- **Ayrilma** (`DELETE .../membership`, degisiklik yok; denetlendi): sahip `409 OWNER_CANNOT_LEAVE`; uyelik satiri silinir, `onMemberGone` odadan
  cikarir (`leftAt`) ve `ClubMemberLeftEvent` ile etkinlik odalarindan dusurur (kendi etkinligi haric). Mesajlasma tarafinda tum yollar
  `leftAt IS NULL` ister (liste, mesajlar, read, medya, okunmamis) -> 404. Yeniden katilimda `joinedAt` yenilenir, eski gecmis gorunmez.
- **Yeni WS olayi** `conversation-removed` (`/user/queue/message-events`, `{type, conversationId, at}`): oda uyeligi dusen (ayrilma, cikarma,
  yasaklama, oda kapanisi/kulup silme) kullanicilara commit sonrasi gonderilir (`RoomConversations.notifyRemoved`).
- Yeni hata kodu yok (`OWNER_CANNOT_LEAVE`, `FORBIDDEN` zaten ceviriliydi). Yeni bildirim: `notif.community.deleted.*`.

## Hata kodlari

Yeni hata kodu eklenmedi.

## Uygunsuz ifade filtresi (V300)

- `CommunityService.create/update` (ad, açıklama, kategori), `CommunityPostService.create` (gönderi metni), `ClubAnnouncementService.create` (duyuru), `ClubJoinFormService.setQuestions` (yeni/değişen katılım soruları) `ContentGuard` ile denetlenir; ihlalde `422 CONTENT_PROFANITY` + `field` (ayrıntı: docs/MOBILE_API_GUIDE.md). PATCH yalnızca değişen alanı denetler; yönetici de muaf değildir.
- Kulüp sohbet odası mesajları (`messaging`) filtrelenmez.
- Hata kodu: `CONTENT_PROFANITY` (`i18n/ops*.properties`, tr/en/ar).

## Kulüp kategorileri yönetimi (V550)

- **Tablo** `community_category` (`category_key` benzersiz, `name_tr/en/ar`, `icon`, `sort_order`, `active`). V550 mevcut kulüplerde kullanılan kategori değerlerini **aynen** `key` olarak tohumlar (en kalabalık 20'si aktif, kalanı pasif); tablo hâlâ boşsa 8 varsayılan ekler (`akademik, spor, sanat, kultur, teknoloji, bilim, sosyal-sorumluluk, girisimcilik`). `community.category` serbest metin sütunu değişmedi; artık `key` taşır.
- **Okuma** `GET /api/communities/categories` (giriş gerekir; ETag uyumlu, `X-Categories-Version`, `Vary: Accept-Language`). Yalnız **aktif** kategoriler, yönetici sırasıyla. Satır: `{category, count, key, name, icon, sortOrder}` — `category` (= `key`) ve `count` eski alanlardır (geriye uyumlu), `name` istek dilinde (en/ar boşsa tr), `count` keşifte görünen (ACTIVE+PUBLIC) kulüp sayısı (0 olabilir; eskiden 0 olanlar listelenmezdi). `GET /api/communities?category=<key>` süzgeci aynen çalışır (tam eşleşme).
- **Yazma** `POST /api/communities` ve `PATCH /api/communities/{id}`: `category` boş = kategorisiz; doluysa kategori **var ve aktif** olmalı (büyük/küçük harf duyarsız, kanonik key kaydedilir), aksi `400 COMMUNITY_CATEGORY_INVALID`. Güncellemede kategori **değişmiyorsa** (mevcut değerle aynı) pasif olsa da kabul edilir. Pasif/silinmiş kategoriye sahip mevcut kulüpler `category` alanını olduğu gibi döner (`CommunityView.category` = key; adı için aktif listeden eşleştirin, bulunamazsa key'i gösterin).
- **Hata kodları** (tr/en/ar `i18n/community*.properties`): `COMMUNITY_CATEGORY_LIMIT` (409, `{0}`=sınır), `COMMUNITY_CATEGORY_IN_USE` (409, `{0}`=kulüp sayısı), `COMMUNITY_CATEGORY_INVALID` (400), `COMMUNITY_CATEGORY_NOT_FOUND` (404), `COMMUNITY_CATEGORY_KEY_TAKEN` (409), `COMMUNITY_CATEGORY_ORDER_INVALID` (400). Ayar: `app.community.max-categories` (20).
- Yönetici uçları: `docs/ADMIN_API.md` "Kulüp kategorileri". Web: `/admin/community-categories`.
- **Mobil**: `/communities/categories` disk önbelleği TTL'i 30 günden **1 güne** indirilmeli (ETag/304 ile zaten ucuz); yanıttaki `X-Categories-Version` değişince yeniden çekilebilir.

## B1: üye/başvuru/gönderi alanları

- `MemberView` (`/members`, `/members/search`) ve `JoinRequestView` (`/requests`) satırlarına `department`, `classYear` (profil gizlilik ayarı `DEPARTMENT`/`CLASS_YEAR` bakana izin veriyorsa; tek `AvatarVisibility.visibleOwners` sorgusu; engel ilişkisinde `null`). `JoinRequestView.requestedAt` = başvuru zamanı (`joinedAt`, PENDING kaydın oluşma anı).
- `PostView.authorRole` (`OWNER|ADMIN|MODERATOR|MEMBER`): sayfadaki yazarların aktif üyelik rolü tek sorguda (`findByCommunityIdAndUserIdIn`); aktif üye değilse alan yok (`NON_NULL`). Kulüp gönderilerinde beğeni modeli olmadığından `likeCount/liked` eklenmedi.
- `CommunityView.requestedAt`: yalnız `PENDING_REVIEW` kulüpte (= `createdAt`), `NON_NULL`; `/api/me/communities` bekleyen satırı için.
- `SearchHit` COMMUNITY: `memberCount` (aktif üye sayısı, toplu), `category`, `myStatus` (`ACTIVE|PENDING|NONE`; BANNED `NONE` gösterilir). POSTS için `likeCount` (`post.like_count` sayacı).
