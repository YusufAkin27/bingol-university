# W3-C - Backend metin ve çok dil

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 3. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: M.

Sen **W3-C** iş akışı ajanısın (Doğrulama mesajı, teknik metin, ICS/e-posta, çoğul AR, terim). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: K-23
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w3c && mkdir -p /c/bu_verify_w3c && git archive HEAD | tar -x -C /c/bu_verify_w3c`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w3c/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w3c/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w3c BACKEND_PORT=18310 WEB_PORT=28310`, `docker compose up -d --build`, `BASE=http://localhost:18310 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W3-C: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (3)

#### T-129 - Doğrulama hatası yanıtında ham alan adı ('displayName: boş değer olamaz'); Hibernate AR varsayılan mesajı bozuk  [ORTA | kanıt P]
- **Kaynak bulgular:** A9-16 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** common/ApiExceptionHandler.validation, FieldApiException, ValidationMessages_{tr,en,ar}.properties
- **Düzeltme:** field ayrı alan, message yalnız yerelleştirilmiş cümle; alan etiket sözlüğü
- **Test gereksinimi:** Dinamik: register boş ad 3 dilde; mobil errorText
- **Bağımlılık:** T-004

#### T-130 - Kullanıcıya sızan teknik metinler (INVALID_ROLE rol sabitleri, yyyy-MM-dd, CALENDAR/EXAM/ANNOUNCEMENT, Hata kodu: ACCESS_BLOCKED, BUILD_ENV)  [ORTA | kanıt S]
- **Kaynak bulgular:** A9-17 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** backend messages.properties (122 vb.), mobil sistemuiBlockedCode, p01ConfigCode/configError
- **Düzeltme:** Rol adlarını yerelleştir, biçimi GG.AA.YYYY örneğiyle yaz; ham kodu yalnız 'destek kodu' etiketiyle
- **Test gereksinimi:** i18n bütünlük testi

#### T-131 - ICS takvim adı sabit Türkçe; e-posta tarihleri tek biçim ve saat dilimsiz; e-posta içerik/teslimat gözlemleri (Reply-To çelişkisi, noreply, kopya anahtar kümeleri, E-mail yazımı)  [ORTA | kanıt S]
- **Kaynak bulgular:** A9-18, A9-19, A9-20 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** academic/IcsBuilder (42), auth/NewLoginNotifier (23), AuthService (264), mail.properties, MailTransport.applyHeaders, mail-templates
- **Düzeltme:** Dile göre takvim adı; EN '10 Nov 2026, 14:05 (UTC+3)'; Reply-To ile alt bilgi çelişkisini gider; gövdeye güvenlik satırı; ölü mail.* kopya anahtarlarını kaldır
- **Test gereksinimi:** MailRenderer testleri 3 dil
- **Bağımlılık:** H-05

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- backend i18n/*.properties, ValidationMessages_*, mail-templates, ApiExceptionHandler.validation

**Dokunmayacakların (başka iş akışının):**
- mobil

Paylaşılan dosya kilitleri: i18n-messages. Flyway aralığın: **-**, indeks öneki **-**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18310, WEB_PORT=28310, COMPOSE_PROJECT_NAME=bu_w3c.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- I18nMessagesIntegrityTest
- dinamik 3 dil örnekleri
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.
