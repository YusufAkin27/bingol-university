# W2-G - Mobil çevrimdışı ve önbellek ORTA

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 2. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: L.

Sen **W2-G** iş akışı ajanısın (Silinen içerik kalıntısı, geçici dosyalar, iOS yedek, Outbox ORTA, ApiClient ORTA). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: W1-G bitmiş
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w2g && mkdir -p /c/bu_verify_w2g && git archive HEAD | tar -x -C /c/bu_verify_w2g`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w2g/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w2g/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yığın gerekmez** (bu iş akışı mobil/web/belge ağırlıklı): testleri birim/widget/sahte sunucu (MockClient, yerel HttpServer; A15 yöntemi) ile yaz; bir backend yığını gerekirse yalnız kendi COMPOSE_PROJECT_NAME ve boş port ile kur, A7 ortak yığınına (18081) DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W2-G: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (5)

#### T-102 - Silinen / yönetici kaldırması / engellenen içeriğin diske yazılmış kalıntıları temizlenmiyor (görsel baytları, replyTo, list.json önizleme); ImageDiskCache.remove hiç çağrılmıyor  [ORTA | kanıt S]
- **Kaynak bulgular:** A4-04, A15-22, A15-23, A15-24 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil core/cache/message_cache.dart markGone (191-212), list.json lastMessage (249-283), image_disk_cache.dart remove (89-92) ve tavan 40 yazma (35,86), main.dart onBlockedUser (163,168)
- **Düzeltme:** markGone: ek url/thumbUrl'leri ImageDiskCache.remove; replyTo.text=''; list.json lastMessage önizlemesi sıfır; gone mesajda text=''; onBlockedUser ImageDiskCache temizliği; her yazmada artımlı toplam sayacı; portal HTML'i diske yazma
- **Test gereksinimi:** a15 S2.7, I3, I4, I5; MessageCache+ImageDiskCache birim testi

#### T-103 - Kamera/seçici/sıkıştırma geçici dosyaları (tek gösterimlik dahil) silinmiyor; çıkışta da süpürülmüyor  [ORTA | kanıt S]
- **Kaynak bulgular:** A4-05 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/chat/media_camera_page.dart (163-164,209-225), core/platform/video_service.dart, core/outbox/outbox.dart (459)
- **Düzeltme:** Gönderim/kuyruğa kopyalama sonrası ve dispose'ta kaynak dosyayı sil; çıkışta getTemporaryDirectory alt dizinlerini süpür; açılışta artık dosya süpürmesi
- **Test gereksinimi:** Sahte path_provider dizini: signOut sonrası boş

#### T-104 - iOS Application Support altındaki kullanıcı verisi (msg_cache, api_cache, img_cache, outbox_media) yedeğe giriyor; kişisel yanıtlar düz JSON  [ORTA | kanıt S]
- **Kaynak bulgular:** A4-06, A4-14, A8-24 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil core/cache/message_cache.dart (42-45), disk_cache.dart (112-115), image_disk_cache.dart (37-40), outbox.dart (251-254), photo_autosave.dart (43)
- **Düzeltme:** Önbellekleri getApplicationCacheDirectory'ye taşı (Library/Caches yedeklenmez); outbox_media için BuNativeBridge excludeFromBackup (W3-G); kişisel uçları (/users/me, /timetable, /exams, /bookmarks) belleğe indir veya anahtarı Keystore'da tutarak şifrele
- **Test gereksinimi:** Birim: cache dizini; iOS aracı testi isExcludedFromBackup (macOS)

#### T-105 - Outbox ORTA paketi: maxItems aşımında en eski sessiz atılır, saat değişimi kuyruğu bozar, List.sort kararsız, ATTACHMENT_* sınırsız yeniden yükleme, yazma hatası sessiz, failed ögeler medya kotasını tutar, çıkışta bekleyen mesaj uyarısız silinir  [ORTA | kanıt P]
- **Kaynak bulgular:** A15-10, A15-11, A15-12, A15-13, A15-14, A15-15, A15-17, A10-19 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil core/outbox/outbox.dart (359-376, 347, 640-648, 502-506, 440-447, 479-484), chat_detail_page.dart (309-316), session çıkış akışı
- **Düzeltme:** Tavan dolunca yeni enqueue'yu reddet; seq numarası + createdAt>now düzeltme; ek yeniden yükleme sayacı ≤2 sonra failed; yazma hatasında yeniden dene ve enqueue false; kota yalnız pending; çıkışta pendingCount>0 ise onay (ARB kilidi, p35 öneki)
- **Test gereksinimi:** a15 S1.1b/c, S1.7b/c, S1.8, S1.9, S1.11, S1.12 yeşil
- **Bağımlılık:** T-083

#### T-106 - ApiClient ORTA: Content-Length yokken yanıt tavanı uygulanmaz; yazma/GET yarışı bayat veriyi taze damgalar, POST zaman aşımında geçersizleme yok; menü kartı sunucu 500'ünde 'menü girilmedi' gösterir  [ORTA | kanıt P]
- **Kaynak bulgular:** A15-18, A15-19, A15-21 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil core/api.dart (174-183, 219, 395, 355-360), features/home/home_tab.dart menü kartı
- **Düzeltme:** Akışı sayarak kes (await for + maxResponseBytes); GET başlangıç anı yakala, inv>startedAt ise taze damgalama; ağ hatasında yazma için de geçersizle; menü kartında hata ile boş durumu ayır
- **Test gereksinimi:** a15 S3.3, S3.3b, S3.8, U2/U3
- **Bağımlılık:** T-084

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- core/outbox/**, core/api.dart, core/cache/**, features/chat/media_camera_page.dart, core/platform/video_service.dart, features/home/home_tab.dart (menü kartı)

**Dokunmayacakların (başka iş akışının):**
- chat_detail_page.dart (W2-I)

Paylaşılan dosya kilitleri: arb. Flyway aralığın: **-**, indeks öneki **-**. Mobil l10n öneki: **p34**.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- a15 ORTA testleri yeşil
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.
