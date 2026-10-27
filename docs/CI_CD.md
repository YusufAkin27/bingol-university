# CI/CD ve güvenlik taramaları

İş akışları `.github/workflows/` altındadır. **Hiçbiri GitHub'da çalıştırılarak doğrulanmadı**; yalnızca YAML yapısı `node scripts/check-workflows.js` ile denetlendi. İlk koşuda hata çıkabilir (aşağıdaki "İlk kurulum" listesine bakın).

## İş akışları

| Dosya | Tetikleyici | İş |
|---|---|---|
| `ci.yml` | her push (tüm dallar), PR, elle | `backend` (`mvn -B verify`, jacoco, H2 — Postgres gerekmez), `web` (lint, typecheck, test, build), `mobile` (Flutter 3.47.8: `pub get`, `dart analyze`, `flutter test`), `openapi-drift` (`scripts/openapi-check.js` varsa), `workflows-lint`, `docker` (backend+web imaj derleme; GHCR'ye yalnız `main` ve `v*` etiketinde), `web-e2e` (yalnız elle, `run_e2e=true`) |
| `deploy-staging.yml` | `main` üzerinde CI başarılı olunca; elle (`tag` girdisi) | SSH ile staging: imajı çek, `docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d`, sağlık denetimi, başarısızsa önceki imaja dön |
| `release-android.yml` | `v*` etiketi, elle | keystore'u sırlardan yaz, `flutter build appbundle`, AAB artifact |
| `codeql.yml` | `main` push/PR + haftalık | java-kotlin, javascript-typescript |
| `dependency-review.yml` | PR | yüksek önem derecesi bağımlılık açığında başarısız |
| `gitleaks.yml` | push, PR, haftalık | sır taraması (`.gitleaks.toml`) |
| `zap-baseline.yml` | haftalık + elle | OWASP ZAP baseline, **yalnız staging** (`.zap/rules.tsv`) |
| `k6-load.yml` | elle | k6 yük testi (staging), bkz. `scripts/k6/README.md` |

Genel: `permissions: contents: read` varsayılanı, iş bazında yükseltme; `concurrency` ile eski koşular iptal (etiket koşuları hariç, deploy kuyruğa girer, iptal edilmez). Aksiyonlar **sürüm etiketiyle** sabitlenmiştir (`@v4.2.2` gibi); tam commit SHA sabitlemesi için Dependabot `github-actions` güncellemeleri sonrası `pinact` benzeri bir araç önerilir (SHA'lar çevrimdışı doğrulanamadığı için eklenmedi).

Imaj adları: `ghcr.io/<sahip>/<depo>-backend` ve `-web` (küçük harf). Etiketler: `latest` (varsayılan dal), `sha-<tam sha>`, git etiketi. `docker-compose.prod.yml` (BE2) imajı `${BACKEND_IMAGE}` / `${WEB_IMAGE}` değişkenlerinden almalıdır; deploy betiği `.deploy/current.env` dosyasına bunları yazar ve `docker compose` onu ortam olarak okur (sunucuda `--env-file .deploy/current.env` ya da `.env` ile birleştirme gerekebilir: **BE2 ile doğrulanmalı**).

## Gerekli GitHub sırları ve değişkenleri

Sırlar (Settings → Secrets and variables → Actions; ortam sırları ilgili Environment'ta):

| Ad | Nerede | Anlam |
|---|---|---|
| `STAGING_HOST` | env `staging` | Sunucu adı/IP |
| `STAGING_SSH_USER` | env `staging` | SSH kullanıcısı |
| `STAGING_SSH_KEY` | env `staging` | Özel anahtar (yalnız dağıtım kullanıcısı; `authorized_keys` içinde `command=` ile kısıtlanabilir) |
| `STAGING_KNOWN_HOSTS` | env `staging` | `ssh-keyscan -H <host>` çıktısı |
| `STAGING_GHCR_TOKEN` | env `staging` | Sunucunun GHCR'den çekmesi için `read:packages` PAT |
| `ANDROID_KEYSTORE_BASE64` | env `production` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | env `production` | İmza bilgileri |
| `ANDROID_GOOGLE_SERVICES_JSON_BASE64` | env `production` | (ops.) Firebase `google-services.json` |
| `K6_EMAIL`, `K6_PASSWORD` (+ `_2`...) | env `staging` | Yük testi hesapları |
| `GITLEAKS_LICENSE` | depo | (yalnız kurumsal org için) |

Değişkenler (`vars.*`): `STAGING_URL` (https), `STAGING_DEPLOY_PATH` (varsayılan `/opt/bu-kampus`), `STAGING_HEALTH_URL` (sunucu içinden sağlık; varsayılan `http://127.0.0.1:8080/actuator/health` — izleme yığını `MANAGEMENT_PORT` ile health'i 8081'e taşıyorsa `http://127.0.0.1:8081/...` yapın ve portun sunucuda erişilebilir olduğundan emin olun), `API_BASE` (Android derlemesi için üretim API adresi).

Uygulama sırları (JWT, DB, SMTP, FCM...) **iş akışlarına girmez**; sunucudaki `.env` ile yönetilir (`docs/DEPLOY.md`).

## GitHub Environments ve onay kuralları

- `staging`: onay gerekmez (otomatik dağıtım); yalnız `main` dalı dağıtabilir (Deployment branches: `main`).
- `production`: **Required reviewers** (en az 1 kişi) + `Deployment branches and tags` = `v*` etiketleri. Android sürümü bu ortama bağlıdır; ileride üretim dağıtımı da `production`'ı kullanmalıdır.
- ZAP ve k6 `staging` ortamını kullanır; üretime asla yönlendirmeyin.

## Dal koruması önerisi (`main`)

- Doğrudan push yok; PR + en az 1 onay; **Code Owners** incelemesi (`.github/CODEOWNERS`).
- Gerekli durum kontrolleri: `Backend (mvn verify, H2)`, `Web (lint, tip, test, derleme)`, `Mobil (analyze + test)`, `Docker imajları (backend)`, `Docker imajları (web)`, `Gitleaks / scan`, `Dependency review / review`.
- "Require branches to be up to date", "Require conversation resolution", force-push ve silme yasak, linear history (squash merge).
- İki geliştirici düzeni: herkes `feature/*` dalında çalışır, küçük PR açar, diğeri inceler (`CODEOWNERS` karşılıklı genişletilebilir); migration ve `SecurityConfig` değişiklikleri her zaman ikinci göz ister. Flyway aralıkları ajan/özellik bazında ayrılmıştır (`CLAUDE.md`); PR şablonundaki kontrol listesi bunu hatırlatır.

## İlk kurulum / bilinen belirsizlikler

1. Repo ayarları: Actions'a `packages: write` izni (Settings → Actions → Workflow permissions: okuma/yazma ya da iş bazlı izin yeterli), GHCR paketi gizli kalır.
2. `dependency-review` private repoda GitHub Advanced Security ister; yoksa iş akışını devre dışı bırakın.
3. `zaproxy/action-baseline` kural dosyası `.zap/rules.tsv` sekmeyle ayrılmıştır.
4. Flutter paketi `mobile/packages/video_compress_android` yerel yol bağımlılığıdır; `flutter pub get` depodan çözer. `mobile` işi `flutter analyze` yerine `dart analyze` kullanır (istenildiği gibi); uyarılar işi bozuyorsa `analysis_options.yaml` düzenlenmeli.
5. `ci.yml` backend testleri 30 dk zaman aşımlıdır; jacoco raporu artifact olarak saklanır.
6. Dependabot haftalık gruplu PR açar; `main` korumasıyla birleşmeden önce CI'nın yeşil olması gerekir.
