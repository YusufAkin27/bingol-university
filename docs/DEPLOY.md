# Üretim Kurulumu (DEPLOY)

Bu belge BÜ Kampüs yığınını tek sunucuda Docker Compose ile üretime almayı anlatır.

> **Önerilen yol (V2): `docker-compose.prod.yml`** = Caddy (otomatik HTTPS) + web (nginx, yalnız statik/SPA) + backend + postgres + redis + backup. Bölüm 0 hızlı kurulumu, bölüm 10-12 CDN, staging ve yedek/izleme bağlantılarını anlatır. Geliştirme için kök `docker-compose.yml` değişmedi. Aşağıdaki bölüm 1-9 genel bilgi olarak geçerlidir (proxy olarak Caddy yerine nginx/Traefik/LB kullanılacaksa onlar yol gösterir).

## 0. Hızlı kurulum (docker-compose.prod.yml)

```bash
# 1) Sunucu hazırlığı (Ubuntu 22.04/24.04, root): docker, ufw (22/80/443), fail2ban, otomatik güvenlik güncellemesi
sudo bash scripts/deploy/bootstrap-server.sh --deploy-user bu
# 2) Sırlar (ekrana yazmaz, dosya izni 600) ve düzenleme
bash scripts/ops/gen-secrets.sh                 # .env.prod taslağı: DB/JWT/ADMIN/CRYPTO/DEVICE sırları üretilir
$EDITOR .env.prod                               # DOMAIN, ACME_EMAIL, CORS_ORIGINS, PUBLIC_WEB_URL, MAIL_*, BACKUP_AGE_RECIPIENT...
# 3) DNS A/AAAA kaydı sunucuyu göstersin; 80/443 açık. İlk dağıtım:
bash scripts/deploy/update.sh --first
# 4) Sonraki güncellemeler (yedek -> çek -> derle -> yeniden başlat -> sağlık -> başarısızsa otomatik geri al):
bash scripts/deploy/update.sh [--ref v1.5.0]
bash scripts/deploy/rollback.sh                 # elle geri alma
```

### Mimari kararı: Caddy önde, nginx yalnız statik

```
İstemci --HTTPS(80/443)--> Caddy --/api /files /ws--> backend:8080
                                  \--diğer her şey--> web (nginx, statik SPA)
```

- Caddy, Let's Encrypt sertifikasını otomatik alır/yeniler (`DOMAIN`, `ACME_EMAIL`; `caddy_data` volume'u kaybedilmemeli). HSTS ve güvenlik başlıkları `deploy/Caddyfile` içindedir.
- **Neden doğrudan backend?** `web/nginx.conf` içindeki `client_max_body_size 12m` sınırı 40 MB gönderi videosu yüklemesini keserdi; Caddy'de gövde sınırı `CADDY_MAX_BODY` (55 MB) ile ayarlanır ve çift vekil olmaz. nginx'in kendi `/api` vekili üretimde kullanılmaz (kök `docker-compose.yml` ile yerel kullanımda sürer).
- **`X-Forwarded-For`:** Caddy istemcinin gönderdiği başlığı **ezer** ve `{client_ip}` yazar; backend `prod` profilinde `server.forward-headers-strategy=framework` + `app.security.trusted-proxies` (compose'ta `TRUSTED_PROXIES`, varsayılan Docker/özel ağlar) ile yalnız bu ağdan gelen proxy'ye güvenir. Backend portu **dışarıya yayınlanmaz** (`expose: 8080`, yalnız `edge`/`internal` ağları): IP engelleri ve rate limit gerçek IP'yi görür.
- **Ağ:** yalnız Caddy `80/443` yayınlar. `postgres`/`redis`/`backup` `internal` (internete çıkışı olmayan) ağdadır; backend FCM/SMTP için `edge` ağına da bağlıdır.
- **Sertleştirme:** tüm konteynerlerde `no-new-privileges`, `cap_drop: ALL` (yalnız gerekenler eklenir), backend/redis/caddy/web `read_only` + `tmpfs`, backend root olmayan kullanıcı (uid 1001), kaynak limitleri, `restart: unless-stopped`, healthcheck'ler, `json-file` günlük döndürme (10 MB x 5).
- **Doğrulayıcı yansıması:** compose `CRYPTO_MASTER_KEYS`, `CRYPTO_ACTIVE_KEY_ID`, `DB_PASSWORD`, `JWT_SECRET`, `ADMIN_PASSWORD`, `CORS_ORIGINS`, `PUBLIC_WEB_URL`, `BACKUP_AGE_RECIPIENT` için `:?` kullanır (eksikse `docker compose` bile başlamaz); `CRYPTO_REQUIRE_KEYS=true` sabittir; `ProdSettingsValidator` + `KeyProvider` eksik/güvensiz değeri uygulama açılışında reddeder (boş `CRYPTO_MASTER_KEYS` ile prod açılışı reddedilir: `KeyProviderTest`).
- Gönderi videosu için Spring çok parçalı yükleme sınırı compose'ta `MULTIPART_MAX_FILE=45MB` (prod varsayılanı 5 MB videoyu keserdi).


## 1. Mimari ve reverse proxy / TLS

```
İstemci --HTTPS--> [TLS sonlandırıcı: Caddy / nginx / Traefik / bulut LB] --HTTP--> web (nginx, :8090) --> backend (:8080)
```

- TLS **proxy katmanında** sonlanır. Proxy `X-Forwarded-For`, `X-Forwarded-Proto`, `X-Forwarded-Host` başlıklarını iletmelidir; prod profilinde `server.forward-headers-strategy=framework` bu başlıkları kullanır (rate limit IP'si ve HSTS buna bağlıdır). **Backend portunu (8080) internete açmayın**; yalnızca proxy erişsin (güvenlik duvarı / `BACKEND_PORT` bind'ı `127.0.0.1`).
- WebSocket (`/ws`) için proxy'de `Upgrade`/`Connection` başlıkları ve uzun okuma zaman aşımı (>= 120 sn) açık olmalı.
- HSTS (`max-age=31536000; includeSubDomains`) yalnızca HTTPS isteklerde yazılır; HTTP'den HTTPS'e yönlendirmeyi proxy yapar.
- `/actuator/health` dışındaki actuator uçları ADMIN yetkisi ister; prod'da yalnızca `health,info` yayımlanır. Proxy'de `/actuator` yolunu dışarıya vermeyin (yalnızca iç sağlık denetimi).
- Swagger/OpenAPI prod'da kapalıdır (`springdoc.*`).

Örnek Caddyfile:

```
kampus.bingol.edu.tr {
    encode gzip
    reverse_proxy localhost:8090
}
```

## 2. Kurulum adımları

```bash
git clone <repo> && cd bingol-university
cp .env.example .env        # sırları doldurun; .env commit'lenmez
# .env: SPRING_PROFILES_ACTIVE=prod
docker compose config -q    # doğrulama
docker compose up -d --build
curl -f localhost:8080/actuator/health
```

`prod` profilinde `ProdSettingsValidator` eksik/güvensiz ayarı anlaşılır bir hatayla bildirir ve uygulama **başlamaz** (sır değeri log'a yazılmaz; yalnızca ayar adı). Kontrol edilenler: `DB_PASSWORD` (boş / `bingol` olamaz), `JWT_SECRET` (>= 32 karakter, `dev-only` içeremez), `ADMIN_PASSWORD`, `CORS_ORIGINS` (zorunlu, `*` olamaz), `MAIL_HOST` (`MAIL_ENABLED=true` iken). Uyarı olarak: `MAIL_ENABLED=false` (kodlar log'a yazılır), FCM yok (push gitmez), `localhost` CORS kökeni. Ek olarak mesaj şifreleme ana anahtarları prod'da zorunludur (`CRYPTO_MASTER_KEYS`, bkz. [ENCRYPTION.md](ENCRYPTION.md)).

## 3. Ortam değişkenleri

| Değişken | Zorunlu (prod) | Açıklama |
|---|---|---|
| `SPRING_PROFILES_ACTIVE` | evet (`prod`) | Boş = profilsiz yerel davranış; `dev` = yerel geliştirme |
| `DB_PASSWORD` | evet | PostgreSQL şifresi (compose hem postgres hem backend için kullanır) |
| `DB_URL`, `DB_USER` | hayır | Compose içinde sabit; harici DB için ezin |
| `JWT_SECRET` | evet | >= 32 karakter rastgele (`openssl rand -base64 36`); değişirse tüm oturumlar düşer |
| `ADMIN_PASSWORD` | evet | `/api/admin/**` Basic auth şifresi |
| `ADMIN_EMAILS` | önerilir | Virgüllü; bu adresler ADMIN rolü alır |
| `CORS_ORIGINS` | evet | Virgüllü https kökenleri (panel/web adresi) |
| `CRYPTO_MASTER_KEYS`, `CRYPTO_ACTIVE_KEY_ID` | evet | Mesaj şifreleme ana anahtarları (`id:base64(32 bayt)`); kaybı = mesaj kaybı, yedekleyin |
| `MAIL_ENABLED`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM` | `MAIL_ENABLED=true` önerilir | Doğrulama kodu e-postası; kapalıyken kod log'a yazılır. Spam'e düşmemek için ek ayarlar (`MAIL_REPLY_TO`, `MAIL_REQUIRE_TLS`, `MAIL_MAX_PER_MINUTE`, SPF/DKIM/DMARC): [MAIL_DELIVERABILITY.md](MAIL_DELIVERABILITY.md) |
| `FCM_CREDENTIALS_FILE` | hayır | Konteyner içindeki Firebase servis hesabı JSON yolu (secret olarak mount edin); boşsa push kapalı |
| `PUBLIC_WEB_URL` | önerilir | Herkese açık web adresi (destek takip bağlantıları) |
| `STORAGE_DIR` | hayır | Compose'ta `/data/uploads` (volume) |
| `INITIAL_FILL` | hayır | Boş tablolarda ilk haber/menü doldurma |
| `DB_POOL_MAX`, `DB_POOL_MIN_IDLE` | hayır | Hikari havuzu (varsayılan 20 / 5) |
| `MULTIPART_MAX_FILE`, `MULTIPART_MAX_REQUEST` | hayır | Yükleme sınırları (5MB / 6MB) |
| `BACKEND_MEM_LIMIT`, `BACKEND_CPUS`, `POSTGRES_MEM_LIMIT`, `REDIS_MEM_LIMIT` | hayır | Konteyner kaynak limitleri (1g / 2 / 1g / 256m) |
| `JAVA_TOOL_OPTIONS` | hayır | Ek JVM bayrakları (imaj varsayılanı: `-XX:MaxRAMPercentage=75`) |
| `BACKEND_PORT`, `WEB_PORT`, `ADMIN_PATH` | hayır | Portlar ve gizli yönetim yolu |
| `DEVICE_HMAC_KEY` | önerilir | Cihaz kimliği (`X-Device-Id`) HMAC-SHA256 anahtarı (>= 32 karakter, `openssl rand -base64 36`). Boşsa `JWT_SECRET`'ten türetilir; anahtar değişirse mevcut cihaz engelleri eşleşmez, bu yüzden ayrı ve kalıcı tutun (verilip 32 karakterden kısaysa prod açılışı reddedilir; boşsa uyarı yok, yine de ayrı anahtar önerilir) |
| `BAN_ALLOWLIST` | önerilir | Asla IP ile engellenmeyecek ek ağlar (virgüllü IP/CIDR; yönetici ofis çıkış adresleri). Loopback ve özel ağlar zaten muaftır |
| `BLOCK_ANONYMIZERS` | hayır | `true` = yöneticinin yüklediği anonimleştirici (Tor/VPN/veri merkezi) aralıklarından gelen istekler engellenir (varsayılan `false`) |
| `BAN_CACHE_TTL_SECONDS`, `BAN_LOG_RETENTION_DAYS` | hayır | Engel önbelleği yenileme (20 sn) ve cihaz/deneme günlüğü saklama (90 gün) |

Diğer modüllerin ayarları (`app.media.*`, `app.chat.*`, `NOTIFICATION_RETENTION_DAYS` vb.) `application.properties` içinde ortam değişkeni karşılığıyla listelidir.

## 4. Yedekleme

**PostgreSQL** (günlük, cron ile; şifreli ve sunucu dışına kopyalayın):

```bash
docker compose exec -T postgres pg_dump -U bingol -Fc bingol > backup/bingol-$(date +%F).dump
# geri yükleme
docker compose exec -T postgres pg_restore -U bingol -d bingol --clean --if-exists < backup/bingol-YYYY-MM-DD.dump
```

- Geri yükleme provasını periyodik yapın; 14 günlük günlük + 6 aylık haftalık saklama önerilir.
- **Yüklemeler** (`uploads` volume'u: avatar, kapak, sohbet görselleri) ayrıca yedeklenmeli: `docker run --rm -v <proje>_uploads:/d -v $PWD/backup:/b alpine tar czf /b/uploads-$(date +%F).tgz -C /d .`
- **`CRYPTO_MASTER_KEYS` ve `.env`** parola yöneticisinde / ayrı güvenli yerde saklanmalı; veritabanı yedeği anahtarsız mesajları çözemez.

## 5. Redis kalıcılığı

Compose `--appendonly yes` ile AOF açar (`redisdata` volume'u). Redis'te yalnızca geçici/yeniden üretilebilir veri vardır (doğrulama kodları, refresh token hash'leri, rate limit, presence, askı işaretleri). Kayıp sonucu: kullanıcılar yeniden giriş yapar, bekleyen kodlar düşer; **veri kaybı olmaz**. Yine de `redisdata` volume'unu koruyun (oturumların kesilmemesi için). Redis çökerse auth ve mesajlaşma çalışmaz; haber/menü okuma çalışır.

## 6. Ölçekleme ve zamanlayıcılar

Backend durumsuzdur (JWT, Redis) ve yatay ölçeklenebilir; ancak **`@Scheduled` görevleri her örnekte çalışır**. Çoklu örnekte çift çalışma riski olan görevler: haber/menü senkronu (kaynak siteye çift istek), push kampanya dağıtıcı (zaten `FOR UPDATE SKIP LOCKED`, güvenli), etkinlik hatırlatmaları (çift bildirim), bildirim/mesaj/olay saklama temizlikleri (idempotent, zararsız), medya yetim süpürücüsü, sohbet odası bakımı.

Çözüm: `config.SchedulerLock` (Redis `SET NX PX` + sahip belirteci). Görev sahipleri metotlarını şöyle sarmalamalıdır:

```java
@Scheduled(cron = "${news.sync.cron}", zone = "Europe/Istanbul")
void nightly() {
    schedulerLock.tryRun("news-sync", Duration.ofMinutes(30), this::syncAll);
}
```

- `ttl`, görevin en uzun süresinden büyük olmalı; kilit TTL ile kendiliğinden düşer.
- Redis erişilemezse görev **atlanır** (fail-closed) ve sonraki tetikte denenir.
- Kilit adı görev başına benzersiz olmalı (`schedlock:<ad>` anahtarı).
- Daha zengin ihtiyaç (en az bekleme süresi, kilit denetimi) doğarsa ShedLock (JDBC provider) önerilir; bu, `pom.xml`'e bağımlılık ve yeni Flyway tablosu gerektirir.

Tek örnek (varsayılan compose ve tek VPS kurulumu) çalıştırıyorsanız ek işlem gerekmez: `@Scheduled` görevleri tek süreçte çalışır, çift çalışma riski yoktur, `SchedulerLock` sarmalamasına gerek yoktur (yalnız ileride ikinci backend örneği eklenirse gerekir). Ayrıca: dosya yüklemeleri yerel diskte olduğundan çoklu örnek için paylaşılan volume (NFS) veya nesne depolama gerekir; WebSocket presence/pub-sub Redis üzerindendir ve örnekler arası çalışır.

## 7. İzleme ve uyarı

- **Sağlık:** `GET /actuator/health` (compose healthcheck + proxy/uptime izleyici). `/actuator/health/liveness` ve `/readiness` probe'ları açıktır.
- **Bakım durumu:** `GET /api/status` (haber/menü senkron bakımda mı).
- **Log:** konteyner stdout'u; `docker compose logs -f backend`. Docker log rotasyonu (`max-size`, `max-file`) ayarlayın. Log'larda sır/kod yoktur (kod yalnızca `MAIL_ENABLED=false` iken yazılır).
- **Uyarı önerileri:** sağlık kontrolü 2 dk üst üste başarısız; disk > %80 (pgdata/uploads); yedek işi başarısız; 5xx oranı artışı (proxy log'u); `Uretim ayari uyarisi` / `Zamanlayici kilidi alinamadi` log satırları. Prometheus kullanılacaksa `micrometer-registry-prometheus` bağımlılığı (pom.xml) ve `management.endpoints.web.exposure.include`'a `prometheus` eklenmelidir (uç ADMIN'e kısıtlı kalır, proxy dışına verilmez).

## 8. Güncelleme ve geri alma

```bash
git pull
docker compose build backend web
docker compose up -d backend web     # Flyway migration'ları açılışta otomatik uygulanır
```

- Güncellemeden önce `pg_dump` alın. Graceful shutdown: SIGTERM'de 30 sn'ye kadar istekler tamamlanır (`stop_grace_period: 40s`).
- **Geri alma:** önceki imaj/etikete dönün (`git checkout <etiket>` + `docker compose up -d --build`). Flyway migration'ları **geri sarılmaz**; şema değişikliği içeren sürümü geri alacaksanız yedekten geri yükleme gerekir. Bu yüzden migration'lar geriye uyumlu (önce ekle, sonra kullan, en son kaldır) yazılır.
- Sıfır kesinti gerekiyorsa iki backend örneği + proxy'de sıralı yeniden başlatma kullanın (bkz. 6. bölüm kilit notu).

## 8.1 Erişim engelleri (IP / cihaz): proxy ve yapılandırma

- **`X-Forwarded-For` doğruluğu şarttır.** Engel, `common.ClientIp` ile çözülen istemci IP'sine bakar: `X-Forwarded-For` yalnızca bağlantıyı kuran eş `app.security.trusted-proxies` içindeyse (varsayılan loopback + özel ağlar) dikkate alınır. Üretimde ters vekil (nginx/ingress) `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;` iletmeli ve backend'e yalnızca vekil üzerinden erişilmelidir. Aksi halde herkes vekil IP'sinden görünür (özel ağ = engellenemez) ya da başlık sahtelenir. Compose `web` (nginx, `web/nginx.conf`) `/api`, `/files` ve `/ws` için `X-Forwarded-For $proxy_add_x_forwarded_for` ve `X-Real-IP` iletir (kontrol edildi); `X-Device-Id` gibi özel başlıklar nginx'ten olduğu gibi geçer. Önünde ek bir yük dengeleyici/CDN varsa onun da gerçek istemci IP'sini `X-Forwarded-For`'a yazması ve adresinin `app.security.trusted-proxies` içinde olması gerekir; aksi halde IP engeli yalnızca o ara katmanın IP'sini görür. Cihaz engeli bundan etkilenmez.
- **Cihaz engeli** `X-Device-Id` başlığına dayanır (mobil istemci gönderir; bkz. MOBILE_API_GUIDE.md "Cihaz kimliği başlıkları ve ACCESS_BLOCKED"). VPN'den bağımsızdır; başlık yoksa uygulanamaz.
- **`DEVICE_HMAC_KEY`:** cihaz özetleri bu anahtarla HMAC-SHA256'dır. Değişirse mevcut `DEVICE` engelleri ve `user_device_log` özetleri yeni özetlerle eşleşmez; kalıcı ve yedekli tutun.
- **İzin listesi:** `BAN_ALLOWLIST=203.0.113.0/28,2001:db8:10::/48` — yönetici ofis çıkış adresleri; bunlar kapsayan bir CIDR engeline rağmen geçer.
- **Anonimleştirici listesi (Tor örneği).** Sunucu dış servis çağırmaz; listeyi yönetici yükler. Tor çıkış düğümleri için resmi liste (`https://check.torproject.org/torbulkexitlist`, satır başına bir IPv4) bir yönetici makinesinde indirilir ve metin olarak yüklenir:
  ```bash
  curl -s https://check.torproject.org/torbulkexitlist -o tor-exit.txt
  jq -Rs '{text: ., source: "tor-exit"}' tor-exit.txt | curl -s -X POST "$BASE/api/admin/access-bans/anonymizers" \
      -H "Authorization: Bearer $ADMIN_TOKEN" -H 'Content-Type: application/json' -d @-
  ```
  Yükleme biçimi: satır başına `IP-veya-CIDR [etiket]`, `#` yorum; en çok 5000 satır/istek (daha uzun listeyi parçalayın: `split -l 4000 tor-exit.txt part_`). VPN/veri merkezi aralıkları aynı biçimde `source` etiketiyle yüklenir; yenilemek için `DELETE /api/admin/access-bans/anonymizers?source=tor-exit` sonra yeniden yükleyin. `BLOCK_ANONYMIZERS=true` olmadan liste uygulanmaz.
- **Zamanlayıcı:** `AccessBanRetentionJob` (gece 04:30) cihaz/deneme günlüğünü 90 gün sonra siler; `SchedulerLock` ile çok örnekte tek çalışır. Vuruş sayaçları bellekte toplanıp 5 sn'de bir yazılır (çok örnekte her örnek kendi sayacını ekler).

## 9. KVKK saklama süreleri

| Veri | Süre | Mekanizma |
|---|---|---|
| Analitik olaylar | 180 gün | `analytics.EventRetention` (toplulaştırılmış) |
| Bildirimler | okunmuş 90 gün, okunmamış 365 gün | `NOTIFICATION_RETENTION_DAYS`, `NOTIFICATION_UNREAD_RETENTION_DAYS` |
| Herkese açık destek talepleri | 365 gün | `PUBLIC_TICKET_RETENTION_DAYS` |
| Herkes için silinen mesajlar (şifreli) | `CHAT_DELETED_RETENTION_DAYS` (0 = süresiz) | `DeletedMessageRetention` |
| Sahiplenilmemiş sohbet görselleri | 24 saat | `CHAT_MEDIA_UNCLAIMED_HOURS` |
| Cihaz/IP geçmişi (`user_device_log`) ve engellenen deneme günlüğü | 90 gün (`BAN_LOG_RETENTION_DAYS`) | `AccessBanRetentionJob`; hesap silinince kullanıcının kayıtları anında silinir |
| Hesap silme | anında anonimleştirme | `DELETE /api/users/me` |
| Veri taşınabilirliği | talep üzerine | `GET /api/users/me/export` |

Yedekler de kişisel veri içerir: yedek saklama süresi (öneri <= 6 ay) politika belgesinde yer almalı; silinen hesaplar yedekten geri yükleme sonrası yeniden anonimleştirilmelidir. Sözleşme metinleri taslaktır; yayın öncesi hukuki inceleme gerekir.

- **Sohbet ek saklama (V270):** `app.chat.media.view-once-retention-days` (varsayılan 365; 0 = açılışta/24 sa sonra silme). Yönetici sohbet erişimi ve denetim: docs/ENCRYPTION.md "Yönetici erişimi, saklama süreleri ve denetim".

## 10. Medya: ffmpeg dönüştürme ve CDN

### ffmpeg
Backend imajı `ffmpeg`/`ffprobe` içerir (`backend/Dockerfile`). Gönderi videoları arka planda H.264 (main) + AAC, en çok 720p, ~1,5 Mbps, `+faststart` olarak yeniden kodlanır; poster gönderilmediyse ilk anlamlı kareden üretilir. Ayarlar: `MEDIA_TRANSCODE_ENABLED`, `MEDIA_TRANSCODE_WORKERS` (CPU limitiyle uyumlu: `BACKEND_CPUS` >= workers x `MEDIA_TRANSCODE_THREADS`), `MEDIA_TRANSCODE_TIMEOUT`. ffmpeg yoksa ya da kapalıysa video orijinal sunulur (kesinti yok). Ayrıntı: [MEDIA_PIPELINE.md](MEDIA_PIPELINE.md). Geçici dosyalar `/tmp` tmpfs'tedir (2 GB).

### CDN hazırlığı (imzalı kısa ömürlü URL)
Varsayılan **kapalıdır** (`MEDIA_CDN_BASE_URL` boş). Gönderi medyası oturum gerektirir; CDN yalnız **imzalı URL** ile kullanılabilir.

- **Çalışma modeli:** `MEDIA_CDN_BASE_URL=https://cdn.example.edu.tr` + `MEDIA_CDN_REDIRECT=true` iken, yetkisi doğrulanmış kullanıcının `GET /api/posts/media/{id}` isteği `302 Location: https://cdn.../files/cdn/post/{id}?t=0&exp=..&sig=..` döner (`Cache-Control: no-store`). CDN, origin'i (bu uygulama) aynı yoldan çeker; origin imzayı ve süreyi doğrular, gönderi silinmiş/gizliyse 404 verir ve `Cache-Control: public, max-age=<imzanın kalan ömrü, en çok MEDIA_CDN_TTL>` ekler. Baytlar origin'de çözülüp sunulur (diskte şifreli kalır).
- **Cloudflare/Bunny arkası kurulum:**
  1. `cdn.example.edu.tr` → CDN, origin = `https://<DOMAIN>` (Caddy). Origin protokolü HTTPS ("Full (strict)").
  2. **Cache kuralı:** yalnız `/files/cdn/post/*` yolu önbelleğe alınır; **önbellek anahtarı sorgu dizesini (t, exp, sig) içermeli** ("Include query string: all"). Başka yol (`/api/*`, `/ws`, `/files/p/*`, yönetim) için "Bypass cache".
  3. **TTL:** "Respect origin Cache-Control" (kenar TTL'i origin başlığından gelir; 120-300 sn). `Range` isteklerini origin'e iletin / "Slice" kullanın (video).
  4. Origin ucuna CDN dışından doğrudan erişim de imza gerektirir; ek koruma olarak Caddy/ufw ile yalnız CDN IP aralıklarına izin vermek isteğe bağlıdır.
  5. CORS gerekmez (`<video>`/`<img>` etiketleri); gerekirse CDN'de `Access-Control-Allow-Origin` yalnız uygulama kökeni.
- **UYARI - özel içeriği önbelleğe almayın:** CDN'de "Cache Everything" gibi kuralları `/api/**` veya `/files/p/**` (sohbet medyası) için **açmayın**. Sohbet görselleri/videoları ve oturumlu uçlar `no-store/private` başlıklarına uyar; CDN bunları görmezden gelirse yetkisiz içerik sızar. Gönderi medyası da yalnız bu belgedeki **imzalı URL** biçimiyle CDN'e verilir.
- **Mobil uyumluluğu:** 302 yönlendirmesi başka bir köke gider; HTTP istemcisi yönlendirmede `Authorization` başlığını **taşımamalıdır**. Mobil/web ile test etmeden `MEDIA_CDN_REDIRECT=true` açmayın (geri alınabilir: false).
- İmza anahtarı `app.media.signing-secret` yoksa `JWT_SECRET`'ten türer; JWT rotasyonu açık CDN URL'lerini geçersiz kılar (kısa ömürlü, sorun değil). Saat sapması imza hatası üretir (NTP).

## 11. Staging

```bash
cp .env.staging.example .env.staging && bash scripts/ops/gen-secrets.sh --env staging --force
# Ayrı sunucuda ya da ayrı alan adıyla:
ENV_FILE=.env.staging PROJECT=bu-staging COMPOSE_FILES="-f docker-compose.prod.yml -f docker-compose.staging.yml" \
  bash scripts/deploy/update.sh --first
```

`docker-compose.staging.yml` üretim bindirmesidir: `SPRING_PROFILES_ACTIVE=prod,staging`, **MailHog** (sahte SMTP; arayüz `127.0.0.1:8025`, SSH tüneliyle), daha küçük yedek saklama. Aynı yapı, **farklı sırlar** (özellikle `CRYPTO_MASTER_KEYS`/`JWT_SECRET`/`DB_PASSWORD`) ve farklı alan adı. Üretim verisini staging'e kopyalamayın (KVKK). `-p bu-staging` volume'ları ayırır.

## 12. Yedekleme, izleme ve olay müdahalesi bağlantıları

- Yedek servisi (`backup`) **her saat** şifreli (age) `pg_dump` + uploads (fotoğraflar dahil) yedeği alır, **en yeni 3 tutulur**, haftalık geri yükleme doğrulaması yapar: [BACKUP.md](BACKUP.md) (politika/kararlar), [BACKUP_RESTORE.md](BACKUP_RESTORE.md). Bölüm 4'teki elle komutlar yedek servisi varken gerekmez.
- Anahtarlar/sırlar: [KEY_MANAGEMENT.md](KEY_MANAGEMENT.md). Olay müdahalesi: [RUNBOOK.md](RUNBOOK.md).
- İzleme: `monitoring/` (Prometheus/Grafana/Alertmanager); yedek metriği `backup_last_success_timestamp_seconds` `monitoring/textfile/backup.prom` üzerinden gelir (aynı dosya `http://backup:9199/backup.prom` ile de sunulur, bkz. OBSERVABILITY.md sonu). İzleme yığınını `-f monitoring/docker-compose.monitoring.yml` ile ekleyin.

## 13. Tek VPS: adım adım (Ubuntu 22.04/24.04 LTS)

Önerilen en az: 2 vCPU, 4 GB RAM (JVM + PostgreSQL + ffmpeg), SSD; yüklemeler ve 3 yedek için veri boyutunun en az 4 katı disk.

1. **DNS:** `DOMAIN` için A (ve varsa AAAA) kaydı VPS IP'sine. Yayılmadan ilk dağıtım yapmayın (Let's Encrypt hız sınırı).
2. **SSH anahtarı (yerelde):** `ssh-keygen -t ed25519`; `ssh-copy-id root@<ip>`. Anahtarla girişin çalıştığını **ayrı bir oturumda** doğrulayın.
3. **Sunucu hazırlığı (root):** `git clone <repo> /opt/bu && cd /opt/bu && sudo bash scripts/deploy/bootstrap-server.sh --deploy-user bu` — Docker, UFW (yalnız 22/80/443; DB/Redis/backend portu zaten yayınlanmaz), fail2ban, otomatik güvenlik güncellemesi, saat dilimi `Europe/Istanbul`, 2 GB swap. Sonra `/etc/ssh/sshd_config`: `PasswordAuthentication no`, `PermitRootLogin no`; `systemctl reload ssh`. Depo sahibi `bu` olmalı: `chown -R bu:bu /opt/bu`, `su - bu`.
4. **Sırlar:** `bash scripts/ops/gen-secrets.sh` → `.env.prod` (izin 600). Elle doldurun: `DOMAIN`, `ACME_EMAIL`, `CORS_ORIGINS`/`PUBLIC_WEB_URL` (`https://<DOMAIN>`), `ADMIN_EMAILS`, `MAIL_*`, `BACKUP_AGE_RECIPIENT`. Tam liste ve açıklamalar `.env.prod.example` içindedir (`ProdSettingsValidator`'ın zorunlu tuttukları: `DB_PASSWORD`, `JWT_SECRET`, `ADMIN_PASSWORD`, `CORS_ORIGINS`, `CRYPTO_MASTER_KEYS`/`CRYPTO_ACTIVE_KEY_ID`, `MAIL_HOST`). **`.env.prod` ve `CRYPTO_MASTER_KEYS`'i hemen şifre yöneticisine + çevrimdışı kasaya kopyalayın** (yedeğe girmez: [BACKUP.md](BACKUP.md)).
5. **Yedek anahtarı:** çevrimdışı makinede `age-keygen -o kurtarma.age.key`; `age1...` genel anahtarı `BACKUP_AGE_RECIPIENT`'e. Önerilen: `BACKUP_REMOTE` (ikinci sunucu/S3, `deploy/rclone/rclone.conf`).
6. **FCM (push):** Firebase servis hesabı JSON'u tek satır (`base64 -w0 firebase.json`) `FCM_CREDENTIALS_JSON`'a. Ayrıntı: [PUSH_SETUP.md](PUSH_SETUP.md). Boşsa yalnız uygulama içi bildirim çalışır.
7. **E-posta alan adı:** SPF/DKIM/DMARC kayıtları ve `List-Unsubscribe`: [MAIL_DELIVERABILITY.md](MAIL_DELIVERABILITY.md), [changes/mail.md](changes/mail.md). Gerçek SMTP olmadan doğrulama kodu e-postası gitmez.
8. **İlk dağıtım:** `bash scripts/deploy/update.sh --first` (derler, başlatır, sağlık kontrolü). Doğrulama: `curl -I https://<DOMAIN>/` (200, geçerli sertifika), `https://<DOMAIN>/api/status`, `https://<DOMAIN>/actuator/health` **404** olmalı.
9. **İlk yönetici:** `ADMIN_EMAILS`'teki adresle `bingol.edu.tr` e-postası üzerinden uygulamadan/`/api/auth/register` ile kayıt + doğrulama; giriş yapınca rol ADMIN olur. Yönetim paneli `https://<DOMAIN>/admin` (ya da `ADMIN_PATH`). Basic auth yedek yolu: `admin:$ADMIN_PASSWORD`.
10. **Yedek ön kontrolü:** `docker compose -p bu -f docker-compose.prod.yml --env-file .env.prod exec backup /opt/backup/backup.sh --dry-run`, sonra bir elle yedek ve `verify-restore.sh --latest` (BACKUP.md).
11. **Güncelleme:** `bash scripts/deploy/update.sh [--ref vX.Y.Z]` (önce yedek, çek, derle, başlat, sağlık; başarısızsa otomatik geri alma). **Geri alma:** `bash scripts/deploy/rollback.sh`; şema değişikliği olan sürümde yedekten geri yükleme gerekir (bölüm 8).
12. **Proxy doğrulaması (Caddy, `deploy/Caddyfile`):** `/files/**` ve `/api/**` backend'e gider, gövde sınırı `CADDY_MAX_BODY` (55 MB; Spring 45 MB), WebSocket `/ws` otomatik yükseltilir ve tamponlanmaz (okuma 180 sn), `X-Forwarded-For` Caddy tarafından `{client_ip}` olarak yazılır (istemci başlığı ezilir) ve backend yalnız `TRUSTED_PROXIES` ağından gelene güvenir (CLAUDE.md rate limit notu karşılandı). Yüklemeler `uploads` volume'unda (`STORAGE_DIR=/data/uploads`) kalır ve saatlik yedeğe dahildir.

## Sistem durumu, Prometheus ve Uptime Kuma önerisi (VPS)

- **Yönetici paneli:** `/admin/system` (API: `GET /api/admin/system/overview`). 30 sn'de bir yenilenir; CRIT'e geçişte yöneticilere uygulama içi bildirim gider, `OBS_ALERT_EMAIL` doluysa e-posta da denenir. Eşikler `app.observability.*` (bkz. ADMIN_API.md).
- **Prometheus (`/actuator/prometheus`):** varsayılan KAPALI. Açmak için `MANAGEMENT_PORT=8081` ve `ACTUATOR_EXPOSURE=health,info,prometheus`; uç yalnız bu ayrı portta ve compose ağı içinde herkese açıktır (`ports:` ile dışarı verilmez, ana portta `/actuator/**` ADMIN'dir). Ayrıntı: OBSERVABILITY.md. Dışarıdan erişilecekse proxy'de Basic auth ya da IP kısıtı şarttır; emin değilseniz açmayın.
- **Küçük VPS için öneri:** tam Prometheus+Grafana yığını (monitoring/) 2 GB altındaki makinede ağırdır. Bunun yerine (1) **Uptime Kuma** (tek konteyner, ~100 MB): `https://<alan>/actuator/health` için HTTP(s) monitörü (2 dk), TLS sertifika süresi monitörü, gerekirse "keyword" monitörü ile web ana sayfası; bildirim kanalı olarak e-posta/Telegram. (2) Uygulama içi uyarıyı **dış** kanalın yedeği olarak bırakın: Uptime Kuma backend tamamen çöktüğünde uyarır, `SystemAlertService` ise backend ayaktayken iç sorunları (kuyruk, yedek, disk) bildirir. İkisi birbirini tamamlar; backend çöktüğünde uygulama içi bildirim gelmez.
- **Yedek:** yedek ajanı `last-success.json` yazmazsa `backup.age` göstergesi UNKNOWN kalır ve eskime uyarısı üretmez; yedek betiği dosyayı yazdığından emin olun.
