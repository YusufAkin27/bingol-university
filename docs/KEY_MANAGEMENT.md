# Anahtar ve Sır Yönetimi

Bu belge üretimdeki sırların üretimini, saklanmasını, rotasyonunu ve kaybı/sızıntısı durumunu anlatır. Mesaj şifreleme tasarımı: [ENCRYPTION.md](ENCRYPTION.md). Yedekler: [BACKUP_RESTORE.md](BACKUP_RESTORE.md). Olay müdahalesi: [RUNBOOK.md](RUNBOOK.md).

## 1. Sır envanteri

| Sır | Ne korur | Kaybolursa | Sızarsa | Rotasyon |
|---|---|---|---|---|
| **`CRYPTO_MASTER_KEYS`** | Sohbet mesajları, sohbet görselleri/videoları, **gönderi videoları** (DEK'leri sarar) | **Şifreli verinin kalıcı kaybı** (kurtarma yok) | Veritabanı/dosya yedeğine erişen herkes şifreli veriyi çözer | Bölüm 3 (ekle-geç-sakla) |
| `JWT_SECRET` | Access JWT imzası, imzalı medya URL'leri (ayrı anahtar yoksa) | Tüm oturumlar düşer (kullanıcılar yeniden giriş yapar); veri kaybı yok | Saldırgan geçerli token üretebilir | Bölüm 5 |
| `DEVICE_HMAC_KEY` | Cihaz kimliği özetleri (cihaz engelleri) | Mevcut cihaz engelleri eşleşmez | Cihaz kimliği özetleri tahmin edilebilir | Bölüm 5 |
| `DB_PASSWORD` | PostgreSQL | Sunucudan yeniden ayarlanır | Veritabanı erişimi (ağ dışına kapalı: yalnız konteyner ağı) | `ALTER USER` + `.env.prod` |
| `ADMIN_PASSWORD` | `/api/admin/**` Basic auth yedek yolu | Yeniden ayarlanır | Yönetici API'si | Yeniden ayarla + yeniden başlat |
| `FCM_CREDENTIALS_JSON` | Push gönderimi (Firebase servis hesabı) | Firebase konsolundan yeni anahtar | Üçüncü kişi push gönderebilir | Bölüm 6 |
| `MAIL_PASSWORD` | SMTP | Sağlayıcıdan yenile | Alan adından e-posta gönderilebilir | Sağlayıcıdan yenile |
| age **kurtarma özel anahtarı** | Yedeklerin çözülmesi | Yedekler **okunamaz** (canlı veri sağlam kalır, ama felakette kurtarma yok) | Sızmış anahtar + yedek dosyası = tüm veri | Bölüm 7 |
| `deploy/backup-keys/verify.key` | Haftalık otomatik doğrulama | Yenisi üretilir | Sunucudaki yedekler çözülebilir (canlı DB zaten orada) | Bölüm 7 |
| `ACME` hesabı / `caddy_data` volume | TLS sertifikaları | Caddy yeniden alır (Let's Encrypt sınırlarına dikkat) | - | - |

Sırlar **hiçbir zaman** git'e, imaja, loga, hata mesajına, e-postaya, sohbete yazılmaz. Üretimde dosya `.env.prod` (izin **600**, sahibi dağıtım kullanıcısı); `.gitignore` bunu kapsar.

## 2. `CRYPTO_MASTER_KEYS` üretimi ve biçimi

Biçim: `id:base64(32 bayt)`; birden çok anahtar virgülle (boşluk/noktalı virgül de olur). `id`: `[A-Za-z0-9_.-]{1,32}`.

```bash
# Tek anahtar
echo "k1:$(openssl rand -base64 32)"
# Çıktıyı doğrudan .env.prod'a: CRYPTO_MASTER_KEYS=k1:....   CRYPTO_ACTIVE_KEY_ID=k1
# (otomatik: bash scripts/ops/gen-secrets.sh  -> .env.prod, izin 600, ekrana sır yazmaz)
```

- `CRYPTO_ACTIVE_KEY_ID`: **yeni** DEK'leri saran anahtar. Boşsa listedeki **son** anahtar.
- `CRYPTO_REQUIRE_KEYS=true`: anahtar yokken uygulama **açılmaz**. Prod profilinde zaten zorunludur: `KeyProvider` (`ConfiguredKeyProvider`) `prod` profilinde boş `CRYPTO_MASTER_KEYS` ile **açılışı reddeder** (`KeyProviderTest.missingKeyFailsStartupInProductionButWarnsInDev`); `docker-compose.prod.yml` değişkeni `:?` ile ayrıca zorunlu kılar (boşsa `docker compose` bile başlamaz). Geliştirme anahtarı (`dev`) üretimde asla kullanılamaz.
- Anahtar **tam 32 bayt** olmalıdır; kısa/uzun anahtarlar açılışta reddedilir.
- Büyük önem: yeni bir ortam (staging) **farklı** anahtar kullanır; üretim anahtarı staging'e kopyalanmaz.

### Hangi veri bu anahtarla korunur?

- Sohbet mesajları ve ekleri: konuşma başına DEK (`conversation_key.wrapped_key`), DEK'ler ana anahtarla sarılı.
- **Gönderi videoları** (`post_media`): dosya başına rastgele DEK, ana anahtarla sarılı (`post_media.wrapped_dek`, biçim `<anahtarId>:<base64url>`); diskteki dosya parçalı AES-256-GCM (`BUP1`). Sarma AAD'si dosya yolunu içerir: bir satırın `wrapped_dek` değeri başka satıra kopyalanamaz. Eski (düz) videolar `MEDIA_ENCRYPT_EXISTING=true` ile arka planda şifrelenir ([MEDIA_PIPELINE.md](MEDIA_PIPELINE.md)).

## 3. Çoklu anahtar ve rotasyon

Rotasyon **ekle → etkinleştir → eskisini SAKLA** sırasıyla yapılır; eski anahtar listeden **silinmez** (eski veri onunla sarılıdır).

1. Yeni anahtar üretin: `echo "k2:$(openssl rand -base64 32)"`.
2. `.env.prod`'da listeye **ekleyin**: `CRYPTO_MASTER_KEYS=k1:...,k2:...` ve **önce yedekleyin** (bölüm 4).
3. `CRYPTO_ACTIVE_KEY_ID=k2` yapın, backend'i yeniden başlatın (`update.sh` ya da `docker compose up -d backend`). Yeni konuşmalar/gönderi videoları artık `k2` ile sarılır.
4. Mevcut konuşma DEK'lerini yeni anahtara taşımak için `TOKEN=<admin> scripts/crypto-rotate.sh rewrap` (= `POST /api/admin/crypto/rewrap`, ayrıntı ENCRYPTION.md) çalıştırılır. **Gönderi videosu DEK'leri bu uçla yeniden sarılmaz** (dosya başına, `post_media.wrapped_dek`): eski sarma `k1` ile kalır ve **`k1` listede kaldığı sürece** okunur. Bu yüzden `k1` pratikte silinmez.
5. **Eski anahtarı silme:** yalnızca `k1` ile sarılı hiçbir kayıt kalmadığı doğrulandıktan sonra (ve eski yedeklerin geri yüklenmesi gerekmeyecekse; yedekler `k1` ile sarılı DEK içerir!) kaldırılabilir. Varsayılan politika: **eski anahtarları süresiz tutun** (tek satırlık maliyet).
6. Rotasyon takvimi: yılda bir ya da personel değişimi/şüphe durumunda. Tarih ve anahtar `id`'si şifre yöneticisi notuna yazılır (anahtar değeri değil kasaya).

> Anahtarı değiştirip `id`'yi aynı bırakmak **yasaktır**: aynı `id` ile farklı anahtar, mevcut DEK'lerin çözülememesine yol açar. Her yeni anahtar yeni `id` alır.

## 4. Anahtarın yedeklenmesi (zorunlu, en az iki ayrı yer)

`CRYPTO_MASTER_KEYS` ve bütün `.env.prod` **veritabanı yedeğinin içinde değildir**; ayrıca saklanmalıdır:

1. **Şifre yöneticisi** (ekip kasası; erişim kaydı olan, en az 2 yönetici). Not: anahtar listesi + `CRYPTO_ACTIVE_KEY_ID` + son değişiklik tarihi.
2. **Çevrimdışı kasa:** yazdırılmış (kâğıt) ya da şifreli USB; fiziksel kasa/banka kasası. **Sunucudan ve bulut hesabından bağımsız** olmalı.
3. **Önerilen: Shamir bölme** (`ssss`), tek kişiye bağımlılığı ve tek parça sızmasını önler:
   ```bash
   # 3 parçadan 2'si birleşince açılır (3 farklı yönetici/konum)
   echo "k1:BASE64ANAHTAR" | ssss-split -t 2 -n 3 -w bukampus-k1
   # Kurtarma: ssss-combine -t 2   (parçalardan ikisini girin)
   ```
   Her parça ayrı kişiye/konuma. Parçaları ve kimde olduğunu bir tabloya yazın (kişi değişince yeniden bölün).
4. **Doğrulama:** her yedek tatbikatında (yılda 2) kasadaki kopyanın **fiilen** okunduğu ve sunucudaki değerle aynı olduğu kontrol edilir (BACKUP_RESTORE.md kontrol listesi). Hiç denenmemiş yedek anahtar, yedek değildir.
5. Aynı mantık age kurtarma özel anahtarı için de geçerlidir (ayrı ayrı iki konumda).

## 5. `JWT_SECRET` ve `DEVICE_HMAC_KEY` rotasyonu

- **`JWT_SECRET`** (>= 32 karakter, `dev-only` içeremez, `openssl rand -base64 48`): değişince tüm access token'lar geçersizleşir (en çok 15 dk), kullanıcılar yeniden giriş yapar; refresh token'lar Redis'te opak ve hash'li olduğundan etkilenmez ama JWT doğrulaması başarısız olacağı için istemciler yenilemeyi dener. İmzalı medya URL'leri (`MediaUrlSigner`, ayrı anahtar yoksa) ve CDN imzalı URL'leri de geçersiz olur (kısa ömürlüdür, kendiliğinden yenilenir). Planlı rotasyon düşük trafikte yapılır; sızıntıda **hemen**.
- **`DEVICE_HMAC_KEY`** (>= 32 karakter): değişirse mevcut **cihaz engelleri** (`DEVICE` türü) ve `user_device_log` özetleri yeni özetlerle eşleşmez; engelli cihazlar yeniden girebilir. Bu yüzden **ayrı, kalıcı** tutulur ve yedeklenir; rotasyon yalnızca sızıntıda ve engel listesi yeniden üretilebiliyorsa yapılır. Boşsa `JWT_SECRET`'ten türetilir (JWT rotasyonu cihaz engellerini de bozar; ayrı anahtar tavsiye edilir).
- Tüm oturumları kapatmak için ayrıca `POST /api/auth/logout-all` kullanıcı bazlı; toplu iptal için JWT rotasyonu.

## 6. Diğer sırlar

- **FCM (`FCM_CREDENTIALS_JSON`)**: Firebase konsolu > Proje ayarları > Hizmet hesapları > yeni özel anahtar oluştur; ham JSON ya da base64 **tek satır**. Eski anahtarı konsoldan silin. Hiçbir zaman repoya/imaja girmez. Rotasyon: yeni anahtarı ekle, backend'i yeniden başlat, push gönderimini doğrula, eskiyi iptal et. (bkz. [PUSH_SETUP.md](PUSH_SETUP.md))
- **Yönetici şifreleri**: `ADMIN_PASSWORD` >= 12 karakter; yönetici hesapları (`ADMIN_EMAILS`) güçlü ve benzersiz şifre + mümkünse parola yöneticisi. Personel ayrılınca: `ADMIN_EMAILS`'ten çıkar, rolü düşür, `ADMIN_PASSWORD`'ü değiştir, kişinin bildiği tüm paylaşılan sırları rotasyona al.
- **SMTP / Sentry DSN / webhook URL'si**: sağlayıcıdan yenilenir; webhook URL'si de bir sırdır (kanala yazma yetkisi verir).
- **SSH**: yalnız anahtar girişi (`bootstrap-server.sh` çıktısındaki öneri); ayrılan personelin anahtarı `authorized_keys`'ten silinir.

## 7. age (yedek) anahtarlarının rotasyonu

1. `age-keygen` ile yeni çift üret; yeni **genel** anahtarı `BACKUP_AGE_RECIPIENT` yap, servisi yeniden başlat (`up -d backup`).
2. Yeni yedekler yeni anahtarla şifrelenir; **eski yedekler eski özel anahtarla açılır**, eski özel anahtarı saklama süresi (12 ay) boyunca tutun.
3. Doğrulama anahtarı (`verify.key`) sızdıysa/değiştirilecekse: yenisini üretip `BACKUP_VERIFY_AGE_RECIPIENT` ve `deploy/backup-keys/verify.key`'i güncelleyin; eski yedekler için doğrulama o yedekler yerine yeni yedeklerde yapılır.

## 8. Kaybın sonuçları

| Kayıp | Etki | Ne yapılır |
|---|---|---|
| `CRYPTO_MASTER_KEYS` tamamen (hiçbir kopya yok) | Tüm şifreli mesajlar, sohbet medyası ve gönderi videoları **kalıcı olarak okunamaz**. Hesaplar, gönderi metinleri, düz resimler (şifresiz alanlar) çalışır. | RUNBOOK "Şifreleme anahtarı kaybı": yeni anahtar üretilir (yeni id), uygulama yeni verilerle devam eder; eski şifreli veri silinir/arşivlenir; kullanıcılara duyuru; KVKK etkisi değerlendirilir. **Bu yüzden iki ayrı güvenli konum zorunludur.** |
| Yalnız bir kopya (diğeri sağlam) | Etki yok | Kaybolan kopyayı hemen yeniden oluşturun (yeni parçalar/kopya) |
| Aktif olmayan eski anahtar | O anahtarla sarılı DEK'lerin verisi okunamaz (rotasyon sonrası `k1` düşürüldüyse) | Eski anahtarı kasadan geri koyun; bu yüzden eski anahtarlar silinmez |
| age kurtarma anahtarı | Yedekler çözülemez | Canlı veriyi hemen yeni anahtarla yeniden yedekleyin; eski yedekler kayıp sayılır |

## 9. Sızıntıda yapılacaklar

Genel: **tespit zamanını kaydet**, etkilenen sırrı hemen rotasyona al, erişim günlüklerini incele, kapsamı belirle. Kişisel veri ihlali şüphesinde **KVKK 72 saat** bildirim sürecini [docs/legal/internal/03_veri_ihlali_mudahale_plani.md](legal/internal/03_veri_ihlali_mudahale_plani.md) ile başlatın.

- **`CRYPTO_MASTER_KEYS` sızdı:** yeni anahtar ekle + aktif yap (bölüm 3); sızan anahtarla sarılı DEK'leri **yeniden sar** (konuşma DEK'leri: rewrap ucu); asıl risk, saldırganın **veri + anahtar** ikilisini birlikte ele geçirmiş olmasıdır: veritabanı/dosya yedeklerinin de sızıp sızmadığını belirleyin. Sızan anahtarla sarılı eski yedekler çözülebilir kabul edilir (veri ihlali değerlendirmesi). Gönderi videoları için (dosya başına DEK, yeniden sarma ucu yok): sızan anahtarın kapsadığı videoları yeni anahtarla yeniden şifrelemek gerekirse `scripts/ops/encrypt-existing-post-videos.sh --reseal-key k1` kullanılır (dosyayı çözüp yeni aktif anahtarla sarılı yeni DEK ile yeniden yazar; ayrıntı MEDIA_PIPELINE.md).
- **`JWT_SECRET` sızdı:** hemen değiştir + yeniden başlat (tüm oturumlar düşer); şüpheli yönetici işlemleri için denetim kaydını (`audit_log`) tara.
- **`DB_PASSWORD` sızdı:** parolayı değiştir (`ALTER USER bingol PASSWORD ...`), `.env.prod`, backend + backup'ı yeniden başlat; ağ dışa kapalı olduğundan sızıntı yolu araştırılır (log, yedek, repo).
- **`ADMIN_PASSWORD` / yönetici hesabı:** parolayı değiştir, yönetici oturumlarını kapat, denetim kaydını incele.
- **FCM anahtarı sızdı:** Firebase konsolunda anahtarı **hemen sil**, yenisini ekle.
- **age özel anahtarı sızdı:** yeni anahtar çifti; uzak kopyalardaki yedekler sızmış sayılır (ihlal değerlendirmesi); mümkünse en eski yedekleri silin.
- **Sunucu ele geçirildi:** tüm sırlar sızmış varsayılır (hepsini rotasyona al, sunucuyu yeniden kur), canlı veri sızdı sayılır; KVKK süreci.

## 10. Operasyonel kurallar

- Sırları yalnızca `scripts/ops/gen-secrets.sh` ile üretin; çıktı ekrana yazılmaz, dosya izni 600.
- `.env.prod` içeriğini sohbet/e-posta/ticket ile paylaşmayın; paylaşım şifre yöneticisi üzerinden.
- Her rotasyon ve erişim değişikliği `docs/RUNBOOK.md` "Değişiklik günlüğü"ne tarih + kişi ile (değer olmadan) işlenir.
- `docker compose config` çıktısı sırları açar: ekran görüntüsü/paylaşım yapmayın; CI günlüklerinde gizlenmelidir.
