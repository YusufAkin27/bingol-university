# Olay Müdahale Runbook'u (RUNBOOK)

Kime: nöbetçi mühendis/yönetici. Her olayda önce **sakin kalın, kaydedin** (saat, ne görüldü, ne yapıldı). Komutlar sunucuda repo kökünden çalışır:

```bash
DC="docker compose -f docker-compose.prod.yml --env-file .env.prod"
$DC ps                       # servis durumları
$DC logs --tail=200 backend  # son günlük
```

İlgili belgeler: [DEPLOY.md](DEPLOY.md), [BACKUP_RESTORE.md](BACKUP_RESTORE.md), [KEY_MANAGEMENT.md](KEY_MANAGEMENT.md), [OBSERVABILITY.md](OBSERVABILITY.md) (uyarılar, Grafana, Sentry), [PUSH_SETUP.md](PUSH_SETUP.md), [ENCRYPTION.md](ENCRYPTION.md).

Önem derecesi: **S1** hizmet tamamen kapalı / veri sızıntısı; **S2** önemli özellik bozuk; **S3** kısmi/yavaş.

## 1. Backend çöktü / sürekli yeniden başlıyor (S1)

Belirti: `BackendDown` uyarısı, `/api` 502/503, `$DC ps` backend `restarting`/`unhealthy`.

1. `$DC logs --tail=300 backend | grep -iE "ERROR|Exception|Uretim ayarlari|APPLICATION FAILED"`
2. **Açılış doğrulaması hatası** (`Uretim ayarlari gecersiz`, `Sifreleme ana anahtari yok`): `.env.prod` eksik/yanlış. Son değişikliği geri alın; sırları şifre yöneticisinden doğrulayın. Anahtar değeri log'a yazılmaz, yalnız adı.
3. **Flyway hatası** (`Migration checksum mismatch`, `Detected failed migration`): uygulanmış migration düzenlenmemeli. Kodu önceki sürüme alın (`bash scripts/deploy/rollback.sh`); başarısız migration bir sürüm yarım kaldıysa veritabanını yedekten geri yükleme gerekebilir (BACKUP_RESTORE).
4. **OOM** (`OutOfMemoryError`, `exit code 137`): `$DC logs` + `docker stats`; `BACKEND_MEM_LIMIT` artırın; ffmpeg eşzamanlılığını düşürün (`MEDIA_TRANSCODE_WORKERS=1`); `docker compose up -d backend`.
5. **DB/Redis bağlantısı** (`Connection refused`): bölüm 2 / 3.
6. Son dağıtımdan sonra başladıysa: `bash scripts/deploy/rollback.sh --auto`.
7. Çözülmezse: bakım bandını açın (yönetici `maintenance_mode` ayarı) ve olayı yükseltin.

## 2. Veritabanı doldu / yavaş / çöktü (S1-S2)

Belirti: `DiskAlmostFull`, `PSQLException: No space left`, `could not extend file`.

1. `df -h` ve `docker system df`; `$DC exec postgres du -sh /var/lib/postgresql/data`.
2. Hızlı yer açma (güvenli sıra): `docker image prune -f`; eski konteyner günlükleri (`json-file` zaten döner); `backups` volume'unda eski yedekler (`BACKUP_KEEP_*` küçültüp `backup.sh` çalıştırın); `uploads` dışı.
3. Tablo şişmesi: `$DC exec postgres psql -U bingol -d bingol -c "select relname, pg_size_pretty(pg_total_relation_size(oid)) from pg_class where relkind='r' order by pg_total_relation_size(oid) desc limit 10"`. Olay/log tabloları (analitik 180 gün, bildirim, `mail_outbox`) saklama işleriyle temizlenir; `VACUUM (ANALYZE)` çalıştırın. `VACUUM FULL` kilitler: bakım penceresinde.
4. Diski büyütün (sağlayıcı) → dosya sistemi büyütme → `docker compose up -d postgres`.
5. Bozulma şüphesi (`invalid page`, `could not read block`): **yazmayı durdurun** (`$DC stop backend`), önce yedek alın (`pg_dump` deneyin), [BACKUP_RESTORE](BACKUP_RESTORE.md) bölüm 5 ile yeni örneğe geri yükleyin.
6. Bağlantı havuzu tükendi (`HikariPool ... timeout`): yavaş sorgu/kilit: `select pid, state, wait_event, left(query,80) from pg_stat_activity where state <> 'idle' order by query_start`; takılı oturumu `pg_terminate_backend(pid)`.

## 3. Redis yok / çöktü (S1)

Etkisi: giriş, kayıt, refresh, rate limit, mesajlaşma, presence çalışmaz; haber/menü okuma çalışır (CLAUDE.md).

1. `$DC ps redis`, `$DC logs --tail=100 redis`, `$DC exec redis redis-cli ping`.
2. Çöktüyse: `$DC up -d redis` (AOF `redisdata` ile durum geri gelir). Disk doluysa bölüm 2.
3. Bellek (`maxmemory 200mb`, `noeviction`): `redis-cli info memory`; anahtar patlaması varsa (`redis-cli --scan --pattern 'rl:*' | wc -l`) kaynağı bulun (saldırı?) → bölüm 8.
4. Veri kaybolduysa: kullanıcılar yeniden giriş yapar, bekleyen kayıt kodları (1 saat) düşer, askı işaretleri (`suspended:*`) kaybolur → **askıya alınmış kullanıcılar yeniden dene**: yönetici panelinden askıdakileri kontrol edin; gerekirse backend yeniden başlatılarak işaretler yeniden üretilir (açılış senkronu).
5. Backend Redis'e yeniden bağlanır (timeout 2 sn); gerekirse `$DC restart backend`.

## 4. FCM / push hataları (S3)

Belirti: bildirimler push olarak gelmiyor; `fcm` sağlık göstergesi DOWN/WARN; günlükte `FirebaseMessagingException`, `UNREGISTERED`, `SENDER_ID_MISMATCH`, `THIRD_PARTY_AUTH_ERROR`.

1. `GET /api/admin/ops/health` (`fcm`). Uygulama içi bildirim kutusu etkilenmez.
2. `fcm: kapali` → `FCM_CREDENTIALS_JSON` boş/yanlış: tek satır JSON/base64 olduğunu doğrulayın (PUSH_SETUP). Düzeltip `$DC up -d backend`.
3. `UNREGISTERED`/`INVALID_ARGUMENT` yalnız ölü token'lardır: otomatik silinir, işlem gerekmez.
4. Toplu hata + `401/403`: servis hesabı anahtarı iptal edilmiş/dönmüş → Firebase konsolundan yeni anahtar (KEY_MANAGEMENT bölüm 6).
5. iOS gelmiyor: APNs anahtarı (Firebase > Cloud Messaging > APNs) eksik/süresi dolmuş.
6. Kota/Firebase kesintisi: https://status.firebase.google.com; push kampanyaları kuyruğu 3 yeniden deneme yapar, kutu bildirimi kalıcıdır.

## 5. Şifreleme anahtarı kaybı (S1, veri kaybı)

Önce **gerçekten kayıp mı** kontrol edin: şifre yöneticisi, çevrimdışı kasa, **Shamir parçaları** (`ssss-combine`), eski sunucudaki `.env.prod`, `docker inspect <backend>` ortamı (yalnız çalışan konteynerde varsa; `docker inspect` ile okuyup **hemen güvenli yere** kaydedin).

Hiçbir kopya yoksa (KEY_MANAGEMENT bölüm 8):
1. Mevcut şifreli veri **kalıcı okunamaz**: mesajlar, sohbet görselleri/videoları, gönderi videoları.
2. Yeni anahtar üretin (**yeni `id`**), `CRYPTO_MASTER_KEYS`/`CRYPTO_ACTIVE_KEY_ID`'ye ekleyin, yeni kopyaları **iki ayrı yerde** saklayın (yeniden kaybolmasın).
3. Uygulama anahtarsız açılmaz; eski anahtar `id`'si yoksa eski DEK'ler çözülemez: hatalar mesaj okumada `KEY_UNAVAILABLE` olarak görülür. Kullanıcılara mesaj geçmişinin kaybolduğunu duyurun; kayıp mesajları/medyayı veritabanından temizleme kararını yönetim onayıyla alın.
4. **KVKK:** veri kaybı da bir "veri güvenliği olayı"dır; ihlal değerlendirmesi için hukuk/KVKK sorumlusuna bildirin ([03 Veri ihlali müdahale planı](legal/internal/03_veri_ihlali_mudahale_plani.md)).
5. Neden ve düzeltici adımları (kopya sayısı, tatbikat) olay günlüğüne yazın.

## 6. Veri sızıntısı / ihlal şüphesi (S1, KVKK 72 saat)

Örnekler: yedek dosyası/uzak kova açık kaldı, sır repoda göründü, yetkisiz yönetici erişimi, SQL enjeksiyonu şüphesi, sunucuya yetkisiz giriş.

1. **Durumu sınırlayın:** erişimi kapatın (kova/bağlantı), şüpheli hesabı/oturumu kapatın, ilgili sırrı **hemen** rotasyona alın ([KEY_MANAGEMENT bölüm 9](KEY_MANAGEMENT.md)). Kanıtı silmeyin: günlükleri ve disk görüntüsünü kopyalayın.
2. **Zamanı kaydedin:** farkına varma anı = KVKK saati başlangıcı. Veri sorumlusunun kurula bildirimi **en geç 72 saat** içindedir; ilgili kişilere "en kısa sürede". Süreç, şablonlar ve karar ağacı: **[docs/legal/internal/03_veri_ihlali_mudahale_plani.md](legal/internal/03_veri_ihlali_mudahale_plani.md)**. Hukuk/KVKK sorumlusunu **hemen** arayın.
3. **Kapsamı belirleyin:** hangi veri (şifreli mi? anahtar da sızdı mı?), kaç kişi, hangi dönem. `audit_log` (yönetici işlemleri), `message_access_audit` (yönetici mesaj çözme), sunucu/Caddy erişim günlükleri, `user_device_log`.
4. Şifreli veri + anahtar **birlikte** sızmadıysa etki çok daha düşüktür (bunu belgeleyin).
5. Düzeltin, kök nedeni kapatın, olay raporu yazın (zaman çizelgesi, etki, alınan önlemler).

## 7. IP/cihaz engeli yanlış pozitif (S2)

Belirti: meşru kullanıcı `ACCESS_BLOCKED` alıyor (kampüs NAT'ı, ortak IP, kardeşin cihazı, VPN).

1. Kullanıcıdan görünen IP'yi/destek talep kodunu alın; yönetici paneli > Erişim engelleri > engel kayıtlarını ve **vuruş/deneme günlüğünü** inceleyin (engel kimin, ne zaman, neden).
2. **IP engeli:** ilgili kaydı kaldırın ya da kapsayan CIDR'yi daraltın. Kampüs/ofis çıkış adresleri için **izin listesi**: `.env.prod` `BAN_ALLOWLIST=203.0.113.0/28,...` (loopback ve özel ağlar zaten muaf) → `$DC up -d backend`. İzin listesi engelden önce gelir.
3. **Cihaz engeli:** `DEVICE` engel kaydını kaldırın. Cihaz kimliği HMAC'idir; `DEVICE_HMAC_KEY` değiştiyse eski engeller tutmaz (beklenen).
4. **Yanlış IP görünüyorsa** (hep Caddy/proxy IP'si): `X-Forwarded-For` iletimi bozuk; `TRUSTED_PROXIES` ve Caddy ayarını doğrulayın (DEPLOY.md bölüm 1/8.1). Aksi halde bir kişinin engeli herkesi etkiler.
5. Anonimleştirici (Tor/VPN) listesi aşırı genişse: `DELETE /api/admin/access-bans/anonymizers?source=...` ve `BLOCK_ANONYMIZERS=false`.
6. Kalıcı çözüm: engel gerekçesini gözden geçir, tekrarlarsa eşiği/süreyi ayarla; kullanıcıya itiraz yolu (destek talebi) sağlayın.

## 8. Saldırı / aşırı yük / kaba kuvvet (S2)

1. Caddy günlüğü: `$DC logs caddy | tail`; en çok istek yapan IP'ler (`jq -r .request.remote_ip`).
2. Uygulama rate limit'i 429 döner (`rl:*` Redis). Kalıcı kaynak: yönetici panelinden IP engeli (süreli); mümkünse ağ düzeyinde `ufw deny from <ip>`.
3. Kayıt/giriş patlaması: `register` IP başına saatte 10 ile sınırlıdır; `redis-cli --scan --pattern 'rl:*'` ile bakın.
4. ffmpeg CPU'yu tüketiyorsa: `MEDIA_TRANSCODE_WORKERS=1` ya da `MEDIA_TRANSCODE_ENABLED=false` (videolar orijinal olarak sunulur), `up -d backend`.

## 9. Medya / video sorunları (S3)

- **Videolar PENDING'de kalıyor:** `$DC logs backend | grep -i transcode`; `ffmpeg -version` backend imajında var mı (`$DC exec backend ffmpeg -version | head -1`); `scripts/ops/encrypt-existing-post-videos.sh --status` kuyruk sayıları. Bozuk video 3 denemeden sonra `FAILED` olur ve **orijinal** sunulmaya devam eder (kullanıcı etkilenmez).
- **Video oynamıyor / `KEY_UNAVAILABLE`:** `CRYPTO_MASTER_KEYS` içinde videonun `wrapped_dek` önekindeki anahtar `id`'si (`select split_part(wrapped_dek,':',1), count(*) from post_media where encrypted group by 1`) var mı? Eksikse eski anahtarı listeye geri koyun.
- **Disk dolu (`/tmp` tmpfs):** ffmpeg geçici dosyaları; `tmpfs: /tmp:size=2g`; `MEDIA_TRANSCODE_WORKERS` azaltın.
- **CDN:** bkz. DEPLOY.md bölüm 10; imza hataları saat sapmasından olabilir (NTP).

## 10. Geri alma (bozuk dağıtım)

```bash
bash scripts/deploy.sh --rollback        # ÜRETİM (yerelden): önceki sürüm dizini + :previous imajlar
bash scripts/deploy/rollback.sh          # sunucu içinde elle; onaylı (update.sh kaydı: .deploy/previous_ref)
bash scripts/deploy/rollback.sh --ref v1.4.2
```

- `deploy.sh` ve `update.sh` başarısız sağlık kontrolünde **kendiliğinden** geri alır; ikisi de dağıtımdan ÖNCE şifreli yedek alır (başarısızsa dağıtım hiç başlamaz).
- **Flyway geri sarılmaz.** Eklemeli (geriye uyumlu) migration'larda kod geri alınınca çalışır. Veri/şema uyumsuzsa: yedekten geri yükleme (BACKUP_RESTORE).
- Geri alma sonrası: sağlık, giriş, bir mesaj, bir video; olayı kaydedin; hatalı sürümü etiketleyin.

## 11. Olay kaydı şablonu

```
Olay: ____  Önem: S_  Başlangıç: ____  Tespit: ____  Çözüm: ____
Etki: kullanıcılar/özellik/veri       KVKK değerlendirmesi: gerekli/değil (neden)
Kök neden: ____        Yapılanlar (zaman damgalı): ____
Düzeltici/önleyici: ____  Sahip/Tarih: ____
```

## 12. Günlükler

**Tatbikat günlüğü** (yedek geri yükleme, anahtar kurtarma):

| Tarih | Tür | Süre | Bulgu | Yapan |
|---|---|---|---|---|
| | | | | |

**Anahtar emanet doğrulama günlüğü** (T-137 / H-02; değer YAZILMAZ). `CRYPTO_MASTER_KEYS` ve yedek age ÖZEL anahtarı `deploy.sh` tarafından yerelde **iki ayrı dosyaya** yazılır (`.deploy/generated-secrets.txt`, `.deploy/backup-age-private.key`); her biri **farklı** iki bağımsız yere (şifre yöneticisi + çevrimdışı kasa) taşınır ve emanet **fiilen okunarak** doğrulanır. Doğrulama: (a) emanetten anahtarı yeni bir makineye elle aktarın; (b) age için `age -d -i <anahtar> <bir yedeğin db.dump.age>` bir yedeği açsın (`scripts/backup/verify-restore.sh`); (c) `CRYPTO_MASTER_KEYS` için staging'de bu anahtarla bir mesajın şifresi çözülsün. Her emanet/yer için bir satır; yılda en az 1 kez ve her anahtar değişiminde tekrarlayın.

| Tarih | Sır (CRYPTO / age) | Emanet yeri (1 / 2) | "Fiilen okundu" testi (nasıl, sonuç) | Yapan / ikinci kişi |
|---|---|---|---|---|
| | | | | |

**Sır/anahtar değişiklik günlüğü** (değer YAZILMAZ):

| Tarih | Sır | Neden | Yapan |
|---|---|---|---|
| | | | |
