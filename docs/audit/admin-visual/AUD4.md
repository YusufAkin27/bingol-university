# AUD4: Yönetim paneli görsel/mobil/anlaşılırlık denetimi — Bildirimler + Sistem + Giriş + Kabuk

Denetleyen: AUD4 ajanı (salt okunur; kod DEĞİŞTİRİLMEDİ). Tarih: 2026-11-01. Etiket: AUD4.
Kapsam: menü grupları **Bildirimler** (Push kampanyaları + oluşturma, Mail şablonları, Mail kampanyaları, Mail kuyruğu, Mail engel/bastırma listesi, Push altyapısı) ve **Sistem** (Sistem durumu, Kaynaklar, Operasyon, Çökme raporları, Veri saklama, Uygulama güncelleme, Ayarlar, Roller/İzinler, Denetim kaydı, Mesaj erişimi, Şifreleme) + Giriş, Yönetici kayıt, 404 ve genel kabuk (AdminLayout, üst bar, yan menü, arama, kullanıcı menüsü).
Rota kaynağı: `web/src/layouts/adminNav.ts` + `web/src/routes.admin.tsx` (kapsamdaki 22 rota/ekran + ayrıntı rotaları `mail/templates/:id`, `mail/campaigns/:id`, `campaigns/new`).

## 0. Yöntem ve sınırlar

- **Taban çizgisi:** `git archive HEAD` (e9f171b6) ile `C:\bu_qa\aud4_snap2\web` kopyası; Vite portu **5204** (`--strictPort`). Paylaşılan çalışma ağacında diğer ajanlar (SEARCH/KIT) dosyaları düzenlerken ilk çekimlerim bozulduğu için (örn. `src/search/index.ts` dışa aktarımı eksikti → 1280/koyu çekimleri hata ekranı verdi) tüm çekimler bu **donmuş HEAD** kopyasından yeniden alındı. Yani aşağıdaki "önce" görüntüleri HEAD'in davranışıdır; çalışma ağacındaki yarım KIT/SEARCH işleri dahil değildir.
- **Backendsiz:** Playwright (`@playwright/test` chromium) ile `/api/**` taklidi. `web/e2e/mockPanel.ts` yalnız birkaç uç tanımladığı için kendi zengin taklidimi yazdım (repoya konmadı; dosyalar `…/scratchpad/aud4/mock.mjs`, `run.mjs`, `run2.mjs`). Her sayfa için üç durum: **dolu** (gerçekçi veri, uyarı/kritik/başarısız karışık), **boş** (sıfır/boş liste), **hata** (500; istemci 2 kez yeniden denediği için 4,5 sn beklenip çekildi).
- **Görüntüler:** `C:\bu_qa\shots\adminvisual\before\AUD4\<sayfa>-<durum>-<genişlik>-<tema>.png` — 19 sayfa × 3 durum × 3 genişlik (390x844, 768x1024, 1280x800) × 2 tema (açık/koyu) = **342 tam sayfa** + kabuk/giriş/kayıt/sekme/çekmece/diyalog ek çekimleri (toplam **544 dosya**). Örn. `system-full-390-light.png`, `shell-search-bakim-390-light.png`, `settings-tab-maintenance-390-light.png`, `push-ops-stats-390-light.png`.
- **Otomatik ölçüm** (her çekimde): sayfa düzeyi yatay taşma, <44 px dokunma hedefleri, WCAG kontrast (metin/arka plan, <4,5:1; büyük metin <3:1), en küçük yazı boyutu, konsol hataları.
- **Doğrulanamadı / sınırlar:** gerçek backend verisi ve gerçek cihaz (iOS Safari, Android Chrome gerçek dokunma) yok; ekran okuyucu ve klavye gezintisi elle denenmedi; RTL (Arapça) denenmedi (panel yalnız Türkçe kararı); crash çekmecesi, Güncelleme sihirbazı ve "Giriş yapılıyor…" durumu çekimde güvenilir açılmadı (aşağıda ilgili satırlarda "doğrulanamadı" yazıldı). Mock'ta tanımlamadığım uçlar (`/departments`, `POST /admin/push/audience-count`, `/admin/users/1`) kampanya oluşturma sayfasında 404 verdi; oradaki hata kutuları mock kaynaklı olabilir (6.2'de belirtildi).
- **Hatalı alarm ayıklama:** İlk taslakta "haber türü ham enum" ve "NO_CONSENT ham kod" bulgularını yazmıştım; gerçek backend kodları (`HABER/DUYURU/ETKINLIK`, `SUPPRESSED/INACTIVE/…`) çevrili olduğundan bunlar mock uydurmasıydı, rapordan çıkarıldı.

## Özet ölçümler

Sayfa düzeyi yatay taşma: **hiçbir sayfada, hiçbir genişlikte yok** (342/342 çekim; tablolar kendi kapsayıcılarında kaydırıyor). Asıl sorun taşma değil, **kaydırma içinde gizlenen bilgi/eylem**.
Kontrast (<4,5:1): yalnız **kampanya telefon önizlemesinde 3,79:1** (bildirim başlığı/gövdesi, açık+koyu). En küçük yazı: 11,5 px (önizleme uygulama adı), diğer her yerde ≥12,8 px.
390 px'te <44 px dokunma hedefi sayısı (dolu durum, açık tema; tüm sayfalarda ortak 3 tanesi kabuktandır: arama düğmesi 44x40, hesap menüsü 72x42, depolama bandı bağlantısı 191x24):

| Sayfa | <44 px hedef | Sayfa | <44 px hedef |
|---|---|---|---|
| Ayarlar | 18 | Çökme raporları | 7 |
| Mail kuyruğu | 13 | Veri saklama | 6 |
| Sistem durumu | 10 | Kaynak durumu | 5 |
| Yeni kampanya | 9 | Operasyon | 4 |
| Mail şablonları | 9 | Kampanyalar, Push altyapısı, Uygulama güncelleme, Şifreleme, 404 | 3 (yalnız kabuk) |
| Mail kampanyaları | 9 | Roller | 8 |
| Mesaj erişimi | 9 | Denetim kaydı | 7 |
| Mail engel listesi | 8 | | |

Neden: (1) `Button size="sm"` mobilde 40 px (`components/ui/Button.module.css:131-136`), (2) onay kutuları 13-18 px, (3) 36-42 px arama kutuları, (4) satır içi bağlantılar (24-26 px).

## Puan tablosu (1 kötü – 5 çok iyi)

| # | Sayfa | (a) mobil | (b) tasarım | (c) anlaşılırlık | (d) görselleştirme | Bulgu (K/Y/O/D) |
|---|---|---|---|---|---|---|
| 1 | Kabuk | 3 | 3 | 2 | 2 | 1/3/3/2 |
| 2 | Giriş | 5 | 4 | 4 | – | 0/0/1/2 |
| 3 | Yönetici kayıt | 4 | 3 | 4 | – | 0/0/1/2 |
| 4 | 404 | 5 | 3 | 2 | – | 0/0/1/0 |
| 5 | Push kampanyaları | 2 | 3 | 3 | 2 | 0/2/2/1 |
| 6 | Yeni kampanya | 3 | 3 | 4 | 3 | 0/2/2/1 |
| 7 | Mail şablonları | 3 | 3 | 4 | 2 | 0/1/3/1 |
| 8 | Mail kampanyaları | 3 | 3 | 3 | 3 | 0/1/2/2 |
| 9 | Mail kuyruğu | 2 | 3 | 2 | 3 | 0/3/2/2 |
| 10 | Mail engel listesi | 3 | 3 | 3 | 2 | 0/2/1/1 |
| 11 | Push altyapısı | 3 | 3 | 3 | 4 | 0/2/3/0 |
| 12 | Sistem durumu | 3 | 3 | **1** | 1 | 2/3/4/0 |
| 13 | Kaynak durumu | 4 | 3 | 3 | 2 | 0/1/2/2 |
| 14 | Operasyon | 3 | 3 | 2 | 1 | 0/3/2/2 |
| 15 | Çökme raporları | 3 | 3 | 3 | 2 | 0/2/5/0 |
| 16 | Veri saklama | 3 | 4 | 3 | 4 | 0/2/3/1 |
| 17 | Uygulama güncelleme | 4 | 3 | 4 | 3 | 0/0/3/2 |
| 18 | Ayarlar | 3 | 3 | 3 | 2 | 0/2/3/2 |
| 19 | Roller ve izinler | 2 | 3 | 2 | 2 | 0/2/2/1 |
| 20 | Denetim kaydı | 2 | 3 | 2 | 1 | 0/2/3/1 |
| 21 | Mesaj erişimi | 2 | 3 | 3 | 1 | 0/1/2/1 |
| 22 | Şifreleme | 4 | 3 | 1 | 2 | 0/2/1/1 |

(K = KRİTİK, Y = YÜKSEK, O = ORTA, D = DÜŞÜK. Sayılar rapor sonundaki dağılımla aynıdır.)

---

# BÖLÜM A — Ortak (sayfalar arası) bulgular

Bunlar tek tek sayfa ajanlarının değil KIT/ortak katmanın işidir; sayfa ajanları kullanımını ekler.

| # | Önem | Bulgu | Kanıt | Çözüm (kim) | Boyut |
|---|---|---|---|---|---|
| G1 | YÜKSEK | **Tablo → kart yok.** Kapsamdaki 15 liste/tablo sayfasında hiçbir `Column` `card` ipucu taşımıyor; telefonda tüm tablolar yatay kaydırma: ilk 2 sütun görünür, kalan (çoğu kez "İşlem"/eylem düğmesi) gizli. Veri saklamada **Dışa aktar/Temizle** düğmeleri görünmüyor. | `campaigns-full-390-light.png`, `crashes-full-390-light.png`, `data-retention-full-390-light.png`, `audit-full-390-light.png`, `roles-full-390-light.png` | KIT `ResponsiveTable` (kart ipuçları öncelik 1-3 + eylem) → sayfa ajanları sütunlara `card:{priority,actions}` ekler. | L (KIT) + S/sayfa |
| G2 | YÜKSEK | **Süzgeç duvarı.** Denetim 8, Mesaj erişimi 7, Mail kuyruğu 5, Bastırma 5, Çökme 5, Push kuyruğu 5 süzgeç alanı telefonda tam genişlikte alt alta (400-520 px); asıl liste ekranın altında. | `audit-full-390-light.png`, `mail-queue-full-390-light.png`, `push-ops-queue-390-light.png` | KIT `FilterPanel`: "Süzgeçler (2)" katlanır çekmece + etkin süzgeç çipleri + tek tarih aralığı seçici. | M (KIT) |
| G3 | YÜKSEK | **Dokunma hedefi <44 px** (bkz. Özet ölçümler). | ölçüm tablosu | KIT: `Button sm` mobilde 44 px; `Checkbox` 24 px + 44 px etkin alan; `SearchInput` 44 px; satır içi bağlantılara dolgu. | S (KIT) |
| G4 | YÜKSEK | **Jargon ve tutarsız terim.** Aynı kavrama sayfaya göre farklı ad: "Ölü" (Sistem/Operasyon), "Vazgeçilen (DEAD)" (Push), "Başarısız (ölü)" (Mail kuyruğu), "Bastırma" (menü) ↔ "engel listesi" (kullanıcı dili). | `system-full-1280-light.png`, `push-ops-queue-390-light.png`, `mail-queue-full-390-light.png` | Tek sözlük (aşağıda "Sade dil sözlüğü"); i18n anahtarlarını `web/src/i18n/tr/admin-*.ts`'te topluca güncelle. | M |
| G5 | ORTA | **Hata durumu hep aynı:** "Veriler yüklenemedi — Sunucu bir hata verdi. Biraz sonra tekrar deneyin." Sayfada iki bölüm hata verince iki özdeş kutu (Sistem, Mail kuyruğu). Neyin yüklenemediği ve kullanıcının ne yapacağı yazmıyor; 403/ağ yok/zaman aşımı ayrımı yok. | `system-error-390-light.png`, `mail-queue-error-390-light.png`, `settings-error-390-light.png` | `ErrorState`'e `subject` ("Mail kuyruğu yüklenemedi") + neden ayrımı ("İnternet bağlantınızı kontrol edin" / "Bu sayfaya yetkiniz yok"); aynı sayfada tek özet. | S (KIT) |
| G6 | ORTA | **Boş durum çocuk dili:** Çökme "0" kutuları gri; "Uygulama hata vermedikçe liste boş kalır" süzgeç hatası gibi okunur. İyi örnek: Kampanyalar, Mail şablonları (eylem düğmesi var). | `crashes-empty-390-light.png`, `campaigns-empty-390-light.png` | "Her şey yolunda" tipi olumlu boş durum (süzgeçsizken) vs "Süzgece uyan kayıt yok" (süzgeçliyken). | S |
| G7 | ORTA | **Kalıcı bantlar** (bakım + depolama) mobilde ~%22 ekran. (Bkz. 1.2) | `campaigns-full-390-light.png` | Kabuk. | M |
| G8 | ORTA | **Sayı kutuları hizasız:** `StatCard` değerleri kutu içinde alta yaslı; etiket 1 satır/2 satır olunca aynı satırdaki değerler farklı yükseklikte ("Okunan 2.480" ↔ "Oluşturulan 5.400"; "Son 7 günde aktif 3.100" etiketten ~100 px uzakta). | `push-ops-stats-390-light.png`, `push-ops-devices-390-light.png` | KIT `StatCard`: etiket üstte, değer hemen altında (`align-content:start`), trend oku slotu. | S (KIT) |
| G9 | ORTA | **Renk anlamı ters:** ilerleme çubukları marka kırmızısı (`--primary`) — "Bitti %100" bile kırmızı; kırmızı = hata anlamıyla çelişir. | `mail-campaigns-full-390-light.png`, `mail-campaign-detail-390-light.png`; `mail/mail.module.css:27-32` | KIT `ProgressBar` tonları (info/success/warning/danger) — durumdan türet. | S (KIT) |
| G10 | ORTA | **Yinelenen/belirsiz simgeler** (bkz. 1.3): menüde aynı simge 3-4 farklı sayfada. | `shell-rail-768-light.png` | KIT `Icon` seti + `adminNav.ts` (SEARCH/shell ajanı). | M |
| G11 | DÜŞÜK | **Yükleniyor:** tek büyük gri kutu iskeleti (Sistem); çoğunda tablo iskeleti var. | `system-error-390-light.png` (4,5 sn'lik ara görüntü) | Sayfaya özgü iskelet (kart ızgarası). | S |
| G12 | ORTA | **Sekme durumu URL'de değil:** Ayarlar (`SettingsPage.tsx:58`), Operasyon (`OpsPage.tsx:469`), Sistem ölü kayıtlar (`SystemStatusPage.tsx:119`), Veri saklama geçmişi (`HistoryPanel.tsx:18`) sekmeleri `useState`; arama derin bağlantısı (`path#anchor`) sekmeyi açamaz. Push (`?tab=`) ve Kampanyalar (`?status=`) URL'de. | kaynak | Sekmeleri `?tab=` ile senkronla (arama sözleşmesi için ön koşul). | S/sayfa |

### Sade dil sözlüğü (öneri)

| Teknik terim (şimdi) | Önerilen sade ifade |
|---|---|
| Ölü kayıt / DEAD / Vazgeçilen | Gönderilemedi (defalarca denendi, vazgeçildi) |
| Kuyruk (outbox/queue) | Gönderim sırası ("sırada bekleyen") |
| En eski gecikme | En uzun bekleyen: 70 dk |
| Bastırma listesi | Mail gönderilmeyecek adresler (engel listesi) |
| Kimliksiz kod bütçesi | Üyeliksiz kişilere günlük kod hakkı |
| Redis | Hızlı önbellek |
| WebSocket oturumu | Şu an bağlı kullanıcı |
| Zamanlayıcı (cron/job) | Otomatik görev ("her gece 00:00'da çalışır") |
| FCM / APNs | Android bildirim servisi (Firebase) / Apple bildirim servisi |
| Token | Cihaz adresi |
| Makbuz / SHA-256 | Yedek dosyası kaydı / doğrulama parmak izi |
| VACUUM FULL | (gösterme; "disk alanı hemen boşalmayabilir" yeter) |
| Ana anahtar / veri anahtarı / yeniden sarma | Şifreleme anahtarı / eski anahtarla korunan kayıt / yeni anahtara geçirme |
| Çökme grubu / imza | Aynı hata (aynı hatayı yaşayanlar tek satırda) |
| Transcode | Video küçültme |
| Profil/RBAC | Yetki grubu |
| Tercihle atlandı | Bildirimi kapattığı için gitmedi |
| Idempotency/gerekçe | (gerekçe: "Neden yapıyorsunuz? (kayıt altına alınır)") |

---

# BÖLÜM B/C sayfa bulguları aşağıdadır (1-4 kabuk ve oturum, 5-11 Bildirimler, 12-22 Sistem)


## 1. Genel kabuk (AdminLayout, üst bar, yan menü, arama, kullanıcı menüsü, bantlar)

Dosyalar: `web/src/layouts/AdminLayout.tsx`, `AdminLayout.module.css`, `QuickNav.tsx`, `UserMenu.tsx`, `adminNav.ts`, `pages/admin/dataretention/StorageBanner.tsx`.
Puan: (a) mobil 3 · (b) tasarım 3 · (c) anlaşılırlık 2 · (d) görselleştirme 2 (ilgisiz: kabukta grafik yok; yalnız durum rozetleri fırsatı var)

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 1.1 | KRİTİK | Arama yalnız menü sayfa adlarını bulur. "bakım modu" yazınca "Eşleşen sayfa yok"; yan menü süzmesi de aynı ("Eşleşen menü öğesi yok"). Kullanıcının asıl isteği olan ayar/alan/eylem araması çalışmıyor. `QuickNav.tsx:21-28` yalnız `adminNav` etiketleri + grup adını `navMatches` ile süzer; `AdminLayout.tsx:130` aynı işlev. | `shell-search-bakim-390-light.png`, `shell-drawer-filter-bakim-390-light.png` | SEARCH ajanının motoru (web/src/search) QuickNav + menü süzmesinde ortak kullanılmalı; bu raporun "aranabilir öğe" listeleri (aşağıda her sayfada) dizin girdisi olarak alınmalı. Sonuç satırında: simge + başlık + yol (Sistem > Ayarlar > Bakım modu) + tür rozeti (Sayfa/Ayar/Eylem). | L |
| 1.2 | YÜKSEK | İki kalıcı bant (bakım bandı + depolama uyarısı) telefonda ~160-200 px yer kaplar (844 px ekranın ~%22'si) ve her sayfada, kapatılamaz. İlk ekranda sayfa başlığı güçlükle görünür. `AdminLayout.tsx:357-366`. | `campaigns-full-390-light.png` (tüm 390 çekimlerinde aynı) | Mobilde tek satır özet + "ayrıntı" düğmesi (daraltılabilir); depolama bandı oturum başına kapatılabilir (yalnız kritikte kalıcı); ya da bantları üst çubuğun altında yatay kaydırmasız tek satır rozet yap. | M |
| 1.3 | YÜKSEK | 720-1099 px (tablet dikey, 768) "rail" kipinde ~25 etiketsiz simge; birçoğu aynı simge: `shield` (Erişim engelleri, Roller, Mesaj erişimi, Şifreleme), `list` (Raporlar... Mail kuyruğu, Denetim), `eyeOff` (Kara liste, Gizlenenler, Argo), `bell` (Kampanyalar, Push altyapısı), `panel` (Operasyon, Veri saklama), `chart` hem Analitik hem **Sistem durumu**. Etiket yalnız `title` (dokunmatikte yok). Rail 72 px'i kalıcı olarak alıp içeriği 664 px'e sıkıştırır; Bildirimler ve Sistem grupları rail'de ilk ekranda görünmez (kaydırma gerekir). `adminNav.ts:134-156`. | `shell-rail-768-light.png`, `crashes-full-768-light.png` | 768'de rail yerine telefondaki gibi çekmece kullan (ya da rail'e grup başlığı kısaltması + her öğeye ayrı simge). Yinelenen simgeleri ayır: Sistem durumu = `activity/heart`, Şifreleme = `lock`, Roller = `key`, Mesaj erişimi = `eye`, Push altyapısı = `smartphone`. | M |
| 1.4 | YÜKSEK | Dokunma hedefleri <44 px: üst bardaki arama düğmesi 44x40, hesap menüsü 72x42; `min-height:40px` (`AdminLayout.module.css:383`), 44 px kuralı yalnız menü öğeleri/süzme kutusu/grup başlıkları için tanımlı (`:298-312`), üst çubuk düğmeleri kapsam dışı kalmış. | ölçüm (390 px, tüm sayfalarda aynı): `button._searchBtn 44x40`, `button._trigger 72x42` | Mobilde tüm üst bar öğeleri `min-height:44px`; arama düğmesi etiketli ("Ara") ya da 44x44 simge. | S |
| 1.5 | ORTA | Telefonda arama penceresi küçük, ortalanmış kutu (`Modal size="sm"`); klavye açılınca sonuç alanı daralır. Öneri/son aramalar yok; boş durumda ne yapılacağı yazmıyor. | `shell-search-open-390-light.png`, `shell-search-empty-390-light.png` | Mobilde tam ekran sayfa (üstte sabit arama kutusu, altında gruplu sonuçlar; boşken "Sık kullanılanlar": Bakım modu, Çökme raporları, Mail kuyruğu...). Boş sonuç: "Bulunamadı. Şunu deneyin: bakım, kota, yedek". | M |
| 1.6 | ORTA | Kullanıcı menüsünde rol etiketi her zaman "Yönetici" (`UserMenu.tsx`: `admin.layout.roleAdmin`); gerçek yetki profili (Tam yetkili / İzleyici...) gösterilmiyor. Menüde tema, ayarlar, "Yetkilerim" yok. | `shell-usermenu-390-light.png` | Profil adı + "Yetkilerim" bağlantısı (/admin/roles) ekle; salt okunur profilde üst barda "Salt okunur" rozeti (neden bazı düğmelerin pasif olduğunu çocuk bile anlar). `rbac/me` verisi mevcut. | S |
| 1.7 | ORTA | Gruplu menüde "Sistem" grubunda 11, "Bildirimler"de 6 öğe; mobilde uzun liste. Varsayılan açık grup yalnız "Genel bakış" + geçerli grup. Sık kullanılan kısa yol yok. | `shell-drawer-390-light.png` | Menü başında "Sık kullanılanlar / Son açılanlar" (localStorage, kişiye özel); "Sistem" grubu iki alt gruba (İzleme / Yönetim) bölünebilir. | M |
| 1.8 | DÜŞÜK | Üst çubukta başlık kırpılıyor ("Uygulama gün...", "Mesaj erişim k...", "Sohbetler ve ş...") ve sayfa başlığı hemen altında tekrar veriliyor; ayrıca menüdeki ad ile sayfa başlığı farklı ("Şifreleme" ↔ "Sohbetler ve şifreleme"). | `app-versions-full-390-light.png`, `crypto-full-390-light.png` | Mobilde üst çubukta yalnız geri/menü + kısa ad ya da sayfa başlığı; menü adı = sayfa başlığı. | S |
| 1.9 | DÜŞÜK | Çekmece koyu lacivert, ana içerik açık temada krem; sayfa-çekmece geçişinde kontrast tutarlı ama açık temada çekmece "ağır" görünür. | `shell-drawer-390-light.png` | Açık temada açık yüzeyli çekmece (token: `--surface`); tercih. | S |

Görselleştirme önerisi: Kabuğa "tek bakışta durum noktası": üst çubukta sağda küçük bir **trafik ışığı noktası** (yeşil/sarı/kırmızı + metin "Sistem: Sorun var"). Veri: `GET /admin/system/overview` → `overall` (zaten sistem sayfasında çekiliyor; kabukta ortak react-query anahtarı `qk.system.overview()` ile 60 sn'de bir). Dosya: `AdminLayout.tsx` `tools` bölümü (satır ~346). Yetki: yalnız `system.read` olanlara.

Aranabilir öğe listesi (kabuk): 
- Tema değiştir (açık/koyu) — eş anlamlı: koyu mod, gece modu, karanlık, tema — kısa yol: Eylem
- Çıkış yap — oturumu kapat, çıkış, logout
- Siteyi görüntüle — ana site, web sitesi
- Menüyü daralt/genişlet — kenar çubuğu, yan menü
- Sayfa ara (Ctrl K) — arama, bul, git
- Bakım bandı ("Bakım modu açık") → Sistem > Ayarlar > Bakım modu
- Depolama uyarısı bandı → Sistem > Veri saklama
- Yetkilerim (öneri) → Sistem > Roller ve izinler

---

## 2. Giriş sayfası (`/admin/login`) — `pages/admin/LoginPage.tsx`, `LoginPage.module.css`
Puan: (a) 5 · (b) 4 · (c) 4 · (d) –

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 2.1 | ORTA | Şifremi unuttum yolu yok (backend `forgot-password` akışı var; yönetici paneline bağlanmamış). Yanlış şifrede kullanıcı yalnız "E-posta veya şifre hatalı" görür, çıkış yolu yok. | `login-badcreds-390-light.png` | "Şifremi unuttum" bağlantısı (var olan mobil/site akışına) ya da "Yardım için sistem yöneticisine yazın" notu. Ürün kararı gerekir. | S |
| 2.2 | DÜŞÜK | Doğrulama hataları alan altında, güzel; ancak "Giriş yapılıyor…" sırasında düğme ve alanlar kilitli mi, çekimle doğrulanamadı. | `login-validation-390-light.png` | Elle kontrol. | S |
| 2.3 | DÜŞÜK | Koyu tema yalnız sağ üstteki düğmeyle; kart kontrastı yeterli. | `login-full-390-dark.png` | Değişiklik gerekmez. | – |

Aranabilir öğe: (oturum açılmadan arama yok) — yok.

## 3. Yönetici kayıt (`/admin/register`) — `pages/admin/AdminRegisterPage.tsx`
Puan: (a) 4 · (b) 3 · (c) 4 · (d) –

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 3.1 | ORTA | Koşullar onay kutusu ~20 px; hata metni ("Devam etmek için kabul etmelisiniz.") etiketin hemen altında sıkışık, aralıksız; satır, onay kutusu etiketi ile aynı blokta. | `register-validation-390-light.png` | Onay kutusu 24 px + satır yüksekliği 44 px dokunma alanı, hata metnine `margin-block-start`. | S |
| 3.2 | DÜŞÜK | Üç alan aynı anda "Bu alan zorunludur." gösteriyor (3 kez aynı cümle); ilk hataya odak/kaydırma yok. | aynı | Tek özet satırı ("3 alan eksik") + ilk alana odak. | S |
| 3.3 | DÜŞÜK | Şifre kuralı ("En az 12 karakter") alanın altında soluk gri; güç göstergesi yok. | aynı | Canlı kural listesi (12 karakter ✓). | S |

Aranabilir öğe: yok (oturum öncesi).

## 4. 404 sayfası (`/admin/<olmayan>`) — `pages/admin/AdminNotFoundPage.tsx`
Puan: (a) 5 · (b) 3 · (c) 2 · (d) –

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 4.1 | ORTA | Açıklama metni genel boş-durum metni: "Kayıt eklendiğinde burada görünecek." (404 için anlamsız); düğme yok. Üst çubukta başlık sadece "Yönetim". `AdminNotFoundPage.tsx:9-13` `EmptyState` varsayılan açıklama. | `notfound-full-390-light.png` | Metin: "Aradığınız sayfa bulunamadı. Adresi yanlış yazmış ya da yetkiniz olmayan bir sayfayı açmış olabilirsiniz." + "Genel bakışa dön" düğmesi + arama kutusu. | S |

Aranabilir öğe: —

# BÖLÜM B — Bildirimler grubu

## 5. Push kampanyaları (`/admin/campaigns`) — `pages/admin/CampaignsPage.tsx`, `campaigns/CampaignDrawer.tsx`
Puan: (a) 2 · (b) 3 · (c) 3 · (d) 2

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 5.1 | YÜKSEK | Altı sütunlu tablo telefonda yatay kaydırmalı: ilk ekranda yalnız Durum + İçerik; Alıcı, Zaman, Oluşturan görünmüyor, "daha fazlası var" ipucu yok. İçerik metni kesiliyor ("başlıyo"). Sütunlarda `card` ipucu yok (`CampaignsPage.tsx:55-98`). | `campaigns-full-390-light.png` | KIT `ResponsiveTable` (card ipuçları: öncelik 1 = başlık, 2 = durum + alıcı, 3 = zaman) ile kart görünümüne düşür; kartta "2.400 / 5.200 kişiye gitti" cümlesi. | M |
| 5.2 | YÜKSEK | Gönderimi süren kampanyada ilerleme görünmüyor: yalnız "2.400 / 5.200" ham sayı; yüzde ve "kaç dakikadır sürüyor" yok. Liste 5 sn'de bir yenileniyor ama görsel geri bildirim yok. | `campaigns-full-390-light.png`, `campaigns-drawer-390-light.png` | Satırda ince ilerleme çubuğu (veri: `recipientCount/audienceSize`), SENDING için hareketli nokta; tamamlananlarda "%96 ulaştı, %4 tercihle atlandı" tek cümle (veri: `skippedCount`). | S |
| 5.3 | ORTA | Durum sekmeleri 7 adet, yatay kaydırmalı ("Du..." yarım kesik); sayaç yok, hangisinde kaç kampanya olduğu belli değil. | `campaigns-full-390-light.png` | Tek seçimli rozet-çip + yanında sayı (backend sayı vermiyorsa yüklü sayfadan hesaplanabilir; kesin sayı için backend gerekir) ya da `Select`. | S |
| 5.4 | ORTA | Sayfa açıklaması yok (`PageHeader` ikinci satırı boş bırakılmış, `CampaignsPage.tsx:~100`); diğer sayfaların hepsinde var. "Başarısız" kampanyada hata kodu (ör. `FCM_DISABLED`) listede görünmüyor. | `campaigns-full-390-light.png` | "Kimlere, ne zaman ve kaç kişiye bildirim gönderdiğinizi buradan izlersiniz" + başarısız satırda "Neden: Push sağlayıcı (FCM) kapalı" (hata kodu çeviri tablosu `admin.p14.code.*` var). | S |
| 5.5 | DÜŞÜK | Boş durum iyi ("Kampanya yok" + "Yeni kampanya" düğmesi); hata durumu genel ("Sunucu bir hata verdi"). | `campaigns-empty-390-light.png`, `campaigns-error-390-light.png` | Hata metnine "Bildirim kampanyaları yüklenemedi" gibi konu ekle. | S |

Görselleştirme: (1) Satır içi mini ilerleme çubuğu (`StatusPill` + `ProgressBar`; KIT bileşeni) — `CampaignsPage.tsx` "recipients" sütunu. (2) Sayfa tepesinde 3 büyük sayı: "Bu hafta gönderilen / ulaşan kişi / bekleyen" (veri: yüklü sayfa; kesin toplam için backend). (3) Kampanya çekmecesinde "ulaştı / tercihle atlandı / kalan" halka (`DonutChart`; veri `recipientCount, skippedCount, audienceSize`) — `CampaignDrawer.tsx`.

Aranabilir öğeler (başlık · eş anlamlılar · kısa yol):
- Kampanyalar (sayfa) · push kampanyası, bildirim gönder, duyuru bildirimi · Bildirimler > Kampanyalar
- Yeni kampanya (eylem) · bildirim oluştur, push gönder · Bildirimler > Kampanyalar > Yeni
- Durum süzgeci: Tümü / Zamanlandı / Gönderiliyor / Gönderildi / İptal / Başarısız / Duraklatıldı (alan, 7 değer) · filtrele, durum
- Kampanya ayrıntı çekmecesi: Hedef kitle, Alıcı sayısı, Kitle büyüklüğü, Tercihle atlanan, Kaynak, Dokununca açılan yer, Planlanan zaman, Başlangıç/Bitiş, Oluşturan, İçerik (dillere göre)
- İptal et / Duraklat / Devam ettir (eylem, çekmece) · kampanyayı durdur
- Otomatik yenileme notu ("Gönderim sürüyor; liste 5 saniyede bir yenileniyor")

---

## 6. Yeni kampanya oluştur (`/admin/campaigns/new`) — `pages/admin/CampaignComposePage.tsx`, `campaigns/*`
Puan: (a) 3 · (b) 3 · (c) 4 · (d) 3

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 6.1 | YÜKSEK | Sayfa başlığının hemen altında "+ Yeni kampanya" düğmesi var ama bu düğme **taslağı sıfırlar** (`admin.campaigns.compose.reset`); sayfa zaten "Yeni kampanya oluştur". Yanlışlıkla basılabilir, adı yanıltıcı. | `campaign-new-full-390-light.png` | Etiket "Taslağı temizle" + onay penceresi (zaten var) + ikincil/soluk stil. | S |
| 6.2 | YÜKSEK | Kitle seçeneği 9 kutu alt alta (telefonda ~600 px); varsayılan "Yalnızca ben (deneme)" seçili iken altta boş bir hata kutusu (simge var, metin yok) ve "Aradığınız kayıt bulunamadı." uyarısı çıkıyor. Mock'ta kullanıcı araması (`/admin/users/{id}`) 404 döndüğü için olabilir; ancak **boş metinli hata kutusu** gerçek bir eksik (metinsiz `Callout`): dogrulanamadı, mock sınırlı. | `campaign-new-full-390-light.png` | Boş metinli callout asla çizilmesin; "Yalnızca ben" kitlesinde alıcı sayısı "1 kişi (siz)". Kitle seçimini 2 sütun çip/ select'e indir. | S |
| 6.3 | ORTA | 5 adım numaralı ama tek uzun sayfa; ilerleme/adım göstergesi yok, "Gözden geçir ve gönder" düğmesi sayfanın en altında; alıcı sayısı üstte görünmez. | `campaign-new-full-390-light.png` (3610 px yükseklik) | Yapışkan alt çubuk: "5.200 kişiye gidecek · [Gözden geçir]"; adımlar katlanır (accordion) ve tamamlananlar ✓ ile özetlenir. | M |
| 6.4 | ORTA | Dil sekmeleri ("Türkçe zorunlu ●", "English ○", "العربية") küçük, durum noktası yalnız renk (kırmızı/gri nokta; yalnız renge güvenme). Başlık/metin kutusu sayaçları var (iyi). | `campaign-new-full-390-light.png` | Sekme etiketine "dolu/boş" metni ya da ✓ simgesi. | S |
| 6.5 | DÜŞÜK | Telefon önizlemesi güzel ama koyu telefon + gradyan sabit renkli (token dışı olabilir); önizleme dil düğmeleri (TR/EN/AR) 36 px. | `campaign-new-full-390-light.png` | Dil düğmeleri 44 px; renkler token. Ölçüm: önizleme bildirim başlığı/metni 3,79:1 kontrast (< 4,5:1; açık+koyu temada, `phone.module.css` `_nTitle/_nBody`). | S |

Görselleştirme: Kitle seçildikçe "5.200 kişi → 4.800'ü bildirim almak istiyor" kutusu (halka: alacak / tercihle kapalı; veri `AudiencePreview.count / willReceive / optedOut`, zaten API'de; `AudiencePreviewPanel.tsx`) sayfa üstünde yapışkan.

Aranabilir öğeler: 
- Kime gidecek? (bölüm) · hedef kitle · Tüm kullanıcılar, Fakülte, Bölüm, Sınıf, Uygulama dili, Seçili kullanıcılar, E-posta/numara listesi, Yöneticiler, Yalnızca ben (deneme) — her biri ayrı alan/seçenek girdisi
- Alıcıları önizle (eylem) · kaç kişi alacak
- Ne yazacak? (bölüm) · Türkçe/İngilizce/Arapça başlık, metin · karakter sınırı 100/300
- Bildirim türü: Duyuru, Haber, Etkinlik, Sistem (tercihleri yok sayar!) 
- Dokununca ne açılsın? · hedef sayfa: Yok, Haber, Etkinlik, Topluluk, Destek talebi, Bağlantı (https)
- Ne zaman gitsin? · Hemen gönder, İleri tarihe zamanla · sessiz saatler
- Telefonda görünümü (önizleme) · Kendime test gönder (eylem) · Gözden geçir ve gönder (eylem)
- Taslağı temizle (eylem)

---

## 7. Mail şablonları (`/admin/mail/templates`, `/admin/mail/templates/:id`) — `pages/admin/MailTemplatesPage.tsx`, `mail/TemplateEditor.tsx`, `mail/TemplatePreview.tsx`
Puan: (a) 3 · (b) 3 · (c) 4 · (d) 2

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 7.1 | YÜKSEK | Liste telefonda Ad + Durum + Diller; Sürüm ve Güncellendi sütunları kayıyor. Satır adı dar sütunda 3-4 satıra kırılıyor ("Hos / geldin e- / postasi"). | `mail-templates-full-390-light.png` | Kart görünümü: ad (tam genişlik) + durum + "Güncellendi 5 saat önce" + dil çipleri. | M |
| 7.2 | ORTA | Dil çipleri `TR EN AR` içeriği olmayanlarda **üstü çizili** ve soluk (`opacity:.55` + `line-through`, `mail.module.css:10-13`); "çizili = yok" anlamı çocuk için belirsiz. | `mail-templates-full-390-light.png` | Üstü çizili yerine "AR yok" (soluk, açıklamalı `title`), ya da ✓ / ✗ simgesi. | S |
| 7.3 | ORTA | Durum süzgeci ile arama kutusu yan yana, "Durum" etiketi sağda üstte (hizasız): etiket yalnız Select'te, arama kutusunda yok. | `mail-templates-full-390-light.png` | İki alanın etiketleri aynı hizada ya da ikisi de etiketsiz + placeholder. | S |
| 7.4 | ORTA | Şablon düzenleyici (HTML + değişken `{{firstName}}` gibi) çocuk için teknik; "HTML içerik" metin kutusu, değişken yer tutucuları. Önizleme ayrı bölüm. | `mail-template-edit-390-light.png` | "Yazı yazma" kipi (zengin metin) + "Gelişmiş: HTML" katlanır; değişkenler tıklanabilir "Ad ekle" düğmeleri (veri `MailVariables` API'de var). | L |
| 7.5 | DÜŞÜK | Boş durum ("Henüz şablon yok" + yönlendirme) iyi; hata durumu genel. | `mail-templates-empty-390-light.png`, `-error-` | Hata metnine konu. | S |

Görselleştirme: Liste başında "3 şablon: 1 yayında · 1 taslak · 1 arşiv" üç parçalı çubuk (veri: yüklü sayfa); düzenleyicide dil tamamlanma noktaları 3/3.

Aranabilir öğeler: Mail şablonları (sayfa) · e-posta şablonu, mail metni · Yeni şablon (eylem) · Şablon adında ara (alan) · Durum: Taslak/Yayında/Arşiv · Şablon düzenleyici: Şablon adı, Açıklama, Konu, HTML içerik, dil sekmeleri (Türkçe/English/العربية), Değişkenler, Önizleme, Test gönder (eylem), Yayınla, Arşivle, Sürüm geçmişi.

---

## 8. Mail kampanyaları (`/admin/mail/campaigns`, `/:id`) — `pages/admin/MailCampaignsPage.tsx`, `mail/CampaignWizard.tsx`, `mail/CampaignDetail.tsx`
Puan: (a) 3 · (b) 3 · (c) 3 · (d) 3

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 8.1 | YÜKSEK | İlerleme çubuğu **kırmızı** (marka rengi) — kırmızı hata/tehlike anlamı taşırken "Bitti %100" bile kırmızı çubuk; "Hata" satırında çubuk gri. Renk anlamı ters. `MailParts.tsx` ilerleme çubuğu. | `mail-campaigns-full-390-light.png`, `mail-campaign-detail-390-light.png` | Devam eden = mavi/nötr, bitti = yeşil, hata = kırmızı (token `--info/--success/--danger`). | S |
| 8.2 | ORTA | Liste: İlerleme sütunu kırpılıyor ("3.200 / 5.00"), Kitle ve Zaman sütunları görünmüyor. | `mail-campaigns-full-390-light.png` | Kart görünümü + "3.200 / 5.000 gitti". | M |
| 8.3 | ORTA | Ayrıntı: 6 özdeş sayı kutusu (Hedef/Bekleyen/Kuyruğa alınan/Atlanan/Hatalı/İptal) + çubuk. Altı kutu telefonda 600 px yer kaplar; dağılım tek bakışta okunmuyor. "Kuyruğa alınan, e-posta kuyruğuna yazılan demektir..." jargon. | `mail-campaign-detail-390-light.png` | Yığılmış tek çubuk/halka (gitti / bekliyor / atlandı / hata) + yalnız sıfırdan farklı kutular; cümle: "5.000 kişiden 3.200'üne gönderildi, 1.800'ü sırada bekliyor, 43'ü gönderilemedi". | M |
| 8.4 | DÜŞÜK | "Atlanma sebepleri" ve "Dil dağılımı" düz sayı listeleri; oranlar görünmüyor. (Not: çevirisi olmayan atlanma kodu ham metin görünür; gerçek kodlar `admin.mail.skip.*` ile çevrili, mock'ta uydurma kod kullandığım için bunu hata saymadım.) | `mail-campaign-detail-390-light.png` | Dil dağılımı iki dilimli halka/çubuk, atlanma sebepleri yüzdeli yatay çubuk. | S |
| 8.5 | DÜŞÜK | Duraklat/İptal et düğmeleri yan yana, boşluk dar; iptal kırmızı dolgulu (doğru ama yanlışlıkla dokunma riski). | `mail-campaign-detail-390-light.png` | İptal'i ikincil kırmızı çerçeve + onay (zaten gerekçe diyaloğu var). | S |

Görselleştirme: Detay sayfası: "Gönderim hunisi" (`FunnelChart`: hedef 5.000 → sıraya alındı 3.200 → atlandı 40 → hata 3; veri `counters`). Liste: satır içi çubuk.

Aranabilir öğeler: Mail kampanyaları (sayfa) · toplu e-posta, duyuru maili · Yeni kampanya (eylem; sihirbaz: ad, şablon seçimi, kitle [Herkes/Süzgeç/Kullanıcılar/E-postalar], zamanlama) · Kampanya adında ara · Durum süzgeci (Taslak/Zamanlandı/Gönderiliyor/Duraklatıldı/Bitti/İptal/Hata) · Detay: İlerleme, Duraklat, Devam, İptal et, Alıcılar tablosu + durum süzgeci, Dil dağılımı, Atlanma sebepleri.

---

## 9. Mail kuyruğu (`/admin/mail/queue`) — `pages/admin/MailQueuePage.tsx`, `mail/MailQuotaCard.tsx`
Puan: (a) 2 · (b) 3 · (c) 2 · (d) 3

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 9.1 | YÜKSEK | Telefonda 5 süzgeç alanı tam genişlikte alt alta (Durum, Şablon, Tür, Başlangıç, Bitiş) ≈ 500 px; tablo ilk ekranda görünmez. | `mail-queue-full-390-light.png` | Süzgeçler "Süzgeçler (2)" katlanır paneli; tarih aralığı tek `DateRangePicker` (KIT'te var). | M |
| 9.2 | YÜKSEK | Tablo telefonda yatay kaydırmalı; "Son hata" sütununda uzun hata metni (SocketTimeoutException... smtp.example.invalid) dar sütunda karakter karakter sarılıyor, ilk satır ~350 px yükseklikte (1280 px'te bile). | `mail-queue-full-390-light.png`, `mail-queue-full-1280-light.png` | Hata metni 2 satır + "…" (`line-clamp`), tamamı çekmecede; bir sütunda `overflow-wrap:anywhere` yerine `max-width: 24ch`. | S |
| 9.3 | YÜKSEK | Jargon: "Kimliksiz kod bütçesi 33/100 (şifre sıfırlama sınırı 100)", "Başarısız (ölü)", "Yeniden denenecek", "Atlandı / iptal", "Duyuru için kalan 40 (işlemsel rezerv 50)", "Sayaç yalnız bugün ve dünü gösterir (Redis...)". Kota kartında 12 etiket-değer çifti. | `mail-queue-full-390-light.png` | Üstte tek cümle: "Bugün 500 postanın 410'unu kullandınız (%82). 90 posta hakkınız kaldı; duyurular için 40." Ayrıntı katlanır ("Ayrıntıları göster"). "Ölü" yerine "Gönderilemedi (vazgeçildi)". | M |
| 9.4 | ORTA | Kota kartında ilerleme çubuğu var (iyi), ama geçmiş günler (`history`, 6 gün) çizilmiyor, yalnız "Dün gönderilen 120". | `mail-queue-full-1280-light.png` | 6 günlük mini sütun/sparkline + kota çizgisi (veri `QuotaView.history`, dosya `MailQuotaCard.tsx:47`). | S |
| 9.5 | ORTA | Kuyruk durumu sayıları (Bekliyor 12, Yeniden denenecek 2, Başarısız 3, Atlandı 0) düz metin; "en eski bekleyen 08:52" saat; kaç dakikadır beklediği yok. | `mail-queue-full-390-light.png` | Dört parçalı durum çubuğu + "En eski posta 45 dk'dır bekliyor" (renk eşik: 10 dk uyarı, 30 dk kritik; eşikler sistem sayfasından). | S |
| 9.6 | DÜŞÜK | Arama kutusu 1280'de diğer süzgeçlerden dar, "Bitiş tarihi" tek başına ikinci satıra düşüyor (hizasız). | `mail-queue-full-1280-light.png` | CSS grid 5 eşit sütun / sar. | S |
| 9.7 | DÜŞÜK | Satır onay kutuları 13x13 (dokunma < 44). | ölçüm (390 px): `input[checkbox] 18x18` (mail kuyruğu seç-hepsi), 13x13 (Sistem > ölü kayıtlar) | Onay kutusunu 24 px + 44 px dokunma alanı (ortak `Checkbox` stili, KIT). | S |

Görselleştirme: (1) Kota **halkası** ya da yarım daire göstergesi (%82, renk eşikleri 80/95; veri `QuotaView.percent`, `level`). (2) 6 günlük çubuk (`history`). (3) Kuyruk durumunu yığılmış yatay çubuk (veri `queue`). Dosyalar: `mail/MailQuotaCard.tsx`, `MailQueuePage.tsx`.

Aranabilir öğeler: Mail kuyruğu (sayfa) · gönderilecek postalar, e-posta sırası · Günlük gönderim kotası (bölüm; eş anlamlı: mail limiti, kota doldu) · Kalan hak, Duyuru için kalan, Kimliksiz kod bütçesi, Bekliyor/Yeniden denenecek/Başarısız/Atlandı sayaçları · Arama (tam e-posta / @alan.adı / kayıt no) · Süzgeçler: Durum, Şablon, Tür, Başlangıç/Bitiş tarihi · Toplu: Yeniden dene, İptal et (eylem) · Ayrıntı çekmecesi (zaman çizelgesi, uyarılar, yeniden denenemiyor nedeni).

---

## 10. Mail engel listesi — "Bastırma listesi" (`/admin/mail/suppressions`) — `pages/admin/MailSuppressionPage.tsx`
Puan: (a) 3 · (b) 3 · (c) 3 · (d) 2

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 10.1 | YÜKSEK | Menüde "Bastırma listesi", sayfada "Mail bastırma listesi", kullanıcı isteğinde "Mail engel listesi": **"bastırma" jargon**; "Teslim hatası / Abonelikten çıktı / Şikayet / Elle eklendi" etiketleri iyi ama başlık anlaşılmaz. `admin-p13.ts: admin.p13.nav.suppressions`. | `mail-suppressions-full-390-light.png` | Ad: "Mail gönderilmeyecek adresler" (kısa: "Mail engel listesi"); eş anlamlı olarak "bastırma, engelli, abonelik iptali" aramaya girsin. | S |
| 10.2 | YÜKSEK | Telefonda 5 süzgeç alt alta (arama, sebep, tür, başlangıç, bitiş) ≈ 400 px; liste yalnız Adres + Sebep gösteriyor, tür/not/tarih sütunları kayıyor. | `mail-suppressions-full-390-light.png` | Katlanır süzgeç + kart görünümü. | M |
| 10.3 | ORTA | Adres alanında "Adres kayıtlı değil (özet 99aa88bb…)" — çocuk için anlamsız. | `mail-suppressions-full-390-light.png` | "Adres gösterilemiyor (güvenlik için saklanmıyor)" + ayrıntıda neden. | S |
| 10.4 | DÜŞÜK | Sebep dağılımı özet yok. | – | Üstte 4 renkli sayaç/halka: Teslim hatası x, Abonelikten çıkan y, Şikayet z, Elle w (yüklü sayfadan; kesin toplam için backend). | S |

Aranabilir öğeler: Mail engel listesi (sayfa) · bastırma, abonelikten çıkanlar, engellenen adresler · Adres ekle (eylem) · CSV indir (eylem) · Süzgeçler: Sebep (Teslim hatası, Abonelikten çıktı, Şikayet, Elle eklendi), Tür (İşlemsel/Duyuru), Tarih aralığı · Ayrıntı: Kullanıcı hesabı, Ekleyen yönetici · Listeden kaldır (eylem; gerekçe + kullanıcının kendi çıkışı için ek onay).

---

## 11. Push işlemleri / "Push altyapısı" (`/admin/push/ops?tab=fcm|queue|devices|stats`) — `pages/admin/PushOpsPage.tsx`, `pushops/*`
Puan: (a) 3 · (b) 3 · (c) 3 · (d) 4 (donut/çubuk/çizgi var)

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 11.1 | YÜKSEK | FCM sekmesinde ilk bakışta "Kapalı" nedeni ham teknik metin: `INIT_FAILED:com.google.auth.oauth2.ServiceAccountCredentialsReadException` ve "(dosya/JSON bozuk...)", "docs/PUSH_SETUP.md" gibi geliştirici yolları yönetici panelinde; 4 paragraf. | `push-ops-full-390-light.png` | Üstte tek cümle + trafik ışığı: "Push bildirimleri şu an GİTMİYOR. Sebep: Firebase anahtarı yüklenemedi." Teknik ayrıntı "Ayrıntıları göster" altında; yönerge ("sunucu yöneticisine iletin"). | S |
| 11.2 | YÜKSEK | 4 sekme telefonda kayıyor ("Bildi..." yarım); sekme "Kuyruk" ve "FCM" jargon. Sayfa açıklaması 3 satır. | `push-ops-full-390-light.png` | Sekme adları: "Bağlantı", "Sıradaki bildirimler", "Cihazlar", "İstatistik". | S |
| 11.3 | ORTA | İstatistik sekmesi: 5 sayı kutusunda değerler farklı yüksekliklerde (alt hizalı: "Okunan 2.480" ile "Oluşturulan 5.400" aynı satırda farklı hizada); çizgi grafik güzel ama altında aynı veri 14 satırlık tablo (tarih 3 satıra sarılıyor) + tür dağılımı tablo. | `push-ops-stats-390-light.png` | Tablo "Tablo olarak göster" anahtarının arkasına; tür dağılımı yatay çubuk (`BarChart`), "Okunma oranı %46" halka; üstte yorum: "Son 14 günde 5.400 bildirim gönderildi, yarısından azı (%46) açıldı". | S |
| 11.4 | ORTA | Cihazlar sekmesi iyi (donut + sürüm çubuğu) fakat donut ve çubuğun altında aynı verinin tablosu tekrar; tile hizası aynı sorun ("3.100" etiketten çok uzakta). Donut renkleri 4 farklı ton, Web/Diğer dilimleri çok ince. | `push-ops-devices-390-light.png` | Tabloyu gizle/katla; stat tile `align-items:start`. | S |
| 11.5 | ORTA | Kuyruk sekmesi: DEAD/FAILED/PENDING/SENDING rozetleri ve `THIRD_PARTY_AUTH_ERROR` gibi hata kodları (çeviri tablosu `admin.p14.code.*` var). Toplu işlem 200 sınırı. | `push-ops-queue-390-light.png` | Üstte: "12 bekliyor · 2 gidiyor · 5 hata verdi · 3 vazgeçildi" çubuğu; "DEAD" yerine "Vazgeçildi". | S |

Görselleştirme: FCM sekmesinde trafik ışığı + "Son 24 saatte 18.400 bildirim gitti" (veri `outbox/stats.sentLast24h`); Kuyruk sekmesinde derinlik çubuğu (`pending/sending/failed/dead`) ve "en eski bekleyen 70 dk" (`oldestPendingAgeSeconds`). Dosyalar: `pushops/FcmTab.tsx`, `QueueTab.tsx`, `StatsTab.tsx`, `DevicesTab.tsx`.

Aranabilir öğeler: Push altyapısı (sayfa) · bildirim altyapısı, firebase · FCM durumu (sekme): Bağlantıyı doğrula (eylem, dakikada 5), FCM neden kapalı?, iOS push hazırlığı (APNs, plist) · Kuyruk (sekme): durum/tür/kampanya/tarih süzgeçleri, Yeniden dene, İptal et, Toplu işlem · Cihazlar: Platform dağılımı, Uygulama sürümleri, 30 gündür görülmeyen cihazlar · Bildirim istatistikleri: Okunma oranı, Türe göre dağılım, Son 14 gün · Kampanya hata özeti.

# BÖLÜM C — Sistem grubu

## 12. Sistem durumu (`/admin/system`) — `pages/admin/SystemStatusPage.tsx`, `SystemStatusPage.module.css`, `api/system.ts`
Puan: (a) 3 · (b) 3 · (c) **1** · (d) 1

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 12.1 | KRİTİK | "Her şey yolunda mı?" sorusuna tek bakışta cevap yok. Üstte yalnız küçük "Genel durum: ✕ Kritik" rozeti + "Kritik durumda 1 gösterge var. Aşağıdaki kırmızı kartlara bakın." Sorunlu gösterge 25 kartın içinde aranır (telefonda sayfa 6000 px). `SystemStatusPage.tsx:313-324`. | `system-full-390-light.png` | Üstte büyük **trafik ışığı kahramanı**: 🟢 "Her şey yolunda" / 🟡 "Dikkat: 2 şey gözden geçirilmeli" / 🔴 "Sorun var: Push bildirimleri 70 dakikadır gecikiyor" (metin `indicator.message` zaten backend'den Türkçe geliyor). Renk + simge + metin. Sorunlu kartlar kahramanın hemen altında (tıklayınca kart açılır); "21 gösterge normal ✓" katlanır liste. | M |
| 12.2 | KRİTİK | Etiketsiz/ham göstergeler: `mail.dailyQuota`, `storage`, `jobs.storage-alert` kartlarında başlık **ham anahtar** (çeviri yok); değerleri birimsiz ("82", "83,4" — `%` yok). Çeviri `i18n/tr/admin-system.ts:25-49`'da yalnız 25 gösterge adı; backend `SystemOverviewService.java:134,167` ve iş listesi `:50` bu üç anahtarı üretir. `unitOf` (`api/system.ts:71-78`) bu anahtarları 'count' sayar. Ayrıca `*.error` (sorgu hatası) anahtarı da çevrisiz. | `system-full-390-light.png` ("mail.dailyQuota", "storage", "jobs.storage-alert") | Eksik 3-4 etiket + `unitOf`'a `mail.dailyQuota`/`storage` → percent. Ham anahtarı kullanıcıya asla göstermeme (bilinmeyen anahtar → "Diğer gösterge"). (Düzeltme KIT/sayfa ajanı kapsamında; dosya yalnız bu sayfaya ait.) | S |
| 12.3 | YÜKSEK | Nesne değerleri ham basılıyor: "SCHEDULED: 2 · SENDING: 1 · SENT: 40 · FAILED: 1" (kampanya sayıları), FCM için `delivered: … · lastFailureAt: 2026-…Z`. `formatValue` `SystemStatusPage.tsx:41-48`. | `system-full-390-light.png` | Kampanya sayıları = küçük yığılmış çubuk + "2 zamanlı, 1 gidiyor, 40 gitti, 1 hata"; FCM = "18.400 bildirim gitti, 12 hata (son hata 14 dk önce)". Durum adlarını `admin.campaigns.status.*` ile çevir. | S |
| 12.4 | YÜKSEK | Jargon ve eşik cümleleri: "Ölü kayıt", "Bekleyen", "En eski gecikme", "Uyarı: 1 · Kritik: 10" (hangi birim?), "Redis", "WebSocket oturumları", "Depolama diski doluluğu", "0 dk önce" (zamanlayıcılar), "Push sağlayıcı (FCM)". | `system-full-390-light.png` | Her kartın altında tek cümlelik açıklama: "Ölü kayıt = defalarca denendi, gönderilemedi (vazgeçildi)". Başlıklar: "Gönderilemeyen e-postalar", "Sırada bekleyen e-postalar", "Canlı bağlantı sayısı", "Önbellek (Redis) yanıt süresi", "Veritabanı yanıt süresi". Eşik: "10 dk'yı geçerse uyarı, 30 dk'yı geçerse kritik". | M |
| 12.5 | YÜKSEK | Sorunlu kart ile normal kart aynı boyut/ağırlıkta; kart ızgarası 25 kart; telefonda tek sütun ≈ 5000 px. Sol kenar rengi 4 px (ince). | `system-full-390-light.png`, `system-full-768-light.png` | Sıralama: Kritik → Uyarı → Bilinmiyor → Normal; normaller kompakt tek satır (ad + ✓ + değer). Telefonda 2 sütunlu mini kart. | M |
| 12.6 | ORTA | Sayısal göstergeler için ölçek yok: disk %83,4, yedek yaşı 6,5 sa, kuyruk gecikmesi 70 dk yalnızca büyük sayı; eşik (uyarı/kritik) ayrı soluk satırda. | `system-full-390-light.png` | Her kartta **eşikli çubuk** (bullet bar): değer işareti + sarı/kırmızı bölgeler (veri: `value`, `threshold.warn/crit` API'de var). Disk için halka. | M |
| 12.7 | ORTA | "Ölü (DEAD) kayıtlar" tablosu telefonda yatay kaydırmalı, onay kutuları 13x13, 4 düğme sıkışık ("Seçilenleri yeniden dene", "Tümünü yeniden dene", "Seçilenleri sil"). "DEAD" büyük harf jargon. | `system-full-390-light.png`, `system-dead-push-390-light.png` | Kart listesi; "Gönderilemeyen kayıtlar"; yıkıcı düğme ayrı. | M |
| 12.8 | ORTA | Disk ve depolama iki ayrı kart, aynı bilgi (83,4 ve 83,4); Veri saklama sayfasına bağlantı yok. | `system-full-390-light.png` | Tek "Disk doluluğu" kartı + "Veri saklama sayfasına git". | S |
| 12.9 | ORTA | Yükleniyor: tek büyük gri kutu (kart iskeleti yok); hata ve boş durum açık. | `system-error-390-light.png` | Skeleton kartları 3 grup başlığıyla. | S |

Görselleştirme (hepsi mevcut API verisiyle, dosya `SystemStatusPage.tsx` `IndicatorCard`):
- Trafik ışığı kahramanı: `overall` + sorunlu göstergelerin `message` alanı.
- Eşikli çubuk: tüm sayısal göstergeler (`value` + `threshold`); `disk.storage`, `storage`, `mail.dailyQuota` için **halka** (0-100).
- Kuyruk derinliği: `mail.pending / mail.dead`, `push.pending / push.dead` çubuğu; `*.oldestPendingAge` "70 dk'dır bekliyor" cümlesi.
- Zamanlayıcılar: 11 satır "son çalışma yaşı" zaman çizelgesi (her satır: ad · "10 dk önce" · eşik işaretli çubuk). Uyarı için `value` (saniye) ve `threshold.warn`.
- Sparkline için geçmiş veri YOK (sadece anlık): "backend gerekir" (`/admin/system/overview/history`).

Aranabilir öğeler: Sistem durumu (sayfa) · sağlık, her şey yolunda mı, sunucu durumu, izleme · Genel durum · Kuyruklar ve kampanyalar (bölüm): E-posta ölü kayıt, E-posta bekleyen, E-posta en eski gecikme, Günlük e-posta kotası, Push ölü kayıt/bekleyen/en eski gecikme, Kampanya geciken gönderim, Kampanya sayıları · Altyapı ve yedek (bölüm): WebSocket oturumları, Veritabanı yanıt süresi, Redis, Push sağlayıcı (FCM), Disk doluluğu, Depolama doluluğu, Son başarılı yedek · Zamanlayıcılar (bölüm): Haber senkronu, Yemek listesi senkronu, Mail kuyruğu işleyici, Push kuyruğu işleyici, Push kampanya dağıtıcı, Mail kampanya dağıtıcı, Mail temizliği, Push temizliği, Cihaz token temizliği, Bildirim saklama temizliği, Analitik saklama temizliği, Depolama uyarı işi · Şimdi yenile (eylem) · Ölü kayıtlar: E-posta/Push sekmeleri, Seçilenleri yeniden dene, Tümünü yeniden dene, Seçilenleri sil (eylem; eş anlamlı: başarısız postaları tekrar dene).

---

## 13. Kaynaklar / scraper — "Kaynak durumu" (`/admin/sources`) — `pages/admin/SourcesPage.tsx`, `bulk/bulk.module.css`
Puan: (a) 4 · (b) 3 · (c) 3 · (d) 2

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 13.1 | YÜKSEK | "Bakımda / Çalışıyor" rozeti jargon; "kaynak site yapısı değişti, eski veri sunuluyor" mesajı ham backend metni olarak etiket-değer listesinin ortasında. Çocuğa "ne yapmalıyım?" belirsiz. | `sources-full-390-dark.png` | Üstte tek cümle + ışık: "Haberler 12 saattir güncellenmedi. Üniversite sitesine ulaşılamıyor; eski haberler gösteriliyor. Yapmanız gereken bir şey yok / 'Şimdi dene' ile elle deneyebilirsiniz (saatte 3 hak)." | S |
| 13.2 | ORTA | 8 satırlık soluk etiket/değer listesi (`dl`), tarihler mutlak ("31 Eki 2026 21:38") — "ne kadar önce" yok; zamanlama beklentisi (gece 00:00 / ayda bir) yazmıyor. | `sources-full-390-dark.png` | "Son başarılı: 12 sa önce (beklenen: her gece)" + eşikli çubuk (haber 36 sa, yemek 35 gün; sistem eşikleriyle aynı). | S |
| 13.3 | ORTA | Haber türü dağılımı düz metin ("1.280 · Haber 600, Duyuru 500, Etkinlik 180"); gizlenen sayısı ayrı satır. | `sources-full-390-dark.png` | Yığılmış tek çubuk (haber/duyuru/etkinlik) + "Son 7 günde 34 yeni kayıt" büyük sayı (veri `itemsLast7d`, `total`, `hidden`, `byType`). | S |
| 13.4 | DÜŞÜK | "Şimdi senkronize et" düğmesi 40 px yükseklikte (<44); iki kart arasında düğme hizası farklı. | ölçüm: `button 40px` | 44 px. | S |
| 13.5 | DÜŞÜK | Üstteki sarı not iki paragraf, 8 satır (kural + limit); ilk ekranda içerikten önce. | `sources-full-390-dark.png` | Kartların altına ya da "Nasıl çalışır?" katlanır. | S |

Görselleştirme: (1) İki büyük "yaşı" göstergesi (halka: son başarılı senkron yaşı / beklenen sıklık). (2) Haber türü yığılmış çubuk. (3) Menü: "310 gün kayıtlı, 12 gün ileride (30 günden az → uyarı)" çubuğu (`upcomingDays`). Dosya: `SourcesPage.tsx:~100-150`.

Aranabilir öğeler: Kaynak durumu (sayfa) · scraper, haber çekme, senkron, kaynak site · Haber, duyuru ve etkinlik kaynağı (kart): Son başarılı senkron, Son deneme, Son mesaj, Son 7 günde çekilen, Toplam kayıt, Gizlenen · Yemek listesi kaynağı: Kayıtlı gün, Bugün ve sonrası, Fotoğraflı gün · Şimdi senkronize et (eylem ×2; gerekçe ister, saatte 3) · Scraper kuralı notu.

---

## 14. Operasyon (`/admin/ops`) — `pages/admin/OpsPage.tsx`
Puan: (a) 3 · (b) 3 · (c) 2 · (d) 1

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 14.1 | YÜKSEK | Sistem durumu sayfasıyla büyük ölçüde **tekrar** (kuyruklar, yedek, sağlık, kaynak): iki yerde farklı sayılar/adlar ("Ölü" / "Ölü kayıt", "Ölüleri yeniden dene" / "Seçilenleri yeniden dene"). Kullanıcı hangisine bakacağını bilemez. | `ops-full-390-light.png`, `system-full-390-light.png` | İki sayfayı tek "Sistem" sayfasında sekmelerle birleştir (Genel / Kuyruklar / Yedek / Sürüm-bakım / Dış bağlantılar) ya da Operasyon'u "Eylemler" sayfası yap, durum Sistem'de kalsın. Karar ürün sahibi. | L |
| 14.2 | YÜKSEK | Sağlık bileşenleri ham: `total=42949672960 · free=5000000000 · threshold=10485760 · path=/app/. · exists=true`, `validationQuery=isValid()`, `error=Connection refused`. Bayt cinsinden diskSpace. `OpsPage.tsx:133-139`. | `ops-full-390-light.png` | Bilinen bileşenler için cümle: "Disk: 5 GB boş (%12) — az kaldı" + çubuk; bilinmeyen detaylar "Teknik ayrıntı" katlanırı. Bileşen adları: db → "Veritabanı", redis → "Önbellek", mail → "E-posta sunucusu". | M |
| 14.3 | YÜKSEK | Süreler saniye olarak ham: "En eski bekleyen 4.200 sn", "180 sn" (`ageText` `OpsPage.tsx:213-217`, `admin.ops.q.oldestAge: '{n} sn'`). | `ops-tab-kuyruklar-390-light.png` | "70 dk" / "3 dk" biçimi (sistem sayfasındaki `toUnit` ile aynı). | S |
| 14.4 | ORTA | Sekmeler 5 (Sağlık, Kuyruklar, Yedekleme, Sürüm ve bakım, Dış bağlantılar); telefonda "Sürür" kesik. Kuyruk istatistikleri dikey `dl` listesi (6 satır × 3 kart), çubuk/oran yok. | `ops-tab-kuyruklar-390-light.png` | Kuyruk kartında yığılmış çubuk (bekleyen/gidiyor/başarısız/ölü) + "son 24 saatte 18.400 gitti". | M |
| 14.5 | ORTA | "Ölüleri yeniden dene" jargon. "Medya dönüştürme" (transcode) açıklaması yok. | `ops-tab-kuyruklar-390-light.png` | "Gönderilemeyenleri tekrar dene (3 kayıt)". Medya: "Yüklenen videoların küçültülmesi". | S |
| 14.6 | DÜŞÜK | "Son güncelleme" kart içinde 3 kez tekrar; sayfa üstünde de. | aynı | Tek yerde. | S |
| 14.7 | DÜŞÜK | Dış bağlantılar (Sentry, Grafana) sekmesi: https alanları + "Kaydet" her biri; mobilde alan altında düğme (sorunsuz). | `ops-tab-dbalantlar-390-light.png` | – | – |

Görselleştirme: Sağlık bileşenlerini 3 halka/ışık ("Veritabanı 🟢 7 ms, Önbellek 🟢 2 ms, Disk 🟡 %88 dolu"); yedek: "6 saat önce, 3,2 GB" + son 48 saat çizelgesi (tek veri noktası → çubuk eşikli). Dosyalar: `OpsPage.tsx` HealthTab, QueuesTab, BackupTab.

Aranabilir öğeler: Operasyon paneli (sayfa) · ops, sunucu sağlığı · Sağlık sekmesi: Bileşenler, Kaynak sistemler · Kuyruklar: E-posta kuyruğu, Push kuyruğu, Medya dönüştürme, Ölüleri yeniden dene (eylem ×2) · Yedekleme: Son başarılı yedek, Son deneme, Boyut · Sürüm ve bakım: Bakım modu durumu, En düşük/Güncel sürüm (Android, iOS), Ayarlarda düzenle (bağlantı) · Dış bağlantılar: Sentry (hata izleme), Grafana (metrikler), Kaydet · Şimdi yenile.

---

## 15. Çökme raporları (`/admin/crashes`) — `pages/admin/CrashesPage.tsx`, `crashes/crashes.module.css`
Puan: (a) 3 · (b) 3 · (c) 3 · (d) 2

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 15.1 | YÜKSEK | Tablo telefonda yatay kaydırmalı: yalnız Hata + Durum + "Rapor" yarı kesik; Sürümler, Görülme, İşlem görünmüyor. Hata satırında dosya yolu karakter karakter sarılıyor (`package:bu_kampus/features/menu/men u_page.dart:142`). | `crashes-full-390-light.png` | Kart görünümü: "RangeError — 241 kez, 2.0.5 sürümünde, 5 dk önce" tek cümle + durum rozeti + "İncele" (44 px). Yol `line-clamp` + tam yol çekmecede. | M |
| 15.2 | YÜKSEK | Sürüm çipleri şifreli: "2.0.5 · A · 200", "2.0.4 · i · 41" (A = Android, i = iOS) — 768 px'te ölçüldü; çocuk anlamaz. | `crashes-full-768-light.png` | "Android 2.0.5: 200 kez". | S |
| 15.3 | ORTA | 5 özet kutusu aynı biçimde (4 / 2 / 9 / 1 / 260) ama tıklanamaz ve renksiz; "Yeni 4" kutusu kırmızı olmalı. Trend yok ("dün 180 idi"). | `crashes-full-390-light.png` | Kutular durum süzgeci olur (tıklayınca liste süzülür), "Yeni" kırmızı vurgu; "Son 24 saatte 260 rapor" büyük sayı + dünle karşılaştırma ("backend gerekir": dün değeri API'de yok). | S |
| 15.4 | ORTA | Boş durum cümlesi süzgeç hatası gibi okunuyor ("Filtrelere uyan bir çökme grubu bulunamadı. Uygulama hata vermedikçe liste boş kalır."); hiç çökme yokken kutlama/güven mesajı yok; sıfır sayılar gri. | `crashes-empty-390-light.png` | "Harika: hiç çökme raporu yok 🎉" (süzgeç yoksa), süzgeçliyse "Süzgece uyan çökme yok". | S |
| 15.5 | ORTA | 5 süzgeç alanı (arama + durum + platform + sürüm + sıralama) telefonda alt alta (~330 px). | `crashes-full-390-light.png` | Katlanır süzgeç; durum çipleri. | S |
| 15.6 | ORTA | Jargon: "Çökme grubu", "imza", "yığın izi", "Yeniden açıldı (1)". | `admin-cr1.ts` | "Aynı hata" gruplama açıklaması başlıkta bir cümle ("Aynı hatayı yaşayan kullanıcılar tek satırda toplanır"). | S |
| 15.7 | ORTA | Dokunma: satır eylemleri/"Ayrıntı" düğmeleri. Çekmece davranışı (satıra dokununca) çekimde görüntülenemedi — dogrulanamadi. | `crashes-drawer-390-light.png` (açılmadı) | Elle kontrol. | – |

Görselleştirme: (1) "En çok çöken 5 hata" yatay çubuk (veri `eventCount`, liste `sort=count`) — sayfa tepesinde. (2) Sürüm başına çökme dağılımı (veri `versions[]`): hangi sürüm sorunlu → "2.0.5'te %83". (3) Zaman serisi sparkline/çubuk (24 saat/30 gün) **backend gerekir**: şu an `CrashSummary.events24h` tek sayı; detayda olay zamanları var (`events[].occurredAt`) ama liste için yok. Dosya: `CrashesPage.tsx:124-140`, `Stat` `:215`.

Aranabilir öğeler: Çökme raporları (sayfa) · uygulama çöktü, hata raporu, crash · Özet: Yeni, İncelemede, Çözüldü, Yeniden açılan, Son 24 saatte rapor · Süzgeçler: Ara (hata türü/kare/ileti), Durum (Yeni/İncelemede/Çözüldü), Platform (Android/iOS/Diğer), Sürüm, Sıralama (Son görülme/İlk görülme/Rapor sayısı) · Liste: Hata, Durum, Rapor, Sürümler, Görülme · Ayrıntı çekmecesi: Hata türü, İlk kare, İleti, Toplam rapor, Yığın izi, Durumu değiştir (gerekçe; Çözüldü → düzeltilen sürüm), Sil (gerekçe) · Anonimlik notu.

---

## 16. Veri saklama (`/admin/data-retention`) — `pages/admin/DataRetentionPage.tsx`, `dataretention/*`
Puan: (a) 3 · (b) 4 · (c) 3 · (d) 4 (sayfanın en iyisi)

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 16.1 | YÜKSEK | "Şişebilen log tabloları" tablosunda telefonda **eylem düğmeleri (Dışa aktar / Temizle) görünmüyor**: yalnız Tablo + Satır sütunu, kalan sütunlar yatay kaydırmada. Sayfanın asıl işi gizli. | `data-retention-full-390-light.png` | Kart görünümü: tablo adı (Türkçe etiket) + "14,2 milyon satır · 2 GB · en eski 7 ay önce" + [Dışa aktar] [Temizle] 44 px. | M |
| 16.2 | YÜKSEK | Jargon: "Şişebilen log tabloları", "makbuz", "SHA-256", "VACUUM FULL", "asgari saklama", "RUNNING/PARTIAL". Teknik tablo adları `analytics_event` mono olarak ana etiketin altında. | `data-retention-full-390-light.png`, `admin-ds1.ts:73,138` | Başlık: "Yer kaplayan kayıtlar (eski olanları temizleyebilirsiniz)". "Makbuz" → "Yedek dosyası kaydı". "VACUUM FULL" dipnota. | S |
| 16.3 | ORTA | En büyük tablolar düz metin (`ul`); boyut bilgisi yalnız rakam. | `data-retention-full-390-light.png` | Yatay çubuk (veri `database.topTables[].totalBytes`) + "Veritabanının %39'u tek tabloda". `StorageCards.tsx:68-77`. | S |
| 16.4 | ORTA | Geçmiş tablosunda tablo adı karakter karakter sarılıyor ("anal / ytic / s_ev / ent"), tarih aralığı 3 satır; sekme etiketi "Silme geçm..." kesik. | `data-retention-full-390-light.png` | Kart görünümü; `overflow-wrap:anywhere` yerine kısaltma. | S |
| 16.5 | ORTA | Disk kartları iyi (çubuk + %), ancak "Ölçülen/Kapasite ayarından hesaplanan" ayrımı çocuk için anlamsız; yenile düğmesi yalnız ↻ simgesi (etiketsiz). | `data-retention-full-390-light.png` | "Yaklaşık değer" rozeti + `aria-label`/metin. | S |
| 16.6 | DÜŞÜK | Silme önizlemesinde "bu işlem ~X GB boşaltır" tahmini sayfada yok (API `estimatedBytes` var: `PurgePreview`). | – | Diyalogda büyük sayı: "~410 MB boşalır". | S |

Görselleştirme: Mevcut çubuklara ek: top tablolar çubuk grafiği; "temizlenebilir alan" yığın çubuğu (tablo × `sizeBytes`, `deletable`). Dosyalar: `dataretention/StorageCards.tsx`, `TablesPanel.tsx`.

Aranabilir öğeler: Veri saklama ve depolama (sayfa) · disk dolu, yer aç, eski kayıtları sil, log temizliği · Depolama doluluğu (bölüm): Veritabanı boyutu, En büyük tablolar, Veritabanı sunucusu diski, Uygulama diski (Yüklemeler/Yedekler) · Şişebilen log tabloları (bölüm): tablo satırları (analytics_event, audit_log, notification, mail_outbox… dinamik) · Dışa aktar (eylem; gerekçe + makbuz), Temizle (eylem; tablo adını yazarak onay) · Geçmiş: Dışa aktarma makbuzları, Silme geçmişi · Depolama uyarı bandı (eşik %80/%90).

---

## 17. Uygulama güncelleme (`/admin/app-versions`) — `pages/admin/AppVersionsPage.tsx`, `appVersions/*`
Puan: (a) 4 · (b) 3 · (c) 4 · (d) 3

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 17.1 | ORTA | Sürüm dağılımı tablo (Sürüm/Cihaz/Durum); durum rozeti telefonda kesiliyor ("Güncelleme öner", "Zorunlu güncelle"). | `app-versions-full-390-light.png` | Yatay yığılmış çubuk (güncel / önerilen / zorunlu / bilinmiyor; veri `distribution`, `belowMin`, `belowLatest`) + satır bazında çubuk; rozet kısa metin. | M |
| 17.2 | ORTA | "Cihaz sayıları nereden geliyor?" mavi bilgi kutusu içeriğin en üstünde (teknik not); asıl veri aşağıda. Metin: "Sayim cihaz kayitlarindan; son 30 gun gorulen cihazlar. (Son 30 gün)" çiftli. | `app-versions-full-390-light.png` | Alta/`?` ipucuna taşı. | S |
| 17.3 | ORTA | "Zorunlu güncelleme görecek: 120 cihaz" gibi kritik etki rakamı küçük kutuda; tehlikeli eylemin (zorlama) sonucu ilk bakışta anlaşılmıyor. | – | Kutuda "120 cihaz (%3,4) uygulamayı açamayacak" cümlesi, kırmızı. | S |
| 17.4 | DÜŞÜK | Üst çubuk başlığı kısalıyor ("Uygulama gün..."). | `app-versions-full-390-light.png` | – | S |
| 17.5 | DÜŞÜK | "Yenile" düğmesi küçük; sihirbaz (`PublishWizard`) diyaloğunu çekimle doğrulayamadım. | `app-versions-action-390-light.png` | Elle kontrol. | – |

Görselleştirme: Platform başına **halka**: "Android: %72 güncel, %24 eski, %1,5 çok eski, %1,5 bilinmiyor"; sürüm dağılımı çubuğu. Veri: `VersionDistribution.distribution/platforms`. Dosya `AppVersionsPage.tsx:111,192`.

Aranabilir öğeler: Uygulama güncelleme (sayfa) · zorunlu güncelleme, sürüm zorla, eski sürüm, store · Android / iOS kartları: Yayındaki sürüm, Zorunlu en düşük sürüm, Sayılan cihaz, Zorunlu güncelleme görecek, Güncelleme önerisi görecek, Sürümü bilinmeyen · Sürüm dağılımı tablosu · Yeni sürümü yayınla (eylem; mod: Zorunlu güncelle / Yalnız öner / Zorunluluğu kaldır) · Güncelleme ekranını önizle (eylem) · Cihaz sayıları nereden geliyor? · Ayarlar > Mağaza ve sürümler bağlantısı.

---

## 18. Ayarlar (`/admin/settings`) — `pages/admin/SettingsPage.tsx`, `settings/*`
Puan: (a) 3 · (b) 3 · (c) 3 · (d) 2

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 18.1 | YÜKSEK | En kritik ayar olan **Bakım modu 4. sekmede** (6 sekme, telefonda yatay kaydırma, ilk açılışta "Genel ve iletişim"). Neyin açık/kapalı olduğu sayfa üstünde görünmüyor; yalnız bakım AÇIKKEN sekmede "AÇIK" rozeti çıkar (`SettingsPage.tsx:140`). | `settings-full-390-light.png`, `settings-tab-maintenance-390-light.png` | Sayfa tepesinde "Şu an" şeridi: Bakım modu (Kapalı/Açık) · Duyuru bandı (Açık/Kapalı + metin) · Zorunlu güncelleme (Android: Yalnız öneri, iOS: Kapalı) · Etkinlik onayı (Açık). Her biri ilgili ayara kayar (anchor). | M |
| 18.2 | YÜKSEK | Her alanın kendi "Kaydet" düğmesi (Genel sekmesinde 17 "Kaydet" düğmesi, 70x40: ölçüm 18 dokunma hedefi < 44 px); kaydedilmemiş değişiklik sayacı/üst çubuğu yok; pasif düğme soluk pembe (opacity .55) ve "neden pasif?" açıklaması yok. | `settings-full-390-light.png` | Sticky alt çubuk: "2 değişiklik kaydedilmedi [Hepsini gözden geçir] [Vazgeç]" (her anahtar ayrı `PUT` olmaya devam eder, sunucu sözleşmesi aynı). | M |
| 18.3 | ORTA | Onay penceresi ham değer farkı: Eski değer `false` → Yeni değer `true` (`SettingDiff.tsx`). Boş sebep alanı pencere açılır açılmaz kırmızı çerçeve + "Sebep en az 5 karakter olmalı" gösteriyor (kullanıcı daha yazmadan hata). | `settings-maintenance-dialog-390-light.png` | Boolean için "Kapalı → AÇIK"; hata yalnız dokunulduktan/gönder denendikten sonra (`GuardedDialog` KIT dışı; raporla). | S |
| 18.4 | ORTA | Alan ipuçları/jargon: "Sözleşme kimlik alanları" (KEP, VERBİS), "Apple uygulama kimliği", "Android paket adı", "Bant bağlantısı". Çoğunda yer tutucu (`https://`) dışında örnek yok. | `settings-full-390-light.png` | Alan altına tek cümle açıklama + örnek ("KEP: kayıtlı elektronik posta adresi"). | S |
| 18.5 | ORTA | Duyuru bandı sekmesi canlı önizleme içeriyor (iyi) ama uygulamadaki gerçek görünümden uzak; bakım mesajı sekmesinde önizleme yok. | `settings-tab-banner-390-light.png` | Bakım mesajı için de önizleme; boş bırakılırsa "Varsayılan metin gösterilir" notu. | S |
| 18.6 | DÜŞÜK | Etkinlik sekmesi (onay anahtarı + iki sayı): "0 = sınırsız" ipucu iyi; sayı alanlarında +/− yok. | `settings-tab-events-390-light.png` | Stepper. | S |
| 18.7 | DÜŞÜK | Hata durumu iyi ("Veriler yüklenemedi / Tekrar dene"), ancak sekmeler hata halinde de görünüyor. | `settings-error-390-light.png` | – | – |

Görselleştirme: "Şu an" şeridi (yukarıda); Mağaza sekmesinde min/güncel sürüm yan yana ölçek ("2.0.3 ── 2.0.5"), ters sırada kırmızı (mevcut uyarının görseli). Dosya `SettingsPage.tsx:150-160`.

### Ayarlar — arama dizini için ham liste (anchor = `data-key="<anahtar>"`, `SettingRow.tsx:72`; bölüm başlığı = `Card title`)
| Başlık | Eş anlamlılar | Yol (kısa) | Anahtar / anchor | İzin |
|---|---|---|---|---|
| Bakım modu | bakıma al, siteyi kapat, uygulamayı kapat, kapat, bakım, kesinti | Sistem > Ayarlar > Bakım modu | `maintenance_mode` | settings.read/write |
| Bakım mesajı (Türkçe/English/العربية) | bakım yazısı, kapalı mesajı | Ayarlar > Bakım modu | `maintenance_message_tr/en/ar` | settings.write |
| Duyuru bandı metni (TR/EN/AR) | banner, üst bant, uyarı bandı, duyuru çubuğu | Ayarlar > Duyuru bandı | `banner_text_tr/en/ar` | settings.write |
| Bant bağlantısı | banner linki, duyuru linki | Ayarlar > Duyuru bandı | `banner_url` | settings.write |
| Uygulamadaki görünüm (önizleme) | banner önizleme | Ayarlar > Duyuru bandı | `Card: Uygulamadaki görünüm` | settings.read |
| Android en düşük sürüm | zorunlu güncelleme, minimum sürüm, eski sürümü engelle | Ayarlar > Mağaza ve sürümler | `min_version_android` | settings.write |
| Android güncel sürüm | yayındaki sürüm, son sürüm | aynı | `latest_version_android` | settings.write |
| Android mağaza bağlantısı | play store linki | aynı | `store_url_android` | settings.write |
| Android paket adı | package name, tr.com.bukampus.app | aynı | `store_package_android` | settings.write |
| iOS en düşük sürüm / güncel sürüm / mağaza bağlantısı | app store, apple | aynı | `min_version_ios`, `latest_version_ios`, `store_url_ios` | settings.write |
| Apple uygulama kimliği | app id, appstore id | aynı | `apple_app_id_ios` | settings.write |
| Güncelleme ekranı metni (TR/EN/AR) | güncelleme mesajı, yeni sürüm yazısı | aynı | `update_message_tr/en/ar` | settings.write |
| Uygulama güncelleme sayfası (bağlantı) | sürüm dağılımı | aynı | `AppVersionsLink` | settings.read |
| Uygulama adı | isim, başlık | Ayarlar > Genel | `app_name` | settings.write |
| Web sitesi | site adresi, url | aynı | `website` | settings.write |
| İletişim e-postası | mail adresi, bize ulaşın | aynı | `contact_email` | settings.write |
| Destek e-postası | yardım maili, destek adresi, reply-to | aynı | `support_email` | settings.write |
| Telefon | numara, telefon numarası | aynı | `phone` | settings.write |
| Adres | posta adresi | aynı | `address` | settings.write |
| Veri sorumlusu unvanı / adresi / e-postası | KVKK, sözleşme sahibi | Ayarlar > Genel > Sözleşme kimlik alanları | `legal.controller.name/address/email` | settings.write |
| KEP adresi | kayıtlı elektronik posta | aynı | `legal.controller.kep` | settings.write |
| VERBİS sicil no | verbis | aynı | `legal.controller.verbis` | settings.write |
| Barındırma konumu | sunucu yeri, veri nerede | aynı | `legal.hosting.location` | settings.write |
| Instagram / X (Twitter) / YouTube | sosyal medya, hesap bağlantısı | Ayarlar > Genel > Sosyal medya | `instagram`, `twitter`, `youtube` | settings.write |
| Yönetici onayı gerektiren etkinlikler | etkinlik onayı, onaysız yayınla | Ayarlar > Etkinlikler | `events_require_approval` | settings.write |
| Kullanıcı başına en çok açık etkinlik | etkinlik sınırı, kota | aynı | `event_max_open_per_user` | settings.write |
| Günlük etkinlik açma sınırı | günlük limit | aynı | `event_daily_create_limit` | settings.write |
| Fakülte listesi (ekle / yukarı-aşağı / sil / kaydet) | fakülteler, bölümler listesi | Ayarlar > Fakülteler | `faculties` | settings.write |
| Kaydet / Geri al (her alan) | değişikliği kaydet | eylem | `save-<anahtar>` (`data-testid`) | settings.write |

---

## 19. Roller ve izinler (`/admin/roles`) — `pages/admin/RolesPage.tsx`, `pages/admin/roles.module.css`
Puan: (a) 2 · (b) 3 · (c) 2 · (d) 2

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 19.1 | YÜKSEK | İzin matrisi telefonda 35 satır × 5 profil sütunu: izin adı sütunu geniş, profil sütunları yatay kaydırmada (görünür tek sütun "Tam yetkili"). Satırların ana etiketi ham anahtar (`users.read`, `data.retention.export`, mono). | `roles-full-390-light.png` | Bölümlü (Kullanıcılar, Moderasyon, İçerik, Destek, İletişim, Sistem…) katlanır liste; her profil için "Moderatör: 14/35 izin" kartı ve tıklayınca ✓/– listesi. Ham anahtar yalnız küçük ipucu. | L |
| 19.2 | YÜKSEK | Yönetici listesi ve bekleyen değişiklik tabloları telefonda kesik (Profil, Son görülme, Öneren görünmüyor); uzun e-posta taşma yerine kırpılıyor. | `roles-full-390-light.png` | Kart görünümü. | M |
| 19.3 | ORTA | Dil: "iki kişi onayı", "ADMIN_EMAILS", "Sabit [ADMIN_EMAILS]" rozeti, "USER/ADMIN" teknik. | `roles-full-390-light.png`, `admin-p16.ts` | "Sabit hesap (sunucu ayarından; değiştirilemez)". | S |
| 19.4 | ORTA | "Ben" kartında "35 izin" yalnız sayı; hangi sayfaları göremediği belli değil. | `roles-full-390-light.png` | "Yapabilecekleriniz / yapamayacaklarınız" iki kısa liste; salt okunur ise sarı not. | S |
| 19.5 | DÜŞÜK | Sayfa yetkili olmayan profile bile açık (`perm: dashboard.read`) — doğru ama kendi yetkisini görme amaçlı; menüde "Roller/İzinler" simgesi `shield` diğer 3 öğeyle aynı. | `adminNav.ts:153` | Simge ayır (bkz. 1.3). | S |

Görselleştirme: Profil başına halka/çubuk "izin kapsamı" (veri `matrix.entries[].profiles`); izin matrisi ısı haritası (✓ yeşil, – gri; simge + metin). Dosya `RolesPage.tsx`.

Aranabilir öğeler: Roller ve izinler (sayfa) · yetki, profil, kim ne yapabilir · Ben (yetkilerim) · Yöneticiler (liste) · Profil değiştir (eylem; gerekçe; FULL için iki kişi onayı) · Profil değişiklikleri (bekleyen; Onayla/Reddet) · İzin matrisi: her izin satırı (35 adet; ör. "Kullanıcı listesi ve ayrıntısı", "Tam e-posta, IP, cihaz", "Toplu push ve mail kampanyası gönderme", "Uygulama ayarlarını değiştirme (bakım modu, sürüm)", "Sistem durumu, kuyruklar, yedek"...) + profil açıklamaları (Tam yetkili, Moderatör, Destek, Editör, İzleyici).

---

## 20. Denetim kaydı (`/admin/audit`) — `pages/admin/AuditPage.tsx`, `audit/*`
Puan: (a) 2 · (b) 3 · (c) 2 · (d) 1

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 20.1 | YÜKSEK | Telefonda 8 süzgeç alanı (arama, yönetici, yöntem, durum kodu, başlangıç, bitiş, hedef türü, hedef kimliği) ≈ 520 px, tablo sayfanın altında; her seçici kendi satırında farklı genişlikte (hizasız). | `audit-full-390-light.png` | "Süzgeçler (0)" katlanır çekmece; tarih tek aralık seçici; sık kullanılan çipler (Bugün, Reddedilenler, Ayar değişiklikleri). | M |
| 20.2 | YÜKSEK | Satırın anlaşılır cümlesi ("Ayar değiştirildi", "Gönderi silindi", "Kullanıcı bilgisi okundu" + altında teknik `PUT /api/admin/...`) **3. sütunda**; telefonda yalnız Zaman + Yönetici görünür, yani en değerli bilgi (ne yapıldı) ekranın dışında. Bilinmeyen yollar için eylem çevirisi yoksa ham yol başlık oluyor ("İşlem · academic/exams/publish-with-a-very-long-segment..."). | `audit-full-390-light.png`, `audit-full-1280-light.png` | Mobil kartta ilk satır: "Ayar değiştirildi · Bakım modu"; ikinci satır: yönetici + zaman + ✓/✕; teknik yol katlanır. Çeviri tablosunu (yol → cümle) genişlet, yedek: "Bir işlem yapıldı (teknik ayrıntı için aç)". | M |
| 20.3 | ORTA | Tablo kart görünümüne düşmüyor; "Zaman, Yönetici" sonrası sütunlar kayıyor. | `audit-full-390-light.png` | ResponsiveTable. | M |
| 20.4 | ORTA | "Filtreleri temizle" soluk gri küçük metin düğmesi, 127x40 (44 px altı). | `audit-full-390-light.png` | İkincil düğme. | S |
| 20.5 | ORTA | Özet/grafik yok: kaç işlem, kaç reddedildi, kim en aktif. | – | Üstte 3 sayı: "Bugün 128 işlem · 3 reddedildi · en aktif: boss" (yüklü sayfadan; kesin sayı için backend). | S |
| 20.6 | DÜŞÜK | Boş/hata durumları iyi; CSV aktar düğmesi iyi (44 px). | `audit-empty-390-light.png` | – | – |

Görselleştirme: günlük işlem sayısı çubuğu (14 gün) — **backend gerekir** (toplama ucu yok); yüklü sayfadan sınırlı. Durum kodu dağılımı halka (2xx/4xx).

Aranabilir öğeler: Denetim kaydı (sayfa) · kim ne yaptı, işlem geçmişi, log · Mesaj erişim kayıtları (bağlantı) · CSV dışa aktar (eylem) · Süzgeçler: Ara, Yönetici, Yöntem, Durum kodu, Başlangıç/Bitiş tarihi, Hedef türü, Hedef kimliği, Filtreleri temizle · Satır ayrıntısı: İstek kimliği (kopyala), Sebep, Özet, IP · Saklama: 365 gün.

---

## 21. Mesaj erişim kayıtları (`/admin/audit/message-access`) — `pages/admin/MessageAccessPage.tsx`
Puan: (a) 2 · (b) 3 · (c) 3 · (d) 1

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 21.1 | YÜKSEK | 7 süzgeç telefonda alt alta (~430 px); tablo yalnız Zaman + Yönetici gösterir; Erişim türü/Sohbet/Sebep/IP kayıyor. | `message-access-full-390-light.png` | Katlanır süzgeç + kart: "mod@… 31 Eki 23:18'de kullanıcı #9'un medyasını açtı (sebep: yok)". | M |
| 21.2 | ORTA | "Sebep: —" boş olması önemli bir uyarı (gerekçesiz erişim) ama sıradan metin. | `message-access-full-1280-light.png` | Sebep yoksa sarı "Sebep yazılmamış" rozeti. | S |
| 21.3 | ORTA | "Sohbet kimliği / Kullanıcı kimliği" sayısal; tıklanabilir bağlantı değil. | – | Kullanıcı sayfasına bağlantı. | S |
| 21.4 | DÜŞÜK | Menü adı "Mesaj erişimi", başlık "Mesaj erişim kayıtları" (kısaltılıyor). | `message-access-full-390-light.png` | Birleştir. | S |

Görselleştirme: "Son 30 günde 14 erişim, 3'ü gerekçesiz" iki sayı + yönetici başına yatay çubuk. Veri: yüklü liste (sınırlı).

Aranabilir öğeler: Mesaj erişim kayıtları (sayfa) · özel yazışmaya kim baktı, sohbet görüntüleme logu · Denetim kaydına dön · Süzgeçler: Sebep içinde ara, Yönetici, Erişim türü (Sohbet listesi önizlemesi/Mesajlar/Medya/Toplu akış/Şikâyet bağlamı), Kullanıcı kimliği, Sohbet kimliği, Başlangıç/Bitiş · Filtreleri temizle.

---

## 22. Şifreleme (`/admin/crypto`) — `pages/admin/CryptoPage.tsx`
Puan: (a) 4 · (b) 3 · (c) 1 · (d) 2

| # | Önem | Sorun | Kanıt | Öneri | Boyut |
|---|---|---|---|---|---|
| 22.1 | YÜKSEK | Jargon duvarı: "Etkin ana anahtar k2", "Tanımlı anahtarlar", "Yönetici mesaj çözme: Açık", "Ana anahtar başına sarılı veri anahtarı sayısı", "Yeniden sarma gerekli". Çocuk ne olduğunu ve ne yapacağını anlamaz. | `crypto-full-390-light.png`, `CryptoPage.tsx:55-72` | Üstte tek cümle + ışık: "🟢 Mesajlar korunuyor. 1.200 kayıt hâlâ eski anahtarla (k1) korunuyor — yenilemeniz gerekebilir." Terimler `?` ipucunda. | M |
| 22.2 | YÜKSEK | Sayfa başlığı "Sohbetler ve şifreleme" (menü: "Şifreleme"); aynı sayfada "Kullanıcı mesajlarını aç" (kullanıcı arama + sohbet görüntüleyici) — **güvenlik durumu ile mesaj okuma aracı aynı sayfada**, ikisi ilgisiz. Mesaj okuma bir yetkili/denetimli eylemdir (chat.read). | `crypto-full-390-light.png` | İkisini ayır; mesaj okuma "Sohbet akışı/Kullanıcı mesajları" altında. | M |
| 22.3 | ORTA | DEK sayıları (k1: 1.200, k2: 54.000) iki satır, çubuk yok; "devKey" geliştirme anahtarı uyarısı kırmızı callout (iyi). | `crypto-full-390-light.png` | Yığılmış tek çubuk "%2 eski / %98 güncel" (veri `dekCountsByMasterKey`) + "Yenile" bilgisi. | S |
| 22.4 | DÜŞÜK | Anahtar adları mono; etiket-değer satırlarında hizasız (etiketten sonra girinti farklı). | `crypto-full-390-light.png` | Hizala. | S |

Aranabilir öğeler: Şifreleme (sayfa) · mesaj şifreleme, anahtar yenileme, kripto · Şifreleme durumu: Etkin ana anahtar, Tanımlı anahtarlar, Yönetici mesaj çözme (Açık/Kapalı), Veri anahtarı sayıları, Yeniden sarma gerekli, Geliştirme anahtarı uyarısı · Kullanıcı mesajlarını aç (Kullanıcı ara; eylem).


---

# BÖLÜM D — Arama dizini için notlar (SEARCH ajanı + sayfa ajanları)

1. **Girdi biçimi (öneri):** `{ id:'settings.maintenance_mode', title:'Bakım modu', keywords:['bakıma al','siteyi kapat','kesinti','bakım'], path:'/admin/settings?tab=maintenance', anchor:'maintenance_mode', page:'Sistem > Ayarlar', perm:'settings.read', kind:'setting' }`. Her sayfa bölümünün sonundaki "Aranabilir öğeler" listeleri bu girdilerin ham kaynağıdır; Ayarlar için tam tablo 18. bölümde.
2. **Hazır anchor'lar:** `SettingRow` zaten `data-key="<anahtar>"` taşır (`settings/SettingRow.tsx:72`); bakım anahtarı satırı `SettingsPage.tsx:342` (`data-key="maintenance_mode"`). Bunlar `data-search-anchor` ile eşlenebilir (yeni öznitelik eklemek yerine mevcut `data-key` kullanılabilir). Diğer sayfalarda anchor yok: bölüm başlıkları (`Card title`), süzgeç alanları, düğmeler için eklenmeli.
3. **Derin bağlantı ön koşulu:** G12 — Ayarlar, Operasyon, Sistem ölü kayıtlar, Veri saklama geçmişi sekmeleri URL'ye bağlanmadan `path#anchor` sekmeyi açamaz; Ayarlar'da ilk açılışta "Genel" sekmesi olduğundan "bakım modu" sonucu gizli sekmedeki öğeye gidecek. Vurgu animasyonu `prefers-reduced-motion`'a saygılı olmalı (renk + kenarlık).
4. **Yetki:** Ayarlar öğeleri `settings.read`, Sistem/Kuyruk `system.read`, Veri saklama `data.retention.read`, Denetim `audit.read`, Kampanya/Mail `comms.read`; menüdeki `perm` değerleriyle (`adminNav.ts`) aynı. VIEWER profili `*.read` görür ama yazma eylemleri (Kaydet, Yeniden dene, Sil) için arama sonucu "yetkiniz yok" değil gizli olmalı (sözleşme).
5. **Arama penceresi tasarımı (mobil):** tam ekran; üstte sabit arama kutusu (44 px), altta gruplu sonuçlar (Sayfalar / Ayarlar / Eylemler), her satır: simge + başlık + yol + rozet; boş durumda öneri çipleri ("bakım", "kota", "yedek", "çökme"). Menü süzmesi (AdminLayout.tsx:130) aynı motoru kullanınca "Eşleşen menü öğesi yok" yerine sayfa altında alt sonuçlar listelenir.
6. **Terimler (günlük dil → girdi):** "siteyi kapat/bakıma al" → Bakım modu; "banner/üst bant" → Duyuru bandı; "zorunlu güncelleme/eski sürümü engelle" → Uygulama güncelleme + Ayarlar > min sürüm; "disk doldu/yer aç" → Veri saklama; "kim ne yaptı" → Denetim kaydı; "mail gitmiyor" → Mail kuyruğu / Mail engel listesi / Sistem durumu; "bildirim gitmiyor" → Push altyapısı > FCM durumu; "uygulama çöktü" → Çökme raporları; "yetki ver" → Roller ve izinler; "şifre yenile" → Şifreleme.

---

# BÖLÜM E — Sayfa ajanı için öncelik sırası

Sıra = (kullanıcı etkisi × bulgu ağırlığı) / iş büyüklüğü; her adımda önce "S" işleri, sonra "M". Her sayfa ajanı kendi dosyasında kalmalı; ortak bileşen gereksinimleri en sonda (KIT).

1. **Sistem durumu (12)** — en büyük kazanım: trafik ışığı kahramanı (12.1) + eksik etiket/birim düzeltmesi (12.2, tek dosya, S) + ham nesne değerleri (12.3) + sorunlu kartları öne alma (12.5). Çocuk testinin en çok başarısız olduğu sayfa (c=1).
2. **Ayarlar (18) + arama anchor'ları** — "Şu an" şeridi (bakım/banner/zorunlu güncelleme), boolean farkının "Kapalı → Açık" yazılması (18.3), anchor + `?tab=` (G12). Kullanıcının doğrudan örneği ("bakım modu") burada.
3. **Kabuk (1)** — arama motorunun bağlanması (1.1, SEARCH ile), mobil bant daraltma (1.2), simge ayrıştırma (1.3), 44 px üst çubuk (1.4), tam ekran mobil arama (1.5), profil rozeti (1.6).
4. **Mail kuyruğu (9)** — kota özeti cümlesi + halka + 6 günlük çubuk (9.3, 9.4), katlanır süzgeç (9.1), uzun hata satırı kırpma (9.2).
5. **Çökme raporları (15)** — kart görünümü (15.1), sürüm çiplerinin okunur hale gelmesi (15.2), tıklanır özet kutuları + "en çok çöken 5" çubuğu (15.3, görselleştirme).
6. **Veri saklama (16)** — telefonda gizli Dışa aktar/Temizle düğmeleri (16.1), jargon (16.2), en büyük tablolar çubuğu (16.3).
7. **Push altyapısı (11)** — FCM sekmesi tek cümle + ışık (11.1), sekme adları, istatistik tablo gizleme + yorum cümlesi (11.3).
8. **Operasyon (14)** — Sistem ile birleştirme/ayırma kararı (14.1, ürün sahibi), ham sağlık detayı (14.2), saniye → dakika (14.3, S).
9. **Denetim kaydı (20) + Mesaj erişimi (21)** — mobil kartta "ne yapıldı" ilk satır (20.2), katlanır süzgeç (20.1, 21.1), gerekçesiz erişim rozeti (21.2).
10. **Push kampanyaları (5) + Yeni kampanya (6)** — kart görünümü + ilerleme çubuğu (5.1, 5.2), "Taslağı temizle" etiketi (6.1), yapışkan alıcı sayısı (6.3).
11. **Roller ve izinler (19)** — bölümlü izin listesi + profil kartları (19.1, L), kart görünümü (19.2).
12. **Mail şablonları / kampanyaları / engel listesi (7, 8, 10)** — "Mail gönderilmeyecek adresler" adı (10.1), ilerleme çubuğu rengi (8.1), kart görünümü, süzgeç katlama.
13. **Kaynak durumu (13), Uygulama güncelleme (17), Şifreleme (22)** — cümleyle özet + çubuklar; Şifreleme sayfasından mesaj okuma aracını ayırma (22.2).
14. **Giriş / Kayıt / 404 (2-4)** — küçük metin/aralık düzeltmeleri; 404 metni ve düğmesi (4.1, S).

**KIT ajanından gerekenler** (kit dışı ortak dosyaya dokunmadım; eksik olarak raporluyorum): `ResponsiveTable` (kart ipuçlu), `FilterPanel` (katlanır süzgeç), `StatusHero`/`TrafficLight` (renk + simge + cümle), `ProgressBar`/`Meter` (eşikli, tonlu), `Gauge/Ring` (yüzde halkası), `Sparkline`, `StackedBar` (yığılmış yatay çubuk), `KpiTile` (trend oku + hizalı), `ErrorState subject/neden`, 44 px dokunma varsayılanları, `Checkbox` büyük etkin alan, `SearchAnchor`. Eksik grafik verisi (backend gerekir): sistem göstergelerinin geçmişi (sparkline), çökme zaman serisi/dün karşılaştırması, denetim günlük sayıları, kampanya durum sayaçları, "dün" karşılaştırmalı özetler.

---

# BÖLÜM F — Bulgu dağılımı

| Önem | Sayfa bulguları (1-22) | Ortak (G1-G12) | Toplam |
|---|---|---|---|
| KRİTİK | 3 | 0 | 3 |
| YÜKSEK | 36 | 4 | 40 |
| ORTA | 51 | 7 | 58 |
| DÜŞÜK | 27 | 1 | 28 |
| **Toplam** | **117** | **12** | **129** |


# Ek: bu denetimde kullanılan dosyalar
- Çekim betikleri: `…/scratchpad/aud4/run.mjs`, `run2.mjs`, `mock.mjs`, `analyze.mjs` (repoya konmadı).
- Ham ölçüm dosyaları: `…/scratchpad/aud4/r_{full,empty,error}_{390,wide}.json`.
- Donmuş kaynak kopyası: `C:\bu_qa\aud4_snap2\web` (HEAD e9f171b6).


---

# UYGULAMA DURUMU (NOTIF, dalga 2) — 2026-11-01

Etiket NOTIF. Ekran görüntüleri (sonra): `C:\bu_qa\shots\adminvisual\after\NOTIF\` (Sistem durumu 390/1280 açık, Mail kuyruğu 390/1280, Ayarlar 390, Denetim 390). Fixture: `web/e2e/fixtures/notifsys.ts` (backendsiz /api taklidi; node ile de çalışır).

| Madde | Durum | Not |
|---|---|---|
| 12.1 trafik ışığı kahramanı | KAPANDI | `systemstatus/StatusHero.tsx`: renk + simge + cümle ("Her şey yolunda" / "Dikkat: N şey" / "Sorun var: N şey"), backend `message` cümleleriyle sorun listesi, "Göster" düğmesi ilgili karta kaydırır |
| 12.2 ham anahtar / birimsiz değer | KAPANDI | `mail.dailyQuota`, `storage`, `jobs.storage-alert` adları; `unitOf` yüzde; bilinmeyen anahtar "Diğer gösterge", `*.error` "Bu bölüm okunamadı" |
| 12.3 nesne değerleri | KAPANDI | kampanya sayıları tek cümle + yığılmış çubuk; bildirim servisi cümlesi |
| 12.4 jargon / açıklama | KAPANDI | her göstergeye tek cümle, sade adlar |
| 12.5 25 kart -> gruplu katlanır | KAPANDI | 3 `<details>` grup; sorunlu grup açık, normaller tek satır |
| 12.6 eşikli çubuk, doluluk halkası | KAPANDI | `Meter` + `ProgressRing` (disk, depolama, e-posta hakkı) |
| 12.7 ölü kayıtlar kart | KAPANDI | `ResponsiveTable`, 2 satır hata kırpma + "Tamamını göster"; "Gönderilemeyen kayıtlar" |
| 12.8 disk/depolama tekrarı | KISMEN | ikisi ayrı ad ve açıklamayla halka; "Veri saklama sayfasına git" bağlantısı eklendi |
| 12.9 iskelet | KAPANDI | 4 parçalı iskelet; hata tek kutu |
| 14.2/14.3/14.5 Operasyon | KAPANDI | disk cümlesi + "Teknik ayrıntı" katlanır, bileşen adları sade, saniye -> dk, "Gönderilemeyenleri tekrar dene", kuyruk özet cümlesi, Sistem durumu bağlantısı, tekrarlanan "Son güncelleme" kaldırıldı |
| 14.1 Sistem + Operasyon birleştirme | KALDI | ürün kararı; yalnız bağlantı ve ortak terimler yapıldı |
| 9.1-9.5 Mail kuyruğu | KAPANDI | süzgeçler katlanır ("Süzgeçler (N)"), kart görünümü, hata 2 satır kırpma, kota cümlesi + 6 günlük sütunlar + ayrıntılar katlanır, "Gönderilemedi (vazgeçildi)" tek terim |
| 9.7 onay kutusu 44 px | ORTAK | `Checkbox` ortak dosyada (SHARED) |
| 8.1 / G9 ilerleme çubuğu rengi | KAPANDI | `ProgressBar tone` (devam eden mavi, biten yeşil, duran sarı, hata kırmızı) |
| 7.2 üstü çizili dil çipi | KAPANDI | "AR yok" metni |
| 16.1/16.2 Veri saklama | KAPANDI | telefonda kart + Dışa aktar/Temizle görünür, "Yer kaplayan kayıtlar", "Yedek dosyası kayıtları" |
| 16.3 en büyük tablolar çubuğu | KALDI | |
| 20.1/20.2 Denetim | KAPANDI | süzgeçler katlanır, kartta "ne yapıldı" başlıkta, özet cümlesi (reddedilen sayısı) |
| 18.1-18.3 Ayarlar | KISMEN | "Şu an" şeridi (bakım, bant, zorunlu güncelleme, etkinlik onayı), kaydedilmemiş değişiklik çubuğu + "Hepsini geri al", onay penceresinde "Kapalı -> Açık". Her alanın kendi Kaydet düğmesi KALDI (sunucu sözleşmesi aynı kaldı); boş sebep hatası `GuardedDialog` ortak dosyasında, raporlandı |
| 22.1/22.3 Şifreleme | KISMEN | tek cümle durum + güncel/eski anahtar çubuğu, sade adlar, başlık "Şifreleme". 22.2 (mesaj okuma aracını ayırma) KALDI |
| G12 sekme URL'de | SEARCH | useUrlTab ile yapıldı; Push altyapısı da `useUrlTab`'a geçirildi, sekme içerikleri `tab-*` anchor |
| Arama dizini | KAPANDI | `search/index/notifsysPages.ts` (+ `notifications.ts`, `system.ts` içine eklendi); anchor'lar: kampanya, şablon, mail kampanyası, kuyruk, engel listesi, push sekmeleri, kaynaklar, operasyon sekmeleri, çökme, veri saklama, roller, denetim, mesaj erişimi, şifreleme, ayarlar "Şu an" |
| 5-6, 10, 11, 13, 15, 17, 19, 21 (kart görünümü, jargon, görselleştirme) | KALDI | zaman yetmedi: Push kampanyaları, Yeni kampanya, Mail engel listesi, Push altyapısı, Kaynaklar, Çökme, Uygulama güncelleme, Roller, Mesaj erişimi için yalnız arama anchor'ları eklendi |

Backend gerekir: sistem göstergeleri geçmişi (sparkline), kampanya durum sayaçları, denetim günlük sayıları.
