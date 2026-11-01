# Birim (fakülte/bölüm) haberleri ve duyuruları: API sözleşmesi

Üniversitenin 23 alt sitesinden (`<kod>.bingol.edu.tr`: 10 fakülte, 5 enstitü, 7 MYO, YDYO) duyuruları çeker; öğrenciye **kendi bölümünün** akışını gösterir. Kaynak sitelere yalnızca zamanlayıcı istek atar (CLAUDE.md bölüm 5); API isteği sırasında asla.

## Eşleme (kural)

- Kullanıcının profilindeki `department` (+ `faculty`, `grade`) → bir kaynak sitenin bölümü (`/bolumler/<slug>/`). Bölüm adı `AudienceKey` ile normalize edilir (sondaki "Bölümü/Programı" atılır).
- **Fakülte doğrulaması (HARDEN A1):** profilde fakülte varsa isabet eden kaynak o fakülteye hizmet etmelidir (`faculty_keys`, `AudienceKey`); **tek isabet de doğrulanır**. "Hemşirelik" hem Sağlık Bilimleri Fakültesi'nde hem Hemşirelik Yüksekokulu'nda geçer: Hemşirelik YO öğrencisine SBF duyuruları gösterilmez, sonuç boştur. Birden çok sitede aynı ad varsa fakülte ayırır, ayıramazsa boş. Profilde fakülte yoksa yalnız **tek** isabet eşleşir (eski davranış). MYO'larda anahtar `meslek yuksekokulu`dur: tek okulda geçen program eşleşmeye devam eder.
- Bölümün kendi duyuru akışı varsa (`/bolumler_/<slug>/duyurular/`) o akış **ve** kaynağın fakülte/okul genel akışı birleşir; yoksa yalnız genel akış.
- **Eşleşme yoksa ya da akış boşsa uç boş dizi (`[]`) döner. İstemci hiçbir şey çizmez: yer tutucu, boş durum, "bulunamadı" yazısı, bilgi satırı YOK. Öğrenci böyle bir özellik olduğunu fark etmemelidir.**
- Yüksek lisans/doktora (`grade` = `MASTER`/`PHD`) kullanıcılarına ayrıca ilgili enstitü akışı da eklenir.

## Kullanıcı uçları (JWT, her rol)

### `GET /api/news/unit?limit=10`
`limit` 1-20 (varsayılan 10). Yanıt: `UnitNewsItem[]`, en yeni önce (`publishedDate` azalan). Eşleşme yok/boş: `[]` (200). Hata (ağ/5xx) halinde istemci de şeridi gizler. Yanıt **kişiseldir**: `Cache-Control: private, no-store` (HARDEN A9; `ShallowEtagHeaderFilter` no-store gören yanıta ETag eklemez, ortak önbellek/vekil sunamaz). Anonim istek 401.

```json
[{
  "id": 123,
  "title": "2026-2027 Güz Dönemi Vize Sınav Programı",
  "summary": "İlk 200 karakter düz metin…",
  "publishedDate": "2026-10-28",
  "sourceName": "Mühendislik ve Mimarlık Fakültesi",
  "unitName": "Bilgisayar Mühendisliği",
  "url": "https://mmf.bingol.edu.tr/bolumler_/bilgisayar-muhendisligi/duyurular/…/",
  "attachments": [{"name": "2026_guz_vize_programi.pdf", "url": "https://mmf.bingol.edu.tr/media/59080/…pdf", "type": "PDF"}]
}]
```
`unitName`: bölüm akışından gelen kayıtta bölüm adı, genel akıştan geleni `null`. `attachments[].type`: `PDF | DOC | XLS | PPT | OTHER` (yalnız `https://` adresleri).

### `GET /api/news/unit/{id}`
Detay: yukarıdaki alanlar + `body` (düz metin, paragraflar `\n\n` ile ayrılır, en çok 8000 karakter). Kullanıcının kapsamında olmayan ya da gizli kayıt: 404 `UNIT_NEWS_NOT_FOUND`. Ekler uygulamada **dış bağlantı olarak** (tarayıcı/PDF görüntüleyici) açılır; dosya sunucuya kopyalanmaz.

## Yönetici uçları (`/api/admin/unit-news`, RBAC `content.read` / `content.write`)

| Uç | Açıklama |
|---|---|
| `GET /sources` | 23 kaynak: `{code, name, kind (FACULTY/INSTITUTE/VOCATIONAL/LANGUAGE), baseUrl, enabled, graduate, facultyKeys[], departmentCount, announcementCount, lastSuccessAt, lastAttemptAt, lastMessage, maintenance}` |
| `PUT /sources/{code}` | `{enabled, facultyKeys[]}`: kaynağı aç/kapat; katalogdaki hangi fakülte adlarına (AudienceKey) hizmet ettiği (eşleme ayarı) |
| `GET /sources/{code}/departments` | Sitenin bölümleri: `{slug, name, nameKey, hasOwnFeed}[]` (salt okunur) |
| `POST /sources/{code}/sync` | Tek kaynağı elle çek (202, rate limit); `POST /sync` hepsini |
| `GET /announcements?source=&q=&hidden=&page=0&size=20` | Sayfalı liste: `{content:[{id, sourceCode, sourceName, unitName, title, url, publishedDate, attachmentCount, hidden}], totalElements, totalPages, number, size}` |
| `PUT /announcements/{id}/hidden` | `{hidden: boolean}`: öğrencilerden gizle/göster |

Hatalar: `{code, message}`; 404 `UNIT_SOURCE_NOT_FOUND`, `UNIT_NEWS_NOT_FOUND`; 400 `UNIT_FACULTY_KEYS_INVALID` (en çok 40 ad), 400 `UNIT_FACULTY_KEY_INVALID` (HARDEN A10: boş olmayan ama anahtara indirgenemeyen ya da virgül içeren ad artık sessizce atılmaz; boş satırlar yok sayılır). Not: yazma hız sınırı kovası tüm `/api/admin/**` yazmalarıyla ortaktır (kaynak güncelleme ayrı kovaya alınmadı).

## Çekim kuralları

Gece 01:00 (`unitnews.sync.cron`), kaynaklar arası ve istekler arası 600 ms bekleme, açık User-Agent, kaynak başına `/duyurular/` (tek sayfa) + yalnız **yeni** kayıtların detayı (kayıt başına bir istek), ilk dolumda son 90 gün ve en çok 60 kayıt/akış. Yapı değişirse exception yok: kaynak `maintenance`, eski veri sunulur. Saklama 365 gün.

Sertleştirme (HARDEN): (A2) senkron durum alanlarını (`last_*`, `maintenance`, `departments_checked_at`) tek `UPDATE` ile yazar, `enabled`/`faculty_keys`'e dokunmaz (`UnitSource` `@DynamicUpdate`); senkron sırası gelen kaynağı yeniden okur, bu arada kapatılmışsa atlar. (A3) HTTP istekleri `followRedirects(false)` + elle en çok 3 sıçrama; her sıçrama `safeUrl` (yalnız https, port boş/443, kullanıcı bilgisi yasak, `*.bingol.edu.tr`) **ve kaynağın kendi host'u** kuralından geçer; gövde en çok 1 MB, istek başına 20 sn, toplam 40 sn. (A5) Detay sayfası okunamazsa kayıt **eklenmez**, sonraki gece yeniden denenir; 3. ardışık başarısızlıkta (bellek içi sayaç) başlık+bağlantıyla eklenir. (A6) `fetchDepartments` iki isteği ve bölüm yenilemesi sonrası ilk akış isteği arasında 600 ms bekler. (A8) 160 karakterden uzun slug, 200 karakterden uzun akış yolu atlanır; bölüm başına hata kaynağı bakıma düşürmez; siteden kalkan bölümler silinir (bulunan sayı eskinin yarısından azsa silme yapılmaz). (A7) Bilinen sınırlama: `@Scheduled` çekim `SchedulerLock` ile sarmalanmamıştır (çok örnekli çalışmada iki örnek aynı gece çeker; tek örnekte sorun yok, bkz. `docs/DEPLOY.md` bölüm 6).
