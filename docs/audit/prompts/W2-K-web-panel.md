# W2-K - Web: yönetim paneli ve site ORTA

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 2. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: L.

Sen **W2-K** iş akışı ajanısın (Taşma, izin uyumu, panel eksikleri, CLS/soft 404). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: W1-B (users.verify izni, yeni uçlar) ve W1-C bitmiş; docs/openapi.json yenilenmiş
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: web: `npm run lint && typecheck && test && build && check:contract && check:i18n`; Playwright e2e/ ilgili

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w2k && mkdir -p /c/bu_verify_w2k && git archive HEAD | tar -x -C /c/bu_verify_w2k`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w2k/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w2k/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yığın gerekmez** (bu iş akışı mobil/web/belge ağırlıklı): testleri birim/widget/sahte sunucu (MockClient, yerel HttpServer; A15 yöntemi) ile yaz; bir backend yığını gerekirse yalnız kendi COMPOSE_PROJECT_NAME ve boş port ile kur, A7 ortak yığınına (18081) DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W2-K: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 1b. SÖZLEŞMELER (aynı dalgada paralel çalışan akışlarla; alan/davranış adlarını DEĞİŞTİRME)

- **C8** (W1-B -> W2-K): Yeni izin `users.verify` (yalnız FULL) ve gerekçe kuralları; web nav/GuardedAction bunu W2-K'da izler.

## 2. KAPSAM - T maddeleri (4)

#### T-155 - Web panel yatay taşma: /admin/audit (1280/768) ve 390 px'te mail kuyruğu, roller, erişim engelleri, push altyapısı  [ORTA | kanıt P]
- **Kaynak bulgular:** A3-01, A3-02 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** web/src/pages/admin/AuditPage + audit/*, MailQueuePage, RolesPage, AccessBans, PushOpsPage (CSS modülleri)
- **Düzeltme:** Tablo sarmalayıcı overflow-x:auto; yol hücresi overflow-wrap:anywhere/min-width:0; istatistik gridleri auto-fit minmax(min(100%,9rem),1fr); dd overflow-wrap
- **Test gereksinimi:** Playwright/ekran görüntüsü 1280/768/390; vitest

#### T-156 - Web: menü izni ↔ backend izni uyumsuz (Bölüm duyuruları MODERATOR), 403 'bağlantınızı kontrol edin' yanıltması, rapor detayı VIEWER, izin yüklenirken gereksiz istek (403 gürültüsü), yazma düğmeleri GuardedAction ile korunmuyor  [ORTA | kanıt P]
- **Kaynak bulgular:** A3-03, A3-04, A3-05, A3-06, A14-10 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** web/src/layouts/adminNav.ts, auth/permissions.tsx (RequirePerm loading), UserDetail (devices/audit/sessions sekmeleri), ReportsPage, Dashboard/Sources, tickets/posts/mail/push ops/access-bans GuardedAction
- **Düzeltme:** Nav perm değerlerini AdminPermissionPolicy ile otomatik karşılaştıran test; yetkisiz sekme/bölüm gizle; 403 için 'yetkiniz yok' mesajı; RequirePerm loading iken render etme; rapor detay sorgusu useCan('chat.read'); yazma düğmeleri GuardedAction
- **Test gereksinimi:** adminNav↔policy testi; VIEWER/EDITOR/SUPPORT/MODERATOR Playwright gezintisi
- **Bağımlılık:** T-010, T-018

#### T-157 - Panel kapsam eksikleri: push cihaz son sonucu (lastPush*), FCM kapalı nedeni + errorCodes dağılımı, kullanıcı bildirim tercihleri, sunucu önbelleği (C1) durumu/temizleme  [ORTA | kanıt S]
- **Kaynak bulgular:** A3-07, A3-23, A3-24, A3-25, A14-14 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** web/src/api/adminUsers.ts PushDevice, pages/admin/users/PushDevicesTab.tsx, FcmTab, PushOpsPage; backend cache namespace invalidate ucu (system.write) gerekirse
- **Düzeltme:** PushDevicesTab'a son push durumu/hata kodu sütunu + Türkçe açıklama tablosu; Push altyapısı sayfasına DEAD hata kodu dağılımı ve FCM kapalı nedeni; kullanıcı detayında salt okunur tercihler; önbellek 'geçersiz kıl' düğmesi (yeni backend ucu → AdminPermissionPolicy kuralı)
- **Test gereksinimi:** check:contract; vitest; RbacCoverageTest (yeni uç)

#### T-158 - Web site: FAQ/Hukuki metinler CLS (0.21/0.18); bilinmeyen yollar HTTP 200 (soft 404), 404 sayfası h1'siz  [ORTA | kanıt P]
- **Kaynak bulgular:** A3-11, A3-12 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** web/src/pages/site (FAQ, Legal), web/nginx.conf (try_files), prerender, NotFoundPage
- **Düzeltme:** İskelet min-height / prerender'a ilk SSS grubu; prerender 404.html + nginx error_page 404 (sitemap rotaları dışı); X-Robots-Tag noindex (/support/track, bilinmeyen); 404'e h1/description
- **Test gereksinimi:** Lighthouse CLS<0.1; curl 404 durumu

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- web/src/**, web/nginx.conf, nginx-security.conf, web/scripts

**Dokunmayacakların (başka iş akışının):**
- backend (yalnız yeni önbellek ucu için W1-B'ye talep)

Paylaşılan dosya kilitleri: docs-shared. Flyway aralığın: **-**, indeks öneki **-**. Mobil l10n öneki: **web i18n anahtar önekü p-yok (admin.*, site.*)**.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- web: `npm run lint && typecheck && test && build && check:contract && check:i18n`; Playwright e2e/ ilgili
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- Kalite kapıları yeşil
- Roller x rotalar Playwright taraması
- Lighthouse CLS < 0.1
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.
