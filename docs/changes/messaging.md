# Mesajlasma (messaging) - API degisiklikleri ve gercek zamanli istemci rehberi

Tum degisiklikler geriye uyumludur (yalniz ekleme / uyumlu duzeltme).

## Degisenler

| Uc / alan | Degisiklik |
|---|---|
| `ConversationView.mutedForever` (boolean) | Yeni alan. `PUT /api/conversations/{id}/mute {"forever":true}` ile sessize alinan konusmada `true`. `muted`/`mutedUntil` ayni kalir (suresiz icin `mutedUntil` ~100 yil sonradir; UI "suresiz" gostermek icin `mutedForever`e bakmalidir). |
| `GET /api/conversations/unread-count` | Liste satirlarindaki `unreadCount` ile AYNI tanim: ayrilmamis uyelik, katilma sonrasi, kendi/gizlenen/silinen mesajlar ve engel iliskisi olan gondericilerin mesajlari sayilmaz. `total` sessiz olmayanlar, `mutedTotal` sessizdekiler. |
| `POST /api/conversations/{id}/read` ve WS `/app/chat.read` | Hic mesaji olmayan konusmada artik 400 degil, **204 no-op**. Konusmanin son mesajindan buyuk `lastMessageId` hala 400 `INVALID_MESSAGE_ID`. Asiri sik istek (konusma basina 10 sn'de 20) **sessizce** atilir (204, hata yok); imlec sonraki istekle ilerler. Istemci yalnizca gorunur son mesaji gondermelidir. |
| Rate limit (429 `RATE_LIMITED`) | `GET /api/conversations/{id}`: 120/dk. `PATCH /{id}`, `POST /{id}/members`, `DELETE /{id}/members/{userId}`, `POST /{id}/leave`: kullanici basina ortak 30/dk. |
| `DELETE /api/messages/{id}` | Kulup odasinda gonderi yonetme yetkisi olan yonetici/moderator, etkinlik odasinda organizator baskasinin mesajini silebilir (sure siniri yok). Diger uyeler icin degisiklik yok (403 `MESSAGE_DELETE_FORBIDDEN`). Not: silen kisi odanin uyesi olmalidir. |
| WebSocket | Access token suresi dolunca (exp + 60 sn) sunucu baglantiyi **kapatir** (close kodu 1008, neden `TOKEN_EXPIRED`). Istemci token'i yenileyip yeniden baglanmali ve `GET .../messages?after=<son id>` ile eksikleri cekmelidir. |
| Push | Buyuk odalarda bildirimler asenkron ve (20+ cevrimdisi alicida) toplu gider; gonderici beklemez. |

Yeni hata kodu yoktur.

## Mesaj nesnesi (`MessageView`)

```json
{
  "id": 42, "conversationId": 7, "senderId": 3, "clientId": "uuid", "text": "merhaba",
  "removed": false, "createdAt": "2026-10-26T07:23:32Z",
  "replyToMessageId": 40,
  "replyTo": {"id": 40, "senderId": 5, "text": "onceki", "deleted": false},
  "edited": true, "editedAt": "2026-10-26T07:25:00Z",
  "deleted": false,
  "reactions": [{"emoji": "👍", "count": 2}], "myReaction": "👍",
  "attachments": [ ... ]
}
```

- Gonderim: `POST /api/conversations/{id}/messages {"text","clientId","replyToMessageId?","attachmentIds?"(en fazla 4; doluysa text bos olabilir)}`. Ayni `clientId` ile tekrar: 200 + mevcut mesaj, yenide 201.
- `deleted=true` / `removed=true`: metin sabit aciklamadir; ek ve yanit gosterilmez.
- Duzenleme `PATCH /api/messages/{id} {"text"}` (gonderen, varsayilan 15 dk). Tepki `PUT/DELETE /api/messages/{id}/reaction {"emoji"}`; izinli liste `GET /api/messages/reactions`.

## Konusma tercihleri

- Sessize al: `PUT /api/conversations/{id}/mute {"durationMinutes":1..525600}` ya da `{"forever":true}` (ikisi birden 400). `DELETE` ile kaldir. Yanit `ConversationView`.
- Arsiv: `PUT /api/conversations/{id}/archive {"keepArchived":false}`, `DELETE` ile cikar; liste: `GET /api/conversations?archived=true`.
- `ConversationView`: `{id,type,title,peer,memberCount,admin,lastMessage,unreadCount,blocked,createdAt,muted,mutedUntil,archived,mutedForever}`.
- Rozet: `GET /api/conversations/unread-count` -> `{"total":3,"mutedTotal":5,"conversations":[{"conversationId":10,"unread":3,"muted":false}]}`.

## WebSocket (STOMP, ham WebSocket, SockJS yok)

- Baglanti: `ws(s)://<host>/ws`. STOMP `CONNECT` cercevesinde `Authorization: Bearer <access JWT>` zorunlu; yoksa/gecersizse/askidaysa ERROR cercevesi (`UNAUTHORIZED`, `SUSPENDED`, `TOKEN_EXPIRED`). Heartbeat 10 sn/10 sn. Ilk cerceve 10 sn icinde CONNECT olmalidir. Mobil istemci `Origin` gondermez.
- Gonderim hedefleri (`SEND`, yalnizca `/app/**`):

| Hedef | Yuk | Not |
|---|---|---|
| `/app/chat.send` | `{conversationId,text,clientId,replyToMessageId?,attachmentIds?}` | Kaydedilen mesaj gondericinin `/user/queue/messages` kuyruguna da duser (ack, `clientId` ile) |
| `/app/chat.read` | `{conversationId,lastMessageId}` | Sessiz limit; bos konusmada no-op |
| `/app/chat.typing` | `{conversationId}` | 2 sn'de 1, fazlasi sessizce atilir |

- Abonelik hedefleri (`SUBSCRIBE`, yalnizca bunlar; `/topic/**` kapali):

| Hedef | Yuk |
|---|---|
| `/user/queue/messages` | `MessageView` (yeni mesaj) |
| `/user/queue/message-events` | `{type: "edited"\|"deleted"\|"reaction", conversationId, messageId, userId, message?, emoji?, reactions?, at}` |
| `/user/queue/read-receipts` | `{conversationId,userId,lastMessageId}` |
| `/user/queue/typing` | `{conversationId,userId}` |
| `/user/queue/errors` | `{code,message,clientId?}` (baglanti kapanmaz) |

- Teslim kalici degildir (Redis pub/sub): yeniden baglaninca her aktif konusma icin `GET /api/conversations/{id}/messages?after=<son bilinen id>` ile bosluk doldurulur.
- Token suresi: her `SEND` ve sunucu taraflı tarama exp + 60 sn sonra reddeder/kapatir; istemci baglanti kapaninca refresh edip yeniden baglanir.

## KVKK / dis aktarim

`GET /api/users/me/export` mesaj bolumleri yeni alanlarla uyumludur: `sentMessages` (id, conversationId, createdAt, removed, editedAt, replyToMessageId, text), `messageReactions` (+ `conversationSettings`: mutedUntil, archivedAt), `sentChatImages`. Herkes icin silinmis mesajlar disa aktarimda yer almaz. Degisiklik gerekmedi.
