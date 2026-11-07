# Teknik SEO (tarayıcı yüzeyi): robots, sitemap, URL hijyeni, başlıklar, denetim

Site: <https://bukampus.com.tr>. Kapsam: botların sitemizi **nasıl bulduğu ve neyi gördüğü** (robots.txt, sitemap.xml, yönlendirmeler, durum kodları, HTTP başlıkları, JS'siz içerik, denetim betiği). Sayfa içi meta/JSON-LD ayrı iştir; strateji ve kullanıcı kontrol listesi için bkz. [SEO.md](SEO.md).

Dosya haritası:

| Dosya | Görevi |
|---|---|
| `web/src/seo/crawl.ts` | `buildRobots`, `buildSitemap` (diller `routeMeta.localizedLangs`), içerik özeti (`contentHash`) |
| `web/src/seo/prerender.ts` | sayfa başına head/noscript (2. iş); burada yalnız `routeSignature` ve sitemap/robots çağrıları |
| `web/scripts/prerender.mjs` | derleme sonrası dosya yazımı, `seo-lastmod.json`, nginx üretilen parça, doğrulama |
| `web/seo-lastmod.json` | sayfa başına gerçek `lastmod` kaydı (depoda tutulur) |
| `web/nginx.conf`, `web/nginx-security.conf` | URL hijyeni, 404, `X-Robots-Tag`, önbellek, `.well-known` |
| `deploy/Caddyfile` | uç katman: https, www → apex, API/dosya yanıtlarında `X-Robots-Tag` |
| `web/scripts/check-seo.mjs` | `npm run check:seo` denetimi (+ `--live` canlı davranış denetimi) |
| `web/scripts/refresh-prerender.mjs` | gece menü/haber yenilemesi (bölüm 6) |

## 1. Canlıda bulunan sorunlar (2026-11-01, yalnız `GET`/`HEAD`) ve çözümleri

| Bulgu (canlı) | Etki | Çözüm |
|---|---|---|
| `/zzz`, `/foo/bar`, `/.env`, `/sitemap.xml/` → **200 + SPA HTML** | soft 404; dizin kirliliği | `location /` artık `try_files $uri =404`; yalnız gerçek dosya ya da bilinen rota sunulur (404 + `404.html`, `noindex`) |
| `/.well-known/assetlinks.json` ve `apple-app-site-association` → 200 + HTML | App Links / Universal Links doğrulaması başarısız | ayrı konumlar: dosya yoksa yalın `404`, varsa `application/json`, yönlendirme yok (bölüm 7) |
| `/TR`, `/Tr/privacy` → 200 | aynı içerik farklı adreste | küçük harfe **301** |
| `/tr/privacy/`, `/tr//privacy`, `/tr/index.html`, `/index.html` → 200 | yinelenen URL (canonical kurtarır ama sinyal bölünür) | tek kanonik biçime **301** (bölüm 3) |
| `/privacy/` → `/tr/privacy/` → (200) iki atlama | sızıntı | eski öneksiz adres tek atlamada `/tr/privacy` |
| `/admin/*` başlıksız 200 (yalnız JS ile `noindex`) | yönetim kabuğu dizine girebilir | tüm yönetim yollarında `X-Robots-Tag: noindex, nofollow, noarchive` (gizli `ADMIN_PATH` dahil, bölüm 5) |
| `/tr/news/<id>` statik kabuğu ana sayfanın canonical'ını taşıyor | kopya kabuk | `X-Robots-Tag: noindex, follow` (haber ayrıntısı dizine girmez; liste girer) |
| `/api/*` (Caddy doğrudan backend) `X-Robots-Tag` yok | robots dışında ikinci güvence yok | Caddy'de `/api`, `/files`, `/ws` ve iç uçlarda `noindex, nofollow` |
| `Content-Type: text/html` (charset yok), sitemap `text/xml` | düşük risk | `charset utf-8` (Arapça/Türkçe), sitemap `application/xml` |
| robots.txt yalnız `*` grubu | eğitim botları serbest; destek izleme/ws kapalı değil | bölüm 2 |
| sitemap'te 81 URL, hepsinde `lastmod` = derleme günü | Google `lastmod`'a güvenmeyi bırakır | bölüm 4 |
| hukuki belgelerin en/ar sürümü hreflang kümesinde | metin Türkçe → kopya | sitemap'ten çıkarıldı; baş (head) tarafı 2. işin (bölüm 4.3) |
| `location /api/` vb. `^~` değil (regex konumu `*.js` isteklerini kapabilir) | `/api/x.js` yanlış yönlenir (`SECURITY_AUDIT_2026-10-28`) | `^~ /api/`, `^~ /files/`, `^~ /ws` |

Zaten doğru olanlar: http → https (Caddy 308), `www` → apex (301, yol korunur), HSTS, tek biçim `/tr` ana sayfa canonical, `404.html` + `noindex`, `/support/track` `noindex`.

## 2. robots.txt politikası

`web/src/seo/crawl.ts` → `buildRobots`. Derlemede `dist/robots.txt`.

- **`User-agent: *`**: `Disallow: /api/ /files/ /ws /actuator/ /admin /support/track /*/support/track`; `Allow: /`. Sayfalar, `/assets/` (JS/CSS), `/fonts/`, `/og.png` açıktır; Google'ın sayfayı **render edebilmesi** için JS/CSS engellenmemelidir (`check:seo` doğrular).
- **Googlebot / Bingbot / Yandex / DuckDuckBot ve yanıt-arama botları** (OAI-SearchBot, ChatGPT-User, PerplexityBot, Claude-SearchBot…) `*` kuralıyla serbesttir.
- **Yalnız model eğitimi botları kapalı** (`Disallow: /`): GPTBot, Google-Extended, CCBot, ClaudeBot, anthropic-ai, Applebot-Extended, Bytespider, meta-externalagent, cohere-ai, Diffbot, ImagesiftBot. Gerekçe: haber/duyuru içeriği üniversitenin; eğitim verisi olarak toplanması istenmez. Arama ve yanıt motorlarında görünürlük korunur. **Karar sizindir**: listeyi değiştirmek için yalnız `AI_TRAINING_BOTS` (crawl.ts) düzenlenir. `Google-Extended` yalnız Gemini eğitimini kapatır, Google Arama'yı etkilemez.
- **Gizli yönetim yolu** (`ADMIN_PATH`) robots.txt'te yazılmaz (yolu açıklamamak için); onu `X-Robots-Tag` korur. `prerender.mjs` ve `check:seo` bunu doğrular.
- **Hesap silme / veri talebi** sayfaları indekslenebilir bırakıldı: Google Play, hesap silme URL'sinin herkese açık ve taranabilir olmasını ister. Form gönderimi zaten `noindex` gerektirmez (sayfada kişisel veri yok). Giriş/kayıt yalnız yönetim panelindedir (`noindex`).
- `Crawl-delay` yok (Google yok sayar; Bing için gerekirse Bing Webmaster'dan ayarlanır).

## 3. URL sözleşmesi (tek kanonik biçim)

Kanonik biçim: `https://bukampus.com.tr/<tr|en|ar>[/yol]`; küçük harf; sonda `/` yok; `index.html` yok; çift `/` yok; sorgu dizesi yok (izleme parametreleri canonical'a girmez).

| İstek | Yanıt |
|---|---|
| `http://…` | 308 → https (Caddy) |
| `www.bukampus.com.tr/<yol>` | 301 → `bukampus.com.tr/<yol>` (Caddy) |
| `/` | 200: Türkçe ana sayfa üstverisi (canonical `/tr`), istemci dil seçer (`RootRedirect`). **Sunucu `Accept-Language` ile YÖNLENDİRMEZ**: botlar hep aynı içeriği görür; hreflang `x-default` = `/tr` |
| `/index.html`, `/tr/index.html`, `/tr/privacy/index.html` | 301 → `/`, `/tr`, `/tr/privacy` |
| `/tr/`, `/tr/privacy/`, `/tr//privacy`, `//tr/privacy` | 301 → `/tr`, `/tr/privacy` |
| `/TR`, `/Tr/privacy`, `/EN/faq` | 301 → küçük harf dil öneki |
| `/privacy`, `/privacy/`, `/news/12/` vb. (eski öneksiz site adresleri) | 301 → `/tr/privacy` … (Google Play'e verilmiş adresler bozulmaz; sorgu dizesi korunur) |
| `/brand`, `/brand/` | 301 → `/tr/brand` (`/brand/<dosya>` varlıktır, yönlenmez) |
| `/tr/news/123`, `/tr/legal/<tür>`, `/tr/support/track` | 200 kabuk (dinamik; ilki ve sonuncusu `noindex`) |
| `/admin`, `/admin/*` (ya da `ADMIN_PATH`) | 200 kabuk + `X-Robots-Tag: noindex, nofollow, noarchive` |
| Bilinmeyen herhangi yol (`/zzz`, `/tr/zzz`, `/.env`) | **404** + `404.html` (`noindex`, `h1`, açıklama, canonical yok) |
| `/.well-known/assetlinks.json`, `/apple-app-site-association` yoksa | yalın 404 (HTML değil) |
| `/api/*`, `/files/*`, `/ws` | backend; `X-Robots-Tag: noindex, nofollow` |

Gerekçe notları:
- 410 kullanılmadı: kaldırılmış kalıcı bir sayfa yok; eski öneksiz adresler 301 ile yaşar. Bir sayfa gerçekten kaldırılırsa `nginx.conf` içine `location = /tr/eski { return 410; }` eklenir ve sitemap'ten düşer.
- Yönlendirmeler `$request_uri` (ham, kodlu) ile yapılır; çözülmüş `$uri` satır sonu enjeksiyonuna açıktır. Test: `crawl.test.ts`.
- Haritalar (`map $request_uri $site_canon` …) `conf.d` içinden `http{}` bağlamına dahil edildiği için `server{}` dışında durur.

## 4. sitemap.xml

### 4.1 İçerik
`buildSitemap` (crawl.ts). 78 URL (27 rota × 3 dil − haberin en/ar'ı − açık rızanın ar'ı = 78; bölüm 4.3). Her `<url>`: mutlak https `loc`, `lastmod`, `xhtml:link` hreflang (`tr`, `en`, `ar`, `x-default`; kendine dahil, karşılıklı), `changefreq`/`priority` (Google yok sayar, zararsız). `noindex` sayfalar (404, destek izleme, haber ayrıntısı, yönetim) yoktur.

### 4.2 `lastmod`: sayfa başına gerçek tarih
`web/seo-lastmod.json`: `"<rota>:<dil>" → { hash, lastmod }`. Her derlemede sayfanın **içerik imzası** (başlık, açıklama, JSON-LD, noscript metni; hash'li varlık adları ve modulepreload HARİÇ) hesaplanır:
- imza aynı → eski `lastmod` korunur;
- imza değişti ya da kayıt yok → `lastmod` = derleme günü (İstanbul saati) ve dosya güncellenir.

**Kural: sayfa metnini/başlığını/açıklamasını değiştiren commit'te `npm run build` çalıştırıp güncellenen `web/seo-lastmod.json`'u da commit edin.** (Docker derlemesi dosyayı depodan okur, konteyner içinde yazılanı atar; commit edilmezse o dağıtımda değişen sayfalar yine "bugün" alır ama sonraki dağıtımda tekrar bugün alır: tarih ilerler, yanlış-eski olmaz.) İlk tohum: sayfa bileşeninin son git değişiklik tarihi. `SEO_LASTMOD_WRITE=0` dosyayı yazmaz (salt okunur CI).
`/menu` ve `/news` için asıl `lastmod`'u gece yenilemesi verinin değiştiği güne çeker (bölüm 6).

### 4.3 Yanlış dilli sayfalar (kısmi yerelleşme kuralı)
İçeriği yalnız bazı dillerde gerçekten yerelleştirilmiş sayfalar `RouteMeta.langs` ile işaretlenir (`src/seo/routeMeta.ts`, **tek kaynak**, `localizedLangs()`): şu an `/news` (yalnız `tr`: haberler kaynak sitede Türkçe) ve `/legal/explicit-consent` (`tr`+`en`: Arapçası yok). Hukuki belgelerin geri kalanının en/ar metni arka uçta VAR (V820), bu yüzden üç dilde indekslenir. Kural:
- **sitemap** (`crawl.ts`) ve **sayfa head'i** (`headModel.ts`) aynı `localizedLangs`'i kullanır: yerelleşmiş dillerin URL'si + hreflang kümesi + `x-default` (listede `tr` varsa o). Yerelleşmemiş dil sürümü (ör. `/en/news`) `canonical → /tr/news`, hreflang yok, sitemap dışı.
- `check-seo.mjs` aynı tabloyu `PARTIAL_LANG_PATHS` olarak aynalar (betik TypeScript'e bağımlı olmasın); `crawl.test.ts` iki tarafın eşitliğini doğrular. Yeni kısmi rota = `routeMeta.ts` `langs` + `PARTIAL_LANG_PATHS` satırı.
- Haber ayrıntısı sitemap'e hiç girmez (`noindex, follow`).

## 5. HTTP başlıkları

| Konum | `X-Robots-Tag` | `Cache-Control` |
|---|---|---|
| `/tr`, `/en/…` sayfaları ve kök | `max-image-preview:large` | `no-cache` (ETag ile doğrulama) |
| haber ayrıntısı `/xx/news/<id>` | `noindex, follow` | `no-cache` |
| `/xx/support/track` | `noindex, nofollow` | `no-cache` |
| yönetim kabuğu (`/admin` ya da `ADMIN_PATH`) | `noindex, nofollow, noarchive` | `no-cache` |
| `404.html` | `noindex, nofollow` | `no-cache` |
| `/api`, `/files`, `/ws` (nginx ve Caddy) | `noindex, nofollow` | backend |
| `/assets/*`, `/fonts/*` | – | `public, max-age=31536000, immutable` |
| `/robots.txt`, `/sitemap.xml` | – | `public, max-age=3600` |
| küçük hash'siz dosyalar (png, svg, js…) | – | `public, max-age=604800` |
| `.well-known/*` | – | `public, max-age=3600` |

Sıkıştırma: Caddy `zstd gzip`; nginx `gzip` (brotli modülü imajda yok). HTTP/2-3 Caddy'de (`Alt-Svc: h3`). `Link: rel=canonical` başlığı gerekmez.

Güvenlik başlıkları SEO'yu bozmuyor: CSP `default-src 'self'` + `img-src` bingol.edu.tr (JS/CSS/görsel aynı kökenden; Googlebot render eder), `X-Frame-Options: DENY` yalnız çerçevelemeyi engeller, `Referrer-Policy` ölçümü etkilemez. **HSTS**: `max-age=31536000; includeSubDomains` var, `preload` yok. hstspreload.org koşulları (≥1 yıl, `includeSubDomains`, `preload`) teknik olarak yakındır, ama listeye girmek **geri alması yıllar süren** bir karardır ve **tüm alt alanların** https'e hazır olmasını gerektirir; bu yüzden eklenmedi (karar kullanıcıya aittir: alt alanlar hazırsa `Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"` yazıp hstspreload.org'dan başvurun).

Gizli `ADMIN_PATH`: derlemede `prerender.mjs` yolu doğrular (`^/[A-Za-z0-9_-]+(/…)*$`) ve nginx konum parçasını (`dist/_nginx-generated.conf`) üretir; `Dockerfile` onu `/etc/nginx/snippets/generated-locations.conf`'a taşır, html kökünden siler. Parça yoksa imaj derlenmez ve nginx açılmaz (kapalı-hata).

## 6. Taze içerik: menü ve haber (gece yenileme)

Sorun: menü/haber içeriği tarayıcıda API'den yüklenir; prerender yalnız kabuk yazar → JS çalıştırmayan botlar (Bing/Yandex/sosyal önizleme/yapay zekâ botları) boş görür. Çözüm (öneri A): `web/scripts/refresh-prerender.mjs`.

**Ne yapar.** Kendi API'mizden (`/api/menu/today`, `/api/menu`, `/api/news?size=20`; kaynak siteye ASLA istek yok) veriyi alır; her dilin `/menu` ve `/news` sayfasının `<noscript>` gövdesine bir blok yazar: bugünün menüsü (yemek + kcal + toplam), ayın menü tablosu, son 20 haber/duyuru **başlığı** (yalnız kaynağa bağlantı + tarih; özet/görsel kopyalanmaz, telif için), "Son güncelleme" damgası. Sitemap'te yalnız verisi değişen sayfaların `lastmod`'unu o güne çeker. Tekrar çalıştırılabilir (blok `<!--dyn:start hash=…-->` işaretli; veri aynıysa hiçbir şey değişmez). API/web ulaşılamazsa çıkış kodu 2, hiçbir dosyaya dokunulmaz (eski içerik sunulur). Tarayıcıda JS açıkken `noscript` görünmez; istemci yine API'den günceli çizer (hidrasyon uyumu sorunu yok: kök mevcut içeriği değiştirir).

**Mimari (web konteyneri `read_only` olduğu için `docker cp` çalışmaz).** Betik sonucu adlandırılmış volume'a (`bu_webdyn`) yazar; web konteyneri onu `/var/lib/bu-dyn` altında salt okunur okur. Dizin adı **derleme kimliğidir** (`dist/build-id.txt`, nginx'e `set $dyn_root /var/lib/bu-dyn/<kimlik>` olarak gömülür): yeni dağıtımda kimlik değişir, eski katman kendiliğinden kullanılmaz (eski HTML'in silinmiş hash'li varlıklara bağlanması imkânsız) ve betik eski dizinleri siler. Katman yoksa nginx derleme çıktısını sunar. Volume tanımı `deploy/compose.bukampus.yml` içindedir (deploy betiği değişmedi; bir sonraki dağıtımda oluşur).

**Çalıştırma (sunucuda; sizin yapacağınız).** Betik sürüm dizinindedir (`/opt/bukampus/current/web/scripts/refresh-prerender.mjs`). Elle:

```
docker run --rm --network bu_edge \
  -v bu_webdyn:/out \
  -v /opt/bukampus/current/web/scripts/refresh-prerender.mjs:/app/refresh.mjs:ro \
  node:22-alpine node /app/refresh.mjs \
  --base http://web:80 --api http://backend:8080 --out /out --origin https://bukampus.com.tr
```

Beklenen çıktı: `refresh-prerender: tr/menu güncellendi …` ya da `veri değişmedi`. Doğrulama: `curl -s https://bukampus.com.tr/tr/menu | grep "Bugünün yemek listesi"` (JS'siz görünüm).

Zamanlama (systemd; yeni iki dosya, **henüz eklenmedi**; deploy betiğine dokunulmadı): `/etc/systemd/system/bu-seo-refresh.service` (`Type=oneshot`, `User=deploy`, `SupplementaryGroups=docker`, `ExecStart=` yukarıdaki komut, `TimeoutStartSec=5min`) ve `bu-seo-refresh.timer` (`OnCalendar=*-*-* 00:15:00 Europe/Istanbul` — haber senkronu 00:00, menü ayın son günü 23:30'dan sonra; `Persistent=true`). Her dağıtımdan sonra bir kez de çalıştırın (yeni kimlik boş katmanla başlar; çalışana dek derleme çıktısı sunulur, bozulma olmaz). Cron kullanacaksanız aynı komut `15 0 * * *` (TZ=Europe/Istanbul).

**Henüz yok:** aylık arşiv `/menu/YYYY-MM` (SEO.md P1): yeni SPA rotası + prerender yolu + `routeMeta` satırı gerektirir (sayfa bileşeni işi); API `GET /api/menu?month=YYYY-MM` hazır. Günlük URL (`/menu/2026-11-03`) üretilmez (ince içerik).

## 7. Uygulama bağlantısı doğrulama dosyaları (App Links / Universal Links)

**Güncel yöntem (SH, paylaşım bağlantıları `/s/*`):** dosyalar elle değil, web imajı derlenirken `web/scripts/gen-app-links.mjs` ile `APPLE_TEAM_ID` / `PLAY_APP_SIGNING_SHA256` değerlerinden üretilir (değer yoksa üretilmez, 404 kalır); yollar yalnız `/s/*`. Adımlar: [DEPLOY.md §8.2](DEPLOY.md), sözleşme: [SHARING.md](SHARING.md). Aşağıdaki elle yöntem yedektir (örnek `/*/news/*` yolu artık kullanılmaz).

nginx hazır (bölüm 1); **dosyaları uydurmadık** (parmak izi/Team ID kullanıcıdadır). Değerleri verince:

1. **Android** — Play Console → *Uygulama bütünlüğü → Play Uygulama İmzalama* → **SHA-256 sertifika parmak izi** (yükleme anahtarının DEĞİL, Play'in uygulama imzalama anahtarının). Paket: `tr.com.bukampus.app`. Dosyayı oluşturun: `web/public/.well-known/assetlinks.json`
   ```json
   [{"relation":["delegate_permission/common.handle_all_urls"],
     "target":{"namespace":"android_app","package_name":"tr.com.bukampus.app",
               "sha256_cert_fingerprints":["AA:BB:…"]}}]
   ```
   Android manifest'e `android:autoVerify="true"` ile `https://bukampus.com.tr` `intent-filter` (uygulama işi). Test: `https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://bukampus.com.tr&relation=delegate_permission/common.handle_all_urls`.
2. **iOS** — Apple Developer → *Membership* → **Team ID**; bundle `tr.com.bukampus.app`. Dosya, **uzantısız**: `web/public/.well-known/apple-app-site-association`
   ```json
   {"applinks":{"details":[{"appIDs":["TEAMID.tr.com.bukampus.app"],"components":[{"/":"/*/news/*"}]}]}}
   ```
   (yollar uygulamanın açacağı sayfalarla eşleşmelidir). Xcode *Associated Domains*: `applinks:bukampus.com.tr`. Eski iOS için aynı içerik `/apple-app-site-association` adresinden de istenir (nginx konumu hazır; dosyayı `web/public/apple-app-site-association` olarak da koyun).
3. `npm run build` → Vite `public/` içeriğini `dist/`'e kopyalar; nginx dosyaları `application/json`, yönlendirmesiz, `Cache-Control: public, max-age=3600` ile sunar. Doğrulama: `curl -sI https://bukampus.com.tr/.well-known/assetlinks.json` → `200`, `content-type: application/json`; `npm run check:seo -- --live https://bukampus.com.tr` bunu da denetler.
4. Sitemap'e girmezler; `check:seo` içindeki "dist'te yok" bağlantı denetiminden etkilenmezler.

## 8. check-seo (`npm run check:seo`)

`dist/` üzerinde, bağımlılıksız, katı. `npm run build && npm run check:seo`. Çıkış kodu 1 = hata. `--strict` uyarıları da hata sayar (birleştirme sonrası/yayın kapısı: `npm run check:seo:strict`). `--dist`, `--origin` seçenekleri; `VITE_ADMIN_PATH` ortam değişkeni gizli yönetim yolunun robots'ta sızmadığını denetler.

| Alan | Denetlenen (hata = H, uyarı = U) |
|---|---|
| title | tek ve boş değil (H); ≤70 karakter (U); dil içinde yinelenmez (H) |
| description | tek, boş değil (H); 50–175 karakter (U); dil içinde yinelenmez (H) |
| canonical | indekslenebilir sayfada tek (H); mutlak https, sorgu/parça/sonda `/`/büyük harf yok (H); kendisi ya da var olan indekslenebilir sayfa (H); kökün canonical'ı `/tr` (H) |
| robots meta | birden çok çelişen yönerge yok (H) |
| hreflang | kendine gönderme, `x-default`, geçerli kod, hedef sayfa var + indekslenebilir + doğru dilde, **karşılıklılık** (H); `noindex` sayfada hreflang yok (H) |
| dil | `<html lang>` klasörle uyumlu, Arapça `rtl` (H) |
| içerik | tek `<h1>` (404'te ≥1) (H); `<noscript>` var ve ≥120 karakter metin = JS'siz içerik (H) |
| OG/Twitter | og:title/description/url/image/type/locale, twitter:card (H); og:url = canonical; og:image dist'te var (H) |
| JSON-LD | geçerli JSON, `@context` schema.org, `http://` adres yok (H) |
| bağlantılar | iç bağlantı önrender sayfası/dinamik rota/dosya olmalı (H); sondaki `/`, büyük harf (H); `http://` karışık içerik (H) |
| sitemap | `loc` ↔ sayfa birebir: noindex/canonical dışı sayfa yok, indekslenebilir sayfa eksik yok (H); alternatifler = sayfa hreflang'ı (H); `lastmod` geçerli, gelecekte değil (H); hepsi aynı ve bugünden eski (U; bugünün tarihiyse site genelinde içerik bugün değişmiştir, meşru) |
| robots | `Sitemap:` mutlak (H); `*`, Googlebot, Bingbot için sayfalar/`/assets`/`/fonts`/`/og.png` açık (H); api/files/admin/ws/support-track kapalı (H) |
| kısmi yerelleşme | yerelleşmemiş dil sürümü canonical → tr değil ya da hreflang taşıyor; hreflang dilleri `PARTIAL_LANG_PATHS` ile uyuşmuyor (H) |
| diğer | 404.html noindex + h1 + canonical yok (H); security.txt yer tutucu; webmanifest simgeleri; yönetim nginx parçası üretilmiş (H) |

`--live <köken>`: yayındaki siteye ~25 `GET` (150 ms aralıkla) ile davranış denetimi: yönlendirmeler (`/tr/`, `/TR`, `/index.html`, `//`), 404'ler (`/zzz-yok`, `/.env`), `X-Robots-Tag` (admin/api/haber ayrıntısı/destek izleme), robots/sitemap tipi, www → apex, sitemap'ten 5 örnek adresin 200 + canonical eşleşmesi. Dağıtımdan sonra çalıştırın.

Testler: `src/seo/crawl.test.ts` (robots/sitemap/nginx kuralları ve check-seo'nun sentetik bozuk girdileri yakaladığı), `notFound.test.ts`, `seo.test.ts`.

### Dağıtım kapısı önerisi (deploy.sh DEĞİŞTİRİLMEDİ)
1. **CI** (web işi): `npm run lint && npm run typecheck && npx vitest run && npm run build && npm run check:bundle && npm run check:seo:strict`. Strict birleştirme sonrası 0 hata, 0 uyarı verir; CI'da bu kapı açıktır.
2. **deploy.sh**, `docker compose … up` sonrası (isteğe bağlı satır): `(cd web && node scripts/check-seo.mjs --live https://bukampus.com.tr) || echo "UYARI: SEO canlı denetimi başarısız"`; başarısızlık dağıtımı geri almasın (yalnız uyarı), çünkü ağ kaynaklı yanlış alarm mümkündür.
3. `build` sonrası `git diff --exit-code web/seo-lastmod.json` (CI): içerik değişti ama `seo-lastmod.json` commit edilmediyse uyarı.

## 9. Kullanıcının yapması gerekenler (dağıtım sonrası)

1. Dağıtın; ardından `node web/scripts/check-seo.mjs --live https://bukampus.com.tr` (GET, kibar) ve elle: `curl -sI https://bukampus.com.tr/zzz` → **404**, `…/tr/` → **301 /tr**, `…/admin/login` → `x-robots-tag: noindex…`.
2. **Gece yenilemesi**: bölüm 6'daki `docker run` komutunu bir kez çalıştırın, `curl -s https://bukampus.com.tr/tr/menu | grep "Bugünün yemek listesi"` ile görün; sonra systemd timer (00:15) ya da cron ekleyin. İlk dağıtımda `bu_webdyn` volume'unun oluştuğunu doğrulayın (`docker volume ls | grep webdyn`).
3. **Search Console**: *Alan* mülkü `bukampus.com.tr` (DNS TXT; bkz. SEO.md bölüm 8) → *Site haritaları* → `https://bukampus.com.tr/sitemap.xml` gönderin (**78 URL** beklenir; eski gönderim 81 idi: "keşfedilen URL" düşüşü beklenen ve doğrudur). Bing Webmaster: *Search Console'dan içe aktar*.
4. Search Console *URL denetimi*: `/tr/privacy/`, `/TR`, `/tr/zzz` → artık 301/301/404 (önbelleğe eski sonuç kalmışsa "yeniden dizine ekle" isteyin). *Sayfalar* raporunda "Soft 404" ve "Kopya, kullanıcı kanonik seçmedi" sayılarının 1-2 hafta içinde düştüğünü izleyin.
5. App Links için bölüm 7'deki parmak izi/Team ID'yi sağlayın (yoksa nginx 404 döner; zararsız).
6. Kararlar: (a) eğitim botlarının engeli (bölüm 2) uygun mu; (b) HSTS `preload` (bölüm 5); (c) haber ayrıntısının ileride dizine alınması (nginx `X-Robots-Tag: noindex, follow` satırı ve sayfa meta'sı birlikte değişmeli).
7. Sayfa metni değiştiren her commit'te `web/seo-lastmod.json` güncellemesini commit edin (bölüm 4.2).
8. `npm run check:seo:strict` temiz olmalı (0 hata, 0 uyarı); kısmi yerelleşme kuralı sayfa head'ine uygulanmıştır (bölüm 4.3).

## 10. Bilinen sınırlar

- Kök `/` istemci yönlendirmesi kullanır (JS'siz tarayıcı Türkçe ana sayfayı görür; canonical `/tr`). Sunucu tarafı dil yönlendirmesi bilerek yok.
- `/tr/legal/<TÜR>` büyük/küçük harf varyantları 200 kabuk verir (kanonik biçim küçük harf-tire; yönlendirme eklenmedi, trafik yok).
- Haber ayrıntısı JS'siz içerik sunmaz (kabuk); noindex olduğu için sorun değil.
- `refresh-prerender.mjs` yalnız `noscript` gövdesini yeniler; `<title>`/JSON-LD aynı kalır (menü/haber meta'sı sabit). Menü için `dateModified` JSON-LD'si 2. işe önerilir.
- `web/nginx-tls.conf.example` bu belgedeki kuralları taşımaz (örnek dosya); TLS'yi nginx'te sonlandıran kurulumda `nginx.conf` içeriği buna taşınmalıdır.
