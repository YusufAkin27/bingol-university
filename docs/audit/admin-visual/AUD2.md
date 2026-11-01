# AUD2: Yönetim paneli görsel denetimi (Moderasyon + Destek)

Etiket: AUD2. Salt okunur denetim: kodda hiçbir değişiklik yapılmadı. Tarih: 2026-11-01.
Ortak kurallar: `C:\bu_deploy_logs\admin-visual-common.md`.

## 0. Kapsam, yöntem, sınırlar

**Kapsam (adminNav.ts + routes.admin.tsx):** Moderasyon grubunun 9 öğesi ve Destek grubunun 2 öğesi + talep detay rotası = 12 sayfa.

| # | Sayfa | Rota |
|---|---|---|
| 1 | Raporlar | `/admin/reports` |
| 2 | Sohbet medyası ve mesajlar (sohbet akışı) | `/admin/chat-feed` |
| 3 | Gönderiler | `/admin/posts` (`?open=<id>` çekmece) |
| 4 | Anketler | `/admin/polls` |
| 5 | Yasaklı görseller (blocklist) | `/admin/moderation/blocklist` |
| 6 | İhlaller (strike) | `/admin/moderation/strikes` |
| 7 | Gizlenen içerik | `/admin/moderation/hidden` |
| 8 | Karar şablonları (gerekçe şablonları) | `/admin/moderation/reason-templates` |
| 9 | Uygunsuz ifade filtresi | `/admin/profanity` |
| 10 | Destek talepleri | `/admin/support/tickets` |
| 11 | Talep ayrıntısı | `/admin/support/tickets/:id` |
| 12 | Geri bildirim ve öneriler | `/admin/support/feedback` |

Kapsam dışı (başka ajan): `/admin/users/:id/messages` (Kullanıcılar grubu), Topluluk grubundaki içerik onayı.

**Yöntem.** Vite 5202 + Playwright (Chromium). `/api/*` `page.route` ile taklit edildi (dolu / boş / hata, ayrı ayrı; hata kipinde 10 sn beklendi çünkü react-query 3 kez yeniden dener). `web/e2e/mockPanel.ts` yalnız `/admin/me`, rbac ve birkaç uç taklit ettiği için bu sayfalara özgü yanıtlar benim betiğimde (repo dışı, geçici dizinde) yazıldı; sahte veri uzun ad/e-posta/metin, görsel, gizli/silinmiş durumlar içerir. Profil FULL (tüm izinler).
Ölçümler her ekran görüntüsünde otomatik alındı: belge yatay taşması, ekran dışına çıkan öğe, dokunma hedefi < 44 px, metin kontrastı (WCAG, hesaplanan arka plan), en küçük yazı boyutu.

**Ekran görüntüleri:** `C:\bu_qa\shots\adminvisual\before\AUD2\` (yaklaşık 250 dosya). Ad kalıbı: `<sayfa>[-empty|-error]-<390|768|1280>-<light|dark>.png`. Kaplama/çekmece/diyalog görüntüleri: `reports-confirm`, `reports-decision-suspend`, `polls-detail`, `polls-form`, `polls-select`, `posts-detail`, `strikes-forgive`, `reason-templates-modal`, `feedback-drawer`, `ticket-notes`, `chat-feed-media`, `chat-feed-messages`, `reports-resolved`. Ölçüm özeti: aynı dizindeki `_metrics*.json` (en güncel: `_metricsfull-*`, `_metricserror-*`, `_metricsempty.json`).

**Sınırlar (doğrulanamayanlar).**
- Taklit veriyle çalıştım; gerçek sunucu yanıtları, RBAC'ın VIEWER/SUPPORT profilleri ve 20k+ satırlık listelerde davranış doğrulanamadı.
- Telefon görüntüsü masaüstü Chromium'da 390x844 + dokunma kipi ile alındı; gerçek iOS/Android tarayıcı çubuğu/klavye davranışı doğrulanamadı.
- Çalışma ağacı denetim sırasında başka ajanlarca değişiyordu (KIT: Card/Table/PageHeader/charts; SEARCH: `src/search`, üst arama kutusu). Bir ara `src/search/index.ts` eksik dışa aktarım yüzünden sayfalar çöktü; çöken görüntüleri yeniden aldım. Görüntüler "önce" durumunun bir anlık kesitidir; KIT bileşenleri değişirse aşağıdaki ortak bulguların bir kısmı kendiliğinden düzelebilir.
- Her ekranın boş/hata durumunu görüntüledim; ortak `EmptyState/ErrorState` bileşeni olduğundan metinler (kaynak koddan okundu) sayfa başına yazıldı.
- "Gerekçe/typeToConfirm" diyaloglarının hepsi tek tek görüntülenmedi (ortak `GuardedAction`); İhlal affı ve gönderi/anket diyalogları örneklendi.

**Puan ölçeği (1-5, 5 en iyi):** (a) mobil taşma/kırılma, (b) tasarım hataları, (c) çocuk bile anlasın.

## 1. Özet puan tablosu

| Sayfa | (a) mobil | (b) tasarım | (c) anlaşılırlık | Büyüklük |
|---|---|---|---|---|
| Raporlar | 3 | 3 | 3 | L |
| Sohbet akışı | 1 | 2 | 2 | L |
| Gönderiler | 1 | 3 | 3 | M |
| Anketler | 2 | 3 | 3 | L |
| Yasaklı görseller | 4 | 4 | 2 | M |
| İhlaller | 2 | 3 | 2 | M |
| Gizlenen içerik | 2 | 3 | 3 | M |
| Karar şablonları | 2 | 4 | 3 | S |
| Uygunsuz ifade | 4 | 3 | 2 | M |
| Destek talepleri | 2 | 4 | 3 | S |
| Talep ayrıntısı | 4 | 3 | 3 | M |
| Geri bildirim | 3 | 4 | 4 | S |

## 2. Ortak (çapraz) bulgular

Sayfa ajanları bunları kendi sayfalarında çözmeye çalışmasın; KIT dizinleri (`components/ui`, `components/charts`) veya ortak kuraldır. Rapor KIT ajanına gitmeli.

- **X-1 [YÜKSEK, L] `Table` telefonda kart/yığın görünümü yok.** `Table.tsx` yalnız `overflow:auto` kaydırma kabuğu (`Table.module.css` `.scroll`) kullanır; yatay kaydırma göstergesi yok. Etkilenen 5 sayfa: Anketler, İhlaller, Gizlenen içerik, Karar şablonları, Destek talepleri. Önemli sütunlar (Durum, İşlem: "Affet", "Geri al", "Düzenle/Sil") ekran dışında kalır; kullanıcı kaydırılabildiğini bilmez. Kanıt: `strikes-390-light.png`, `hidden-390-light.png`, `tickets-390-light.png`, `reason-templates-390-light.png`, `polls-390-light.png`. Öneri: `Table`'a `mobileCards` kipi (her satır kart: ilk sütun başlık, "Durum" rozeti sağ üst, diğer sütunlar etiket: değer, işlem düğmeleri kart altında).
- **X-2 [YÜKSEK, M] Dokunma hedefi.** Kit düğmesi `md` = 40 px, `sm` = 40 px (telefonda), onay kutuları 13/18/20 px, bağlantılar 20-26 px yükseklik. Ölçüm (390 px): Raporlar 9, Anketler 9-13, Gönderiler 11, Sohbet akışı 10-16 ihlal. Hedef ≥ 44 px (kutu için etiket satırının tamamı dokunulabilir olmalı).
- **X-3 [YÜKSEK, M] Filtre yığını.** Filtre alanları telefonda tek sütun alt alta: İhlaller 6 alan ≈ 520 px, Gönderiler 8 alan ≈ 600 px, Gizlenen içerik 4 alan, Sohbet akışı 8 alan. Veri ikinci ekranda başlar. Öneri: ortak katlanabilir "Filtreler (2 etkin)" bileşeni, tarih aralığı tek alan, sık kullanılan 1-2 filtre açık.
- **X-4 [ORTA, M] `StatCard`.** Değer alta yaslı, başlık üstte; 2 satırlı başlıklarda büyük boşluk, yan yana kartların rakamları hizasız (`chat-feed-media-1280-light.png`, `posts-390-light.png`). Uzun değer ("7.57 GB") ikiye bölünür. Trend oku / sparkline / halka desteği yok.
- **X-5 [ORTA, S] Bağlantı rengi = tehlike rengi.** Tablo/liste bağlantıları kırmızı + altı çizili (Anket başlığı kalın kırmızı, "Ayse Yilmaz", "Sohbette göster"). Kırmızı aynı zamanda hata/riskli eylem rengi; çocuk bağlantıyı hata sanır. Bağlantı için nötr/mavi token.
- **X-6 [ORTA, S] Rutin satır eylemleri dolu kırmızı.** Her satırdaki "Sil", "Kaldır", "Seçilenleri sil" dolu kırmızı düğme; sayfada kırmızı gürültü, gerçek tehlikeli eylem ayırt edilmez. Öneri: satırda ghost/outline + kırmızı yazı, dolu kırmızı yalnız onay diyaloğunda.
- **X-7 [ORTA, S] "Kimlik/no" jargonu.** "Kullanıcı kimliği", "Sohbet no", "Yazar numarası", "Yönetici kimliği", "Birleştirilecek hedef kimliği": kimse numarayı ezbere bilmez. Her yerde arama/seçici ("Ad veya e-posta ara") olmalı; yalnız bir yerde (Sohbet akışı kullanıcı alanı) var.
- **X-8 [DÜŞÜK, S] Terim tutarsızlığı.** "Süzgeç" (Sohbet, Gönderiler, Anketler, İhlaller) / "Filtre" (Denetim kaydı: "Filtreleri temizle") karışık; "Şablon" üç farklı anlamda (Karar şablonları, Hazır yanıtlar > "Şablon ekle", Mail şablonları); "Sil" / "Kaldır" / "Affet" / "Geri al" / "Geri aç" / "Yeniden aç" sözlüğü yok. Tek sözlük öneri.
- **X-9 [ORTA, S] Sayı biçimi.** "7.57 GB" nokta ondalık, geri kalan sayılar Türkçe ("27,4%", "24.310"). `formatBytes` yerel biçim kullanmıyor. Yüzde işareti Türkçede "%27,4".
- **X-10 [YÜKSEK, M] Çekmece/diyalog telefonda.** Gönderi detay çekmecesinde kapatma (X) ekran dışı (`posts-detail-390-light.png`), anket çekmecesinde içerik sağa taşıyor (`polls-detail-390-light.png`). Genel `Drawer` küçük ekranda `max-width:100vw` + iç `min-width:0` davranmalı; alt sayfa (bottom-sheet) kipi tutarlı olmalı.
- **X-11 [ORTA, S] 768 px kenar çubuğu.** Yalnız ikon, etiketsiz; ikon dokunma hedefi 56x40; hangi ikon ne belli değil (`reports-768-light.png`). Kabuk (AdminLayout) sorumlusu: tooltip veya etiket.
- **X-12 [DÜŞÜK, S] Ham İngilizce değerler.** "ACTIVE" (Raporlar hedef önizleme), "INAPPROPRIATE" (Gönderi detayı şikâyet listesi), "FeedPost / text / AppUser / displayName" (Uygunsuz ifade istatistiği). Çeviri/okunur ad.
- **X-13 [DÜŞÜK, S] Kontrast.** Ölçülen tüm ana metinler ≥ 4.5:1 (açık+koyu), tek istisna: 13 px tarih/saat metinleri 4.47:1 (Raporlar kartı `.cardMeta`, Talep ayrıntısı `.time`); ve Anket toplu çubuğunda "Seçimi temizle" açık temada 1.00:1 (aşağıda PL-4). Koyu tema genel olarak sağlam.

## 3. Sayfa raporları

Önem dizisi: KRİTİK (kullanılamaz/veri kaybı riski) > YÜKSEK > ORTA > DÜŞÜK. Kimlik: `<sayfa kısaltması>-<no>`.

### 3.1 Raporlar (`/admin/reports`)  [puan a3 b3 c3, iş L]

Kaynak: `web/src/pages/admin/ReportsPage.tsx` (562 satır) + `reports/*`, `chat/ReportContext.tsx`.
Kanıt: `reports-{390,768,1280}-{light,dark}.png`, `reports-empty-390-light.png`, `reports-error-390-light.png`, `reports-resolved-*`, `reports-decision-suspend-390-light.png`, `reports-confirm-390-light.png`.
Ölçüm: yatay taşma yok; 390 px'te 9 küçük hedef; en küçük yazı 11.2 px.

Sorunlar
- **R-1 [YÜKSEK] Telefonda ana-ayrıntı akışı bozuk.** Kuyruk (5 kart) + 3 ayrıntı kartı + karar kartı tek sütunda ≈ 3900 px; karar bölümü 2900 px aşağıda. Karta dokununca `scrollIntoView` ile aşağı atlar ama "listeye dön" yok. Kanıt `reports-390-light.png`. Düzeltme: <960 px'te ayrıntı tam ekran çekmece/sayfa (üstte geri oku, altta yapışkan "Kararı uygula"), ya da kartı sekmelerle (Özet / Bağlam / Karar) böl.
- **R-2 [YÜKSEK] "Seçili" = kırmızı.** Seçili kart pembe zemin + kırmızı çerçeve; "Reddet" (zararsız) seçildiğinde de kırmızı çerçeve; "Kullanıcı" hedef rozeti de kırmızı. Kırmızı hem "seçili" hem "tehlike" demek. Seçili için nötr vurgu (primary çizgisi + onay işareti), tehlike yalnız "Kullanıcıyı askıya al".
- **R-3 [YÜKSEK] Ham sayı etiketleri.** "Öncelik 120", "3 raporlayan", "Bu hedefe 2 rapor": öncelik formülü (açık raporlayan x10, gizliyse +100) yalnız kodda yazılı. Öneri: "Acil/Yüksek/Normal" + simge + tek cümle ("3 farklı kişi şikâyet etti; içerik otomatik gizlendi").
- **R-4 [ORTA] Telefonda klavye kısayolu satırı** (j k, 1-4, Ctrl+Enter) anlamsız; `(pointer: coarse)` altında gizle.
- **R-5 [ORTA] Karar sonucu açık değil.** Onay metni: "101 numaralı rapor için “Kullanıcıyı askıya al” uygulanacak. Aynı hedefe ait tüm açık raporlar birlikte kapanır." Rapor numarası kullanıcı için anlamsız; "ne olacak" cümlesi eksik: kullanıcı bildirim alır mı, oturumu kapanır mı, "İçeriği gizle" sonradan "Gizlenen içerik" sayfasından geri alınabilir mi. Kart altındaki küçük ipucu onayda tekrar edilmeli, riskli kararda ek sonuç satırı.
- **R-6 [ORTA] "Karar nedeni: Belirtme"** belirsiz: "Belirtme" ne anlama geliyor? Alanın kullanıcıya gösterilip gösterilmediği ipucunda yok. "Neden seçilmedi" + yanında "Kullanıcıya gönderilen bildirimde görünür" ipucu.
- **R-7 [ORTA] Aynı rozet iki kez**: "Taciz" hem neden hem neden-kodu olarak (kartta ve bağlam kartında) görünür. Eşitse birini gizle.
- **R-8 [ORTA] Ham "ACTIVE"** hesap durumu (TargetPreview `StatusPill`).
- **R-9 [ORTA] Bağlam kartında iç içe kaydırma:** şikâyet edilen mesaj kutusu sabit yükseklikte kırpılıyor (görsel ve uzun metin yarım, `reports-1280-light.png`); "Çevre mesajlar" listesi sabit yükseklikte kırpılıyor.
- **R-10 [ORTA] Toplu seçim kutusu 20x20**; seçimde satır tıklaması ile kutu ayrı, hangisinin ne yaptığı belli değil.
- **R-11 [DÜŞÜK] "Sohbette aç" / kullanıcı bağlantıları** 20-24 px yükseklik; kırmızı bağlantı (X-5).
- **R-12 [DÜŞÜK] Sekmelerde sayı yok** ("Açık (5)"); `Çözüldü` sekmesinde karar rozeti yeşil "Reddet" gibi tersi anlamda olabilir.
- **R-13 [DÜŞÜK] Tarih 4.47:1, en küçük yazı 11.2 px** (rozetler).
- **R-14 [DÜŞÜK] 768 px'te tek sütun**; 768 geniş tabletlerde iki sütun (liste + ayrıntı) için yer var.
- Boş durum: "Bekleyen rapor yok / Yeni raporlar geldiğinde burada görünür." Anlaşılır. Hata durumu: `ErrorState` + "Tekrar dene" iyi.

Görselleştirme önerisi (mevcut API yeterli olanlar)
- Üst özet şeridi (`ReportsPage.tsx` başlık altı, ~satır 252-273 civarı): "Bekleyen 5 · en acil 120 · en eski 3 gün" üç büyük sayı; kaynak: yüklenen `items` (sunucu toplam sayı vermiyor; "20+" gösterilir; **tam toplam için backend gerekir**).
- Hedef türüne göre yatay çubuk veya halka (kullanıcı/mesaj/gönderi...): `countByTarget(items)` zaten hesaplanıyor (satır 168).
- Günlük gelen rapor sparkline'ı: sayfa verisinde yok; `/api/admin/analytics` içinde rapor serisi var mı bilinmiyor, bulunamadı: **backend gerekir**.

Aranabilir öğeler (arama dizini için ham liste)
| Başlık | Eş anlamlılar | Tür |
|---|---|---|
| Raporlar | şikâyetler, bildirimler, ihbar, kötüye kullanım | page |
| Açık raporlar sekmesi | bekleyen, çözülmemiş | section |
| Çözülen raporlar sekmesi | karara bağlanan, geçmiş raporlar | section |
| Sıralama | öncelik sırası, önce en yeni, önce en eski | field |
| Hedef türü filtresi | kullanıcı/mesaj/gönderi/topluluk/etkinlik filtre | field |
| CSV indir (raporlar) | dışa aktar, excel, liste indir | action |
| Toplu karar | çoklu rapor, hepsini reddet, seçilenlere uygula | action |
| Raporlanan içerik önizlemesi | önizleme, görsel, metin | section |
| Şikâyet ayrıntısı ve bağlamı | bağlam, çevre mesajlar, ilişkili şikâyetler, sohbette aç | section |
| Karar: Reddet | yersiz rapor, kapat, dokunma | action |
| Karar: İçeriği gizle | gizle, kaldır, yayından al | action |
| Karar: Uyar | uyarı gönder, ikaz | action |
| Karar: Kullanıcıyı askıya al | banla, hesabı dondur, askıya al | action |
| Karar nedeni | sebep kodu, taciz, spam, cinsel içerik, telif | field |
| Hazır neden şablonları | karar nedeni şablonu, hazır metin | section |
| Uyarı mesajı | kullanıcıya mesaj | field |
| Askıya alma nedeni | askı sebebi, zorunlu | field |
| Kararı uygula | onayla, çöz | action |
| Klavye kısayolları | j k, 1-4, ctrl enter | section |
| Sohbette göster / Sohbette aç | mesajı gör | action |
| Kullanıcı sayfasını aç | profil, kullanıcı detay | action |

### 3.2 Sohbet medyası ve mesajlar (`/admin/chat-feed`)  [puan a1 b2 c2, iş L]

Kaynak: `ChatFeedPage.tsx` (79) + `chat/FeedParts.tsx`, `ReasonGate.tsx`, `ChatBubble.tsx`, `MessageActions.tsx`, `MessageBulkBar.tsx`.
Kanıt: `chat-feed-390-light.png` (sebep diyaloğu), `chat-feed-media-{390,768,1280}-*.png`, `chat-feed-messages-390-light.png`, `chat-feed-error-390-light.png`.
Ölçüm: Mesajlar sekmesi 390 px'te belge yatay taşması **321 px** (sayfa 711 px genişliğe uzuyor), en küçük yazı 9.6 px.

Sorunlar
- **C-1 [KRİTİK] Mesajlar sekmesi telefonda yatay taşıyor.** `.feedHead` / `.convTitle` ("Gönderen → Grup adı") satırı kırılmıyor (`chat.module.css`, ölçüm: öğe 29..711 px). Tüm sayfa küçülerek görünür/yan kayar; üst çubuk kayar. Kanıt `chat-feed-messages-390-light.png`. Düzeltme: `min-width:0; overflow-wrap:anywhere` + başlığı iki satıra böl (gönderen / → sohbet).
- **C-2 [YÜKSEK] İki ardışık engel.** Önce zorunlu sebep diyaloğu, sonra "Önce bir süzgeç seçin" boş durumu (sunucu süzgeçsiz akışı reddeder, `FEED_FILTER_REQUIRED`). Çocuk için "neden hiçbir şey yok?" Öneri: tek kart, iki adım: "1) Neden bakıyorsun? 2) Kimin sohbeti?"; süzgeç yokken ilk alan kullanıcı arama.
- **C-3 [YÜKSEK] İstatistik kartları bozuk.** Rakam kartın altında, başlık üstte (2 satırlı başlıklarda yarım kart boşluk); "7.57 GB" iki satıra bölünür ve ondalık nokta (X-4, X-9). Altı kart ham sayı yığını; anlam yok ("Silinmiş mesaj ekleri", "Süresi dolan" ne demek?).
- **C-4 [YÜKSEK] Medya ızgarası düzensiz.** Kartlar farklı yükseklik; "Saklama süresi doldu" yer tutucusu 1280 px'te kart çizgisinin dışına taşıyor (`chat-feed-media-1280-light.png`); video/tek gönderimlik rozeti görselin altında yer değiştiriyor. Sabit en-boy oranlı kare kutu + rozet görselin üst köşesine.
- **C-5 [ORTA] Jargon:** "Süzgeç", "Gölge engelli", "Tek gönderimlik", "Sohbet no", "Silinmiş mesaj ekleri", "Süresi dolan", "İletilmedi", "Alıcıya iletilmedi (engel)". Sade karşılık: "Filtre", "Engellendiği için karşıya gitmedi", "Bir kez bakılabilen", "Sohbet numarası → sohbet adı ara".
- **C-6 [ORTA] Mesaj seçme kutusu 13 px**, "İşlemler" düğmesi 40 px; toplu seçim modu açıkça "Toplu seçim" olarak yok (kutular önceden görünüyor).
- **C-7 [ORTA] "Sohbette göster" bağlantısı 24-34 px yükseklik.**
- **C-8 [ORTA] İstatistik hatası sessiz.** `chatMediaStats` hata verirse kartlar "—" kalır, hata mesajı/yeniden dene yok (`ChatFeedPage.tsx` yalnız `stats.isLoading` kullanıyor). Hata görüntüsü: `chat-feed-error-390-light.png` (kapının arkasında ayrıntı yok).
- **C-9 [ORTA] 1280 px'te "Bitiş" alanı ikinci satıra düşüyor**; filtre ızgarası 4+1 dengesiz.
- **C-10 [ORTA] Gönderen iki kez:** başlıkta avatar+ad, balonda yine ad+saat; satır başına ~120 px gereksiz.
- **C-11 [DÜŞÜK] 9.6 px yazı** (rozet/alt bilgi), "Sebebi değiştir" ghost 40 px.
- **C-12 [DÜŞÜK] "Bu erişim denetim kaydına yazılır"** sayfa üstünde sönük satır; önem verilmeli (kilit simgesi + kalın).
- İyi: sebep diyaloğu çok anlaşılır (hazır şablon çipleri, 20 karakter sayacı), `chat-feed-390-light.png`.

Görselleştirme önerisi
- İstatistik: "Toplam 19.323 medya (görsel %95, video %5)" tek halka + büyük sayı; "Son 24 saatte +224" trend oku; boyut için ilerleme çubuğu (veri: `AdminMediaStats`: `imageCount, videoCount, viewOnceCount, deletedMessageMediaCount, purgedCount, totalBytes, last24h`). Günlük seri yok: sparkline için **backend gerekir**.
- Medya ızgarasında tarih başlıkları ("Bugün / Dün") gruplama; veri mevcut (`createdAt`).

Aranabilir öğeler
| Başlık | Eş anlamlılar | Tür |
|---|---|---|
| Sohbet medyası ve mesajlar | sohbet izleme, mesajlaşma denetimi, fotoğraf video, özel yazışma | page |
| Görüntüleme sebebi | neden bakıyorsun, gerekçe, denetim kaydı, sebep yaz | action |
| Sebebi değiştir | gerekçeyi yenile | action |
| Medya sekmesi | fotoğraf, video, görseller | section |
| Mesajlar sekmesi | mesaj akışı, yazışmalar | section |
| Tür filtresi (görsel/video) | tür | field |
| Kullanıcı süzgeci | kişi ara, e-posta, ad | field |
| Sohbet no | sohbet numarası, konuşma id | field |
| Başlangıç / Bitiş tarihi | tarih aralığı | field |
| Tek gönderimlik (bir kez bakılan) | kaybolan medya, view once | field |
| Silinmiş mesaj | silinen, kullanıcı sildi | field |
| Gölge engelli | engellendi, iletilmedi, suppressed | field |
| Medya var | ekli mesajlar | field |
| Süzgeçleri sıfırla | filtreyi temizle | action |
| Mesajı gizle / geri göster / kalıcı sil | moderasyon, kaldır | action |
| Seçilenleri gizle (toplu) | çoklu gizle, 200 mesaj | action |
| İstatistik: toplam boyut | depolama, GB | section |
| Sohbette göster | konuşmayı aç | action |

### 3.3 Gönderiler (`/admin/posts`)  [puan a1 b3 c3, iş M]

Kaynak: `PostsAdminPage.tsx` (231) + `posts/PostParts.tsx`, `PostDetail.tsx`, `FeedContentMedia.tsx`.
Kanıt: `posts-{390,768,1280}-*.png`, `posts-detail-390-light.png`, `posts-error-390-light.png`, `posts-empty-*`.
Ölçüm: 390 px'te belge yatay taşması **133 px** (sayfa 523 px'e genişliyor).

Sorunlar
- **P-1 [KRİTİK] Telefonda yatay taşma + yazar adı harf harf dikey.** Satır başlığındaki (`.rowHead` / `.author`) uzun e-posta (`mehmet.kaya.cok.uzun…@bingol.edu.tr`) kırılmıyor; kendi yan elemanı olan ad ("Mehmet Kaya Cok Uzun…") 1 harf genişliğe sıkışıp her harf alt alta yazılıyor. Kanıt `posts-390-light.png` (3. kart). Düzeltme: `.author {display:grid; min-width:0}`, e-posta `overflow-wrap:anywhere`/kırp, rozetler ayrı satır.
- **P-2 [KRİTİK] Detay çekmecesi telefonda kapatılamıyor.** Aynı taşma yüzünden çekmece 523 px'e yaslanıyor; başlıkta kapatma (X) görünmüyor, içerik ("2 şikâyet" rozeti, şikâyet satırı) sağdan kesik (`posts-detail-390-light.png`). Kısmen P-1'in sonucu olabilir; çekmeceye ayrıca `max-width:100vw` ver.
- **P-3 [YÜKSEK] Gizle / Düzenle / Sil üçlüsü.** 40 px yüksekliğinde üç düğme yan yana, "Sil" dolu kırmızı hemen "Gizle"nin yanında; yanlış dokunma kolay. "Sil: 30 gün sonra kalıcı silinir, yazara bildirim gider" cümlesi yalnız onay diyaloğunda; satırda "Gizle geri alınabilir, Sil alınamaz" ayrımı yok. Öneri: "⋯ İşlemler" menüsü veya Sil'i ayrı ve ghost yap (X-6).
- **P-4 [YÜKSEK] Filtre bloğu 8 alan ≈ 600 px** ve sayfa üstünde iki uzun açıklama paragrafı (başlık + denetim notu) ≈ 8 satır; ilk gönderi ekranın 3. ekranında (X-3). "Yazar numarası", "En az açık şikâyet" jargon (X-7).
- **P-5 [ORTA] İstatistik kartları dengesiz:** "Son 24 saat: 64 gönderi" ipucu yalnız ilk kartta, değer hizası kayıyor ("98.234" kartın altına iner), 5. kart tek başına (`posts-390-light.png`).
- **P-6 [ORTA] Ham "INAPPROPRIATE"** çekmece şikâyet listesinde (çevrilmemiş neden kodu); `admin.reports.reason.*` anahtarı var, kullanılmıyor.
- **P-7 [ORTA] Önizleme küçük (64 px)** ve detay çekmecesinde görsel büyütme akışı farklı; hızlı karar için büyük önizleme + yanında düğmeler.
- **P-8 [ORTA] Durum rozetleri tutarsız:** "Gizli" sarı, "Silinmiş" kırmızı, "Düzenlendi" gri, "2 şikâyet" kırmızı; kırmızı hem şikâyet hem silinmiş. Simge + renk sistemi.
- **P-9 [DÜŞÜK] Beğeni sayısı tek başına;** "128 beğeni" şikâyetle ilişkisi yok; sıralama (en çok şikâyetli) yok (API: `minReports` filtresi var, sıralama yok).
- Boş/hata: "Gönderi bulunamadı" ve "Veriler yüklenemedi" iyi.

Görselleştirme önerisi
- Üstte "Şikâyetli 7 gönderi bekliyor" kırmızı vurgulu büyük sayı + tıklayınca `minReports=1` filtresi (veri: `openReportedCount`).
- "Yayında / Gizli / Silinmiş" tek yığılmış çubuk (`postCount, hiddenCount, deletedCount`); 24 saat farkı için trend oku ("bugün +64"). Günlük seri: **backend gerekir**.

Aranabilir öğeler
| Başlık | Eş anlamlılar | Tür |
|---|---|---|
| Gönderiler | keşfet gönderileri, paylaşımlar, fotoğraf paylaşımı | page |
| Gönderi istatistikleri | toplam gönderi, beğeni, medya, gizli, şikâyetli | section |
| Durum filtresi (yayında/gizli/silinmiş) | durum | field |
| Metin veya yazar ara | gönderi ara, yazar adı, e-posta | field |
| Yazar numarası | yazar id, kullanıcı numarası | field |
| En az açık şikâyet | şikâyetli gönderiler, şikayet sayısı | field |
| Başlangıç / Bitiş tarihi | tarih aralığı | field |
| Medyalı | fotoğraflı, görselli | field |
| Süzgeçleri sıfırla | filtre temizle | action |
| Gönderi ayrıntısı | detay, şikâyetler, denetim kaydı | action |
| Gönderiyi düzenle | metni değiştir, 7 kelime | action |
| Gönderiyi gizle | akıştan kaldır, geri açılabilir | action |
| Gönderiyi geri aç | yeniden yayınla, gizlemeyi kaldır | action |
| Gönderiyi sil | kalıcı sil, 30 gün | action |
| Silme gerekçesi | yazara bildirilir | field |
| Denetim kaydı bağlantısı | log, kim ne yaptı | action |

### 3.4 Anketler (`/admin/polls`)  [puan a2 b3 c3, iş L]

Kaynak: `PollsAdminPage.tsx` (234) + `polls/PollDetail.tsx`, `PollForm.tsx`, `pollsLogic.ts`.
Kanıt: `polls-{390,768,1280}-*.png`, `polls-detail-390-light.png`, `polls-form-390-*.png`, `polls-select-390-{light,dark}.png`, `polls-empty-*`, `polls-error-*`.
Ölçüm: yatay taşma yok (tablo kendi içinde kayıyor), 9-16 küçük hedef.

Sorunlar
- **PL-1 [YÜKSEK] Telefonda tablo okunamıyor.** Başlık sütunu 3 harfli parçalara kırılıyor ("Yemekh/ane/menusu/nu nasil…"), "Durum / Oy / Kapanış" sütunları ekran dışı (X-1). Kanıt `polls-390-light.png`.
- **PL-2 [YÜKSEK] Detay çekmecesi telefonda sağa taşıyor:** açıklama, "Oy hakkı olan" kartı ve sonuç çubukları kesik (`polls-detail-390-light.png`); "Katılım %32" kartı tek başına, oy çubuklarında yüzde/sayı görünmüyor (kesik).
- **PL-3 [YÜKSEK] Anket başlığı kalın kırmızı bağlantı** (hata rengi), tıklanabilir ama "tehlikeli" izlenimi (X-5).
- **PL-4 [YÜKSEK] Toplu işlem çubuğu.** (a) "Seçimi temizle" ghost düğmesi **açık temada görünmez** (ölçülen kontrast 1.00:1, koyu çubukta koyu yazı; koyuda görünür, `polls-select-390-light.png` vs `-dark.png`). (b) Çubuk sayfa altına yapışıyor ve listeyi örtüyor. (c) "Seçilenleri iptal et" ve "Seçilenleri sil" aynı kırmızı, yan yana; "iptal" (oylar korunur) ile "sil" (oylar silinir) farkı yalnız onay diyaloğunda. Diyalog sonuç yazıyor (iyi), düğme etiketinde yok.
- **PL-5 [ORTA] 7 istatistik kartı ham sayı:** "Toplam anket 38 / Açık 5 / Kapalı 29 / Taslak 2 / İptal 2 / Toplam oy 24.310 / Ort. katılım 27,4%". 2 sütunda son kart yalnız. Halka+yığılmış çubuk (X-4).
- **PL-6 [ORTA] "Menü puanlamaları" bir filtre düğmesi** (aria-pressed) ama etiket eylem gibi okunuyor; "Yalnız yemek puanları" etiketi + seçili durumu onay işaretiyle.
- **PL-7 [ORTA] Form (Anket oluştur) çok uzun** (başlık, açıklama, tür, sonuç görünürlüğü, açılış, kapanış, 3 onay kutusu, seçenekler, hedef kitle...) tek kaydırma; "Taslak olarak kaydet" onay kutusu en altta; "Gizli oy" onay kutusu açıklaması (ipucu) kısaltılmış. Adımlı form veya bölüm başlıkları.
- **PL-8 [ORTA] Durum etiket seti karışık:** "Zamanlanmış/Açık/Kapalı/Taslak/İptal" (durum) + "Gizli oy" + kapsam + tür: tabloda 5 ayrı sütun; kart modunda tek satır cümle ("Genel anket, tek seçim, 1 Kasım'da kapanıyor").
- **PL-9 [DÜŞÜK] Sayfalama düğmeleri 40x40, satır onay kutuları 18 px** (X-2); sayfalama "5" toplam öğe soluk, ne olduğu belirsiz ("5 kayıt").
- **PL-10 [DÜŞÜK] Kapanış tarihi iki satıra bölünüyor** ("1 Kas / 2026 / 02:00").
- İyi: sonuç çubukları + "Gizli oy: kimin ne seçtiği gösterilmez" güvenceli cümle; kapat/iptal/sil diyaloglarında sonuç cümlesi ("Kapatılan anket yeniden açılamaz") çok iyi.

Görselleştirme önerisi
- Liste satırında mini katılım çubuğu (oy / hak sahibi, `turnout` yalnız detayda; listede yok → **liste için backend gerekir**); listede yalnız `totalVotes` var: oy sayısına göre küçük yatay çubuk.
- Üst özet: "5 anket açık, ortalama katılım %27" cümle + halka (`open/closed/draft/cancelled`).
- Detayda sonuç çubuğu (zaten var) + kazanan vurgusu ("Grup A %50 ile önde") yorum cümlesi.

Aranabilir öğeler
| Başlık | Eş anlamlılar | Tür |
|---|---|---|
| Anketler | oylama, seçim, yemek puanı, anket listesi | page |
| Anket oluştur | yeni anket, oylama başlat | action |
| Anket istatistikleri | toplam, açık, kapalı, taslak, katılım oranı | section |
| Başlıkta ara | anket ara | field |
| Kapsam filtresi (genel/kulüp/yemek) | kapsam | field |
| Durum filtresi | açık, kapalı, taslak, iptal, zamanlanmış | field |
| Menü puanlamaları | yemek puanı, yemekhane değerlendirme | action |
| Anket ayrıntısı | sonuçlar, oy dağılımı, katılım | section |
| Anketi düzenle | değiştir | action |
| Oylamayı kapat | sonlandır, bitir | action |
| Anketi iptal et | vazgeç | action |
| Anketi sil | kalıcı sil | action |
| CSV dışa aktar (anket) | indir, excel | action |
| Seçilenleri kapat/iptal et/sil (toplu) | çoklu işlem | action |
| Anket türü | tek seçim, çoklu, puanlama 1-5, sıralı | field |
| Sonuç görünürlüğü | sonuçlar ne zaman görünür | field |
| Gizli oy | anonim, kimlik gizli | field |
| Oy değiştirilebilsin | oyu geri al | field |
| Açıldığında bildirim gönder | push, haber ver | field |
| Hedef kitle (fakülte/bölüm/sınıf) | kime açık | field |
| Açılış / Kapanış tarihi | zamanlama | field |
| Taslak olarak kaydet | yayınlama | field |

### 3.5 Yasaklı görseller (`/admin/moderation/blocklist`)  [puan a4 b4 c2, iş M]

Kaynak: `BlocklistPage.tsx` (162).
Kanıt: `blocklist-{390,768,1280}-*.png`, `blocklist-empty-*`, `blocklist-error-*`.
Ölçüm: yatay taşma yok.

Sorunlar
- **B-1 [YÜKSEK] "SHA-256 özeti" kimse için anlamlı değil.** Yönetici 64 karakterlik özeti nereden bulacak? Sayfada anlatım yok, `PageHeader`'da açıklama yok. Öneri: "Görseli seç → özet otomatik hesaplanır" (tarayıcıda `SubtleCrypto.digest`, API aynı: `POST {sha256, note}`); raporlardaki görselden doğrudan "Bu görseli yasakla" kısayolu. Başlık altı açıklama: "Buraya eklenen görseller bir daha yüklenemez."
- **B-2 [YÜKSEK] Liste yalnız 64 karakter kod:** görsel yok (özet tek yönlü; görsel saklanmıyor, bu bir veri sınırı), iki satıra bölünen monospace; hangi görselin yasaklandığı notla anlaşılır. Not alanı isteğe bağlı: "Neden yasaklandı?" zorunlu ya da öneri çipleri.
- **B-3 [ORTA] "Kaldır" her satırda dolu kırmızı (X-6); 63x40; "Kopyala" 40x40.**
- **B-4 [ORTA] "Ekleyen: #1"** kimlik (isim yok; API `createdBy` sayı: ad için **backend gerekir**).
- **B-5 [ORTA] Eklenen özetin sonucu yazmıyor:** "Listeye ekle" sonrası "Bu görsel artık yüklenemez; mevcut yüklemeler silinmez" cümlesi yok (kaldırma diyaloğunda yalnız "aynı görsel yeniden yüklenebilir").
- **B-6 [DÜŞÜK] Boş durum iyi ama eylemsiz** ("Liste boş / Henüz yasaklı bir görsel özeti eklenmedi") — forma kaydıran düğme.
- İyi: form alanı doğrulama cümlesi ("Özet 64 onaltılık karakterden oluşmalıdır").

Görselleştirme: tek büyük sayı "2 yasaklı görsel" + "son 30 günde X engellenen yükleme" (**bu sayaç API'de yok: backend gerekir**).

Aranabilir öğeler
| Başlık | Eş anlamlılar | Tür |
|---|---|---|
| Yasaklı görseller | engelli resimler, blocklist, kara liste, hash | page |
| Özet ekle | görsel yasakla, yasak listesine ekle | action |
| SHA-256 özeti | hash, parmak izi, görsel kodu | field |
| Not (isteğe bağlı) | açıklama, sebep | field |
| Listeye ekle | kaydet | action |
| Özeti kopyala | kodu kopyala | action |
| Özeti kaldır | yasağı kaldır, izin ver | action |

### 3.6 İhlaller (`/admin/moderation/strikes`)  [puan a2 b3 c2, iş M]

Kaynak: `StrikesPage.tsx` (228), `moderation/p11Logic.ts`.
Kanıt: `strikes-{390,768,1280}-*.png`, `strikes-forgive-390-*.png`, `strikes-empty-*`, `strikes-error-390-light.png`.

Sorunlar
- **S-1 [YÜKSEK] Telefonda "Karar / Tarih / Durum / Affet" sütunları ekran dışı** (X-1); sayfanın tek eylemi ("Affet") görünmez. Kanıt `strikes-390-light.png`.
- **S-2 [YÜKSEK] 6 filtre alanı alt alta ≈ 520 px** (X-3); varsayılan "Sayılanlar" ama tarihler boş ve yer kaplıyor.
- **S-3 [YÜKSEK] Jargon, yorum cümlesi yok.** "İhlal", "Sayılıyor", "Sayılanlar/Sayılmayanlar", "Kullanıcı kimliği", açıklama "Sayılan ihlal sayısı, tekrarlayan ihlal önerisini belirler". Çocuk için: "Kural ihlali kaydı. Bir kişi 3 kez ihlal ederse askıya alma önerilir (Askı önerileri sayfası). Yanlış kararı 'Affet' ile silebilirsin." (eşik değeri API'de yok: **backend gerekir**).
- **S-4 [ORTA] Hangi rapordan geldiği yok.** `reportId` alınıyor ama gösterilmiyor (satır bağlantısı "Rapor #101" olmalı).
- **S-5 [ORTA] Affet geri alınamaz** ama satırdaki düğme sıradan ikincil düğme; diyalog uyarısı iyi (`strikes-forgive-390-light.png`: kırmızı kutu, "Bu işlem geri alınamaz", sebep zorunlu).
- **S-6 [ORTA] Kullanıcı hücresi:** kırmızı bağlantı + 3 satıra bölünen e-posta; kimliksiz satır "Kullanıcı #13 / #13" tekrar.
- **S-7 [DÜŞÜK] "İptal (itiraz kabulü)", "Affedildi", "Sayılıyor"** rozet renk/simge tutarsız (sarı/yeşil/gri) — kullanıcı sayısı için tek cümle yeterli.
- Boş/hata: "İhlal kaydı yok / Süzgeçlere uyan ihlal bulunamadı." anlaşılır; hata iyi.

Görselleştirme (mevcut API: sayfalı satırlar; toplamlar yok)
- Üstte: "Şu an sayılan ihlal: N" büyük sayı (`total` filtreli; durum=Sayılanlar iken doğru).
- En çok ihlali olan 5 kişi yatay çubuk (yüklenen satırlardan `userId` grupla; yalnız ilk sayfa olduğunu belirt).
- Karar türü dağılımı halkası (uyarı/gizleme/askı) satırlardan.

Aranabilir öğeler
| Başlık | Eş anlamlılar | Tür |
|---|---|---|
| İhlaller | strike, kural ihlali, ceza puanı, uyarı geçmişi | page |
| Kullanıcı kimliği filtresi | kişi, id | field |
| Durum (Sayılanlar/Sayılmayanlar/Tümü) | aktif ihlal, affedilen | field |
| İçerik türü / Karar filtresi | uyarı, gizleme, askıya alma | field |
| Başlangıç / Bitiş tarihi | tarih | field |
| İhlali affet | cezayı sil, geri al, ihlal puanını düşür | action |
| Af sebebi | gerekçe | field |
| İhlal listesi | tablo | section |

### 3.7 Gizlenen içerik (`/admin/moderation/hidden`)  [puan a2 b3 c3, iş M]

Kaynak: `HiddenContentPage.tsx` (202).
Kanıt: `hidden-{390,768,1280}-*.png`, `hidden-empty-*`, `hidden-error-*`.

Sorunlar
- **H-1 [YÜKSEK] Telefonda "Gizleyen / Gizlenme / Geri al" ekran dışı** (X-1); metin önizlemesi 4 harflik sütunda ("Hemen/tıkla/kazan Bu…") kırpılıyor.
- **H-2 [YÜKSEK] 1280 px'te görsel önizleme 230x290 px**, tek satır ~300 px; metin önizlemesi sabit yükseklikte yarım ("tasirmaya calisir:" kesik) (`hidden-1280-dark.png`). Önizleme 96 px küçük resim; tıklayınca büyüt; metin 3 satır + "devamı".
- **H-3 [ORTA] Jargon:** "Otomatik (eşik)" (kaç şikâyette? hangi eşik?), "Yönetici kararı", "Önizleme yok", "İçerik artık yok", sağda sıkışık küçük gri gerekçe ("Bu tür geri alınamaz; yalnız yönetici kararıyla gizlenir.") okunmuyor.
- **H-4 [ORTA] "Geri al" belirsiz** (neyi?); "Yeniden yayına al" ve satırda sonuç ipucu (diyalogda var).
- **H-5 [ORTA] Filtre yığını 4 alan** (X-3).
- **H-6 [DÜŞÜK] Sahibi bağlantısı kırmızı + 2 satır, hedef 43 px** (X-5).
- Boş durum "Gizlenen içerik yok / Süzgeçlere uyan…" iyi.

Görselleştirme: "3 içerik gizli: 2 yönetici, 1 otomatik" halka (`hiddenBy`), tür çubuğu; "En eskisi 8 gün önce gizlendi" cümlesi (`hiddenAt`).

Aranabilir öğeler
| Başlık | Eş anlamlılar | Tür |
|---|---|---|
| Gizlenen içerik | gizli, kaldırılan içerik, yayından alınan | page |
| İçerik türü filtresi | gönderi, mesaj, profil fotoğrafı | field |
| Gizleyen filtresi (otomatik/yönetici) | kim gizledi | field |
| Başlangıç / Bitiş tarihi | tarih | field |
| Geri al (yeniden yayına al) | gizlemeyi kaldır, tekrar göster | action |
| Önizleme | içerik önizleme | section |

### 3.8 Karar şablonları (`/admin/moderation/reason-templates`)  [puan a2 b4 c3, iş S]

Kaynak: `ReasonTemplatesPage.tsx` (260).
Kanıt: `reason-templates-{390,768,1280}-*.png`, `reason-templates-modal-390-*.png`, `reason-templates-empty-*`, `reason-templates-error-*`.

Sorunlar
- **T-1 [YÜKSEK] Telefonda tablo:** "Metin" sütunu kesik, "Durum / Sıra / Düzenle / Sil" ekran dışı (X-1).
- **T-2 [ORTA] Adlandırma:** menü "Karar şablonları" ≠ sayfa başlığı "Karar nedeni şablonları" ≠ Destek'te "Hazır yanıtlar > Şablon ekle" (X-8).
- **T-3 [ORTA] "Kod" (SPAM_ADS) teknik;** çocuk ne işe yaradığını anlamaz. Kod otomatik üretilebilir ("Başlıktan"); formda ipucu var ("Sonradan değişmez") ama neden gerektiği yok.
- **T-4 [ORTA] "EN: var · AR: Türkçe"** belirsiz ("AR: Türkçe" = Arapça yoksa Türkçe gösterilir). "İngilizce ✓ · Arapça yok (Türkçe gösterilir)".
- **T-5 [ORTA] Modal 7 alan** (kod, TR, EN, AR, sıra, etkin) telefonda ~1100 px; alt çubuk kaydırmayla birlikte iniyor olabilir (`reason-templates-modal-390-light.png` yalnız ilk 5 alanı gösteriyor; alt kısım doğrulanamadı). Dil alanlarını sekmelere/Gelişmiş bölümüne.
- **T-6 [DÜŞÜK] "Sıra" sayısı** kullanıcıya soyut; sürükle-bırak veya ▲▼ (API `sortOrder`).
- İyi: sayfa sonunda mavi bilgilendirme çubuğu "Bu metinler kullanıcıya bildirim olarak gider" yorum cümlesi örnek.

Görselleştirme: gerek yok (küçük liste); sayaç "2 / 50 şablon" ilerleme çubuğuna dönüşebilir.

Aranabilir öğeler
| Başlık | Eş anlamlılar | Tür |
|---|---|---|
| Karar nedeni şablonları | hazır sebep, karar şablonu, red nedeni metni | page |
| Şablon ekle | yeni şablon | action |
| Şablonu düzenle | metni değiştir | action |
| Şablonu sil | kaldır | action |
| Kod | şablon adı | field |
| Türkçe / İngilizce / Arapça metin | çeviri, dil | field |
| Sıra | sıralama | field |
| Etkin (kararlarda seçilebilir) | aktif, pasif | field |
| Şablon sayısı sınırı (50) | limit | section |

### 3.9 Uygunsuz ifade filtresi (`/admin/profanity`)  [puan a4 b3 c2, iş M]

Kaynak: `ProfanityPage.tsx` (350).
Kanıt: `profanity-{390,768,1280}-*.png`, `profanity-empty-*`, `profanity-error-*`.

Sorunlar
- **PR-1 [YÜKSEK] Sayfa sırası ters.** Bilgi kartı → istatistik → alan dağılımı → "Metni dene" → sekmeler → "Kelime ekle" (2 form) → arama + dışa aktarma → **liste en altta** (≈ 2000 px aşağıda, `profanity-390-light.png`). Asıl iş (listeyi görmek/silmek) en son.
- **PR-2 [YÜKSEK] Sekmeler (Engellenen/İzin verilen) yanlış yerde:** "Metni dene" aracından sonra, ekleme formu ve listeyi değiştirir; hangi bölümü etkilediği belli değil.
- **PR-3 [YÜKSEK] Teknik bilgi kartı:** "Yerleşik liste: 830 kelime (tr 412, en 288, ar 130) · kaynak: profanity-words.txt", "mod ENGELLE (yalnızca okunur; app.moderation.profanity.*)", `FeedPost / text`, `AppUser / displayName`. Yapılandırma anahtarı ve dosya adı yöneticiye anlamsız (X-12). Öneri: "Filtre açık. Yasaklı kelimeyi yazan kullanıcıya hata gösterilir." + "Bu hafta 96 deneme engellendi (en çok gönderi metninde)".
- **PR-4 [ORTA] İstatistik:** iki kart eşit değil (telefonda ikincisi dar), "24 saat 14 / 7 gün 96" yorumsuz (günlük ortalama 13,7: normal mi artış mı?).
- **PR-5 [ORTA] "Ekle" düğmesi "Toplu ekle (satır başına bir kelime)" etiketine yapışık** (form arası boşluk yok).
- **PR-6 [ORTA] "Sil" dolu kırmızı, 41x40** (X-6); onay diyaloğu var.
- **PR-7 [ORTA] "Metni dene" sonucu:** "Eşleşen kökler", "Sadeleştirilmiş metin" teknik; sonuç "Engellenir/Temiz" iyi ama renk+simge ile.
- **PR-8 [ORTA] "Kelime" ipucu** ("Düz kelime: kök + ek eşleşir. "=kelime" yalnız tam eşleşme, "*kelime" metin içinde geçme") kod söz dizimi; örnekli, iki satırlık açıklama + 3 çip örnek.
- **PR-9 [DÜŞÜK] "yönetici #1"** kimlik (isim yok).
- İyi: sade "Metni dene" aracı; boş durum "Kayıt yok / Yerleşik liste dışında yönetici tarafından eklenmiş kelime bulunmuyor" doğru.

Görselleştirme: (API `stats.last24h.total`, `last7d.total`, `byField`)
- 7 günlük alan dağılımı yatay çubuk ("Gönderi metni 40 · Profil adı 31 · Topluluk açıklaması 25"), üstte trend oku (bugün / 7 gün ortalaması). Günlük seri yok: sparkline için **backend gerekir**.
- Kelime sayıları (engelli/izinli, yerleşik/yönetici) küçük yığılmış çubuk.

Aranabilir öğeler
| Başlık | Eş anlamlılar | Tür |
|---|---|---|
| Uygunsuz ifade filtresi | küfür filtresi, yasaklı kelime, argo, hakaret | page |
| Yerleşik liste bilgisi | kaç kelime var, kaynak | section |
| Engellenen deneme istatistiği (24 saat / 7 gün) | kaç kez engellendi | section |
| Alan bazında dağılım | nerede engellendi | section |
| Metni dene | test et, deneme, kontrol | action |
| Engellenen sekmesi | yasaklı kelimeler | section |
| İzin verilen sekmesi | istisna, beyaz liste | section |
| Kelime ekle | yeni yasaklı kelime | action |
| Dil (tümü/TR/EN/AR) | | field |
| Not | | field |
| Toplu ekle | liste yapıştır, çoklu kelime | action |
| Ara (kelime listesi) | | field |
| Dışa aktar (CSV) | indir | action |
| Kelimeyi sil | kaldır | action |
| Filtre durumu (açık/kapalı, mod) | engelle işaretle | section |

### 3.10 Destek talepleri (`/admin/support/tickets`)  [puan a2 b4 c3, iş S]

Kaynak: `TicketsPage.tsx` (163), `support/Support.module.css`.
Kanıt: `tickets-{390,768,1280}-*.png`, `tickets-empty-*`, `tickets-error-*`.

Sorunlar
- **TK-1 [YÜKSEK] Telefonda "Durum" sütunu ekran dışı** ("Yanıt bekliyor" en önemli bilgi); kullanıcı/öncelik/güncelleme de (X-1). Kanıt `tickets-390-light.png`.
- **TK-2 [ORTA] Satır tıklanabilir ama işaret yok** (ok simgesi/"Aç"), klavye ve ekran okuyucu için `onRowClick` satırı.
- **TK-3 [ORTA] "Yalnızca herkese açık" onay kutusu** kit dışı yerel `<input>` (13x13, satır içi stil), anlamı belirsiz ("herkese açık" = hesapsız misafir talebi); etiket "Yalnız hesapsız (misafir) talepler".
- **TK-4 [ORTA] Öncelik sütunu çoğunlukla "—", atama "#1"** (kimlik); önceliği olmayan normal satırda "Normal" gizleniyor, acil sıralama yok (sıralama seçeneği yok).
- **TK-5 [ORTA] Özet yok:** "3 talep yanıt bekliyor, en eskisi 2 gün" (yüklenen satırlardan hesaplanabilir; toplam için **backend gerekir**).
- **TK-6 [DÜŞÜK] CSV düğmesi telefonda tam genişlik** üstte yer yiyor.
- Boş durum "Bu filtrede talep yok / Yeni destek talepleri geldiğinde…" iyi; hata iyi.

Görselleştirme: durum çubuğu (Yanıt bekliyor / Yanıtlandı / Kapalı) üstte tıklanabilir sayı kutuları (süzgeç görevi); "Acil 1, Yüksek 1" rozet sayıları.

Aranabilir öğeler
| Başlık | Eş anlamlılar | Tür |
|---|---|---|
| Destek talepleri | yardım talepleri, ticket, şikâyet kutusu, destek | page |
| Durum filtresi | yanıt bekliyor, yanıtlandı, kapalı | field |
| Yalnızca herkese açık | misafir talepler, hesapsız | field |
| CSV indir (talepler) | dışa aktar | action |
| Talep listesi | konu, kategori, kullanıcı, öncelik, atanan | section |

### 3.11 Talep ayrıntısı (`/admin/support/tickets/:id`)  [puan a4 b3 c3, iş M]

Kaynak: `TicketDetailPage.tsx` (480), `support/ChatThread.tsx`, `moderation/p11Logic.ts`.
Kanıt: `ticket-detail-{390,768,1280}-*.png`, `ticket-notes-*`, `ticket-detail-error-*`.
Ölçüm: telefonda taşma yok, küçük hedef 0 (iyi).

Sorunlar
- **TD-1 [YÜKSEK] Tehlikeli eylem yanlış yerde/yetersiz işaretli.** "Sil" (talebi **kalıcı** sil) "Talebi kapat" düğmesinin hemen yanında, soluk ghost metin olarak; yanlışlıkla "Kapat" yerine dokunulabilir. Diyalog güçlü (gerekçe + "SİL" yazdırma), ama konumlandırma: "Geri alınamaz işlemler" bölümüne al (Geri bildirim çekmecesinde zaten böyle).
- **TD-2 [YÜKSEK] Telefonda sıralama:** yazışma → yanıt kutusu → Öncelik/atama → Hazır yanıtlar. Hazır yanıtlar ve yanıt kutusu iki ekran arayla; "Yanıtla" düğmesi boşken soluk (neden pasif belli değil). Hazır yanıt çipleri kutunun hemen üstünde olmalı.
- **TD-3 [ORTA] Atama kimlik sayısıyla:** "Yönetici kimliği" kutusu + "Ata" düğmesi yan yana ve dikey hizasız (`ticket-detail-390-light.png`). `/admin/rbac/admins` uç noktası var (mock'ta görüldü): açılır listeden seç (**uç mevcut, ek backend gerekmez**; yetki `rbac.manage`'e bağlıysa SUPPORT için erişilemez, doğrulanamadı).
- **TD-4 [ORTA] Öncelik açılır listesi renksiz/simgesiz** ("Acil"); listede rozet var, detayda yok.
- **TD-5 [ORTA] Hazır yanıtlar yalnız bu tarayıcıda** (localStorage): başka bir destek görevlisi görmez; ekip paylaşımı için **backend gerekir**.
- **TD-6 [DÜŞÜK] Mesaj saati 4.47:1** (13 px, X-13). Dil: "Yanıt bekliyor" rozeti iyi.
- **TD-7 [DÜŞÜK] Başlık uzun konuda 3 satır;** üst çubuk ile çakışma görüntüsü fullPage kayması (ekran görüntüsü artefaktı olabilir, doğrulanamadı).
- İyi: sohbet balonu görünümü (kullanıcı/destek ekibi), "İç notlar müşteriye GÖRÜNMEZ" uyarısı, kapalı talep cümlesi ("Bu talep kapalı; yeni yanıt yazılamaz.").

Görselleştirme: üstte zaman çizgisi çipleri: "Açıldı 31 Eki → Yanıtlandı → Kapatıldı" ve "İlk yanıt süresi" büyük sayı (mesaj `createdAt` farkından hesaplanır, mevcut veri).

Aranabilir öğeler
| Başlık | Eş anlamlılar | Tür |
|---|---|---|
| Talep ayrıntısı | ticket detay, yazışma | page |
| Yazışma sekmesi | konuşma, mesajlar | section |
| İç notlar sekmesi | ekip notu, özel not | section |
| Yeni iç not ekle | not yaz | action |
| Yanıtınız (yanıt yaz) | cevapla, kullanıcıya yaz | field |
| Yanıtla | gönder | action |
| Talebi kapat | kapat, çözüldü | action |
| Yeniden aç | tekrar aç | action |
| Talebi kalıcı sil | sil, geri alınamaz | action |
| Öncelik | acil, yüksek, düşük | field |
| Atama (yönetici kimliği) | kime atandı, sorumlu | field |
| Atamayı kaldır | | action |
| Hazır yanıtlar | şablon, kayıtlı cevap | section |
| Yazdığımı şablon yap | taslağı kaydet | action |
| Yeni hazır yanıt metni | | field |

### 3.12 Geri bildirim ve öneriler (`/admin/support/feedback`)  [puan a3 b4 c4, iş S]

Kaynak: `FeedbackPage.tsx` (344), `support/Support.module.css`.
Kanıt: `feedback-{390,768,1280}-*.png`, `feedback-drawer-390-*.png`, `feedback-empty-*`, `feedback-error-*`.
Ölçüm: 390 px'te 14 px yatay taşma (uzun e-posta).

Sorunlar
- **F-1 [YÜKSEK] Telefonda 14 px yatay taşma:** uzun e-posta satırı (`.fbMeta`) kırılmıyor (`feedback-390-light.png`, 2. kart sağa taşıyor).
- **F-2 [ORTA] "Oy" kutusu anlamsız:** "42 / oy" — kaç kişi destekliyor? "42 kişi destekliyor" yorum; listede oya göre sıralama yok (API sıralama parametresi yok: **backend gerekir**).
- **F-3 [ORTA] "Değerlendir" düğmesi kartın sol üstünde**, oy kutusundan önce; işlem etiketi belirsiz ("Yanıtla/Duruma bak"); kartın tamamı tıklanabilir olmalı.
- **F-4 [ORTA] Çekmece:** "Birleştirilecek hedef kimliği" sayı soruyor; hedef öneriyi arayıp seçme yok; "Geri alınamaz işlemler" bölümü iyi yerde ama telefonda en altta kaydırma gerek.
- **F-5 [ORTA] Çekmece alt çubuğu:** "Kaydet" ilk açılışta pasif (değişiklik yok) — neden pasif? ipucu "Değişiklik yapınca açılır".
- **F-6 [DÜŞÜK] Arama kutusu yok;** yalnız durum+kategori.
- **F-7 [DÜŞÜK] Platform/sürüm (android v2.0.5) küçük gri;** "yanıt verdin" simgesi.
- İyi: durum/kategori rozetleri, "Yönetici yanıtı" vurgulu kutu, çekmece bildirimi ("Kullanıcıya bildirim gider").

Görselleştirme: üstte durum hunisi (Yeni → İnceleniyor → Planlandı → Tamamlandı) sayılarla; kategori donut'ı (hata/öneri/şikâyet/teşekkür) yüklenen satırlardan; "En çok oy alan 3 öneri" listesi (mevcut `voteCount`, ilk sayfadan).

Aranabilir öğeler
| Başlık | Eş anlamlılar | Tür |
|---|---|---|
| Geri bildirim ve öneriler | öneri panosu, hata bildirimi, şikâyet, teşekkür | page |
| Durum filtresi | yeni, inceleniyor, planlandı, tamamlandı, reddedildi | field |
| Kategori filtresi | hata, öneri, şikayet, teşekkür | field |
| CSV indir (geri bildirim) | dışa aktar | action |
| Değerlendir | yanıtla, durum değiştir | action |
| Yönetici yanıtı | cevap | field |
| Herkese açık öneri panosuna al | oylamaya aç, yayınla | field |
| Birleştir | aynı öneri, çift kayıt | action |
| Geri bildirimi kalıcı sil | sil | action |

## 4. İstatistik (sayı dağılımı)

Aşağıdaki sayım bu raporun sayfa bölümlerindeki (3.x) madde etiketleri (R-, C-, P-, PL-, B-, S-, H-, T-, PR-, TK-, TD-, F-) + ortak bulgulardır (X-); yinelenen ortak bulgular sayfa maddelerinde tekrar sayılmadı.

| Önek | KRİTİK | YÜKSEK | ORTA | DÜŞÜK | Toplam |
|---|---|---|---|---|---|
| R | 0 | 3 | 7 | 4 | 14 |
| C | 1 | 3 | 6 | 2 | 12 |
| P | 2 | 2 | 4 | 1 | 9 |
| PL | 0 | 4 | 4 | 2 | 10 |
| B | 0 | 2 | 3 | 1 | 6 |
| S | 0 | 3 | 3 | 1 | 7 |
| H | 0 | 2 | 3 | 1 | 6 |
| T | 0 | 1 | 4 | 1 | 6 |
| PR | 0 | 3 | 5 | 1 | 9 |
| TK | 0 | 1 | 4 | 1 | 6 |
| TD | 0 | 2 | 3 | 2 | 7 |
| F | 0 | 1 | 4 | 2 | 7 |
| X (ortak, bölüm 2) | 0 | 4 | 6 | 3 | 13 |
| **Genel toplam** | **3** | **31** | **56** | **22** | **112** |

## 5. Sayfa ajanı için öncelik sırası

1. **Gönderiler (P-1, P-2)**: kritik yatay taşma + kapanmayan çekmece. Ucuz ve çok etkili; önce yap.
2. **Sohbet akışı (C-1, C-3, C-4)**: kritik taşma (321 px), istatistik ve medya ızgarası.
3. **Ortak KIT isteği (X-1, X-2, X-3, X-4, X-10)**: Table kart kipi, 44 px hedef, filtre katlama, StatCard, Drawer taşması. Bunlar gelmeden İhlaller / Gizlenen içerik / Karar şablonları / Destek talepleri / Anketler sayfalarının tablo sorunları (S-1, H-1, T-1, TK-1, PL-1) çözülemez; sayfa ajanları `Table`'a kart kipi geldiğini varsayıp yalnız satır-kart içeriğini tanımlasın.
4. **Raporlar (R-1, R-2, R-3, R-5)**: en çok kullanılan moderasyon ekranı; telefonda ayrıntı çekmecesi, seçili/tehlike rengi ayrımı, sonuç cümleleri.
5. **Anketler (PL-2, PL-4, PL-5)**: çekmece taşması, toplu çubuğun görünmez düğmesi, istatistik halkası.
6. **Destek talepleri + Talep ayrıntısı (TK-1, TD-1, TD-2, TD-3)**.
7. **İhlaller / Gizlenen içerik (S-3, S-4, H-2, H-3)**: yorum cümleleri, önizleme boyutu.
8. **Uygunsuz ifade (PR-1, PR-2, PR-3)**: bölüm sırası + teknik bilgi kartı.
9. **Geri bildirim (F-1, F-2)**.
10. **Yasaklı görseller (B-1)**: görselden otomatik özet + sayfa açıklaması.
11. **Karar şablonları (T-1..T-5)** ve DÜŞÜK maddeler.

Her sayfada arama dizinine (3.x tabloları) girdi ekleme ve her girdiye `anchor` koyma işi ayrı bir adım olarak planlanmalı.

## 6. Başka akışlara etki / notlar

- Bu rapor dışında hiçbir dosya değiştirilmedi. Geçici betikler repo dışındadır (`%TEMP%` scratchpad); ekran görüntüleri repoya konmadı.
- `web/e2e/mockPanel.ts` bu sayfalar için yetersizdir (yalnız denetim, posta, erişim engeli uçlarını taklit eder); sayfa ajanları görsel doğrulama için bu denetimin fixture'larına benzer, sayfa başına dolu/boş/hata yanıtları ekleyebilir (öneri: `web/e2e/fixtures/moderation.ts`).
- Çalışma ağacı sırasında başka bir ajan `web/src/search/index.ts` dosyasını düzenlerken `groupByPage` eksik dışa aktarımı yüzünden `/admin/*` sayfaları çöktü ("Bir şeyler ters gitti"); bu geçiciydi (sonradan düzeldi), ancak SEARCH ajanı yarım commit göndermemeye dikkat etmeli.
