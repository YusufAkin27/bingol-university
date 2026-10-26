# Üretim Kurulumu (DEPLOY)

Bu belge BÜ Kampüs yığınını (postgres + redis + backend + web/nginx) tek sunucuda Docker Compose ile üretime almayı anlatır.

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
| `MAIL_ENABLED`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM` | `MAIL_ENABLED=true` önerilir | Doğrulama kodu e-postası; kapalıyken kod log'a yazılır |
| `FCM_CREDENTIALS_FILE` | hayır | Konteyner içindeki Firebase servis hesabı JSON yolu (secret olarak mount edin); boşsa push kapalı |
| `PUBLIC_WEB_URL` | önerilir | Herkese açık web adresi (destek takip bağlantıları) |
| `STORAGE_DIR` | hayır | Compose'ta `/data/uploads` (volume) |
| `INITIAL_FILL` | hayır | Boş tablolarda ilk haber/menü doldurma |
| `DB_POOL_MAX`, `DB_POOL_MIN_IDLE` | hayır | Hikari havuzu (varsayılan 20 / 5) |
| `MULTIPART_MAX_FILE`, `MULTIPART_MAX_REQUEST` | hayır | Yükleme sınırları (5MB / 6MB) |
| `BACKEND_MEM_LIMIT`, `BACKEND_CPUS`, `POSTGRES_MEM_LIMIT`, `REDIS_MEM_LIMIT` | hayır | Konteyner kaynak limitleri (1g / 2 / 1g / 256m) |
| `JAVA_TOOL_OPTIONS` | hayır | Ek JVM bayrakları (imaj varsayılanı: `-XX:MaxRAMPercentage=75`) |
| `BACKEND_PORT`, `WEB_PORT`, `ADMIN_PATH` | hayır | Portlar ve gizli yönetim yolu |

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

Tek örnek (varsayılan compose) çalıştırıyorsanız ek işlem gerekmez. Ayrıca: dosya yüklemeleri yerel diskte olduğundan çoklu örnek için paylaşılan volume (NFS) veya nesne depolama gerekir; WebSocket presence/pub-sub Redis üzerindendir ve örnekler arası çalışır.

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

## 9. KVKK saklama süreleri

| Veri | Süre | Mekanizma |
|---|---|---|
| Analitik olaylar | 180 gün | `analytics.EventRetention` (toplulaştırılmış) |
| Bildirimler | okunmuş 90 gün, okunmamış 365 gün | `NOTIFICATION_RETENTION_DAYS`, `NOTIFICATION_UNREAD_RETENTION_DAYS` |
| Herkese açık destek talepleri | 365 gün | `PUBLIC_TICKET_RETENTION_DAYS` |
| Herkes için silinen mesajlar (şifreli) | `CHAT_DELETED_RETENTION_DAYS` (0 = süresiz) | `DeletedMessageRetention` |
| Sahiplenilmemiş sohbet görselleri | 24 saat | `CHAT_MEDIA_UNCLAIMED_HOURS` |
| Hesap silme | anında anonimleştirme | `DELETE /api/users/me` |
| Veri taşınabilirliği | talep üzerine | `GET /api/users/me/export` |

Yedekler de kişisel veri içerir: yedek saklama süresi (öneri <= 6 ay) politika belgesinde yer almalı; silinen hesaplar yedekten geri yükleme sonrası yeniden anonimleştirilmelidir. Sözleşme metinleri taslaktır; yayın öncesi hukuki inceleme gerekir.
