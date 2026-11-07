# Telefon / rehber verisi temizleme planı

Durum (2026-11-07): telefon rehberi eşleştirme, telefon numarası ve WhatsApp doğrulama özellikleri kaldırıldı (kod, uçlar, izinler, çeviriler). Telefon numarası hiçbir yerde toplanmaz ve zorunlu değildir. Bu belge, **canlı veritabanında ve Redis'te kalmış olabilecek** artık veriyi güvenle temizlemek için bir PLANDIR. **Hiçbir komut bu çalışma kapsamında çalıştırılmadı.** Üretimde kişisel veri silme / sütun düşürme geri alınamaz; her adım onay ister.

İlgili: `docs/changes/profile.md` ("Rehber eşleştirme KALDIRILDI"), `docs/DATABASE.md`, `docs/LEGAL_NOTES.md` bölüm 14, `docs/BACKUP_RESTORE.md`.

## 1. Envanter: neresinde veri olabilir

| Yer | Ne | Kişisel veri mi | Eylem |
|---|---|---|---|
| `profile_privacy.contacts_discoverable` (V995, `BOOLEAN NOT NULL DEFAULT FALSE`) | "Rehberden bulunabilirim" tercihi | Evet (tercih; kullanıcıya bağlı) | Kod artık yazmaz/okumaz. Sütun düşürülmez; değerler sıfırlanabilir (bölüm 4). Sütun DÜŞÜRME ayrı, sonraki bir sürümde ve yedek sonrası |
| `app_user.email_sha256` (V240, indeks `usr240_email_sha256`) | E-postanın tuzsuz SHA-256 özeti | Evet (kalıcı kimlik özeti) | **KALIR**: e-posta bastırma listesi (`mail_suppression`, `MailSuppressionAdminService`) eşlemesi bu sütunu kullanır. Hesap silmede zaten NULL'lanır |
| Redis `cm:day:<uid>:<gün>` | Günlük rehber aday sayacı | Dolaylı (kullanıcı kimliği + sayaç) | TTL'li; kendiliğinden düşer. İsteğe bağlı erken silme (bölüm 5) |
| Redis `rl:contacts-match:user:<uid>`, `rl:contacts-match:ip:<ip>`, `rl:contacts-discoverable:user:<uid>` | Hız sınırı sayaçları | IP/kullanıcı kimliği (kısa ömürlü) | TTL 1 saat; kendiliğinden düşer |
| Uygulama günlükleri (`docker compose logs backend`) | `/api/users/contacts/*` isteği satırları | İstek yolu, kimlik | Günlük döndürme saklama süresiyle düşer |
| `audit_log` / analitik ham olaylar | Eski çağrıların izi olabilir | Evet (kimlik + yol) | Mevcut saklama işi (`DbMaintenanceJob`) süresi dolunca siler; elle silme gerekmez |
| İstemci cihazı | Rehber hiçbir zaman sunucuda saklanmadı; yalnız istek sırasında bellekte e-posta özetleri taşındı | - | Sunucuda silinecek rehber içeriği YOKTUR |

Telefon numarası / WhatsApp: veritabanında bu amaçla bir sütun veya tablo oluşturulmadı (V995 ve ilgili migration'larda yok). `app_setting` içindeki `phone` anahtarı kurumun herkese açık iletişim numarasıdır (kişisel veri değil), dokunulmaz. Meta/WhatsApp erişim anahtarı (`META_WA_*`) hiç oluşturulmadı; `.env`/sunucuda böyle bir sır varsa kaldırılmalıdır (bölüm 6).

## 2. Önce yedek

1. `docs/BACKUP_RESTORE.md` yordamıyla tam mantıksal yedek alın (`pg_dump -Fc`) ve geri yüklenebilirliğini doğrulayın; yedeğin tarih/sağlama toplamını not edin.
2. Silme defteri (`app.deletion-ledger`) ve yedekten geri yükleme sonrası yeniden anonimleştirme kuralları geçerlidir (`docs/BACKUP_RESTORE.md` 5.7).
3. Değişiklik penceresini bakım saatine alın; web/mobil istemciler zaten bu uçları çağırmıyor.

## 3. Sayım sorguları (yalnız okuma)

```sql
-- Rehber bulunabilirlik bayrağı açık olan kullanıcı sayısı
SELECT COUNT(*) FILTER (WHERE contacts_discoverable) AS acik,
       COUNT(*)                                       AS toplam
FROM profile_privacy;

-- Hash sütunu dolu hesap sayısı (bilgi; sütun bastırma listesi için kalır)
SELECT COUNT(*) FILTER (WHERE email_sha256 IS NOT NULL) AS dolu,
       COUNT(*) FILTER (WHERE deleted_at IS NOT NULL AND email_sha256 IS NOT NULL) AS silinmis_ama_dolu
FROM app_user;

-- Silinmiş (anonimleştirilmiş) hesapta hash kalmamalı: beklenen 0
SELECT COUNT(*) FROM app_user WHERE deleted_at IS NOT NULL AND email_sha256 IS NOT NULL;
```

Sonuçları (sayılar, tarih) onay kaydına yazın. `silinmis_ama_dolu` > 0 ise önce o hesaplar `AccountDataPurger` mantığıyla düzeltilmeli, bu bir bulgudur.

## 4. Onay sonrası temizleme SQL'i (ÇALIŞTIRMAYIN; onay + yedek şart)

Amaç: kullanılmayan bayrağı sıfırlamak. Parçalı, kısa kilitli, yeniden çalıştırılabilir.

```sql
-- Parça parça (ör. 5000'lik) sıfırlama; satır sayısı 0 dönene kadar tekrarlayın.
UPDATE profile_privacy
   SET contacts_discoverable = FALSE
 WHERE user_id IN (
        SELECT user_id FROM profile_privacy
         WHERE contacts_discoverable = TRUE
         ORDER BY user_id
         LIMIT 5000);

-- Doğrulama: beklenen 0
SELECT COUNT(*) FROM profile_privacy WHERE contacts_discoverable = TRUE;
```

Not: sütun düşürme (`ALTER TABLE profile_privacy DROP COLUMN contacts_discoverable`) bu planın DIŞINDADIR. İstenirse yeni bir Flyway migration'ı (mevcut V995'e dokunmadan, sonraki boş sürüm numarası) ile, yedek alındıktan ve bir sürüm boyunca eski kodla çalışma riski kalmadıktan sonra yapılır.

`app_user.email_sha256` için TOPLU NULL'lama önerilmez (bastırma listesi eşlemesi bozulur). Gelecekte bastırma eşlemesi başka yolla yapılırsa ayrıca değerlendirilir.

## 5. Redis anahtar temizliği (isteğe bağlı; anahtarlar zaten TTL'li)

```bash
# Önce say (SCAN; KEYS kullanmayın)
docker compose exec -T redis redis-cli --scan --pattern 'cm:day:*' | wc -l
docker compose exec -T redis redis-cli --scan --pattern 'rl:contacts-*' | wc -l

# Onaydan sonra sil (UNLINK: bloklamaz)
docker compose exec -T redis sh -c "redis-cli --scan --pattern 'cm:day:*' | xargs -r -n 100 redis-cli UNLINK"
docker compose exec -T redis sh -c "redis-cli --scan --pattern 'rl:contacts-*' | xargs -r -n 100 redis-cli UNLINK"
```

Bu anahtarlar silinmese de en geç 24 saat içinde kendiliğinden düşer. `FLUSHALL` KULLANMAYIN (oturum/refresh jetonlarını siler).

## 6. Sır ve yapılandırma temizliği

- Sunucu `.env` / ortam değişkenlerinde `CONTACTS_DAILY_CANDIDATE_CAP` (artık okunmuyor), varsa `META_WA_*` / `WHATSAPP_*` satırları kaldırılır.
- **Manuel adım (kullanıcı):** gerçek bir Meta (WhatsApp Business) erişim anahtarı HENÜZ oluşturulmadı; oluşturulmaması yeterlidir. Meta/Google geliştirici konsollarında bu özellik için açılmış uygulama/hesap varsa kapatılır. Android için Play Console "Hassas izinler" beyanından `READ_CONTACTS` kaldırılır; App Store Connect "Uygulama Gizliliği"nde Contacts veri türü işaretli değilse bırakılır, işaretliyse kaldırılır (`docs/store/data_safety.md`, `docs/ios-store/APP_PRIVACY.md` güncellendi).

## 7. Hukuki metinler

Yayındaki sözleşme/KVKK metinleri hâlâ rehber eşleştirmeyi anlatır (uygulanmış migration'lara dokunulmaz). Sonraki sözleşme sürümünde ifadeler çıkarılmalıdır: `docs/LEGAL_NOTES.md` bölüm 14.

## 8. Doğrulama listesi (temizlikten sonra)

- [ ] Bölüm 3 sayımları kaydedildi; yedek doğrulandı.
- [ ] `contacts_discoverable = TRUE` sayısı 0.
- [ ] `silinmis_ama_dolu` = 0.
- [ ] Redis `cm:day:*` / `rl:contacts-*` boş.
- [ ] `/api/users/contacts/match` ve `/discoverable` 404 döner (uçlar kaldırıldı).
- [ ] Kullanıcı arama (`/api/users/search`), profil, takip, sohbet duman betikleri yeşil.
