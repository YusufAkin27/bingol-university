# AUD1: Yönetim paneli görsel denetimi (Genel Bakış + Kullanıcılar grubu)

Tarih: 2026-11-01 · Etiket: AUD1 · Tür: **salt okunur denetim** (kod değiştirilmedi; hatalar düzeltilmedi, raporlandı).
Kapsam: menü grupları **Genel Bakış** (Pano, Analitik ve 5 sekmesi) ve **Kişiler** (uygulamadaki adıyla "Kullanıcılar" grubu: Kullanıcılar, Kullanıcı ayrıntısı, Doğrulanmamış kullanıcılar, Askı önerileri, İtirazlar, Erişim engelleri). Ortak kurallar: `C:\bu_deploy_logs\admin-visual-common.md`.

## 1. Yöntem

- **Kod okuma:** `web/src/layouts/adminNav.ts`, `web/src/routes.admin.tsx`, her sayfa dosyası, `components/ui` ve `components/charts`, `i18n/tr/*`.
- **Görsel ölçüm:** Vite dev (port 5201) + Playwright Chromium, **backendsiz**. `web/e2e/mockPanel.ts` yalnız ~12 uç taklit ediyor (pano, analitik, kullanıcı listesi yok); bu yüzden denetim ajanı kendi, daha zengin taklit katmanını yazdı (repoya **eklenmedi**; ajan çalışma klasöründe). Taklit: dolu veri (uzun e-posta, uzun ad, Arapça ad, 120 karakterlik boşluksuz not gibi uç durumlar dahil), boş veri, 500 hata; kullanıcı ayrıntısında ayrıca "askıda" ve "silinmiş".
- **Matris:** 390×844, 768×1024, 1280×800 × açık/koyu tema × senaryo; tam sayfa ekran görüntüsü + diyalog/sekme/seçim durumları. Toplam **296+ ekran görüntüsü** (yeniden çekimler dahil) → `C:\bu_qa\shots\adminvisual\before\AUD1\<sayfa>-<senaryo>-<genişlik>-<tema>.png`. Ham ölçümler: aynı klasörde `metrics-390.json`, `metrics-768.json`, `metrics-1280.json` (+ `metrics-redo-*.json`).
- **Otomatik ölçüm** (her ekran görüntüsünde sayfa içi betik): yatay taşma (`scrollWidth > clientWidth`), dokunma hedefi < 44 px (satır içi metin bağlantıları hariç; onay kutularında etiket alanı sayılır), metin kontrastı (< 4,5:1; büyük metin < 3:1; canvas ile ön plan/arka plan çözümü), kesilen metin.
- **Puan ölçeği (1-5):** 5 = sorunsuz, 1 = kullanılamaz. (a) mobil taşma/kırılma, (b) tasarım hataları, (c) "çocuk bile anlasın", (d) görselleştirme (5 = veri uygun grafiklerle gösteriliyor).
- **Boyut:** S ≤ 0,5 gün, M ≈ 1-2 gün, L ≥ 3 gün (tek ajan).
- **Önemli not (çalışma ağacı):** ekran görüntüleri paylaşılan çalışma ağacında, başka ajanların **tamamlanmamış değişiklikleriyle** (KIT: `Card.tsx`, `Table.tsx`, `Tabs`, yeni `ActionBar/Insight/ProgressRing`; SEARCH: `src/search`) çekildi. "Önce" = çekim anındaki çalışma ağacı. `src/search/index.ts` geçici olarak bozuk olduğu için 23 ekran hata sınırında kaldı; bunlar **yeniden çekildi** (bkz. §14).

## 2. Rota envanteri (adminNav.ts + routes.admin.tsx)

| Menü grubu | Menü adı | Yol | Bileşen | İzin | Ekran görüntüsü |
|---|---|---|---|---|---|
| Genel | Genel bakış | `/admin` | `DashboardPage` | `dashboard.read` | var |
| Genel | Analitik | `/admin/analytics` ve `/admin/analytics/:tab?` (`?tab=overview\|growth\|engagement\|retention\|demographics&from=&to=&dim=`) | `AnalyticsPage` (+5 sekme) | `analytics.read` | var (5 sekme) |
| Kullanıcılar | Kullanıcılar | `/admin/users` | `UsersPage` | `users.read` | var |
| Kullanıcılar | (ayrıntı) | `/admin/users/:id` | `UserDetailPage` | `users.read` | var |
| Kullanıcılar | (alt sayfa) | `/admin/users/:id/messages` | `UserMessagesPage` | `chat.read` | **yok** (hassas sohbet içeriği sayfası; sohbet/denetim ajanına bırakıldı) |
| Kullanıcılar | (eski yol) | `/admin/users/:id/message` | `LegacyMessageRedirect` | - | yönlendirme |
| Kullanıcılar | Doğrulanmamış kullanıcılar | `/admin/pending-users` | `PendingUsersPage` | `users.pii` | var |
| Kullanıcılar | Askı önerileri | `/admin/moderation/suspensions` | `SuspendRecommendationsPage` | `moderation.read` | var |
| Kullanıcılar | İtirazlar | `/admin/moderation/appeals` | `AppealsPage` | `moderation.read` | var |
| Kullanıcılar | Erişim engelleri | `/admin/security/access-bans` | `AccessBansPage` (3 sekme) | `moderation.read` | var |

Bilgi mimarisi notu (IA-1): "Askı önerileri", "İtirazlar", "Erişim engelleri" moderasyon işleridir ama menüde **Kullanıcılar** grubunda; "Moderasyon" grubunda ise Raporlar, Sohbet akışı, Gönderiler... Yönetici "askı/itiraz"ı nerede arayacağını bilemez. Ayrıca grup adı ("Kullanıcılar") ile ilk öğe adı ("Kullanıcılar") aynı. Öneri: bu üçünü "Moderasyon" grubuna taşı ya da grubu "Kişiler ve güvenlik" diye adlandır; arama dizininde her ikisinde de bulunsun.

## 3. Sonuç özeti

Sayı dağılımı ve en kötü 10 sorun §15'te; sayfa ajanı için öncelik sırası §16'da.

Tek bakışta puanlar:

| Sayfa | (a) mobil | (b) tasarım | (c) anlaşılırlık | (d) görselleştirme | Boyut | Kritik sayısı |
|---|---|---|---|---|---|---|
| Genel bakış | 3 | 3 | 2 | 2 | L | 0 |
| Analitik | 3 | 3 | 2-3 | 3 | M-L | 1 |
| Kullanıcılar | 1 | 2 | 3 | 2 | L | 2 |
| Kullanıcı ayrıntısı | 1 | 2 | 3 | 2 | L | 2 |
| Doğrulanmamış kullanıcılar | 1 | 3 | 3 | 2 | M | 1 |
| Askı önerileri | 4 | 3 | 2 | 1 | S | 0 |
| İtirazlar | 4 | 3 | 3 | 1 | S | 0 |
| Erişim engelleri | 2 | 2 | 2 | 2 | L | 1 |

## 4. Ortak (kit) bulgular: sayfa ajanları bunları kendi dosyalarında çözemez

KIT ajanının dizinlerinde (`components/ui`, `components/charts`) çözülmeli; sayfa ajanları yalnız kullanır.

| # | Önem | Bulgu | Etkilediği sayfalar | Öneri |
|---|---|---|---|---|
| ORT-1 | **KRİTİK** | **`Table` telefonda kart görünümüne düşmüyor;** yalnız yatay kaydırma, kaydırılabildiğini gösteren gölge/ok yok, kaydırma kutusu sayfa kaydırmasından ayrı dikey kaydırma da yapıyor (`.scroll{max-height}`). Eylem sütunları ve kimlik bilgisi ekran dışında kalıyor. | Kullanıcılar, Doğrulanmamış, Erişim engelleri (+ tüm tablolu sayfalar) | `Table` için `card` modu (başlıkları etiket, ilk sütun başlık, son sütun eylem menüsü) ve ≤720 px otomatik; `max-height` mobilde kaldır. (KIT'te `card` ipucu yazılıyor; çekim sırasında etkin değildi.) |
| ORT-2 | YÜKSEK | **`Tabs` sağa kesiliyor, kaydırma ipucu yok, seçili sekme görünür alana kaydırılmıyor.** 390 px'te "Tutundur…", "VPN/Tor lis…", "Veri dışa aktarma" yarım/görünmez. | Analitik, Erişim engelleri, Kullanıcı ayrıntısı (Derin yönetim) | Kenar solma gölgesi + `scrollIntoView` + dar ekranda `Select`. Sekme yüksekliği 44 px. |
| ORT-3 | YÜKSEK | **`StatCard` sparkline kartın dışına taşıyor** (sabit 96 px, `flex:none`; 390 px'te bitişik kartı örtüyor, başlığı kesiyor). | Pano (Son 30 gün, Günlük aktif kullanıcı) | Sparkline'ı kart genişliğine sığdır / dar kartta alta al. |
| ORT-4 | YÜKSEK | **`ErrorState` her kartta aynı genel metin ve ~270 px yükseklik:** "Veriler yüklenemedi / Sunucu bir hata verdi. Biraz sonra tekrar deneyin." Pano'da 7, Analitik/Genel'de 7 kez tekrar; 404, 403, ağ hatası, 500 ayrımı yok ("Kullanıcı bulunamadı" altında "Tekrar dene"). Kart başlığı (hangi veri) kaybolabiliyor. | Pano, Analitik, Kullanıcı ayrıntısı | Kompakt tek satırlık varyant (simge + "X yüklenemedi · Tekrar dene"); duruma göre metin/eylem. |
| ORT-5 | ORTA | **Dokunma hedefleri < 44 px:** `Button size="sm"` mobilde 40 px (masaüstünde ~32), arama düğmesi 44×40, hesap menüsü 72×42, "İçeriğe geç" 117×42, tarih girdileri 27 px (yalın `<input type=date>`), tablo onay kutuları 18-28 px, sıralama düğmeleri 40 px. | hepsi | Mobilde `min-height:44px` (Button), onay kutusu hücresi 44×44, tarih girdisi KIT bileşeni. |
| ORT-6 | ORTA | **768 px ray menüsünde 20 simge, etiketsiz**; birçok simge birbirinin aynısı (iki "çubuk grafik", iki "göz kapalı", üç "uyarı"); öğeler 40 px. Hangi simgenin neye gittiği tahmin edilemiyor. (Menü bileşeni SEARCH/layout ajanının; kit simgeleri ortak.) | tüm sayfalar | Tooltip/etiket, benzersiz simgeler. |
| ORT-7 | ORTA | **Grafik göstergesi (legend) metin rengi seri renginden alınıyor:** açık temada "Arama" 2,98:1, "4. sınıf" 2,98:1, "Etkinlik katılımı"/"3. sınıf"/"Etkinlik" 4,15:1 (< 4,5:1). | Analitik (Etkileşim, Genel, Demografi) | Legend metni `--text`, renk yalnız işaret kutusunda. |
| ORT-8 | ORTA | **Grafik paleti temalar arasında anlam değiştiriyor** (Doğrulanmış: açıkta mavi/kırmızı, koyuda mercan/mavi; kayıt çizgisi açıkta lacivert, koyuda mercan). Kırmızı = tehlike çağrışımı olan renkle olumlu veri gösteriliyor. | Pano, Analitik | `--chart-1..n` sıra ve anlamı tema-bağımsız; "iyi/kötü" için ayrı success/danger tokenları. |
| ORT-9 | ORTA | **Marka kırmızısı hem birincil hem tehlike rengi:** "Kabul et", "Doğrula", "Engel ekle", "Yükle" gibi olumlu birincil düğmeler ile "Sil", "Hesabı sil" tehlike düğmeleri aynı renk ailesinde (yalnız ton farkı). Yalnız renge güvenilemez. | İtirazlar, Doğrulanmamış, Erişim engelleri, Kullanıcı ayrıntısı | Olumlu eylem için ayrı birincil ton/ikon; tehlike eylemi outline-kırmızı + simge. |
| ORT-10 | ORTA | **Gerekçe/metin alanları daha yazılmadan kırmızı kenarlıkla açılıyor** (zorunlu alan odakta, hata gibi). | Kullanıcı ayrıntısı, İtirazlar, Erişim engelleri diyalogları | `touched` olunca hata rengi. (`GuardedDialog`, `ReasonField`) |
| ORT-11 | ORTA | **Üst çubuk sayfa başlığı kırpıyor** ("Doğrulanmamı…") ve telefonda kırıntı yolu gizli. | Doğrulanmamış (diğerleri sığıyor) | Başlık 2 satır / kısa ad. |
| ORT-12 | DÜŞÜK (artefakt) | Tam sayfa ekran görüntülerinde çizgi/alan grafikleri x ekseninin ~%60'ında bitiyor (768 ve 1280'de; sessiz makinede 5 sn beklemeyle de aynı). **Doğrulandı: ekran görüntüsü artefaktı** (Playwright `fullPage` yeniden boyutlandırma anında `ResponsiveContainer` yeniden çiziyor); aynı kart viewport'ta tek başına çekilince çizgi tam (362 px, 30 gün). Gerçek hata değil; ekran görüntülerinde kesik grafik görürseniz bu yüzdendir. | Pano, Analitik | — |
| ORT-13 | DÜŞÜK | Çevrilmemiş ham enum değerleri (`ADMIN`, `MEMBER`, `ACTIVE`, `GOING`, `BUG`, `android`) rozet olarak çıkıyor (sayfa dosyasında: `users/UserExtras.tsx`). | Kullanıcı ayrıntısı | Bkz. UDT-3. |


## 5. Sayfa: Genel bakış (Pano) `/admin`

Kaynak: `web/src/pages/admin/DashboardPage.tsx`, `dashboard/panels.tsx`, `dashboard/Trends.tsx`, `dashboard/ModerationCounters.tsx`, `dashboard/dashboard.module.css`. İzin: `dashboard.read`.
API (mevcut): `GET /admin/analytics/overview`, `/registrations`, `/active-users`, `GET /status`, `GET /admin/audit?size=5`, `GET /admin/moderation/appeals?status=OPEN&size=50`, `.../suspend-recommendations?status=OPEN&size=50`.

**Puanlar (1-5):** (a) mobil 3 · (b) tasarım 3 · (c) "çocuk anlasın" 2 · (d) görselleştirme 2 · **boyut: L** (yeniden kurgu; kit bileşenleri hazır olunca M)

Kanıt: `dashboard-full-390-light.png`, `dashboard-full-768-light.png`, `dashboard-full-1280-dark.png`, `dashboard-empty-390-dark.png`, `dashboard-error-390-light.png` (hepsi `C:\bu_qa\shots\adminvisual\before\AUD1\`).

### Sorunlar (önem sırasıyla)

| # | Önem | Sorun | Kanıt | Önerilen düzeltme |
|---|---|---|---|---|
| DSH-1 | YÜKSEK | **Sparkline kartın dışına taşıyor (390 px).** `Sparkline` sabit `width=96` ve `flex:none`; `.spark{max-width:40%}` yüzde bir flex kabında işe yaramıyor. "Son 30 gün" kartında çizim kart kenarından dışarı çıkıyor, "Günlük aktif kullanıcı" kartında bitişik "Haftalık aktif" kartının üstüne biniyor ve başlık ("Günlük aktif kullanıcı") grafiğin altında kesiliyor. | `dashboard-full-390-light.png` (y≈1150-1500) | `components/ui/Card.tsx` (KIT): Sparkline genişliği `min(96px, 40cqw)`/`width:100%` + `min-width:0`; dar kartta sparkline'ı sayının ALTINA satıra al. Sayfa tarafında değişiklik gerekmez. |
| DSH-2 | YÜKSEK | **Ham sayı yığını, yorum yok.** 20 KPI kutusu, 6 başlık altında düz sayı: "Yapışkanlık 24%", "Günlük/Haftalık/Aylık aktif" jargon; "Bugün 42" ile dünün karşılaştırması yok. İlk bakışta "iyi mi kötü mü" anlaşılmıyor. | `dashboard-full-1280-dark.png` | Üste tek cümlelik özet bandı (kit `Insight`): "Bugün 2.150 kişi girdi; dünden %12 fazla. 9 açık rapor ve 14 destek talebi sizi bekliyor." Türkçe karşılıkları: Yapışkanlık → "Her 4 aylık kullanıcıdan 1'i her gün giriyor" (dau/mau); DAU/WAU/MAU → "Bugün / bu hafta / bu ay giren kişi". |
| DSH-3 | YÜKSEK | **Karşılaştırma/trend oku yok.** `StatCard.change` hiç kullanılmıyor; oysa `registrations` 30 günlük seri ve `active-users` serisi elde (dün/önceki 7 gün hesaplanabilir). | `DashboardPage.tsx` l.88-112 | `registrations.points` ve `activeUsers.points`'tan `periodCompare` (analytics/transform.ts'de hazır) ile "dünden +%X" üretip `change`/`changeLabel` ver. |
| DSH-4 | ORTA | **Mobilde sayfa çok uzun (~3.800 px = 4,5 ekran).** "Dikkat gerektirenler" ve "Kaynak durumu" üstte iyi, ama ardından 20 kutu ve 2 grafik. Karar vermek için kaydırmak gerekiyor. | `dashboard-full-390-light.png` | 4 "ana" kutu (Giren kişi, Yeni kayıt, Açık iş, Askıdaki hesap) üstte büyük; kalanı katlanabilir "Ayrıntılı sayılar" (`<details>`/accordion). |
| DSH-5 | ORTA | **Tek sayıyla anlatılabilecek oranlar düz sayı:** Doğrulanmış 11.200 (%87) halka olmalı; Cihaz dağılımı yığılı çubuk (iyi) ama yüzde+sayı tek satırda sıkışık; kaynak durumu iki ayrı kart. | aynı | `ProgressRing` (KIT) ile "Doğrulanmış %87"; cihaz için `DonutChart` veya mevcut çubuk + büyük yüzdeler. |
| DSH-6 | YÜKSEK | **Hata durumunda aynı "Veriler yüklenemedi" kartı 7 kez alt alta** (Dikkat gerektirenler, Kaynak durumu, genel `overview` hatası, Kayıtlar, Günlük aktif, Cihaz dağılımı, Son yönetici işlemleri; hepsi ~270 px). Hangi verinin gelmediği, sunucunun mu ağın mı sorunu olduğu anlaşılmıyor; sayfa 2.600 px uzuyor. Sunucu 500 iken "Biraz sonra tekrar deneyin" tek çare gibi. | `dashboard-error-390-light.png` | Tek üst bant: "Sunucuya ulaşılamadı; sayılar şu an gösterilemiyor. [Yenile]"; tek hata olduğunda kartları küçük gri "—" ile göster; her kartın `ErrorState compact` yerine tek paylaşılan `useQueries` hata özeti. |
| DSH-7 | ORTA | **Boş durum:** 20 kutu "0" gösteriyor; "Bekleyen iş yok" (iyi), ancak yeni kurulumda "veri yok" ile "gerçekten 0" ayrımı yok. Grafikler "Bu aralık için veri yok" (iyi). | `dashboard-empty-390-dark.png` | Tüm değerler 0 ise üstte "Henüz kullanıcı yok; ilk kayıt gelince burada görünecek." |
| DSH-8 | ORTA | **Son yönetici işlemleri ham HTTP gösteriyor:** `POST /api/admin/users/102/suspend 200`, `PATCH /api/admin/settings/maintenance_mode 403`. Çocuk/uzman olmayan yönetici için anlamsız. Uzun e-posta mobilde satır kırıyor (taşmıyor). | `dashboard-full-390-light.png` (altta) | `summary`/`targetType`/`reason` alanları (`AuditRowV2`) zaten var: "Ayşe, Mehmet C.'yi askıya aldı — sebep: ..." şeklinde cümle; 403 için "yetkisi olmadığı için reddedildi" rozeti. |
| DSH-9 | DÜŞÜK | 768 px ekran görüntüsünde iki grafik yarım çizili: **ekran görüntüsü artefaktı** (bkz. ORT-12), gerçek hata değil. | `dashboard-full-768-light.png` | — |
| DSH-10 | DÜŞÜK | Menü ve araç çubuğu simgeleri 768 px'te (ray menü) 40 px; bkz. ORT-6. | metrics | — |
| DSH-11 | DÜŞÜK | Başlık hiyerarşisi: bölüm başlıkları `--text-sm` gri (okunur ama düşük vurgu), grafikler kartların altında ama "Kayıtlar, son 30 gün" başlığı cümle değil. | — | "Son 30 günde 1.180 kişi kaydoldu" gibi cümle başlık + alt metinde en yoğun gün. |

### Görselleştirme önerileri (mevcut API verisiyle)

| Veri (dosya:satır / API alanı) | Mevcut | Önerilen |
|---|---|---|
| `overview.activeUsers.dau/wau/mau`, `stickiness` (`DashboardPage.tsx` l.98-112) | 4 düz kutu | Tek büyük kutu "Bugün giren kişi" + sparkline (`activeUsers.points`) + "dünden %X" oku; altında "bu hafta/bu ay" iki küçük sayı; `stickiness` → halka ("giren/aylık"). |
| `overview.verifiedUsers/totalUsers` (l.69-79) | 2 kutu | `ProgressRing` %87 + "1.640 kişi henüz doğrulamadı" cümlesi. |
| `overview.newUsers.today/last7d/last30d` + `registrations.points` | 3 kutu, 1 sparkline | Tek kart: büyük "Bugün 42" + 30 günlük mini çizgi + "önceki 7 güne göre +%21" (periodCompare). |
| `overview.openReports/openTickets/newFeedback/communities.pending/events.pending` | 5 düz sayı + "Dikkat" listesi (tekrar) | Yalnız "Dikkat gerektirenler" kalsın (bağlantılı); aynı sayıları ayrıca "Destek ve moderasyon" kutularında tekrar etme (şu an iki kez gösteriliyor: `AttentionPanel` ve `Section support`). |
| `overview.devices` | yığılı çubuk | Donut (3 dilim) ya da mevcut çubuk + büyük %; zaten iyi, yalnız yüzde metni büyütülmeli. |
| `overview.messages.total/last24h` | 1 kutu | "Son 24 saatte 5.231 mesaj" büyük; toplam küçük. |
| `/status` (NEWS/MENU) | 2 satır | Yeşil/sarı büyük "Her şey yolunda" / "Yemek menüsü bakımda" tek şerit. |

### Aranabilir öğe listesi (arama dizini ham girdileri)

`kind`: page/section/setting/action/field. Yol: `/admin`. Anchor önerisi sayfa ajanı tarafından verilir.

| Başlık | Eş anlamlılar | Kısa yol (breadcrumb) | kind | perm |
|---|---|---|---|---|
| Genel bakış | pano, ana sayfa, dashboard, özet | Genel > Genel bakış | page | dashboard.read |
| Dikkat gerektirenler | bekleyen işler, yapılacaklar, onay bekleyen | Genel bakış > Dikkat gerektirenler | section | dashboard.read |
| Açık rapor sayısı | şikayet sayısı, raporlar | Genel bakış > Dikkat gerektirenler | section | dashboard.read |
| Cevap bekleyen destek talebi | açık talep, ticket | Genel bakış > Dikkat gerektirenler | section | dashboard.read |
| Onay bekleyen topluluk / etkinlik | kulüp onayı, etkinlik onayı | Genel bakış > Dikkat gerektirenler | section | dashboard.read |
| Kaynak durumu | haber durumu, menü bakımda, scraper | Genel bakış > Kaynak durumu | section | dashboard.read |
| Toplam kullanıcı / Doğrulanmış / Askıdaki hesap | üye sayısı, kayıtlı kişi | Genel bakış > Kullanıcılar | section | dashboard.read |
| Yeni kayıtlar (bugün, 7 gün, 30 gün) | yeni üye, kayıt sayısı | Genel bakış > Yeni kayıtlar | section | dashboard.read |
| Aktiflik (günlük/haftalık/aylık aktif, yapışkanlık) | DAU, WAU, MAU, kaç kişi giriyor | Genel bakış > Aktiflik | section | dashboard.read |
| Etkileşim ve içerik (mesaj, topluluk, etkinlik, favori, kampanya) | mesajlaşma sayısı | Genel bakış > Etkileşim ve içerik | section | dashboard.read |
| Destek ve moderasyon sayaçları (açık itiraz, açık askı önerisi) | bekleyen itiraz | Genel bakış > Moderasyon | section | moderation.read |
| Kayıtlar, son 30 gün (grafik) | kayıt grafiği | Genel bakış > Grafikler | section | dashboard.read |
| Günlük aktif kullanıcı grafiği | giriş grafiği | Genel bakış > Grafikler | section | dashboard.read |
| Cihaz dağılımı | Android iOS web oranı, telefon türü | Genel bakış > Cihaz dağılımı | section | dashboard.read |
| Son yönetici işlemleri | denetim özeti, kim ne yaptı | Genel bakış > Son yönetici işlemleri | section | audit.read |
| Tümünü gör (denetim kayıtları) | denetim sayfasına git | Genel bakış > Son yönetici işlemleri | action | audit.read |
| Tekrar dene (hata kartı) | yenile | Genel bakış | action | dashboard.read |


---

## 6. Sayfa: Analitik `/admin/analytics` (5 sekme)

Kaynak: `web/src/pages/admin/AnalyticsPage.tsx`, `analytics/{OverviewTab,GrowthTab,EngagementTab,RetentionTab,DemographicsTab}.tsx`, `analytics/parts.tsx`, `analytics/transform.ts`, `analytics/analytics.module.css`. İzin: `analytics.read`. URL durumu: `?tab=overview|growth|engagement|retention|demographics&from=&to=&dim=` (eski `/analytics/:tab` de çalışır).
API: `/admin/analytics/{overview,registrations,active-users,breakdown,engagement,retention,support,push,content}`, `GET /faculties`, `GET /status`.

**Puanlar (1-5):**

| Sekme | (a) mobil | (b) tasarım | (c) çocuk anlasın | (d) görselleştirme | Boyut |
|---|---|---|---|---|---|
| Sayfa çatısı (başlık, KVKK notu, sekme çubuğu, tarih aralığı) | 3 | 3 | 3 | - | S |
| Genel | 3 | 3 | 2 | 3 | M |
| Büyüme | 3 | 3 | 3 | 3 | M |
| Etkileşim | 3 | 3 | 2 | 3 | M |
| Tutundurma | 2 | 3 | 2 | 3 | M |
| Demografi | 3 | 3 | 3 | 3 | S |

Kanıt: `analytics-{overview,growth,engagement,retention,demographics}-{full,empty,error}-{390,768,1280}-{light,dark}.png`, ayrıca `analytics-demo-classyear-full-*`.

### Sayfa çatısı (tüm sekmeler)

| # | Önem | Sorun | Kanıt | Düzeltme |
|---|---|---|---|---|
| ANL-1 | YÜKSEK | **Sekme çubuğu telefonda sağa kesiliyor, kaydırılabildiği belli değil.** "Tutundurma" ve "Demografi" 390 px'te görünmüyor ("Tutundur…" yarım). Aktif sekme "Tutundurma" seçiliyken başlığı kesik (`analytics-retention-full-390-light.png`). Sekme bar'ı yatay kaydırıyor ama gölge/ok yok; seçili sekme otomatik görünür alana kaydırılmıyor. | `analytics-overview-full-390-light.png`, `analytics-retention-full-390-light.png` | `components/ui/Tabs.tsx` (KIT): kenarlarda solma gölgesi + seçili sekmeyi `scrollIntoView({inline:'center'})`; ya da mobilde Select'e düş. |
| ANL-2 | ORTA | **Dönem düğmeleri ile tarih alanları hizasız:** "Son 7/30/90 gün" hapları, "Başlangıç/Bitiş" etiketli tarih girdilerinin altında farklı taban çizgisinde (1280'de ~12 px kaymış); 390'da ise iki ayrı satır. Seçili hap kırmızı (marka rengi) = "tehlike" gibi okunuyor. | `analytics-overview-full-1280-light.png` | Tek `DataToolbar` satırı; seçili hap için `--primary-soft` zemin + kalın kenarlık. |
| ANL-3 | ORTA | **KVKK notu tüm sekmelerde üstte yer kaplıyor** (390'da 3 satır ≈ 80 px, her sekmede aynı). | `analytics-growth-full-390-light.png` | Tek satırlık "i" simgeli açılır ipucu ya da sayfa altına. |
| ANL-4 | ORTA | **Hata durumunda her kart kendi "Veriler yüklenemedi" kutusunu basıyor, kart başlığı kayboluyor** (genel sekmede 7 özdeş kutu, ilk dördünün başlığı yok). Hangi grafiğin yüklenemediği anlaşılmıyor. `Async` bileşeni `ChartCard`ı sarmadan çalışıyor. | `analytics-overview-error-390-light.png` | `parts.tsx` `Async`: hatada `Card title` + kompakt satır ("Günlük kayıtlar yüklenemedi · Tekrar dene") ya da tek üst hata bandı. |
| ANL-5 | ORTA | **Boş durum metni tek ve soğuk:** "Bu aralık için veri yok" her grafikte; hangi aralıkta/ne zaman veri gelir söylenmiyor. | `analytics-overview-empty-390-light.png` | "Seçtiğiniz tarihlerde kayıt yok. Aralığı genişletmeyi deneyin." + "Son 90 gün" kısayol düğmesi. |
| ANL-6 | DÜŞÜK | Tam sayfa ekran görüntülerinde grafikler yarım çizilmiş görünüyor; **ekran görüntüsü artefaktı** (bkz. ORT-12; viewport'ta tek kart çekiminde çizim tam). | `analytics-overview-full-1280-light.png` | — |

### Sekme: Genel (`OverviewTab.tsx`)

| # | Önem | Sorun | Kanıt | Düzeltme |
|---|---|---|---|---|
| ANL-O1 | ORTA | **Büyüme sekmesiyle yinelenen grafikler:** "Günlük kayıtlar" ve "Toplam kullanıcı sayısı" hem Genel hem Büyüme'de (aynı veri). Kullanıcı hangi sekmede ne bulacağını bilemiyor. | `analytics-overview-full-1280-light.png`, `analytics-growth-full-390-light.png` | Genel = yalnız "özet + 3 büyük sayı + 1 grafik"; ayrıntı Büyüme/Etkileşim'e. |
| ANL-O2 | ORTA | **Grafik başlıkları etiket, cümle değil**: "Günlük aktif kullanıcılar", "İçerik akışı". Yorum yok ("Son 30 günde en yoğun gün 14 Eki, 2.400 kişi"). | aynı | `Insight` (KIT) ile grafik üstüne tek cümle: ort., en yüksek gün, önceki döneme göre %. |
| ANL-O3 | ORTA | **"Toplam kullanıcı sayısı" grafiği y-ekseni 0'dan başlıyor** → çizgi neredeyse düz; büyüme hissedilmiyor. | `analytics-growth-full-390-light.png` | Alan grafiği yerine "30 günde +%X (+1.180)" büyük sayı + sparkline; ya da min ekseni veri minimumuna yakın. |
| ANL-O4 | ORTA | **Destek kartı: 3 kutu 390'da tek sütun, her biri ~100 px yüksekliğinde** (toplam 330 px); "Yanıtlanan" ile "Kapatılan" farkı açıklanmamış; "ilk yanıt süresi 3,1 sa" tek satır gri metin. | `analytics-overview-full-390-light.png` | `grid3`'ü 390'da 3 sütun kompakt; ilk yanıt süresini büyük sayı + "hedef 4 sa" ilerleme halkası. |
| ANL-O5 | ORTA | **Kampanya tablosu kartta sığmıyor:** "Tarih" sütunu kesiliyor ("30 Eki 202"), 390'da başlık 3 satıra kırılıyor. | `analytics-overview-full-1280-light.png`, `…-390-light.png` | Tablo yerine 3 satırlık liste kartı (başlık, durum rozeti, alıcı sayısı). |
| ANL-O6 | DÜŞÜK | İçerik akışı yığılı çubuk 30 dar sütun; 1280'de x etiketleri üst üste ("3 Eki 6 Eki 9 Eki 12 Eki"). Kırmızı=Duyuru, mavi=Haber, yeşil=Etkinlik, ayrıca gösterge çubuk altında (iyi). | `analytics-overview-full-1280-light.png` | Etiket aralığı `interval="preserveStartEnd"`; haftalık topla. |
| ANL-O7 | DÜŞÜK | "Kaynak durumu" kartı Pano'dakiyle aynı (yinelenen). | aynı | Analitik'ten kaldır. |

### Sekme: Büyüme (`GrowthTab.tsx`)

| # | Önem | Sorun | Kanıt | Düzeltme |
|---|---|---|---|---|
| ANL-G1 | YÜKSEK | **"Dönem karşılaştırması" kartı mobilde sıkışık ve hizasız:** açıklama ("Önceki 7 güne göre (196)") dar bir sütuna 4-5 satır olarak sarıyor; iki kutuda yüzde değerleri farklı yüksekliklerde. Grafik ("Seçili aralıkta N yeni kayıt") ile "Son 30 gün" kutusu iki ayrı sorgudan (seçili aralık / son 60 gün) hesaplanıyor; mock verisinde 1.223 ve 1.019 çıktı (mock serisi tutarsız olabilir, gerçek veride de en az bir gün fark olasılığı var) ve kullanıcıya fark açıklanmıyor. | `analytics-growth-full-390-light.png` | `StatCard` değişim satırını alt satıra tam genişlik al; "Seçili aralık" ile "Son 30 gün" kutularını aynı kaynağa bağla veya etiketle. |
| ANL-G2 | ORTA | **Doğrulama halkasında renk anlamı temaya göre değişiyor:** açık temada Doğrulanmış=mavi, Doğrulanmamış=kırmızı; koyu temada Doğrulanmış=mercan/kırmızımsı, Doğrulanmamış=mavi. Yalnız renkle okuyan için ters anlam. Büyük "%87" halkanın içinde değil üstte. | `analytics-growth-full-390-dark.png` vs `…-light.png` | `DonutChart` (KIT) renk sırası tema-bağımsız; `ProgressRing` ile merkezde %87. |
| ANL-G3 | DÜŞÜK | Kümülatif grafik ile günlük kayıt grafiği aynı kartlarda; "Tablo olarak göster" düğmesi sağ altta küçük (yükseklik ~32 px). | metrics | Düğme ≥44 px; tablo gizli başlasın (öyle). |

### Sekme: Etkileşim (`EngagementTab.tsx`)

| # | Önem | Sorun | Kanıt | Düzeltme |
|---|---|---|---|---|
| ANL-E1 | YÜKSEK | **Teknik olay adları ham gösteriliyor** ("screen_view", "message_sent", "event_rsvp") ve ekran adları ("home", "menu", "chat"). Jargon; "çocuk bile anlasın" ilkesine ters. | `analytics-engagement-full-390-light.png` | `topEvents.name`/`screens.screen` için Türkçe eşleme sözlüğü (örn. `screen_view` → "Ekran açılışı", `home` → "Ana sayfa"); bilinmeyenler gri "teknik ad" etiketiyle. i18n `admin.analytics.event.*`. |
| ANL-E2 | ORTA | **Huni (funnel) çubukları ve altındaki tablo aynı veriyi iki kez veriyor, iki farklı yüzdeyle**: çubuk "ilk adıma göre %" (%83, %58…), tablo "önceki adıma göre %" (%83, %70…). Karışıklık. | `analytics-engagement-full-390-light.png` | Tek gösterim: çubuk + her adımda "bir önceki adımdan %70 devam etti" cümlesi; tablo "Tablo olarak göster"e. |
| ANL-E3 | ORTA | **Günlük etkileşim çizgi grafiği 4 seriyi tek eksende gösteriyor:** mesajlar (~1.500) baskın, gönderi/RSVP/arama dipte düz çizgi; küçük seriler okunmuyor. | aynı | 4 küçük grafik (small multiples) ya da seri başına sparkline kutusu ("Mesaj: günde ort. 1.480"). |
| ANL-E4 | DÜŞÜK | "Ekran görüntülemeleri" çubuk listesi çok uzun olabilir; sıralama/ilk 8 kısıtı yok. Üst olay tablosu 390'da "Kullanıcı" sütunu kenara yapışık. | aynı | İlk 8 + "Tümünü göster". |

### Sekme: Tutundurma (`RetentionTab.tsx`, `parts.tsx` `CohortHeat`)

| # | Önem | Sorun | Kanıt | Düzeltme |
|---|---|---|---|---|
| ANL-R1 | KRİTİK | **Kohort ısı haritasında 7. gün ve 30. gün sütunları telefonda ekran dışında** (yalnız "1. gün" görünüyor, tablo iç kaydırmalı; ok/gölge yok). Sekmenin asıl bilgisi (haftalık/aylık dönüş) 390 px'te görünmüyor. | `analytics-retention-full-390-light.png` | Mobilde her kohort için kart: "7 Eyl haftası · 300 kişi → 1. gün %55 · 7. gün %32 · 30. gün %18" + 3 ilerleme çubuğu; ya da hücre genişliği küçültülüp 5 sütun sığdırılır (≈ 62 px/sütun). |
| ANL-R2 | ORTA | **Jargon:** "Kohort tutundurma", "Kayıt haftası", "Dönüş oranı". Açıklama metni iyi ama başlıkta terim. | aynı | "Kayıt olanlar sonra geri dönüyor mu?" başlığı; "1. gün %55 = bugün kayıt olanların yarısından çoğu ertesi gün tekrar girdi" örnek cümlesi. |
| ANL-R3 | ORTA | **Isı rengi yalnız renk tonu (mavi yoğunluk) ve yüzde yazısı;** "iyi/kötü" yargısı yok. Lejant 390'da 2 satıra kırılıyor. | aynı | Satır sonuna ortalama/öneri simgesi; sade bir çizgi grafik (D1/D7/D30 ortalamaları) ekle. |
| ANL-R4 | ORTA | Boş durum "Henüz kohort verisi yok." kısa; ne zaman veri olacağı yok. | `analytics-retention-empty-390-light.png` | "Kullanıcılar kayıt olup 1 gün geçince burada belirir." |

### Sekme: Demografi (`DemographicsTab.tsx`)

| # | Önem | Sorun | Kanıt | Düzeltme |
|---|---|---|---|---|
| ANL-D1 | YÜKSEK | **Çubuk listesi ve altındaki tablo aynı veriyi yineliyor; tablo iç içe kaydırma kutusunda (son satır yarım kesik)**, 390'da sayfa içinde ikinci bir dikey kaydırma alanı. | `analytics-demographics-full-390-light.png` | Tabloyu varsayılan gizle ("Tablo olarak göster" gibi) ya da iç `max-height` kaldır. |
| ANL-D2 | ORTA | Boyut düğmeleri (Fakülte/Bölüm/Sınıf/Dil/Rol/Durum/Platform) 390'da 2 satır, yükseklik ~34 px (<44 px). | metrics | `Tabs` ya da `Select`; hedef 44 px. |
| ANL-D3 | ORTA | Rol/Durum/Platform gibi **çok az dilimli boyutlarda donut + tablo**; 6'dan çok dilimde çubuk (iyi). Donut'ta yüzde etiketi dilim üstünde yok. | `analytics-demo-classyear-full-390-light.png` | Dilimde yüzde etiketi; merkezde toplam. |
| ANL-D4 | DÜŞÜK | Fakülte listesi tanımsızsa uyarı kutusu ayarlara bağlanıyor (iyi); ancak "Bilinmiyor" satırı gri rozet olarak yer alıyor, anlamı ("profilini doldurmamış") yok. | kaynak `DemographicsTab.tsx` | Alt açıklama: "Fakülte bilgisini girmemiş kullanıcılar". |

### Görselleştirme önerileri (Analitik)

| Veri | Mevcut | Önerilen |
|---|---|---|
| `active-users` (dau serisi, wau, mau) | çizgi + 2 çip | Büyük "Bugün X kişi", sparkline, dünden/geçen haftaya oku; wau/mau halka ("aylık kullanıcıların %61'i bu hafta geldi"). |
| `registrations` (count, cumulative) | 2 alan grafik | "30 günde +1.180" büyük sayı + günlük çubuk (kümülatif grafik kaldır). |
| `engagement.funnel` | çubuk + tablo | Huni (mevcut `FunnelChart`) + adım arası düşüş oku; tablo gizli. |
| `engagement.daily` (4 seri) | tek eksen çizgi | 4 küçük çizgi (her serinin kendi ölçeği). |
| `engagement.topEvents/screens` | tablo + çubuk | Türkçe adlar, ilk 8, yatay çubuk. |
| `retention.cohorts` (d1/d7/d30) | ısı tablosu | Mobil kart + ortalama çizgisi (3 nokta: D1/D7/D30 ortalaması). |
| `breakdown` | çubuk/donut + tablo | Tek görsel + üstte en büyük dilim cümlesi ("Kullanıcıların %20'si Mühendislik'te"). |
| `support.tickets` (open/answered/closed) | 3 kutu | Yığılı tek çubuk (14 açık · 22 yanıtlandı · 190 kapalı) + ilk yanıt süresi halka. |
| `push.recent` | tablo | Kart listesi + "ulaşan alıcı" mini çubuk. |

### Aranabilir öğe listesi

| Başlık | Eş anlamlılar | Kısa yol | kind | perm |
|---|---|---|---|---|
| Analitik | istatistik, rapor, grafikler | Genel > Analitik | page | analytics.read |
| Genel sekmesi | özet grafikler | Analitik > Genel | section | analytics.read |
| Büyüme sekmesi | kayıt artışı, yeni üye | Analitik > Büyüme | section | analytics.read |
| Etkileşim sekmesi | kullanım, mesaj sayısı, huni | Analitik > Etkileşim | section | analytics.read |
| Tutundurma sekmesi | geri dönüş, retention, kohort | Analitik > Tutundurma | section | analytics.read |
| Demografi sekmesi | fakülte dağılımı, kimler kullanıyor | Analitik > Demografi | section | analytics.read |
| Tarih aralığı (7/30/90 gün, başlangıç, bitiş) | dönem, tarih seç | Analitik > Tarih aralığı | field | analytics.read |
| Günlük aktif kullanıcılar (haftalık/aylık aktif) | DAU WAU MAU, kaç kişi giriyor | Analitik > Genel | section | analytics.read |
| Günlük kayıtlar / Toplam kullanıcı sayısı | kayıt grafiği, kümülatif | Analitik > Genel/Büyüme | section | analytics.read |
| İçerik akışı (haber, duyuru, etkinlik) | yayın sayısı | Analitik > Genel | section | analytics.read |
| Destek ve geri bildirim özeti | talep sayıları, ilk yanıt süresi | Analitik > Genel | section | analytics.read |
| Bildirim kampanyaları özeti | son kampanyalar, alıcı sayısı | Analitik > Genel | section | analytics.read |
| Dönem karşılaştırması | geçen haftaya göre, artış | Analitik > Büyüme | section | analytics.read |
| E-posta doğrulama oranı | doğrulanmış kullanıcı | Analitik > Büyüme | section | analytics.read |
| Kullanım hunisi | kayıttan mesaja, dönüşüm | Analitik > Etkileşim | section | analytics.read |
| En çok gerçekleşen olaylar | olay listesi | Analitik > Etkileşim | section | analytics.read |
| Günlük etkileşim | mesaj, gönderi, arama grafiği | Analitik > Etkileşim | section | analytics.read |
| Ekran görüntülemeleri | en çok açılan ekran | Analitik > Etkileşim | section | analytics.read |
| Kohort tutundurma | 1. gün 7. gün 30. gün | Analitik > Tutundurma | section | analytics.read |
| Demografi boyutu: Fakülte / Bölüm / Sınıf / Dil / Rol / Durum / Platform | dağılım seç | Analitik > Demografi | field | analytics.read |
| Tabloyu göster/gizle | tablo olarak göster | Analitik > (grafik) | action | analytics.read |
| KVKK notu | gizlilik, kişisel veri | Analitik | section | analytics.read |


---

## 7. Sayfa: Kullanıcılar `/admin/users`

Kaynak: `web/src/pages/admin/UsersPage.tsx`, `users/users.module.css`, `users/filters.ts`, `users/DebouncedInput.tsx`, `components/ui/Table.tsx`. İzinler: `users.read` (liste), `users.write` (toplu askı), CSV dışa aktarma sunucuda. API: `GET /admin/users` (süzgeç + sayfa + sıralama), `GET /admin/users/export.csv`, `GET /faculties`, `POST /admin/users/bulk`. Durum URL'de (`?q=&status=&role=&faculty=&department=&classYear=&language=&verified=&createdFrom=&createdTo=&seenFrom=&seenTo=&sort=&page=`).

**Puanlar (1-5):** (a) mobil 1 · (b) tasarım 2 · (c) "çocuk anlasın" 3 · (d) görselleştirme 2 · **boyut: L**

Kanıt: `users-full-{390,768,1280}-{light,dark}.png`, `users-empty-*`, `users-error-*`, `users-bulk-select-full-390-light.png`.

| # | Önem | Sorun | Kanıt | Önerilen düzeltme |
|---|---|---|---|---|
| USR-1 | **KRİTİK** | **Kullanıcının adı ve e-postası hiçbir ekranda görünmüyor (genişlik 0 px).** "Ad" sütununda yalnız avatar dairesi var; `.personText` ölçümü: 0 px, hücre 76 px (Playwright `getBoundingClientRect`, 1280 px'te de). Neden: `users.module.css` `.person` içinde art arda `min-width: 14rem;` ve `min-width: 0;` (ikincisi birincisini eziyor) + `.personText{min-width:0}` + `overflow:hidden; white-space:nowrap` → tablo otomatik yerleşiminde sütun avatara büzülüyor (yan sütunlarda uzun fakülte adları genişliği alıyor). Yöneticinin listede kimi gördüğü anlaşılmıyor. | `users-full-1280-light.png`, `users-full-390-light.png` | `.person{min-width:14rem}` (ikinci `min-width:0` silinsin) veya sütuna `width:22%; min-width:12rem`; mobilde kart görünümü (USR-2). Not: `Table.tsx` KIT'te değişiyor; düzeltme sonrası yeniden ölç. |
| USR-2 | **KRİTİK** | **Tablo telefonda kart olmayıp yatay kaydırmalı; ilk ekranda yalnız "No · avatar · Fakülte · Sınıf".** Durum, rol, son görülme, hesap durumu sağda ekran dışında; kaydırılabildiği belli değil (gölge/ok yok). Ekran görüntüsünde telefonda satır başına kimlik bilgisi yok (USR-1 ile birleşince tablo anlamsız). | `users-full-390-light.png` | Telefonda (≤720 px) satırı karta çevir: avatar + **ad**, e-posta (kırp), altında durum rozeti + rol + "son görülme: 3 gün önce"; tüm kart tıklanabilir (44 px+). KIT `Table card` ipucunu kullan. |
| USR-3 | YÜKSEK | **Filtreler 390 px'te ~530 px yükseklikte, 11 kontrol (arama + 7 filtre + 4 tarih) alt alta; ilk satır görünene kadar iki ekran.** Tarih alanları tarayıcının yalın `<input type=date>` stilinde (kare köşe, 11 px yazı, `dd.mm.yyyy`), diğer girdilerle (yuvarlak, 16 px) tutarsız. "Bölüm" alanının etiketi yok, yalnız placeholder; "Doğrulama: Tümü" seçimi dar kutuda "Doğrulama: Tüm" kesik. | `users-full-390-light.png`, `users-full-768-light.png` | Filtreleri "Filtrele (3)" düğmesiyle açılan panel/çekmeceye al (Drawer var); etkin filtreler çip olarak (×) üstte; tarihler `DateRangePicker` (KIT) ile "Kayıt tarihi: son 30 gün". Koyu temada tarih kutuları yalın gri (27 px yüksek), diğer girdilerden kopuk (`users-full-390-dark.png`). |
| USR-4 | YÜKSEK | **Tablo kendi içinde dikey kaydırma kutusu** (`Table.module.css` `.scroll{max-height:max(22rem, 100dvh-14rem)}`): 390×844'te 12 satırdan ~6'sı görünür, son satır yarım kesik; sayfa kaydırması ile tablo kaydırması iç içe, telefonda "takılma" hissi; sayfalama kutunun dışında altta. | `users-full-390-light.png`, `users-full-768-light.png` | Mobilde `max-height:none`; sayfalamayı tablo altında sabit tut. |
| USR-5 | ORTA | **Dokunma hedefleri küçük:** satır onay kutuları 18 px (etiket alanı yok), başlık onay kutusu, sıralama düğmeleri 40 px; tıklanabilir satırın (detaya gider) görsel ipucu yok (ok/ chevron). | ölçüm (§13) | Onay kutusu hücresini 44×44 yap; kart sağında `›`. |
| USR-6 | ORTA | **Toplu işlem çubuğu telefonda ~190 px yüksek, satırların üstüne biniyor** ve altında boş alan bırakıyor (3 düğme 2 satıra kırılıyor); "Seçimi temizle" düğmesinin metin rengi koyu lacivert zeminle aynı (kontrast ölçümü 1,00:1) → **görünmez**. | `users-bulk-select-full-390-light.png` | Tek satır: "2 seçili · [Askıya al] [⋯]"; alt çubuk 64 px. |
| USR-7 | ORTA | **Özet cümlesi ve sayılar:** "52 kullanıcı" ve sayfalama altında tekrar "52"; toplam/aktif/askıda dağılımı yok. | `users-full-1280-light.png` | Üste şerit: "Toplam 12.840 · 37 askıda · 1.640 doğrulanmamış" (overview uçları elde) + filtrelenmiş sayı cümlesi. |
| USR-8 | ORTA | **Belirsiz etiketler:** "Hiç" (son görülme yok) → "Hiç giriş yapmadı"; "—" ile boş fakülte; rol "Yönetici/Kullanıcı" iyi; durum "Askıda/Silindi" iyi ama rozet tonları (gri "Silindi") renk-tek. Sütun başlığı "Dil" yerine "Uygulama dili". | `users-full-1280-light.png` | Metin güncellemesi. |
| USR-9 | ORTA | **Hata durumu:** filtre bloğu duruyor, altında genel kutu (iyi), ancak "CSV olarak indir" hâlâ etkin. | `users-error-390-light.png` | Hata varken CSV'yi devre dışı; sunucu 5xx ise "Sunucu şu an yanıt vermiyor" metni. |
| USR-10 | DÜŞÜK | Boş durum ("Kullanıcı bulunamadı — Arama sözcüğünü kısaltın ya da filtreleri temizleyin") anlaşılır ama eylem düğmesi yok. | `users-empty-390-light.png` | "Filtreleri temizle" düğmesi ekle. |
| USR-11 | DÜŞÜK | Masaüstünde 10 sütun ("No, Ad, Fakülte, Sınıf, Dil, Rol, Durum, Kayıt tarihi, Son görülme"); 1280'de "Son görülme" kenara taşıyor (yatay kaydırma). | `users-full-1280-light.png` | "No" ve "Dil" sütunlarını gizle / daralt. |

### Görselleştirme önerileri

| Veri | Mevcut | Önerilen |
|---|---|---|
| `analytics/overview` (`totalUsers`, `verifiedUsers`, `suspendedUsers`, `newUsers.*`) — `UsersPage.tsx` kullanmıyor | yok | Liste üstünde 4 kutuluk özet şerit; "Doğrulanmış %87" halka. |
| Satır: `status`, `emailVerified`, `lastSeenAt` | rozet + tarih | Çevrimiçi/son görülme noktası (yeşil: bugün, gri: >30 gün) + "3 gün önce" göreli zaman. |
| `analytics/breakdown?dimension=status|faculty` | yok | Seçili filtrenin yanında mini dağılım çubuğu (fakülte/durum). |
| `createdAt` | tarih | Göreli ("12 gün önce") + yeni kullanıcılara "Yeni" rozeti (7 gün). |

### Aranabilir öğe listesi

| Başlık | Eş anlamlılar | Kısa yol | kind | perm |
|---|---|---|---|---|
| Kullanıcılar | üyeler, öğrenciler, hesaplar, kişi listesi | Kişiler > Kullanıcılar | page | users.read |
| Kullanıcı ara (ad veya e-posta) | kişi bul, arama kutusu | Kullanıcılar > Arama | field | users.read |
| Durum filtresi (Aktif/Askıda/Silindi) | askıdaki kullanıcılar, silinmiş hesaplar | Kullanıcılar > Filtreler | field | users.read |
| Rol filtresi (Kullanıcı/Yönetici) | adminleri listele | Kullanıcılar > Filtreler | field | users.read |
| Fakülte / Bölüm / Sınıf filtresi | okul, öğrenci grubu | Kullanıcılar > Filtreler | field | users.read |
| Dil filtresi (TR/EN/AR) | uygulama dili | Kullanıcılar > Filtreler | field | users.read |
| Doğrulama filtresi | e-postasını doğrulamayanlar | Kullanıcılar > Filtreler | field | users.read |
| Kayıt tarihi / Son görülme aralığı | ne zaman kayıt oldu, son giriş | Kullanıcılar > Tarih filtreleri | field | users.read |
| Filtreleri temizle | sıfırla | Kullanıcılar > Filtreler | action | users.read |
| CSV olarak indir | excel, dışa aktar, liste indir | Kullanıcılar | action | users.read |
| Toplu askıya al | çoklu askı | Kullanıcılar > Toplu işlemler | action | users.write |
| Toplu askıyı kaldır | çoklu aç | Kullanıcılar > Toplu işlemler | action | users.write |
| Toplu oturum kapat | herkesi çıkar | Kullanıcılar > Toplu işlemler | action | users.write |
| Sıralama: ad, kayıt tarihi, son görülme | sırala | Kullanıcılar > Tablo | field | users.read |
| Maskeli arama uyarısı (en az 3 karakter) | e-posta gizli | Kullanıcılar > Arama | field | users.read |

---

## 8. Sayfa: Kullanıcı detayı `/admin/users/:id`

Kaynak: `UserDetailPage.tsx`, `users/{UserActions,UserDeepTabs,UserExtras,ActivityBars,ProfileTab,SessionsTab,PushDevicesTab,NotificationsTab,ExportTab}.tsx`, `accessbans/UserDevices.tsx`, `components/admin/guard/AuditTrail.tsx`, `users/users.module.css`, `users/deep.module.css`. İzinler: `users.read`, `users.write` (askı, şifre sıfırlama, oturum), `users.role`, `users.delete`, `users.verify`, `users.pii` (oturum/cihaz sekmeleri), `users.export`, `comms.single` (bildirim), `moderation.write` (cihaz/IP engeli). Alt sayfa: `/admin/users/:id/messages` (sohbet içeriği; `chat.read`) bu ajanın kapsamı dışında bırakıldı (ekran görüntüsü alınmadı).
API: `GET /admin/users/{id}`, `POST .../suspend|unsuspend|verify-email|send-reset|revoke-sessions`, `PATCH .../role`, `DELETE`, `GET .../sessions|push-devices|notifications|devices`, `PATCH .../profile`.

**Puanlar (1-5):** (a) mobil 1 · (b) tasarım 2 · (c) "çocuk anlasın" 3 · (d) görselleştirme 2 · **boyut: L**

Kanıt: `user-detail-{full,suspended,deleted,error}-{390,768,1280}-{light,dark}.png`, `user-suspend-dialog-full-*`, `user-delete-dialog-full-*`, `user-tab-sessions-full-*`, `user-tab-export-full-*`.

| # | Önem | Sorun | Kanıt | Önerilen düzeltme |
|---|---|---|---|---|
| UDT-1 | **KRİTİK** | **Sayfa yatay taşıyor:** 390 px'te sayfa genişliği 493 px, 1280 px'te 1.368 px (`scrollWidth > clientWidth`; `full`, `suspended`, `deleted` üçünde de). Sağ sütundaki "Yönetici işlemleri" kartı 493 px'e genişlemiş, düğmeler ekrandan taşıyor; sayfayı sağa sürüklemek gerekiyor. Neden: `.stack` bir `display:grid` ve sütun şablonu yok → örtük `auto` sütun, içerideki uzun e-posta/yol (`AuditTrail`, mock'ta 62 karakterlik yönetici e-postası) min-content'ini alıyor; `.stack{min-width:0}` kendi sütununu sınırlamıyor. | `user-detail-full-390-light.png` (493×6269), `user-detail-full-1280-light.png` (1368×3643) | `.stack{grid-template-columns:minmax(0,1fr)}` + `AuditTrail` e-posta/yol `overflow-wrap:anywhere`. |
| UDT-2 | **KRİTİK** | **Telefonda 20 kart tek sütun, sayfa 6.269 px (7,4 ekran); yönetici işlemleri (Askıya al, Rolü değiştir, Hesabı sil) ~4.000 px aşağıda.** Karar anında (şikâyet gelmiş kullanıcıyı askıya almak) önce 15 kart kaydırmak gerekiyor; ilk ekranda yalnız profil ve sayaçlar. | `user-detail-full-390-light.png` | Üstte yapışkan "Hızlı işlem" çubuğu (Askıya al · Bildirim gönder · ⋯ Diğer); içerik **sekmelere** ("Özet · Etkinlik · Destek ve raporlar · Güvenlik · Yönetim"). Her sekme ≤2 ekran. |
| UDT-3 | YÜKSEK | **Çevrilmemiş ham değerler rozet olarak gösteriliyor:** `ADMIN`, `MEMBER`, `ACTIVE`, `PENDING`, `GOING`, `BUG`, `NEW`, `ACCOUNT`, `OPEN`, `HARASSMENT` ve küçük harf `android`, `ios` (UserExtras.tsx l.114-210: `<Badge>{c.role}</Badge>`, `{c.status}`, `{e.rsvp}`, `{f.category}`, `{r.reason}`). Türkçe karşılıklar (`admin.users.platform.*`, `admin.reports.reason.*`, durum sözlükleri) mevcut ama kullanılmamış. | `user-detail-full-1280-light.png` | `td()` ile çeviri: "Yönetici/Üye", "Aktif/Onay bekliyor", "Katılacak", "Hata", "Yeni", "Hesap", "Açık", "Taciz". |
| UDT-4 | YÜKSEK | **Karar için risk özeti yok:** "Hakkındaki rapor 3", "Gönderdiği rapor 0" 8 eşit kutuya karışmış; ihlal/askı geçmişi, açık rapor vurgusu, "güvenli mi riskli mi" sinyali yok. Askıda durumdaki kullanıcıda sebep yalnız küçük bir uyarı kutusunda. | `user-detail-suspended-390-light.png` | Üste "Dikkat" şeridi: "3 açık rapor · son ihlal 2 gün önce · hesap askıda (sebep: …)", renk + simge + metin; sayaçlar gruplansın (Etkinlik / Destek / Moderasyon). |
| UDT-5 | YÜKSEK | **Cihaz bilgisi 4 ayrı yerde:** "Cihaz kayıtları" (extras.devices), "Cihazlar" (deviceCount + platform rozetleri), "Cihazlar ve IP'ler" (erişim engelleri), "Derin yönetim > Cihazlar" (push token). Kullanıcı hangisine bakacağını bilemez. | `user-detail-full-1280-light.png` | Tek "Cihazlar" sekmesi: cihaz kartı = platform, sürüm, son görülme, IP'ler, push durumu, "engelle". |
| UDT-6 | ORTA | **Derin yönetim sekmeleri 390 px'te sağa kesik** ("Profil müdahalesi · Oturumlar · Cih…"); 5 sekmeden son ikisi ("Bildirimler", "Veri dışa aktarma") kaydırmadan görünmüyor; ipucu yok; sekme yüksekliği 40 px. | `user-detail-full-390-light.png` | Bkz. ANL-1 (Tabs kit). |
| UDT-7 | ORTA | **ActivityBars:** 14 çubuk, eksende yalnız ilk/son tarih; değerler yalnız `title` (dokunmatikte görünmez); yorum yok. | `user-detail-full-390-light.png` (altta) | "Son 14 günde 9 gün giriş yaptı (toplam 76 açılış)" cümlesi + gün harfleri + dokununca değer. |
| UDT-8 | ORTA | **Silme ve rol değiştirme düğmeleri yan yana/sıkışık:** "Rolü değiştir" seçici + düğme 390'da iki satıra bölünmüş, "Hesabı sil" kırmızı tam genişlik, "Askıya al" ile aynı boy. Tehlikeli eylemler güvenli eylemlerle aynı kartta ayrım çizgisi olmadan. (Onay diyaloğu yazılı onay ister: iyi.) | `user-detail-full-390-light.png`, `user-delete-dialog-full-390-light.png` | "Tehlikeli bölge" alt kartı (ayrı başlık, açıklama: "Bu işlem geri alınamaz"). |
| UDT-9 | ORTA | **Askıya al diyaloğunda boş gerekçe alanı daha yazmadan kırmızı kenarlıkla açılıyor** (hata gibi görünüyor); aynı kalıp İtirazlar, Erişim engeli diyaloglarında. | `user-suspend-dialog-full-390-light.png` | Kenarlığı yalnız `touched` olunca kırmızı yap; odak halkasını koru. |
| UDT-10 | ORTA | **Hata durumu 404'te yanıltıcı:** "Veriler yüklenemedi — Kullanıcı bulunamadı" + "Tekrar dene" (yeniden denemek anlamsız); listeye dön bağlantısı yok. | `user-detail-error-390-light.png` | 404 için "Bu kullanıcı bulunamadı (silinmiş olabilir) · [Kullanıcılara dön]". |
| UDT-11 | ORTA | **Küçük dokunma hedefleri:** "Fotoğrafı temizle", "Biyografiyi temizle", "Adı değiştir", "IP'yi engelle", "Cihazı engelle" gibi `size="sm"` düğmeler mobilde 40 px (`Button.module.css` `.sm{min-height:40px}` ≤960 px), masaüstünde ~32 px; hedef ≥44 px. | ölçüm (§13) | `.sm` için mobilde `min-height:44px` (KIT). |
| UDT-12 | DÜŞÜK | Silinmiş kullanıcı: işlemler kartı "silinmiş hesap" notu (iyi) ama aynı sayfada hâlâ 15 kart; "Derin yönetim" kartı tek cümle. | `user-detail-deleted-390-light.png` | Silinmiş için tek özet kart + "anonimleştirildi" bilgisi. |
| UDT-13 | DÜŞÜK | Başlıkta RTL ad ("محمد علي") soldan, ok/kırıntı karışık yönde; `dir="auto"` yok. | `user-detail-full-1280-light.png` | `<h1 dir="auto">`. |

### Görselleştirme önerileri

| Veri (`AdminUserDetail`) | Mevcut | Önerilen |
|---|---|---|
| `counts.*` (8 değer) + `follow` | 10 eşit kutu | Gruplu: "Sosyal" (takipçi/takip/topluluk/etkinlik), "Destek" (talep/geri bildirim), "Moderasyon" (hakkındaki/gönderdiği rapor; >0 ise sarı/kırmızı vurgu). |
| `recentActivity` (14 gün) | yalın çubuk | Çubuk + "9/14 gün aktif" halka + tek cümle yorum. |
| `extras.notificationPrefs` | 5 rozet "açık/kapalı" | Anahtar (toggle) görünümlü salt-okunur liste. |
| `extras.messagesSent/notificationsTotal/Unread` | metin | `ProgressRing`: okunmamış %8. |
| `consents` | liste | Onay rozeti seti (Kullanım koşulları ✓ v2, Gizlilik ✓ v2). |
| `status/suspendedReason` | küçük uyarı | Büyük durum bandı (renk + simge + sebep + "askıyı kaldır" düğmesi). |

### Aranabilir öğe listesi

| Başlık | Eş anlamlılar | Kısa yol | kind | perm |
|---|---|---|---|---|
| Kullanıcı ayrıntısı | profil, hesap detayı, kişi sayfası | Kişiler > Kullanıcılar > Ayrıntı | page | users.read |
| Profil özeti (e-posta, durum, rol, doğrulama) | kimlik kartı | Kullanıcı ayrıntısı > Profil | section | users.read |
| Sayaçlar (geri bildirim, destek talebi, raporlar…) | istatistikler | Kullanıcı ayrıntısı > Sayaçlar | section | users.read |
| Hesap bilgileri (bildirim sayısı, gönderilen mesaj, engellenenler) | hesap özeti | Kullanıcı ayrıntısı > Hesap bilgileri | section | users.read |
| Kullanıcının mesajlarını aç | sohbet geçmişi, mesaj içeriği | Kullanıcı ayrıntısı > Hesap bilgileri | action | chat.read |
| Bildirim tercihleri | haber duyuru bildirimi açık mı | Kullanıcı ayrıntısı | section | users.read |
| Üye olduğu topluluklar / Oluşturduğu etkinlikler / Katıldığı etkinlikler | kulüpler, etkinlik geçmişi | Kullanıcı ayrıntısı | section | users.read |
| Geri bildirimleri / Destek talepleri | şikayet, öneri | Kullanıcı ayrıntısı | section | users.read |
| Hakkındaki raporlar / Gönderdiği raporlar | şikayet edilenler | Kullanıcı ayrıntısı | section | users.read |
| Derin yönetim: Profil müdahalesi | fotoğrafı sil, biyografiyi sil, adı düzelt | Kullanıcı ayrıntısı > Derin yönetim | section | users.write |
| Profil fotoğrafını temizle | avatar kaldır | Derin yönetim > Profil müdahalesi | action | users.write |
| Biyografiyi temizle | hakkında yazısını sil | Derin yönetim > Profil müdahalesi | action | users.write |
| Görünen adı değiştir | isim düzelt, takma ad | Derin yönetim > Profil müdahalesi | action | users.write |
| Oturumlar (tek oturumu kapat) | açık oturumlar, girişler | Derin yönetim > Oturumlar | section | users.pii |
| Push cihazları (token sil) | bildirim cihazı | Derin yönetim > Cihazlar | section | users.pii |
| Bildirim geçmişi (yalnız okunmamış) | gelen kutusu | Derin yönetim > Bildirimler | section | users.read |
| Veri dışa aktarma (KVKK) | kişisel veriyi indir, JSON | Derin yönetim > Veri dışa aktarma | action | users.export |
| Son aktivite | giriş grafiği | Kullanıcı ayrıntısı | section | users.read |
| Yönetici işlemleri | işlem düğmeleri | Kullanıcı ayrıntısı | section | users.write |
| Askıya al / Askıyı kaldır | hesabı dondur, engelle, yasakla | Yönetici işlemleri | action | users.write |
| Doğrulama e-postasını onayla (e-postayı doğrula) | elle doğrula | Yönetici işlemleri | action | users.verify |
| Şifre sıfırlama e-postası gönder | şifremi unuttum, parola | Yönetici işlemleri | action | users.write |
| Oturumlarını kapat | çıkış yaptır, tüm cihazlardan | Yönetici işlemleri | action | users.write |
| Rolü değiştir (Kullanıcı/Yönetici) | admin yap, yetki ver | Yönetici işlemleri | action | users.role |
| Hesabı sil | kaldır, anonimleştir, KVKK silme | Yönetici işlemleri | action | users.delete |
| Bildirim gönder (tek kullanıcıya) | mesaj yolla, push | Kullanıcı ayrıntısı > Bildirim | action | comms.single |
| Cihazlar ve IP'ler / Cihazı engelle / IP'yi engelle / Kullanıcı + cihazlarını engelle | erişim engeli | Kullanıcı ayrıntısı | action | moderation.write |
| Denetim kaydı (bu kullanıcı için) | kim ne yaptı | Kullanıcı ayrıntısı | section | audit.read |
| Onaylanan sözleşmeler | kullanım koşulları onayı, KVKK onayı | Kullanıcı ayrıntısı | section | users.read |


---

## 9. Sayfa: Doğrulanmamış kullanıcılar (Bekleyen kayıtlar) `/admin/pending-users`

Kaynak: `PendingUsersPage.tsx`, `pending/pending.module.css`, `api/pendingUsers.ts`, `bulk/BulkBars.tsx`. İzin: `users.pii` (sayfa), `users.verify` (Doğrula/toplu). API: `GET /admin/pending-registrations` (imleç), `POST .../{email}/verify | resend-code`, `DELETE .../{email}`, CSV. Kayıtlar Redis'te 72 saat yaşar.

**Puanlar (1-5):** (a) mobil 1 · (b) tasarım 3 · (c) "çocuk anlasın" 3 · (d) görselleştirme 2 · **boyut: M**

Kanıt: `pending-{full,empty,error}-{390,768,1280}-{light,dark}.png`, `pending-verify-dialog-full-*`.

| # | Önem | Sorun | Kanıt | Önerilen düzeltme |
|---|---|---|---|---|
| PND-1 | **KRİTİK** | **Telefonda satır eylemleri ("Doğrula", "Kodu yeniden gönder", "Sil / iptal et") ekran dışında.** 390 px'te yalnız onay kutusu, e-posta, ad ve yarım "Bölüm" sütunu görünüyor; sayfanın tek amacı olan düğmeler yatay kaydırmanın sonunda (ipucu yok). Toplu seçim yapılabiliyor ama eylem görünmüyor. | `pending-full-390-light.png` | Mobilde kart: e-posta + ad, "Kalan süre" çubuğu, altında üç tam genişlik düğme (44 px); ya da kart üzerine dokununca alt sayfa (bottom sheet) eylem listesi. |
| PND-2 | YÜKSEK | **Uzun e-posta karakter karakter kırılıyor** (67 karakterlik adres 5 satıra bölünüyor); satır yüksekliği 150+ px, sütun genişliği e-posta için yetersiz. | `pending-full-390-light.png`, `pending-full-1280-light.png` | `overflow-wrap:anywhere` yerine `@` sonrası kırılma (`<wbr>`); ya da e-postayı tek satır + üç nokta + dokununca tam. |
| PND-3 | ORTA | **"Doğrula" ve "Sil / iptal et" iki ayrı kırmızı** (marka kırmızısı vs koyu tehlike kırmızısı); onaylayıcı eylem ile yıkıcı eylem aynı renk ailesinde, yan yana ~12 px aralıkla (yanlış tıklama riski). Düğmeler 1280'de ~32 px. | `pending-full-1280-light.png` | "Doğrula" için `--success`/birincil yeşil ton; "Sil" yalnız metin düğmesi (outline kırmızı). Aralık ≥16 px, yükseklik 44 px. |
| PND-4 | ORTA | **Kalan süre yalnız metin** ("2 gün 2 sa", "20 dk"); 72 saatlik pencerenin ne kadarının kaldığı görünmüyor, süresi dolmak üzere olanlar öne çıkmıyor. "Kod gönderimi 1" sütunu anlamsız (kaç kez kod gönderildi?). | `pending-full-1280-light.png` | `ProgressRing`/ince çubuk (`remainingSeconds/259200`), son 6 saat sarı, son 1 saat kırmızı; sütun "Kod gönderimi: 1 kez" (4+ ise "çok denemiş" uyarısı). |
| PND-5 | ORTA | **Başlık topbar'da "Doğrulanmamı…" diye kesiliyor (390).** | `pending-full-390-light.png` | Topbar başlığı `text-overflow` yerine iki satır / daha kısa ad ("Bekleyen kayıtlar"). Menü adı ile sayfa başlığı aynı olmalı. |
| PND-6 | ORTA | **Özet cümlesi yok:** "3 kayıt gösteriliyor" yerine "3 kişi kayıt oldu ama e-posta kodunu girmedi; 1'inin süresi 6 saatten az kaldı." | `pending-full-390-light.png` | Üst özet şerit + sayıya göre renk. |
| PND-7 | ORTA | **Boş durum çift anlamlı:** "Bekleyen kayıt bulunmuyor ya da aramanızla eşleşen yok." İki durumu ayırmıyor. | `pending-empty-390-light.png` | Arama boşsa: "Şu an bekleyen kayıt yok. Herkes doğrulamış." / aramalıysa: "Aramanızla eşleşen yok" + temizle. |
| PND-8 | DÜŞÜK | "Okul no" rozeti iyi ama sütun etiketi "E-posta / okul no" karışık; "Bölüm / sınıf" hücresi boş "—". | `pending-full-1280-light.png` | Metin. |
| PND-9 | DÜŞÜK | Doğrulama diyaloğu (gerekçe zorunlu) iyi; toplu doğrulama ilerleme göstergesi var (iyi) ama telefonda modal `size=sm` içinde uzun hata listesi kaydırmalı. | `pending-verify-dialog-full-390-light.png` | — |

### Görselleştirme önerileri

| Veri (`PendingUser`) | Önerilen |
|---|---|
| `remainingSeconds` | Satırda ince ilerleme çubuğu; üstte "Süresi dolmak üzere: 1" rozeti. |
| `resendCount` | "3+ kez kod istedi" simgesi (mail ulaşmıyor olabilir ipucu). |
| liste uzunluğu | Üstte "Bekleyen 3 · bugün kayıt olan 2 · süresi dolacak 1" mini sayaçlar. |
| `faculty/department` | Bölüm bazlı dağılım gerekmez; satırda yalnız kısa ad. |

### Aranabilir öğe listesi

| Başlık | Eş anlamlılar | Kısa yol | kind | perm |
|---|---|---|---|---|
| Doğrulanmamış kullanıcılar | bekleyen kayıtlar, kodu girmeyenler, onaysız üyeler | Kişiler > Doğrulanmamış kullanıcılar | page | users.pii |
| Bekleyen kayıt ara (e-posta, ad, okul no) | arama | Doğrulanmamış kullanıcılar > Arama | field | users.pii |
| CSV indir (bekleyen kayıtlar) | excel, dışa aktar | Doğrulanmamış kullanıcılar | action | users.pii |
| Doğrula (kodsuz hesap oluştur) | elle onayla, e-posta doğrulamasını atla | Doğrulanmamış kullanıcılar > Satır eylemleri | action | users.verify |
| Kodu yeniden gönder | doğrulama kodu tekrar, mail gönder | Doğrulanmamış kullanıcılar > Satır eylemleri | action | users.pii |
| Sil / iptal et | kaydı kaldır | Doğrulanmamış kullanıcılar > Satır eylemleri | action | users.pii |
| Toplu doğrula (en çok 50) | çoklu onay | Doğrulanmamış kullanıcılar > Toplu işlemler | action | users.verify |
| Toplu iptal | çoklu sil | Doğrulanmamış kullanıcılar > Toplu işlemler | action | users.pii |
| Kalan süre (72 saat) | süre dolumu, otomatik silinme | Doğrulanmamış kullanıcılar > Tablo | field | users.pii |
| Kod gönderim sayısı | kaç kez kod istendi | Doğrulanmamış kullanıcılar > Tablo | field | users.pii |

---

## 10. Sayfa: Askı önerileri `/admin/moderation/suspensions`

Kaynak: `SuspendRecommendationsPage.tsx`, `moderation/moderation.module.css`, `api/moderation.ts`. İzin: `moderation.read` (liste); kabul/yoksay yazma uçlarına sunucu `moderation.write` ister. API: `GET /admin/moderation/suspend-recommendations?status=OPEN|ACCEPTED|DISMISSED&cursor&size`, `POST .../{id}/accept|dismiss`.

**Puanlar (1-5):** (a) mobil 4 · (b) tasarım 3 · (c) "çocuk anlasın" 2 · (d) görselleştirme 1 · **boyut: S**

Kanıt: `suspensions-{full,empty,error}-{390,768,1280}-{light,dark}.png`.

| # | Önem | Sorun | Kanıt | Önerilen düzeltme |
|---|---|---|---|---|
| SUS-1 | YÜKSEK | **Kimlik yalnız numara: "Kullanıcı #102".** Kim olduğu, kaç gündür üye olduğu, hangi ihlalleri yaptığı kartta yok; karar için bağlantıya tıklayıp ayrı sayfaya gitmek gerek. API satırı `{id,userId,strikeCount,status,createdAt}`; ad/e-posta/ihlal sebepleri **backend gerekir** (ör. `userDisplayName`, `lastStrikes[]`). Ön yüzde geçici çözüm: sayfa başına ≤20 kullanıcı için `GET /admin/users/{id}` (N+1, önbellekli). | `suspensions-full-390-light.png` | Kartta avatar + ad + "3 ihlal" + son ihlal sebebi çipleri; ad yoksa "#102 (ayrıntı için aç)". |
| SUS-2 | YÜKSEK | **Sayfanın ne olduğu yazmıyor.** Kaynak yorumu "kısa sürede tekrarlanan ihlallerden otomatik üretilir; karar yöneticiye aittir" ama kullanıcıya hiçbir yerde söylenmiyor; "3 ihlal" neyin ihlali, hangi sürede belirsiz. | `suspensions-full-390-light.png` | Başlık altına: "Kısa sürede çok ihlal yapan kullanıcılar için sistem askıya alma önerir. Askıya alırsanız kullanıcı giriş yapamaz; yoksayarsanız öneri kapanır." |
| SUS-3 | ORTA | **"Yoksay" onaysız, anında çalışıyor** (yanlış dokunuşla öneri kapanıyor); "Askıya al" onay diyaloğu var ama gerekçe istemiyor (diğer askı eylemlerinde gerekçe zorunlu: tutarsız). | `SuspendRecommendationsPage.tsx` l.99-112, 124-133 | Her ikisi için aynı `GuardedDialog` + gerekçe. |
| SUS-4 | ORTA | **Sekmelerde sayı yok** ("Açık · Kabul edildi · Yoksayıldı"); kabul/yoksay edilen kartlarda kim, ne zaman, ne dedi yok. | `suspensions-full-390-light.png` | "Açık (2)" sayısı (zaten `ModerationCounters` aynı veriyi çekiyor); karar satırı. |
| SUS-5 | ORTA | **"Kullanıcı #102" bağlantısı satır içi metin (~20 px yüksek)**, parmakla zor basılıyor; kartın tamamı tıklanabilir değil. | metrics | Kart başlığını 44 px'lik satır yap. |
| SUS-6 | DÜŞÜK | Boş sayfa 390 px'te alt %60 boş (iyi: kısa liste); boş durum "Öneri yok — Bu durumda listelenecek öneri bulunmuyor" yeterli ama "Harika, bekleyen öneri yok" gibi olumlu geri bildirim yok. | `suspensions-empty-390-light.png` | Olumlu metin + simge. |

### Görselleştirme önerileri

| Veri | Önerilen |
|---|---|
| `strikeCount` | İhlal noktaları (●●●○○ = 3/5) + renk eşiği; sıralama "en çok ihlal üstte". |
| `createdAt` | "2 gündür bekliyor" göreli zaman; 3 günü geçenler sarı. |
| Üst özet | "2 açık öneri · en yüksek ihlal 5" mini sayaç. |

### Aranabilir öğe listesi

| Başlık | Eş anlamlılar | Kısa yol | kind | perm |
|---|---|---|---|---|
| Askı önerileri | askıya alma önerisi, ihlal eşiği, otomatik öneri | Kişiler > Askı önerileri | page | moderation.read |
| Durum sekmeleri: Açık / Kabul edildi / Yoksayıldı | önerileri filtrele | Askı önerileri > Sekmeler | field | moderation.read |
| Askıya al (öneriyi kabul et) | kullanıcıyı dondur, banla | Askı önerileri > Kart | action | moderation.write |
| Yoksay (öneriyi kapat) | önerme, reddet | Askı önerileri > Kart | action | moderation.write |
| Daha fazla yükle | sonraki sayfa | Askı önerileri | action | moderation.read |

---

## 11. Sayfa: İtirazlar `/admin/moderation/appeals`

Kaynak: `AppealsPage.tsx`, `moderation/moderation.module.css`, `moderation/CsvButton.tsx`, `api/moderation.ts`. İzin: `moderation.read`; karar `moderation.write`. API: `GET /admin/moderation/appeals?status=OPEN|ACCEPTED|REJECTED&cursor&size`, `POST .../{id}/decide {accept,note}` (gerekçe `X-Admin-Reason`), CSV.

**Puanlar (1-5):** (a) mobil 4 · (b) tasarım 3 · (c) "çocuk anlasın" 3 · (d) görselleştirme 1 · **boyut: S**

Kanıt: `appeals-{full,empty,error}-{390,768,1280}-{light,dark}.png`, `appeals-decide-dialog-full-*`.

| # | Önem | Sorun | Kanıt | Önerilen düzeltme |
|---|---|---|---|---|
| APL-1 | YÜKSEK | **İtiraz edilen içerik görünmüyor:** kart yalnız "Keşfet gönderisi #55" + "Kullanıcı #102" + itiraz metni. Karar vermek için içeriğin ne olduğu, neden gizlendiği (hangi kural/rapor) kartta yok; yönetici başka sayfaya gitmek zorunda ve oraya bağlantı da verilmiyor. API `AppealView` yalnız `targetType/targetId`; içerik önizlemesi ve ilk karar sebebi için **backend gerekir**; geçici: `targetType` için "Gizlenen içerikler" sayfasına (`/admin/moderation/hidden`) derin bağlantı. | `appeals-full-390-light.png` | Kartta "Gizlenen içerik: [önizleme] · Sebep: Spam" bloğu; bağlantı. |
| APL-2 | ORTA | **Kullanıcı kimliği yalnız numara** (bkz. SUS-1). | `appeals-full-390-light.png` | Aynı çözüm. |
| APL-3 | ORTA | **Karar sonucu kartta açık değil:** "Reddet / Kabul et" düğmesinin ne yaptığı yalnız diyalogda yazıyor. Diyalogda ayrıca iki metin kutusu var ("Not (isteğe bağlı)" kullanıcıya mı gider? belirtilmemiş; "İşlem gerekçesi (denetim kaydına yazılır)" zorunlu): karışık. | `appeals-decide-dialog-full-390-light.png` | Not etiketine "Kullanıcıya gönderilir" ekle; kartta "Kabul: içerik geri açılır · Reddet: gizli kalır" alt yazısı. |
| APL-4 | ORTA | **Bekleme süresi yok** ("Gönderildi: 30 Eki 2026 13:00" mutlak tarih); en eski itiraz üstte mi belli değil. | `appeals-full-390-light.png` | "2 gündür bekliyor" + sıralama. |
| APL-5 | ORTA | **Aynı durum iki kez gösteriliyor:** sekme "Açık" seçili iken her kartta "● Açık" rozeti. | `appeals-full-390-light.png` | Rozeti yalnız Kabul/Reddedildi sekmelerinde göster. |
| APL-6 | ORTA | **"Kabul et" birincil kırmızı** (yıkıcı eylem rengi), "Reddet" ikincil beyaz; kabul = olumlu sonuç, ancak marka kırmızısı tehlike gibi okunuyor. | `appeals-full-390-light.png` | Kabul için olumlu (yeşil/primary-soft) ton. |
| APL-7 | DÜŞÜK | CSV düğmesi telefonda tam genişlik (ikincil eylem baskın). | `appeals-full-390-light.png` | Başlık satırında ikon düğme. |
| APL-8 | DÜŞÜK | Karar diyaloğunda boş gerekçe alanı daha yazmadan kırmızı (bkz. UDT-9). | `appeals-decide-dialog-full-390-light.png` | — |

### Görselleştirme önerileri

| Veri | Önerilen |
|---|---|
| `status` dağılımı (3 sekme çağrısı) | Üstte "Açık 2 · Kabul 14 · Reddedildi 6" çubuk (sekme sayıları; ilk sayfa sınırı yüzünden 50+ olabilir). |
| `createdAt` | Bekleme süresi çubuğu/rozet. |
| `targetType` | Tür simgeleri (gönderi, mesaj, kullanıcı fotoğrafı). |

### Aranabilir öğe listesi

| Başlık | Eş anlamlılar | Kısa yol | kind | perm |
|---|---|---|---|---|
| İtirazlar | itirazı incele, karar itirazı, gizlenen içerik itirazı | Kişiler > İtirazlar | page | moderation.read |
| İtiraz durum sekmeleri (Açık / Kabul edildi / Reddedildi) | filtre | İtirazlar > Sekmeler | field | moderation.read |
| İtirazları CSV indir | excel, dışa aktar | İtirazlar | action | moderation.read |
| İtirazı kabul et (içerik geri açılır) | geri aç, ihlali iptal et | İtirazlar > Kart | action | moderation.write |
| İtirazı reddet | gizli kalsın | İtirazlar > Kart | action | moderation.write |
| Karar notu (kullanıcıya gider, en çok 500) | açıklama notu | İtirazlar > Karar diyaloğu | field | moderation.write |
| İşlem gerekçesi (denetim kaydı) | sebep | İtirazlar > Karar diyaloğu | field | moderation.write |
| Daha fazla yükle | sonraki | İtirazlar | action | moderation.read |

---

## 12. Sayfa: Erişim engelleri `/admin/security/access-bans`

Kaynak: `AccessBansPage.tsx`, `accessbans/{BansTab,BulkTab,AnonymizersTab,AddBanDialog,UserDevices}.tsx`, `accessbans/accessBans.module.css`, `api/accessBans.ts`. İzin: `moderation.read` (görüntü), `moderation.write` (ekle/düzenle/sil/toplu/VPN listesi). API: `/admin/access-bans/{stats,anonymizers,bulk}`, `GET/POST/PATCH/DELETE /admin/access-bans`, `GET .../{id}/attempts`.

**Puanlar (1-5):** (a) mobil 2 · (b) tasarım 2 · (c) "çocuk anlasın" 2 · (d) görselleştirme 2 · **boyut: L**

Kanıt: `accessbans-{full,empty,error}-{390,768,1280}-{light,dark}.png`, `accessbans-bulk-full-*`, `accessbans-anon-{full,empty}-*`, `accessbans-add-dialog-full-*`.

| # | Önem | Sorun | Kanıt | Önerilen düzeltme |
|---|---|---|---|---|
| ACB-1 | **KRİTİK** | **Telefonda Engeller tablosu 721 px genişliğinde, görünür alan 356 px:** "Süre / İsabet / Ekleyen / Eylemler" sütunları ekran dışı; **Denemeler / Düzenle / Pasife al / Kaldır düğmeleri görünmüyor** (kaydırma ipucu yok). Masaüstünde (1280) normal notla tablo sığıyor (950/950), fakat **boşluksuz uzun not** (mock: 120 karakter) Not sütununu sınırsız genişletip eylemleri de ekran dışına itiyor (`accessbans-full-1280-light.png`; kullanıcı girdisi olduğu için gerçek senaryo). | `accessbans-full-390-light.png`, `accessbans-full-1280-light.png` | Mobilde kart görünümü (tür rozeti + değer + neden + kalan süre; eylemler "⋯" menüsü). Not sütununa `max-width:24ch; overflow-wrap:anywhere` (tam metin `title`). |
| ACB-2 | YÜKSEK | **Telefonda IP / CIDR değerleri ortasından kırılıyor** (Değer sütunu 76 px: "203.0.1 / 13.7", "198.51. / 100.0/2 / 4"; satır başına 2-3 satır) → hangi IP'nin engelli olduğu okunmuyor. | `accessbans-full-390-light.png` | Değer sütununda `white-space:nowrap` + kart görünümü; kopyalama düğmesi (`CopyButton` var). |
| ACB-3 | YÜKSEK | **Jargon:** "CIDR", "IP aralığı (CIDR)", "VPN/Tor listeleri", "Anonimleştirici ağlar", "Tor çıkış düğümleri", "İsabet", "Cihaz kimliği", "Aktif CIDR engeli". "Çocuk bile anlasın" ilkesine ters; hangi engelin ne işe yaradığı ve riski (yanlış IP'yi engellersen kampüs içi herkes kilitlenir) yazmıyor. | `accessbans-anon-full-390-light.png` | Etiketler: "İsabet" → "Kaç kez engelledi"; "IP aralığı (CIDR)" → "IP aralığı (örn. 203.0.113.0/24: 256 adres)"; her sekmeye 1 cümlelik açıklama + uyarı kutusu ("Kampüs ağını engellemeyin"). |
| ACB-4 | YÜKSEK | **Üst istatistik kutuları 5 ayrı eşit kutu** (390'da 3 satır, ~400 px); "Son 24 saatte engellenen deneme 1.234" en önemli sayı ama diğerleriyle aynı boyda; ne iyi ne kötü yorumu yok. | `accessbans-full-390-light.png` | Büyük "Son 24 saatte 1.234 deneme engellendi" + 4 küçük türe göre (yığılı çubuk); "dünden %X". |
| ACB-5 | ORTA | **Filtre düzeni 390 px'te dağınık:** "Tür" ve "Durum" seçicileri alt alta, "Engel ekle" düğmesi bunların yanında ortada yüzüyor, arama kutusu etiketsiz ve ayrı; masaüstünde Tür/Durum/Arama yan yana ama "Engel ekle" sağ uçta, hizasız (select 44, arama 40 px). | `accessbans-full-390-light.png`, `…-1280-light.png` | `DataToolbar` (KIT); "Engel ekle" sabit alt/üst birincil düğme. |
| ACB-6 | ORTA | **Sekme çubuğu 390'da kesik** ("VPN/Tor lis…"). | `accessbans-full-390-light.png` | Bkz. ANL-1. |
| ACB-7 | ORTA | **Engel ekleme diyaloğu uzun (840 px) tek sütun;** doğru çalışıyor ama "Değer" boşken uyarı yok, "Engelle" düğmesi soluk (devre dışı) nedeni söylenmiyor (gerekçe 5 karakter). | `accessbans-add-dialog-full-390-light.png` | Devre dışı düğme altında "Gerekçe yazın" ipucu. |
| ACB-8 | ORTA | **Hata durumunda üstte kompakt hata + altta sekmeler hata verici:** iki ayrı kutu. | `accessbans-error-390-light.png` | Tek hata bandı. |
| ACB-9 | ORTA | **Toplu IP/CIDR ekleme formu:** 10 satırlık metin alanı + 4 alan; "0 satır" ipucu iyi; ancak biçim örneği yok (yalnız "Her satıra bir IP veya CIDR yazın"); satır başına "etiket" desteği sayfada yazmıyor (kodda var). | `accessbans-bulk-full-390-light.png` | Placeholder'da 3 örnek satır. |
| ACB-10 | DÜŞÜK | "Pasif" / "Süresi doldu" durum rozetleri gri (renk-tek); süresi dolmuş engel hâlâ listede aktif gibi (3. satır). | `accessbans-full-1280-light.png` | Pasif satırları soluk + "Süresi 1 Eki'de doldu". |
| ACB-12 | DÜŞÜK | **Kullanıcı engelinde kişinin adı monospace (kod) yazı tipiyle** gösteriliyor ("Mehmet Can Öztürk" kod gibi, 3 satıra bölünerek); ad ile IP aynı stilde. | `accessbans-full-390-dark.png` | Ad normal yazı tipi, IP/cihaz kodu monospace. |
| ACB-11 | DÜŞÜK | VPN/Tor sekmesi iyi yapılandırılmış (bilgi kutusu + ayar + yükleme + liste) ama "Anonimleştirici ağları engelle ayarı" salt-okunur "Açık" rozeti; ayarın nerede değiştirileceği "sunucu yapılandırması" (yönetici için anlamsız). | `accessbans-anon-full-390-light.png` | "Bunu değiştirmek için sistem yöneticisine (sunucu ayarı) başvurun". |

### Görselleştirme önerileri

| Veri | Önerilen |
|---|---|
| `stats.activeByKind` (IP, CIDR, DEVICE, USER) | Tek yığılı yatay çubuk + gösterge; toplam "21 aktif engel". |
| `stats.blockedLast24h` | Büyük sayı + dünden oku (geçmiş seri yok → **backend gerekir** saatlik seri için). |
| `ban.hitCount`, `lastHitAt` | Satırda mini çubuk (en çok vuruş alan engel öne), "son vuruş 2 sa önce". |
| `ban.expiresAt` | Kalan süre rozeti ("12 gün kaldı"). |
| `anonymizers.bySource`, `total` | Donut (tor/vpn) + "98.765 aralık". |

### Aranabilir öğe listesi

| Başlık | Eş anlamlılar | Kısa yol | kind | perm |
|---|---|---|---|---|
| Erişim engelleri | IP engeli, yasaklı IP, ban listesi, kara liste, engellenen cihazlar | Kişiler > Erişim engelleri | page | moderation.read |
| Aktif engel sayıları (IP / CIDR / cihaz / kullanıcı) | kaç engel var | Erişim engelleri > Özet | section | moderation.read |
| Son 24 saatte engellenen deneme | engellenen istek | Erişim engelleri > Özet | section | moderation.read |
| Engeller sekmesi | liste | Erişim engelleri > Engeller | section | moderation.read |
| Tür filtresi / Durum filtresi / Engel ara (IP, cihaz, not) | süzgeç | Erişim engelleri > Engeller > Filtreler | field | moderation.read |
| Engel ekle (tür, değer, neden, bitiş, not, gerekçe) | IP engelle, cihaz engelle, kullanıcıyı engelle | Erişim engelleri > Engeller | action | moderation.write |
| Bitiş: süresiz / tarihli | geçici engel | Erişim engelleri > Engel ekle | field | moderation.write |
| Engeli düzenle | not değiştir, süre uzat | Erişim engelleri > Engeller > Satır | action | moderation.write |
| Engeli pasife al / etkinleştir | kapat, aç, geçici durdur | Erişim engelleri > Engeller > Satır | action | moderation.write |
| Engeli kaldır | sil | Erişim engelleri > Engeller > Satır | action | moderation.write |
| Denemeler (engellenen istekler çekmecesi) | kim girmeye çalıştı, vuruşlar | Erişim engelleri > Engeller > Satır | action | moderation.read |
| Toplu IP/CIDR ekle | liste yapıştır, çoklu IP | Erişim engelleri > Toplu IP/CIDR ekle | section | moderation.write |
| VPN/Tor listeleri | anonimleştirici, proxy engeli, tor çıkış listesi | Erişim engelleri > VPN/Tor listeleri | section | moderation.read |
| Anonimleştirici ağları engelle ayarı | VPN engeli açık mı | Erişim engelleri > VPN/Tor listeleri | setting | moderation.read |
| Liste yükle (kaynak etiketi + CIDR listesi) | vpn listesi ekle | Erişim engelleri > VPN/Tor listeleri | action | moderation.write |
| Yüklü listeyi kaldır | vpn listesi sil | Erişim engelleri > VPN/Tor listeleri | action | moderation.write |
| Kendini kilitleme uyarısı (BAN_SELF_LOCKOUT) | kendi IP mi engelleniyor | Erişim engelleri | setting | moderation.write |


---

## 13. Otomatik ölçüm özeti (ham veri: `metrics-all.json`)

Tüm ölçümler 296 ekran görüntüsünün her birinde sayfa içi betikle alındı. "Sayfaya özgü hedef": ortak üst çubuktaki 3 öğe (İçeriğe geç, Sayfa ara, hesap menüsü) çıkarıldıktan sonra 44 px'in altında kalan etkileşimli öğeler. Kontrast: metin düğümleri; grafik legend'ı dışında açık/koyu temada eşik altı metin bulunmadı (yalnız `Seçimi temizle` düğmesi 1,00:1).

| Sayfa (dolu veri) | 390: sayfa / görünür genişlik | 390: sayfaya özgü <44 px hedef | 768: taşma | 1280: sayfa / görünür genişlik | Kontrast eşik altı (açık / koyu) |
|---|---|---|---|---|---|
| dashboard | 390 / 390 | 1 | yok | 1280 / 1280 | 0 / 0 |
| analytics-overview | 390 / 390 | 9 | yok | 1280 / 1280 | 3 / 0 |
| analytics-growth | 390 / 390 | 8 | yok | 1280 / 1280 | 0 / 0 |
| analytics-engagement | 390 / 390 | 6 | yok | 1280 / 1280 | 6 / 0 |
| analytics-retention | 390 / 390 | 0 | yok | 1280 / 1280 | 0 / 0 |
| analytics-demographics | 390 / 390 | 7 | yok | 1280 / 1280 | 0 / 0 |
| users | 390 / 390 | 23 | yok | 1280 / 1280 | 0 / 0 |
| user-detail | 493 / 390 **TAŞMA** | 5 | yok | 1368 / 1280 **TAŞMA** | 0 / 0 |
| pending | 390 / 390 | 15 | yok | 1280 / 1280 | 0 / 0 |
| suspensions | 390 / 390 | 2 | yok | 1280 / 1280 | 0 / 0 |
| appeals | 390 / 390 | 2 | yok | 1280 / 1280 | 0 / 0 |
| accessbans | 390 / 390 | 13 | yok | 1280 / 1280 | 0 / 0 |
| accessbans-bulk | 390 / 390 | 0 | yok | 1280 / 1280 | 0 / 0 |
| accessbans-anon | 390 / 390 | 2 | yok | 1280 / 1280 | 0 / 0 |


Yatay taşma yalnız **Kullanıcı ayrıntısı** sayfasında (ve ondan türeyen diyalog/sekme görüntülerinde): 390 px'te 493, 1280 px'te 1368 px (UDT-1). Diğer sayfalarda sayfa düzeyinde taşma yok; ancak tablolar kendi kaydırma kutusunda taşıyor (Kullanıcılar tablosu, Doğrulanmamış tablosu, Erişim engelleri tablosu 721 px / görünür 356 px, kohort ısı haritası): bunlar sayfa taşması sayılmıyor ama kullanılabilirlik açısından bulgudur (USR-2, PND-1, ACB-1, ANL-R1).

## 14. Doğrulayamadıklarım ve sınırlar

- **Gerçek veri/sunucu yok:** her şey taklit veriyle. USR-1 (ad sütununun 0 px'e çökmesi) ve UDT-1 (taşma) gerçek sunucu verisiyle **doğrulanmadı**; mock'taki uzunluklar gerçekçi seçildi ama gerçek veride tablo sütunları farklı genişleyebilir.
- **Yalnız FULL profili** denendi. MODERATOR/SUPPORT/VIEWER'da gizlenen düğme/sekme/maskeli e-posta görünümleri görüntülenmedi.
- **Kullanıcı sohbet sayfası** (`/admin/users/:id/messages`) ve Pano'nun `ModerationCounters` hata durumu (tek tek) ekran görüntüsüne alınmadı.
- **Gerçek dokunmatik cihaz/iOS Safari yok;** Chromium 390×844 emülasyonu. `pointer: coarse` kuralları (Button/Table) tetiklenmedi, yalnız `max-width` kuralları.
- **Erişilebilirlik:** ekran okuyucu, klavye odak sırası, `aria` denetlenmedi (yalnız görsel/ölçüm). Kontrast yalnız metin düğümleri için ölçüldü; ikon, placeholder, girdi kenarlığı ve grafik renkleri ölçülmedi (koyu tema placeholder/tarih girdileri gözle değerlendirildi).
- **RTL/Arapça arayüz denenmedi** (yönetim paneli yalnız Türkçe kararı); yalnız Arapça kullanıcı adı/itiraz metni veri olarak göründü.
- **Çalışma ağacı hareketli hedef:** KIT (`Table` kart ipucu, `Card`, `Tabs`, `Insight/ProgressRing/ActionBar`) ve SEARCH (`src/search`) çalışırken çekim yapıldı; "önce" görüntüler o anki hâli yansıtır. KIT'in sonradan yaptığı değişikliklerin bulguları kapatıp kapatmadığı (özellikle ORT-1, ORT-3) doğrulanmadı. 23 ekran `src/search/index.ts` geçici hatası yüzünden hata sınırında kaldı; bunlar ve grafik sayfaları toplam 52 ekran olarak yeniden çekildi.
- **Grafik yarım çizimi** = ekran görüntüsü artefaktı (ORT-12), viewport'ta tek kart çekimiyle doğrulandı.
- API alanları ve "backend gerekir" notları TS tiplerinden (`web/src/api/*.ts`) okundu; backend kodu/docs açılmadı.
- Ekran görüntüleri repoya konmadı (kural gereği `C:\bu_qa\shots\adminvisual\before\AUD1\`); rapordaki dosya adları o klasöre göredir.

## 15. Sayı dağılımı ve en kötü 10 sorun

Bulgu sayısı (bu rapordaki numaralı tablolar):

| Alan | KRİTİK | YÜKSEK | ORTA | DÜŞÜK | Toplam |
|---|---|---|---|---|---|
| Ortak (kit) | 1 | 3 | 7 | 2 | 13 |
| Genel bakış | 0 | 4 | 4 | 3 | 11 |
| Analitik | 1 | 4 | 17 | 6 | 28 |
| Kullanıcılar | 2 | 2 | 5 | 2 | 11 |
| Kullanıcı ayrıntısı | 2 | 3 | 6 | 2 | 13 |
| Doğrulanmamış | 1 | 1 | 5 | 2 | 9 |
| Askı önerileri | 0 | 2 | 3 | 1 | 6 |
| İtirazlar | 0 | 1 | 5 | 2 | 8 |
| Erişim engelleri | 1 | 3 | 5 | 3 | 12 |
| **Toplam** | **8** | **23** | **57** | **23** | **111** |


**En kötü 10** (etki × yaygınlık):

1. **USR-1 (KRİTİK):** Kullanıcılar listesinde ad ve e-posta görünmüyor (genişlik 0 px); en temel sayfa yarı kullanılamaz. Küçük CSS düzeltmesi (S).
2. **UDT-1 (KRİTİK):** Kullanıcı ayrıntısı sayfası yatay taşıyor (390 → 493 px, 1280 → 1368 px); yönetici işlemleri kartı ekran dışında. `.stack` grid sütun şablonu (S).
3. **ORT-1 / USR-2 (KRİTİK):** Tablolar telefonda kart olmuyor, yatay kaydırma ipucu yok; kimlik ve eylemler ekran dışında (Kullanıcılar, Doğrulanmamış, Erişim engelleri). KIT `Table card` (M).
4. **PND-1 (KRİTİK):** Doğrulanmamış kullanıcılarda "Doğrula / Kodu yeniden gönder / Sil" telefonda görünmüyor.
5. **ACB-1 (KRİTİK):** Erişim engellerinde eylem sütunları telefonda (tablo 721/356 px) ve uzun notla masaüstünde ekran dışı.
6. **UDT-2 (KRİTİK):** Kullanıcı ayrıntısı telefonda 6.269 px, 20 kart; Askıya al/Sil ~4.000 px aşağıda. Sekme + hızlı işlem çubuğu (L).
7. **ANL-R1 (KRİTİK):** Tutundurma ısı haritasında 7. ve 30. gün sütunları telefonda görünmüyor.
8. **DSH-1 + DSH-6 (YÜKSEK):** Pano'da sparkline kart dışına taşıyor/başlığı kesiyor; hata durumunda aynı "Veriler yüklenemedi" kutusu 7 kez.
9. **SUS-1 / APL-1 (YÜKSEK):** Karar sayfalarında (askı önerisi, itiraz) kullanıcının adı ve itiraz edilen içerik yok; "Kullanıcı #102" ile karar verilemez (kısmen backend gerekir).
10. **USR-3 + ANL-E1 + UDT-3 (YÜKSEK):** Filtre bloğu 530 px (3 ekran), ham teknik olay adları (`screen_view`) ve çevrilmemiş enum rozetleri (`ADMIN`, `PENDING`): "çocuk bile anlasın" ilkesine aykırı.

## 16. Sayfa ajanı için öncelik sırası

Bağımlılık notu: "KIT" ile işaretli maddeler `components/ui` / `components/charts` değişikliği ister; sayfa ajanları bunları bekler. Diğerleri sayfanın kendi dosyasında yapılır.

| Sıra | Ne | Bulgular | Dosya(lar) | Boyut | Bağımlılık |
|---|---|---|---|---|---|
| 1 | **Hızlı kritik düzeltmeler** (kod hatası niteliğinde): ad sütununu geri getir; ayrıntı sayfası taşmasını gider | USR-1, UDT-1 | `pages/admin/users/users.module.css` (`.person`, `.stack`), `components/admin/guard/AuditTrail` kaydırma | S | yok |
| 2 | **Tablo → kart (telefon)** Kullanıcılar, Doğrulanmamış, Erişim engelleri; not sütunu kısıtı | USR-2, PND-1, PND-2, ACB-1, ACB-2, ORT-1 | `UsersPage.tsx`, `PendingUsersPage.tsx`, `accessbans/BansTab.tsx` | M | KIT `Table card` |
| 3 | **Kullanıcı ayrıntısı yeniden düzeni:** üstte durum/risk bandı + hızlı işlem çubuğu, içerik sekmelerde; enum çevirileri; cihaz bölümlerini birleştir | UDT-2, UDT-3, UDT-4, UDT-5, UDT-6, UDT-8 | `UserDetailPage.tsx`, `users/UserExtras.tsx`, `users/UserActions.tsx` | L | KIT `Tabs`, `Insight`, `ActionBar` |
| 4 | **Pano:** özet cümle + dünle karşılaştırma + halka; sparkline/hata düzeltmesi; yinelenen sayaçları sadeleştir | DSH-1..8 | `DashboardPage.tsx`, `dashboard/*` | L | KIT `Insight`, `ProgressRing`, `StatCard` sparkline |
| 5 | **Analitik:** sekme çubuğu, kohort mobil görünümü, olay adı sözlüğü, huni/tablo yinelemesi, küçük çoklu grafikler, hata kartı başlıkları | ANL-1, ANL-R1, ANL-E1..E3, ANL-D1, ANL-G1, ANL-4 | `AnalyticsPage.tsx`, `analytics/*`, `i18n/tr/admin-analytics.ts` | M-L | KIT `Tabs`, `charts` legend |
| 6 | **Karar sayfaları:** açıklama metni, kimlik/içerik bağlamı, onaylı yoksayma, sekme sayıları | SUS-1..5, APL-1..6 | `SuspendRecommendationsPage.tsx`, `AppealsPage.tsx` | S (+ backend: ad, içerik önizleme) | backend (ad/önizleme) |
| 7 | **Kullanıcılar sayfası:** filtre paneli + çipler, özet şerit, göreli zaman, toplu çubuk | USR-3..11 | `UsersPage.tsx`, `users/filters.ts` | M | KIT `DataToolbar`/`DateRangePicker` |
| 8 | **Erişim engelleri sadeleştirme:** jargon açıklamaları, istatistik şeridi, filtre düzeni | ACB-3..12 | `AccessBansPage.tsx`, `accessbans/*` | M | KIT `Tabs` |
| 9 | **Doğrulanmamış:** kalan süre çubuğu, düğme renkleri, özet | PND-3..8 | `PendingUsersPage.tsx` | S | yok |
| 10 | **Ortak kit düzeltmeleri** (paralel, ayrı ajan): dokunma hedefi 44 px, legend renkleri, palet tutarlılığı, simge/etiket | ORT-5..13 | `components/ui`, `components/charts` | M | - |
| 11 | **Arama dizini girdileri** (SEARCH sözleşmesi): her sayfanın "Aranabilir öğe listesi" tablosu hazır; anchor'ları sayfa ajanı koyar | §5-§12 listeleri | `web/src/search/index/*.ts` | S/sayfa | SEARCH ajanı |

Not (IA-1): "Askı önerileri / İtirazlar / Erişim engelleri" öğelerinin menüde Moderasyon grubuna taşınması kararı yönetici (kullanıcı) kararıdır; arama dizininde her iki yoldan bulunacak biçimde girdi eklemek yeterli.
