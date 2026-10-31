# W2-F - Backend KVKK, saklama ve destek

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 2. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: L.

Sen **W2-F** iş akışı ajanısın (Hesap silme kapsamı, saklama süreleri, rehber eşleştirme, genel destek formu, admin çözme/Sentry). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: K-13, K-14, K-16
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w2f && mkdir -p /c/bu_verify_w2f && git archive HEAD | tar -x -C /c/bu_verify_w2f`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w2f/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w2f/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w2f BACKEND_PORT=18260 WEB_PORT=28260`, `docker compose up -d --build`, `BASE=http://localhost:18260 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W2-F: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (5)

#### T-061 - Rehber eşleştirme: tuzsuz SHA-256 ile öğrenci dizini taraması (saatte 3000 aday), kullanıcı reddedemiyor; email_sha256 kalıcı ve aydınlatmada yok; mobil izin bağlamsız  [ORTA | kanıt PS]
- **Kaynak bulgular:** A16-07, A8-15, A11-21, A1-36, A4-15 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** profile/ContactMatchService+Controller, user/User.emailSha256, mobil core/contacts/contacts_service.dart + auth/permissions_page.dart (W2-I/W3-G)
- **Düzeltme:** 'Rehberden bulunabilirim' gizlilik anahtarı (varsayılan KAPALI), userId yalnız karşılıklı eşleşmede, günlük toplam aday tavanı 2000, numara@ biçimlerini hariç tut; aydınlatmaya ekle; mobil iznini ilk kullanıma ertele
- **Test gereksinimi:** Gizlilik kapalı kullanıcı eşleşmede dönmez; günlük tavan 429; smoke-contacts-match
- **Bağımlılık:** K-16, T-139
- **KARAR (varsayılan = ÖNERİ):** K-16 Rehber eşleştirme gizliliği | Seçenekler: (a) Mevcut limit; (b) 'Rehberden bulunabilirim' anahtarı varsayılan KAPALI, userId yalnız karşılıklı eşleşmede, günlük 2000 aday tavanı, okul numarası@ hariç | ÖNERİ: (b). Mobil izin ilk kullanımda istensin.

#### T-062 - Genel destek formu: elapsedMs/honeypot istemci kontrollü; ortak 100/sa tavanıyla form kilitleme; izleme anahtarı süresiz  [ORTA | kanıt PS]
- **Kaynak bulgular:** A16-12 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** support/ticket/PublicSupportService.submit, track token
- **Düzeltme:** Sunucu imzalı zaman damgalı form jetonu; küresel tavan yerine kod bütçesi (requireCodeQuota); izleme anahtarına son kullanma/ticket kapanınca iptal
- **Test gereksinimi:** elapsedMs uydurma ile gönderim reddedilir; public-support-e2e.sh

#### T-063 - Hesap silme/KVKK kapsamı: blocked_attempt_log, profanity_hit_log, message_attachment_view, mail_outbox.to_address (düz kod dahil), OWNER üyelik satırı, club_audit/message_access_audit hedefi  [ORTA | kanıt PS]
- **Kaynak bulgular:** A8-16, A1-26, A11-09, A8-25 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** profile/AccountDataPurger (DELETES/SCRUBS), dbmaint/DbMaintenanceJob.mailSent, mail/MailService.vars, export DataExporter, docs/DATABASE.md matrisi
- **Düzeltme:** Her tablo için sil/anonimleştir/yasal saklama kararı; mail_outbox vars_json'dan code sil/maskele; adres eşleşmeli silme; OWNER satırını kapat; AccountDataPurgerCoverageTest (yeni user-sütunlu tablo listede yoksa kırmızı)
- **Test gereksinimi:** Coverage testi + silme sonrası information_schema taraması

#### T-064 - Silinen mesaj / düzenleme geçmişi / tek gösterimlik görsel / edit-delete penceresi süresiz; yedekte silinen veri canlanır (silme defteri yok)  [ORTA | kanıt S]
- **Kaynak bulgular:** A8-14, A1-27, A8-17 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** application.properties (app.chat.deleted-retention-days=0, view-once-retention-days=365, edit/delete-window=0), DeletedMessageRetention, docs/BACKUP_RESTORE.md bölüm 5/2
- **Düzeltme:** K-14 değerleriyle üretim ayarı ve saklama politikası eşleme; silinen kullanıcı kimlikleri için yedek dışı 'silme defteri' + geri yükleme betiğinde yeniden uygula; uzak saklama ≤365 gün
- **Test gereksinimi:** DeletedMessageRetention testi; geri yükleme provası betiği (staging)
- **Bağımlılık:** K-14
- **KARAR (varsayılan = ÖNERİ):** K-14 Silinen mesaj / tek gösterimlik / düzenleme-silme penceresi | Seçenekler: (a) mevcut; (b) deleted 90 gün, view-once açıldıktan 7 gün (kullanılmamış 30 gün), düzenleme penceresi 24 sa, silme sınırsız | ÖNERİ: (b). Beyan ('bir kez') ve KVKK ile hizalanır; aydınlatma metni sürümüne işlenir.

#### T-065 - Yönetici sohbet çözme prod'da varsayılan açık; isteğe bağlı Sentry üçüncü taraf aktarımı belgelenmemiş  [ORTA | kanıt S]
- **Kaynak bulgular:** A8-19, A8-20 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** docker-compose.prod.yml:127, application.properties, config/ProdSettingsValidator, pom.xml sentry-logback, docs/legal/internal/08
- **Düzeltme:** K-13 kararı: rapor kimliği zorunlu + kota; DSN doluysa validator uyarısı + send-default-pii=false; tedarikçi listesi güncelle
- **Test gereksinimi:** ProdSettingsValidatorTest
- **Bağımlılık:** T-015
- **KARAR (varsayılan = ÖNERİ):** K-13 Yönetici sohbet çözme (CRYPTO_ADMIN_DECRYPT_ENABLED) | Seçenekler: (a) Açık; (b) kapalı varsayılan; (c) açık ama rapor kimliği/iki kişi onayı zorunlu | ÖNERİ: (c): yalnız şikâyet kaydı bağlı konuşmalarda, gerekçe ≥20 + rapor kimliği, saatlik kota, FULL + (isteğe bağlı) ikinci onay; kullanıcıya erişim sonrası bildirim hukuk görüşüyle.
- **KARAR (varsayılan = ÖNERİ):** K-31 Prod ADMIN_EMAILS ≥2 ve Sentry | Seçenekler: (a)/(b) | ÖNERİ: ADMIN_EMAILS en az 2 adres (validator WARN); Sentry kullanılmasın (DSN boş), kullanılacaksa AB bölgesi + send-default-pii=false + tedarikçi listesi.

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- profile/AccountDataPurger, profile/ContactMatch*, dbmaint/**, mail/MailService, support/ticket/PublicSupportService, docs/DATABASE.md, docs/legal/internal/*, application.properties saklama anahtarları, config/ProdSettingsValidator (Sentry)

**Dokunmayacakların (başka iş akışının):**
- moderasyon raporlama

Paylaşılan dosya kilitleri: app-props, docs-shared, i18n-messages. Flyway aralığın: **V995-V999**, indeks öneki **kvk9_**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18260, WEB_PORT=28260, COMPOSE_PROJECT_NAME=bu_w2f.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- AccountDataPurgerCoverageTest yeşil
- smoke-contacts-match, public-support-e2e
- docs/DATABASE.md matris
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.
