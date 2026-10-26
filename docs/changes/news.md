# news / menu / status degisiklikleri (Flyway V170)

Hepsi geriye uyumludur (yalnizca ekleme).

## API
- `GET /api/news`: `type` buyuk/kucuk harf toleransli (`duyuru`, `Etkinlik`). Gecersiz tur artik
  `400 NEWS_TYPE_INVALID` (eskiden `MALFORMED_REQUEST`). `size` 1-50'e, `page` >= 0'a sabitlenir.
- `NewsSummary` ve `NewsDetail` yeni alan: `eventDate` (yyyy-MM-dd veya null; yalnizca ETKINLIK).
- Siralama: `publishedDate DESC NULLS LAST, id DESC` (liste ve arama). Tarihi ayristirilamayan kayitlar artik
  cekim gununu (Europe/Istanbul) `publishedDate` olarak alir; V170 eski NULL kayitlari da doldurur.
- `GET /api/menu?month=`: gecersiz ay (`yyyy-MM` disi veya 2000-2100 disi) `400 MENU_MONTH_INVALID`.
- `GET /api/status`: her kaynakta yeni `maintenanceMessage` (istek dilinde bakim metni; bakim yoksa null).
  Mevcut `message` teknik ayrinti olarak kalir.

## Etkinlik tarihi (event modulu ajanina)
- Kaynak liste (`tip=2`) tek bir tarih sutunu verir; bunun yayin mi etkinlik mi tarihi oldugu CANLI HTML
  olmadan dogrulanamadi (kaynaga istek atmak yasak). Bu yuzden `publishedDate` "listedeki tarih" olarak kalir.
- Yeni `news_item.event_date`: ETKINLIK detay sayfasinda "Etkinlik Tarihi:", "Baslangic Tarihi:" veya
  "Tarih:" etiketli alandan cikarilir (`NewsScraper.extractEventDate`); bulunamazsa NULL.
- Takvim sorgusu (`OfficialEventRepository.inRange`) onerilen: `COALESCE(n.eventDate, n.publishedDate)` ile
  aralik filtresi ve siralama. V170 `event_date` icin kismi indeks ekler.

## Sync davranisi
- Liste baglantilari `absUrl` ile mutlak yapilir (baz: `/buproject/`), `http://` -> `https://`; 1000 karakteri
  asan baglanti (kirpilmis link bozuk olacagindan) atlanir.
- Tarih ayristirma: `d.M.yyyy`, `d/M/yyyy`, `yyyy-MM-dd`, "12 Kasim 2026" (Turkce ay adlari, buyuk/kucuk harf).
- Detayi cekilemeyen ana-site kayitlari (`content IS NULL`) gece cekimi sirasinda yeniden denenir: kayit basina
  en cok 5 deneme (`content_attempts`), denemeler arasi >= 20 saat, sync basina en cok 20 kayit, 500 ms bekleme.
  Yeni cron/istek yolu yok; yalnizca mevcut gece zamanlayicisi.
- Menu: `menu_day.items` 1000 karakteri asarsa satir sinirinda kirpilir (tum senkronu bozmasin).

## Yapilandirma (ortak dosyalar; ana ajan eklemeli)
- `application.properties`: `spring.messages.basename=i18n/messages,i18n/news`
  (yeni anahtarlar: `error.NEWS_TYPE_INVALID`, `error.MENU_MONTH_INVALID`, `status.maintenance.NEWS|MENU`;
  yuklenmezse `maintenanceMessage` null, hata metni koddaki Turkce varsayilana duser).
