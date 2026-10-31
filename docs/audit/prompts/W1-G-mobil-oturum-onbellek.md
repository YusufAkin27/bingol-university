# W1-G - Mobil: oturum nesli, çıkış temizliği, kuyruk/önbellek sağlamlığı, açılış hızı, görsel hattı, galeriye kaydet

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 1. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: XL (≈3 gün).

Sen **W1-G** iş akışı ajanısın (Outbox bozuk depo, oturum nesli, çıkış envanteri, captive portal, şema, 5xx dalgası, açılış, görsel HttpClient, otomatik kaydetme, iOS Keychain). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: W1-H ile SÖZLEŞME: C5, C6 (bkz. plan)
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol; a15 test dosyalarını (C:\bu_qa\a15\tests\ varsa; yoksa A15 raporu Ek-A eşlemesinden yeniden yaz) repoya mobile/test/a15/ olarak ekle

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w1g && mkdir -p /c/bu_verify_w1g && git archive HEAD | tar -x -C /c/bu_verify_w1g`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w1g/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w1g/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yığın gerekmez** (bu iş akışı mobil/web/belge ağırlıklı): testleri birim/widget/sahte sunucu (MockClient, yerel HttpServer; A15 yöntemi) ile yaz; bir backend yığını gerekirse yalnız kendi COMPOSE_PROJECT_NAME ve boş port ile kur, A7 ortak yığınına (18081) DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W1-G: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 1b. SÖZLEŞMELER (aynı dalgada paralel çalışan akışlarla; alan/davranış adlarını DEĞİŞTİRME)

- **C5** (W1-G -> W1-H): `Outbox` mevcut public API'si (enqueue/remove/deliveries/items) imza değiştirmeden kalır; W1-G yalnız ekleme yapar.
- **C6** (W1-G -> W1-H): `PhotoAutoSave.considerReceived/saveSent/takeDeniedNotice` imzaları sabit (çağrı yeri `chat_detail_page.dart`, W1-H).
- **C7** (W1-A <-> W1-G): Sunucu refresh idempotansı (T-007) ve mobil oturum nesli (T-084) birbirinden bağımsız; ikisi de gerekli.

## 2. KAPSAM - T maddeleri (10)

#### T-083 - Kuyruk deposu okunamazsa/bozuksa TÜM bekleyen mesajlar ve medya dosyaları açılışta sessizce silinir  [KRİTİK | kanıt P]
- **Kaynak bulgular:** A15-01 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil core/outbox/outbox.dart load (334-352), _save, _sweepOrphanFiles
- **Düzeltme:** Okuma istisnasında _loaded=false bırakıp yeniden dene (silme yok); bozuk JSON'u outbox_v1_corrupt anahtarına taşı ve kayıt kayıt kurtar; _sweepOrphanFiles yalnız başarılı yüklemeden sonra
- **Test gereksinimi:** a15 S1.4a (kesik JSON kuyruğu korunur) + okuma istisnası atan sahte depo ile ikinci load kurtarır; S1.4b yeşil kalır

#### T-084 - Oturum nesli yok: çıkışla yarışan refresh oturumu geri getirir; uçuştaki GET önceki kullanıcının yanıtını yeni hesabın önbelleğine yazar; süren drain eski hesabın mesajını gönderir; MessageCache.clear yarışı; signOut silme hatası yutulur  [KRİTİK | kanıt PV]
- **Kaynak bulgular:** A15-04, A15-05, A15-16, A15-20, A4-02, A4-03, A4-13 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil core/api.dart (_doRefresh 492-512, setTokens 516-530, önbellek anahtarı $lang|u|$path 216-221,402-412), core/session.dart (signOut/_persist 310-360), core/outbox/outbox.dart drain (578-620) ve clear, core/cache/message_cache.dart clear/_loadConv
- **Düzeltme:** ApiClient'a oturum 'nesil' sayacı (setTokens(null)/ilk girişte artar); istek başında nesil yakala, yanıtta değiştiyse önbelleğe YAZMA ve SESSION_CHANGED fırlat; _doRefresh sonucu nesil değiştiyse at; _persist tek Future zincirine al; Outbox.clear kuşak sayacı + drain her adımda byClientId kontrolü; MessageCache kuşak sayacı; signOut silme başarısızsa kısa yeniden dene + signedOut işareti
- **Test gereksinimi:** a15 S2.11, S5.x, S1.13, S2.8 testleri yeşil; ApiClient: refresh uçuşta iken setTokens(null) → tokens null kalır ve onTokensChanged(yeni) çağrılmaz

#### T-085 - Çıkışta temizlenmeyen kullanıcıya özel yerel depolar: arama geçmişi (recent_searches), photo_autosave.json (ayar+kaydedilen ek kimlikleri), ders hatırlatıcı ayarı  [KRİTİK | kanıt P]
- **Kaynak bulgular:** A15-03 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/search/search_page.dart (175,214-232), features/chat/photo_autosave.dart (37-65), academic reminders deposu, main.dart:165-169 onUserDataCleared
- **Düzeltme:** onUserDataCleared'a arama geçmişi, PhotoAutoSave sıfırlama (dosya+bellek), hatırlatıcı deposu; kural: yeni kullanıcıya özel depo = temizleme kancası + 'çıkış sonrası tüm depolar boş' envanter testi (secure storage anahtar listesi dahil)
- **Test gereksinimi:** a15 S2.9 (anahtar envanteri genişletilmiş) yeşil

#### T-086 - Captive portal / proxy 200 (JSON olmayan gövde) 'başarı' sayılıyor; null gövde önbelleğe yazılıyor; bağlantı 'çevrimiçi' görünüyor  [YÜKSEK | kanıt P]
- **Kaynak bulgular:** A15-06 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil core/api.dart _decode (458-470) ve önbellek yazımı (402-412), core/connectivity/connectivity_service.dart (23)
- **Düzeltme:** 2xx'te JSON çözülemezse/Content-Type JSON değilse ApiError(0,'BAD_RESPONSE'), reportSuccess çağırma, önbelleğe yazma; 204 dışında null gövdeyi önbellekleme
- **Test gereksinimi:** a15 S3.5: portal HTML sonrası ikinci get AĞA gider

#### T-087 - Tip-bozuk / uyumsuz mesaj kaydı sohbeti kalıcı açılmaz bırakıyor; mesaj önbelleği şema sürümü okunmuyor  [YÜKSEK | kanıt P]
- **Kaynak bulgular:** A15-07 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil core/cache/message_cache.dart (_loadConv 136-150, 'v':1 yazılıyor 309, upsertMessage 177-186); chat_detail_page _boot savunma try/catch W1-H'de
- **Düzeltme:** _loadConv v==1 ve her öğede id is num doğrula, aksi halde dosyayı sil; upsertMessage/markGone try/catch
- **Test gereksinimi:** a15 S2.4b ve ui U1 (v:99 kayıtlı sohbet açılır, sunucu mesajı gelir) yeşil

#### T-088 - 5xx dalgası (502/503 deploy) kuyruktaki mesajları 'Gönderilemedi'ye çevirir; ağ geçidi hatası çevrimiçi sayılır  [YÜKSEK | kanıt P]
- **Kaynak bulgular:** A15-08 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil core/outbox/outbox.dart (663-676 serverFails/maxServerFails), core/connectivity/connectivity_service.dart (23), core/api.dart (345-360)
- **Düzeltme:** 502/503/504 ve Retry-After'lı yanıtları ağ hatası gibi ele al (serverFails sayma) veya eşiği süreye bağla (≥30 dk); reportSuccess yalnız status<500 ve JSON yanıtta
- **Test gereksinimi:** a15 S1.6 ve conn C1/C2 yeşil

#### T-089 - Splash /auth/me yanıtını bekliyor (kötü ağda ~40 sn); runApp öncesi seri secure-storage okumaları; tema/dil yüklemesi sonradan (flash); soğuk açılışta mükerrer/gereksiz istekler (/me/summary, /app/info iki kez, her açılışta dil PATCH)  [YÜKSEK | kanıt ST]
- **Kaynak bulgular:** A5-02, A5-06, A5-15, A5-05 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil core/session.dart restore/_loadMe (92-133), main.dart (108-139), core/app_gate.dart (116-123), features/shell/app_shell.dart (60-62,101-117), features/home/home_tab.dart (94-124), core/api.dart (in-flight GET)
- **Düzeltme:** Token varsa HEMEN signedIn (kabuk), /auth/me arka planda (yalnız kesin 401'de çıkış) veya splash 2-3 sn üst sınırı; secure-storage okumaları Future.wait + runApp önce; tema/dil paralel yükle; ApiClient tek uçuşlu GET; dil PATCH yalnız değişince; HomeTab /app/info AppGate sonucundan
- **Test gereksinimi:** Widget/ApiClient testleri; --trace-startup ölçümü zayıf ağ (H-09); mevcut session/app_gate testleri

#### T-090 - Görsel indirme her görsel için yeni HttpClient (keep-alive yok); Keşfet/etkinlik/haber/yemek görselleri diske yazılmıyor (Image.network)  [YÜKSEK | kanıt ST]
- **Kaynak bulgular:** A5-03 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil core/cache/image_disk_cache.dart (185), features/posts/post_card.dart (40), features/events/event_cover.dart (33), widgets/common.dart NewsThumb (214), features/menu/menu_photo.dart (32), features/profile/user_profile_page.dart (807)
- **Düzeltme:** DiskNetworkImage için tek statik HttpClient (maxConnectionsPerHost≈6, idleTimeout 15 sn); Image.network yerlerini BuImage/persistentNetworkImage ile değiştir (kullanıcıya özel yetkili görselde persist ayrımı korunur); menü fotoğrafına ResizeImage
- **Test gereksinimi:** Görsel önbellek birim testleri (I1-I8); ağ isteği sayısı testi: ikinci yükleme diskten

#### T-091 - Sohbet fotoğraflarının galeriye otomatik kaydı varsayılan AÇIK (gönderen oda/grup dahil, rızasız) ve kapatma anahtarı yalnız ULAŞILAMAZ (ölü) SettingsPage içinde  [YÜKSEK | kanıt PV]
- **Kaynak bulgular:** A4-09, A10-09, A8-24 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/chat/photo_autosave.dart (enabled() varsayılan true 105-106), features/profile/settings_page.dart (ölü; tek anahtar burada 279-284), canlı gizlilik sayfası (privacy_data_page.dart)
- **Düzeltme:** K-12: varsayılan KAPALI (mevcut kullanıcı için açık seçilmediyse kapalı say), ilk açılışta rıza metni, anahtarı canlı Profil > Gizlilik ve veriler sayfasına taşı (ARB kilidi, p30 öneki), yalnız birebir sohbet; çıkışta temizlik T-085 ile
- **Test gereksinimi:** photo_autosave birim testi: yeni kurulum enabled()==false; çıkış sonrası saved boş; widget testi anahtar canlı sayfada
- **Bağımlılık:** T-085
- **KARAR (varsayılan = ÖNERİ):** K-12 Galeriye otomatik kaydetme | Seçenekler: (a) Varsayılan açık; (b) varsayılan KAPALI, açıkça etkinleştirme + ilk fotoğrafta rıza; (c) özelliği kaldır | ÖNERİ: (b); anahtar canlı 'Profil > Gizlilik ve veriler' sayfasına taşınır (şimdiki tek anahtar ulaşılamayan SettingsPage içinde); yalnız birebir sohbet; çıkışta ayar ve kayıt listesi temizlenir.

#### T-092 - iOS Keychain: erişilebilirlik default (cihaz yedeğine taşınabilir); outbox_v1 yeniden kurulumda kalır (FreshInstallGuard yalnız access/refresh siler — kısmen kapandı)  [ORTA | kanıt PV]
- **Kaynak bulgular:** A4-07 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil core/session.dart (FlutterSecureStorage), core/outbox/outbox.dart, core/device_identity.dart, core/platform/fresh_install.dart
- **Düzeltme:** IOSOptions(accessibility: first_unlock_this_device); FreshInstallGuard.sessionKeys'e outbox_v1 ekle (device_id bilerek korunur)
- **Test gereksinimi:** fresh_install_test genişlet (outbox_v1 silinir, device_id kalır)

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- mobile/lib/core/api.dart, session.dart, main.dart, app_gate.dart, device_identity.dart
- mobile/lib/core/outbox/** (public metot imzalarını DEĞİŞTİRME, yalnız ekle)
- mobile/lib/core/cache/** (message_cache, disk_cache, image_disk_cache, cache_lifecycle, cache_policy)
- mobile/lib/core/connectivity/**, core/platform/fresh_install.dart
- features/shell/app_shell.dart, features/home/home_tab.dart (home_parts.dart W1-J'nin)
- features/search/search_page.dart (arama geçmişi), akademik hatırlatıcı deposu
- features/chat/photo_autosave.dart (imzalar sabit: considerReceived/saveSent/takeDeniedNotice), features/profile/privacy_data_page.dart (anahtar satırı)
- features/posts/post_card.dart, features/events/event_cover.dart, widgets/common.dart (NewsThumb), features/menu/menu_photo.dart, features/profile/user_profile_page.dart (807 civarı Image.network)
- mobile/lib/l10n/*.arb (YALNIZ kilitle: arb; önek p30)
- mobile/test/** (kendi testlerin; a15 testlerini mobile/test/a15/ altına KALICI taşı)
- docs/MOBILE_UI.md bölüm 4.2 çıkış temizliği envanteri

**Dokunmayacakların (başka iş akışının):**
- features/chat/chat_detail_page.dart, chat_tab.dart, core/realtime/** (W1-H); android/** ve ios/** (W1-I); features/auth/welcome_page.dart, home_parts.dart (W1-J)

Paylaşılan dosya kilitleri: arb, docs-shared. Flyway aralığın: **-**, indeks öneki **-**. Mobil l10n öneki: **p30 (örn. p30AutosaveTitle); kilit arb**.

## 4. ÖZEL TALİMATLAR

KRİTİK ÖNCELİK SIRASI: önce T-083, sonra T-084, T-085, T-086, T-087, T-088, sonra açılış/görsel/otokayit. Oturum nesli tasarımı: ApiClient içinde monoton `_gen` sayacı; setTokens(null) ve ilk giriş artırır; her istek başında yakalanır; yanıtta farklıysa önbelleğe YAZMA ve ApiError(0,'SESSION_CHANGED'); _doRefresh aynı kontrolü yapar; Outbox.clear ve MessageCache.clear kendi kuşak sayacına sahip. T-091: SettingsPage ulaşılamaz (kanıt: grep SettingsPage lib → yok); anahtarı privacy_data_page.dart'a taşı (arayüz KİLİTLİ: yalnız mevcut satır bileşenlerini kullan, yeni görsel dil icat etme), varsayılan KAPALI, çıkışta temizle; settings_page.dart'a DOKUNMA (W4-A siler). PhotoAutoSave imzaları sabit kalmalı (chat_detail_page W1-H'de çağırıyor). Uyumluluk: eski diskte kayıt (enabled anahtarı yok) = kapalı. Açılış: runApp'i secure-storage beklemeden çağır ama DeviceIdentity hazır olmadan ilk istek ATILMASIN.

## 5. TEST ve DOĞRULAMA

- mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol; a15 test dosyalarını (C:\bu_qa\a15\tests\ varsa; yoksa A15 raporu Ek-A eşlemesinden yeniden yaz) repoya mobile/test/a15/ olarak ekle
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- A15 kırmızı testleri (S1.4a, S2.11, S5.x, S1.13, S2.8, S2.9, S3.5, S2.4b, U1, S1.6, C1) YEŞİL
- flutter analyze 0 warning; tüm mevcut testler yeşil
- çıkış sonrası depo envanter testi (secure storage anahtarları dahil)
- photo_autosave yeni kurulumda kapalı; anahtar canlı sayfada widget testi
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.
