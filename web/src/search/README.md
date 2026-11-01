# Yönetim paneli araması: sayfa ajanları kılavuzu

Üst çubuktaki arama (Ctrl/Cmd+K, `layouts/QuickNav.tsx`) ve yan menü süzgeci (`AdminLayout.tsx`) **aynı motoru** kullanır.
Amaç: yönetici "bakım modu" yazınca Ayarlar sayfasındaki bakım modu alanına gitsin, oraya kaydırılsın ve ~2 sn vurgulansın.
Sayfanızdaki **her anlamlı öğe** (ayar, alan, filtre, düğme, bölüm, ipucu) aranabilir olmalı.

## 1. Üç adım

1. **Girdi yaz**: `web/src/search/index/<grup>.ts` dosyasında kendi sayfanız için `SearchEntry` ekleyin
   (grup dosyaları: `overview, people, moderation, community, academic, support, content, notifications, system`; yalnız kendi grubunuzun dosyasını düzenleyin, çakışma olmaz).
2. **Anchor koy**: sayfa kodunda öğeye `data-search-anchor="..."` ya da `<SearchAnchor id="...">` ekleyin.
3. **Sekme/açıklayıcı varsa**: `useSearchReveal` ile sayfanın o öğeyi görünür kılmasını sağlayın.

Menü sayfalarının kendisi (`page` girdisi) `adminNav.ts` + `pageInfo.ts` içinden **otomatik** üretilir; yeni menü sayfası eklerseniz `pageInfo.ts`'e açıklama + anahtar kelime satırı yazın (test zorlar).

## 2. Girdi (`SearchEntry`)

```ts
{
  id: 'settings.maintenance_mode',   // benzersiz: <sayfa>.<öğe>
  kind: 'setting',                    // section | setting | field | action  (page: yalnız menüde olmayan alt sayfa)
  page: 'settings',                   // adminNav.ts öğe kimliği → yol, izin, grup, simge oradan gelir
  title: 'Bakım modu',                // ekrandaki metinle AYNI
  section: 'Bakım modu',              // kırıntıdaki ara başlık (sekme/kart adı), isteğe bağlı
  anchor: 'maintenance_mode',         // sayfadaki data-search-anchor değeri; yoksa yalnız sayfa açılır
  keywords: ['bakıma al', 'siteyi kapat', 'geçici kapatma'],
  description: 'Açınca tüm kullanıcılar bakım mesajını görür.',  // 1 cümle, düz Türkçe
  // path: paths.admin.campaignNew,   // menü yolundan farklıysa (daima paths.admin.* kullanın)
  // perm: 'settings.write',          // sayfa izninden farklıysa (yazma gerektiren eylem gibi)
}
```

Dolu örnek: `index/system.ts` (Ayarlar, Uygulama güncelleme, Sistem durumu). Kopyalayıp uyarlayın.

**kind seçimi**: `section` kart/sekme/başlık · `setting` kaydedilen ayar · `field` form alanı/filtre/sütun grubu · `action` düğme (Yayınla, Sil, Dışa aktar…).
Eylem düğmesi yetki gerektiriyorsa `perm` verin: izni olmayan kullanıcı sonucu **görmez** (RBAC).

## 3. Anchor koyma

```tsx
<Card title="Sosyal medya" data-search-anchor="card-social">…</Card>        // data-* kabul eden bileşen
<SearchAnchor id="source-note"><Callout …/></SearchAnchor>                   // kabul etmeyen bileşeni sarmak için
<PermissionButton data-search-anchor={`publish-${platform}`} …>              // şablonlu anchor da olur
```

- Anchor değeri yalnız `A-Z a-z 0-9 . _ -`; sayfa içinde benzersiz.
- Ayar alanları: `SettingRow` anchor'ı **ayar anahtarının kendisi** koyar (`data-search-anchor={k}`); girdinizin `anchor`'ı anahtardır (`app_name`).
- Liste/tablo satırı gibi **dinamik** öğeye anchor koymayın; bölüm (tablo başlığı, filtre çubuğu) yeter.
- Anchor, `scroll-margin` ile yapışkan üst çubuğun altında kalmaz; vurgu kenarlık + halkadır (`search.module.css`), ekstra stil yazmayın.

### Sekme / accordion / lazy içerik

Hedef yalnız bir sekmede çiziliyorsa sayfa, aramanın "aç" çağrısını dinler. İşleyici **yan etkisiz ve tekrar çağrılabilir** olmalı
(arama hedefi bulunana dek ~3,5 sn boyunca her ~100 ms çağırır):

```tsx
useSearchReveal((anchor) => {
  const tab = TAB_OF_ANCHOR[anchor];   // anchor → sekme eşlemesi
  if (tab) setTab(tab);
});
```

**Sekme durumunu URL'de tutun**: `useState` yerine `useUrlTab` (`search/useUrlTab.ts`) kullanın; sekme `?tab=...` olur
(yenileme/paylaşım aynı sekmeyi açar, `#hash` korunur) ve açıcı kendiliğinden bağlanır:

```tsx
const [tab, setTab] = useUrlTab<TabId>(TABS, 'health');   // varsayılan sekme adrese yazılmaz
// sekme içeriğine  <SearchAnchor id="tab-queues">  koyarsanız  #tab-queues  o sekmeyi açar
// (kural: `<param>-<sekme değeri>`); tek tek alanlar için useSearchReveal ile anchor → sekme eşlemesi yazın.
```

Uygulananlar: Ayarlar (`?tab=maintenance`), Operasyon, Sistem durumu ölü kayıtlar (`?tab=push`), Veri saklama geçmişi (`?tab=purges`).

`<details>` içindeki hedef otomatik açılır. Veri yüklenince çizilen öğeler (Skeleton sonrası) beklenir; bulunamazsa kullanıcıya
"Bu alan şu an bu sayfada görünmüyor." bildirimi çıkar (hata değildir: örn. veri yok, izin yok).

## 4. Anahtar kelime yazım kuralları

Yönetici teknik terimi bilmez; **neyi yapmak istediğini** yazar. Her girdi için 3-10 anahtar kelime:

- **Günlük dil**: "siteyi kapat", "bakıma al", "kimin ne yaptığını gör", "gitmeyen mail".
- **Eş anlamlılar**: şikayet/bildirim/ihbar · engelle/yasakla/ban · sil/kaldır · mail/e-posta/eposta · kulüp/topluluk.
- **Yaygın yabancı sözcükler**: push, banner, cron, log, token, qr, kvkk (Türkçe yazımı da: "bildirim", "bant").
- **İngilizce yalnız yaygınsa**: maintenance, dashboard (az sayıda).
- **Ekranda görünen metni tekrar etmeyin** (başlık zaten aranır); farklı söyleyişleri yazın.
- **Çok genel sözcük koymayın** ("sayfa", "ayar", "yönetim", "liste"): her şeyle eşleşip gürültü yapar.
- **Yazım hatası/aksan yazmayın**: motor büyük-küçük harf, `İ/ı`, `ç ğ ö ş ü` ve küçük yazım hatalarını (4+ harfte 1, 8+ harfte 2 harf) zaten tolere eder. "bakim" yazan "bakım"ı bulur; ayrıca eklemeye gerek yok.
- Birden çok kelimelik kalıp yazabilirsiniz ("zorunlu güncelleme"); sorgu kelimeleri sıradan bağımsız VE ile eşleşir, tam kalıp eşleşmesi en üste çıkar.
- **Açıklama (`description`)**: tek cümle, "ne işe yarar / ne olur" (çocuk anlasın). Teknik terim yok. Sonuçta ikinci satır olarak görünür ve düşük ağırlıkla aranır.
- **Başlık**: ekrandaki etiketle birebir. Aynı ada sahip iki girdi varsa `section` ile ayırt edin.

Sıralama: başlık > anahtar kelime > açıklama > kırıntı; tam başlık/anahtar kelime eşleşmesi en üstte; aynı puanda sayfa > bölüm > ayar > alan/eylem.

## 5. Test ve doğrulama

- `npm run test -- src/search` : motor, kayıt defteri, kapsam testleri.
- `coverage.test.ts`: (a) girdi kimlikleri benzersiz, `page` menüde var; (b) **her girdinin anchor'u kaynak kodda bulunur**
  (`data-search-anchor="x"`, `SearchAnchor id="x"`, şablonlu önek ya da `SettingRow` gibi anahtar tabanlı); (c) derin girdisi olmayan
  sayfalar **raporlanır**: `BEKLENEN_EKSIKLER` listesinden kendi sayfanızı **silin** (liste sıfırlanana dek şablon).
- Yeni sayfa menüye eklenirken `pageInfo.ts`'e satır yazılmadıysa `build.test.ts` düşer.
- Elle deneme: panelde Ctrl+K → sorgu → Enter; sayfa açılmalı, öğe ortaya kaydırılıp ~2 sn vurgulanmalı; yan menü süzgecine aynı sorguyu yazınca sayfa + altında kısa yol görünmeli.

## 6. Dosya haritası

| Dosya | Görev |
|---|---|
| `types.ts` | `SearchEntry` (yazdığınız) ve `ResolvedEntry` |
| `index/<grup>.ts` | Sayfa grubu başına girdi listeleri (**siz düzenlersiniz**) |
| `registry.ts` | Grup dosyalarını birleştirir |
| `pageInfo.ts` | Menü sayfalarının açıklama + anahtar kelimeleri |
| `build.ts` | Menü sayfaları + girdiler → yol/izin/kırıntı çözümü |
| `engine.ts`, `fold.ts` | Motor: Türkçe katlama, önek/alt dizgi/yazım hatası, puan, gruplama, vurgulama, öneri |
| `useAdminSearch.ts` | React kancası (RBAC filtresi, dizin önbelleği); QuickNav ve menü süzgeci ortak kullanır |
| `anchor.tsx`, `search.module.css` | `SearchAnchor`, `useSearchAnchorFocus`, `useSearchReveal`, vurgu stili |
| `useUrlTab.ts` | Sekme durumunu `?tab=` ile URL'de tutar; `tab-<değer>` anchor'ı sekmeyi açar |
| `recent.ts`, `popular.ts` | Son aramalar (localStorage, hata toleranslı), sık aramalar |
