# W1-D - Backend: mesajlaşma gizliliği, engel/presence, avatar, olaylar

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 1. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: L (≈2 gün).

Sen **W1-D** iş akışı ajanısın (Rızasız DM kısmi çözüm, avatar gizliliği (mesajlaşma parçası), gölge engel, katılım öncesi olaylar, üye çıkarma olayı, oda moderatörü, tek gösterimlik, yer tutucu bayrakları). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: W1-H ile SÖZLEŞME: C1-C4 (bkz. plan)
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w1d && mkdir -p /c/bu_verify_w1d && git archive HEAD | tar -x -C /c/bu_verify_w1d`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w1d/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w1d/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w1d BACKEND_PORT=18140 WEB_PORT=28140`, `docker compose up -d --build`, `BASE=http://localhost:18140 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W1-D: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 1b. SÖZLEŞMELER (aynı dalgada paralel çalışan akışlarla; alan/davranış adlarını DEĞİŞTİRME)

- **C1** (W1-D -> W1-H): `ConversationView.canModerate: boolean` (oda/kulüp/etkinlikte çağıranın mesaj silme yetkisi). Alan yoksa mobil `false` varsayar.
- **C2** (W1-D -> W1-H): `MessageView.placeholderKind`: `"BLOCKED"`, `"UNREADABLE"` veya `null`; `text` alanı geriye uyumlu kalır (eski mobil Türkçe metni görür).
- **C3** (W1-D -> W1-H): Üye çıkarma/ayrılma/toplu bakımda kullanıcının `/user/queue/message-events` kuyruğuna `{type:"conversation-removed", conversationId}` (mevcut mobil bu olayı tanır).
- **C4** (W1-D <-> W1-H): Tek gösterimlik: tüketim yanıt tamamen yazıldıktan sonra; aynı kullanıcı 60 sn içinde yeniden açabilir; HEAD/Range reddedilir; gönderen 403, başka kullanıcı 410 (mevcut); mobil ağ hatasında BİR kez yeniden dener.

## 2. KAPSAM - T maddeleri (8)

#### T-034 - Sohbet yer tutucuları (engellenen mesaj, görüntülenemiyor) Türkçe sabit; EN/AR kullanıcı Türkçe görür  [KRİTİK | kanıt PS]
- **Kaynak bulgular:** A9-05 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** backend messaging/dto/MessagingDtos (18,22) + MessageViewAssembler (117,120) + WS yükü; mobil features/chat/message_placeholder.dart + ARB (ARB kilidi)
- **Düzeltme:** SÖZLEŞME: MessageView'a placeholderKind (BLOCKED|UNREADABLE|null) alanı eklenir, text geriye uyumlu kalır; mobil kind'a göre ARB metni (tr/en/ar, ARB'de p31 öneki)
- **Test gereksinimi:** Backend: MessageViewAssembler testi; Mobil: l10n testi 3 dil + eski sunucu (kind yok) geriye uyumu
- **Bağımlılık:** backend ve mobil aynı dalgada: sözleşme alan adı sabit

#### T-025 - Rızasız DM / grup ekleme: çıktığı gruba tekrar eklenebilir, presence ile izleme (kısmi çözüm: yeniden ekleme yasağı, presence kısıtı, ek limit)  [YÜKSEK | kanıt P]
- **Kaynak bulgular:** A16-02, A1-11 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** messaging/ConversationService.openDirect/createGroup/addMembers, messaging/ws/PresenceService.shareConversation, MessageController (presence), profile/privacy/ProfilePrivacy
- **Düzeltme:** Çıkan/çıkarılan kullanıcıyı aynı kişi tekrar ekleyemez (kayıt tut); presence ucuna limiter 60/dk; presenceAudience gizlilik (varsayılan güvenli); günlük 'yeni karşı taraf' sınırı 30→10; tam rıza modeli ayrı madde
- **Test gereksinimi:** ConversationServiceTest: çık+yeniden ekle 403/yok sayılır; presence rate limit; smoke-messaging/chat-groups
- **Bağımlılık:** tam model: T-026
- **KARAR (varsayılan = ÖNERİ):** K-08 DM rızası modeli | Seçenekler: (a) Mevcut + hız sınırı; (b) mesaj isteği: ilk DM yalnız ortak bağlam (ortak kulüp/etkinlik/takip) varsa doğrudan, yoksa istek; grup daveti kabul gerektirir; presence karşılıklı kabul sonrası; (c) kapalı DM (yalnız takip ettikleri) | ÖNERİ: (b). Kısa vadede (W1-D) çıkış sonrası yeniden eklemeyi yasakla, presence'a limit ve gizlilik ekle; tam istek akışı karardan sonra W2-D.

#### T-027 - Avatar gizliliği (ONLY_ME/SHARED_CONTEXT) ve moderasyon avatar_hidden sohbet/kulüp/etkinlik/gönderi uçlarında uygulanmıyor  [YÜKSEK | kanıt PS]
- **Kaynak bulgular:** A11-02, A1-12 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** Parça 1 (W1-D): messaging/ConversationService 207-214,514-518, WS olay avatar URL'leri; Parça 2 (W1-F): community/CommunityService 619, CommunityPostService 190, extras/ClubMemberSearchService 64, event/EventService 677,879, extras/CoOrganizerService 83,109, admission/EventAdmissionService 281
- **Düzeltme:** Her DTO kurucusunda AvatarVisibility.visibleOwners(viewer, ids, AVATAR); visibility==null iken avatar gönderme (fail-closed); getAvatarUrl() kullanımı için ArchUnit/grep testi
- **Test gereksinimi:** ONLY_ME avatarlı kullanıcı için üye listesi/arama/sohbet listesinde avatarUrl null; avatar_hidden testi; QueryRulesTest benzeri tarama

#### T-028 - Gölge engel sızıntısı (mesajlaşma): engellenen grup kurarken 403 BLOCKED, ConversationView.blocked iki yönlü, presence 404, engelli eski mesaja tepki/düzenleme; engel hedefi silinmişse 204  [ORTA | kanıt P]
- **Kaynak bulgular:** A10-04, A1-13, A11-10, A1-28 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** messaging/ConversationService.requireNotBlocked/relatedIds/blocked (386-391,539), messaging/ws/PresenceService (104-120), MessageActionService.requireDirectNotBlocked (254-262), MessageViewAssembler, BlockController
- **Düzeltme:** 'Ben engelledim' kümesini (blocks.blockedBy(me)) ayır; engelleyen için aynı normal yanıt (presence sabit offline, createGroup/openDirect sessiz no-op); blocked yalnız engelleyene true; block ucunda hedef ACTIVE değilse 404
- **Test gereksinimi:** ConversationShadowTest: hiddenFrom=1→2 iken blocked=false, presence 200 offline; smoke-block-shadow

#### T-030 - Gruba sonradan katılan üye, katılım öncesi mesajın düzenlenmiş METNİNİ ve tepkisini canlı olayla alıyor  [ORTA | kanıt P]
- **Kaynak bulgular:** A10-02 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** messaging/MessageActionService.publish (272-282)
- **Düzeltme:** GRUP için joinedAt<=message.createdAt (veya first_visible_message_id) olmayan alıcıları çıkar
- **Test gereksinimi:** smoke-messaging: sonradan eklenen üye eski mesaj düzenlemesinde olay almaz

#### T-031 - Çıkarılan/ayrılan üyeye olay yok; mobil önbellekli açılış 404'ü yutuyor ve poll sessizce ölü; EventChatMaintenance toplu JDBC olaysız  [ORTA | kanıt P]
- **Kaynak bulgular:** A10-06, A10-20 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** backend messaging/ConversationService.removeMember/leave, event.chat.EventChatMaintenance (52); mobil chat_detail_page _boot (495-500) ve _poll (622) [W1-H]
- **Düzeltme:** Backend: conversation-removed olayı (removeMember, leave diğer cihazlar, toplu bakım); Mobil: 404 CONVERSATION_NOT_FOUND/403'te sayfayı kapat + MessageCache.removeConversation + bilgilendir
- **Test gereksinimi:** Backend: olay yayını testi; Mobil: widget testi çıkarılmış üye açılışı

#### T-032 - Kulüp/etkinlik odası moderatörü mobilden başkasının mesajını silemez (ConversationView.admin odalarda hep false)  [ORTA | kanıt S]
- **Kaynak bulgular:** A10-07 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** backend messaging/ConversationView + RoomConversations (canModerate); mobil chat_detail_page.dart:1691
- **Düzeltme:** Backend ConversationView.canModerate ekle (oda moderasyon yetkisi); mobil canDelete bunu kullanır
- **Test gereksinimi:** Backend servis testi + mobil widget testi

#### T-033 - Tek gösterimlik görsel baytlar teslim edilmeden tüketiliyor; HEAD/ön-getirme de tüketir  [ORTA | kanıt S]
- **Kaynak bulgular:** A10-08 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** backend messaging/media/MessageAttachmentService.openViewOnce; mobil features/chat/view_once_viewer.dart (56-66)
- **Düzeltme:** Tüketimi yanıt tamamen yazıldıktan sonra yap veya iki aşamalı açış jetonu; HEAD/Range reddet; ağ kopmasında kısa pencere (60 sn) aynı kullanıcıya yeniden ver
- **Test gereksinimi:** Eşzamanlı 6 açış 1x200 korunur; kopma simülasyonu testi
- **KARAR (varsayılan = ÖNERİ):** K-14 Silinen mesaj / tek gösterimlik / düzenleme-silme penceresi | Seçenekler: (a) mevcut; (b) deleted 90 gün, view-once açıldıktan 7 gün (kullanılmamış 30 gün), düzenleme penceresi 24 sa, silme sınırsız | ÖNERİ: (b). Beyan ('bir kez') ve KVKK ile hizalanır; aydınlatma metni sürümüne işlenir.

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- messaging/ConversationService.java, MessageActionService.java, MessageController.java, MessageViewAssembler.java, dto/MessagingDtos.java, room/RoomConversations.java, media/MessageAttachmentService.java, ws/PresenceService.java
- event/chat/EventChatMaintenance.java
- moderation/BlockController.java
- profile/privacy/ProfilePrivacy*.java (presenceAudience alanı)
- i18n/messaging*.properties (kilit: i18n-messages ortak dosya ise)
- docs/changes/messaging.md
- ilgili testler ve scripts/smoke-messaging.sh, smoke-chat-groups.sh, smoke-block-shadow.sh, smoke-chat-receipts-video.sh

**Dokunmayacakların (başka iş akışının):**
- messaging/MessageService.java, MessagingFanoutConfig, ws/ChatEventBus, ws/WebSocketConfig, ChatWsController (W1-E'nin); community/**, event/** (W1-F); mobil (W1-H sözleşmeyi tüketir)

Paylaşılan dosya kilitleri: i18n-messages, docs-shared. Flyway aralığın: **V930-V939**, indeks öneki **msg9_**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18140, WEB_PORT=28140, COMPOSE_PROJECT_NAME=bu_w1d.

## 4. ÖZEL TALİMATLAR

SÖZLEŞMELER (mobil W1-H bunları tüketir; alan adlarını DEĞİŞTİRME): (C1) ConversationView.canModerate: boolean (oda/kulüp/etkinlikte çağıranın mesaj silme yetkisi). (C2) MessageView.placeholderKind: 'BLOCKED' | 'UNREADABLE' | null; text alanı geriye uyumlu kalır (eski mobil Türkçe metni görür). (C3) Üye çıkarma/ayrılma/toplu bakım: kullanıcının /user/queue/message-events kuyruğuna {type:'conversation-removed', conversationId} (mevcut mobil bu olayı tanıyor). (C4) Tek gösterimlik: açış tüketimi yanıt tamamen yazıldıktan sonra; aynı kullanıcı 60 sn içinde yeniden açabilir; HEAD/Range reddedilir; gönderen 403, başka kullanıcı 410 (mevcut davranış korunur). Tam 'mesaj isteği' modelini (T-026) YAPMA (K-08 kararı sonrası W2-D); yalnız T-025 kısmi çözümü. Gölge engel: engellenen taraf engellendiğini ÖĞRENMEMELİ - hata kodu/alan farkı bırakma.

## 5. TEST ve DOĞRULAMA

- backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- Aşağıdaki SÖZLEŞMELER uygulanmış ve docs/changes/messaging.md'de belgeli
- smoke-messaging, smoke-chat-groups, smoke-block-shadow, smoke-chat-receipts-video yalıtılmış yığında yeşil
- ws-test.js gölge-engel beklentisiyle çalışır (betik güncellemesi W3-H; sen yalnız davranışı koru)
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.
