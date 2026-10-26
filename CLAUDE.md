# CLAUDE.md — BÜ Kampüs (Bingöl Üniversitesi) Projesi

Bu dosya, repoda çalışan yapay zekâ ajanları ve geliştiriciler için kılavuzdur. Burada yazanlar koddaki mevcut duruma dayanır; kodla çeliştiğini görürseniz dosyayı güncelleyin.

İlgili belgeler: [docs/MVP.md](docs/MVP.md) (yol haritası), [docs/API_PLAN.md](docs/API_PLAN.md) (modül planı), [docs/ADMIN_API.md](docs/ADMIN_API.md) (yönetim paneli API sözleşmesi), [docs/MESSAGING_DESIGN.md](docs/MESSAGING_DESIGN.md), [docs/ONERILER.md](docs/ONERILER.md) (öncelikli öneri listesi), [docs/CHANGELOG.md](docs/CHANGELOG.md), [docs/MOBILE_API_GUIDE.md](docs/MOBILE_API_GUIDE.md) (mobil API rehberi), [docs/MOBILE_UI.md](docs/MOBILE_UI.md), [docs/PUSH_SETUP.md](docs/PUSH_SETUP.md), [docs/MOBILE_PUSH.md](docs/MOBILE_PUSH.md), [docs/DEPLOY.md](docs/DEPLOY.md) (üretim), [docs/PERFORMANCE.md](docs/PERFORMANCE.md), [docs/ENCRYPTION.md](docs/ENCRYPTION.md), [docs/MEDIA_PIPELINE.md](docs/MEDIA_PIPELINE.md). Modül bazlı API/davranış değişiklik notları: `docs/changes/*.md` (auth, mail, push, event, community, messaging, profile, news, ops).

## 1. Proje özeti ve mimari

Bingöl Üniversitesi öğrenci/personel uygulaması: haber-duyuru-etkinlik ve yemek listesi, üyelik (yalnız `bingol.edu.tr`), profil, bildirimler, mesajlaşma, topluluklar, etkinlikler (QR + elle yoklama), favoriler/arama, destek, sözleşmeler, yönetim paneli.

- `backend/` — Spring Boot 4.1.x, Java 17, Maven; PostgreSQL 16 (Flyway), Redis, WebSocket/STOMP, JJWT, jsoup, Firebase Admin (isteğe bağlı), Lombok
- `web/` — React + TypeScript (Vite): herkese açık tanıtım sitesi + `/admin` yönetim paneli (bkz. `web/README.md`)
- `mobile/` — Flutter (iOS/Android), paket `bu_kampus`: kayıt/giriş/doğrulama/şifre sıfırlama + Ana Sayfa, Keşfet, Sohbet (kişi/kulüp/etkinlik, gerçek zamanlı), Kulüpler, Etkinlikler (QR), Yemek, Bildirimler, Arama, Destek, Profil, Ayarlar; açık/koyu tema. Mimari ve derleme: [docs/MOBILE_UI.md](docs/MOBILE_UI.md); tasarım şablonları `mobile/design/*.dc.html`. iOS Windows'tan `xcross` ile derlenir (Türkçe karakterli yolda ASCII junction `C:\bu_mobile`, `PUB_CACHE=C:\pubcache`, Flutter `C:\src\flutter`)
- `docker-compose.yml` — postgres, redis, backend (ve varsa web)

### Backend paket haritası (`backend/src/main/java/edu/bingol/backend/`)

| Paket | İçerik |
|---|---|
| `news`, `menu`, `status` | Scraper'lar + senkronizasyon + sorgu servisleri; `SyncStatus` ile bakım durumu (`GET /api/status`) |
| `auth` (+ `auth.jwt`, `auth.token`) | Bekleyen kayıt (Redis `reg:<email>`) + e-posta doğrulama, giriş, refresh, `logout-all`, şifre sıfırlama (`forgot-password` → `verify-reset-code` → `reset-password`); `JwtService`, `JwtAuthFilter`, `RefreshTokenService`, `SessionService` (`revokeAll`), `VerificationService`. Ayrıntı: `docs/changes/auth.md` |
| `mail` | E-posta kuyruğu: `MailService.enqueue` → `mail_outbox` tablosu → `MailQueueWorker` (`FOR UPDATE SKIP LOCKED`, 5 dk kira, geri çekilme 1 dk/5 dk/30 dk/2 sa/12 sa, `app.mail.max-attempts` sonra DEAD); `MailTemplate` + `i18n/mail*.properties` + `mail-templates/layout.html` (tr/en/ar, HTML + düz metin); `mailQueue` sağlık göstergesi. Ayrıntı: `docs/changes/mail.md` |
| `user`, `profile` | `User` varlığı (rol, durum, dil, bölüm…), profil, kullanıcı arama, hesap silme (anonimleştirme) |
| `notification` (+ `fcm`, `campaign`) | Cihaz kaydı (`platform`, `appVersion`, `locale`, `lastSeenAt`; 60 gün görülmeyen token gece temizlenir), uygulama içi liste, tercihler; `PushDispatcher` (asenkron FCM gönderimi, 500'lük parçalar, 3 yeniden deneme, UNREGISTERED token silme, `targetType`/`targetId` yükü, Android kanalları, APNs ayarları, `fcm` sağlık göstergesi); yönetici push kampanyaları (hedef kitle, 3 dil, zamanlama). Ayrıntı: `docs/changes/push.md` |
| `moderation` | Engelleme, raporlama, `ReportTargetHandler` SPI, kullanıcı askıya alma, admin rapor kuyruğu |
| `messaging` (+ `ws`, `media`, `room`) | Birebir/grup sohbet, STOMP `/ws`, Redis pub/sub, presence; yanıt/düzenleme/herkes için silme/tepki, sessize alma (`mutedForever`)/arşiv, okunmamış sayacı, sohbet görselleri (`media`: `/api/conversations/{cid}/media`, ayrıntı `docs/changes/messaging.md`); kulüp/etkinlik odaları (`chat_room_link`, `RoomConversations`): `GET /api/communities/{id}/chat`, `GET /api/events/{id}/chat` → `ConversationView.type` `CLUB`/`EVENT` + `communityId`/`eventId` (kalıcı tür `GROUP` kalır; tür/kaynak bağlantıdan türetilir) |
| `community`, `event` | Topluluklar, kullanıcı etkinlikleri, RSVP, QR + elle yoklama, hatırlatmalar |
| `bookmark`, `search` | Haber favorileri; `SearchProvider` SPI ile PostgreSQL Türkçe tam metin arama |
| `support` (`feedback`, `ticket`, `faq`) | Geri bildirim + öneri panosu, destek talepleri, SSS |
| `legal` | Sürümlü sözleşmeler (tr/en/ar) + kullanıcı onay kayıtları |
| `appinfo` | Uygulama bilgisi, sürüm kontrolü, bakım modu, banner (`app_setting`) |
| `export` | `DataExporter` SPI — KVKK "verilerimi indir" (`GET /api/users/me/export`) |
| `i18n` | `Lang` (tr/en/ar), `I18n` servisi, `Accept-Language` çözümleyici. Metin dosyaları `src/main/resources/i18n/<modül>.properties` (+`_en`, `_ar`): `messages` (çekirdek), `auth`, `mail`, `push`, `event`, `community`, `messaging`, `profile`, `news`, `ops`; `spring.messages.basename` hepsini sayar — yeni modül dosyası eklenince basename'e de eklenir |
| `crypto`, `media` | Mesaj şifreleme (zarf şifreleme, `CRYPTO_MASTER_KEYS`; bkz. `docs/ENCRYPTION.md`) ve görsel hattı (`MediaService`: tür/boyut doğrulama, yeniden kodlama, EXIF temizliği; bkz. `docs/MEDIA_PIPELINE.md`) |
| `common` | `ApiException`, `ApiExceptionHandler`, `ApiAuthenticationEntryPoint` (401 `{code,message}`), `RateLimitedException` (429 + `Retry-After`), `RateLimiter`, `CurrentUser`, `CursorPage`, `Hashing`, `storage/` (`FileStorage`, `/files/**`) |
| `config` | `SecurityConfig`, `WebConfig` (ETag), `CorsConfig`, `*Properties` (`@ConfigurationProperties` record'ları), `ProdSettingsValidator` (prod profilinde eksik/güvensiz sırrı açılışta reddeder), `SchedulerLock` (Redis `SET NX PX` ile çoklu örnek kilidi; altyapı hazır, `@Scheduled` görevleri henüz sarmalanmadı — bkz. `docs/DEPLOY.md` bölüm 6) |

Katman kuralı: **Controller → Service → Repository**. Controller yalnızca HTTP eşlemesi + rate limit yapar; entity'ler API'ye doğrudan dönmez, `dto/` (veya modül içi) record'larına çevrilir.

### SPI'lar (modüller arası gevşek bağ)
- `ReportTargetHandler` (moderation): raporlanabilir içerik türleri (USER, MESSAGE, POST, COMMUNITY, EVENT) kendi handler bean'ini yazar.
- `SearchProvider` (search): genel aramaya katılan türler.
- `DataExporter` (export): kullanıcının kendi verisini dışa aktaran bölümler.
- `NotificationService` (notification): `send`, `sendLocalized`, `broadcast(Localized)`, `sendBulk` — diğer modüller bildirimi yalnızca buradan gönderir.

### Redis'in rolü
Doğrulama kodu (`vc:*`), refresh token (`rt:*`, yalnız SHA-256 hash), rate limit (`rl:*`), askıya alınan kullanıcı işareti (`suspended:<id>`), presence (`presence:*`, `lastseen:*`), mesajlaşma pub/sub kanalı, bekleyen kayıt (`reg:<email>`, 1 sa), kod kilidi (`vc:lock:<email>`), oturum iptali (`rtu:<uid>` refresh kümesi, `pwchg:<uid>` şifre/oturum değişim anı), `schedlock:<ad>` görev kilidi. Redis yoksa auth/mesajlaşma çalışmaz; haber/menü okuma uçları Redis'e dokunmaz.

### Zamanlayıcılar (`Europe/Istanbul`)
| Görev | Varsayılan | Ayar |
|---|---|---|
| Haber/duyuru/etkinlik çekimi | her gece 00:00 | `news.sync.cron` |
| Yemek listesi | ayın son günü 23:30 | `menu.sync.cron` |
| Push kampanya dağıtıcı | 10 sn'de bir (`FOR UPDATE SKIP LOCKED`) | `app.push.poll-ms` |
| Etkinlik hatırlatma | 1 gün / 1 saat önce | event paketi |
| Mail kuyruğu işleyici | `app.mail.queue-poll-ms` (5 sn) ve yeni kayıtta; 30 günden eski SENT/DEAD kayıtlar gece silinir | `app.mail.*` |
| Eski cihaz token temizliği | her gece 04:00 (60 gün görülmeyen) | `app.push.device-cleanup-cron`, `app.push.device-ttl-days` |
| Sohbet odası bakımı | 5 dk (kapanan/yasaklı üyelerin düşürülmesi) | `app.chat.room-purge-ms` |

Açılışta tablolar **boşsa** ilk doldurma **arka planda** bir kez yapılır (`app.sync.initial-fill`). Manuel: `POST /api/admin/sync`, `/api/admin/sync-menu`.

### "Bakımda" mekanizması
Kaynak site değişir/ulaşılmazsa senkronizasyon exception fırlatmaz; `StatusService.markMaintenance` çağrılır, eski veri sunulur. `GET /api/status` → `{NEWS:{maintenance,…}, MENU:{…}}`. Ek olarak yönetici ayarı `maintenance_mode` uygulama genelinde bakım bandı gösterir (`GET /api/app/info`).

## 2. Çalıştırma, derleme, test

**Önemli:** Bu makinede yalnızca **Java 8** var; backend Java 17 ister → derleme/test **Docker'daki Maven 17 konteynerinde** yapılır. Flutter `C:\src\flutter` altında (mobil derleme/test ASCII `C:\bu_mobile` yolundan). Node 24/npm 11 yerelde var (web için).

```bash
# backend/ içinde (Git Bash)
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test

# tüm yığın
cp .env.example .env        # DB_PASSWORD, JWT_SECRET, ADMIN_PASSWORD zorunlu
docker compose up -d --build
curl localhost:8080/actuator/health
```

- Şema **yalnızca Flyway** ile yönetilir (`ddl-auto=validate`). Testler H2 + `spring.flyway.enabled=false` + `create-drop` kullanır (`src/test/resources/application.properties`; main'deki dosyanın **yerine geçer**, gerekli anahtarlara orada varsayılan verin).
- PostgreSQL'e özel native sorgular H2'de çalışmaz: bunlar **duman betikleriyle** doğrulanır.
- **Duman betikleri** (`scripts/`, çalışan compose yığınına karşı, ASCII, tekrar çalıştırılabilir): `smoke.sh` (çekirdek), `smoke-support.sh` (destek/sözleşme/i18n/kampanya), `smoke-search.sh`, `smoke-messaging.sh`, `SKIP_REMINDER=1 smoke-communities-events.sh`, `SLOW=1 node ws-test.js`. Betikler arasında `docker compose exec -T redis redis-cli flushall` (kayıt ucu IP başına saatte 10 ile sınırlı). Yeni modül = yeni duman betiği. Performans: `BASE=http://localhost:8080 node scripts/perf/perf-api.js` mobilin ana yollarını ölçer (p50/p95/p99, 304/ETag; eşik `PERF_P95_MS`, varsayılan 400 ms; test kullanıcısı `mobil.test@bingol.edu.tr` kayıtlı olmalı) — bkz. `scripts/perf/README.md`, `docs/PERFORMANCE.md`.
- `.env` yalnızca yerel (gitignored). Admin uçları: JWT `ROLE_ADMIN` (kullanıcı `ADMIN_EMAILS` listesindeyse) veya Basic auth `admin:$ADMIN_PASSWORD`.

### Ortam değişkenleri
Üretim: `SPRING_PROFILES_ACTIVE=prod` (`application-prod.properties`: `forward-headers-strategy=framework`, Swagger kapalı, yalnız `health,info` actuator). `ProdSettingsValidator` açılışta `DB_PASSWORD`, `JWT_SECRET`, `ADMIN_PASSWORD`, `CORS_ORIGINS`, `CRYPTO_MASTER_KEYS`, `MAIL_HOST` (`MAIL_ENABLED=true` iken) eksik/güvensizse uygulamayı **başlatmaz** (değer log'a yazılmaz). Kurulum, yedek, ölçekleme: [docs/DEPLOY.md](docs/DEPLOY.md).

`DB_URL/DB_USER/DB_PASSWORD`, `REDIS_HOST/PORT`, `JWT_SECRET` (≥32 karakter, üretimde zorunlu), `ADMIN_PASSWORD`, `ADMIN_EMAILS` (virgüllü; bu adresler ADMIN olur), `MAIL_ENABLED/HOST/PORT/USERNAME/PASSWORD/FROM` (gerçek gönderim `MAIL_ENABLED=true`; kapalıyken kod log'a yazılır), `FCM_CREDENTIALS_JSON` (ham JSON ya da base64) veya `FCM_CREDENTIALS_FILE` (bkz. `docs/PUSH_SETUP.md`), `CRYPTO_MASTER_KEYS`/`CRYPTO_ACTIVE_KEY_ID`, `SPRING_PROFILES_ACTIVE`, `PUBLIC_WEB_URL`, `STORAGE_DIR`, `CORS_ORIGINS`, `BACKEND_PORT`, `INITIAL_FILL`.

## 3. Kodlama kuralları

### Backend
- **Paket başına özellik**; entity'ler Lombok (`@Getter @Setter`), enum'lar `EnumType.STRING`.
- **Spring Data depo arayüzleri üst düzey dosyada olmalı.** İç içe (nested) arayüzler taranmaz ve bean oluşmaz. Bean adı çakışmasına dikkat (aynı basit ada sahip iki depo → `BeanDefinitionOverrideException`; modül öneki verin: `SupportMessageRepository`).
- **Flyway:** sürüm aralıkları modüle ayrılmıştır (V1-V6 çekirdek, V10 topluluk/etkinlik, V20 mesajlaşma, V30 favori/arama, V40 admin/analitik, V59-V99 performans/etkinlik/kulüp/moderasyon/şifreleme/sohbet özellikleri; **V100 auth/oturum (ayrıldı, henüz migration yok: bekleyen kayıt Redis'te), V110 mail (`mail_outbox`), V120 push (cihaz meta), V140 topluluk, V160 profil/arama, V170 haber (`event_date`, `content_attempts`), V180 ops indeksleri**; yeni modül yeni aralık). Uygulanmış bir migration'ı **değiştirmeyin**. **İndeks adları tüm şemada benzersizdir** (önek kullanın). `ddl-auto=validate`: entity ile şema birebir uyuşmalı.
- **Hata modeli:** `ApiException(status, "KOD", "Türkçe varsayılan mesaj", args…)`. Kullanıcıya giden metin `error.<KOD>` anahtarıyla **istek dilinde** çevrilir (`i18n/<modül>.properties`: tr varsayılan, `_en`, `_ar`; çekirdek `messages*.properties`; tüm paketler `spring.messages.basename`'de sayılıdır). **Yeni hata kodu = üç dosyaya da çeviri.** Çeviri argümanları metin olarak geçilir (`String.valueOf(n)`), argümanlı metinlerde kesme işareti (`'`) kullanılmaz.
- **Bildirim/e-posta metinleri alıcının kayıtlı dilinde** üretilir (`sendLocalized`, `broadcastLocalized`, `mail.*` anahtarları). İçerik kaynaklı metinler (haber başlığı) çevrilmez.
- Native sorgularda parametre kullanın, `LIKE` girdisini kaçırın (`\`, `%`, `_`); dinamik sıralama alanları beyaz listeyle.
- Controller DTO'ları `record`; doğrulama `jakarta.validation`; sayfalama: büyük/akan listelerde `CursorPage`, yönetim listelerinde sayfa tabanlı.
- **Dosya kodlaması UTF-8, BOM'suz.** Dosyaları Write/Edit ile yazın (bu ortamda uzun bash heredoc'lar ve Windows terminali Türkçe/Arapça karakterde güvenilir değil; betiklerde ASCII kullanın).
- Yorumlar kısa Türkçe, "neden"i anlatır; kimlik/log mesajları ASCII ağırlıklı; kullanıcıya dönen metinler düzgün Türkçe karakterli.
- Servis sözleşmesi: senkronizasyon/gönderim metotları çağıranına exception sızdırmaz.

### Web (`web/`)
Bkz. `web/README.md` (komutlar, klasör haritası, E2E). Geliştirme: `cd web && npm run dev` (Vite proxy → backend 8080; `changeOrigin` kapalı kalmalı: Spring CORS Host/Origin eşleşmesine bakar). Üretim: `docker compose` içindeki `web` servisi (nginx, `WEB_PORT`, varsayılan 8090) `/api`, `/files`, `/ws` isteklerini backend'e vekiller, `Host` başlığını korur. TypeScript strict, CSS Modules + tasarım token'ları, kendi i18n (tr/en/ar, Arapçada RTL — mantıksal CSS özellikleri), react-query, token'lar `sessionStorage`. Yeni sayfa yalnızca kendi dosyasında; rotalar `routes.tsx`, menü `layouts/adminNav.ts`. `npm run lint && typecheck && test && build` yeşil olmalı.

### Mobil (Flutter)
Yapı: `lib/core/` (tek HTTP katmanı `api.dart` + ETag/304 LRU önbelleği, `session.dart`, `app_gate.dart` açılış kapısı, `analytics.dart`, `realtime/` STOMP istemcisi, `push/`, `platform/`), `features/<alan>/`, `widgets/`; testler `mobile/test/` (`flutter test`, `C:\bu_mobile` yolundan). Tek API katmanı (`lib/core/api.dart`, tek uçuşlu refresh), renkler yalnızca `context.bu` (BuTokens) üzerinden, her ekranda yükleniyor/hata/boş/bakım durumları, kaynak sitelere doğrudan istek yok. Ayrıntı: docs/MOBILE_UI.md.

## 4. Güvenlik kuralları (kesin)
1. **Sırlar kodda/commit'te olmaz.** `.env`, anahtarlar, FCM JSON'u, `data/` commit'lenmez. Varsayılan `dev-only-…` JWT anahtarı yalnızca yerel içindir.
2. **Kayıt yalnızca `bingol.edu.tr`** (alt alanlar dahil) ve **sözleşme kabulüyle** (`acceptTerms=true`; onaylar `legal_acceptance`'a yazılır). **E-posta doğrulaması şart.**
3. **Token'lar:** access JWT 15 dk (`role` claim'i içerir); refresh opak, tek kullanımlık, Redis'te hash'li. Doğrulama kodları hash'li, 10 dk, 5 deneme.
4. **Auth ve yazma uçlarında rate limit zorunlu** (`RateLimiter`); yeni uç → limit.
5. **Enumerasyona karşı genel cevaplar** (login, resend-code, geçersiz kod).
6. **`/api/admin/**` yalnızca ADMIN.** Askıya alınan kullanıcı Redis anahtarıyla anında reddedilir (HTTP ve WebSocket). Yönetici kendini silemez/rolünü düşüremez; son yönetici korunur.
7. **Doğrulama kodu log'a yalnız `app.mail.enabled=false` iken** yazılır.
8. **KVKK:** hesap silme = anonimleştirme; `GET /api/users/me/export`; yeni kişisel veri tutan modül `DataExporter` ekler. Analitik toplulaştırılmıştır; olaylar 180 gün saklanır.
9. Yüklemeler: tür/boyut doğrulanır, dosya adı sunucuda üretilir; yalnızca `FileStorage` üzerinden.
10. Push kampanya URL hedefi yalnızca `https://`; CSV dışa aktarımda hücre kaçışı (CSV enjeksiyonu).

## 5. Scraping kuralları (kesin)
- Kaynak siteye **yalnızca zamanlayıcı** (ve boş tabloda tek seferlik ilk doldurma / ADMIN manuel tetikleme) istek atar; API isteği sırasında asla.
- Mevcut kayıtlar tekrar çekilmez; istekler arası bekleme (500 ms), zaman aşımı, açık User-Agent. Yapı değişirse exception yok → `markMaintenance`, eski veri sunulur. `http://` linkleri `https://`'e çevrilir.
- Kaynaklar: `https://www.bingol.edu.tr/buproject/HaberDuyuruEtkinlik.aspx?tip=0|1|2&dil=tr` ve `https://sks.bingol.edu.tr/yemek-listesi` (ayda bir). Cron'ları sıklaştırmayın.

## 6. Git ve commit kuralları
- Küçük, odaklı commit'ler; açık mesaj. `main`'e itmeden önce **derleme + testler + ilgili duman betikleri geçmeli**.
- Repo **private**; `git add` öncesi `git status` ile `.env`/sır/`node_modules`/`.claude/worktrees` olmadığını kontrol edin.
- Paralel ajan çalışması: her ajan kendi git worktree'sinde, ayrı Flyway aralığı ve ayrı Docker portu/proje adıyla (`COMPOSE_PROJECT_NAME`, `BACKEND_PORT`) çalışır; birleştirmede migration indeks adı ve bean adı çakışmalarına bakın.

## 7. Yapma listesi
- Kaynak siteyi istek sırasında/mobilden/sık çekme; scraper hatasında 500'e düşme.
- Sır yazma; rate limit'siz uç; kullanıcı varlığını sızdıran cevap; admin yetkisini gevşetme; entity'yi API cevabı yapma.
- Uygulanmış migration'ı düzenleme; çeviri anahtarsız hata kodu; iç içe depo arayüzü.
- BOM eklemek; `target/`, `data/`, `node_modules/`, `dist/` commit'lemek.

## 8. Bilinen sınırlamalar
- Haberlerde yalnızca ilk sayfa (20 kayıt/tür) çekilir; harici alt sitelerdeki duyurularda içerik yoktur.
- Rate limit sabit pencere; IP, `prod` profilinde `forward-headers-strategy=framework` ile `X-Forwarded-For`'dan alınır — proxy bu başlığı iletmelidir (profilsiz yerelde `getRemoteAddr()`).
- `register`, doğrulanmış e-posta için 409 döner (sınırlı enumerasyon; bilinen taviz).
- Şifre sıfırlama **var** (3 adım: `forgot-password` → `verify-reset-code` → `reset-password`; başarıdan sonra tüm oturumlar kapanır, bkz. `docs/MOBILE_API_GUIDE.md` 1.7). Gerçek SMTP ve Firebase/FCM kimlik bilgileri henüz girilmedi: `MAIL_ENABLED=false` iken kod log'a yazılır; FCM kimliği yoksa yalnızca uygulama içi bildirim kutusu dolar, push gitmez (kimlik gelince ek kod gerekmez, `docs/PUSH_SETUP.md`). iOS push ayrıca APNs anahtarı (ücretli Apple Developer hesabı) ister.
- Bekleyen push kuyruğu bellektedir; süreç yeniden başlarsa gönderilmemiş push kaybolabilir (bildirim kutusu kalıcıdır). `@Scheduled` görevleri çok örnekli çalışmada `SchedulerLock` ile henüz sarmalanmamıştır; tek örnekte sorun yoktur.
- Haber `publishedDate` kaynak listedeki tarihtir; gerçek etkinlik tarihi `eventDate` (detay sayfasından, bulunamazsa `null`).
- Sözleşme metinleri **taslaktır**, hukuki inceleme gerekir; EN/AR sözleşme çevirileri yok (Türkçe sunulur). Arapça arayüz çevirileri anadil incelemesi ister.
- Mobil: gerçek zamanlı sohbet (STOMP), sohbet görseli, QR yoklama, açılış kapısı, analitik ve ETag önbelleği **var**; FCM/APNs push kodu hazır ama Firebase/APNs bilgisi bekliyor. Uygulama içi EN/AR çeviri henüz yok (API EN/AR hata ve bildirim metni üretir). iOS derlemesi `xcross` ile: uygulama simgesi desteği yok, debug sürüm ana ekran simgesinden açılmaz, ücretsiz Apple ID imzası 7 gün geçerli, `GoogleService-Info.plist` paketleme desteği doğrulanmadı (bkz. `docs/MOBILE_PUSH.md`).

## 9. Yönetim paneli API'leri (özet)

Ayrıntılı sözleşme: [docs/ADMIN_API.md](docs/ADMIN_API.md).

- `admin` paketi: kullanıcı yönetimi (liste/detay/rol/silme/CSV), denetim kaydı (`AuditInterceptor`, 403 için `AuditAccessDeniedHandler`), haber gizleme, sözleşme sürüm/kabul istatistikleri. `analytics` paketi: olay alımı (`POST /api/analytics/events`), `ActivityTracker` (son görülme/günlük aktiflik), `/api/admin/analytics/*` raporları, 180 gün olay saklama.
- Dinamik/raporlama sorguları `NamedParameterJdbcTemplate` ile parametreli yazılır (PostgreSQL'e özel; H2 testlerinde çalıştırılmaz). Gün sınırları her yerde `Europe/Istanbul` (`analytics.DateRange`).
- Redis anahtarları: `seen:<uid>` (5 dk, son görülme kısıtı), `act:<uid>:<gün>` (günlük aktiflik), `rolechg:<uid>` (rol değişim anı, 16 dk; `JwtAuthFilter` eski token'ı reddeder), `suspended:<uid>` (askı/silme).
- CORS: `app.cors.allowed-origins` (`CORS_ORIGINS`), yalnızca `/api/**` ve `/files/**`.
- Uçtan uca doğrulama: `scripts/smoke-admin.sh` (diğer smoke betikleri gibi `BASE` ile).
