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
| Destek | `GET /api/admin/support/tickets?status=&cursor=`, `GET .../{id}`, `POST .../{id}/reply {text}`, `POST .../{id}/close` |
| SSS | `GET/POST /api/admin/faq`, `PUT/DELETE /api/admin/faq/{id}` (`lang` tr\|en\|ar) |
| Sözleşmeler | herkese açık `GET /api/legal`, `/api/legal/{type}`; yönetici `POST /api/admin/legal/{type} {tr:{title,content}, en?, ar?, requireReaccept}` |
| Ayarlar | `GET /api/admin/settings`, `PUT /api/admin/settings/{key} {value}` (mağaza linkleri, iletişim, banner, bakım modu, sürüm kontrolü) |
| Push | `POST /api/admin/push/audience-count`, `POST/GET /api/admin/push/campaigns`, `GET .../{id}`, `POST .../{id}/cancel` |
| Topluluk / etkinlik onayı | `GET /api/admin/communities`, `POST /api/admin/communities/{id}/approve\|reject`, `GET /api/admin/events`, `POST /api/admin/events/{id}/approve\|reject` |
| Haber senkronu | `POST /api/admin/sync`, `POST /api/admin/sync-menu`, `GET /api/status` |
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
