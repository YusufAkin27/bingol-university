# Backend Haritası (BACKEND_MAP)

Bu belge backend kaynak kodundan **otomatik üretilir**; elle düzenlemeyin. Amaç: projeye yeni giren kişinin ya da ajanın "hangi modül nerede, neye bağlı, hangi uçları ve tabloları var" sorusuna dosya açmadan cevap bulması.

- Kaynak: `deploy/be-257-20261111` dalı, commit `3d0d5490` (canlıdaki backend hattı; `main` bu hattan ayrışmıştır, bkz. CLAUDE.md).
- Ham veriyi yeniden üretmek için: `python -I -X utf8 scripts/backend-map.py <repo-kökü> docs/backend-map.json`. Bu Markdown belgesi aynı JSON'dan türetilir; üretici betik yalnız JSON'u yazar.
- Ham veri: [backend-map.json](backend-map.json) (modül başına tüm uçlar, tablolar, işler, bağımlılık ağırlıkları).
- Etkileşimli ağ grafiği: https://claude.ai/artifact/WC1PeN3HVGRGBPgFBaoniT (özel; sahibi paylaşmadıkça başkası açamaz).

## Özet

| Modül | Java dosyası | HTTP ucu | Tablo/varlık | Zamanlanmış iş | Migration | Modül bağı |
|---|---|---|---|---|---|---|
| 38 | 1239 | 783 | 125 | 62 | 169 (en yüksek V1873) | 290 |

## Nasıl okunur

- **Bağlı olduğu**: bu modülün Java `import` ile doğrudan kullandığı diğer modüller. Parantezdeki sayı, import yapan dosya sayısıdır (bağın gücü).
- **Kullanan**: bu modülü import eden modüller. Sayı büyükse modül merkezîdir; değiştirirken etki alanı geniştir.
- Import olmayan bağlar burada görünmez: Spring olayları (`@EventListener`), SPI uygulamaları (`ReportTargetHandler`, `SearchProvider`, `DataExporter`) ve `NotificationService` üzerinden gönderilen bildirimler.

## En merkezî modüller (en çok kullanılan)

| Modül | Kullanan modül sayısı | Bağlı olduğu modül sayısı | Dosya |
|---|---|---|---|
| `common` | 34 | 5 | 29 |
| `i18n` | 23 | 1 | 3 |
| `config` | 21 | 9 | 27 |
| `user` | 20 | 0 | 4 |
| `admin` | 19 | 20 | 76 |
| `notification` | 18 | 11 | 77 |
| `export` | 14 | 6 | 4 |
| `moderation` | 13 | 11 | 66 |
| `profile` | 12 | 15 | 33 |
| `media` | 11 | 4 | 30 |
| `auth` | 8 | 13 | 73 |
| `community` | 7 | 13 | 74 |

## Modül tablosu

| Modül | Dosya | Uç | Tablo | İş | Bağlı olduğu | Kullanan | Dış sistemler |
|---|---|---|---|---|---|---|---|
| `academic` | 22 | 37 | 0 | 2 | 8 | 5 | Redis |
| `accessban` | 24 | 13 | 2 | 2 | 8 | 6 | PostgreSQL, Redis |
| `admin` | 76 | 69 | 1 | 0 | 20 | 19 | PostgreSQL, Redis |
| `analytics` | 20 | 16 | 0 | 0 | 6 | 4 | Redis |
| `appinfo` | 6 | 6 | 1 | 0 | 3 | 5 | PostgreSQL, Redis |
| `auth` | 73 | 32 | 3 | 2 | 13 | 8 | PostgreSQL, Google/Apple OAuth, Redis |
| `bookmark` | 8 | 7 | 1 | 0 | 3 | 0 | PostgreSQL, Redis |
| `catalog` | 2 | 2 | 0 | 0 | 2 | 6 | Redis |
| `common` | 29 | 1 | 0 | 1 | 5 | 34 | PostgreSQL, Dosya deposu, Redis |
| `community` | 74 | 86 | 11 | 1 | 13 | 7 | PostgreSQL, Dosya deposu, Redis |
| `config` | 27 | 0 | 0 | 0 | 9 | 21 | Redis |
| `crash` | 8 | 6 | 0 | 2 | 7 | 0 | Redis |
| `crypto` | 20 | 2 | 0 | 0 | 2 | 3 | Redis |
| `dbmaint` | 14 | 9 | 2 | 2 | 5 | 5 | PostgreSQL, Redis |
| `devseed` | 3 | 0 | 0 | 0 | 4 | 0 | Dosya deposu |
| `event` | 86 | 100 | 12 | 3 | 14 | 4 | PostgreSQL, Redis |
| `export` | 4 | 1 | 0 | 0 | 6 | 14 | Redis |
| `forum` | 142 | 58 | 17 | 3 | 15 | 0 | PostgreSQL, Redis |
| `health` | 1 | 1 | 0 | 0 | 0 | 0 | - |
| `i18n` | 3 | 0 | 0 | 0 | 1 | 23 | - |
| `legal` | 10 | 8 | 0 | 0 | 3 | 5 | PostgreSQL, Redis |
| `mail` | 51 | 35 | 5 | 4 | 7 | 5 | PostgreSQL, Kaynak siteler, Redis, SMTP |
| `media` | 30 | 3 | 0 | 2 | 4 | 11 | Redis |
| `menu` | 25 | 8 | 4 | 4 | 8 | 2 | PostgreSQL, Kaynak siteler, Redis |
| `messaging` | 73 | 53 | 8 | 7 | 20 | 5 | PostgreSQL, Redis, WebSocket/STOMP |
| `moderation` | 66 | 41 | 2 | 2 | 11 | 13 | PostgreSQL, Redis |
| `news` | 13 | 3 | 1 | 1 | 6 | 7 | PostgreSQL, Kaynak siteler, Redis |
| `notification` | 77 | 43 | 4 | 7 | 11 | 18 | PostgreSQL, FCM, Redis |
| `observability` | 16 | 8 | 0 | 2 | 7 | 5 | Redis |
| `poll` | 23 | 18 | 4 | 2 | 11 | 1 | PostgreSQL, Redis |
| `post` | 106 | 53 | 12 | 10 | 12 | 7 | PostgreSQL, Redis |
| `profile` | 33 | 15 | 2 | 1 | 15 | 12 | PostgreSQL, Redis |
| `search` | 11 | 2 | 0 | 0 | 3 | 6 | Redis |
| `share` | 8 | 2 | 0 | 0 | 10 | 2 | Redis |
| `status` | 7 | 1 | 0 | 0 | 2 | 5 | PostgreSQL |
| `support` | 29 | 35 | 0 | 1 | 9 | 1 | PostgreSQL, Redis |
| `unitnews` | 15 | 9 | 3 | 1 | 7 | 1 | PostgreSQL, Kaynak siteler, Redis |
| `user` | 4 | 0 | 1 | 0 | 0 | 20 | PostgreSQL |

## Modül künyeleri

### academic

`backend/src/main/java/edu/bingol/backend/academic/` · 22 dosya, 3594 satır
- Bağlı olduğu: `common` (10), `moderation` (3), `config` (2), `profile` (1), `notification` (1), `export` (1), `dbmaint` (1), `catalog` (1)
- Kullanan: `unitnews` (3), `poll` (3), `admin` (2), `notification` (1), `messaging` (1)
- Dış sistemler: Redis
- Controller'lar: `TimetableController` `/api` (19 uç); `AcademicController` `/api` (10 uç); `OfficialTimetableController` `/api` (8 uç)
- Zamanlanmış işler: `AcademicRetentionJob.nightly` (cron = "${app.academic.retention-cron:0 30 3 * * *}", zone = "Europe/Istanbul"); `ExamReminderJob.scheduled` (fixedDelayString = "${app.exam-reminder.poll-ms:60000}", initialDelayString = "${app.exam-reminder.initial-del)

### accessban

`backend/src/main/java/edu/bingol/backend/accessban/` · 24 dosya, 2589 satır
- Bağlı olduğu: `common` (4), `user` (1), `i18n` (1), `export` (1), `dbmaint` (1), `config` (1), `auth` (1), `admin` (1)
- Kullanan: `auth` (6), `moderation` (2), `messaging` (2), `notification` (1), `crash` (1), `config` (1)
- Dış sistemler: PostgreSQL, Redis
- Controller'lar: `AdminAccessBanController` `/api/admin` (13 uç)
- Tablolar: `ban280_anonymizer_range`, `user_device_log`
- Zamanlanmış işler: `AccessBanHits.flushScheduled` (fixedDelayString = "${app.security.ban-flush-ms:5000}"); `AccessBanRetentionJob.scheduled` (cron = "${app.security.ban-log-cleanup-cron:0 30 4 * * *}", zone = "Europe/Istanbul")
- Filtreler: `AccessBanFilter`

### admin

`backend/src/main/java/edu/bingol/backend/admin/` · 76 dosya, 8908 satır
- Alt paketler: `bulk`, `chat`, `chat/action`, `pii`, `rbac`, `twofactor`, `users`, `users/extras`
- Bağlı olduğu: `common` (41), `user` (19), `auth` (10), `news` (5), `config` (5), `profile` (4), `notification` (4), `menu` (4), `crypto` (4), `messaging` (3), `i18n` (3), `moderation` (2), `analytics` (2), `academic` (2), `status` (1), `observability` (1), `media` (1), `mail` (1), `legal` (1), `export` (1)
- Kullanan: `mail` (7), `event` (7), `community` (7), `moderation` (6), `support` (5), `post` (5), `notification` (3), `dbmaint` (3), `poll` (2), `forum` (2), `crash` (2), `config` (2), `analytics` (2), `unitnews` (1), `messaging` (1), `menu` (1), `common` (1), `appinfo` (1), `accessban` (1)
- Dış sistemler: PostgreSQL, Redis
- Controller'lar: `AdminBulkController` `/api/admin` (10 uç); `AdminUserController` `/api/admin` (9 uç); `AdminChatActionController` `/api/admin` (9 uç); `RbacController` `/api/admin/rbac` (8 uç); `AdminUserExtrasController` `/api/admin` (8 uç); `AdminOpsController` `/api/admin/ops` (4 uç); `AdminPendingRegistrationController` `/api/admin/pending-registrations` (4 uç); `AuditController` `/api/admin` (3 uç); `AdminChatFeedController` `/api/admin` (3 uç); `AdminTwoFactorController` `/api/admin` (3 uç); `AdminLegalController` `/api/admin/legal` (2 uç); `AdminNewsController` `/api/admin/news` (2 uç); `AdminChatViewerController` `/api/admin/users/{userId}/conversations` (2 uç); `AdminUserCreateController` `/api/admin` (1 uç); `AdminReportContextController` `/api/admin/reports` (1 uç)
- Tablolar: `admin_profile_change`
- Filtreler: `AdminPathGuardFilter`, `AdminReasonFilter`

### analytics

`backend/src/main/java/edu/bingol/backend/analytics/` · 20 dosya, 2413 satır
- Alt paketler: `behavior`
- Bağlı olduğu: `common` (6), `status` (2), `notification` (2), `admin` (2), `i18n` (1), `export` (1)
- Kullanan: `admin` (2), `profile` (1), `dbmaint` (1), `config` (1)
- Dış sistemler: Redis
- Controller'lar: `AdminAnalyticsController` `/api/admin/analytics` (9 uç); `BehaviorController` `/api/admin/analytics/behavior` (6 uç); `AnalyticsController` `/api/analytics` (1 uç)

### appinfo

`backend/src/main/java/edu/bingol/backend/appinfo/` · 6 dosya, 699 satır
- Bağlı olduğu: `common` (3), `i18n` (2), `admin` (1)
- Kullanan: `support` (1), `profile` (1), `menu` (1), `legal` (1), `event` (1)
- Dış sistemler: PostgreSQL, Redis
- Controller'lar: `AppInfoController` `/api` (4 uç); `AppVersionAdminController` `/api/admin/app-versions` (2 uç)
- Tablolar: `app_setting`

### auth

`backend/src/main/java/edu/bingol/backend/auth/` · 73 dosya, 7447 satır
- Alt paketler: `dto`, `jwt`, `oauth`, `realemail`, `session`, `token`, `twofactor`
- Bağlı olduğu: `common` (22), `i18n` (14), `config` (12), `user` (10), `accessban` (6), `mail` (5), `profile` (4), `observability` (4), `export` (3), `notification` (2), `moderation` (2), `legal` (1), `catalog` (1)
- Kullanan: `admin` (10), `messaging` (3), `profile` (2), `common` (2), `notification` (1), `moderation` (1), `config` (1), `accessban` (1)
- Dış sistemler: PostgreSQL, Google/Apple OAuth, Redis
- Controller'lar: `AuthController` `/api/auth` (15 uç); `TwoFactorController` `/api/auth` (8 uç); `OAuthController` `/api/auth/oauth` (5 uç); `RealEmailController` `/api/users/me/email` (2 uç); `SessionController` `/api/auth/sessions` (2 uç)
- Tablolar: `auth_identity`, `two_factor_device`, `user_session`
- Zamanlanmış işler: `DeferredVerificationJob.scheduledSend` (fixedDelayString = "${app.auth.deferred-verification.poll-ms:3600000}", initialDelayString = "${app.auth.defer); `DeferredVerificationJob.scheduledPurge` (cron = "${app.auth.deferred-verification.purge-cron:0 20 3 * * *}", zone = "Europe/Istanbul")
- Filtreler: `ProfileIncompleteWriteFilter`, `UnverifiedWriteFilter`, `JwtAuthFilter`, `RealEmailRequiredWriteFilter`

### bookmark

`backend/src/main/java/edu/bingol/backend/bookmark/` · 8 dosya, 546 satır
- Alt paketler: `dto`
- Bağlı olduğu: `news` (4), `common` (3), `post` (1)
- Dış sistemler: PostgreSQL, Redis
- Controller'lar: `BookmarkController` `/api/bookmarks` (7 uç)
- Tablolar: `bookmark`

### catalog

`backend/src/main/java/edu/bingol/backend/catalog/` · 2 dosya, 283 satır
- Bağlı olduğu: `common` (2), `i18n` (1)
- Kullanan: `profile` (2), `messaging` (1), `mail` (1), `community` (1), `auth` (1), `academic` (1)
- Dış sistemler: Redis
- Controller'lar: `CatalogController` `/api/catalog` (2 uç)

### common

`backend/src/main/java/edu/bingol/backend/common/` · 29 dosya, 2784 satır
- Alt paketler: `cache`, `storage`, `web`
- Bağlı olduğu: `i18n` (5), `config` (3), `auth` (2), `media` (1), `admin` (1)
- Kullanan: `admin` (41), `forum` (34), `community` (34), `post` (25), `event` (24), `messaging` (23), `auth` (22), `moderation` (19), `notification` (14), `mail` (14), `support` (12), `menu` (10), `academic` (10), `profile` (9), `media` (7), `unitnews` (6), `analytics` (6), `search` (5), `poll` (5), `dbmaint` (4), `crash` (4), `accessban` (4), `news` (3), `legal` (3), `bookmark` (3), `appinfo` (3), `status` (2), `share` (2), `crypto` (2), `config` (2), `catalog` (2), `observability` (1), `export` (1), `devseed` (1)
- Dış sistemler: PostgreSQL, Dosya deposu, Redis
- Controller'lar: `FileController` `/` (1 uç); `ApiErrorController` `/` (0 uç)
- Zamanlanmış işler: `IdempotentCreate.scheduledCleanup` (cron = "${app.idempotency.cleanup-cron:0 40 3 * * *}", zone = "Europe/Istanbul")
- Filtreler: `IdempotencyFilter`, `RequestBodyLimitFilter`

### community

`backend/src/main/java/edu/bingol/backend/community/` · 74 dosya, 8086 satır
- Alt paketler: `admin`, `category`, `dto`, `extras`, `permissions`
- Bağlı olduğu: `common` (34), `user` (9), `notification` (8), `messaging` (7), `admin` (7), `moderation` (6), `media` (5), `export` (2), `search` (1), `profile` (1), `i18n` (1), `config` (1), `catalog` (1)
- Kullanan: `event` (33), `poll` (10), `post` (2), `messaging` (2), `forum` (2), `share` (1), `notification` (1)
- Dış sistemler: PostgreSQL, Dosya deposu, Redis
- Controller'lar: `CommunityController` `/api` (23 uç); `ClubAdminController` `/api/admin/communities` (19 uç); `ClubPermissionController` `/api` (15 uç); `ClubExtrasController` `/api/communities/{id}` (12 uç); `ClubContentAdminController` `/api/admin/community-posts` (6 uç); `CommunityCategoryAdminController` `/api/admin/community-categories` (6 uç); `CommunityAdminController` `/api/admin/communities` (3 uç); `ClubJoinCodeController` `/api` (2 uç); `ClubChatController` `/` (1 uç)
- Tablolar: `club_audit`, `club_invite`, `club_join_answer`, `club_join_question`, `club_member_grant`, `club_ownership_transfer`, `community`, `community_audience`, `community_category`, `community_member`, `community_post`
- Zamanlanmış işler: `ClubExtrasMaintenance.scheduledRun` (fixedDelayString = "${app.chat.room-purge-ms:300000}", initialDelayString = "${app.chat.room-purge-ms:300000}")
- SPI uygulamaları: `ReportTargetHandler: CommunityReportHandlers`, `SearchProvider: CommunitySearchProvider`

### config

`backend/src/main/java/edu/bingol/backend/config/` · 27 dosya, 2028 satır
- Bağlı olduğu: `common` (2), `admin` (2), `notification` (1), `media` (1), `mail` (1), `legal` (1), `auth` (1), `analytics` (1), `accessban` (1)
- Kullanan: `auth` (12), `post` (10), `media` (7), `mail` (7), `observability` (5), `admin` (5), `forum` (3), `common` (3), `support` (2), `menu` (2), `event` (2), `dbmaint` (2), `crash` (2), `academic` (2), `unitnews` (1), `poll` (1), `notification` (1), `news` (1), `messaging` (1), `community` (1), `accessban` (1)
- Dış sistemler: Redis
- Filtreler: `BasicAuthThrottleFilter`

### crash

`backend/src/main/java/edu/bingol/backend/crash/` · 8 dosya, 1071 satır
- Bağlı olduğu: `common` (4), `config` (2), `admin` (2), `user` (1), `observability` (1), `notification` (1), `accessban` (1)
- Dış sistemler: Redis
- Controller'lar: `CrashAdminController` `/api/admin/crashes` (5 uç); `CrashReportController` `/api/app` (1 uç)
- Zamanlanmış işler: `CrashAlertService.scheduled` (fixedDelay = 120_000, initialDelay = 150_000); `CrashService.scheduledFlush` (fixedDelay = 60_000, initialDelay = 90_000)

### crypto

`backend/src/main/java/edu/bingol/backend/crypto/` · 20 dosya, 1356 satır
- Bağlı olduğu: `common` (2), `media` (1)
- Kullanan: `admin` (4), `messaging` (3), `media` (1)
- Dış sistemler: Redis
- Controller'lar: `AdminCryptoController` `/api/admin` (2 uç)

### dbmaint

`backend/src/main/java/edu/bingol/backend/dbmaint/` · 14 dosya, 2099 satır
- Alt paketler: `admin`
- Bağlı olduğu: `common` (4), `admin` (3), `config` (2), `observability` (1), `analytics` (1)
- Kullanan: `observability` (1), `messaging` (1), `forum` (1), `accessban` (1), `academic` (1)
- Dış sistemler: PostgreSQL, Redis
- Controller'lar: `RetentionAdminController` `/api/admin` (9 uç)
- Tablolar: `data_export_receipt`, `data_purge_log`
- Zamanlanmış işler: `DbMaintenanceJob.nightly` (cron = "${app.dbmaint.cron:0 0 3 * * *}", zone = "Europe/Istanbul"); `DbMaintenanceJob.hourlyMailCodeScrub` (cron = "${app.dbmaint.mail-code-scrub-cron:0 10 * * * *}", zone = "Europe/Istanbul")

### devseed

`backend/src/main/java/edu/bingol/backend/devseed/` · 3 dosya, 513 satır
- Bağlı olduğu: `user` (1), `post` (1), `messaging` (1), `common` (1)
- Dış sistemler: Dosya deposu

### event

`backend/src/main/java/edu/bingol/backend/event/` · 86 dosya, 9980 satır
- Alt paketler: `admin`, `admission`, `chat`, `dto`, `extras`
- Bağlı olduğu: `community` (33), `common` (24), `user` (11), `notification` (8), `moderation` (7), `admin` (7), `messaging` (6), `export` (3), `profile` (2), `news` (2), `media` (2), `config` (2), `search` (1), `appinfo` (1)
- Kullanan: `notification` (2), `share` (1), `profile` (1), `messaging` (1)
- Dış sistemler: PostgreSQL, Redis
- Controller'lar: `EventController` `/api` (31 uç); `EventAdminOpsController` `/api/admin/events` (18 uç); `EventAdmissionController` `/api` (16 uç); `EventExtrasController` `/api` (15 uç); `EventAdminController` `/api/admin/events` (9 uç); `EventModeratorController` `/api` (5 uç); `EventChatController` `/api/events/{id}/chat-room` (5 uç); `EventChatController` `/` (1 uç)
- Tablolar: `event_admission`, `event_announcement`, `event_application`, `event_attendance`, `event_certificate`, `event_co_organizer`, `event_feedback`, `event_moderation_log`, `event_moderator`, `event_rsvp`, `event_series_member`, `user_event`
- Zamanlanmış işler: `EventGoingCountReconciler.nightly` (cron = "${app.event.going-reconcile-cron:0 20 3 * * *}", zone = "Europe/Istanbul"); `EventReminderService.scheduled` (fixedDelayString = "${events.reminder.delay-ms:60000}", initialDelayString = "${events.reminder.initial-delay-); `EventChatMaintenance.scheduledRun` (fixedDelayString = "${app.chat.room-purge-ms:300000}", initialDelayString = "${app.chat.room-purge-ms:300000}")
- SPI uygulamaları: `ReportTargetHandler: EventCoverReportHandler`, `ReportTargetHandler: EventReportHandler`, `SearchProvider: EventSearchProvider`

### export

`backend/src/main/java/edu/bingol/backend/export/` · 4 dosya, 280 satır
- Bağlı olduğu: `support` (1), `profile` (1), `notification` (1), `moderation` (1), `legal` (1), `common` (1)
- Kullanan: `post` (3), `messaging` (3), `event` (3), `auth` (3), `notification` (2), `forum` (2), `community` (2), `profile` (1), `poll` (1), `moderation` (1), `analytics` (1), `admin` (1), `accessban` (1), `academic` (1)
- Dış sistemler: Redis
- Controller'lar: `DataExportController` `/api` (1 uç)

### forum

`backend/src/main/java/edu/bingol/backend/forum/` · 142 dosya, 10758 satır
- Alt paketler: `admin`, `category`, `comment`, `comment/spi`, `media`, `moderation`, `moderation/spi`, `notify`, `notify/spi`, `poll`, `poll/spi`, `profile`, `search`, `share`, `topic`, `topic/dto`, `topic/spi`
- Bağlı olduğu: `common` (34), `moderation` (13), `i18n` (7), `user` (4), `post` (3), `config` (3), `share` (2), `search` (2), `profile` (2), `notification` (2), `media` (2), `export` (2), `community` (2), `admin` (2), `dbmaint` (1)
- Dış sistemler: PostgreSQL, Redis
- Controller'lar: `ForumTopicController` `/api/forum/topics` (12 uç); `ForumAdminController` `/api/admin/forum` (11 uç); `ForumCommentController` `/api/forum` (10 uç); `ForumProfileController` `/api/forum` (7 uç); `ForumMediaController` `/` (3 uç); `ForumMuteController` `/api/forum/mutes` (3 uç); `ForumPollController` `/api/forum/topics/{topicId}/poll` (3 uç); `ForumBlockAuthorController` `/api/forum` (2 uç); `ForumModerationController` `/api/forum` (2 uç); `ForumNotificationPrefController` `/api/forum/notification-prefs` (2 uç); `ForumSearchController` `/api/forum/search` (2 uç); `ForumCategoryController` `/api/forum/categories` (1 uç)
- Tablolar: `forum_anon_alias`, `forum_bookmark`, `forum_category`, `forum_category_group`, `forum_comment`, `forum_comment_like`, `forum_media`, `forum_moderation_action`, `forum_notification_pref`, `forum_poll`, `forum_poll_option`, `forum_poll_vote`, `forum_topic`, `forum_topic_follow`, `forum_topic_image`, `forum_topic_like`, `forum_user_mute`
- Zamanlanmış işler: `ForumMediaJanitor.unattached` (cron = "${app.forum.media.cleanup-cron:0 35 * * * *}", zone = "Europe/Istanbul"); `ForumMediaJanitor.deleted` (cron = "${app.forum.media.deleted-cleanup-cron:0 50 4 * * *}", zone = "Europe/Istanbul"); `ForumNotifyCleanupJob.scheduled` (cron = "${app.forum.notify-cleanup-cron:0 40 3 * * *}", zone = "Europe/Istanbul")
- SPI uygulamaları: `ReportTargetHandler: ForumReportHandlers`, `SearchProvider: ForumSearchProvider`

### health

`backend/src/main/java/edu/bingol/backend/health/` · 1 dosya, 17 satır
- Controller'lar: `HelloController` `/api` (1 uç)

### i18n

`backend/src/main/java/edu/bingol/backend/i18n/` · 3 dosya, 127 satır
- Bağlı olduğu: `user` (1)
- Kullanan: `mail` (14), `auth` (14), `forum` (7), `common` (5), `support` (4), `notification` (4), `poll` (3), `moderation` (3), `legal` (3), `admin` (3), `status` (2), `share` (2), `profile` (2), `post` (2), `observability` (2), `appinfo` (2), `news` (1), `messaging` (1), `menu` (1), `community` (1), `catalog` (1), `analytics` (1), `accessban` (1)

### legal

`backend/src/main/java/edu/bingol/backend/legal/` · 10 dosya, 818 satır
- Bağlı olduğu: `i18n` (3), `common` (3), `appinfo` (1)
- Kullanan: `profile` (1), `export` (1), `config` (1), `auth` (1), `admin` (1)
- Dış sistemler: PostgreSQL, Redis
- Controller'lar: `LegalController` `/api` (8 uç)
- Filtreler: `LegalReacceptFilter`

### mail

`backend/src/main/java/edu/bingol/backend/mail/` · 51 dosya, 5862 satır
- Alt paketler: `admin`, `campaign`
- Bağlı olduğu: `i18n` (14), `common` (14), `config` (7), `admin` (7), `user` (2), `observability` (2), `catalog` (1)
- Kullanan: `auth` (5), `support` (1), `observability` (1), `config` (1), `admin` (1)
- Dış sistemler: PostgreSQL, Kaynak siteler, Redis, SMTP
- Controller'lar: `MailTemplateAdminController` `/api/admin/mail` (12 uç); `MailOpsAdminController` `/api/admin/mail` (11 uç); `MailCampaignAdminController` `/api/admin/mail/campaigns` (10 uç); `MailUnsubscribeController` `/api/public/mail` (2 uç)
- Tablolar: `mail_campaign`, `mail_outbox`, `mail_suppression`, `mail_template_custom`, `mail_template_custom_version`
- Zamanlanmış işler: `MailQueueWorker.poll` (fixedDelayString = "${app.mail.queue-poll-ms:5000}"); `MailQueueWorker.purgeOld` (cron = "0 40 3 * * *", zone = "Europe/Istanbul"); `MailCampaignDispatcher.poll` (fixedDelayString = "${app.mail.campaign-poll-ms:10000}"); `MailCampaignDispatcher.purgeOld` (cron = "0 20 3 * * *", zone = "Europe/Istanbul")

### media

`backend/src/main/java/edu/bingol/backend/media/` · 30 dosya, 3453 satır
- Alt paketler: `transcode`
- Bağlı olduğu: `config` (7), `common` (7), `post` (3), `crypto` (1)
- Kullanan: `community` (5), `forum` (2), `event` (2), `profile` (1), `post` (1), `messaging` (1), `menu` (1), `crypto` (1), `config` (1), `common` (1), `admin` (1)
- Dış sistemler: Redis
- Controller'lar: `PrivateMediaController` `/` (1 uç); `AdminTranscodeController` `/api/admin/ops/transcode` (1 uç); `PostMediaCdnController` `/` (1 uç)
- Zamanlanmış işler: `MediaOrphanSweeper.scheduled` (cron = "${app.media.sweep-cron:0 30 3 * * *}", zone = "Europe/Istanbul"); `TranscodeWorker.tick` (fixedDelayString = "${app.media.transcode.poll-ms:5000}", initialDelayString = "${app.media.transcode.initial-)

### menu

`backend/src/main/java/edu/bingol/backend/menu/` · 25 dosya, 1691 satır
- Alt paketler: `dto`
- Bağlı olduğu: `common` (10), `config` (2), `status` (1), `notification` (1), `media` (1), `i18n` (1), `appinfo` (1), `admin` (1)
- Kullanan: `admin` (4), `poll` (3)
- Dış sistemler: PostgreSQL, Kaynak siteler, Redis
- Controller'lar: `MenuAdminController` `/api/admin/menu` (5 uç); `MenuController` `/api` (3 uç)
- Tablolar: `daily_menu_push_log`, `menu_content_image`, `menu_dish_calorie`, `menu_item_calorie`
- Zamanlanmış işler: `MealMenuNotifier.scheduled` (cron = "${app.push.daily-menu-cron:0 30 11 * * *}", zone = "Europe/Istanbul"); `MealMenuNotifier.catchUp` (cron = "${app.push.daily-menu-catchup-cron:0 0/15 11-13 * * *}", zone = "Europe/Istanbul"); `MenuSyncService.scheduledSync` (cron = "${menu.sync.cron:0 30 23 L * *}", zone = "Europe/Istanbul"); `MenuSyncService.scheduledCatchUp` (cron = "${menu.catchup.cron:-}", zone = "Europe/Istanbul")

### messaging

`backend/src/main/java/edu/bingol/backend/messaging/` · 73 dosya, 10481 satır
- Alt paketler: `dto`, `media`, `room`, `room/dept`, `room/notice`, `ws`
- Bağlı olduğu: `common` (23), `moderation` (13), `user` (10), `share` (3), `profile` (3), `export` (3), `crypto` (3), `auth` (3), `notification` (2), `community` (2), `accessban` (2), `unitnews` (1), `media` (1), `i18n` (1), `event` (1), `dbmaint` (1), `config` (1), `catalog` (1), `admin` (1), `academic` (1)
- Kullanan: `community` (7), `event` (6), `admin` (3), `profile` (1), `devseed` (1)
- Dış sistemler: PostgreSQL, Redis, WebSocket/STOMP
- Controller'lar: `ConversationController` `/api/conversations` (19 uç); `MessageController` `/api` (11 uç); `MessageMediaController` `/api/conversations/{cid}/media` (6 uç); `RoomNoticeController` `/api/conversations/{cid}/notices` (6 uç); `DepartmentChatController` `/api/department-chat` (4 uç); `ClientStateController` `/api` (3 uç); `DepartmentChatAdminController` `/api/admin/department-chats` (2 uç); `MessageInfoController` `/api/messages` (1 uç); `AdminMediaPreviewController` `/api/admin/media/attachments` (1 uç); `ChatWsController` `/` (0 uç)
- Tablolar: `chat_room_link`, `conversation_add_ban`, `conversation_member`, `department_chat_room`, `message_attachment`, `message_attachment_view`, `message_reaction`, `room_notice`
- Zamanlanmış işler: `DeletedMessageRetention.scheduledPurge` (cron = "${app.chat.deleted-retention-cron:0 40 3 * * *}", zone = "Europe/Istanbul"); `MessageEncryptionMigrator.scheduled` (initialDelayString = "${app.crypto.migrate-initial-delay-ms:15000}", fixedDelayString = "${app.crypto.migrate-); `ChatMediaMaintenance.scheduled` (cron = "${app.chat.media.cleanup-cron:0 15 * * * *}", zone = "Europe/Istanbul"); `ChatMediaMaintenance.purgeViewOnce` (cron = "${app.chat.media.view-once-cron:0 30 * * * *}", zone = "Europe/Istanbul"); `RoomMaintenance.scheduledPurge` (fixedDelayString = "${app.chat.room-purge-ms:300000}", initialDelayString = "${app.chat.room-purge-ms:300000}"); `PresenceService.refreshLocal` (fixedDelay = 10_000); `TokenExpiryGuard.sweep` (fixedDelay = 30_000)
- SPI uygulamaları: `ReportTargetHandler: MessageReportHandler`, `ReportTargetHandler: MessageImageReportHandler`, `ReportTargetHandler: RoomNoticeReportHandler`

### moderation

`backend/src/main/java/edu/bingol/backend/moderation/` · 66 dosya, 5464 satır
- Alt paketler: `admin`, `dto`, `profanity`
- Bağlı olduğu: `common` (19), `user` (11), `admin` (6), `i18n` (3), `notification` (2), `accessban` (2), `profile` (1), `post` (1), `news` (1), `export` (1), `auth` (1)
- Kullanan: `post` (13), `messaging` (13), `forum` (13), `event` (7), `community` (6), `profile` (3), `academic` (3), `poll` (2), `auth` (2), `admin` (2), `support` (1), `share` (1), `export` (1)
- Dış sistemler: PostgreSQL, Redis
- Controller'lar: `ModerationAdminController` `/api/admin` (9 uç); `AdminModerationExtrasController` `/api/admin/moderation` (8 uç); `ProfanityAdminController` `/api/admin/profanity` (8 uç); `AdminModerationController` `/api/admin` (7 uç); `BlockController` `/api/users` (3 uç); `AppealController` `/api/appeals` (2 uç); `ReportController` `/api/reports` (2 uç); `ModerationExportController` `/api/admin` (2 uç)
- Tablolar: `account_delete_hold`, `violation_ledger`
- Zamanlanmış işler: `ViolationLedgerService.purgeExpired` (cron = "0 40 4 * * *", zone = "Europe/Istanbul"); `ProfanityHitLogger.purgeOld` (cron = "0 30 4 * * *", zone = "Europe/Istanbul")
- SPI uygulamaları: `ReportTargetHandler: ConversationReportHandler`, `ReportTargetHandler: SmokeReportTargetHandler`, `ReportTargetHandler: UserReportHandler`

### news

`backend/src/main/java/edu/bingol/backend/news/` · 13 dosya, 1050 satır
- Alt paketler: `dto`
- Bağlı olduğu: `common` (3), `status` (1), `search` (1), `notification` (1), `i18n` (1), `config` (1)
- Kullanan: `admin` (5), `bookmark` (4), `search` (2), `event` (2), `unitnews` (1), `share` (1), `moderation` (1)
- Dış sistemler: PostgreSQL, Kaynak siteler, Redis
- Controller'lar: `NewsController` `/api` (3 uç)
- Tablolar: `news_item`
- Zamanlanmış işler: `NewsSyncService.scheduledSync` (cron = "${news.sync.cron:0 0 0 * * *}", zone = "Europe/Istanbul")

### notification

`backend/src/main/java/edu/bingol/backend/notification/` · 77 dosya, 8371 satır
- Alt paketler: `admin`, `campaign`, `dto`, `fcm`, `live`, `outbox`
- Bağlı olduğu: `common` (14), `i18n` (4), `admin` (3), `export` (2), `event` (2), `user` (1), `config` (1), `community` (1), `auth` (1), `accessban` (1), `academic` (1)
- Kullanan: `event` (8), `community` (8), `support` (4), `post` (4), `admin` (4), `observability` (3), `moderation` (2), `messaging` (2), `forum` (2), `auth` (2), `analytics` (2), `poll` (1), `news` (1), `menu` (1), `export` (1), `crash` (1), `config` (1), `academic` (1)
- Dış sistemler: PostgreSQL, FCM, Redis
- Controller'lar: `NotificationController` `/api` (12 uç); `CampaignController` `/api/admin/push` (11 uç); `PushOpsController` `/api/admin` (8 uç); `NotificationMuteController` `/` (5 uç); `LiveActivityController` `/api/live-activities` (3 uç); `PushFcmAdminController` `/api/admin/push/fcm` (2 uç); `PushOutboxAdminController` `/api/admin/push/outbox` (2 uç)
- Tablolar: `live_activity`, `notification_mute`, `notification_subtype_pref`, `push_outbox`
- Zamanlanmış işler: `DeviceCleanupJob.scheduled` (cron = "${app.push.device-cleanup-cron:0 0 4 * * *}", zone = "Europe/Istanbul"); `NotificationRetentionJob.scheduled` (cron = "${app.notification.retention-cron:0 30 3 * * *}", zone = "Europe/Istanbul"); `CampaignService.dispatchDue` (fixedDelayString = "${app.push.poll-ms:10000}"); `CampaignService.recoverStale` (fixedDelayString = "${app.push.campaign-recover-ms:60000}"); `LiveActivityService.cleanup` (cron = "0 17 * * * *", zone = "Europe/Istanbul"); `PushOutboxWorker.poll` (fixedDelayString = "${app.push.outbox.poll-ms:5000}"); `PushOutboxWorker.purgeOld` (cron = "${app.push.outbox.cleanup-cron:0 20 3 * * *}", zone = "Europe/Istanbul")

### observability

`backend/src/main/java/edu/bingol/backend/observability/` · 16 dosya, 2079 satır
- Bağlı olduğu: `config` (5), `notification` (3), `user` (2), `i18n` (2), `mail` (1), `dbmaint` (1), `common` (1)
- Kullanan: `auth` (4), `mail` (2), `dbmaint` (1), `crash` (1), `admin` (1)
- Dış sistemler: Redis
- Controller'lar: `SystemOverviewController` `/api/admin/system` (8 uç)
- Zamanlanmış işler: `StorageAlertJob.scheduled` (fixedDelayString = "${app.observability.storage-check-ms:900000}", initialDelay = 180_000); `SystemAlertService.scheduled` (fixedDelay = 60_000, initialDelay = 120_000)
- Filtreler: `RequestIdFilter`

### poll

`backend/src/main/java/edu/bingol/backend/poll/` · 23 dosya, 2902 satır
- Bağlı olduğu: `community` (10), `user` (5), `common` (5), `menu` (3), `i18n` (3), `academic` (3), `moderation` (2), `admin` (2), `notification` (1), `export` (1), `config` (1)
- Kullanan: `share` (1)
- Dış sistemler: PostgreSQL, Redis
- Controller'lar: `PollController` `/api/polls` (10 uç); `PollAdminController` `/api/admin/polls` (8 uç)
- Tablolar: `poll`, `poll_ballot`, `poll_option`, `poll_vote`
- Zamanlanmış işler: `PollCloseJob.scheduled` (cron = "${app.poll.close-cron:0 */10 * * * *}", zone = "Europe/Istanbul"); `PollCloseJob.ensureMenuPoll` (cron = "0 5 0 * * *", zone = "Europe/Istanbul")
- SPI uygulamaları: `ReportTargetHandler: PollReportHandler`

### post

`backend/src/main/java/edu/bingol/backend/post/` · 106 dosya, 10361 satır
- Alt paketler: `admin`, `comment`, `feed`, `follow`, `like`, `media`, `mention`, `notify`, `popularity`, `reel`, `reels`, `save`, `social`, `spi`
- Bağlı olduğu: `common` (25), `moderation` (13), `config` (10), `user` (9), `profile` (5), `admin` (5), `notification` (4), `export` (3), `search` (2), `i18n` (2), `community` (2), `media` (1)
- Kullanan: `media` (3), `forum` (3), `share` (2), `profile` (1), `moderation` (1), `devseed` (1), `bookmark` (1)
- Dış sistemler: PostgreSQL, Redis
- Controller'lar: `PostController` `/api` (10 uç); `PostCommentController` `/api` (9 uç); `AdminPostController` `/api/admin` (7 uç); `FollowController` `/api/users` (5 uç); `AdminPostCommentController` `/api/admin` (4 uç); `FollowRequestController` `/api/users/me/follow-requests` (4 uç); `PostMediaController` `/` (4 uç); `FeedController` `/api/feed` (3 uç); `PostSaveController` `/api/posts` (3 uç); `PostLikeController` `/api/posts/{id}` (2 uç); `LikedPostsController` `/api/posts` (1 uç); `UserReelsController` `/api` (1 uç)
- Tablolar: `follow_request`, `post`, `post_comment`, `post_comment_like`, `post_like`, `post_media`, `post_mention`, `post_save`, `post_watch`, `user_follow`, `user_follow_stats`, `user_popularity`
- Zamanlanmış işler: `PostCounterRepairJob.scheduled` (cron = "${app.post.counter-repair-cron:0 30 3 * * *}", zone = "Europe/Istanbul"); `PostRankService.scheduled` (fixedDelayString = "${app.post.rank.recompute-ms:300000}", initialDelayString = "${app.post.rank.initial-delay); `PostScoreJob.scheduled` (cron = "${app.post.score-cron:0 5 * * * *}", zone = "Europe/Istanbul"); `PostRetentionJob.scheduled` (cron = "${app.post.retention.cron:0 10 5 * * *}", zone = "Europe/Istanbul"); `CommentCounterRepairJob.scheduled` (cron = "${app.post.comment-repair-cron:0 40 3 * * *}", zone = "Europe/Istanbul"); `FollowRequestJob.scheduled` (fixedDelayString = "${app.follow.request-heal-ms:300000}", initialDelayString = "${app.follow.request-heal-ms:); `PostMediaJanitor.unattached` (cron = "${app.post.media.cleanup-cron:0 25 * * * *}", zone = "Europe/Istanbul"); `PostMediaJanitor.deleted` (cron = "${app.post.media.deleted-cleanup-cron:0 40 4 * * *}", zone = "Europe/Istanbul"); `UserPopularityService.scheduled` (fixedDelayString = "${app.post.popularity.recompute-ms:3600000}", initialDelayString = "${app.post.popularity.); `PostWatchRetentionJob.scheduled` (cron = "${app.post.reels.retention-cron:0 20 5 * * *}", zone = "Europe/Istanbul")
- SPI uygulamaları: `ReportTargetHandler: PostReportHandlers`, `SearchProvider: PostSearchProvider`, `ReportTargetHandler: CommentReportHandler`, `SearchProvider: ReelSearchProvider`

### profile

`backend/src/main/java/edu/bingol/backend/profile/` · 33 dosya, 3515 satır
- Alt paketler: `completeness`, `dto`, `naming`, `onboarding`, `privacy`
- Bağlı olduğu: `common` (9), `user` (7), `moderation` (3), `search` (2), `i18n` (2), `catalog` (2), `auth` (2), `post` (1), `messaging` (1), `media` (1), `legal` (1), `export` (1), `event` (1), `appinfo` (1), `analytics` (1)
- Kullanan: `post` (5), `auth` (4), `admin` (4), `messaging` (3), `forum` (2), `event` (2), `share` (1), `search` (1), `moderation` (1), `export` (1), `community` (1), `academic` (1)
- Dış sistemler: PostgreSQL, Redis
- Controller'lar: `ProfileController` `/api` (9 uç); `OnboardingController` `/api/users` (3 uç); `MeSummaryController` `/api/me` (1 uç); `CompletenessController` `/` (1 uç); `PrivacyController` `/api/users/me/privacy` (1 uç)
- Tablolar: `display_name_history`, `profile_privacy`
- Zamanlanmış işler: `DeletionLedgerReapplier.nightly` (cron = "${app.privacy.deletion-ledger-cron:0 50 3 * * *}", zone = "Europe/Istanbul")
- SPI uygulamaları: `SearchProvider: UserSearchProvider`, `ReportTargetHandler: AvatarReportHandler`

### search

`backend/src/main/java/edu/bingol/backend/search/` · 11 dosya, 518 satır
- Bağlı olduğu: `common` (5), `news` (2), `profile` (1)
- Kullanan: `profile` (2), `post` (2), `forum` (2), `news` (1), `event` (1), `community` (1)
- Dış sistemler: Redis
- Controller'lar: `SearchController` `/api` (1 uç); `SearchSuggestController` `/` (1 uç)
- SPI uygulamaları: `SearchProvider: NewsSearchProvider`

### share

`backend/src/main/java/edu/bingol/backend/share/` · 8 dosya, 1042 satır
- Bağlı olduğu: `post` (2), `i18n` (2), `common` (2), `user` (1), `profile` (1), `poll` (1), `news` (1), `moderation` (1), `event` (1), `community` (1)
- Kullanan: `messaging` (3), `forum` (2)
- Dış sistemler: Redis
- Controller'lar: `SharePageController` `/` (2 uç)

### status

`backend/src/main/java/edu/bingol/backend/status/` · 7 dosya, 281 satır
- Alt paketler: `dto`
- Bağlı olduğu: `i18n` (2), `common` (2)
- Kullanan: `unitnews` (2), `analytics` (2), `news` (1), `menu` (1), `admin` (1)
- Dış sistemler: PostgreSQL
- Controller'lar: `StatusController` `/api` (1 uç)

### support

`backend/src/main/java/edu/bingol/backend/support/` · 29 dosya, 2652 satır
- Alt paketler: `admin`, `faq`, `feedback`, `ticket`
- Bağlı olduğu: `common` (12), `admin` (5), `user` (4), `notification` (4), `i18n` (4), `config` (2), `moderation` (1), `mail` (1), `appinfo` (1)
- Kullanan: `export` (1)
- Dış sistemler: PostgreSQL, Redis
- Controller'lar: `TicketController` `/api` (9 uç); `SupportAdminController` `/api/admin` (7 uç); `FeedbackController` `/api` (7 uç); `FaqController` `/api` (5 uç); `PublicSupportController` `/api/public/support` (5 uç); `SupportExportController` `/api/admin/support` (2 uç)
- Zamanlanmış işler: `PublicSupportService.scheduledCleanup` (cron = "${app.support.cleanup-cron:0 30 3 * * *}", zone = "Europe/Istanbul")

### unitnews

`backend/src/main/java/edu/bingol/backend/unitnews/` · 15 dosya, 1704 satır
- Bağlı olduğu: `common` (6), `academic` (3), `status` (2), `user` (1), `news` (1), `config` (1), `admin` (1)
- Kullanan: `messaging` (1)
- Dış sistemler: PostgreSQL, Kaynak siteler, Redis
- Controller'lar: `UnitNewsAdminController` `/api/admin/unit-news` (7 uç); `UnitNewsController` `/api/news/unit` (2 uç)
- Tablolar: `unit_announcement`, `unit_department`, `unit_source`
- Zamanlanmış işler: `UnitNewsSyncService.scheduledSync` (cron = "${unitnews.sync.cron:0 0 1 * * *}", zone = "Europe/Istanbul")

### user

`backend/src/main/java/edu/bingol/backend/user/` · 4 dosya, 291 satır
- Kullanan: `admin` (19), `moderation` (11), `event` (11), `messaging` (10), `auth` (10), `post` (9), `community` (9), `profile` (7), `poll` (5), `support` (4), `forum` (4), `observability` (2), `mail` (2), `unitnews` (1), `share` (1), `notification` (1), `i18n` (1), `devseed` (1), `crash` (1), `accessban` (1)
- Dış sistemler: PostgreSQL
- Tablolar: `app_user`

