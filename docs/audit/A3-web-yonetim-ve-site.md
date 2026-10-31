# A3 - Web denetimi: yönetim paneli + herkese açık tanıtım sitesi

Tarih: 2026-10-31 · Kapsam: `web/` (React + TS + Vite) · Kaynak: HEAD b405782 (statik) + A7 yalıtılmış yığını (`http://localhost:18190`, dinamik).
Üretim sunucusuna / canlı siteye hiçbir erişim yapılmadı. Kod değiştirilmedi. Ekran görüntüleri: `C:\bu_qa\shots\a3\` (repo dışı).

## 1. Kalite kapıları (gerçek sonuçlar)

| Kapı | Sonuç |
|---|---|
| `npm ci` | Tamam. `npm audit --omit=dev`: **0 zafiyet**. Uyarı: `esbuild` install-script `allowScripts` kapsamında değil (yalnız bilgi). |
| `npm run lint` | Temiz (0 uyarı/hata). |
| `npm run typecheck` | Temiz. |
| `npm test` | **100 dosya / 977 test geçti.** Süre 462 sn (makine yüklüyken; setup 294 sn, environment 682 sn kümülatif). Çıktıda ~336 satır React `act(...)` uyarısı (SiteLayout 65, MaintenanceNotice 18, HomePage/DownloadPage 6'şar...) - hata değil, test gürültüsü. |
| `npm run build` | Tamam (49 sn) + prerender: 81 sayfa + kök, sitemap.xml (81 `<loc>`), robots.txt. `dist/` içinde `.map` yok (sourcemap kapalı: iyi). |
| `npm run check:bundle` | **Bütçe tamam**: girdi JS 90.98/100 KB, en ağır site sayfası (ar) 126.87/135, toplam JS 641.7/680 KB (171 parça), CSS 6.1/10. Bütçeye yakın: `routes.admin` 15.28/16, `admin.tr` 62.72/66 (tüm panel sözlüğü tek parça), `vendor-react` 44.33/50. |
| `npm run check:contract` | 262 web çağrısı, 250 eşleşti, **0 eşleşmeyen**, 12 dinamik (atlandı). |
| `npm run check:i18n` | tr/en/ar anahtarları eşit. |
| E2E (Playwright `e2e/*.spec.ts`) | **Koşulmadı** (yoğun makinede süre/ortak tarayıcı; yerine aşağıdaki kendi dinamik gezintim yapıldı). |

En büyük 10 çıktı (ham KB): vendor-charts 423 (gzip 113), admin.tr 240 (64), vendor-react 142 (45), site.tr 59 / site.en 59 / site.ar 53, routes.admin 49, vendor-query 46, EventsAdminPage 43, vendor-router 40. Kullanılmayan bağımlılık görülmedi (5 çalışma zamanı bağımlılığı: react, react-dom, react-router-dom, @tanstack/react-query, recharts).

## 2. Dinamik gezinti özeti
- Yönetici (FULL) ile **52 panel rotası** 1280 px'te gezildi: hepsi yüklendi, **konsol hatası 0, API 4xx/5xx 0, ham çeviri anahtarı 0** (tek istisna A3-20). Bilinmeyen `/admin/xyz` doğru 404 sayfasını gösterir.
- 1024/768/390 px'te 32 rota: yatay taşma bulunanlar A3-01/02.
- Tanıtım sitesi: **24 rota x 3 dil x 2 genişlik (390/1280)** = 144 sayfa: konsol hatası 0, ağ hatası 0, ham anahtar 0, `<img>` alt eksikliği 0, Arapçada `dir=rtl lang=ar`, taşma 0, hreflang/canonical/og var. 404 sayfası `h1`siz (A3-12).
- RBAC: 4 profil (MODERATOR/EDITOR/SUPPORT/VIEWER, A14'ün test hesapları) ile 50 rota tarandı; uyumsuzluklar A3-03..06.
- Not: Ortak tarayıcının `localhost:18190` bağlantı havuzu sonradan doygunlaştı (diğer ajan sekmeleri; curl ile API 50 ms'de yanıt veriyordu). Bu yüzden "bozuk access + geçerli refresh", "çift geçersiz token", "yıkıcı diyalog (sebep zorunluluğu/Esc)" dinamik testleri **tamamlanamadı** (ürün hatası değil, ortam). Bu davranışlar `client.test.ts`/`guard.test.ts`/`GuardedAction` birim testleriyle kapsanıyor.

## 3. Bulgular

### ORTA

**A3-01 - Denetim kaydı sayfasında yatay sayfa taşması (1280 ve 768 px)**
- Rota: `/admin/audit` (`web/src/pages/admin/AuditPage.tsx` + `pages/admin/audit/*`).
- Belirti: 1280 px'te `scrollWidth` 1462 > 1265; 768 px'te 1327 > 753. Tablo kendi dikey kaydırıcısına sahipken sayfanın kendisi de yatay kayıyor; "Durum" sütunu kesiliyor. Uzun `POST /api/admin/academic/exams/999999999/publish` yolu satırı genişletiyor.
- Tekrar: yönetici ile `/admin/audit` aç, 1280 px. Ekran: `C:\bu_qa\shots\a3\admin-audit-1280.png`, `resp-768-audit.png`.
- Öneri: tablo sarmalayıcısına `overflow-x:auto; max-width:100%`, yol hücresine `overflow-wrap:anywhere`/`min-width:0`; üst grid çocuklarına `min-width:0`.

**A3-02 - 390 px'te yatay taşma: Mail kuyruğu, Roller, Erişim engelleri, Push altyapısı**
- Rotalar: `/admin/mail/queue` (sw 867), `/admin/roles` (705), `/admin/security/access-bans` (441, `_stats_` kartları 441 px'e uzuyor), `/admin/push/ops` (398, `DD`/`pill` uzun değer).
- Belirti: telefon genişliğinde sayfa yatay kayıyor, arama kutusu/kartlar kesiliyor (mail kuyruğunda arama alanı ekran dışına taşıyor).
- Ekran: `resp-390-mail_queue.png`, `resp-390-roles.png`, `resp-390-security_access-bans.png`, `resp-390-push_ops.png`.
- Öneri: sayfa seviyesinde `main{min-width:0}`, istatistik gridlerinde `grid-template-columns:repeat(auto-fit,minmax(min(100%,9rem),1fr))`, `dd{overflow-wrap:anywhere}`, rol matrisi ve kuyruk tablosu `overflow-x:auto` kabına.

**A3-03 - Akademik duyurular: menü izni ile backend izni uyumsuz (MODERATOR)**
- Dosya: `web/src/layouts/adminNav.ts` (`acdAnnouncements` -> `perm: 'content.read'`), backend `AdminPermissionPolicy`: `area("/api/admin/announcements(/.*)?", COMMS_READ, COMMS_ANNOUNCE)`.
- Belirti: MODERATOR (content.read var, comms.read yok) menüde "Bölüm duyuruları"nı görür, sayfa açılır, `GET /api/admin/announcements` **403** -> "Veriler yüklenemedi / Bu işlem için yetkiniz yok" hata kartı. Aynı sayfanın yazma düğmeleri (Duyuru ekle) comms.announce ister (F, E).
- Tekrar: `qa-a14-moderator@bingol.edu.tr` ile `/admin/academic/announcements`. Ekran: `rbac-moderator-academic_announcements.png` (yoksa `rbac-*` dosyaları).
- Öneri: nav `perm: 'comms.read'` yap (ve ekleme düğmesini `comms.announce` ile `GuardedAction permission` yap); sayfa/izin eşleşmesi için `adminNav` perm değerlerini `AdminPermissionPolicy` ile otomatik karşılaştıran bir test ekle (şu an yalnız tek yönlü kapsam testi var).

**A3-04 - Kullanıcı detayı: 403 "bağlantınızı kontrol edin" diye yanlış açıklanıyor (SUPPORT, VIEWER)**
- Rota: `/admin/users/:id`. SUPPORT: `GET /admin/users/2/devices` 403 + `GET /admin/audit?targetType=USER...` 403; VIEWER: `devices` 403.
- Belirti: "Denetim kaydı yüklenemedi - Bağlantınızı kontrol edip yeniden deneyin" (403, ağ hatası gibi anlatılıyor) ve cihaz sekmesinde "Veriler yüklenemedi". Yetkisiz bölümler hiç gösterilmemeli.
- Ekran: `rbac-support-users_2.png`.
- Öneri: audit/devices/sessions/push-devices bölümlerini `useCan('audit.read')` / `useCan('users.pii')` ile gizle; `adminError` 403 için "yetkiniz yok" mesajı versin (denetim paneli başka bir hata anahtarı kullanıyor olabilir).

**A3-05 - Raporlar: VIEWER için ilk rapor otomatik açılıp "yetkiniz yok" hatası, toplu seçim kutuları görünür**
- Rota: `/admin/reports`; `GET /api/admin/reports/{id}` backend'de `chat.read` ister (VIEWER'da yok), liste `moderation.read` (VIEWER'da var).
- Belirti: sayfa açılır açılmaz sağ panelde kırmızı "Veriler yüklenemedi - Bu işlem için yetkiniz yok"; satırlarda toplu işlem onay kutuları VIEWER'a da görünür.
- Ekran: `rbac-viewer-reports.png`.
- Öneri: detay sorgusunu `useCan('chat.read')` ile koşullandır; yoksa "Şikâyet ayrıntısı bu profilde gizli" bilgilendirmesi; seçim kutusu/BulkBar `moderation.write` yoksa gizli.

**A3-06 - İzin bilgisi gelmeden/izinsiz yere gereksiz istekler (403 gürültüsü)**
- `auth/permissions.tsx`: izin yüklenirken `can()` true döner; sayfalar bu sırada istek atar. Gözlem: MODERATOR ilk açılışta `/admin/campaigns/new` -> `POST push/audience-count` 403 ve "yetkiniz yok" uyarısı, ardından NoPermission sayfası; EDITOR genel bakış: `moderation/appeals`, `moderation/suspend-recommendations`, `audit` için 3 adet 403 (Dashboard bileşenleri izne bakmıyor; hata sessiz yutuluyor ama sunucu/denetim kaydı gürültüsü ve gecikme). SUPPORT/VIEWER `sources` sayfasında `system/overview` + `dead-letters` 403 (sessiz).
- Öneri: `RequirePerm` içinde izin `loading` iken çocukları render etme (spinner); Dashboard/Sources panellerini kendi izinleriyle (`moderation.read`, `audit.read`, `system.read`) koşullandır.

**A3-07 - [İSTEK / panel kapsam eksiği] Push cihaz teşhisi arayüzde yok**
- Backend (P1): `GET /api/admin/users/{id}/push-devices` artık `lastPushStatus`, `lastPushErrorCode`, `lastPushAt` döndürüyor (`AdminPushDeviceService`/`UserExtrasDtos.PushDeviceInfo`). Web: `api/adminUsers.ts` `PushDevice` tipinde bu alanlar **yok**, `pages/admin/users/PushDevicesTab.tsx` yalnız platform/sürüm/token sonu/son görülme gösteriyor (locale bile gösterilmiyor).
- Etki: "bana bildirim gelmiyor" şikâyetini destek ekibi panelden çözemez (UNREGISTERED, THIRD_PARTY_AUTH_ERROR vb. görünmez).
- Öneri: sekmede "Son push: başarılı/başarısız (kod) - zaman" sütunu + kod için Türkçe açıklama tablosu.

**A3-11 - Düzen kayması (CLS) kötü: FAQ ve Hukuki metinler (390 px)**
- Ölçüm (3 tekrar, Chromium): `/tr/faq` CLS **0.209** (kaynak `SECTION._group_*`), `/en/faq` 0.133, `/tr/legal` **0.176** (`ASIDE._box_*`). Eşik 0.1. Ana sayfa/Yardım/Haberler 0.
- Neden: veri (SSS/sözleşme listesi) gelince gövde yüksekliği değişiyor; prerender HTML'inde içerik yok ya da iskelet yüksekliği farklı.
- Öneri: iskelet/min-height ayır, prerender'a ilk SSS grubunu göm veya `content-visibility`/`aspect` ayrılmış alan kullan.

**A3-12 - Soft 404: bilinmeyen site yolları HTTP 200 dönüyor**
- `web/nginx.conf`: `location ~ ^/(tr|en|ar)(/|$)` -> `try_files ... /$1/index.html`; `/tr/zzz-not-found` -> **200**, `<link rel=canonical>` kendisi, `robots noindex` yalnız JS ile (`NotFoundPage` `usePageMeta noindex`), statik HTML'de yok. 404 sayfasında `h1` yok, `meta description` yok.
- Etki: arama motorlarında sahte sayfa indekslenebilir; izleme bağlantısı `/support/track` da yalnız istemci noindex.
- Öneri: prerender çıktısına `404.html` üret, nginx'te bilinen rota listesi (sitemap) dışında `error_page 404`; en azından `X-Robots-Tag: noindex` başlığı `/support/track` ve bilinmeyen yollara; 404 sayfasına `h1`.

### DÜŞÜK

**A3-13 - Yönetim kabuğu arama motoru/başlık hijyeni**
- `/admin/*` ilk HTML site SEO'sunu taşır (title "BÜ Kampüs · Kampüs hayatı tek uygulamada", og). `/admin/nonexistent-page` sekme başlığı site başlığı kalıyor (panelde başlık güncellenmiyor). `robots.txt` `Disallow: /admin` varsayılan yolu ilan eder (gizli `VITE_ADMIN_PATH` kullanılıyorsa bu satır yoktur: kod doğru), ayrıca `X-Robots-Tag: noindex` yok; robots.txt engeli URL'nin dizine girmesini önlemez.
- Öneri: nginx `location ^~ /admin { add_header X-Robots-Tag "noindex, nofollow" always; }` (gizli yol için `VITE_ADMIN_PATH` şablonu), panel 404'te başlığı ayarla.

**A3-14 - "Bağımsız uygulama / resmî değil" beyanı yalnız Çocuk güvenliği sayfasında**
- `i18n/*/child-safety.ts`: "üniversitenin resmî uygulaması değildir" yalnız orada. Ana sayfa, Hakkında, alt bilgi ve Özellikler'de yok. Site kopyası "resmî sitelerden derlenir" diyor (kaynak anlamında doğru), ama yasak "Resmi uygulama/üniversite logosu" iddiası bulunmadı: logo yalnız BÜ Kampüs markası; Marka sayfası "Bingöl Üniversitesi resmî logosu bu pakette yok" diyor.
- Öneri: alt bilgiye ve Hakkında'ya tek satırlık "BÜ Kampüs bağımsız bir öğrenci uygulamasıdır; Bingöl Üniversitesi'nin resmî uygulaması değildir" (3 dil).

**A3-15 - Sürüm notları / mağaza bağlantıları**
- `ChangelogPage`: yalnız "Ekim 2026" ve "Eylül 2026" statik girdiler; mobil `pubspec.yaml` 2.0.3+20003 ve yeniden tasarım sürümü yok, sayfada sürüm numarası hiç geçmiyor (2.0.2/2.0.3 tutarsızlığı oluşamıyor ama bilgi eksik). "Bu liste elle derlenir".
- `StoreButton`: mağaza bağlantısı `GET /api/app/info` `stores` alanından; QA yığınında boş olduğu için "Yakında" durumu görüldü (canlı Play/App Store bağlantısı doğrulanamadı). Kod içi not: resmî rozet SVG'leri yerine nötr düğme (marka kuralı gereği yayında değiştirilmeli).
- Öneri: yayın öncesi `app_setting` mağaza URL'lerini doldur, rozetleri değiştir, değişiklik günlüğüne 2.0.x girdisi ekle.

**A3-16 - Herkese açık iletişim ve KVKK veri sorumlusu e-postası kişisel Gmail**
- `backend/.../V481__legal_controller_settings.sql`: `support_email` ve `legal.controller.email` = `ysufakin23@gmail.com`; İletişim sayfasında ("Destek e-postası") ve sözleşme metinlerinde görünüyor. Kurumsal alan adı yerine kişisel hesap: sürdürülebilirlik/KVKK algısı sorunu.
- Öneri: `bukampus.com.tr` alan adlı bir adres tanımla (ayarlardan değiştirilebilir; yeni migration gerekmez).

**A3-17 - Herkese açık destek formunda erişilebilirlik küçük eksikleri**
- Akış çalışıyor (boş gönderimde alan hataları, 3,5 sn sonra gönderim 202, kod adımı; honeypot `website` gizli ve `tabIndex=-1`). Eksikler: form -> kod adımı geçişinde odak taşınmıyor/duyurulmuyor (yalnız "done" `role=status`); kod adımında "yeniden gönder" yok (geri dönüp yeniden gönderilmeli); kod doğrulama (hız sınırı 429) hata gövdesi dinamik doğrulanamadı.
- Ekran: `support-code-390.png` (tam sayfa görüntüde yapışkan başlık/çerez bandı artefaktı, hata değil).

**A3-18 - İstemci oturum davranışı**
- `api/client.ts`: refresh yanıtı **403** (örn. `ACCESS_BLOCKED`, geçici kural) oturumu bitirir ("401/403 = reddedildi"). `AuthProvider.verify`: ağ/5xx hatasında durum `anonymous` olur ve kullanıcı girişe atılır (token silinmese de geçici kesintide oturum kaybı hissi); yalnız kısa bir "bağlantı yok, yeniden dene" durumu olabilir.
- İyi: jetonlar yalnız `sessionStorage`, tek uçuşlu refresh, 429/5xx'te oturum bozulmuyor.

**A3-19 - Tanıtım sitesi dış bağlantı şema doğrulaması tutarsız**
- `layouts/SiteLayout.tsx:90` (`data.banner.url`), `pages/site/components/ContactList.tsx` (`info.website`, `info.social.*`), `pages/admin/NewsAdminPage.tsx:116` (`r.url`) doğrudan `href`'e basılıyor. `MarkdownText`, `NewsDetailPage` (`safeSourceUrl`), `OpsPage` (`safeHttpsUrl`) doğru süzüyor. Değerler yönetici/kaynak kaynaklı ve CSP `script-src 'self'` `javascript:` gezinmesini engeller; yine de derinlemesine savunma.
- Öneri: tek `safeHttpUrl()` yardımcı fonksiyonu kullan (yalnız `https:` / `mailto:`).

**A3-20 - Roller sayfasında ham izin anahtarı**
- `/admin/roles` metninde ham `admin.full` görünüyor (matristeki "yalnız FULL" izninin kimliği). Diğer ham anahtar yok. Öneri: Türkçe etiket ("Yalnız tam yetkili").

**A3-21 - Güvenlik başlıkları (nginx)**
- Doğrulandı: `Content-Security-Policy` (default-src 'self', frame-ancestors 'none', object-src 'none'), `X-Content-Type-Options`, `Referrer-Policy: strict-origin-when-cross-origin`, `X-Frame-Options: DENY`, `Permissions-Policy`, her location'da include. Eksik/zayıf: `style-src 'unsafe-inline'`; `connect-src ... ws: wss:` her kökene izin (yalnız `'self'` yeterli olabilir: nginx aynı kökenden WS vekiller); web konteyneri nginx'inde HSTS yok (üretimde Caddy ekliyor: `deploy/Caddyfile` `Strict-Transport-Security`; doğrudan `WEB_PORT` açılırsa yok); `/files/` yanıtlarına CSP `default-src 'self'` ekli (yüklenen SVG/HTML için iyi).
- XSS: `dangerouslySetInnerHTML`/`innerHTML`/`eval` kullanımı yok; `MarkdownText` yalnız http(s)/mailto/`/`/`#` bağlantılarına izin veriyor. Açık yönlendirme yok (`from` yalnız router state'i). Jeton URL'ye/konsola yazılmıyor. `npm audit` 0.

**A3-22 - Performans ölçümleri (tek örnek, yüklü makine, throttle yok; yalnız yön göstergesi)**
- Site (390 px): `/tr/` FCP/LCP 2.29 sn + TBT ~1.0 sn (soğuk ilk yükleme, 5 uzun görev), tekrarda `/ar/` 1.12 sn/TBT 0.2; `/tr/` 1280: LCP 1.66 sn/TBT 0.26; haberler 0.8 sn; CLS: ana sayfa 0 (FAQ/legal A3-11). Panel (1280): genel bakış LCP 0.32 sn, kullanıcılar 0.45 sn; yönetici sayfaları 2-14 sn'ye varan gezinti süreleri yük altında backend/DB gecikmesinden (`analytics` 14 sn, `campaigns/new` 31 sn, `appeals` 31 sn `networkidle` aşımı ilk koşuda; ikinci koşuda 2-3 sn) - makine 5+ ajanla paylaşımlı olduğu için ürün hızı olarak yorumlanamaz.
- Yapısal: `admin.tr` sözlüğü (62 KB gzip) panelin tüm sayfaları için tek parça (sayfa başına bölünse ilk açılış hafifler); `vendor-charts` 110 KB yalnız analitik/panel sayfalarında lazy ise sorun yok (doğrulanmadı); react-query `staleTime` 30 sn, `refetchOnWindowFocus:false`, 4xx'te yeniden deneme yok (doğru); `refetchInterval` yalnız canlı kampanya/kota/FCM gibi yerlerde. Büyük tablolar sunucu sayfalı (20 satır), sanallaştırma gerekmiyor.
- Öneri: Lighthouse'u CI'da throttle'lı (mobil profil) koş, ana sayfa için LCP/TBT bütçesi ekle.

### Panel kapsam isteği (backend'de var, panelde yok / kısmen)
- **A3-07** (yukarıda): push cihaz son sonucu.
- **A3-23 - Sistem sağlığı göstergeleri**: `FcmHealthIndicator.disabledReason` (`NO_CREDENTIALS|INIT_FAILED:<sınıf>`) ve `PushQueueHealthIndicator.errorCodes` (hata kodu başına sayaç) yalnız actuator health'te; `FcmTab` yalnız `FcmCheck.error` ham kodunu gösteriyor (Türkçe açıklama yok), `PushOpsPage` kuyruk istatistiklerinde `errorCodes` kırılımı/DEAD kayıtlarda "hata kodu gruplarına göre" süzgeç yok. İstek: Push altyapısı sayfasına "DEAD hata kodu dağılımı" kartı ve FCM kapalı nedeninin Türkçe açıklaması.
- **A3-24 - Kullanıcı detayında bildirim tercihleri (Anketler / Akademik duyurular)** görünmüyor; destek ekibi "bildirimi kapattı mı" bilemez. İstek: salt okunur tercih listesi (+ cihaz dili `locale`).
- **A3-25 - Sunucu okuma önbelleği (C1)**: panelde önbellek durumu/temizleme yok (`CACHE_ENABLED`, namespace sürümleri). İçerik düzeltmesi sonrası eski veri gösterilirse acil müdahale için "önbelleği geçersiz kıl" düğmesi (system.write) faydalı.
- Menü kalori düzenleme (`MenuAdminPage` + `menu/CalorieEditor`, `PUT /admin/menu/{date}/calories` ve toplu) panelde **var**.

## 4. Kapsam dışı / bakılamayan
- Koyu tema ekran görüntüleri ve klavye/odak/ekran okuyucu elle testleri alınmadı (yalnız `a11y.test.tsx` axe birim testi geçiyor); kontrast ölçülmedi.
- Yıkıcı onay diyaloglarının dinamik doğrulaması ve oturum süresi dolma akışı (bkz. 2. bölüm, ortam kısıtı).
- Playwright E2E paketi koşulmadı; Lighthouse otomasyonu (chrome-devtools) kullanılmadı, ölçümler PerformanceObserver ile.
- Canlı siteye/mağazalara erişim yok: Play/App Store bağlantıları, canlı HSTS/CSP, canlı sitemap doğrulanamadı.
- QA yığınında haber/menü/etkinlik verisi boş (INITIAL_FILL=false): tablo sıralama/uzun metin/CSV/boş-sonuç davranışları çoğu sayfada yalnız boş durum olarak görüldü.
