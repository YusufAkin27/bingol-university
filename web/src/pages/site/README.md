# Tanıtım sitesi: ortak bileşenler el kitabı (SITE1)

Kalan site sayfalarını yazacak ajanlar için. Tüm bileşenler `src/pages/site/components/` altındadır; stiller CSS Modules + `src/styles/tokens.css` belirteçleri, mantıksal CSS özellikleri (RTL), dış font/CDN yok.

1. **Sayfa iskeleti:** `usePageMeta({ route })` (SEO tek kaynağı `seo/routeMeta.ts`) + `<PageHero eyebrow title lead crumbs />` (tüm iç sayfaların minimal başlığı: bol boşluk, hafif kırmızı ışıma; tek `h1` burada) + içerik bölümleri (`<section className="container">`, dikey boşluk `clamp(2.75rem, 7vw, 5rem)`) + sayfa sonu `<CtaBand title text />`.
2. **Telefon:** `<PhoneMockup shot="home" />` (iPhone görünümlü saf CSS çerçeve; ekran `<img width height>`, alt metni çevrilir). `shot` kimlikleri `screenshots.ts`'te: `home, discover, chat, clubs, events, qr, menu, poll, academic`. Boyut: `width="min(60vw, 240px)"` ya da bağlamda `--phone-w`. `tilt={±2..6}` hafif eğim, `crop={0.6}` (tam boy ekranın oranı) kart içinde kısa telefon, `peek` alttan solma (altı boş ekranlar zaten peek). Sayfada yalnız ilk ekrandaki telefona `priority` verin (LCP: `fetchpriority=high`, `loading=eager`); diğerleri lazy.
3. **Yeni ekran görüntüsü eklemek:** PNG'yi 600 px genişlikte WebP'ye çevirin (<= 60 KB, ASCII ad, `src/assets/site/app-<ad>.webp`), kişi adı/e-posta/uydurma sayı içermesin, `screenshots.ts`'e `{src,width,height,peek,alt}` ekleyin ve `site.shot.<ad>.alt` anahtarını üç dile yazın (`site.test`/`site1.test.tsx` boyut ve çeviri denetler).
4. **Mağaza düğmesi:** `<StoreButton store="android|ios" href={stores.android} size="lg" />`; `stores = useStoreLinks()`. Bağlantı BOŞSA rozet tıklanamaz ve "Yakında" der; ASLA sahte adres yazmayın. Alt bilgide ince ön ayar `components/StoreBadge`. Koyu zemin için `onDark`, açık yüzey için `variant="outline"`.
5. **Başlıklar ve ritim:** `<SectionHeading eyebrow title lead align level />` (h2 varsayılan). Sayfada tek h1; bölümler h2, kart başlıkları h3.
6. **Özellik satırı:** `<FeatureRow shot secondShot title text flip />` (zikzak; RTL'de otomatik aynalanır); satırları `<ul><li>` içine koyun. Veri: `components/features.ts` (`SHOWCASE` = ekranlı 8 özellik, `FEATURES` = 14 ayrıntı, metinler `site.show.*` / `site.feat.*`).
7. **Adımlar ve maddeler:** `<Steps items={[{title,text?}]} />` (numaralı `<ol>`, masaüstünde 3 sütun), `<PointList items={[{icon,text}]} />` (simgeli kart ızgarası; güvenlik/gizlilik/değerler).
8. **Hareket:** kaydırınca beliren öğeler için `<Reveal delay={80}>` (yalnız opacity + transform, `IntersectionObserver`; `prefers-reduced-motion` ve IO yoksa doğrudan görünür). İlk ekrandaki (LCP) öğeleri sarmayın. JS animasyon kitaplığı eklemeyin.
9. **Bağlantılar ve dil:** iç bağlantılar yalnız `paths.ts` sabitleriyle ve `components/LocalizedLink`'in `Link/NavLink`'i ile (dil öneki otomatik). Metinler `src/i18n/{tr,en,ar}/` dosyalarında, yeni anahtar = üç dil (`npm run check:i18n`); yeni dosya eklerseniz `i18n/bundles/site.<dil>.ts`'e katın. Arapçada Latin kimlikler (`bingol.edu.tr`) için `className="ltr"`.
10. **Yasaklar:** uydurma sayı/istatistik/yorum/ödül yok; uygulama Bingöl Üniversitesi'nin RESMÎ uygulaması DEĞİL, bağımsız öğrenci uygulamasıdır (`site.v3.independent`, `site.v3.footer.independent`); yönetim yolu bağlantısı yok; yeni dinamik rota yok (404 mantığı W2-K'da). Her sayfa 390 dp'de yatay kaydırmasız, 1280 px'te düzgün olmalı; doğrulama: `npx vitest run src/pages/site`, `npx playwright test w3site-cls.spec.ts`.

## Ekran görüntüleri (kaynak → web)

Kaynak: GÜNCEL uygulamanın gerçek ekran çıktıları. Tek üretici: `mobile/test/redesign/site_shots_test.dart` (gerçek widget'lar + uydurma veri: "Elif K." gibi sade adlar, gerçek kişi/e-posta yok; Türkçe, açık tema, 390x844 dp, dpr 3 = 1170x2532 PNG, elle çizilmiş 9:41 durum çubuğu). Üretim (PowerShell, `C:u_mobile` içinde): `$env:SITE_SHOTS_OUT='C:u_qa\shots\site2'; flutter test test/redesign/site_shots_test.dart --tags store-shots` (`SITE_SHOTS_ONLY=home,menu` ile daraltılır). PNG'ler 900 px genişlikte WebP'ye çevrilir (Pillow, quality 82, her biri <= 90 KB; `app-<ad>.webp`, 900x1948). Altı kısa kalan iki ekran (`qr`, `academic`) içeriğin altından kırpılır ve `peek` çizilir.

| Web yolu (`src/assets/site/`) | Test sahnesi (kaynak ekran) |
|---|---|
| `app-home.webp` | `home`: `AppShell` Ana Sayfa sekmesi (alt gezinme çubuğu dahil) |
| `app-discover.webp` | `discover`: `AppShell` Keşfet sekmesi (2 sütun masonry) |
| `app-chat.webp` | `chat`: `ChatDetailPage` birebir konuşma (görsel + okundu) |
| `app-clubs.webp` | `clubs`: `AppShell` Kulüpler sekmesi (Keşfet) |
| `app-events.webp` | `events`: `EventsPage` (takvim + gün listesi) |
| `app-qr.webp` | `qr`: `Etkinlik2QrPage` (yoklama QR, 900x1538 kırpık, peek) |
| `app-menu.webp` | `menu`: `MenuPage` (günün menüsü + kalori + "Yemek kartı bakiyesi / Bakiye yükle" kartı) |
| `app-poll.webp` | `poll`: `PollDetailPage` (oy verme, "Oy ver" düğmesi) |
| `app-academic.webp` | `academic`: `AcademicHubPage` (sıradaki sınav + 4 kart, 900x1462 kırpık, peek) |
| `app-delete.webp` | `delete`: `DeleteAccountPage` (Hesabı sil) |
| `app-support.webp` | `support`: `SupportPage` (SSS açık + taleplerim + Yeni talep) |

## Hukuki ve güven sayfaları (SITE3)

- **`InfoPage`** (Güvenlik, Çocuk Güvenliği, Topluluk Kuralları, Erişilebilirlik, Çerezler, Hesap Silme): `PageHero` + isteğe bağlı `highlights` ("Kısaca": `PointList`, metinler `site.trust.<sayfa>.pt1..`, yalnız sayfanın kendi `pg.*` metinlerini özetler, `components/trustPoints.ts`) + okuma sütunu (~68 karakter) + bölümler ince çizgiyle ayrılır; >= 5 bölümde >= 1040 px yapışkan "Bu sayfada" içindekileri. `figure={{ s1: <PhoneMockup .../> }}` bir bölümün yanına (mobilde altına) görsel koyar; `after`/`intro`/`children` eskisi gibi.
- **`Steps stack`**: tek sütun, adım cümleleri başlık değil paragraf (uzun yönergeler için; `o` numaralı listeler InfoPage'de bununla çizilir).
- **Hesap silme** (`/delete-account`, Google Play için herkese açık URL): adımlar uygulamadaki gerçek yolu anlatır (Ayarlar > Gizlilik ve veriler > Verilerim > Hesabımı sil > onay kutusu > Devam et > şifre). Ekran görüntüsü `app-delete.webp` ← `site_shots_test.dart` `delete` sahnesi (kişisel veri içermez).
- **Sözleşme okuma** (`LegalPage`/`LegalDocument`): 17 px / 1.75 satır, ~68 karakter, mobilde açılır içindekiler, yazdırma stili (üst/alt bilgi gizli); yüklenirken sürüm satırı yer tutucudur ve iskelet >= 70vh'dir (CLS).
- **Okuma sayfaları monochrome (C dalgası):** `InfoPage`, `LegalDocument`, `LegalListPage`, `DataRequestPage`, `DeleteAccountPage`, `BrandPage`, `PointList`, `AdminAccessNotice` yalnız anlamsal belirteç kullanır (`--text`/`--text-muted`/`--text-faint`, `--border`, `--surface*`; vurgu rengi yok, `font-weight` yalnız `--fw-emphasis`). Okuma belirteçleri `tokens.css` sonundaki "site: okuma" bloğunda: `--read-measure` (68ch), `--read-size`, `--read-leading`, `--touch-min` (44 px), `--rule` (1 px çizgi), `--label-track` (küçük büyük-harf etiket aralığı; Arapçada 0), `--font-serif` (yalnız marka kiti başlık örneği). **`ReadingToc`** (`components/ReadingToc.tsx`): içindekilerin tek bileşeni (geniş: yapışkan liste + `aria-current="location"` ile aktif bölüm işareti, `useActiveSection`; dar: açılır düğme); `usePrintDoc` yazdırmada site üst/alt bilgisini gizler. Gövde metni ikincil ton, başlık/vurgu/bağlantı tam metin rengi (kalın yazı yok); yazdırma stili sade siyah-beyaz, harici bağlantılar sonuna adresiyle basılır. Hukuki metin İÇERİĞİ ve çevirileri değişmedi.

