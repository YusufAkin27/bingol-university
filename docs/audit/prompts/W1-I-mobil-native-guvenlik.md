# W1-I - Mobil: yerel güvenlik, native katman ve push yönlendirme güvenliği

> AJAN GÖREV METNİ (kopyala-yapıştır). Dalga 1. Kaynak: docs/audit/00-KONSOLIDE.md (T kartları aşağıya gömülüdür), plan: docs/audit/01-DALGA-PLANI.md. Büyüklük: S (≈0.5-1 gün).

Sen **W1-I** iş akışı ajanısın (MainActivity exported payload, KVKK dışa aktarma panosu, BootReceiver, Android kanal adları). Görevin: aşağıdaki T maddelerini, yalnız sana ait dosyalarda, test ve doğrulamayla birlikte eksiksiz kapatmak ve `scripts/agent-push.sh` ile yalnız kendi dosyalarını pushlamaktır. Önce kısa bir plan yaz, sonra uygula. Bağımsız çalış: bu metin sana gereken her şeyi verir; belirsizlikte T kartındaki 'Düzeltme' ve ilgili `docs/audit/A*.md` bölümüne bak.

## 0. Önkoşul / bağlam

- Önkoşul: Yok
- Denetim bulguları kod DEĞİŞTİRİLMEDEN yazıldı; konsolidasyonda grep ile yeniden doğrulananlar 'kanıt V' ile işaretlidir. Kodun şu anki hâli kartlardaki satır numaralarından kayabilir: önce ara, sonra düzelt.
- Test altyapısı: mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol; Android: `flutter build apk --debug` derlenir (manifest/Kotlin doğrulaması)

## 1. ORTAK KURALLAR (ihlal etme; ayrıntı: CLAUDE.md ve docs/audit/01-DALGA-PLANI.md bölüm 2)

1. Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama`. Önce `CLAUDE.md`'yi, sonra bu görevin T kartlarında adı geçen `docs/audit/A*.md` bölümlerini oku. Kodlama kuralları için CLAUDE.md geçerlidir (katman kuralı, ApiException + `error.<KOD>` 3 dil, Flyway kuralları, rate limit, UTF-8 BOM'suz, Write/Edit ile yaz, uzun bash heredoc kullanma, betiklerde ASCII).
2. **Canlı sunucuya (77.83.37.160 / bukampus.com.tr) HİÇBİR istek atma**; sır/anahtar değeri yazma veya commitleme. Yalnız yerel dosyalar ve kendi yalıtılmış Docker yığınında çalış.
3. **Yalnız SAHİP OLDUĞUN dosyalara dokun** (bölüm 3). `scripts/agent-push.sh` verdiğin dosyaları BÜTÜN halde commit eder; başka ajanın yarım değişikliği aynı dosyadaysa o da commit'e girer. Sahip olmadığın dosyada değişiklik gerekirse DUR ve teslim raporunda koordinatöre bildir. Ortak dosyalar için KİLİT protokolü: `LOCK="$(git rev-parse --git-dir)/lock-<ad>"; until mkdir "$LOCK" 2>/dev/null; do sleep 5; done` ... düzenle + test + push ... `rmdir "$LOCK"` (kilit adları: arb, i18n-messages, admin-policy, app-props, docs-shared; kilidi kısa tut).
4. **Temiz kopyada doğrula:** `rm -rf /c/bu_verify_w1i && mkdir -p /c/bu_verify_w1i && git archive HEAD | tar -x -C /c/bu_verify_w1i`; yalnız KENDİ değiştirdiğin dosyaları aynı göreli yolla üstüne kopyala (`cp --parents`), testleri orada koş. Backend: `cd /c/bu_verify_w1i/backend && MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app maven:3-eclipse-temurin-17 mvn -B test -Dtest='<sınıflar>'` (bu makinede Java 8 var; backend Java 17 konteynerinde derlenir). Mobil: `export PUB_CACHE='C:\pubcache'; export PATH="/c/src/flutter/bin:$PATH"; cd /c/bu_verify_w1i/mobile && flutter pub get --offline && flutter analyze && flutter test <dosyalar>`. Web: `cd web && npm ci && npm run lint && npm run typecheck && npm test && npm run build`.
5. **Yığın gerekmez** (bu iş akışı mobil/web/belge ağırlıklı): testleri birim/widget/sahte sunucu (MockClient, yerel HttpServer; A15 yöntemi) ile yaz; bir backend yığını gerekirse yalnız kendi COMPOSE_PROJECT_NAME ve boş port ile kur, A7 ortak yığınına (18081) DOKUNMA.
6. **Commit/push:** küçük odaklı commit'ler: `bash scripts/agent-push.sh "W1-I: <özet> (T-xxx)" <yol1> <yol2> ...` yalnız kendi dosyaların. `git add -A`, `git add .`, `--no-verify`, `git reset --hard`, `git checkout --` YASAK. Push, doğrulama yeşil olmadan yapılmaz.
7. **Migration/Flyway:** yalnız sana ayrılan aralık; uygulanmış migration'ı DEĞİŞTİRME; indeks adları önekli ve benzersiz; ddl-auto=validate ile entity-şema birebir; PG'ye özel SQL H2'de çalışmaz: PG'de duman/EXPLAIN ile doğrula.
8. **Yeni yazma ucu = rate limit; yeni admin ucu = AdminPermissionPolicy kuralı** (kilit admin-policy); entity API'ye dönmez; `error.<KOD>` yeni hata kodu = tr/en/ar çeviri; `python -I -X utf8 scripts/i18n-dupkeys.py` temiz.
9. **Mobil arayüz KİLİTLİDİR** (docs/MOBILE_DESIGN_SYSTEM.md): T kartı açıkça istemedikçe yerleşim/renk/ölçü değiştirme; yalnız `context.bu` token'ları; yeni renk ekleme. Mobil yeni metin = ARB 3 dil (öneki yukarıda).
10. **Dürüst ol:** yapamadığını/doğrulayamadığını teslim raporunda AÇIKÇA yaz; testi yeşile çevirmek için testi zayıflatma; kanıtı olmayan bir şeyi 'düzeltildi' diye raporlama.

## 2. KAPSAM - T maddeleri (4)

#### T-100 - Android bildirim kanalı varsayılan adları ASCII-leştirilmiş Türkçe (uygulama açılmadan ilk push'ta bu adlarla oluşur)  [YÜKSEK | kanıt S]
- **Kaynak bulgular:** A9-11 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil android LocalReminders.kt (136-143 defaultNames/defaultDescs); res/values-{en,ar}
- **Düzeltme:** Doğru Türkçe diakritikler veya Android strings.xml (values/values-en/values-ar) ile yerelleştirilmiş varsayılanlar; ARB karşılıklarıyla aynı sözlük
- **Test gereksinimi:** Kotlin birim/bildirim kanalı testi veya statik tarama (ASCII-leşmiş Türkçe yok)

#### T-098 - Dışa açık MainActivity harici bu_reminder_payload ekstrasını güvenmeden PushRouter'a veriyor (zorla çıkış, sahte CONVERSATION_CLOSED); ölü session_replaced push dalı  [ORTA | kanıt S]
- **Kaynak bulgular:** A4-01, A13-13 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil android MainActivity.kt (33,36-40), AndroidManifest.xml (36), core/push/push_service.dart (182-186,407), push_targets.dart (101), push_router.dart (34-38)
- **Düzeltme:** Yerel hatırlatma yolundan type/event anahtarlarını geçirme (yalnız targetType/targetId/... beyaz liste, uzunluk sınırı); intent ekstrasını nonce ile imzala veya launcher dışı girişi yok say; session_replaced dalı kaldır
- **Test gereksinimi:** resolvePushTarget birim testi: yerel kaynaklı yük signOut üretmez; adb am start testi (H-09)

#### T-099 - KVKK dışa aktarma JSON'u panoya konup 30 sn Timer ile silinmeye çalışılıyor (arka planda güvenilmez)  [ORTA | kanıt S]
- **Kaynak bulgular:** A4-08 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil features/profile/profil2_my_data_page.dart (17-26,52-56)
- **Düzeltme:** Panoya kişisel veri koyma; sistem paylaşımı/dosya (share) veya ClipDescription.EXTRA_IS_SENSITIVE + lifecycle resumed'da temizlik
- **Test gereksinimi:** kExportClipboardTtl ve AppLifecycleState widget testi

#### T-101 - BootReceiver exported=true gereksiz (başka uygulamalar rearmAll'ı tetikleyebilir)  [DÜŞÜK | kanıt S]
- **Kaynak bulgular:** A4-10 (ayrıntı docs/audit/A*.md)
- **Dosya/modül:** mobil android AndroidManifest.xml (62)
- **Düzeltme:** exported=false (sistem yayınları yine alınır)
- **Test gereksinimi:** Manifest lint/dumpsys; reboot sonrası hatırlatma yeniden kuruluyor (H-09)

## 3. DOSYA SAHİPLİĞİ

**Sahip olduğun (düzenleyebileceğin) dosyalar:**
- mobile/android/** (MainActivity.kt, LocalReminders.kt, AndroidManifest.xml, res/values*)
- mobile/lib/core/push/push_service.dart, push_router.dart, push_targets.dart (push_channels.dart W4'te silinebilir: dokunma)
- mobile/lib/features/profile/profil2_my_data_page.dart
- mobile/ios/** (yalnız okuma/denetim; değişiklik gerekirse BuNativeBridge.swift tek dosya)
- mobile/lib/l10n/*.arb (YALNIZ kilitle: arb; önek p32)
- mobile/test/** (push_*, back_navigation hariç; yeni testler)

**Dokunmayacakların (başka iş akışının):**
- features/chat/**, core/api.dart, session.dart, outbox, cache (W1-G/W1-H); backend; web

Paylaşılan dosya kilitleri: arb. Flyway aralığın: **-**, indeks öneki **-**. Mobil l10n öneki: **p32**.

## 4. ÖZEL TALİMATLAR

T-098: intent ekstrasından gelen yük yalnız hedef anahtarlar (targetType/targetId/conversationId/eventId/postId/communityId/newsId/ticketId/pollId/userId/announcementId) beyaz listesiyle PushRouter'a verilir, string uzunluğu ≤200; type/event/signOut yolu YALNIZ FCM/ön plan push yükünden gelebilir (kaynak bayrağıyla ayır). session_replaced dalı ölü: kaldır. Android kanal adları: Kotlin varsayılanlarını düzgün Türkçe diakritikle yaz (ASCII değil) VE values-en/values-ar strings.xml ekle; ARB sözlüğüyle aynı metin. FLAG_SECURE kapsamına DOKUNMA (K-05 kararı bekler). iOS dosyalarına zorunlu olmadıkça dokunma (macOS'ta derlenemiyor).

## 5. TEST ve DOĞRULAMA

- mobil: temiz kopyada `flutter analyze` (0 warning) + ilgili `flutter test` dosyaları + etkilenen shots/golden sahneleri; `C:\src\flutter`, PUB_CACHE=C:\pubcache, ASCII yol; Android: `flutter build apk --debug` derlenir (manifest/Kotlin doğrulaması)
- Her T için kartın 'Test gereksinimi' satırındaki regresyon testini YAZ ve temiz kopyada çalıştır; test önce kırmızı (hatayı yakalıyor) sonra yeşil olmalı.
- Mevcut testleri bozma; bozulan bir test gerçek davranış değişikliğini yansıtıyorsa testi güncelle ve raporda gerekçesini yaz.

## 6. BİTİRME KRİTERİ

- resolvePushTarget birim testi: yerel hatırlatma kaynaklı yük type=session_replaced / event=CONVERSATION_CLOSED ile durum DEĞİŞTİRMEZ
- Manifest: BootReceiver exported=false; MainActivity yalnız launcher exported
- Kanal adları ASCII-leşmiş Türkçe içermez (tarama testi)
- dışa aktarma panoya yazılmaz
- Tüm T maddeleri kapalı veya gerekçeli ertelenmiş; yalnız kendi dosyaların commit'lenmiş ve `origin/feature/mobil-uygulama`'ya pushlanmış; `git status` sende kendi dosyalarından artık yok.

## 7. TESLİM RAPORU (son mesajın)

- Her T için: KAPANDI / KISMEN / ERTELENDİ (neden) + commit SHA'ları.
- Çalıştırılan komutlar ve gerçek sonuçlar (geçen/kalan test sayıları; smoke tablosu); çalıştıramadıkların.
- Dokunmadığın ama gerektiğini gördüğün dosyalar (başka iş akışına öneri), yeni bulduğun sorunlar.
- `docs/changes/<modül>.md` ve (varsa) docs/ADMIN_API.md / docs/PERFORMANCE.md güncellemesi yapıldı mı.
- Bekleyen karar/insan eylemi (K-xx/H-xx) ve riskler. Canlı sunucuya dokunulmadığını ve yalnız kendi dosyalarını commit'lediğini belirt.
