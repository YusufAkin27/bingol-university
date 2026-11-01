# Yedekleri Google Drive'a taşıma (uzak kopya) — adım adım kurulum

Bu belge, sunucudaki yedeklerin **Google Drive'a** gönderilmesini ve sunucunun rahatlatılmasını anlatır. Genel yedek politikası: [BACKUP.md](BACKUP.md); geri yükleme: [BACKUP_RESTORE.md](BACKUP_RESTORE.md); anahtarlar: [KEY_MANAGEMENT.md](KEY_MANAGEMENT.md). Kod: `scripts/backup/` (`remote-sync.sh`, `remote.sh`, `prune-local-after-remote.sh`, `status-refresh.sh`, `lib.sh`).

> **Gerçek bir Drive hesabına karşı bu depoda DENENMEDİ.** Mantık (yükleme, dogrulama, GFS saklama, yerel azaltma, durum JSON'u, hata yolu) rclone'un yerel `alias` uzağıyla `scripts/backup/selftest-remote.sh` içinde sınandı (51 kontrol). İlk gerçek yüklemeyi bu belgedeki `--dry-run` ve doğrulama adımlarıyla mutlaka izleyin.

## 0. Nasıl çalışır (kısa)

```
her saat :05   ->  yerel yedek (db.dump.age + uploads.tar.zst.age + manifest.json + SHA256SUMS), age ile ŞİFRELİ, sunucuda
her gün 03:35  ->  en yeni geçerli yerel yedek Google Drive'a yüklenir  (.partial-<damga> klasörüne)
                   -> İNDİRMEDEN doğrulanır (boyut + MD5/hash + SHA256SUMS/manifest birebir)
                   -> doğrulanınca <damga> adına çevrilir (uzakta damga adlı klasör = eksiksiz yedek)
                   -> ancak ondan sonra uzak saklama uygulanır (eski klasörler silinir)
                   -> (isteğe bağlı) doğrulanmış kopyası olan eski yerel yedekler azaltılır
başarısızsa    ->  09:35, 15:35, 21:35'te yeniden dener (yalnız son başarı >20 saat eskiyse)
```

- **Drive yalnızca şifreli veri görür.** Yedekler yüklenmeden önce `age` ile şifrelidir (özel anahtar sunucuda yoktur). Ek şifreleme (rclone crypt) gerekmez; **crypt kullanmayın** — crypt hash vermediği için doğrulama yalnızca boyuta düşer (bölüm 9).
- **Saatlik tam yükleme YAPILMAZ.** Her saat tam `uploads` arşivini yüklemek Drive kotasını (15 GB) ve günlük 750 GB yükleme sınırını hızla tüketir. Uzağa **günde bir** tam yedek gider; saatlik yedekler yalnız sunucuda kalır.
- **Sonuç (RPO):** Drive kopyası en kötü durumda **~24 saat** geridir; son saatler yalnızca sunucu diskindedir. Daha sık yükleme isterseniz `BACKUP_REMOTE_CRON`'u artırın (kotayı hesaplayın, bölüm 1).
- Uzak saklama **tek dizinde, kopya oluşturmadan** (GFS): son 7 gün + son 4 hafta + son 6 ay; her hafta/ay için o dönemin **en yeni** yedeği tutulur. Dönemler birbirine biner (bugünün yedeği hem günlük hem haftalık sayılır), bu yüzden Drive'da en çok ~15 klasör bulunur.

## 1. Kota hesabı (başlamadan önce)

Drive'a giden her klasör = DB dökümü + `uploads` arşivi (şifreli, sıkıştırılmış). Tahmini boyut **S** için:

```bash
DC="docker compose -p bu -f docker-compose.prod.yml --env-file .env.prod"
$DC exec backup cat /var/backups/metrics/last-success.json     # "sizeBytes" = bir yedeğin boyutu (bayt)
```

| Ayar | Drive'da en çok klasör |
|---|---|
| varsayılan 7 / 4 / 6 | 7 + 3 + 5 = **15** (+1 yükleme anında) = **~16 x S** |
| 3 / 2 / 3 | 3 + 1 + 2 = 6 (+1) = **~7 x S** |

- **Drive ücretsiz sınırı 15 GB** (Gmail ve Fotoğraflar ile ortak). Örnek: S = 650 KB -> ~10 MB; S = 500 MB (çok fotoğraf) -> ~8 GB.
- `uploads` büyüdükçe S büyür; **her gün tamamı yeniden yüklenir** (artımlı yedek yok). S, 15 GB / 16 = **~900 MB**'ı geçerse saklamayı azaltın (`BACKUP_REMOTE_KEEP_*`) ya da Google One kotası alın.
- Kota dolarsa yükleme **başlamaz** ve hiçbir şey silinmez (`remote.lastError: Drive depolama kotası dolu`). Uyarı alın, saklamayı düşürün.
- Dosyalar Drive'ın **çöp kutusuna gitmez**: uzak silmeler `--drive-use-trash=false` ile kalıcıdır (çöp kutusu da kotadan düşer). Elle sildiğiniz dosyalar çöp kutusuna gider; kotayı gerçekten boşaltmak için çöp kutusunu boşaltın.

## 2. Hangi Google hesabı?

- Mümkünse **kuruma ait, tek bir kişiye bağlı olmayan** bir Google hesabı (ör. `yedek@...`) kullanın; kişisel hesap işten ayrılınca yedek de gider. `bingol.edu.tr` Workspace hesabı kullanılacaksa kuruluşun Drive kotasını ve dış uygulama (OAuth) iznini BT yöneticisine sorun.
- Hesapta **iki adımlı doğrulama** açık olsun. Parola değişse bile rclone'un yenileme belirteci genelde geçerli kalır; hesaba bağlı **uygulama izni iptal edilirse** (bölüm 8) veya hesap kilitlenirse yeniden yetkilendirme gerekir.
- **Servis hesabı (service account) KULLANMAYIN.** Servis hesabının kendi Drive kotası yoktur (0 bayt); dosyayı kendi adına yükleyemez (`storageQuotaExceeded`). Yalnızca Google Workspace'te bir **Paylaşılan Drive (Shared Drive)** içinde, hesabın üye yapıldığı durumda çalışır. Bu kurulumda kişisel/kurumsal hesap + OAuth kullanılır.

## 3. (Önerilir) Kendi OAuth istemci kimliğiniz (client_id)

rclone'un yerleşik `client_id`'si **tüm rclone kullanıcılarıyla paylaşılır**; yoğun saatlerde `403 rateLimitExceeded` / yavaşlama olabilir ve Google bu kimliğe kısıt koyabilir. Kendi kimliğinizi oluşturun (bir kez, ~10 dk):

1. <https://console.cloud.google.com> -> yeni proje (ör. `bu-kampus-yedek`).
2. **APIs & Services -> Library -> Google Drive API -> Enable**.
3. **OAuth consent screen**: User type **External**, uygulama adı, destek e-postası. **Scopes** adımında `.../auth/drive.file` ekleyin.
4. **Publishing status'u "In production" yapın.** ⚠ Durum **"Testing"** kalırsa Google, bu uygulamanın **yenileme belirtecini 7 günde geçersiz kılar**; yedek bir hafta sonra `invalid_grant` ile durur. (`drive.file` hassas olmayan kapsam olarak sınıflandırılır, üretime almak için Google doğrulaması beklemez; yine de Google'ın güncel kurallarını konsolda kontrol edin. "Unverified app" uyarısı kendi hesabınızla yetkilendirirken çıkarsa *Advanced -> Go to ... (unsafe)* ile devam edilir.)
5. **Credentials -> Create credentials -> OAuth client ID -> Application type: Desktop app**. Çıkan **Client ID** ve **Client secret**'ı not edin (sırdır; yalnız `rclone.conf` ve parola yöneticinizde durur).

Kendi `client_id` kullanmak istemezseniz bu adımı atlayın; aşağıda `client_id`/`client_secret` satırlarını boş bırakırsınız (rclone yerleşik kimliği kullanır; hız sınırı riskini kabul edersiniz).

## 4. Belirteci kendi bilgisayarınızda alın

Sunucuda tarayıcı yoktur; yetkilendirme **kendi bilgisayarınızda** yapılır ve yalnızca sonucu (belirteç) sunucuya taşınır.

1. rclone kurun: <https://rclone.org/downloads/> (sürüm >= 1.66 önerilir).
2. Çalıştırın (kendi kimliğinizi kullanıyorsanız ikisini de verin):

```bash
rclone authorize "drive" --drive-client-id "<CLIENT_ID>" --drive-client-secret "<CLIENT_SECRET>" --drive-scope drive.file
```

3. Tarayıcı açılır; yedek için ayırdığınız **Google hesabıyla** giriş yapıp izin verin. Terminal şuna benzer bir çıktı verir:

```
Paste the following into your remote machine --->
{"access_token":"ya29....","token_type":"Bearer","refresh_token":"1//0g....","expiry":"2026-11-01T12:00:00.000000+03:00"}
<---End paste
```

4. Bu satırı bir sonraki adımdaki `token =` değeri olarak kullanın. **Bu JSON bir sırdır** (yenileme belirteci hesabınızdaki rclone'un oluşturduğu dosyalara erişim verir): sohbet/e-posta ile paylaşmayın, depoya koymayın.

> `scope = drive.file` **yalnızca rclone'un oluşturduğu dosya ve klasörleri** görür. Hesabınızdaki diğer dosyalara erişemez (en az yetki). Sonuç: yedek klasörünü **Drive arayüzünden elle oluşturmayın**; rclone kendisi oluşturur (ilk `remote-sync.sh` çalışmasında `rclone mkdir`). Elle oluşturulmuş klasör bu kapsamda *görünmez* (boş liste / 404). Klasörü Drive'da görür, taşıyabilir ve yeniden adlandırabilirsiniz, ama dosya içeriğini oraya elle eklemeyin.

## 5. Sunucuya `rclone.conf` yerleştirme

Sunucuda depo dizininde (`/srv/bu` gibi) `deploy/rclone/rclone.conf` dosyasını oluşturun:

```ini
[gdrive]
type = drive
client_id = <CLIENT_ID>
client_secret = <CLIENT_SECRET>
scope = drive.file
token = {"access_token":"ya29....","token_type":"Bearer","refresh_token":"1//0g....","expiry":"2026-11-01T12:00:00.000000+03:00"}
```

```bash
# bilgisayarınızdan (dosyayı yazdıktan sonra) — ya da sunucuda doğrudan editörle oluşturun
scp rclone.conf sunucu:/srv/bu/deploy/rclone/rclone.conf
ssh sunucu 'chmod 600 /srv/bu/deploy/rclone/rclone.conf'
```

- **Dosya izni 0600.** `backup` konteyneri açılışta dosyayı `postgres` (uid 70) sahipliğine alıp 0600 yapar; başka kullanıcı okuyamaz. **Dosya git'e girmez** (`.gitignore`: `deploy/rclone/rclone.conf`); `git status` ile doğrulayın. Bir kopyasını parola yöneticinizde de saklayın (sunucu kaybında yeniden yetkilendirmek zorunda kalmazsınız; bu zorunlu değildir, `rclone authorize` ile yeniden alınabilir).
- **Neden yazılabilir bağlanıyor?** Google'ın erişim belirteci ~1 saatte biter; rclone yenisini aldığında `rclone.conf`'a **geri yazar**. Dizin salt okunur (`:ro`) bağlıysa her çalışmada `Failed to save new token` hatası oluşur (rclone belleğindeki belirteçle devam etse de, yenileme belirteci döndürülürse kaybolur). Bu yüzden `docker-compose.prod.yml` artık `./deploy/rclone:/config/rclone` dizinini **yazılabilir** bağlar. Yenilenen belirteç dosyada kalır, konteyner yeniden başlasa bile korunur. Güvenlik: yalnızca bu tek dizin (başka sunucu yolu değil) bağlıdır; dosya 0600; konteynerde `cap_drop: ALL`.
- Yapılandırmayı parolayla şifrelemek isterseniz `rclone config` ile parola koyup `.env.prod`'a `RCLONE_CONFIG_PASS=...` yazın.

## 6. `.env.prod` ve yeniden başlatma

```bash
# .env.prod
BACKUP_REMOTE=gdrive:BU-Kampus-Yedek        # rclone uzak adı : Drive'daki klasör adı (rclone oluşturur)
# isteğe bağlı (varsayılanlar aşağıdadır)
# BACKUP_REMOTE_KEEP_DAILY=7
# BACKUP_REMOTE_KEEP_WEEKLY=4
# BACKUP_REMOTE_KEEP_MONTHLY=6
# BACKUP_REMOTE_CRON=35 3 * * *             # günlük yükleme saati (Europe/Istanbul)
# BACKUP_REMOTE_BWLIMIT=8M                  # bant sınırı (bos = sinirsiz)
```

```bash
DC="docker compose -p bu -f docker-compose.prod.yml --env-file .env.prod"
$DC up -d --build backup backend      # backup: yeni imaj (jq + yeni betikler); backend: BACKUP_REMOTE uyarısını kaldırır
```

`docker compose ... up` ortam değişkenleri değiştiği için `backup` ve `backend` konteynerlerini yeniden oluşturur; kısa kesinti yalnız bu ikisindedir.

## 7. İlk deneme ve doğrulama

```bash
# 1) Drive'a erişim (tarayıcıda alınan belirteç geçerli mi?)
$DC exec -u postgres backup rclone lsd gdrive:
$DC exec -u postgres backup rclone about gdrive:               # toplam/kullanılan/boş alan

# 2) Kuru çalışma: ne yükleneceğini, boş alanı ve yükleme sonrası silinecek eski klasörleri yazar; hiçbir şey değiştirmez
$DC exec -u postgres backup /opt/backup/remote-sync.sh --dry-run

# 3) Gerçek ilk yükleme (boyuta göre dakikalar/saatler sürebilir); günlüğü izleyin
$DC exec -u postgres backup /opt/backup/remote-sync.sh
$DC logs --tail 50 backup

# 4) Drive'da ne var?
$DC exec -u postgres backup rclone lsf gdrive:BU-Kampus-Yedek --dirs-only
$DC exec -u postgres backup rclone size gdrive:BU-Kampus-Yedek
```

Başarılı çıktıda `UZAK KOPYA TAMAM ve dogrulandi: <damga>` görülür. Durumu görün:

```bash
$DC exec backup cat /var/backups/metrics/last-success.json
# "remote": {"configured":true,"kind":"drive","name":"gdrive","lastSuccessAt":"...Z","lastVerifiedAt":"...Z","lastError":null,"bytes":...,"count":1}
```

Aynı bilgiyi yönetim panelinde **Sistem -> Yedekleme** sayfası gösterir (`GET /api/admin/system/backup`, izin `system.read`).

**Doğrulama nasıl yapılır (indirmeden):** (a) yerel ve uzak dosya sayısı + toplam bayt eşit; (b) `rclone check --one-way` (Drive MD5'ini yerel MD5 ile karşılaştırır, veri indirmez); (c) `SHA256SUMS` ve `manifest.json` uzakta birebir aynı. Üçü geçmeden klasör yayınlanmaz ve hiçbir eski yedek silinmez. Daha sıkı (ama yükleme kadar trafik yapan) doğrulama: `.env.prod`'a `BACKUP_REMOTE_VERIFY_DOWNLOAD=1`.

**Zorunlu: uzaktan geri yükleme provası** — bölüm 10'daki adımlarla başka bir bilgisayarda bir kez deneyin. Denenmemiş uzak kopya, kopya sayılmaz.

## 8. Sunucudaki yerel yedekleri azaltma (disk rahatlasın)

**Önce** en az bir kez: yükleme `UZAK KOPYA TAMAM` demeli, panelde `remote.lastVerifiedAt` dolu olmalı ve bölüm 10'daki geri yükleme provası geçmeli.

İki kademeli, güvenli yol:

1. **Yerel saklamayı düşürün** (`.env.prod`; sunucudaki saatlik yedek penceresi): 

```bash
BACKUP_KEEP_DAILY=3        # son 3 saatlik yedek (3 saatlik pencere)
BACKUP_KEEP_WEEKLY=0       # haftalık/aylık yerel kopya yok; bunlar artık Drive'da
BACKUP_KEEP_MONTHLY=0
$DC up -d backup           # her saatlik yedekten sonra fazlası kendiliğinden silinir
```

2. **Tek seferlik / otomatik temizlik — yalnız uzakta doğrulanmışsa sil.** Betik, bir yerel yedeği ancak Drive'daki kopyası `rclone check` + boyut + `SHA256SUMS` ile doğrulanırsa siler; her katmanda (daily/weekly/monthly) en yeni N yedek (varsayılan 2) yerelde kalır; yedek dizini dışına çıkmaz, sembolik bağları izlemez:

```bash
# Varsayılan KURU ÇALIŞMA: ne silineceğini listeler, hiçbir şey silmez
$DC exec -u postgres backup /opt/backup/prune-local-after-remote.sh --keep 2
# Çıktıyı okuyup uygunsa:
$DC exec -u postgres backup /opt/backup/prune-local-after-remote.sh --keep 2 --apply
# Otomatik (her günlük yüklemeden sonra): .env.prod -> BACKUP_LOCAL_KEEP_WHEN_REMOTE_OK=2
```

Betik şunları **silmez**: uzakta kopyası olmayan (saatlik, günlük yüklemeye girmeyen) yedekleri, uzak kopyası doğrulanamayanları, en yeni N'i. Bu nedenle disk kazancının asıl kaynağı yukarıdaki 1. adımdır; 2. adım Drive'a giden ve artık yerelde gereksiz kalan yedekleri toplar.

> **Sunucudaki tüm yedekleri silmeyin.** Drive günlüktür; sunucuda en az birkaç saatlik yedek durmalı (yanlış silme/bozuk güncelleme için hızlı geri dönüş) ve en yeni yedek her zaman yerelde kalmalıdır. Betik ve `BACKUP_LOCAL_KEEP_WHEN_REMOTE_OK` bu yüzden en az 1 yedeği (varsayılan 2) korur.

## 9. Ayarlar (özet)

| Değişken | Varsayılan | Anlam |
|---|---|---|
| `BACKUP_REMOTE` | boş | `rcloneUzakAdı:KlasörAdı`; boşsa uzak kopya kapalı |
| `BACKUP_REMOTE_SCHEDULE` | `daily` | `each` = her yerel yedeği yükle (eski davranış; Drive için önerilmez) |
| `BACKUP_REMOTE_CRON` / `_RETRY_CRON` | `35 3 * * *` / `35 9,15,21 * * *` | günlük yükleme / başarısızsa yeniden deneme (yalnız son başarı >20 sa eskiyse) |
| `BACKUP_REMOTE_KEEP_DAILY/WEEKLY/MONTHLY` | 7 / 4 / 6 | uzak saklama (GFS). 0 = o katman kapalı |
| `BACKUP_REMOTE_MAX_DELETE` | 20 | bir çalışmada en çok silinecek uzak klasör (hata/saat kayması koruması; en eskiden başlar) |
| `BACKUP_LOCAL_KEEP_WHEN_REMOTE_OK` | boş (kapalı) | N: uzakta doğrulananlar için katman başına yerelde en yeni N kalır |
| `BACKUP_RCLONE_DRIVE_CHUNK` | `64M` | Drive yükleme parçası (bellek ~ parça x 1 aktarım; konteyner 1 GB). Büyük parça = daha hızlı, kesintide daha çok tekrar |
| `BACKUP_RCLONE_TIMEOUT` | `5m` | rclone boşta zaman aşımı (tek bir G/Ç beklemesi) |
| `BACKUP_REMOTE_BWLIMIT` | boş | bant sınırı (`8M` ya da `08:00,2M 23:00,off`) |
| `BACKUP_REMOTE_VERIFY` / `_VERIFY_DOWNLOAD` | `hash` / `0` | `size` = yalnız boyut; `VERIFY_DOWNLOAD=1` = indirerek tam karşılaştırma |

Kodda sabit güvenli varsayılanlar: `--transfers 1`, `--checkers 2`, `--retries 3`, `--low-level-retries 10`, `--contimeout 60s`, `--drive-stop-on-upload-limit` (Drive'ın 750 GB/gün yükleme sınırında boşuna denemez), tek yükleme için ~4 saat üst süre (`BACKUP_REMOTE_MAX_SECONDS`).

**Kısmi yükleme temizliği:** yükleme `.partial-<damga>` klasörüne yapılır, doğrulanınca yeniden adlandırılır. Yarım kalmış bir yükleme asla damga adı almaz; bir sonraki çalışma aynı damgayı devam ettirir, **farklı** damgalı eski `.partial-*` klasörlerini siler. Yerelde `.remote-stage-*` (sabit bağlı geçici kopya, ek disk kullanmaz) çalışma sonunda silinir.

**crypt notu:** rclone `crypt` uzakları hash vermez (`could not be checked`); doğrulama yalnız boyut + `SHA256SUMS`/`manifest.json` içeriğine iner. Yedekler zaten age ile şifreli olduğundan crypt gereksizdir; kullanıyorsanız `BACKUP_REMOTE_VERIFY_DOWNLOAD=1` açın.

## 10. Geri yükleme: Drive'dan indirme + age anahtarı

Felaket senaryosu (sunucu gitti): yeni sunucu + **rclone yapılandırması** (`rclone.conf` kopyanız ya da bölüm 4'ü tekrarlayarak yeni belirteç) + **age ÖZEL anahtarı** (çevrimdışı kasa/parola yöneticisi; olmadan yedek açılamaz) + **`.env.prod` ve `CRYPTO_MASTER_KEYS`** ([BACKUP.md](BACKUP.md) sır notu).

```bash
rclone lsf gdrive:BU-Kampus-Yedek --dirs-only                       # damgalar: 20261101T033500/ ...
mkdir restore-in
rclone copy gdrive:BU-Kampus-Yedek/<DAMGA> ./restore-in/ --progress  # 4 dosya: db.dump.age, uploads.tar.zst.age, manifest.json, SHA256SUMS
(cd restore-in && sha256sum -c SHA256SUMS)                           # hepsi OK olmalı
# sonra BACKUP_RESTORE.md bölüm 5 / 10.6: restore.sh ./restore-in --identity kurtarma.age.key ...
age -d -i kurtarma.age.key restore-in/db.dump.age | pg_restore --list | head   # hızlı: şifre çözülüyor mu?
```

Prova için `./restore-in` klasörünü `verify-restore.sh` ile de denetleyebilirsiniz (`verify-restore.sh ./restore-in --identity <anahtar>`). Drive arayüzünden de klasörü indirebilirsiniz (zip); içeriği aynıdır.

## 11. Sorun giderme

Hata metni panelde `remote.lastError` olarak kısa ve sırsız görünür; ayrıntı `docker compose logs backup`.

| Belirti | Neden | Çözüm |
|---|---|---|
| `invalid_grant` / "Google yetkisi geçersiz" | (1) OAuth uygulaması **Testing** modunda (7 gün); (2) <https://myaccount.google.com/permissions> üzerinden erişim kaldırıldı; (3) belirteç 6 ay kullanılmadı; (4) aynı client için hesap başına 100'den fazla belirteç üretildi (en eskisi iptal olur); (5) hesap şifresi/güvenlik olayı | Bölüm 3-4'ü tekrarlayın (uygulama "In production" olsun) ve yeni `token` ile `rclone.conf`'u güncelleyin; `docker compose restart backup` gerekmez, sonraki çalışma alır |
| `Failed to save new token in config file` | `deploy/rclone` salt okunur bağlı / sahiplik yanlış | Compose'ta `:ro` olmamalı (bölüm 5); `docker compose up -d backup` (entrypoint sahipliği düzeltir) |
| `403 rateLimitExceeded` / `userRateLimitExceeded` | rclone'un paylaşılan yerleşik `client_id`'si | Bölüm 3: kendi `client_id`; geçiciyse sonraki deneme düzelir |
| "Drive depolama kotası dolu" (`storageQuotaExceeded`) | 15 GB doldu / servis hesabı | `BACKUP_REMOTE_KEEP_*` düşürün, Drive'ın çöp kutusunu boşaltın, kotayı artırın; servis hesabı kullanmayın (bölüm 2) |
| "Drive günlük yükleme sınırı" (750 GB/gün) | Çok büyük/çok sık yükleme | Yükleme sıklığını azaltın; ertesi gün devam eder |
| `directory not found` / klasör boş görünüyor | Klasör Drive arayüzünden elle açıldı (`drive.file` göremez) | Elle açılan klasörü silin; `BACKUP_REMOTE` yeni adı kullansın, rclone oluştursun |
| Yükleme çok yavaş / zaman aşımı | Bant genişliği, çok küçük `chunk` | `BACKUP_RCLONE_DRIVE_CHUNK=128M` (bellek!), `BACKUP_RCLONE_TIMEOUT=10m`, gece saati |
| "uzak kopya boyutu/dosya sayisi farkli" | Yükleme yarım kaldı ya da Drive dosyayı geç gösterdi | Kendiliğinden yeniden yüklenir (yeniden deneme zamanlayıcısı); sürerse logu paylaşın |
| Uyarı: "rclone uzak adi rclone.conf icinde yok" | `BACKUP_REMOTE`'taki ad `rclone.conf` bölüm adıyla eşleşmiyor | `[gdrive]` ile `gdrive:...` aynı olmalı |

**Güvenlik özeti:** Drive'a yalnızca age ile şifreli veri gider; `rclone.conf` (yenileme belirteci) bir sırdır ve yalnız rclone'un oluşturduğu dosyalara erişir; panel ve durum dosyası yalnız rclone **uzak adını** gösterir (hedef yolu/belirteç asla). Sunucu ele geçirilirse saldırgan Drive'daki yedekleri **silebilir** (belirteç silme yetkisi verir): yedek klasörünün bir kopyasını ayrı bir yerde (ör. aylık elle indirme) tutmak ve Drive hesabında sürüm geçmişini açık tutmak iyi bir ek önlemdir. Saklama süresi uzak tarafta ≤ 365 gün olmalıdır (varsayılan: 6 aylık katman) — [BACKUP_RESTORE.md](BACKUP_RESTORE.md) bölüm 2.

## 12. İzleme

- Panel: **Sistem -> Yedekleme** (`GET /api/admin/system/backup`): yerel sayı/boyut/en eski, uzak son başarı/doğrulama/hata/boyut/sayı, zamanlama ve saklama.
- Prometheus (`backup_remote.prom`): `backup_remote_configured`, `backup_remote_last_success_timestamp_seconds`, `backup_remote_last_verified_timestamp_seconds`, `backup_remote_last_status`, `backup_remote_bytes`, `backup_remote_count`, `backup_local_count`, `backup_local_bytes`, `backup_local_oldest_timestamp_seconds`. Uyarılar: `BackupRemoteStale` (36 saat), `BackupRemoteLastFailed` (12 saat) — `monitoring/prometheus/alert.rules.yml`.
- Webhook (`BACKUP_WEBHOOK_URL`): uzak yükleme başarısız olursa `UZAK YEDEK BASARISIZ` bildirimi gider. **Davranış değişikliği:** uzak yükleme hatası artık *yerel* yedeği başarısız saymaz (`last-failure.json` yazılmaz); hata `remote.lastError` ve yukarıdaki metrik/bildirimle görünür.
- Testler: `bash scripts/backup/selftest-remote.sh` (Docker: bkz. dosya başı; backup imajında çalıştırın), `scripts/backup/selftest-prune.sh`.
