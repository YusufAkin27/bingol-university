# W2-C - Backend push ve bildirim

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 2. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: M.

Sen **W2-C** iş akışı ajanısın (Android tag, moderasyon hedefi, kampanya çift gönderim, FCM kuyruğu/durum). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: W1-A T-008 bitmiş
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w2c && mkdir -p /c/bu_verify_w2c && git archive HEAD | tar -x -C /c/bu_verify_w2c`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w2c/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w2c/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w2c BACKEND_PORT=18230 WEB_PORT=28230`, `docker compose up -d --build`, `BASE=http://localhost:18230 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W2-C: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (4)

#### T-076 - Android 'tag' varsayılanı tür adı/thread: farklı duyuru/anket/sistem bildirimleri tepside birbirinin yerini alıyor  [ORTA | kanıt S]
- **Kaynak bulgular:** A13-01 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** notification/fcm/FirebaseFcmSender.android(), notification/PushMessages.threadId/of, FirebaseFcmPayloadTest (46)
- **Düzeltme:** tag yalnız birleşmesi istenen yerde (conv:<id>, follow:, postlike:, commpost:); diğerlerinde tag yok veya benzersiz; SYSTEM sohbet bildirimi conv: ile çakışmasın; testi tersine çevir
- **Test gereksinimi:** FirebaseFcmPayloadTest güncelle; GERÇEK CİHAZ doğrulaması (H-09)

#### T-077 - Moderasyon bildirimi targetType=MESSAGE mobilde sohbet kimliği sanılıyor (yanlış sohbet/404)  [ORTA | kanıt S]
- **Kaynak bulgular:** A13-05 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** backend moderation/ModerationNotifier.data; mobil core/push/push_targets.dart _destOf('MESSAGE')
- **Düzeltme:** Sunucu mesaj hedefinde conversationId de göndersin (veya targetType göndermesin); mobil MESSAGE eşlemesi yalnız conversationId varsa
- **Test gereksinimi:** Birim: resolvePushTarget MESSAGE moderasyon yükü

#### T-078 - Push kampanyası çift gönderim koruması yarışta çalışmıyor (iki eşzamanlı istek iki kampanya)  [ORTA | kanıt P]
- **Kaynak bulgular:** A14-09 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** notification/campaign/CampaignService (duplicate kontrolü, ~352 https kuralı sırası)
- **Düzeltme:** Atomik duplicate (Redis SET NX veya benzersiz indeks requestKey/içerik özeti), istemci requestKey; https doğrulama duplicate kontrolünden önce
- **Test gereksinimi:** Eşzamanlı 2 POST → 1x202 + 1x409

#### T-079 - FCM kimliği yok/kapalıyken bildirimler kalıcı kuyruğa yazılmıyor (kimlik sonradan girilince geçmiş push gitmez); üretim FCM durumu bilinmiyor  [ORTA | kanıt S]
- **Kaynak bulgular:** A13-14 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** notification/PushDispatcher.enabled (hold-when-disabled), application.properties
- **Düzeltme:** K-30 kararı; yönetici panelinde FCM kapalı nedeni görünür (W2-K); açılışta ERROR log korunur
- **Test gereksinimi:** PushDispatcher testi hold-when-disabled
- **Bağımlılık:** K-30, H-08
- **KARAR (varsayılan = ÖNERİ):** K-30 FCM kapalıyken push kuyruğu (hold-when-disabled) | Seçenekler: (a) Kapalı (silinir); (b) açık (kuyrukta bekler, 24 sa ömür) | ÖNERİ: FCM kimliği 1-2 gün içinde girilecekse (b), girilmeyecekse (a). Önce üretimde durum (H-08).

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- notification/** (fcm/FirebaseFcmSender tag mantığı hariç zaman aşımı satırları W2-B'nin), moderation/ModerationNotifier.java

**Dokunmayacakların (başka iş akışının):**
- W2-B dosyaları

Paylaşılan dosya kilitleri: i18n-messages, docs-shared. Flyway aralığın: **V975-V979**, indeks öneki **psh9_**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18230, WEB_PORT=28230, COMPOSE_PROJECT_NAME=bu_w2c.

## 4. ÖZEL TALİMATLAR

T-076 testi tersine çevrilir: yalnız birleşmesi istenen yerde tag.

## 5. TEST ve DOĞRULAMA

- backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- FirebaseFcmPayloadTest güncel
- kampanya eşzamanlı test
- docs/changes/push.md
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.
