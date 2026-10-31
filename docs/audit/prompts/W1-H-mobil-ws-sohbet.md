# W1-H - Mobil: gerçek zamanlı bağlantı, mesaj gönderim güvenilirliği, sohbet ekranı

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 1. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: L (≈2 gün).

Sen **W1-H** iş akışı ajanısın (WS ack kaybı, STOMP backoff, tek soket, sohbet rebuild, mesaj sınırı, üye çıkarma/moderatör/tek gösterimlik/yer tutucu mobil parçaları). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: W1-D ile SÖZLEŞME C1-C4; W1-G ile C5
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w1h && mkdir -p /c/bu_verify_w1h && git archive HEAD | tar -x -C /c/bu_verify_w1h`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w1h/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w1h/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yığın gerekmez** (bu iş akışı mobil/web/belge ağırlıklı): testleri birim/widget/sahte sunucu (MockClient, yerel HttpServer; A15 yöntemi) ile yaz; bir backend yığını gerekirse yalnız kendi COMPOSE_PROJECT_NAME ve boş port ile kur, A7 ortak yığınına (18081) DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W1-H: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 1b. SÖZLEŞMELER (aynı dalgada paralel çalışan akışlarla; alan/davranış adlarını DEĞİŞTİRME)

- **C1** (W1-D -> W1-H): `ConversationView.canModerate: boolean` (oda/kulüp/etkinlikte çağıranın mesaj silme yetkisi). Alan yoksa mobil `false` varsayar.
- **C2** (W1-D -> W1-H): `MessageView.placeholderKind`: `"BLOCKED"`, `"UNREADABLE"` veya `null`; `text` alanı geriye uyumlu kalır (eski mobil Türkçe metni görür).
- **C3** (W1-D -> W1-H): Üye çıkarma/ayrılma/toplu bakımda kullanıcının `/user/queue/message-events` kuyruğuna `{type:"conversation-removed", conversationId}` (mevcut mobil bu olayı tanır).
- **C4** (W1-D <-> W1-H): Tek gösterimlik: tüketim yanıt tamamen yazıldıktan sonra; aynı kullanıcı 60 sn içinde yeniden açabilir; HEAD/Range reddedilir; gönderen 403, başka kullanıcı 410 (mevcut); mobil ağ hatasında BİR kez yeniden dener.
- **C5** (W1-G -> W1-H): `Outbox` mevcut public API'si (enqueue/remove/deliveries/items) imza değiştirmeden kalır; W1-G yalnız ekleme yapar.
- **C6** (W1-G -> W1-H): `PhotoAutoSave.considerReceived/saveSent/takeDeniedNotice` imzaları sabit (çağrı yeri `chat_detail_page.dart`, W1-H).

## 2. KAPSAM - T maddeleri (5)

#### T-093 - WS ile gönderilen metin ack gelmeden sayfa kapanınca/ölü soketle sessizce kaybolur (hiçbir kalıcı kayıt yok); WS yolu bekleyen Outbox'ı geçer  [KRİTİK | kanıt PS]
- **Kaynak bulgular:** A10-01, A15-02, A10-10 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/chat/chat_detail_page.dart (947-960 WS gönderim + 8 sn _ackTimers, 411 dispose), core/realtime/stomp_client.dart send, core/outbox/outbox.dart (enqueue API — salt okunur kullanım)
- **Düzeltme:** WS ile atılan her mesajı ack gelene kadar Outbox'a (veya oturum düzeyi ack-bekleyen kayda) yaz; zamanlayıcıyı sayfaya değil ChatRealtime/Outbox'a bağla; sayfa kapanınca iptal etme; konuşmada bekleyen Outbox öğesi varsa yeni mesajı da Outbox'a ekle (sıra)
- **Test gereksinimi:** Widget testi: bağlı sahte ChatRealtime, ack yok, sayfayı kapat → Outbox.items clientId'yi içerir ve bağlantıda REST'e gider; chat_offline_test, m1_silent_queue_test genişlet
- **Bağımlılık:** Outbox API değişmez (W1-G ile arayüz sözleşmesi: enqueue/remove)

#### T-094 - STOMP TOKEN_EXPIRED/UNAUTHORIZED döngüsünde geri çekilme yok (3 sn'de 191 bağlantı + 190 refresh); _attempt her CONNECTED'da sıfırlanır  [YÜKSEK | kanıt P]
- **Kaynak bulgular:** A15-09, A4-11 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil core/realtime/stomp_client.dart (265-272, 207, 74)
- **Düzeltme:** Bu dalda _scheduleReconnect (üstel); art arda 3 UNAUTHORIZED sonrası StompFatal.sessionExpired; _attempt yalnız bağlantı ≥30 sn kararlıysa sıfırlanır
- **Test gereksinimi:** a15 C4 (connects <10) ve C6 yeşil

#### T-095 - Aynı anda en çok 3 WebSocket (kabuk + ChatTab + ChatDetail), her mesaj 3 kez alınır  [YÜKSEK | kanıt S]
- **Kaynak bulgular:** A5-01 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/shell/app_shell.dart (56), features/chat/chat_tab.dart (74-75), features/chat/chat_detail_page.dart (143,711), core/session.dart realtime
- **Düzeltme:** Tek session.realtime; ChatTab/ChatDetail ona abone (widget.realtime ?? session.realtime!); start/stop referans sayaçlı yalnız kabukta
- **Test gereksinimi:** Testler zaten realtime enjeksiyonu destekler; soket sayısı testi = 1

#### T-096 - Sohbet detayında her yoklama/olayda koşulsuz setState: görünen tüm balonlar yeniden kurulur; GlobalKey sızıntısı; her _merge'de tam sıralama  [YÜKSEK | kanıt T]
- **Kaynak bulgular:** A5-04, A5-22, A5-17 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/chat/chat_detail_page.dart (617 _poll, 2619-2655, 2651 _rowKeys, 830 _merge)
- **Düzeltme:** _poll'da yalnız added||changed ise setState; Key(id) + findChildIndexCallback; _rowKeys _msgs ile eşit; sıralı ekleme (binary insert); rota üstte başka sayfa varken yoklamayı duraklat
- **Test gereksinimi:** Sentetik rebuild sayacı testi; profile modda DevTools (H-09)

#### T-097 - Mobil mesaj sınırı UTF-16 sayar (gönder sessizce yok), sunucu kod noktası sayar; düzenleme yolunda sınır yok  [ORTA | kanıt P]
- **Kaynak bulgular:** A10-05 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil chat_detail_page.dart (883 sessiz return, 2948 sayaç), core/outbox/outbox.dart maxTextLength
- **Düzeltme:** Tek ölçü: text.runes.length hem sayaçta hem _submit hem Outbox hem _saveEdit; aşımda görünür uyarı
- **Test gereksinimi:** 1001-2000 emoji gönderilir; 2001 uyarı; sunucu ile eşit
- **Bağımlılık:** sunucu tarafı T-055 (W2-D); mobil kısım bağımsızdır
- **KARAR (varsayılan = ÖNERİ):** K-32 Profil metin sayım birimi | Seçenekler: (a) kod noktası her yerde | ÖNERİ: (a): mesaj, bio, ad ve mobil sayaç aynı (Dart runes.length); sunucuda @Size yerine özel doğrulayıcı.

### Paylaşılan T maddeleri (başka iş akışıyla ortak; YALNIZ senin parçan)

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

#### T-034 - Sohbet yer tutucuları (engellenen mesaj, görüntülenemiyor) Türkçe sabit; EN/AR kullanıcı Türkçe görür  [KRİTİK | kanıt PS]
- **Kaynak bulgular:** A9-05 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** backend messaging/dto/MessagingDtos (18,22) + MessageViewAssembler (117,120) + WS yükü; mobil features/chat/message_placeholder.dart + ARB (ARB kilidi)
- **Düzeltme:** SÖZLEŞME: MessageView'a placeholderKind (BLOCKED|UNREADABLE|null) alanı eklenir, text geriye uyumlu kalır; mobil kind'a göre ARB metni (tr/en/ar, ARB'de p31 öneki)
- **Test gereksinimi:** Backend: MessageViewAssembler testi; Mobil: l10n testi 3 dil + eski sunucu (kind yok) geriye uyumu
- **Bağımlılık:** backend ve mobil aynı dalgada: sözleşme alan adı sabit

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- mobile/lib/features/chat/chat_detail_page.dart, chat_tab.dart, view_once_viewer.dart, message_placeholder.dart, message_bubble.dart (yalnız placeholder metni), forward_sheet.dart (W2-I; şimdi dokunma)
- mobile/lib/core/realtime/** (stomp_client.dart, chat_realtime.dart)
- mobile/lib/l10n/*.arb (YALNIZ kilitle: arb; önek p31)
- mobile/test/** (chat_*, m1_*, stomp_* testleri ve yenileri)

**Dokunmayacakların (başka iş akışının):**
- core/outbox/**, core/api.dart, session.dart, cache/** (W1-G: yalnız MEVCUT public metotları KULLAN), features/chat/photo_autosave.dart (W1-G), android/ios (W1-I)

Paylaşılan dosya kilitleri: arb. Flyway aralığın: **-**, indeks öneki **-**. Mobil l10n öneki: **p31**.

## 4. ÖZEL TALİMATLAR

SÖZLEŞME tüketimi: ConversationView.canModerate (yoksa false), MessageView.placeholderKind (yoksa mevcut metin davranışı), 'conversation-removed' olayı (404/403'te sayfayı kapat + MessageCache.removeConversation + toast), tek gösterimlik: ağ hatasında BİR kez yeniden dene (sunucu 60 sn pencere tanıyacak). Outbox: yalnız mevcut enqueue/remove/deliveries API'sini kullan; WS ile atılan her metni ack gelene kadar Outbox'ta tut. Tek soket: Session.realtime (session.dart W1-G'nin: sen yalnız kullan; gerekiyorsa getter'ın var olduğunu doğrula, yoksa koordinatöre bildir). ARB: yer tutucu metinleri p31 öneki, 3 dil; `flutter gen-l10n` + 3 dil anahtar eşitliği.

## 5. TEST ve DOĞRULAMA

- mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- WS ack testi (sayfa kapanınca Outbox'ta kalır, bağlantıda REST'e gider) yeşil
- a15 C4/C6 (STOMP döngüsü) yeşil
- soket sayısı testi = 1
- chat rebuild sayacı testi
- 1001-2000 emoji gönderilir, 2001 uyarı
- tr/en/ar yer tutucu testi + eski sunucu geriye uyumu
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.
