# BÜ Kampüs Web

Tek bir React uygulaması: herkese açık **tanıtım sitesi** (`/`) ve `/admin` altında **yönetim paneli**.
Bu dizin iskelettir: kabuk, tasarım sistemi, API istemcisi, kimlik, i18n ve rota yer tutucuları hazırdır; sayfalar sırayla doldurulur.

Yığın: Vite 5 · React 18 · TypeScript (strict) · react-router-dom 6 (`<Routes>`, `React.lazy`) · TanStack Query 5 · Recharts 2 ·
CSS değişkenleri + CSS Modules (Tailwind yok) · Vitest + Testing Library · ESLint (typescript-eslint, react-hooks) + Prettier.
Dış CDN/font bağımlılığı yoktur (yerel font yığınları, CSP `default-src 'self'`).

## Kurulum ve komutlar

```bash
cd web
npm install
cp .env.example .env     # isteğe bağlı
npm run dev              # http://localhost:5173  (/api, /files, /ws -> http://localhost:8080)
npm run lint             # ESLint
npm run typecheck        # tsc --noEmit (strict)
npm run test             # Vitest (jsdom)
npm run build            # typecheck + üretim derlemesi -> dist/
npm run preview          # derlenmiş uygulama (http://localhost:4173, aynı proxy)
npm run format           # Prettier
```

Docker: `docker build -t bingol-web ./web`. Kökten `docker compose up -d --build` → `web` servisi `http://localhost:${WEB_PORT:-8090}`
(nginx: SPA fallback, `/api` `/files` `/ws` → `backend:8080`, gzip, uzun önbellek, CSP ve güvenlik başlıkları).

## Ortam değişkenleri

| Değişken | Varsayılan | Anlamı |
|---|---|---|
| `VITE_API_BASE` | `/api` | API taban yolu (derleme zamanı). Aynı kökenden proxy ile sunulduğu için çoğu zaman değişmez. |
| `VITE_DEV_BACKEND` | `http://localhost:8080` | Yalnızca dev/preview: Vite proxy hedefi. |

Docker: derleme `VITE_API_BASE=/api` ile yapılır; `WEB_PORT` (compose) dış portu belirler.

## Klasör haritası (`src/`)

| Klasör | İçerik |
|---|---|
| `api/` | `client.ts` (fetch, Bearer, `Accept-Language`, `ApiError`, tek-uçuş refresh), `types.ts` (tüm sözleşme tipleri), modül başına ince fonksiyonlar (`auth`, `appInfo`, `legal`, `faq`, `users`, `analytics`, `reports`, `support`, `feedback`, `campaigns`, `settings`, `approvals`, `news`, `audit`), `queryKeys.ts` (`qk`), `hooks.ts` (`useAppInfo`, `useStoreLinks`), `index.ts` |
| `auth/` | `AuthProvider` (`useAuth`), `RequireAdmin`, `ForbiddenScreen`, `tokens.ts` (sessionStorage) |
| `i18n/` | `lang.ts`, `I18nProvider` (`useI18n`: `t`, `td`, `formatDate`, `formatNumber`, `dir`), `index.ts` (birleştirici), `{tr,en,ar}/<ad-alanı>.ts` |
| `components/ui/` | UI kiti (Button, Fields, Card/StatCard, Badge/StatusPill, Table, Pagination/LoadMore, Modal/Drawer/ConfirmDialog, Tabs, Toast, Feedback [Spinner/Skeleton/EmptyState/ErrorState], PageHeader, SearchInput, DateRangePicker, Tooltip, Avatar, CopyButton, MarkdownText, DataToolbar, Icon, ContourBackdrop). `import { ... } from '../../components/ui'` |
| `components/charts/` | LineAreaChart, BarChart, DonutChart, FunnelChart, CohortTable (Recharts sarmalayıcıları; **ayrı içe aktarılır**, `ui`'dan çıkmaz) |
| `components/` | `PlaceholderPage`, `brand/Logo` (variant mark|horizontal|vertical, tone auto|light|dark; görseller `src/assets/brand/`, `brand/build.js` üretir), `StoreBadge`, `LanguageSwitcher`, `ThemeToggle`, `ErrorBoundary` |
| `layouts/` | `SiteLayout`, `AdminLayout`, `adminNav.ts` (**menünün tek kaynağı**), `QuickNav`, `UserMenu` |
| `pages/site/`, `pages/admin/` | Her sayfa kendi dosyasında; üstünde kullanacağı API uçlarını yazan yorum vardır |
| `styles/` | `tokens.css` (renk, aralık, gölge, yarıçap, tipografi; açık/koyu/Arapça), `global.css` |
| `lib/` | `storage.ts` (hata toleranslı), `theme.tsx`, `hooks.ts` (`useDebouncedValue`, `usePageTitle`), `date.ts`, `errors.ts` (`errorMessage`) |
| `test/` | `setup.ts`, `utils.tsx` (`renderWithProviders`), `fetchMock.ts` |
| kök | `routes.tsx` (TÜM rotalar), `paths.ts` (yol sabitleri), `App.tsx`, `main.tsx` |

## Yeni sayfa nasıl eklenir

1. `src/pages/admin/XPage.tsx` (veya `site/`) açın; **ilk satırlara hangi API uçlarını kullandığını** yorum olarak yazın. `export default` bileşen.
2. Site sayfası: `src/routes.tsx`; yönetim sayfası: `src/routes.admin.tsx` (ayrı parça, site ziyaretçisi indirmez). `const XPage = lazy(() => import('./pages/.../XPage'))` ve `<Route path="..." element={<XPage />} />` ekleyin.
3. Yönetim menüsünde görünecekse `src/layouts/adminNav.ts` içine öğe ekleyin (yol `paths.ts`'ten).
4. Metinleri **ilgili ad alanı dosyasına** üç dilde ekleyin (`i18n/tr|en|ar/<ad-alanı>.ts`). Anahtarlar `admin.<alan>.*`, `site.*`, `legal.*`, `common.*` önekiyle başlar.
   Eksik anahtar derlemede (en/ar `Record<TranslationKey,string>`) ve testte (`i18n.test.tsx`: üç sözlüğün anahtar kümesi eşit, yer tutucular aynı) yakalanır.
5. Veri için `src/api/*.ts` fonksiyonlarını ve `qk` anahtarlarını `useQuery`/`useMutation` ile kullanın. Hata metni: `errorMessage(useI18n(), err)`.
6. Yer tutucuyu (`PlaceholderPage`) `PageHeader` + gerçek içerikle değiştirin. Yükleniyor/boş/hata durumlarını `Table`, `EmptyState`, `ErrorState` ile verin.

Kurallar: mantıksal CSS (`margin-inline`, `inset-inline-start`…), renkler yalnızca `var(--…)` ile, sayı/e-posta gibi LTR içerik için `className="ltr"`,
grafikler yalnızca `components/charts` üzerinden (Recharts yalnızca onu içe aktaran sayfanın parçasına girer).

## Kimlik ve oturum

- `POST /api/auth/login` → token'lar **sessionStorage**'a (hata toleranslı; admin için localStorage kullanılmaz) → `GET /api/admin/me` ile rol doğrulanır.
- ADMIN olmayan hesap "yetkiniz yok" ekranını görür (`ForbiddenScreen`). `RequireAdmin` `/admin/**`'i korur.
- İstemci 401'de **tek-uçuşlu** refresh yapar (refresh token tek kullanımlıdır; eşzamanlı isteklerde tek `/auth/refresh`). Başarısızsa oturum kapanır ve `/admin/login`'e yönlenir.
- Her istek `Accept-Language: tr|en|ar` taşır (seçim `localStorage` `bu.lang`).

## Çok dillilik

`tr` (varsayılan), `en`, `ar` (`<html dir="rtl" lang="ar">`). Harici kütüphane yok; `useI18n()`:
`t('key', {param})`, `td(dinamikAnahtar, fallback)`, `formatDate/formatDateTime/formatNumber` (Latin rakamlı `ar`).

**Yönetim paneli (`/admin`, giriş dahil) YALNIZ Türkçedir:** `layouts/AdminScope.tsx` dili `tr`ye sabitler (`I18nProvider forcedLang`), dil seçici yoktur, sitenin `bu.lang` tercihi korunur ve panelden çıkınca geri gelir. Yeni panel metinleri yalnız `tr/` altına yazılır; en/ar karşılığı gerekmeyen ad alanları (`tr/admin-guard.ts`, `tr/admin-shell.ts`) `scripts/check-i18n.mjs` içinde `TR_ONLY` listesindedir ve `i18n/all.ts` en/ar sözlüklerine aynı Türkçe metni katar.

**Sözlükler dil başına ve kapsam başına lazy parçadır** (ana paket küçük kalır): `i18n/bundles/site.{tr,en,ar}.ts` (ziyaretçi yalnız kendi dilini indirir), `bundles/admin.tr.ts` (yalnız `/admin`; yönetim yalnız Türkçe), `registry.ts` (çalışma zamanı kayıt defteri: `loadDictionary`, `translate`, `hasKey`; indirme hatasında `I18nProvider` görünen dili korur, hiç dil yoksa Türkçeye düşer). `i18n/index.ts` yalnız tür (`TranslationKey`) ve `translate/hasKey` cephesidir, sözlük içermez; **uygulama kodu `i18n/all.ts`'i içe aktarmaz** (tüm diller ana pakete girer). `all.ts` testler (`test/setup.ts` otomatik içe aktarır), önrender ve betikler içindir. Yeni ad alanı: üç dilde dosya aç, ilgili `bundles/*` dosyasına ve `all.ts`'e ekle. `scripts/prerender.mjs` sayfanın sözlük ve sayfa parçalarını `modulepreload` olarak HTML'e yazar (vite manifest'inden).

## Performans ve paket bütçesi

`npm run check:bundle` (build sonrası): `dist/assets` gzip boyutları `bundle-budget.json` ile karşılaştırılır (girdi paketi, en ağır önrender sayfa, parça başına, toplam). Aşımda çıkış kodu 1; CI'da uyarı (`continue-on-error`). Yeni büyük bağımlılık ya da sayfa eklerken önce bütçeye bakın; bilinçli yükseltmeyi dosyada gerekçeleyin. Yazı tipleri değişken Inter (latin 48 KB, latin-ext 85 KB nadiren, `inter-turkish` 3 KB yalnız Ğ ğ İ ı Ş ş); `/assets/*` ve `/fonts/*` nginx'te 1 yıl `immutable`, HTML `no-cache`.

## API sözleşmesi

[docs/ADMIN_API.md](../docs/ADMIN_API.md) — tüm uçlar için tip (`api/types.ts`) ve fonksiyon yazılmıştır; henüz uygulanmamış yeni uçlar da sözleşmeye göredir.
Not: `GET /api/app/info` mağaza bağlantısı vermez; `useStoreLinks()` `GET /api/app/version?platform=…` içindeki `storeUrl`'ü kullanır (sözleşmede `info.stores` gelirse onu öncelikler).
CSP `img-src` yalnızca `'self' data: https://www.bingol.edu.tr https://*.bingol.edu.tr` içerir (haber görselleri okul sitesinden gelir); başka harici görsel kaynağı eklenmemelidir. Görsel yüklenemezse sayfalar gradyan/ikon yedeği gösterir.

## Tarayıcı (E2E) testleri

Playwright, gerçek backend'e karşı çalışır (örn. `docker compose up -d`). Yönetici hesapları için `scripts/make-user.sh`
(e-posta backend'in `ADMIN_EMAILS` listesinde olmalı) ve demo veri için `scripts/seed-demo.sh` kullanılır.

```bash
# Vite geliştirme sunucusu (kendi portunda) + backend http://localhost:8080
E2E_PORT=5190 E2E_ADMIN_EMAIL=admin1@bingol.edu.tr npx playwright test

# Üretim benzeri nginx (docker compose, WEB_PORT) üzerinde
E2E_BASE_URL=http://localhost:8095 E2E_ADMIN_EMAIL=admin1@bingol.edu.tr npx playwright test site.spec.ts
```

Backend'siz kritik yol testleri (`e2e/mocked-critical.spec.ts`: yönetici girişi, kullanıcı listesi, gönderi gizleme,
küfür listesi; tüm `/api` istekleri `page.route` ile taklit edilir): `npm run e2e:mock` (ilk kez `npm run e2e:install`).
Yavaş makinede `npm run build && npx vite preview --port 4180` açıp `E2E_BASE_URL=http://localhost:4180 npm run e2e:mock` daha hızlıdır.

OpenAPI tipleri: `npm run gen:api` (`docs/openapi.json` -> `src/api/generated/schema.d.ts`); tip güvenli örnek
modüller `src/api/typed/*` (bkz. `docs/MOBILE_CODEGEN.md`).

Notlar: giriş hız sınırı (e-posta başına 15 dk'da 10, IP başına 30) nedeniyle testler belirteçleri yeniden kullanır;
çok çalıştırdıysanız `docker compose exec -T redis redis-cli flushall` ile sınırlar sıfırlanır. `E2E_SHOTS=1` ekran
görüntülerini `e2e/.results/` altına yazar (commit'lenmez).

## Telefon çizimleri ve mağaza rozetleri (tanıtım sitesi)

- `pages/site/components/Phone.tsx` yalnızca çerçevedir; içindeki ekranlar `components/screens/*.tsx` altında mobil uygulamanın tasarım şablonlarının (`mobile/design/*.dc.html`) HTML/CSS ile yeniden çizimidir (görsel dosya yok, gerçek ekran görüntüsü değil). Örnek metinler `screens/text.ts` içinde tr/en/ar; kişi adı/fotoğraf yoktur. Boyut `--phone-s` (390 px tasarım genişliği çarpanı), kırpma `--phone-crop` ile verilir.
- `StoreButton` sitenin tek mağaza düğmesidir (`components/StoreBadge` yalnızca alt bilgi ön ayarıdır). Resmî Google Play / App Store rozet SVG'leri marka kuralları gereği değiştirilmeden kendi sayfalarından alınmalıdır; bu ortamda indirilemediği için nötr, rozet benzeri düğme kullanılır. **Mağazalarda yayına çıkınca `StoreButton` gövdesi resmî rozetlerle değiştirilmelidir** (props aynı kalır).
