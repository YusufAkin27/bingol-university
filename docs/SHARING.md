# İçerik paylaşımı (SH): bağlantı sözleşmesi, önizleme sayfası, mesajla paylaşım

Kullanıcı bir gönderiyi, Reels'i, haberi, duyuruyu veya etkinliği (1) uygulama içinde bir kullanıcıya **mesajla** paylaşabilir (sohbette önizleme kartı), (2) WhatsApp/Instagram gibi uygulamalara **bağlantı önizlemesiyle** (OpenGraph) paylaşabilir; (3) bağlantıya tıklayan kişide uygulama yüklüyse ilgili sayfa açılır, değilse mağazaya gidilir.

Bu belge BE + web altyapısının ve mobilin dayanacağı sözleşmedir. Kod: `backend/.../share/*` (`ShareService`, `SharePageController`, `SharePageRenderer`), `messaging` (mesaj `share` alanı), `web/scripts/gen-app-links.mjs`, `deploy/Caddyfile`, `web/nginx.conf`.

## 1. Paylaşım bağlantısı

```
https://bukampus.com.tr/s/{t}/{id}
```

| `t` | Tür | `id` | API'deki karşılığı (`share.type`) | Uygulamada açılacak sayfa |
|---|---|---|---|---|
| `p` | gönderi | `post.id` | `POST` | gönderi ayrıntısı (`GET /api/posts/{id}`) |
| `r` | Reels (video gönderi) | `post.id` | `REEL` | Reels oynatıcı (aynı `post.id`; `GET /api/posts/{id}`) |
| `n` | haber / duyuru / (siteden gelen) etkinlik haberi | `news_item.id` | `NEWS` | haber ayrıntısı (`GET /api/news/{id}`; tür `DUYURU` ise duyuru) |
| `e` | kullanıcı/kulüp etkinliği | `user_event.id` | `EVENT` | etkinlik ayrıntısı (`GET /api/events/{id}`) |

- `id` yalnız rakamdır (en çok 18 hane). Taban adres sunucuda `app.share.base-url` (`PUBLIC_WEB_URL`, varsayılan `https://bukampus.com.tr`); istemci bağlantıyı **kendisi üretmek yerine** mesaj/kart yanıtındaki `share.url` değerini kullanmalıdır. Gönderi/Reels kartında `url` her zaman `/s/p/` ya da `/s/r/` kodunu **gönderenin seçtiği türe** göre taşır (`POST` → `p`, `REEL` → `r`).
- Özel şema yedeği (Instagram/Facebook iç tarayıcıları evrensel bağlantıyı açmaz): `bukampus://s/{t}/{id}` — mobil bu şemayı ve evrensel bağlantıyı **aynı** yönlendiriciye bağlar.
- Uygulamanın açtığı yol kümesi yalnız `/s/*` (AASA/assetlinks). Başka site yolları (`/tr/...`) uygulamaya açılmaz.
- Uygulamada açma kuralı (mobil): oturum yoksa önce giriş; giriş sonrası hedef sayfa. İçerik görüntülenemiyorsa (silinmiş/gizli/yetki yok) ilgili ayrıntı ucu zaten 404 döner → "içerik bulunamadı" ekranı.

## 2. Herkese açık önizleme sayfası: `GET /s/{t}/{id}`

- permitAll, kimlik gerekmez. Tek HTML (satır içi CSS, tek sabit satır içi betik, harici kaynak yok). `Content-Type: text/html;charset=UTF-8`.
- **Dil:** `Accept-Language` (tr varsayılan, en, ar; Arapçada `dir="rtl"`). Yanıt `Vary: Accept-Language`.
- **Meta etiketleri:** `<title>`, `description`, `og:site_name` ("BÜ Kampüs"), `og:type` (haber için `article`, diğerleri `website`), `og:title`, `og:description`, `og:url` (kanonik paylaşım adresi), `og:image` (+`og:image:alt`; marka görseli için 1200x630), `og:locale`, `twitter:card=summary_large_image` (+title/description/image), `apple-itunes-app` (Smart App Banner: `app-id=6830530499, app-argument=<paylaşım URL'si>`), `robots=noindex,nofollow`.
- **Görsel kuralı (`og:image`):**
  - gönderi/Reels: `https://bukampus.com.tr/s/{p|r}/{id}/img` — yalnız herkese açık gönderinin küçük resmi/posteri (bkz. §2.2);
  - haber/duyuru: kaynak görseli, yalnız `https` ve `bingol.edu.tr` (alt alanlar dahil), kullanıcı bilgisi ve alışılmadık port yok (`http` → `https`); aksi halde marka görseli;
  - etkinlik: kapak (`/files/...` → mutlak adres); yoksa marka görseli;
  - görseli olmayan / gizli / bulunamayan içerik: `https://bukampus.com.tr/og.png` (marka).
- **Görünür sayfa:** kart (görsel, tür rozeti, başlık, alt başlık, açıklama), **"Uygulamada aç"** (`bukampus://s/{t}/{id}`; Android UA'da `intent://` bağlantısına çevrilir: uygulama yoksa Play'e düşer), **App Store** ve **Google Play** düğmeleri, "tüm indirme seçenekleri" (`/{dil}/download`).
- **Yönlendirme betiği (yalnız mobil UA):** iOS'ta gizli `iframe` ile `bukampus://` denenir, Android'de `intent://`; sayfa 1,5 sn içinde gizlenmez/odak kaybetmezse (`visibilitychange`/`pagehide`/`blur` yok) mağazaya yönlenir: iOS UA → `https://apps.apple.com/tr/app/id6830530499`, Android UA → `https://play.google.com/store/apps/details?id=tr.com.bukampus.app`. **Masaüstü:** otomatik yönlendirme yok (kart görünür kalır); "tüm indirme seçenekleri" web indirme sayfasına (`/{dil}/download`) gider.
- **CSP:** sayfa kendi başlığını yazar (genel API CSP'si bu yolda devre dışı): `default-src 'none'; script-src 'sha256-…'; style-src 'sha256-…'; img-src 'self' https://bingol.edu.tr https://*.bingol.edu.tr data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`. Betik ve stil sabittir (dinamik veri `data-*` özniteliklerinde), özetleri sunucuda hesaplanır; `unsafe-inline` yoktur.
- **Önbellek/hız:** `Cache-Control: public, max-age=300`; IP başına dakikada 300 (`app.share.page-per-minute`; aşımda nötr sayfa + `429` + `Retry-After`, `no-store`). Redis kesikse sayfa sınırsız yine sunulur (yalnız veritabanı). Her yanıt `X-Robots-Tag: noindex, nofollow`.

### 2.1 Gizlilik (kesin)

Yalnız **herkese açık** içerik önizlenir:

| Tür | Herkese açık sayılma koşulu |
|---|---|
| haber/duyuru | `news_item.hidden = false` |
| etkinlik | `status = ACTIVE`; kulüp etkinliğiyse kulüp `ACTIVE` ve `PUBLIC` (özel kulüp etkinliği yalnız üyesine) |
| gönderi/Reels | silinmemiş ve gizlenmemiş, yazar hesabı `ACTIVE`, yazar **gizli hesap değil** |

Aksi her durumda (gizli, silinmiş, yok, askıdaki yazar, geçersiz kimlik, tanınmayan tür `t`) **aynı nötr sayfa** döner: başlık "BÜ Kampüs'te bir içerik", marka görseli, "Uygulamada aç" + mağaza düğmeleri, **HTTP 200**, `noindex`. Var/yok ayrımı yapılmaz (kimlik dışında HTML aynıdır). Tüm metinler HTML kaçışlıdır; URL'ler sunucuda doğrulanmış değerlerdir ve ayrıca kaçışlanır.

### 2.2 OpenGraph görseli: `GET /s/{p|r}/{id}/img`

Yalnız yukarıdaki kurallara göre herkese açık gönderinin **küçük resmi / video posteri** (kısa süreli `public, max-age=300`); aksi `404` (gövde yok). Sayfa bu durumda `og.png` marka görseline düşmez; gönderide görsel yoksa sayfa zaten `og:image` olarak markayı koyar. Ham video/tam boyutlu görsel bu uçtan **sunulmaz**.

## 3. Uygulama bağlantısı doğrulama (Universal Links / App Links)

`https://bukampus.com.tr/.well-known/apple-app-site-association` (uzantısız, `application/json`, yönlendirme yok; eski iOS için kökte `/apple-app-site-association` da) ve `/.well-known/assetlinks.json`. İçerik `web/scripts/gen-app-links.mjs` ile **web imajı derlenirken** üretilir (`web/Dockerfile`, `npm run build`'den sonra):

```json
// apple-app-site-association
{"applinks":{"apps":[],"details":[{"appIDs":["<TEAMID>.tr.com.bukampus.app"],"paths":["/s/*"]}]}}
// assetlinks.json
[{"relation":["delegate_permission/common.handle_all_urls"],
  "target":{"namespace":"android_app","package_name":"tr.com.bukampus.app",
            "sha256_cert_fingerprints":["AA:BB:…"]}}]
```

**Gerçek değerler kullanıcıdan gelir; uydurulmaz.** Değer yoksa ilgili dosya **üretilmez** (nginx yalın 404 verir), derleme uyarı basar ve başarısız olmaz; bağlantı yine mağaza/web sayfasına düşer, yalnız uygulamayı doğrudan açmaz.

| Değer | Nereden | Ortam değişkeni (`.env.prod` / build arg) | `scripts/deploy.sh` |
|---|---|---|---|
| Apple Team ID (10 karakter) | Apple Developer > Membership | `APPLE_TEAM_ID` | `DEPLOY_APPLE_TEAM_ID` |
| Play uygulama imzalama sertifikası SHA-256 (yükleme anahtarı DEĞİL) | Play Console > Uygulama bütünlüğü > Play Uygulama İmzalama | `PLAY_APP_SIGNING_SHA256` (virgülle birden çok) | `DEPLOY_PLAY_APP_SIGNING_SHA256` |

Adımlar için docs/DEPLOY.md "Paylaşım bağlantıları". Mobil tarafı: iOS Associated Domains `applinks:bukampus.com.tr`; Android manifest `android:autoVerify="true"` + `https://bukampus.com.tr` `pathPrefix="/s/"` filtresi ve `bukampus://s/` şeması.

## 4. Mesajla paylaşım

### 4.1 İstek

`POST /api/conversations/{cid}/messages` (ve WebSocket `/app/chat.send` `ChatSend`) gövdesine isteğe bağlı `share`:

```json
{
  "clientId": "c-9f2",
  "text": "Buna bak!",
  "share": { "type": "POST", "id": 123 }
}
```

- `share.type`: `POST | REEL | NEWS | EVENT` (büyük/küçük harf serbest). `share.id`: içerik kimliği.
- `text` isteğe bağlı kısa nottur (boş olabilir; mevcut kurallar: temizleme, en çok 2000 karakter, **mesaj şifreleme aynen geçerli** — not şifreli gövdede saklanır). Boş `text` yalnız `share` doluyken kabul edilir.
- `share`, `attachmentIds` ve `viewOnce` ile **birleşmez** (422 `SHARE_TARGET_INVALID`).
- **Doğrulama:** paylaşan kullanıcı içeriği **görebiliyor** olmalı (gizli hesabın gönderisini yalnız kabul edilmiş takipçisi paylaşabilir; engel/silinmiş/gizlenmiş/yetkisiz/olmayan içerik → ayrım yapılmadan `422 SHARE_TARGET_INVALID`, 3 dilde çevrilmiş mesaj). Mesaj hakkı/rate limit harcanmadan önce denetlenir.
- Diğer akış aynıdır: `clientId` ile idempotent (tekrar gönderimde `200` + aynı mesaj), yanıt verme (`replyToMessageId`), düzenleme (not), herkes için silme, raporlama, tepki. Sessizce engelli (gölge engel) karşı tarafa hiçbir şey gitmez.

### 4.2 `MessageView.share` (yanıt; geriye uyumlu, isteğe bağlı alan)

Paylaşım mesajlarında `MessageView` (`GET .../messages`, `POST .../messages` yanıtı, WS `/user/queue/messages`, konuşma listesi `lastMessage`) `share` alanını taşır. **Kart OKUMA ANINDA, görüntüleyene göre hesaplanır** (veritabanında yalnız tür + kimlik tutulur): aynı mesaj gönderen için `available=true`, alıcı içeriği göremiyorsa (gizli hesap, engel, özel kulüp) `available=false` olabilir.

```json
{
  "id": 4412, "conversationId": 17, "senderId": 5, "clientId": "c-9f2",
  "text": "Buna bak!", "removed": false, "createdAt": "2026-11-05T10:12:00Z",
  "share": {
    "type": "POST",
    "id": 123,
    "available": true,
    "title": "Kampüste bahar",
    "subtitle": "Ayşe Yılmaz",
    "imageUrl": "/api/posts/media/55?thumb=true",
    "kind": "PHOTO",
    "url": "https://bukampus.com.tr/s/p/123"
  }
}
```

```json
{ "type": "NEWS", "id": 88, "available": true, "title": "Final takvimi açıklandı",
  "subtitle": "Bingöl Üniversitesi", "imageUrl": "https://www.bingol.edu.tr/media/9/a.jpg",
  "kind": "DUYURU", "url": "https://bukampus.com.tr/s/n/88" }
```

```json
{ "type": "EVENT", "id": 3, "available": true, "title": "Bahar Şenliği",
  "subtitle": "Fotoğraf Kulübü", "imageUrl": "/files/events/ab12.jpg", "url": "https://bukampus.com.tr/s/e/3" }
```

İçerik silinmiş / gizlenmiş / alıcı göremiyor (**başlık, alt başlık, görsel, tür ayrıntısı BOŞ — alanlar hiç gönderilmez**):

```json
{ "type": "POST", "id": 123, "available": false, "url": "https://bukampus.com.tr/s/p/123" }
```

Alanlar:

| Alan | Açıklama |
|---|---|
| `type` | `POST \| REEL \| NEWS \| EVENT` (gönderenin seçtiği tür; `REEL` kartı oynatıcıda açılır) |
| `id` | içerik kimliği (`post.id`, `news_item.id`, `user_event.id`) |
| `available` | görüntüleyen şu an içeriği görebiliyor mu; `false` ise istemci **"Bu içerik artık görüntülenemiyor"** yazar ve dokunmayı kapatır |
| `title` | gönderi metni (yoksa yazar adı), haber/etkinlik başlığı (en çok 140 karakter) |
| `subtitle` | yazar adı (gönderi), "Bingöl Üniversitesi" (haber), kulüp adı ya da yer (etkinlik); dile bağlı kelime içermez, tür etiketini istemci yerelleştirir |
| `imageUrl` | küçük resim: göreli `/api/posts/media/{id}?thumb=true` (oturumlu istek, `Authorization` ile), göreli `/files/...` (herkese açık), ya da `https` `bingol.edu.tr` görseli; yoksa gönderilmez |
| `kind` | `NEWS`: `HABER \| DUYURU \| ETKINLIK`; `POST/REEL`: `PHOTO \| VIDEO`; `EVENT`: gönderilmez |
| `url` | herkese açık paylaşım bağlantısı (kopyala/dışarı paylaş için); içerik sızdırmaz |

- Silinen/gizlenen/engelli/çözülemeyen **mesajda** `share` hiç gönderilmez (mevcut `removed`/`deleted` kuralları).
- Yanıt alıntısında (`replyTo.text`) yalnız paylaşım içeren, notsuz mesajın alıntısı `"🔗"` olur.
- **Sohbet listesi `lastMessage` önizlemesi nötrdür:** `share` yalnız `type`, `id`, `available`, `url` taşır (başlık/görsel yok); `text` boşsa istek dilinde `🔗 Gönderi paylaştı` / `🔗 Reels paylaştı` / `🔗 Haber paylaştı` / `🔗 Etkinlik paylaştı` (en/ar karşılıkları `i18n/share*.properties`) yazılır, notlu paylaşımda not korunur.
- **Gerçek zamanlı:** WS `/user/queue/messages` alıcıya **kendi** kartıyla gider (alıcı göremiyorsa `available=false`).

### 4.3 Push / bildirim önizlemesi

Metin gövdesi alıcının **kayıtlı dilinde** nötrdür; içerik başlığı/ayrıntısı yoktur: `🔗 Gönderi paylaştı` (tr), `🔗 Shared a post` (en), `🔗 شارك منشوراً` (ar); Reels/Haber/Etkinlik için `share.preview.*` anahtarları. Gönderenin notu varsa `…: not` eklenir (100 karakter). Başlık/`data` (`conversationId`, `messageId`, `conversationType`) mevcut sohbet bildirimiyle aynıdır; uygulama içi bildirim kutusuna düz metin yazılmaz.

### 4.4 Hata

| Durum | Kod | Mesaj (tr) |
|---|---|---|
| içerik yok / göremiyor / tür geçersiz / ek ya da tek gösterimlik ile birlikte | `422 SHARE_TARGET_INVALID` | Bu içerik paylaşılamıyor. |
| boş metin ve `share` yok | `400 EMPTY_MESSAGE` | (mevcut) |

## 5. Veri, KVKK ve saklama

- Şema: `message.share_type` (`VARCHAR(8)`), `message.share_ref_id` (`BIGINT`), yalnızca referans (V1280). İçerik kopyası **tutulmaz**; kart her okumada güncel duruma göre kurulur (silinen/gizlenen içerik anında "kullanılamaz" olur). Kullanıcı kimliği tutan yeni sütun yok → `AccountDataPurgerCoverageTest` etkilenmez. Paylaşım referansı mesajla aynı saklama/silme yaşam döngüsündedir (`DeletedMessageRetention`, hesap silmede mesaj gönderen anonimleşir).
- KVKK dışa aktarma (`sentMessages`): her mesaj için `sharedContentType` ve `sharedContentId` (paylaşılan içeriğin kendisi değil).
- Herkese açık sayfa kişisel veri taşımaz; yalnız herkese açık içeriği gösterir. Yazar adı yalnız zaten herkese açık gönderilerde ve yalnız herkese açık hesaplar için görünür.

## 6. Yönlendirme / altyapı

- Caddy (`deploy/Caddyfile`, `Caddyfile.bukampus` bunu içe aktarır): `/s/*` → backend (`@backend` listesi; gövde sınırı 128 KB, `noindex`). Web router'ında `/s` rotası yoktur (site rotaları `/tr /en /ar` önekli) → çakışma yok.
- `web/nginx.conf` (+ `nginx-tls.conf.example`): web konteynerine doğrudan erişen kurulumlar için `location ^~ /s/` backend'e vekiller; `security.conf` **bilerek eklenmez** (ikinci bir CSP satır içi betiği engellerdi).
- `.well-known/*` nginx konumları hazırdı (docs/SEO_TECHNICAL.md §7); dosyalar artık §3'teki betikle üretilir.
- Duman doğrulama (canlı): `curl -sI https://bukampus.com.tr/s/n/1` → `200`, `content-type: text/html`; `curl -s -A WhatsApp https://bukampus.com.tr/s/n/<id> | grep og:`; `curl -s https://bukampus.com.tr/.well-known/apple-app-site-association`.

## 7. Profil paylaşımı + QR (`USER`, kod `u`)

- **Bağlantı:** `https://bukampus.com.tr/s/u/{kullaniciId}` (sayısal kimlik; kullanıcı adı DEĞİL: ad değişince bağlantı bozulmaz, `ShareTarget` int kimlikle çalışır). Özel şema `bukampus://s/u/{id}`. `ShareType.USER("u")`; `message.share_type VARCHAR(8)` kolonuna `USER` sığar, CHECK/enum kısıtı yok, **yeni migration gerekmedi**. Android App Link (`/s/` önek) ve AASA (`/s/*`) zaten kapsar.
- **Herkese açık sayfa:** `GET /s/u/{id}` HER kimlik için AYNI nötr profil sayfasıdır ("BÜ Kampüs profili", OpenGraph + Smart App Banner + mağaza yönlendirmesi, noindex, HTTP 200): ad/@kullanıcı adı/avatar anonim sayfada ASLA yoktur, böylece var/yok/gizli/engelli/askıda ayrımı sızmaz ve kimlik taramasıyla isim toplanamaz (`SharePageController`, `ShareService.publicView` USER için her zaman boştur).
- **Mesaj kartı (görüntüleyene göre, `ShareService.resolveUsers`):** yalnız giriş yapmış görüntüleyene; `available=false` (içerik sızmaz): hesap yok / ACTIVE değil (askı, silinmiş) / iki yönlü engel. Kendi profilim her zaman görünür. Gizli hesabın başlığı (ad, @kullanıcı adı, avatar) zaten her üyeye görünür; içerik kilidi profil ekranında takip isteği akışıyla sürer. Karta yalnız `title`=ad, `subtitle`=`@kullaniciAdi`, `imageUrl`=avatar (`AvatarVisibility` gizlilik kararına uyar; gizliyse yok) girer. Gönderme: `share:{type:"USER",id}`, görünmüyorsa 422 `SHARE_TARGET_INVALID`. Sohbet listesi önizlemesi `share.preview.USER`.
- **Mobil:** profilde (kendi/başkası) "Profili paylaş" mevcut paylaşım sayfasıyla; "QR kodum" (Profil üst satırı, Profil menüsü, Ayarlar) ve "QR tara" (QR ekranı, Profil menüsü, Ayarlar, Arama). QR içeriği = yukarıdaki https bağlantısı (telefon kamerası da açar). Tarama yalnız `parseShareLink` ile çözülen kendi alan adımızı/`bukampus://` şemasını ve YALNIZ `u` türünü kabul eder; başka her değer "Bu bir BÜ Kampüs profil kodu değil" der, taranan metin asla açılmaz. QR çizimi `features/events/qr_painter.dart` (saf Dart, bağımsız çözücü testli) yeniden kullanılır; yeni bağımlılık yok.

