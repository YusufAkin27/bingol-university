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

## Herkes etkinlik açar + katılım türü (`joinPolicy`) + katılım istekleri

**Yetki kuralı (değişmedi, netleştirildi):** `POST /api/events` kimliği doğrulanmış HERKES içindir. `communityId` boşsa bağımsız (kulüpsüz) etkinlik: `events_require_approval` (varsayılan `false`) kapalıysa hemen `ACTIVE` (201), açıksa `PENDING_REVIEW` (202). `communityId` doluysa kulüp kuralı aynen sürer (`MANAGE_EVENTS`; kulüp ACTIVE olmalı). Kötüye kullanım korumaları (var olanlar): kullanıcı başına IP-bağımsız 10 etkinlik/saat (RateLimiter), bağımsız etkinlikte günlük açma sınırı (`event_daily_create_limit`, 5) ve aynı anda açık etkinlik sınırı (`event_max_open_per_user`, 5), başlık/açıklama/yer için küfür filtresi (`ContentGuard`), başlık 3-150, açıklama ≤2000, yer ≤200.

**Migration YOK (V400 kullanılmadı).** Katılım türü zaten `event_admission.mode` (`OPEN`/`APPROVAL`, V62) ve istekler `event_application` (V62) tablolarında; `event.join_policy` kolonu eklemek aynı durumu iki yerde tutardı. `event_rsvp.status` CHECK'i (`GOING`,`INTERESTED`) DEĞİŞMEDİ: `PENDING`/`REJECTED` kalıcı değil, istek durumundan TÜRETİLİR (`EventRsvp.Status` enum'unda var ama yazılmaz; `PUT /rsvp` bunları 400 `VALIDATION_ERROR` ile reddeder).

### Sözleşme
- `POST /api/events` gövdesi: `{title, description?, startsAt, endsAt, location?, capacity?, communityId?, joinPolicy?}`; `joinPolicy` `OPEN` (varsayılan) | `APPROVAL`.
- `PATCH /api/events/{id}`: `joinPolicy` isteğe bağlı (organizatör). `APPROVAL -> OPEN`: bekleyen/bekleme listesindeki istekler `CANCELLED` olur ve kullanıcılara `notif.admission.modeOpen` gider; kabul edilenler GOING kalır. Sorular için `PUT /events/{id}/admission` (mevcut) sürer.
- `EventView` yeni alanlar: `joinPolicy` (`OPEN`|`APPROVAL`), `organizer {id, displayName, avatarUrl}` (engel ilişkisinde avatar null), `pendingCount` (yalnız `canManage` olana dolu, diğerlerinde `null`), `myRsvp` artık `GOING|INTERESTED|PENDING|REJECTED|null` (`PENDING` = istek/bekleme listesi; `GOING` olan her zaman `GOING`). Eski alanlar (`createdBy`, `organizerName`...) durur.
- `PUT /api/events/{id}/rsvp {status}`: `INTERESTED` aynen. `GOING`: `OPEN`'da doğrudan katılım (kapasite doluysa 409 `EVENT_FULL`); `APPROVAL`'da KATILIM İSTEĞİ açar (önceden 409 `APPLICATION_REQUIRED` idi) ve `{"myRsvp":"PENDING","goingCount":3,"capacity":20}` döner; kapasite PENDING'i saymaz. Etkinlikte soru tanımlıysa `GOING` istekte cevap taşınamaz: 400 `ANSWERS_REQUIRED` → istemci `POST /events/{id}/applications {note, answers}` kullanır. Organizatör kendi etkinliğine istek açamaz (409 `ORGANIZER_CANNOT_APPLY`); reddedilmiş kullanıcı 409 `APPLICATION_REJECTED`; kayıtlar kapalıysa (APPROVAL'da da) 409 `EVENT_REGISTRATION_CLOSED`; engel ilişkisinde 404.
- `DELETE /api/events/{id}/rsvp`: GOING'i, bekleyen isteği ve kalan INTERESTED kaydını geri çeker (idempotent); yer açılırsa bekleme listesi terfi eder.
- Organizatör (organizatör/ortak organizatör/kulüp yetkilisi/ADMIN):
  - `GET /api/events/{id}/requests?status=PENDING&cursor=&size=50` → `CursorPage<ApplicantView>` (`status`: `PENDING|ACCEPTED|REJECTED|WAITLISTED|CANCELLED`; `userId`, `displayName`, `avatarUrl`, `department`, `note`, `answers`).
  - `POST /api/events/{id}/requests/{userId}/approve` → `{id, status:"ACCEPTED"}`; kontenjan doluysa 409 `EVENT_FULL` ve istek PENDING kalır (bekleme listesine düşürmek isteyen mevcut `/applications/{appId}/accept|waitlist` uçlarını kullanır).
  - `POST /api/events/{id}/requests/{userId}/reject {reason?}` → `{id, status:"REJECTED"}` (kabul edilmiş katılımcıyı da çıkarır).
  - Mevcut `/applications/*` uçları aynı veriyi sunar (takma ad ilişkisi).
- Hız sınırları: istek açma 20/dk + 60/sa (`event-apply*`), karar 60/dk, RSVP 30/dk + aynı etkinlikte 5/dk.

### Bildirimler (`NotificationType.EVENT`, data: `eventId`, `applicationId`; tr/en/ar mevcut)
`notif.admission.received` (yeni istek → organizatör), `accepted`, `rejected`/`rejectedNote`, `waitlisted`, `promoted`, `removed`, `modeOpen` (karar → isteyen). Yeni anahtar eklenmedi.

### Sohbet üyeliği
`GET /api/events/{id}/chat` + `RoomConversations` (mevcut). Üyelik = GOING katılımcılar + organizatör/ortak organizatör (+ kulüp etkinliği yetkilisi). OPEN'da GOING olan girer; APPROVAL'da GOING yalnız onaydan sonra oluşur, dolayısıyla PENDING/REJECTED giremez; onayda eklenir (`EventChatHooks.onGoing`), geri çekme/ret/çıkarma/iptalde düşer (`onLeft`). Bu sürümde `GOING -> INTERESTED` geçişi de odadan çıkarır ve `EventChatMaintenance` (`app.chat.room-purge-ms`) artık INTERESTED üyeleri de düşürür (önceden odada kalıyorlardı).


## Yönetici etkinlik moderasyonu (V460)

Ayrıntılı sözleşme ve örnek yanıt: `docs/ADMIN_API.md` "Etkinlik moderasyonu". Özet:

- Yeni uçlar (yalnız ADMIN, 60/dk): `GET /api/admin/events/{id}` (detay + geçmiş + `allowedActions`), `POST /api/admin/events/{id}/hide|unhide|cancel` gövde `{reason}` (zorunlu, ≤ 300). `GET /api/admin/events` süzme parametreleri kazandı: `status` (`ALL` dahil; varsayılan hâlâ `PENDING_REVIEW`), `q`, `communityId`, `standalone`, `joinPolicy`, `from`, `to`; yanıt şekli aynı. Yönetici listesinde `pendingCount`/`canManage` her etkinlik için doludur.
- Geçişler: `ACTIVE→HIDDEN` (sessiz), `HIDDEN→ACTIVE`, `ACTIVE|PENDING_REVIEW|HIDDEN→CANCELLED` (katılımcı/istek sahibi `notif.event.cancelled`, sahibe sebepli `notif.event.cancelledByAdmin`, sohbet odası kapanır). Geçersiz geçiş 409 `EVENT_INVALID_TRANSITION`.
- Kullanıcı tarafı davranış değişikliği: `HIDDEN` etkinlik organizatöre de 404 döner (önceden organizatör görebiliyordu); "etkinliklerim"in `created`/`organizing` modundan düşer.
- Şema: `user_event.moderation_reason/moderated_by/moderated_at` (NULL'a izin) + `event_moderation_log` tablosu; indeksler `evm460_*`. Şikâyet işleyicisi (`EventReportHandler`) artık geri alınabilir (`unhide`) ve yalnız `ACTIVE`'i gizler.
- Yeni çeviri anahtarları: `error.EVENT_INVALID_TRANSITION`, `notif.event.cancelledByAdmin.title/body` (`i18n/event*.properties`, tr/en/ar).


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


## Etkinlik yazma doğrulaması (V550 dönemi)

`EventService.create` ve `update` (kulüp yöneticisi `PATCH /api/events/{id}` ile admin `PATCH /api/admin/events/{id}` aynı yolu kullanır) aynı kuralları uygular. Metinler önce kırpılır; uzunluk kırpılmış metinle ölçülür. Hepsi `400`:

| Alan / kural | Sınır (ayar) | Hata kodu |
|---|---|---|
| Başlık | en çok **100** (`app.event.max-title-length`); kırpılmış en az 3 (`VALIDATION_ERROR`) | `EVENT_TITLE_TOO_LONG` |
| Açıklama | en çok **1000** (`app.event.max-description-length`) | `EVENT_DESCRIPTION_TOO_LONG` |
| Yer | en çok **120** (`app.event.max-location-length`) | `EVENT_LOCATION_TOO_LONG` |
| Bitiş > başlangıç (eşitlik geçersiz) | — | `INVALID_DATES` |
| Süre (bitiş - başlangıç) | en çok **30 gün** (`app.event.max-duration-days`) | `EVENT_TOO_LONG` |
| Başlangıç geçmişte olamaz | `startsAt > şimdi` (**tolerans yok**; eşitlik/geçmiş reddedilir) | `PAST_EVENT` |

- Güncellemede metin sınırları yalnızca **değişen** alana uygulanır (sınırdan uzun eski kayıt, aynı metin yeniden gönderilince bozulmaz); süre sınırı yalnızca `startsAt`/`endsAt` gönderilince denetlenir. `PAST_EVENT` yalnızca başlangıç değişirse (başlamış etkinliğin başlangıcı zaten `409 EVENT_STARTED`).
- DTO `@Size` üst sınırları eskisi gibi geniş kaldı (150/2000/200; yalnızca sütun güvenliği); asıl sınır servistedir ki özel hata kodu dönsün. Bu sınırları aşan istek (örn. 2001 karakterlik açıklama) `VALIDATION_ERROR` alır.
- Etkinlik moderasyonu (V460) kuralları aynen korunur: kulüp zorunlu, `ACTIVE`/`PENDING_REVIEW`, admin uçları.
- Yeni hata kodları (tr/en/ar `i18n/event*.properties`, `{0}` = sınır): `EVENT_TITLE_TOO_LONG`, `EVENT_DESCRIPTION_TOO_LONG`, `EVENT_LOCATION_TOO_LONG`, `EVENT_TOO_LONG`.


## Yönetici etkinlik derin yönetimi (P07, V690)

- Yeni yönetici uçları `event/admin/**`: başvuru listesi/zorla kabul-ret, yoklama listesi/elle düzeltme, sertifika listesi/iptal/iptali geri alma, anonim geri bildirim listesi/silme, duyuru kaydı listesi/silme, düzenleyen listesi/çıkarma, CSV'ler (yoklama, başvuru, etkinlik listesi) ve toplu gizle/yeniden yayınla/iptal (`POST /api/admin/events/bulk`, ≤ 100). Sözleşme: `docs/ADMIN_API.md` "Etkinlik derin yönetimi (P07)".
- **Kullanıcı tarafı davranış değişikliği:** `event_certificate` artık iptal edilebilir (V690: `revoked_at/by/reason`). İptal edilmiş sertifika `GET /api/certificates/verify/{code}` içinde `valid:false` döner ve `GET /api/events/{id}/certificate` `409 CERTIFICATE_REVOKED` verir (mobil: yeni hata kodu genel hata olarak gösterilir).
- Yönetici yoklama düzeltmesi "yok" yaparsa sertifika doğrulaması geçersiz döner (kayıt silinmez); tekrar "var" yapılırsa geçerli olur.
- Yeni hata kodları `i18n/eventadmin*.properties` (basename'e `i18n/eventadmin` eklendi).

## B1: yoklama kısa kodu, istek satırı alanları, kulüp logosu

- `GET /api/events/{id}/checkin-code` yanıtına `manualCode`: 6 karakter (`CheckinCodeService.MANUAL_ALPHABET`, 30 bit), `HMAC(key,"manual:"+eventId+"."+pencere)` ile türetilir (QR imzasından üretilemez); QR ile aynı 30 sn'lik pencere mantığı (güncel + önceki pencere). `POST /events/{id}/check-in` `code` alanında hem eski `eventId.pencere.imza` jetonunu hem kısa kodu kabul eder (nokta içermeyen 6 simge = kısa kod; küçük harf/boşluk/tire tolere edilir). Kısa kod için kullanıcı+etkinlik başına ek sınır dakikada 8 (`checkin-manual:`), genel sınır (dakikada 20) aynen. Durumsuz olduğundan migration yok; RSVP/GOING/pencere kuralları değişmedi.
- `ApplicantView` (`GET /events/{id}/requests`, `/applications`): `email` yalnız başvuran `showEmail=true` dediyse ve çağıran `requireManager` geçtiyse (engel ilişkisinde `null`); `department` / `classYear` `CommunityService.profileExtras` (`AvatarVisibility` DEPARTMENT / CLASS_YEAR) ile başvuranın gizlilik ayarına uyar, ham profil değeri sızmaz. Başka uç/yanıtta yeni e-posta alanı yok.
- `chatAccess` artık yüklü `EventView`dan hesaplanır (`EventChatService.chatAccess(EventView)`; `canManage` / `myRsvp`); etkinliği yeniden yüklemez, tek ek sorgu oda aramasıdır.
- `EventView.communityLogoUrl`: kulüp etkinliğinde kulüp logosu (`CommunityService.byIds` ile ad ve logo tek sorguda).

Ek (B1): `CalendarItem.pendingCount` (yalnız `manageableIds` içindeki etkinlik; toplu `pendingCounts`), `EventView.cancelReason` (= `moderationReason`, CANCELLED/HIDDEN) ve `EventView.rejectReason` (= `reviewNote`, REJECTED) yalnız yönetene; hepsi `NON_NULL`. Arama `SearchHit` EVENT: `startsAt`/`endsAt`.
