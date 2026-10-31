# W2-I - Mobil push, bildirim kutusu, sohbet olgunlaştırma, galeri izni

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 2. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: L.

Sen **W2-I** iş akışı ajanısın (Okunmamış süzgeci, tepsi/rozet, forward/boşluk doldurma/olay işleme, READ_MEDIA geçişi (K-03)). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: W1-H bitmiş; K-03
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w2i && mkdir -p /c/bu_verify_w2i && git archive HEAD | tar -x -C /c/bu_verify_w2i`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w2i/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w2i/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yığın gerekmez** (bu iş akışı mobil/web/belge ağırlıklı): testleri birim/widget/sahte sunucu (MockClient, yerel HttpServer; A15 yöntemi) ile yaz; bir backend yığını gerekirse yalnız kendi COMPOSE_PROJECT_NAME ve boş port ile kur, A7 ortak yığınına (18081) DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W2-I: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (4)

#### T-141 - READ_MEDIA_IMAGES/VIDEO Play Foto/Video İzinleri politikası riski (sohbet için sistem seçici beklenir); photo_manager + gal birlikte  [YÜKSEK | kanıt S]
- **Kaynak bulgular:** A8-06 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil android AndroidManifest.xml (16-18), features/chat/media_library.dart + media_picker_page (kilitli arayüz), photo_manager, gal
- **Düzeltme:** K-03: image_picker Photo Picker'a geçiş ve READ_MEDIA_* kaldır; iOS NSPhotoLibraryUsageDescription sadeleşir; 'özel galeri' arayüzü değişir (tasarım onayı)
- **Test gereksinimi:** İzin akışı widget testleri; Android 13+ cihaz testi (H-09)
- **Bağımlılık:** K-03
- **KARAR (varsayılan = ÖNERİ):** K-03 Galeri izni (READ_MEDIA_*) politikası | Seçenekler: (a) Photo Picker'a geç, READ_MEDIA_* kaldır; (b) çekirdek işlev beyanı ile izni koru; (c) önce Play ön inceleme | ÖNERİ: (a). Ret riski yüksek ve geri dönüşü pahalı; ama 'özel galeri' arayüzü (media_picker_page) kilitli olduğundan tasarım onayı gerekir: Android'de sistem seçici + uygulama içi önizleme/başlık adımı korunsun.

#### T-081 - Bildirim kutusu 'Okunmamış' süzgeci yalnız yüklenmiş ilk sayfayı süzüyor; sayaç ve tür ikonları eksik  [ORTA | kanıt S]
- **Kaynak bulgular:** A13-03, A13-06 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/notifications/notifications_page.dart (shown, _loadMore), notif_row.dart
- **Düzeltme:** Süzgeç sunucuya unread=true ile; count>1 için 'N yeni mesaj'; USER_FOLLOW/SYSTEM ikon ve etiketleri (ARB kilidi)
- **Test gereksinimi:** notif_design_test: 25+ bildirim, okunmamışlar eski sayfada

#### T-082 - Okunan sohbetin Android tepsi bildirimi temizlenmiyor; iOS ikon rozeti (iOS tarafı eb505c0 ile eklendi, Android tepsi ve macOS derleme doğrulaması açık)  [ORTA | kanıt PS]
- **Kaynak bulgular:** A13-04 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil android Kotlin (NotificationManager.cancel tag=conv:<id>), core/push/icon_badge.dart (mevcut), chat_detail_page okundu noktası
- **Düzeltme:** Android'de conv:<id> bildirimini sohbet okununca kapat (platform kanalı); iOS rozet macOS CI'da doğrula
- **Test gereksinimi:** icon_badge_test mevcut; Android kanal birim testi; GERÇEK CİHAZ (H-09)

#### T-108 - Sohbet olgunlaştırma: İlet çevrimdışıyken 'başarısız' der (çift ileti), liste ilk 50 sohbet; boşluk doldurma delikleri (150 mesaj, RECEIPT öncesi resync); edited/reaction/conversation-updated/access-blocked olayları işlenmiyor  [ORTA | kanıt S]
- **Kaynak bulgular:** A10-11, A10-12, A10-13 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil chat_detail_page.dart (1774-1802, 599-648), forward_sheet.dart (60,104), core/realtime/chat_realtime.dart (150-173), stomp_client.dart (208-212)
- **Düzeltme:** Ağ hatasında 'kuyruğa alındı' say; listeyi imleçle sayfala, closed bilgisini sunucudan al; after döngüsünü nextCursor==null'a dek sürdür, resync'i SUBSCRIBE onayına bağla; olayları ilgili mesaja/başlığa uygula
- **Test gereksinimi:** ForwardSheet çevrimdışı testi; edited/reaction olay testi
- **Bağımlılık:** T-093

### Paylaşılan T maddeleri (başka iş akışıyla ortak; YALNIZ senin parçan)

#### T-077 - Moderasyon bildirimi targetType=MESSAGE mobilde sohbet kimliği sanılıyor (yanlış sohbet/404)  [ORTA | kanıt S]
- **Kaynak bulgular:** A13-05 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** backend moderation/ModerationNotifier.data; mobil core/push/push_targets.dart _destOf('MESSAGE')
- **Düzeltme:** Sunucu mesaj hedefinde conversationId de göndersin (veya targetType göndermesin); mobil MESSAGE eşlemesi yalnız conversationId varsa
- **Test gereksinimi:** Birim: resolvePushTarget MESSAGE moderasyon yükü

#### T-026 - Mesaj isteği / rıza modeli (ilk DM ve grup daveti PENDING, kabul edene kadar bildirim/push yok, yanıtsız tek taraflı mesaj sınırı)  [ORTA | kanıt S]
- **Kaynak bulgular:** A16-02, A1-11 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** messaging/** (yeni istek durumu), notification gönderim kapıları, mobil sohbet listesi 'İstekler' (W2-I)
- **Düzeltme:** K-08 kararına göre: ortak bağlam yoksa istek akışı; grup davetinde kabul; presence karşılıklı kabulden sonra; yeni tablo/durum (Flyway)
- **Test gereksinimi:** Servis ve entegrasyon testleri; smoke-messaging yeni akış
- **Bağımlılık:** T-025, K-08
- **KARAR (varsayılan = ÖNERİ):** K-08 DM rızası modeli | Seçenekler: (a) Mevcut + hız sınırı; (b) mesaj isteği: ilk DM yalnız ortak bağlam (ortak kulüp/etkinlik/takip) varsa doğrudan, yoksa istek; grup daveti kabul gerektirir; presence karşılıklı kabul sonrası; (c) kapalı DM (yalnız takip ettikleri) | ÖNERİ: (b). Kısa vadede (W1-D) çıkış sonrası yeniden eklemeyi yasakla, presence'a limit ve gizlilik ekle; tam istek akışı karardan sonra W2-D.

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- features/notifications/**, core/push/**, features/chat/** (W1-H sonrası), android Kotlin (tepsi), media_picker_page/media_library (K-03)

**Dokunmayacakların (başka iş akışının):**
- W2-G dosyaları

Paylaşılan dosya kilitleri: arb. Flyway aralığın: **-**, indeks öneki **-**. Mobil l10n öneki: **p36**.

## 4. ÖZEL TALİMATLAR

Kartlardaki 'Düzeltme' satırları yeterlidir; karar bekleyen (K-xx) maddelerde ÖNERİ varsayılanını uygula ve raporda belirt. Dosya sahipliği çakışması görürsen DUR ve raporla.

## 5. TEST ve DOĞRULAMA

- mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- notif_design_test 25+ bildirim
- ForwardSheet çevrimdışı testi
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.
