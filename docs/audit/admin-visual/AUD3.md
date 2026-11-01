# AUD3: Topluluk, Akademik, İçerik sayfaları görsel denetimi

Salt okunur denetim (kod değişmedi). Tarih: 2026-11-01. Kapsam: `adminNav.ts` grupları `community` (6 rota), `academic` (3), `content` (4) = 13 menü sayfası + 2 gömülü yüzey (Kulüp çekmecesi 7 sekme, Etkinlik çekmecesi 7 sekme).

Yöntem: Vite 5203, backendsiz Playwright taklidi (`web/e2e/mockPanel.ts` RBAC çekirdeği + AUD3 verisi; betikler `C:\bu_qa\aud3\*.cjs`, repoda YOK). Her sayfa için dolu / boş / hata durumu; 390x844, 768x1024, 1280x800; açık + koyu tema. Ayrıca çekmece, form, ay görünümü, onay penceresi gibi açık durumlar. Ekran görüntüleri: `C:\bu_qa\shots\adminvisual\before\AUD3\<sayfa>-<durum>-<genişlik>-<tema>.png` (yaklaşık 330 dosya; durumlar `full|empty|error|error2`, açık yüzeyler `clubs-drawer-*`, `events-drawer`, `acdcalendar-month`, `legal-editor`, `*-form`, `news-hide`, `menu-bulk` ...). Sayısal ölçüm: `report-base.json`, `report-rest.json`, `report-extras.json` aynı klasörde.

Puan: 1 kötü, 5 çok iyi. (a) mobil, (b) tasarım, (c) "çocuk bile anlasın", (d) görselleştirme olgunluğu.

## 0. Genel özet

Hiçbir sayfada sayfa düzeyinde yatay taşma YOK (390 ve 768'de `scrollWidth == clientWidth`; kenar çubuğunun ekran dışı çekmecesi sayılmaz). Ama iki yerde içerik, kendi kapsayıcısı içinde kırılıyor (Haberler tablosu, Kulüp çekmecesi > Üyeler). Panelde grafik yok: Sözleşmeler'deki kabul çubuğu bu kapsamın tek gerçek görselleştirmesi.

Toplam bulgu: sayfa düzeyinde 99 (KRİTİK 2, YÜKSEK 36, ORTA 45, DÜŞÜK 16) + ortak/KIT düzeyinde 9 (G1-G9: KRİTİK 1, YÜKSEK 4, ORTA 2, DÜŞÜK 2) = 108.

### Ortak (kit düzeyi) bulgular: sayfa ajanı değil KIT ajanı çözmeli

| # | Bulgu | Önem | Kanıt | Öneri |
|---|---|---|---|---|
| G1 | `Table` mobilde kart/yığın görünümüne düşmüyor; yalnız yatay kaydırma (`components/ui/Table.module.css` `.scroll`, 960 px altında yalnız sıralama düğmesi büyüyor). Haberler, Sözleşme sürüm geçmişi ve Kulüpler listesinde 2-3 sütun görünür, gerisi kesik ve kaydırma ipucu yok | KRİTİK | `news-full-390-light.png`, `clubs-full-390-light.png`, `legal-full-390-light.png` | `Table`'a `mobileCards` kipi: sütunları `header: değer` satırlarına çevir, ilk sütun başlık; satır tıklaması korunur |
| G2 | Dokunma hedefi: 390 px'te tüm `Button`/`IconButton` 40 px yüksek (hedef 44), `size="sm"` ve simge düğmeleri 32-37 px, onay kutuları 13-20 px, çekmece kapat düğmesi 32x40. `report-extras.json`: örn. `menu-bulk-390-light` 50 öğe, `events-bulk` 12, `news-hide` 15 küçük hedef | YÜKSEK | `events-bulk-390-light.png`, `clubs-drawer-general-390-light.png` | Kaba işaretçi (`pointer: coarse`) ve <=600 px için `min-block-size: 44px`, onay kutusunu 24 px + 44 px dokunma alanı yap |
| G3 | `Tabs` taşınca yalnız sağdan kesiliyor ("Reddedi", "Gönde", "Serti"); kaydırılabildiğini gösteren gölge/ok yok. Kulüp çekmecesinde 7, etkinlik çekmecesinde 7 sekme | YÜKSEK | `events-full-390-light.png`, `clubs-drawer-members-390-light.png`, `events-drawer-390-light.png` | Kenar solma (fade) + aktif sekmeyi görünüre kaydır; ya da mobilde `Select`'e dön |
| G4 | `Badge tone="primary"` kırmızı (marka rengi) ve `danger` da kırmızı: "Sürüm 3", "Sahip", "Sabit" rozetleri hata gibi okunuyor | YÜKSEK | `legal-full-390-light.png` (Sürüm rozetleri), `contentreview-full-390-light.png` ("Sabit"), `clubs-drawer-members-390-light.png` ("Sahip") | `primary` rozetini nötr/koyu ya da mavi-gri yap; kırmızıyı yalnız hata/uyarıya ayır |
| G5 | Süzgeç blokları mobilde sayfanın ilk 500-600 px'ini kaplıyor (Kulüpler, Kulüp içerikleri, Sınavlar, Etkinlikler); liste ilk ekranda görünmüyor | YÜKSEK | `contentreview-full-390-light.png`, `acdexams-full-390-light.png` | Ortak `FilterBar`: mobilde "Süzgeçler (2)" düğmesi + alt panel; etkin süzgeçler çip olarak görünsün |
| G6 | Yıkıcı "Sil" düğmesi düzenle/yayından kaldır düğmeleriyle aynı satırda ve bitişik; dokunma hatası riski (onay penceresi var, yine de) | ORTA | `acdcalendar-full-390-light.png`, `acdannounce-full-390-light.png` | Sil'i taşma menüsüne (⋯) al ya da aralık + ayırıcı koy |
| G7 | Tarih alanı `dd.mm.yyyy` yer tutucusu tarayıcıya bağlı, boş durumda "gg.aa.yyyy" yerine İngilizce kısaltma görünüyor (tr-TR'de bile `dd.mm.yyyy`) | DÜŞÜK | `contentreview-full-390-light.png`, `events-full-390-light.png` | Alan etiketine "(gün.ay.yıl)" ipucu ya da kendi tarih seçici |
| G8 | Hata durumu: React Query 2 yeniden deneme + üstel bekleme nedeniyle hata 5-7 sn iskeletle bekliyor, sonra "Veriler yüklenemedi / Sunucu bir hata verdi" geliyor. Mesaj tüm sayfalarda aynı ve neyin yüklenemediğini söylemiyor | ORTA | `news-error2-390-dark.png`, `menu-error2-1280-light.png`; doğrulama: `/admin/events` 4 sn'de iskelet, 8 sn'de hata durumu | Sayfaya özgü cümle ("Kulüp listesi yüklenemedi"), 5xx'te kısa sayaç ya da "tekrar deneniyor" metni |
| G9 | Kenar çubuğu sticky yüksekliği tam sayfa ekran görüntüsünde 800 px'te bitiyor (yalnız yakalama yapıntısı olabilir, `fullPage` kayması); gerçek tarayıcıda DOĞRULANAMADI | DÜŞÜK | `categories-full-1280-dark.png` | Elle kontrol |

Başka ajanlara etkisi: G1-G5 KIT (`components/ui`) işi; sayfa ajanları yalnız kendi sayfalarında kullanır. Başlık araması ("Panelde ara") bu sırada başka ajan tarafından değişiyordu, kapsam dışı.

## 1. Topluluk grubu

### 1.1 Kulüpler: `/admin/communities` (`pages/admin/ClubsManagePage.tsx`, `clubs/ClubList.tsx`, `clubs/ClubDrawer.tsx`, `CommunitiesAdminPage.tsx` onay kuyruğu)

Puan: a 2, b 3, c 3, d 1. İş: L (görsel + mobil tablo + çekmece).

KRİTİK:
- K1. Kulüp çekmecesi > Üyeler sekmesinde uzun adlı/e-postalı üye satırı yatay taşıyor ve ad dikey harf harf kırılıyor ("Ç / o / k / U / z ..."), sağ kenar kesiliyor. Neden: `ClubMembersTab.tsx:108-117` `.person` `inline-flex` ve e-posta `nowrap` (`clubs.module.css:100`), `min-width:0` yok. Kanıt: `clubs-drawer-members-390-light.png`. Düzeltme: `.person { flex-wrap: wrap; min-width: 0 }`, e-posta `overflow-wrap:anywhere`, ad ayrı satır.
YÜKSEK:
- Y1. Kulüp tablosu mobilde 3 sütun görünür (Kulüp, Durum, Sahip yarım), Üye/Şikâyet/Oluşturulma görünmüyor; kaydırma ipucu yok (G1). Kanıt: `clubs-full-390-light.png`. Slug (`bilgisayar-muhendisligi-...`) satırı uzatıyor: mobilde gizle.
- Y2. 7 sekmeli çekmece: "Gönderiler/Duyurular/Denetim" görünmüyor (G3), kapat düğmesi 32x40 (G2). Kanıt: `clubs-drawer-general-390-light.png`.
- Y3. Süzgeç yığını (Durum, Ara, Kategori, Görünürlük, Katılım, Yalnız şikâyetliler) mobilde ~450 px (G5). Kategori serbest metin kutusu; kategori listesi API'de var (`/admin/community-categories`), seçim kutusu olmalı (yazım hatası "Teknoloji/teknoloji" sonuçsuz kalır).
- Y4. Yan yana iki seviye sekme: "Tüm kulüpler / Onay kuyruğu" altında "Onay bekleyen / Aktif / Reddedilen / G..." (sağ kesik). Kanıt: `clubs-queue-390-light.png`.
- Y5. Çekmece "Tehlikeli bölge": "Kulübü kapat" ve "Sahipliği zorla devret" aynı görsel ağırlıkta; kapatmanın ne yapacağı yazılı (iyi), ama Sahiplik kartında kırmızı çerçeve + devre dışı soluk buton ayırt edilmiyor. Kanıt: `clubs-drawer-danger-390-light.png`.
ORTA:
- O1. "Üye" sütunu "342 + 5 bekliyor" iki sayı; "Şikâyet 2" yalnız kırmızı çip. Renk + simge + sayı (güvenli) ama cümle yok.
- O2. Dolu satır sahibi `ownerName=null` iken `#14` yazıyor (kullanıcı kimliği, anlamsız): "Adı yok (zeynep.k@...)" daha iyi. Kanıt: `clubs-full-1280-light.png`.
- O3. Dark tema: durum hapları ve çipler okunur (kontrast tamam; gözle, ölçülmedi). Kanıt: `clubs-full-1280-dark.png`.
- O4. Boş durum: "Bu süzgeçlere uyan kulüp yok" iyi; ama süzgeç temizleme bağlantısı boş durumda yok. Kanıt: `clubs-empty-390-light.png`.
DÜŞÜK: "Durum geçmişi" çekmecede ham `APPROVE` kodu gösteriyor (`clubs-drawer-general-390-light.png`, `admin.p06` durum geçmişi eylem adı çevrilmemiş: ya mock verisi ya gerçek bir çeviri eksiği; DOĞRULANAMADI, backend eylem kodu sözlüğü gerekir).

Görselleştirme (veri mevcut: `ClubRow.memberCount/pendingCount/openReportCount/eventCount`, `ClubDetail.statusHistory/openReports`):
- Sayfa başına özet şerit (mevcut liste sayısından): "4 kulüp: 1 yayında, 1 onay bekliyor, 1 kapalı, 1 reddedildi" yığılmış yatay çubuk (`ClubList.tsx` toplam `data.total`; durum dağılımı için ek istek gerekir: yalnız yüklenen sayfadan hesaplanırsa yanıltıcı, bu yüzden "backend gerekir: durum başına sayı").
- Satırda üye sayısı için küçük yatay çubuk (en büyük kulübe göre), bekleyen başvuru sarı nokta + sayı.
- Çekmece başlığında 4 büyük sayı kutusu (üye, bekleyen, etkinlik, açık şikâyet) `ClubDrawer.tsx:55-70` rozetlerin yerine.
- Çekmece "Durum geçmişi": dikey zaman çizelgesi (`statusHistory` zaten tarihli).
Aranabilir öğeler (başlık | eş anlamlılar | yol):
- Kulüpler | topluluk, kulüp listesi | /admin/communities
- Kulüp ara | kulüp adı, sahip, e-posta | #club-search
- Kulüp durumu süzgeci | yayında, kapalı, reddedilen, silinen | #club-status
- Kategori süzgeci | tür | #club-category
- Görünürlük | herkese açık, gizli, özel | #club-visibility
- Katılım türü | herkese açık, onaylı katılım | #club-join
- Yalnız şikâyetli kulüpler | raporlanan | #club-reported
- Süzgeçleri temizle | sıfırla | #club-reset
- CSV indir (kulüpler) | dışa aktar, excel | #club-csv
- Onay kuyruğu | bekleyen kulüpler, onayla, reddet | /admin/communities?tab=queue
- Kulüp çekmecesi sekmeleri: Genel, Üyeler, Başvurular, Gönderiler, Duyurular, Denetim, Tehlikeli bölge (her biri `?club=<id>&tab=` biçiminde derin bağlantı)
- Üye rolü değiştir | yönetici yap, moderatör | çekmece > Üyeler
- Kulüpten çıkar / yasakla | at, banla | çekmece > Üyeler
- Kulübü kapat / yeniden aç / sil | askıya al | çekmece > Tehlikeli bölge
- Sahipliği devret | sahip değiştir, başkan | çekmece > Tehlikeli bölge
- Davet bağlantıları | davet kodu, iptal | çekmece > Başvurular

### 1.2 Kulüp kategorileri: `/admin/community-categories` (`CommunityCategoriesPage.tsx`)

Puan: a 4, b 4, c 2, d 2. İş: S-M.
YÜKSEK:
- Y1. Jargon: "Anahtar" ("Küçük harf, rakam ve tire...") ve "Simge anahtarı" ("mobil uygulama bu anahtarı simgeye eşler") çocuğa/yeni yöneticiye anlamsız. Kanıt: `categories-edit-390-light.png`. Öneri: "Kısa ad (adreste görünür)" ve simge için seçim ızgarası (mobildeki simge listesi), anahtarı otomatik üret, "Gelişmiş" altına al.
- Y2. "Kategori ekle" formu listeyi aşağı itiyor; mobilde form ekranın ortasında, liste gizleniyor ve düğme soluk (devre dışı) kalıyor. Öneri: alt çekmece/modal.
ORTA:
- O1. Satır başına 5 düğme (↑ ↓ Düzenle Pasife al Sil) mobilde iki satıra sarıyor, 37x40 simge düğmeleri (G2). "Sil" kullanımda iken devre dışı olmalı ve nedeni yazılmalı (kullanım sayısı 14 olan kategoride "Sil" görünür). Kanıt: `categories-full-390-light.png`.
- O2. EN/AR alanı boş olan satırda "AR:" boş görünüyor (yarım çeviri uyarısı yok). Kanıt: `categories-full-390-light.png` "Sanat ve Kültür".
- O3. Sıralama yalnız ↑/↓; mobilde sürükle uygun değil, ama kullanım sayısı yüksek sırayı etkilemiyor, sıra "mobilde görünen sıra" cümlesi yok.
DÜŞÜK: üst açıklama 4 satır, kısaltılabilir; "Aktif kategori: 2 / 12" yalnız metin (halka/çubuk olur).
Görselleştirme: üst kısımda "Kullanım" yatay çubuk listesi (`usageCount`: Teknoloji 14, Sanat 6, Spor 0), "2/12 aktif" ilerleme çubuğu (`activeCount/maxActive`), kullanılmayan kategori için gri "kullanılmıyor" etiketi.
Aranabilir: Kategori ekle | yeni tür | #cat-add; Kategori sırası | yukarı aşağı, sırala | #cat-order; Kategoriyi pasife al/aktifleştir | gizle | #cat-toggle; Kategori sil | kaldır | #cat-delete; Ad (Türkçe/İngilizce/Arapça) | çeviri | #cat-names; Simge | ikon | #cat-icon; Anahtar | kısa ad, slug | #cat-key; Aktif kategori sınırı (12) | en fazla | #cat-limit.

### 1.3 Kulüp denetimi: `/admin/communities/audit` (`ClubAuditPage.tsx`)

Puan: a 4, b 3, c 1-2, d 1. İş: M.
YÜKSEK:
- Y1. Önce "Topluluk kimliği" diye bir sayı yazdırıyor; kimliği kimse bilmiyor (`ClubAuditPage.tsx:52-62`). Kulüp seçici (arama kutusu + liste, `listClubs` API'si var) olmalı; boş durumda ("Kulüp seçin") "Topluluklar" sayfasına bağlantı yetersiz. Kanıt: `clubaudit-full-390-light.png`.
- Y2. Kayıtlar ham: eylem kodu rozeti (sözlükte olmayan kod ham `MEMBER_ROLE` olarak çıkıyor, `td(..., a.action)` geri dönüşü), `detail` ham JSON (`{"from":"MEMBER","to":"ADMIN"...}`) monospaced. Kanıt: `clubaudit-full-390-light.png` (kod: mock eylem adı gerçek koda uymayabilir, gerçek 13 kod çevrili: `admin-safety.ts:157-169`; bilinmeyen kod geri dönüşü yine ham). Öneri: "Ayşe Yılmaz, Burak Can'ı yönetici yaptı" biçiminde tek cümle; ayrıntıyı katla.
ORTA:
- O1. Zaman çizelgesi yok: liste düz kart yığını; gün başlıkları ("Bugün", "Dün") ve dikey çizgi yok.
- O2. Süzgeç yok (eylem türü, kişi, tarih).
- O3. Aktör adı yoksa "Kullanıcı #12" (kimlik) gösteriliyor.
DÜŞÜK: "Göster" düğmesi yarım genişlik, form kenarlığı: hizalama iyi; hata/boş durumlar anlaşılır ("Henüz kayıt yok").
Görselleştirme: eylem türüne göre simge + renk (üye, davet, devir, yetki), son 30 günde günlük kayıt sayısı küçük sütun grafiği (yalnız yüklenen kayıtlardan; tamamı için backend gerekir).
Aranabilir: Kulüp denetim kaydı | geçmiş, log, kim ne yaptı | /admin/communities/audit; Kulüp seç | topluluk kimliği | #audit-club; Daha fazla göster | önceki kayıtlar | #audit-more.

### 1.4 Kulüp içerikleri (içerik inceleme): `/admin/content-review` (`ContentReviewPage.tsx`, `clubs/ContentList.tsx`, `clubs/ContentParts.tsx`)

Puan: a 3, b 3, c 3, d 1. İş: M.
YÜKSEK:
- Y1. Süzgeç yığını ilk ekranı dolduruyor (Durum, Tür, Ara, "En az açık şikâyet", Başlangıç, Bitiş, Sıralama; liste ~720 px'de başlıyor). G5. Kanıt: `contentreview-full-390-light.png`.
- Y2. "Sabit" rozeti kırmızı = hata gibi (G4, `ContentParts.tsx:172` `tone="primary"`). Kanıt: aynı.
- Y3. Satır eylemleri (Şikâyetler, Düzenle, Gizle, Sil) dokunma hedefi 40 px; "Sil" bitişik (G2/G6). "Şikâyetler" bağlantı gibi düz yazı (88x40).
ORTA:
- O1. "En az açık şikâyet" sayı kutusu etiketsiz yer tutucu; "0 yazarsanız hepsi" anlamı yok.
- O2. Kulüp adı etiketi "Kulüp:" altında ayrı satırda, küçük, uzun adlarda iki satır.
- O3. Gizlenen içeriğin soluk görünmesi yok, "Gizli" yalnız sarı çip; sebep ayrı satırda iyi.
- O4. Görsel (imageUrl) küçük resim yok, yalnız metin; incelenen içeriğin fotoğrafı görünmüyor (`ContentRow.imageUrl` mevcut).
DÜŞÜK: tarih alanları G7.
Görselleştirme: üstte "Bekleyen: 3 şikâyetli, 2 gizli" sayı kutuları (yalnız yüklenen sayfadan; toplam için backend sayacı gerekir); satırda şikâyet sayısına göre kırmızı yoğunluk çubuğu; gönderi görselinin küçük resmi.
Aranabilir: Kulüp içerik moderasyonu | gönderi, duyuru incele | /admin/content-review; Durum (görünür/gizli/silinmiş) | #cr-state; Tür (gönderi/duyuru) | #cr-kind; Metin/yazar/kulüp ara | #cr-q; En az açık şikâyet | raporlu | #cr-min-reports; Tarih aralığı | #cr-dates; Sıralama (yeni/şikâyet) | #cr-sort; İçeriği düzenle | metni değiştir | satır eylemi; Gizle / Geri al | #cr-hide; Sil (geri alınamaz) | #cr-delete; Şikâyetleri gör | #cr-reports.

### 1.5 Etkinlikler: `/admin/events` (`EventsAdminPage.tsx`, `events/EventDetailDrawer.tsx`, `events/ops/*`)

Puan: a 3, b 3, c 3, d 1. İş: L.
YÜKSEK:
- Y1. Doluluk hiçbir yerde görünmüyor: `EventView.goingCount` ve `capacity` var, listede yalnız "Kontenjan: 200" (`EventsAdminPage.tsx:384`), kaç kişi katıldığı yok. Etkinlik doluluk halkası/çubuğu "187 / 200 kişi (%94 dolu)" bu sayfanın en büyük fırsatı. Kanıt: `events-full-1280-light.png`.
- Y2. İki katman sekme (durum: Onay bekleyen/Aktif/Gizli/Reddedilen/İptal edilen/Tümü + kapsam: Tümü/Kulüpsüz) mobilde kesiliyor ("Reddedi...") (G3); iç içe iki sekme çubuğu kafa karıştırıcı. Kanıt: `events-full-390-light.png`. Kapsamı süzgeç seçimine (checkbox "Yalnız kulüpsüz") çevir.
- Y3. Çekmecede "Sil (iptal eder)" etiketi çelişkili (`i18n/tr/admin-events.ts:38`): Sil mi iptal mi? "İptal et" ayrıca var. Aynı alt çubukta 4 düğme iki satıra taşıyor. Kanıt: `events-drawer-390-light.png`. Öneri: "Kalıcı kaldır", ve çıkacak sonucu bir cümleyle yaz.
- Y4. Satır seçme kutusu 13x13 px (`opsStyles.pick`), "Sayfadakilerin tümünü seç" 13 px: dokunulamaz (G2). Kanıt: `events-bulk-390-light.png`.
ORTA:
- O1. Çekmece sekmeleri 7 adet, "Sertifikalar" vb. kesik (G3).
- O2. "Katılım türü" etiketi ile arama kutusu arasında dikey boşluk bozuk (etiket arama kutusuna yapışık) ve "Başlangıç (en erken/en geç)" iki ayrı tarih; "Bu hafta / Bu ay" hızlı seçici yok. Kanıt: `events-full-390-light.png`.
- O3. Bilgi mavi kutusu her zaman sayfada ("Etkinliği yalnızca kulüp üyeleri oluşturur...") yer kaplıyor; kapatılabilir olmalı.
- O4. Etkinlik zaman bilgisi "6 Kas 2026 14:00" var, "5 gün sonra / geçmiş" yok (`timingBadge` yalnız bazı durumlarda).
- O5. Hata/yükleme: 5-7 sn iskelet sonra hata (G8).
DÜŞÜK: kapak görseli (`coverUrl`) yok; boş duruma "Süzgeci temizle" eylemi.
Görselleştirme (mevcut veri): satırda `goingCount/capacity` yatay doluluk çubuğu + yüzde; `pendingCount` sarı "14 bekliyor" nokta; çekmece Genel sekmesinde `requests` (bekleyen/kabul/yedek/red/iptal) yığılmış tek çubuk + `attendedCount`; Geri bildirim sekmesinde `summary.distribution` 5 yıldız histogramı (API'de var); Yoklama sekmesinde `summary` (geldi/gelmedi/işaretsiz) halka. Üstte zaman çizelgesi: "Bu hafta 3 etkinlik" şeridi.
Aranabilir: Etkinlikler | etkinlik listesi, onay | /admin/events; Durum sekmeleri (onay bekleyen, aktif, gizli, reddedilen, iptal) | #ev-status; Etkinlik ara | başlık, yer, organizatör | #ev-q; Kulüpsüz etkinlikler | eski kayıtlar | #ev-standalone; Katılım türü (herkese açık / başvurulu) | #ev-join; Başlangıç aralığı | tarih | #ev-dates; Listeyi CSV indir | #ev-csv; Toplu gizle/göster/iptal | çoklu seç | #ev-bulk; Etkinliği onayla / reddet | #ev-approve; Çekmece: Genel, Başvurular, Yoklama, Sertifikalar, Geri bildirim, Duyurular, Düzenleyenler, Denetim (`?open=<id>&tab=`); Sertifikayı iptal et/geri ver | #ev-cert; Yoklamayı elle işaretle | QR, katıldı | #ev-attendance; Geri bildirim sil | #ev-feedback; Etkinliği gizle / iptal et / sil | #ev-actions.

### 1.6 Etkinlik başvuruları: `/admin/events/applications` (`EventApplicationsPage.tsx`)

Puan: a 3, b 3, c 2, d 2. İş: S-M.
YÜKSEK:
- Y1. Etkinlik "kimliği" numarası isteniyor (`EventApplicationsPage.tsx:55-64`); etkinlik seçici (başlık arama) olmalı.
- Y2. "Katılan 187" ile "Kabul edilen 187" aynı sayı ve farkı anlatılmıyor; altı sayı kutusu yan yana, ilişki yok (kabul edilen = katılan - bekleyen vs.?). "Yedek liste", "İptal / geri çekilen" jargon. Kanıt: `eventapps-full-390-light.png`, `eventapps-full-1280-dark.png`.
- Y3. Mobilde 6 kutu tek sütun alt alta ~700 px; 2 sütun olmalı.
ORTA: Kontenjan ve doluluk metni "Kontenjan: 200" yalnız; "13 yer kaldı" yok. Başvuranlar bu sayfada yok (belgelendi, doğru): ama yönlendirme bağlantısı "Etkinliği aç" yok, yalnız onay kuyruğu bağlantısı ("Etkinlik onay kuyruğu").
DÜŞÜK: bağlantı rengi/altı çizgi tutarlı.
Görselleştirme: kontenjana göre doluluk halkası (187/200 = %94, 13 boş yer); başvuru hunisi (başvuru → bekleyen → kabul → katıldı) yatay çubuk (mevcut `AdmissionSummary`); tek cümle: "200 kişilik etkinliğin 187'si dolu, 14 başvuru karar bekliyor."
Aranabilir: Etkinlik başvuruları özeti | katılım, kontenjan, bekleme listesi | /admin/events/applications; Etkinlik seç | kimlik | #ea-event; Bekleyen/Kabul/Red/İptal sayıları | #ea-stats.

## 2. Akademik grubu

### 2.1 Akademik takvim: `/admin/academic/calendar` (`academic/AcademicCalendarPage.tsx`)

Puan: a 2, b 3, c 3, d 2. İş: L.
KRİTİK: yok.
YÜKSEK:
- Y1. Ay görünümü telefonda kullanılamaz: 7 sütun ~45 px hücre, olay çipi "C…" harfine kısalıyor (35x23 px), hücrede 1-2 olaydan fazlası sığmaz (`academic.module.css:101-163`, `.cell { min-block-size:4rem }`). Kanıt: `acdcalendar-month-390-light.png`. Öneri: mobilde noktalı ay ızgarası + seçilen gün listesi (gün seçilince altında olay kartları) ya da gün gün "ajanda" görünümü.
- Y2. Varsayılan görünüm "Liste", takvim ikinci sekmede ve "Ay" etiketi tek harfli ikinci sekme; takvim sayfasının varsayılanı takvim olmalı. Ay başlığı ile "Önceki ay / Sonraki ay / Bugün" üç düğme iki satıra sarıyor. Kanıt: `acdcalendar-month-390-light.png`.
- Y3. Liste mobilde: üstte 3 büyük süzgeç (Tür, Durum, Ara) ~280 px, ardından satırda 3-4 düğme (G5, G6). Kanıt: `acdcalendar-full-390-light.png`.
ORTA:
- O1. Çeşitli tür adları ("DERS_KAYIT" -> "Ders kaydı" iyi), ama olay çipleri renk kodsuz: tür başına renk yok (Vize/Final/Tatil aynı mavi). Kanıt: `acdcalendar-full-1280-light.png`.
- O2. "Yalnızca yayındaki olaylar mobil uygulamada görünür" bilgisi başlıkta var (iyi); taslaklar listede yalnız gri hap; ayrım için aralık yok.
- O3. Ekleme formu (`EventFormModal`): "Tüm gün" kutusu 20 px, tarih alanı tarayıcı yerel tipi; bitiş boşsa ne olur belirsiz ("Bitiş" etiketi, hata mesajı "bitiş başlangıçtan önce" tek ipucu). Kanıt: `acdcalendar-form-390-light.png`.
- O4. "Toplu içe aktar" için örnek satır ipucu uzun metin, yapıştırma formatı gösteren örnek tablo yok. Kanıt: `acdcalendar-import-390-light.png`.
DÜŞÜK: sayfalama "3" toplam sayısı tek başına duruyor ("3 kayıt" demeli).
Görselleştirme: önce bir "yaklaşan olaylar" şeridi (en yakın 3 olay: "Ara sınav haftası: 10 gün sonra"); ay ızgarasında tür renkli noktalar; dönem zaman çizelgesi (Gantt benzeri: dönem başlangıcı, ders kaydı, vize, final, bütünleme; `kind` + `startsAt/endsAt` yeterli).
Aranabilir: Akademik takvim | dönem, tatil, sınav haftası | /admin/academic/calendar; Olay ekle | yeni tatil, ders kaydı | #cal-add; Toplu içe aktar | csv, yapıştır, excel | #cal-import; Tür süzgeci | vize, final, bütünleme, resmi tatil | #cal-kind; Yayın durumu | taslak, yayında | #cal-status; Ara | #cal-q; Liste / Ay görünümü | takvim | #cal-view; Önceki/Sonraki ay, Bugün | #cal-nav; Yayına al / yayından kaldır | #cal-publish; Tüm gün | #cal-allday; Bölüme özel | kapsam | #cal-scope; CSV indir | #cal-csv; Toplu işlem (seçili olayları yayınla/sil) | #cal-bulk.

### 2.2 Sınavlar: `/admin/academic/exams` (`academic/AcademicExamsPage.tsx`)

Puan: a 3, b 3, c 3, d 1. İş: M.
YÜKSEK:
- Y1. Sınav programı düz kart listesi; tarihe göre gruplama, takvim şeridi, çakışma uyarısı yok. Sınav programının doğal görünümü "gün gün zaman çizelgesi" (aynı gün/saat çakışmaları, sınıf+bölüm bazlı). Kanıt: `acdexams-full-1280-light.png`.
- Y2. Süzgeç yığını (Tür, Sınıf, Bölüme göre süz, Durum, Ara = 5 alan, ~420 px) liste ilk ekranda yok (G5). Kanıt: `acdexams-full-390-light.png`. "Bölüme göre süz" serbest metin; bölüm listesi seçim olmalı (yazım hatası).
ORTA:
- O1. Satır başlığı "BIL201 · Veri Yapıları Vize" ders kodu önde, kısa ve düz; sınav tarihine göre "10 gün sonra / geçti" yok.
- O2. Form (`acdexams-form-390-light.png`): "Dönem" serbest metin ("2026-2027 Güz" örnek ipucu iyi), "Fakülte/Bölüm" serbest metin (kapsam boşsa herkese gösterilir kuralı üstte yazılı ama formda yok). Alan sayısı 11, tek sütun uzun.
- O3. Taslak/yayında rozeti + 3 düğme üst üste satırda (G6).
DÜŞÜK: "Not" etiketi ile içerik aynı satırda belirsiz.
Görselleştirme: "yaklaşan sınavlar" şeridi; tarihe göre gruplanmış liste ("Bu hafta", "Gelecek hafta", "Daha sonra"); sınav yoğunluğu ısı çizelgesi (gün başına sınav sayısı: `startsAt`).
Aranabilir: Sınav programı | vize, final, bütünleme takvimi | /admin/academic/exams; Sınav ekle | #ex-add; Tür / Sınıf / Bölüm süzgeçleri | #ex-filters; Durum | taslak, yayında | #ex-status; Ara | ders kodu | #ex-q; Dönem | güz, bahar | #ex-term; Salon | derslik | #ex-room; CSV indir | #ex-csv; Toplu yayınla/sil | #ex-bulk.

### 2.3 Bölüm duyuruları: `/admin/academic/announcements` (`academic/AcademicAnnouncementsPage.tsx`)

Puan: a 3, b 3, c 3, d 2. İş: M.
YÜKSEK:
- Y1. Okunma oranı yalnız metin ("Okunma: 1.240 / 4.210 (%29)", `AcademicAnnouncementsPage.tsx:308-320` `readPercent` hesaplanıyor ama çubuk yok). Kanıt: `acdannounce-full-390-light.png`. İlerleme çubuğu + "Hedef kitlenin %29'u okudu" tek cümle.
- Y2. Satır başında 4 düğme (Düzenle, Sabitle/Sabitlemeyi kaldır, Yayından kaldır, Sil) üç satıra sarıyor ve başlığın ÜSTÜNDE; kullanıcı önce düğmeleri sonra içeriği görüyor. Eylemler kartın altında/menüde olmalı. Kanıt: aynı.
ORTA:
- O1. Form: "Fakülte/Bölüm" serbest metin, "Sınıf" seçim; "Bu duyuru yaklaşık 4.210 kullanıcıya ulaşır" (iyi, canlı hedef sayacı). Bildirim gönderme ("Bildirim gönder") onay kutusu etkisini açıklamıyor (kaç kişiye push gider?). Kanıt: `acdannounce-form-390-light.png`.
- O2. "Sabit" rozeti kırmızı (G4).
- O3. Duyuru metni 8 satır, katlanmıyor (uzun metinlerde sayfa şişer).
DÜŞÜK: yayın/bitiş tarihi "Yayın: 31 Eki 2026 10:00 · Bitiş: 21 Kas" iyi; "Bildirim gönderildi" metni; durum süzgecinde `scheduled/active/expired` için adlar.
Görselleştirme: okunma halkası/çubuğu; "yayında / planlı / süresi doldu" durum zaman çizgisi (yayın-bitiş aralığı mini çubuğu); üstte 4 sayı kutusu (yayında, taslak, planlı, süresi dolan; durum süzgeci sayıları için backend sayacı gerekir, yüklenen sayfadan yaklaşık).
Aranabilir: Bölüm duyuruları | duyuru, bildirim | /admin/academic/announcements; Duyuru ekle | #an-add; Hedef kitle (fakülte/bölüm/sınıf) | #an-audience; Yayın zamanı / bitiş | zamanlama | #an-schedule; Sabitle | üste tut | #an-pin; Bildirim gönder | push | #an-notify; Ek bağlantı | dosya | #an-attachment; Durum süzgeci (taslak, planlı, yayında, süresi doldu) | #an-status; Okunma sayısı | #an-reads; CSV indir | #an-csv; Toplu işlem | #an-bulk.

## 3. İçerik grubu

### 3.1 Sözleşmeler: `/admin/content/legal` (`LegalAdminPage.tsx`, `content/Legal.module.css`, `content/MarkdownEditor.tsx`)

Puan: a 3, b 4, c 3, d 4 (en iyi). İş: M.
YÜKSEK:
- Y1. 8 sözleşme kartı mobilde tek sütun ~1400 px; sürüm geçmişi ve "Yeni sürüm" editörü bunların altında. Kullanıcı bir karta basınca editöre ulaşmak için ekranı uzun kaydırmak zorunda. Kanıt: `legal-full-390-light.png`, `legal-editor-390-light.png`. Öneri: mobilde yatay kaydırmalı kart şeridi ya da seçim kutusu; seçilince editöre otomatik kaydır.
- Y2. Kabul oranı renk yorumu yok: KVKK %3 yeşil çubuk, Gizlilik %69 yeşil. Düşük oran "az kişi onayladı" uyarısı vermiyor (renk eşiği + simge + metin). Kanıt: `legal-full-1280-dark.png`.
- Y3. "Sürüm 3" rozeti kırmızı (G4); seçili kart kırmızı çerçeve (hata gibi). Seçim durumu kalın çerçeve+işaret ile yapılmalı.
ORTA:
- O1. Sürüm geçmişi tablosu mobilde "Yeniden onay" sütunu kesik (G1); "Yeniden onay" jargon: "Kullanıcılardan yeniden onay istendi mi".
- O2. Editörde Markdown araç çubuğu düğmeleri 32x32 px (G2); önizleme yan yana, mobilde alt alta, çok uzun. Kanıt: `legal-editor-390-light.png`.
- O3. "Yayınla" onayı çok güçlü ("YAYINLA v4" yazdırma) iyi; etkisi "X kullanıcıya yeniden onay sorulacak" cümlesi var (iyi, `admin.p05.legal.impact*`).
- O4. Boş durum: "Henüz yayınlanmadı" 4 kartta; kart sayısını azaltmak için "yayınlanmamış 4 sözleşme" tek satırda toplanabilir.
DÜŞÜK: sürüm tarihleri iki biçim (kart "2 Eki 2026", tablo "2 Eki 2026 10:00").
Görselleştirme: kabul oranı için halka (yüzde ortada) + eşik rengi; "Sürüm 3 yayında; 4.100/4.210 kabul etti" cümlesi; üstte "genel uyum" özeti (8 sözleşmeden kaçı %90 üstü). Sürüm geçmişi zaman çizelgesi (sürümler dikey). 
Aranabilir: Sözleşmeler | kullanım koşulları, gizlilik, KVKK | /admin/content/legal; her sözleşme türü (Kullanım koşulları, Gizlilik politikası, KVKK aydınlatma, Topluluk kuralları, Açık rıza, Çerez, İçerik bildirimi/kaldırma, Veri saklama) | #legal-<tür>; Kabul oranı | onay yüzdesi | #legal-acceptance; Sürüm geçmişi | eski sürümler | #legal-history; Yeni sürüm yayınla | güncelle | #legal-editor; Dil sekmeleri (Türkçe, İngilizce, Arapça) | #legal-langs; Önceki sürümden kopyala | #legal-copy; Yeniden onay iste | kullanıcıdan tekrar onay | #legal-reaccept; Önizleme | #legal-preview; Markdown araç çubuğu | kalın, italik, başlık | #legal-toolbar.

### 3.2 Sık sorulan sorular: `/admin/content/faq` (`FaqAdminPage.tsx`)

Puan: a 3, b 3, c 3, d 1. İş: S-M.
YÜKSEK:
- Y1. Satır eylemleri (↑ ↓ Yayından kaldır Düzenle ✕) simge düğmeleri 32-37 px ve 5 tane tek satır; "✕" (sil) tek başına alta düşüyor, hedefi küçük ve etiketsiz görünüyor (G2/G6). Kanıt: `faq-full-390-light.png`.
- Y2. Soru formunda Kategori serbest metin + liste oku "▼" (`FaqAdminPage.tsx:305-313`), açıldığında kırmızı çerçeve (hata) daha yazmadan görünüyor; ok simgesi diğer seçim kutularından farklı (tutarsız bileşen). Kanıt: `faq-form-390-light.png`.
ORTA:
- O1. Sıra numarası elle sayı ("Sıra numarası 0") ve ayrıca ↑↓ ile sıralama: iki yöntem.
- O2. Dil sekmesi Türkçe/İngilizce/Arapça: hangi dilde kaç soru olduğu, çevirisi eksik soru uyarısı yok.
- O3. Arapça içerikte yön (RTL) önizleme yok.
- O4. Boş durum ("Henüz soru yok") ayrıntısı ekranda doğrulanmadı: `faq-empty-390-light.png` bakın.
DÜŞÜK: "1 soru" kategori sayacı iyi.
Görselleştirme: kategori başına soru sayısı küçük çubuk; "yayında / taslak" sayı kutuları; dil kapsama durumu (tr 12, en 5, ar 3).
Aranabilir: SSS | sıkça sorulan, yardım | /admin/content/faq; Soru ekle | #faq-add; Dil sekmeleri | #faq-langs; Kategori | grup | #faq-category; Soru / Yanıt | #faq-text; Sıra numarası | #faq-order; Yayında anahtarı | gizle, yayından kaldır | #faq-published; Yukarı/aşağı taşı | sırala | #faq-move; Soruyu sil | #faq-delete; Daha fazla yükle | #faq-more.

### 3.3 Haberler: `/admin/content/news` (`NewsAdminPage.tsx`, `content/News.module.css`)

Puan: a 1, b 3, c 3, d 2. İş: M.
KRİTİK:
- K1. Haberler tablosu mobilde kullanılamaz: başlık sütunu ~70 px'e eziliyor ve her satır 20 harfte kırılıyor ("Üniver / sitesi / Rektör / ü yeni ..."), satır ~600 px yüksekliğinde; Kaynak/Eylem sütunları görünmüyor. Neden (kod hatası): `content/News.module.css:34` ve `:39` ikisi de `.title { min-width: ... }` yazıyor, ikinci `min-width: 0` birinciyi (`14rem`) eziyor; üstüne `.title > span:first-child { overflow-wrap:anywhere }` (satır 41) harf bazında kırmayı serbest bırakıyor. Kanıt: `news-full-390-light.png` (karşılaştır `news-full-1280-dark.png` masaüstünde iyi). Çözüm: tek `min-width: 14rem` bırak (ya da G1 kart kipi).
YÜKSEK:
- Y1. Senkron kartı: "Yemek listesi: Bakımda" kırmızı hap + "Kaynak notu: Kaynak sitenin yapısı değişti" — iyi bilgi ama "Bakımda" ne demek (veri eski mi, yeni mi?) yazmıyor: "Son 19 gündür yemek listesi güncellenemedi; eski liste gösteriliyor" gibi tek cümle gerekir. "Son başarılı" tarih yerine "3 saat önce". Kanıt: `news-full-390-light.png`.
- Y2. Satırda yalnız göz simgesi ile gizle/göster (tek simge düğmesi 36 px, mobilde görünmez); metin etiketi yok (`aria-label` var). Kanıt: `news-full-1280-dark.png`.
ORTA:
- O1. Süzgeçler iki ayrı kapsülde alt alta (tür, görünürlük), ikisi de aynı genişlikte ama etiket yok (yalnız ilk seçenek: "Tüm türler", "Tümü" belirsiz: ikinci hangi süzgeç?). Kanıt: `news-full-390-light.png`.
- O2. "Şimdi senkronize et" iki kez (kaynak başına) ve onay penceresi var (iyi); kaynak siteye yük bindirme uyarısı mesajı onay penceresinde (`news-sync-390-light.png`).
- O3. Gizlenmiş haber satırı üstü çizili + "Gizli" rozeti (iyi), ama gizleme gerekçesi sütunu yok.
DÜŞÜK: Tür sütunu salt metin, `Badge` ile renklenebilir; "—" tarih boş.
Görselleştirme: senkron kartında "Son 7 gün" çubuğu (haber/duyuru/etkinlik günlük sayı: `ContentAnalytics.daily` API'si analitik tarafında var, burada kullanılmıyor); durum noktası + "x saat önce" yaş göstergesi; üstte "Toplam 120 haber, 6 gizli" sayı kutuları (liste `totalItems` var, gizli sayısı için ek istek gerekir).
Aranabilir: Haberler | duyurular, etkinlik haberleri | /admin/content/news; Kaynak senkronizasyonu | haberleri çek, güncelle | #news-sync; Haber ve duyuru senkronu | #news-sync-news; Yemek listesi senkronu | #news-sync-menu; Bakım durumu | kaynak sitesi çöktü | #news-sync-status; Başlıkta ara | #news-q; Tür süzgeci | haber, duyuru, etkinlik | #news-type; Görünürlük süzgeci (görünen/gizli) | #news-visible; Haberi gizle / göster | yayından kaldır | #news-hide; Kaynağı aç | orijinal bağlantı | #news-source; CSV indir | #news-csv; Toplu gizle/göster | #news-bulk.

### 3.4 Yemek menüsü: `/admin/content/menu` (`MenuAdminPage.tsx`, `menu/CalorieEditor.tsx`, `menu/CalorieBulkImport.tsx`)

Puan: a 2, b 3, c 2, d 1. İş: M-L.
YÜKSEK:
- Y1. Menü kalori tablosu telefonda: her gün ~280 px, 30 günlük ay ~9000 px (ölçülen sayfa yüksekliği 3260 px yalnız 6 gün için, `report-rest.json` `menu-full-390-light`); kalori kutuları 88x34, "Kalorileri kaydet" devre dışı gri görünüşlü ve her gün ayrı (30 ayrı kaydet). Kanıt: `menu-full-390-light.png`, `menu-bulk-390-light.png` (50 küçük hedef). Öneri: gün kartlarını katlanır yap (bugün + yaklaşan 7 gün açık, gerisi kapalı), tek "Tümünü kaydet" yapışkan çubuk.
- Y2. Kalori görsel değil: yemek başına çubuk yok, günlük toplamı yalnız metin ("Toplam: en az 560 kcal (3/4 yemek)"). Eksik kalori (boş kutu) sadece boş kutu; "Eksik" rozeti/renk yok. Kanıt: `menu-full-1280-light.png`.
- Y3. Açıklama metinleri jargon ve uzun (4-5 satır): "birebir aynı menü aynı görseli alır, menüde en ufak değişiklik olursa görsel düşer ve yeni görsel beklenir", "Girilen kalori yemek adına kaydedilir: aynı yemek sonraki günlerde ... otomatik dolar" (`admin.menu.hint`, `admin.menu.kcal.hint`). Kanıt: `menu-full-390-light.png`. Üç kısa madde + "Daha fazla bilgi" katlama.
ORTA:
- O1. Ay seçici yerel `type=month` kutusu (tarayıcıya bağlı); ay ileri/geri düğmesi ve "Bu ay" yok.
- O2. "Toplu kalori yapıştır" katlama (iyi) ama örnek satırdaki `MERCİMEK ÇORBASI` büyük harf; Excel şablonu indirme yok. Kanıt: `menu-bulk-390-light.png`.
- O3. Fotoğraf yok yer tutucusu 107x70 px kesikli kutu; yükleme sınırı ("5 MB") ekran başında, yükleme sırasında ilerleme gösterimi `uploading` metni.
- O4. "Aydaki tüm günleri seç" + her gün onay kutusu 13 px (G2).
DÜŞÜK: tarih biçimi "1 Kasım 2026 Pazar" iyi; boş durum "Bu ay için menü yok" tek satır, nedeni yok (kaynak sitesi mi, bakım mı?). Kanıt: `menu-empty-390-dark.png`.
Görselleştirme: yemek başına yatay kalori çubuğu (tüm ayın en yüksek yemeğine göre), günlük toplam için dilimli halka/sütun ("1 Kasım: 980 kcal, ay ortalaması 820"), ay boyunca günlük toplam kalori sparkline'ı (`totalKcal`), eksik kalorili günleri turuncu nokta ile işaretleyen "ay özeti ızgarası" (30 hücre: tam / eksik / menü yok). Hepsi `AdminMenuDay.dishes/totalKcal/kcalComplete` ile yapılır.
Aranabilir: Yemek menüsü | yemekhane, günün menüsü | /admin/content/menu; Ay seç | #menu-month; Toplu kalori yapıştır | excel, csv, kcal | #menu-bulk-kcal; Yemek kalorisi (kcal) | enerji, kalori gir | #menu-kcal; Kalorileri kaydet | #menu-kcal-save; Günlük toplam kalori | #menu-total; Yemek fotoğrafı ekle/değiştir/kaldır | resim | #menu-photo; Aydaki tüm günleri seç | #menu-select-all; Seçili günlerin fotoğrafını sil (toplu) | #menu-bulk-delete; CSV indir | #menu-csv; Fotoğraf sınırları (JPEG/PNG/WebP, 5 MB) | #menu-photo-help.

## 4. Sayfa ajanı için öncelik sırası

KIT ajanı önce (sayfa ajanlarının bağımlılığı):
1. G1 `Table` mobil kart kipi (Haberler, Kulüpler, Sözleşme geçmişi buna bağlı).
2. G2 dokunma hedefi 44 px (Button/IconButton/Checkbox/Drawer kapat).
3. G3 Tabs taşma ipucu, G4 rozet tonu, G5 `FilterBar` (mobil katlanır süzgeç), doluluk/ilerleme/halka/sparkline bileşenleri (mevcut `components/charts` + yeni "ProgressBar/Ring").

Sayfa ajanı (kendi sayfalarında):
1. Haberler: `News.module.css:34/39` kopyalanan `min-width` hatası (KRİTİK, 1 satır) + kart kipi. Boyut S.
2. Kulüpler: Üyeler satırı taşması `clubs.module.css:100` + `ClubMembersTab.tsx:108` (KRİTİK). Boyut S.
3. Yemek menüsü: katlanır gün kartları, kalori çubukları, tek kaydet (YÜKSEK). Boyut M-L.
4. Etkinlikler: doluluk çubuğu/halkası, tek sıra sekme, "Sil (iptal eder)" etiketi. Boyut M.
5. Etkinlik başvuruları ve Kulüp denetimi: kimlik girişini seçiciye çevir; sayı kutuları 2 sütun, açıklayıcı cümle. Boyut M.
6. Akademik takvim: mobil ay görünümü (noktalı ızgara + gün listesi), varsayılan takvim, yaklaşan şeridi. Boyut L.
7. Duyurular: okunma çubuğu, eylemleri karta alta/menüye. Boyut S.
8. Sözleşmeler: kart şeridi/seçici, eşik renkli kabul halkası, rozet tonu. Boyut M.
9. Sınavlar: tarihe göre gruplama + çakışma uyarısı. Boyut M.
10. Kulüp içerikleri: süzgeç katlama, görsel küçük resim, "Sabit" rozeti. Boyut M.
11. Kategoriler: jargon ("Anahtar", "Simge anahtarı") sadeleştirme, form modal. Boyut S.
12. SSS: eylem düğmeleri menüsü, kategori seçici, dil kapsama göstergesi. Boyut S.
13. Tüm sayfalar: arama dizini girdileri (yukarıdaki "Aranabilir" listeleri) + anchor'lar; `web/src/search/index/community.ts`, `academic.ts`, `content.ts` olarak üç dosya önerilir.

## 5. Doğrulanamayanlar

- Gerçek backend verisiyle eylem kodlarının çevirisi (özellikle `statusHistory.action`, kulüp denetimi) doğrulanamadı; mock'ta eylem kodları gerçek kodlarla birebir değil.
- Ekran okuyucu/klavye turu, gerçek dokunmatik cihaz, RTL (Arapça) düzen denenmedi; yalnız tr, açık/koyu.
- Kontrast oranı hesaplanmadı (gözle inceleme); koyu temada belirgin kontrast hatası görülmedi.
- Tam sayfa ekran görüntüsünde yapışkan kenar çubuğu 800 px'te kesiliyor: yakalama yapıntısı olabilir (G9).
- Yük ve ağ hatası dışındaki hata türleri (403 yetki, 409 çakışma) denenmedi.
- Etkinlik çekmecesindeki Başvurular/Yoklama/Sertifikalar/Geri bildirim/Duyurular/Düzenleyenler/Denetim sekmeleri yalnız Genel sekmesi için görüntülendi; diğer sekme içerikleri için görüntü alınmadı (kod okundu: `events/ops/*`).
