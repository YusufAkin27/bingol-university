# Kişisel Veri Saklama ve İmha Politikası (İç Belge)

Kapsam: BÜ Kampüs (backend, web, mobil). Dayanak: 6698 s. KVKK m.7, "Kişisel Verilerin Silinmesi, Yok Edilmesi veya Anonim Hale Getirilmesi Hakkında Yönetmelik" (m.8-9: periyodik imha en geç 6 ay). Kullanıcıya dönük özet: `docs/legal/retention_tr.md`. **Süreler koddan doğrulanmıştır; ayar adları parantezdedir.**

## 1. Roller

| Rol | Sorumluluk |
|---|---|
| Veri sorumlusu temsilcisi | Politikayı onaylar, imha raporlarını imzalar |
| Teknik sorumlu (geliştirici/DevOps) | Zamanlanmış temizlik işlerinin çalıştığını izler, yedek döngüsünü yönetir |
| Hukuk danışmanı | Süre ve yasal saklama yükümlülüklerini gözden geçirir |
| Moderatör/yönetici | Yalnızca görev kapsamında veriye erişir (bkz. 04 numaralı belge) |

## 2. Saklama ve imha envanteri

| Veri | Tablo / depo | Süre (ayar) | Mekanizma | İmha yöntemi |
|---|---|---|---|---|
| Bekleyen kayıt | Redis `reg:<email>` | 1 saat | Redis TTL | Otomatik |
| Doğrulama kodu | Redis `vc:*` | 10 dk, 5 deneme | TTL | Otomatik |
| Refresh token (hash) | Redis `rt:*`, `rtu:<uid>` | 30 gün (`jwt.refresh-ttl-days`) | TTL, çıkışta/şifre değişiminde/yeni mobil girişte silme | Otomatik |
| Bildirim kutusu | `notification` | Okunmuş 90 gün (`app.notification.retention-days`), okunmamış 365 gün (`...unread-retention-days`) | Gece 03:30 işi | Silme |
| Cihaz FCM token | `device` | 60 gün görülmezse (`app.push.device-ttl-days`) | Gece 04:00 işi | Silme |
| Cihaz/IP günlüğü | `user_device_log` | 90 gün (ayara bağlı; bkz. LEGAL_CHECKLIST: **5651 kararı**) | Gece işi (access-ban modülü) | Silme |
| Engellenen deneme günlüğü | `blocked_attempt_log` | 90 gün (`app.security.ban-log-retention-days`); hesap silmede kullanıcının satırları da silinir | Gece işi | Silme |
| Uygunsuz ifade isabet kaydı | `profanity_hit_log` | 90 gün (`app.dbmaint.log-days`); hesap silmede kullanıcının satırları da silinir | Gece 03:00 işi | Silme |
| Silme defteri (yedek dışı) | `app.privacy.deletion-ledger-file` | Süresiz (yalnız sayısal kimlik + zaman; kişisel veri yok) | Hesap silmede eklenir | Geri yükleme sonrası yeniden anonimleştirme; dosya ≤ 365 gün uzak kopya politikasına tabi değildir, ayrı hacimde tutulur |
| Analitik olay | `analytics_event` | 180 gün | Gece 03:15 (`analytics.retention.cron`) | Silme |
| Mail kuyruğu | `mail_outbox` | SENT 7 gün, DEAD 30 gün (`app.dbmaint.mail-sent-days`/`mail-dead-days`); doğrulama/sıfırlama **kodu** gönderimden 1 saat sonra, hesabı olmayan adreslere giden SENT satırları 1 gün sonra silinir | Saatlik + gece işi (`DbMaintenanceJob`) | Silme / değişken temizleme |
| Silinen mesaj (şifreli) ve düzenleme geçmişi | `message`, `message_revision` | **90 gün** (`app.chat.deleted-retention-days`, K-14); düzenleme penceresi 24 saat (`app.chat.edit-window-minutes`), silme sınırsız | Gece 03:40 işi | Kalıcı silme (CASCADE) |
| Tek gönderimlik görsel baytları | Dosya deposu + `message_attachment` | **7 gün** (`app.chat.media.view-once-retention-days`, K-14; alıcı yalnız ilk 24 saatte açabilir) | Saatlik iş | Dosya silme, `purged_at` |
| Bağlanmamış sohbet medyası | Dosya deposu | 24 saat (`app.chat.media.unclaimed-hours`) | Saatlik iş | Dosya silme |
| Herkese açık destek talebi | `support_ticket` | 365 gün (`app.support.public-ticket-retention-days`) | İş | Silme |
| Etkinlik sohbet odası | `conversation` | Etkinlik bitiminden 7 gün (`app.chat.event-room-close-days`) | İş | Kapatma |
| Sözleşme onayı | `legal_acceptance` | Hesap silmede korunur | — | Zamanaşımı sonu |
| Moderasyon izi | `moderation_strike`, `report`, ban kayıtları | Hesap silmede kimliksiz korunur | — | Gözden geçirme |
| Yönetici işlem kaydı | `admin_audit` | Süre tanımlı değil (kod temizlemez) | — | **Karar gerekir** |
| Yönetici mesaj erişim kaydı | `message_access_audit` | Yalnızca-ekleme (tetikleyici); kod temizlemez | — | **Karar gerekir** (dış arşiv + süre) |

## 3. Hesap silme (anonimleştirme)

`AccountDataPurger` ve ilgili servisler: silinen — device, notification, notification_pref, notification_subtype_pref, bookmark, feedback_vote, event_feedback, user_block (iki yön), club_join_answer, OWNER/BANNED olmayan topluluk üyelikleri, yüklenen sohbet görselleri, **blocked_attempt_log, profanity_hit_log, message_attachment_view, message_reaction, club_member_grant, conversation_add_ban, event_co_organizer, e-posta kuyruğundaki eski adres satırları**. Her sütunun kararı ve gerekçesi `docs/DATABASE.md` bölüm 16 ve `AccountDataPurger.RETAINED` içindedir (`AccountDataPurgerCoverageTest` yeni sütunda uyarır). Metinleri temizlenen — feedback, support_ticket, support_message, moderation_appeal, report notu, event_application, event_certificate adı. Odalardan çıkış. Korunan — legal_acceptance, moderasyon izi, event_attendance, topluluk gönderileri, mesajlar, admin_audit. **Not:** `analytics_event` hesap silmede ayrıca silinmez (kullanıcı satırı anonimleştirildiği için olaylar kimliksizdir; kalan süre 180 güne kadar).

## 4. Periyodik imha

1. Otomatik işler günlük/saatlik çalışır; her çeyrek yılda bir (en geç 6 ayda bir) teknik sorumlu, işlerin son çalışma ve silinen kayıt sayılarını kontrol eder, **imha tutanağı** (tarih, kapsam, yöntem, sorumlu) hazırlar ve 3 yıl saklar (Yönetmelik m.7).
2. Çok örnekli çalışmada `@Scheduled` işlerinin `SchedulerLock` ile sarmalanması (DEPLOY.md bölüm 6) tamamlanana kadar tek örnek çalıştırılır.
3. Yedekler: veritabanı yedeği saklama döngüsü içinde kendiliğinden kaybolur; geri yüklemede silinmiş verinin yeniden çıkmaması için **silme defteri** (yedek dışı dosya, `DELETION_LEDGER_FILE`) açılışta ve her gece yeniden uygulanır (`DeletionLedgerReapplier`); uzak yedek saklama süresi en çok 365 gündür (`docs/BACKUP_RESTORE.md`). Şifreleme ana anahtarları veritabanı yedeğinden ayrı saklanır (`docs/ENCRYPTION.md`).

## 5. Anonimleştirme ölçütü

Ad, e-posta, profil alanları ve fotoğraf geri döndürülemez biçimde değiştirilir; kullanıcı satırı kimliğe bağlanamaz hale gelir. Mesaj/gönderi gibi başkalarının bağlamı olan kayıtlarda yazar anonim görünür.

## 6. Gözden geçirme

Politika yılda en az bir kez ve her yeni kişisel veri tutan modülde (yeni `DataExporter` ile birlikte) güncellenir.

## 7. Rehber eşleştirme ve e-posta özeti (T-061, aydınlatmaya eklenecek)

- `app_user.email_sha256`: kayıt e-postasının tuzsuz SHA-256 özeti; rehber eşleştirme (kullanıcının rehberindeki adreslerin özetiyle karşılaştırma) için tutulur, hesap silmede NULL'lanır. Tuzsuz özet takma adlandırmadır, anonimleştirme değildir: aydınlatma metni "kendi e-posta özetiniz saklanır" demelidir (hukuk: yeni gizlilik metni sürümü, `scripts/build-legal-migration-v620.js` yöntemi).
- Rehber eşleştirme **açık onaylıdır**: "Rehberden bulunabilirim" ayarı varsayılan KAPALI (`profile_privacy.contacts_discoverable`); kapalı kullanıcı bulunmaz ve eşleştirme yapamaz (karşılıklı). Rehberdeki özetler ve sonuçlar saklanmaz; hesap başına günde en çok 2000 tekil aday sorgulanabilir.
- Mobil: rehber izni ilk kullanımda ve amacı açıklanarak istenmelidir.
