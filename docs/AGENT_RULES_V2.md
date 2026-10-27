# Ajan çalışma kuralları (V2 turu)

Bu belge, bu turda paralel çalışan TÜM ajanların ortak kurallarıdır. Görev brifinindeki özel kurallar bunlara eklenir.

## Ortam
- Repo: `C:\Users\Toprak Çevik\OneDrive\Masaüstü\project\bingol-university`, dal `feature/mobil-uygulama` (ana çalışma klasörü; ajanlar aynı klasörde çalışır). Önce `CLAUDE.md` ve ilgili örnek belgeyi (`docs/POSTS_DESIGN.md`) oku.
- Mobil: YALNIZCA `C:\bu_mobile` yolu (Türkçe karakterli yol analyzer'ı bozar). `$env:PUB_CACHE='C:\pubcache'; $env:PATH='C:\src\flutter\bin;C:\Program Files\Git\cmd;'+$env:PATH; Set-Location C:\bu_mobile`.
- Backend testi yalnız Docker Maven ile (makinede yalnız Java 8): backend/ içinde Git Bash'ten, AĞIR işlemleri kilit betiğiyle sıraya sok:
  `bash ../scripts/with-lock.sh bash -c 'MSYS_NO_PATHCONV=1 timeout 900 docker run --rm -v bu-m2:/root/.m2 -v "$(pwd -W):/src:ro" maven:3-eclipse-temurin-17 sh -c "mkdir /work && tar -C /src --exclude=target -cf - . | tar -C /work -xf - && cd /work && mvn -B -q -Djacoco.skip=true test"'`
  Hedefli test için `-Dtest=...` ekle. Docker bazen yanıt vermez (`timeout 20 docker info`): yanıtsızsa bekle/yeniden dene; yoksa kodu yazıp doğrulamayı raporla ama "çalıştırdım" DEME.
- Web: `cd web; npm run lint; npm run typecheck; npm test; npm run build` (tam test paketi paralel yükte zaman aşımına düşebilir: kendi testlerini hedefli koş, en sonda tam paket).
- Yarım dosyalar: başka ajanların dosyaları derlemeyi geçici kırabilir. Kendi dosyalarının sağlamlığını temiz bir `git worktree add --detach C:/bu_<ad> HEAD` + dosya kopyalama ile doğrula; kırık dosya başkasınınsa düzeltme, raporla.
- Windows/bash tuzakları: uzun heredoc'lar Türkçe karakterde bozulur: dosyaları Write ile yaz; betiklerde ASCII; curl `-F file=@` için `cygpath -m`; uzun gövdeleri dosyadan gönder (`--data-binary @dosya`); komut satırı 32K sınırı.
- `rm -rf` ve toplu silme komutları güvenlik denetiminde engellenir: silme gerekmiyorsa yapma; yeni klasör adı kullan.

## Sahiplik ve çakışma
- Kendi paket/klasörünün sahibisin. Ortak dosyalarda (application.properties, SecurityConfig, i18n bundle'ları, web routes.tsx/adminNav.ts/paths.ts/i18n index, mobil theme/typography/fake_app.dart, docs/API_CONTRACTS_V2.md, scripts/smoke-*.sh) YALNIZ küçük Edit; her Edit öncesi dosyayı yeniden oku; Write ile ezme.
- Flyway aralıkları (tek migration dosyası/özellik; indeks adı öneki zorunlu): academic V320–V329 (`acd320_`), polls V330–V339 (`pol330_`), social V340–V349 (`soc340_`), push outbox V350–V359 (`pso350_`), medya dönüştürme V360–V369 (`trn360_`). Mevcut son: V310 (gönderiler), V300 küfür, V290 hukuki, V280 erişim engeli. Başka aralığa YAZMA.
- API SÖZLEŞMESİ ÖNCE: backend özellik ajanı, kodlamaya başlamadan İLK 10 DAKİKADA `docs/API_CONTRACTS_V2.md` içine kendi bölümünü (uçlar, istek/yanıt JSON'u, hata kodları, sayfalama, yetki) yazar ve bölüm başlığını `## [HAZIR] <özellik>` yapar. Mobil/web ajanları bölüm hazır olana kadar FakeBackend ile iskeletini yazar, sonra sözleşmeye uyar; ayrıntı için backend kodunu (controller/DTO) da okur. Sözleşme değişirse backend ajanı bölümün sonuna `DEĞİŞİKLİK:` satırı ekler.
- Backend hata kodu = tr/en/ar çeviri (i18n bundle); yeni modül bundle'ı `application.properties` basename listesine eklenir. Herkese açık metinler `ContentGuard` (küfür filtresi) kullanır. Yönetici işlemleri denetim kaydına yazılır. Yeni kişisel veri = `DataExporter` + `AccountDataPurger` kapsamı. Rate limit zorunlu.

## Teslim
- Mobil: yeni dizeler AppLocalizations, ARB ekleri (`mobile/lib/l10n/app_{tr,en,ar}.arb` + `context.l10n.<anahtar>`, `flutter gen-l10n`; iş listesi `docs/I18N_MOBILE.md`, tarayıcı `node scripts/i18n-audit.js`).
- Testler yaz ve çalıştır (backend birim/H2; mobil widget + FakeBackend 320/390/430 açık/koyu; web Vitest). `scripts/smoke-<özellik>.sh` yaz (çalıştırma).
- Docs güncelle (MOBILE_API_GUIDE/ADMIN_API/changes). git commit/push, docker compose yeniden başlatma, `adb install` YAPMA (ana oturum yapar).
- Bitince KISA Türkçe rapor: yapılanlar, TAM sözleşme, migration, ayarlar, test sonucu, doğrulanamayanlar, eksikler.
