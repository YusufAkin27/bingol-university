# Yönetim Paneli API Sözleşmesi

Web yönetim paneli (`web/`) ve backend bu sözleşmeye göre paralel geliştirilir. **Mevcut** uçlar kodda zaten vardır
(`backend/src/main/java/.../*Controller.java`); aşağıda **yeni** uçlar ve gerekli değişiklikler tanımlıdır.
Tüm `/api/admin/**` uçları `ROLE_ADMIN` ister (JWT `role` claim'i). Hata gövdesi: `{"code","message"}`; dil: `Accept-Language: tr|en|ar`.
Tarihler ISO-8601 (`2026-10-23T12:00:00Z`), tarih-yalnız alanlar `yyyy-MM-dd`. Sayfalama: `page` (0 tabanlı) + `size` (≤100) → `{items, page, totalPages, totalItems}`.

## Mevcut uçlar (panel kullanır)
| Alan | Uçlar |
|---|---|
| Kimlik | `POST /api/auth/login`, `/refresh`, `/logout`, `GET /api/auth/me` |
| Raporlar | `GET /api/admin/reports?status=OPEN&cursor=&size=`, `POST /api/admin/reports/{id}/resolve {action: DISMISS\|HIDE\|WARN\|SUSPEND_USER, message}` |
| Kullanıcı askı | `POST /api/admin/users/{id}/suspend {reason}`, `/unsuspend` |
| Geri bildirim | `GET /api/admin/feedback?status=&category=&cursor=&size=`, `PATCH /api/admin/feedback/{id} {status, adminResponse, publicVisible}` |
| Destek | `GET /api/admin/support/tickets?status=&publicOnly=&cursor=` (herkese açık talepler `publicTicket:true`, `userId` null; doğrulanmamışlar listelenmez), `GET .../{id}`, `POST .../{id}/reply {text}` (cevap + `emailStatus`: NOT_APPLICABLE/SENT/FAILED), `POST .../{id}/close` |
| SSS | `GET/POST /api/admin/faq`, `PUT/DELETE /api/admin/faq/{id}` (`lang` tr\|en\|ar) |
| Sözleşmeler | herkese açık `GET /api/legal`, `/api/legal/{type}`; yönetici `POST /api/admin/legal/{type} {tr:{title,content}, en?, ar?, requireReaccept}` |
| Ayarlar | `GET /api/admin/settings`, `PUT /api/admin/settings/{key} {value}` (mağaza linkleri, iletişim, banner, bakım modu, sürüm kontrolü) |
| Push | `POST /api/admin/push/audience-count`, `POST/GET /api/admin/push/campaigns`, `GET .../{id}`, `POST .../{id}/cancel` |
| Topluluk / etkinlik onayı | `GET /api/admin/communities`, `POST /api/admin/communities/{id}/approve\|reject`, `GET /api/admin/events` (süzmeli), `GET /api/admin/events/{id}`, `POST /api/admin/events/{id}/approve\|reject\|hide\|unhide\|cancel` (bkz. "Etkinlik moderasyonu") |
| Haber senkronu | `POST /api/admin/sync`, `POST /api/admin/sync-menu`, `GET /api/status` |
| Menü fotoğrafı | `GET /api/admin/menu?from=&to=` → `[{date, items, imageUrl}]`; `PUT /api/admin/menu/{date}/image` (multipart `file`, jpg/png/webp) → `200 {date, imageUrl}`; `DELETE /api/admin/menu/{date}/image` → 204. Satır yoksa 404 `MENU_DAY_NOT_FOUND`; geçersiz tarih 400 `MENU_DATE_INVALID`/`MENU_RANGE_INVALID`. Kullanıcı uçları (`/api/menu`, `/api/menu/today`) yanıtına `imageUrl` (string|null) eklendi. |
| İstatistik (basit) | `GET /api/admin/stats` |
| Genel (giriş gerekmez) | `GET /api/app/info` (mağaza linkleri, iletişim, banner), `GET /api/faq`, `GET /api/legal*` |

## Yeni uçlar

### Yönetici kimliği
`GET /api/admin/me` → `{id, email, displayName, role}`

### Kullanıcı yönetimi
- `GET /api/admin/users?q=&status=&role=&faculty=&department=&classYear=&language=&verified=&page=&size=&sort=createdAt,desc`
  - `q`: ad veya e-posta (büyük/küçük harf duyarsız, LIKE kaçışlı); `sort`: `createdAt|lastSeenAt|displayName` + `,asc|desc`
  - → `{items:[AdminUserRow], page, totalPages, totalItems}`
  - `AdminUserRow`: `{id, email, displayName, faculty, department, classYear, language, role, status, emailVerified, createdAt, lastSeenAt, avatarUrl}`
- `GET /api/admin/users/{id}` → `AdminUserDetail` = `AdminUserRow` + `{bio, suspendedReason, deletedAt, deviceCount, platforms:["ANDROID"], counts:{feedback, tickets, reportsAgainst, reportsFiled, conversations, communities, eventsCreated, bookmarks}, consents:[{type,version,acceptedAt}], recentActivity:[{day,opens}]}`
- `PATCH /api/admin/users/{id}/role {role:"USER"|"ADMIN"}` → 204. Kendi rolünü düşüremez; son yönetici düşürülemez (409 `LAST_ADMIN`).
- `DELETE /api/admin/users/{id}` → 204 (anonimleştirme, hesap silme ile aynı mantık; kendini silemez).
- `GET /api/admin/users/export.csv` + aynı filtreler → `text/csv` (UTF-8 BOM, hücre CSV-enjeksiyonuna karşı kaçışlı, en çok 50.000 satır).

### Profil: fakülte
- `User.faculty` (≤120). `PATCH /api/users/me {faculty}`; `ProfileView`/`PublicProfile` içinde `faculty`.
- `GET /api/faculties` (herkese açık) → `["Mühendislik Fakültesi", …]` — liste `app_setting` anahtarı `faculties` içinde `;` ile ayrılmış tutulur (yönetici `PUT /api/admin/settings/faculties`). Liste boş değilse profildeki fakülte listeden biri olmalıdır (`INVALID_FACULTY`).

### Kullanım takibi (mobil → backend)
- `POST /api/analytics/events` (giriş gerekli, dakikada 30 istek) gövde `{events:[{name, screen?, props?, at?}]}` (≤50 olay; `name` `[a-z0-9_]{1,40}`; `props` en çok 5 anahtar, değerler ≤100 karakter, kişisel veri yok) → 204. Olaylar `analytics_event` tablosuna yazılır; **180 gün** sonra silinir (zamanlayıcı).
- Her kimlikli istekte kullanıcı başına günde en çok bir kez `activity_daily(user_id, day, opens)` güncellenir ve `app_user.last_seen_at` en çok 5 dakikada bir yazılır (Redis ile kısıtlanır; istek yolunu yavaşlatmaz).
- KVKK: yalnızca toplulaştırılmış analitik gösterilir; kullanıcı detayında yalnızca günlük açılış sayıları görünür. `GET /api/users/me/export` bu verileri de içerir.

### Analitik (`/api/admin/analytics/*`, `from`/`to` = `yyyy-MM-dd`, varsayılan son 30 gün, en çok 366 gün)
- `GET .../overview` → `{totalUsers, verifiedUsers, suspendedUsers, newUsers:{today,last7d,last30d}, activeUsers:{dau,wau,mau}, stickiness, messages:{total,last24h}, communities:{active,pending}, events:{upcoming,pending}, openReports, openTickets, newFeedback, pushCampaignsSent30d, bookmarks, devices:{android,ios,web}}` (`stickiness` = dau/mau, 0-1)
- `GET .../registrations?from=&to=` → `{points:[{date,count,cumulative}]}` (günlük, boş günler 0 ile doldurulur)
- `GET .../active-users?from=&to=` → `{points:[{date,dau}], wau, mau}`
- `GET .../breakdown?dimension=faculty|department|classYear|language|role|status|platform` → `{dimension, total, items:[{key,label,count,percent}]}` (azalan sayı; boş değer `key:"unknown"`; en çok 50 öğe, fazlası `other`)
- `GET .../engagement?from=&to=` → `{topEvents:[{name,count,uniqueUsers}], screens:[{screen,views}], daily:[{date,messages,posts,rsvps,searches}], funnel:[{step,count}]}` — `funnel` adımları: `registered, verified, profileCompleted, joinedCommunity, sentMessage`
- `GET .../retention` → `{cohorts:[{weekStart,size,d1,d7,d30}]}` (yüzde 0-100; son 12 hafta)
- `GET .../support` → `{tickets:{open,answered,closed}, avgFirstResponseMinutes, feedbackByCategory:[{key,count}], feedbackByStatus:[{key,count}]}`
- `GET .../push` → `{totals:{campaigns,recipients}, recent:[CampaignView]}`
- `GET .../content?from=&to=` → `{daily:[{date,news,announcements,events}], sources:{NEWS:{maintenance,lastSuccessAt}, MENU:{…}}}`

### Denetim kaydı
`/api/admin/**` altındaki **GET dışı** tüm istekler (HandlerInterceptor, gövde kaydedilmez) `admin_audit` tablosuna yazılır:
`GET /api/admin/audit?page=&size=&adminId=&method=&q=` → `{items:[{id,adminId,adminEmail,method,path,status,at,ip}], …}` (en yeni önce).
**v2 (V630): hedef/sebep/özet/istek kimliği, yeni süzgeçler, CSV ve GET denetimi için bkz. "Denetim kaydı v2 ve yönetici yazma güvenliği" bölümü (sayfa sonu).**

### Sözleşme yönetimi eksikleri
`GET /api/admin/legal/{type}/versions` → `[{version, lang, title, content, requireReaccept, active, publishedAt}]` (tüm diller, en yeni önce).
`GET /api/admin/legal/acceptance-stats` → `[{type, version, accepted, totalActiveUsers}]` (güncel sürüm kabul oranı).

### Haber yönetimi
`NewsItem.hidden` (varsayılan false). `GET /api/admin/news?q=&type=&hidden=&page=&size=` ve `PATCH /api/admin/news/{id} {hidden}` → 204. Gizli kayıtlar herkese açık liste, detay, arama ve favorilerde görünmez.

### CORS
`app.cors.allowed-origins` (virgüllü liste, varsayılan `http://localhost:5173,http://localhost:3000`) için yalnızca `/api/**` ve `/files/**`; kimlik bilgisi çerezi kullanılmaz (Bearer başlığı). Üretimde web, nginx ile `/api` → backend proxy'si arkasında aynı kökenden sunulur.

## Hata kodları (yeni)
`LAST_ADMIN` (409), `CANNOT_MODIFY_SELF` (400), `INVALID_FACULTY` (400), `INVALID_EVENT` (400), `INVALID_RANGE` (400). Her kod için `messages*.properties` içinde `error.<KOD>` çevirisi (tr/en/ar) eklenir.

## Gerçekleşim notları (backend ile netleşen ayrıntılar)

Sözleşme alanları değişmedi; aşağıdakiler belirsiz kalan noktaların kesin hâlidir.

- **Kimlik:** `GET /api/admin/me` JWT ister (Basic auth ile 401). Yönetici JWT'si olan panel her istekte `Authorization: Bearer` gönderir.
- **Rol değişimi ve eski token:** `PATCH /api/admin/users/{id}/role` sonrası o kullanıcının eski access token'ı (role claim'i eski) **401** döner; panel/mobil mevcut akışla `/auth/refresh` çağırıp yeni rolde token alır (işaret 16 dk yaşar). `ADMIN_EMAILS` listesindeki bir hesabı USER'a düşürmek kalıcı değildir: o kullanıcı bir sonraki girişte yeniden ADMIN olur.
- **Hata kodları:** `CANNOT_MODIFY_SELF` rol düşürme ve silme için; `LAST_ADMIN` hem rol düşürme hem silme için (409). Geçersiz `sort`/`dimension`/enum değerleri `VALIDATION_ERROR` veya `MALFORMED_REQUEST` (400); kullanıcı bulunamadı `USER_NOT_FOUND` (404). `INVALID_RANGE` mesajı `{0}` yerine 366 alır.
- **Kullanıcı listesi:** `status`, `role` büyük harf enum; `verified`/`classYear` boş bırakılırsa filtre yok; silinmiş (DELETED) hesaplar `status` verilmezse de listelenir. `AdminUserDetail` alanları `AdminUserRow` ile **aynı düzeyde düz** gelir (iç içe değil).
- **CSV:** sütunlar `id,email,displayName,faculty,department,classYear,language,role,status,emailVerified,createdAt,lastSeenAt`; `sort` desteklenir; CSV dışa aktarımı (GET olmasına rağmen kişisel veri içerdiği için) denetim kaydına yazılır.
- **Fakülte:** `GET /api/faculties` boş liste dönebilir. Yönetici `PUT /api/admin/settings/faculties` değerini `;` ile ayırır; backend kırpar, boşları/tekrarları atar (her ad ≤120, toplam ≤1000 karakter, aksi 400). Boş `faculty` gönderimi alanı temizler. Hesap silinince fakülte de silinir.
- **Kullanım takibi:** `app_open` adlı olay günlük `opens` sayacını artırır; ekran raporu `screen_view` olaylarının `screen` alanından üretilir; `search` olayı `engagement.daily.searches` sayacını besler. `at` verilmezse veya son 7 günün/+5 dk'nın dışındaysa sunucu saati kullanılır (reddedilmez). `props` değerleri skaler (metin/sayı/mantıksal) olmalı; `@` içeren değer kişisel veri sayılıp reddedilir. Bir olay geçersizse tüm istek reddedilir (`INVALID_EVENT`). Hesap silinince kullanıcının `activity_daily` ve olayları da silinir.
- **Analitik tanımları:** gün sınırları Europe/Istanbul. `totalUsers`/`breakdown`/`funnel` silinmiş hesapları saymaz (`breakdown?dimension=status` hepsini sayar). `registrations` aralıktaki tüm kayıt satırlarını sayar. `dau` bugün (İstanbul), `wau`/`mau` bugün dahil son 7/30 gün, benzersiz kullanıcı. `platform` dağılımı cihaz kaydı sayısıdır (kullanıcı başına birden çok olabilir). `funnel` adımları aralıkta kayıt olan kullanıcılar için bağımsız sayılır (`profileCompleted` = bölüm ve sınıf dolu; `joinedCommunity` = aktif üyelik; `sentMessage` = en az bir mesaj). `retention`: doğrulanmış kullanıcılar, kohort haftası Pazartesi başlangıçlı; D1/D7/D30 = kayıt gününden tam N gün sonra aktif olanların, N günü henüz dolmuş kullanıcılara oranı (yüzde, 1 ondalık); henüz hesaplanamayan = 0. `support.avgFirstResponseMinutes` son 90 günde açılan taleplerin ilk yetkili yanıt süresi ortalaması. `push.totals` yalnızca SENT kampanyaları sayar; `recent` son 10 kampanyadır (tüm durumlar). `content.daily` haber tarihi (`published_date`) bazlıdır; `sources` değerleri `/api/status` ile aynı şekildedir.
- **Denetim kaydı:** GET dışı tüm `/api/admin/**` istekleri, yetkisiz (403) denemeler ve `users/export.csv` yazılır; Basic auth yöneticisi için `adminId` null, `adminEmail` kullanıcı adıdır. Gövde ve sorgu dizgesi saklanmaz. `method` filtresi büyük/küçük harf duyarsızdır, `q` yol veya e-postada arar.
- **Haber:** `GET /api/admin/news` satırı `{id,type,title,summary,url,imageUrl,publishedDate,fetchedAt,hidden}`. Gizli haber `GET /api/news/{id}`'de 404, listede/aramada/favorilerde yok, favoriye eklenemez, yeni-haber bildiriminde gönderilmez.
- **Sözleşme kabul oranı:** `accepted`/`totalActiveUsers` yalnızca ACTIVE ve e-postası doğrulanmış kullanıcıları sayar.
- **CORS:** `CORS_ORIGINS` (docker-compose) `app.cors.allowed-origins` değerini besler; `*` verilirse tüm kökenler, boş bırakılırsa CORS kapalıdır. Yanıtta `Content-Disposition` ve `ETag` okunabilir.

### Kullanıcı detayı: `extras` (eklendi)
`GET /api/admin/users/{id}` yanıtına `extras` alanı eklendi: `showEmail`, `notificationPrefs{news,announcements,events,messages,communities}`,
`notificationsTotal`, `notificationsUnread`, `messagesSent` (yalnızca sayı; mesaj içeriği ASLA dönmez), `blocking`, `blockedBy`,
`devices[{platform,registeredAt}]`, `communities[{id,name,role,status,joinedAt}]`, `eventsCreated[...]`, `eventsAttending[...rsvp]`,
`feedback[...]`, `tickets[...]`, `reportsAgainst[...]`, `reportsFiled[...]` (her liste en fazla 50 kayıt).

## T12 — Moderasyon genişletmeleri (ayrıntı: [MODERATION.md](MODERATION.md))

- `GET /api/admin/reports?status=OPEN&order=asc|desc|priority&targetType=&cursor=&size=` → `{items:[ReportView], nextCursor}`. `ReportView` yeni alanlar: `priority`, `reasonCode`, `preview{kind:IMAGE|TEXT,url,thumbnailUrl,mime,text}|null`, `hidden`, `hiddenBy` (`AUTO`|`ADMIN`|null), `openReporters`. **`order=priority` modunda `cursor` sayfa numarasıdır (0'dan)**; diğer modlarda rapor id'si. Yeni hedef türleri: `MESSAGE_IMAGE`, `USER_AVATAR`, `COMMUNITY_COVER`, `EVENT_COVER` (handler kayıtlıysa).
- `POST /api/admin/reports/{id}/resolve {action: DISMISS|HIDE|WARN|SUSPEND_USER, message?, reasonCode?}` → 204 (`reasonCode`: `SPAM|HARASSMENT|SEXUAL|VIOLENCE|HATE|PRIVACY|COPYRIGHT|IMPERSONATION|OTHER`; geçersiz → 400 `REASON_CODE_INVALID`).
- `POST /api/admin/reports/bulk-resolve {ids:[≤100], action, message?, reasonCode?}` → 200 `[{id, ok, error}]` (satır hataları `error` kodu olarak; dakikada 20 çağrı).
- `GET /api/admin/reports/reason-templates` → `[{code, text (istek dilinde), texts:{tr,en,ar}}]`.
- `GET /api/admin/moderation/appeals?status=OPEN|ACCEPTED|REJECTED&cursor=&size=` → `{items:[{id,userId,targetType,targetId,message,status,adminNote,createdAt,decidedAt}], nextCursor}`; `POST …/appeals/{id}/decide {accept:boolean, note?}` → 204 (kabul = içerik geri açılır, ihlal iptal; 409 `ALREADY_RESOLVED`, 409 `TARGET_NOT_REVERSIBLE`).
- `GET /api/admin/moderation/suspend-recommendations?status=OPEN` → `{items:[{id,userId,strikeCount,status,createdAt}], nextCursor}`; `POST …/{id}/accept` (kullanıcıyı askıya alır) · `POST …/{id}/dismiss` → 204.
- `GET /api/admin/moderation/blocklist?cursor=&size=` → `{items:[{sha256,note,createdBy,createdAt}], nextCursor}`; `POST …/blocklist {sha256 (64 hex), note?}` → 201 (idempotent); `DELETE …/blocklist/{sha256}` → 204 / 404.
- Kullanıcı uçları: `POST /api/appeals {targetType,targetId,message}` → 201 `{id}`; `GET /api/appeals/mine`.

## T24 — Kullanıcı bazlı sohbet görüntüleyici

Yalnızca JWT'li ADMIN (Basic auth 401). Her sayfa isteği otomatik değiştirilemez denetim kaydı yazar (`message_access_audit`; **gerçek sebep zorunlu**: `X-Admin-Reason` / `reason` ≥ 10 karakter, bkz. sayfa sonu; zorunluluk kapalıyken sistem gerekçesi `yonetici sohbet goruntuleme`); kayıt yazılamazsa içerik dönmez (`503 CRYPTO_UNAVAILABLE`). Hız sınırı: yönetici başına dakikada 120 sayfa. Ayrıntı ve güvenlik kararları: [ENCRYPTION.md](ENCRYPTION.md) §4.

| Uç | Açıklama |
|---|---|
| `GET /api/admin/users/{id}/conversations?cursor&size` | `{user, items[], nextCursor}`; öğe: `id, type (DIRECT/GROUP), title, peer{id,displayName,avatarUrl}, memberCount, totalMessages, lastActivityAt, left, lastMessage{id,senderId,mine,text,error,deleted,hidden,createdAt}`. Son mesaj yeniden eskiye; `cursor` = önceki sayfanın `nextCursor`; `size` ≤ 30. |
| `GET /api/admin/users/{id}/conversations/{cid}/messages?before&size` | `{user, conversation{id,type,title,peer,left}, items[], nextBefore}`; `items` **eskiden yeniye**; `before` = daha önce yüklenen en eski mesaj kimliği; `size` ≤ 50. Öğe: `id, senderId, senderName, mine, createdAt, text, error, edited, editedAt, revisions[{text,error,revisedAt}], deleted, deletedAt, deletedBy, deletedByName, hidden, replyTo{id,senderId,text,error,deleted}, reactions[{emoji,userId}], attachments[{id,kind,contentType,width,height,bytes,hidden,previewUrl,thumbUrl}]`. |
| `GET /api/admin/media/attachments/{id}/preview?thumb` | (T8) ek önizlemesi; silinmiş mesajın eki dahil. |
| ~~`POST /api/admin/messages/decrypt`~~ | **Kaldırıldı** (404/405). |

Hatalar: `404 USER_NOT_FOUND`, `404 CONVERSATION_NOT_FOUND` (konuşma kullanıcının üyeliği değilse), `403 ADMIN_DECRYPT_DISABLED`, `429 RATE_LIMITED`, `503 CRYPTO_UNAVAILABLE`.

## V270 — Sohbet görüntüleyici (kısıtsız) + toplu izleme alanı + şikâyet bağlamı

Hepsi yalnızca JWT'li ADMIN (Basic auth 401), yönetici başına dakikada 120 istek (`429 RATE_LIMITED`), her çağrı içerik dönmeden önce `message_access_audit`'e yazılır (konuşma başına bir satır; `kind`: `LIST_PREVIEW`, `VIEW_MESSAGES`, `MEDIA`, `FEED`, `REPORT_CONTEXT`). Ortak hatalar: `403 ADMIN_DECRYPT_DISABLED`, `503 CRYPTO_UNAVAILABLE`, `400 INVALID_FILTER` (geçersiz `kind`/`order`/tarih). Zaman alanları ISO-8601 UTC; `from`/`to` = ISO an ya da `yyyy-MM-dd` (Europe/Istanbul, `to` o günü dahil eder).

### Kullanıcı sohbet görüntüleyici: değişiklikler (kısıtsız görünürlük)
`GET /api/admin/users/{id}/conversations?cursor&size(≤30)` ve `.../{cid}/messages?before&size(≤50)` artık üyelik penceresi, `clearedUpTo`, kullanıcı gizlemesi, ayrılma, arşiv, sessize alma ve gölge engel NEDENİYLE hiçbir mesajı/sohbeti gizlemez. Hedef kullanıcı hiç üye olmadıysa `404 CONVERSATION_NOT_FOUND`. Anonimleştirilmiş hesapta mevcut davranış korunur (ad/e-posta anonim gelir, sohbetler yine listelenir).

Konuşma satırı: `{id, type, title, peer{id,displayName,avatarUrl,email}|null, memberCount, totalMessages, lastActivityAt, left, joinedAt, leftAt, state{hiddenByUser,cleared,archived,muted}, lastMessage{id,senderId,mine,text,error,deleted,hidden,suppressed,createdAt}|null}`.

`messages` yanıtı: `{user, conversation{id,type,title,peer,left,state,members[{person{id,displayName,avatarUrl,email},role,joinedAt,leftAt}]}, items[], nextBefore}`. Mesaj (`items[i]`, eskiden yeniye):
```json
{"id":9001,"conversationId":10,"senderId":2,"senderName":"Bob","sender":{"id":2,"displayName":"Bob","avatarUrl":null,"email":"b@bingol.edu.tr"},
 "mine":false,"createdAt":"2026-02-01T10:00:00Z","text":"çözülmüş gövde","error":null,
 "edited":true,"editedAt":"...","revisions":[{"text":"ilk sürüm","error":null,"revisedAt":"..."}],
 "deleted":true,"deletedAt":"...","deletedBy":2,"deletedByName":"Bob","deleteKind":"EVERYONE_BY_SENDER|EVERYONE_BY_OTHER|null",
 "hidden":false,"suppressed":true,"blockedBy":{"id":3,"displayName":"Carol","avatarUrl":null,"email":"..."},
 "status":"SENT|DELIVERED|READ","replyTo":{"id":8999,"senderId":1,"text":"...","error":null,"deleted":false},
 "reactions":[{"emoji":"👍","userId":1}],
 "attachments":[{"id":55,"kind":"IMAGE|VIDEO","contentType":"image/webp","width":800,"height":600,"durationMs":null,"bytes":12345,
   "viewOnce":true,"viewedBy":[{"id":1,"displayName":"Alice","at":"..."}],"purged":false,"hidden":false,"messageDeleted":true,
   "previewUrl":"/api/admin/media/attachments/55/preview","thumbUrl":"/api/admin/media/attachments/55/preview?thumb=true"}]}
```
`error` doluysa (`NO_CIPHERTEXT`, `AUTH_FAILED`, ...) `text` null'dır (satır bazında). `previewUrl/thumbUrl` bayt silindiyse (`purged`) null. `deleteKind`: yalnız "herkes için silme" vardır; kullanıcının kendi "sohbeti sil/gruptan ayrıl" işlemi mesajı silmez (`state.cleared`). `blockedBy`: gölge engelli mesajda engeli koyan taraf. `status`: gönderen dışındaki üyelerin makbuzuna göre; bastırılmış mesaj hep `SENT`.

### Ek önizleme
`GET /api/admin/media/attachments/{id}/preview[?thumb=true]`: gizlenmiş, silinmiş mesaj ve tek gösterimlik ekler dahil (Bearer ile istenir; video Range destekli). Tek gösterimlik bayt saklama süresi (`app.chat.media.view-once-retention-days`, varsayılan 365) dolup silindiyse `410 MEDIA_PURGED`.

### `GET /api/admin/chat-media` — tüm sohbetlerdeki ekler
Sorgu: `cursor` (ek id), `size` (≤60, varsayılan 30), `kind=IMAGE|VIDEO|ALL`, `viewOnce=true|false`, `deleted=true|false` (mesaj silinmiş mi), `userId` (kullanıcının üye olduğu/olmuş olduğu sohbetlerin ekleri: gönderen ya da alıcı), `conversationId`, `from`, `to`, `order=desc|asc` (varsayılan desc; imleç yönü buna uyar). Yalnız bir mesaja bağlı ekler.
```json
{"items":[{"attachmentId":55,"conversationId":10,"conversationTitle":"Alice · Bob","conversationType":"DIRECT","messageId":9001,
  "sender":{"id":1,"displayName":"Alice","avatarUrl":null,"email":"a@bingol.edu.tr"},
  "recipients":[{"id":2,"displayName":"Bob","avatarUrl":null,"email":"b@bingol.edu.tr"}],"memberCount":2,
  "kind":"IMAGE","viewOnce":true,"viewedBy":[{"id":2,"displayName":"Bob","at":"2026-02-01T10:01:00Z"}],"purged":false,
  "messageDeleted":false,"hidden":false,"suppressed":false,"createdAt":"2026-02-01T10:00:00Z","width":800,"height":600,
  "durationMs":null,"bytes":12345,"previewUrl":"/api/admin/media/attachments/55/preview","thumbUrl":"/api/admin/media/attachments/55/preview?thumb=true"}],
 "nextCursor":54}
```
`recipients`: birebirde karşı taraf; grupta boş, `memberCount` aktif üye sayısı. `previewUrl/thumbUrl` `purged` ise null. Denetim: `kind=MEDIA`.

### `GET /api/admin/chat-media/stats`
```json
{"imageCount":10,"videoCount":2,"viewOnceCount":3,"deletedMessageMediaCount":1,"hiddenCount":0,"suppressedCount":0,"purgedCount":0,"totalBytes":123456,
 "last24h":{"imageCount":1,"videoCount":0,"viewOnceCount":1,"deletedMessageMediaCount":0,"hiddenCount":0,"suppressedCount":0,"purgedCount":0,"totalBytes":100}}
```

### `GET /api/admin/chat-messages` — tüm sohbetlerden mesaj akışı
Sorgu: `cursor` (mesaj id; en yeni önce), `size` (≤50, varsayılan 30), `userId` (üye olduğu/olmuş olduğu sohbetler), `senderId`, `conversationId`, `deleted`, `suppressed`, `hasMedia` (true|false), `from`, `to`. Metin araması yoktur (gövde şifreli). Çözme sayfa başına toplu; hata satır bazında (`message.error`).
```json
{"items":[{"message":{ /* yukarıdaki mesaj nesnesi */ },
           "conversation":{"id":10,"type":"DIRECT","title":"Alice · Bob","memberCount":2}}],
 "nextCursor":8950}
```
`message.mine` yalnız `userId` verildiyse o kullanıcıya göre doludur. Denetim: `kind=FEED`.

### Şikâyet bağlamı
- `GET /api/admin/reports?...` (mevcut kuyruk) satırlarına eklendi: `reporter{id,displayName,email}`, `reportedUser{id,displayName,email}|null`, `viewerPath|null`.
- `GET /api/admin/reports/{id}` → şikâyet + bağlam. `404 REPORT_NOT_FOUND`. Denetim: `kind=REPORT_CONTEXT` (sohbet içeriği çözülürse).
```json
{"id":12,"targetType":"MESSAGE","targetId":9001,"reason":"HARASSMENT","reasonCode":null,"note":"küfür etti","status":"OPEN","resolution":null,
 "priority":10,"createdAt":"...","resolvedAt":null,
 "reporter":{"id":1,"displayName":"Alice","email":"a@bingol.edu.tr"},
 "reportedUser":{"id":2,"displayName":"Bob","email":"b@bingol.edu.tr"},
 "context":{"type":"MESSAGE","targetExists":true,
   "conversation":{"id":10,"type":"DIRECT","title":"Alice · Bob","memberCount":2,"members":[{"person":{"id":1,"displayName":"Alice","avatarUrl":null,"email":"..."},"role":"MEMBER","joinedAt":"...","leftAt":null}]},
   "reportedMessageId":9001,"reportedAttachmentId":null,
   "messages":[{"reported":true,"message":{ /* mesaj nesnesi: silinmiş olsa da çözülmüş, ekler previewUrl/thumbUrl ile */ }}],
   "content":null,
   "userStats":{"reportsAgainstUser":2,"activeStrikes":1,"totalStrikes":2}},
 "relatedReports":{"sameTargetCount":1,"last":[{"id":11,"reporter":{"id":3,"displayName":"Carol","email":"..."},"reason":"SPAM","status":"OPEN","createdAt":"..."}]},
 "viewerPath":"/admin/users/2/messages?c=10&m=9001"}
```
`context.type`: `MESSAGE`, `MESSAGE_IMAGE`, `USER`, `POST`, `COMMUNITY`, `EVENT` ya da `NONE` (cover/avatar vb.). `MESSAGE`/`MESSAGE_IMAGE`: şikâyet edilen mesaj ±10 mesaj (eskiden yeniye, aynı sohbet; `reported:true` işaretli; `MESSAGE_IMAGE` için `reportedAttachmentId` dolu); `USER`: şikâyet eden ile edilen arasındaki birebir sohbetin son 20 mesajı (yoksa `messages:[]`, `conversation:null`); `POST/COMMUNITY/EVENT`: `content{kind,id,title,text,communityId,ownerId,imageUrl,deleted,status,createdAt}`. `viewerPath` sohbet bilinmiyorsa `/admin/users/{id}/messages`, sahip bilinmiyorsa null.

### Şikâyet oluşturma (kullanıcı) kuralı
`POST /api/reports` `MESSAGE`: yalnız sohbetin aktif üyesi ve mesaj kendisine ulaşmışsa kabul edilir; gölge engelle bastırılmış (`suppressed`) başkasının mesajı için `404 TARGET_NOT_FOUND` (varlık sızıntısı yok). Silinmiş/gizli mesaj raporlanabilir ve yönetici gövdeyi görür (V96: şifreli gövde silmede saklanır). Tek gösterimlik görselin baytı saklama süresi boyunca yönetici bağlamında önizlenir.

## V280 — Erişim engelleri (IP / CIDR / cihaz / kullanıcı)

Yönetici; kayıtlı bir kullanıcıyı, **kayıtlı olmayan kişiyi** IP/CIDR ile ya da mobil **cihaz kimliğiyle** engelleyebilir. Engelli IP/cihaz hiçbir `/api/**` ucuna (anonim dahil: kayıt, giriş, herkese açık uçlar) ve WebSocket el sıkışmasına giremez; yeni engelde eşleşen kullanıcıların **mevcut oturumları** da kapanır. Tümü `ADMIN` + rate limit + denetim kaydı (yazma işlemleri; ayrıca liste/istatistik/cihaz listesi GET'leri de denetlenir). Ortak notlar:

- **Sayfalama:** imleçli. Yanıt `{items, nextCursor}`; sonraki sayfa `?cursor=<nextCursor>`; `size` 1..100 (varsayılan 20), yeniden eskiye.
- **Engellenemezler:** loopback, özel ağlar (10/8, 172.16/12, 192.168/16, 169.254/16, fc00::/7, fe80::/10, ::1) ve `BAN_ALLOWLIST` (CIDR listesi) hiçbir zaman IP ile engellenmez; bunları (ya da `force` yoksa kendi IP/cihazınızı) engelleme girişimi `400 BAN_SELF_LOCKOUT`. Yönetici hesapları (ADMIN rolü) `USER` ile engellenemez ve IP/cihaz engelinde oturumları kapatılmaz. `/api/admin/**` IP/cihaz engelinden muaftır.
- **Cihaz değeri:** `DEVICE` için yönetici ham kimlik (8..128 karakter, `[A-Za-z0-9._:-]`) **ya da** 64 haneli hex özeti girebilir; sunucu HMAC-SHA256 ile özetler, ham değer saklanmaz/loglanmaz. Panelde cihazlar `deviceHash` (tam) / `deviceShort` (ilk 8 karakter) ile gösterilir.
- **Zaman:** tüm tarihler ISO-8601 UTC. `expiresAt` verilmezse engel süresizdir; geçmiş tarih `400 BAN_INVALID_VALUE`.
- **Gecikme:** değişiklikte yerel önbellek anında yenilenir; çok örnekli kurulumda diğer örnekler en geç 20 sn (`BAN_CACHE_TTL_SECONDS`) sonra görür.

`reasonCode`: `ABUSE | SPAM | FRAUD | OTHER` (varsayılan `OTHER`). `note` en çok 300 karakter, yalnız yöneticide görünür; istemciye engel sebebi **asla** sızdırılmaz.

### `BanView` (tek engel kaydı)
```json
{"id":17,"kind":"CIDR","value":"198.51.100.0/24","valueShort":"198.51.100.0/24","note":"VPN sağlayıcı A",
 "reasonCode":"ABUSE","createdBy":3,"createdAt":"2026-10-27T10:00:00Z","expiresAt":null,
 "active":true,"effective":true,"hitCount":42,"lastHitAt":"2026-10-27T11:20:31Z","userId":null,"userDisplayName":null}
```
`kind`: `IP | CIDR | DEVICE | USER`. `value`: IP/CIDR kanonik metni (CIDR ağ adresine çekilir: `10.1.2.3/8` → `10.0.0.0/8`; IPv6 tam gösterimle, ör. `2001:db8:0:0:0:0:0:0/32`), DEVICE için 64 haneli özet, USER için kullanıcı id'si. `valueShort`: DEVICE'ta ilk 8 karakter, diğerlerinde `value`. `effective` = `active` ve süresi dolmamış. `userId`/`userDisplayName` yalnız `USER` engelinde dolu.

### `GET /api/admin/access-bans?kind=&active=&q=&cursor=&size=`
`kind` (IP|CIDR|DEVICE|USER), `active=true` (etkin ve süresi dolmamış) / `false` (kaldırılmış ya da süresi dolmuş), `q` (değer ya da not içinde, büyük/küçük harf duyarsız). Yanıt `200`:
```json
{"items":[ /* BanView */ ],"nextCursor":12}
```

### `POST /api/admin/access-bans`
```json
{"kind":"DEVICE","value":"<ham cihaz kimliği ya da 64 haneli özet>","reasonCode":"FRAUD","note":"çoklu hesap",
 "expiresAt":"2026-12-31T00:00:00Z","alsoBlockUserDevices":false,"alsoBlockUserIps":false,"force":false}
```
`kind`: `IP` / `CIDR` (`value` adres ya da `a.b.c.d/n`, IPv6 desteklenir; tek adres IP olarak saklanır) / `DEVICE` / `USER` (`value` = kullanıcı id'si; `alsoBlockUserDevices`/`alsoBlockUserIps` yalnız USER için, bkz. block-access). `force=true` yalnız kendi IP/cihazınızı kapsayan engeli onaylar (özel ağ ve izin listesi `force` ile de engellenemez). Yanıt `201`:
```json
{"bans":[ /* yeni oluşan BanView'ler; zaten etkin engel varsa boş + warnings:["ALREADY_BANNED"] */ ],
 "devicesBlocked":0,"ipsBlocked":1,"sessionsClosedUsers":2,"warnings":[]}
```
`sessionsClosedUsers`: oturumu kapatılan kullanıcı sayısı. `warnings` değerleri: `ALREADY_BANNED`, `OWN_DEVICE_SKIPPED`, `OWN_IP_SKIPPED`, `NO_DEVICE_ON_RECORD`, `SHARED_IP_RISK` (paylaşımlı/CGNAT IP başka kullanıcıları da etkileyebilir). Hatalar: `400 BAN_INVALID_VALUE`, `400 BAN_SELF_LOCKOUT`, `404 USER_NOT_FOUND`.

### `PATCH /api/admin/access-bans/{id}`
Gövde (hepsi isteğe bağlı): `{"note":"...","expiresAt":"2026-12-31T00:00:00Z","noExpiry":true,"active":true}`. `noExpiry=true` süresiz yapar. Yanıt `200` `BanView`; yok → `404 BAN_NOT_FOUND`.

### `DELETE /api/admin/access-bans/{id}` → `204`
Engeli kaldırır (`active=false`; vuruş geçmişi korunur). Önbellek anında yenilenir. Yok → `404 BAN_NOT_FOUND`.

### `POST /api/admin/access-bans/bulk` (10 dakikada 10 istek)
VPN sağlayıcı aralıklarını toplu engeller.
```json
{"text":"# yorum\n198.51.100.0/24 sağlayıcı-A\n203.0.113.7\n2001:db8::/32","reasonCode":"ABUSE","note":"varsayılan not","expiresAt":null,"force":false}
```
Satır satır `IP-veya-CIDR [etiket]` (etiket satırın notu olur; boş ve `#` satırlar atlanır; ayraç boşluk/virgül/noktalı virgül). **En çok 5000** satır (aşarsa `400 BAN_BULK_TOO_LARGE`), hiç satır yoksa `400 BAN_INVALID_VALUE`. Yanıt `201`:
```json
{"created":3,"alreadyBanned":1,"closedSessions":2,
 "rejected":[{"line":5,"value":"bozuk-satir","error":"BAN_INVALID_VALUE"},{"line":6,"value":"10.0.0.0/8","error":"BAN_SELF_LOCKOUT"}]}
```
`line` 1 tabanlı metin satır numarası; `error`: `BAN_INVALID_VALUE` (bozuk) ya da `BAN_SELF_LOCKOUT` (özel ağ / izin listesi / kendi IP'niz).

### `GET /api/admin/access-bans/{id}/attempts?cursor=&size=`
Bu engele takılan son denemeler (en çok 90 gün; aynı engel+IP için dakikada en çok bir satır). Yanıt `200`:
```json
{"items":[{"id":901,"kind":"IP","ip":"198.51.100.9","deviceShort":null,"userId":null,"path":"/api/auth/login","at":"2026-10-27T11:20:31Z"}],"nextCursor":null}
```
`deviceShort` cihaz özetinin ilk 8 karakteri. Yok → `404 BAN_NOT_FOUND`.

### `GET /api/admin/access-bans/stats`
```json
{"activeBans":{"IP":4,"CIDR":2,"DEVICE":7,"USER":3},"anonymizerRanges":1500,"anonymizersEnforced":false,
 "blockedAttemptsLast24h":128,
 "topBans":[{"id":17,"kind":"CIDR","value":"198.51.100.0/24","note":"VPN sağlayıcı A","hitCount":42,"lastHitAt":"2026-10-27T11:20:31Z"}]}
```
`topBans` en çok vuran 5 engel (DEVICE değeri 8 karakterlik özet). `hitCount` bellekte toplanıp ~5 sn'de bir yazılır.

### `GET /api/admin/users/{id}/devices`
Kullanıcının son 90 gündeki cihazları (çoklu hesap tespiti). Yanıt `200`:
```json
{"userId":42,
 "devices":[{"deviceHash":"9f2c…(64 hane)","deviceShort":"9f2c41ab","platform":"ANDROID","appVersion":"1.4.2",
   "firstSeenAt":"2026-09-01T08:00:00Z","lastSeenAt":"2026-10-27T09:10:00Z","lastEvent":"REFRESH","seenCount":57,
   "firstIp":"198.51.100.1","lastIp":"198.51.100.2",
   "ips":[{"ip":"198.51.100.1","family":4,"firstSeenAt":"…","lastSeenAt":"…","seenCount":30,"blocked":false}],
   "blocked":false,"banId":null,
   "sharedWithUsers":[{"id":77,"displayName":"Diğer Hesap"}]}],
 "unidentifiedIps":[{"ip":"198.51.100.4","family":4,"firstSeenAt":"…","lastSeenAt":"…","seenCount":3,"blocked":false}]}
```
`sharedWithUsers`: aynı cihaz özetini kullanan diğer hesaplar (en çok 10). `unidentifiedIps`: `X-Device-Id` göndermeden görülen IP'ler (eski istemciler). `blocked`/`banId`: cihaz için etkin engel. Kullanıcı yok → `404 USER_NOT_FOUND`.

### `POST /api/admin/users/{id}/block-access`
Tek tıkla kullanıcı + cihazları + (istenirse) IP'leri engeller.
```json
{"devices":true,"ips":false,"userBan":true,"reasonCode":"ABUSE","note":"tekrarlayan ihlal","expiresAt":null,"force":false}
```
`userBan` verilmezse `true` kabul edilir. `devices`: son 90 günde görülen cihaz özetleri (cihaz başlığı olmayan kayıtlar atlanır); `ips`: son **30 gündeki** IP'ler (özel ağ/izin listesi/kendi IP'niz atlanır; paylaşımlı ya da CGNAT adres başka kullanıcıları da etkileyebilir, yanıtta `SHARED_IP_RISK` uyarısı gelir). Kullanıcının ve engellenen cihazı kullanan tüm hesapların oturumları kapanır, FCM kayıtları silinir. Yanıt `200` — `POST /access-bans` ile aynı biçim: `{"bans":[…],"devicesBlocked":2,"ipsBlocked":0,"sessionsClosedUsers":3,"warnings":[]}`. Yönetici hedefi → `400 BAN_SELF_LOCKOUT`; yok → `404 USER_NOT_FOUND`.

### Anonimleştirici ağlar (VPN / Tor / veri merkezi)
`BLOCK_ANONYMIZERS=true` iken yöneticinin yüklediği aralıklardan gelen istekler engellenir (varsayılan kapalı; liste yine de yönetilebilir). **Sunucu dış servise gitmez**; listeyi yönetici yükler (biçim ve Tor örneği: DEPLOY.md bölüm 8.1).

- `POST /api/admin/access-bans/anonymizers` `{"text":"185.220.101.0/24\n185.220.102.5 ozel-etiket","source":"tor-exit"}` → `201` `{"added":2,"duplicates":0,"rejected":[{"line":4,"value":"bozuk","error":"BAN_INVALID_VALUE"}]}`. Aynı satır/5000 sınırı ve `BAN_BULK_TOO_LARGE` geçerli; özel ağ satırı `BAN_SELF_LOCKOUT` ile reddedilir.
- `GET /api/admin/access-bans/anonymizers?cursor=&size=` (size ≤ 200) → `{"enforced":false,"total":1500,"bySource":{"tor-exit":1500},"items":[{"id":9,"cidr":"185.220.101.0/24","source":"tor-exit","addedAt":"…"}],"nextCursor":null}`.
- `DELETE /api/admin/access-bans/anonymizers/{id}` → `204` (yok → `404 BAN_NOT_FOUND`).
- `DELETE /api/admin/access-bans/anonymizers?source=tor-exit` → `200` `{"deleted":1500}` (boş `source` = etiketsizler; liste yenilemek için önce sil sonra yükle).

### Hata kodları (3 dilde `i18n/ops*.properties`)
`ACCESS_BLOCKED` (403; istemci mesajı "Bu cihaza veya ağa erişim kapatıldı."), `BAN_SELF_LOCKOUT` (400), `BAN_INVALID_VALUE` (400), `BAN_NOT_FOUND` (404), `BAN_BULK_TOO_LARGE` (400; `{0}` = 5000).

### Veri ve KVKK
`user_device_log` (kullanıcı, cihaz özeti, platform, sürüm, IP, ilk/son görülme, sayaç) ve `blocked_attempt_log` **90 gün** sonra gece 04:30'da silinir (`BAN_LOG_RETENTION_DAYS`); hesap silinince (anonimleştirme) kullanıcının cihaz/IP kayıtları anında silinir; `GET /api/users/me/export` içinde `accessHistory` bölümü (ham kimlik yok, 8 karakterlik özet) bulunur. Ham cihaz kimliği hiçbir yerde saklanmaz.

## Doğrulanmamış (bekleyen) kayıtlar

Kayıt, e-posta kodu doğrulanana kadar yalnızca Redis'te (`reg:<email>`) durur; `app_user` satırı yoktur, bu yüzden `GET /api/admin/users` listesinde görünmez. `ADMIN` + denetim kaydı.

- `GET /api/admin/pending-registrations?cursor=&size=&q=` (size 1..100, varsayılan 20; `q`: e-posta/okul numarası ya da ad içinde geçen, büyük/küçük harf duyarsız; e-postaya göre sıralı imleç: `cursor` = önceki cevabın `nextCursor`'u, null ise son sayfa) → `{items:[{email, displayName, faculty, department, grade, createdAtEpochSec, remainingSeconds, resendCount}], nextCursor}`. `email` yöneticiye TAM görünür. Şifre özeti dönmez. Redis SCAN kullanır.
- `DELETE /api/admin/pending-registrations/{email}` → `204` (e-posta ya da okul numarası; yoksa `404 NOT_FOUND`). Kaydı iptal eder; kullanıcı yeniden kayıt olabilir.
- `GET /api/admin/users?q=226051015` okul numarasıyla da bulur (e-posta `ILIKE %q%`).
- `POST /api/admin/pending-registrations/{email}/verify` → `201 {id, email, displayName, createdAt}` (path: tam e-posta ya da okul numarası). Kod GEREKTİRMEDEN hesabı oluşturur (`emailVerified=true`, kayıttaki ad/dil/fakülte/bölüm/sınıf/şifre özeti, sözleşme onayı `acceptTerms` varsayımıyla `legal_acceptance`'a yazılır), bekleyen kaydı ve doğrulama kodunu/kilidini siler. Bekleyen yoksa `404 PENDING_REGISTRATION_NOT_FOUND`; doğrulanmış hesap zaten varsa ya da benzersizlik ihlalinde `409 EMAIL_ALREADY_REGISTERED` (bekleyen kayıt silinir). Kullanıcı sonra normal girişle (e-posta/numara + kayıttaki şifre) girer.
- `POST /api/admin/pending-registrations/{email}/resend-code` → `204`. Yeni doğrulama kodu gönderir; 60 sn bekleme kuralı aynen geçerli (`429 RESEND_COOLDOWN`); yoksa `404 PENDING_REGISTRATION_NOT_FOUND`.
- Veritabanındaki doğrulanmamış satırlar (eski akışlar): `GET /api/admin/users?verified=false` ile listelenir; `POST /api/admin/users/{id}/verify-email` → `204` (idempotent) elle doğrular.
- Denetim kaydı: tüm bu POST/DELETE istekleri `AuditInterceptor` ile (hangi yönetici, hangi yol/e-posta) yazılır; ayrıca sunucu log'unda `ADMIN_VERIFY` satırı.

### Yönetici yetkileri (kullanıcı yönetimi)

Tüm uçlar yalnız `ADMIN` (JWT rolü ya da Basic) ve denetlenir. Kendini silme/rol düşürme `400 CANNOT_MODIFY_SELF`; son yönetici düşürme/silme `409 LAST_ADMIN`.

| İşlem | Uç |
|---|---|
| Ara (ad, e-posta, okul numarası; `verified`, `status`, `role` süzgeçleri) | `GET /api/admin/users?q=` |
| Askıya al / aç | `POST /api/admin/users/{id}/suspend`, `/unsuspend` |
| Rol değiştir | `PATCH /api/admin/users/{id}/role` |
| Sil (anonimleştir) | `DELETE /api/admin/users/{id}` |
| E-postayı elle doğrula | `POST /api/admin/users/{id}/verify-email` |
| Şifre sıfırlama kodu e-postası gönder (doğrulanmamışsa `409 USER_NOT_VERIFIED`; bekleme `429 RESEND_COOLDOWN`) | `POST /api/admin/users/{id}/send-reset` |
| Tüm oturumlarını kapat | `POST /api/admin/users/{id}/revoke-sessions` |
| Bekleyen kaydı doğrula / kod gönder / iptal | `POST .../pending-registrations/{email}/verify`, `/resend-code`, `DELETE .../{email}` |

## Uygunsuz ifade filtresi (`/api/admin/profanity`)

Herkese açık metin alanlarında (kulüp/etkinlik/profil/grup başlığı vb.) küfür, argo ve hakaret reddedilir; **sohbet mesajları (gövde/açıklama) filtrelenmez**. Yerleşik liste `backend/src/main/resources/moderation/profanity-{tr,en,ar}.txt` (LDNOOBW, CC-BY-4.0 + elle yazılmış kökler; ayrıntı `NOTICE.md`) ve izin listesi `profanity-allow-tr.txt`; yönetici kayıtları `profanity_term` tablosundadır (V300). Yerleşik liste silinemez; yanlış pozitif için yönetici **ALLOW** kaydı ekler. `ADMIN` + yazma istekleri denetim kaydına yazılır; rate limit: yazma 60/dk, check 120/dk (yönetici başına).

- `GET /api/admin/profanity?kind=BLOCK|ALLOW&q=&cursor=&size=` → `{items:[{id,term,kind,lang,note,createdBy,createdAt}], nextCursor}` (id azalan; `cursor` = önceki `nextCursor`; size 1..50).
- `POST /api/admin/profanity` `{term (2-80), kind, lang?: TR|EN|AR|ALL, note?}` → `201` kayıt. Hemen etkindir (bu örnekte anında, diğer örneklerde `app.moderation.profanity.cache-ttl-seconds` = 30 sn içinde). Söz dizimi: düz kelime = kök + en fazla 7 harflik ek; `=kelime` yalnızca tam eşleşme; `*kelime` metin içinde geçme; iki sözcük = tamlama. Hatalar: `400 PROFANITY_TERM_INVALID`, `409 PROFANITY_TERM_EXISTS`.
- `POST /api/admin/profanity/bulk` `{text (satır satır, en çok 500 satır), kind, lang?}` → `{added, skipped, invalid}` (`#` ile başlayan satırlar yok sayılır).
- `DELETE /api/admin/profanity/{id}` → `204` / `404 PROFANITY_TERM_NOT_FOUND`.
- `POST /api/admin/profanity/check` `{text}` → `{blocked, matches:[kök], normalized}` (test kutusu; eşleşmeyi YALNIZCA yöneticiye gösterir).
- `GET /api/admin/profanity/info` → `{builtIn:{tr,en,ar,allow,source}, adminBlock, adminAllow, settings:{enabled, mode}}`.
- `GET /api/admin/profanity/stats` → `{last24h:{total, byField:[{entity,field,count}]}, last7d:{...}}`. `profanity_hit_log` kelime SAKLAMAZ (alan, varlık, kullanıcı, zaman); 90 gün sonra gece 04:30'da silinir.
- `GET /api/admin/profanity/export.csv?kind=` → yöneticinin eklediği kayıtlar (CSV; hücre kaçışlı).

Ayarlar (salt okunur): `app.moderation.profanity.enabled` (varsayılan true), `mode` = `BLOCK` (varsayılan; 422 ile reddeder) | `FLAG` (engellemez, yalnızca istatistiğe `FLAG` yazar), `cache-ttl-seconds` (30). Web: `/admin/profanity`.

## Kulüp kategorileri (`/api/admin/community-categories`) — V550

Kulüp oluştururken seçilebilen **sınırlı** kategori listesi (`community_category`; en çok `app.community.max-categories` = 20 **aktif**). Yalnız ADMIN; yazmalar `AuditInterceptor` ile denetlenir; yazma hız sınırı 120/dk. `community.category` sütunu serbest metin olarak kalır ve kategorinin **`key`** değerini taşır (FK yok; eski değerler V550 ile aynen tabloya tohumlanır).

| Uç | Açıklama |
|---|---|
| `GET /` | `{items:[{id,key,nameTr,nameEn,nameAr,icon,sortOrder,active,usageCount,createdAt,updatedAt}], activeCount, maxActive}`; tümü (pasifler dahil), `sortOrder` sırasıyla; `usageCount` = silinmemiş kulüp sayısı |
| `POST /` (201) | `{key?, nameTr, nameEn?, nameAr?, icon?, active?}`; `key` boşsa Türkçe addan üretilir (`^[a-z0-9][a-z0-9-]{0,39}$`), en/ar boşsa tr; sona eklenir. `409 COMMUNITY_CATEGORY_KEY_TAKEN`, aktif sınır doluysa `409 COMMUNITY_CATEGORY_LIMIT` |
| `PUT /{id}` | adlar/simge/aktif güncellenir; **`key` değişmez** (gövdedeki yok sayılır). `404 COMMUNITY_CATEGORY_NOT_FOUND` |
| `PATCH /{id}/active` | `{active}`; pasiften aktife geçişte sınır denetlenir (`409 COMMUNITY_CATEGORY_LIMIT`) |
| `DELETE /{id}` (204) | kullanımda ise `409 COMMUNITY_CATEGORY_IN_USE` (mesajda kulüp sayısı; pasife alınmalı), değilse silinir |
| `PUT /order` | `{ids:[...]}` tüm kategorileri tekrarsız içermeli, aksi `400 COMMUNITY_CATEGORY_ORDER_INVALID`; yanıt `GET /` şekli |

Herkese açık okuma: `GET /api/communities/categories` (giriş gerekir) — ayrıntı `docs/changes/community.md`.

## Keşfet gönderileri moderasyonu (`/api/admin/posts`)

`ADMIN` (JWT) + denetim kaydı (yazma uçları ve `GET /api/admin/posts/media/{id}` önizlemesi `AuditInterceptor` ile yazılır). Hız sınırı: yönetici başına dakikada 120. Silinmiş/gizli içerik dahil hepsi görünür. Tasarım: [POSTS_DESIGN.md](POSTS_DESIGN.md), ayrıntı: [changes/post.md](changes/post.md).

**Karar:** gönderilerde **ilk gönderi onayı yoktur**; gönderi anında yayınlanır, yönetici sonradan denetler. Yorum, hikâye, #etiket/@bahsetme, kaydet ve video kaldırıldı (V470; bkz. `docs/changes/post.md`) — `/api/admin/comments`, `/api/admin/stories`, `/api/admin/hashtags` uçları yoktur.

- `GET /api/admin/posts?cursor=&size=&q=&status=&authorId=&minReports=&hasMedia=&from=&to=` (size 1..50, varsayılan 20; imleç = gönderi id, en yeni önce) → `{items:[PostRow], nextCursor}`.
  - `q`: **gönderi metni**, yazar adı veya e-postası (ILIKE; `\ % _` kaçışlı). `status`: `ALL` (varsayılan) | `VISIBLE` | `HIDDEN` (gizli, silinmemiş) | `DELETED`; geçersiz değer `400 VALIDATION_ERROR`. `authorId`: yazar. `minReports`: en az N **açık** şikâyeti olanlar. `from`/`to`: `YYYY-AA-GG` (Europe/Istanbul). Eski `hidden=`/`deleted=` boolean süzgeçleri geriye uyum için durur.
  - `PostRow`: `{id, author:{id,displayName,email,avatarUrl}, text, media:[{id,kind,url,thumbUrl,width,height,durationMs,hidden}], likeCount, mediaCount, hidden, deleted, hiddenReason, createdAt, editedAt, hiddenAt, deletedAt, deletedBy, openReportCount}`; medya adresleri `/api/admin/posts/media/{id}[?thumb=true]` (Bearer ile blob olarak alınır). `commentCount` kaldırıldı.
- `GET /api/admin/posts/{id}` → `{post: PostRow, reports:[{id, reason, note, status:"OPEN"|"RESOLVED", createdAt}]}` (bu gönderiye yapılan en çok 50 şikâyet; açıklar önce). `404 POST_NOT_FOUND`.
- `PATCH /api/admin/posts/{id}` `{text}` → `PostRow`. Metni düzenler (`editedAt` dolar, denetim kaydı, yazara yerelleştirilmiş bildirim `notif.post.adminedit`). Boş/boşluk metin = metin temizlenir (yalnız fotoğraflı gönderide; fotoğrafsız eski gönderide `400 POST_EMPTY`). Biçim kuralı yönetici için de geçerli: tek satır, en çok 7 kelime ve 60 karakter (`422 POST_TEXT_INVALID` / `POST_TEXT_TOO_LONG`); silinmiş gönderi `404`. **Küfür süzgeci (`ContentGuard`) yönetici düzenlemesinde bilerek ATLANIR**: yönetici ihlalli metni temizlemek için düzenler ve her düzenleme denetim kaydına yazılır; süzgeç yöneticiyi engellemez.
- `POST /api/admin/posts/{id}/hide` `{reason?}` → `PostRow` (idempotent; `hidden_at` + gönderi medyası erişime kapanır: `PostMediaService.hide`; yazara bildirim gitmez, geri alınabilir). `POST .../unhide` → `PostRow` (geri alır). 30 gündür gizli kalan gönderi gece işiyle yumuşak silinir.
- `DELETE /api/admin/posts/{id}` `{reason?}` (gövde isteğe bağlı) → `204`. Yumuşak silme + `PostDeletedEvent` (silinmişse `404`); medya/satırlar 30 gün sonra temizlenir (`PostMediaJanitor`, `PostRetentionJob`). `reason` yazara giden gerekçedir ve `post.hidden_reason`a yazılır. **Rapor entegrasyonu:** gönderinin açık `FEED_POST` şikâyeti varsa önce `ReportService.resolve(HIDE)` çağrılır (yazara `notif.mod.removed` bildirimi, tüm açık şikâyetler `RESOLVED/HIDE`, ihlal kaydı, raporlayanlara sonuç bildirimi); şikâyet yoksa yazara doğrudan `notif.mod.removed` gider.
- `GET /api/admin/posts/stats` → `{postCount, likeCount, mediaCount, hiddenCount, deletedCount, openReportedCount, last24h:{postCount, likeCount, mediaCount, hiddenCount, deletedCount}}` (`openReportedCount` = açık şikâyeti olan farklı gönderi sayısı).

Şikâyet kuyruğu: `targetType` `FEED_POST` (kullanıcı `POST /api/reports` ile bildirir; `FEED_COMMENT` ve `STORY` türleri kaldırıldı, eski kayıtları V470 siler). `GET /api/admin/reports/{id}` bağlamında `context.content` = `{kind:"FEED_POST", id, text, ownerId, imageUrl, deleted, status:"VISIBLE"|"HIDDEN"|"DELETED", createdAt, postId, media:[{id,kind,url,thumbUrl}]}`; kuyruk önizlemesi (`preview`) ilk medya ya da metindir. Karar `HIDE` → gönderi gizlenir (geri alınabilir: otomatik gizleme eşiği, itiraz ve reddetmede `unhide`); kalıcı kaldırma için gönderi ekranındaki **Sil** kullanılır (açık şikâyetleri birlikte sonuçlandırır).

## Akademik (`/api/admin/academic/*`, `/api/admin/announcements`)

Sözleşme: [API_CONTRACTS_V2.md](API_CONTRACTS_V2.md) "Akademik". Tüm uçlar yalnız ADMIN; yazma işlemleri denetim kaydına düşer.

- **Akademik takvim:** `GET|POST /api/admin/academic/events`, `GET|PATCH|DELETE .../{id}`, `POST .../{id}/publish|unpublish`, `POST .../import` (`{text, publish}`; satır `TÜR;Başlık;başlangıç;bitiş?;bölüm?`, geçerli satırlar yazılır, hatalar satır numarasıyla döner).
- **Resmi sınav programı:** `/api/admin/academic/exams` (aynı kalıp; `faculty|department|grade` boş = herkes).
- **Duyurular:** `GET|POST /api/admin/announcements` (`status=all|draft|scheduled|active|expired`), `GET|PATCH|DELETE .../{id}`, `publish|unpublish`, `GET .../audience-count?department&faculty&grade`. `notify=true` görünür olunca hedef kitleye bir kez push gönderir; `pinned` sabitler; `attachmentUrl` yalnız https.
- Gelecek: bölüm yetkilisi için `DEPT_ADMIN` rolü + `dept_admin_scope(user_id, department)` (bkz. `docs/changes/academic.md`). Şimdilik yalnız ADMIN.

## Anketler (`/api/admin/polls`) ve kalıcı push kuyruğu (`/api/admin/push/outbox`)

Anket (yalnız ADMIN; yazma işlemleri denetim kaydına yazılır; **sonuçlar her zaman görünür, kim ne oy verdi hiçbir uçta yoktur**, gizli ankette de aynıdır):

| Uç | Açıklama |
|---|---|
| `GET /api/admin/polls?status=&scope=&q=&page=0&size=20` | `{items:[{id,title,type,scope,communityId,status,state,anonymous,totalVotes,opensAt,closesAt,createdAt,createdBy}],page,size,total}` |
| `GET /api/admin/polls/{id}` | PollView (`resultsVisible=true`, sonuçlar dolu) |
| `POST /api/admin/polls/{id}/close` · `/cancel` | Erken kapat / iptal (oylar kapanır, sonuçlar korunur) |
| `DELETE /api/admin/polls/{id}` | 204; anket, seçenek ve oylar kalıcı silinir |
| `POST /api/admin/polls/bulk` `{ids:[..],action:"CLOSE|CANCEL|DELETE"}` | `{done,skipped}` (en çok 100) |
| `GET /api/admin/polls/stats` | `{total,open,closed,draft,cancelled,totalVotes,byScope,avgTurnoutPercent}` |
| `GET /api/admin/polls/{id}/export.csv` | `optionId,text,count,percent,score` (kimliksiz; hücre kaçışlı, formül önekli hücreler `'` ile etkisizleştirilir) |

Yönetici anketi oluşturmak için kullanıcı uçlarını kullanır: `POST /api/polls` (JWT ADMIN; `scope=GLOBAL|MENU`). Basic auth ile oluşturulamaz (oluşturan kimliği gerekir).

**Düzenleme** de kullanıcı ucudur: `PATCH /api/polls/{id}` (JWT ADMIN her ankete yetkilidir; yalnız verilen alanlar değişir, `closesAt:""` kapanışı kaldırır, taslakta `draft:false` yayınlar). Oy alınmış açık ankette yapısal alanlar (tür, seçenekler, gizlilik, hedef kitle, açılış, oy değiştirme) `409 POLL_LOCKED`, kapalı ankette `409 POLL_CLOSED`. **Web paneli (P03)** bu sözleşmeyi birebir kullanır (`web/src/api/adminPolls.ts`); menü puanlamaları ayrı uç değildir: `GET /api/admin/polls?scope=MENU` listesi + `GET /{id}` içindeki `average`/`results`. Silme/iptal/kapatma ve toplu işlemde sebep `X-Admin-Reason` başlığıyla gider (toplu uçta zorunlu, bkz. AdminGuardPolicy).

Push kuyruğu:

| Uç | Açıklama |
|---|---|
| `GET /api/admin/push/outbox/stats` | `{enabled,holdWhenDisabled,pending,sending,failed,dead,sentLast24h,oldestPendingAgeSeconds,oldestPendingAt}` (`pending` = PENDING, `failed` = geri çekilmede bekleyen) |
| `POST /api/admin/push/outbox/retry-dead` | `{requeued:n}`: DEAD kayıtlar PENDING'e döner, deneme sayacı sıfırlanır |

Sağlık: `/actuator/health` → `pushQueue` (`pending`, `sending`, `dead`, `oldestPendingAgeSeconds`; ölü kayıt ya da 15 dk'dan eski bekleyen varsa `WARN`).


## Etkinlik moderasyonu (`/api/admin/events`) — V460

Etkinlik kötüye kullanımına karşı yöneticiye gizleme/iptal ve süzmeli liste eklendi. Tüm uçlar yalnız ADMIN (JWT `ROLE_ADMIN` ya da Basic auth); hız sınırı **60/dk** (yönetici başına, 429 + `Retry-After`); POST'lar `AuditInterceptor` ile denetim kaydına yazılır (yol + yöntem + durum) ve **sebep** ayrıca `event_moderation_log` tablosuna (yönetici, geçiş, sebep) yazılır; detayda `history` olarak döner.

### Durum makinesi (`UserEvent.Status`)

| Mevcut durum | Uç | Yeni durum | Bildirim | Not |
|---|---|---|---|---|
| `PENDING_REVIEW` | `POST /{id}/approve` | `ACTIVE` | sahibe "onaylandı" | mevcut |
| `PENDING_REVIEW` | `POST /{id}/reject` `{reason?}` | `REJECTED` | sahibe "reddedildi" | mevcut; diğer durumlarda 409 `NOT_PENDING` |
| `ACTIVE` | `POST /{id}/hide` `{reason}` | `HIDDEN` | **yok** | sessiz, geri alınabilir |
| `HIDDEN` | `POST /{id}/unhide` `{reason}` | `ACTIVE` | yok | |
| `ACTIVE` / `PENDING_REVIEW` / `HIDDEN` | `POST /{id}/cancel` `{reason}` | `CANCELLED` | katılımcılara + istek sahiplerine `notif.event.cancelled` (ACTIVE/HIDDEN iken, etkinlik bitmediyse); **sahibe sebepli** `notif.event.cancelledByAdmin` | sohbet odası kapanır, bekleyen başvurular kapanır, kapak görseli bırakılır, hatırlatmalar durur (yalnız ACTIVE'e gider) |
| `REJECTED`, `CANCELLED` | hide/unhide/cancel | — | — | 409 `EVENT_INVALID_TRANSITION` |

`HIDDEN` etkinlik: listelerden, takvimden, "öne çıkan"dan, genel aramadan, "etkinliklerim"den düşer; doğrudan erişimde (`GET /api/events/{id}`, RSVP, düzenleme, silme, QR/yoklama) herkese — **organizatör dahil** — 404 `EVENT_NOT_FOUND` (yalnız yönetici görür); sohbet odası erişimi kapanır (ACTIVE şartı). `unhide` ile aynen geri gelir.

### `GET /api/admin/events` — süzmeli liste

Sorgu: `status` (`PENDING_REVIEW` varsayılan — eski davranış | `ACTIVE` | `REJECTED` | `CANCELLED` | `HIDDEN` | `ALL`; büyük/küçük harf fark etmez), `q` (en çok 100 karakter; başlık / yer / kulüp adı / organizatör adı; Türkçe harf duyarsız: `I`, `ı`, `İ`, `i` hepsi eşleşir; `%`/`_` düz karakterdir), `communityId`, `standalone=true` (kulüpsüz), `joinPolicy` (`OPEN`|`APPROVAL`), `from` / `to` (ISO-8601 anlık, `2026-11-01T00:00:00Z`; etkinlik **başlangıcı** `[from, to)`), `cursor` (önceki sayfanın `nextCursor`'ı), `size` (varsayılan 20). Sıralama sabit: id azalan. Gövde: `{items: EventView[], nextCursor}`. `EventView` mevcut sözleşmedir; yönetici listesinde `canManage=true` ve `pendingCount` (bekleyen katılım isteği, APPROVAL dışında 0) **her** etkinlik için doludur. Hatalar: 400 `VALIDATION_ERROR` (bilinmeyen `status`), 400 `INVALID_DATES` (`to <= from`).

### `GET /api/admin/events/{id}` — detay

```json
{
  "event": { "...EventView...": "status, communityName, organizer, joinPolicy, goingCount, interestedCount, capacity, pendingCount" },
  "organizerEmail": "ogrenci@bingol.edu.tr",
  "requests": {"pending": 2, "waitlisted": 0, "accepted": 1, "rejected": 0, "cancelled": 0},
  "attendedCount": 0,
  "reviewNote": null,
  "moderationReason": "Uygunsuz içerik",
  "moderatedBy": 7,
  "moderatedAt": "2026-10-28T10:00:00Z",
  "history": [{"id": 3, "adminId": 7, "adminName": "Yönetici", "action": "HIDE", "fromStatus": "ACTIVE", "toStatus": "HIDDEN", "reason": "Uygunsuz içerik", "createdAt": "2026-10-28T10:00:00Z"}],
  "allowedActions": ["unhide", "cancel"]
}
```

`history` son 20 kayıt (yeniden eskiye); `action`: `HIDE | UNHIDE | CANCEL | REPORT_HIDE | REPORT_UNHIDE` (`REPORT_*`: şikâyet çözümlemesi, `adminId` null olabilir). `allowedActions`: `PENDING_REVIEW` → `approve, reject, cancel`; `ACTIVE` → `hide, cancel`; `HIDDEN` → `unhide, cancel`; `REJECTED`/`CANCELLED` → boş. Web düğmeleri bunu esas almalıdır.

### `POST /api/admin/events/{id}/hide | unhide | cancel`

Gövde zorunlu: `{"reason": "…"}` (boş olamaz, ≤ 300 karakter; aşarsa 400 `VALIDATION_ERROR`). Yanıt `200` ve detay gövdesi (yukarıdaki). Hatalar: 404 `EVENT_NOT_FOUND`, 409 `EVENT_INVALID_TRANSITION` (geçersiz geçiş), 429 hız sınırı, 403 yönetici değil. `approve`/`reject` hâlâ `204`.

### Şikâyet entegrasyonu

`ReportTargetHandler` (EVENT) artık geri alınabilirdir: rapor `HIDE` ile çözülünce/eşik aşılınca yalnız `ACTIVE` etkinlik `HIDDEN` olur (geçmişe `REPORT_HIDE`); itiraz kabulü/rapor reddi `unhide` çağırır (`REPORT_UNHIDE`). `PENDING_REVIEW`/`CANCELLED`/`REJECTED` etkinlikler şikâyetle değiştirilmez.

### Hata kodları (3 dilde `i18n/event*.properties`)

`EVENT_INVALID_TRANSITION` (409; `{0}`=mevcut durum, `{1}`=işlem). Bildirim anahtarı: `notif.event.cancelledByAdmin` (`{0}` başlık, `{1}` sebep).


## Mail şablonları ve kampanyaları (`/api/admin/mail/*`) — V430

Yöneticiler veritabanında adlandırılmış, sürümlü **duyuru e-posta şablonları** tanımlar ve bunları **toplu/seçili** kullanıcılara gönderir. Yalnız ADMIN (`/api/admin/**`); yazma/önizleme/test uçları yönetici kimliği ister (**JWT ile giriş**; Basic auth 401 alır). Tüm yazma uçları denetim kaydına düşer (`AuditInterceptor`). Hata gövdesi her zaman `{code,message}` (istek dilinde; `Accept-Language`). Liste yanıtları sayfa tabanlıdır: `{items, page (0 tabanlı), totalPages, totalItems}`.

Mimari: şablon `mail_template_custom` (üst kayıt) + `mail_template_custom_version` (değişmez sürümler); kampanya `mail_campaign` + alıcı satırları `mail_campaign_recipient` (`UNIQUE(campaign_id,user_id)`; **yalnız kullanıcı kimliği, e-posta metni saklanmaz**). Zamanlayıcı (`app.mail.campaign-poll-ms`, 10 sn; `SchedulerLock` + `FOR UPDATE SKIP LOCKED`) zamanı gelen kampanyanın alıcılarını çözer ve partiler halinde (`app.mail.campaign-batch`, 200) `MailService.enqueue(..., MailTemplate.CUSTOM, ...)` ile kuyruğa yazar (kategori ANNOUNCEMENT: abonelikten çık alt bilgisi, bastırma listesi, gönderim hızı sınırı mail kuyruk işçisindedir). Her alıcı için "QUEUED" işareti ve kuyruk satırı tek transaction'dadır: çift tıklama / yeniden çalıştırma / iki örnek durumunda aynı kişiye ikinci e-posta oluşmaz.

### Değişkenler

`GET /api/admin/mail/variables` → `{variables:[{name,placeholder,description,automatic}], maxHtmlLength:100000, maxSubjectLength:200}`. İzinli küme (başka değişken yok; yönetici özel anahtar-değer tanımlayamaz): `{{ad}}`, `{{eposta}}`, `{{bolum}}`, `{{fakulte}}`, `{{sinif}}`, `{{uygulamaUrl}}`, `{{abonelikCikUrl}}`. `{{ ad }}` (boşluklu) yazımı `{{ad}}` olarak normalize edilir; `{{{ad}}}` ve dengesiz `{{` reddedilir. HTML'de değerler **HTML kaçışlı** yerleştirilir, düz metinde olduğu gibi. Her duyuru e-postasına abonelikten çık bağlantısı kuyruk işçisi tarafından **otomatik** eklenir (şablonda ayrıca `{{abonelikCikUrl}}` kullanmak isteğe bağlıdır). Konu, mevcut `layout.html` başlık alanında da gösterilir.

### Şablon uçları

| Uç | Açıklama |
|---|---|
| `GET /templates?status=DRAFT\|PUBLISHED\|ARCHIVED&q=&page=0&size=20` | Liste (`size` en çok 100). `q` addın içinde arar (büyük/küçük harf duyarsız) → `TemplateRow` |
| `GET /templates/{id}` | Ayrıntı (geçerli sürümün tüm dil içerikleri) → `TemplateView` |
| `GET /templates/{id}/versions` | `[{version, createdBy, createdAt}]` (yeni → eski) |
| `POST /templates` (201) | Oluştur (TASLAK, sürüm 1). Saatte 60 yazma |
| `PUT /templates/{id}` | Ad/açıklama her zaman; **içerik değiştiyse yeni sürüm** (aynı içerik → sürüm artmaz). ARCHIVED düzenlenemez (409). Durum korunur |
| `POST /templates/{id}/publish` | TASLAK/ARŞİV → YAYINDA (tr konu + gövde şart). İdempotent |
| `POST /templates/{id}/archive` | → ARŞİV (yeni kampanyada kullanılamaz; mevcutlar sürüme sabit olduğu için etkilenmez) |
| `DELETE /templates/{id}` (204) | Hiçbir kampanyada kullanılmamışsa sil; aksi halde 409 `MAIL_TEMPLATE_IN_USE` (arşivleyin) |
| `POST /templates/preview` | **Kaydetmeden** önizleme (editör canlı önizleme). Saatte 240 |
| `POST /templates/{id}/preview` | Kayıtlı sürümü önizle. Saatte 240 |
| `POST /templates/{id}/test` (202) | Test e-postası **yalnız isteyen yöneticinin kendi adresine** (konu başına `[TEST] `). Saatte 10 |

İstek `TemplateRequest` (oluştur/güncelle aynı):

```json
{
  "name": "Bahar şenliği duyurusu",
  "description": "Genel duyuru şablonu",
  "tr": { "subject": "Merhaba {{ad}}, şenlik başlıyor", "html": "<h2>Bahar Şenliği</h2><p>Sevgili {{ad}} ({{bolum}}), ...</p><a href=\"{{uygulamaUrl}}\">Uygulamayı aç</a>", "text": null },
  "en": { "subject": "Hello {{ad}}", "html": "<p>Hi {{ad}}, ...</p>", "text": null },
  "ar": null
}
```

- `tr` zorunlu; `en`/`ar` yoksa (`null` ya da tüm alanlar boş) o dilin alıcılarına **tr içeriği** gider (kampanya raporunda `languageFallback`). Bir dil verilirse `subject` (≤200) ve `html` (≤100000) zorunludur; `text` boşsa HTML'den üretilir (satır sonları, `- ` madde işareti, bağlantı `metin (https://...)`).
- **HTML güvenliği (sunucuda, kaydederken):** `script/style/iframe/object/embed/form/input/svg/meta/link...` ve tüm `on*` olay öznitelikleri silinir; bağlantı (`a href`) ve görsel (`img src`) **yalnız https**; `a` etiketlerine `rel="noopener noreferrer nofollow"` zorlanır; `style` özniteliği serbest ama `expression()`, `javascript:`, `vbscript:`, `@import`, `behavior`, `-moz-binding`, ters eğik çizgi içerenler ve https olmayan `url()` içerenler öznitelikle birlikte atılır. Yanıttaki `html` zaten temizlenmiş halidir.

`TemplateView` (oluştur/güncelle/ayrıntı/yayınla/arşivle yanıtı):

```json
{ "id": 7, "name": "Bahar şenliği duyurusu", "description": "...", "category": "ANNOUNCEMENT",
  "status": "PUBLISHED", "version": 2,
  "tr": { "subject": "...", "html": "<h2>...", "text": "..." }, "en": { "subject": "...", "html": "...", "text": "..." }, "ar": null,
  "languages": ["tr","en"], "variablesUsed": ["ad","bolum","uygulamaUrl"],
  "createdBy": 1, "createdAt": "2026-10-28T10:00:00Z", "updatedAt": "2026-10-28T10:05:00Z" }
```

`TemplateRow`: `{id,name,description,category,status,version,languages,updatedAt}`. `status`: `DRAFT` | `PUBLISHED` | `ARCHIVED`.

Önizleme isteği: `POST /templates/preview` → `{ "lang": "en", "content": { "subject": "...", "html": "...", "text": null } }`; `POST /templates/{id}/preview` → `{ "lang": "ar", "version": 1 }` (gövde isteğe bağlı → tr, geçerli sürüm). Yanıt `PreviewView`:

```json
{ "lang": "ar", "usedLang": "tr", "fallback": true, "subject": "Merhaba Ayşe Yılmaz, ...",
  "html": "<!DOCTYPE html>... (layout sarmalı, tam sayfa)", "text": "...",
  "sampleVariables": { "ad": "Ayşe Yılmaz", "eposta": "ayse.yilmaz@bingol.edu.tr", "bolum": "Bilgisayar Mühendisliği", "fakulte": "Mühendislik Fakültesi", "sinif": "2", "uygulamaUrl": "https://...", "abonelikCikUrl": "https://.../abonelik-onizleme" } }
```

`html` tam e-posta belgesidir; admin panelinde **sandbox'lı `iframe srcdoc`** ile gösterin (kendi sayfanıza `innerHTML` basmayın). Not: önizlemede abonelikten çık alt bilgisi görünmez (gerçek gönderimde kuyruk işçisi ekler). Test gönderimi yanıtı `TestSendView`: `{queued:true, lang, usedLang, to:"a***@bingol.edu.tr"}`.

### Kampanya uçları

| Uç | Açıklama |
|---|---|
| `GET /campaigns?status=&q=&page=0&size=20` | Liste (en yeni önce) → `CampaignView` (sayaçlarla) |
| `GET /campaigns/{id}` | Detay + sayaçlar |
| `GET /campaigns/{id}/recipients?status=FAILED\|SKIPPED\|QUEUED\|PENDING\|CANCELLED&page=0&size=50` | Alıcı raporu / hata listesi, **adres maskeli** → `RecipientRow` |
| `POST /campaigns/audience/preview` | Hedef kitle önizleme (kayıt yazmaz). Saatte 120 |
| `POST /campaigns` (201) | Kampanya kaydı (TASLAK). Saatte 30 |
| `PUT /campaigns/{id}` | Yalnız TASLAK (aksi 409 `MAIL_CAMPAIGN_NOT_EDITABLE`) |
| `POST /campaigns/{id}/schedule` (202) | Zamanla / şimdi gönder. Saatte 20 |
| `POST /campaigns/{id}/pause` · `/resume` · `/cancel` | Duraklat / devam / iptal. Saatte 60 |

`CampaignRequest` (oluştur ve güncelle):

```json
{ "name": "Bahar şenliği - Mühendislik", "templateId": 7,
  "audience": { "type": "FILTER", "filter": { "faculty": "Mühendislik Fakültesi", "classYear": 2 } },
  "scheduledAt": "2026-11-01T09:00:00+03:00", "requestKey": "form-ac-2c1f..." }
```

- `templateId`: **YAYINDA** olmalı (`MAIL_TEMPLATE_NOT_PUBLISHED`). Kampanya, zamanlandığı andaki **şablon sürümüne sabitlenir** (`templateVersion`); sonradan şablon güncellenirse bu kampanya etkilenmez.
- `audience.type`: `ALL` (tüm aktif + e-postası doğrulanmış kullanıcılar) · `FILTER` (`filter`: `faculty`, `department`, `classYear` 0-8, `role` `USER|ADMIN`, `language` `tr|en|ar`, `communityId` (aktif üyeler); alanlar VE ile birleşir, **en az biri dolu olmalı**; fakülte/bölüm büyük-küçük harf duyarsız tam eşleşme) · `USERS` (`userIds`, en çok 2000) · `EMAILS` (`emails`, en çok 2000; **yalnız kayıtlı kullanıcılarla eşleşir**, kayıtsız/bozuk adres kampanyaya eklenmez ve `unmatched` olarak sayılır; adres metni saklanmaz). Hiç eşleşen yoksa `MAIL_CAMPAIGN_NO_RECIPIENTS`; hatalı filtre/liste `MAIL_CAMPAIGN_AUDIENCE_INVALID`.
- `scheduledAt` ISO-8601 (Europe/Istanbul için `+03:00` ofseti gönderin; sunucu UTC anı olarak saklar). Boş/geçmiş = hemen. En çok 90 gün ilerisi (`MAIL_CAMPAIGN_SCHEDULE_INVALID`). `schedule` gövdesi isteğe bağlı: `{ "scheduledAt": "..." }` zamanı geçersiz kılar.
- `requestKey` (≤64, isteğe bağlı): aynı yönetici + aynı anahtar ile tekrar `POST /campaigns` **aynı kampanyayı** döndürür (çift tıklama koruması). Web: form açıldığında bir kez üretin.
- `schedule` idempotenttir: ZAMANLANDI/GÖNDERİLİYOR/BİTTİ kampanyada ikinci çağrı değişiklik yapmaz (ZAMANLANDI + henüz çözülmemişse yeni `scheduledAt` zamanı günceller). Hedefte gönderilecek kimse yoksa 400 `MAIL_CAMPAIGN_NO_RECIPIENTS`.

`AudiencePreviewRequest`: `{ "audience": {...}, "templateId": 7 }` (`templateId` isteğe bağlı; verilirse dil geri düşüşü hesaplanır). Yanıt:

```json
{ "total": 1240, "willSend": 1198, "skipped": 42,
  "skippedByReason": { "SUPPRESSED": 30, "INACTIVE": 8, "DUPLICATE_ADDRESS": 2, "INVALID_ADDRESS": 2 },
  "unmatched": 3, "languages": { "tr": 1100, "en": 80, "ar": 18 }, "languageFallback": 12 }
```

`languages` gönderilecek alıcıların **kullanılacak** dili (şablonda dili olmayanlar tr sayılır), `languageFallback` kaç alıcının dilinde içerik olmadığından tr'ye düştüğüdür. ALL/FILTER'da askıdaki, silinmiş ve e-postası doğrulanmamış kullanıcılar hiç hedefe girmez; USERS/EMAILS'te seçilmiş olup uygun olmayanlar `INACTIVE` olarak atlanmış sayılır.

`CampaignView`:

```json
{ "id": 12, "name": "Bahar şenliği - Mühendislik", "templateId": 7, "templateName": "Bahar şenliği duyurusu", "templateVersion": 2,
  "status": "SENDING",
  "audience": { "type": "FILTER", "filter": { "faculty": "Mühendislik Fakültesi", "department": null, "classYear": 2, "role": null, "language": null, "communityId": null }, "userCount": null, "unmatched": 0 },
  "scheduledAt": "2026-11-01T06:00:00Z", "resolvedAt": "2026-11-01T06:00:11Z", "startedAt": "2026-11-01T06:00:10Z", "finishedAt": null,
  "createdBy": 1, "createdAt": "2026-10-28T10:10:00Z", "updatedAt": "2026-11-01T06:00:40Z", "error": null,
  "counters": { "target": 1240, "pending": 400, "queued": 800, "skipped": 38, "failed": 2, "cancelled": 0,
                "skippedByReason": { "SUPPRESSED": 30, "INACTIVE": 8 }, "languages": { "tr": 1100, "en": 80, "ar": 0 },
                "languageFallback": 12, "progressPercent": 67 } }
```

- `status`: `DRAFT` (taslak) → `SCHEDULED` (zamanlandı) → `SENDING` (gönderiliyor) → `DONE` (bitti); yan durumlar `PAUSED` (duraklatıldı), `CANCELLED` (iptal), `FAILED` (sistem hatası; `error` dolu). Geçişler: `pause` SCHEDULED/SENDING'den; `resume` PAUSED'dan (alıcılar çözülmüşse SENDING, değilse SCHEDULED); `cancel` DRAFT/SCHEDULED/SENDING/PAUSED'dan (bekleyen alıcılar CANCELLED olur; zaten gönderilenler geri alınmaz); DONE/FAILED iptal edilemez (409 `MAIL_CAMPAIGN_INVALID_STATE`). Aynı duruma tekrar geçiş isteği (pause→pause, cancel→cancel) etkisizdir ve 200 döner.
- Sayaçlar alıcı satırlarından **türetilir** (sapma olmaz): `target` = alıcı satırı sayısı (atlananlar dahil) = `pending+queued+skipped+failed+cancelled`. `queued` = e-posta kuyruğuna alınan ("gönderilen"; gerçek SMTP teslimi ve sonradan bastırılan/geri dönen adresler kuyruk işçisinin sorumluluğundadır, `/actuator/health` `mailQueue`). `skippedByReason`: `SUPPRESSED` (abonelikten çıkmış/bounce/şikâyet), `INACTIVE` (askıda/silinmiş/doğrulanmamış seçilmiş kullanıcı), `DUPLICATE_ADDRESS`, `INVALID_ADDRESS`. `failed`: kuyruğa yazılamadı (`errorCode` `MAIL_UNAVAILABLE` / `ENQUEUE_ERROR`). `audience.userCount`: USERS/EMAILS'te eşleşen kullanıcı sayısı, diğerlerinde `null`. `progressPercent` = `pending` dışındakilerin oranı.

`RecipientRow`: `{userId, status (PENDING|QUEUED|SKIPPED|FAILED|CANCELLED), skipReason, errorCode, lang, langFallback, email ("a***@bingol.edu.tr"), updatedAt}`.

### Hata kodları (3 dilde `i18n/mailadmin*.properties`)

| Kod | HTTP | Anlam |
|---|---|---|
| `MAIL_TEMPLATE_INVALID` | 400 | Konu/gövde/yer tutucu geçersiz (`{0}` = alan: `subject`, `html`, `text`, `placeholder`, `tr`...) |
| `MAIL_TEMPLATE_VARIABLE_UNKNOWN` | 400 | İzinli kümede olmayan `{{x}}` (`{0}` = ad) |
| `MAIL_TEMPLATE_NOT_FOUND` | 404 | |
| `MAIL_TEMPLATE_NOT_EDITABLE` | 409 | Arşivlenmiş şablon düzenlenemez |
| `MAIL_TEMPLATE_NOT_PUBLISHED` | 409 | Kampanya için şablon YAYINDA olmalı |
| `MAIL_TEMPLATE_IN_USE` | 409 | Kampanyada kullanılmış şablon silinemez |
| `MAIL_CAMPAIGN_NOT_FOUND` | 404 | |
| `MAIL_CAMPAIGN_NOT_EDITABLE` | 409 | Yalnız TASLAK düzenlenir |
| `MAIL_CAMPAIGN_NO_RECIPIENTS` | 400 | Hedefte gönderilecek kimse yok |
| `MAIL_CAMPAIGN_AUDIENCE_INVALID` | 400 | Boş/hatalı filtre, liste sınırı (2000) aşımı |
| `MAIL_CAMPAIGN_SCHEDULE_INVALID` | 400 | 90 günden ileri |
| `MAIL_CAMPAIGN_INVALID_STATE` | 409 | Durum bu işlem için uygun değil |
| `MAIL_UNAVAILABLE` | 503 | Test e-postası kuyruğa yazılamadı (mevcut kod) |
| Hız sınırı (mevcut 429 + `Retry-After`) | 429 | |

### KVKK / saklama

Alıcı satırlarında yalnız `user_id` tutulur (e-posta metni yok; `EMAILS` hedefi kimliğe çevrilip yalnız kimlik saklanır). Biten/iptal edilen kampanyalar ve alıcı satırları `app.mail.campaign-retention-days` (180) gün sonra gece 03:20'de silinir; kullanıcı hesabını silince alıcı satırları silinir (`AccountDataPurger`). Kampanya `audience_value` alanındaki kullanıcı kimlikleri (USERS/EMAILS) hesap silindikten sonra anonimleştirilmiş satırı gösterir; kampanya saklama süresiyle birlikte silinir.


### Etkinlik oluşturma kuralı (kulüp zorunlu) ve yönetici düzenleme/silme

**Oluşturma (`POST /api/events`)**: `communityId` zorunludur; yoksa `400 EVENT_CLUB_REQUIRED` (admin dahil; bağımsız etkinlik açılamaz — mevcut kulüpsüz kayıtlar olduğu gibi kalır, listelenir, yönetilebilir). Tarih/geçmiş doğrulamaları kulüp denetiminden önce çalışır (`INVALID_DATES`, `PAST_EVENT`).

| Oluşturan | Sonuç |
|---|---|
| Kulüp OWNER / ADMIN / MODERATOR (ya da `MANAGE_EVENTS` yetkili, rolü MEMBER değil) ve sistem ADMIN'i | `ACTIVE` (onay gerekmez) |
| Sade `MEMBER` + özel `MANAGE_EVENTS` verilmiş (ör. `EVENT_MANAGER` şablonu) | `PENDING_REVIEW` → yönetici `approve`/`reject` eder |
| Sade `MEMBER` (izin yok), üye olmayan | `403 FORBIDDEN` |
| Kulüp aktif değil | `409 COMMUNITY_NOT_ACTIVE` |

**Yönetici düzenleme `PATCH /api/admin/events/{id}`** (60/dk, denetlenir): gövde `{title?, description?, startsAt?, endsAt?, location?, capacity?, joinPolicy?, reason?}` (`capacity=0` sınırsız; `reason` isteğe bağlı ≤ 300, geçmişe `EDIT` yazılır). Kurallar `EventService.update` ile aynı: yalnız `ACTIVE`/`PENDING_REVIEW` (aksi `409 EVENT_NOT_EDITABLE`), bitmişse `409 EVENT_ENDED`, kapasite katılımcıdan az olamaz `409 CAPACITY_TOO_LOW`, başlamış etkinliğin başlangıcı `409 EVENT_STARTED`; saat/yer değişirse katılımcılara `notif.event.updated`. Yanıt `200` + detay.

**Yönetici silme `DELETE /api/admin/events/{id}?reason=…`** (`reason` zorunlu ≤ 300; `204`): **yumuşak silme** — satır fiziksel silinmez (RSVP, yoklama, sertifika, KVKK dışa aktarımı ve denetim geçmişi buna bağlı); durum `CANCELLED` olur. Yan etkiler `cancel` ile aynı (katılımcı/istek sahibi `notif.event.cancelled`, sahibe sebepli `notif.event.cancelledByAdmin`, sohbet odası kapanır, kapak bırakılır); geçmişe `DELETE` yazılır. `ACTIVE`/`PENDING_REVIEW`/`HIDDEN` dışında `409 EVENT_INVALID_TRANSITION`. `cancel` ile fark: yalnız geçmişteki `action` ve HTTP şekli (204, gövdesiz).

`allowedActions` artık `edit` ve `delete` da içerir: `PENDING_REVIEW` → `approve, reject, edit, cancel, delete`; `ACTIVE` → `edit, hide, cancel, delete`; `HIDDEN` → `unhide, cancel, delete`; `REJECTED`/`CANCELLED` → boş.

**Kulüp yetkilileri** (mevcut mantık, değişmedi, test edildi): etkinliği oluşturan, ortak organizatörler ve kulüpte `MANAGE_EVENTS` yetkisi olanlar (MODERATOR+) `PATCH /api/events/{id}` ile düzenler, `DELETE /api/events/{id}` ile iptal (= yumuşak silme + bildirim) eder; yetkisiz `403`. `HIDDEN` etkinlik organizatöre de 404'tür.

Yeni hata kodu: `EVENT_CLUB_REQUIRED` (400; `i18n/event*.properties` tr/en/ar). `event_moderation_log.action` değerleri: `HIDE, UNHIDE, CANCEL, DELETE, EDIT, REPORT_HIDE, REPORT_UNHIDE`.


## Sistem durumu (`/api/admin/system/**`, yalnız ADMIN)

Paket `observability`. Yazma (POST) uçları denetim kaydına düşer; hız sınırı: okuma 120/dk, yazma 30/10 dk.

### `GET /api/admin/system/overview`

Tüm göstergeler tek yanıtta. Her gösterge `{status: OK|WARN|CRIT|UNKNOWN, value, threshold, message}`; `message` yalnız OK değilse dolu ve istek dilindedir (`Accept-Language` tr/en/ar). `UNKNOWN` = ölçülemiyor/henüz veri yok (uyarı tetiklemez). `overall` = bilinen göstergelerin en kötüsü.

```json
{
  "generatedAt": "2026-10-28T10:00:00Z",
  "overall": "CRIT",
  "indicators": {
    "mail.dead":             {"status":"CRIT","value":25,"threshold":{"warn":1,"crit":20},"message":"25 kayıt ölü (DEAD) durumda; inceleyip yeniden deneyin."},
    "mail.pending":          {"status":"OK","value":3,"threshold":null,"message":null},
    "mail.oldestPendingAge": {"status":"WARN","value":900,"threshold":{"warn":600,"crit":1800},"message":"En eski bekleyen kayıt 15 dakikadır gönderilmedi."},
    "push.dead": {}, "push.pending": {}, "push.oldestPendingAge": {},
    "campaign.overdue":      {"status":"OK","value":0,"threshold":{"warn":600,"crit":1800},"message":null},
    "campaign.counts":       {"status":"OK","value":{"SENT":12,"SCHEDULED":1},"threshold":null,"message":null},
    "websocket.sessions":    {"status":"OK","value":42,"threshold":null,"message":null},
    "db":                    {"status":"OK","value":4,"threshold":{"warn":1000},"message":null},
    "redis":                 {"status":"OK","value":1,"threshold":null,"message":null},
    "fcm":                   {"status":"UNKNOWN","value":null,"threshold":null,"message":"Push (FCM) kapalı veya yapılandırılmamış."},
    "disk.storage":          {"status":"OK","value":41.5,"threshold":{"warn":80,"crit":90},"message":null},
    "backup.age":            {"status":"UNKNOWN","value":null,"threshold":{"warn":3,"crit":6},"message":"Yedek durum dosyası yok veya okunamadı."},
    "jobs.mail-queue":       {"status":"OK","value":3,"threshold":{"warn":120,"crit":360},"message":null}
  }
}
```

Birimler: `*Age`, `campaign.overdue`, `jobs.*` ve eşikleri **saniye**; `backup.age` ve eşikleri **saat**; `disk.storage` yüzde; `db`/`redis` ms. `*.oldestPendingAge` "zamanı gelmiş (`next_attempt_at` geçmiş) ama gönderilmemiş en eski kayıt"ın gecikmesidir (geri çekilme beklemesindeki ve hız sınırlı duyuru kayıtları sayılmaz; aksi halde bilerek bekleyenler yalancı CRIT üretirdi). `jobs.<anahtar>` değeri son **başarılı** çalışmadan bu yana geçen saniyedir; uygulama yeniden başlayınca bellek sıfırlanır, ilk çalışmaya kadar UNKNOWN.

Zamanlayıcı anahtarları: `news-sync`, `menu-sync`, `mail-queue`, `push-queue`, `campaign-dispatch`, `mail-campaign`, `mail-purge`, `push-purge`, `device-cleanup`, `notification-retention`, `analytics-retention`.

Eşikler (`app.observability.*`, varsayılanlar): `dead-warn=1` (≥1 WARN), `dead-crit=20` (>20 CRIT); `queue-age-warn-minutes=10`, `queue-age-crit-minutes=30` (>30 dk CRIT); `disk-warn-percent=80`, `disk-crit-percent=90`; `backup-warn-hours=3`, `backup-crit-hours=6` (saatlik yedek: >3 sa WARN, >6 sa CRIT); `db-warn-millis=1000`; `poller-max-age-seconds=120` (sık işleyici: >120 sn WARN, >360 sn CRIT); `nightly-max-age-hours=26` (>26 sa WARN, >52 sa CRIT); `monthly-max-age-days=32`. Son hata son başarıdan yeniyse en az WARN.

### Ölü (DEAD) kayıtlar

| Uç | Açıklama |
|---|---|
| `GET /dead-letters/mail?limit=50` | `[{id, template, to (maskeli: a***@alan), attempts, lastError (temizlenmiş), createdAt}]`, en çok 200 |
| `GET /dead-letters/push?limit=50` | `[{id, userId, attempts, lastError, createdAt}]` |
| `POST /dead-letters/{mail\|push}/retry` | Gövde `{"ids":[1,2]}`; `ids` boş/yoksa **tüm** ölüler. `{requeued:n}`. Deneme sayacı sıfırlanır, `PENDING` olur |
| `POST /dead-letters/{mail\|push}/delete` | Gövde `{"ids":[...]}` ZORUNLU (en çok 500; boşsa 400). `{deleted:n}`; yalnız `DEAD` durumundaki satırlar etkilenir |

İçerik (mail değişkenleri, push gövdesi) hiçbir uçta dönmez. Eski toplu uçlar (`/api/admin/ops/mail-outbox/retry-dead`, `/api/admin/push/outbox/retry-dead`) çalışmaya devam eder.

### Yönetici uyarısı

`SystemAlertService` her dakika (`SchedulerLock` `obs-alert`) genel durumu hesaplar; **CRIT olmayandan CRIT'e geçişte** (CRIT'te kalmak tekrar uyarı üretmez) en çok `app.observability.alert-interval-minutes` (60) dakikada bir tüm aktif yöneticilere uygulama içi `SYSTEM` bildirimi (alıcının dilinde, `obs.alert.*`) gönderir; `app.observability.alert-email` doluysa ayrıca kuyruk dışı, anında e-posta denenir (mail kuyruğu çökükse birincil kanal bildirimdir). Durum/kısıt Redis'te (`obs:state`, `obs:alert:sent`). Kapatma: `OBS_ALERT_ENABLED=false`.

### Korelasyon kimliği

Her yanıt `X-Request-Id` başlığı taşır (istemci değeri `[A-Za-z0-9._-]{8,64}` ise korunur, değilse UUID üretilir); log satırlarında `[requestId]` olarak görünür; `{code,message}` hata gövdelerine `traceId` olarak eklenir (destek talebinde bu değer istenir).

## Denetim kaydı v2 ve yönetici yazma güvenliği (P02/P04, V630)

Kapsam: tüm `/api/admin/**` uçları. Migration `V630__admin_audit_v2.sql` (yeni kolonlar NULL'a izinli; eski satırlar değişmez; saklama 365 gün, V520 ayarı aynı).

### Sebep (reason) nasıl gönderilir
Üç yoldan biri (öncelik sırasıyla): (1) başlık `X-Admin-Reason: <metin>` (Türkçe/Arapça karakter için yüzde-kodlu gönderilebilir: `encodeURIComponent`), (2) **GET**'te sorgu parametresi `?reason=`, (3) JSON gövdede üst düzey `reason` alanı (yalnız bu alan okunur; gövde **saklanmaz**, Content-Length bilinen ve ≤ 64 KB gövdelerde çalışır; büyük/parçalı gövdede başlık kullanın). En çok 300 karakter saklanır; kontrol karakterleri boşluğa çevrilir.
Ayar: `app.admin.require-reason` (varsayılan `true`; testlerde `false`). Kapalıyken sebep zorunlu değildir ama verilirse yine kaydedilir.

**Sebep ZORUNLU (yoksa/çok kısaysa `400 REASON_REQUIRED`, mesaj tr/en/ar, `{0}` = en az uzunluk):**

| İstek | En az |
|---|---|
| `PATCH /api/admin/users/{id}/role` | 5 |
| `DELETE /api/admin/users/{id}` | 5 |
| `POST /api/admin/legal/{type}` (sözleşme yayınlama) | 5 |
| `PUT /api/admin/settings/{key}`, yalnız kritik anahtarlar: `maintenance_mode`, `min_version_*`, `store_url_*`, `legal.*`/`legal_*`, `support_email` | 5 |
| `POST .../bulk` (örn. `/access-bans/bulk`) | 5 |
| Sohbet içeriği açan GET'ler: `GET /api/admin/users/{id}/conversations[/{cid}/messages]`, `GET /api/admin/chat-media`, `GET /api/admin/chat-messages`, sohbet bağlamı dönen `GET /api/admin/reports/{id}` | **10** (`message_access_audit.reason` kısıtı) |

Sohbet uçlarında girilen gerçek sebep `message_access_audit.reason`'a yazılır (sistem gerekçesinin yerine). Sohbet **istatistik** ucu (`/chat-media/stats`) ve medya önizleme (`<img>`) sebep istemez. Web notu: sayfalama isteklerinde aynı sebep her isteğe eklenmelidir (durumsuz). Şikâyet detayında yalnız sohbet mesajı bağlamı açılıyorsa sebep aranır (kullanıcı/kulüp şikâyetlerinde aranmaz).

### Hız sınırı (yönetici başına; 429 `RATE_LIMITED` + `Retry-After`)
Tüm yazma istekleri (POST/PUT/PATCH/DELETE `/api/admin/**`): **60/dk**. Yıkıcı/geri alınması zor işlemler ek olarak **20/saat**: kullanıcı silme, rol değiştirme, `verify-email`, `send-reset`, `revoke-sessions`, sözleşme yayını, kritik ayar, toplu işlemler, bekleyen kayıt silme, blocklist ekle/sil, askı önerisi kabul. Basic auth yöneticileri ortak kovayı paylaşır. Okuma ve sohbet görüntüleyici kendi sınırlarını korur (120/dk). Ayarlar: `app.admin.write-per-minute`, `app.admin.destructive-per-hour`. Kural tek yerde (`AdminGuardInterceptor`) olduğu için yeni yönetici yazma ucu otomatik kapsanır.

### `Idempotency-Key` (yazma uçları)
`POST|PUT|PATCH|DELETE /api/admin/**` isteğine `Idempotency-Key: <8-100 karakter [A-Za-z0-9._:-]>` eklenirse (web `useGuardedMutation` zaten gönderir): ilk istek işlenir; aynı anahtarla gelen ikinci istek ilkini **beklemez**: ilk bitene dek `409 REQUEST_IN_PROGRESS` (+ `Retry-After: 1`), bitince saklanan sonuç (durum kodu + ≤ 16 KB gövde) `Idempotency-Replayed: true` başlığıyla döner (gövde 16 KB'ı aşarsa yalnız durum). **2xx dışı sonuç anahtarı serbest bırakır** (düzeltip aynı anahtarla yeniden denenebilir). Aynı anahtar başka yol/yöntemle gelirse `422 IDEMPOTENCY_KEY_REUSED`. Anahtar yönetici başınadır (Redis `idem:<adminId>:<key>`, 60 sn; `app.admin.idempotency-ttl-seconds`). Redis yoksa fail-open. Başlık yoksa/bozuksa istek normal işlenir.

### `GET /api/admin/audit` (genişletildi)
Süzgeçler: `adminId`, `method`, `q` (yol, e-posta, sebep, özet, hedef kimliği), `from`/`to` (`yyyy-MM-dd` Europe/Istanbul günü, `to` o günü dahil; ya da ISO-8601 an), `targetType` (örn. `USER`), `targetId`, `status` (tam kod `403` ya da sınıf `4xx`); `page`, `size` (≤ 100). Geçersiz tarih `400 VALIDATION_ERROR`.
```json
{ "items": [ { "id": 981, "adminId": 5, "adminEmail": "root@bingol.edu.tr", "method": "PATCH",
    "path": "/api/admin/users/3/role", "status": 204, "at": "2026-10-28T09:12:44Z", "ip": "10.0.0.7",
    "targetType": "USER", "targetId": "3", "reason": "yetki düzeltme talebi", "summary": "rol -> USER",
    "requestId": "9c1f0a7e-..." } ],
  "page": 0, "totalPages": 1, "totalItems": 1 }
```
`targetType/targetId/reason/summary/requestId` eski satırlarda `null`. Basic auth yöneticisinde `adminId = null`, `adminEmail = "basic-admin"`. Hedef, servis `AuditContext.target(...)` ile bildirmediyse yoldan çıkarılır (`/users/3/role` → `USER`/`3`, `/settings/maintenance_mode` → `SETTING`/anahtar, `/support/tickets/8/reply` → `TICKET`/`8`). `requestId` = `X-Request-Id` yanıt başlığı / hata gövdesindeki `traceId`.

### `GET /api/admin/audit/export.csv`
Aynı süzgeçler. UTF-8 BOM, CRLF, hücre başında `= + - @` formül kaçışı (`'` öneki), en çok 50.000 satır (en yeni önce), akış halinde. Başlık: `id,at,adminId,adminEmail,method,path,status,targetType,targetId,reason,summary,requestId,ip`. **Bu istek de denetlenir** (`targetType=AUDIT`, `summary="csv satir=N"`).

### `GET /api/admin/audit/message-access`
Yönetici sohbet içeriği erişim kayıtları (içerik dönmez). Süzgeçler: `adminId`, `targetUserId`, `conversationId`, `kind` (`LIST_PREVIEW|VIEW_MESSAGES|MEDIA|FEED|REPORT_CONTEXT`), `q` (sebep içinde), `from`, `to`, `page`, `size`. Bu okuma da denetlenir.
```json
{ "items": [ { "id": 77, "adminId": 5, "adminEmail": "root@bingol.edu.tr", "conversationId": 10, "targetUserId": 1,
    "kind": "VIEW_MESSAGES", "messageCount": 3, "fromMessageId": 120, "toMessageId": 122,
    "reason": "şikayet no 4521 incelemesi", "ip": "10.0.0.7", "at": "2026-10-28T09:10:00Z" } ],
  "page": 0, "totalPages": 1, "totalItems": 1 }
```

### GET denetimi (`@AuditRead`)
Kişisel veri okuyan uçlar kayda girer (sebep zorunlu değil; kayıt zorunlu): kullanıcı detayı `GET /users/{id}`, kullanıcı CSV, destek talebi yazışması `GET /support/tickets/{id}`, şikâyet bağlamı `GET /reports/{id}`, sohbet görüntüleyici/akış uçları, `GET /audit/message-access`, cihaz/IP geçmişi ve erişim engeli listeleri (önceden). Yeni uç için `@AuditRead` (admin paketi) eklenir; genel liste uçlarına eklenmez.

### ADMIN_EMAILS tuzağı
`ADMIN_EMAILS` içindeki hesabın rolü panelden düşürülemez, hesap silinemez: `409 ADMIN_EMAIL_PINNED` (aksi halde sonraki girişte `promoteIfAdmin` rolü geri verir). Kalıcı çıkarma için önce ortam değişkeninden kaldırın. Yükseltmek serbesttir.

### Yeni hata kodları (3 dilde `i18n/obs*.properties`)
`REASON_REQUIRED` (400, `{0}` en az uzunluk), `ADMIN_EMAIL_PINNED` (409), `REQUEST_IN_PROGRESS` (409), `IDEMPOTENCY_KEY_REUSED` (422).
