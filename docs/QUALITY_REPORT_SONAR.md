# SonarQube kalite raporu (2026-11-01)

Kapsam: backend (Java 17) + web (TypeScript/CSS) SonarQube Community 26.10 ile taranmıştır; mobil (Dart) Community sürümde taranmaz, ayrı özeti aşağıdadır. Tarama yerel, geçici bir SonarQube konteynerinde yapıldı (iş sonunda silindi); canlı sunucuya istek yoktur. Ham JSON çıktıları repoda değildir.

Taranan sürüm: `e2c1cc13` (`feature/mobil-uygulama`). Düzeltmeler bu taramadan SONRA `54e9c67b` ile eklendi; **yeniden taranmadı** (aşağıdaki sayılar düzeltme öncesidir).

## 1. Özet tablo

| Ölçüt | Değer |
|---|---|
| Kalite kapısı | OK (Sonar way; yeni kod koşulu yok, koşul listesi boş) |
| Kod satırı (ncloc) | 140 848 (Java 69 020, TypeScript 59 249, CSS 12 579); 1 507 dosya |
| Bug | 37 (hepsi MAIN; güvenilirlik derecesi **C**) |
| Zafiyet | 12 (6 MAIN, 6 test dosyası; güvenlik derecesi **D**) |
| Güvenlik noktası (hotspot) | 0 (inceleme derecesi A) |
| Kod kokusu | 85 (bakım kolaylığı derecesi **A**, borç oranı %0,0, ~1 277 dk) |
| Toplam açık bulgu | 134: BLOCKER 5, CRITICAL 1, MAJOR 123, MINOR 5 |
| Kapsam (Sonar, birleşik) | %85,9 (satır %88,8); lines_to_cover 81 593, kapsanmayan 9 123 |
| Backend kapsamı (JaCoCo) | satır %83,5, dal %73,4 |
| Web kapsamı | satır %91,1 (vitest v8: ifade %92,5, dal %84,5, fonksiyon %73,4) |
| Tekrar (duplication) | %5,3 (web tarafı %10,7); 2 942 blok, 99 dosya |
| Bilişsel karmaşıklık | 15 030 |

Testler: backend `mvn test` 2 917 test, 0 hata, 6 atlanmış (BUILD SUCCESS, 5 dk 37 sn); web vitest 110 dosya / 1 094 test, hepsi geçti.

Derece çevirisi: Sonar'da bir MAJOR bug/zafiyet bile derecenin C/D'ye düşmesine yeter; aşağıda görüleceği gibi bunların neredeyse tamamı yanlış-pozitif ya da düşük risklidir. Dereceler bu yüzden gerçek riski olduğundan kötü gösterir.

## 2. Bulguların kural kırılımı (açık)

| Kural | Adet | Anlamı | Yargı |
|---|---|---|---|
| `S8786` (java 22, ts 27) | 49 | `trim` benzeri regex'lerde süper-doğrusal geri izleme | Düşük risk (bkz. madde 7) |
| `S6813` | 14 | Alan enjeksiyonu (Spring) | Stil; dokunulmadı |
| `S9383` (ts) | 10 + `S6544` 1 | `navigate(...)` Promise döndürüyor ama beklenmiyor | Yanlış-pozitif (react-router standardı) |
| `S6218` | 10 | Dizi taşıyan `record`'larda `equals/hashCode` | Yanlış-pozitif/stil (kayıtlar karşılaştırılmıyor) |
| `S6389` (test metinleri) | 6 | Testlerde bilinçli Arapça/çift yönlü karakter | Yanlış-pozitif |
| `S5998` | 5 | E-posta regex'lerinde yinelenen grup | Düşük risk |
| `S6848/S6845/S6843/S6825/S6852` | 12 | Erişilebilirlik (web arayüz bileşenleri) | Gerçek ama düşük öncelik |
| `S1845` | 4 (+1 blocker) | Büyük/küçük harf farkıyla ad çakışması | Düzeltildi |
| `S1313`, `S5850`, `S2068`, `S2245`, `S2259`, `S2445`, `S4656` vb. | ~20 | Tekil | Madde 3 |

## 3. En önemli 10 bulgu ve yargı

| # | Önem / kural | Yer | Yargı |
|---|---|---|---|
| 1 | CRITICAL zafiyet `java:S5443` | `media/transcode/TranscodeService.java:230` (`Files.createTempDirectory("trn")`) | Yanlış-pozitif/kabul: `createTempDirectory` dizini yalnız sahibi için (0700) oluşturur, adı rastgeledir; yapılandırmadaki `tempDir` ile ayrı dizine de alınabilir. Değişiklik yok. |
| 2 | BLOCKER `java:S2178` | `event/CheckinCodeService.java:72` (`ok \| prev`) | Yanlış-pozitif, BİLİNÇLİ: iki pencerenin de her zaman hesaplanması zamanlama farkını gizler (kodda yorum var). Dokunulmadı. |
| 3 | BLOCKER `java:S1845` x4 | `AdminPushDeviceService`, `DevSeedRunner`, `EventExtrasController`, `SystemOverviewService` | Gerçek ama kozmetik (alan/sabit adı yalnız harf boyuyla ayrışıyor). **Düzeltildi** (yeniden adlandırma). |
| 4 | BUG `java:S2259` | `CheckinCodeService.java:52` (`code` boş olabilir) | Yanlış-pozitif: `normalizeManual(null)` boş döner, uzunluk testi 6'ya eşit olmadığı için `contains` çağrısına inilmez. |
| 5 | BUG `java:S2259` | `auth/LoginIdentifier.java:45` | Yanlış-pozitif: `at > 0` yalnız `email != null` iken doğru olabilir. |
| 6 | BUG `java:S2583` | `mail/campaign/CustomMailRenderer.java:71` | Gerçek (ölü kod): `contentOf` hiç `null` dönmez. **Düzeltildi**. |
| 7 | BUG `java:S5855` | `mail/MailBounces.java:15` | Gerçek (kopya alternatif `does not exist`). **Düzeltildi**, davranış aynı. |
| 8 | VULN `java:S2077` | `dbmaint/ChunkedDeleter.java:162` (`"SET LOCAL statement_timeout = " + sayı`) | Yanlış-pozitif: eklenen değer yapılandırmadan gelen sayıdır, kullanıcı girdisi değil (kodda yorum). Tablo adları sabit beyaz listeden. |
| 9 | VULN `java:S2068` x2 | `auth/jwt/JwtAuthFilter.java:30` (`PASSWORD_CHANGED_KEY_PREFIX`), `devseed/DevSeedRunner.java:37` | JwtAuthFilter yanlış-pozitif (Redis anahtar öneki). DevSeedRunner: bilinen geliştirme şifresi, `@Profile("seed & !prod")` ile prod'da yüklenmez, `DevSeedProdGuardTest` bunu doğrular; belgeli. Kabul. |
| 10 | VULN `ts:S2245` x2 | `web/.../useGuardedMutation.ts:12`, `supportLogic.ts:61` | Yanlış-pozitif: `Math.random` yalnız `crypto.randomUUID` yoksa idempotency anahtarı yedeği ve yerel şablon kimliği için; güvenlik jetonu değil. |

Diğerleri: `S5850` x3 (`Texts.java`, `MailProperties.java`, `PostService.java`: `^-+|-+$` biçimli trim regex'i, kasıtlı, yanlış-pozitif); `S6218` x10; `S2445` x2 (`ProcessRunner`: parametre `StringBuilder` üzerinde senkronizasyon, çağıran ve okuyan aynı nesneyi kullanıyor, kasıtlı); `S4656` x2 (CSS yinelenen `min-width`, dikkate değer değil); test dosyalarındaki 6 `S6389` (Arapça test metni).

## 4. Düzeltmeler

Commit `54e9c67b` (hedefli testler 189/189 yeşil: `*Extras*`, `*Mail*`, `*Observab*`, `*DevSeed*`, `*Ics*`, `*PushDevice*`):
- `S1845` BLOCKER x4: `TAIL`->`TAIL_CHARS`, `USERS`->`SEED_USERS`, `ICS`->`ICS_TYPE`, `JOBS`->`JOB_SPECS` (yalnız private/paket içi sabit adı, davranış aynı).
- `S5855`: `MailBounces` regex'indeki kopya alternatif kaldırıldı.
- `S2583`: `CustomMailRenderer.resolve` içindeki hiç çalışmayan `null` dalı kaldırıldı.

Yeniden taranmadı; beklenen etki: BLOCKER 5 -> 1 (yalnızca bilinçli `S2178`), bug 37 -> 36.

## 5. Düzeltilmeyenler ve nedeni

- Yanlış-pozitifler (madde 3: S5443, S2178, S2259 x2, S2077, S2068, S2245, S5850, S2445, S6389): kod değiştirmek davranışı bozar ya da güvenlik amacını (sabit-zamanlı karşılaştırma) zayıflatır.
- `S8786` (49): regex'ler ya sabit/güvenilir girdide (yapılandırma, URL öneki) ya da zaten boyut sınırlı girdide (`PostService.normalize` girdisi `@Size(max=1000)`) çalışır; en kötü durumda ~10^6 adım. Yine de kritik bir kullanıcı girdisi yolunda tekrar açılırsa `String.strip()` veya elle kırpma tercih edilmeli.
- `S6813` (14): alan enjeksiyonunu yapıcı enjeksiyonuna çevirmek geniş değişikliktir; işlevsel riski yok, kapsam dışı bırakıldı.
- Web erişilebilirlik (`S6848` vb., 12): gerçek ve düşük öncelikli iyileştirme; ayrı bir işe konabilir.
- `S9383`/`S6544` (11): react-router `navigate` standardı; `void` eklemek gürültü.
- `S6218` (10): dizi alanlı kayıtlarda `equals` kullanılmıyor.

Sonuç: tarama gerçek bir güvenlik açığı bulmadı. Güvenlik "D" ve güvenilirlik "C" dereceleri, MAJOR seviyedeki yanlış-pozitiflerden gelir. İsterseniz bu bilinçli bulgular Sonar'da "Accepted/False positive" işaretlenerek derece düzeltilebilir (yerel örnek silindiği için kalıcı kayıt tutulmadı).

## 6. Mobil (Dart/Flutter) özeti (Sonar dışı)

`e2c1cc13` temiz kopyasında:
- `flutter analyze`: **No issues found** (0 sorun).
- `flutter test`: **4 893 geçti**, 0 hata, **1 454 atlandı** (testlerdeki `skip` bayrakları; ekran görüntüsü/golden türü testler, `skip: skipShots` gibi). Test dosyası 201, `test(`/`testWidgets(` çağrısı ~1 984.
- Boyut: `lib/` 299 Dart dosyası, ~137 000 satır; `test/` ~60 000 satır.
- Mobil kapsam (lcov) ölçülmedi.

## 7. Doğrulanamayanlar / notlar

- Düzeltmeler sonrası yeniden tarama yapılmadı.
- Mobil için kapsam ve Sonar benzeri statik analiz sayıları yok (Community sürüm Dart'ı desteklemez).
- Web lcov yolları Sonar için `web/src/...` biçimine çevrilip yüklendi (vitest ham çıktısı `src\...` yazıyor); `scripts/sonar/run-sonar.sh` bu dönüşümü yapmıyordu (ham dosyayla web kapsamı Sonar'a yansımaz); betiğe dönüşüm adımı eklendi.
- Windows bind mount üzerinde `mvn test` bu makinede çok yavaş (bağlam başına 2-4 dk); adlandırılmış Docker birimi (volume) içinde çalıştırınca 5 dk 37 sn sürdü.
- Backend per-dizin Sonar kırılımı alınamadı; JaCoCo sayıları doğrudan XML'den.
