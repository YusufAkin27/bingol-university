# Web tasarım sistemi ve yeniden tasarım kuralları (`web/`)

Bu belge **mevcut** web tasarım sisteminin envanteridir ve yeni sayfa/bileşen tasarımı için kalıcı kuralları içerir. Sıfırdan ikinci bir sistem kurulmaz: `web/src/styles/tokens.css` tek kaynaktır. Mobil karşılığı: [MOBILE_DESIGN_SYSTEM.md](MOBILE_DESIGN_SYSTEM.md).

## 1. Mimari (değiştirilmez)

- React 18 + TypeScript (strict) + Vite 5, `react-router-dom` 7, `@tanstack/react-query` 5. Test: Vitest, Playwright (`@playwright/test`).
- Stil: **CSS Modules + `tokens.css` değişkenleri**. Tailwind, CSS-in-JS ve shadcn/ui **yoktur ve eklenmez** (shadcn/ui Tailwind ister; bu proje ile uyumsuz). Yeni bağımlılık yalnız gerekçeli ve paket bütçesi (`web/bundle-budget.json`) içinde.
- Dil: tr/en/ar (`web/src/i18n`), Arapçada RTL: **mantıksal CSS özellikleri** (`margin-inline`, `padding-block`, `inset-inline-start`…). Yönetim paneli yalnız Türkçe.
- Herkese açık site önrender edilir (`web/src/seo/prerender.ts`): yeni site sayfası = `routeMeta.ts` kaydı + `site.*` çevirileri + sitemap/JSON-LD testleri.
- Rotalar: site `routes.tsx`, panel `routes.admin.tsx` (lazy). Menü: `layouts/adminNav.ts`.

## 2. Token envanteri (`web/src/styles/tokens.css`)

| Grup | Değişkenler |
|---|---|
| Marka | `--ink #171e33` (lacivert), `--red-600 #f73a2e` (logo), `--red-700 #c62a20` (eylem), `--red-800`, `--chrome` (koyu kabuk), `--hero`/`--hero-end` |
| Anlamsal (açık) | `--bg #faf6f3`, `--surface`, `--surface-2/3`, `--border`, `--border-strong`, `--text`, `--text-muted`, `--text-faint`, `--primary*`, `--accent*`, `--link`, `--focus #1f5fd1` |
| Durum | `--success`, `--warning`, `--danger`, `--info` (+ `-soft`), `--select-bg/-border` (seçim nötr-mavi; kırmızı yalnız marka/tehlike) |
| Boşluk | `--space-1…8` = 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4.5 rem |
| Yarıçap | `--radius-xs 4`, `sm 10`, `md 14`, `lg 20` (kart/panel), `xl 34` (yalnız telefon maketi), `pill` |
| Gölge | `--shadow-1 none`, `--shadow-2` (kart/yükselti), `--shadow-3` (modal/maket) |
| Tipografi | Inter (yerel woff2: latin, latin-ext, turkish). `--text-xs .8125rem … --text-2xl 2rem`, `--text-3xl clamp(2.25rem, 1.4rem + 3.4vw, 3.75rem)` |
| Düzen | `--header-h 64px`, `--ease cubic-bezier(.2,.7,.2,1)` |
| Tema | Açık varsayılan; koyu: `@media (prefers-color-scheme: dark)` **ve** `:root[data-theme='dark']`. Her yeni token iki temada tanımlanır. |

Kural: bileşen CSS'inde **ham renk/piksel yok**, yalnız token. Yeni değer gerekiyorsa önce `tokens.css`'e (açık+koyu) eklenir.

## 3. Bileşen envanteri

- **UI kiti** `web/src/components/ui/` (panel + site): Button, Card, Badge, Fields (Input/Select/Textarea/Checkbox), Overlay (Modal/ConfirmDialog), Table/ResponsiveTable, Tabs, Tooltip, Toast, Pagination, PageHeader, EmptyState/ErrorState/Skeleton (`Feedback`), Insight, StatTile, ProgressBar… (`index.ts` dışa aktarır). Yeni panel sayfası bunları kullanır.
- **Site bileşenleri** `web/src/pages/site/components/`: PageHero, SectionHeading, FeatureRow, PhoneMockup, Steps, PointList, CtaBand, AppCallout, FaqAccordion, StoreButton, NewsCard, Reveal (kaydırınca belirme), InfoPage, LegalDocument…
- Ortak: `LanguageSwitcher`, `ThemeToggle`, `Breadcrumbs`, `CookieBanner`, `ErrorScreen`.

## 4. Tasarım ilkeleri

Modern, minimal, premium, sade; güçlü görsel hiyerarşi; mobil öncelikli; gereksiz gölge/gradient/dekorasyon yok; generic "yapay zekâ şablonu" görünümünden kaçınılır. Marka kimliği: Bingöl dağları ve Murat Nehri'nden gelen soğuk lacivert + kar beyazı yüzey + **tek** kırmızı vurgu.

Her sayfa tasarımında:
1. Önce mevcut sayfayı çalıştırıp incele; amacı ve bilgi hiyerarşisini yaz.
2. `frontend-design` yeteneğini kullan; kütüphane API'si için Context7 ile güncel dokümanı doğrula.
3. Yalnız token + mevcut bileşenler; yeni bileşen yalnızca ortak kullanılacaksa `components/`'e.
4. Yalnız CSS ile geçiştirme: gerekirse yerleşimi, bileşen yapısını ve etkileşimi yeniden kur.
5. Okunabilirlik: gövde ≥ 16 px, ikincil ≥ 13 px; kontrast WCAG AA (açık ve koyu tema); dokunma hedefi ≥ 44 px.
6. Animasyon ölçülü ve `prefers-reduced-motion` ile kapanır; içerik animasyona **bağımlı olmaz** (JS/animasyon çalışmazsa içerik görünür kalır).
7. Erişilebilirlik: klavye, görünür odak, landmark, tek `h1`, `a11y.test.tsx` yeşil.
8. Loading / boş / hata durumları tasarlanır (panel: `Feedback`).
9. İş mantığı, API ve çevirilerin üç dili korunur; RTL'de bozulma olmaz.

## 5. Doğrulama akışı (her tasarım değişikliğinde)

```bash
cd web && npm run lint && npm run typecheck && npm test && npm run build && npm run check:bundle
```

Gerçek tarayıcı kontrolü (Playwright MCP; ekran görüntüleri `.playwright-mcp/` altına, git'e girmez):
1. Yerel: `cd web && npm run dev` (Vite proxy → backend 8080) ya da canlı adres.
2. Görünümler: **1440×900, 768×1024, 390×844**; açık + koyu tema; tr + ar (RTL).
3. `Reveal` içeriği kaydırınca belirir: ekran görüntüsünden önce sayfayı uçtan uca kaydır (tam sayfa görüntü kaydırmaz, bölümler boş çıkar).
4. Taşma denetimi: `document.documentElement.scrollWidth <= innerWidth` ve `right > innerWidth` olan öğe yok.
5. Menü, dil/tema anahtarı, form ve ana CTA'lar tıklanarak denenir; konsol hatası yok.

## 6. Mevcut tasarım bulguları (3 Kasım 2026, canlı `/tr`, 1440 ve 390 px)

Teknik taraf sağlam: mobilde yatay taşma yok, 13 px altı yazı yok, içerik tam. Tasarım iyileştirme adayları:

1. **Hero**: boşluk fazla, hiyerarşi zayıf; telefon maketi küçük ve alt kısmı kesik; marka (Bingöl/Murat Nehri) görsel olarak hissedilmiyor, arka plan dokusu çok soluk.
2. **"Kampüste her gün açacağınız ekranlar"**: dört telefon görüntüsü ~140 px, kesik ve okunamıyor; açıklamalar küçük; üst/alt boşluk dengesiz.
3. **"Üç adımda başlayın"**: adımlar görsel olarak hafif (küçük numara rozeti, tek satır metin), bant içeriği az.
4. **"Verileriniz size ait"**: dört güven kartı sol sütunla dengesiz, ikonlar küçük, kart içi boşluk fazla.
5. **Alt bilgi**: "Yasal" sütunu 11 bağlantı ile çok uzun; iletişim bloğunda kişisel Gmail adresi, kişisel telefon ve Gaziantep adresi var: **kurumsal güven sorunu** (tasarım değil içerik; yönetim panelinde "Ayarlar" ile düzeltilir).
6. **Reveal**: kaydırmadan alınan tam sayfa görüntüde üç bölüm boş çıkıyor. Kaydırınca içerik geliyor (hata değil) ama animasyon başarısız olursa içerik gizli kalmamalı (bkz. ilke 6).
7. Bu taramada **incelenmeyenler**: koyu tema, Arapça (RTL), tablet genişliği ve iç sayfalar (Özellikler, Haberler, Yemek listesi, Yardım, Hakkımızda, İndir, hukuki metinler) ve yönetim paneli.
