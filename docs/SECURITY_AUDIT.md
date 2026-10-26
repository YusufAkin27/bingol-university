# Güvenlik denetimi (T5)

Kod okuma + çalışan yığına (BASE=http://localhost:8105, `COMPOSE_PROJECT_NAME=wt_t5`) karşı saldırı
betikleriyle yapılan OWASP API Top 10 odaklı denetim. Kaynak kod bu görevde **değiştirilmedi**;
düzeltmeler T19'da yapılacak. Betikler `scripts/security/` altında, tekrar çalıştırılabilir ve
yıkıcı değildir (yalnızca kendi oluşturdukları `sec-t5-*` / zaman damgalı test kullanıcılarına dokunur).

**En önemli iki bulgu (önce bunlara bakın):** [B1](#b1-yüksek--avatar-yüklemede-gerçek-içerik-doğrulaması-yok)
(avatar yüklemede gerçek içerik doğrulaması yok — sahte Content-Type ile keyfi içerik kabul ediliyor)
ve [B2](#b2-orta--yüksek-rate-limit-ip-kaynağı-getremoteaddr-reverse-proxy-arkasında-güvenilmez)
(rate limit IP kaynağı `getRemoteAddr()`, reverse proxy arkasında güvenilmez — zaten CLAUDE.md'de
bilinen sınırlama olarak kayıtlı, burada somut ölçümle doğrulandı).

## Çalıştırma

```bash
export COMPOSE_PROJECT_NAME=wt_t5 BACKEND_PORT=8105
docker compose up -d --build postgres redis backend
./scripts/make-user.sh boss@bingol.edu.tr "Boss Admin" Sifre1234   # ADMIN_EMAILS listesinde olmali

BASE=http://localhost:8105 bash scripts/security/jwt-auth-attacks.sh
docker compose exec -T redis redis-cli flushall   # kayit/dogrulama rate limit sifirlanir
BASE=http://localhost:8105 bash scripts/security/bola-idor-scan.sh
docker compose exec -T redis redis-cli flushall
BASE=http://localhost:8105 node scripts/security/ws-attacks.js
docker compose exec -T redis redis-cli flushall
BASE=http://localhost:8105 bash scripts/security/upload-attacks.sh
docker compose exec -T redis redis-cli flushall
BASE=http://localhost:8105 bash scripts/security/misc-attacks.sh
bash scripts/security/dep-audit.sh
```

Betikler arasında `redis-cli flushall` gereklidir; aksi halde kayıt/doğrulama uçlarının saatlik
IP limiti (10/saat) sahte "başarısız" sonuçlar üretir (test altyapısı sorunu, güvenlik açığı değil).

## Uç listesi (BOLA/IDOR taraması için çıkarıldı)

`backend/src/main/java/**/*Controller.java` içindeki tüm `@*Mapping` ifadeleri taranmıştır
(33 controller, ~150 uç). `{id}` içeren uçlardan saldırı yüzeyine girenler
`scripts/security/bola-idor-scan.sh` içinde iki/üç kullanıcı ile test edilmiştir:
mesajlaşma (`/api/conversations/{id}`, `/{id}/messages`, `/{id}/members/{userId}`),
topluluk (`/api/communities/{id}`, `/{id}/members/{userId}/role`, `/{id}/posts/{postId}`),
etkinlik (`/api/events/{id}`, `/{id}/attendance/{userId}`, `/{id}/checkin-code`, `/{id}/attendance.csv`),
profil (`/api/users/{id}`, `/api/users/{id}/presence`), yönetim (`/api/admin/users/{id}/role`,
`/api/admin/users/{id}`). Tam uç listesi (yöntem + yol) bu betiğin başındaki yorumda ve
`git log` ile çıkarılan grep çıktısında mevcuttur; ayrıca aşağıdaki komutla yeniden üretilebilir:

```bash
grep -rn "@\(Get\|Post\|Put\|Delete\|Patch\)Mapping(\|@RequestMapping(" backend/src/main/java
```

## Bulgular (önem sırasıyla)

### B1 (Yüksek) — Avatar yüklemede gerçek içerik doğrulaması yok

**Yeniden üretim:** `scripts/security/upload-attacks.sh` (madde 1, 3, 4, 5). Örnek:
```bash
curl -X POST -H "Authorization: Bearer <token>" \
  -F "file=@xss.svg;type=image/png" http://localhost:8105/api/users/me/avatar
```
`LocalFileStorage.save()` (`backend/src/main/java/edu/bingol/backend/common/storage/LocalFileStorage.java:38-41`)
yalnızca `MultipartFile.getContentType()` (istemcinin bildirdiği MIME başlığı) ile `allowed` kümesini
karşılaştırır; **sihirli bayt/ImageIO çözümü yoktur**. Sonuç: düz metin, SVG+XSS yükü veya
GIF/HTML polyglot dosyası, Content-Type başlığı `image/jpeg|png|webp` olarak sahte beyan edilince
kabul edilir, `.jpg/.png/.webp` uzantısıyla diske yazılır ve `GET /files/avatars/{ad}` ile sunulur.

**Etki:** Depolamada keyfi/zararlı içerik saklanabilir (defacement, kötü amaçlı dosya dağıtımı,
depolama kötüye kullanımı). Doğrudan tarayıcı XSS etkisi, `FileController`'ın uzantıya göre sabit
`Content-Type` + `X-Content-Type-Options: nosniff` ile sunması sayesinde **kısmen azaltılmıştır**
(modern tarayıcılar nosniff ile MIME sniffing yapmaz, SVG/HTML olarak yorumlamaz); ancak gelecekte
eklenecek önizleme/thumbnail/moderasyon önizleme uçlarında (T1/T12) bu azaltıcı etken geçerli
olmayabilir. Ayrıca `exif-gps.jpg` testi, **EXIF/GPS metaverisinin temizlenmediğini** doğruladı
(aynı bulgu grubu, B1'in alt maddesi): sunulan dosyada orijinal GPS metni hâlâ mevcut — KVKK/gizlilik
riski (konum sızıntısı).

**Not:** Bu, zaten `CLAUDE.md`'nin "Mevcut durum" tablosunda eksik olarak işaretli ve T1 görevinin
tam olarak kapsamı ("sihirli bayt doğrulaması, ImageIO ile yeniden kodlama, EXIF temizliği").
Burada somut saldırı betiğiyle **doğrulanmış ve kapsamı netleştirilmiş** bir bulgudur.

**Önerilen düzeltme (T1/T19):** `MediaService`'te (1) ilk N bayt üzerinden sihirli bayt kontrolü
(JPEG `FFD8FFxx`, PNG `89504E47`, WebP `RIFF....WEBP`), (2) `ImageIO.read()` ile gerçek çözüm +
yeniden kodlama (bu adım EXIF/ICC/GPS'i de otomatik atar), (3) çözülemeyen/dekode hatası veren
dosyayı reddet. SVG `image/svg+xml` zaten `allowed` kümesinde değil — bu doğru, ama Content-Type
sahteciliğini durduran asıl kontrol gerçek piksel verisi doğrulamasıdır.

### B2 (Orta-Yüksek) — Rate limit IP kaynağı (`getRemoteAddr()`) reverse proxy arkasında güvenilmez

**Yeniden üretim:** `scripts/security/misc-attacks.sh` (madde 1). Bu test ortamında (backend'e
doğrudan bağlanılıyor, proxy yok) `X-Forwarded-For` başlığı değiştirmek rate limit'i **atlatmadı**
(10/14 istek kabul edildi, limit doğru çalıştı) — çünkü `server.forward-headers-strategy`
backend'de **hiç ayarlı değil** (grep ile doğrulandı) ve Tomcat `getRemoteAddr()` gerçek TCP
bağlantı adresini döndürüyor.

**Etki (üretim senaryosu, CLAUDE.md "Bilinen sınırlamalar"nda zaten kayıtlı):** `docker-compose.yml`
içindeki `web` (nginx) servisi backend'e proxy yapıyor. nginx arkasında iki olasılık var:
(a) `forward-headers-strategy` ayarlanmazsa, nginx'ten gelen **tüm** istekler backend için **aynı
IP** (nginx'in iç IP'si) gibi görünür → `register:ip:*`, `login:ip:*` vb. anahtarlar paylaşılan tek
kovaya düşer → **bir kullanıcının çok istek göndermesi tüm kullanıcıları** kayıt/giriş rate
limitinden kilitler (kullanılabilirlik/DoS). (b) `forward-headers-strategy=native/framework`
ayarlanır ama `X-Forwarded-For`'u körü körüne güvenilir alırsa, saldırgan kendi isteklerine
rastgele `X-Forwarded-For` değerleri ekleyip **her istekte yeni "IP"** görünerek IP başına limiti
sınırsız atlatabilir (brute force/enumerasyon/kayıt spam'inde doğrudan kullanılabilir).

**Önerilen düzeltme (T19):** `server.forward-headers-strategy=framework` + yalnızca bilinen
proxy'den (docker ağı içindeki `web` servisi) gelen `X-Forwarded-For`'u kabul eden bir
`RemoteIpValve`/`ForwardedHeaderFilter` yapılandırması; reverse proxy yoksa (yerel/test) bu
ayarı açmayın. Alternatif: rate limit anahtarına IP yanında `User-Agent`/cihaz kimliği veya
(kimlikli uçlarda) kullanıcı id'si de eklemek.

### B3 (Düşük-Orta) — `npm audit`: üretim bağımlılığında açık, geliştirme bağımlılıklarında kritik/yüksek açıklar

**Yeniden üretim:** `cd web && npm audit --omit=dev` ve `npm audit` (ağ erişimi gerekir; bu
denetimde ağ **vardı**, çıktı aşağıda).

- **Üretim bağımlılığı (moderate):** `react-router` 6.0.0–7.17.0 — açık yönlendirme (open redirect)
  GHSA-wrjc-x8rr-h8h6 ve SSR hydration'da yapıcı enjeksiyonu GHSA-337j-9hxr-rhxg. Düzeltme:
  `npm audit fix --force` (react-router-dom@7.18.4'e yükseltir, kırıcı değişiklik — web/README
  E2E'leri yeniden çalıştırın).
- **Geliştirme bağımlılıkları (yalnız CI/yerel risk, üretim paketine girmez):** `tinypool` (kritik,
  prototype pollution → RCE, vitest zinciri), `playwright` (yüksek, sertifika doğrulaması
  atlanıyor), `esbuild`/`vite` (moderate, geliştirme sunucusuna keyfi istek). Düzeltme: `vitest`/
  `vite`/`@playwright/test` majör sürüm güncellemesi (kırıcı, ayrı bir görevde planlanmalı).

**Etki:** Üretim riski düşük-orta (open redirect; XSS/CSRF zincirine eklenebilir). Geliştirme
bağımlılıkları üretim imajına girmiyor (web `Dockerfile` yalnızca derlenmiş `dist/`'i nginx'e
kopyalar), risk CI/geliştirici makinesiyle sınırlı.

### B4 (Düşük) — Bağımsız olarak çağrılan Basic-auth admin ucu, zayıf parola denemelerine karşı test edildi

**Yeniden üretim:** `scripts/security/jwt-auth-attacks.sh` (madde 7): `admin:admin`,
`admin:password`, `admin:admin123` denendi, hepsi reddedildi (`ADMIN_PASSWORD` ortam değişkeninden
geliyor, varsayılan yok edilirse rastgele üretilip loglanıyor — `SecurityConfig.adminUser`). Bulgu
yok, ancak **operasyonel not**: `.env`'de zayıf/varsayılan `ADMIN_PASSWORD` kullanılırsa bu uç
açık hedef olur; üretimde güçlü, rastgele parola ve mümkünse ek ağ kısıtlaması (IP allowlist)
önerilir.

## Test edilip bulgu çıkmayan alanlar (iyi haberler)

Aşağıdakiler `scripts/security/*` ile test edildi ve **güvenli** bulundu (kod da bu sonucu
doğruluyor); regresyon için saklanmalıdır:

- **JWT/yetki atlatma** (`jwt-auth-attacks.sh`): `alg:none`, süresi dolmuş token, başka bir
  token'dan taşınan imza, `PATCH /api/admin/users/{id}/role` ile kendi kendine yükseltme, kayıt/
  profil güncellemede `role`/`id`/`email` mass assignment, askıya alınan kullanıcının token'ının
  anında reddi (`rolechg:`/`suspended:` Redis anahtarları çalışıyor) — hepsi reddedildi.
  `JwtService.parse()` `Jwts.parser().verifyWith(key)` kullanıyor; imza doğrulanmadan claim okunmaz,
  bu yüzden `alg:none` ve imza taşıma saldırıları yapısal olarak kapalı.
- **BOLA/IDOR** (`bola-idor-scan.sh`): yabancı kullanıcı başka birinin konuşmasını okuyamadı/
  mesaj gönderemedi/üye çıkaramadı/başlık değiştiremedi (404 — varlık sızdırmıyor); topluluk
  PATCH/rol atama/üye çıkarma (403); etkinlik PATCH/DELETE/checkin-code/attendance/attendance.csv
  (403). `GET /api/users/{id}` kasıtlı olarak sınırlı genel alanlar döndürüyor (`email` gizli) —
  tasarım gereği, sızıntı değil.
- **WebSocket** (`ws-attacks.js`, mevcut `scripts/ws-test.js` ile birlikte): token'sız CONNECT
  reddedilir; `/user/{başkasınınId}/queue/messages` ve çıplak `/queue/messages` aboneliği
  `StompAuthInterceptor`'ın beyaz listesiyle reddedilir; SEND gövdesine eklenen sahte
  `senderId`/`userId` alanı yok sayılır (gönderen her zaman STOMP `Principal`'dan alınır,
  `ChatWsController.send`).
- **Yükleme — boyut/boş dosya** (`upload-attacks.sh`): 3 MB dosya (2 MB sınırı) 413 ile, boş
  dosya 400 ile reddedildi; 12 eşzamanlı yüklemede saatlik 10 limiti doğru uygulandı (yarış durumu
  yok, Redis `INCR` atomik).
- **Kaba kuvvet / enumerasyon** (`misc-attacks.sh`): doğrulama kodunda 5 deneme sınırı çalışıyor
  (`VerificationService.MAX_ATTEMPTS`); login yanıtı var/yok olan e-posta için aynı (401,
  `ApiException` genel mesaj); zamanlama farkı testte önemli çıkmadı (BCrypt doğal gecikmesi hariç).
- **SQL enjeksiyonu fuzz** (`misc-attacks.sh`): `/api/search?q=`, `/api/admin/users?sort=`
  payload'ları (`' OR 1=1`, `DROP TABLE`, `UNION SELECT`, `SLEEP()`) 500'e düşürmedi; arama
  parametreli sorgu kullanıyor, `sort` `UserFilter.orderBy()` beyaz listesiyle 400 veriyor.
  `app_user` tablosu test sonrası hâlâ erişilebilir durumda (DROP çalışmadı). Repo genelinde
  tarama: tüm native sorgular `NamedParameterJdbcTemplate`/`@Query(:param)` kullanıyor; string
  birleştirmeyle kullanıcı girdisi SQL'e eklenen tek yer `AdminUserRepository`'nin `orderBy`
  alanı ve o da whitelist'ten geçiyor.
- **CORS/başlıklar** (`misc-attacks.sh`): rastgele origin için `Access-Control-Allow-Origin`
  yansıtılmıyor (CORS yalnız `app.cors.allowed-origins`); `X-Content-Type-Options: nosniff` ve
  `X-Frame-Options: DENY` mevcut (Spring Security varsayılanı).
- **Maven bağımlılıkları**: `versions-maven-plugin` ile kontrol edildi, hepsi güncel/yakın güncel
  (Spring Boot 4.1.2 → sonraki 4.2.0-RC1 henüz kararlı değil; `jjwt` 0.12.6 → 0.13.0 küçük
  güncelleme; `jsoup` 1.18.3 → 1.23.2). Bilinen kritik/yüksek CVE'li bir sürüm **görülmedi**
  (çevrimiçi NVD taraması değil, yalnızca sürüm karşılaştırması — bkz. sınırlamalar).

## Sınırlamalar / kapsam dışı

- Maven tarafı için gerçek bir CVE veritabanı taraması (`dependency-check-maven`/OWASP) **çalıştırılmadı**
  (NVD veri tabanı indirmesi uzun sürer, bu denetimin zaman bütçesini aşar); yalnızca
  `versions-maven-plugin` ile sürüm güncelliği karşılaştırıldı. `npm audit` için ağ erişimi
  **vardı** ve tam çalıştırıldı.
- Mobil (Flutter) istemci incelenmedi — proje genelinde ertelenmiş durumda, kod yok.
- Yük/performans odaklı saldırılar (DoS boyutlu) T6'nın kapsamına bırakıldı; burada yalnızca
  rate-limit/yarış-durumu odaklı doğrulamalar yapıldı.
- Topluluk `POST .../posts` testinde kulüp henüz ADMIN onayı beklediğinden (`202 Accepted`)
  `COMMUNITY_NOT_FOUND` alındı; üye-olmayanın gönderi yapıp yapamayacağı onaylı bir toplulukla
  tekrar test edilmeli (T4/T10 kapsamına not edildi, burada kesin IDOR bulgusu değil).
- Bağımsız etkinlik oluşturma bu ortamda `202 Accepted` (admin onayı bekliyor) döndü; CLAUDE.md
  "Varsayılan kararlar"da "hemen yayınlanır" yazsa da bu, `events_require_approval` ayarının henüz
  **uygulanmadığını** (T9'un kapsamı) gösteriyor — güvenlik açığı değil, özellik eksikliği.

## Betik envanteri

| Betik | Kapsam |
|---|---|
| `scripts/security/jwt-auth-attacks.sh` | JWT (`alg:none`, süre, imza taşıma), rol yükseltme, mass assignment, zayıf Basic-auth, askı sonrası token reddi |
| `scripts/security/bola-idor-scan.sh` | Mesajlaşma/topluluk/etkinlik/profil `{id}` uçlarında BOLA/IDOR |
| `scripts/security/ws-attacks.js` | STOMP: token'sız CONNECT, yabancı `/user` kuyruğu, gönderici sahteciliği |
| `scripts/security/upload-attacks.sh` + `make-upload-fixtures.js` | Sahte Content-Type, SVG/polyglot, boyut/boş dosya, EXIF/GPS, eşzamanlı yükleme |
| `scripts/security/misc-attacks.sh` | XFF/rate-limit, enumerasyon, doğrulama kodu kaba kuvvet, SQLi fuzz, CORS/başlıklar |
| `scripts/security/dep-audit.sh` | `npm audit` (web) + Maven sürüm kontrolü (backend) |
