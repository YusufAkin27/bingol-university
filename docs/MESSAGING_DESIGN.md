# Mesajlaşma Özelliği – Teknik Tasarım Notu

Durum: Taslak (kod yazılmadı) · Kapsam: backend (Spring Boot 4.1.2 / Java 17) + mobil (Flutter)

## 0. Mevcut durum ve tasarım ilkeleri

Koddan çıkarılan, tasarımın dayandığı gerçekler:

| Konu | Mevcut durum |
|---|---|
| Kimlik | `app_user` tablosu (`User`: `id` Long IDENTITY, `email`, `displayName`, `emailVerified`, `createdAt`). Kayıt yalnızca `*.bingol.edu.tr` e-postasıyla; giriş ve refresh yalnızca `emailVerified=true` kullanıcıya token verir. |
| Access token | JWT HS256, `sub` = kullanıcı id, claim `email`, TTL 15 dk (`jwt.access-ttl-minutes`). `JwtService.parseUserId(token)` geçerliyse `Long`, değilse `null` döner. |
| Refresh token | Opak, Redis'te SHA-256 özeti (`rt:<hash>`), tek kullanımlık (rotation), 30 gün. |
| HTTP kimlik doğrulama | `JwtAuthFilter` (`Authorization: Bearer`), principal = `Long` kullanıcı id, rol `ROLE_USER`. `SecurityConfig`: stateless, CSRF kapalı, `anyRequest().authenticated()`. |
| Rate limit | `RateLimiter.check(key, max, window)`: Redis sabit pencere (`INCR` + `EXPIRE`), aşımda `ApiException(429, RATE_LIMITED)`. Anahtar öneki `rl:`. |
| Hata biçimi | `ApiException` + `ApiExceptionHandler` (kod + Türkçe mesaj). |
| Bağımlılıklar | `spring-boot-starter-websocket`, `spring-boot-starter-data-redis`, `bucket4j_jdk17-core/lettuce 8.14.0`, `jsoup 1.18.3` (zaten pom'da). Veritabanı: geliştirmede H2 dosyası, üretimde PostgreSQL; `ddl-auto=update`. |
| Mobil | `mobile/pubspec.yaml` mevcut (Flutter). |

İlkeler:
1. Kalıcı gerçek kaynağı SQL veritabanıdır; Redis yalnızca geçici/hızlı durum (presence, rate limit, pub/sub) tutar. Redis kaybı mesaj kaybı doğurmamalıdır.
2. Mesaj gönderimi tek bir servis yolundan geçer: `MessageService.send(...)`. Hem REST hem WebSocket aynı servisi çağırır; yetki, temizleme, rate limit, kayıt orada olur.
3. Paket yapısı mevcut düzenle uyumlu: `edu.bingol.backend.chat` (entity, repository, service, controller), `edu.bingol.backend.chat.ws` (STOMP yapılandırma, interceptor). Yeni sınıflar `auth` paketindeki `ApiException`, `RateLimiter`, `JwtService` sınıflarını yeniden kullanır.

---

## 1. Veri modeli

Birebir (DIRECT) konuşma önce, grup (GROUP) sonra. Şema baştan her ikisini taşıyacak şekilde kurulur; grup uçları 2. fazda açılır.

### 1.1 Tablolar

**`conversation`**

| Alan | Tip | Not |
|---|---|---|
| `id` | BIGINT IDENTITY PK | Mevcut `User` ile aynı strateji. (Dışarıya sızdırma/tahmin kaygısı varsa UUID; bkz. Açık sorular.) |
| `type` | VARCHAR(10) NOT NULL | `DIRECT` / `GROUP` |
| `direct_key` | VARCHAR(41) NULL, **UNIQUE** | Yalnızca DIRECT için: `min(userA,userB) + ":" + max(userA,userB)`. Aynı iki kişi arasında yinelenen konuşmayı veritabanı düzeyinde engeller (yarış koşullarına karşı). GROUP için NULL (UNIQUE NULL'a izin verir). |
| `title` | VARCHAR(100) NULL | Yalnızca GROUP |
| `created_by` | BIGINT NOT NULL | FK `app_user.id` |
| `created_at` | TIMESTAMP NOT NULL | |
| `last_message_id` | BIGINT NULL | Denormalize; konuşma listesi sıralaması/önizleme için |
| `last_message_at` | TIMESTAMP NULL | Denormalize; listede sıralama anahtarı |

**`conversation_participant`**

| Alan | Tip | Not |
|---|---|---|
| `id` | BIGINT PK | |
| `conversation_id` | BIGINT NOT NULL FK | |
| `user_id` | BIGINT NOT NULL FK | |
| `role` | VARCHAR(10) | `MEMBER` / `ADMIN` (grup için) |
| `joined_at` | TIMESTAMP NOT NULL | Gruba sonradan katılan, öncesini görebilir mi? (Açık sorular) |
| `left_at` | TIMESTAMP NULL | Ayrıldı/çıkarıldı; doluysa yetki yok |
| `last_read_message_id` | BIGINT NOT NULL DEFAULT 0 | Okundu imleci (bkz. 1.3) |
| `last_read_at` | TIMESTAMP NULL | |
| `muted_until` | TIMESTAMP NULL | Bildirim susturma (isteğe bağlı) |
| `hidden_before_message_id` | BIGINT NOT NULL DEFAULT 0 | "Konuşmayı benim için sil": bu id'ye kadar olan mesajlar bu kullanıcıya gösterilmez |

Kısıt: `UNIQUE (conversation_id, user_id)`.

**`message`**

| Alan | Tip | Not |
|---|---|---|
| `id` | BIGINT IDENTITY PK | Tek bir artan sıra; imleç sayfalama ve okundu imleci bunun üzerine kurulur. |
| `conversation_id` | BIGINT NOT NULL FK | |
| `sender_id` | BIGINT NOT NULL FK | Hesap silinirse anonimleştirme için NULL'lanabilir (bkz. 5.5) |
| `client_msg_id` | VARCHAR(36) NOT NULL | İstemcinin ürettiği UUID; idempotency (tekrar gönderimde çift kayıt olmasın) |
| `body` | VARCHAR(2000) NOT NULL | Düz metin, sunucuda temizlenmiş (bkz. 5.3) |
| `created_at` | TIMESTAMP NOT NULL | Sunucu saati |
| `deleted_at` | TIMESTAMP NULL | Gönderen "herkesten sil" yaptığında; kullanıcıya silindi görünür, şifreli gövde **saklanır** (T24) |
| `edited_at` | TIMESTAMP NULL | Düzenleme ilk sürümde yok; alan ileriye dönük |

Kısıt: `UNIQUE (conversation_id, sender_id, client_msg_id)`.

**`user_block`**

| Alan | Tip |
|---|---|
| `blocker_id`, `blocked_id` | BIGINT, birleşik PK |
| `created_at` | TIMESTAMP |

**`message_report`**

| Alan | Tip | Not |
|---|---|---|
| `id` | BIGINT PK | |
| `reporter_id` | BIGINT NOT NULL | |
| `message_id` | BIGINT NULL | Belirli mesaj |
| `reported_user_id` | BIGINT NOT NULL | |
| `conversation_id` | BIGINT NOT NULL | |
| `reason` | VARCHAR(20) | `SPAM`, `HARASSMENT`, `INAPPROPRIATE`, `OTHER` |
| `note` | VARCHAR(500) NULL | |
| `status` | VARCHAR(12) | `OPEN` / `REVIEWED` / `DISMISSED` |
| `created_at` | TIMESTAMP | |
| `snapshot_body` | VARCHAR(2000) NULL | Raporlanan mesajın o anki metni (gönderen silerse kanıt kalsın; saklama süresi 5.5'te) |

### 1.2 İndeksler

- `message (conversation_id, id DESC)`: geçmiş sayfalama (en kritik indeks). `id` zaten artan olduğundan `created_at` ayrıca indekslenmez.
- `message (conversation_id, sender_id, client_msg_id)` UNIQUE: idempotency.
- `message (created_at)`: saklama süresi temizleme işi için.
- `conversation_participant (user_id, left_at)` + UNIQUE `(conversation_id, user_id)`: "kullanıcının konuşmaları" ve "katılımcı mı?" sorguları.
- `conversation (last_message_at DESC)`: tek başına değil; liste sorgusu katılımcı tablosuyla birleştiği için `conversation_participant (user_id)` yeterli, sıralama `last_message_at` ile bellek içi/ORDER BY.
- `conversation (direct_key)` UNIQUE.
- `user_block (blocked_id)`: "beni engelleyen var mı" sorgusu için ikinci yön.
- `message_report (status, created_at)`: yönetici kuyruğu.

### 1.3 Okundu bilgisi: mesaj başına değil, imleç başına

Her (mesaj, kullanıcı) çifti için satır tutmak yazma yükünü katlar. Bunun yerine `conversation_participant.last_read_message_id` kullanılır: kullanıcı X, konuşma C içinde `id <= last_read_message_id` olan her şeyi okumuştur. Sonuçlar:
- Okunmamış sayısı: `COUNT(message WHERE conversation_id=C AND id > last_read AND sender_id <> me AND deleted_at IS NULL)`. Liste ekranında N konuşma için tek sorguda toplu hesaplanır; sayı büyürse `unread_count` önbelleği Redis'te (`unread:{userId}:{convId}`) tutulabilir (2. faz optimizasyonu, ilk sürümde sorgu yeterli).
- İmleç yalnızca ileri gider (`GREATEST(old, new)`); eski bir değerle geri gelen istek yok sayılır. Konuşmadaki en büyük mesaj id'sini de geçemez (doğrulanır).
- Birebirde "karşı taraf okudu" göstergesi: diğer katılımcının `last_read_message_id >= mesaj.id`. Grupta "okuyanlar" listesi ilk sürümde yok; imleçlerden türetilebilir.
- "Teslim edildi" (delivered) durumu ilk sürümde yok: gönderen için `SENT` (sunucu kaydetti) ve `READ` yeterli. İleride `last_delivered_message_id` eklenebilir.

---

## 2. WebSocket / STOMP tasarımı

### 2.1 Yapılandırma

- `@EnableWebSocketMessageBroker`, `WebSocketMessageBrokerConfigurer`.
- Endpoint: **`/ws`** (yalnızca ham WebSocket; mobil istemci için SockJS gerekmez ve eklenmez). `setAllowedOriginPatterns` ile mobil için Origin zorunlu değildir; web istemcisi eklenirse izinli origin listesi açıkça verilir (`*` kullanılmaz).
- Uygulama hedef öneki: `/app`. Kullanıcıya özel önek: `/user`. Basit/relay broker hedefleri: `/queue`, `/topic`.
- İletim limitleri (`WebSocketTransportRegistration`): `messageSizeLimit` 16 KB, `sendBufferSizeLimit` 512 KB, `sendTimeLimit` 10 sn, `timeToFirstMessage` ~10 sn (CONNECT göndermeyen bağlantı kapatılır).
- Heartbeat: sunucu 10 sn/istemci 10 sn (`setHeartbeatValue` + `TaskScheduler`); ölü bağlantılar ve presence düzeltmesi için gerekli.

### 2.2 Hedefler (destination) yapısı

İstemci → sunucu (`/app/...`):

| Hedef | Amaç | Yük |
|---|---|---|
| `/app/chat.send` | Mesaj gönder | `{conversationId, clientMsgId, body}` |
| `/app/chat.read` | Okundu imlecini ilerlet | `{conversationId, lastReadMessageId}` |
| `/app/chat.typing` | "yazıyor…" (isteğe bağlı, kalıcı değil, rate limitli) | `{conversationId}` |

Sunucu → istemci (hepsi kullanıcıya özel; `convertAndSendToUser(userId, ...)`):

| Hedef (istemci aboneliği) | İçerik |
|---|---|
| `/user/queue/messages` | Yeni mesaj (`MessageDto`) – kullanıcının tüm konuşmaları için tek kuyruk. Konuşma başına abonelik gerekmez; istemci `conversationId` ile yönlendirir. |
| `/user/queue/receipts` | Gönderene ack: `{clientMsgId, messageId, createdAt}` ve okundu bildirimleri `{conversationId, userId, lastReadMessageId}` |
| `/user/queue/errors` | İşlenemeyen komut hatası: `{code, message, clientMsgId?}` (RATE_LIMITED, NOT_PARTICIPANT, BLOCKED, TOO_LONG…) |
| `/user/queue/presence` | (2. faz) İlgili kişilerin çevrimiçi/çevrimdışı değişimi |
| `/user/queue/typing` | Karşı tarafın yazıyor bilgisi |

Neden konuşma başına `/topic/conversation.{id}` değil? Topic'e abone olmak yetkilendirme sorunu doğurur (her SUBSCRIBE'da katılımcılık sorgusu, abonelik sızıntısı, kullanıcı çıkarıldıktan sonra devam eden abonelik). Kullanıcıya özel kuyruk, sunucunun gönderim anında hedef kullanıcı listesini kendisinin belirlemesini sağlar; yetki kontrolü tek noktada (göndermede) kalır. Grup boyutu küçük kaldığı sürece (örn. ≤ 200) bu fan-out maliyeti kabul edilebilir.

Akış (birebir): istemci `SEND /app/chat.send` → `ChatWsController` kimlik/izin → `MessageService.send` (doğrula, rate limit, temizle, DB'ye yaz, `last_message_*` güncelle) → **işlem commit olduktan sonra** (`@TransactionalEventListener(AFTER_COMMIT)`) her katılımcı için `/user/queue/messages` yayını ve göndericiye `/user/queue/receipts` ack. Böylece istemci hiç kaydedilmemiş bir mesajı almaz.

REST'ten de mesaj gönderilebilir (`POST /api/chat/conversations/{id}/messages`): WebSocket yokken/çevrimdışı kuyruktan boşaltırken kullanışlı ve aynı idempotency anahtarıyla aynı servisi çağırır (bkz. 6.4).

### 2.3 Kimlik doğrulama

İki aşama vardır ve ikisi de gereklidir.

**a) Handshake (HTTP Upgrade).** `SecurityConfig` şu an `anyRequest().authenticated()` olduğundan `/ws` yolu da korunur ve `JwtAuthFilter` `Authorization: Bearer` başlığını okur. Dart tarafında WebSocket el sıkışmasına özel başlık eklenebildiği için (`webSocketConnectHeaders`) başlık yöntemi kullanılabilir. **Token'ı URL sorgu parametresiyle göndermeyiz** (sunucu/proxy günlüklerine sızar). Öneri: `/ws` için `permitAll` yapıp (Upgrade yetkisiz de alınabilir, hemen sonra CONNECT zorunlu) kimliği STOMP CONNECT'te doğrulamak. Bu, istemci kütüphanelerinin başlık desteğine bağımlılığı kaldırır. İki yaklaşım karşılaştırması ve karar Açık sorular'da; varsayılan öneri: **handshake'te `permitAll`, CONNECT'te zorunlu doğrulama, `timeToFirstMessage` ile yetkisiz bağlantıları kısa sürede kes**.

**b) STOMP kanal doğrulaması (`ChannelInterceptor`).** `configureClientInboundChannel` içinde `StompAuthChannelInterceptor`:
- `CONNECT` çerçevesi: `Authorization` native header'ından `Bearer` token alınır → `JwtService.parseUserId` → `null` ise `MessagingException`/ERROR çerçevesi ve bağlantı kapanır. Geçerliyse `accessor.setUser(new UsernamePasswordAuthenticationToken(userId, null, ROLE_USER))`. Not: `Principal.getName()` string üretir; `userId` Long principal'ı korumak için `Authentication.getPrincipal()` kullanılır, `convertAndSendToUser` hedefinde `String.valueOf(userId)` kullanılır (kullanıcı hedef çözümlemesi `Principal.getName()` ile eşleşir).
- Ek kontrol: kullanıcı veritabanında hâlâ var ve `emailVerified` mi? (CONNECT seyrek olduğu için bir sorgu kabul edilebilir; `JwtAuthFilter` bunu yapmıyor, çünkü token yalnızca doğrulanmış kullanıcıya verilir; hesap silme/yasaklama senaryosu için CONNECT'te kontrol önerilir.)
- Token'ın bitiş zamanı `exp` oturum nesnesine (`sessionAttributes["tokenExp"]`) yazılır.
- `SEND`, `SUBSCRIBE`: yalnızca CONNECT'te belirlenen kullanıcı kabul edilir; istemci başka bir kullanıcı kimliği iddia edemez (`user` yalnızca sunucu tarafından atanır).
- Yetkilendirme: Spring Security 7'de `@EnableWebSocketSecurity` + `AuthorizationManager<Message<?>>` ile `messageMatchers` (`/app/**` → `authenticated`, `SUBSCRIBE /user/queue/**` → `authenticated`, `/topic/**` abonelik → reddet, diğer her şey → reddet). Bu, mevcut HTTP zincirinden bağımsızdır; CSRF mesaj katmanında WebSocket için çerez kullanılmadığından (bearer) gereksizdir ve kapatılır (HTTP zincirinde de kapalı).
- İstemcinin `SUBSCRIBE` ile `/user/queue/*` dışında bir yere abone olması engellenir (özellikle `/topic/**` ve başka kullanıcıların hedefleri).

### 2.4 Token süresi dolunca ne olur?

Access token 15 dk. WebSocket bağlantısı ise saatlerce açık kalabilir; CONNECT anındaki kimlik sonsuza kadar geçerli sayılmamalı.

Karar:
1. Sunucu, oturumun `tokenExp` değerini tutar. Her gelen `SEND` çerçevesinde (interceptor) `now > tokenExp + 60 sn tolerans` ise komut reddedilir, `/user/queue/errors`'a `TOKEN_EXPIRED` yazılır ve (ayarlanabilir) bağlantı **kapatılır** (close code 4401 benzeri / STOMP ERROR). Okuma yönünde (sunucudan istemciye) yayın devam edebilir, ancak sonraki SEND başarısız olur.
2. İstemci, `exp`'ten ~60 sn önce proaktif olarak refresh yapar (`/api/auth/refresh`) ve yeni token ile bağlantıyı kurar. Kısa vadede en basit/sağlam yol: bağlantıyı **kapatıp yeni token'la yeniden bağlanmak** (STOMP'ta CONNECT sonrası yeniden kimlik doğrulamanın standart yolu yoktur). İsteğe bağlı iyileştirme: özel bir `/app/auth.refresh` komutu ile oturumdaki `tokenExp`'i yenilemek (yeni JWT doğrulanır, **aynı kullanıcı** olduğu kontrol edilir). İlk sürümde yeniden bağlanma yöntemi tercih edilir; mesaj kaybı yoktur çünkü kalıcılık DB'dedir ve istemci yeniden bağlanınca kaçırdıklarını REST ile çeker (6.3).
3. Süresi dolan oturumları temizlemek için sunucuda periyodik tarama (örn. 60 sn'de bir, kayıtlı oturumlar üzerinde) isteğe bağlıdır; gönderim anındaki kontrol zorunlu olandır.
4. Refresh token geçersizse (rotation sonrası tekrar kullanım, 30 gün doldu, logout): bağlantı kurulmaz, istemci giriş ekranına döner. Logout'ta (`/api/auth/logout`) açık WebSocket oturumunu kapatmak için kullanıcı → oturum eşlemesi (`SimpUserRegistry`) kullanılır; çok sunuculu ortamda bu işlem Redis pub/sub `chat:control` kanalıyla tüm düğümlere yayılır (kullanıcı, başka düğümde bağlı olabilir).

---

## 3. Redis'in rolü

### 3.1 Çok sunuculu ölçekleme

Sorun: Kullanıcı A, sunucu-1'e; kullanıcı B, sunucu-2'ye bağlıysa, sunucu-1'in bellek içi basit broker'ı B'ye ulaşamaz.

Seçenekler:

| Seçenek | Artı | Eksi |
|---|---|---|
| **A. Redis pub/sub ile kendi köprümüz (öneri)** | Zaten Redis var; ek altyapı yok; kontrol bizde. | STOMP kullanıcı hedeflerini kendimiz yönlendiririz. |
| B. STOMP broker relay (RabbitMQ/ActiveMQ STOMP) | Spring'in standart çözümü; `/user` hedefleri düğümler arası otomatik çalışır. | Redis STOMP konuşmaz; yeni altyapı (RabbitMQ + STOMP eklentisi) gerekir. |
| C. Sticky session + tek düğüm | En basit. | Ölçeklenmez, tek hata noktası. |

Öneri (A): **Mesaj önce DB'ye yazılır, sonra Redis kanalına yayımlanır; her düğüm kendi yerel bağlı kullanıcılarına iletir.**
- Kanal: `chat:events` (tek kanal, JSON zarf: `{type: MESSAGE|READ|TYPING|PRESENCE|CONTROL, targetUserIds:[...], payload}`) ya da kullanıcı başına `chat:user:{id}` (bağlı olunan düğümde abonelik gerektirir; `RedisMessageListenerContainer` ile `PatternTopic`). Tek kanal + düğüm tarafı süzme, başlangıç için basit ve yeterlidir; kullanıcı sayısı büyürse düğüm başına abonelik yönetimi yapılır.
- Her düğüm `RedisMessageListenerContainer` ile dinler; gelen olay için `SimpUserRegistry.getUser(userId) != null` ise `SimpMessagingTemplate.convertAndSendToUser(...)` çağırır; değilse atlar. Yayıncı düğüm de kendi olayını aynı yoldan alır (tek kod yolu; özel durum yok).
- Redis pub/sub "en çok bir kez, kalıcı değil" garantisi verir: o anda abone olmayan düğüm mesajı kaçırır. Bu kabul edilebilir çünkü gerçek kaynak DB'dir: bağlantısı kopan/Redis sorunu yaşayan istemci yeniden bağlanınca `afterId` ile eksikleri çeker (6.3). Mesaj için "kesin teslim" gerekirse Redis Streams + tüketici grupları düşünülür (bkz. Açık sorular).
- Çok düğümde çift bildirim olmaması için `AFTER_COMMIT` sonrası **bir kez** yayımlanır.

### 3.2 Presence (çevrimiçi/çevrimdışı)

- Anahtar: `presence:{userId}` → değer: bağlı oturum sayısı ya da `SET presence:{userId}:{sessionId}` biçiminde; TTL ile. Önerilen: **sayaç değil, oturum anahtarları**: `SET presence:{userId}:{sessionId} <nodeId> EX 45`. Heartbeat (10 sn) sırasında TTL yenilenir (interceptor `HEARTBEAT` izleyemez; bunun yerine istemciden her 20–25 sn'de hafif `SEND /app/presence.ping` ya da sunucuda `SessionConnectedEvent` + zamanlanmış yenileme). `SessionDisconnectEvent` ile silinir.
- Neden sayaç değil: düğüm çökerse sayaç asla düşmez; TTL'li oturum anahtarları kendiliğinden temizlenir.
- Çevrimiçi mi? `presence:{userId}:*` taraması yerine daha ucuz: `ZADD presence:online <epoch> userId` (skor = son görülme) ve çevrimiçi eşiği 45 sn. Tek sorgu: `ZSCORE`. Toplu: `ZMSCORE`. Eski kayıtlar periyodik `ZREMRANGEBYSCORE` ile temizlenir. (Bu tasarımda ikincisi önerilir.)
- Gizlilik: Presence bir kişisel veridir. Yalnızca **ortak bir konuşması olan ve engellenmemiş** kişiler birbirinin durumunu görebilir; kullanıcı ayarlarından "çevrimiçi durumumu gizle" seçeneği (varsayılan açık/kapalı kararı Açık sorular'da). "Son görülme" ilk sürümde yok (yalnızca çevrimiçi/çevrimdışı).
- Presence değişim olayı (`ONLINE`/`OFFLINE`) yalnızca durum geçişinde yayımlanır (aynı kullanıcının ikinci cihazı bağlanınca tekrar yayın yok); geçişi tespit etmek için `presence` yazımı sonucu kontrol edilir.
- Push bildirimi: çevrimdışı kullanıcıya mesaj gelince FCM/APNs push (ayrı özellik; bu tasarımda yalnızca kancası: `MessageService` olayı `OfflineNotifier`'a gider). Presence burada "WebSocket'te yoksa push gönder" kararında kullanılır.

### 3.3 Mesaj başına rate limit

Mevcut `RateLimiter` (sabit pencere) bu iş için kullanılabilir ancak sabit pencerenin sınır patlaması vardır (pencere sonu + başında 2N mesaj). Öneri:
- İlk sürüm: mevcut `RateLimiter.check("msg:user:" + userId, 30, Duration.ofMinutes(1))`. Basit, tutarlı. Ek olarak kısa patlamayı engelleyen ikinci kural: `check("msg:burst:user:" + userId, 5, Duration.ofSeconds(5))`.
- Konuşma bazlı ek kural (spam/taciz): `check("msg:conv:" + convId + ":" + userId, 20, Duration.ofMinutes(1))`.
- Yeni kullanıcılar için (hesap yaşı < 24 sa) daha sıkı değerler (örn. 10/dk) – öneri, Açık sorular'da.
- İkinci aşama: pom'da zaten bulunan **Bucket4j + Lettuce** ile token bucket (burst 5, dolum 30/dk). Böylece sınır patlaması olmaz ve tek Redis çağrısıyla atomik çalışır. `RateLimiter` arayüzü korunur; iç uygulama değiştirilir.
- **WebSocket'e özgü**: `RateLimiter` `ApiException` fırlatır; STOMP'ta HTTP exception handler çalışmaz. `@MessageExceptionHandler` + `@SendToUser("/queue/errors")` ile `ApiException` → `ErrorFrame{code,message,clientMsgId}` eşlemesi yazılır. Sınır aşımı bağlantıyı kapatmaz; ancak ardışık çok sayıda aşım (örn. 100/dk) bağlantıyı keser ve kullanıcı için kısa süreli bloklama anahtarı (`ban:msg:{userId}` EX 10 dk) koyar.
- Redis erişilemezse: fail-open (mesaj gitsin) mi, fail-closed mi? Öneri: **fail-closed ama kısa devre** (Redis yokken zaten presence/pub-sub de çalışmaz); kararın kendisi Açık sorular'da.
- Typing olayları için ayrı, çok gevşek bir limit (3 sn'de 1).

---

## 4. REST uçları

Tümü `/api/chat/**` altında; `SecurityConfig`'de ek kural gerekmez (`anyRequest().authenticated()` kapsar). Principal `Long` id olduğundan controller imzası `Authentication auth` → `(Long) auth.getPrincipal()` (mevcut `AuthController.me` deseni). Hata biçimi `ApiException`.

| Uç | Açıklama |
|---|---|
| `GET /api/chat/conversations?cursor=&limit=30` | Kullanıcının konuşmaları. Sıralama: `last_message_at DESC, id DESC`. İmleç: `(last_message_at, id)` kodlanmış opak string. Her öğe: `id`, `type`, karşı taraf (`userId`, `displayName`), `lastMessage{id, body (kısaltılmış), senderId, createdAt}`, `unreadCount`, `muted`. Engellenmiş kişiyle konuşma listede kalır ancak `blocked=true` işaretlenir. |
| `POST /api/chat/conversations` | Birebir başlat/aç: `{userId}` → varsa mevcut konuşmayı döner (idempotent, `direct_key` ile), yoksa oluşturur. Kendi kendine, doğrulanmamış, engelleyen/engellenen kullanıcıyla `403/400`. Grup (2. faz): `{type:"GROUP", title, memberIds}`. |
| `GET /api/chat/conversations/{id}/messages?before=&after=&limit=50` | **İmleç tabanlı** geçmiş (aşağıda). |
| `POST /api/chat/conversations/{id}/messages` | Mesaj gönder (REST yedeği): `{clientMsgId, body}`; WebSocket ile aynı servis ve rate limit. `201` + `MessageDto`; aynı `clientMsgId` tekrar gelirse `200` + mevcut mesaj. |
| `POST /api/chat/conversations/{id}/read` | `{lastReadMessageId}` → imleci ilerlet; `204`. WebSocket `chat.read` ile eşdeğer. |
| `DELETE /api/chat/conversations/{id}/messages/{messageId}` | Yalnızca gönderen, "herkesten sil" (tombstone). Süre sınırı örn. 24 saat (Açık sorular). |
| `DELETE /api/chat/conversations/{id}` | "Benim için sil" → `hidden_before_message_id` = son mesaj id; yeni mesaj gelirse konuşma yeniden görünür. Birebirde karşı tarafın verisini silmez. |
| `GET /api/chat/users/search?q=&limit=20` | Kullanıcı arama (aşağıda). |
| `PUT /api/chat/blocks/{userId}` / `DELETE /api/chat/blocks/{userId}` / `GET /api/chat/blocks` | Engelle / kaldır / listele. |
| `POST /api/chat/reports` | `{messageId?, userId, reason, note?}` → `202`. |
| `GET /api/admin/chat/reports?status=OPEN` | Yönetici raporları (mevcut `/api/admin/**` Basic auth kuralı altında; ek rol işi gerekmez). |

### 4.1 İmleç tabanlı geçmiş

`message.id` tek artan sıra olduğu için imleç doğrudan mesaj id'sidir (offset kullanılmaz; yeni mesajlar geldikçe sayfa kaymaz).
- İlk yükleme: `GET .../messages?limit=50` → en yeni 50 (id azalan).
- Geriye (eski): `before=<en eski görülen id>` → `WHERE conversation_id=? AND id < :before AND id > :hiddenBefore ORDER BY id DESC LIMIT :limit+1`. Yanıt: `{items, nextBefore (null ise başa ulaşıldı)}`.
- İleri (kaçırılanlar, yeniden bağlanma): `after=<son bilinen id>` → `id > :after ORDER BY id ASC LIMIT :limit`, `hasMore` ile.
- `before` ve `after` birlikte verilemez (400). `limit` üst sınırı 100.
- Yetki: istekten önce `participant(conversation_id, user_id, left_at IS NULL)`; yoksa **404** (403 değil; konuşma varlığını sızdırmamak için). Gruptan çıkarılmış kullanıcı, `left_at` anına kadar olan mesajları görsün mü? Açık sorular.
- Yanıt sıralaması istemcide tutarlı olsun diye her zaman id'ye göre aynı yönde döner (örn. `items` artan sırada).

### 4.2 Kullanıcı arama (yalnızca doğrulanmış kullanıcılar)

- Sorgu: `emailVerified = true` **ve** `id <> me` **ve** karşılıklı engel yok.
- Eşleşme: `displayName` ön ek/içerik (`LOWER(displayName) LIKE :q%`). E-posta ile arama, adres taramasına ve e-posta ifşasına yol açar: **e-posta döndürülmez ve e-postayla aranmaz** (yalnızca tam e-posta eşleşmesi seçeneği Açık sorular'da). Yanıt: `{id, displayName}` (gerekirse fakülte/bölüm, varsa).
- `q` en az 3 karakter, en çok 50; `limit` en çok 20; LIKE joker karakterleri (`%`, `_`) kaçırılır.
- Rate limit: `RateLimiter.check("usersearch:user:" + me, 30, Duration.ofMinutes(1))` (kullanıcı listesini toplu çekmeyi zorlaştırır).
- İndeks: `app_user (email_verified, lower(display_name))` (PostgreSQL'de ifade indeksi; H2'de basit indeks). Büyürse `pg_trgm`.
- Kullanıcıların keşfedilebilirliği ayarı (aranabilir/aranamaz) KVKK açısından önerilir; Açık sorular.

### 4.3 Engelleme ve raporlama

- Engel `user_block` satırıdır. Birebir konuşmada: engelleyen mesaj alamaz (sunucu, alıcı tarafında bırakır, **göndericiye engellendiği söylenmez**: gönderen mesajı `SENT` görür ancak teslim edilmez/kaydedilir ve alıcıya iletilmez; alternatif, açık hata dönmek, Açık sorular). Engellenen kişi yeni konuşma başlatamaz ve aramada görünmez.
- Gönderim yolunda kontrol: `MessageService.send` birebirde karşı tarafla engel ilişkisini her iki yönde kontrol eder (kısa Redis önbelleği `block:{a}:{b}`, değişimde silinir).
- Raporlama: konuşmadaki herhangi bir katılımcı mesaj/kullanıcı raporlayabilir. Rapor oluşturulurken mesaj metni `snapshot_body`'ye kopyalanır. Aynı kullanıcı aynı hedefi tekrar raporlayamaz (UNIQUE `reporter_id, message_id`). Rate limit: `report:user:{id}` 10/gün. Bir kullanıcı için `OPEN` rapor eşiği aşılırsa (örn. 5 farklı raporlayan) otomatik kısıtlama/yönetici bildirimi (Açık sorular).
- Raporlayan kişi otomatik olarak engeller mi? İstemcide "raporla ve engelle" seçeneği; sunucu iki ayrı çağrı olarak tutar.

---

## 5. Güvenlik ve kötüye kullanım

### 5.1 Yetkilendirme
- **Tek kural:** bir konuşmanın mesajını/meta verisini yalnızca `conversation_participant` satırı olan ve `left_at IS NULL` kullanıcı okuyabilir/yazabilir. Bu kontrol repository düzeyinde merkezî bir metotla (`requireParticipant(convId, userId)`) yapılır; her REST ve STOMP işleyicisi bunu çağırır. Koleksiyon sorguları da `JOIN participant` ile sınırlıdır (IDOR'a karşı: id tahmin ederek başkasının konuşmasına erişim 404 döner).
- İstemciden gelen `senderId` hiçbir zaman kullanılmaz; gönderen daima kimlikten (`Principal`) alınır.
- Okundu imleci yalnızca kendi katılımcı satırını etkiler.
- WebSocket'te `SUBSCRIBE` yalnızca `/user/queue/*`; `/topic/**` kapalı (bkz. 2.3).
- Yönetici uçları mevcut Basic auth + `ROLE_ADMIN` altında; yönetici rapor görürken ilgili mesaj bağlamı (±N mesaj) görür ve her erişim denetim kaydı (log) olarak tutulur.

### 5.2 Boyut limitleri
- `body`: 1–2000 karakter (Bean Validation `@Size(max=2000)`, `@NotBlank`), UTF-8 bayt sınırı ~8 KB. STOMP çerçeve sınırı 16 KB (`messageSizeLimit`), HTTP gövde sınırı küçük tutulur (`server.tomcat.max-http-form-post-size` yerine istek DTO doğrulaması + `spring.servlet.multipart` kapalı).
- Ek (dosya/görsel) ilk sürümde **yok**; eklenirse ayrı bir nesne depolama + yükleme + virüs/MIME tarama tasarımı gerekir.
- Kullanıcı başına açık WebSocket bağlantısı üst sınırı (örn. 3 cihaz); fazlası en eski bağlantıyı düşürür. IP başına bağlantı hızı: mevcut `RateLimiter` ile `ws-connect:ip:{ip}` 30/dk.
- Konuşma sayısı limitleri: günlük yeni birebir konuşma başlatma sayısı (örn. 20/gün) – toplu taciz/spam için.

### 5.3 XSS / enjeksiyon
- Mesaj gövdesi **düz metindir**; HTML/Markdown işlenmez. Sunucu: kayıt öncesi `Jsoup.clean(body, Safelist.none())` ile etiketler sıyrılır (pom'da jsoup 1.18.3 mevcut) ve ardından kontrol karakterleri (`\u0000`-`\u001F`, newline hariç), yönlendirme/bidi kontrol karakterleri (`U+202A–U+202E`, `U+2066–U+2069`) ve sıfır genişlikli karakter yığınları temizlenir; Unicode NFC normalleştirme; baş/son boşluk kırpma; ardışık çok sayıda yeni satır sınırlanır. Dikkat: `Jsoup.clean` `&` gibi karakterleri `&amp;` biçimine çevirir; bu nedenle ya `Entities.EscapeMode`/`outputSettings.prettyPrint(false)` ile çıktı ayarlanır ya da yalnızca "etiket içeriyor mu" kontrolü yapılıp saf metin `Jsoup.parse(body).text()` ile elde edilir. Seçim uygulama aşamasında testle sabitlenir (örn. `a < b & c` aynen korunmalı).
- **İstemci çıkışı** asıl savunmadır: Flutter `Text` widget'ı metni olduğu gibi çizer (HTML yorumlamaz); WebView/`flutter_html` ile mesaj gösterilmez. Bağlantılar otomatik tıklanabilir yapılacaksa yalnızca `http/https` şeması, kullanıcıya hedef gösterilerek (kimlik avı uyarısı) açılır.
- SQL enjeksiyonu: yalnızca JPA/parametreli sorgular; arama `LIKE` parametreleri kaçırılır; ham SQL birleştirme yok.
- JSON: bilinmeyen alanlar yok sayılır, `Content-Type` doğrulanır; STOMP yükü `Jackson` ile sabit DTO'ya bağlanır (polimorfik tip çözümleme kapalı).
- Günlüklerde mesaj gövdesi **yazılmaz** (yalnızca id'ler/uzunluk).
- CSWSH (Cross-Site WebSocket Hijacking): bearer token kullanıldığı ve çerez yok olduğu için risk düşük; yine de web istemcisi varsa `Origin` doğrulanır.
- Üretimde yalnızca `wss://` (TLS) – düz `ws://` reddedilir/yönlendirilir (ters vekil yapılandırması).

### 5.4 Spam
- Rate limitler (3.3), yeni konuşma başlatma günlük üst sınırı, aynı metni kısa sürede tekrarlama algılama (`SET msgdup:{userId}:{sha1(body)} NX EX 60` – ikinci kez gelirse sessizce engelle/uyar), URL sayısı limiti (bir mesajda en çok 3 bağlantı), rapor sayısı eşiğiyle otomatik kısıtlama, engelleme (4.3).
- Doğrulanmış `bingol.edu.tr` hesabı zorunluluğu zaten bir kimlik/spam bariyeridir; ek olarak mesajlaşma, yalnızca `emailVerified` kullanıcılar için açıktır.
- Davranışsal sinyaller (çok sayıda farklı kişiye ilk mesaj) için sayaç: `newconv:{userId}` EX 1 gün.

### 5.5 KVKK (6698 sayılı kanun)
- **Veri sorumlusu ve aydınlatma:** Mesaj içerikleri kişisel veridir (özel nitelikli veri içerebilir). Aydınlatma metninde amaç, saklama süresi, aktarım (push sağlayıcı), haklar belirtilir; açık rıza gerekip gerekmediği hukuk birimiyle netleştirilir (Açık sorular).
- **Veri minimizasyonu:** E-posta başkalarına gösterilmez (yalnızca `displayName`); sunucu günlüklerinde mesaj metni yok; presence kalıcı saklanmaz (yalnızca Redis TTL).
- **Saklama süresi:** Öneri varsayılan: mesajlar konuşma sona erene/kullanıcı silene kadar, en fazla **N ay/yıl** (örn. 12 ay, Açık sorular). `@Scheduled` günlük iş: `DELETE FROM message WHERE created_at < now - retention` (toplu, `LIMIT` ile parça parça). `deleted_at` ile tombstone'lanmış mesajların gövdesi hemen boşaltılır, satırlar 30 gün sonra tamamen silinir. Raporlara bağlı `snapshot_body` en fazla 1 yıl (veya karar kapanışından 90 gün) saklanır.
- **Silme hakkı / unutulma:** `DELETE /api/auth/me` benzeri hesap silme akışında (henüz yok; ayrı iş) sohbet verileri için: kullanıcının `participant` satırları silinir, gönderdiği mesajlarda `sender_id` NULL'lanır ve `body` boşaltılır ya da konuşma birebirse karşı tarafın kopyası olarak "silinmiş kullanıcı" etiketiyle anonimleştirilir (karşı tarafın hakkı ile denge – hukuki görüş, Açık sorular). Redis'teki `presence`, `rl:*`, `block:*` anahtarları silinir; `user_block` ve `message_report` içindeki kullanıcı kayıtları anonimleştirilir/silinir.
- **Erişim/taşınabilirlik:** `GET /api/chat/export` (kullanıcının kendi gönderdiği ve aldığı mesajlar, JSON) – talep üzerine asenkron üretim; ilk sürümde manuel (yönetici) süreçle de karşılanabilir.
- **Yedekler:** silinen verinin yedeklerde kalma süresi ve yedek saklama politikası belgelenir.
- **Güvenlik önlemleri:** Aktarımda TLS; durağan veride disk şifreleme (PostgreSQL altyapı düzeyi). Uçtan uca şifreleme kapsam dışıdır (sunucu moderasyon/rapor için içeriğe erişebilir; kullanıcıya aydınlatma metninde açıkça yazılır).
- **Denetim kaydı:** yönetici erişimi (rapor inceleme) kim/ne zaman/hangi konuşma olarak kaydedilir.

---

## 6. Flutter istemci tarafı

(Kütüphane önerisi: `stomp_dart_client`; yerel depolama için `sqflite`/`drift` ya da `isar`; güvenli token saklama için `flutter_secure_storage`; bağlantı durumu için `connectivity_plus`. Mevcut `mobile/pubspec.yaml` bağımlılıkları uygulama aşamasında gözden geçirilir.)

### 6.1 Bağlantı yönetimi
- Tek bir `ChatConnection` servisi (singleton), durum makinesi: `disconnected → connecting → connected → reconnecting`. UI bu durumu dinler ("Bağlanılıyor…" bandı).
- Uygulama **ön plandayken** bağlı kalır; arka plana geçince (iOS/Android kısıtlamaları) bağlantı kapatılır ve bildirimler push ile gelir. Öne dönünce yeniden bağlan + eksikleri çek (6.3).
- Oturum kapatma (logout): bağlantı kapatılır, yerel mesaj önbelleği ve kuyruk silinir (başka kullanıcının verisi kalmasın).
- `wss://<host>/ws`; CONNECT başlığında `Authorization: Bearer <access>`; heartbeat 10 sn/10 sn.
- Abonelikler (bağlanınca tek seferde): `/user/queue/messages`, `/user/queue/receipts`, `/user/queue/errors` (+ ileride `presence`, `typing`).

### 6.2 Yeniden bağlanma ve token yenileme
- Üstel geri çekilme + jitter: 1 s, 2 s, 4 s … en çok 30 s; rastgele %20 sapma (sunucu yeniden başladığında herkes aynı anda gelmesin). Ağ yoksa (`connectivity_plus`) deneme yapma, ağ gelince hemen dene.
- Her yeniden bağlanma denemesinden **önce** access token'ın `exp` değeri kontrol edilir (JWT yükünden okunur); 60 sn içinde dolacaksa önce `POST /api/auth/refresh`.
- Refresh çağrısı **tek uçuşta** (single-flight): aynı anda birden fazla bileşen (HTTP istemcisi, WebSocket) refresh isterse tek istek yapılır ve sonuç paylaşılır. Zorunlu: refresh token **tek kullanımlık** olduğundan (rotation, `getAndDelete`) eşzamanlı iki refresh çağrısından biri `401 INVALID_REFRESH_TOKEN` alır ve kullanıcı yanlışlıkla oturumdan atılır.
- Yeni token çiftinin yerel olarak yazılması atomik olmalı (çökme sonrası eski refresh token ile kalma riski): önce yeni çift `flutter_secure_storage`'a yazılır.
- Zamanlayıcı: bağlantı açıkken `exp - 60 sn` anında proaktif refresh → bağlantıyı kapat → yeni token ile yeniden bağlan (bkz. 2.4). Sunucudan `TOKEN_EXPIRED`/ERROR gelirse de aynı akış.
- Refresh `401` (geçersiz/süresi dolmuş) ise: oturum sonlandırılır, giriş ekranı.
- Mesaj gönderimi sırasında HTTP `401` alınırsa (REST yedeği) aynı single-flight refresh sonra tek yeniden deneme.

### 6.3 Boşluk kapatma (resync)
Bağlantı her kurulduğunda (ve uygulama öne geldiğinde): her konuşma için yerelde bilinen en büyük `messageId` ile `GET .../messages?after=<id>` çağrılır (ya da önce `GET /conversations` ile `lastMessage.id` karşılaştırılır; yalnızca ilerleyenler için `after` isteği atılır). Böylece Redis pub/sub veya WebSocket kopması kaynaklı kayıplar kapanır. Gelen mesajlar `id` ile tekilleştirilir (WebSocket ve REST çakışabilir) ve `clientMsgId` ile yerel "gönderiliyor" kayıtları eşlenir.

### 6.4 Çevrimdışı kuyruk
- Gönderilen her mesaj önce yerel veritabanına `status=PENDING`, `clientMsgId=UUIDv4`, `createdAtLocal` ile yazılır ve arayüzde hemen görünür (iyimser).
- Kuyruk işleyici (bağlantı `connected` olunca ve ağ gelince): `PENDING` kayıtları sıralı (konuşma başına sıra korunur) olarak WebSocket `chat.send` ile gönderir. Ack (`/user/queue/receipts` ile `clientMsgId` eşleşmesi) gelince `SENT` + sunucu `messageId`. Ack 10 sn gelmezse REST yedeği (`POST .../messages`) ile aynı `clientMsgId` kullanılarak yeniden denenir; sunucu idempotent olduğundan çift mesaj oluşmaz.
- Kalıcı hatalar (`NOT_PARTICIPANT`, `BLOCKED`, `TOO_LONG`) → `FAILED`, kullanıcıya "tekrar dene/sil". `RATE_LIMITED` → geri çekilmeyle otomatik yeniden dene.
- Kuyruk üst sınırı (örn. 100 bekleyen mesaj) ve eski bekleyenler için zaman aşımı (örn. 24 sa → `FAILED`).
- Yerel önbellek: son N mesaj konuşma başına saklanır; çevrimdışıyken açılan sohbet önbellekten okunur. Okundu imleci değişiklikleri de kuyruklanır (yalnızca en son değer gönderilir).
- Uygulama sonlandırılırsa kuyruk kalıcıdır (yerel DB); açılışta yeniden işlenir.

### 6.5 Diğer
- Okundu: bir sohbet ekranı görünür ve öndeyken, listenin sonuna kadar kaydırılmışsa `chat.read` (debounce ~1 sn) gönderilir.
- Erişilebilirlik/güvenlik: mesaj metni `Text` ile (HTML yok); panoya/ekran görüntüsü politikaları ürün kararı.

---

## 7. Uygulama aşamaları ve test stratejisi

### 7.1 Aşamalar

**Faz 0 – Hazırlık** 
- `ChatProperties` (limitler, retention), `application.properties` ayarları (rate limit sayıları, WS limitleri), Redis anahtar önekleri belgesi (`rl:`, `rt:` mevcut; yeni: `presence:`, `chat:events`, `block:`).
- Hata kodları: `NOT_PARTICIPANT`, `BLOCKED`, `MESSAGE_TOO_LONG`, `TOKEN_EXPIRED`.

**Faz 1 – Birebir mesajlaşma (REST önce)**
1. Entity + repository + şema: `Conversation`, `ConversationParticipant`, `Message`, `UserBlock`. (Üretimde `ddl-auto=update` yerine Flyway/Liquibase geçişi önerilir; Açık sorular.)
2. `MessageService` (yetki, temizleme, idempotency, rate limit, `last_message_*`).
3. REST: konuşma aç/listele, geçmiş (imleç), mesaj gönder, okundu, kullanıcı arama.
4. Birim + entegrasyon testleri (7.2). Flutter: konuşma listesi + sohbet ekranı REST ile (yoklama/çekme ile çalışan ilk sürüm).

**Faz 2 – Gerçek zamanlı (tek düğüm)**
5. STOMP yapılandırması, `StompAuthChannelInterceptor`, mesaj yetkilendirme, `chat.send/read`, `/user/queue/*` yayını (AFTER_COMMIT).
6. Token süresi akışı (2.4), `@MessageExceptionHandler`.
7. Flutter: `ChatConnection`, yeniden bağlanma, token yenileme, çevrimdışı kuyruk, resync.

**Faz 3 – Çok düğüm ve presence**
8. Redis pub/sub köprüsü (`chat:events`), presence (ZSET), engelleme/rapor, yönetici rapor ucu.
9. İki düğümlü uçtan uca test; yük testi.

**Faz 4 – Sertleştirme ve ek özellikler**
10. KVKK işleri (retention işi, dışa aktarma, hesap silmede anonimleştirme), Bucket4j token bucket'a geçiş, push bildirimi kancası, tekrar/URL spam kuralları.
11. Grup konuşmaları (rol, katılma/ayrılma, üye ekleme limitleri).
12. Gözlemlenebilirlik: Actuator/Micrometer metrikleri (`chat.ws.sessions`, `chat.messages.sent`, `chat.ratelimit.rejected`, pub/sub gecikmesi).

### 7.2 Test stratejisi

Pom'da test bağımlılıkları var (`spring-boot-starter-*-test`); Testcontainers eklenmemiş: **`org.testcontainers:testcontainers`, `junit-jupiter` ve (PostgreSQL gerekirse) `postgresql`** `test` kapsamında eklenir.

1. **Birim testleri** (Mockito, hızlı): `MessageService` (yetkisiz, engelli, boy, idempotency, rate limit çağrısı), metin temizleyici (XSS örnekleri, bidi, `a < b & c`), imleç hesaplama (okundu geri gitmez), `direct_key` üretimi.
2. **Repository testleri** (`@DataJpaTest`, H2): sayfalama sorguları (before/after, sınırlar, `hidden_before`), unique kısıtları, okunmamış sayısı. PostgreSQL'e özgü ifade indeksleri/SQL'ler varsa aynı testler Testcontainers PostgreSQL ile de koşar.
3. **Redis entegrasyon testleri (Docker + Testcontainers):**
   - `GenericContainer("redis:7-alpine").withExposedPorts(6379)`; `@DynamicPropertySource` ile `spring.data.redis.host/port` ayarlanır.
   - `RateLimiter`/mesaj limiti: pencere aşımında 429, pencere sonrası serbest kalma (kısa pencere ile), farklı kullanıcıların birbirini etkilememesi.
   - Presence: bağlan/ayrıl/TTL dolması (kısa TTL ile).
   - Pub/sub köprüsü: **iki ayrı uygulama bağlamı** (iki `SpringApplication` örneği, farklı portlar, aynı Redis ve aynı DB) başlatılır; istemci A düğüm-1'e, B düğüm-2'ye STOMP ile bağlanır; A mesaj gönderince B'nin `/user/queue/messages` kuyruğundan aldığı doğrulanır. Docker yoksa bu testler `@EnabledIf`/`assumeTrue(DockerClientFactory.instance().isDockerAvailable())` ile atlanır (CI'da zorunlu).
4. **WebSocket uçtan uca (`@SpringBootTest(webEnvironment = RANDOM_PORT)` + `WebSocketStompClient`):** geçerli token ile CONNECT başarılı; token yok/bozuk → ERROR/kapanış; süresi dolmuş token (kısa `jwt.access-ttl-minutes` ya da `Clock` enjekte edilmiş `JwtService`) → CONNECT reddi, bağlantı sırasında dolarsa `SEND` reddi; `/topic/**` ve başka kullanıcı kuyruğuna SUBSCRIBE reddi; katılımcı olmayanın `SEND`'i reddi; kullanıcı kimliği sahteciliği (başka `senderId` göndermek) etkisiz.
5. **REST güvenlik testleri (`MockMvc`/`@WithMockUser` yerine gerçek JWT):** başkasının konuşması 404, kimlik doğrulamasız 401, arama sonucunda doğrulanmamış kullanıcı ve e-posta yok, engellenen kişi aramada yok.
6. **KVKK testleri:** retention işi eski mesajları siler (zaman `Clock` ile ilerletilir), hesap silmede anonimleştirme.
7. **Mobil:** `ChatConnection` durum makinesi ve backoff için birim testleri (sahte zamanlayıcı); single-flight refresh yarış testi; çevrimdışı kuyruk (kalıcılık + yeniden deneme + idempotency); `integration_test` ile yerel backend'e karşı bir duman testi.
8. **Yük/dayanıklılık (Faz 3 sonu):** k6/Gatling ile örn. 2 000 eşzamanlı bağlantı, düğüm yeniden başlatma, Redis kesintisi (mesajlar DB'de kalır, istemciler resync ile telafi eder), sunucu ve istemci heartbeat zaman aşımı.
9. **CI:** Docker destekli runner'da `mvn verify`; Redis/Postgres konteynerleri Testcontainers ile; ayrı profil `-Pintegration` istenirse yavaş testler ayrılır.

---

## 8. Açık sorular

1. **Kimlik id'si:** Konuşma/mesaj id'leri ardışık `BIGINT` mı (basit, imleç dostu) yoksa dışarıya UUID/opak mı? (IDOR savunması zaten yetki kontrolüyle sağlanıyor; ardışık id toplam hacmi sızdırır.)
2. **Handshake kimlik doğrulaması:** `/ws` için `permitAll` + CONNECT'te zorunlu doğrulama (önerilen) mi, yoksa handshake'te bearer başlığı zorunlu mu? Hedef istemciler (yalnızca Flutter mi, web de gelecek mi?) ve ters vekilin başlık geçirmesi netleşmeli.
3. **Token süresi dolunca:** Yeniden bağlanma (önerilen) yeterli mi, yoksa `/app/auth.refresh` ile bağlantı içinde yenileme istenir mi? Süre dolumunda bağlantı hemen mi kapatılsın, yalnızca `SEND` mi reddedilsin?
4. **Ölçekleme altyapısı:** Redis pub/sub köprüsü (A) mı, RabbitMQ STOMP relay mi? Mesajlar için "en az bir kez teslim" gereksinimi var mı (Redis Streams)? Hedef eşzamanlı kullanıcı sayısı nedir?
5. **Rate limit değerleri:** Dakikada 30 mesaj, 5 sn'de 5 patlama uygun mu? Yeni hesaplar için daha sıkı sınır? Redis erişilemezse fail-open mı fail-closed mı?
6. **Grup mesajlaşma:** Kimler grup açabilir (herkes mi, yalnızca belirli roller mi)? Maksimum üye sayısı? Sonradan katılan geçmişi görür mü? Gruptan çıkarılan, çıkış anına kadarki mesajları görmeye devam eder mi? Okuyanlar listesi gerekli mi?
7. **Kullanıcı keşfi:** İsimle arama yeterli mi (e-posta ile arama olmasın)? Kullanıcı "aranamaz" olabilsin mi? Fakülte/bölüm/öğrenci-personel ayrımı gibi ek filtreler var mı? Tüm doğrulanmış kullanıcılar birbirine yazabilsin mi, yoksa ortak bölüm/ders şartı mı?
8. **Engellenen kişiye davranış:** Sessizce teslim etmeme (taciz edenin fark etmemesi) mi, açık hata mı?
9. **Presence gizliliği:** Çevrimiçi durum varsayılan açık mı kapalı mı? "Son görülme" istenir mi?
10. **KVKK:** Saklama süresi kaç ay/yıl? Açık rıza mı, hukuki sebep mi? Hesap silinirken karşı tarafın kopyasındaki mesajlar silinsin mi anonimleşsin mi? Yönetici moderasyonunun içeriğe erişim kapsamı ve denetim süreci? Veri sorumlusu (üniversite birimi) kim? Uçtan uca şifreleme istenir mi?
11. **Mesaj düzenleme/silme:** Düzenleme olacak mı? "Herkesten sil" için zaman sınırı?
12. **Push bildirimleri:** FCM/APNs kullanılacak mı? Bildirim içeriğinde mesaj metni gösterilsin mi (gizlilik)? Ayrı bir tasarım gerekir.
13. **Eklenti desteği:** Görsel/dosya gönderimi planlanıyor mu? (Depolama, tarama, KVKK etkisi.)
14. **Şema yönetimi:** `ddl-auto=update` yerine Flyway/Liquibase'e geçiş zamanı (özellikle üretim PostgreSQL'e geçişte)? H2 geliştirme ve PostgreSQL üretim farkları (ifade indeksleri) için test stratejisi.
15. **Moderasyon:** Anahtar kelime filtresi / otomatik küfür tespiti istenir mi? Raporlar kim tarafından, hangi SLA ile incelenir? Rapor eşiği aşımında otomatik kısıtlama uygulansın mı?
16. **Çok cihaz:** Aynı kullanıcı birden çok cihazdan bağlanabilir mi (varsayılan evet, en çok 3)? Okundu imleci cihazlar arası senkron (sunucu imleci ortak olduğundan evet).

## T13 — Sohbet özellikleri (V92)

Hepsi şifreli mesaj altyapısı üzerindedir; `Message.body` hâlâ yalnızca bellekte. Yetki sırası: mesaj yok / üye değil / gruba katılmadan önceki mesaj -> **404** (varlık sızdırılmaz); üye ama yetkisiz -> 403. Engelli birebirde düzenleme ve tepki 403 `BLOCKED`; askıdaki/silinen hesap 403 `ACCOUNT_SUSPENDED`. Tüm yazma uçları rate limitlidir.

| Özellik | Uç | Kurallar |
|---|---|---|
| Yanıtlama | `POST /api/conversations/{id}/messages` gövdesinde `replyToMessageId` (WS `chat.send` aynı alan) | Aynı konuşma, silinmemiş/gizlenmemiş, gruba katılma sonrası mesaj; aksi 404 `MESSAGE_NOT_FOUND`. Cevapta `replyTo{id,senderId,text,deleted}`: önizleme **çözülmüş, 100 karaktere kısaltılmış**; hedef sonradan silinirse `deleted=true`, metin "Bu mesaj silindi". Gruba sonradan katılan, öncesindeki mesajın önizlemesini görmez. |
| Düzenleme | `PATCH /api/messages/{id}` `{text}` | Yalnız gönderen; `app.chat.edit-window-minutes` (varsayılan 15) sonrası 403 `MESSAGE_EDIT_EXPIRED`. Yeni nonce ile **yeni şifreli gövde yazılır**; eski şifreli sürüm `message_revision`'a arşivlenir (T24; yalnızca yönetici görüntüleyici gösterir) (AAD gönderen+clientId aynı kalır). Aynı metin = işlem yok. `edited`/`editedAt` döner. Silinmiş/gizlenmiş 409 `MESSAGE_NOT_EDITABLE`. |
| Herkes için silme | `DELETE /api/messages/{id}` | Gönderen (`app.chat.delete-window-minutes`, 0 = sınırsız) veya **grup yöneticisi** (süresiz). T24 ile DEĞİŞTİ: `deleted_at/deleted_by` işaretlenir, şifreli gövde/nonce/sürüm, yanıt bağı ve `edited_at` **saklanır**; kullanıcı API'si yalnızca "Bu mesaj silindi" döner (içerik, yanıt önizlemesi, ek meta verisi yok; ek erişimi kapalı, ek baytları yönetici önizlemesi için saklanır), tepkiler silinir. İdempotent (204). Saklama süresi `app.chat.deleted-retention-days` (0 = süresiz). Yönetici, silinmiş mesajı kullanıcı bazlı sohbet görüntüleyicide çözülmüş görür (bkz. ENCRYPTION.md §4, ADMIN_API.md T24). KVKK dışa aktarımı silinmişleri içermez. |
| Tepkiler | `PUT /api/messages/{id}/reaction` `{emoji}`, `DELETE ...` , `GET /api/messages/reactions` (izinli liste) | Mesaj başına kullanıcı başına 1 tepki (tekrar PUT emojiyi değiştirir; DB `UNIQUE`). İzinli liste `app.chat.reactions` (virgüllü; boş = 👍 ❤️ 😂 😮 😢 🙏); U+FE0F farkı yok sayılır; dışı 400 `REACTION_NOT_ALLOWED`. Mesaj görünümünde `reactions:[{emoji,count}]` + `myReaction`. Tepkiler push/bildirim üretmez. Engelli kullanıcıların tepkileri sayaca dahildir (basitlik; gizlilik sızıntısı yok, yalnız sayı). |
| Okunmamış sayaçları | `GET /api/conversations/unread-count`; `ConversationView.unreadCount` | Mevcut okundu imleci üzerine (`last_read_message_id`); kendi, gizlenmiş ve **silinmiş** mesajlar sayılmaz. `total` = sessize alınmamış konuşmaların toplamı (uygulama rozeti), `mutedTotal` = sessizdekiler, `conversations[]` dökümü. |
| Sessize alma | `PUT /api/conversations/{id}/mute` `{durationMinutes}` veya `{forever:true}`; `DELETE` | `muted_until` (üye başına). **Karar:** sessizdeyken push YOK ve uygulama içi bildirim satırı YOK (`NotificationService.sendNewMessage` hiç çağrılmaz); WebSocket teslimi ve okunmamış sayacı DEĞİŞMEZ (sayaç artar, rozet toplamı sessizleri dışarıda bırakır). T16 `quietHours` bundan bağımsız ikinci süzgeçtir: sessiz değilse `sendNewMessage` yine quietHours'a tabidir. Süre dolunca otomatik açılır. |
| Arşiv | `PUT /api/conversations/{id}/archive` `{keepArchived}`; `DELETE`; liste `?archived=true` | `archived_at` (üye başına). Varsayılan liste arşivdekileri göstermez. Yeni mesaj gelince arşivden ÇIKAR (`keepArchived=false`); `keepArchived=true` ise arşivde kalır (okunmamış sayacı artmaya devam eder). |
| Mesaj arama | — (sunucuda YOK) | **Karar:** mesajlar şifreli olduğundan sunucu tarafı arama yapılmaz (`SearchProvider`'a MESSAGE eklenmez; bu hem düz metin dizini hem anahtar sızıntısı riski olur). Yerine **istemci tarafı arama** kontratı: istemci `GET /api/conversations/{id}/messages?before=<id>&size=<=50` ile sayfalayıp çözülmüş metni yerelde tarar. Güvenlik: yalnız kendi (aktif üyesi olduğu) konuşmaları, gruba katılma öncesi görünmez, engelli gönderici metni gizli, silinen/gizlenen içerik yok; uç `msg:history:<uid>` 120 istek/dk ile sınırlıdır (toplu çözme taraması yavaşlar); sayfa başı yalnız dönen kayıtlar çözülür. İstemci sonucu diske düz yazmamalıdır. |

### WebSocket olayları
`/user/queue/message-events` (abonelik beyaz listesine eklendi; başka hedef yok): `{type, conversationId, messageId, userId, message?, emoji?, reactions?, at}`.
`edited` (güncel `message` ile), `deleted`, `reaction` (`emoji` null = kaldırıldı; `reactions` toplam sayaçlar). Okundu olayı mevcut `/user/queue/read-receipts` kuyruğudur. Hepsi `ChatEventBus` -> `BusCipher` ile şifreli çerçeve olarak Redis'e gider; alıcılar aktif üyeler (engel ilişkisi olanlar ve eylemi yapanın diğer cihazları hariç/dahil kuralı `messages` ile aynı). Kaçırılan olaylar için gerçek kaynak REST geçmişidir (`edited/deleted/reactions` alanları geçmiş cevabında da vardır).

### Hata kodları (3 dilde)
`MESSAGE_NOT_OWNER`, `MESSAGE_NOT_EDITABLE`, `MESSAGE_EDIT_EXPIRED`, `MESSAGE_DELETE_FORBIDDEN`, `MESSAGE_DELETE_EXPIRED`, `REACTION_NOT_ALLOWED` (+ mevcut `MESSAGE_NOT_FOUND`, `BLOCKED`, `VALIDATION_ERROR`). Yeni bildirim şablonu yoktur (tepki/düzenleme/silme push üretmez).

### KVKK
`DataExporter` `messageReactions`: verilen tepkiler + sessize alma/arşiv ayarları; `sentMessages` artık `deleted/editedAt/replyToMessageId` alanlarını da içerir (silinenin metni null). Hesap silmede tepkiler kişisel veri taşımayan anonim hesaba bağlı kalır.
