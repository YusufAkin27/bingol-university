# W1-E - Backend: mesajlaşma performansı ve mesaj sırası

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 1. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: M (≈1.5 gün).

Sen **W1-E** iş akışı ajanısın (500 üyeli oda bildirim dağıtımı, WS teslim MGET, SEND sırası). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: Yok
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar; ölçüm: 500 üyeli grup x 8 mesaj (A2 §T-035 tarifi) ve 300 WS alıcı

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w1e && mkdir -p /c/bu_verify_w1e && git archive HEAD | tar -x -C /c/bu_verify_w1e`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w1e/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w1e/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w1e BACKEND_PORT=18150 WEB_PORT=28150`, `docker compose up -d --build`, `BASE=http://localhost:18150 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W1-E: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (3)

#### T-035 - 500 üyeli odada bildirim dağıtımı ~115 bildirim/sn (alıcı başına 6-8 sorgu, fiilen 2 iş parçacığı); kuyruk dolarsa bildirim sessizce atlanır  [YÜKSEK | kanıt P]
- **Kaynak bulgular:** A2-02 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** messaging/MessagingFanoutConfig, messaging/MessageService.notifyOffline (339,393-443), notification/NotificationService.doSend
- **Düzeltme:** Alıcıları parçala, tercih/aktiflik/token tek IN sorgusu; notification için çok satırlı INSERT .. ON CONFLICT (user_id,collapse_key) WHERE read_at IS NULL DO UPDATE (kısmi benzersiz indeks, yeni V9xx); aynı sohbet görevlerini birleştir; havuz çekirdek=max=4 ve reddedilen görev için metrik/uyarı
- **Test gereksinimi:** 500 üye x 8 mesaj ölçümü: son bildirim <2 sn; NotificationServiceTest; smoke-messaging; migration PG'de doğrulama

#### T-036 - WebSocket teslimi alıcı sayısıyla doğrusal (alıcı başına sıralı Redis suspended kontrolü)  [ORTA | kanıt P]
- **Kaynak bulgular:** A2-04 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** messaging/ws/ChatEventBus.deliverLocal (64-70,82-91)
- **Düzeltme:** Zarf başına tek MGET veya askı kümesini 5-10 sn bellek önbelleği; yalnız yerel bağlı kullanıcılar için sorgula
- **Test gereksinimi:** 300 alıcı p95 <300 ms; ws-test.js

#### T-037 - Aynı WS oturumundan SEND'ler eşzamanlı işleniyor: mesaj sırası bozuluyor; id/commit/createdAt sırası farklı, after= geç commit olanı atlayabilir  [ORTA | kanıt P]
- **Kaynak bulgular:** A10-03, A10-16 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** messaging/ws/WebSocketConfig (76-80), ChatWsController.send, MessageRepository.before/after, ConversationMember first_visible
- **Düzeltme:** clientInboundChannel tek iş parçacığı veya kullanıcı başına sıralı kuyruk; süzgeçleri kimlik tabanlı (first_visible_message_id); after için kısa geri alma payı
- **Test gereksinimi:** ws-test.js: aynı soketten 20 hızlı chat.send sırası korunur (betiği güncelle)

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- messaging/MessageService.java, MessagingFanoutConfig.java, ws/ChatEventBus.java, ws/WebSocketConfig.java, ws/ChatWsController.java, MessageRepository.java
- notification/NotificationService.java (doSend toplu), NotificationRepository.java, yeni migration (kısmi benzersiz indeks)
- docs/PERFORMANCE.md ve docs/changes/messaging.md ölçüm notları (kilit: docs-shared)
- ilgili testler; scripts/ws-test.js'ye YALNIZ yeni sıra testi bölümü ekleme YOK (W3-H); scripts/perf/** ölçüm betikleri

**Dokunmayacakların (başka iş akışının):**
- messaging/ConversationService, MessageActionService, MessageAttachmentService, ws/PresenceService, MessagingDtos (W1-D'nin); push paketi (FirebaseFcmSender, PushOutbox*) - W2-B/W2-C

Paylaşılan dosya kilitleri: docs-shared. Flyway aralığın: **V940-V949**, indeks öneki **fan9_**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18150, WEB_PORT=28150, COMPOSE_PROJECT_NAME=bu_w1e.

## 4. ÖZEL TALİMATLAR

Davranışı koru: bildirim tercihleri, sessiz saat, mute, engel, push kapıları (PushGate) aynı sonucu vermeli; yalnız sorgu sayısı düşer. Kısmi benzersiz indeks için (user_id, collapse_key) WHERE read_at IS NULL; mevcut verideki yinelenenleri migration içinde temizle (en yeni kalsın). Kuyruk dolarsa 'sessizce atla' yerine metrik + WARN ve görev birleştirme. T-037: yorumu değil testi güvene al (20 hızlı SEND sırası). DÜŞÜK sapma: yalnız bu T'leri yap, A10-18 (push önizleme substring) W3-F'de.

## 5. TEST ve DOĞRULAMA

- backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar; ölçüm: 500 üyeli grup x 8 mesaj (A2 §T-035 tarifi) ve 300 WS alıcı
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- Ölçüm öncesi/sonrası tablosu docs/PERFORMANCE.md'de
- smoke-messaging + ws-test.js yalıtılmış yığında (gölge engel testleri W3-H'de güncellenecek: beklenen 2 eski FAIL)
- migration V870→V94x yolunda ve boş PG'de uygulanır (A7 yöntemi)
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.
