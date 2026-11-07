# Yedekleme Özeti (saatlik, son 3)

Bu belge tek VPS için **yedekleme politikasını ve kararlarını** özetler. Ayrıntılar (anahtar kurulumu, geri yükleme adımları, doğrulama, tatbikat listesi): [BACKUP_RESTORE.md](BACKUP_RESTORE.md). Kurulum: [DEPLOY.md](DEPLOY.md) bölüm 13.

## Politika

| Konu | Değer |
|---|---|
| Sıklık | **Her saat** (`BACKUP_CRON`, varsayılan `5 * * * *`, saat dilimi `Europe/Istanbul`) |
| Saklama | **En yeni 3 yedek** (`BACKUP_KEEP_DAILY=3`; haftalık/aylık kapalı: `BACKUP_KEEP_WEEKLY=0`, `BACKUP_KEEP_MONTHLY=0`) = 3 saatlik pencere |
| Kapsam | PostgreSQL (`pg_dump -Fc`) + **yüklenen tüm dosyalar/fotoğraflar** (`STORAGE_DIR` = `uploads` volume, tar+zstd) |
| Sıra / tutarlılık | Önce veritabanı dökümü, sonra dosyalar (DB'de olup dosyası olmayan satır oluşmaz; tersi yetim dosya olur ve süpürücüler temizler) |
| Biçim | `daily/<YYYYmmddTHHMMSS>/` içinde `db.dump.age`, `uploads.tar.zst.age`, `manifest.json`, `SHA256SUMS`. Yazma `.partial-*` adına yapılır, bitince **atomik `mv`** |
| Rotasyon | **Yalnızca başarılı yedekten sonra**; başarısız yedek hiçbir şeyi silmez. Yalnızca `YYYYmmddTHHMMSS` adlı dizinlere dokunur |
| Çakışma | `flock` ile aynı anda iki yedek çalışmaz |
| Disk | Başlamadan bos alan < (DB + uploads boyutu) ise **yedek alınmaz**, mevcutlar korunur, hata + webhook; bos alan < 2x ise uyarı |
| Uzak kopya | `BACKUP_REMOTE` (rclone: **Google Drive**/S3/SFTP). Boşsa kapalı. **Günde 1 tam yükleme** (03:35) + indirmeden doğrulama + uzak saklama 7 günlük/4 haftalık/6 aylık; Drive kurulumu ve kota hesabı: **[BACKUP_GDRIVE.md](BACKUP_GDRIVE.md)** |
| Haftalık doğrulama | `verify-restore.sh --latest` (pazar 04:30): geçici PostgreSQL'e gerçek geri yükleme + satır sayısı karşılaştırması |

### UYARILAR (okuyun)

1. **Yerel yedek tek başına yedek değildir.** `backups` volume'u uygulamayla aynı VPS diskindedir; disk/VPS kaybı hem canlı veriyi hem 3 yedeği alır. **`BACKUP_REMOTE` ile ikinci bir sunucu/S3 tanımlayın** (farklı sağlayıcı/bölge). Tanımsızsa yedek yalnızca "yanlış silme / bozuk güncelleme"ye karşı korur.
2. **3 saatlik pencere:** bir hata (silinmiş veri, kötü migration) 3 saatten uzun fark edilmezse yerel yedeklerin hepsi hatalı duruma geçmiş olur. Uzak tarafta daha uzun saklama (ör. günlük kopyaları 30 gün; nesne yaşam kuralıyla) önerilir; yerel varsayılan politikayı bu belge istenen şekilde 3'te tutar.
3. **Saatlik RPO = 1 saat** (yedek anındaki hâl). Saat içi veri kaybı kabul edilmiştir.
4. Yedekler kişisel veri içerir (KVKK): silinen hesaplar geri yükleme sonrası yeniden anonimleştirilir (BACKUP_RESTORE.md adım 7).

## Kararlar

**Şifreleme: age genel anahtarı (parola değil).** İstek `BACKUP_ENCRYPTION_KEY` (parola) önermişti; bunun yerine mevcut **age alıcı (public key)** modeli korundu: sunucuda yalnızca genel anahtar (`BACKUP_AGE_RECIPIENT=age1...`) durur, **özel anahtar sunucuda olmaz**. Sunucu ele geçirilse bile yedekler (özellikle uzak kopya) çözülemez; parola modelinde parola sunucuda durmak zorundadır ve bu fayda kaybolur. Şifresiz mod yoktur: `BACKUP_AGE_RECIPIENT` boşsa yedek ve compose reddedilir. Özel (kurtarma) anahtarı çevrimdışı kasada + parola yöneticisinde (>= 2 yer).

**Sır yedeği: `.env.prod` yedeğe KONMAZ.** Yedekte `JWT_SECRET`, `DB_PASSWORD`, `CRYPTO_MASTER_KEYS`, `MAIL_PASSWORD`, FCM anahtarı **yoktur**. Gerekçe: veritabanı + anahtar aynı arşivde olsaydı (özellikle uzak kopyada) yedeği ele geçiren her şeyi açardı; ayrıca mesajlar ve gönderi videoları `CRYPTO_MASTER_KEYS` ile şifrelidir. Sırlar ayrı yerde saklanır: şifre yöneticisi + çevrimdışı kasa ([KEY_MANAGEMENT.md](KEY_MANAGEMENT.md)). **`.env.prod` + `CRYPTO_MASTER_KEYS` kopyanız yoksa yedek geri yüklense bile şifreli mesajlar/videolar kalıcı olarak okunamaz.** Yapılandırma özeti olarak yedeğin `manifest.json` dosyası Flyway sürümü, tablo satır sayıları, dosya sayısı, boyut ve ana makine adını içerir (sır içermez). Kod/compose zaten git'tedir.

**Uzak kopya: rclone (isteğe bağlı), önerilen hedef Google Drive** ([BACKUP_GDRIVE.md](BACKUP_GDRIVE.md)). `BACKUP_REMOTE=gdrive:BU-Kampus-Yedek` gibi; yapılandırma `deploy/rclone/rclone.conf` (gitignored, 0600; OAuth belirteci yenilendiği için dizin **yazılabilir** bağlanır). Yükleme şifreli dosyalar üzerindendir (age zaten uygulanmış; Drive yalnız şifreli veri görür). Saatlik yedekler uzağa gitmez: `remote-sync.sh` günde bir en yeni geçerli yedeği yükler, **indirmeden doğrular** (boyut + hash + `SHA256SUMS`) ve ancak ondan sonra uzak saklamayı uygular. Uzak hata yerel yedeği/rotasyonu **bozmaz** ve yerel yedeği başarısız saymaz: hata `last-success.json` içindeki `remote.lastError`, `backup_remote.prom` ve webhook ile görünür. `BACKUP_REMOTE_SCHEDULE=each` eski "her saat yükle" davranışıdır (önerilmez). Sunucuyu rahatlatmak için `scripts/backup/prune-local-after-remote.sh` (varsayılan kuru çalışma; yalnız uzakta doğrulanmış yerel yedekleri siler).

## Durum dosyaları (gözlemlenebilirlik)

`BACKUP_STATUS_FILE` (compose'ta sabit: `/var/backups/metrics/last-success.json`; backend aynı host dizinini `/backup-status` altında salt okunur bağlar ve `BACKUP_STATUS_FILE=/backup-status/last-success.json` okur, böylece uygulama içi gösterge UNKNOWN kalmaz); başarısızlık dosyası aynı dizinde `last-failure.json`. İkisi de atomik yazılır. Başarıda `last-failure.json` silinir.

```json
{"lastSuccessAt":"2026-10-28T10:52:20Z","time":"2026-10-28T10:52:20Z","file":"20261028T135217","sizeBytes":485280,"durationSec":3,"dbOk":true,"filesOk":true,"local":{"count":3,"bytes":1500000,"oldestAt":"2026-10-28T08:05:00Z"},"remote":{"configured":true,"kind":"drive","name":"gdrive","lastSuccessAt":"2026-10-28T00:40:12Z","lastVerifiedAt":"2026-10-28T00:40:30Z","lastError":null,"bytes":7340032,"count":6},"schedule":{"cron":"5 * * * *","verifyCron":"30 4 * * 0","remoteCron":"35 3 * * *"},"retention":{"localDaily":3,"localWeekly":0,"localMonthly":0,"remoteDaily":7,"remoteWeekly":4,"remoteMonthly":6}}
{"time":"2026-10-28T13:52:26+0300","error":"pg_dump basarisiz...","durationSec":3,"dbOk":false,"filesOk":false}
```

`sizeBytes` = şifreli DB + dosya arşivi toplamı; `file` = yedek dizin adı. Prometheus textfile metrikleri (`backup.prom`) aynen sürer ([OBSERVABILITY.md](OBSERVABILITY.md)); saatlik yedek için `BackupTooOld` eşiği (şu an 36 saat) ~3 saate çekilmelidir (`monitoring/prometheus/alert.rules.yml`).

## Komutlar

```bash
DC="docker compose -p bu -f docker-compose.prod.yml --env-file .env.prod"
# Elle komutlar TEK KULLANICIYLA (postgres, uid 70) çalışır: -u postgres şart (root sahipli 700 dizin saatlik prune'u çökertir).
# Betikler root çağrılsa bile kendilerini postgres'e geçirir, yine de -u postgres kullanın.
$DC exec -u postgres backup /opt/backup/backup.sh --dry-run    # ön kontrol, hiçbir şey yazmaz
$DC exec -u postgres backup /opt/backup/backup.sh              # hemen yedek
$DC exec backup ls -l /var/backups/daily           # en fazla 3 dizin
$DC exec backup cat /var/backups/last-success.json
$DC exec -u postgres backup /opt/backup/verify-restore.sh --latest   # gerçek geri yükleme denemesi (canlıya dokunmaz)
```

Geri yükleme: BACKUP_RESTORE.md bölüm 5 (`restore.sh <yedek> --identity <anahtar> ...`; canlı DB adı bilinçli `--overwrite-live` ister, uygulamayı durdurma adımı bölümde). Kod konumu: `scripts/backup/` (`backup.sh`, `restore.sh`, `verify-restore.sh`, `lib.sh`, `selftest.sh`).
