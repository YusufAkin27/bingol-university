# Birim (fakülte/bölüm) haberleri ve duyuruları: API sözleşmesi

Üniversitenin 23 alt sitesinden (`<kod>.bingol.edu.tr`: 10 fakülte, 5 enstitü, 7 MYO, YDYO) duyuruları çeker; öğrenciye **kendi bölümünün** akışını gösterir. Kaynak sitelere yalnızca zamanlayıcı istek atar (CLAUDE.md bölüm 5); API isteği sırasında asla.

## Eşleme (kural)

- Kullanıcının profilindeki `department` (+ `faculty`, `grade`) → bir kaynak sitenin bölümü (`/bolumler/<slug>/`). Bölüm adı `AudienceKey` ile normalize edilir (sondaki "Bölümü/Programı" atılır).
- Bölümün kendi duyuru akışı varsa (`/bolumler_/<slug>/duyurular/`) o akış **ve** kaynağın fakülte/okul genel akışı birleşir; yoksa yalnız genel akış.
- **Eşleşme yoksa ya da akış boşsa uç boş dizi (`[]`) döner. İstemci hiçbir şey çizmez: yer tutucu, boş durum, "bulunamadı" yazısı, bilgi satırı YOK. Öğrenci böyle bir özellik olduğunu fark etmemelidir.**
- Yüksek lisans/doktora (`grade` = `MASTER`/`PHD`) kullanıcılarına ayrıca ilgili enstitü akışı da eklenir.

## Kullanıcı uçları (JWT, her rol)

### `GET /api/news/unit?limit=10`
`limit` 1-20 (varsayılan 10). Yanıt: `UnitNewsItem[]`, en yeni önce (`publishedDate` azalan). Eşleşme yok/boş: `[]` (200). Hata (ağ/5xx) halinde istemci de şeridi gizler.

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

Hatalar: `{code, message}`; 404 `UNIT_SOURCE_NOT_FOUND`, `UNIT_NEWS_NOT_FOUND`.

## Çekim kuralları

Gece 01:00 (`unitnews.sync.cron`), kaynaklar arası ve istekler arası 600 ms bekleme, açık User-Agent, kaynak başına `/duyurular/` (tek sayfa) + yalnız **yeni** kayıtların detayı (kayıt başına bir istek), ilk dolumda son 90 gün ve en çok 60 kayıt/akış. Yapı değişirse exception yok: kaynak `maintenance`, eski veri sunulur. Saklama 365 gün.
