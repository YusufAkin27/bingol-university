# W2-D - Backend alan mantığı ORTA, gizlilik yan kanalları, mesaj isteği modeli, sohbet videosu

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 2. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: XL.

Sen **W2-D** iş akışı ajanısın (İptal 404, menü fit, bildirim kesmesi, kurum taklidi, gizlilik yan kanalları, dosya erişimi, profil sayımı, gölge engel (profil/takip/etkinlik), mesaj isteği (K-08), sohbet video meta). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: W1-A T-001, W1-D, W1-F bitmiş; K-08, K-10
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w2d && mkdir -p /c/bu_verify_w2d && git archive HEAD | tar -x -C /c/bu_verify_w2d`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w2d/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w2d/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yalıtılmış yığın (smoke):** temiz kopyada `.env.example` -> `.env` (DB_PASSWORD, JWT_SECRET >=32, ADMIN_PASSWORD, `ADMIN_EMAILS=boss@bingol.edu.tr`, `MAIL_ENABLED=false`, `LEGAL_ENFORCE_REACCEPT=false`), `export COMPOSE_PROJECT_NAME=bu_w2d BACKEND_PORT=18240 WEB_PORT=28240`, `docker compose up -d --build`, `BASE=http://localhost:18240 ADMIN_PASSWORD=... ONLY="smoke-..." bash scripts/smoke-all.sh`; bitince `docker compose down -v`. A7 ortak yığınına (18081) ve `flushall` ile başkalarının verisine DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W2-D: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (10)

#### T-026 - Mesaj isteği / rıza modeli (ilk DM ve grup daveti PENDING, kabul edene kadar bildirim/push yok, yanıtsız tek taraflı mesaj sınırı)  [ORTA | kanıt S]
- **Kaynak bulgular:** A16-02, A1-11 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** messaging/** (yeni istek durumu), notification gönderim kapıları, mobil sohbet listesi 'İstekler' (W2-I)
- **Düzeltme:** K-08 kararına göre: ortak bağlam yoksa istek akışı; grup davetinde kabul; presence karşılıklı kabulden sonra; yeni tablo/durum (Flyway)
- **Test gereksinimi:** Servis ve entegrasyon testleri; smoke-messaging yeni akış
- **Bağımlılık:** T-025, K-08
- **KARAR (varsayılan = ÖNERİ):** K-08 DM rızası modeli | Seçenekler: (a) Mevcut + hız sınırı; (b) mesaj isteği: ilk DM yalnız ortak bağlam (ortak kulüp/etkinlik/takip) varsa doğrudan, yoksa istek; grup daveti kabul gerektirir; presence karşılıklı kabul sonrası; (c) kapalı DM (yalnız takip ettikleri) | ÖNERİ: (b). Kısa vadede (W1-D) çıkış sonrası yeniden eklemeyi yasakla, presence'a limit ve gizlilik ekle; tam istek akışı karardan sonra W2-D.

#### T-029 - Gölge engel sızıntısı (profil/takip/etkinlik): follow 404, sayaçlar null, EventAdmission/CoOrganizer tespiti  [ORTA | kanıt P]
- **Kaynak bulgular:** A1-13 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** profile/ProfileService 97, post/follow/FollowService 90, event/admission/EventAdmissionService 179, event/extras/CoOrganizerService 62
- **Düzeltme:** Beni engelleyen için normal yanıt: sabit sayaç 0/false, follow no-op 200, hata yok
- **Test gereksinimi:** ShadowBlockProfileTest genişlet; smoke-block-shadow
- **Bağımlılık:** T-028

#### T-038 - Sohbet videosu yeniden kodlanmıyor, GPS/cihaz meta verisi alıcılara gidiyor (M11/L9)  [ORTA | kanıt S]
- **Kaynak bulgular:** A1-18 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** messaging/media/*, media/Mp4Info, mevcut media/transcode hattı
- **Düzeltme:** Sohbet videosunu transcode hattından geçir (-map_metadata -1 +faststart) veya en azından udta/meta/©xyz kutularını kaldır; K-10 kararıyla uyumlu (transcode kodu silinmez)
- **Test gereksinimi:** Birim: meta kutuları temizlenmiş çıktı; ffmpeg'li ortamda duman
- **Bağımlılık:** K-10
- **KARAR (varsayılan = ÖNERİ):** K-10 Gönderi video hattı silinsin mi? | Seçenekler: (a) Hepsini sil; (b) gönderiye özgü yükleme/CDN/Range/ayarları sil, VideoTranscoder/TranscodeService koru ve sohbette kullan; (c) dokunma | ÖNERİ: (b). Önce üretimde SELECT count(*) FROM post_media WHERE kind='VIDEO' (H-08). 0 ise gönderi tarafı silinir; transcode çekirdeği sohbet videosu için yeniden kullanılır.

#### T-049 - İptal edilen etkinlik katılımcılara 404; bildirim derin bağlantısı ölü; organizatör iptali neden almıyor  [ORTA | kanıt P]
- **Kaynak bulgular:** A12-06 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** event/EventService.ensureVisible, UserEventRepository.attending/mineUpcoming/minePast
- **Düzeltme:** RSVP'si olan kullanıcıya CANCELLED etkinliği salt-okunur göster (durum+neden); 'iptal edilenler' ayrımı; organizatör iptaline cancelReason
- **Test gereksinimi:** Katılımcı iptal sonrası GET 200 CANCELLED

#### T-050 - Yemek senkronunda fit() çağrılmıyor: 1000 karakteri aşan gün tüm senkronu bozup bakım moduna sokar  [ORTA | kanıt S]
- **Kaynak bulgular:** A12-07 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** menu/MenuSyncService.sync (String.join), MenuDay.items length=1000
- **Düzeltme:** fit(String.join(..)) ve gün başına try/catch (hatalı günü atla, devam et)
- **Test gereksinimi:** Uzun gün içeren sahte kaynak testi

#### T-051 - Toplu bildirimlerde sessiz 500/1000 kesmesi (iptal/saat değişimi, kulüp silme, organizatör duyurusu)  [ORTA | kanıt S]
- **Kaynak bulgular:** A12-09 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** event/EventService.NOTIFY_LIMIT=500, EventAdmissionService, community/CommunityService.delete, event/extras/AnnouncementService.MAX_RECIPIENTS=1000, poll/PollAccess.communityUserIds
- **Düzeltme:** afterId imleçli sayfalı döngü veya sendBulk; üst sınır varsa yanıtta truncated:true
- **Test gereksinimi:** 600 katılımcılı etkinlik iptalinde 600 bildirim

#### T-052 - Kulüp/etkinlik/duyuru adlarında kurum taklidi denetimi yok (Bingöl Üniversitesi Rektörlüğü anında ACTIVE)  [ORTA | kanıt P]
- **Kaynak bulgular:** A16-06 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** community/CommunityService.create (134-136), event/EventService.create (195-197), duyuru başlığı; profile/naming/DisplayNamePolicy
- **Düzeltme:** Rezerve ifade denetimi (isReserved) kulüp adı/etkinlik başlığı/duyuru başlığına; eşleşen PENDING_REVIEW'e düşer; bidi/görünmez karakter reddi
- **Test gereksinimi:** Rektörlük/Resmi Duyuru adlı kulüp PENDING_REVIEW; temiz ad ACTIVE
- **Bağımlılık:** T-001
- **KARAR (varsayılan = ÖNERİ):** K-01 'Resmî' etiketi ve bağımsızlık beyanı | Seçenekler: (a) Etiketler kalsın; (b) 'Üniversite programı/takvimi' olarak değiştir; (c) tüm 'resmi' sözcükleri kaldır | ÖNERİ: (b): 'Resmi tatil' kalır; sınav/dönem etiketi 'Üniversite programı'; ölü ARB anahtarlarını sil; Profil>Hakkında ve web alt bilgisine tek satır 'Bağımsız bir uygulamadır; Bingöl Üniversitesi'nin resmî uygulaması değildir' (3 dil). Kod doğrulaması: rozet anahtarları kullanılmıyor, yalnız sınav sekmesi görünür; risk düşük-orta ama App Store 4.1 için ucuz önlem.

#### T-053 - Gizlilik ayarları yan kanallardan atlanıyor: öneri 'reason' bölüm eşleşmesi, DEPARTMENT feed, SharedContext (INTERESTED dahil)  [ORTA | kanıt S]
- **Kaynak bulgular:** A1-16 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** post/follow/FollowService (216-228), post/social/SocialFeedRepository (20), profile/privacy/SharedContextRepository (29,45)
- **Düzeltme:** reason yalnız alan görünürse; ortak bağlamda etkinlik için GOING; DEPARTMENT feed'de yazar görünürlüğü süz
- **Test gereksinimi:** ONLY_ME bölümlü kullanıcı öneri/feed'de bölüm eşleşmesiyle çıkmaz
- **Bağımlılık:** T-024

#### T-054 - /files/** herkese açık: özel kulüp gönderi görselleri URL ile süresiz kimliksiz erişilebilir  [ORTA | kanıt S]
- **Kaynak bulgular:** A1-21 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** config/SecurityConfig (/files/**), common/storage/FileController, community post medya URL'leri
- **Düzeltme:** Özel kulüp görselleri için imzalı/yetkili sunum (MediaUrlSigner deseni) veya URL sızıntısını kabul eden risk notu
- **Test gereksinimi:** Özel kulüp görseli imzasız 403/404

#### T-055 - Profil metin sınırı UTF-16 sayıyor (bio/displayName/faculty), mesaj kod noktası sayıyor; akademik alanlar birbirinden bağımsız güncelleniyor  [ORTA | kanıt P]
- **Kaynak bulgular:** A11-11, A7-08, A11-12 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** profile/dto/ProfileDtos (@Size), profile/ProfileService.update, edit_profile_page sayaç (W3-G)
- **Düzeltme:** @Size yerine kod noktası doğrulayıcı (K-32); fakülte değişince bölüm doğrula/temizle; classYear'ı grade'den türet veya kaldır; hata metni yerelleştirilmiş
- **Test gereksinimi:** 300 emoji bio kabul/ret kuralı tutarlı; Mühendislik+Fen-Edebiyat tutarsız çift reddi
- **KARAR (varsayılan = ÖNERİ):** K-32 Profil metin sayım birimi | Seçenekler: (a) kod noktası her yerde | ÖNERİ: (a): mesaj, bio, ad ve mobil sayaç aynı (Dart runes.length); sunucuda @Size yerine özel doğrulayıcı.

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- event/**, community/**, menu/MenuSyncService, profile/ProfileService+DTO, post/follow/FollowService, post/social/*, profile/privacy/*, common/storage/FileController, config/SecurityConfig (/files), messaging/** (K-08 ve video için)

**Dokunmayacakların (başka iş akışının):**
- push, moderasyon raporlama

Paylaşılan dosya kilitleri: i18n-messages, docs-shared. Flyway aralığın: **V980-V989**, indeks öneki **dom9_**. Mobil l10n öneki: **-**.
Yalıtılmış yığın portların: BACKEND_PORT=18240, WEB_PORT=28240, COMPOSE_PROJECT_NAME=bu_w2d.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- backend: Docker Maven 17 (CLAUDE.md §2) - temiz kopyada `-Dtest=<ilgili sınıflar>` ile hedefli, sonra ilgili paketin tamamı; tam paket (23 dk) koordinatör dalga sonunda koşar
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- smoke-block-shadow, smoke-messaging, smoke-communities-events, smoke-profile-privacy.sh
- K-08 ve K-10 kararları alınmadan T-026/T-038 başlatılmaz
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.
