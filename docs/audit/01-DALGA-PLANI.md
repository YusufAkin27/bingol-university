# Düzeltme dalga planı

Tarih: 2026-10-31. Kaynak: [00-KONSOLIDE.md](00-KONSOLIDE.md) (176 tekil madde, 33 karar, 15 insan eylemi). Her iş akışının KOPYALA-YAPIŞTIR hazır ajan görev metni [prompts/](prompts/) altındadır.

## 1. İlkeler

1. **Aynı dosyaları değiştiren maddeler aynı iş akışında**; her dosyanın bir dalgada tek sahibi vardır (bölüm 7 kartlarındaki 'Sahip olunan dosyalar').
2. Bir dalgada en çok **10** paralel iş akışı. Dalga 1 = güvenlik + veri kaybı + KRİTİK/YÜKSEK; Dalga 2 = ORTA hatalar + performans; Dalga 3 = tasarım/metin/belge/DÜŞÜK; Dalga 4 = ölü kod/tekrar (arayüz kilitli: golden/shots ile).
3. Dalgalar arası dosya çakışması **sıra ile** çözülür: Dalga N+1 yalnız Dalga N'in push'ları doğrulandıktan sonra başlar (aynı dosyada yeni iş akışı en güncel `origin` üstünde çalışır).
4. Karar bekleyen maddeler (K-xx) ilgili iş akışının görev metninde 'ÖNERİM varsayılanı' ile yazılıdır; karar farklı gelirse görev metni güncellenir. Karar gelmeden **başlatılmaması** gerekenler 'Önkoşul' sütununda işaretlidir (W2-D'nin K-08/K-10 parçaları, W3-A, W4-B).
5. Hiçbir iş akışı canlı sunucuya dokunmaz; hiçbir iş akışı CLAUDE.md'yi düzenlemez (W3-D'nindir); modül notları `docs/changes/<modül>.md` içine yazılır.

## 2. Paylaşılan çalışma ağacı protokolü (tüm görev metinlerine gömülüdür)

- Tüm ajanlar **aynı çalışma ağacını ve aynı yerel dalı** (`feature/mobil-uygulama`) paylaşır. `scripts/agent-push.sh` verilen dosyaları **bütün halde** `git add` eder: aynı dosyada başka ajanın yarım değişikliği varsa o da commit'e girer. Bu yüzden: (a) yalnız kartında yazan dosyaları düzenle; (b) başka iş akışının dosyasını düzenleme, gerekirse koordinatöre yaz; (c) ortak dosyalar için **kilit** kullan.
- **Kilit protokolü** (ortak dosyalar: ARB `app_{tr,en,ar}.arb` + üretilmiş `app_localizations*.dart` -> kilit `arb`; `backend/src/main/resources/i18n/messages*.properties` -> `i18n-messages`; `admin/rbac/AdminPermissionPolicy.java` ve `AdminGuardPolicy` -> `admin-policy`; `application.properties` -> `app-props`; `docs/ADMIN_API.md`, `docs/PERFORMANCE.md`, `docs/changes/*.md` -> `docs-shared`):
  ```bash
  LOCK="$(git rev-parse --git-dir)/lock-arb"   # ad: arb | i18n-messages | admin-policy | app-props | docs-shared
  until mkdir "$LOCK" 2>/dev/null; do sleep 5; done   # 15 dk'dan eski kilidi kır: find "$LOCK" -maxdepth 0 -mmin +15 -exec rmdir {} \;
  # düzenle -> (ARB ise: cd mobile && flutter gen-l10n) -> bash scripts/agent-push.sh "<mesaj>" <dosyalar>
  rmdir "$LOCK"
  ```
  Kilit **kısa** tutulur: düzenle + test + push + bırak (yarım ARB bırakma).
- **Temiz kopyada doğrulama:** push'tan önce `git archive HEAD | tar -x -C /c/bu_verify_<wf>` (ASCII yol; başkalarının yarım değişiklikleri yoktur), **yalnız kendi değiştirdiğin dosyaları** aynı göreli yolla üstüne kopyala, testleri orada koş. Windows'ta `git archive` CRLF üretirse `LegalMigration*FileTest` düşer (A7-13: ürün hatası değil); LF'e çevir veya yoksay.
- **Yalıtılmış yığın** (smoke için): temiz kopya dizininde `.env.example` -> `.env`, `COMPOSE_PROJECT_NAME=bu_<wf>`, `BACKEND_PORT` ve `WEB_PORT` iş akışının portu (bölüm 7 kartı), `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`, `ADMIN_EMAILS=boss@bingol.edu.tr`; işin bitince `docker compose down -v`. Paylaşımlı A7 yığınına (`18081`) DOKUNMA.
- **Commit:** `bash scripts/agent-push.sh "<WF>: <özet> (T-xxx)" <yol1> <yol2> ...` (küçük, odaklı). `git add -A` / `git add .` YASAK. Sır/derleme çıktısı yolları script tarafından reddedilir.

## 3. Dalga özeti

| Dalga | İş akışı sayısı | T sayısı | KRİTİK/YÜKSEK/ORTA/DÜŞÜK | Başlangıç koşulu |
|---|---:|---:|---|---|
| 1 | 10 | 74 | 10/32/28/4 | Hemen (W1-J İLK: deploy engelleyicileri) |
| 2 | 10 | 50 | 0/1/46/3 | Dalga 1 push'ları ve koordinatör doğrulaması bitince; K-03/K-08/K-10/K-13..K-16/K-27 kararları |
| 3 | 8 | 38 | 1/10/12/15 | Dalga 2 bitince; K-01/K-20..K-25 kararları; avatar/tipografi kararı ile |
| 4 | 2 | 9 | 0/0/0/9 | Dalga 3 bitince; K-10/K-11 ve H-08 üretim sayımları |
| İNSAN | - | 5 | 0/2/2/1 | kod dışı (00-KONSOLIDE bölüm 5) |

## 4. Flyway aralıkları, indeks ve l10n önekleri

Son uygulanmış sürüm **V896**. **Üretim şu an V870'tedir; V880, V890, V896 (+ C1/P1/P3 kodu) henüz DEPLOY EDİLMEDİ.** İlk deploy V880..V896 + aşağıdaki yeni sürümleri TEK seferde uygular (`out-of-order=false`: numaralar monoton). Yeni aralık **V900+** (V889 yok, V897-V899 boş bırakıldı). Kurallar: aralık dışına çıkma; uygulanmış migration'ı DEĞİŞTİRME; indeks adları tüm şemada benzersiz (önek zorunlu); `DROP INDEX CONCURRENTLY` için ayrı dosya + `<ad>.sql.conf` (`executeInTransaction=false`); her migration (a) boş PG16'da V1->son, (b) V870->son yolunda (A7 yöntemi) ve `ddl-auto=validate` ile açılışta doğrulanır.

| İş akışı | Flyway | İndeks öneki | Mobil l10n öneki | Port (backend/web) |
|---|---|---|---|---|
| W1-A | V900-V909 | aut9_ | - | 18110/28110 |
| W1-B | V910-V919 (gerekmezse kullanma) | adm9_ | - | 18120/28120 |
| W1-C | V920-V929 | prv9_ | - | 18130/28130 |
| W1-D | V930-V939 | msg9_ | - | 18140/28140 |
| W1-E | V940-V949 | fan9_ | - | 18150/28150 |
| W1-F | V950-V959 | evt9_ | - | 18160/28160 |
| W1-G | - | - | p30 (örn. p30AutosaveTitle); kilit arb | - |
| W1-H | - | - | p31 | - |
| W1-I | - | - | p32 | - |
| W1-J | - | - | yok (yalnız mevcut anahtar metni) | 18170/28170 |
| W2-A | V960-V969 | prf9_ | - | 18210/28210 |
| W2-B | V970-V974 | ops9_ | - | 18220/28220 |
| W2-C | V975-V979 | psh9_ | - | 18230/28230 |
| W2-D | V980-V989 | dom9_ | - | 18240/28240 |
| W2-E | V990-V994 | mod9_ | - | 18250/28250 |
| W2-F | V995-V999 | kvk9_ | - | 18260/28260 |
| W2-G | - | - | p34 | - |
| W2-H | - | - | p35 | - |
| W2-I | - | - | p36 | - |
| W2-K | - | - | web i18n anahtar önekü p-yok (admin.*, site.*) | - |
| W3-A | - | - | p40 | - |
| W3-B | - | - | p41 | - |
| W3-C | - | - | - | 18310/28310 |
| W3-D | - | - | - | - |
| W3-E | - | - | - | - |
| W3-F | V1000-V1009 | lowb_ | - | 18330/28330 |
| W3-G | - | - | p42 | - |
| W3-H | V1010-V1019 | lgl9_ | - | 18340/28340 |
| W4-A | - | - | - | - |
| W4-B | (veri temizliği gerekirse V1020+) | olu9_ | - | 18410/28410 |

l10n kuralı (mobil): yeni anahtarlar yalnız iş akışının öneki ile (`p30...`); mevcut `p00-p26` ve tekil adlı (`chat*`, `auth*`...) anahtarlar yeniden kullanılabilir; 3 dilde (tr/en/ar) eşit; `flutter gen-l10n` + üretilmiş Dart dosyaları aynı commit'te; ARB kilidi. Backend: yeni hata kodu = ilgili modül properties dosyasında 3 dil; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.

## 5. Dağıtım notları (ÖNEMLİ)

1. **T-144 (A17-02) ve T-145 (A17-01) deploy'dan ÖNCE düzeltilmeli** (W1-J, ilk iş): `docker-compose.prod.yml` backend `environment`'ı belgelerde '.env.prod'a yazın' denen ~150 değişkeni iletmiyor (LEGAL_ENFORCE_REACCEPT hiç açılamaz, FCM_CREDENTIALS_FILE etkisiz); `MAIL_ENABLED=false` prod'da backend'i BAŞLATMAZ ama DEPLOY.md/deploy.sh 'uyarı' diyor (Brevo bilgisi olmadan `deploy.sh` otomatik geri almaya düşer). Bu iki madde olmadan yapılan deploy ya sessizce eksik yapılandırılır ya da geri alınır.
2. **Henüz deploy edilmedi:** V890 (sohbet küçük resim kenarı), V896 (mesaj önizleme tercihi), V880, C1 (sunucu okuma önbelleği), P1 (push düzeltmeleri), P3. Dalga 1'in V900+ migration'ları bunların ÜSTÜNE biner; deploy sırasında Flyway V870 -> V9xx tek koşuda uygular (A7: V880+V890+V896 0,3 sn). **Geri alma:** Flyway geri sarılmaz; `deploy.sh` otomatik geri alma eski imajı yeni şemayla başlatır -> bu yüzden T-146 (deploy öncesi `backup.sh`) Dalga 1 W1-J'dedir; migration'lar geriye uyumlu (ekleme önce, silme sonra) yazılır.
3. **Önerilen deploy kesitleri:** (i) Dalga 1 + W1-J bitince **tek backend deploy** (V880..V959) + mobil 2.0.4 AAB (Dalga 1 mobil: W1-G/H/I/J); (ii) Dalga 2 bitince ikinci deploy (V960..V999); (iii) Dalga 3-4 üçüncü. Her deploy öncesi: tam `mvn test`, `smoke-all.sh`, `docs/openapi.json` yenileme, web kalite kapıları, `deploy.sh --dry-run`.
4. **Minimum sürüm zorlaması (K-06):** mobil düzeltmeler mağazada yayında ve benimsenince `min_version_*` yükseltilir; mağaza bağlantıları (`store_url_*`) dolu olmadan zorunlu ekran 'Güncelle' düğmesiz kalır.
5. **İlk gerçek deploy öncesi insan eylemleri:** H-01 (uzak yedek), H-02 (anahtar emaneti), H-03 (harici izleme), H-05 (SPF/DKIM/DMARC), H-08 (üretim durumu salt-okunur doğrulamaları). Bunlar kod değildir ama yayını engeller (A8-01 KRİTİK).

## 6. İş akışları arası SÖZLEŞMELER (aynı dalgada paralel çalışan akışlar)

| Sözleşme | Taraflar | İçerik |
|---|---|---|
| C1 | W1-D -> W1-H | `ConversationView.canModerate: boolean` (oda/kulüp/etkinlikte çağıranın mesaj silme yetkisi). Alan yoksa mobil `false` varsayar. |
| C2 | W1-D -> W1-H | `MessageView.placeholderKind`: `"BLOCKED"`, `"UNREADABLE"` veya `null`; `text` alanı geriye uyumlu kalır (eski mobil Türkçe metni görür). |
| C3 | W1-D -> W1-H | Üye çıkarma/ayrılma/toplu bakımda kullanıcının `/user/queue/message-events` kuyruğuna `{type:"conversation-removed", conversationId}` (mevcut mobil bu olayı tanır). |
| C4 | W1-D <-> W1-H | Tek gösterimlik: tüketim yanıt tamamen yazıldıktan sonra; aynı kullanıcı 60 sn içinde yeniden açabilir; HEAD/Range reddedilir; gönderen 403, başka kullanıcı 410 (mevcut); mobil ağ hatasında BİR kez yeniden dener. |
| C5 | W1-G -> W1-H | `Outbox` mevcut public API'si (enqueue/remove/deliveries/items) imza değiştirmeden kalır; W1-G yalnız ekleme yapar. |
| C6 | W1-G -> W1-H | `PhotoAutoSave.considerReceived/saveSent/takeDeniedNotice` imzaları sabit (çağrı yeri `chat_detail_page.dart`, W1-H). |
| C7 | W1-A <-> W1-G | Sunucu refresh idempotansı (T-007) ve mobil oturum nesli (T-084) birbirinden bağımsız; ikisi de gerekli. |
| C8 | W1-B -> W2-K | Yeni izin `users.verify` (yalnız FULL) ve gerekçe kuralları; web nav/GuardedAction bunu W2-K'da izler. |
| C9 | tüm backend akışları -> W3-D/koordinatör | API şekli değişen her akış `docs/changes/<modül>.md` yazar; `docs/openapi.json` yalnız dalga sonunda yeniden üretilir (OpenApiExportTest), sonra web `check:contract` ve `gen-mobile-models`. |

## 7. İş akışı kartları

### W1-A - Backend: kimlik, oturum, hesap yaşam döngüsü, hata zarfı

- **Dalga:** 1 - **Büyüklük:** L (≈2 gün) - **Görev metni:** [prompts/W1-A-kimlik-oturum.md](prompts/W1-A-kimlik-oturum.md)
- **Özet:** Kayıtta ad politikası, yönetici kendini silme, Redis devre kesici, hata zarfı/Basic 401, parola politikası, kilit DoS, refresh idempotansı, oturum iptalinde FCM cihaz silme
- **Kapsam (T):** T-001 (kayit_ad), T-002 (admin_self_delete), T-003 (redis_breaker), T-004 (hata_zarfi), T-005 (parola), T-006 (kilit_dos), T-007 (refresh_idem), T-008 (fcm_cihaz_iptal), T-009 (kimlik_dusuk)
- **Sahip olunan dosyalar:** backend/src/main/java/edu/bingol/backend/auth/** (AuthService, AuthController, AccountCreator, LoginThrottle, jwt/JwtAuthFilter, token/*); profile/ProfileService.java (YALNIZ deleteAccount/anonymize) ve profile/ProfileController.java (silme ucu); moderation/UserModerationService.java (suspend/unsuspend; bu dosya yalnız W1-A'nındır); notification/SessionDeviceCleaner.java + test; config/SecurityConfig.java; common/ApiExceptionHandler.java, common/ApiAuthenticationEntryPoint.java, yeni ErrorController/AccessDeniedHandler, common/RateLimiter.java (yalnız devre kesici), analytics/ActivityTracker.java; application.properties (yalnız spring.data.redis.* zaman aşımı satırları; kilit: app-props); i18n/auth*.properties; i18n/messages*.properties yalnız kilitle (kilit: i18n-messages); ilgili backend/src/test/** testleri; scripts/smoke.sh, smoke-student-number.sh, smoke-single-session.sh güncellemesi
- **Dokunulmayacaklar:** admin/**, support/**, messaging/**, event/**, community/**, poll/**, post/**, moderation/ (UserModerationService dışı), mobil, web
- **Test/duman gereksinimi:** backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar
- **Bitirme kriteri:** T maddelerinin tamamı kod+test ile yeşil; smoke.sh + smoke-single-session.sh + smoke-student-number.sh yalıtılmış yığında yeşil; docs/changes/auth.md güncel; yeni hata kodları 3 dilde (i18n-dupkeys temiz)
- **Flyway:** V900-V909 - **İndeks öneki:** aut9_ - **l10n öneki:** - - **Port:** 18110 / 28110 - **Paylaşılan dosya kilitleri:** i18n-messages, app-props
- **Önkoşul/bağımlılık:** Yok (Dalga 1 başlangıcı)

### W1-B - Backend: yönetici paneli yetkisi, yol çözümleme, hiyerarşi, denetim

- **Dalga:** 1 - **Büyüklük:** L (≈2 gün) - **Görev metni:** [prompts/W1-B-admin-rbac.md](prompts/W1-B-admin-rbac.md)
- **Özet:** %-kodlu yol bypass, kodsuz doğrulama, rol onayı bypass, gerekçe kuralları, hiyerarşi, çözme kotası, denetim kalitesi, ayar doğrulama
- **Kapsam (T):** T-010 (pct_yol), T-011 (verify_bypass), T-012 (rol_onay), T-013 (gerekce), T-014 (hiyerarsi), T-015 (decrypt_kota), T-016 (denetim), T-017 (ayar_dogrulama)
- **Sahip olunan dosyalar:** backend/.../admin/** HARİÇ admin/AuditRepository.java ve admin/UserFilter.java (W1-C'nin); admin/rbac/** (AdminPermissionPolicy yalnız kilitle: admin-policy); admin/AdminGuardPolicy.java, AdminGuardInterceptor, AuditRecorder, AuditInterceptor, AuditAccessDeniedHandler; auth/AccountCreator.java'ya YALNIZ ADMIN_EMAILS terfisi satırı (W1-A ile aynı dosya: önce W1-A'nın push ettiğini doğrula; çakışırsa koordinatöre bildir); crypto/AdminDecryptService + admin sohbet görüntüleyici denetleyicisi (AdminChatViewerController) + CryptoProperties; appinfo/ ayar servisi (PUT /api/admin/settings/{key} doğrulaması); i18n/ops.properties, modadmin*, chatadmin* (kilit: i18n-messages ortak dosya ise); docs/ADMIN_API.md ve docs/changes/ops.md (kilit: docs-shared); ilgili testler: AdminPermissionPolicyTest, RbacCoverageTest, AdminGuardPolicyTest; scripts/smoke-admin*.sh
- **Dokunulmayacaklar:** PII maskeleme dosyaları (W1-C'nin listesi), kullanıcı API'leri (community/event/poll/post), mobil, web
- **Test/duman gereksinimi:** backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar (RbacCoverageTest ve AdminPermissionPolicyTest ZORUNLU)
- **Bitirme kriteri:** Her admin ucu bir izne eşli (RbacCoverageTest yeşil); Türetilmiş %xx varyant testi yeşil; smoke-admin.sh, smoke-admin-rbac.sh (ikinci yönetici ile), smoke-admin-moderation.sh yalıtılmış yığında yeşil; docs/ADMIN_API.md yeni users.verify izni ve gerekçe kuralları
- **Flyway:** V910-V919 (gerekmezse kullanma) - **İndeks öneki:** adm9_ - **l10n öneki:** - - **Port:** 18120 / 28120 - **Paylaşılan dosya kilitleri:** admin-policy, i18n-messages, docs-shared
- **Önkoşul/bağımlılık:** T-010 ilk; T-013 ve T-016 ona bağlı

### W1-C - Backend: yönetici PII maskeleme, destek temizliği, içerik filtresi, takip önerisi

- **Dalga:** 1 - **Büyüklük:** L (≈2 gün) - **Görev metni:** [prompts/W1-C-gizlilik-pii-filtre.md](prompts/W1-C-gizlilik-pii-filtre.md)
- **Özet:** Maskeleme tek yerde (JSON+CSV+kitle önizleme), destek temizliği transaction hatası, ownTicket NPE, filtre atlatmaları, takip önerisi sorgusu
- **Kapsam (T):** T-018 (pii), T-019 (q_kehanet), T-020 (destek_cleanup), T-021 (ownticket), T-022 (filtre_link), T-023 (filtre_bosluk), T-024 (takip_oneri)
- **Sahip olunan dosyalar:** notification/campaign/CampaignService.java ve AudienceResolver.java (YALNIZ SamplePerson maskeleme); community/admin/** ve event/admin/** (maskeleme); post/admin/AdminPostService.java; moderation/admin/** (ModAdminDtos, AdminReportContextService), moderation/profanity/** (ProfanityMatcher, ProfanityText, liste dosyaları; ProfanityAdminController W3-F'nin); support/** (ticket/TicketService, PublicSupportService, admin/SupportExportController); mail/admin/MailSuppressionAdminService.java; accessban/AccessBanDtos.java; admin/AuditRepository.java ve admin/UserFilter.java (bu iki dosya admin paketinde ama W1-C'nindir); post/follow/FollowService.java (YALNIZ suggestions) + yeni migration (user_block indeksleri); ilgili testler ve scripts/smoke-admin-support.sh, smoke-admin-moderation.sh, smoke-profanity.sh, public-support-e2e.sh
- **Dokunulmayacaklar:** admin/rbac/**, admin/Admin*Service (W1-B), messaging/**, event/** (admin/ hariç), mobil, web
- **Test/duman gereksinimi:** backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar; PostgreSQL'e özel takip önerisi sorgusu için 20k seed ile EXPLAIN (scripts/perf/seed-20k.sql)
- **Bitirme kriteri:** SUPPORT/VIEWER/EDITOR JWT ile tüm /api/admin GET uçlarında maskesiz e-posta yok (yeni genel sızıntı testi); scheduledCleanup() doğrudan testi yeşil; ProfanityMatcher yeni testleri yeşil; smoke-profanity; follow-suggestions c=20 p95 < 500 ms, 503=0
- **Flyway:** V920-V929 - **İndeks öneki:** prv9_ - **l10n öneki:** - - **Port:** 18130 / 28130 - **Paylaşılan dosya kilitleri:** i18n-messages
- **Önkoşul/bağımlılık:** Yok

### W1-D - Backend: mesajlaşma gizliliği, engel/presence, avatar, olaylar

- **Dalga:** 1 - **Büyüklük:** L (≈2 gün) - **Görev metni:** [prompts/W1-D-mesajlasma-gizlilik.md](prompts/W1-D-mesajlasma-gizlilik.md)
- **Özet:** Rızasız DM kısmi çözüm, avatar gizliliği (mesajlaşma parçası), gölge engel, katılım öncesi olaylar, üye çıkarma olayı, oda moderatörü, tek gösterimlik, yer tutucu bayrakları
- **Kapsam (T):** T-025 (dm_rizasiz), T-027 (avatar_gizlilik), T-028 (golge_msg), T-030 (katilim_oncesi), T-031 (uye_cikarma), T-032 (oda_mod_sil), T-033 (view_once), T-034 (yer_tutucu)
- **Sahip olunan dosyalar:** messaging/ConversationService.java, MessageActionService.java, MessageController.java, MessageViewAssembler.java, dto/MessagingDtos.java, room/RoomConversations.java, media/MessageAttachmentService.java, ws/PresenceService.java; event/chat/EventChatMaintenance.java; moderation/BlockController.java; profile/privacy/ProfilePrivacy*.java (presenceAudience alanı); i18n/messaging*.properties (kilit: i18n-messages ortak dosya ise); docs/changes/messaging.md; ilgili testler ve scripts/smoke-messaging.sh, smoke-chat-groups.sh, smoke-block-shadow.sh, smoke-chat-receipts-video.sh
- **Dokunulmayacaklar:** messaging/MessageService.java, MessagingFanoutConfig, ws/ChatEventBus, ws/WebSocketConfig, ChatWsController (W1-E'nin); community/**, event/** (W1-F); mobil (W1-H sözleşmeyi tüketir)
- **Test/duman gereksinimi:** backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar
- **Bitirme kriteri:** Aşağıdaki SÖZLEŞMELER uygulanmış ve docs/changes/messaging.md'de belgeli; smoke-messaging, smoke-chat-groups, smoke-block-shadow, smoke-chat-receipts-video yalıtılmış yığında yeşil; ws-test.js gölge-engel beklentisiyle çalışır (betik güncellemesi W3-H; sen yalnız davranışı koru)
- **Flyway:** V930-V939 - **İndeks öneki:** msg9_ - **l10n öneki:** - - **Port:** 18140 / 28140 - **Paylaşılan dosya kilitleri:** i18n-messages, docs-shared
- **Önkoşul/bağımlılık:** W1-H ile SÖZLEŞME: C1-C4 (bkz. plan)

### W1-E - Backend: mesajlaşma performansı ve mesaj sırası

- **Dalga:** 1 - **Büyüklük:** M (≈1.5 gün) - **Görev metni:** [prompts/W1-E-mesajlasma-performans.md](prompts/W1-E-mesajlasma-performans.md)
- **Özet:** 500 üyeli oda bildirim dağıtımı, WS teslim MGET, SEND sırası
- **Kapsam (T):** T-035 (fanout), T-036 (ws_teslim), T-037 (send_sira)
- **Sahip olunan dosyalar:** messaging/MessageService.java, MessagingFanoutConfig.java, ws/ChatEventBus.java, ws/WebSocketConfig.java, ws/ChatWsController.java, MessageRepository.java; notification/NotificationService.java (doSend toplu), NotificationRepository.java, yeni migration (kısmi benzersiz indeks); docs/PERFORMANCE.md ve docs/changes/messaging.md ölçüm notları (kilit: docs-shared); ilgili testler; scripts/ws-test.js'ye YALNIZ yeni sıra testi bölümü ekleme YOK (W3-H); scripts/perf/** ölçüm betikleri
- **Dokunulmayacaklar:** messaging/ConversationService, MessageActionService, MessageAttachmentService, ws/PresenceService, MessagingDtos (W1-D'nin); push paketi (FirebaseFcmSender, PushOutbox*) - W2-B/W2-C
- **Test/duman gereksinimi:** backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar; ölçüm: 500 üyeli grup x 8 mesaj (A2 §T-035 tarifi) ve 300 WS alıcı
- **Bitirme kriteri:** Ölçüm öncesi/sonrası tablosu docs/PERFORMANCE.md'de; smoke-messaging + ws-test.js yalıtılmış yığında (gölge engel testleri W3-H'de güncellenecek: beklenen 2 eski FAIL); migration V870→V94x yolunda ve boş PG'de uygulanır (A7 yöntemi)
- **Flyway:** V940-V949 - **İndeks öneki:** fan9_ - **l10n öneki:** - - **Port:** 18150 / 28150 - **Paylaşılan dosya kilitleri:** docs-shared
- **Önkoşul/bağımlılık:** Yok

### W1-F - Backend: etkinlik, kulüp, anket, duyuru alan mantığı ve sistem-admin yetkisi

- **Dalga:** 1 - **Büyüklük:** XL (≈3 gün) - **Görev metni:** [prompts/W1-F-alan-mantigi.md](prompts/W1-F-alan-mantigi.md)
- **Özet:** Sistem ADMIN rolü, etkinlik yetkisi canlı kulüp bağı, hedef kitle İ eşlemesi, goingCount, yoklama PII, legacy sohbet, kapsam, kulüp silinince anket, CSV, avatar (kulüp/etkinlik parçası)
- **Kapsam (T):** T-040 (admin_rolu), T-041 (etkinlik_yetki), T-042 (hedef_kitle_i), T-043 (goingcount), T-044 (yoklama_pii), T-045 (legacy_chat), T-046 (kapsam_id), T-047 (kulup_silinince_anket), T-048 (anket_csv)
- **Paylaşılan T (yalnız bu akışın parçası):** T-027 (avatar_gizlilik)
- **Sahip olunan dosyalar:** event/** (event/admin/**, event/chat/EventChatMaintenance.java [W1-D] ve event/extras/IcsService.java+IcsWriter.java [W1-J] HARİÇ); community/** (community/admin/** HARİÇ); poll/**; academic/DepartmentAnnouncementService.java ve ortak audience yardımcıları; common/CurrentUser.java; post/PostController.java (YALNIZ delete içindeki admin kapısı); i18n/event*.properties, community*.properties, poll*.properties, academic*.properties; docs/changes/event.md, community.md, poll.md; ilgili testler; scripts/smoke-communities-events.sh, smoke-club-lifecycle.sh, smoke-poll.sh, smoke-academic.sh, event-admission-e2e.sh, club-permissions-smoke.sh
- **Dokunulmayacaklar:** messaging/**, admin/** (RBAC), */admin/** (W1-C), event/extras/IcsService.java+IcsWriter.java (W1-J), mobil
- **Test/duman gereksinimi:** backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar; İ eşlemesi PostgreSQL'e özeldir: H2 testi yetmez, PG'de smoke veya Testcontainers benzeri doğrulama
- **Bitirme kriteri:** Her T için regresyon testi (rapor 'Regresyon' satırları); smoke-communities-events (SKIP_REMINDER=1), smoke-club-lifecycle, smoke-poll, smoke-academic yalıtılmış yığında yeşil; İşletme/İktisat/İlahiyat bölümlü kullanıcıyla scope=mine ve audience-count PG'de doğrulandı
- **Flyway:** V950-V959 - **İndeks öneki:** evt9_ - **l10n öneki:** - - **Port:** 18160 / 28160 - **Paylaşılan dosya kilitleri:** i18n-messages, docs-shared
- **Önkoşul/bağımlılık:** T-040 PermissionMatrix/JWT 'ap' talebini YALNIZ OKUR (W1-B ile dosya çakışması yok)

### W1-G - Mobil: oturum nesli, çıkış temizliği, kuyruk/önbellek sağlamlığı, açılış hızı, görsel hattı, galeriye kaydet

- **Dalga:** 1 - **Büyüklük:** XL (≈3 gün) - **Görev metni:** [prompts/W1-G-mobil-oturum-onbellek.md](prompts/W1-G-mobil-oturum-onbellek.md)
- **Özet:** Outbox bozuk depo, oturum nesli, çıkış envanteri, captive portal, şema, 5xx dalgası, açılış, görsel HttpClient, otomatik kaydetme, iOS Keychain
- **Kapsam (T):** T-083 (outbox_bozuk), T-084 (oturum_nesli), T-085 (cikis_depolar), T-086 (portal), T-087 (sema), T-088 (serv5xx), T-089 (acilis), T-090 (gorsel_http), T-091 (otokayit), T-092 (keychain)
- **Sahip olunan dosyalar:** mobile/lib/core/api.dart, session.dart, main.dart, app_gate.dart, device_identity.dart; mobile/lib/core/outbox/** (public metot imzalarını DEĞİŞTİRME, yalnız ekle); mobile/lib/core/cache/** (message_cache, disk_cache, image_disk_cache, cache_lifecycle, cache_policy); mobile/lib/core/connectivity/**, core/platform/fresh_install.dart; features/shell/app_shell.dart, features/home/home_tab.dart (home_parts.dart W1-J'nin); features/search/search_page.dart (arama geçmişi), akademik hatırlatıcı deposu; features/chat/photo_autosave.dart (imzalar sabit: considerReceived/saveSent/takeDeniedNotice), features/profile/privacy_data_page.dart (anahtar satırı); features/posts/post_card.dart, features/events/event_cover.dart, widgets/common.dart (NewsThumb), features/menu/menu_photo.dart, features/profile/user_profile_page.dart (807 civarı Image.network); mobile/lib/l10n/*.arb (YALNIZ kilitle: arb; önek p30); mobile/test/** (kendi testlerin; a15 testlerini mobile/test/a15/ altına KALICI taşı); docs/MOBILE_UI.md bölüm 4.2 çıkış temizliği envanteri
- **Dokunulmayacaklar:** features/chat/chat_detail_page.dart, chat_tab.dart, core/realtime/** (W1-H); android/** ve ios/** (W1-I); features/auth/welcome_page.dart, home_parts.dart (W1-J)
- **Test/duman gereksinimi:** mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol; a15 test dosyalarını (C:\bu_qa\a15\tests\ varsa; yoksa A15 raporu Ek-A eşlemesinden yeniden yaz) repoya mobile/test/a15/ olarak ekle
- **Bitirme kriteri:** A15 kırmızı testleri (S1.4a, S2.11, S5.x, S1.13, S2.8, S2.9, S3.5, S2.4b, U1, S1.6, C1) YEŞİL; flutter analyze 0 warning; tüm mevcut testler yeşil; çıkış sonrası depo envanter testi (secure storage anahtarları dahil); photo_autosave yeni kurulumda kapalı; anahtar canlı sayfada widget testi
- **Flyway:** - - **İndeks öneki:** - - **l10n öneki:** p30 (örn. p30AutosaveTitle); kilit arb - **Port:** - - **Paylaşılan dosya kilitleri:** arb, docs-shared
- **Önkoşul/bağımlılık:** W1-H ile SÖZLEŞME: C5, C6 (bkz. plan)

### W1-H - Mobil: gerçek zamanlı bağlantı, mesaj gönderim güvenilirliği, sohbet ekranı

- **Dalga:** 1 - **Büyüklük:** L (≈2 gün) - **Görev metni:** [prompts/W1-H-mobil-ws-sohbet.md](prompts/W1-H-mobil-ws-sohbet.md)
- **Özet:** WS ack kaybı, STOMP backoff, tek soket, sohbet rebuild, mesaj sınırı, üye çıkarma/moderatör/tek gösterimlik/yer tutucu mobil parçaları
- **Kapsam (T):** T-093 (ws_ack), T-094 (stomp_loop), T-095 (tek_ws), T-096 (chat_rebuild), T-097 (mesaj_sinir)
- **Paylaşılan T (yalnız bu akışın parçası):** T-031 (uye_cikarma), T-032 (oda_mod_sil), T-033 (view_once), T-034 (yer_tutucu)
- **Sahip olunan dosyalar:** mobile/lib/features/chat/chat_detail_page.dart, chat_tab.dart, view_once_viewer.dart, message_placeholder.dart, message_bubble.dart (yalnız placeholder metni), forward_sheet.dart (W2-I; şimdi dokunma); mobile/lib/core/realtime/** (stomp_client.dart, chat_realtime.dart); mobile/lib/l10n/*.arb (YALNIZ kilitle: arb; önek p31); mobile/test/** (chat_*, m1_*, stomp_* testleri ve yenileri)
- **Dokunulmayacaklar:** core/outbox/**, core/api.dart, session.dart, cache/** (W1-G: yalnız MEVCUT public metotları KULLAN), features/chat/photo_autosave.dart (W1-G), android/ios (W1-I)
- **Test/duman gereksinimi:** mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol
- **Bitirme kriteri:** WS ack testi (sayfa kapanınca Outbox'ta kalır, bağlantıda REST'e gider) yeşil; a15 C4/C6 (STOMP döngüsü) yeşil; soket sayısı testi = 1; chat rebuild sayacı testi; 1001-2000 emoji gönderilir, 2001 uyarı; tr/en/ar yer tutucu testi + eski sunucu geriye uyumu
- **Flyway:** - - **İndeks öneki:** - - **l10n öneki:** p31 - **Port:** - - **Paylaşılan dosya kilitleri:** arb
- **Önkoşul/bağımlılık:** W1-D ile SÖZLEŞME C1-C4; W1-G ile C5

### W1-I - Mobil: yerel güvenlik, native katman ve push yönlendirme güvenliği

- **Dalga:** 1 - **Büyüklük:** S (≈0.5-1 gün) - **Görev metni:** [prompts/W1-I-mobil-native-guvenlik.md](prompts/W1-I-mobil-native-guvenlik.md)
- **Özet:** MainActivity exported payload, KVKK dışa aktarma panosu, BootReceiver, Android kanal adları
- **Kapsam (T):** T-098 (exported_payload), T-099 (export_pano), T-100 (kanal_ascii), T-101 (boot)
- **Sahip olunan dosyalar:** mobile/android/** (MainActivity.kt, LocalReminders.kt, AndroidManifest.xml, res/values*); mobile/lib/core/push/push_service.dart, push_router.dart, push_targets.dart (push_channels.dart W4'te silinebilir: dokunma); mobile/lib/features/profile/profil2_my_data_page.dart; mobile/ios/** (yalnız okuma/denetim; değişiklik gerekirse BuNativeBridge.swift tek dosya); mobile/lib/l10n/*.arb (YALNIZ kilitle: arb; önek p32); mobile/test/** (push_*, back_navigation hariç; yeni testler)
- **Dokunulmayacaklar:** features/chat/**, core/api.dart, session.dart, outbox, cache (W1-G/W1-H); backend; web
- **Test/duman gereksinimi:** mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol; Android: `flutter build apk --debug` derlenir (manifest/Kotlin doğrulaması)
- **Bitirme kriteri:** resolvePushTarget birim testi: yerel hatırlatma kaynaklı yük type=session_replaced / event=CONVERSATION_CLOSED ile durum DEĞİŞTİRMEZ; Manifest: BootReceiver exported=false; MainActivity yalnız launcher exported; Kanal adları ASCII-leşmiş Türkçe içermez (tarama testi); dışa aktarma panoya yazılmaz
- **Flyway:** - - **İndeks öneki:** - - **l10n öneki:** p32 - **Port:** - - **Paylaşılan dosya kilitleri:** arb
- **Önkoşul/bağımlılık:** Yok

### W1-J - Dağıtım hattı düzeltmeleri ve KRİTİK metin düzeltmeleri

- **Dalga:** 1 - **Büyüklük:** M (≈1-1.5 gün) - **Görev metni:** [prompts/W1-J-dagitim-kritik-metin.md](prompts/W1-J-dagitim-kritik-metin.md)
- **Özet:** Prod compose değişken iletimi, MAIL_ENABLED belge/kod uyumu, deploy.sh yedek ve anahtar dosyası, ProdSettingsValidator uyarıları, Caddy log, KRİTİK metinler (A9-01/02/03)
- **Kapsam (T):** T-122 (hesap_kapatilacak), T-123 (forgot_baglanti), T-124 (marka), T-136 (yedek_tek), T-137 (anahtar_emanet), T-138 (izleme), T-144 (prod_env), T-145 (mail_enabled), T-146 (deploy_yolu), T-147 (caddy), T-153 (fulls_validator)
- **Sahip olunan dosyalar:** docker-compose.prod.yml, docker-compose.yml (yalnız env iletimi), scripts/deploy.sh, scripts/deploy/**, deploy/Caddyfile, .env.example, .env.prod.example; docs/DEPLOY.md, docs/DEPLOY_SCRIPT.md, docs/LAUNCH_CHECKLIST.md, docs/RUNBOOK.md (tatbikat şablonu), docs/BACKUP_RESTORE.md (ilgili bölümler); backend config/ProdSettingsValidator.java (+test); observability/SystemAlertService.java (yalnız e-posta konusu), event/extras/IcsService.java, IcsWriter.java, academic/IcsBuilder.java (yalnız kullanıcıya görünen takvim adı); i18n/messages*.properties (YALNIZ msg.forgot.sent satırı; kilit: i18n-messages); mobile/lib/features/auth/welcome_page.dart, mobile/lib/features/home/home_parts.dart (marka yazımı); mobile/lib/l10n/app_tr.arb satır 61 (YALNIZ settingsLogoutAllBody; kilit: arb; önek yok - mevcut anahtar)
- **Dokunulmayacaklar:** CLAUDE.md (W3-D'nin; ortam değişkenleri listesini docs/DEPLOY.md ve .env örneklerine yaz), diğer tüm uygulama kodu
- **Test/duman gereksinimi:** scripts: `bash -n`, `node scripts/check-workflows.js`, `scripts/ci/compose-ports-check.sh`; backend: ProdSettingsValidatorTest, I18nMessagesIntegrityTest; mobil: l10n_test + ilgili 2 widget testi
- **Bitirme kriteri:** docker compose -f docker-compose.prod.yml config çıktısında belgelenen değişkenler backend environment'ında görünür (LEGAL_ENFORCE_REACCEPT, FCM_CREDENTIALS_FILE, DB_POOL_*, OBS_ALERT_*, BLOCK_ANONYMIZERS, BAN_*); deploy.sh --dry-run: Brevo bilgisi yoksa baştan red; yedek adımı var; DEPLOY.md bölüm 0/2/14.2 gerçek akışı anlatır; A9-01/02/03 düzeltmeleri testli
- **Flyway:** - - **İndeks öneki:** - - **l10n öneki:** yok (yalnız mevcut anahtar metni) - **Port:** 18170 / 28170 - **Paylaşılan dosya kilitleri:** arb, i18n-messages, docs-shared
- **Önkoşul/bağımlılık:** Yok; DEPLOY'DAN ÖNCE tamamlanmalı

### W2-A - Backend performans: sorgu ve veri yolu

- **Dalga:** 2 - **Büyüklük:** L - **Görev metni:** [prompts/W2-A-backend-perf-sorgu.md](prompts/W2-A-backend-perf-sorgu.md)
- **Özet:** Görsel işleme işlem dışı, anket oy sayaç, takip akışı, bakım parçaları, events N+1, indeks/HOT
- **Kapsam (T):** T-068 (gorsel_islem), T-069 (anket_oy), T-070 (takip_akis), T-071 (bakim_parca), T-072 (events_n1), T-073 (indeks)
- **Sahip olunan dosyalar:** T maddelerinin dosyaları (ProfileService.setAvatar, CommunityService.setCover/setLogo, EventService.setCover/manageableIds, ConversationService.setAvatar, MenuAdminService, PollVoteService, SocialFeedRepository, DbMaintenanceJob, ChunkedDeleter, yeni migration)
- **Dokunulmayacaklar:** push, mesaj fanout, mobil, web
- **Test/duman gereksinimi:** backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar + 20k seed EXPLAIN/ölçüm
- **Bitirme kriteri:** Her T için ölçüm öncesi/sonrası docs/PERFORMANCE.md; smoke-poll, smoke-all ilgili alt küme
- **Flyway:** V960-V969 - **İndeks öneki:** prf9_ - **l10n öneki:** - - **Port:** 18210 / 28210 - **Paylaşılan dosya kilitleri:** docs-shared
- **Önkoşul/bağımlılık:** Dalga 1 W1-E/W1-F/W1-C bitmiş olmalı

### W2-B - Backend dayanıklılık ve altyapı sertleştirme

- **Dalga:** 2 - **Büyüklük:** M - **Görev metni:** [prompts/W2-B-backend-dayaniklilik-altyapi.md](prompts/W2-B-backend-dayaniklilik-altyapi.md)
- **Özet:** FCM timeout/scheduler havuzu/scraper bütçesi, küçük performans, imaj sabitleme+tarama, DB rolleri, Redis parolası
- **Kapsam (T):** T-074 (fcm_timeout_sched), T-075 (perf_dusuk), T-148 (image_pin), T-149 (db_rol), T-150 (redis_pw)
- **Sahip olunan dosyalar:** notification/fcm/FirebaseFcmSender.java, notification/outbox/PushOutboxWorker.java, application*.properties (scheduling.pool), news/*Scraper*, menu/MenuScraper, common/cache/CacheService, common/RateLimiter, messaging/ws/PresenceService.refreshLocal, observability/StorageUsageService, profile/ProfileController (/api/faculties); Dockerfile'lar, docker-compose.prod.yml, .github/workflows/*, dependabot.yml
- **Dokunulmayacaklar:** W2-C push mantığı (PushDispatcher, PushMessages, kampanya)
- **Test/duman gereksinimi:** backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar; workflow YAML (check-workflows.js)
- **Bitirme kriteri:** İş parçacığı dökümünde sched-* havuzu; CI yeşil + trivy adımı; staging'de rol ayrımı kanıtı (K-28 onaylıysa)
- **Flyway:** V970-V974 - **İndeks öneki:** ops9_ - **l10n öneki:** - - **Port:** 18220 / 28220 - **Paylaşılan dosya kilitleri:** app-props, docs-shared
- **Önkoşul/bağımlılık:** W2-C ile FirebaseFcmSender çakışmasın: bu akışta yalnız zaman aşımı ayarı

### W2-C - Backend push ve bildirim

- **Dalga:** 2 - **Büyüklük:** M - **Görev metni:** [prompts/W2-C-backend-push.md](prompts/W2-C-backend-push.md)
- **Özet:** Android tag, moderasyon hedefi, kampanya çift gönderim, FCM kuyruğu/durum
- **Kapsam (T):** T-076 (android_tag), T-077 (mod_hedef), T-078 (kampanya_cift), T-079 (fcm_kuyruk)
- **Sahip olunan dosyalar:** notification/** (fcm/FirebaseFcmSender tag mantığı hariç zaman aşımı satırları W2-B'nin), moderation/ModerationNotifier.java
- **Dokunulmayacaklar:** W2-B dosyaları
- **Test/duman gereksinimi:** backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar
- **Bitirme kriteri:** FirebaseFcmPayloadTest güncel; kampanya eşzamanlı test; docs/changes/push.md
- **Flyway:** V975-V979 - **İndeks öneki:** psh9_ - **l10n öneki:** - - **Port:** 18230 / 28230 - **Paylaşılan dosya kilitleri:** i18n-messages, docs-shared
- **Önkoşul/bağımlılık:** W1-A T-008 bitmiş

### W2-D - Backend alan mantığı ORTA, gizlilik yan kanalları, mesaj isteği modeli, sohbet videosu

- **Dalga:** 2 - **Büyüklük:** XL - **Görev metni:** [prompts/W2-D-backend-alan-gizlilik.md](prompts/W2-D-backend-alan-gizlilik.md)
- **Özet:** İptal 404, menü fit, bildirim kesmesi, kurum taklidi, gizlilik yan kanalları, dosya erişimi, profil sayımı, gölge engel (profil/takip/etkinlik), mesaj isteği (K-08), sohbet video meta
- **Kapsam (T):** T-026 (dm_model), T-029 (golge_diger), T-038 (sohbet_video), T-049 (iptal_404), T-050 (menu_fit), T-051 (bildirim_kesme), T-052 (kurum_taklidi), T-053 (gizlilik_yan), T-054 (files_public), T-055 (profil_sayim)
- **Sahip olunan dosyalar:** event/**, community/**, menu/MenuSyncService, profile/ProfileService+DTO, post/follow/FollowService, post/social/*, profile/privacy/*, common/storage/FileController, config/SecurityConfig (/files), messaging/** (K-08 ve video için)
- **Dokunulmayacaklar:** push, moderasyon raporlama
- **Test/duman gereksinimi:** backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar
- **Bitirme kriteri:** smoke-block-shadow, smoke-messaging, smoke-communities-events, smoke-profile-privacy.sh; K-08 ve K-10 kararları alınmadan T-026/T-038 başlatılmaz
- **Flyway:** V980-V989 - **İndeks öneki:** dom9_ - **l10n öneki:** - - **Port:** 18240 / 28240 - **Paylaşılan dosya kilitleri:** i18n-messages, docs-shared
- **Önkoşul/bağımlılık:** W1-A T-001, W1-D, W1-F bitmiş; K-08, K-10

### W2-E - Backend moderasyon ve kötüye kullanım

- **Dalga:** 2 - **Büyüklük:** L - **Görev metni:** [prompts/W2-E-backend-moderasyon.md](prompts/W2-E-backend-moderasyon.md)
- **Özet:** Rapor paketi, yeniden kayıt/strike, nefret listesi, hız sınırı kapsamı
- **Kapsam (T):** T-057 (rapor_paketi), T-058 (yeniden_kayit), T-059 (nefret_liste), T-060 (hiz_siniri)
- **Sahip olunan dosyalar:** moderation/**, accessban/**, ReportTargetHandler uygulamaları (community/event/post/profile handler dosyaları), ilgili controller'lara limiter
- **Dokunulmayacaklar:** messaging, event mantığı
- **Test/duman gereksinimi:** backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar + RateLimitCoverageTest (yeni)
- **Bitirme kriteri:** RateLimitCoverageTest yeşil; smoke-admin-moderation, smoke-access-ban, smoke-block-shadow
- **Flyway:** V990-V994 - **İndeks öneki:** mod9_ - **l10n öneki:** - - **Port:** 18250 / 28250 - **Paylaşılan dosya kilitleri:** i18n-messages
- **Önkoşul/bağımlılık:** K-15, K-27 kararları

### W2-F - Backend KVKK, saklama ve destek

- **Dalga:** 2 - **Büyüklük:** L - **Görev metni:** [prompts/W2-F-backend-kvkk-destek.md](prompts/W2-F-backend-kvkk-destek.md)
- **Özet:** Hesap silme kapsamı, saklama süreleri, rehber eşleştirme, genel destek formu, admin çözme/Sentry
- **Kapsam (T):** T-061 (rehber), T-062 (destek_bot), T-063 (silme_kvkk), T-064 (mesaj_saklama), T-065 (decrypt_sentry)
- **Sahip olunan dosyalar:** profile/AccountDataPurger, profile/ContactMatch*, dbmaint/**, mail/MailService, support/ticket/PublicSupportService, docs/DATABASE.md, docs/legal/internal/*, application.properties saklama anahtarları, config/ProdSettingsValidator (Sentry)
- **Dokunulmayacaklar:** moderasyon raporlama
- **Test/duman gereksinimi:** backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar
- **Bitirme kriteri:** AccountDataPurgerCoverageTest yeşil; smoke-contacts-match, public-support-e2e; docs/DATABASE.md matris
- **Flyway:** V995-V999 - **İndeks öneki:** kvk9_ - **l10n öneki:** - - **Port:** 18260 / 28260 - **Paylaşılan dosya kilitleri:** app-props, docs-shared, i18n-messages
- **Önkoşul/bağımlılık:** K-13, K-14, K-16

### W2-G - Mobil çevrimdışı ve önbellek ORTA

- **Dalga:** 2 - **Büyüklük:** L - **Görev metni:** [prompts/W2-G-mobil-cevrimdisi-orta.md](prompts/W2-G-mobil-cevrimdisi-orta.md)
- **Özet:** Silinen içerik kalıntısı, geçici dosyalar, iOS yedek, Outbox ORTA, ApiClient ORTA
- **Kapsam (T):** T-102 (kalinti), T-103 (temp), T-104 (ios_yedek), T-105 (outbox_orta), T-106 (api_orta)
- **Sahip olunan dosyalar:** core/outbox/**, core/api.dart, core/cache/**, features/chat/media_camera_page.dart, core/platform/video_service.dart, features/home/home_tab.dart (menü kartı)
- **Dokunulmayacaklar:** chat_detail_page.dart (W2-I)
- **Test/duman gereksinimi:** mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol
- **Bitirme kriteri:** a15 ORTA testleri yeşil
- **Flyway:** - - **İndeks öneki:** - - **l10n öneki:** p34 - **Port:** - - **Paylaşılan dosya kilitleri:** arb
- **Önkoşul/bağımlılık:** W1-G bitmiş

### W2-H - Mobil performans ve boyut

- **Dalga:** 2 - **Büyüklük:** M - **Görev metni:** [prompts/W2-H-mobil-performans-boyut.md](prompts/W2-H-mobil-performans-boyut.md)
- **Özet:** Jank paketi, görsel bellek, APK boyutu
- **Kapsam (T):** T-109 (jank), T-110 (gorsel_bellek), T-111 (apk_boyut)
- **Sahip olunan dosyalar:** features/shell/floating_nav.dart, app_shell.dart (animasyon), widgets/bu_page_scaffold.dart, notifications_page.dart, widgets/bu_default_avatar.dart, media_crop/**, pubspec.yaml assets, proguard-rules.pro, fonts
- **Dokunulmayacaklar:** chat_detail_page (W2-I)
- **Test/duman gereksinimi:** mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol + flutter build apk --analyze-size
- **Bitirme kriteri:** Boyut tablosu öncesi/sonrası; release AAB'de FCM+QR+kamera duman testi (H-09)
- **Flyway:** - - **İndeks öneki:** - - **l10n öneki:** p35 - **Port:** - - **Paylaşılan dosya kilitleri:** arb
- **Önkoşul/bağımlılık:** K-02

### W2-I - Mobil push, bildirim kutusu, sohbet olgunlaştırma, galeri izni

- **Dalga:** 2 - **Büyüklük:** L - **Görev metni:** [prompts/W2-I-mobil-push-sohbet.md](prompts/W2-I-mobil-push-sohbet.md)
- **Özet:** Okunmamış süzgeci, tepsi/rozet, forward/boşluk doldurma/olay işleme, READ_MEDIA geçişi (K-03)
- **Kapsam (T):** T-081 (okunmamis_suzgec), T-082 (tepsi_rozet), T-108 (sohbet_olgun), T-141 (read_media)
- **Paylaşılan T (yalnız bu akışın parçası):** T-077 (mod_hedef), T-026 (dm_model)
- **Sahip olunan dosyalar:** features/notifications/**, core/push/**, features/chat/** (W1-H sonrası), android Kotlin (tepsi), media_picker_page/media_library (K-03)
- **Dokunulmayacaklar:** W2-G dosyaları
- **Test/duman gereksinimi:** mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol
- **Bitirme kriteri:** notif_design_test 25+ bildirim; ForwardSheet çevrimdışı testi
- **Flyway:** - - **İndeks öneki:** - - **l10n öneki:** p36 - **Port:** - - **Paylaşılan dosya kilitleri:** arb
- **Önkoşul/bağımlılık:** W1-H bitmiş; K-03

### W2-K - Web: yönetim paneli ve site ORTA

- **Dalga:** 2 - **Büyüklük:** L - **Görev metni:** [prompts/W2-K-web-panel.md](prompts/W2-K-web-panel.md)
- **Özet:** Taşma, izin uyumu, panel eksikleri, CLS/soft 404
- **Kapsam (T):** T-155 (web_tasma), T-156 (web_izin), T-157 (web_panel_eksik), T-158 (web_cls_404)
- **Sahip olunan dosyalar:** web/src/**, web/nginx.conf, nginx-security.conf, web/scripts
- **Dokunulmayacaklar:** backend (yalnız yeni önbellek ucu için W1-B'ye talep)
- **Test/duman gereksinimi:** web: `npm run lint && typecheck && test && build && check:contract && check:i18n`; Playwright e2e/ ilgili
- **Bitirme kriteri:** Kalite kapıları yeşil; Roller x rotalar Playwright taraması; Lighthouse CLS < 0.1
- **Flyway:** - - **İndeks öneki:** - - **l10n öneki:** web i18n anahtar önekü p-yok (admin.*, site.*) - **Port:** - - **Paylaşılan dosya kilitleri:** docs-shared
- **Önkoşul/bağımlılık:** W1-B (users.verify izni, yeni uçlar) ve W1-C bitmiş; docs/openapi.json yenilenmiş

### W3-A - Mobil tasarım tutarlılığı

- **Dalga:** 3 - **Büyüklük:** XL - **Görev metni:** [prompts/W3-A-mobil-tasarim.md](prompts/W3-A-mobil-tasarim.md)
- **Özet:** Diyalog birleştirme, tipografi, dar ekran, kNavInset, medya balonları, dokunma, kontrast, tutarsızlıklar, RTL
- **Kapsam (T):** T-112 (dialog), T-113 (tipo), T-114 (dar_liste), T-115 (navinset), T-116 (ayar_kirpma), T-117 (medya_balon), T-118 (dokunma), T-119 (kontrast), T-120 (tutarsizlik), T-121 (rtl)
- **Sahip olunan dosyalar:** mobile/lib/widgets/**, features/** UI dosyaları (T listesi), core/typography.dart, core/theme/**
- **Dokunulmayacaklar:** backend, web
- **Test/duman gereksinimi:** mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol + A6 shots koşusu (tr390/ar390/tr320, 1.3x)
- **Bitirme kriteri:** Piksel eşitliği: golden/shots öncesi-sonrası (arayüz KİLİTLİ); K-20/K-21 onaylı
- **Flyway:** - - **İndeks öneki:** - - **l10n öneki:** p40 - **Port:** - - **Paylaşılan dosya kilitleri:** arb
- **Önkoşul/bağımlılık:** K-20, K-21 kararları; W1-G/H/I, W2-G/H/I bitmiş

### W3-B - Mobil metin ve çok dil

- **Dalga:** 3 - **Büyüklük:** L - **Görev metni:** [prompts/W3-B-mobil-metin.md](prompts/W3-B-mobil-metin.md)
- **Özet:** Hitap, çoğul, terim, çeviri düzeltmeleri, 'Resmi' etiketi, A9 küçükleri
- **Kapsam (T):** T-125 (resmi), T-126 (hitap), T-127 (cogul), T-128 (terim), T-132 (sabit_metin), T-133 (ceviri_dizgi), T-135 (a9_dusuk)
- **Sahip olunan dosyalar:** mobile/lib/l10n/*.arb, features içi sabit metinler, iOS InfoPlist.strings
- **Dokunulmayacaklar:** backend properties (W3-C)
- **Test/duman gereksinimi:** mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol + i18n-audit.js
- **Bitirme kriteri:** tr/en/ar anahtar eşitliği; terim tarama betiği 0 sapma
- **Flyway:** - - **İndeks öneki:** - - **l10n öneki:** p41 - **Port:** - - **Paylaşılan dosya kilitleri:** arb
- **Önkoşul/bağımlılık:** K-01, K-22, K-23

### W3-C - Backend metin ve çok dil

- **Dalga:** 3 - **Büyüklük:** M - **Görev metni:** [prompts/W3-C-backend-metin.md](prompts/W3-C-backend-metin.md)
- **Özet:** Doğrulama mesajı, teknik metin, ICS/e-posta, çoğul AR, terim
- **Kapsam (T):** T-129 (dogrulama_ham), T-130 (teknik_metin), T-131 (ics_mail)
- **Sahip olunan dosyalar:** backend i18n/*.properties, ValidationMessages_*, mail-templates, ApiExceptionHandler.validation
- **Dokunulmayacaklar:** mobil
- **Test/duman gereksinimi:** backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar
- **Bitirme kriteri:** I18nMessagesIntegrityTest; dinamik 3 dil örnekleri
- **Flyway:** - - **İndeks öneki:** - - **l10n öneki:** - - **Port:** 18310 / 28310 - **Paylaşılan dosya kilitleri:** i18n-messages
- **Önkoşul/bağımlılık:** K-23

### W3-D - Belge, CLAUDE.md ve openapi

- **Dalga:** 3 - **Büyüklük:** M - **Görev metni:** [prompts/W3-D-belge-claude-openapi.md](prompts/W3-D-belge-claude-openapi.md)
- **Özet:** A17/A18 belge düzeltmeleri, CLAUDE.md, openapi yenileme
- **Kapsam (T):** T-161 (belge_paket), T-162 (openapi)
- **Sahip olunan dosyalar:** CLAUDE.md, docs/** (audit hariç), README.md
- **Dokunulmayacaklar:** kod
- **Test/duman gereksinimi:** Belge bağlantı betiği; OpenApiExportTest
- **Bitirme kriteri:** scripts/openapi-check.js DRIFT yok; NUL/BOM yok
- **Flyway:** - - **İndeks öneki:** - - **l10n öneki:** - - **Port:** - - **Paylaşılan dosya kilitleri:** docs-shared
- **Önkoşul/bağımlılık:** Tüm önceki dalgalar

### W3-E - Web DÜŞÜK ve site

- **Dalga:** 3 - **Büyüklük:** S - **Görev metni:** [prompts/W3-E-web-dusuk.md](prompts/W3-E-web-dusuk.md)
- **Özet:** Web küçükleri, ErrorBoundary AR
- **Kapsam (T):** T-134 (errorboundary), T-159 (web_dusuk)
- **Sahip olunan dosyalar:** web/src/**
- **Dokunulmayacaklar:** backend
- **Test/duman gereksinimi:** web kalite kapıları
- **Bitirme kriteri:** web kalite kapıları yeşil
- **Flyway:** - - **İndeks öneki:** - - **l10n öneki:** - - **Port:** - - **Paylaşılan dosya kilitleri:** -
- **Önkoşul/bağımlılık:** W2-K bitmiş

### W3-F - Backend DÜŞÜK paketi

- **Dalga:** 3 - **Büyüklük:** L - **Görev metni:** [prompts/W3-F-backend-dusuk.md](prompts/W3-F-backend-dusuk.md)
- **Özet:** Mesajlaşma/alan/güvenlik/küçük hatalar, CSV tekrar, PII/yaş kararları
- **Kapsam (T):** T-039 (msg_dusuk), T-056 (alan_dusuk), T-066 (pii_gorsel_yas), T-067 (kod_butcesi), T-154 (altyapi_dusuk), T-164 (backend_dusuk_diger), T-165 (guvenlik_dusuk), T-166 (csv_tekrar)
- **Sahip olunan dosyalar:** T listesindeki dosyalar
- **Dokunulmayacaklar:** mobil, web
- **Test/duman gereksinimi:** backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar
- **Bitirme kriteri:** her T testli
- **Flyway:** V1000-V1009 - **İndeks öneki:** lowb_ - **l10n öneki:** - - **Port:** 18330 / 28330 - **Paylaşılan dosya kilitleri:** i18n-messages
- **Önkoşul/bağımlılık:** K-17, K-18, K-26

### W3-G - Mobil DÜŞÜK paketi

- **Dalga:** 3 - **Büyüklük:** M - **Görev metni:** [prompts/W3-G-mobil-dusuk.md](prompts/W3-G-mobil-dusuk.md)
- **Özet:** Medya host denetimi, saat dilimi, lint, iOS yerel ağ, push küçükleri
- **Kapsam (T):** T-080 (push_dusuk), T-107 (media_auth), T-176 (mobil_dusuk)
- **Paylaşılan T (yalnız bu akışın parçası):** T-080 (push_dusuk)
- **Sahip olunan dosyalar:** T listesindeki dosyalar
- **Dokunulmayacaklar:** backend
- **Test/duman gereksinimi:** mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol
- **Bitirme kriteri:** flutter analyze 0 warning
- **Flyway:** - - **İndeks öneki:** - - **l10n öneki:** p42 - **Port:** - - **Paylaşılan dosya kilitleri:** arb
- **Önkoşul/bağımlılık:** K-07

### W3-H - Test/CI, hukuk ve mağaza belgeleri

- **Dalga:** 3 - **Büyüklük:** M - **Görev metni:** [prompts/W3-H-test-ci-hukuk.md](prompts/W3-H-test-ci-hukuk.md)
- **Özet:** Shots testleri, flaky, ws-test, smoke; yeni sözleşme sürümü; Play/Apple belgeleri
- **Kapsam (T):** T-139 (aydinlatma), T-140 (play_data), T-163 (test_ci)
- **Sahip olunan dosyalar:** mobile/test/**, scripts/*.sh|js, docs/store/**, docs/ios-store/**, docs/legal/**, yeni migration (sözleşme sürümü)
- **Dokunulmayacaklar:** uygulama kodu
- **Test/duman gereksinimi:** scripts + testler
- **Bitirme kriteri:** smoke-all.sh yalıtılmış yığında yeşil
- **Flyway:** V1010-V1019 - **İndeks öneki:** lgl9_ - **l10n öneki:** - - **Port:** 18340 / 28340 - **Paylaşılan dosya kilitleri:** docs-shared
- **Önkoşul/bağımlılık:** K-24, K-25 (avukat onayı olmadan sözleşme YAYINLANMAZ)

### W4-A - Mobil ölü kod ve tekrar birleştirme

- **Dalga:** 4 - **Büyüklük:** L - **Görev metni:** [prompts/W4-A-mobil-olu-kod.md](prompts/W4-A-mobil-olu-kod.md)
- **Özet:** Erişilemeyen dosyalar, ölü semboller, ölü ARB anahtarları, tekrar birleştirme (arayüz kilitli)
- **Kapsam (T):** T-167 (olu_mobil), T-168 (olu_arb), T-174 (tekrar_mobil)
- **Sahip olunan dosyalar:** mobile/lib/**, ARB
- **Dokunulmayacaklar:** backend, web
- **Test/duman gereksinimi:** mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol + shots piksel karşılaştırması
- **Bitirme kriteri:** flutter analyze && flutter test yeşil; golden/shots eşit
- **Flyway:** - - **İndeks öneki:** - - **l10n öneki:** - - **Port:** - - **Paylaşılan dosya kilitleri:** arb
- **Önkoşul/bağımlılık:** W3-B bitmiş (ARB), W1-G T-091 bitmiş (SettingsPage)

### W4-B - Backend + web ölü kod ve tekrar

- **Dalga:** 4 - **Büyüklük:** L - **Görev metni:** [prompts/W4-B-backend-web-olu-kod.md](prompts/W4-B-backend-web-olu-kod.md)
- **Özet:** Backend/web ölü kod, video hattı (K-10), eski enum (K-11), CSV/Range tekrar
- **Kapsam (T):** T-169 (olu_backend), T-170 (video_hatti), T-171 (enum_eski), T-172 (olu_web), T-173 (range_tekrar), T-175 (tekrar_web)
- **Sahip olunan dosyalar:** backend/**, web/src/**
- **Dokunulmayacaklar:** mobil
- **Test/duman gereksinimi:** backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar; web kalite kapıları
- **Bitirme kriteri:** mvn test + RbacCoverageTest + OpenApiExportTest; web kapıları
- **Flyway:** (veri temizliği gerekirse V1020+) - **İndeks öneki:** olu9_ - **l10n öneki:** - - **Port:** 18410 / 28410 - **Paylaşılan dosya kilitleri:** i18n-messages
- **Önkoşul/bağımlılık:** K-10, K-11, H-08

## 8. Koordinatör dalga-sonu kontrol listesi

1. Tüm push'lar `origin/feature/mobil-uygulama` üzerinde; `git log` ile her iş akışının commit'leri ve teslim raporları okundu.
2. Temiz `git archive HEAD` kopyasında: backend tam `mvn -B test` (≈23 dk), `RbacCoverageTest`, `OpenApiExportTest`, `I18nMessagesIntegrityTest`, `QueryRulesTest`; mobil `flutter analyze` (0 warning) + tam `flutter test`; web `npm run lint && typecheck && test && build && check:contract && check:i18n`.
3. Boş PG16'da V1->son ve V870->son migration yolları + `ddl-auto=validate` açılış (A7 §3.3 yöntemi); iki yolda şema eşitliği.
4. Yalıtılmış yığında `BASE=... ADMIN_PASSWORD=... ./scripts/smoke-all.sh` (Redis `rl:*` temizliği için FLUSH_CMD sarmalayıcı; paylaşımlı yığında `flushall` KULLANMA).
5. `docs/openapi.json` yeniden üret (C9); `scripts/openapi-check.js` DRIFT yok.
6. Dosya çakışması taraması: aynı dosyayı iki iş akışı commit'lediyse (`git log --format=%an -- <dosya>`) sonucu elle incele.
7. K-xx kararlarından yeni gelenleri ilgili görev metinlerine işle; H-xx durumunu güncelle.

## 9. Görev metinleri dizini

| İş akışı | Dosya |
|---|---|
| W1-A | [W1-A-kimlik-oturum.md](prompts/W1-A-kimlik-oturum.md) |
| W1-B | [W1-B-admin-rbac.md](prompts/W1-B-admin-rbac.md) |
| W1-C | [W1-C-gizlilik-pii-filtre.md](prompts/W1-C-gizlilik-pii-filtre.md) |
| W1-D | [W1-D-mesajlasma-gizlilik.md](prompts/W1-D-mesajlasma-gizlilik.md) |
| W1-E | [W1-E-mesajlasma-performans.md](prompts/W1-E-mesajlasma-performans.md) |
| W1-F | [W1-F-alan-mantigi.md](prompts/W1-F-alan-mantigi.md) |
| W1-G | [W1-G-mobil-oturum-onbellek.md](prompts/W1-G-mobil-oturum-onbellek.md) |
| W1-H | [W1-H-mobil-ws-sohbet.md](prompts/W1-H-mobil-ws-sohbet.md) |
| W1-I | [W1-I-mobil-native-guvenlik.md](prompts/W1-I-mobil-native-guvenlik.md) |
| W1-J | [W1-J-dagitim-kritik-metin.md](prompts/W1-J-dagitim-kritik-metin.md) |
| W2-A | [W2-A-backend-perf-sorgu.md](prompts/W2-A-backend-perf-sorgu.md) |
| W2-B | [W2-B-backend-dayaniklilik-altyapi.md](prompts/W2-B-backend-dayaniklilik-altyapi.md) |
| W2-C | [W2-C-backend-push.md](prompts/W2-C-backend-push.md) |
| W2-D | [W2-D-backend-alan-gizlilik.md](prompts/W2-D-backend-alan-gizlilik.md) |
| W2-E | [W2-E-backend-moderasyon.md](prompts/W2-E-backend-moderasyon.md) |
| W2-F | [W2-F-backend-kvkk-destek.md](prompts/W2-F-backend-kvkk-destek.md) |
| W2-G | [W2-G-mobil-cevrimdisi-orta.md](prompts/W2-G-mobil-cevrimdisi-orta.md) |
| W2-H | [W2-H-mobil-performans-boyut.md](prompts/W2-H-mobil-performans-boyut.md) |
| W2-I | [W2-I-mobil-push-sohbet.md](prompts/W2-I-mobil-push-sohbet.md) |
| W2-K | [W2-K-web-panel.md](prompts/W2-K-web-panel.md) |
| W3-A | [W3-A-mobil-tasarim.md](prompts/W3-A-mobil-tasarim.md) |
| W3-B | [W3-B-mobil-metin.md](prompts/W3-B-mobil-metin.md) |
| W3-C | [W3-C-backend-metin.md](prompts/W3-C-backend-metin.md) |
| W3-D | [W3-D-belge-claude-openapi.md](prompts/W3-D-belge-claude-openapi.md) |
| W3-E | [W3-E-web-dusuk.md](prompts/W3-E-web-dusuk.md) |
| W3-F | [W3-F-backend-dusuk.md](prompts/W3-F-backend-dusuk.md) |
| W3-G | [W3-G-mobil-dusuk.md](prompts/W3-G-mobil-dusuk.md) |
| W3-H | [W3-H-test-ci-hukuk.md](prompts/W3-H-test-ci-hukuk.md) |
| W4-A | [W4-A-mobil-olu-kod.md](prompts/W4-A-mobil-olu-kod.md) |
| W4-B | [W4-B-backend-web-olu-kod.md](prompts/W4-B-backend-web-olu-kod.md) |

