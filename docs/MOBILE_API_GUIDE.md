# Mobil Geliştirici Rehberi (Bingöl Üniversitesi API)

Bu rehber Flutter (ve diğer) istemci geliştiricileri içindir. Makine okunur sözleşme: [`docs/openapi.json`](openapi.json) (OpenAPI 3.1, 137 yol / 159 işlem; `node scripts/openapi-gen.js` ile canlı sunucudan yenilenir, `node scripts/openapi-check.js` ile gerçek yanıtlarla doğrulanır). Bu rehber OpenAPI'nin anlatamadığı şeyleri anlatır: akışlar, WebSocket, yeniden deneme davranışları. Çelişki olursa **kod doğrudur**; rehberi güncelleyin.

Önerilen paketler: HTTP için `dio` (interceptor), token için `flutter_secure_storage`, STOMP için `stomp_dart_client`, ağ durumu için `connectivity_plus`, yerel mesaj önbelleği için `drift`/`sqflite`.

## 0. Genel kurallar

| Konu | Kural |
|---|---|
| Taban adres | `https://<alan-adı>/api/...`; dosyalar `/files/...`; WebSocket `wss://<alan-adı>/ws`. Yerelde `http://localhost:8080` |
| Biçim | JSON, UTF-8. Zaman damgaları ISO-8601 UTC (`2026-10-26T07:23:32.117112Z`); yalnız tarih alanları `yyyy-MM-dd`. Kimlikler `int64` (Dart `int`) |
| Dil | `Accept-Language: tr` / `en` / `ar` başlığı **her istekte** gönderilmelidir. Hata `message` metni bu dilde gelir. Desteklenmeyen dil Türkçeye düşer. Bildirim/e-posta metinleri ise kullanıcının **kayıtlı** dilindedir (`PATCH /api/users/me {language}`) |
| Boş değerler | Sunucu `null` alanları da yazar. OpenAPI'de `required` olmayan her alan `null` olabilir (belge buna göre üretilir): Dart modellerinde zorunlu olmayan alanları nullable yapın |
| Hata gövdesi | `{"code":"INVALID_CODE","message":"Kod geçersiz veya süresi dolmuş."}`. Mantığı **`code`** üzerine kurun, `message` yalnızca kullanıcıya göstermek içindir |
| Yetkilendirme | `Authorization: Bearer <accessToken>` |
| Bakım | Kaynak site (haber/menü) ulaşılamazsa API 500 vermez; eski veri sunar, `GET /api/status` bakımda olduğunu söyler (bkz. bölüm 9) |

### 0.1 Kimliksiz 401 gövdesi ve 429 başlığı
Token yok/geçersiz/süresi dolmuşsa `ApiAuthenticationEntryPoint` artık **`{"code":"UNAUTHORIZED","message":"..."}`** gövdesi döner (istek dilinde). Uygulama kodundan gelen 401'ler (`INVALID_CREDENTIALS`, `INVALID_REFRESH_TOKEN`) aynı biçimdedir. Yine de 401 mantığını **HTTP durumuna** bağlamak en güvenlisidir (eski sunucularda gövde boş olabilir).

`429 RATE_LIMITED` yanıtlarında **`Retry-After: <saniye>`** başlığı vardır (bkz. bölüm 5).

## 1. Kimlik akışı: kayıt, e-posta kodu, giriş, refresh

```
register ──► (e-postaya 6 haneli kod, asenkron) ──► verify-email ──► {accessToken, refreshToken}
   (kayıt verisi Redis'te bekler; hesap yalnız verify-email ile oluşur)   login ─┘ (zaten kayıtlıysa)
forgot-password ─► verify-reset-code {resetToken} ─► reset-password   (bkz. 1.7)
 her 401'de: refresh (tek uçuş) ──► yeni çift ──► isteği 1 kez tekrar dene
```

### 1.1 Kayıt
```http
POST /api/auth/register
Content-Type: application/json
Accept-Language: tr

{"email":"ayse@bingol.edu.tr","password":"Sifre1234x","displayName":"Ayşe Yılmaz","acceptTerms":true,"language":"tr"}
```
`202 Accepted` → `{"message":"Doğrulama kodu e-posta adresinize gönderildi."}`

**Bekleyen kayıt:** kayıt verisi (şifre özeti, ad, dil) e-posta doğrulanana kadar yalnızca Redis'te (`reg:<email>`, 1 saat) tutulur; veritabanında hesap yoktur. Hesap **`verify-email` başarılı olunca** oluşur ve sözleşme onayı o anda yazılır. 1 saat içinde doğrulanmazsa kayıt düşer: yeniden `register` gerekir. Doğrulanmamış adresle tekrar `register` mevcut bekleyen veriyi ezmez; 60 sn içinde `429 RESEND_COOLDOWN`.

**Mail kuyruğu:** `register`/`resend-code` e-postayı kuyruğa yazıp hemen döner; gönderim arka planda yapılır, yani **kod birkaç saniye (SMTP sorunlarında daha geç) sonra gelir**. Arayüzde "kod gönderildi" deyip geri sayımı hemen başlatın, ekranı kilitlemeyin. Kuyruğa yazılamazsa `503 MAIL_UNAVAILABLE`. Gönderim başarısızsa sunucu en çok 5 kez yeniden dener (1 dk, 5 dk, 30 dk, 2 sa, 12 sa); kullanıcı yine de "kodu yeniden gönder" ile yeni kod isteyebilir.

- Yalnızca `bingol.edu.tr` ve alt alanları; aksi `400 EMAIL_DOMAIN_NOT_ALLOWED`. `acceptTerms` **true olmalı** (sözleşme kabulü sunucuda kaydedilir); `password` 8-72 karakter; `displayName` ≤ 80; `language` isteğe bağlı `tr|en|ar` (verilmezse `Accept-Language`).
- E-postası zaten doğrulanmış hesap için `409 EMAIL_ALREADY_REGISTERED` (kullanıcıyı giriş ekranına yönlendirin).
- IP başına saatte 10 kayıt (`429 RATE_LIMITED`).
- **Akademik alanlar (isteğe bağlı):** `faculty`, `department`, `grade` (bkz. 1.8). Verilirse katalogla doğrulanır; geçersizse `400 ACADEMIC_INVALID`. Bekleyen kayıtla taşınır, `verify-email` ile hesaba yazılır.

### 1.2 Kod gönderme/doğrulama
```http
POST /api/auth/resend-code    {"email":"ayse@bingol.edu.tr"}   → 202 (hesap var olsun olmasın aynı yanıt)
POST /api/auth/verify-email   {"email":"ayse@bingol.edu.tr","code":"482913"}
```
`verify-email` → `200`:
```json
{"accessToken":"eyJhbGciOiJIUzI1NiJ9...","refreshToken":"cn219myvLJlkbdbg-_aBxsQygQN2L8_spDoX26JW3XE","expiresInSeconds":900,"tokenType":"Bearer"}
```
- Kod 6 hane, **10 dk** geçerli, tek kullanımlık, **5 yanlış deneme** (sonra adres 10 dk kilitlenir: `429 TOO_MANY_ATTEMPTS`; `resend-code` veya yeni `register` kilidi açar). Yanlış/süresi dolmuş/bekleyen kayıt yok: aynı `400 INVALID_CODE` (ayırt edilmez). `verify-email` ek sınırı: e-posta başına 10 dk'da 10.
- Yeniden gönderme için **60 sn bekleme** vardır (`429 RESEND_COOLDOWN`): arayüzde geri sayım gösterin.
- Geliştirme ortamında (`MAIL_ENABLED=false`) kod e-posta yerine backend log'una yazılır; `scripts/make-user.sh` bunu otomatikleştirir.

### 1.3 Giriş
```http
POST /api/auth/login   {"email":"ayse@bingol.edu.tr","password":"Sifre1234x"}   → 200 (TokenResponse)
```
Hatalar: `401 INVALID_CREDENTIALS` (kullanıcı yok ve yanlış şifre **aynı yanıt**; ayırt etmeyin), `403 EMAIL_NOT_VERIFIED` (doğrulama ekranına yönlendirin), `403 ACCOUNT_SUSPENDED`. Sınır: IP başına 15 dk'da 30, e-posta başına 15 dk'da 10 deneme.

### 1.4 Token'lar
- **Access token**: JWT (HS256), **15 dk** (`expiresInSeconds: 900`). Yük: `sub` (kullanıcı id), `email`, `role` (`USER|ADMIN`), `iat`, `exp`. İmzayı istemci doğrulayamaz; `exp`'i yalnızca *proaktif yenileme zamanı* için okuyun.
- **Refresh token**: opak, 30 gün, **tek kullanımlıktır** (her yenilemede eskisi ölür, yenisi gelir). Sunucuda yalnızca SHA-256 özeti tutulur.
- İkisini de `flutter_secure_storage`'da saklayın; log'a yazmayın.

### 1.5 Yenileme (refresh) ve tek uçuş (single-flight) kuralı
```http
POST /api/auth/refresh   {"refreshToken":"cn219..."}   → 200 yeni TokenResponse (eski refresh token artık geçersiz)
```
`401 INVALID_REFRESH_TOKEN`: refresh token geçersiz/kullanılmış/süresi dolmuş, hesap pasif → **oturumu bitir, giriş ekranına dön**.

**Refresh token tek kullanımlık olduğundan eşzamanlı iki yenileme isteğinden biri 401 alır ve kullanıcı yanlışlıkla oturumdan atılır.** Bu yüzden uygulamada refresh'i tek bir yerden, tek uçuşta yapın (HTTP istemcisi, WebSocket ve arka plan işleri aynı kilidi paylaşır):

```dart
class AuthSession {
  Future<Tokens>? _inflight;

  /// Aynı anda kaç kişi isterse istesin tek HTTP isteği atılır, sonuç paylaşılır.
  Future<Tokens> refresh() => _inflight ??= _doRefresh().whenComplete(() => _inflight = null);

  Future<Tokens> _doRefresh() async {
    final old = await storage.readRefresh();
    final res = await dio.post('/api/auth/refresh', data: {'refreshToken': old});
    final t = Tokens.fromJson(res.data);
    await storage.write(t);        // ÖNCE yeni çifti yaz (çökme olursa eski, ölü token kalmasın)
    return t;
  }
}

// Dio interceptor: 401 -> refresh (tek uçuş) -> isteği BİR kez tekrar dene
onError: (e, handler) async {
  if (e.response?.statusCode == 401 && !e.requestOptions.extra.containsKey('retried')) {
    try {
      final t = await session.refresh();
      final req = e.requestOptions..extra['retried'] = true
        ..headers['Authorization'] = 'Bearer ${t.accessToken}';
      return handler.resolve(await dio.fetch(req));
    } on DioException catch (r) {
      if (r.response?.statusCode == 401) session.signOut();   // refresh de 401 -> oturum bitti
    }
  }
  handler.next(e);
}
```
Ek öneriler: access token'ın bitişine ~60 sn kala proaktif yenileyin (özellikle WebSocket için); ağ hatasında (zaman aşımı, bağlantı yok) refresh token'ı **silmeyin** (yalnızca sunucudan gelen 401 oturumu bitirir); `refresh` zaman aşımına uğradıysa sonucu bilemezsiniz (sunucu tüketmiş olabilir): bir kez daha denemek 401 verebilir; bu durumda giriş ekranına dönmek kabul edilebilir.

### 1.6 Çıkış ve 401'in diğer nedenleri
- `POST /api/auth/logout {"refreshToken"}` → `204` (refresh token iptal; access token süresi dolana kadar teknik olarak geçerli kalır, istemci siler). Çıkışta WebSocket'i kapatın, yerel mesaj önbelleğini ve bekleyen kuyruğu silin, `DELETE /api/devices/{fcmToken}` ile push kaydını kaldırın.
- `POST /api/auth/logout-all` (Bearer, gövdesiz) → `204`: **tüm cihazlardaki** refresh token'ları siler ve eski access token'ları da reddettirir (çağıran cihaz dahil; yeniden giriş gerekir). Kullanıcı başına 15 dk'da 5 (`429 RATE_LIMITED`). Ayarlarda "tüm cihazlardan çık" için kullanın; sonrasında yerel durumu `logout` ile aynı şekilde temizleyin.
- Hesap **askıya alınırsa** veya **silinirse** access token hemen 401 olur ve yenileme de başarısızdır. Yönetici **rolü değiştirirse** eski token 401 olur; `refresh` yeni rolde token verir (normal akış).
- `GET /api/auth/me` → `{id,email,displayName}`; ayrıntılı profil `GET /api/users/me`.

### 1.7 Şifre sıfırlama (3 adım)
```http
POST /api/auth/forgot-password   {"email":"ayse@bingol.edu.tr"}                              → 202 (hesap olsun olmasın aynı yanıt; kod e-postayla, asenkron)
POST /api/auth/verify-reset-code {"email":"...","code":"482913"}                              → 200 {"resetToken":"..."}
POST /api/auth/reset-password    {"email":"...","resetToken":"...","newPassword":"Yeni1234x"} → 200 {"message":"..."}
```
- Kod 6 hane, 10 dk, tek kullanımlık; deneme/kilit kuralı kayıt koduyla aynıdır (`TOO_MANY_ATTEMPTS`, `INVALID_CODE`). `resetToken` tek kullanımlık, kısa ömürlü bir anahtardır: yalnızca bellekte tutun, saklamayın.
- `newPassword` 8-72 karakter. Başarılı sıfırlamada kullanıcının **tüm oturumları kapanır** (refresh token'lar silinir, eski access token'lar reddedilir): kullanıcıyı giriş ekranına yönlendirin.
- Sınırlar: `forgot-password` IP başına saatte 10 ve e-posta başına saatte 5; `verify-reset-code` ve `reset-password` IP başına 10 dk'da 20 (`429 RATE_LIMITED`).

### 1.8 Akademik katalog (fakülte, bölüm, sınıf)
Kimlik gerektirmez (kayıt ekranında kullanılır). IP başına dakikada 120 istek.
```http
GET /api/catalog/academic        → 200 + ETag + Cache-Control: public, max-age=86400
{"version":1,
 "faculties":[{"id":"muhendislik","name":"Mühendislik Fakültesi",
               "departments":[{"id":"bilgisayar-muhendisligi","name":"Bilgisayar Mühendisliği"}, ...]}, ...],
 "grades":[{"id":"PREP","name":"Hazırlık"},{"id":"1","name":"1. sınıf"}, ... {"id":"6","name":"6. sınıf"},
           {"id":"MASTER","name":"Yüksek lisans"},{"id":"PHD","name":"Doktora"}]}

GET /api/catalog/departments?q=muh&limit=30   → 200 (en çok 30; Türkçe harf/aksan/büyük-küçük duyarsız)
[{"faculty":"Mühendislik Fakültesi","department":"Mühendislik Fiziği"}, ...]
```
- Kayıt (`POST /api/auth/register`) ve profil (`PATCH /api/users/me`) gövdesinde `faculty` / `department` (ad olarak, id değil) ve `grade` (`PREP`, `1`..`6`, `MASTER`, `PHD`) gönderilir. Alanlar isteğe bağlıdır; verilenler katalogla doğrulanır: bölüm, gönderilen (ya da profilde kayıtlı) fakülteye ait olmalıdır; aksi `400 ACADEMIC_INVALID`. Profilde boş metin alanı temizler.
- `GET /api/users/me` yanıtı `faculty`, `department`, `grade` alanlarını döndürür (eski kullanıcılarda serbest metin ya da `null` olabilir).
- Arama kutusunda her tuşta istek atmayın (debounce); tüm kataloğu bir kez çekip yerelde süzmek de mümkündür (≈ 740 program).

## 2. Dil (Accept-Language) ve çok dillilik
- Her istekte `Accept-Language` gönderin (uygulama dili). Sunucu `error.<KOD>` anahtarını bu dilde çevirir; çeviri yoksa Türkçe varsayılan metin döner.
- Arayüz metinleri istemcide çevrilir; **içerik kaynaklı metinler** (haber başlığı, yemek adı) çevrilmez.
- Kullanıcının kayıtlı dili (`language`) push/e-posta metinlerini belirler: uygulama dilini değiştirince `PATCH /api/users/me {"language":"en"}` de çağırın.
- Arapça için RTL ve mantıksal (start/end) yerleşim kullanın.
- Çok dilli içerikler (`GET /api/legal*`, `/api/faq`) ayrı `lang` parametresi almaz; dil **`Accept-Language`** başlığından seçilir. EN/AR sözleşme metni yoksa Türkçe döner.

## 3. Sayfalama sözleşmeleri
İki biçim vardır; hangisinin kullanıldığı uca bağlıdır (aşağıdaki liste `openapi.json`'dan üretilmiştir).

**İmeç (cursor) sayfa** (akan listeler): `GET ...?cursor=<nextCursor>&size=20`
```json
{"items":[{"id":5,"...":"..."},{"id":4,"...":"..."}],"nextCursor":4}
```
- `size` 1-50 arasına kırpılır (varsayılan genelde 20). İlk istekte `cursor` vermeyin. `nextCursor == null` → liste bitti. `nextCursor` bir kayıt kimliğidir; **opak** kabul edin, saklamayın, hesaplamayın. Sıralama genelde yeniden eskiye (`id` azalan).
- Aynı kayıt iki sayfada görünebilir/atlanabilir değildir (offset kullanılmaz), ama sayfalama sırasında yeni kayıtlar üstten eklenebilir: yenilemek için ilk sayfayı yeniden çekin.
- Cursor kullanan uçlar: `/api/notifications` (ek olarak `unreadCount`), `/api/bookmarks`, `/api/communities`, `/api/communities/{id}/members|posts|requests`, `/api/conversations`, `/api/events`, `/api/events/{id}/attendees`, `/api/feedback/mine`, `/api/me/communities`, `/api/me/events`, `/api/support/tickets` ve yönetici listeleri.

**Mesaj geçmişi** (`GET /api/conversations/{id}/messages`) iki yönlüdür:
| Parametre | Anlam | Sıra |
|---|---|---|
| (yok) | en yeni `size` (varsayılan 30) mesaj | yeni → eski |
| `before=<en eski görülen id>` | daha eskiler (yukarı kaydırma) | yeni → eski; `nextCursor` bir sonraki `before` |
| `after=<son bilinen id>` | kaçırılanlar (yeniden bağlanma) | eski → yeni; `nextCursor` doluysa devam için `after=<nextCursor>` |

`before` ve `after` birlikte verilemez (`400 VALIDATION_ERROR`). Yetkisiz/olmayan konuşma `404 CONVERSATION_NOT_FOUND` (varlığı sızdırmaz).

**Diğer imleç/sayfalama biçimleri:**
- `GET /api/users/search?q=&size=&cursor=` → `{"items":[PublicProfile],"nextCursor":20|null}`; `q` en az 2 karakter (`QUERY_TOO_SHORT`), `size` 1-20, `cursor` 0-200 (opak kabul edin), dakikada 60 ve günde 500 istek.
- `GET /api/search?q=`: `type` verilmezse gruplu özet (`groups[]`, `limit` 1-20, `nextCursor` hep `null`). **`type=NEWS` gibi tür verilirse** o tür için sayfalı liste: `limit` 1-50, yanıttaki `nextCursor` bir sonraki istekte `cursor` olarak gönderilir (0-1000, aksi `400 VALIDATION_ERROR`; son sayfada `null`). Yanıt: `{"q","groups":[{"type","items":[]}],"nextCursor"}`.
- `GET /api/users/me/blocks?cursor=&limit=` (limit 1-50) gövdesi **düz dizidir**; devam varsa **`X-Next-Cursor`** yanıt başlığı gelir ve aynen `cursor` olarak verilir. Başlık yoksa liste bitmiştir.
- Takvim için bkz. 11.1.

**Sayfa tabanlı** (`page` 0 tabanlı, `size`): `/api/news` (`type`, `q`), `/api/suggestions`, ve yönetici listeleri (`/api/admin/users|news|audit`). Yanıt: `{"items":[...],"page":0,"totalPages":30,"totalItems":60}`. Haber listesi bu biçimdedir; `type` değerleri `HABER|DUYURU|ETKINLIK`.

## 4. WebSocket / STOMP (mesajlaşma)

Ham WebSocket (SockJS **yok**), alt protokol STOMP 1.2. Adres: `wss://<alan-adı>/ws` (yerelde `ws://`). Kimlik **CONNECT çerçevesinde** doğrulanır (el sıkışma herkese açıktır ama 10 sn içinde CONNECT göndermeyen bağlantı kapatılır). Token'ı **URL'ye koymayın**.

### 4.1 Bağlanma ve abonelikler
```text
>>> CONNECT
accept-version:1.2
host:<alan-adı>
heart-beat:10000,10000
Authorization:Bearer <accessToken>

^@
<<< CONNECTED
version:1.2
heart-beat:10000,10000
^@
>>> SUBSCRIBE
id:sub-0
destination:/user/queue/messages
^@
```
Bağlanır bağlanmaz şu beş kuyruğa abone olun (başka hedefe abonelik reddedilir; `/topic/**` kapalı):

| Kuyruk | İçerik |
|---|---|
| `/user/queue/messages` | yeni mesaj (`MessageView`); **kendi gönderdiğiniz mesaj da buraya düşer** (ack, `clientId` ile eşleştirin) |
| `/user/queue/read-receipts` | `{conversationId,userId,lastMessageId}`: `userId` konuşmada `lastMessageId`'ye kadar okudu |
| `/user/queue/typing` | `{conversationId,userId}`: karşı taraf yazıyor (kalıcı değil, 2 sn'de 1 ile sınırlı) |
| `/user/queue/message-events` | `{type:"edited"\|"deleted"\|"reaction", conversationId, messageId, userId, message?, emoji?, reactions?, at}`: düzenleme, herkes için silme, tepki değişimi; ilgili mesajı yerelde güncelleyin |
| `/user/queue/errors` | `{code,message,clientId}`: komut hataları; bağlantı kapanmaz |

`MessageView`:
```json
{"id":42,"conversationId":7,"senderId":3,"clientId":"7b0c1f3e-...","text":"merhaba","removed":false,"createdAt":"2026-10-26T07:23:32Z",
 "replyToMessageId":40,"replyTo":{"id":40,"senderId":5,"text":"önceki","deleted":false},
 "edited":true,"editedAt":"2026-10-26T07:25:00Z","deleted":false,
 "reactions":[{"emoji":"👍","count":2}],"myReaction":"👍","attachments":[]}
```
- `removed=true` (moderasyonla gizlenmiş ya da engellediğiniz kullanıcının mesajı) veya `deleted=true` (herkes için silinmiş) ise `text` yer tutucudur; içeriği, eki ve yanıt önizlemesini göstermeyin, "kaldırıldı" kutusu çizin.
- `replyTo` alıntılanan mesajın özetidir; `edited=true` ise "düzenlendi" etiketi gösterin. `attachments[]` biçimi için bkz. 4.8.
- Düzenleme/silme/tepki değişimleri `message-events` kuyruğundan canlı gelir; bağlantı kopukken kaçırılanlar için açık sohbetin son sayfasını yeniden çekin.

### 4.2 İstemci → sunucu komutları (`SEND`)
| Hedef | Gövde | Not |
|---|---|---|
| `/app/chat.send` | `{"conversationId":1,"text":"merhaba","clientId":"<UUIDv4>","replyToMessageId":40,"attachmentIds":[9]}` | metin ≤ 2000 karakter; `replyToMessageId` ve `attachmentIds` (en çok 4) isteğe bağlıdır; ek varsa metin boş olabilir |
| `/app/chat.read` | `{"conversationId":1,"lastMessageId":42}` | imleç yalnız ilerler; son mesajı aşan değer `INVALID_MESSAGE_ID`; boş konuşmada no-op; konuşma başına 10 sn'de 20'den sık istek **sessizce** atılır, bu yüzden yalnızca görünen son mesajı gönderin |
| `/app/chat.typing` | `{"conversationId":1}` | 2 sn'de 1, fazlası sessizce atılır |

```text
>>> SEND
destination:/app/chat.send
content-type:application/json

{"conversationId":1,"text":"merhaba","clientId":"7b0c1f3e-4a52-4d2a-9d6e-0f1c2b3a4d5e"}^@
<<< MESSAGE            (destination:/user/queue/messages; ack olarak kendi mesajınız, sunucu id'siyle)
{"id":43,"conversationId":1,"senderId":7,"clientId":"7b0c1f3e-...","text":"merhaba","removed":false,"createdAt":"..."}
<<< MESSAGE            (destination:/user/queue/errors; ör. engelli kullanıcıya)
{"code":"BLOCKED","message":"Bu kullanıcıyla mesajlaşamazsınız.","clientId":"7b0c1f3e-..."}
```
**WS hata `message` metni çevrilmez** (Türkçe varsayılandır): kullanıcıya göstereceğiniz metni **`code`'dan kendi çevirilerinizle** üretin (bölüm 10'daki tr/en/ar tablodan alabilirsiniz). Sık kodlar: `EMPTY_MESSAGE`, `MESSAGE_TOO_LONG`, `CONVERSATION_NOT_FOUND`, `BLOCKED`, `RATE_LIMITED` (kullanıcı başına dakikada 30 mesaj), `BAD_REQUEST` (bozuk yük).

### 4.3 `clientId` ile idempotency ve çevrimdışı kuyruk
- Her gönderilen mesaj için **istemci bir UUIDv4 `clientId`** üretir (≤ 64 karakter). Sunucu `(konuşma, gönderen, clientId)` tekrarını yeni mesaj saymaz: aynı `clientId` ile yeniden gönderim **çift mesaj üretmez** (REST'te `200` + mevcut mesaj, yenide `201`).
- Önerilen akış: mesajı yerelde `PENDING` + `clientId` ile yaz (iyimser göster) → bağlıysa `chat.send`; `/user/queue/messages`'te aynı `clientId` gelince `SENT` + sunucu `id`; **10 sn içinde ack gelmezse** REST yedeği `POST /api/conversations/{id}/messages {"text","clientId"}` ile aynı `clientId`'yi yeniden gönderin (idempotent).
- `errors` kuyruğunda `clientId` taşıyan kalıcı hatalar (`BLOCKED`, `MESSAGE_TOO_LONG`, `CONVERSATION_NOT_FOUND`) → mesaj `FAILED`; `RATE_LIMITED` → geri çekilmeyle tekrar dene.
- Mesaj id'leri konuşma içinde artandır; ekranda `id`'ye göre sıralayıp tekilleştirin (WS ile REST çakışabilir).

### 4.4 Bağlantı yaşam döngüsü, yeniden bağlanma ve boşluk kapatma
1. Uygulama **ön plandayken** bağlı kalın; arka plana geçince kapatın (bildirimler push ile gelir). Öne gelince yeniden bağlanın.
2. Heartbeat 10 sn/10 sn. Sunucu CONNECT göndermeyen/ölü bağlantıyı kapatır; mesaj/gönderim sınırları: tek çerçeve ≤ 16 KB.
3. Kopmada **üstel geri çekilme + jitter**: 1, 2, 4, … en çok 30 sn, ±%20 rastgele. Ağ yoksa (`connectivity_plus`) denemeyin; ağ gelince hemen deneyin.
4. Her yeniden bağlanma denemesinden **önce** access token'ın `exp`'ini kontrol edin; 60 sn içinde dolacaksa önce `session.refresh()` (tek uçuş!) yapın.
5. **Boşluk kapatma (resync)**: Redis pub/sub ve WebSocket "en çok bir kez" teslimdir; gerçek kaynak veritabanıdır. Bağlantı her kurulduğunda (ve uygulama öne geldiğinde) her konuşma için yerelde bilinen **en büyük mesaj id'siyle** `GET /api/conversations/{id}/messages?after=<id>` çağırın (verimlilik için önce `GET /api/conversations` ile `lastMessage.id`'yi karşılaştırıp yalnızca ilerleyenleri çekin). `nextCursor` doluysa tekrarlayın. Gelen mesajları `id` ile tekilleştirin, `clientId` ile yerel `PENDING` kayıtlarını eşleyin.

### 4.5 Token süresi dolunca (WebSocket)
- Access token 15 dk'dır; bağlantı saatlerce açık kalabilir. Sunucu CONNECT anındaki `exp`'i tutar. `exp + 60 sn` geçtikten sonra gelen **her `SEND`** reddedilir (`TOKEN_EXPIRED`); okuma yönündeki yayınlar sürebilir ama gönderemezsiniz.
- Sunucu `exp + 60 sn` sonra bağlantıyı kendisi de **kapatır** (close kodu 1008, neden `TOKEN_EXPIRED`): kapanışta refresh edip yeniden bağlanın ve resync yapın.
- Çözüm (standart): `exp - 60 sn`'de zamanlayıcıyla **proaktif** `session.refresh()` → bağlantıyı kapat → yeni token'la yeniden bağlan → resync (4.4). Mesaj kaybı olmaz.
- CONNECT sırasında token geçersiz/süresi dolmuşsa ya da hesap askıdaysa sunucu `ERROR` çerçevesi gönderir ve bağlantı kurulmaz; `message` başlığı kodu taşır:

| ERROR `message` | Anlam | İstemci davranışı |
|---|---|---|
| `UNAUTHORIZED` | token yok/bozuk | refresh dene; olmazsa giriş ekranı |
| `TOKEN_EXPIRED` | CONNECT'te veya SEND'de token süresi dolmuş | refresh + yeniden bağlan |
| `SUSPENDED` | hesap askıda | oturumu kapat, askı mesajı göster |
| `FORBIDDEN_DESTINATION` | izin verilmeyen hedefe SEND/SUBSCRIBE | istemci hatası; düzeltin |

- Refresh de 401 verirse oturum bitmiştir: giriş ekranı.

### 4.6 Diğer mesajlaşma uçları (REST)
`GET/POST /api/conversations` (birebir `{userId}`: varsa `200` mevcut, yoksa `201`; grup `{title,memberIds}` → `201`; günde en çok 30), `GET/PATCH /api/conversations/{id}`, `POST .../leave`, `POST .../members`, `DELETE .../members/{userId}`, `POST .../read {lastMessageId}` (204; hiç mesajı olmayan konuşmada da 204 no-op), `POST /api/messages/{id}/report {reason,note}`, `GET /api/users/{id}/presence` (`{online,lastSeenAt}`; yalnız ortak konuşması olan, engel ilişkisi olmayan kullanıcılar; aksi `404`), engelleme: `POST/DELETE /api/users/{id}/block`, `GET /api/users/me/blocks`. Ayrıntı: `openapi.json`, tasarım: [MESSAGING_DESIGN.md](MESSAGING_DESIGN.md).

**Kulüp ve etkinlik sohbetleri (sohbet sekmesi).** `ConversationView.type` `DIRECT`, `GROUP`, `CLUB` veya `EVENT` olabilir; ayrıca `communityId` (yalnız `CLUB`) ve `eventId` (yalnız `EVENT`) alanları gelir, diğerlerinde `null`. Sohbeti açmak için:
- `GET /api/communities/{id}/chat`: kulüp sohbetini getir-ya-da-oluştur ve çağıranı ekler; `ConversationView` döner. Yalnız kulübün aktif üyesi (yetkisize/onaysız kulüpte `404 CHAT_ROOM_NOT_FOUND`, kapalı odada `409 CHAT_ROOM_CLOSED`).
- `GET /api/events/{id}/chat`: etkinlik sohbeti; RSVP'si `GOING`/`INTERESTED` olan ya da etkinliği yönetebilen girer (yetkisize `403 FORBIDDEN`, görünmeyen/iptal edilmiş etkinlikte `404 EVENT_NOT_FOUND`).
Mesaj gönderme/okuma/WebSocket mevcut `/api/conversations/{id}/**` ve `/app/chat.*` ile aynıdır. Bu sohbetlere elle üye eklenmez, `leave` çalışmaz (`400 NOT_A_GROUP`); kulüpten ayrılan ya da RSVP'sini kaldıran kullanıcı sohbetten düşer (mesaj gönderme `404`). Kulüp/etkinlik adı sohbet başlığıdır. Durum/katılma için ayrıca `GET /api/communities/{id}/chat-room`, `POST /api/communities/{id}/chat-room/join` (takma ad `/chat/join`) ve `GET /api/events/{id}/chat-room`, `POST /api/events/{id}/chat-room/join` vardır. Etkinlik odası bitişten 7 gün sonra kapanır; kulüpten yasaklanan/ayrılan kullanıcı odadan düşürülür (en geç birkaç dakikada).

### 4.7 Konuşma tercihleri, okunmamış sayacı, mesaj eylemleri
`ConversationView`: `{id,type,title,peer,memberCount,admin,lastMessage,unreadCount,blocked,createdAt,muted,mutedUntil,mutedForever,archived,communityId,eventId}`.
- **Sessize al:** `PUT /api/conversations/{id}/mute` gövde `{"durationMinutes":1..525600}` **veya** `{"forever":true}` (ikisi birden `400`); `DELETE` ile kaldırılır; yanıt `ConversationView`. Süresiz sessizde `mutedUntil` ~100 yıl sonradır: "süresiz" göstermek için **`mutedForever`**'a bakın.
- **Arşiv:** `PUT /api/conversations/{id}/archive {"keepArchived":false}`, `DELETE` ile çıkarılır; liste `GET /api/conversations?archived=true`.
- **Rozet:** `GET /api/conversations/unread-count` → `{"total":3,"mutedTotal":5,"conversations":[{"conversationId":10,"unread":3,"muted":false}]}`; satırlardaki `unreadCount` ile aynı tanım (kendi/silinmiş/engelli gönderici mesajları sayılmaz). `total` sessiz olmayanlar, `mutedTotal` sessizdekiler.
- **Mesaj eylemleri:** gönderim `POST /api/conversations/{id}/messages {"text","clientId","replyToMessageId?","attachmentIds?"}`; düzenleme `PATCH /api/messages/{id} {"text"}` (gönderen, varsayılan 15 dk); herkes için silme `DELETE /api/messages/{id}` (kulüp yöneticisi/moderatörü ve etkinlik organizatörü başkasınınkini de silebilir, diğerleri `403 MESSAGE_DELETE_FORBIDDEN`); tepki `PUT/DELETE /api/messages/{id}/reaction {"emoji"}`, izinli liste `GET /api/messages/reactions`.
- Ek sınırlar: `GET /api/conversations/{id}` dakikada 120; `PATCH`, üye ekle/çıkar ve `leave` kullanıcı başına ortak dakikada 30.

### 4.8 Sohbet görselleri (medya yükleme)
1. `POST /api/conversations/{cid}/media` (multipart, alan **`file`**) → `201` `AttachmentView` `{id,kind,width,height,bytes,contentType,removed,url,thumbUrl}`. Sunucu görseli yeniden kodlar (EXIF temizliği, en çok ~1600 px, sıkıştırılmış); yükleme üst sınırı 5 MB, dakikada 10 ve günde 200 yükleme, mesaja eklenmemiş en çok 20 görsel.
2. Dönen `id` mesaj gönderiminde `attachmentIds`'e konur (mesaj başına en çok 4; REST veya `chat.send`). Hata kodları: `ATTACHMENT_LIMIT`, `ATTACHMENT_INVALID`, `ATTACHMENT_NOT_FOUND`, `MEDIA_BLOCKED` (422), `CHAT_MEDIA_PENDING_LIMIT` (429). Mesaja eklenmemiş kendi yüklemeniz `DELETE .../media/{aid}` ile silinir (mesaja bağlıysa `409 ATTACHMENT_IN_USE`). Sahiplenilmemiş yüklemeler 24 saatte temizlenir.
3. **Okuma kimliklidir:** `url` ve `thumbUrl` (`/api/conversations/{cid}/media/{aid}` ve `/thumb`) Bearer ister; görseli çizerken `Authorization` başlığı verin. Başlık veremeyen bileşenler için `GET .../media/{aid}/link` → `{url,thumbUrl,expiresAt}` kısa ömürlü (varsayılan 5 dk) imzalı adres verir. Gizlenen (`removed=true`) ekte adresler `null`dır.
4. Görseli raporlamak için `POST .../media/{aid}/report {reason,note}` (günlük rapor limiti ortak).

## 5. Rate limit (429) davranışı
- Sınırlar Redis'te **sabit pencere** sayacıdır; aşılınca `429` ve `{"code":"RATE_LIMITED","message":"Çok fazla deneme. Lütfen daha sonra tekrar deneyin."}`. (Doğrulama kodu uçlarında özel kodlar: `RESEND_COOLDOWN`, `TOO_MANY_ATTEMPTS`.)
- 429 yanıtında **`Retry-After: <saniye>`** başlığı gelir (sayacın kalan ömrü; `X-RateLimit-*` yoktur). Otomatik tekrar için bu süreyi bekleyin (başlık yoksa üstel geri çekilme, en az 5 sn, en çok 5 dk); kullanıcıya "biraz sonra tekrar deneyin" gösterin, aynı istekleri döngüde tekrarlamayın. Okundu bilgisi gibi bazı uçlar aşırı isteği hata vermeden sessizce atar (204).
- Okuma (GET) uçlarının çoğunda sınır yoktur; yazma uçlarının hepsinde vardır. Anahtar genelde kullanıcı kimliğidir (kimliksiz uçlarda IP).

| Uç | Sınır |
|---|---|
| `POST /api/auth/register`, `resend-code` | IP başına saatte 10 |
| `POST /api/auth/verify-email` | IP başına 10 dk'da 20 |
| `POST /api/auth/login` | IP başına 15 dk'da 30; e-posta başına 15 dk'da 10 |
| `POST /api/auth/refresh` | IP başına 15 dk'da 60 |
| `POST /api/auth/forgot-password` | IP başına saatte 10; e-posta başına saatte 5 |
| `POST /api/auth/verify-reset-code`, `reset-password` | IP başına 10 dk'da 20 |
| `POST /api/auth/logout-all` | kullanıcı başına 15 dk'da 5 |
| Mesaj gönderme (WS ve REST ortak) | kullanıcı başına dakikada 30 |
| Yazıyor bilgisi | konuşma başına 2 sn'de 1 (sessizce atılır) |
| `POST /api/conversations` | günde 30 |
| Rapor (`/api/reports`, `/api/messages/{id}/report`) | günde 20 |
| Arama `GET /api/search`, `GET /api/users/search` | dakikada 60 |
| Favori ekle/çıkar | dakikada 60 |
| Topluluk oluştur / katıl / gönderi | saatte 5 / saatte 20 / dakikada 10 |
| Etkinlik oluştur / RSVP / QR yoklama | saatte 10 / dakikada 30 / dakikada 20 |
| Avatar yükleme | saatte 10 |
| Sohbet görseli yükleme | dakikada 10, günde 200 |
| `GET /api/me/summary`, `GET /api/events/{id}/attendees/preview` | dakikada 120 |
| `GET /api/communities/{id}/requests` | saatte 240 |
| Hesap silme | saatte 5; veri dışa aktarma günde 3 |
| Destek talebi aç / yanıt | günde 5 / saatte 30 |
| Geri bildirim / oy | günde 10 / saatte 60 |
| Analitik olayı | dakikada 30 |
| WebSocket el sıkışma | IP başına dakikada 600 |

## 6. Push bildirimleri (FCM) yük formatı
Cihaz kaydı: giriş yaptıktan sonra FCM token ile `POST /api/devices {"fcmToken":"...","platform":"ios","appVersion":"1.4.0","locale":"tr"}` → `204` (saatte 30). `platform`: `ios|android|web` (büyük/küçük harf fark etmez, sunucu büyük harfe çevirir; geçersiz `400`); `appVersion` (≤ 32) ve `locale` (≤ 16) isteğe bağlıdır. Upsert: aynı token başka kullanıcıdaysa devredilir; her çağrı `lastSeenAt`'i yeniler, bu yüzden **her açılışta** ve token yenilenince (`onTokenRefresh`) çağırın. Kullanıcı başına en çok 10 cihaz (fazlası en eskiden silinir); 60 gün görülmeyen token sunucuca temizlenir. `GET /api/devices` yanıtında `appVersion`, `locale`, `lastSeenAt` de vardır. Çıkışta `DELETE /api/devices/{token}` (Bearer geçerliyken). Geçersiz token FCM'den `UNREGISTERED` dönünce sunucu tarafından silinir.

Android 13+ için `POST_NOTIFICATIONS` izni isteyin; yerel kanallar: `chat` (MESSAGE), `event` (EVENT), `announcement` (NEWS, ANNOUNCEMENT, COMMUNITY, SYSTEM). iOS için APNs anahtarı Firebase'e yüklenmelidir (bkz. [PUSH_SETUP.md](PUSH_SETUP.md), [MOBILE_PUSH.md](MOBILE_PUSH.md)).

**Yönlendirme sözleşmesi (`data`, tüm değerler string):** `type` (NEWS, ANNOUNCEMENT, EVENT, MESSAGE, COMMUNITY, SYSTEM), varsa `subtype`, **`targetType`** (NEWS, EVENT, COMMUNITY, POST, CONVERSATION, TICKET, FEEDBACK, URL) ve **`targetId`** (hedefin kimliği; `URL` için adres). Eski `target`/`value` anahtarları aynı değerlerle korunur. Türe göre ek kimlikler: `conversationId`, `eventId`, `communityId`, `newsId`, `postId`, `ticketId`; gruplanmış bildirimde `count` (>1). Yönlendirmede önce `targetType`/`targetId`'ye, yoksa ilgili `...Id` alanına, o da yoksa bildirim listesine gidin. Toplam yük 4096 bayt ile sınırlıdır. `badge` yalnızca tek kullanıcıya giden bildirimlerde okunmamış bildirim sayısıdır; toplu gönderimde rozeti açılışta `GET /api/notifications/unread-count` ile güncelleyin.

Aşağıdaki tablolar ek ayrıntıdır. FCM mesajı hem `notification` (başlık/gövde, kullanıcının dilinde) hem **`data`** (yalnızca string anahtar/değer) taşır. Her mesajda `data.type` vardır; yönlendirme için kullanılır:

| `data.type` | Ek `data` anahtarları | Anlam / hedef ekran |
|---|---|---|
| `MESSAGE` | `conversationId`, `messageId` | sohbeti aç (kullanıcı çevrimdışıyken gelir; metin önizlemesi başlıkta) |
| `NEWS` | `newsId` (tekil haber) | haber detayı; toplu duyuruda `newsId` olmayabilir → haber listesi |
| `ANNOUNCEMENT`, `EVENT` | `newsId`, `eventId` | duyuru / etkinlik (`eventId` kullanıcı etkinliği hatırlatma/onay bildirimlerinde) |
| `COMMUNITY` | `communityId`, `postId?` | topluluk / gönderi |
| `SYSTEM` | `ticketId?`, `feedbackId?` | destek talebi yanıtı, geri bildirim durumu, askı/uyarı vb. |
| (kampanya) | `target`, `value?`, `campaignId` | yönetici kampanyası, aşağıda |

**Yönetici kampanyaları**: `data.type` kampanya türüdür (`ANNOUNCEMENT` varsayılan, `NEWS`, `EVENT`, `SYSTEM`); ek olarak `data.campaignId` (string id) ve hedef varsa:

| `data.target` | `data.value` | Davranış |
|---|---|---|
| `NEWS` | haber id | `/api/news/{id}` detayı |
| `EVENT` | etkinlik id | etkinlik detayı |
| `COMMUNITY` | topluluk id | topluluk sayfası |
| `TICKET` | destek talebi id | talep detayı |
| `URL` | `https://...` | yalnız `https://` (sunucu doğrular); uygulama içi tarayıcı/harici açma. Yine de istemcide şemayı kontrol edin |
| `NONE`/yok | yok | yalnızca uygulamayı aç |

Örnek (FCM `data` kısmı):
```json
{"type":"ANNOUNCEMENT","target":"NEWS","value":"41","campaignId":"12"}
```
Uygulama içi bildirim listesi: `GET /api/notifications` → `{"items":[{"id":5,"type":"EVENT","title":"...","body":"...","data":"{\"eventId\":\"2\"}","read":false,"createdAt":"..."}],"nextCursor":4,"unreadCount":4}`. Dikkat: listedeki **`data` bir JSON dizesidir** (nesne değil): `jsonDecode(item.data)` yapın; anahtarlar push `data`'sıyla aynıdır. Okundu: `POST /api/notifications/read {"ids":[5,4]}` veya `{"all":true}` (204). Tercihler: `GET/PUT /api/notifications/preferences` (`news, announcements, events, messages, communities`; `SYSTEM` her zaman gider).

Not: Firebase servis hesabı (`FCM_CREDENTIALS_JSON`/`FILE`) girilmedikçe sunucu push göndermez; yalnızca uygulama içi liste dolar. Sessiz saatler ve tercihler push'a da uygulanır. Gönderim arka planda yapılır, geçici hatada 3 kez yeniden denenir; süreç yeniden başlarsa kuyruktaki push kaybolabilir, bildirim kutusu kalıcıdır.

## 7. Dosya yükleme sözleşmesi
Yükleme uçları `multipart/form-data`, **alan adı `file`** (topluluk/etkinlik kapağı dahil) ve oturum (Bearer) ister:

| Uç | Alan | Tür | En büyük | Sınır |
|---|---|---|---|---|
| `POST /api/users/me/avatar` | `file` | jpg, png, webp | **2 MB** | saatte 10 |
| `POST /api/communities/{id}/cover` | `file` | jpg, png, webp | **3 MB** | saatte 10 |
| `POST /api/communities/{id}/posts/upload` | `file` | jpg, png, webp | **3 MB** | saatte 20 |
| `POST /api/events/{id}/cover` | `file` | jpg, png, webp | **3 MB** | saatte 10 |

- Doğrulama **`Content-Type`** üzerinden yapılır: parçanın `Content-Type`'ı mutlaka `image/jpeg|image/png|image/webp` olmalı (Dio `MultipartFile.fromFile(path, contentType: MediaType('image','jpeg'))`). Dosya adını sunucu üretir (UUID); istemcinin adı kullanılmaz.
- Hatalar: `400 INVALID_FILE` (tür/boş), `413 FILE_TOO_LARGE` (ayrıca Spring genel üst sınırı 5 MB; istek 6 MB'ı aşarsa da `FILE_TOO_LARGE`), `503 STORAGE_UNAVAILABLE`. Yüklemeden önce istemcide küçültüp sıkıştırın.
- Yanıt göreli URL döndürür (`/files/avatars/<uuid>.jpg` biçiminde, avatar için profil nesnesinde `avatarUrl`). Görseli `https://<alan-adı>` + yol ile **kimliksiz** `GET` ile indirebilirsiniz (herkese açık, `Cache-Control: max-age=30 gün, immutable`; URL değişmez, önbellekleyin).
- Gönderi görseli akışı: önce `.../posts/upload` ile yükleyip dönen URL'yi `POST /api/communities/{id}/posts {text, imageUrl}` içinde gönderin.
- Sohbet görselleri ayrı bir akıştır (kimlikli okuma, `attachmentIds`): bkz. 4.8. Mesaj metni düz metindir (≤ 2000 karakter; HTML/Markdown yorumlanmaz, `Text` ile çizin).

## 8. Sürüm kontrolü ve bakım akışı
Uygulama açılışında (ve öne her gelişte, en çok birkaç dakikada bir) kimliksiz iki çağrı yapın:

```http
GET /api/app/version?platform=android&version=1.0.3      # platform: android | ios; version: 1.2.3.4 biçimi (sayılar+nokta)
→ {"updateRequired":false,"updateAvailable":true,"latestVersion":"1.1.0","storeUrl":"https://play.google.com/..."}
GET /api/app/info
→ {"appName":"Bingöl Üniversitesi","website":"https://www.bingol.edu.tr","contactEmail":null,"supportEmail":null,"phone":null,"address":null,
   "social":{"instagram":null,"twitter":null,"youtube":null},"banner":null,
   "maintenance":{"enabled":false,"message":"Sistem bakımda. Lütfen daha sonra tekrar deneyin."},"languages":["tr","en","ar"]}
```
Karar akışı:
1. `updateRequired=true` → **zorunlu güncelleme** ekranı (kapatılamaz), `storeUrl`'ye yönlendir. API çağrılarına devam etmeyin.
2. `updateAvailable=true` → kapatılabilir "yeni sürüm var" iletisi.
3. `maintenance.enabled=true` → uygulama genelinde bakım bandı/ekranı (`maintenance.message` dilde gelir); **sunucu bu modda istekleri reddetmez**, yalnızca bayrak yükseltir: yazma işlemlerini kapatıp okumayı serbest bırakmak ürün kararıdır. `banner` doluysa duyuru bandı gösterin.
4. `GET /api/status` → `{"NEWS":{"maintenance":false,"lastSuccessAt":"...","lastAttemptAt":"...","message":null},"MENU":{...}}`: haber/menü kaynağı ulaşılamıyorsa `maintenance=true`, **eski veri sunulmaya devam eder**; listenin üstünde "veriler güncel olmayabilir" uyarısı gösterin, hata ekranı değil.
5. Ağ/5xx hatalarında genel hata ekranı + yeniden dene; `GET /actuator/health` yalnızca altyapı içindir.

## 9. KVKK uçları: verilerimi indir, hesabımı sil
- **Verilerimi indir**: `GET /api/users/me/export` → `200 application/json` (`Content-Disposition: attachment; filename="my-data.json"`): `{"exportedAt":"...","<bölüm>":{...}}` biçiminde profil, mesajlar, favoriler, etkinlikler, topluluklar, destek kayıtları, rıza kayıtları, analitik özetleri vb. (bölümler `DataExporter` ekleyen modüllere göre büyür; sabit alan listesine güvenmeyin). Günde 3 kez. Dosya olarak kaydedip paylaşım menüsüyle sunun; log'a yazmayın.
- **Hesabımı sil**: `DELETE /api/users/me` gövde `{"password":"..."}` → `204` (yanlış şifre `403 WRONG_PASSWORD`; saatte 5). Silme **anonimleştirmedir**: kişisel alanlar temizlenir, refresh token'lar iptal edilir, access token anında 401 olur. Çağrı başarılı olunca istemci: token'ları, yerel veritabanını, önbelleği, FCM kaydını silip karşılama ekranına dönmeli. Onay penceresi ve "geri alınamaz" uyarısı gösterin.
- **Sözleşmeler**: `GET /api/legal` (liste), `GET /api/legal/{type}` (`TERMS, PRIVACY, KVKK, COMMUNITY_RULES`; dil `Accept-Language`), onay bekleyenler `GET /api/legal/consents/pending` (giriş gerekir; yeni sürüm yeniden onay istiyorsa liste doludur → onay ekranı), onay `POST /api/legal/consents`, geçmiş `GET /api/legal/consents/mine`. Kayıtta `acceptTerms=true` zorunludur.
- İzinler: yalnızca kendi verinize erişirsiniz; başkasının kaynağına istek `404` döner (varlık sızdırılmaz).

## 10. Hata kodları (tr / en / ar)
Tablo `backend/src/main/resources/i18n/messages*.properties` dosyalarından **otomatik** üretilir: `node scripts/openapi-errors.js --inject docs/MOBILE_API_GUIDE.md` (HTTP sütunu kodda `ApiException(HttpStatus.X, "KOD")` kullanımlarından çıkarılır; birden fazla durum olabilir; `-` = yalnızca çerçeve/doğrulama katmanından gelir). Metinlerdeki `{0}`, `{1}` sunucu tarafında doldurulur. İstemcide aynı anahtarlarla kendi çevirinizi tutun (WebSocket hatalarında sunucu çevirmez).

Genel durum kodları: `400` doğrulama/iş kuralı, `401` kimlik, `403` yetki/askı, `404` yok (veya başkasının kaynağı), `409` çakışma, `413` büyük dosya, `429` sınır, `5xx` sunucu (genel hata ekranı).

<!-- ERRORS:BEGIN -->

| Kod | HTTP | Turkce (tr) | English (en) | Arabic (ar) |
|---|---|---|---|---|
| `ACCOUNT_SUSPENDED` | 403 | Hesabınız askıya alınmıştır. | Your account has been suspended. | تم تعليق حسابك. |
| `ALREADY_MEMBER` | 409 | Zaten üyesiniz veya isteğiniz bekliyor. | You are already a member or your request is pending. | أنت عضو بالفعل أو أن طلبك قيد الانتظار. |
| `ALREADY_REPORTED` | 409 | Bu içeriği zaten raporladınız. | You have already reported this content. | لقد أبلغت عن هذا المحتوى مسبقًا. |
| `ALREADY_RESOLVED` | 409 | Rapor zaten sonuçlandırılmış. | This report has already been resolved. | تمت معالجة هذا البلاغ مسبقًا. |
| `BANNED` | 403 | Bu topluluktan uzaklaştırıldınız. | You have been removed from this community. | تمت إزالتك من هذا المجتمع. |
| `BLOCKED` | 403 | Bu kullanıcıyla mesajlaşamazsınız. | You cannot message this user. | لا يمكنك مراسلة هذا المستخدم. |
| `BOOKMARK_LIMIT` | 409 | En fazla {0} kayıt tutulabilir. Önce bazılarını kaldırın. | You can save at most {0} items. Remove some first. | يمكنك حفظ {0} عنصرًا كحد أقصى. أزل بعضها أولًا. |
| `CAMPAIGN_NOT_CANCELLABLE` | 409 | Yalnızca bekleyen kampanyalar iptal edilebilir. | Only pending campaigns can be cancelled. | يمكن إلغاء الحملات المعلّقة فقط. |
| `CAMPAIGN_NOT_FOUND` | 404 | Kampanya bulunamadı. | Campaign not found. | الحملة غير موجودة. |
| `CANNOT_BLOCK_SELF` | 400 | Kendinizi engelleyemezsiniz. | You cannot block yourself. | لا يمكنك حظر نفسك. |
| `CANNOT_MESSAGE_SELF` | 400 | Kendinizle konuşma başlatamazsınız. | You cannot start a conversation with yourself. | لا يمكنك بدء محادثة مع نفسك. |
| `CANNOT_MODIFY_SELF` | 400 | Bu işlemi kendi hesabınız üzerinde yapamazsınız. | You cannot perform this action on your own account. | لا يمكنك تنفيذ هذا الإجراء على حسابك الخاص. |
| `CANNOT_REPORT_SELF` | 400 | Kendi içeriğinizi raporlayamazsınız. | You cannot report your own content. | لا يمكنك الإبلاغ عن المحتوى الخاص بك. |
| `CANNOT_SUSPEND_ADMIN` | 400 | Yönetici askıya alınamaz. | An administrator cannot be suspended. | لا يمكن تعليق حساب مسؤول. |
| `CAPACITY_TOO_LOW` | 409 | Kapasite, katılacak kişi sayısından ({0}) az olamaz. | Capacity cannot be lower than the number of attendees ({0}). | لا يمكن أن تكون السعة أقل من عدد الحاضرين ({0}). |
| `CHECKIN_CLOSED` | 409 | Yoklama henüz açılmadı. | Check-in has not opened yet. | لم يُفتح تسجيل الحضور بعد. |
| `CHECKIN_CONFLICT` | 409 | Yoklama işleniyor, tekrar deneyin. | Check-in is being processed, please try again. | جارٍ معالجة تسجيل الحضور، يرجى المحاولة مرة أخرى. |
| `COMMUNITY_LIMIT` | 409 | En fazla {0} topluluğun sahibi olabilirsiniz. | You can own at most {0} communities. | يمكنك امتلاك {0} مجتمعات كحد أقصى. |
| `COMMUNITY_NOT_ACTIVE` | 409 | Topluluk henüz yayında değil. | The community is not published yet. | المجتمع غير منشور بعد. |
| `COMMUNITY_NOT_FOUND` | 404 | Topluluk bulunamadı. | Community not found. | المجتمع غير موجود. |
| `CONVERSATION_NOT_FOUND` | 404 | Konuşma bulunamadı. | Conversation not found. | المحادثة غير موجودة. |
| `EMAIL_ALREADY_REGISTERED` | 409 | Bu e-posta ile zaten kayıt olunmuş. | This email is already registered. | هذا البريد الإلكتروني مسجّل مسبقًا. |
| `EMAIL_DOMAIN_NOT_ALLOWED` | 400 | Yalnızca bingol.edu.tr uzantılı e-posta ile kayıt olunabilir. | Only email addresses ending in bingol.edu.tr can register. | يمكن التسجيل فقط بعناوين البريد الإلكتروني المنتهية بـ bingol.edu.tr. |
| `EMAIL_NOT_VERIFIED` | 403 | Giriş için önce e-posta adresinizi doğrulayın. | Please verify your email address before signing in. | يرجى تأكيد بريدك الإلكتروني قبل تسجيل الدخول. |
| `EMPTY_MESSAGE` | 400 | Mesaj boş olamaz. | The message cannot be empty. | لا يمكن أن تكون الرسالة فارغة. |
| `EVENT_ENDED` | 409 | Etkinlik sona erdi. | The event has ended. | انتهت الفعالية. |
| `EVENT_FULL` | 409 | Etkinliğin kontenjanı doldu. | The event is full. | اكتمل عدد المشاركين في الفعالية. |
| `EVENT_NOT_EDITABLE` | 409 | Bu etkinlik düzenlenemez. | This event cannot be edited. | لا يمكن تعديل هذه الفعالية. |
| `EVENT_NOT_FOUND` | 404 | Etkinlik bulunamadı. | Event not found. | الفعالية غير موجودة. |
| `EVENT_NOT_OPEN` | 409 | Etkinlik henüz yayında değil. | The event is not published yet. | الفعالية غير منشورة بعد. |
| `EVENT_STARTED` | 409 | Başlamış etkinliğin başlangıcı değiştirilemez. | The start time of an event that has started cannot be changed. | لا يمكن تغيير وقت بدء فعالية بدأت بالفعل. |
| `FAQ_NOT_FOUND` | 404 | Soru bulunamadı. | Question not found. | السؤال غير موجود. |
| `FEEDBACK_NOT_FOUND` | 404 | Geri bildirim bulunamadı. | Feedback not found. | الملاحظات غير موجودة. |
| `FILE_TOO_LARGE` | 413 | Dosya en fazla {0} MB olabilir. | The file can be at most {0} MB. | الحد الأقصى لحجم الملف {0} ميغابايت. |
| `FORBIDDEN` | 403 | Bu işlem için yetkiniz yok. | You are not authorized to do this. | ليست لديك صلاحية لتنفيذ هذا الإجراء. |
| `GROUP_FULL` | 400 | Bir grupta en fazla {0} üye olabilir. | A group can have at most {0} members. | يمكن أن تضم المجموعة {0} أعضاء كحد أقصى. |
| `INVALID_AUDIENCE` | 400 | Hedef kitle geçersiz. | The target audience is invalid. | الجمهور المستهدف غير صالح. |
| `INVALID_CODE` | 400 | Kod geçersiz veya süresi dolmuş. | The code is invalid or has expired. | الرمز غير صالح أو انتهت صلاحيته. |
| `INVALID_CREDENTIALS` | 401 | E-posta veya şifre hatalı. | Incorrect email or password. | البريد الإلكتروني أو كلمة المرور غير صحيحة. |
| `INVALID_DATES` | 400 | Bitiş zamanı başlangıçtan sonra olmalı. | The end time must be after the start time. | يجب أن يكون وقت الانتهاء بعد وقت البدء. |
| `INVALID_EVENT` | 400 | Geçersiz olay verisi. | Invalid event data. | بيانات الحدث غير صالحة. |
| `ACADEMIC_INVALID` | 400 | Fakülte, bölüm veya sınıf bilgisi geçersiz. Listeden seçin. | Invalid faculty, department or grade. Please choose from the list. | الكلية أو القسم أو الصف غير صالح. يرجى الاختيار من القائمة. |
| `INVALID_FACULTY` | 400 | Geçersiz fakülte. Listedeki fakültelerden birini seçin. | Invalid faculty. Please choose one from the list. | الكلية غير صالحة. يرجى اختيار كلية من القائمة. |
| `INVALID_FILE` | 400 | Geçersiz dosya türü. | Invalid file type. | نوع الملف غير صالح. |
| `INVALID_IMAGE_URL` | 400 | Görsel yalnızca yüklenen dosyalardan olabilir. | The image must be one of the uploaded files. | يجب أن تكون الصورة من الملفات المرفوعة فقط. |
| `INVALID_MESSAGE_ID` | 400 | Geçersiz mesaj kimliği. | Invalid message ID. | معرّف الرسالة غير صالح. |
| `INVALID_RANGE` | 400 | Geçersiz tarih aralığı. Biçim yyyy-MM-dd olmalı ve en fazla {0} gün seçilebilir. | Invalid date range. Use the yyyy-MM-dd format and select at most {0} days. | نطاق التاريخ غير صالح. استخدم الصيغة yyyy-MM-dd واختر {0} يومًا كحد أقصى. |
| `INVALID_REFRESH_TOKEN` | 401 | Oturum süresi doldu, tekrar giriş yapın. | Your session has expired. Please sign in again. | انتهت جلستك. يرجى تسجيل الدخول مرة أخرى. |
| `INVALID_ROLE` | 400 | Yalnızca MODERATOR veya MEMBER atanabilir. | Only MODERATOR or MEMBER can be assigned. | يمكن تعيين MODERATOR أو MEMBER فقط. |
| `INVALID_VERSION` | 400 | Geçersiz sürüm numarası. | Invalid version number. | رقم الإصدار غير صالح. |
| `LAST_ADMIN` | 409 | Son yönetici düşürülemez veya silinemez. | The last administrator cannot be demoted or deleted. | لا يمكن خفض رتبة المسؤول الأخير أو حذفه. |
| `LEGAL_NOT_FOUND` | 404 | Belge bulunamadı. | Document not found. | المستند غير موجود. |
| `MAIL_UNAVAILABLE` | 503 | Doğrulama e-postası şu anda gönderilemiyor. Lütfen daha sonra tekrar deneyin. | The verification email cannot be sent right now. Please try again later. | تعذّر إرسال رسالة التحقق حاليًا. يرجى المحاولة لاحقًا. |
| `MALFORMED_REQUEST` | - | İstek biçimi geçersiz. | The request format is invalid. | تنسيق الطلب غير صالح. |
| `MEMBER_NOT_FOUND` | 404 | Üye bulunamadı. | Member not found. | العضو غير موجود. |
| `MESSAGE_NOT_FOUND` | 404 | Mesaj bulunamadı. | Message not found. | الرسالة غير موجودة. |
| `MESSAGE_TOO_LONG` | 400 | Mesaj en fazla {0} karakter olabilir. | A message can be at most {0} characters. | يمكن أن تتكون الرسالة من {0} حرفًا كحد أقصى. |
| `NOT_A_GROUP` | 400 | Bu işlem yalnızca gruplarda yapılabilir. | This action is only available in groups. | هذا الإجراء متاح في المجموعات فقط. |
| `NOT_A_SUGGESTION` | 400 | Yalnızca öneriler herkese açık panoya alınabilir. | Only suggestions can be added to the public board. | يمكن إضافة الاقتراحات فقط إلى اللوحة العامة. |
| `NOT_FOUND` | 404 | Bulunamadı. | Not found. | غير موجود. |
| `NOT_GROUP_ADMIN` | 403 | Bu işlem için grup yöneticisi olmalısınız. | You must be a group admin to do this. | يجب أن تكون مشرف المجموعة لتنفيذ هذا الإجراء. |
| `NOT_MEMBER` | 403, 404 | Bu özel topluluğun içeriğini yalnızca üyeler görebilir. | Only members can see the content of this private community. | لا يمكن لغير الأعضاء رؤية محتوى هذا المجتمع الخاص. |
| `NOT_PENDING` | 409 | Bu kayıt onay beklemiyor. | This item is not awaiting approval. | هذا العنصر لا ينتظر الموافقة. |
| `NOT_RSVPED` | 403 | Yoklama için etkinliğe katılacağınızı önceden bildirmiş olmalısınız. | To check in, you must have confirmed that you are going to the event. | لتسجيل الحضور يجب أن تكون قد أكدت مشاركتك في الفعالية مسبقًا. |
| `NO_RECIPIENTS` | 400 | Bu hedef kitlede alıcı bulunamadı. | No recipients were found for this audience. | لم يتم العثور على مستلمين لهذا الجمهور. |
| `OWNER_CANNOT_LEAVE` | 409 | Topluluk sahibi ayrılamaz. | The community owner cannot leave. | لا يمكن لمالك المجتمع المغادرة. |
| `PAST_EVENT` | 400 | Geçmişe etkinlik açılamaz. | An event cannot be created in the past. | لا يمكن إنشاء فعالية في الماضي. |
| `PIN_LIMIT` | 409 | En fazla {0} yazı sabitlenebilir. | At most {0} posts can be pinned. | يمكن تثبيت {0} منشورات كحد أقصى. |
| `POST_NOT_FOUND` | 404 | Yazı bulunamadı. | Post not found. | المنشور غير موجود. |
| `QUERY_TOO_SHORT` | 400 | En az 2 karakter girin. | Enter at least 2 characters. | أدخل حرفين على الأقل. |
| `RATE_LIMITED` | 429 | Çok fazla deneme. Lütfen daha sonra tekrar deneyin. | Too many attempts. Please try again later. | محاولات كثيرة جدًا. يرجى المحاولة لاحقًا. |
| `REPORT_NOT_FOUND` | 404 | Rapor bulunamadı. | Report not found. | البلاغ غير موجود. |
| `REQUEST_NOT_FOUND` | 404 | Bekleyen istek bulunamadı. | Pending request not found. | لم يتم العثور على طلب معلّق. |
| `REQUEST_PENDING` | 409 | Katılma isteğiniz zaten bekliyor. | Your join request is already pending. | طلب الانضمام الخاص بك قيد الانتظار بالفعل. |
| `RESEND_COOLDOWN` | 429 | Yeni kod için lütfen 1 dakika bekleyin. | Please wait 1 minute before requesting a new code. | يرجى الانتظار دقيقة واحدة قبل طلب رمز جديد. |
| `RSVP_CONFLICT` | 409 | İsteğiniz zaten işleniyor, tekrar deneyin. | Your request is already being processed, please try again. | طلبك قيد المعالجة بالفعل، يرجى المحاولة مرة أخرى. |
| `SETTING_NOT_FOUND` | 404 | Ayar bulunamadı. | Setting not found. | الإعداد غير موجود. |
| `SLUG_CONFLICT` | 409 | Topluluk adı çakıştı, tekrar deneyin. | The community name conflicted, please try again. | تعارض اسم المجتمع، يرجى المحاولة مرة أخرى. |
| `STORAGE_UNAVAILABLE` | 503 | Dosya şu anda kaydedilemiyor. | The file cannot be saved right now. | تعذّر حفظ الملف حاليًا. |
| `SUGGESTION_NOT_FOUND` | 404 | Öneri bulunamadı. | Suggestion not found. | الاقتراح غير موجود. |
| `TARGET_NOT_FOUND` | 404 | Raporlanan içerik bulunamadı. | The reported content was not found. | المحتوى المبلَّغ عنه غير موجود. |
| `TARGET_TYPE_UNSUPPORTED` | 400 | Bu tür henüz raporlanamıyor. | This type cannot be reported yet. | لا يمكن الإبلاغ عن هذا النوع حاليًا. |
| `TERMS_NOT_ACCEPTED` | - | Devam etmek için sözleşmeleri kabul etmelisiniz. | You must accept the agreements to continue. | يجب قبول الاتفاقيات للمتابعة. |
| `TICKET_CLOSED` | 409 | Bu talep kapatılmış. Yeni bir talep açın. | This request is closed. Please open a new one. | هذا الطلب مغلق. يرجى فتح طلب جديد. |
| `TICKET_NOT_FOUND` | 404 | Talep bulunamadı. | Support request not found. | طلب الدعم غير موجود. |
| `TOO_MANY_ATTEMPTS` | 429 | Çok fazla hatalı deneme. Yeni kod isteyin. | Too many incorrect attempts. Request a new code. | محاولات خاطئة كثيرة. اطلب رمزًا جديدًا. |
| `TOO_MANY_OPEN_TICKETS` | 409 | En fazla {0} açık talebiniz olabilir. Önce mevcut taleplerden birini kapatın. | You can have at most {0} open requests. Close one of your existing requests first. | يمكنك الاحتفاظ بـ {0} طلبات مفتوحة كحد أقصى. أغلق أحد طلباتك الحالية أولًا. |
| `TURKISH_CONTENT_REQUIRED` | - | Türkçe başlık ve metin zorunludur. | A Turkish title and message are required. | العنوان والنص بالتركية مطلوبان. |
| `UNAUTHORIZED` | 401 | Giriş gerekli. | Sign-in required. | تسجيل الدخول مطلوب. |
| `UNSUPPORTED_LANGUAGE` | - | Desteklenmeyen dil. Geçerli değerler: tr, en, ar. | Unsupported language. Valid values: tr, en, ar. | لغة غير مدعومة. القيم الصالحة: tr و en و ar. |
| `USER_NOT_FOUND` | 404 | Kullanıcı bulunamadı. | User not found. | المستخدم غير موجود. |
| `USER_UNAVAILABLE` | 403 | Bu kullanıcıya mesaj gönderilemez. | A message cannot be sent to this user. | لا يمكن إرسال رسالة إلى هذا المستخدم. |
| `USE_LEAVE` | 400 | Kendinizi çıkaramazsınız; ayrılmayı kullanın. | You cannot remove yourself; use leave instead. | لا يمكنك إزالة نفسك؛ استخدم خيار المغادرة. |
| `VALIDATION_ERROR` | 400 | Geçersiz istek. | Invalid request. | طلب غير صالح. |
| `VERSION_OUTDATED` | 409 | Bu belgenin yeni bir sürümü yayımlandı. Güncel sürümü onaylayın. | A newer version of this document has been published. Please accept the current version. | تم نشر إصدار أحدث من هذا المستند. يرجى قبول الإصدار الحالي. |
| `WRONG_PASSWORD` | 403 | Şifre hatalı. | Incorrect password. | كلمة المرور غير صحيحة. |

<!-- ERRORS:END -->

## 11. Uç haritası (özet)
Tam liste ve şemalar için `docs/openapi.json` (gruplar: `1-public`, `2-authenticated`, `3-admin`).
| Alan | Uçlar |
|---|---|
| Herkese açık | `GET /api/news`, `/api/news/{id}`, `/api/menu`, `/api/menu/today`, `/api/status`, `/api/app/info`, `/api/app/version`, `/api/faq`, `/api/legal*`, `/api/faculties`, `/files/**` |
| Kimlik | `/api/auth/*` (bölüm 1) |
| Profil | `GET /api/me/summary` (11.1), `GET/PATCH/DELETE /api/users/me`, `POST /api/users/me/avatar`, `GET /api/users/{id}`, `GET /api/users/search`, `GET /api/departments` |
| Bildirim | `/api/devices`, `/api/notifications*` |
| Mesajlaşma | `/api/conversations*` (mute/archive/unread-count dahil), `/api/conversations/{cid}/media*`, `/api/messages/*`, `GET /api/communities/{id}/chat`, `GET /api/events/{id}/chat`, `/ws` (bölüm 4) |
| Topluluk / etkinlik | `/api/communities*`, `/api/events*`, `/api/me/communities`, `/api/me/events` (QR yoklama: `GET /api/events/{id}/checkin-code` organizatör, `POST /api/events/{id}/check-in` katılımcı) |
| Arama / favori | `GET /api/search`, `/api/bookmarks*` |
| Destek | `/api/feedback`, `/api/suggestions`, `/api/support/tickets*`, `/api/faq` |
| Moderasyon | `POST /api/reports`, `POST /api/messages/{id}/report`, engelleme uçları |
| Analitik | `POST /api/analytics/events` (≤ 50 olay; `app_open`, `screen_view`, `search`; kişisel veri göndermeyin, `@` içeren değer reddedilir) |
| KVKK | `GET /api/users/me/export`, `DELETE /api/users/me` (bölüm 9) |

### 11.1 Yeni ve değişen uçlar (özet)
- **`GET /api/me/summary`** (Bearer, dakikada 120) → `{"communities":3,"events":1,"bookmarks":12,"unreadNotifications":4,"unreadMessages":7}`. Ana sayfa/sekme rozetleri için tek istek.
- **Haber:** `GET /api/news?type=` büyük/küçük harf toleranslıdır; geçersiz tür `400 NEWS_TYPE_INVALID`; `size` 1-50. `NewsSummary`/`NewsDetail`'de yeni **`eventDate`** (`yyyy-MM-dd` veya `null`; yalnız ETKINLIK). Sıralama yayın tarihi azalan, tarihsizler sonda. `GET /api/menu?month=yyyy-MM` geçersiz ay `400 MENU_MONTH_INVALID`. `GET /api/status` her kaynakta **`maintenanceMessage`** (istek dilinde; bakım yoksa `null`) taşır; `message` teknik ayrıntıdır, kullanıcıya `maintenanceMessage` gösterin.
- **Takvim:** `GET /api/events/calendar?month=YYYY-MM` → `CalendarItem[]`. USER öğelerinde yeni `myRsvp`, `goingCount`, `interestedCount`, `capacity` (`null` = sınırsız), `status`, `communityName`; OFFICIAL öğelerde bunlar `null`. Önceki aydan süren etkinlikler ay içinde görünür (`date` ay içinde kalır, `startsAt` gerçek başlangıç). Sonuç sınırlıdır (USER 300, resmi 200); sınır aşılırsa **`X-Truncated: true`** başlığı gelir (kullanıcıya "tümü gösterilmiyor" notu verin). OFFICIAL öğe tarihi haberin `eventDate` değeri varsa o, yoksa yayın tarihidir.
- **Katılımcı önizleme:** `GET /api/events/{id}/attendees/preview` (Bearer, dakikada 120) → `{"goingCount":42,"interestedCount":7,"avatars":[{"userId","displayName","avatarUrl"}]}`; en çok 8 avatar, yalnız gizlilik ayarı izin verenler. Tam liste (`/attendees`) organizatöre kısıtlıdır.
- **Topluluk:** `GET /api/communities/categories` → `[{"category":"Spor","count":3}]` (yalnız ACTIVE+PUBLIC; `category` değeri `GET /api/communities?category=Spor` filtresinde aynen kullanılır, `q` ad/açıklamada arar). Katılım: önce `GET /api/communities/{id}/join-questions` → `[{id,question}]`; sonra `POST /api/communities/{id}/join {"answers":[{"questionId":1,"answer":"..."}]}` → `{"status":"ACTIVE"|"PENDING"}`; soru varsa hepsi yanıtlanmalı, yoksa `400 ANSWERS_REQUIRED`. Açık kulüpte gövde gerekmez. Yönetici için `GET /api/communities/{id}/requests?include=answers` her isteğe `answers[]` ekler (verilmezse alan yoktur); onay/ret sonrası yanıtlar silinir.
- **Engeller:** `GET /api/users/me/blocks?cursor=&limit=` düz dizi + `X-Next-Cursor` (bölüm 3).
- Cihaz kaydı ve push `data` değişiklikleri bölüm 6'da, `logout-all` ile şifre sıfırlama bölüm 1'dedir.
- **Hesap silme** artık cihazları, bildirimleri, favorileri, kulüp başvuru yanıtlarını ve topluluk üyeliklerini de temizler; yerel veriyi silmek istemcinin işidir.

`/api/admin/**` yönetim panelidir (web); mobil istemci kullanmaz.

## 12. Sözleşme testi ve belge yenileme
```bash
# Yığın ayakta iken (ör. compose proje adı wt_t7, port 8107)
BASE=http://localhost:8107 ADMIN_PASSWORD=... node scripts/openapi-gen.js      # docs/openapi.json'ı canlı sunucudan yeniler
BASE=http://localhost:8107 ADMIN_PASSWORD=... COMPOSE_PROJECT_NAME=wt_t7 node scripts/openapi-check.js
node scripts/openapi-errors.js --inject docs/MOBILE_API_GUIDE.md                # hata tablosunu yeniler
```
`openapi-check.js`: belge ile canlı belgenin aynılığını, kimlikli/kimliksiz erişim kurallarını (Swagger/`/v3/api-docs` yalnızca ADMIN; arayüz üretimde kapalı), kimlik akışını ve parametresiz tüm GET uçlarının gerçek yanıtlarını şemaya karşı (tür, zorunlu alan, belgesiz alan, null) doğrular; `FORCE_SEED=1` ile örnek kayıt oluşturup POST gövdelerini de doğrular. Swagger arayüzü yalnızca `dev` profilinde (`SPRING_PROFILES_ACTIVE=dev` veya `SWAGGER_UI_ENABLED=true`) açılır ve yine ADMIN ister.
