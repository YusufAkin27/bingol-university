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

## W1-F: etkinlik yetkisi canlı kulüp bağı, yoklama gizliliği, sohbet girişi (T-040/041/043/044/045, T-027 parça 2)

- **Sistem ADMIN rolü artık izne bağlı (T-040).** `Actor.admin()` (= yalnız `ROLE_ADMIN`) yerine `Actor.systemAdmin(izin)`: JWT `ap` talebi (`AdminProfile`) → `PermissionMatrix`. Etkinlik yönetimi/oluşturma/seri/ortak organizatör/başvuru kuralı için `content.write` (FULL, EDITOR), görünürlük istisnası için `content.read`. **VIEWER/SUPPORT/MODERATOR** profili artık kullanıcı API'sinde başkasının etkinliğini yönetemez (403); talep yoksa (P16 öncesi eski token) kapalı başarısız olur. `/api/admin/**` yolundan gelen servis çağrıları `new Actor(id, true)` ile kısıtsız kalır (izin kontrolü `AdminPermissionInterceptor`da). Yetki yalnız sistem müdahalesinden geliyorsa `admin_audit`'e satır düşer (`method/path` isteğin kendisi, `target_type=EVENT`, `summary=sistem-yonetici-mudahalesi: ...`; `SystemAdminAudit`).
- **Organizatör yetkisi canlı kulüp bağına bağlı (T-041).** Kulüp etkinliğinde `canManage` = (content.write'lı sistem yöneticisi) VEYA kulüpte **canlı `MANAGE_EVENTS`** (olusturan dahil: yasaklanan/çıkarılan/yetkisi alınan oluşturan **yönetemez**: katılımcı listesi/PII, yoklama, duyuru, seri, QR kodu 403; özel kulüpte kulüp üyesi değilse 404) VEYA **kulüp üyeliği süren ortak organizatör**. Kulüpsüz (eski) etkinlikte kural eski: oluşturan veya ortak organizatör. Yeni `EventService.isOrganizer(userId, event)`.
- `POST /events/{id}/co-organizers`: hedef kullanıcı **kulübün aktif üyesi** olmalı, değilse `409 CO_ORGANIZER_NOT_MEMBER` (yeni kod, `event*.properties` tr/en/ar). Sahip düzeyi (ekleme/çıkarma) kulüp etkinliğinde artık yalnız `MANAGE_EVENTS`/sistem yöneticisi.
- `POST /events/{id}/series`: kopya, kaynağın durumunu devralmaz; kulüpte yönetici düzeyinde olmayan (sade üye, `MANAGE_EVENTS` verilmiş) kullanıcının seri kopyaları `PENDING_REVIEW` olur. `PATCH /events/{id}`: **ACTIVE** kulüp etkinliğinin başlık/açıklama/yer metnini staff olmayan biri değiştirirse etkinlik yeniden `PENDING_REVIEW`'e düşer (kapak ve tarih değişiklikleri durumu etkilemez).
- `ClubMemberLeftEvent` (ayrıldı/çıkarıldı/yasaklandı): kullanıcının o kulübün etkinliklerindeki **ortak organizatör kayıtları silinir**, **özel (PRIVATE) kulüp** etkinliklerindeki bitmemiş RSVP'leri silinir (GOING ise sayaç atomik azalır); etkinlik sohbet odalarından **oluşturan dahil** çıkarılır. Yeni `EventMemberLeftCleanup`. Migration gerekmez; kulüp dışı mevcut ortak organizatörler çalışma zamanı kontrolüyle yetkisizdir.
- **`UserEvent.goingCount` `updatable=false` (T-043).** Sayaç yalnız koşullu UPDATE'lerle (`tryIncrementGoing/decrementGoing`) değişir; kayıtları kapat/başlık/kapak gibi tam-varlık UPDATE'leri bayat sayacı ezip kapasiteyi aşırmaz.
- **Elle yoklama yalnız GOING (ya da zaten yoklama kaydı olan) kullanıcıya (T-044):** RSVP'siz keyfi kullanıcı kimliği `404 USER_NOT_FOUND` (ad/bölüm sızıntısı ve sahte yoklama yok). `GET /events/{id}/attendance` ve `.csv`: engel ilişkisi olan çift listede yok; `department` yalnız sahibinin gizlilik ayarı izin veriyorsa (`ONLY_ME` → `null`).
- **`GET /api/events/{id}/chat` (eski uç) INTERESTED/PENDING ile girişi kapatır (T-045):** yalnız GOING veya organizatör (APPROVAL modu atlanmaz); diğerleri `403 FORBIDDEN`.
- **Avatar gizliliği (T-027 parça 2):** katılımcı listesi, organizatör, ortak organizatör ve başvuran satırlarında `avatarUrl` artık `CommunityService.avatarsFor` ile (engel + `ONLY_ME`/`SHARED_CONTEXT` + moderasyon `avatar_hidden`); gizlilik kararı verilemezse avatar gönderilmez. `ClubAvatarPrivacyTest` kulüp/etkinlik kodunda doğrudan `getAvatarUrl()` kullanımını tarar.

## W2-D: iptal, toplu bildirim, kurum taklidi, gölge engel (T-049, T-051, T-052, T-029)

- **İptal edilen etkinlik (T-049):** RSVP'si ya da başvurusu olan kullanıcı `GET /api/events/{id}` ile CANCELLED etkinliği **salt okunur** görür (`status=CANCELLED`, `cancelReason`); yabancı kullanıcıya hâlâ 404. `DELETE /rsvp` iptal edilmiş etkinlikte de çalışır. `GET /api/events/mine?mode=cancelled` RSVP'li olunan iptal edilenleri listeler (imleç = id). `POST /events/{id}/cancel` isteğe bağlı gövde `{"reason":"..."}` (en çok 300, `user_event.cancel_reason`, V980); neden RSVP'li katılımcıya ve yönetene görünür, yönetici iç notu (`moderationReason`) katılımcıya sızmaz. Yazma/yoklama/sohbet yolları `loadVisible`'da kaldı (iptal edilen için 404).
- **Toplu bildirim (T-051):** etkinlik iptali/saat değişimi, başvuru modu değişimi/iptali, kulüp silme, kulüp yazısı ve organizatör duyurusu artık **tüm** alıcılara kimlik imeçli sayfalarla (500'lük) gider; eski 500/1000 sessiz kesme kalktı. Güvenlik tavanı 50.000 alıcı (`Paging.FANOUT_CAP`); duyuruda tavana çarpılırsa `AnnouncementResult.truncated=true`. `PollAccess.communityUserIds` (100.000) değişmedi.
- **Kurum taklidi (T-052):** kulüp adı / etkinlik başlığı `DisplayNamePolicy.looksReserved` (rektör, resmi, destek, yönetici, bukampus, bingöl üniversitesi vb.) ile eşleşirse yeni kulüp ve etkinlik **PENDING_REVIEW**'a düşer (otomatik onay yalnız temiz adda; sistem yöneticisi muaf); yayındaki kulüp rezerve ada yeniden adlandırılamaz (`400 RESERVED_DISPLAY_NAME`), etkinlik başlığı rezerve ada çevrilirse yeniden onaya düşer; etkinlik duyuru başlığı rezerve ise `400 RESERVED_DISPLAY_NAME`. Kulüp adı/etkinlik başlığı/yer/duyuru başlığında bidi/sıfır genişlikli/kontrol karakteri `400 INVALID_DISPLAY_NAME`.
- **Gölge engel (T-029):** beni engelleyen organizatörün etkinliğine başvuru normal "PENDING" cevabını döner (kayıt/bildirim yok); beni engelleyen kullanıcıyı ortak organizatör eklemek normal cevabı döner (kayıt/bildirim yok). Ben engellediysem eski 404 davranışı.

## FIX-P05: RSVP yarisi, sinirlar, engel, rapor, oda senkronu (backend duzeltme turu)

- **RSVP durum gecisi sahiplenilir (A05#2).** `EventRsvpRepository.transition(id, from, to)` ve `deleteClaim(id)` kosullu UPDATE/DELETE; es zamanli cift dokunusta yalniz kazanan `going_count` sayacini degistirir (eskiden hayalet koltuk / fazla rezervasyon). Istemci etkisi yok (ikinci istek ayni 200 sonucunu alir). Gece 03:20 `EventGoingCountReconciler` (SchedulerLock) sayaci GOING satir sayisina esitler (`app.event.going-reconcile-cron`).
- **Sohbet odasi senkronu commit sonrasi (A05#4, A05#8).** `EventService.chatSync` ve `ClubExtrasHooks` (uye katildi/ayrildi/kulup yayin/ad/silme) oda islemini RSVP/uyelik islemi commit olduktan sonra AYRI islemde calistirir. Oda hatasi artik uyeligi/RSVP'yi geri almaz (eskiden rollback-only -> 500). Oda uyeligi RSVP yanitindan kisa sure sonra gorunur olabilir (bakim gorevi tutarsizligi giderir). `ClubInviteService.join` benzersizlik yarisi `409 ALREADY_MEMBER`.
- **Etkinlik acma sinirlari (A05#6, K14) - FINAL-ALL: VARSAYILAN KAPALI.** `EventAdmissionHooks.beforeCreate(a, count)` `POST /api/events` ve `POST /api/events/{id}/series` (kopya sayisi kadar) icinde cagrilir: `409 EVENT_LIMIT_OPEN` / `429 EVENT_LIMIT_DAILY`. Sayim KULUP etkinliklerini de kapsar. Eski mobil surumler bu yeni hatalari beklemedigi icin kod varsayilani `event_max_open_per_user` = 0 ve `event_daily_create_limit` = 0 (sinirsiz; onceki davranis). Sinir yonetici ayariyla (`app_setting`) bilincli acilir; sistem ADMIN muaf. Hata kodlari tr/en/ar ceviriyle hazirdir.
- **Engelleme takibi siler (A06#3, K15).** `POST /api/users/{id}/block` iki yonlu takibi ve bekleyen takip isteklerini de kaldirir (`BlockService` -> `FollowService/FollowRequestService.dropBetween`); engel kalkinca takip geri gelmez. Mobil: profil ekraninda takip durumu `NONE`.
- **Etkinlik listeleri baslangic alt siniri (A05#5).** `upcoming`/`featured` sorgulari `startsAt >= from - 60 gun` ile biter; 60 gunden once baslamis ve hala surdugu gorunen kayitlar (suresi <= 30 gun kurali V550 oncesi veri) listede/one cikanda gorunmez. Yeni indeks `evt1110_active_ends` (V1110), `cnt1111_post_author_idx` (V1111).
- **Hatirlatma (A05#7, K16).** "Yarin basliyor" artik baslangica 22-26 saat kala gider (eskiden 1-24 saat); kisa surede RSVP verilenler zaten saat hatirlatmasi alir. Gonderim istisna firlatirsa iz geri alinir. Metin degismedi.
- **Rapor/itiraz yarislari (A05#10).** Es zamanli cift rapor `409 ALREADY_REPORTED`; rapor/itiraz karari satir kilidiyle okunur (cift strike/bildirim yok); toplu karar beklenmeyen hatada `INTERNAL_ERROR` satiri doner, kalan kimlikler islenir.
- **Ozel kulupten ayrilan (A05#11).** Kabul edilmis basvuru `CANCELLED` olur, bekleme listesinden siradaki terfi eder, etkinlik sohbet odasindan cikarilir.
- **CSV (A05#9).** Moderasyon rapor/itiraz ve kulup CSV'si 50.000 satiri bellekte listelemez (kimlik imecli parcalar); etkinlik yoklama CSV'si 5.000 satirda kesildiyse son satir `TRUNCATED,...` olur. Saklama temizligi (`profanity_hit_log`, `violation_ledger`, `account_delete_hold`) ChunkedDeleter + SchedulerLock ile.


## Kisisel QR ile yoklama, yoklama acma anahtari, etkinlik moderatorleri (2026-11-06, V1490)

**Kok neden (hata):** `GET /events/{id}/checkin-code` yoklama penceresi (baslangic-30 dk .. bitis+30 dk) disinda 409 `CHECKIN_CLOSED` doner; mobil bu hatayi sabit "Sunucu ile baglanti kurulamadi" metniyle gizliyordu. Mobil artik sunucu mesajini gosterir. Ters akis eklendi: katilimci kisisel QR gosterir, sahip/moderator okutur.

**Etkinlik olusturma:** yalniz KULUP SAHIBI (OWNER) etkinlik olusturur (`403 EVENT_CREATE_OWNER_ONLY`); kulup yoneticisi / `MANAGE_EVENTS` izinli uye (eski 202 PENDING_REVIEW yolu) artik olusturamaz. Sistem ADMIN'i panelden yonetmeye devam eder. Mevcut etkinlikler ve yonetimleri degismez.

**Yoklama acma anahtari:** `user_event.attendance_open` (varsayilan kapali). `PUT /events/{id}/attendance-open {open}` yalniz sahip. Kapaliyken `GET /events/{id}/my-ticket` ve `POST /events/{id}/scan` 409 `ATTENDANCE_NOT_OPEN`. Zaman penceresi kurali aynen gecerlidir. Eski `checkin-code`/`check-in` uclari degismedi.

**Kisisel QR:** `GET /events/{id}/my-ticket` yalniz GOING katilimciya; `bingol-ticket:{etkinlik}.{kullanici}.{pencere}.{HMAC}`, 60 sn pencere, ~3 dk gecerli. `POST /events/{id}/scan {code}` sahip/moderator (`TAKE_ATTENDANCE`): `MARKED` | `ALREADY`; hatalar `INVALID_CODE`, `NOT_RSVPED_SCAN`, `CHECKIN_CLOSED`. Rate limit: 60/dk (bilet), 120/dk (okutma).

**Moderatorler (`event_moderator`):** sahip, kulup uyeleri arasindan moderator ekler/cikarir (`GET|PUT|DELETE /events/{id}/moderators[/{userId}]`, en cok 20). `GET /events/{id}/my-permissions` -> `{owner, attendanceOpen, permissions[]}`. Yetkiler tek tek: `TAKE_ATTENDANCE` (QR okut + elle yoklama), `MANAGE_REQUESTS` (basvuru onay/ret/liste), `VIEW_ATTENDEES` (katilimci + yoklama listesi), `SEND_ANNOUNCEMENT`, `EDIT_INFO` (baslik/aciklama/yer), `EDIT_SCHEDULE` (tarih/saat). `PUT /events/{id}` moderatorde alan bazlidir; kapasite ve katilim turu sahip-ozeldir. Sahip-ozel (moderatore ASLA verilemez): etkinligi kapatma/iptal/silme, kayit kapatma, yoklamayi acip kapatma, moderator ve yetki yonetimi, ayarlar. Yetkisiz moderator `403 EVENT_PERMISSION_DENIED`. Moderator, kulup uyeligi surdukce gecerlidir. Ekleme/cikarmada moderatore bildirim (`notif.event.moderatorAdded|moderatorRemoved`, tr/en/ar); verilen yetki denetim icin log'a yazilir. KVKK: hesap silmede satirlar silinir (`AccountDataPurger`), disa aktarim bolumu `eventModerator`.


## Yoklama modeli v2 + bulusma noktasi (V1491)

**Bulusma noktasi:** `user_event.meeting_point` (<=200) + `meeting_lat/meeting_lng` (opsiyonel; metin yoksa koordinat silinir). Etkinlik yeri (`location`) ayri kalir. `POST/PATCH /events` ve `EventView` alanlari `meetingPoint, meetingLat, meetingLng`; moderatorde `EDIT_INFO` kapsami. Bitmis etkinlikte yalniz `description` duzenlenir (diger alan 409 `EVENT_ENDED`). Yer/bulusma noktasi/saat degisince GOING katilimciya `notif.event.updated`; saat degismediyse ayni etkinlik icin 10 dk'da tek bildirim (`update_notified_at`). Push yukunde `meetingPoint` anahtari.

**Yoklama:** katilimci yalniz `GET /events/{id}/my-ticket` ile QR uretir. Sahip/yonetici/moderator icin 403 `TICKET_NOT_FOR_STAFF` (kisisel QR yok). `POST /events/{id}/scan` coklu okutucu: es zamanli ayni kisi icin tek kayit, ikinciye `ALREADY` (CHECKIN_CONFLICT yeni transaction'da bir kez tekrarlanir). `GET /events/{id}/attendance/roster` -> `{rows[{..., status: PRESENT|ABSENT|NONE}], present, absent, pending, total}`; `GET /attendance` satirlarina `status` eklendi. `PUT /attendance/{userId} {status}` (`PRESENT|ABSENT|NONE`; NONE kaydi siler; eski `{present}` hala calisir). `POST /attendance/bulk {status, userIds | rest:true}` (rest = kaydi olmayan onayli katilimcilar; eski `entries` hala calisir). Elle isaretleme pencere acildiktan sonra etkinlik bittikten sonra da serbest; QR okutma pencere kuralina tabidir. Yetki: `TAKE_ATTENDANCE` isaretler, `VIEW_ATTENDEES` listeyi gorur. Eski `checkin-code`/`check-in` uclari eski surumler icin duruyor.


## Biten ve iptal edilen etkinlikler normal kullanicidan gizlenir (2026-11-07)

**Model (incelenen):** `user_event.ends_at` ZORUNLU (NOT NULL, `validateDates`: bitis > baslangic, sure <= 30 gun); durumlar `PENDING_REVIEW|ACTIVE|REJECTED|CANCELLED|HIDDEN`. Ayri "yayin sonu" alani yok. Resmi duyuru etkinlikleri (`news_item` ETKINLIK) AYRI bir kaynaktir (saat yok, yalniz takvimde `OFFICIAL`); bu kuralin kapsami disindadir ve degismedi.

**Bitis kurali:** etkinlik tam `endsAt` aninda biter (`endsAt <= simdi` => bitmis). `endsAt` her kayitta var oldugu icin "gun sonu" gibi uydurma bir kural GEREKMEZ (alan bos olsaydi gerekce: baslangic gununun Europe/Istanbul 23:59:59.999'u; bugun kullanilmaz). Karsilastirma backend'de UTC anlariyla (`Instant`) yapilir; mobil yalniz gostermek icin yerele cevirir, bu yuzden saat dilimi farki gecmis etkinligi gelecekte gostermez. Gun siniri (takvim ayi) Europe/Istanbul 00:00 ile hesaplanir, saklama UTC'dir. Tek kaynak: `EventLiveness.isLive(e, now)` (ACTIVE ve `endsAt > now`) ve `EventLiveness.state` (LIVE|ENDED|CANCELLED|UNAVAILABLE).

**Listeler (filtre SORGUDA):** `GET /api/events`, `/events/featured`, `/events/calendar`, `/me/events?mode=upcoming|going|attending`, genel arama (`EventSearchProvider`: `status='ACTIVE' AND ends_at >= now()`), ICS, ana sayfa sayaci (`MeSummaryService`) zaten yalniz ACTIVE + bitmemis dondurur (indeks `idx_event_status_start` + kismi `evt1110_active_ends`). Bu degisiklikte kapanan bosluklar: (1) `GET /events?from=<gecmis>` artik alt siniri "simdi"nin altina indiremez; (2) `GET /events/calendar` gecmis aylar ve ay icindeki biten etkinlikler icin kullanici etkinligi dondurmez (`OFFICIAL` haberler aynen); istisna: `communityId` verilen listede istek sahibi o kulubun yoneticisi (MODERATOR+) ya da icerik yazma izinli sistem yoneticisiyse gecmis de gelir. Gecmis her zaman erisilebilir kalan yollar: `/me/events?mode=past|created|organizing|cancelled` (katilim gecmisi, duzenlediklerim), `GET /events/{id}` (derin baglanti; iptal/bitmis etkinlik 404 vermez, `status` ve `endsAt` ile durum gosterilir), yonetici paneli (`/api/admin/events`, `event.admin`).

**Bildirimler:** (a) `EventReminderService` gonderimden HEMEN ONCE etkinligi veritabanindan yeniden okur; iptal/bitmis/yayinda olmayan etkinlige hatirlatma gitmez (sahiplenme geri alinmaz, yeniden denenmez). (b) `notifyGoing` ("etkinlik guncellendi") bitmis/yayinda olmayan etkinlikte gonderilmez; iptal bildirimi yalniz etkinlik bitmediyse gider (eski kural). (c) Basvuru bildirimleri (alindi, kabul/bekleme/terfi/ret/cikarildi, moda gecis, iptal) bitmis ya da iptal etkinlik icin gonderilmez. (d) Duyuru zaten `409 EVENT_ENDED` ile reddedilir. (e) Push TTL: etkinlik bildirimlerinin yukunde `eventEndsAt` (ISO UTC) bulunur; FCM `ttl` / APNs `apns-expiration` = min(tur varsayilani, bitise kalan sure), en az 60 sn. Telefon kapaliyken bekleyen bildirim bitis aninda platformda sona erer. PushOutbox/PushDispatcher yapisi degismedi.

**Uygulama ici bildirim kutusu:** `GET /api/notifications` EVENT turundaki ogelere `eventState` ekler (`LIVE|ENDED|CANCELLED|UNAVAILABLE`, istek anindaki projeksiyon, kalici veriye yazilmaz; alan yoksa gonderilmez). Liste filtrelenmez, ogeler "sona erdi/iptal edildi" ile isaretlenir (iptal bildiriminin kendisi kaybolmaz). Mobil bu bayragi gosterir; dokunus ayrintiya gider.

**Platform siniri (belgelenmis varsayim):** zaten GOSTERILMIS bir sistem (push) bildirimi sunucudan UZAKTAN silinemez; FCM/APNs bunu desteklemez. Bu yuzden TTL ile gec ulasma engellenir; gosterilmis bildirime dokunulursa uygulama dürüst "etkinlik sona erdi/iptal edildi" durumunu acar. Planli YEREL hatirlatmalar mobilde, etkinlik iptal/bitis durumu ogrenildiginde iptal edilir.

**Veri:** hicbir etkinlik silinmedi; yeni migration yok.
## Yoklama okutma gercek zamanli geri bildirim (2026-11-07)

- Yeni STOMP kuyrugu `/user/queue/attendance-events` (`AttendanceLiveEvents`, `ChatEventBus` + Redis pub/sub; yalniz ilgili kisilere, commit SONRASI, hata yoklamayi bozmaz). Yeni okutmada: `SCAN` -> etkinlik sahibi + `TAKE/VIEW_ATTENDANCE` yetkili moderatorler `{key,eventId,userId,displayName,at,present,total}` (engel iliskisi olan ciftte ad/kimlik null, sayac gider); `MARKED` -> yalniz okutulan katilimci. `key` (`eventId:userId:markedAtMs`) ayni okutma icin sabit (istemci cift olayi eler); 'zaten okutulmus' olay uretmez.
- Yedek: `GET /api/events/{id}/attendance/summary` -> `{present,total,lastName,lastAt}` (VIEW/TAKE yetkisi, 120/dk); katilimci icin mevcut `GET /my-attendance`.
- Hata kodu eklenmedi (i18n degisikligi yok). Pub/sub kalici degildir; kacirilan olay yoklama ile telafi edilir.

## T1: Etkinlik bileti "Biletim" (2026-11-10)

- `GET /api/events/{id}/ticket`: bilet verisi (etkinlik, sahip adi, `state` VALID/ENDED/CANCELLED, `attendanceOpen`); yalniz `GOING` katilimci, sahip/moderator 403 `TICKET_NOT_FOR_STAFF`, katilmayan 403 `NOT_RSVPED`. QR yoklama sozlesmesi (`/my-ticket`) degismedi.
- Mobil: `EventTicketPage`, hesap bazli cevrimdisi onbellek `EventTicketStore` (cikista silinir).
