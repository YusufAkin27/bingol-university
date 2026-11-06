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
| Marka | `--logo-ink` (logo yazısı/glifi: açık temada `#09090b`, koyu temada `#fff`), `--logo-ink-on-light #09090b` / `--logo-ink-on-dark #fff` (zorunlu zemin için sabit tonlar), `--ink #171e33` (lacivert metin), `--red-700 #c62a20` (eylem), `--red-600`/`--red-800`, `--chrome` (koyu kabuk), `--hero`/`--hero-end` |
| Anlamsal (açık) | `--bg #faf6f3`, `--surface`, `--surface-2/3`, `--border`, `--border-strong`, `--text`, `--text-muted`, `--text-faint`, `--primary*`, `--accent*`, `--link`, `--focus #1f5fd1` |
| Durum | `--success`, `--warning`, `--danger`, `--info` (+ `-soft`), `--select-bg/-border` (seçim nötr-mavi; kırmızı yalnız marka/tehlike) |
| Boşluk | `--space-1…8` = 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4.5 rem |
| Yarıçap | `--radius-xs 4`, `sm 10`, `md 14`, `lg 20` (kart/panel), `xl 34` (yalnız telefon maketi), `pill` |
| Gölge | `--shadow-1 none`, `--shadow-2` (kart/yükselti), `--shadow-3` (modal/maket) |
| Tipografi | Inter (yerel woff2: latin, latin-ext, turkish). `--text-xs .8125rem … --text-2xl 2rem`, `--text-3xl clamp(2.25rem, 1.4rem + 3.4vw, 3.75rem)` |
| Düzen | `--header-h 64px`, `--ease cubic-bezier(.2,.7,.2,1)` |
| Tema | Açık varsayılan; koyu: `@media (prefers-color-scheme: dark)` **ve** `:root[data-theme='dark']`. Her yeni token iki temada tanımlanır. |

Kural: bileşen CSS'inde **ham renk/piksel yok**, yalnız token. Yeni değer gerekiyorsa önce `tokens.css`'e (açık+koyu) eklenir.

### Marka / logo (siyah-beyaz, 2026-11-06)
- Marka logosu artık **yalnız siyah ve beyazdır** (kırmızı BÜ karesi kaldırıldı). Kaynak: repo kökündeki `dark_logo.png` (siyah zemin, beyaz glif) ve `light_logo.png` (beyaz zemin, siyah glif). Kırmızı yalnız arayüz eylem vurgusudur (`--red-700`), logoda kullanılmaz.
- Varlıklar `python -I -X utf8 web/scripts/build-brand.py` ile üretilir (Pillow; kök PNG yoksa `web/public/brand/square-*.png` kaynak alınır): şeffaf glif `src/assets/brand/mark-{light,dark}.png` (192 px, paketlenir) ve `public/brand/mark-*.png` (512) / `square-*.png` (1024, kaynak varlık; basın kiti sayfası kaldırıldı); sekme ikonları `favicon-light.png` / `favicon-dark.png` (+ `favicon.ico`, açık tabanlı), `apple-touch-icon.png`, `icon-192/512.png`, `icon-maskable-512.png` (güvenli alan), `og.png` (koyu zemin, beyaz logo + metin).
- Tek bileşen: `components/brand/Logo` (`variant` mark|horizontal|vertical, `tone` auto|light|dark). `auto` iki `<img>` basar ve `[data-theme]` / `prefers-color-scheme` ile birini gösterir: koyu temada beyaz, açık temada siyah glif. Yatay/dikey sürümde glifin yanındaki "Kampüs" yazısı HTML metnidir (`--logo-ink`). Koyu kabuk üzerinde (yönetim yan menüsü) `tone="dark"` verilir. Yeni logo yeri bu bileşenle yapılır; `<img src="/brand/...">` doğrudan kullanılmaz.
- `index.html`: `<link rel="icon" media="(prefers-color-scheme: ...)">` ile sekme ikonu sistem temasına uyar; `theme-color` açık `#FFFFFF`, koyu `#09090B`; `site.webmanifest` `theme_color #09090B`, `background_color #FFFFFF`.

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

## 7. Yönetim paneli: Premium Monochrome (2026-11-06)

`/admin` (giriş/kayıt dahil) mobil uygulamanın "Premium Monochrome" diline getirildi: **marka/vurgu rengi yok, kırmızı yalnız tehlike/hata, kalın yazı yok**. `AdminScope` `<html data-area="admin">` koyar; `tokens.css` sonundaki üç blok (açık, sistem koyu, elle koyu; özgüllük `html:root[data-area='admin']` = 0,2,1) eski marka belirteçlerini nötr tonlarla ezer. Bileşen CSS'i değişmeden kalır: renkler belirteçten gelir, bu yüzden herkese açık site (`data-area` yok) bu bloklardan etkilenmez.

**Belirteçler (yönetim kapsamı)**

| Belirteç | Açık (Premium White) | Koyu (Premium Black) |
|---|---|---|
| `--bg` | `#ffffff` | `#09090b` |
| `--surface` / `--surface-2` / `--surface-3` | `#fafafa` / `#f4f4f5` / `#e4e4e7` | `#141416` / `#1c1c1f` / `#252528` |
| `--text` / `--text-muted` / `--text-faint` | `#09090b` / `#52525b` / `#5f5f68` | `#fafafa` / `#a1a1aa` / `#8e8e97` |
| `--border` / `--border-strong` | `#e4e4e7` / `#71717a` (girdi çerçevesi >= 3:1) | `#303034` / `#74747c` |
| `--primary`, `--accent`, `--link`, `--focus`, `--chrome` | `--text` (ters yüzey: düğme, bağlantı, odak halkası 2 px, ipucu) | aynı: `--text` |
| `--primary-contrast`, `--on-chrome` | `--bg` | `--bg` |
| `--danger` / `--danger-soft` | `#b3261e` / `#fbeeed` (tek renkli belirteç) | `#ff8a82` / `#2a1514` |
| `--success`, `--warning`, `--info` | nötr (`--text` / `--text-muted`); anlam simge + kenarlık biçimi + etiketle verilir | aynı |
| `--chart-1…6` | `#09090b #52525b #7a7a84 #8e8e96 #a8a8b0 #c4c4ca` | `#fafafa #a1a1aa #7b7b84 #62626a #4f4f55 #3f3f44` |
| `--sb-*` (yan menü) | yüzey `--surface` + 1 px kenarlık; etkin öğe zemin farkı + 3 px işaret | aynı |
| `--fw-emphasis` | **400** (tek anahtar); `--fw-regular/medium/semibold/bold/black` ve `--weight-display` buna bağlı | aynı |

**Kurallar**
- Ham renk yok: yeni renk önce `tokens.css`'e (açık + koyu). Kırmızı yalnız `--danger*` (silme, engelleme, doğrulama hatası). Kullanıcı fotoğrafı/medya doğal renkte kalır; e-posta önizleme zemini (`--paper`), medya karartması (`--scrim-media`) ve bildirim telefonu maketi (`--phone-*`) sabit siyah-beyazdır.
- Kalın yazı yok: CSS'te `font-weight: var(--fw-semibold)` gibi **belirteç** yazılır (ham 500/600/700/800 yazılmaz); hiyerarşi boyut + renk + boşlukla kurulur. Kullanıcı kalın isterse tek satır: `--fw-emphasis: 600` (yönetim bloğu).
- Durum (başarı/uyarı/bilgi/tehlike): `Badge` renk yerine simge (onay, üçgen, çarpı, i) ve kenarlık biçimiyle ayrışır (başarı dolu gri, uyarı kesikli, bilgi çizgili, tehlike kırmızı çerçeve); `StatusPill` dolu/halka nokta; `StatusDot` zaten simge taşır. Renk tek başına anlam taşımaz (renk körlüğü dostu).
- Grafik: tek ton skalası; seri ayrımı ek olarak çizgi stili (`CHART_DASHES`: düz, kesik, noktalı...), yığılı/çok serili çubukta 1 px yüzey boşluğu, her zaman açıklama (legend) ve doğrudan etiket/tablo görünümüyle yapılır; tek seri tam kontrast `--chart-1`. 5. ve 6. ton yalnız dolgu ayrımıdır (< 3:1): 4'ten çok seri "Diğer"e katlanır.
- Köşe 10-12-16 (`--radius-sm/md/lg`), ince 1 px kenarlık, gölge yalnız açılır katmanlarda (`--shadow-2/3` çok hafif), gradient/neon/cam yok (iskelet yüklemesi düz yüzey + nefes opaklığı). Animasyon 180-250 ms, `prefers-reduced-motion`'da kapalı.
- Denetim: `web/src/adminMono.test.ts` (yönetim CSS/TSX'inde ham renk yok, `font-weight > 400` yok, yönetim blok belirteçleri nötr, gradient renksiz). Görsel doğrulama: `web/e2e/admin-mono-shots.spec.ts` (backendsiz, tüm sayfalar x açık/koyu x 1440/390/768; `INDEX.md`).

## 8. Canlı hatta taşıma notu (deploy/web-20261106)

Siyah-beyaz tasarım `deploy/release3-20261106` üzerine taşındı. Birleştirme kuralı: canlı hattın **içerik mantığı** (forum/push/rbac yönetici sayfaları, menü/haber/SSS/yasal sayfaların iş mantığı, JSON-LD, `InlineLinks`, `useActiveSection` içindekiler) korunur; yeni **belirteçler** (`tokens.css` yönetim + site blokları, `--fw-*`) ve ana sayfa/Özellikler/İndir/Hakkımızda/logo/telefon maketi tasarımı bunun üstüne uygulanır. Canlı hatta olup tasarım dalında olmayan yönetici CSS'leri (zaman çizelgesi, sistem, yedek vb.) aynı kurallara getirildi: `font-weight` yalnız `var(--fw-*)`, ham renk yok, gradient renksiz (`--text`/`--text-muted`). `adminMono.test.ts` bunları denetler.
