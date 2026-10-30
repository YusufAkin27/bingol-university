# A17: Belge-kod tutarlılığı ve API sözleşmesi denetimi

Tarih: 2026-10-31. Denetim aşaması: kod/belge DEĞİŞTİRİLMEDİ. Üretim sunucusuna erişilmedi.
Taban: HEAD `b405782` (çalışma ağacı değişiklikleri hariç). Dinamik doğrulama yalnız A7 test yığınında (`http://localhost:18081`, `C:\bu_qa\QA-STACK.txt` = READY).

## Özet

| Şiddet | Adet |
|---|---|
| KRİTİK | 0 |
| YÜKSEK | 3 |
| ORTA | 14 |
| DÜŞÜK | 7 |

KRİTİK yok: mobilin çağırdığı 200 benzersiz REST yolunun hepsi backend'de var (aşağıdaki "Doğrulananlar"). Sorunların çoğu eskimiş belge ve yanıltıcı operasyon talimatıdır; ikisi (A17-01, A17-02) gerçek dağıtımı bozabilir/etkisiz bırakabilir.

## Yöntem ve doğrulananlar (sorun YOK)

- **Mobil -> backend yol eşlemesi:** `mobile/lib` içindeki tüm `api.get/post/put/patch/delete/getSwr/getBytes/upload` çağrıları + `'/...'` yol sabitleri çıkarıldı (200 yol), backend `@*Mapping` yollarıyla (623 yol) eşlendi (`{var}` ve `$x` normalize). Eşleşmeyen: 0 (tek "PATH_OK_METHOD_DIFF" ayrıştırma hatasıydı: `PUT /conversations/{id}/archive` var). Yorum/hikâye/kaydet uçlarına mobil çağrı kalmamış. STOMP hedefleri `/app/chat.send|read|delivered|typing` backend `@MessageMapping` ile aynı; `/user/queue/{messages,read-receipts,typing,message-events,errors}` ile uyumlu.
- **OpenAPI canlı karşılaştırma:** admin JWT ile test yığınında `GET /v3/api-docs` (622 işlem) <-> `docs/openapi.json` (622 işlem): yol/yöntem/parametre farkı 0; yalnız şema farkları A17-05'te. (`/v3/api-docs` bu yığında ADMIN yetkisiyle açık; ilk çağrı soğukta >2 dk sürdü, ikincisi 2 sn.)
- **Web sözleşmesi:** `npm run check:contract`: 262 web çağrısı, 250 eşleşti, 0 eşleşmeyen, 12 dinamik (atlandı).
- **Betikler:** `scripts/` içindeki tüm `/api/...` yolları backend'de var; kırık yol yok. Belgelerdeki `scripts/...`/`docs/...` dosya referansları (CLAUDE.md, DEPLOY*, PERFORMANCE, ADMIN_API, MOBILE_PUSH, RUNBOOK vb.) mevcut dosyalara çıkıyor.
- **i18n:** `app_tr/en/ar.arb` her biri 2736 anahtar, eksik/fazla yok.
- **Tema (I2):** `MOBILE_DESIGN_SYSTEM.md` açık tema değerleri (#F8F9FC, #EDEEF1, #E7E8EB, #575E76, #C3C7D4) `mobile/lib/core/theme.dart:138-143` ve `widgets/sistem_widgets.dart:16` ile aynı; `BuDefaultAvatar` `widgets/bu_default_avatar.dart`'ta.
- **Sürüm:** `pubspec.yaml` 2.0.3+20003, `app_gate.dart:13` ve `push_service.dart:22` varsayılan 2.0.3; tutarlı (ANDROID_RELEASE.md'deki 2.0.2 tarihçedir).
- **Hata kodları / enum'lar:** mobilin ele aldığı kodların büyük kısmı backend'de var; backend'de bulunmayanlar (`TOKEN_REUSED`, `SESSION_REVOKED`, `MEDIA_LOST`, `POLL_NEW`, `FEED_COMMENT`) savunmacı/yerel; zarar yok. `LEGAL_REACCEPT_REQUIRED` (+ `requiresAcceptance` listesi), `X-Next-Cursor`, `Idempotency-Key`, `ACCESS_BLOCKED`, `SESSION_REPLACED`, `CONTENT_PROFANITY`, `EVENT_CLUB_REQUIRED`, `DB_TIMEOUT` iki tarafta aynı.
- **PERFORMANCE.md C1 envanteri:** canlı başlıklarla uyumlu (Authorization varsa `private, max-age=N`; `/api/news` 60, `/api/menu` 300, `/api/faq` 600, `/api/status` 30, `/api/communities/categories` 60).

---

## YÜKSEK

### A17-01 | YÜKSEK | Prod'da `MAIL_ENABLED=false` "başlar/uyarı" diye belgelenmiş, kod BAŞLATMAZ
- **Yer:** `docs/DEPLOY.md:66-70` ("Uyarı olarak: `MAIL_ENABLED=false` (kodlar log'a yazılır)"), `docs/DEPLOY_SCRIPT.md` "Sırlar" bölümü ("`DEPLOY_MAIL_USER/PASSWORD` verilmezse `MAIL_ENABLED=false` başlar"), `scripts/deploy.sh:18` ve `:295` (uyarı olarak basar), `docs/DEPLOY.md:143`.
- **Kod:** `backend/.../config/ProdSettingsValidator.java:102-109`: `app.mail.enabled=false` ve `app.mail.allow-log-only` verilmemişse **hata** (`IllegalStateException`, uygulama açılmaz). `docker-compose.prod.yml` bu bayrağı (`APP_MAIL_ALLOW_LOG_ONLY`) backend'e iletmiyor. `docs/BACKUP_RESTORE.md:197` doğru söylüyor ("başlamayı reddeder").
- **Etki:** Brevo bilgisi olmadan `scripts/deploy.sh` (özellikle ilk kurulum / `--ip-test`) `.env.prod`'a `MAIL_ENABLED=false` yazar -> backend sağlık vermez -> otomatik geri alma; belge "kodlar log'a yazılır" diyerek bunu bir uyarı sanmaya itiyor.
- **Düzeltme:** DEPLOY.md bölüm 2'deki "Uyarı olarak" listesinden `MAIL_ENABLED=false` çıkarılıp "HATA (allow-log-only olmadan açılmaz)" yazılmalı; DEPLOY_SCRIPT.md ve `deploy.sh` başlık/uyarı metni "MAIL_ENABLED=false prod'da backend'i açtırmaz; Brevo bilgisi zorunlu (ya da bilinçli `APP_MAIL_ALLOW_LOG_ONLY=true` compose'a iletilmeli)" demeli; tercihen `deploy.sh` mail bilgisi yoksa dağıtımı baştan reddetmeli.

### A17-02 | YÜKSEK | Prod compose, belgelerde "`.env.prod`'a yazın" denen birçok değişkeni konteynere İLETMİYOR (sessiz etkisiz)
- **Yer / kanıt:** `docker-compose.prod.yml:111-176` backend `environment` listesi sabit; `env_file` yok. İletilmeyenler (uygulama `application*.properties`'te okuyor):
  - `LEGAL_ENFORCE_REACCEPT`: `docs/DEPLOY.md:299` ("`.env.prod` içinde `LEGAL_ENFORCE_REACCEPT=true`, `up -d backend`"), `docs/LAUNCH_CHECKLIST.md:86`. Değer konteynere ulaşmaz; yeniden onay zorlaması ASLA açılmaz, operatör açtığını sanır.
  - `FCM_CREDENTIALS_FILE`: `docs/DEPLOY.md:85`, `docs/PUSH_SETUP.md:20`, `.env.example:38`. Prod yalnız `FCM_CREDENTIALS_JSON` iletiyor (`docker-compose.prod.yml:148`); dosya yolu verilirse push sessizce kapalı kalır (yalnız "FCM kimlik bilgisi yok" uyarısı).
  - `DB_POOL_MAX`/`DB_POOL_MIN_IDLE` (`DEPLOY.md:89`), `OBS_ALERT_EMAIL`/`OBS_ALERT_ENABLED` (`DEPLOY.md:246`), `BLOCK_ANONYMIZERS`, `BAN_CACHE_TTL_SECONDS`, `BAN_LOG_RETENTION_DAYS` (`DEPLOY.md` tablosu), `PUSH_MESSAGE_PREVIEW`, `PUSH_OUTBOX_*`, `DBMAINT_*`, `CHAT_*`, `MEDIA_*` (kalite/boyut), `RL_*`, `NOTIFICATION_RETENTION_DAYS` (`DEPLOY.md:99` "Diğer modüllerin ayarları ... ortam değişkeni karşılığıyla listelidir") vb. toplam ~150 değişken.
- **Düzeltme:** `docker-compose.prod.yml` backend'e `env_file: .env.prod` eklemek (veya belgelenen değişkenleri tek tek `${X:-}` ile iletmek; en azından `LEGAL_ENFORCE_REACCEPT`, `FCM_CREDENTIALS_FILE`, `DB_POOL_*`, `OBS_ALERT_*`, `BLOCK_ANONYMIZERS`, `BAN_*`); DEPLOY.md "Ortam değişkenleri" tablosuna "yalnız compose'ta listelenenler iletilir" notu. Aksi halde bölüm 14.4'teki "son adım" çalışmaz.

### A17-03 | YÜKSEK | DEPLOY.md hâlâ `scripts/deploy/update.sh` yolunu "önerilen" diye anlatıyor; fiilî yol `scripts/deploy.sh`
- **Yer:** `docs/DEPLOY.md:7-24` (bölüm 0), `:146-158` (bölüm 8), `:259+` (14.2: `bash scripts/deploy/update.sh --ref vX.Y.Z`). DEPLOY.md'de `deploy.sh`'e hiç atıf yok. `docs/DEPLOY_SCRIPT.md:3` ise "İkisi birlikte kullanılmaz: sunucu düzeni `deploy.sh` içindir" (`/opt/bukampus/{releases,current,.env.prod}`, kod `git archive | ssh tar` ile gider, sunucuda `git pull` yok).
- **Etki:** Operatör DEPLOY.md bölüm 14.2'yi izleyip `update.sh --ref` çalıştırırsa sunucu düzeniyle (`/opt/bukampus` sürüm dizinleri, özel depo erişimi yok) uyuşmayan bir yol çalıştırır; geri alma/yedek adımları farklı olur.
- **Düzeltme:** DEPLOY.md bölüm 0 ve 14.2'ye "Üretimde (bukampus.com.tr VDS) dağıtım: `scripts/deploy.sh` (bkz. DEPLOY_SCRIPT.md); `update.sh` yalnız sunucudan git erişimli kurulumlar içindir" notu ve 14.2 komutlarının `deploy.sh` karşılığı (`--ref`, `--dry-run`, `--rollback`) eklenmeli.

---

## ORTA

### A17-04 | ORTA | `docs/changes/push.md` "Akıllı bildirim" ve `MOBILE_API_GUIDE.md` collapse_key anlatımı P1 ile çelişiyor
- `docs/changes/push.md:88-89`: "Alıcı çevrimiçi (WS bağlı) -> yalnız canlı WS olayı ... fg -> yalnız kutu satırı, push yok ... sohbet başına 20 sn pencere ... dakikada en çok 10 push". P1 (`push.md:135+`, `MessageService.notifyOffline`) bunu tersine çevirdi (her durumda push gider; pencere 0; ayrı mesaj sınırı 60). Eski bölüm silinmeden/işaretlenmeden duruyor; `MOBILE_API_GUIDE.md:783` işaretlenmiş ama `push.md:89` işaretlenmemiş.
- `docs/MOBILE_API_GUIDE.md:790`: "FCM: `collapse_key` + Android `tag` = collapseKey ...". P1 FCM `collapse_key`'i KALDIRDI (`push.md` P1 madde 3, `FirebaseFcmSender`); `tag`/`apns-collapse-id` kaldı.
- **Düzeltme:** `push.md:86-92` bölümüne "(P1 ile geçersiz, bkz. aşağıda)" başlığı veya içerik güncellemesi; `MOBILE_API_GUIDE.md:790`'dan "`collapse_key` +" kaldırılmalı ("FCM `collapse_key` GÖNDERİLMEZ; Android `tag`...").

### A17-05 | ORTA | `docs/openapi.json` P1 alanlarını içermiyor (P1 yeniden üretmedi)
- Canlı `/v3/api-docs` ile fark (tam liste): `PrefsView.messagePreview`, `PrefsUpdate.messagePreview`, `PushDeviceInfo.lastPushStatus/lastPushErrorCode/lastPushAt` yok; `LogoutRequest` şeması (`POST /api/auth/logout` gövdesinde `fcmToken`) yok. Diğer her şey (V880/V890/B1/C1 alanları, `thumbEdge`, `totalCount`, `manualCode`, `chatAccess`, `blockedByMe`, `avatarHidden`) güncel.
- Etki: `scripts/openapi-check.js` DRIFT ile kırmızı olur; `gen-mobile-models.sh` / web `check:contract` eski şemayla çalışır.
- **Düzeltme:** `node scripts/openapi-gen.js` (veya `OpenApiExportTest -Dopenapi.out=docs/openapi.json`) çalıştırıp `docs/openapi.json` commit'lenmeli; P1 commit'i (81fdfb3) bunu atlamış.

### A17-06 | ORTA | CLAUDE.md Flyway aralık tablosu güncel değil
- `CLAUDE.md` §3 "Flyway": V880 (`notification_pref.polls`, `academic_announcements`), V890 (`message_attachment.thumb_edge`), V896 (`notification_pref.message_preview`) yok; V820 (hukuki metin v4) yalnız V800-V819 notunda geçiyor; V200-V470 bloğu hiç anılmıyor (anlamı bilinmeyen aralık: V200-V470 anket/gönderi/akademik/yönetici özellikleri).
- **Düzeltme:** tabloya "V870 menü kalorisi, V880 anket/akademik bildirim tercihi, V890 sohbet küçük resim kenarı, V896 mesaj önizleme tercihi; yeni numara >= V897" ekleyin.

### A17-07 | ORTA | CLAUDE.md duman betiği listesi gerçek `scripts/` ile uyuşmuyor
- Listede olmayan: `smoke-menu-calories.sh` (V870), `smoke-admin-rbac.sh` (yalnız §9'da anılıyor, §2 listesinde yok). Gerçekte 36 `smoke*.sh` (smoke-all.sh ve smoke.sh dahil). Diğer tüm listelenenler mevcut.
- **Düzeltme:** §2 listesine iki betik eklenmeli.

### A17-08 | ORTA | CLAUDE.md paket haritası ve modül notu listesi eksik
- Backend'de var, haritada yok: `academic` (ders programı/sınav/akademik takvim/bölüm duyuruları; `TimetableController`, `AcademicController`; `smoke-academic.sh`; `docs/changes/academic.md`), `catalog` (`GET /api/catalog/academic`), `devseed`, `health`.
- "Modül bazlı ... `docs/changes/*.md`" cümlesi 9 dosya sayıyor; var olan 14: eksik `academic`, `clubadmin`, `modsupport`, `poll`, `post`.
- **Düzeltme:** harita tablosuna `academic`/`catalog` satırı, `changes` listesine eksik beşi.

### A17-09 | ORTA | CLAUDE.md: "`@Scheduled` görevleri henüz `SchedulerLock` ile sarmalanmadı" ve zamanlayıcı tablosu eksik
- `SchedulerLock` artık 10 sınıfta kullanılıyor: `MailQueueWorker`, `MailCampaignDispatcher`, `PushOutboxWorker`, `DbMaintenanceJob`, `RetentionPurgeService`, `TranscodeWorker`, `StorageAlertJob`, `CrashAlertService`, `AccessBanRetentionJob` (+ `SchedulerLock` kendisi). Yanlış ifade: CLAUDE.md §1 `config` satırı ve §8 sınırlamalar (`Push kuyruğu ... @Scheduled görevleri ... henüz sarmalanmamıştır`); `docs/DEPLOY.md` bölüm 6 (`:123`, `:137`) da "sarmalamalıdır" dilinde.
- §1 "Zamanlayıcılar" tablosu ~40 `@Scheduled` görevinden 8'ini listeliyor. Eksik olanlar: `PollCloseJob` (10 dk + 00:05), `AnnouncementNotifier` (60 sn), `PostScoreJob` (saat başı :05), `PostRankService` (5 dk), `PostCounterRepairJob` (03:30), `PostMediaJanitor`, `ChatMediaMaintenance` (saat başı :15/:30), `DeletedMessageRetention` (03:40), `NotificationRetentionJob` (03:30), `PushOutboxWorker` (5 sn + 03:20), `StorageAlertJob` (15 dk), `SystemAlertService` (60 sn), `CrashAlertService`, `MediaOrphanSweeper` (03:30), `AccessBanRetentionJob` (04:30), `EventRetention` (03:15), `ProfanityHitLogger` (04:30), `MailCampaignDispatcher` (10 sn, 03:20), `PublicSupportService` cleanup (03:30), `PostRetentionJob` (05:10).
- **Düzeltme:** tablo tam listelenmeli (veya "tam liste: `grep -rn @Scheduled`" notu) ve `SchedulerLock` ifadesi "yeni görevler `SchedulerLock` ile sarmalanır; sarmalanmayanlar: ..." diye güncellenmeli.

### A17-10 | ORTA | CLAUDE.md §8 "Bilinen sınırlamalar" artık geçersiz maddeler içeriyor
- "**Uygulama içi EN/AR çeviri henüz yok**" (§8 son madde): yanlış. Mobilde `lib/l10n/app_{tr,en,ar}.arb` 2736 anahtar, üçü de tam; `docs/I18N_MOBILE.md`, `LocaleController` var.
- "**Sözleşme metinleri (V99, 2. sürüm) taslaktır ... EN/AR sözleşme çevirileri yok (Türkçe sunulur)**": yanlış. V480 (v3) ve V820 (v4) tr+en+ar aynı sürüm numarasıyla yayınlı (`V820__legal_terms_v4.sql`, "EN ve AR metinler TR ile madde madde esit"); `docs/LEGAL_NOTES.md` bölüm 1: çeviriler var (Arapça hukuk çevirmeni incelemesi bekliyor).
- "FCM/APNs push kodu hazır ama Firebase/APNs bilgisi bekliyor": kodla doğrulanamaz (kimlik bilgisi bu denetimde görülmedi); P1/P2 sonrası durum için sahibinden teyit gerekir. Bu madde ve §2 "Gerçek SMTP ve Firebase ... henüz girilmedi" cümlesi `docs/DEPLOY.md`/`LAUNCH_CHECKLIST` ile teyit edilmeli.
- **Düzeltme:** ilk iki madde silinmeli/yeniden yazılmalı ("Arapça arayüz ve sözleşme çevirileri anadil/hukuk incelemesi ister").

### A17-11 | ORTA | CLAUDE.md "Mobil" bölümü ve `docs/MOBILE_UI.md` klasör haritası ile kod ayrışmış
- `CLAUDE.md` §3 Mobil ve `docs/MOBILE_UI.md` §1 tablosu `core/` altında yalnız api/session/app_gate/analytics/realtime/push/platform sayıyor. Gerçekte var: `core/cache/` (disk/mesaj/görsel önbelleği, `cache_policy`), `core/outbox/` (sessiz gönderme kuyruğu), `core/connectivity/`, `core/contacts/`, `core/crash/`, `core/notify/`, `core/permissions/`, `core/theme/` (BuColorScheme, bileşen temaları), `core/nav.dart`; `features/` altında `academic`, `polls`, `follow`, `legal`, `media_crop`, `platform`, `posts` (haritada yok); `widgets/bu_default_avatar.dart` (N4). (`MOBILE_UI.md` §4.2 ve §6 bu parçaları ayrı ayrı anlatıyor; harita tablosu eski.)
- `docs/MOBILE_UI.md` §11 (satır 127-135): `lib/features/auth/widgets/auth_shell.dart`, `auth_fields.dart`, `auth_sheets.dart`, `auth_art.dart` yok; klasörde `auth_academic.dart`, `auth_controls.dart`, `auth_motion.dart`, `auth_ref.dart` var. `test/auth_shots_test.dart` yok.
- **Düzeltme:** iki belgedeki harita güncellenmeli; §11 dosya adları gerçek dosyalara çevrilmeli.

### A17-12 | ORTA | Ortam değişkeni belgeleri/örnek dosyaları kodla örtüşmüyor
- `CLAUDE.md` §2 "Ortam değişkenleri" listesinde yok: `CACHE_ENABLED` (+ `CACHE_*`), `PUSH_*` (`app.push.*`: `PUSH_OUTBOX_*`, `PUSH_MESSAGE_PREVIEW`), `ADMIN_BASIC_ENABLED` (§2 ilk maddede anılıyor ama listede değil), `LEGAL_ENFORCE_REACCEPT` (smoke için gerekli diyor ama listede yok), `DEVICE_HMAC_KEY`, `MAIL_UNSUBSCRIBE_KEY`, `SENTRY_DSN`, `STORAGE_DB_DISK_*`/`OBS_STORAGE_*`.
- `.env.example` yok (kodda var): `CACHE_ENABLED`, `FCM_CREDENTIALS_JSON`, `DEVICE_HMAC_KEY`, `MAIL_UNSUBSCRIBE_KEY`, `SENTRY_DSN`, `ADMIN_BASIC_ENABLED`, `LEGAL_ENFORCE_REACCEPT`, `MAIL_SSL`, `MAIL_RECIPIENT_GAP_SECONDS`, `REDIS_*`. Kök `docker-compose.yml` bunların çoğunu iletiyor (`CACHE_ENABLED`, `FCM_CREDENTIALS_JSON`) ama örnek dosyada yok.
- `.env.prod.example` yok (prod compose kullanıyor): `CACHE_ENABLED`, `MAIL_UNSUBSCRIBE_KEY`, `MAIL_SSL`, `MAIL_RECIPIENT_GAP_SECONDS`, `OBS_STORAGE_WARN/CRIT_PERCENT`, `STORAGE_DB_DISK_PATH`, `WWW_DOMAIN`, `BACKEND_IMAGE`, `PG_*`; `CRYPTO_REQUIRE_KEYS` ise örnekte var ama prod compose'ta sabit "true" (kullanılmıyor).
- `springdoc.api-docs.enabled` ana ayarda `OPENAPI_DOCS_ENABLED:true`, prod'da false; CLAUDE.md/DEPLOY.md "Swagger kapalı" diyor, `/v3/api-docs` yerelde ADMIN'e açık (belgede bu uç anılmıyor).
- **Düzeltme:** üç dosyaya eksik anahtarlar (yorumlu) eklenmeli; CLAUDE.md listesine "Önbellek/push/oturum" satırı.

### A17-13 | ORTA | `docs/DATABASE.md` tablo envanteri eksik (37 canlı tablo yok)
- Flyway'de oluşturulup düşürülmemiş 101 tablodan 37'si DATABASE.md'de hiç geçmiyor: `admin_profile_change`, `ban280_anonymizer_range`, `bookmark`, `club_invite`, `club_join_answer`, `club_join_question`, `club_member_grant`, `club_ownership_transfer`, `community_category`, `community_member`, `community_post`, **`crash_event`, `crash_group`, `crash_group_version`** (V860), `event_admission`, `event_announcement`, `event_application`, `event_certificate`, `event_co_organizer`, `event_feedback`, `event_series_member`, `exam_schedule`, `feedback_vote`, `mail_campaign`, `mail_template_custom_version`, `message_attachment_view`, `moderation_appeal`, `moderation_reason_template`, `moderation_strike`, `moderation_target_state`, **`poll_ballot`, `poll_option`, `poll_vote`**, `push_campaign`, `support_ticket_note`, `tt_course`, `tt_semester`, `tt_session`.
- Sütun eklemeleri belgelenmemiş: `message_attachment.thumb_edge` (V890), `notification_pref.polls/academic_announcements` (V880), `notification_pref.message_preview` (V896). DATABASE.md'de V860/V870/V880/V890/V896 anılmıyor. (`menu_item_calorie`, `push_outbox`, `data_export_receipt`, `data_purge_log` var.)
- **Düzeltme:** §2 envanterine eksik tablolar (büyüme/saklama) ve migration notu.

### A17-14 | ORTA | `docs/ADMIN_API.md` yönetici cihaz yanıtı P1 alanlarını içermiyor
- `docs/ADMIN_API.md:797`: `GET /users/{id}/push-devices` -> `[{id,platform,appVersion,locale,tokenTail,createdAt,lastSeenAt}]`. Kod (`UserExtrasDtos.PushDeviceInfo`): ayrıca `lastPushStatus`, `lastPushErrorCode`, `lastPushAt` (yalnız `docs/changes/push.md` P1'de anlatılıyor).
- (Genel not: ADMIN_API.md yolları göreli/özet tablolarda yazıyor; tam yol bazlı otomatik karşılaştırma güvenilmez. `RbacCoverageTest` her uç için izin eşlemesini zorlar; belge-kod yol farkı için tek tek yeni uç taraması yapılmadı, bkz. "Bakılamayanlar".)
- **Düzeltme:** 797. satıra üç alan eklenmeli.

### A17-15 | ORTA | `docs/MOBILE_API_GUIDE.md` P3/C1 değişikliklerini içermiyor
- `AttachmentView.thumbEdge` (V890, küçük resim gerçek uzun kenarı; eski kayıt `null`=320) rehberde yok (yalnız `MEDIA_PIPELINE.md:127`, `changes/messaging.md:132`'de). Mobil bunu kullanıyor (`features/chat/chat_media.dart:102`).
- C1 ile eklenen sunucu HTTP önbellek davranışı (`news`/`menu`/`faq`/`status`/`app/info`/`legal`/`categories` için `Cache-Control private,max-age=N`; yetkisizde `public`) rehberde yalnız `catalog`/`events/featured` için geçiyor; yalnız PERFORMANCE.md'de.
- **Düzeltme:** §sohbet görseli bölümüne `thumbEdge`; "HTTP önbellek" kısa bölümü.

### A17-16 | ORTA | `docs/CHANGELOG.md` B1'den sonrası yok
- Son bölüm "B1" (satır 45-55). Eksik: P1/P2 (push düzeltmeleri, V896, logout `fcmToken`), P3 (V890), C1 (sunucu okuma önbelleği, `CACHE_ENABLED`), I4/N4 (mobil avatar/disk önbelleği), mobil yeniden tasarım (51 grup), sürüm 2.0.3+20003, CLN1 disk temizliği. CHANGELOG'daki "Mobil" bölümü hâlâ "Firebase bilgisi bekliyor" ve test listesi eski (api, api_cache, ... 8 dosya; gerçekte 70+).
- **Düzeltme:** CHANGELOG'a P1-P3, C1, I-serisi girişleri.

### A17-17 | ORTA | `docs/MOBILE_PAGES.md` tarihî plan belgesi gibi duruyor, kodla ayrışmış
- Başlık "planlama belgesi, kod değiştirilmedi", tarih 2026-10-29. Referanslar artık yok: `core/connectivity/offline_banner.dart` (satır 44, 331: yalnız `connectivity_service.dart` var), `features/auth/widgets/auth_art|fields|sheets|shell.dart`, `features/chat/chat_info_tabs.dart` (satır 408), `test/auth_shots_test.dart`, `test/store_shots_test.dart`, `test/support/{fake_app,frame_budget,store_shots_images,ui_matrix}.dart` (bazıları testte olmayabilir; `ls mobile/test/support` ile teyit edilmeli). Sayılar (2144 l10n anahtarı; gerçek 2736, 101 ekran, 3300 test) güncel değil.
- **Düzeltme:** belgenin başına "Tarihî (2026-10-29) plan; güncel envanter için kod" uyarısı ya da yeniden üretim; silinen dosyalar çıkarılmalı.

---

## DÜŞÜK

### A17-18 | DÜŞÜK | `docs/MOBILE_DESIGN_SYSTEM.md:49` bozuk denetim karakterleri içeriyor
- Windows yolu `C:\bu_design\stitch-referans-...` dizgeye kaçışsız yazılmış; `\b` -> 0x08 ve `\s`... bir NUL (0x00) baytına dönüşmüş (dosyada 1 NUL). Sonuç: `grep`/git dosyayı ikili (binary) sayar, diff görünmez; yol okunmaz ("`C:u_design\stitch -referans...`").
- **Düzeltme:** satır 49'daki yol `C:/bu_design/stitch-referans-ana-ekranlar/design-system.txt` (veya kod bloğu içinde kaçışsız) olarak yeniden yazılmalı, NUL/0x08 temizlenmeli.

### A17-19 | DÜŞÜK | `docs/changes/push.md` "Mobil için gerekenler (P2'ye)" artık uygulandı
- Maddeler mobilde var: `session.dart:327` çıkışta `fcmToken` gönderiyor, `notification_prefs_page.dart:568` `messagePreview` anahtarı, `core/push/{push_registrar,push_channels,push_banner,push_api}.dart` (`PUT /devices/{token}/state`, `/conversations/{id}/viewing`). Belge hâlâ yapılacak iş gibi.
- **Düzeltme:** başlığı "Mobil karşılığı (P2'de uygulandı)" yapıp dosya adlarını eklemek.

### A17-20 | DÜŞÜK | `deploy.sh -h` çıktısı kesiliyor; DEPLOY_SCRIPT.md kullanım listesi eksik
- `scripts/deploy.sh:44`: `-h|--help) sed -n '2,23p'`; yapılandırma başlığı satır 28'e kadar uzuyor (`DEPLOY_*` listesinin yarısı ve çıkış kodları basılmıyor). `docs/DEPLOY_SCRIPT.md` "Kullanım" bloğu `--ref <git-ref>`, `--skip-warmup`, `--skip-cleanup`'u listelemiyor (kodda var).
- **Düzeltme:** `sed -n '2,28p'`; belgeye üç bayrak.

### A17-21 | DÜŞÜK | Mobil bildirim listesi gerçekte gönderilen türleri eksik/fazla işliyor
- Backend `NotificationType` (canlı örnek: `USER_FOLLOW`): `NEWS, ANNOUNCEMENT, EVENT, MESSAGE, COMMUNITY, SYSTEM, POST_LIKE, POST_COMMENT, COMMENT_REPLY, POST_MENTION, USER_FOLLOW`. `features/notifications/notifications_page.dart` `_icon/_tone/_typeLabel` içinde `USER_FOLLOW` ve `SYSTEM` yok -> varsayılan zil + "Diğer" etiketi; öte yandan hiç gönderilmeyen `POLL`, `POLL_CLOSED`, `POLL_NEW`, `COMMENT_REPLY` (yorumlar kaldırıldı) dalları var (anketler `ANNOUNCEMENT` + alt tür `POLL` ile geliyor). Kozmetik.
- **Düzeltme:** `USER_FOLLOW` (kullanıcı simgesi) ve `SYSTEM` eklemek, ölü dalları temizlemek.

### A17-22 | DÜŞÜK | Kök `README.md` BOM'lu
- `README.md` UTF-8 BOM (EF BB BF) ile başlıyor; CLAUDE.md §7 "BOM eklemek" yasak. (Kod/doc dizinlerinde başka BOM yok.)
- **Düzeltme:** BOM'u kaldırmak.

### A17-23 | DÜŞÜK | `.env.example` `FCM_CREDENTIALS_FILE` önerirken prod yolu yalnız JSON
- `.env.example:38` ("konteyner İÇİNDEKİ yol"), kök `docker-compose.yml:124` dosya yolunu iletiyor (yerelde doğru); prod için A17-02. Sürüm numaraları: `web/package.json` 0.1.0, `backend/pom.xml` 0.0.1-SNAPSHOT, mobil 2.0.3+20003; üç bileşen bağımsız sürümleniyor (belgelenmemiş, tutarsızlık değil). Kodda sürüm sabiti iki yerde (`app_gate.dart:13`, `push_service.dart:22`) tekrarlanıyor (A13 de not etti).
- **Düzeltme:** `.env.example`'a "prod'da yalnız `FCM_CREDENTIALS_JSON`" notu; sürüm sabitini tek yere indirmek.

### A17-24 | DÜŞÜK | `scripts/` içinde yeni eklenmiş (izlenmeyen) betikler var olmayan dosyaya atıf yapıyor
- `scripts/ci/changes.sh` ve `scripts/ci/secret-files-check.sh` (git'te izlenmiyor) `scripts/test-ci-deploy.sh`'e atıf yapıyor; dosya yok. Henüz commit'lenmemiş iş olabilir; commit edilmeden önce eşlenmeli.

---

## Bakılamayanlar / sınırlar

- Alan düzeyi tip uyumu yalnız **anahtar adı** düzeyinde tarandı (309 mobil `['anahtar']` erişimi vs canlı OpenAPI + backend dizgeleri; backend'de karşılığı olmayanlar tek tek incelendi: hepsi mobil yerel/tolerant `??` yedekleri, ör. `pendingRequestCount`, `canManageEvents`, `ReminderSettings` yerel). int/String/null tip farkları ve her enum değeri tek tek doğrulanmadı; STOMP yük gövdeleri ve `ConversationView` iç alanları canlı yanıtla satır satır karşılaştırılmadı.
- `docs/ADMIN_API.md` yolları göreli/özet tablolarla yazıldığından "belgelenmemiş admin ucu" taraması güvenilir yapılamadı; `AdminPermissionPolicy` kural kapsamı `RbacCoverageTest`'e bırakıldı (çalıştırılmadı).
- `docs/ENCRYPTION.md`, `KEY_MANAGEMENT.md`, `RUNBOOK.md`, `docs/design/INDEX.md` (93 satır, 70 dosya) kod karşılaştırması yapılmadı; yalnız dosya referansları kontrol edildi (kırık yok).
- Duman/yük betikleri koşulmadı; `scripts/openapi-check.js` çalıştırılmadı (A17-05 canlı farkla ayrıca kanıtlandı).
- Üretim sunucusuna, `.env`/`.deploy.env` gerçek sırlarına bakılmadı.
