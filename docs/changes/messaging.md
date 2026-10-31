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

## B1: sohbet listesi alanları ve push avatarı

- `ConversationView.lastMessage.senderName`: grup/kulüp/etkinlik sohbetlerinde son mesajı gönderenin adı (engelli gönderen ve birebir sohbette gönderilmez). Gönderen adları liste sayfası için tek `findAllById` ile yüklenir.
- `ConversationView.peer.online`: yalnız birebir sohbette karşı tarafın çevrimiçi durumu; `PresenceService.onlineAmong` ile tek MGET (N+1 yok), Redis erişilemezse `false`, engel ilişkisinde alan yok. `UserSummary.online` ve `MessageView.senderName` `NON_NULL` olduğundan diğer yanıtlarda görünmez.
- Sohbet push/uygulama içi bildirim `data`sına `senderAvatarUrl`: `AvatarVisibility.viewersAmong` (tek ayar sorgusu) ile alıcının avatarı görmesine izin veriliyorsa ve engel yoksa eklenir. Migration yok, yeni hata kodu yok.

Ek (B1): `UserSummary` (`peer`) ve `MemberView` (`GET /conversations/{id}`) `department`/`classYear` taşır; `AvatarVisibility.visibleOwners` ile tek sorguda (DEPARTMENT/CLASS_YEAR alanı bakana kapalıysa veya engel varsa gönderilmez, `NON_NULL`).

## Sohbet gorseli: net balon, sabit kare, galeriye kayit (P3, 2026-10-30)
* **Bulaniklik kok nedeni:** balon `thumbUrl` (320 px) cizerdi; ~224-250 dp x DPR 3 = 670-750 px kutuya olceklenip bulaniklasiyordu (tam ekranda `url`, <=1600 px, net). Cozum: sohbet kucuk resmi artik **kisa kenari ~720 px** (uzun kenar en cok 1280 px, kaynak kucukse buyutulmez, JPEG 0.82) uretilir (`ImageProcessor.chatThumbEdge`); diger turlerin kucuk resmi (320/480) degismedi.
* **Geriye uyumlu yeni alan:** `AttachmentView.thumbEdge` (kucuk resmin gercek uzun kenari, px; `message_attachment.thumb_edge`, V890; eski kayitlarda `null` = 320 px; video/tek gosterimlik/gizli eklerde `null`). Istemci balon kutusu x DPR icin kucuk resim yeterliyse (>= %85) onu, degilse `url` (ana gorsel) kullanir; eski mesajlar da net gorunur (daha cok veri). Mevcut kayitlar yeniden islenmez.
* Mobil: balonda tek gorsel/video posteri/izgara hucreleri SABIT KARE (224 dp, `BoxFit.cover`); decode genisligi = kutu x DPR (en cok 1600), `FilterQuality.medium`; gonderen tarafinda yerel onizleme sunucu gorseline gecerken altta kalir (iskelet/flas yok).
* **Otomatik galeriye kayit (mobil, `photo_autosave.dart`):** Ayarlar'da "Fotograflari galeriye kaydet" (varsayilan acik). Tek gosterimlik/video/silinen/engelli kaydedilmez; ek kimligi bazli tekrar yok; ayar acildiktan sonrakiler. Gonderilen fotograf yerel baytlardan, alinan fotograf `url` indirilerek `BU Kampus` albumune (`gal`, Android MediaStore, iOS add-only) kaydedilir; izin reddinde tek seferlik bilgi + Ayarlar baglantisi.

## W1-D: mesajlasma gizliligi, golge engel, olaylar (V930, 2026-10-31)

Sozlesme alanlari (mobil W1-H tuketir; hepsi geriye uyumlu EKLEME):

- **C1 `ConversationView.canModerate` (boolean):** cagiranin bu konusmada BASKASININ mesajini silme yetkisi. Kulup/etkinlik odasinda `RoomModeration.canModerate` (kulup yoneticisi/moderator, etkinlik organizatoru), kullanici grubunda grup yoneticisi, birebirde `false`. Oda moderatoru icin `admin` hala `false`; istemci silme dugmesini `canModerate`e baglamali. Alan yoksa (eski sunucu) `false` varsay.
- **C2 `MessageView.placeholderKind` ve `ReplyPreview.placeholderKind`:** `"BLOCKED"` (engelli gonderen, `text` = "Engellediğiniz kullanıcının mesajı gizlendi"), `"UNREADABLE"` (govde cozulemedi) veya alan YOK (`NON_NULL`). `text` eskisi gibi Turkce kalir (eski istemci onu gosterir); yeni istemci kind degerine gore kendi dilinde (tr/en/ar) metin gosterir. Silinmis/gizlenmis/yonetici kaldirmasi yer tutucusu degildir (`removed`/`deleted` bayraklari gecerli). WS yukleri ayni `MessageView`u tasidigi icin ayni alan canli olaylarda da vardir.
- **C3 `conversation-removed` olayi:** `/user/queue/message-events` kuyruguna `{type:"conversation-removed", conversationId, at}`; artik (1) yoneticinin uye cikarmasinda cikarilana, (2) kullanicinin kendi ayrilmasinda kendisine (diger cihazlari icin), (3) etkinlik odasi toplu bakiminda dusen her uyeye gider (kulup/etkinlik odasi yollari zaten gonderiyordu). Olay commit SONRASI yayinlanir; teslim hatasi islemi bozmaz.
- **C4 tek gosterimlik acis (iki asamali tuketim):** `GET /api/conversations/{cid}/media/{aid}` (tek gosterimlik): acis basinda (attachment_id,user_id) TALEP satiri alinir (eszamanli ikinci istek 410 `MEDIA_VIEW_ONCE_EXPIRED`); govde istemciye TAMAMEN yazilinca (akis sonuna okundu) talep teslim edilir, "viewed" olayi ve goruldu bilgisi o zaman olusur. Yazim yarim kalirsa (ag kopmasi) talep birakilir ve kullanici hemen yeniden acar. Govde ulasmadi ama sunucu yazdi saydiysa: teslimden **2-60 sn** icinde ayni kullanici **bir kez** daha acabilir (olay tekrarlanmaz); 2 sn'den once gelen yinelenen/on-getirme istekleri 410 alir. **HEAD 405 ve `Range` 416 `MEDIA_VIEW_ONCE_METHOD`** (yeni hata kodu, tr/en/ar) ile reddedilir ve hicbir sey tuketmez. Gonderen 403, thumb/link 404, baska/sure dolmus 410 (degismedi). Mobil: ag hatasinda BIR kez yeniden dener (en az 2 sn bekleme onerilir; yazim yarim kaldiysa beklemeye gerek yok).

Davranis degisiklikleri:

- **Golge engel (T-028):** `ConversationView.blocked` yalniz ENGELLEYENDE `true` (engellenen taraf `false` gorur). `GET /api/users/{id}/presence` engel iliskisinde 404 yerine sabit `{online:false,lastSeenAt:null}` (200) doner. Grup kurarken/uye eklerken BENI ENGELLEYEN kisi sessizce atlanir (403 yok); ben engellediysem bilgilendirici 403 `BLOCKED` kalir. Birebirde engellenen tarafin duzenleme/tepkisi hata vermez ama YAZILMAZ (olay da yok). `POST /api/users/{id}/block`: hedef ACTIVE degilse (silinmis/askida/yok) 404 `USER_NOT_FOUND` (eskiden 204).
- **Rizasiz DM / grup ekleme (T-025, kismi):** gruptan cikan ya da cikarilan kullaniciyi onu ekleyen kisi (`conversation_member.added_by`) bir daha ekleyemez (`conversation_add_ban`; yeni gruplar dahil, SESSIZCE atlanir, hata yok). Gunluk "yeni karsi taraf" siniri: yeni birebir konusma ve yeni grup icin ayri kovalar, kullanici basina gunde **10** (`conv:newpeer:`, `conv:newgroup:`; eskiden yalniz `conv:create:` 30 istek/gun), uye ekleme cagrisi gunde 30. `GET /api/users/{id}/presence` kullanici basina dakikada **60** (429). Cevrimici durum yalniz (a) ortak aktif konusma varsa ve (b) yalniz birebir paylasiliyorsa hedef orada en az bir mesaj yazmissa gorunur, aksi halde sabit cevrimdisi; `ProfilePrivacy.presenceAudience` (varsayilan `SHARED_CONTEXT`, `ONLY_ME` hic gostermez) uygulanir. Sohbet listesindeki `peer.online` ayni kurallarla (`PresenceService.onlineVisibleTo`). Kullanici arayuzu/ucu (`PrivacyService`/`PrivacyDtos`) W2-D'dedir; tam "mesaj istegi" modeli K-08 karari sonrasi W2-D (T-026).
- **Avatar gizliligi (T-027 parca 1):** sohbet listesi `peer.avatarUrl` ve `GET /conversations/{id}` `members[].avatarUrl` artik `AvatarVisibility` (AVATAR alani: `ONLY_ME`/`SHARED_CONTEXT` ve moderasyon `avatar_hidden`) ile suzulur; karar bilesemiyorsa avatar GONDERILMEZ (fail-closed). `UserSummary.of(User)` artik avatar tasimaz; `MessagingAvatarUsageScanTest` mesajlasma paketinde karar disi `getAvatarUrl()` okumasini engeller. Kulup/etkinlik/gonderi yuzeyleri W1-F'dedir.
- **Katilim oncesi olay (T-030):** gruba sonradan katilan (ya da "sohbeti sil" ile temizleyen) uye, katilimindan/temizlemesinden ONCE yazilmis mesajin `edited`/`deleted`/`reaction` olaylarini almaz (gecmis uclariyla ayni kural).

Migration **V930** (`V930__msg9_privacy_events.sql`, indeks oneki `msg9_`): `conversation_member.added_by`; `conversation_add_ban` (PK user_id+adder_id); `profile_privacy.presence_audience` (varsayilan `SHARED_CONTEXT`); `message_attachment_view.delivered_at/reopened_at` (eski satirlar teslim edilmis sayilir). Yeni hata kodu: `MEDIA_VIEW_ONCE_METHOD`.

Bilinen sinirlar: hesap anonimlestirmede `conversation_add_ban`/`added_by` satirlari yalniz sayisal kimlik tasir ve silinmez; yonetici sohbet goruntuleyicisi acis talebini (teslimsiz satir, en cok 30 sn) goruldu gibi gosterebilir (`AdminChatViewerService` `viewed_at` okur, `delivered_at` suzmez).

## W1-H: mobil gercek zamanli baglanti ve sohbet ekrani (2026-10-31)

Yalniz istemci (Flutter) degisiklikleri; sunucu sozlesmesi yukaridaki W1-D bolumundeki C1-C4'tur.

- **WS gonderim guvenilirligi (T-093):** WS ile atilan her metin mesaji, ack gelene kadar kalici kuyruga (`Outbox`, ayni `clientId`) da yazilir; ilk REST denemesi 8 sn ertelenir (ack penceresi). Ack (`/user/queue/messages`, kendi mesajimiz) `ChatRealtime` icinde kuyruktaki kaydi siler; sayfa kapali olsa da. Sayfa kapanir/soket olu/uygulama olurse kuyruk REST'ten gonderir (sunucu `clientId` ile cift mesaj uretmez). Konusmada gercek birikim (cevrimdisi/yeniden denenen kuyruk ogesi) varsa yeni mesaj WS'ye atlamaz, kuyrugun arkasina girer (sira). WS `errors` ile reddedilen mesaj: kuyruk hemen REST'ten dener, gercek sonuc (teslim ya da kalici hata) balona yansir.
- **STOMP geri cekilme (T-094):** `TOKEN_EXPIRED`/`UNAUTHORIZED` artik hemen yeniden baglanmaz; ustel geri cekilme (1, 2, 4... sn, +-%20) ve art arda 3 yetki hatasinda `StompFatal.sessionExpired` (oturum biter). Geri cekilme sayaci `CONNECTED` ile degil, bagli kalma suresi >= 30 sn (`stableAfter`) ile sifirlanir (sunucu baglanip hemen kapatirsa fırtina olmaz).
- **Tek soket (T-095):** `ChatTab` ve `ChatDetailPage` kendi `ChatRealtime`ini kurmaz; `Session.realtime` paylasilir (kabuk baslatir/durdurur, sayfalar yalniz abone olur, dispose etmez). `conversation-removed` olayi icin `ChatRealtime.removedConversations` akisi eklendi.
- **Yeniden kurulum (T-096):** yoklama/olay icerigi degismediyse `setState` yok; `_merge` degisiklik bildirir, yerel alanlar (`_*`) karsilastirmaya girmez; ikili aramayla sirali ekleme; satir anahtari kimlik (`m<id>`/`c<clientId>`) + `findChildIndexCallback`; `_rowKeys` yalniz kurulu satirlari tutar; ustte baska sayfa varken arka plan yoklamasi duraklar; cevrimici durum degismediyse yeniden kurulmaz.
- **Mesaj siniri (T-097):** tek olcu = Unicode kod noktasi (`runes.length`, kirpilmis metin) sayac, gonder dugmesi, `_submit` ve duzenleme yolunda; sunucu da kod noktasi sayar (1001-2000 emoji gider, 2001 gonderilmez ve sayac kirmizi). Yeni metin: `p31ChatMsgTooLong`.
- **Yer tutucu dili (T-034):** `placeholderKind` `BLOCKED`/`UNREADABLE` (mesaj, yanit onizlemesi, sohbet listesi onizlemesi) uygulama dilinde gosterilir (`p31ChatPlaceholderBlocked/Unreadable`, tr/en/ar); alan yoksa (eski sunucu) `text` oldugu gibi.
- **Moderator silme (T-032):** kulup/etkinlik odasinda `ConversationView.canModerate == true` ise baskasinin mesajinda "Mesaji sil" cikar (alan yoksa false).
- **Cikarilan uye (T-031):** `conversation-removed` olayi ya da 404 `CONVERSATION_NOT_FOUND` (acilis, yoklama, gonderim) sayfayi kapatir, `MessageCache.removeConversation` calisir, liste yenilenir ve `p31ChatRemovedToast` gosterilir; onbellekli acilis artik 404'u yutmaz.
- **Tek gosterimlik (T-033, mobil):** `ViewOnceViewer` ag hatasinda (status 0) BIR kez, 2,2 sn sonra yeniden dener (sunucu 2 sn'den once gelen yinelenen istegi 410 sayar); 403/410 yeniden denenmez.

Bilinen sinir: `Outbox` metin siniri hala UTF-16 (`text.length > maxTextLength`, W1-G dosyasi); 1001-2000 emojilik mesaj cevrimdisi kuyruga ALINAMAZ (cevrimiciyken sorunsuz gider). Cozum Outbox'ta `runes.length` kullanmaktir.
