# CLAUDE.md — Bingöl Üniversitesi Projesi

Bu dosya, repoda çalışan yapay zekâ ajanları ve geliştiriciler için kılavuzdur. Burada yazanlar koddaki mevcut duruma dayanır; kodla çeliştiğini görürseniz dosyayı güncelleyin.

Yol haritası: [docs/MVP.md](docs/MVP.md) (başka bir ajan tarafından yazılıyor, henüz olmayabilir).

## 1. Proje özeti ve mimari

Bingöl Üniversitesi duyuru/haber/etkinlik ve yemek listesi uygulaması.

- `backend/` — Spring Boot 4.1.2, Java 17, Maven (JPA, Security, Validation, Actuator, WebSocket, Redis, Bucket4j, JJWT, Mail, jsoup, Lombok)
- `mobile/` — Flutter (Android). Şimdilik tek dosya: `mobile/lib/main.dart` (`http`, `url_launcher`); mobil çalışma ertelendi
- Not: `README.md` içindeki "Spring Boot 3" ifadesi eskidir; gerçek sürüm `backend/pom.xml`'dedir.

### Paket yapısı (`backend/src/main/java/edu/bingol/backend/`)

| Paket | İçerik |
|---|---|
| `news` | `NewsItem`, `ContentType`, `NewsRepository`, `NewsScraper` (`parseList` test edilebilir), `NewsSyncService`, `NewsService` (sorgu), `NewsController`, `dto/` |
| `menu` | `MenuDay`, `MenuRepository`, `MenuScraper` (`parse`), `MenuSyncService`, `MenuService`, `MenuController`, `dto/` |
| `status` | `SyncStatus` (OK/MAINTENANCE), `StatusService`, `StatusController` (`GET /api/status`), `dto/` |
| `auth` | `AuthController` (ince: rate limit + HTTP), `AuthService` (iş kuralları), `dto/` (istek/yanıt record'ları) |
| `auth.jwt` | `JwtService`, `JwtAuthFilter` |
| `auth.token` | `RefreshTokenService`, `VerificationService` (Redis) |
| `user` | `User`, `UserRepository` |
| `mail` | `MailService` (SMTP isteğe bağlı; kapalıyken kod log'a yazılır) |
| `common` | `ApiException`, `ApiExceptionHandler`, `RateLimiter` (Redis), `Hashing` |
| `config` | `SecurityConfig` (filtre zinciri, BCrypt, admin kullanıcısı), `WebConfig` (ETag), `JwtProperties` / `MailProperties` / `SyncProperties` (`@ConfigurationProperties` record'ları) |
| `health` | `HelloController` (`/api/hello`) |

Katman kuralı: Controller → Service → Repository. Controller yalnızca HTTP eşlemesi ve rate limit yapar; entity'ler API'ye doğrudan dönmez, `dto/` record'larına çevrilir.

### Veri akışı

```
Kaynak siteler ──(yalnızca zamanlayıcı)──> Scraper (jsoup) ──> PostgreSQL
                                                                  │
                                         StatusService (OK / MAINTENANCE)
                                                                  ▼
                                         REST (/api/news, /api/menu, /api/status) ──> Flutter
```

### Redis'in rolü

Redis haber/yemek verisini tutmaz; yalnızca kimlik doğrulama için kullanılır:

- **Doğrulama kodu:** `vc:<email>` (SHA-256 hash, 10 dk), `vc:att:<email>` (en fazla 5 deneme), `vc:cd:<email>` (60 sn yeniden gönderim bekleme)
- **Refresh token:** `rt:<sha256(token)>` → kullanıcı id (TTL `jwt.refresh-ttl-days`, varsayılan 30 gün)
- **Rate limit:** `rl:<anahtar>` sayaçları (`RateLimiter`)

Redis yoksa auth uçları çalışmaz; haber/menü okuma uçları Redis'e dokunmaz.

### Zamanlayıcılar (`@EnableScheduling`, saat dilimi `Europe/Istanbul`)

| Görev | Varsayılan cron | Ayar anahtarı |
|---|---|---|
| Haber/duyuru/etkinlik | `0 0 0 * * *` (her gece 00:00) | `news.sync.cron` |
| Yemek listesi | `0 30 23 L * *` (ayın son günü 23:30) | `menu.sync.cron` |

Ek olarak uygulama açılışında (`ApplicationReadyEvent`) tablo **boşsa** bir kez ilk doldurma yapılır. Manuel tetikleme: `POST /api/admin/sync` ve `POST /api/admin/sync-menu` (ADMIN).

### "Bakımda" mekanizması (SyncStatus)

Kaynak site yapısı değişir veya ulaşılamazsa senkronizasyon exception fırlatmaz; `StatusService.markMaintenance(kaynak, mesaj)` çağrılır ve eski veri sunulmaya devam eder. Kaynak anahtarları: `NEWS`, `MENU`. `GET /api/status` her kaynak için `maintenance`, `lastSuccessAt`, `lastAttemptAt`, `message` döner. Haberlerde 3 türün de başarısız olması bakım sayılır; kısmi hata `markOk` ile mesaj taşır. Mobil, `maintenance == true` ise "Sistem şu anda bakımda" bandı gösterir.

## 2. Çalıştırma, derleme, test

**Önemli:** Bu makinede yalnızca **Java 8** kurulu; backend Java 17 gerektirir. Derleme/test **Docker içindeki Maven 17 konteynerinde** yapılır. **Flutter kurulu değildir** (mobil kod burada derlenemez/çalıştırılamaz).

Git Bash'ten, `backend/` dizininde:

```bash
# Derleme
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -q -B -DskipTests compile

# Test
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -q -B test
```

Tüm yığını (PostgreSQL + Redis + backend) çalıştırmak:

```bash
cp .env.example .env      # DB_PASSWORD, JWT_SECRET, ADMIN_PASSWORD doldurulur (zorunlu)
docker compose up -d --build
curl localhost:8080/actuator/health
```

- Veritabanı PostgreSQL 16 (`ddl-auto=update`; Flyway henüz yok). Testler H2 (`src/test/resources/application.properties`) kullanır, `app.sync.initial-fill=false` ile siteye istek atmaz.
- Admin uçları (`/api/admin/**`): Basic auth, kullanıcı `admin`, şifre `ADMIN_PASSWORD`.
- Android emülatöründen API adresi `http://10.0.2.2:8080/api` (`mobile/lib/main.dart` → `apiBase`).
- Mobil (Flutter kurulu bir makinede): `cd mobile && flutter create --platforms=android --org edu.bingol --project-name bingol_mobile . && flutter run`

### Ortam değişkenleri

| Değişken | Anlamı |
|---|---|
| `JWT_SECRET` | JWT imza anahtarı (en az 32 karakter; üretimde zorunlu) |
| `REDIS_HOST`, `REDIS_PORT` | Redis adresi (varsayılan `localhost:6379`) |
| `MAIL_ENABLED`, `MAIL_FROM`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD` | SMTP (varsayılan `MAIL_ENABLED=false`) |
| `ADMIN_PASSWORD` | `/api/admin/**` Basic auth şifresi (kullanıcı `admin`) |

## 3. Kodlama kuralları

### Backend

- **Paket başına özellik:** yeni özellik kendi paketine (`edu.bingol.backend.<özellik>`) girer; controller, service, repository, entity aynı pakette durur.
- **Entity'ler Lombok ile** (`@Getter @Setter`), `jakarta.persistence` kullanılır. Enum alanlar `EnumType.STRING`.
- **Controller'larda DTO'lar `record`** (controller içinde iç içe tanımlı, `static of(Entity)` fabrikasıyla). Entity'yi doğrudan JSON olarak dönmeyin.
- **Hata modeli:** iş kuralı hatalarında `ApiException(HttpStatus, "KOD", "Türkçe mesaj")` fırlatın; `ApiExceptionHandler` bunu `{"code","message"}` gövdesine çevirir. Doğrulama hataları `VALIDATION_ERROR` koduyla döner. Giriş DTO'larında `jakarta.validation` (`@Valid`, `@Size` vb.) kullanın.
- **Spring Boot 4 notları:** starter adları 4.x'e göredir (`spring-boot-starter-webmvc`, test starter'ları `...-test`). Jackson ve diğer yardımcıların paket/sürüm farklarını bilerek ekleyin; yeni bağımlılık eklerken Boot 4 ile uyumunu doğrulayın. Lombok, `maven-compiler-plugin` içinde `annotationProcessorPaths` ile bağlanmıştır — bu yapılandırmayı bozmayın.
- **Dosya kodlaması:** tüm kaynak dosyalar **UTF-8, BOM'suz**. BOM ekleyen editör/araçlardan kaçının (Windows PowerShell `>`/`Set-Content` BOM veya ANSI yazabilir; dosyaları Write/Edit ile yazın).
- **Stil:** mevcut kodun yorum ve isim stiline uyun — kısa Türkçe javadoc/satır yorumları ("neden"i anlatır), İngilizce tanımlayıcılar, 4 boşluk girinti. Config/log mesajlarında mevcut dosyalar ASCII-ağırlıklı Türkçe kullanır; kullanıcıya dönen `ApiException` mesajları düzgün Türkçe karakterlidir.
- **Servis sözleşmesi:** `sync()` türü metotlar exception fırlatmaz, `AtomicBoolean` ile eşzamanlı çalışmayı engeller.

### Mobil (Flutter)

- **Tek API katmanı:** ağ çağrıları tek yardımcı üzerinden yapılır (şu an `getJson` ve `apiBase`). Yeni ekranlar `http.get` çağırmaz; bu katmanı kullanır/genişletir. Auth eklenince token ekleme, 401'de refresh ve hata eşleme de yalnızca burada olmalı.
- **Durumlar:** her liste/ekran yükleniyor, hata ("Sunucuya ulaşılamadı"), boş ("Henüz içerik yok") ve **bakım** (`/status` → `MaterialBanner`) durumlarını ele almalıdır; bakımda eski veri gösterilmeye devam edilir.
- **Arayüz metinleri Türkçe**, tarihler `gg.aa.yyyy` (`_fmtDate`).
- Mobil asla kaynak siteleri (bingol.edu.tr, sks.bingol.edu.tr) doğrudan çağırmaz; yalnızca backend API'si. (Haber "Kaynak sayfada aç" bağlantısı kullanıcı eylemiyle tarayıcıyı açar, scraping değildir.)

## 4. Güvenlik kuralları (kesin)

1. **Sırlar kodda ve commit'te olmaz.** `JWT_SECRET`, `MAIL_*`, `ADMIN_PASSWORD` yalnızca ortam değişkeniyle verilir. `application.properties` içindeki `dev-only-...` JWT varsayılanı yalnızca yerel geliştirme içindir; üretimde mutlaka ezilir. `.env`, anahtar/sertifika dosyaları ve `backend/data/` commit'lenmez.
2. **Kayıt yalnızca `bingol.edu.tr` e-postalarıyla** (alt alanlar dahil, örn. `ogr.bingol.edu.tr`) yapılır (`AuthService.UNIVERSITY_EMAIL`). **E-posta doğrulaması şarttır:** doğrulanmamış hesap giriş yapamaz (`EMAIL_NOT_VERIFIED`) ve refresh edemez. E-postalar küçük harfe normalize edilir.
3. **Token'lar:** access token kısa ömürlü JWT (`jwt.access-ttl-minutes=15`). Refresh token opak, **tek kullanımlık** (her `/refresh`'te döner, `getAndDelete`) ve Redis'te yalnızca **SHA-256 hash'i** saklanır. Doğrulama kodları da hash'li ve 10 dk ömürlüdür, 5 yanlış denemede iptal olur. Parolalar BCrypt ile saklanır.
4. **Auth uçlarında rate limit zorunlu** (`RateLimiter.check`): register, resend-code, verify-email, login (IP + e-posta), refresh. Yeni bir auth ucu eklerseniz limit koymadan birleştirmeyin.
5. **Enumerasyona karşı genel cevaplar:** login yanlış e-posta/şifrede aynı hatayı döner (`INVALID_CREDENTIALS`); `resend-code` hesap var/yok fark etmeksizin aynı cevabı verir; geçersiz/süresi dolmuş/doğrulanmış hesap kodları tek mesajla (`INVALID_CODE`) döner. Yeni uçlarda kullanıcı veya e-posta varlığını sızdırmayın.
6. **`/api/admin/**` yalnızca ADMIN** rolüne açıktır (Basic auth, `spring.security.user.*`); JWT ile giriş yapan kullanıcılar `ROLE_USER` alır ve admin uçlarına giremez. Bu eşlemeyi gevşetmeyin. Diğer tüm uçlar varsayılan olarak `authenticated()`; yalnızca `SecurityConfig`'te açıkça `permitAll` yazılanlar herkese açıktır.
7. **Dev modunda doğrulama kodunu log'a yazma yalnızca `app.mail.enabled=false` iken** yapılır (`MailService`). Üretimde `MAIL_ENABLED=true` olmalı; kodları veya token'ları başka hiçbir koşulda log'lamayın.

## 5. Scraping kuralları (kesin)

- **Siteye yalnızca zamanlayıcı istek atar** (ve tablo boşken tek seferlik ilk doldurma / ADMIN manuel tetikleme). API isteği sırasında veya mobil tarafından kaynak siteye **asla** istek atılmaz; API yalnızca DB'den okur.
- **Mevcut kayıtlar tekrar çekilmez:** haberlerde `repo.existsByUrl(url)` ile atlanır; yalnızca yeni kayıtların detay sayfası indirilir. Yemekte yalnızca değişen günler yazılır.
- **İstekler arası bekleme:** haber detay istekleri arasında `REQUEST_DELAY_MS = 500`. Yeni scraper'larda da benzer bekleme ve zaman aşımı (`timeout`) kullanın; açık bir User-Agent gönderin.
- **Hata/yapı değişikliğinde exception fırlatma:** beklenen yapı yoksa (boş liste, tablo yok) veya site ulaşılamazsa `StatusService.markMaintenance(...)` çağırın, eski veriyi sunmaya devam edin, loglayın. Senkronizasyon metodu çağıranına exception sızdırmaz.
- **`http://` linkler `https://`'e çevrilir** (`replaceFirst("^http://", "https://")`).
- **Kaynaklar:**
  - Haber/duyuru/etkinlik: `https://www.bingol.edu.tr/buproject/HaberDuyuruEtkinlik.aspx?tip=0|1|2&dil=tr` (`tip`: 0 duyuru, 1 haber, 2 etkinlik — `ContentType.siteCode()`). Detay içeriği yalnızca `www.bingol.edu.tr` sayfalarında `div.sade` içinden alınır.
  - Yemek: `https://sks.bingol.edu.tr/yemek-listesi` — **ayda bir, ayın son günü 23:30**.
- Cron değerlerini sıklaştırmayın; kaynak siteye yük bindirmek yasaktır.

## 6. Git ve commit kuralları

- Küçük, odaklı commit'ler; mesajlar Türkçe veya İngilizce olabilir ama açık olmalı (ne ve neden).
- `main`'e doğrudan itmeden önce **derleme geçmeli** (bkz. Bölüm 2, Docker komutu); testi olan değişiklikte test de.
- Repo **private**'tır; yine de sır içeren hiçbir dosya (`.env`, anahtar, gerçek parola/SMTP bilgisi, `data/` DB dosyaları) eklenmez. `git add` öncesi `git status` ile kontrol edin.
- Şu an çalışma dizini git deposu olmayabilir; commit'e geçmeden önce `git init`/remote durumunu kontrol edin.

## 7. Yapma listesi

- Kaynak siteyi istek sırasında, mobilden veya sık aralıkla çekme.
- Scraper hatasında exception fırlatıp API'yi 500'e düşürme; bakım durumunu kullanma.
- Sır/parola/anahtarı koda, loga, commit'e veya örnek dosyaya gerçek değerle yazma.
- Rate limit'siz auth ucu ekleme; kullanıcı/e-posta varlığını ele veren cevap yazma.
- `/api/admin/**` yetkisini gevşetme; entity'yi doğrudan API cevabı yapma.
- Dosyalara BOM ekleme; `target/` ve `data/` çıktılarını düzenleme/commit'leme.
- İstenmeden yeni dokümantasyon dosyası üretme; mevcut dosyaları düzenlemeyi tercih et.

## 8. Bilinen sınırlamalar

- **Haberlerde yalnızca ilk sayfa** (liste başına 20 kayıt) çekilir; eski kayıtların geriye dönük doldurulması yoktur.
- **Harici sitelerdeki duyurularda içerik yoktur:** `www.bingol.edu.tr` dışı bağlantılar için `content` boş kalır, mobil "Kaynak sayfada aç" butonunu gösterir.
- **Rate limit sabit pencere** (fixed window) mantığındadır ve **IP için `getRemoteAddr()`** kullanır. Reverse proxy/yük dengeleyici arkasında tüm istekler proxy IP'si gibi görünür; üretimde `X-Forwarded-For` işlemesi (ör. `server.forward-headers-strategy`) doğru ayarlanmalıdır, aksi halde limit herkesi ortak sayar.
- **`/api/auth/register`**, doğrulanmış bir e-posta için `EMAIL_ALREADY_REGISTERED` (409) döner; bu, bingol.edu.tr adresleri için sınırlı bir enumerasyon sızıntısıdır (bilinen taviz; değiştirilecekse mobil akışla birlikte).
- **Mesajlaşma henüz yok:** WebSocket/Redis/Bucket4j bağımlılıkları eklenmiştir ama mesajlaşma yazılmamıştır; mobilde de henüz giriş/kayıt ekranları yoktur (auth yalnızca backend'dedir).
- Mobil kod bu makinede derlenip test edilemez (Flutter yok).
