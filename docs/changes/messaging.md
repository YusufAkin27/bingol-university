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

## Duzenleme suresi kaldirildi, tek gosterimlik gorsel, grup fotografi (V210)

- **Duzenleme:** `app.chat.edit-window-minutes` (`CHAT_EDIT_WINDOW_MINUTES`) varsayilani 15 -> **0 = sinirsiz**; 0'da sure denetimi uygulanmaz. `MESSAGE_EDIT_EXPIRED` yalniz ayar >0 ise doner.
- **Tek gosterimlik gorsel (view-once):** gonderim govdesine `viewOnce:true` (REST + `chat.send`, tam 1 ek; aksi 400 `VIEW_ONCE_INVALID`). `AttachmentView` + `viewOnce`, `viewed`. Tek gosterimlikte `thumbUrl` yok, `url` yalniz acmamis aliciya dolu. Acis `GET /api/conversations/{cid}/media/{aid}`: ilk istek 200 (`no-store, private`, `inline`), sonrasi 410 `MEDIA_VIEW_ONCE_EXPIRED`, gonderen 403 `MEDIA_VIEW_ONCE_OWN`; `/thumb` ve `/link` 404. Acis `message_attachment_view (attachment_id, user_id)` birincil anahtariyla atomik kaydedilir; gondericiye `/user/queue/message-events` `{type:"viewed",conversationId,messageId,attachmentId,userId,at}`. Baytlar birebirde alici acinca, grupta tum alicilar acinca ya da 24 saat sonra (`app.chat.media.view-once-ttl-hours`, saatlik is `app.chat.media.view-once-cron`) silinir; `message_attachment.purged_at` isaretlenir, goruntuleme kaydi kalir. KVKK `sentChatImages` yalniz meta (+ `viewOnce`). Rapor: icerik silinmisse admin onizleme 404 (mevcut akis bozulmaz). Mesaj `messages` yayininda gondericiye url'siz, alicilara url'li gorunum gider; `edited` olayindan tek gosterimlik ekler cikarilir.
- **Grup adi/fotografi:** yalniz kullanici gruplari + yonetici (kulup/etkinlik odalari `400 NOT_A_GROUP`). `PATCH /api/conversations/{id}` (ad), `PUT|DELETE /api/conversations/{id}/avatar`; `ConversationView.avatarUrl` (`conversation.avatar_url`, `/files/avatars/...`, `ColumnMediaReferenceSource` referansina eklendi). Degisiklikte uyelere `/user/queue/message-events` `{type:"conversation-updated",conversationId,userId,title,avatarUrl,at}`. Yukleyen hesap silinse de grup avatari kalir (kullaniciya bagli degil).
- **Migration V210:** `message_attachment.view_once/purged_at`, `message_attachment_view`, `conversation.avatar_url`; indeksler `vo210_*`.

## Iletildi/okundu makbuzlari ve video mesaj (V230)

- **Makbuz imleci:** `conversation_member.last_delivered_message_id` (okundu >= iletildi; `advanceRead` iletildiyi de ilerletir, mevcut okunanlar V230'da geriye doldurulur). Ack: STOMP `/app/chat.delivered {conversationId,lastMessageId}` ve `POST /api/conversations/{id}/delivered {lastMessageId}` (204; kullanici basina dakikada 120, REST 429, WS sessiz). Imlec yalniz ileri gider, hedef baskalarinin mesajlariyla sinirlidir (kendi mesajini ackleyemez), son mesaji asan deger kirpilir, uye olmayana 404. Sunucu alicinin WS'si acik diye kendiliginden iletildi saymaz.
- **`MessageView.status`:** `SENT|DELIVERED|READ`, yalniz istek sahibinin kendi (silinmemis/gizlenmemis) mesajlarinda; digerlerinde `null`. `ConversationView.lastMessage.status` de. Birebirde karsi taraf, grupta tum diger aktif uyeler (ayrilan, engel iliskisi olan, askidaki, mesajdan sonra katilan haric). Hesap sayfa basina toplu (`ReceiptService.statuses`): konusma uyeleri tek sorgu (`rcp230_member_conv_active` kapsayici kismi indeks), askidaki kullanici denetimi tek `findAllById`; mesaj basina sorgu yok.
- **Olay:** `/user/queue/message-events` `{type:"receipt",conversationId,kind:"delivered"|"read",upToMessageId,userId,at,status}`. Birebirde `upToMessageId` = ack/okuyanin yeni imleci (peer'e); grupta mesaj sahibi basina toplulastirma (sahibin en yuksek mesaji ki durumu esigi gecti; ilerleme yoksa olay yok, en yeni 200 mesaja bakilir). Mevcut `read` akisi ayni olayi (`kind:"read"`, gerekirse once `delivered`) uretir; eski `/user/queue/read-receipts` geriye uyum icin surer. Engel iliskisi olana makbuz gitmez. "Okundu bilgisi kapali" gizlilik ayari kodda yoktur.
- **Video mesaj:** `POST /api/conversations/{cid}/media` `file=video/mp4` (+ istege bagli `poster`). `ftyp` imzasi, Content-Type `video/mp4`, boyut `app.chat.media.video-max-bytes` (40 MB, `413 VIDEO_TOO_LARGE`), sure `app.chat.media.video-max-seconds` (60, `400 VIDEO_TOO_LONG`; `moov/mvhd`'den; ayristirilamazsa `400 VIDEO_INVALID`), gunluk kota `app.chat.media.video-daily-limit` (30, `chatvideo:day:<uid>`). Sunucu yeniden kodlamaz, ffmpeg yok. `AttachmentView` + `durationMs`, `sizeBytes`; `kind` `IMAGE|VIDEO`; `width/height` Integer (videoda bilinmiyorsa `null`). Mesajda en cok 10 ek (`app.chat.media.max-attachments-per-message`, foto/video karisik; 11. ek `400 ATTACHMENT_LIMIT`), videolarin bayt toplami `video-max-total-bytes-per-message` (120 MB) ustunde `413 MESSAGE_MEDIA_TOO_LARGE` (3 dilde); eski `VIDEO_LIMIT` kaldirildi. Yukleme dakikada 20 (`uploads-per-minute`), gonderilmemis en cok 30 (`pending-max`). `viewOnce` + video `400 VIEW_ONCE_INVALID`. `GET .../media/{aid}` videoda HTTP Range (206/416); `/thumb` poster (yoksa 404); `/link` videoda `url=null`. Admin onizleme `GET /api/admin/media/attachments/{id}/preview` videoda Range destekli akis, `?thumb=true` poster; `MediaPreview.kind` `VIDEO`. Moderasyon gizleme, mesaj silme, hesap silme, yetim temizligi ve KVKK dis aktarim goruntuyle ayni kalip.
- **Yeni hata kodlari (uc dilde):** `VIDEO_TOO_LARGE`, `VIDEO_TOO_LONG`, `VIDEO_INVALID`.
- **Multipart limiti** 5/6 MB -> 45/50 MB (`MULTIPART_MAX_FILE`/`MULTIPART_MAX_REQUEST`); diger yuklemeler kendi tur sinirlarini ayrica uygular.
- **Migration V230:** `conversation_member.last_delivered_message_id` + `rcp230_member_conv_active`, `rcp230_message_conv_sender`; `message_attachment.thumb_key` NULL olabilir, `duration_ms`, `kind` kisiti `vid230_att_kind_ck` (`IMAGE|VIDEO`), `vid230_att_video_uploader`. Betik: `scripts/smoke-chat-receipts-video.sh`.

## Sohbeti sil (V231)

- `DELETE /api/conversations/{id}` -> 204, idempotent, uye degilse 404, `conv:manage` limiti (30/dk). **Birebir:** yalniz cagiran icin `cleared_up_to_message_id` = konusmanin son mesaji ve `hidden_at`; mesajlar ve karsi taraf degismez. Filtre `id > cleared`: mesaj gecmisi (`beforeCleared/afterCleared`), `unreadCounts`, son mesaj onizlemesi, medya erisimi (`accessible`), yanit hedefi onizlemesi/yeni yanit. Liste sorgusu `hidden_at IS NULL` ister; yeni mesaj (`persist`) `unhideOnMessage` ile `hidden_at`i temizler (yalniz yeni mesajlar gorunur). **Kullanici grubu:** `leave` ile ayni etki (son yonetici devri dahil) + gizleme; yeniden eklenince gizleme kalkar. **Kulup/etkinlik odasi:** 400 `CONVERSATION_NOT_DELETABLE` (3 dilde). Mute/arsiv sifirlanir.
- KVKK: `conversationSettings` icine `deletedFromListAt`, `clearedUpToMessageId` eklendi; gonderilen mesajlar `sentMessages`te kalir (kendi verisi; silme yalniz gorunumdur). Hesap silme (anonimlestirme) etkilenmez: uyelik satirlari mesaj verisiyle birlikte ayni sekilde kalir.
- Migration `V231__conversation_clear.sql`: `conversation_member.cleared_up_to_message_id`, `hidden_at`, indeks `clr231_member_hidden`.

## Golge engel (V260)

- **Gonderim:** birebirde iki yonden biri engelliyse `BLOCKED` hatasi YOK (mesaj gonderme, sohbet acma, duzenleme/silme/tepki, medya yukleme). Mesaj `message.suppressed=true` ile kalici kaydedilir (engel kalksa da gizli). Yalniz gondericiye (`/user/queue/messages`, kendi cihazlari) yayin; karsi tarafa WS, push, uygulama ici bildirim, makbuz yok. Gonderen durumu hep `SENT` (`ReceiptService`); yazma kotasi, ek ve yukleme sayaclari normal sayilir. Grup davranisi degismedi (engelleyen engellenenin mesajlarini `removed` yer tutucuyla gorur).
- **Alici tarafinda suzme:** `history` (`beforeCleared/afterCleared` goruntuleyen kimligiyle; `conversation.shadowed` bayragi olan konusmalarda), `unreadCounts` (`suppressed=false`), medya erisimi (`accessible`, view-once acma dahil 404), yanit hedefi, duzenleme/tepki/silme (`MessageActionService.access` 404), konusma listesi ve onizleme. Liste: `conversation.last_visible_message_id` (bastirilmamis son mesaj) ve `conversation_member.last_own_suppressed_message_id` (gonderenin kendi bastirilmis son mesaji); goruntuleyenin anahtari `shadowed ? GREATEST(visible, ownSuppressed) : lastMessageId`; hic gorunur mesaji olmayan alicida konusma listede yoktur, imlec (`nextCursor`) ayni anahtardir. Direkt makbuz olayinin `upToMessageId` degeri bastirilmis mesajin oncesinde kesilir.
- **Profil/avatar:** `GET /users/{id}` ve `PublicProfileMapper` engel iliskisinde bos profil (`{id, displayName}`, kalan alanlar null; 404 degil); `avatarUrl` null: konusma `peer`, uye listesi, kulup uyeleri/basvurulari/gonderi yazarlari, etkinlik katilimci/basvuru listesi, ko-organizator listesi, engellenenler listesi. Presence/typing zaten engelde gizli.
- **Migration V260:** `message.suppressed`, `conversation.shadowed`, `conversation.last_visible_message_id` (geriye doldurulur), `conversation_member.last_own_suppressed_message_id`, indeks `shd260_message_suppressed`. Betik: `scripts/smoke-block-shadow.sh`.
- **Not (moderasyon):** rapor akislari bastirilmis mesajda calismaya devam eder; `message` satiri yoneticiye acik olarak kalir.

## V270 — Yönetici toplu izleme ve view-once saklama

- **Yönetici görünürlüğü kısıtsızdır:** `GET /api/admin/users/{id}/conversations[/{cid}/messages]` artık üyelik penceresini (katılma..ayrılma), `cleared_up_to_message_id`, `hidden_at`, arşiv ve sessize almayı UYGULAMAZ; kullanıcının üye olduğu/olmuş olduğu tüm sohbetler ve konuşmadaki TÜM üyelerin tüm mesajları (silinmiş, moderasyonla gizlenmiş, gölge engelli `suppressed`) çözülmüş gelir. Mesajda `deleteKind`, `suppressed`, `blockedBy`, `status` (SENT/DELIVERED/READ), ekte `viewOnce/viewedBy/purged/messageDeleted`; konuşma satırında `state{hiddenByUser,cleared,archived,muted}`.
- **View-once saklama (kural değişti):** alıcı açınca bayt silinmez. Alıcı erişimi yine kapanır (`410 MEDIA_VIEW_ONCE_EXPIRED`; gönderen `403`; thumb/link `404`); bayt `app.chat.media.view-once-retention-days` (varsayılan 365, `0` = eski davranış: açılışta/24 sa sonra silinir) süresince yönetici önizlemesi için tutulur, sonra saatlik iş siler ve `purged_at` yazar. Silinmiş ek için yönetici önizlemesi `410 MEDIA_PURGED`. Kullanıcı hesabı silinirse (KVKK) ekler eskisi gibi hemen kaldırılır.
- **Yeni uçlar:** `GET /api/admin/chat-media`, `/chat-media/stats`, `/chat-messages` (bkz. ADMIN_API.md). Denetim: `message_access_audit.kind` = `MEDIA` / `FEED` / `REPORT_CONTEXT` (konuşma başına bir satır).
- **Şikâyet bağlamı:** `GET /api/admin/reports/{id}` (`context`, `relatedReports`, `viewerPath`); kuyruk satırlarına `reporter`, `reportedUser`, `viewerPath` eklendi. MESSAGE şikâyeti artık yalnız sohbet üyesi ve mesaj kendisine ULAŞMIŞSA kabul edilir (gölge engelle bastırılmış mesaj, gönderen dışındakine `TARGET_NOT_FOUND`).
- **Migration V270:** `adm270_message_created`, `adm270_attachment_created`, `adm270_attachment_viewonce`, `adm270_attachment_kind`. Yeni hata kodları: `MEDIA_PURGED` (410), `INVALID_FILTER` (400).

## P08 — Yönetici sohbet müdahalesi (V710) — mobil sözleşmesi

Sunucu ve mobil istemci uygulanmıştır (mobil: `lib/core/closed_conversations.dart`, `chat_detail_page.dart` kapalı sohbet bandı + `removed` yer tutucusu, `push_targets.dart` `CONVERSATION_REMOVED`). Davranışlar:

- **Yeni hata kodu `CONVERSATION_CLOSED` (HTTP 409):** yönetici sohbeti kapattıysa `POST /api/conversations/{id}/messages` ve STOMP gönderimi bu kodla reddedilir (3 dilde metin). İstemci yazma alanını kapatıp "Bu sohbet yönetici tarafından kapatıldı" göstermelidir. Aynı `clientId` ile tekrar gönderim (idempotent yol) kapalı sohbette de önceki mesajı döndürür. Sohbet yeniden açılınca (`/reopen`) gönderim normale döner.
- **Yönetici gizlemesi yer tutucusu:** yönetici gizlediği ya da kalıcı sildiği mesaj `MessageView` içinde `removed=true`, `text="Bu mesaj yönetici tarafından kaldırıldı"` olarak gelir (`MessagingDtos.ADMIN_REMOVED_TEXT`); moderasyon gizlemesi `"Bu mesaj kaldırıldı"`, kullanıcı silmesi `"Bu mesaj silindi"` olarak ayrı kalır. Yanıt önizlemesi (`replyTo`) de aynı yer tutucuyu kullanır. Metin sabittir (yerelleştirilmez); istemci `removed` bayrağına bakmalıdır.
- **Canlı olay:** gizleme/kalıcı silme aktif üyelere `/user/queue/message-events` `{type:"deleted", messageId}` olarak gelir (mevcut "herkes için sil" olayıyla aynı biçim). Geri gösterme için olay YOKTUR; istemci listeyi yeniden çekince mesaj normal görünür.
- **Bildirimler (SYSTEM türü, `data`: `conversationId`, `targetType=CONVERSATION`, `targetId`, `event` = `CONVERSATION_CLOSED` | `CONVERSATION_REOPENED` | `CONVERSATION_REMOVED`):** sohbet kapatılınca/açılınca tüm aktif üyelere, gruptan çıkarılan üyeye gönderilir.
- **Grupta çıkarılma:** yönetici üyeyi gruptan çıkarırsa kullanıcının üyeliği `left_at` ile kapanır (kendi ayrılmasıyla aynı); sohbet listesinden kaybolur.
