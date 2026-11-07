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

## P07 duzeltme turu (icerik / kazima / sozlesme / destek / onbellek)

Istemci etkisi (mobil/web kodu DEGISMEDI; sozlesme):
- `GET /api/news?q=`: metin aramasi **en az 3 karakter** (onceden 2; 2 karakter `400 VALIDATION_ERROR`), **IP basina dakikada 30**
  (asilirsa `429 RATE_LIMITED` + `Retry-After`), `page` ust siniri 200 (ustu 200'e indirgenir). Aramasiz liste/sayfa degismedi.
  Web `NewsListPage` "en az 2 karakter" kuralini 3'e cekmeli.
- `POST /api/admin/sync` ve `/api/admin/sync-menu`: kaynak basina saatte 3 (panelin `/api/admin/sources/*/sync` ucuyla ayni
  sayac); asilirsa 429. Yanit bicimi ayni (senkron).
- `GET /api/legal/{type}/versions` ve bekleyen onay/yeniden onay okumalari sozlesme METNINI okumaz (cevap ayni); sunucu onbellegi `legal` ad alani.
- `GET /api/menu/today` `Cache-Control` max-age 300 -> 60 (gun donumunde dunun menusu ara onbellekte 15 dk kalmasin).
- Herkese acik destek (`/api/public/support/tickets`, `/verify`): cevap sozlesmesi ayni; SMTP gonderimi artik veritabani isleminin
  disinda. E-posta basina gunluk 5 sayaci yalniz bal kabagi/hiz elemesini gecen gecerli isteklerde harcanir.

Sunucu davranisi:
- Haber liste/arama/favoriler `content` (TEXT) okumaz (`NewsRow` / `NewsSearchRow` dar projeksiyon).
- Menu: gunluk **06:00 "yakalama"** (`menu.catchup.cron`, K20) YAZILDI ama FINAL-ALL'de **VARSAYILAN KAPALI** (`menu.catchup.cron=-`): CLAUDE.md scraping kurali ("cron'lari sikilastirmayin") kesindir, istisna proje sahibinin kararidir. Acmak icin ortam degiskeni `MENU_CATCHUP_CRON="0 0 6 * * *"`: icinde bulunulan ayda >= 20 gun varsa kaynaga ISTEK ATMAZ; ay bossa gunde en cok bir istek, ay kismen doluysa yalniz ayin ilk 7 gunu. Bakim bandi (`GET /api/status`) yalniz icinde bulunulan ayin menusu bossa gosterilir (`StatusService.markAttempt`: son deneme yazilir, bakim acilmaz).
  sikilastirma" kuralina bilincli istisna): icinde bulunulan ayda >= 20 gun varsa kaynaga ISTEK ATMAZ; ay bossa gunde en cok bir
  istek, ay kismen doluysa yalniz ayin ilk 7 gunu. Bakim bandi (`GET /api/status`) yalniz icinde bulunulan ayin menusu bossa gosterilir
  (`StatusService.markAttempt`: son deneme yazilir, bakim acilmaz).
- Birim haberleri: toplu senkron icin 45 dk sure butcesi (`unitnews.sync.budget-minutes`), kaynaklar en eski denenenden baslar,
  butce dolunca kalan kaynaklar ertesi geceye (`unit_source.last_message`); liste govde okumaz, hedef eslesmesi `unitnews` ad alaninda onbellekli.
- Ilk dolum ve yonetici tetiklemeleri adlandirilmis tek is parcacigi (`content-sync`, `SyncExecutor`); eskiden ortak ForkJoin havuzu.
- Haber senkronu: ortada hata olsa da o ana dek kaydedilen kayitlar icin bildirim gider; `InterruptedException` bayragi korunur;
  `sync_status.message` 500 karaktere kirpilir; ana site yonlendirmeleri elle izlenir (yalniz `www.bingol.edu.tr`, https, en cok 3).
- `CacheService.invalidate`: ayni islemde ayni ad alani commit sonrasi TEK kez gecersiz kilinir (toplu kalori yazimi).
- Yonetici destek/geri bildirim CSV'si id azalan 1000'luk sayfalarla akar (50 bin entity bellekte tutulmaz).

## 2026-11-07: imecli haber listesi + birlesik Kaydedilenler

### GET /api/news imecli surum (geriye uyumlu)
- `cursor` YOKSA: eski davranis aynen (`NewsPage {items,page,totalPages,totalItems}`, `page`/`size`).
- `cursor` VARSA (`0` = ilk sayfa): `CursorPage {items:[NewsSummary], nextCursor}`; `nextCursor=null` son sayfa. `page` yok sayilir.
  Ornek: `GET /api/news?type=HABER&cursor=0&size=20` -> `{"items":[...],"nextCursor":18433290412345}`, sonraki istek `cursor=18433290412345`.
- `q` YOKSA imec opaktir (tarih + id bilesik anahtari, OFFSET yok); siralama `publishedDate DESC NULLS LAST, id DESC` ile birebir.
  `q` VARSA imec bir SONRAKI SAYFA NUMARASIDIR (ayni `size` ile devam edin; en cok sayfa 200). Arama IP basina 30/dk siniri aynen.
- Yalniz `cursor=0` ilk sayfa sunucu onbellegine girer (`news` ad alani); diger imecler onbelleklenmez.
- `size` 1..50. Imeci istemci yorumlamamali (yalnizca bir onceki yanittaki `nextCursor`).
- Birim haberleri `GET /api/news/unit`: OFFSET kullanmaz (yalniz `limit`, kullanicinin bolumune gore tek akis), bu yuzden imecli surum eklenmedi.

### Birlesik Kaydedilenler GET /api/bookmarks
- `type` YOKSA eski davranis (yalniz haber, `BookmarkView`, `cursor` = kayit id'si).
- `type` VARSA birlesik liste `CursorPage<BookmarkItem>`: `ALL|NEWS|EVENT|COMMUNITY|POLL|ACADEMIC|POST|FORUM_TOPIC|FORUM_COMMENT`
  (bos = ALL; gecersiz -> 400 `BOOKMARK_TYPE_INVALID`). Yeni kaydedilen once; `cursor` = onceki `nextCursor` (opak, kaydedilme
  zamani mikrosaniyesi). Gorunmez hale gelen hedefler (silinmis, iptal, gizli, engelli) listeden dusurulur: sayfa `size`'dan kisa
  olabilir, `nextCursor` doluysa devam edin.
- Ogeler: `{type,targetId,savedAt,title,subtitle,imageUrl,link,news}`; `link` uygulama ici yol (`/events/{id}`, `/communities/{id}`,
  `/polls/{id}`, `/academic/events/{id}`, `/forum/topics/{id}`, `/forum/comments/{id}`, `/posts/{id}`, `/news/{id}`), `news` yalniz NEWS'te.
- Kaydetme: `PUT|DELETE /api/bookmarks/{news|event|community|poll|academic}/{id}` (204, idempotent, 404 gorunmez hedef, 409 `BOOKMARK_LIMIT`
  toplam 1000), `GET /api/bookmarks/{tur}/ids`. Gonderi ve forum kayitlari kendi uclarinda kalir (`/api/posts/{id}/save`, forum); veri tasinmadi.
- Sema degismedi (`bookmark.target_type` VARCHAR(16), CHECK yok); KVKK: `bookmarks` disa aktarimi ve hesap silme tum turleri kapsar.
- `docs/openapi.json` yeniden uretilmeli (`OpenApiExportTest`, `-Dopenapi.out=...`): bu dalda uretilmedi.
