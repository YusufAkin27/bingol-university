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

Kaynak: uygulamanın kendi ekran çıktıları `C:\bu_qa\shots\tasarim\...` (RENK-1, Türkçe; Stitch ham ekran çıktıları kullanılmadı; tek istisna Keşfet ekranındaki manzara fotoğraflarıdır, bkz. `src/assets/site/CREDITS.md`). Kişi adı içerenler (Ana Sayfa karşılaması "Merhaba!", Keşfet gönderi sahipleri, Sohbet başlığı "Çalışma Grubu") yazılarak temizlendi; hepsi 600 px genişlikte WebP.

| Web yolu (`src/assets/site/`) | Kaynak |
|---|---|
| `app-home.webp` | `p3/home/birebir/01_ana_sayfa_tr.png` (üst 2110 px, karşılama satırı düzeltilmiş) |
| `app-discover.webp` | Keşfet 2 sütun masonry (Stitch v3 kesfet2 A): `C:\bu_design\stitch\v3_kesfet2\_render\img\*.jpg` manzara fotoğrafları + uygulama düzeni, Playwright ile 390x844 @2x ekran görüntüsü (kişi adı yok; fotoğraf kaynakları `src/assets/site/CREDITS.md`) |
| `app-chat.webp` | `chat_bg/sonra/konusma_acik_tr.png` (başlık adı ve bozuk tepki simgesi temizlenmiş) |
| `app-clubs.webp` | `dd/birebir_kulup/01_kesfet_tr.png` |
| `app-events.webp` | `dd/birebir_etkinlik/01_liste_tr.png` |
| `app-qr.webp` | `dd/birebir_etkinlik/07_yoklama_qr_tr.png` (alt boşluk kırpılmış) |
| `app-menu.webp` | `p3/birebir/menu/10_yemek_tr.png` (alt boşluk kırpılmış) |
| `app-poll.webp` | `pollsup/a02_oy_verme_tr.png` (alt boşluk kırpılmış) |
| `app-academic.webp` | `acad/birebir_akademik/01_hub_tr.png` (alt boşluk kırpılmış) |

## Hukuki ve güven sayfaları (SITE3)

- **`InfoPage`** (Güvenlik, Çocuk Güvenliği, Topluluk Kuralları, Erişilebilirlik, Çerezler, Hesap Silme): `PageHero` + isteğe bağlı `highlights` ("Kısaca": `PointList`, metinler `site.trust.<sayfa>.pt1..`, yalnız sayfanın kendi `pg.*` metinlerini özetler, `components/trustPoints.ts`) + okuma sütunu (~68 karakter) + bölümler ince çizgiyle ayrılır; >= 5 bölümde >= 1040 px yapışkan "Bu sayfada" içindekileri. `figure={{ s1: <PhoneMockup .../> }}` bir bölümün yanına (mobilde altına) görsel koyar; `after`/`intro`/`children` eskisi gibi.
- **`Steps stack`**: tek sütun, adım cümleleri başlık değil paragraf (uzun yönergeler için; `o` numaralı listeler InfoPage'de bununla çizilir).
- **Hesap silme** (`/delete-account`, Google Play için herkese açık URL): adımlar uygulamadaki gerçek yolu anlatır (Ayarlar > Gizlilik ve veriler > Verilerim > Hesabımı sil > onay kutusu > Devam et > şifre). Ekran görüntüsü `app-delete.webp` ← `C:/bu_qa/shots/tasarim/p3/profile/birebir_raw/11_hesap_sil_tr.png` (kişisel veri içermez).
- **Sözleşme okuma** (`LegalPage`/`LegalDocument`): 17 px / 1.75 satır, ~68 karakter, mobilde açılır içindekiler, yazdırma stili (üst/alt bilgi gizli); yüklenirken sürüm satırı yer tutucudur ve iskelet >= 70vh'dir (CLS).

