# Gözlemlenebilirlik: metrikler, Sentry, uyarılar

## Mimari

```
backend:8081 /actuator/prometheus  <--  Prometheus  -->  Alertmanager (e-posta / Slack / Telegram)
                                         |
                                      Grafana (panolar)      node-exporter, blackbox (disk, yedek, TLS)
```

Hepsi `monitoring/docker-compose.monitoring.yml` içindedir ve **yalnız** `docker-compose.prod.yml` (ve isteğe bağlı staging) üzerine bindirilir:

```bash
docker compose -f docker-compose.prod.yml -f monitoring/docker-compose.monitoring.yml --env-file .env.prod up -d
```

**Kök `docker-compose.yml` ile BİRLEŞTİRMEYİN** (`-f docker-compose.yml -f docker-compose.prod.yml ...`): o dosya backend:8080 ve web:8090'ı internete düz HTTP yayınlar (Caddy atlanır). `docker-compose.prod.yml` bu portları `ports: !reset []` ile sıfırlar, yine de doğru komut yukarıdaki gibidir; `scripts/ci/compose-ports-check.sh` yalnız Caddy 80/443'ün açık kaldığını CI'da denetler.

Bindirme `MANAGEMENT_PORT=8081` verir: actuator yalnız 8081'de sunulur, 8080'de `/actuator/**` yoktur. Bunun iki sonucu bindirmede çözülmüştür: (1) Caddy'nin aktif sağlık denetimi `BACKEND_HEALTH_PORT=8081` ile aynı porta taşınır (aksi halde 8080'de 404 → tek upstream "unhealthy" → tüm site 503 olurdu); (2) izleme servisleri backend ile aynı `edge` ağına katılır, Prometheus `backend:8081`'i çözer. Yönetim portu Caddy üzerinden dışarı verilmez (`@internal` 404).

Gerekli `.env`: `GRAFANA_ADMIN_PASSWORD` (zorunlu), `ALERT_SMTP_HOST/PORT/USER/PASSWORD`, `ALERT_EMAIL_FROM/TO`, isteğe bağlı `SLACK_WEBHOOK_URL`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` (Alertmanager'da ilgili alıcı bloğunun yorumunu açın), `BACKUP_METRICS_DIR`. Prometheus/Grafana yalnız `127.0.0.1`'e bağlanır; SSH tüneli ya da ters vekil (Caddy) ile erişin.

## Metrik uç noktası güvenliği

- `application-prod.properties`: `MANAGEMENT_PORT` verilirse actuator **ayrı portta** (örn. 8081) sunulur; `ACTUATOR_EXPOSURE` ile `prometheus` açılır. Bu portu compose dışına **yayınlamayın** (`ports:` yok); ana portta (8080) `/actuator/**` yoktur.
- `SecurityConfig`: `/actuator/prometheus` yalnız isteğin geldiği yerel port `management.server.port` ise herkese açık sayılır; diğer her yol/port mevcut kurallarla (health açık, gerisi ADMIN) kalır.
- Yönetim portu açıldığında sağlık denetimi de 8081'e taşınır; monitoring compose dosyası backend `healthcheck`'ini buna göre geçersiz kılar.
- Varsayılan (`MANAGEMENT_PORT` boş): eski davranış, yalnız `health,info`.

## Metrikler

Hazır Micrometer: `http_server_requests_seconds_*` (uri, method, status; histogram açık), JVM, `hikaricp_*`, `process_*`. Özel (`config/ObservabilityMetrics`):

| Metrik | Kaynak |
|---|---|
| `bu_push_delivered_total`, `bu_push_failures_total`, `bu_push_dropped_total`, `bu_push_retries_total` | `PushDispatcher` sayaçları |
| `bu_mail_outbox{status=pending\|failed\|dead}` | `MailService.queueStats()` (15 sn önbellek) |
| `bu_websocket_sessions`, `bu_websocket_users` | `SimpUserRegistry` (yalnız bu sunucu) |

Ayrı sayaç gerektirmeyenler PromQL ile: giriş başarısızlığı `rate(http_server_requests_seconds_count{uri="/api/auth/login",status="401"}[5m])`; engellenen erişim `status=~"403|429"`; gönderi/yorum `method="POST",uri=~"/api/posts.*"`; medya yükleme süresi `http_server_requests_seconds_bucket{uri=~".*media.*"}`. Push kuyruk uzunluğu şu an dışa açık değil (`PushDispatcher` içindeki havuz özel); `PushQueueStuck` uyarısı düşen/başarısız sayaçlardan türetilir. Kalıcı push kuyruğu (outbox) gelince onun gösterge metrikleri eklenmelidir.

Uyarılar: `monitoring/prometheus/alert.rules.yml` — BackendDown, High5xxRate, HighLatencyP95, DbPoolExhausted, PushQueueStuck, MailQueueStuck, HighJvmHeap, DiskLow, BackupTooOld (eşik **3 saat**), BackupLastRunFailed, BackupVerifyFailed, BackupVerifyStale, CertExpiry, ProbeFailed. Pano: Grafana "BU Kampus / BU Uygulama" (otomatik yüklenir; JVM, HTTP, DB, uygulama).

### Yedek metriği (BE2 ile uyum)

`BackupTooOld`, `backup_last_success_timestamp_seconds` metriğini bekler. Yedek betiği başarıda node-exporter textfile dizinine (varsayılan `monitoring/textfile/`, `BACKUP_METRICS_DIR`) şu satırı atomik (geçici dosya + `mv`) yazmalıdır:

```
backup_last_success_timestamp_seconds 1767225600
```

Metrik hiç yoksa uyarı da tetiklenir (`absent`). **BE2'nin gerçek metrik adı/yeri bu belgeyle karşılaştırılmalıdır.** Yönetici API'si (`GET /api/admin/ops/backup-status`) aynı dosyayı (`app.ops.backup-status-file`, varsayılan `/var/backups/last_success`) okur; konteynerde görünmesi için o dizinin backend'e salt okunur bağlanması gerekir.

### TLS süresi

`monitoring/prometheus/blackbox-targets.yml` içine herkese açık HTTPS adresi yazılmalıdır (örnek değer yer tutucudur).

## Operasyon API'si (ADMIN)

`GET /api/admin/ops/health`, `GET /api/admin/ops/mail-outbox/stats`, `POST /api/admin/ops/mail-outbox/retry-dead` (denetim kaydına yazılır), `GET /api/admin/ops/backup-status`. Sözleşme: `docs/API_CONTRACTS_V2.md` "Operasyon paneli". `transcode/stats` henüz yok (isteğe bağlıydı).

## Sentry

- Backend: `SENTRY_DSN` boşsa **kapalı**. Doluysa `ObservabilitySentry` çekirdek SDK'yı başlatır ve logback kök kaydediciye ERROR düzeyi appender ekler. Spring Boot starter kullanılmadı (Boot 4 uyumluluk riski). Ayarlar: `SENTRY_ENVIRONMENT`, `SENTRY_RELEASE` (örn. git sha), `SENTRY_TRACES_SAMPLE_RATE` (varsayılan 0 = performans izi yok).
- Gizlilik: `send-default-pii=false`; `beforeSend` istek gövdesini, başlıkları, çerezleri, sorgu dizesini, kullanıcıyı siler; mesaj/istisna metnindeki e-posta, JWT, `Bearer`, `password/token/code=...` değerlerini maskeler. Kendi barındırdığınız Sentry'de bile bu geçerlidir (KVKK).
- Sürüm bilgisi için imaj derlemesinde `SENTRY_RELEASE=${{ github.sha }}` verilebilir.

### Web için Sentry notu (kod EKLENMEDİ)

`@sentry/react` ile `main.tsx` başında `Sentry.init({ dsn: import.meta.env.VITE_SENTRY_DSN, sendDefaultPii: false, tracesSampleRate: 0, beforeSend(e){ delete e.request?.cookies; delete e.request?.data; return e; } })`. DSN yalnızca derleme zamanı değişkenidir (gizli değil ama yalnız web projesine ait olmalı). Kaynak haritaları için CI'da `@sentry/vite-plugin` ve `SENTRY_AUTH_TOKEN` sırrı gerekir. CSP `connect-src`'e Sentry ingest adresi eklenmelidir (`web/nginx-security.conf`). Uygulanacak ekip: web ajanı.

## Yedek metriği: BE2 ile uyum (kesinleşti)

Yedek servisi (`docker-compose.prod.yml` > `backup`, `scripts/backup/`) metrikleri **Prometheus textfile biçiminde** `${BACKUP_METRICS_DIR:-./monitoring/textfile}/backup.prom` dosyasına atomik (geçici dosya + `mv`) yazar; bu dizin node-exporter `--collector.textfile.directory` ile **aynı** bağlama noktasıdır (ek ayar gerekmez). Aynı dosya `http://backup:9199/backup.prom` ile HTTP olarak da sunulur (yedek: Prometheus'a ek `static_configs` hedefi `backup:9199`, `metrics_path: /backup.prom`; ikisini birden kazımayın, çift seri olur).

| Metrik | Tür | Anlam | Not |
|---|---|---|---|
| `backup_last_success_timestamp_seconds` | gauge | Son **başarılı** yedek (unix sn) | `BackupTooOld` bunu kullanır; başarısız denemede **değişmez** |
| `backup_last_run_timestamp_seconds` | gauge | Son deneme zamanı | |
| `backup_last_status` | gauge | 1 başarılı / 0 başarısız (son deneme) | uyarı önerisi: `== 0` |
| `backup_last_duration_seconds`, `backup_last_db_bytes`, `backup_last_uploads_bytes` | gauge | Süre, şifreli boyutlar | boyut ani düşüşü = şüpheli |
| `backup_verify_last_success_timestamp_seconds` | gauge | Son **başarılı geri yükleme doğrulaması** | Öneri: `time() - backup_verify_last_success_timestamp_seconds > 9*86400` (haftalık doğrulama kaçtı) |
| `backup_verify_last_status` | gauge | Son doğrulama 1/0 | uyarı önerisi: `== 0` |

`/var/backups/last_success` (unix sn) yedek konteynerinde tutulur; yönetici API'si (`app.ops.backup-status-file`) compose'ta `/backup-status/backup.prom` dosyasını okur (`APP_OPS_BACKUP_STATUS_FILE`, aynı textfile dizini salt okunur bağlıdır; içindeki `backup_last_success_timestamp_seconds <sn>` satırı ayrıştırılır). Yedek hiç çalışmadıysa dosya sıfır değerlerle oluşturulur (`absent()` değil ama `time() - 0` çok büyük: `BackupTooOld` tetiklenir, istenen davranış). Başarısızlıkta ayrıca `BACKUP_WEBHOOK_URL`'e bildirim gider.

## Yedek durum göstergesi (uygulama içi) ve uyarı kanalları (A4)

- Uygulama içi `backup` göstergesi (`BackupStatusProvider`) `BACKUP_STATUS_FILE` dosyasını okur. Compose'ta yedek servisi `/var/backups/metrics/last-success.json` yazar; backend aynı host dizinini (`${BACKUP_METRICS_DIR:-./monitoring/textfile}`) `/backup-status` altında **salt okunur** bağlar ve `BACKUP_STATUS_FILE=/backup-status/last-success.json` okur. Biçim `{"lastSuccessAt":"2026-10-28T09:05:00Z",...}` (UTC, `Z` sonekli; yerel saat dilimli biçim `Instant.parse` ile ayrışmaz ve gösterge hep UNKNOWN olurdu).
- Prometheus kuralları: `BackupTooOld` (`time() - backup_last_success_timestamp_seconds > 10800`; saatlik yedek + 3 saatlik pencere), `BackupLastRunFailed` (`backup_last_status == 0` 2 saat), `BackupVerifyFailed` (`backup_verify_last_status == 0`), `BackupVerifyStale` (son başarılı geri yükleme doğrulaması 9 günden eski; doğrulama hiç yapılandırılmadıysa da tetiklenir).
- `BACKUP_WEBHOOK_URL` dolu ise yedek/doğrulama hatası ayrıca webhook ile bildirilir (JSON kaçışı düzeltildi; eski `sed` ifadesi geçersiz olduğundan bildirim hiç gitmiyordu).
