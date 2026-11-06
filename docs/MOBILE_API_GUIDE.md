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

{"email":"ayse@bingol.edu.tr","password":"123456","displayName":"Ayşe Yılmaz","acceptTerms":true,"language":"tr"}
```
`202 Accepted` → `{"message":"Doğrulama kodu e-posta adresinize gönderildi."}`

**Okul numarasıyla kimlik:** tüm kimlik uçlarında (`register`, `verify-email`, `resend-code`, `login`, `forgot-password`, `verify-reset-code`, `reset-password`) `email` alanı **tam e-posta ya da yalnızca okul numarası** olabilir. Numara = e-posta kullanıcı adı: `226051015` ve `226051015@bingol.edu.tr` aynı hesaptır. Numara yalnız rakam, 6-12 hane (boşluk/tire/nokta temizlenir); aksi `400 VALIDATION_ERROR`. Sunucu her yerde tam e-postaya çevirir (`GET /auth/me` → `email` tam e-posta). Kayıt formunda önce tüm bilgiler (ad, e-posta/numara, şifre, fakülte/bölüm/sınıf, sözleşme) toplanır, doğrulama kodu **`register` çağrısının sonunda** gönderilir.

**Bekleyen kayıt:** kayıt verisi (şifre özeti, ad, dil) e-posta doğrulanana kadar yalnızca Redis'te (`reg:<email>`) tutulur; veritabanında hesap yoktur. Süre `app.auth.pending-registration-ttl` (varsayılan **72 saat**), yenilenmez; dolunca kayıt silinir, yeniden `register` gerekir. Hesap **`verify-email` başarılı olunca** oluşur ve sözleşme onayı o anda yazılır. **Doğrulanmamış giriş denemesi:** bekleyen kaydın şifresiyle `login` → `403 EMAIL_NOT_VERIFIED` (istemci "doğrulanmamış" sayfasını açıp kod girişi + `resend-code` sunar; girilen e-posta/numara ve şifre sayfada tutulabilir); şifre yanlışsa genel `401 INVALID_CREDENTIALS` (kaydın varlığı sızmaz). Doğrulanana kadar oturum açılamaz. Doğrulanmamış adresle tekrar `register` mevcut bekleyen veriyi ezmez; 60 sn içinde `429 RESEND_COOLDOWN`.

**Mail kuyruğu:** `register`/`resend-code` e-postayı kuyruğa yazıp hemen döner; gönderim arka planda yapılır, yani **kod birkaç saniye (SMTP sorunlarında daha geç) sonra gelir**. Arayüzde "kod gönderildi" deyip geri sayımı hemen başlatın, ekranı kilitlemeyin. Kuyruğa yazılamazsa `503 MAIL_UNAVAILABLE`. Gönderim başarısızsa sunucu en çok 5 kez yeniden dener (1 dk, 5 dk, 30 dk, 2 sa, 12 sa); kullanıcı yine de "kodu yeniden gönder" ile yeni kod isteyebilir.

- Yalnızca `bingol.edu.tr` ve alt alanları; aksi `400 EMAIL_DOMAIN_NOT_ALLOWED`. `acceptTerms` **true olmalı** (sözleşme kabulü sunucuda kaydedilir); `password` **en az 6**, en çok 72 karakter (başka kural yok; kısa ise `400 PASSWORD_TOO_SHORT`; yönetici hesapları 12+ ve güçlü şifre ister, `400 PASSWORD_TOO_WEAK`); `displayName` **isteğe bağlı** (≤ 80; verilmezse sunucu geçici ad atar: e-posta kullanıcı adı ya da `"Öğrenci"`; yönetici kaydında zorunlu); `language` isteğe bağlı `tr|en|ar` (verilmezse `Accept-Language`).
- **Kayıtta `faculty`/`department`/`grade` gönderilmez** (boş kalır); e-posta doğrulandıktan sonra tek seferlik zorunlu "profili tamamla" adımında girilir: `PATCH /api/users/me` gövde `{"faculty":"Mühendislik Fakültesi","department":"Bilgisayar Mühendisliği","grade":"3"}` (tek istek; bölüm/sınıfın ilk atanmasında kota yok; geçici adın ilk değişimi de 7 günlük `DISPLAY_NAME_COOLDOWN` kuralına sayılmaz). Profil tamamlanana kadar `GET /users/me` içinde `faculty`/`department`/`grade` `null`'dır. (`displayName` kayıtta verilmezse — eski istemci — geçici ad atanır; bkz. yukarı.)
- E-postası zaten doğrulanmış hesap için `409 EMAIL_ALREADY_REGISTERED` (kullanıcıyı giriş ekranına yönlendirin).
- IP başına saatte 10 kayıt (`429 RATE_LIMITED`); `resend-code` IP başına saatte 10, e-posta başına saatte 5.
- **Akademik alanlar (isteğe bağlı):** `faculty`, `department`, `grade` (bkz. 1.8). Verilirse katalogla doğrulanır; geçersizse `400 ACADEMIC_INVALID`. Bekleyen kayıtla taşınır, `verify-email` ile hesaba yazılır.

### 1.1a Kota aşımında ertelenmiş doğrulama (kısıtlı mod)
Günlük doğrulama e-postası kotası (≈300/gün) dolduğunda `register` artık `503 MAIL_QUOTA_EXHAUSTED` ile geri çevirmez: kullanıcıyı **içeri alır ama e-postası doğrulanmamış ve yalnız okur** bırakır.
```http
POST /api/auth/register   {"email":"...","password":"...","acceptTerms":true,"language":"tr","client":"mobile"}
→ 201 Created
{"message":"Hesabınız oluşturuldu. ...","emailVerified":false,"verificationDeferred":true,
 "accessToken":"...","refreshToken":"...","expiresInSeconds":900,"tokenType":"Bearer"}
```
- Normal akış (kota doluyken değil) **aynen** `202 {"message":...}` + e-posta kodu. İstemci HTTP koduna değil **`verificationDeferred === true`** alanına bakar: doğruysa jetonları saklar, kod ekranını AÇMAZ, kullanıcıyı doğrudan uygulamaya alır. `client` (`mobile|web`) alanı isteğe bağlıdır (jeton etiketi; `verify-email` ile aynı).
- `GET /api/users/me` yanıtında her zaman `emailVerified` ve `verificationDeferred` (boolean) vardır. `emailVerified==false && verificationDeferred==true` ise **Profil sayfasında "E-postanızı doğrulayın"** kartı gösterilir.
- `login`/`refresh` ertelenmiş hesapta da çalışır (`200` + `emailVerified:false, verificationDeferred:true` ek alanları; normal girişte bu alanlar yoktur). Diğer doğrulanmamış hesaplarda `403 EMAIL_NOT_VERIFIED` aynen sürer.
- **Doğrulama (JWT'li):** `GET /api/auth/verification/status` → `{emailVerified, verificationDeferred, email}`; `POST /api/auth/verification/resend` → `202` (kod 6 hane/10 dk; `429 RESEND_COOLDOWN` 180 sn + `Retry-After`; kota hâlâ doluysa **`429 MAIL_QUOTA_EXCEEDED`** + `Retry-After` saniye: "Yarın tekrar deneyin" gösterin; `409 EMAIL_ALREADY_VERIFIED`); `POST /api/auth/verification/verify {"code":"482913"}` → `200 {"emailVerified":true,"verificationDeferred":false}` (`400 INVALID_CODE`, `429 TOO_MANY_ATTEMPTS`). Başarıdan sonra **yeni jeton gerekmez**; kısıtlar anında kalkar. Anonim `verify-email`/`resend-code` bu hesaplar için kullanılmaz.
- Kota boşalınca sunucu da (saatlik iş) ertelenmiş hesaba günde en çok 1 kez kod e-postası gönderir; kod 10 dk geçerlidir, süresi dolduysa kullanıcı `resend` ister.
- **Kısıtlı mod:** doğrulanana kadar tüm yazma uçları `403 EMAIL_VERIFICATION_REQUIRED` döner (gönderi/beğeni/takip, mesaj ve sohbet başlatma, kulüp/etkinlik oluşturma-katılma, başvuru, RSVP, anket oyu, medya yükleme). **İzinli yazmalar:** profil düzenleme (`PATCH /users/me`), avatar, doğrulama uçları, çıkış, cihaz/push kaydı, analitik, sözleşme onayı, hesap silme, destek talebi, şikâyet, bildirim tercihleri. Okuma uçları serbesttir. İstemci bu kodu alınca yazma düğmesi yerine "E-postanızı doğrulayın" göstermeli (profil kartına yönlendir).
- Doğrulanmamış (kısıtlı) hesaplar aramada/önerilerde/Keşfet'te başkalarına **görünmez**; 14 gün içinde doğrulanmazsa hesap silinir (anonimleştirme).

### 1.2 Kod gönderme/doğrulama
```http
POST /api/auth/resend-code    {"email":"ayse@bingol.edu.tr"}   → 202 (hesap var olsun olmasın aynı yanıt)
POST /api/auth/verify-email   {"email":"ayse@bingol.edu.tr","code":"482913","password":"Sifre1234","client":"mobile"}
```
**Parola kanıtı (`password`, zorunlu):** istemci kayıt adımında girdiği şifreyi doğrulama isteğinde yeniden gönderir; sunucu bekleyen kaydın şifre özetiyle karşılaştırır. Uyuşmazsa/eksikse genel `400 INVALID_CODE` ve yanlış deneme sayılır (kod tüketilmez). Amaç: aynı e-postaya başkasının yeniden kayıt göndermesiyle sahibin koduna kendi şifresini bağlamasını (hesap devralma) engellemek. Şifre bellekte yoksa (uygulama yeniden açıldı) istemci kullanıcıdan "kayıtta belirlediğiniz şifre"yi ister. Eski istemciler için sunucu bayrağı `app.auth.verify-requires-password=false` (varsayılan true; yalnız geçiş penceresi).
`verify-email` → `200`:
```json
{"accessToken":"eyJhbGciOiJIUzI1NiJ9...","refreshToken":"cn219myvLJlkbdbg-_aBxsQygQN2L8_spDoX26JW3XE","expiresInSeconds":900,"tokenType":"Bearer"}
```
- Kod 6 hane, **10 dk** geçerli, tek kullanımlık, **5 yanlış deneme** (sonra adres 10 dk kilitlenir: `429 TOO_MANY_ATTEMPTS`; `resend-code` veya yeni `register` kilidi açar). Yanlış/süresi dolmuş/bekleyen kayıt yok: aynı `400 INVALID_CODE` (ayırt edilmez). `verify-email` ek sınırı: e-posta başına 10 dk'da 10.
- Yeniden gönderme (`resend-code`, `forgot-password`, aynı adrese tekrar `register`) için **180 sn (3 dk) bekleme** vardır: erken istek `429 RESEND_COOLDOWN` + `Retry-After` (kalan saniye; mesajdaki `{0}` de kalan saniyedir), yeni kod üretilmez/gönderilmez. İlk gönderim beklemesizdir. Kod **tam 10 dakika** geçerlidir (kayıt, şifre sıfırlama ve herkese açık destek formu kodu); 5 yanlış deneme sınırı ve kilit aynen. `resend-code` bekleyen kaydı olmayan adreste kod göndermez ama aynı 180 sn beklemesini ve 429'u uygular (kayıt varlığı sızmaz). Herkese açık destek formunda aynı adrese 180 sn içinde ikinci talep `429 RATE_LIMITED` + `Retry-After` döner.
- Geliştirme ortamında (`MAIL_ENABLED=false`) kod e-posta yerine backend log'una yazılır; `scripts/make-user.sh` bunu otomatikleştirir.

### 1.3 Giriş
```http
POST /api/auth/login   {"email":"ayse@bingol.edu.tr","password":"Sifre1234x","client":"mobile"}   → 200 (TokenResponse)
```
- **`client`** (opsiyonel, `mobile` | `web`, varsayılan `web`; geçersiz değer `400`): mobil uygulama **her zaman `"client":"mobile"`** göndermelidir (`verify-email` gövdesinde de aynı alan vardır: açılan hesabın token'ları mobil etiketlenir). **Çoklu oturum (2026-11-06; eski "tek cihaz kuralı" kalktı)**: hiçbir giriş başka oturumu sonlandırmaz; aynı kullanıcı birden çok cihazdan (mobil/web) açık kalabilir ve push hepsine gider. Her giriş bir oturum kimliği (`sid`) alır (access JWT `sid` talebi). İstemci girişte/kayıtta `X-Device-Name` (örn. `Pixel 8`, `iPhone 15`) ve `X-Device-Id`/`X-Device-Platform`/`X-App-Version` başlıklarını göndermelidir. **Cihazlarım**: `GET /api/auth/sessions` açık oturumları döner (`[{id, client, platform, deviceName, appVersion, ipMasked, createdAt, lastUsedAt, current}]`, bu cihaz `current:true` ve başta); `DELETE /api/auth/sessions/{id}` o cihazdan çıkış yaptırır (204; o oturumun access token'ı anında `401 SESSION_REPLACED`, refresh `401 SESSION_REPLACED`, push kaydı silinir; olmayan/başkasının oturumu `404 SESSION_NOT_FOUND`); `POST /api/auth/logout-all` hepsini kapatır. Başka açık oturum varken bilinmeyen bir cihazdan giriş yapılırsa diğer cihazlara uygulama içi bildirim + push (`SYSTEM`, `targetType=SECURITY`, `targetId=devices`, `securityKind=NEW_DEVICE`) ve güvenlik e-postası gider; bildirime dokunulunca Cihazlarım açılmalıdır. (Eski davranış sunucuda `AUTH_SINGLE_MOBILE_SESSION=true` ile açılabilir.)
- Yeni giriş sonrası push için `POST /api/devices` ile FCM token'ı **yeniden kaydedin** (girişte eski kayıtlar silinir).
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

**`409 REFRESH_IN_PROGRESS` + `Retry-After: 1` (FIX-P02/K1):** aynı refresh token ile eşzamanlı ikinci istek geldiğinde (iki sekme, ön plan + arka plan) ve ilk istek yeni çifti henüz yazmadıysa sunucu önce ~300 ms bekler, hâlâ yoksa 401 yerine **409** döner. Bu bir hata değil "tekrar dene"dir: **oturumu kapatmayın**, `Retry-After` kadar (1 sn) sonra AYNI refresh token ile yeniden deneyin; ilk istek bitince aynı yeni çifti alırsınız. Yanıt kaybolduysa aynı eski token ile yeniden deneme **5 dakika** boyunca (eskiden 45 sn) aynı çifti verir. Çalıntı/yeniden kullanım şüphesinde (tolerans dışı eski token) artık yalnız **o oturum ailesi** (aynı girişin zinciri) kapanır; kullanıcının diğer cihazları açık kalır.

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
- `POST /api/auth/logout {"refreshToken","fcmToken"?}` → `204` (`fcmToken` isteğe bağlı ama **önerilir**: sunucu o cihazın push kaydını da siler, erişim jetonu bitmiş olsa bile) (refresh token iptal; access token süresi dolana kadar teknik olarak geçerli kalır, istemci siler). Çıkışta WebSocket'i kapatın, yerel mesaj önbelleğini ve bekleyen kuyruğu silin, `DELETE /api/devices/{fcmToken}` ile push kaydını kaldırın.
- `POST /api/auth/logout-all` (Bearer, gövdesiz) → `204`: **tüm cihazlardaki** refresh token'ları siler ve eski access token'ları da reddettirir (çağıran cihaz dahil; yeniden giriş gerekir). Kullanıcı başına 15 dk'da 5 (`429 RATE_LIMITED`). Ayarlarda "tüm cihazlardan çık" için kullanın; sonrasında yerel durumu `logout` ile aynı şekilde temizleyin.
- Hesap **askıya alınırsa** veya **silinirse** access token hemen 401 olur ve yenileme de başarısızdır. Yönetici **rolü değiştirirse** eski token 401 olur; `refresh` yeni rolde token verir (normal akış).
- **`SESSION_REPLACED` (401)**: başka bir cihazdan mobil giriş yapıldığında (veya `logout-all`/şifre sıfırlamayla oturumlar kapatıldığında) eski oturumun **her isteği** — access token'ın süresi dolmamış olsa bile — `401 {"code":"SESSION_REPLACED","message":"Hesabınıza başka bir cihazdan giriş yapıldı."}` (tr/en/ar, `Accept-Language`) alır. `POST /api/auth/refresh` de iptal edilmiş refresh token için aynı kodu döner (süresi dolmuş/bilinmeyen token: `INVALID_REFRESH_TOKEN`). İstemci: refresh **denemeden** yerel oturumu temizle, WebSocket'i kapat, giriş ekranını "başka cihazdan giriş yapıldı" mesajıyla aç. (İptal kaydı `rtx:<hash>` mezar taşıdır, 30 gün.)
- `GET /api/auth/me` → `{id,email,displayName}`; ayrıntılı profil `GET /api/users/me`.

### 1.7 Şifre sıfırlama (3 adım)
```http
POST /api/auth/forgot-password   {"email":"ayse@bingol.edu.tr"}                              → 202 (kayıtlı hesap: kod e-postayla, asenkron) | 404 ACCOUNT_NOT_FOUND (kayıtlı/doğrulanmış/aktif hesap yok; e-posta GİTMEZ) | 429 RESEND_COOLDOWN (180 sn içinde ikinci istek, Retry-After)
POST /api/auth/verify-reset-code {"email":"...","code":"482913"}                              → 200 {"resetToken":"..."}
POST /api/auth/reset-password    {"email":"...","resetToken":"...","newPassword":"Yeni1234x"} → 200 {"message":"..."}
```
- Kod 6 hane, 10 dk, tek kullanımlık; deneme/kilit kuralı kayıt koduyla aynıdır (`TOO_MANY_ATTEMPTS`, `INVALID_CODE`). `resetToken` tek kullanımlık, kısa ömürlü bir anahtardır: yalnızca bellekte tutun, saklamayın.
- `newPassword` en az 6, en çok 72 karakter (kısa ise `400 PASSWORD_TOO_SHORT`; yönetici hesapları 12+ ve güçlü, `PASSWORD_TOO_WEAK`). Başarılı sıfırlamada kullanıcının **tüm oturumları kapanır** (refresh token'lar silinir, eski access token'lar reddedilir): kullanıcıyı giriş ekranına yönlendirin.
- Sınırlar: `forgot-password` IP başına saatte 10 ve e-posta başına saatte 5; `verify-reset-code` ve `reset-password` IP başına 10 dk'da 20 (`429 RATE_LIMITED`).

### 1.7a Şifre değiştirme (oturum açıkken)
```http
POST /api/auth/change-password   (Bearer)
{"currentPassword":"Eski1234x","newPassword":"Yeni1234x"}
→ 200 {"accessToken":"...","refreshToken":"...","expiresInSeconds":900,"tokenType":"Bearer"}
```
- Yanıt `login` ile aynı biçimdedir ve **204 değildir**: başarıda kullanıcının tüm oturumları (diğer cihazlar dahil, çağıran cihazın eski token çifti de) kapanır; sunucu çağıran cihaza aynı istemci türünde (`cl`) **yeni token çifti** verir. İstemci eski access/refresh token'ı bu çiftle **hemen değiştirmelidir**; aksi halde sonraki istek `401 SESSION_REPLACED` alır. Eski token'la uçuşta olan istekler 401 alabilir: yeni çiftle bir kez yeniden deneyin.
- Çağıran cihazın açık WebSocket bağlantısı iptal olayıyla (`session-replaced`) kapanır: bu olayda çıkış yapmayın, yeni access token'la yeniden bağlanın (diğer cihazlar giriş ekranına döner).
- `newPassword` en az 6, en çok 72 karakter (kayıt/sıfırlama ile aynı; kısa ise `400 PASSWORD_TOO_SHORT`). Hatalar: `403 WRONG_PASSWORD` (mevcut şifre yanlış), `422 PASSWORD_UNCHANGED` (yeni şifre mevcutla aynı), `429 RATE_LIMITED` (kullanıcı başına saatte 5, IP başına saatte 10). Başarıda kullanıcıya (kayıtlı dilinde) "şifreniz değiştirildi" güvenlik e-postası gider.

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

### 1.9 Cihaz kimliği başlıkları ve `ACCESS_BLOCKED`
Yönetici bir cihazı, IP'yi ya da hesabı engelleyebilir. Engelin cihaz ayağının çalışması için istemci **her HTTP isteğine** (anonim dahil: kayıt, giriş, doğrulama, yenileme) şu başlıkları ekler:

| Başlık | Değer | Not |
|---|---|---|
| `X-Device-Id` | kararlı cihaz kimliği, 8-128 karakter `[A-Za-z0-9._:-]` | Mobil uygulama ilk açılışta rastgele bir UUID üretir ve Keychain/Keystore'da saklar (donanım kimliği okunmaz); her istekte ve STOMP CONNECT'te gönderir. Ham değer sunucuda HMAC-SHA256 ile özetlenir, saklanmaz. Geçersiz/eksik başlık yok sayılır (cihaz engeli uygulanamaz) |
| `X-Device-Platform` | `ANDROID` \| `IOS` \| `WEB` | isteğe bağlı |
| `X-App-Version` | ör. `1.4.2` | isteğe bağlı, en çok 32 karakter |

WebSocket: el sıkışma isteğine aynı başlıklar eklenebilir; STOMP `CONNECT` çerçevesine `device-id`, `device-platform`, `app-version` başlıkları konur (engelli cihaz `ERROR` çerçevesi `ACCESS_BLOCKED` alır).

**`403 ACCESS_BLOCKED`** (`{"code":"ACCESS_BLOCKED","message":"…"}`): bu cihaza/ağa/hesaba erişim kapatılmıştır; sebep verilmez. Her uçta gelebilir (anonim uçlar dahil). İstemci: yenilemeyi **denemez**, oturumu yerelde siler (token + önbellek), tam ekran "erişim kapatıldı" ekranı gösterir (yazı `message`ten), WebSocket'i yeniden bağlamaz. Açık WebSocket'teyken sunucu `/user/queue/message-events` ile `{type:"access-blocked"}` gönderir ve bağlantıyı `ACCESS_BLOCKED` kapanış gerekçesiyle kapatır (`session-replaced` ile karıştırmayın; ondaki gibi yeniden giriş önerilmez). Başlıkları eklemeyen eski istemcilerde yalnızca IP ve hesap engeli çalışır.

### 1.10 Google / Apple ile giriş ve profil tamamlama (onboarding)

> **Özellik bayrağı:** sunucuda `AUTH_OAUTH_ENABLED` (varsayılan **kapalı**). Kapalıyken tüm `/api/auth/oauth/**` uçları `404 {"code":"OAUTH_DISABLED"}` döner: istemci bu kodu alırsa Google/Apple düğmelerini gizler (ya da "şu an kullanılamıyor" gösterir). Sunucu yapılandırması [OAUTH_SETUP.md](OAUTH_SETUP.md); ayrıntılı kurallar `docs/changes/auth.md`.

**Okul e-postası zorunluluğu yoktur**; e-posta + şifre kaydı/girişi aynen sürer. Google/Apple ile giriş **kayıt ve giriş için aynı uçtur** (sunucu sağlayıcı kimliğinden yeni/mevcut kararını verir).

**Akış**
1. İstemci sağlayıcıdan token alır: Google **ID token** (`google_sign_in`, `serverClientId` = Web istemci kimliği), Apple **identityToken** + kendi ürettiği **ham `nonce`** (Apple'a `sha256(ham)` **hex** olarak verilir; sunucuya `nonce` alanında HAM değer gider).
2. `POST /api/auth/oauth/google` `{"idToken","deviceName?","client?"}` ya da `POST /api/auth/oauth/apple` `{"identityToken","nonce","firstName?","lastName?","deviceName?","client?"}`. Apple adı yalnız **ilk** yetkilendirmede gelir: istemci o anda `firstName/lastName` gönderirse sunucu yeni hesapta saklar (sonraki girişlerde göndermeyin/boş gönderin). `client` verilmezse `mobile` sayılır (tek cihaz kuralı: başka cihazdaki mobil oturum düşer).
3. **200** `{accessToken, refreshToken, expiresInSeconds, tokenType, profileCompleted, isNewUser}` (jeton alanları normal girişle aynı; saklama/yenileme 1.4-1.5). Hesabın **2FA'sı açıksa 202** + normal 2FA challenge (`POST /api/auth/login/2fa` ile tamamlanır; o yanıtta `profileCompleted` yoktur, `GET /api/users/me` okuyun).
4. `profileCompleted=true` -> ana sayfa. `false` -> **profil tamamlama ekranı**; sunucu bunu zorlar: `profileCompleted=false` iken GET'ler (okuma) çalışır ama tüm **yazma/etkileşim uçları `403 PROFILE_INCOMPLETE`** döner (STOMP `SEND` dahil). İstemci bu kodu da onboarding ekranına yönlendirme işareti olarak ele almalıdır.
5. Onboarding ekranı: `GET /api/catalog/academic` (fakülte/bölüm/sınıf listesi, 1.8) + `GET /api/users/username-available?u=` (musaitlik, dakikada 30; yalnız oturumlu) + isteğe bağlı fotoğraf `POST /api/users/me/avatar` (onboarding sırasında serbest) -> `PUT /api/users/me/onboarding`.
6. Çıkış/hesap silme/cihaz kaydı (`/api/devices`) onboarding bitmeden de çalışır.

**`PUT /api/users/me/onboarding`**
```json
{"firstName":"Ayşe","lastName":"Yılmaz","username":"ayse.yilmaz","universityName":null,
 "facultyId":"muhendislik","departmentId":"bilgisayar-muhendisligi","classYear":"Y2",
 "bio":"isteğe bağlı kısa metin","acceptTerms":true}
```
- `universityName` boş = Bingöl Üniversitesi (fakülte/bölüm katalogla doğrulanır, geçersiz = `422 ACADEMIC_INVALID`); başka üniversitede fakülte/bölüm serbest metin (`facultyName`/`departmentName`). Fakülte: `facultyId` **ya da** `facultyName`; bölüm: `departmentId` **ya da** `departmentName`. `classYear`: `PREP | Y1..Y6 | POSTGRAD | MASTER | PHD | OTHER`; `OTHER` dışında fakülte+bölüm zorunlu (`422 PROFILE_FIELD_REQUIRED {field}`).
- `username`: 3-24 karakter, `[a-z0-9._]`, harfle başlar, ardışık nokta/alt çizgi yok, büyük/küçük harf duyarsız (küçük harfe çevrilip saklanır). Hatalar: `422 USERNAME_INVALID`, `422 USERNAME_RESERVED`, `422 CONTENT_PROFANITY {field:"username"}`, **`409 USERNAME_TAKEN {field:"username"}`** (eşzamanlı çift alım dahil; kullanıcıya başka ad seçtirin, profil tamamlanmamış kalır).
- **`acceptTerms:true` gönderin** (kayıt sözleşmelerinin kabulü; onay kaydı sunucuda yazılır). Göndermezseniz ve `GET /api/legal/acceptance-status` bekleyen onay gösteriyorsa `400 TERMS_REQUIRED`. Onay ekranı olarak mevcut sözleşme akışını (`/api/legal`) kullanın.
- Yanıt `200 {"profileCompleted":true,"user":{ProfileView}}`. **Idempotent:** tamamlanmış hesapta tekrar çağrı mevcut veriyi ezmez, aynı sonucu döner (ağ kopmasında güvenle yeniden deneyin). Alanlar **kullanıcı beyanıdır**: arayüzde "doğrulanmış öğrenci" gibi gösterilmez.
- Tamamlandıktan sonra düzenleme: `PATCH /api/users/me` (ad, fakülte, bölüm, sınıf, biyografi), kullanıcı adı `PUT /api/users/me/username` `{"username"}` (30 günde bir değişim; **eski kullanıcılara kullanıcı adı boştur**, isteğe bağlı atanabilir).

**`GET /api/users/me`** yanıtına eklendi: `profileCompleted` (bool; eski kullanıcılar `true`), `username` (varsa), `firstName`, `lastName`, `universityName`, `authProviders` (`["GOOGLE","APPLE"]`; yalnız bu uçta). **Soğuk açılışta** `profileCompleted=false` ise doğrudan onboarding ekranı açın.

**Hata kodları (giriş)**
| Kod | HTTP | İstemci davranışı |
|---|---|---|
| `OAUTH_DISABLED` | 404 | sağlayıcı düğmelerini gizle |
| `OAUTH_TOKEN_INVALID` | 400 | imza/aud/iss/süre/nonce hatası: "Giriş doğrulanamadı", yeniden dene |
| `OAUTH_EMAIL_UNVERIFIED` | 403 | Google hesabının e-postası doğrulanmamış |
| `OAUTH_EMAIL_MISSING` | 400 | Apple e-posta vermedi ve hesap yok: kullanıcıya "e-posta paylaşımına izin verin/başka yöntem" |
| **`OAUTH_LINK_REQUIRED`** | 409 | gövde `{code,message,provider,emailMasked}`: **otomatik birleştirme yok**. "`emailMasked` ile kayıtlı hesap var; önce e-posta ve şifrenizle girin, sonra bağlayın" ekranı. |
| `ACCOUNT_SUSPENDED`, `ACCESS_BLOCKED`, `429` | | normal giriş gibi |

**Hesap bağlama (güvenlik ekranı)**: `GET /api/auth/oauth/identities` -> `[{provider,email,emailPrivate,linkedAt}]`; `POST /api/auth/oauth/link` `{"provider":"GOOGLE"|"APPLE","token","nonce?","password"}` (oturum açık; **mevcut şifre yeniden doğrulanır**; parolasız hesapta `password` yerine bağlı sağlayıcının taze token'ı: `reauthProvider/reauthToken/reauthNonce`) -> `200 {"linked":true}`, hatalar `403 WRONG_PASSWORD`, `403 OAUTH_REAUTH_REQUIRED`, `409 OAUTH_IDENTITY_TAKEN` (bu hesap başka kullanıcıya bağlı), `409 OAUTH_PROVIDER_ALREADY_LINKED`; `DELETE /api/auth/oauth/link/{google|apple}` -> `200 {"linked":false}`, `409 OAUTH_LAST_LOGIN_METHOD` (parolası olmayan hesapta tek giriş yöntemi; önce `forgot-password` ile şifre belirletin).

**Parolasız hesap**: OAuth ile açılan hesabın parolası yoktur; e-posta+şifre girişi `401 INVALID_CREDENTIALS` döner. Sonradan parola için mevcut şifre sıfırlama (1.7) kullanılır.

**Hesap silme (`DELETE /api/users/me`)**: parolalı hesap `{"password"}` (eskisi gibi); **parolasız hesap** `{"provider":"GOOGLE"|"APPLE","token","nonce?"}` ile bağlı sağlayıcıdan alınmış TAZE token gönderir (yeniden doğrulama). Not: Apple token iptali (revoke) bu sürümde yoktur (yapılandırma bekliyor); Apple tarafındaki erişim Ayarlar > Apple Kimliği'nden kaldırılabilir.

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
| `/user/queue/read-receipts` | `{conversationId,userId,lastMessageId}`: `userId` konuşmada `lastMessageId`'ye kadar okudu (eski akış, geriye uyum için sürer; yeni istemci `receipt` olayını kullanır, bkz. 4.10) |
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
| `/app/chat.send` | `{"conversationId":1,"text":"merhaba","clientId":"<UUIDv4>","replyToMessageId":40,"attachmentIds":[9]}` | metin ≤ 2000 karakter; `replyToMessageId` ve `attachmentIds` (en çok 10) isteğe bağlıdır; ek varsa metin boş olabilir |
| `/app/chat.delivered` | `{"conversationId":1,"lastMessageId":42}` | iletildi ack'i (bkz. 4.10); imleç yalnız ilerler, kendi mesajların yok sayılır; dakikada 120'den fazlası sessizce atılır |
| `/app/chat.read` | `{"conversationId":1,"lastMessageId":42}` | imleç yalnız ilerler; son mesajı aşan değer `INVALID_MESSAGE_ID`; boş konuşmada no-op; konuşma başına 10 sn'de 20'den sık istek **sessizce** atılır, bu yüzden yalnızca görünen son mesajı gönderin |
| `/app/chat.typing` | `{"conversationId":1}` | 2 sn'de 1, fazlası sessizce atılır |

```text
>>> SEND
destination:/app/chat.send
content-type:application/json

{"conversationId":1,"text":"merhaba","clientId":"7b0c1f3e-4a52-4d2a-9d6e-0f1c2b3a4d5e"}^@
<<< MESSAGE            (destination:/user/queue/messages; ack olarak kendi mesajınız, sunucu id'siyle)
{"id":43,"conversationId":1,"senderId":7,"clientId":"7b0c1f3e-...","text":"merhaba","removed":false,"createdAt":"..."}
<<< MESSAGE            (destination:/user/queue/errors; ör. mesaj çok uzun)
{"code":"MESSAGE_TOO_LONG","message":"Mesaj en fazla 2000 karakter olabilir.","clientId":"7b0c1f3e-..."}
```
**WS hata `message` metni çevrilmez** (Türkçe varsayılandır): kullanıcıya göstereceğiniz metni **`code`'dan kendi çevirilerinizle** üretin (bölüm 10'daki tr/en/ar tablodan alabilirsiniz). Sık kodlar: `EMPTY_MESSAGE`, `MESSAGE_TOO_LONG`, `CONVERSATION_NOT_FOUND`, `BLOCKED`, `RATE_LIMITED` (kullanıcı başına dakikada 30 mesaj), `BAD_REQUEST` (bozuk yük).

### 4.3 `clientId` ile idempotency ve çevrimdışı kuyruk
- Her gönderilen mesaj için **istemci bir UUIDv4 `clientId`** üretir (≤ 64 karakter). Sunucu `(konuşma, gönderen, clientId)` tekrarını yeni mesaj saymaz: aynı `clientId` ile yeniden gönderim **çift mesaj üretmez** (REST'te `200` + mevcut mesaj, yenide `201`).
- Önerilen akış: mesajı yerelde `PENDING` + `clientId` ile yaz (iyimser göster) → bağlıysa `chat.send`; `/user/queue/messages`'te aynı `clientId` gelince `SENT` + sunucu `id`; **10 sn içinde ack gelmezse** REST yedeği `POST /api/conversations/{id}/messages {"text","clientId"}` ile aynı `clientId`'yi yeniden gönderin (idempotent).
- `errors` kuyruğunda `clientId` taşıyan kalıcı hatalar (`MESSAGE_TOO_LONG`, `CONVERSATION_NOT_FOUND`; engel iliskisi artık hata DEĞİLDİR, bkz. gölge engel) → mesaj `FAILED`; `RATE_LIMITED` → geri çekilmeyle tekrar dene.
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
| `SESSION_REPLACED` | oturum başka cihaz girişiyle/iptalle kapandı | refresh deneme; oturumu temizle, giriş ekranı |
| `SUSPENDED` | hesap askıda | oturumu kapat, askı mesajı göster |
| `FORBIDDEN_DESTINATION` | izin verilmeyen hedefe SEND/SUBSCRIBE | istemci hatası; düzeltin |

- Refresh de 401 verirse oturum bitmiştir: giriş ekranı.
- **Oturum sonlandırma olayı**: başka cihazda mobil giriş (veya `logout-all`/şifre sıfırlama) olduğunda sunucu, etkilenen WS bağlantısına **kapanmadan önce** `/user/queue/message-events` kuyruğuna `{"type":"session-replaced","at":"2026-01-01T10:00:00Z"}` gönderir, ~0,4 sn sonra bağlantıyı kapatır (close 1008, neden `SESSION_REPLACED`). İstemci olayı gördüğünde (ya da bu close nedeniyle) yeniden bağlanmayı **denemeden** oturumu temizleyip giriş ekranına dönmelidir. CONNECT'te iptal edilmiş token'a `ERROR message=SESSION_REPLACED` döner. Web bağlantıları mobil girişten etkilenmez.

### 4.6 Diğer mesajlaşma uçları (REST)
`GET/POST /api/conversations` (birebir `{userId}`: varsa `200` mevcut, yoksa `201`; grup `{title,memberIds}` → `201`; günde en çok 30), `GET/PATCH /api/conversations/{id}`, `POST .../leave`, `POST .../members`, `DELETE .../members/{userId}`, `POST .../read {lastMessageId}` (204; hiç mesajı olmayan konuşmada da 204 no-op), `POST /api/messages/{id}/report {reason,note}`, `GET /api/users/{id}/presence` (`{online,lastSeenAt}`; yalnız ortak konuşması olan, engel ilişkisi olmayan kullanıcılar; aksi `404`), engelleme: `POST/DELETE /api/users/{id}/block`, `GET /api/users/me/blocks`. Ayrıntı: `openapi.json`, tasarım: [MESSAGING_DESIGN.md](MESSAGING_DESIGN.md).

**Kulüp ve etkinlik sohbetleri (sohbet sekmesi).** `ConversationView.type` `DIRECT`, `GROUP`, `CLUB` veya `EVENT` olabilir; ayrıca `communityId` (yalnız `CLUB`) ve `eventId` (yalnız `EVENT`) alanları gelir, diğerlerinde `null`. Sohbeti açmak için:
- `GET /api/communities/{id}/chat`: kulüp sohbetini getir-ya-da-oluştur ve çağıranı ekler; `ConversationView` döner. Yalnız kulübün aktif üyesi (yetkisize/onaysız kulüpte `404 CHAT_ROOM_NOT_FOUND`, kapalı odada `409 CHAT_ROOM_CLOSED`).
- `GET /api/events/{id}/chat`: etkinlik sohbeti; RSVP'si `GOING`/`INTERESTED` olan ya da etkinliği yönetebilen girer (yetkisize `403 FORBIDDEN`, görünmeyen/iptal edilmiş etkinlikte `404 EVENT_NOT_FOUND`).
Mesaj gönderme/okuma/WebSocket mevcut `/api/conversations/{id}/**` ve `/app/chat.*` ile aynıdır. Bu sohbetlere elle üye eklenmez, `leave` çalışmaz (`400 NOT_A_GROUP`); kulüpten ayrılan ya da RSVP'sini kaldıran kullanıcı sohbetten düşer (mesaj gönderme `404`). Kulüp/etkinlik adı sohbet başlığıdır. Durum/katılma için ayrıca `GET /api/communities/{id}/chat-room`, `POST /api/communities/{id}/chat-room/join` (takma ad `/chat/join`) ve `GET /api/events/{id}/chat-room`, `POST /api/events/{id}/chat-room/join` vardır. Etkinlik odası bitişten 7 gün sonra kapanır; kulüpten yasaklanan/ayrılan kullanıcı odadan düşürülür (en geç birkaç dakikada).

### 4.7 Konuşma tercihleri, okunmamış sayacı, mesaj eylemleri
`ConversationView`: `{id,type,title,peer,memberCount,admin,lastMessage,unreadCount,blocked,createdAt,muted,mutedUntil,mutedForever,archived,communityId,eventId}`.
- **Sessize al:** `PUT /api/conversations/{id}/mute` gövde `{"durationMinutes":1..525600}` **veya** `{"forever":true}` (ikisi birden `400`); `DELETE` ile kaldırılır; yanıt `ConversationView`. Süresiz sessizde `mutedUntil` ~100 yıl sonradır: "süresiz" göstermek için **`mutedForever`**'a bakın.
- **Arşiv:** `PUT /api/conversations/{id}/archive`, `DELETE` ile çıkarılır; liste `GET /api/conversations?archived=true`. Arşivli sohbet yeni mesajla arşivden ÇIKMAZ ve push/uygulama içi bildirim üretmez (`keepArchived` gönderilebilir ama etkisizdir; her arşiv kalıcıdır); okunmamış sayacı artar. Arşiv çubuğu için `GET /api/conversations/unread-count` -> `archivedChats` (arşivdeki sohbet sayısı) ve `archivedUnreadChats` (okunmamışı olan arşivli sohbet sayısı; sohbet başına 1); arşivli sohbetler `total`/`mutedTotal`a girmez, `conversations[].archived` işaretlidir.
- **Rozet:** `GET /api/conversations/unread-count` → `{"total":3,"mutedTotal":5,"conversations":[{"conversationId":10,"unread":3,"muted":false}]}`; satırlardaki `unreadCount` ile aynı tanım (kendi/silinmiş/engelli gönderici mesajları sayılmaz). `total` sessiz olmayanlar, `mutedTotal` sessizdekiler. **FIX-P03:** sunucu konuşma başına en çok 100'e kadar sayar (100 = "99+"). Okundu/iletildi tikleri ve "yazıyor" varsayılan olarak her konuşmada çalışır (oda ve büyük gruplar dahil); sunucu ayarı `app.chat.receipts-max-members` / `app.chat.receipts-rooms` ile kapatılırsa `MessageView.status` `null` gelir ve `receipt`/`typing` olayları yayınlanmaz (istemci `null` için tik göstermemeli); bir mesaj en çok 10 kez düzenlenebilir (`409 MESSAGE_EDIT_LIMIT`); oda başına dakikada 600 mesaj sınırı (`429`).
- **Mesaj eylemleri:** gönderim `POST /api/conversations/{id}/messages {"text","clientId","replyToMessageId?","attachmentIds?"}`; düzenleme `PATCH /api/messages/{id} {"text"}` (yalnız gönderen; **süre sınırı yok**); herkes için silme `DELETE /api/messages/{id}` (kulüp yöneticisi/moderatörü ve etkinlik organizatörü başkasınınkini de silebilir, diğerleri `403 MESSAGE_DELETE_FORBIDDEN`); tepki `PUT/DELETE /api/messages/{id}/reaction {"emoji"}`, izinli liste `GET /api/messages/reactions`.
- Ek sınırlar: `GET /api/conversations/{id}` dakikada 120; `PATCH`, üye ekle/çıkar ve `leave` kullanıcı başına ortak dakikada 30.

### 4.8 Sohbet görselleri (medya yükleme)
1. `POST /api/conversations/{cid}/media` (multipart, alan **`file`**) → `201` `AttachmentView` `{id,kind,width,height,bytes,contentType,removed,url,thumbUrl}`. Sunucu görseli yeniden kodlar (EXIF temizliği, en çok ~1600 px, sıkıştırılmış); yükleme üst sınırı 5 MB, dakikada 10 ve günde 200 yükleme, mesaja eklenmemiş en çok 20 görsel.
2. Dönen `id` mesaj gönderiminde `attachmentIds`'e konur (mesaj başına en çok **10** ek, foto/video karışık; REST veya `chat.send`; ayar `app.chat.media.max-attachments-per-message`). Hata kodları: `ATTACHMENT_LIMIT`, `ATTACHMENT_INVALID`, `ATTACHMENT_NOT_FOUND`, `MEDIA_BLOCKED` (422), `CHAT_MEDIA_PENDING_LIMIT` (429). Mesaja eklenmemiş kendi yüklemeniz `DELETE .../media/{aid}` ile silinir (mesaja bağlıysa `409 ATTACHMENT_IN_USE`). Sahiplenilmemiş yüklemeler 24 saatte temizlenir.
3. **Okuma kimliklidir:** `url` ve `thumbUrl` (`/api/conversations/{cid}/media/{aid}` ve `/thumb`) Bearer ister; görseli çizerken `Authorization` başlığı verin. Başlık veremeyen bileşenler için `GET .../media/{aid}/link` → `{url,thumbUrl,expiresAt}` kısa ömürlü (varsayılan 5 dk) imzalı adres verir. Gizlenen (`removed=true`) ekte adresler `null`dır.
4. **Video mesaj:** aynı uç `file=video/mp4` (+ isteğe bağlı `poster`= JPEG/PNG önizleme karesi) ile video yükler. Sınırlar: `ftyp` imzalı MP4, ≤ 40 MB (`413 VIDEO_TOO_LARGE`), ≤ 60 sn (`400 VIDEO_TOO_LONG`), bozuk/MP4 değil (`400 VIDEO_INVALID`); kullanıcı başına günde 30 video + ortak yükleme limitleri. Sunucu videoyu **yeniden kodlamaz** (istemci sıkıştırır); poster görsel hattından geçer (EXIF temizliği, ≤ 720 px) ve `thumbUrl` olur (poster yoksa `null`). `AttachmentView`: `kind` (`IMAGE`|`VIDEO`), `durationMs` (video), `sizeBytes`, `width`/`height` (poster ya da MP4 başlığı; bilinmiyorsa videoda `null`). Mesaj başına en çok 10 ek; video + görsel karışık serbest, video sayısı ayrıca sınırlı değil ama bir mesajdaki **videoların bayt toplamı ≤ 120 MB** (`413 MESSAGE_MEDIA_TOO_LARGE`; her video yine ≤ 40 MB / ≤ 60 sn); 10'dan fazla ek `400 ATTACHMENT_LIMIT`. Yükleme dakikada 20, mesaja eklenmemiş en çok 30 ek. Videoda `viewOnce` yok (`400 VIEW_ONCE_INVALID`). Oynatma: `GET .../media/{aid}` Bearer ile **HTTP Range** destekler (`Accept-Ranges: bytes`, `206 Partial Content`, `Content-Range`, `416` geçersiz aralıkta; `Content-Type: video/mp4`); oynatıcıya `Authorization` başlığı verin. `GET .../media/{aid}/thumb` posteri verir (yoksa `404`). `GET .../link` videoda `url=null` döner (yalnız poster için imzalı `thumbUrl`). Rapor, silme (mesaj silinince dosya da silinir) ve KVKK dışa aktarım (yalnız meta) görselle aynıdır.
5. Görseli/videoyu raporlamak için `POST .../media/{aid}/report {reason,note}` (günlük rapor limiti ortak).

**Tek gösterimlik görsel (view-once).** Yükleme aynı; gönderimde `POST /api/conversations/{id}/messages` ve `chat.send` gövdesine `"viewOnce": true` eklenir (yalnız `attachmentIds` doluyken, **tam 1 ek**; aksi `400 VIEW_ONCE_INVALID`; metin boş olabilir, doluysa normal kalır). `attachments[i]` alanlarına `viewOnce` ve `viewed` eklenir. Alıcıda `viewed` = ben açtım mı; göndericide (birebirde) karşı taraf, (grupta) en az bir alıcı açtı mı. Tek gösterimlikte `thumbUrl` **hiç** gelmez; `url` yalnız alıcıya ve henüz açmamışsa doludur (gönderende `null`). Açmak: `GET .../media/{aid}` (`Cache-Control: no-store, private`, `Content-Disposition: inline`) ilk başarılı istekte baytları verir ve açılış kaydedilir; sonrası `410 MEDIA_VIEW_ONCE_EXPIRED`; gönderici `403 MEDIA_VIEW_ONCE_OWN`; `/thumb` ve `/link` tek gösterimlikte `404`. Açılınca gönderene `/user/queue/message-events` ile `{type:"viewed",conversationId,messageId,attachmentId,userId,at}` düşer. Alıcı erişimi ilk açılıştan sonra (ya da 24 saat sonra) kapanır; ancak dosya içeriği artık açılışta SİLİNMEZ: yönetici denetimi için şifreli özel depoda `app.chat.media.view-once-retention-days` (varsayılan 365) boyunca tutulur, sonra silinir (`viewed` bilgisi kalır). İstemci davranışı değişmedi (ikinci açış `410`, gönderen `403`, `/thumb` ve `/link` `404`).

### 4.9 Grup adı ve fotoğrafı
Yalnız kullanıcı gruplarında (`type=GROUP`; `CLUB`/`EVENT` odaları ve birebir hariç, `400 NOT_A_GROUP`) ve yalnız grup yöneticisi (`403 NOT_GROUP_ADMIN`): ad `PATCH /api/conversations/{id} {"title"}`; fotoğraf `PUT /api/conversations/{id}/avatar` (multipart **`file`**, avatar hattı: tür/boyut doğrulama, yeniden kodlama, EXIF temizliği; yanıt `200` `ConversationView`), kaldırma `DELETE /api/conversations/{id}/avatar` (`204`). `ConversationView.avatarUrl` herkese açık `/files/avatars/...` yoludur (yoksa `null`). Değişince tüm üyelere `/user/queue/message-events` ile `{type:"conversation-updated",conversationId,userId,title,avatarUrl,at}` gider. Fotoğraf yönetimi dakikada 10 ile sınırlıdır.

**Sohbeti sil.** `DELETE /api/conversations/{id}` (`204`, idempotent, yönetim limiti ortak 30/dk; üye değilse `404`). Birebir: yalnız çağıran için silinir; konuşma listeden kalkar, eski mesajlar (liste/medya/okunmamış sayacı/son mesaj önizlemesi) bir daha görünmez, karşı tarafta hiçbir şey değişmez. Yeni mesaj gelince (karşı taraf ya da kendisi) konuşma yalnız yeni mesajlarla listede yeniden belirir. Kullanıcı grubu: gruptan ayrılma (`leave` kuralları, son yönetici devri) + listeden gizleme. Kulüp/etkinlik odası: `400 CONVERSATION_NOT_DELETABLE`. Silince sessize alma/arşiv sıfırlanır.

### 4.10 İletildi / okundu makbuzları (tik mantığı)
- **Ack:** mesaj istemciye ulaşınca (WebSocket ya da push ile gelen, uygulama açılınca çekilen mesajlar dahil) `STOMP /app/chat.delivered {conversationId,lastMessageId}` ya da `POST /api/conversations/{id}/delivered {lastMessageId}` (`204`; dakikada 120, aşılırsa REST `429`, WS sessiz). İmleç yalnız ilerler; yalnız üye (`404 CONVERSATION_NOT_FOUND`); kendi mesajların ve konuşmanın son mesajını aşan değer sessizce sınırlanır/yok sayılır. Sunucu, alıcının WebSocket'i açık olsa bile kendiliğinden "iletildi" saymaz; ack istemciden gelir. `read` (okundu) iletildiyi de ilerletir.
- **`MessageView.status`** yalnız **kendi mesajlarında** dolu (başkasınınkinde `null`; silinen/gizlenen mesajda `null`): `SENT` (sunucu aldı, kimse iletilmedi) → `DELIVERED` → `READ`. Birebirde karşı taraf, grupta **tüm** diğer aktif üyeler (ayrılan, engel ilişkisi olan, askıdaki ve mesajdan sonra katılan üyeler hesaba girmez) eşiği geçince ilerler. `ConversationView.lastMessage.status` de aynıdır.
- **Mesaj bilgisi (yalnız birebir, yalnız KENDİ mesajın):** `GET /api/messages/{id}/info?before=<nextCursor>&size=20` (dakikada 60) → `{"message":MessageView,"sentAt":"ISO-UTC","deliveredAt":"ISO-UTC"|null,"readAt":"ISO-UTC"|null,"status":"SENT"|"DELIVERED"|"READ","replies":{"items":[MessageView],"nextCursor":Long|null}}`. `deliveredAt`/`readAt` alıcının iletildi/okundu ack'inin GERÇEK anıdır (ilk kez yazılır, sonraki olaylar üzerine yazmaz). `null` = kayıt yok: yeni mesajda henüz iletilmemiş/okunmamış, ya da bu özellikten ÖNCE ack'lenmiş eski mesaj (zaman bilinmez, sunucu uydurmaz; `status` yine doğru gelir) — istemci "kayıt bulunmuyor" yazar, bu bir hata DEĞİLDİR (`200`). Engel/gölge engel/askıdaki alıcıda `status` `SENT` kalır ve zamanlar `null` döner. Gönderen olmayan, grup/oda, herkes için silinmiş, "sohbeti sil" ile temizlenmiş mesaj ve üye olmayan: `404 MESSAGE_NOT_FOUND`.
- **Gerçek zamanlı:** mesaj sahibine `/user/queue/message-events`: `{type:"receipt",conversationId,kind:"delivered"|"read",upToMessageId,userId,at,status}`. Birebirde `upToMessageId` karşı tarafın yeni imlecidir; kendi mesajlarından `id <= upToMessageId` olanları `status`e (`DELIVERED`/`READ`) yükseltin. Grupta toplulaştırma sunucudadır: olay yalnız durum ilerlediğinde ve sahibine düşer; `upToMessageId` o sahibin durumu `status`e ulaşan en yüksek mesajıdır. Engel ilişkisi olan tarafa makbuz gitmez. Olaylar kalıcı değildir; yeniden bağlanınca `GET .../messages?after=` ile gelen `status` değerleri esastır.

### 4.11 Gölge engel (engelleme)
- **Mesaj:** iki kullanıcıdan biri diğerini engellediyse (iki yön) birebir sohbette gönderim **hata vermez**: `201`, mesaj gönderenin görünümünde normal görünür ve `status` hep `SENT` (tek tik) kalır; karşı tarafa **hiçbir şey ulaşmaz** (geçmiş, son mesaj önizlemesi/liste sırası, okunmamış sayacı, WS, push, bildirim, makbuz, medya, view-once, yanıt/tepki hedefi). Bastırma mesaja kalıcı yazılır; engel sonradan kalksa da o mesajlar karşı tarafta gizli kalır. `BLOCKED` hatası artık gönderim/düzenleme/silme/tepki/medya yükleme/sohbet açma uçlarında dönmez. `ConversationView.blocked` geriye uyum için yanıtta kalır ama banner/composer kilidi için **kullanılmamalıdır**. Gruplarda mevcut davranış sürer (engelleyen, engellediğinin mesajlarını `removed` yer tutucuyla görür; diğer üyeler normal görür).
- **Profil/avatar:** engel ilişkisi olan iki kullanıcı birbirinin fotoğrafını ve bilgisini görmez. `GET /api/users/{id}` engelliyken **404 değil**, boş profil döner: `{id, displayName, faculty/department/classYear/bio/avatarUrl/email: null}`. `avatarUrl` sohbet listesi (`peer`), grup üyeleri, kulüp üyeleri/başvuruları/gönderi yazarları, etkinlik katılımcı/başvuru listeleri, ko-organizatörler ve engellenenler listesinde `null` olur.
- Yükleme kotaları engelde de sayılır.

## 5. Rate limit (429) davranışı
- Sınırlar Redis'te **sabit pencere** sayacıdır; aşılınca `429` ve `{"code":"RATE_LIMITED","message":"Çok fazla deneme. Lütfen daha sonra tekrar deneyin."}`. (Doğrulama kodu uçlarında özel kodlar: `RESEND_COOLDOWN`, `TOO_MANY_ATTEMPTS`.)
- 429 yanıtında **`Retry-After: <saniye>`** başlığı gelir (sayacın kalan ömrü; `X-RateLimit-*` yoktur). Otomatik tekrar için bu süreyi bekleyin (başlık yoksa üstel geri çekilme, en az 5 sn, en çok 5 dk); kullanıcıya "biraz sonra tekrar deneyin" gösterin, aynı istekleri döngüde tekrarlamayın. Okundu bilgisi gibi bazı uçlar aşırı isteği hata vermeden sessizce atar (204).
- Okuma (GET) uçlarının çoğunda sınır yoktur; yazma uçlarının hepsinde vardır. Anahtar genelde kullanıcı kimliğidir (kimliksiz uçlarda IP).

| Uç | Sınır |
|---|---|
| `POST /api/auth/register`, `resend-code` | IP başına saatte 10 |
| `POST /api/auth/verify-email` | IP başına 10 dk'da 20 |
| `POST /api/auth/login` | Başarısız deneme: (e-posta, cihaz) çifti başına 15 dk'da 10, e-posta başına 60; cihaz başına 30; IP başına yalnız yüksek toplu tavan (5000). `X-Device-Id` göndermek NAT'ta (kampüs) kilitlenmeyi önler |
| `POST /api/auth/refresh` | Kullanıcı (token sahibi) başına 15 dk'da 60; IP başına yalnız yüksek toplu tavan |
| `POST /api/auth/forgot-password` | IP başına saatte 10; e-posta başına saatte 5 |
| `POST /api/auth/verify-reset-code`, `reset-password` | IP başına 10 dk'da 20 |
| `POST /api/auth/logout-all` | kullanıcı başına 15 dk'da 5 |
| `POST /api/auth/change-password` | kullanıcı başına saatte 5; IP başına saatte 10 |
| Mesaj gönderme (WS ve REST ortak) | kullanıcı başına dakikada 30 |
| Yazıyor bilgisi | konuşma başına 2 sn'de 1 (sessizce atılır) |
| `POST /api/conversations` | günde 30 |
| Rapor (`/api/reports`, `/api/messages/{id}/report`) | günde 20 |
| Arama `GET /api/search`, `GET /api/users/search` | dakikada 60 |
| Favori ekle/çıkar | dakikada 60 |
| Topluluk oluştur / katıl / gönderi | saatte 5 / saatte 20 / dakikada 10 |
| Etkinlik oluştur / RSVP / QR yoklama | saatte 10 / dakikada 30 / dakikada 20 |
| Avatar yükleme | saatte 10 |
| Sohbet görseli yükleme | dakikada 10, günde 200 (video: ek olarak günde 30) |
| İletildi ack (`delivered`) | dakikada 120 |
| `GET /api/me/summary`, `GET /api/events/{id}/attendees/preview` | dakikada 120 |
| `GET /api/communities/{id}/requests` | saatte 240 |
| Hesap silme | saatte 5; veri dışa aktarma günde 3 |
| Destek talebi aç / yanıt | günde 5 / saatte 30 |
| Geri bildirim / oy | günde 10 / saatte 60 |
| Analitik olayı | dakikada 30 |
| WebSocket el sıkışma | IP başına dakikada 600 |

## 6. Push bildirimleri (FCM) yük formatı
Cihaz kaydı: giriş yaptıktan sonra FCM token ile `POST /api/devices {"fcmToken":"...","platform":"ios","appVersion":"1.4.0","locale":"tr"}` → `204` (saatte 120; `DELETE` ayrı sayaç, saatte 60). **Her girişten sonra yeniden kaydedin** (mobil girişte eski cihaz kayıtları silinir); kayıt yoksa o kullanıcıya push hiç gitmez. `platform`: `ios|android|web` (büyük/küçük harf fark etmez, sunucu büyük harfe çevirir; geçersiz `400`); `appVersion` (≤ 32) ve `locale` (≤ 16) isteğe bağlıdır. Upsert: aynı token başka kullanıcıdaysa devredilir; her çağrı `lastSeenAt`'i yeniler, bu yüzden **her açılışta** ve token yenilenince (`onTokenRefresh`) çağırın. Kullanıcı başına en çok 10 cihaz (fazlası en eskiden silinir); 60 gün görülmeyen token sunucuca temizlenir. `GET /api/devices` yanıtında `appVersion`, `locale`, `lastSeenAt` de vardır. Çıkışta `DELETE /api/devices/{id}` (Bearer geçerliyken; `id` = `GET /api/devices` yanıtındaki cihaz kimliği; eski `DELETE /api/devices/{token}` hâlâ çalışır ama token erişim günlüklerine düşer, yeni istemci kimlik kullanmalı). Geçersiz token FCM'den `UNREGISTERED` dönünce sunucu tarafından silinir.

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
Uygulama içi bildirim listesi: `GET /api/notifications` → `{"items":[{"id":5,"type":"EVENT","title":"...","body":"...","data":"{\"eventId\":\"2\"}","read":false,"createdAt":"..."}],"nextCursor":4,"unreadCount":4}`. Dikkat: listedeki **`data` bir JSON dizesidir** (nesne değil): `jsonDecode(item.data)` yapın; anahtarlar push `data`'sıyla aynıdır. Okundu: `POST /api/notifications/read {"ids":[5,4]}` (en çok 200 kimlik; fazlası 400) veya `{"all":true}` (204). Tercihler: `GET/PUT /api/notifications/preferences` (`news, announcements, events, messages, communities`, `polls`, `academicAnnouncements` (artık yalnız sınav hatırlatmasını yönetir); `messagePreview` alanı KALDIRILDI: mesaj metninin ilk 100 karakteri push gövdesinde/kilit ekranında HER ZAMAN gider); `SYSTEM` her zaman gider).

Not: Firebase servis hesabı (`FCM_CREDENTIALS_JSON`/`FILE`) girilmedikçe sunucu push göndermez; yalnızca uygulama içi liste dolar. Sessiz saatler ve tercihler push'a da uygulanır. Gönderim arka planda yapılır, geçici hatada 3 kez yeniden denenir; süreç yeniden başlarsa kuyruktaki push kaybolabilir, bildirim kutusu kalıcıdır.

## 7. Dosya yükleme sözleşmesi
Yükleme uçları `multipart/form-data`, **alan adı `file`** (topluluk/etkinlik kapağı dahil) ve oturum (Bearer) ister:

| Uç | Alan | Tür | En büyük | Sınır |
|---|---|---|---|---|
| `POST /api/users/me/avatar` | `file` | jpg, png, webp | **2 MB** | saatte 10 |
| `POST /api/communities/{id}/cover` | `file` | jpg, png, webp | **3 MB** | saatte 10 |
| `POST /api/communities/{id}/posts/upload` | `file` | jpg, png, webp | **3 MB** | saatte 20 |
| `PUT /api/events/{id}/cover` (eski ad `POST` de çalışır) | `file` | jpg, png, webp | **3 MB** | saatte 10 |
| `POST /api/posts/media` (Keşfet gönderisi) | `file` (+ video için `poster`) | fotoğraf: jpg, png, webp; **video: mp4, mov (quicktime), m4v, webm (≤ 60 sn)** | fotoğraf 3 MB; **video 50 MB** | saatte 30 |

- Doğrulama **`Content-Type`** üzerinden yapılır: parçanın `Content-Type`'ı mutlaka `image/jpeg|image/png|image/webp` olmalı (Dio `MultipartFile.fromFile(path, contentType: MediaType('image','jpeg'))`). Dosya adını sunucu üretir (UUID); istemcinin adı kullanılmaz.
- Hatalar: `400 INVALID_FILE` (tür/boş), `413 FILE_TOO_LARGE` (ayrıca Spring genel üst sınırı 5 MB; istek 6 MB'ı aşarsa da `FILE_TOO_LARGE`), `503 STORAGE_UNAVAILABLE`. Yüklemeden önce istemcide küçültüp sıkıştırın.
- Yanıt göreli URL döndürür (`/files/avatars/<uuid>.jpg` biçiminde, avatar için profil nesnesinde `avatarUrl`). Görseli `https://<alan-adı>` + yol ile **kimliksiz** `GET` ile indirebilirsiniz (herkese açık, `Cache-Control: max-age=30 gün, immutable`; URL değişmez, önbellekleyin).
- Gönderi görseli akışı: önce `.../posts/upload` ile yükleyip dönen URL'yi `POST /api/communities/{id}/posts {text, imageUrl}` içinde gönderin.
- Sohbet görselleri ayrı bir akıştır (kimlikli okuma, `attachmentIds`): bkz. 4.8. Mesaj metni düz metindir (≤ 2000 karakter; HTML/Markdown yorumlanmaz, `Text` ile çizin).

## 8. Sürüm kontrolü ve bakım akışı
Uygulama açılışında (ve öne her gelişte, en çok birkaç dakikada bir) kimliksiz iki çağrı yapın:

```http
GET /api/app/version?platform=android&version=1.0.3      # platform: android | ios; version: 1.2.3.4 biçimi (sayılar+nokta)
→ {"updateRequired":false,"updateAvailable":true,"latestVersion":"1.1.0","storeUrl":"https://play.google.com/store/apps/details?id=tr.com.bukampus.app",
   "message":"Önemli bir düzeltme yayınlandı.","marketUrl":"market://details?id=tr.com.bukampus.app"}
# storeUrl: yöneticinin yazdığı adres; boşsa Android için paket adından, iOS için Apple kimliğinden TÜRETİLİR (iOS kimliği yoksa null)
# marketUrl: Android market://details?id=..., iOS itms-apps://apps.apple.com/app/id... (yoksa null)
# message: Accept-Language dilinde yönetici metni (boşsa null)
GET /api/app/info
→ {"appName":"Bingöl Üniversitesi","website":"https://www.bingol.edu.tr","contactEmail":null,"supportEmail":null,"phone":null,"address":null,
   "social":{"instagram":null,"twitter":null,"youtube":null},"banner":null,
   "maintenance":{"enabled":false,"message":"Sistem bakımda. Lütfen daha sonra tekrar deneyin."},"languages":["tr","en","ar"]}
```
Karar akışı:
1. `updateRequired=true` → **zorunlu güncelleme** ekranı (kapatılamaz). "Güncelle": önce `marketUrl` (yalnız `market://` / `itms-apps://` şemaları, dış uygulama olarak), açılmazsa `storeUrl` (https); ikisi de `null` ise düğme yerine "Mağazadan güncelleyin" yazısı (ölü düğme yok). `message` doluysa varsayılan açıklamanın yerine gösterin. Kontrol anı: açılış + öne dönüş (en çok 15 dk'da bir; kilit açıkken her dönüşte); ağ yoksa kilitlemeyin (fail-open). API çağrılarına devam etmeyin.
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
| `ACCESS_BLOCKED` | 403 | Bu cihaza veya ağa erişim kapatıldı. | Access from this device or network has been blocked. | تم إغلاق الوصول من هذا الجهاز أو الشبكة. |
| `ACCOUNT_SUSPENDED` | 403 | Hesabınız askıya alınmıştır. | Your account has been suspended. | تم تعليق حسابك. |
| `ALREADY_MEMBER` | 409 | Zaten üyesiniz veya isteğiniz bekliyor. | You are already a member or your request is pending. | أنت عضو بالفعل أو أن طلبك قيد الانتظار. |
| `ALREADY_REPORTED` | 409 | Bu içeriği zaten raporladınız. | You have already reported this content. | لقد أبلغت عن هذا المحتوى مسبقًا. |
| `ALREADY_RESOLVED` | 409 | Rapor zaten sonuçlandırılmış. | This report has already been resolved. | تمت معالجة هذا البلاغ مسبقًا. |
| `BAN_BULK_TOO_LARGE` | 400 | Toplu yüklemede en çok {0} satır olabilir. | A bulk upload can contain at most {0} lines. | يمكن أن يحتوي الرفع الجماعي على {0} سطر كحد أقصى. |
| `BAN_INVALID_VALUE` | 400 | Engel değeri geçersiz. | The ban value is invalid. | قيمة الحظر غير صالحة. |
| `BAN_NOT_FOUND` | 404 | Engel kaydı bulunamadı. | Ban record not found. | سجل الحظر غير موجود. |
| `BAN_SELF_LOCKOUT` | 400 | Bu engel sizi veya yönetim ağını kilitleyebilir; işlem reddedildi. | This ban could lock you or the admin network out; the operation was rejected. | قد يؤدي هذا الحظر إلى إغلاق الوصول عليك أو على شبكة الإدارة؛ تم رفض العملية. |
| `BANNED` | 403 | Bu topluluktan uzaklaştırıldınız. | You have been removed from this community. | تمت إزالتك من هذا المجتمع. |
| `BLOCKED` (artık mesajlaşma uçlarında dönmez) | 403 | Bu kullanıcıyla mesajlaşamazsınız. | You cannot message this user. | لا يمكنك مراسلة هذا المستخدم. |
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
| `POST_NOT_FOUND` | 404 | Gönderi bulunamadı. | Post not found. | المنشور غير موجود. |
| `QUERY_TOO_SHORT` | 400 | En az 2 karakter girin. | Enter at least 2 characters. | أدخل حرفين على الأقل. |
| `RATE_LIMITED` | 429 | Çok fazla deneme. Lütfen daha sonra tekrar deneyin. | Too many attempts. Please try again later. | محاولات كثيرة جدًا. يرجى المحاولة لاحقًا. |
| `REPORT_NOT_FOUND` | 404 | Rapor bulunamadı. | Report not found. | البلاغ غير موجود. |
| `REQUEST_NOT_FOUND` | 404 | Bekleyen istek bulunamadı. | Pending request not found. | لم يتم العثور على طلب معلّق. |
| `REQUEST_PENDING` | 409 | Katılma isteğiniz zaten bekliyor. | Your join request is already pending. | طلب الانضمام الخاص بك قيد الانتظار بالفعل. |
| `RESEND_COOLDOWN` | 429 | Yeni kod için {0} saniye sonra tekrar deneyin. | Please try again in {0} seconds to request a new code. | يرجى المحاولة بعد {0} ثانية لطلب رمز جديد. |
| `ACCOUNT_NOT_FOUND` | 404 | Bu okul numarasına ait kayıtlı hesap bulunamadı. | No registered account was found for this school number. | لم يتم العثور على حساب مسجل لهذا الرقم الجامعي. |
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
| `PASSWORD_TOO_SHORT` | 400 | Şifre en az {0} karakter olmalı. | The password must be at least {0} characters. | يجب أن تتكون كلمة المرور من {0} أحرف على الأقل. |
| `PASSWORD_UNCHANGED` | 422 | Yeni şifre mevcut şifreyle aynı olamaz. | The new password must differ from the current password. | يجب أن تختلف كلمة المرور الجديدة عن الحالية. |

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
- **Haber:** `GET /api/news?type=` büyük/küçük harf toleranslıdır; geçersiz tür `400 NEWS_TYPE_INVALID`; `size` 1-50. `NewsSummary`/`NewsDetail`'de yeni **`eventDate`** (`yyyy-MM-dd` veya `null`; yalnız ETKINLIK). Sıralama yayın tarihi azalan, tarihsizler sonda. `GET /api/menu?month=yyyy-MM` geçersiz ay `400 MENU_MONTH_INVALID`. `GET /api/status` her kaynakta **`maintenanceMessage`** (istek dilinde; bakım yoksa `null`) taşır; `message` teknik ayrıntıdır, kullanıcıya `maintenanceMessage` gösterin. **Arama (P07):** `GET /api/news?q=` en az **3** karakter (2 karakter `400`), IP başına dakikada 30 istek (`429` + `Retry-After`); `page` en çok 200. `GET /api/menu/today` önbelleği 60 sn.
- **Yemek kalorisi (V870):** `GET /api/menu?month=` ve `GET /api/menu/today` günlük nesnesine üç alan eklendi: `dishes: [{ "name": "MERCİMEK ÇORBASI", "kcal": 180 }, ...]` (`items` ile **aynı sıra ve uzunluk**; `kcal` yönetici girmediyse `null`), `totalKcal` (kalorisi bilinen yemeklerin toplamı; hiçbirinin kalorisi yoksa `null`) ve `kcalComplete` (bütün yemeklerin kalorisi girilmişse `true`). `items` (yalnız ad dizisi) ve `imageUrl` aynen durur; eski istemci yeni alanları yok sayar. Arayüz: `kcal != null` ise yemek kartında "180 kcal" gösterin, `null` ise kalori satırını gizleyin (0 yazmayın); günlük toplamı `kcalComplete=false` iken "en az {totalKcal} kcal" diye gösterin, `totalKcal == null` iken hiç göstermeyin. Kalori yöneticiye aittir, kaynak site yeniden çekilse de kaybolmaz; ETag/304 gövdeden üretildiği için kalori değişince önbellek kendiliğinden yenilenir.
- **Takvim:** `GET /api/events/calendar?month=YYYY-MM` → `CalendarItem[]`. USER öğelerinde yeni `myRsvp`, `goingCount`, `interestedCount`, `capacity` (`null` = sınırsız), `status`, `communityName`; OFFICIAL öğelerde bunlar `null`. Önceki aydan süren etkinlikler ay içinde görünür (`date` ay içinde kalır, `startsAt` gerçek başlangıç). Sonuç sınırlıdır (USER 300, resmi 200); sınır aşılırsa **`X-Truncated: true`** başlığı gelir (kullanıcıya "tümü gösterilmiyor" notu verin). OFFICIAL öğe tarihi haberin `eventDate` değeri varsa o, yoksa yayın tarihidir.
- **Katılımcı önizleme:** `GET /api/events/{id}/attendees/preview` (Bearer, dakikada 120) → `{"goingCount":42,"interestedCount":7,"avatars":[{"userId","displayName","avatarUrl"}]}`; en çok 8 avatar, yalnız gizlilik ayarı izin verenler. Tam liste (`/attendees`) organizatöre kısıtlıdır.
- **Topluluk:** `GET /api/communities/categories` → `[{"category":"Spor","count":3}]` (yalnız ACTIVE+PUBLIC; `category` değeri `GET /api/communities?category=Spor` filtresinde aynen kullanılır, `q` ad/açıklamada arar). Katılım: önce `GET /api/communities/{id}/join-questions` → `[{id,question}]`; sonra `POST /api/communities/{id}/join {"answers":[{"questionId":1,"answer":"..."}]}` → `{"status":"ACTIVE"|"PENDING"}`; soru varsa hepsi yanıtlanmalı, yoksa `400 ANSWERS_REQUIRED`. Açık kulüpte gövde gerekmez. Yönetici için `GET /api/communities/{id}/requests?include=answers` her isteğe `answers[]` ekler (verilmezse alan yoktur); onay/ret sonrası yanıtlar silinir.
- **Engeller:** `GET /api/users/me/blocks?cursor=&limit=` düz dizi + `X-Next-Cursor` (bölüm 3).
- Cihaz kaydı ve push `data` değişiklikleri bölüm 6'da, `logout-all` ile şifre sıfırlama bölüm 1'dedir.
- **Hesap silme** artık cihazları, bildirimleri, favorileri, kulüp başvuru yanıtlarını ve topluluk üyeliklerini de temizler; yerel veriyi silmek istemcinin işidir.
- **Google/Apple girişi + profil tamamlama (bölüm 1.10, bayrak `AUTH_OAUTH_ENABLED`, varsayılan kapalı):** `POST /api/auth/oauth/google|apple`, `POST /api/auth/oauth/link`, `DELETE /api/auth/oauth/link/{provider}`, `GET /api/auth/oauth/identities`, `GET /api/users/username-available?u=`, `PUT /api/users/me/onboarding`, `PUT /api/users/me/username`; `GET /api/users/me` yanıtına `profileCompleted`, `username`, `firstName`, `lastName`, `universityName`, `authProviders[]`; tamamlanmamış profilde tüm yazma uçları `403 PROFILE_INCOMPLETE`; `DELETE /api/users/me` gövdesinde `password` artık zorunlu değil (parolasız hesap: `provider`+`token`). Yeni kodlar: `OAUTH_*`, `PROFILE_INCOMPLETE`, `USERNAME_*`, `PROFILE_FIELD_REQUIRED`, `TERMS_REQUIRED`.

`/api/admin/**` yönetim panelidir (web); mobil istemci kullanmaz.

## 12. Sözleşme testi ve belge yenileme
```bash
# Yığın ayakta iken (ör. compose proje adı wt_t7, port 8107)
BASE=http://localhost:8107 ADMIN_PASSWORD=... node scripts/openapi-gen.js      # docs/openapi.json'ı canlı sunucudan yeniler
BASE=http://localhost:8107 ADMIN_PASSWORD=... COMPOSE_PROJECT_NAME=wt_t7 node scripts/openapi-check.js
node scripts/openapi-errors.js --inject docs/MOBILE_API_GUIDE.md                # hata tablosunu yeniler
```
`openapi-check.js`: belge ile canlı belgenin aynılığını, kimlikli/kimliksiz erişim kurallarını (Swagger/`/v3/api-docs` yalnızca ADMIN; arayüz üretimde kapalı), kimlik akışını ve parametresiz tüm GET uçlarının gerçek yanıtlarını şemaya karşı (tür, zorunlu alan, belgesiz alan, null) doğrular; `FORCE_SEED=1` ile örnek kayıt oluşturup POST gövdelerini de doğrular. Swagger arayüzü yalnızca `dev` profilinde (`SPRING_PROFILES_ACTIVE=dev` veya `SWAGGER_UI_ENABLED=true`) açılır ve yine ADMIN ister.

### Etkinlik kapağı ve öne çıkan etkinlik

- `PUT /api/events/{id}/cover` (multipart `file`; yalnız etkinliği oluşturan/ortak organizatör/kulüp yetkilisi/yönetici): görsel medya hattından geçer (tür/boyut doğrulama, yeniden kodlama, EXIF temizliği, en çok 1600 px). 200 -> `EventView` (`coverUrl`: `/files/covers/<özet>.jpg`, herkese açık; küçük resim `-t` ekli). Akış: önce `POST /api/events`, sonra kapak. İptal/reddedilmiş etkinlikte 409 `EVENT_NOT_EDITABLE`; yetkisizde 403, görünmeyende 404.
- `DELETE /api/events/{id}/cover` -> 204 (idempotent). Etkinlik silinince (iptal) kapak dosyası da temizlenir.
- `coverUrl` liste, detay, `/me/events` ve `featured` görünümlerinde; takvimde USER öğelerinde `imageUrl` alanı olarak gelir.
- `GET /api/events/featured` (Bearer, ETag, `Cache-Control: private, max-age=30`): yaklaşan ya da sürmekte olan, ACTIVE kullanıcı etkinlikleri içinde `goingCount` en yüksek olan; eşitlikte başlangıcı yakın olan. Yaklaşan yoksa **204**. Resmi (siteden gelen) etkinlikler dahil değil. Yanıt `EventView`:

```json
{ "id": 12, "title": "Kariyer Günleri", "description": "...", "startsAt": "2026-11-10T09:00:00Z",
  "endsAt": "2026-11-10T17:00:00Z", "location": "Kongre Merkezi", "coverUrl": "/files/covers/ab12.jpg",
  "capacity": 300, "goingCount": 142, "interestedCount": null, "communityId": 3, "communityName": "Kariyer Kulübü",
  "createdBy": 5, "organizerName": "Ayşe K.", "status": "ACTIVE", "myRsvp": "GOING", "canManage": false,
  "createdAt": "2026-10-01T10:00:00Z", "registrationClosed": false }
```

Katılımcı önizlemesi için `GET /api/events/{id}/attendees/preview` çağrılır. Hız sınırı: dakikada 60.

## Kulüp ve etkinlik yaşam döngüsü (kurma, ayrılma, silme, kapatma, Etkinliklerim)

**Kulüp kurma** — `POST /api/communities` `{name, description?, category?, joinPolicy?: OPEN|APPROVAL, visibility?: PUBLIC|PRIVATE}` (her doğrulanmış kullanıcı; saatte 5; aynı anda en çok 3 sahip olunan kulüp, aşımda `409 COMMUNITY_LIMIT`).
- Ayar `app.community.auto-approve` (`APP_COMMUNITY_AUTO_APPROVE`, varsayılan **true**): `201 Created` + `CommunityView.status = "ACTIVE"` (kulüp hemen yayında, sohbet odası kurulu, `myRole = "OWNER"`). `false` ise eski akış: `202 Accepted` + `status = "PENDING_REVIEW"` (yönetici onayı; onaylanınca bildirim gelir). İstemci iki durumu da `status` alanından ayırt etmelidir.
- Düzenleme `PATCH /api/communities/{id}` (`name, description, category, joinPolicy, visibility`; hepsi isteğe bağlı), kapak `POST /api/communities/{id}/cover`, logo `POST|DELETE /api/communities/{id}/logo`. Yetki: `EDIT_INFO` (sahip/yönetici/yetkilendirilmiş üye); yetkisiz `403`.
- **Silme** `DELETE /api/communities/{id}` → `204` (yalnız sahip veya sistem yöneticisi; saatte 10; diğerleri `403 FORBIDDEN`). Yumusak silme (`status = DELETED`): keşfet/arama/`me/communities`'ten düşer, sonrasında her uç `404 COMMUNITY_NOT_FOUND` verir (sahibe de). Etkileri: kulüp sohbet odası kapanır (tüm üyeler odadan çıkar; WS `conversation-removed` olayı), kulübün **bitmemiş** etkinlikleri iptal edilir (katılımcılara `notif.event.cancelled`, etkinlik odaları kapanır; geçmiş etkinlikler görünmez olur), aktif üyelere `notif.community.deleted` bildirimi gider, kapak/logo dosyaları silinir.
- İstek yönetimi (değişmedi): `GET /api/communities/{id}/requests?cursor&size&include=answers`, `POST .../requests/{userId}/approve|reject`, `GET|PUT .../join-questions`; üye yönetimi `DELETE .../members/{userId}?ban=`, `PUT .../members/{userId}/role`. Yetki `MANAGE_MEMBERS`; eşit/üst düzey üyeye müdahale `403 ESCALATION_DENIED`; sahip çıkarılamaz `403 OWNER_PROTECTED`.

**Kulüpten ayrılma** — `DELETE /api/communities/{id}/membership` → `204` (saatte 60). Sahip ayrılamaz: `409 OWNER_CANNOT_LEAVE` (önce `POST .../ownership-transfer` ya da kulübü sil). Ayrılınca (çıkarılma/yasaklanma/istek reddi dahil, aynı kural):
- Kulüp sohbetinden çıkarılır (üyelik satırı `leftAt` ile kapanır) ve bağlı etkinlik sohbetlerinden de (kendi oluşturduğu etkinlik hariç).
- `GET /api/conversations` listesinde artık görünmez; `GET|POST /api/conversations/{id}/messages`, `/read`, medya, okunmamış sayacı, arama `404` verir; `GET /api/communities/{id}/chat` `404 CHAT_ROOM_NOT_FOUND`.
- Açık WebSocket: kullanıcı sohbetin `/user/queue/*` teslim listesinden düştüğü için yeni olay almaz. Ek olarak `/user/queue/message-events` kuyruğuna **`{"type":"conversation-removed","conversationId":7,"at":"..."}`** gelir; istemci konuşmayı listeden ve açık ekrandan kaldırmalıdır.
- Yeniden katılırsa (`join`/onay) sohbet listede yeniden belirir; yalnız yeniden katılımdan sonraki mesajlar görünür (`joinedAt` kuralı), eskiler görünmez ve okunmamış sayılmaz.

**Etkinlik** — oluşturma `POST /api/events` (kulüp etkinliği için `MANAGE_EVENTS`; bağımsız etkinlik herkese açık, yönetici ayarı `events_require_approval` açıksa `202 PENDING_REVIEW`). Düzenleme `PATCH /api/events/{id}`. Yetkili: oluşturan, ortak organizatör, kulüp yetkilisi, yönetici (`EventView.canManage`).
- **İptal** (etkinlik CANCELLED olur, katılımcılara bildirim, sohbet odası kapanır): `DELETE /api/events/{id}` → `204` ya da eşdeğeri `POST /api/events/{id}/cancel` → `204`. İdempotent.
- **Kayıtları kapat** `POST /api/events/{id}/close` → `200 EventView` (`registrationClosed: true`); **yeniden aç** `POST /api/events/{id}/reopen` → `200 EventView`. İdempotent; saatte 60 yönetim işlemi. Kapalıyken: etkinlik görünür kalır; yeni RSVP/başvuru (ve `INTERESTED → GOING` geçişi) `409 EVENT_REGISTRATION_CLOSED`; mevcut RSVP'ler etkilenmez, geri çekilme (`DELETE .../rsvp`) çalışır. İptal/reddedilmiş etkinlikte `409 EVENT_NOT_EDITABLE`, bitmişte `409 EVENT_ENDED`, yetkisizde `403`.
- `EventView`'a yeni alan **`registrationClosed`** (boolean). Tam alan listesi: `id, title, description, startsAt, endsAt, location, coverUrl, capacity, goingCount, interestedCount, communityId, communityName, createdBy, organizerName, status, myRsvp, canManage, createdAt, registrationClosed`.
- **RSVP** `PUT /api/events/{id}/rsvp {"status":"GOING"|"INTERESTED"}` ("Katılıyorum" = `GOING`); katılımcı listesine (`GET .../attendees`, organizatör) girer ve "Etkinliklerim"de görünür. Geri çekme `DELETE .../rsvp`. Sınır: kullanıcı başına dakikada 30 (genel) ve **aynı etkinlikte dakikada 5 değişiklik** (PUT+DELETE toplam); aşımda `429` + `Retry-After`.
- **Etkinliklerim** `GET /api/me/events?mode=&cursor=&size=` (takma ad: `GET /api/events/me`), imleçli (`cursor` = son kaydın `id`'si): `mode=upcoming` yaklaşan/süren, RSVP'lim (GOING+INTERESTED) + oluşturduklarım; `going` yaklaşan, yalnız GOING; `past` bitmiş, RSVP'lim + oluşturduklarım, yeniden eskiye; `created` oluşturduklarım (iptaller hariç, `id` azalan; bekleyen onaylılar dahil). Eski adlar: `attending` (varsayılan; yaklaşan RSVP'liler) ve `organizing` (= `created`). Bilinmeyen mod `attending` gibi davranır.

## Rehber eşleştirme

Kullanıcı rehberindeki e-posta adreslerinden uygulamadaki (bingol.edu.tr) kişileri bulur. Ham e-posta sunucuya gönderilmez.

`POST /api/users/contacts/match` (kimlik doğrulamalı)

```json
{"hashes":["<sha256 hex, küçük harf>", "..."]}
```

- Her hash: e-posta adresinin kırpılıp küçük harfe çevrilmiş halinin SHA-256'sı (UTF-8), 64 karakterli hex.
- En çok 500 hash; fazlası `400 CONTACTS_TOO_MANY`. Yinelenen veya biçimi bozuk değerler sessizce yok sayılır.
- Yanıt: `{"matches":[{"hash":"…","userId":12,"displayName":"…","avatarUrl":"/files/avatars/…"|null,"faculty":null,"department":null}]}`
  (eşleşmeyen hash yanıtta yer almaz).
- Yalnızca aktif, doğrulanmış, bingol.edu.tr (alt alanlar dahil) hesaplar; kendi hesabın ve engel ilişkisi (iki yönlü) olanlar gelmez.
  Avatar, fakülte ve bölüm karşı tarafın gizlilik ayarına göre `null` olabilir.
- Rate limit: kullanıcı başına saatte 6, IP başına saatte 30 istek; aşımda `429` + `Retry-After`.
- Sunucu hash'leri ve sonuçları saklamaz/loglamaz. İstemci de rehberi yalnızca eşleştirme sırasında bellekte tutmalıdır;
  rehber izni kullanıcıdan açıkça istenmelidir.


## Gönderiler (Keşfet akışı)
Tek sözleşme: [POSTS_DESIGN.md](POSTS_DESIGN.md); değişiklik notu: `docs/changes/post.md`. Tüm uçlar Bearer ister.

> **GÜNCELLEME (2026-11-04): video geri geldi, Keşfet tek sıralama oldu; bu kutudaki "yalnız fotoğraf / video `POST_VIDEO_NOT_ALLOWED`" ve `scope=latest|popular` ifadeleri geçersizdir. Geçerli sözleşme: sayfa sonundaki "Keşfet v2" bölümü.**
>
> **SADE KEŞFET (2026-10-28) — bu bölümün ve aşağıdaki "Yorum ve yanıt" / "Gönderi sosyal özellikleri" bölümlerinin eski satırlarıyla çelişirse bu kutu geçerlidir (video/kapsam kısımları hariç, bkz. yukarı).**
> - Gönderi: **tam 1 fotoğraf zorunlu**, metin isteğe bağlı (çok satırlı olabilir; **kullanıcıya gösterilmeyen** üst sınır 2200 karakter/40 satır), isteğe bağlı `mentionUserIds` (en çok 10, yalnız takip ettikleriniz; bkz. "Gönderi etiketleme"). Önce `POST /api/posts/media` (yalnız görsel; video `400 POST_VIDEO_NOT_ALLOWED`), sonra `POST /api/posts` `{"text":"güzel bir gün","mediaIds":[12]}` → 201 `PostView`.
> - Hatalar: `400 POST_PHOTO_REQUIRED` (mediaIds boş), `400 POST_SINGLE_PHOTO_ONLY` (2+), `400 POST_VIDEO_NOT_ALLOWED`, `400 POST_MEDIA_INVALID`, `422 POST_TEXT_TOO_LONG` (gizli üst sınır aşıldı: 2200 karakter/40 satır; PATCH'te de; mesaj sayı içermez), `422 POST_MENTION_INVALID` (etiketlenen kişi takip edilmiyor/pasif/engelli/kendisi/10'dan çok), `422 CONTENT_PROFANITY`. Eski `POST_TOO_LONG` (2000) ve `POST_EMPTY` (oluşturmada) artık dönmez.
> - **Gönderi etiketleme (2026-11-05, V1310; aşağıdaki eski `@[Ad](uid:)` / `mention-suggest` / `MENTION_TOO_MANY` anlatımının ve "etiketler kaldırıldı" notunun YERİNE geçer):** `POST /api/posts` ve `PATCH /api/posts/{id}` gövdesinde isteğe bağlı `mentionUserIds: [int]` (en çok 10, tekrarsız; **yalnız takip ettiğiniz** kişiler: kabul edilmiş takip). Geçersiz her kimlik (takip edilmiyor, pasif, engel var, kendisi, 10'dan çok farklı kişi) → `422 POST_MENTION_INVALID`, tüm istek reddedilir. PATCH'te alan **yoksa etiketler değişmez**, **varsa (boş dizi dahil) liste yeniden yazılır**; yalnız yeni eklenenlere bildirim gider. Metne istemci düz `@Ad Soyad` yazar ve sunucu metne dokunmaz; `PostView.mentions = [{ "userId": 12, "displayName": "Ayşe Yılmaz" }]` (yoksa `[]`; pasif/engelli kişi bakana göre listeden çıkar) ile eşleştirip çizin. Etiket önerisi için ayrı uç yok: `GET /api/users/{id}/following` (+ arama). Etiketlenene `POST_MENTION` bildirimi: başlık "Yeni etiket", gövde "{ad} seni bir gönderide etiketledi" (alıcı dilinde), `targetType: POST`, `targetId` = gönderi, `data.userId` = etiketleyen, push `style=SOCIAL`, `senderName`, `senderAvatarUrl` (gizlilik süzgeciyle), `imageUrl` (küçük resim, yalnız push). Aynı (gönderi, kişi) için tek bildirim; kendi kendine ve alıcının göremediği gizli hesap gönderisinde bildirim yok.
> - **Gönderi videosu sınırı (mobil kırpma ekranı için):** ≤ 60 sn (500 ms tolerans; `400 VIDEO_TOO_LONG`), ≤ 50 MB (`413 VIDEO_TOO_LARGE`), MP4/MOV/M4V/WebM, çözünürlük sınırı yok (sunucu 720p/H.264'e dönüştürür), saatte 30 yükleme.
> - **Kaldırıldı → `410 FEATURE_REMOVED`** (`{"code","message"}`): yorumlar (`/api/posts/{id}/comments`, `/api/comments/**`), hikâyeler (`/api/stories/**`, `/api/users/{id}/stories`), etiketler (`/api/hashtags/**`), `GET /api/users/mention-suggest`, kaydet (`/api/posts/{id}/save`, `/api/posts/saved`), `GET /api/posts/{id}/likes`. İstemci 410'u yeniden denememeli; ilgili arayüzü kaldırıp (gerekirse "uygulamayı güncelleyin" göstererek) çağrıyı bırakmalıdır.
> - **Kalan:** beğeni (`PUT|DELETE /api/posts/{id}/like`), takip ve akış kapsamları, gönderi sil/düzenle(metin), rapor.
> - `PostView` geriye uyumlu: `commentCount=0`, `savedByMe=false`, `mentions=[]`, `hashtags=[]`, `media` ≤ 1 (yalnız ilk görsel). Eski video-only/fotoğrafsız gönderiler listelerde yoktur.
> - Yeni gönderi örneği: istek `{"text":"kampüste akşam","mediaIds":[12]}` → `201 {"id":91,"author":{…},"text":"kampüste akşam","media":[{"id":12,"kind":"IMAGE","url":"/api/posts/media/12","thumbUrl":"/api/posts/media/12?thumb=true","width":1080,"height":1350,"durationMs":null}],"likeCount":0,"commentCount":0,"likedByMe":false,"mine":true,"canEdit":true,"canDelete":true,"createdAt":"…","editedAt":null,"savedByMe":false,"mentions":[],"hashtags":[]}`.

| Uç | Açıklama |
|---|---|
| `POST /api/posts` `{text?, mediaIds?}` | 201 `PostView`. Metin veya medya zorunlu (`400 POST_EMPTY`), metin ≤ 2000 (`400 POST_TOO_LONG`), medya geçersiz (`400 POST_MEDIA_INVALID`), küfür (`422 CONTENT_PROFANITY`). Saatte 20 gönderi. |
| `GET /api/posts/{id}` | `PostView`; silinmiş/gizli/engelli/yazarı pasif → `404 POST_NOT_FOUND`. |
| `PATCH /api/posts/{id}` `{text}` | Yalnız yazar (`403 POST_FORBIDDEN`); `editedAt` dolar, medya değişmez. |
| `DELETE /api/posts/{id}` | 204; yazar veya ADMIN (yumuşak silme). |
| `GET /api/feed?cursor=&size=` | **Tek puanlı akış** (`scope` yok/`top`/`popular`/`latest` aynı akış; `following`/`department` ayrı). Bkz. "Keşfet v2". |
| `GET /api/users/{id}/posts`, `GET /api/posts/mine` | Aynı sayfa biçimi (`cursor`, `size`); engel ilişkisinde boş liste. |

- **İmleç opaktır**: `nextCursor` değerini aynen `cursor` olarak geri verin; `scope` değiştirilince imleç atılır. Bozuk imleç `400 POST_CURSOR_INVALID`. `popular`'da puan saatlik güncellendiği için nadiren aynı gönderi sayfalar arasında tekrar edebilir (istemci `id` ile tekilleştirsin).
- `PostView`: `{id, author{id,displayName,avatarUrl,department}, text, media[], likeCount, commentCount, likedByMe, mine, canEdit, canDelete, createdAt, editedAt}`. `avatarUrl`/`department` yazarın gizlilik ayarına göre `null` olabilir. `canEdit` yalnız yazar, `canDelete` yazar veya ADMIN içindir.
- Okuma uçları dakikada 120, düzenleme/silme dakikada 30 istek; aşımda `429` + `Retry-After`.
- Hata kodları: `POST_NOT_FOUND` 404, `POST_EMPTY` 400, `POST_TOO_LONG` 400, `POST_FORBIDDEN` 403, `POST_MEDIA_INVALID` 400, `POST_CURSOR_INVALID` 400 (tr/en/ar `i18n/post*.properties`).

### Beğeni
| Uç | Açıklama |
|---|---|
| `PUT /api/posts/{id}/like` | 200 `{liked:true, likeCount}`; idempotent. Görünmeyen gönderi `404 POST_NOT_FOUND`. |
| `DELETE /api/posts/{id}/like` | 200 `{liked:false, likeCount}`; idempotent. |
| `GET /api/posts/{id}/likes?cursor=&size=` | `{items:[{id,displayName,avatarUrl,likedAt}], nextCursor:string\|null, total}`; size <= 30; engelliler gizli. |

- Dakikada 120 istek (`429` + `Retry-After`). Mobil iyimser güncelleme yapabilir; yanıttaki `likeCount` gerçeğin kaynağıdır.
- Bildirim türleri: `POST_LIKE`, `POST_COMMENT`, `COMMENT_REPLY` (push `data`: `targetType:"POST"`, `targetId:<postId>`, `commentId` varsa yorum). Aynı gönderinin beğenileri 10 dk içinde tek bildirimde birleşir ("A ve 3 kişi gönderini beğendi"); tercih anahtarı mevcut `communities` bayrağı, ayrıca `subtypes.POST_LIKE|POST_COMMENT|COMMENT_REPLY`.

### Yorum ve yanıt (iç içe)
| Uç | Açıklama |
|---|---|
| `GET /api/posts/{id}/comments?sort=new\|top&cursor=&size=` | `{items:[CommentView], nextCursor:string\|null, total}`; yalnız KÖK yorumlar, size 1-20. `new` yeniden eskiye; `top` = yanıt sayısı sonra yenilik. Her köke `previewReplies` (en eski 2 yanıt) ve `replyCount` gelir. `total` = gönderideki silinmemiş tüm yorum+yanıt (`commentCount`). |
| `GET /api/comments/{id}/replies?cursor=&size=` | `{items:[CommentView], nextCursor}`; eskiden yeniye, size 1-20; `previewReplies` bu uçta `null`. |
| `POST /api/posts/{id}/comments` `{text, parentId?}` | 201 `CommentView`. Metin ≤ 1000. `parentId` verilirse yanıt. |
| `PATCH /api/comments/{id}` `{text}` | Yalnız yazar; `editedAt` dolar. |
| `DELETE /api/comments/{id}` | 204; yazar, gönderi sahibi veya ADMIN. |

- `CommentView`: `{id, postId, parentId, rootId, depth(0..3), author{id,displayName,avatarUrl}, replyToUser{id,displayName}|null, text, deleted, replyCount, mine, canEdit, canDelete, createdAt, editedAt, previewReplies}`.
- **Derinlik**: en çok 3. Derinliği 3 olan bir yoruma yanıt verilirse yeni yorum onun kardeşi olarak eklenir (`parentId` = ebeveynin ebeveyni, `depth` 3) ve `replyToUser` yanıtlanan kişidir; arayüz "@ad" göstermek için `replyToUser` kullanmalı. Her yanıtta `replyToUser` doludur (ebeveyn yazarı).
- **Silinen yorum**: yanıtı varsa listede kalır: `deleted:true`, `text:null`, `author:null` (başlık "Bu yorum silindi"), yanıtları görünür kalır; yanıtı yoksa listeden kalkar. `commentCount` ve `replyCount` buna göre düşer. Silinmiş yoruma yanıt yazılamaz (`400 COMMENT_PARENT_INVALID`).
- **İmleç opaktır** (`nextCursor` aynen `cursor`); `sort` değişince imleç atılır; bozuk imleç `400 POST_CURSOR_INVALID`.
- Engel ilişkisindeki kullanıcıların yorumları iki yönlü gizlenir (`total`e yansımaz). Küfür filtresi `422 CONTENT_PROFANITY` (`field:"text"`).
- Hız: yazma/düzenleme/silme 10 dakikada 30, okuma dakikada 120 (`429` + `Retry-After`).
- Hata kodları: `COMMENT_NOT_FOUND` 404, `COMMENT_EMPTY` 400, `COMMENT_TOO_LONG` 400, `COMMENT_FORBIDDEN` 403, `COMMENT_PARENT_INVALID` 400, görünmeyen gönderi `POST_NOT_FOUND` 404 (tr/en/ar).
- Bildirim: kök yorum → gönderi sahibine `POST_COMMENT`; yanıt → ebeveyn yorum sahibine (ve farklıysa yanıtlanan kişiye) `COMMENT_REPLY`.

## İçerik denetimi: `CONTENT_PROFANITY` (422)

Herkese açık metin alanlarında (kulüp adı/açıklaması/kategorisi/katılım soruları, kulüp gönderisi ve duyurusu, etkinlik başlığı/açıklaması/mekânı/başvuru soruları ve duyurusu, profil adı/biyografi/bölüm, grup sohbeti başlığı, kayıtta görünen ad) uygunsuz ifade reddedilir:

```json
HTTP 422
{ "code": "CONTENT_PROFANITY", "message": "Bu alanda uygunsuz ifade kullanılamaz. Lütfen metni düzenleyin.", "field": "name" }
```

- `message` istek dilindedir (tr/en/ar); `field` istek gövdesindeki alan adıdır (`name`, `description`, `category`, `text`, `title`, `message`, `location`, `questions`, `displayName`, `bio`, `department`, `subject`). Hatalı kelime **asla** yanıtta yer almaz; arayüz yalnızca ilgili alanı işaretleyip mesajı göstermelidir.
- Güncellemelerde (PATCH/PUT) yalnızca **değişen** alanlar denetlenir.
- **Sohbet mesajları (birebir/grup/kulüp/etkinlik odası: gövde ve görsel açıklaması) filtrelenmez.** Sorunlu mesaj için mevcut mesaj şikâyeti kullanılır (sebep `INAPPROPRIATE` / `HARASSMENT`).

## Akademik: ders programı, sınavlar, akademik takvim, bölüm duyuruları

Tam sözleşme (JSON örnekleri, hata kodları, saat biçimleri): [API_CONTRACTS_V2.md](API_CONTRACTS_V2.md) "Akademik". Özet:

- **Ders programı (kişisel):** `GET /api/timetable`, `POST|PATCH|DELETE /api/timetable/courses[/{id}]` (bir ders + çok oturum; çakışma `409 COURSE_CONFLICT`, `force=true` ile geçilir), `POST /api/timetable/import` (en çok 60 oturum), `GET /api/timetable/today|week|reminders`, `GET /api/timetable/export.ics` (VTIMEZONE Europe/Istanbul, haftalık RRULE), dönemler `/api/timetable/semesters` (+ `from-official`).
- **Resmi programdan kişisel program (V1160):** profildeki bölüm + sınıfa göre yayındaki resmi program kişisel programa (`tt_course` + `tt_session`) kopyalanır. `GET /api/timetable` kişisel dersi hiç olmayan, bu dönem için tohum işareti bulunmayan ve resmi programı TEK birimden gelen kullanıcıya bunu otomatik yapar (işaret `tt_official_seed(user_id, term)`; kullanıcı hepsini silse bile aynı dönem için yeniden tohumlanmaz; birden çok birim eşleşirse yapılmaz; sınıf profilde yoksa eşleşme boş). Güncel dönem = yayındaki resmi programın en yenisi. `GET /api/timetable/official/status` → `{available, applied, term|null, units[]}`; `POST /api/timetable/official/apply` gövde `{unit?, replace?, force?}` → `TimetableView`: birden çok birim varken `unit` zorunlu (`422 OFFICIAL_UNIT_REQUIRED`), geçersiz birim ya da eşleşen program yoksa `404 OFFICIAL_TIMETABLE_NOT_FOUND`; `replace=true` görünen kişisel dersleri siler ve yeniden kopyalar (onay istemcide); `replace` yoksa mevcut derslerle çakışma `409 COURSE_CONFLICT`, `force=true` ile geçilir. Kopyalama: aynı dersin (kod varsa kod+ad+hoca, yoksa ad+hoca) gün/saatleri TEK derse oturum olarak toplanır; renk otomatik; ders kodu, derslik ve not kopyalanmaz; grup/şube (I./II. öğretim) ayrımı yapılmaz, aynı gün-saat tek oturuma iner. En çok 40 ders. Ders eklerken/düzenlerken `code`, `color`, `note`, `room` zorunlu değildir (gönderilirse kabul edilir); zorunlu: ders adı + en az bir oturum.
- **Sınavlar:** kişisel `/api/timetable/exams[/upcoming]`. (Resmi sınav programı `GET /api/exams/official` ve bölüm duyuruları `/api/announcements*` V1251 ile KALDIRILDI.)
- **Akademik takvim:** `GET /api/academic/calendar?month=YYYY-MM|from&to`, `GET /api/academic/calendar/next`.
- Ders/sınav hatırlatmaları **mobil yerel bildirimle** yapılır; sunucu yalnız `reminders` listesini verir. Saat dilimi Europe/Istanbul, `dayOfWeek` ISO 1..7.

## Gönderi sosyal özellikleri (kaydet, @etiket, #etiket, takip, hikâyeler)

Tam sözleşme: [API_CONTRACTS_V2.md](API_CONTRACTS_V2.md) "Gönderi sosyal". Özet:

- **Kaydet:** `PUT/DELETE /api/posts/{id}/save` (idempotent, `{saved}`), `GET /api/posts/saved?cursor&size` (PostView sayfası). `PostView.savedByMe` yalnız kendi görünümünüzde dolu; kaydeden sayısı yoktur.
- **@Etiket:** metne istemci `@[Ad Soyad](uid:123)` yazar (seçici ile; `GET /api/users/mention-suggest?q=&postId=&size=8`). Sunucu en çok 10 kişiyi doğrular (11+ → 400 `MENTION_TOO_MANY`; engelli/pasif kullanıcı sessizce düşer). `PostView.mentions` ve `CommentView.mentions` = `[{id, displayName}]`; `text` biçimi aynen korunur, istemci `@[..](uid:..)` kalıbını "@Ad" olarak çizer. Etiketlenene `POST_MENTION` bildirimi (`targetType: POST`, `data.commentId` yorum için).
- **#Etiket:** metindeki `#etiket` (2–40 harf/rakam/_) sunucuda çıkarılır; `PostView.hashtags` (Türkçe küçük harfli). `GET /api/hashtags/trending?size=10` (48 saat, saatlik önbellek), `GET /api/hashtags/suggest?q=`, `GET /api/hashtags/{tag}/posts?cursor&size` (`{tag}` aksanlı/aksansız olabilir).
- **Takip:** `POST/DELETE /api/users/{id}/follow` (`{following, followerCount}`), `GET /api/users/{id}/followers|following?cursor&size`, `GET /api/users/me/follow-suggestions?page=&size=` (`page` 0 tabanlı, `size` varsayılan 10 / en çok 50; gövde düz dizi, devam bilgisi `X-Has-More: true|false` başlığı; en çok 200 öneri, taşan sayfa boş dizi; ayrıntı `docs/changes/post.md`). Profil (`GET /api/users/{id}`) `followerCount`, `followingCount`, `followedByMe` ve `followsMe` (o kullanıcı beni takip ediyor mu) taşır; "karşılıklı" istemcide `followedByMe && followsMe` ile türetilir. Takipçi/takip edilen liste öğeleri `{id, displayName, avatarUrl, department, followedByMe, followsMe}` döner (sayfa başına tek sorgu; kendi satırında ikisi de `false`). Engelli ilişkide mevcut gizleme kuralları aynen sürer; eski sunucuda `followsMe` alanı yoktur (yoksa `false` sayın). `USER_FOLLOW` bildirimi (`targetType: USER`, `targetId` = takipçi); alt tür tercihi `USER_FOLLOW` (ve `POST_MENTION`) mevcut bildirim tercihleri ucundan (`subtypes`) kapatılabilir.
- **Akış:** `GET /api/feed?scope=latest|popular|following|department`. `department` ve profilde bölüm yoksa `items:[]` + `hint:"NO_DEPARTMENT"`. Bilinmeyen kapsam → 400 `FEED_SCOPE_INVALID`.
- **Hikâyeler (24 saat):** medya `POST /api/posts/media` ile yüklenir, `POST /api/stories {mediaId?, text?, caption?, background?}` ile bağlanır (video ≤30 sn → `STORY_VIDEO_TOO_LONG`). `GET /api/stories/tray` (kendim ilk, görülmemiş önce), `GET /api/users/{id}/stories`, `POST /api/stories/{id}/view` (204, idempotent), `GET /api/stories/{id}/viewers` (yalnız sahip), `DELETE /api/stories/{id}`. Süre dolunca 404/boş. Medya aynı `GET /api/posts/media/{id}` ucundan akar. Yanıt/tepki yoktur.
- Hata kodları (tr/en/ar): `MENTION_TOO_MANY`, `FOLLOW_SELF`, `FEED_SCOPE_INVALID`, `HASHTAG_INVALID`, `STORY_NOT_FOUND`, `STORY_FORBIDDEN`, `STORY_EMPTY`, `STORY_TOO_LONG`, `STORY_VIDEO_TOO_LONG`, `STORY_BACKGROUND_INVALID`.


## Anket ve oylama

Tam sözleşme (alanlar, hata kodları, hız sınırları): `docs/API_CONTRACTS_V2.md` → "Anket ve oylama". Mobil için özet:

- **Liste:** `GET /api/polls?scope=open|mine|closed|community:{id}&cursor=&size=` → `{ items: [PollView], nextCursor }` (sayısal imleç). Ana sayfada `open`, kulüp sayfasında `community:{id}`, profilde `mine`.
- **Ayrıntı:** `GET /api/polls/{id}`. `canVote` / `voteBlockedReason` (`NOT_ELIGIBLE|CLOSED|NOT_OPEN|ALREADY_VOTED`) ile düğmeyi/etiketi çizin; `resultsVisible=false` iken `results` null gelir (sonucu gizleyin, "Sonuçlar oylamadan sonra / kapanınca görünür" yazın). `state`: `SCHEDULED|OPEN|CLOSED|CANCELLED|DRAFT`.
- **Oy ver:** `POST /api/polls/{id}/vote` gövde `{ "optionIds": [..] }` (SINGLE 1 öğe, MULTI en çok `maxChoices`, RANKED sıralı: ilk = en çok tercih) veya `{ "rating": 1..5 }` (RATING). İdempotent; yanıt güncel PollView. `409 POLL_CLOSED|POLL_NOT_OPEN|POLL_ALREADY_VOTED`, `403 POLL_NOT_ELIGIBLE`, `400 POLL_INVALID_VOTE`.
- **Oyu geri çek:** `DELETE /api/polls/{id}/vote` (`allowChangeVote=false` ise 409 `POLL_ALREADY_VOTED`).
- **Bugünün menüsünü puanla:** `GET /api/polls/menu/today` → PollView (`scope=MENU`, `type=RATING`, `menuItems`, `average`); yemek listesi yoksa **204**.
- **Oluşturma/yönetme (kulüp yöneticisi):** `POST /api/polls` (`scope=COMMUNITY`, `communityId`; varsayılan gizli oy), `PATCH /api/polls/{id}`, `POST /api/polls/{id}/close`, `DELETE /api/polls/{id}`; `canManage=true` olan ankette düğmeleri gösterin. Genel (`GLOBAL`) ve `MENU` anketlerini yalnız yönetici oluşturur.
- **Gizli oy:** hiçbir yanıt kimin ne oy verdiğini döndürmez; yalnız `myVote` (kendi oyunuz).
- **Bildirim/yönlendirme:** push `data` içinde `target=POLL`, `targetType=POLL`, `targetId=<anket id>` (+ kulüp anketinde `communityId`); dokununca `GET /api/polls/{id}` açın.
- **Hata kodları:** `POLL_NOT_FOUND` 404, `POLL_FORBIDDEN` 403, `POLL_NOT_ELIGIBLE` 403, `POLL_CLOSED` 409, `POLL_NOT_OPEN` 409, `POLL_ALREADY_VOTED` 409, `POLL_LOCKED` 409, `POLL_MENU_EXISTS` 409, `POLL_MENU_NOT_FOUND` 404, `POLL_INVALID_VOTE` 400, `POLL_INVALID` 400, `POLL_SCOPE_INVALID` 400 (mesajlar istek dilinde: tr/en/ar).

## Etkinlik katılım türü ve istekler (herkes etkinlik açar)

Ayrıntı ve örnekler: [changes/event.md](changes/event.md) "Herkes etkinlik açar". Özet: `POST /api/events` herkese açık (`communityId` isteğe bağlı), gövdeye `joinPolicy` (`OPEN` varsayılan | `APPROVAL`); `EventView` yeni alanları `joinPolicy`, `organizer{id,displayName,avatarUrl}`, `pendingCount` (yalnız yöneten), `myRsvp` = `GOING|INTERESTED|PENDING|REJECTED|null`. `APPROVAL` etkinlikte `PUT /rsvp {status:GOING}` istek açar ve `myRsvp:"PENDING"` döner; geri çekme `DELETE /rsvp`. Sorulu etkinlikte 400 `ANSWERS_REQUIRED` → `POST /events/{id}/applications {note,answers}`. Organizatör: `GET /events/{id}/requests?status=PENDING`, `POST /events/{id}/requests/{userId}/approve|reject` (doluysa 409 `EVENT_FULL`). Sohbet (`GET /events/{id}/chat`) yalnız `GOING` katılımcı + organizatörlere açıktır.

## Keşfet puanlı akış (`scope=top`) (Keşfet v2'de tek akış oldu; aşağıdaki "Keşfet v2" geçerli)

`GET /api/feed?scope=top&size=12&cursor=...` → `{items, nextCursor, hint}`. `size` varsayılan 12, üst sınır 30. `nextCursor` opaktır, olduğu gibi geri gönderilir; `null` = son sayfa. `hint:"RANK_REFRESHED"` gelirse (puanlar yeniden hesaplandı) nadiren aynı gönderi tekrar gelebilir: istemci `id`'ye göre tekilleştirir. Puan dönmez. `latest`/`popular` aynen çalışır. Ayrıntı: [POSTS_DESIGN.md](POSTS_DESIGN.md) "Keşfet puanlama".

### 6.x Akıllı bildirim: sohbetteyken bastırma, yığılma önleme (V440 aralığı kullanılmadı; migration yok)

**Karar tablosu (yeni sohbet mesajı, alıcı başına):** gönderen kendisi, sessize alınmış (`muted`/`mutedForever`), arşivde (`archivedAt` dolu; her arşiv kalıcıdır), engel ilişkisi olan, askıdaki/silinmiş hesap -> bildirim YOK. **(P1 ile GÜNCELLENDİ, bkz. `docs/changes/push.md` "P1")** Alıcı o sohbeti görüntülüyor (`viewing:<uid>`, TTL 45 sn) VE canlı WS bağlantısı var -> hiçbir şey. Diğer tüm durumlarda (çevrimiçi, ön plan, arka plan, kapalı) push GİDER; ön plandaki istemci kendisi bastırır/tekilleştirir (`messageId`). Pencere (`message-window-seconds`) varsayılan 0; mesajlara ayrı dakikalık sınır `max-messages-per-minute` (60), diğer türler `max-per-minute` (10, SYSTEM hariç). Sohbet sonuna kadar okununca kutudaki `conv:<id>` satırı okunur. Redis erişilemezse hepsi "açık" (push gider).

**Uçlar (JWT, hız sınırlı):**
- `PUT /api/conversations/{id}/viewing` -> 204. Sohbet açıkken 30 sn'de bir. Üye değilse 404. Ön planı da ima eder.
- `DELETE /api/conversations/{id}/viewing` -> 204 (idempotent; yalnız kayıtlı sohbet aynıysa siler). Sohbetten çıkınca/arka plana geçince.
- `PUT /api/devices/{fcmToken}/state` gövde `{"foreground":true|false}` -> 204. Token kullanıcıya ait değilse 404. (`PUT /api/devices/state` de gövdeyle aynı işi görür.) `false` hem `fg` hem `viewing` anahtarını siler. Ön plandayken 45 sn'de bir yenilenmeli. Durum kullanıcı bazlıdır (çok cihazda herhangi biri ön plandaysa push bastırılır; "yalnız uygulama içi kutu" yolu).

**Push yükü (`data`) ek alanları:** `collapseKey` (örn. `conv:5`, `follow:7`, `postlike:3:<pencere>`), `threadId` (`conv:5`, `community-3`, `event-9`, `post-4`, yoksa tür adı), `channelId`, mevcut `type/subtype/targetType/targetId/count`. FCM: `collapse_key` + Android `tag` = collapseKey, APNs `thread-id` = threadId ve `apns-collapse-id` = collapseKey (<=64 bayt). (Not: `threadId` önceki `conv-<id>` yerine `conv:<id>` oldu.) Ek `conversationType` (`DIRECT|GROUP`) mesaj bildirim verisindedir; alt tür `MESSAGE_DIRECT`/`MESSAGE_GROUP` artık bunlardan atanır (alt tür tercihleri mesajlarda ilk kez gerçekten uygulanır).

**Android kanalları (istemci oluşturur):** `chat` YÜKSEK (mesaj; push önceliği yüksek), `event` YÜKSEK, `announcement` VARSAYILAN (haber, duyuru, kulüp, sistem/moderasyon, ticket yanıtı), `poll` VARSAYILAN (yükte `pollId` varsa), `social` DÜŞÜK (beğeni, yorum, yanıt, etiket, takip). Yüksek öncelikli push: MESSAGE, SYSTEM, EVENT_ADMISSION alt türü.

**Birleştirme ve tekrar:** beğeni: gönderi başına 10 dk'lık pencere, ilk beğeni push'lanır, devamı yalnız kutuda ("X ve N kişi"); takip: aynı kişi için ömür boyu tek bildirim (bırak-al spam yok); kulüp gönderisi: `commpost:<id>` anahtarıyla okunmamışlar tek satır, alt tür `COMMUNITY_POST` (artık tercihle kapatılabilir). Kutu görünümü (`GET /api/notifications`) yeni alan: `groupKey`; `count` zaten vardı.

**Sessiz saat ve tercihler:** ana bayrak + alt tür her `NotificationService.send*` yolunda uygulanır; sessiz saatte kutu yazılır, push gitmez. `SYSTEM` (hesap güvenliği, moderasyon, destek yanıtı) sessiz saati ve ana bayrakları AŞAR ve askıdaki hesaba da gider; diğer türler askıdaki/silinmiş hesaba gitmez (`RecipientGuard`). Toplu yollar (`broadcast`, `sendBulk`, kampanya) sessiz saati SQL'de uygular. Önizleme kararı (V1252): push gövdesi HER ZAMAN mesaj metninin ilk 100 karakteridir (yalnız görsel mesajda simge; birleşen mesajlarda "N yeni mesaj"), başlık gönderen (grupta "Grup - Gönderen") adıdır; kutu tablosuna metin ASLA yazılmaz. Tercih (`messagePreview`) ve `app.push.message-preview*` ayarları kaldırıldı. Android `chat` kanalı bildirimi kilit ekranında `PUBLIC` görünürlükle gider. Tek gösterimlik (view-once) medyada açıklama push'a, yanıt alıntısına ve sohbet listesi son mesajına GİRMEZ: push gövdesi `📷`/`🎬`, `replyTo.text` `"📷 Fotoğraf"`/`"🎬 Video"` + `replyTo.viewOnce:true`, `lastMessage.text` boş (bkz. `docs/changes/messaging.md`).

**FCM doğrulama (yönetici):** `GET /api/admin/push/fcm/status` (ağ çağrısı yok: `enabled`, `projectId`), `POST /api/admin/push/fcm/validate` (Firebase `validateOnly` konu mesajı; hiçbir cihaza gitmez; `validated`, `error` yalnız kod; dakikada 5). Açılışta etkinse log: `FCM etkin: Firebase proje kimligi=<id>`; sağlık `fcm` detayında `projectId`. Anahtar hiçbir yerde yazılmaz.

## Tasarım uygulaması için eklenen opsiyonel alanlar (B1)

Hepsi **geriye uyumlu eklemedir** (alan silme/yeniden adlandırma yok; migration yok). Eski mobil sürümler yeni alanları yok sayar; yeni mobil, alan yoksa ilgili parçayı çizmez. Ayrıntı: `changes/*.md`.

- **Anket listesi:** `GET /api/polls?scope=open|closed|mine|community:{id}` yanıtı `{items,nextCursor,totalCount,openCount}`. `totalCount` = istenen kapsamdaki toplam kayıt (sayfadan bağımsız; "N anket arşivde"), `openCount` = istek sahibine görünen açık anket sayısı (sekme rozeti). Sayımlar üyelik ve hedef kitleyi (fakülte/bölüm/sınıf) SQL'de uygular; liste ise ek olarak yönetici/oluşturan istisnasıyla (kendi hedef kitlesi dışındaki ankete yönetim görünümü) bazı ögeleri gösterebilir, bu yüzden **sayaçlar listede görünen sayıdan küçük olabilir** (aralarındaki fark yalnız yönetilen anketlerdir).
- **Sohbet listesi/detayı (`ConversationView`):** `lastMessage.senderName` yalnız grup/kulüp/etkinlik sohbetinde ve gönderen engelli değilse dolar ("Ahmet: Toplantı…"); birebirde alan hiç gelmez. `peer.online` yalnız birebir sohbetin karşı tarafında gelir (`true|false`; engel ilişkisi varsa alan yok). Diğer yerlerdeki `UserSummary`/`MessageView`'da bu alanlar gönderilmez. Çevrimiçi bilgisi liste başına tek toplu Redis okumasıyla alınır (Redis yoksa `false`).
- **Kulüp üyeleri ve başvurular:** `GET /api/communities/{id}/members`, `.../requests`, `GET /api/communities/{id}/members/search` satırlarına `department` (string) ve `classYear` (1..6, sayı). Profil gizlilik ayarına uyulur (`DEPARTMENT`/`CLASS_YEAR` bakana kapalıysa alan `null`; engel ilişkisinde `null`). `requests` satırlarına `requestedAt` (başvuru zamanı, ISO; `joinedAt` ile aynı değer).
- **Kulüp gönderileri:** `GET /api/communities/{id}/posts` ögelerine (OpenAPI şeması `CommunityDtosPostView`) `authorRole` (`OWNER|ADMIN|MODERATOR|MEMBER`; yazar artık aktif üye değilse alan yok). `likeCount`/`liked` **eklenmedi**: kulüp gönderilerinde beğeni modeli yok (sahte 0 göndermemek için). Beğeni özelliği gelirse eklenecek.
- **Kulüplerim:** `GET /api/me/communities` satırlarında `requestedAt` yalnız inceleme bekleyen (`status=PENDING_REVIEW`) kulüpte dolar (= kulüp başvuru/oluşturma zamanı); aksi halde alan yok. Not: bekleyen **üyelik** başvuruları bu listede yer almaz (liste yalnız aktif üyelikleri ve incelemedeki kendi kulüplerinizi verir).
- **Etkinlik yoklama kodu:** `GET /api/events/{id}/checkin-code` yanıtı `{code,qrPayload,expiresAt,validForSeconds,manualCode}`. `manualCode` 6 karakterli (`ABCDEFGHJKLMNPQRSTUVWXYZ23456789` alfabesi; 0/O/1/I yok) kısa ömürlü koddur; QR ile **aynı pencerede** (30-60 sn) geçerlidir, tahmin edilemez (HMAC). Katılımcı bunu `POST /api/events/{id}/check-in {"code":"K7M4QX"}` ile gönderir (küçük harf, boşluk ve tire tolere edilir; eski uzun jeton aynen çalışır). Elle kod denemeleri kullanıcı+etkinlik başına dakikada 8 ile sınırlıdır (429), hatalı kod `400 INVALID_CODE`.
- **Etkinlik katılım istekleri:** `GET /api/events/{id}/requests` ve `/applications` satırlarında `email` **yalnız başvuran profilinde "e-postamı göster" (`showEmail`) dediyse** ve istek sahibi etkinliği yönetebiliyorsa dolar (aksi halde `null`; engel ilişkisinde de `null`); `department` ve `classYear` başvuranın profil gizlilik ayarına uyar (bakana kapalıysa `null`). Mobil üçünü de opsiyonel okumalıdır; `createdAt` zaten vardı.
- **Etkinlik JSON'u (`EventView`):** `communityLogoUrl` (kulüp etkinliğinde kulübün logosu; yoksa `null`). `endsAt` ve `communityName` zaten vardı.
- **Push `data`:** sohbet bildirimlerine `senderAvatarUrl` (gönderenin avatarı; profil gizliliği alıcıya izin veriyorsa ve engel yoksa; aksi halde anahtar yok). Yalnız **push yükünde** gelir; `GET /api/notifications` listesindeki `data` JSON'unda bulunmaz (avatar sonradan gizlenirse eski kayıtta URL kalmaması için). Mobil yoksa ad baş harfli avatar gösterir.
- **Arama:** `GET /api/search` `SearchHit` ögelerine opsiyonel: COMMUNITY için `memberCount`, `category`, `myStatus` (`ACTIVE|PENDING|NONE`; yasaklı `NONE` görünür); POSTS için `likeCount`. Diğer türlerde alanlar JSON'da yoktur.
- **Yemek:** ek istek yok; büyük harf adları sunucu kaynaktan olduğu gibi saklar (değiştirilmez), başlık biçimi istemcide uygulanır.

### B1 (devam): takip, sohbet bilgisi, etkinlik kartı, profil, engeller

- **Takip listeleri:** `GET /api/users/{id}/followers|following` ögelerinde `followsMe` zaten vardı; yeni `classYear` (profil gizlilik ayarına uyar). `GET /api/users/me/follow-suggestions`: `reason` zaten vardı ama **kod**dur (`CLUB` | `GRADE` | `DEPARTMENT`; metni istemci kendi diline çevirir), yeni `classYear`.
- **Engeller:** `GET /api/users/me/blocks` gövdesi düz dizi kalır; toplam engel sayısı **`X-Total-Count`** yanıt başlığında (CORS ile açıktır).
- **Arama etkinlik satırı:** `SearchHit` EVENT için `startsAt` ve `endsAt` (ISO anı; `date` yalnız gün). Alanlar yoksa gönderilmez.
- **Sohbet bilgisi:** `ConversationView.peer` (birebir) ve `GET /api/conversations/{id}` üye satırları `department`, `classYear` taşır (profil gizlilik ayarı bakana izin veriyorsa; engel ilişkisinde yok).
- **Üye ekle / kullanıcı arama:** `GET /api/users/search` ögelerinde `email` **zaten vardı** ama yalnız sahibi profilinde "e-postayı göster" dediyse dolar (`showEmail`); aksi halde `null`. Gizliliği aşan e-posta eklenmedi (KVKK).
- **Etkinlik kartları:** `GET /api/me/events` (EventView) için bekleyen istek sayısı **`pendingCount`** adıyla zaten vardı (yalnız etkinliği yönetene; diğerlerinde `null`). `GET /api/events/calendar` USER ögelerine de `pendingCount` eklendi (yalnız yönetene, yoksa alan yok). `EventView.cancelReason` (yalnız yönetene; yönetici iptali/gizlemesi gerekçesi) ve `EventView.rejectReason` (yalnız yönetene; inceleme red nedeni); alanlar yoksa gönderilmez. Düzenleyenin kendi iptalinde gerekçe alanı saklanmadığından `cancelReason` gelmez.
- **Profil:** `GET /api/users/me` yanıtına `avatarHidden` (`true` = profil fotoğrafı moderasyonla gizlendi).
- **Etkinlik sohbet erişimi:** `GET /api/events/{id}` (yalnız detay) yanıtında `chatAccess`: `LOCKED` (etkinlik yayında değil, sohbet süresi bitti, oda kapalı ya da kurulmamış ve yönetici değilsiniz), `OPEN` (odaya girebilirsiniz: katılımcı, düzenleyen, kulüp yetkilisi), `MEMBERS` (etkinliğe katılınca açılır). Liste uçlarında alan yok.
- **Bildirim tercihleri (V880):** `GET|PUT /api/notifications/preferences` yanıt/istek gövdesine iki boolean: `polls` ("Anketler") ve `academicAnnouncements` ("Akademik duyurular"); varsayılan `true`, `PUT`ta verilmeyen (null) alan değişmez (eski istemciler etkilenmez). Gönderim koşulu **ana tür bayrağı VE kendi bayrağı**dır: genel anket `announcements` + `polls`, kulüp anketi `communities` + `polls`, sınav hatırlatması `announcements` + `academicAnnouncements` ister (bölüm duyurusu özelliği V1251 ile kaldırıldı) (yani ana bayrak kapalıyken kendi bayrağı açık olsa da bildirim gitmez; arayüzde bu satırlar ana bayrak kapalıyken pasif gösterilmelidir). Varsayılan `true` olduğundan mevcut kullanıcıların davranışı değişmez. `subtypes` haritasında da `POLL` ve `EXAM_REMINDER` anahtarları görünür (`ACADEMIC_ANNOUNCEMENT` alt türü kaldırıldı) ve aynı bayrağı yansıtır (alt tur anahtarıyla yazmak da aynı sütunu günceller).
- **Profil `blockedByMe`:** `GET /api/users/{id}` yanıtında (yalnız başkasının profilinde) `blockedByMe: true|false` = istek sahibi bu kullanıcıyı engellemiş mi. Karşı tarafın beni engellemesi sızdırılmaz (o durumda da `false`, profil gölge engel kuralıyla boş gelir). Kendi profilimde alan yoktur. Çok sayıda engel olsa da doğrudur (`/users/me/blocks` sayfalamasına bağlı değil).


## Gizli hesap ve takip isteği (FOLLOWREQ)

**Kural (Instagram gibi):** takip isteği YALNIZ gizli hesaplar içindir. Herkese açık hesap istek almaz, doğrudan takip edilir. Varsayılan herkese açıktır; mevcut tüm hesaplar açık kalır.

**Hesap türü:** `GET /api/users/me/privacy` yanıtına `privateAccount` (boolean) eklendi. Değiştirmek için `PUT` (ya da `PATCH`, ikisi aynı işi yapar) `/api/users/me/privacy` gövdesi `{"privateAccount": true}`; verilmeyen alanlar değişmez. Hız sınırı: saatte en çok 10 GERÇEK değişiklik + dakikada 3 (aynı değeri tekrar göndermek hak harcamaz); aşılınca 429 + `Retry-After`.

**Takip uçları (yollar değişmedi):** `POST /api/users/{id}/follow` ve `DELETE /api/users/{id}/follow` yanıtı `{following, followerCount, followState}` olur; `followState`: `FOLLOWING | REQUESTED | NONE`.
- Hedef herkese açık: anında `FOLLOWING` (`following=true`).
- Hedef gizli ve takipçi değilsen: istek oluşur, `followState=REQUESTED`, `following=false`, `followerCount=0` (gizli hesapta sayaç sızdırılmaz). Tekrar çağrı idempotenttir (`REQUESTED`; ikinci satır ve ek hız hakkı yok).
- `DELETE`: takipçiysen takibi bırakır, bekleyen isteğin varsa geri çeker; her iki durumda da `followState=NONE`. Gizli hesaptan çıkan kişi tekrar takip için yeniden istek göndermelidir.
- Kendini takip: 400 `FOLLOW_SELF`. Engel ilişkisi: beni engelleyen için gölge engel (200, istek oluşmaz), benim engellediğim için 404 `USER_NOT_FOUND` (mevcut davranış).
- Sınırlar: kullanıcı başına en çok 200 bekleyen giden istek (aşılırsa 422 `FOLLOW_REQUEST_LIMIT`); aynı hedefe 24 saatte en çok 3 yeni istek (red sonrası kötüye kullanım freni; aşılırsa 429).

**Kullanıcı profili / listeler:** `GET /api/users/{id}` (ve kullanıcı arama `GET /api/users/search` satırları, takipçi/takip listesi satırları, takip önerileri) şu alanları taşır: `isPrivate` (boolean), `followState` (`NONE | REQUESTED | FOLLOWING | SELF`), `locked` (boolean: hesap gizli ve sen ne sahibi ne KABUL EDİLMİŞ takipçisisin; bekleyen istek kilidi açmaz). Alanlar yalnız ilgili uçlarda dolar, diğer DTO'larda hiç yazılmaz (JSON'da yok).
- `locked=true` iken `GET /api/users/{id}`: profil kabuğu (ad, avatar, bölüm vb. kendi gizlilik ayarlarına göre) görünür, `followerCount`/`followingCount` **null**'dır (gizlenir). Mobil kilit göstermeli, gönderi ızgarasını ve listeleri çizmemeli.
- `GET /api/users/{id}/followers`, `/following`: `locked=true` iken `{items:[], nextCursor:null, locked:true}` (403 değil). Görünürse `locked:false`.
- `GET /api/users/{id}/posts`: aynı şekilde `{items:[], nextCursor:null, locked:true}`; görünürse `locked:false`.
- Gizli hesap sahibinin GÖNDERİLERİ Keşfet (`top|latest|popular|following|department`), arama (`type=POSTS`), beğeni/beğenenler, rapor ve fotoğraf (`/api/posts/media/{id}`) uçlarında yalnız sahibine ve kabul edilmiş takipçilerine görünür. `GET /api/posts/{id}` takipçi olmayana 404 `POST_NOT_FOUND` verir (var olduğu sızdırılmaz). Kullanıcının kendisi arama ve önerilerde bulunur (kabuk).

**Gelen istekler (hedef = gizli hesap sahibi):**
- `GET /api/users/me/follow-requests?cursor=&size=30` -> `{items:[{userId, displayName, avatarUrl, department, requestedAt}], nextCursor}` (en yeni önce; `nextCursor` sayısal istek kimliği, sonraki istekte `cursor=`). Engelli ve pasif hesaplar listelenmez.
- `GET /api/users/me/follow-requests/count` -> `{count}` (rozet için).
- `POST /api/users/me/follow-requests/{userId}/accept`: gerçek takip oluşur, istek silinir, istek sahibine `FOLLOW_ACCEPTED` bildirimi. Idempotent. **Yanıt 200 `{count}`** (kalan bekleyen istek sayısı; 204 değil).
- `POST /api/users/me/follow-requests/{userId}/decline`: istek sessizce silinir (bildirim YOK). Idempotent, yanıt 200 `{count}`.
- Gizli -> herkese açık geçişte bekleyen TÜM istekler otomatik kabul edilir (parçalı; çok büyük birikim birkaç dakika içinde arka plan işiyle tamamlanır; toplu bildirim gönderilmez). Herkese açık -> gizli geçişte mevcut takipçiler kalır.
- Bekleyen istekler 90 gün sonra silinir. Hesap silme/askıda istekler temizlenir.

**Bildirimler** (alıcının dilinde, push dahil):

| Tür (`type`/`subtype`) | Alıcı | Metin (tr) | Push `targetType` / `targetId` | `collapseKey` |
|---|---|---|---|---|
| `FOLLOW_REQUEST` | hedef (gizli hesap) | "<ad> seni takip etmek istiyor" | `FOLLOW_REQUESTS` / istek sahibinin id'si | `followreq:<istekSahibiId>` |
| `FOLLOW_ACCEPTED` | istek sahibi | "<ad> takip isteğini kabul etti" | `USER` / kabul edenin id'si | `followacc:<kabulEdenId>` |

Gizli hesapta "yeni takipçi" (`USER_FOLLOW`) bildirimi gitmez (istek anında `FOLLOW_REQUEST` gider; kabulde karşı tarafa `FOLLOW_ACCEPTED`). Her ikisi de `communities` bildirim bayrağına bağlıdır.

**Mesaj isteği ile ilişki:** ilk DM'de "alıcı göndereni takip ediyor" bağlamı yalnız KABUL EDİLMİŞ takibe dayanır; bekleyen istek bağlam sayılmaz.

Hata kodu (3 dilde çeviri var): 422 `FOLLOW_REQUEST_LIMIT`. Ayrıntı: `docs/changes/post.md` ve `docs/changes/profile.md` (FOLLOWREQ).

## Keşfet v2 (KS-BE, 2026-11-04): tek sıralama, puanlama, video, Reels, tekrar göstermeme
**Bu bölüm yukarıdaki "SADE KEŞFET" kutusu, `GET /api/feed?scope=latest|popular` satırı ve "Keşfet puanlı akış" bölümüyle çelişirse GEÇERLİDİR.** Ayrıntılı gerekçe, formüller ve
şema: `docs/changes/post.md` "KS-BE (V1220)". Tüm uçlar Bearer ister.

| Uç | Gövde / yanıt |
|---|---|
| `POST /api/posts/media` (multipart `file`, video için `poster` isteğe bağlı) | 201 `{id, kind:"IMAGE"\|"VIDEO", url, thumbUrl, width, height, durationMs, bytes}`. Video: MP4/MOV/M4V/WebM, **≤ 60 sn, ≤ 50 MB**; hatalar `400 VIDEO_INVALID`, `400 VIDEO_TOO_LONG`, `413 VIDEO_TOO_LARGE`, `422 MEDIA_BLOCKED`, `429 POST_MEDIA_PENDING_LIMIT`. Saatte 30 yükleme. |
| `POST /api/posts` `{text?, mediaIds:[id]}` | 201 `PostView`. Tam 1 medya (foto **veya** video); `400 POST_PHOTO_REQUIRED` (boş), `400 POST_SINGLE_PHOTO_ONLY` (2+), `400 POST_MEDIA_INVALID`; metin gizli üst sınır 2200 karakter/40 satır, `mentionUserIds` ≤ 10. Saatte 20. |
| `GET /api/feed?scope=foryou\|popular\|latest\|following&cursor=&size=` | `{items:[PostView], nextCursor, hint, exhausted}`. **Filtre eşlemesi:** Senin İçin = `foryou` (varsayılan, kişiselleştirilmiş), Popüler = `popular` (eski `top` aynı), En Yeni = `latest`, Takip Ettiklerim = `following`; `size` varsayılan 12 (üst sınır 30). `exhausted` yalnız `foryou`/`popular`. |
| `GET /api/feed/reels?cursor=&size=&replay=` | Yalnız video; **öneri algoritması** (kural tabanlı puan, oturumda tekrar yok, izlenmemişler öncelikli); `size` varsayılan 8, üst sınır 20. Aday kalmayınca `items:[]`/son sayfa + **`exhausted:true`**; **`replay=true`** = "Tekrar izle" (imleçsiz ilk çağrı). |
| `POST /api/posts/{id}/not-interested` / `DELETE` | 204 / 204. "İlgilenmiyorum" (Reels + Senin İçin önerilerinden kalkar, 45 gün); DELETE geri alır. |
| `POST /api/feed/seen` `{ids:[…≤100]}` | 204. Ekranda **gerçekten görünen** gönderi/reel kimlikleri (dakikada 60); video kimlikleri Reels izleme geçmişine **gösterim** olarak yazılır (Reels sayfa dönüşü gösterim yazmaz). |
| `POST /api/posts/{id}/view` `{watchedMs, durationMs}` | 204. Video izlenme olayı (dakikada 240): gönderi sayacı + kullanıcı izleme geçmişi (süre, tamamlanma, hızlı geçme: < 1,5 sn ya da < %15); bkz. aşağıdaki kurallar. |
| `GET /api/posts/media/{id}` / `?thumb=true` | Fotoğraf; video (**Range 206/416**) ve poster. Bearer başlığı gerekir (video oynatıcıya `httpHeaders` verin). |
| `GET /api/users/me`, `GET /api/users/{id}` | Yeni alanlar: `popularityScore` (0..100), `likesReceived`, `postCount`, (`ProfileView`'da ayrıca `followerCount`). |
| `GET /api/admin/posts?type=PHOTO\|VIDEO` | Satırda `type`, `viewCount`, `avgCompletionPct`. |

`PostView` yeni alanlar (eskiler aynen): `type:"PHOTO"|"VIDEO"`, `video:{id,url,posterUrl,durationMs,width,height}` (yalnız VIDEO), `viewCount` (yalnız VIDEO),
`popularityScore` (gönderi, 0..100), `author.followerCount`, `author.popularityScore` (kullanıcı, 0..100). `media[0]` aynı medyadır. Örnek:
```json
{"id":91,"author":{"id":7,"displayName":"Ayşe Y.","avatarUrl":null,"department":"Bilgisayar Müh.","followerCount":42,"popularityScore":63},
 "text":"kampüste akşam","media":[{"id":12,"kind":"VIDEO","url":"/api/posts/media/12","thumbUrl":"/api/posts/media/12?thumb=true","width":720,"height":1280,"durationMs":18400}],
 "likeCount":5,"likedByMe":false,"mine":false,"canEdit":false,"canDelete":false,"createdAt":"2026-11-04T10:00:00Z","editedAt":null,
 "type":"VIDEO","video":{"id":12,"url":"/api/posts/media/12","posterUrl":"/api/posts/media/12?thumb=true","durationMs":18400,"width":720,"height":1280},"viewCount":130,"popularityScore":71}
```
- **Puanlar gerçek sayılardır** (beğeni, takipçi, izlenme, tamamlanma, gönderi sayısı); uydurma rozet/ödül yok. İstemci puan HESAPLAMAZ, `popularityScore`'u çubuk/rozet olarak çizer
  (0 = boş). Kullanıcı puanı en çok ~1 saat gecikmelidir; gizli (kilitli) hesapta ve engel gölge profilinde alanlar gelmez (null/yok: çizme).
- **Tekrar göstermeme (Keşfet `foryou`/`popular`):** sunucu döndürdüğü her sayfayı **kendisi görülmüş sayar** (Redis, 48 sa, ≤ 2000); `cursor`'suz çağrı (yenileme) görülmüşleri hariç tutar. **Reels** ise kendi 45 günlük izleme geçmişini kullanır (aşağıda).
  İstemci ek olarak ekranda ≥ ~1 sn görünen kartları `POST /api/feed/seen` ile toplu (örn. sayfa değişiminde/duraklamada, ≤ 100) bildirmelidir. Hepsi görüldüyse sunucu en eski
  görülmüşlerden tekrar eder ve **`exhausted:true`** döner (boş liste yok): istemci isterse "hepsini gördün" ipucu gösterir. Tekrar sayfaları da `nextCursor` ile gezilir.
  `nextCursor` opaktır; yenilemede imleci atın.
- **İzlenme olayı:** video kartı/Reels'ten çıkarken ya da bitince **bir kez** `POST /api/posts/{id}/view {watchedMs, durationMs}`. Sunucu aynı kullanıcı+gönderiyi 6 saatte bir sayar, kendi videosunu,
  fotoğrafı ve < 1 sn'yi saymaz; yanıt hep 204 (sayıldı mı bildirilmez). Döngüde `watchedMs` toplamı süreyi aşabilir (kenetlenir).
- **Reels akışı (mobil sözleşmesi):** ilk çağrı imleçsiz (`GET /api/feed/reels?size=8`), sonra `nextCursor`; ekranda ≥ ~1 sn görünen video için `POST /api/feed/seen`, videodan çıkınca/bitince **bir kez** `POST /api/posts/{id}/view`. `exhausted:true` gelince "Şimdilik tüm videoları gördün" bilgi alanı + **Tekrar izle** (`GET /api/feed/reels?replay=true`) + alternatif (Keşfet gönderileri / takip önerileri); pull-to-refresh imleçsiz çağrıdır (yeni oturum, kontrollü yeniden sıralama, yeni videolar katılır). Üç nokta menüsünde "İlgilenmiyorum" → `POST /api/posts/{id}/not-interested`. Ağırlıklar: `docs/changes/post.md` bölüm 6.
- **Eski sürüm riski:** ≤ 2.0.6 istemciler video gönderiyi görsel gibi yükleyemez; yeni istemci `type`'a bakmalıdır. Bilinmeyen `type` değeri gelirse kartı yoksayın.
## Keşfet: yorumlar, yanıtlar, kaydetme, kullanıcı arama, Reels arama, profil sayaçları (KS-BE2, V1230)

Tam sözleşme (alanlar, hata kodları, birleşme notları): [changes/post.md](changes/post.md) "KS-BE2 (V1230)". Bu bölüm, "SADE KEŞFET" kutusundaki **"yorumlar kaldırıldı / 410"** ve "kaydet kaldırıldı" satırlarını geçersiz kılar (etiket, bahsetme, hikâye kaldırılmış kalır). Tüm uçlar Bearer ister.

| Uç | Açıklama |
|---|---|
| `GET /api/posts/{id}/comments?sort=top\|new&cursor=&size=` | Ust düzey yorumlar → `{items:[CommentView], nextCursor, total}`; `total` = gönderideki yorum + yanıt sayısı. `sort` varsayılan `top` (beğeni, sonra yeni); `size` 20 (en çok 50). |
| `POST /api/posts/{id}/comments` `{text, parentId?}` | 201 `CommentView`. Metin 1-300 karakter; `parentId` = yanıtlanan yorum (yanıta yanıt ust yoruma yassılanır, `replyTo` ile asıl muhatap döner). |
| `GET /api/post-comments/{cid}/replies?cursor=&size=` | Yanıtlar eskiden yeniye (`size` 10, en çok 50). |
| `GET /api/post-comments/{cid}` · `DELETE /api/post-comments/{cid}` | Tek yorum · sil (204; yorum yazarı, gönderi sahibi ya da yetkili yönetici). |
| `PUT\|DELETE /api/post-comments/{cid}/like` | `{liked, likeCount}`; idempotent. |
| `PUT\|DELETE /api/posts/{id}/save` · `GET /api/posts/saved?cursor=&size=` | `{saved, saveCount}` · kaydedilenler (`FeedPage`, yeni kaydedilen önce; görünmez olanlar sessizce elenir). |
| `GET /api/users/search?q=&size=&cursor=` | **Aynı yol/biçim**; artık Türkçe harf + büyük/küçük harf duyarsız, kısmi eşleşme, satırlarda `followedByMe`/`followsMe`/`followerCount`/`followingCount`. Kullanıcı adı (@) yoktur; yalnız görünen ad aranır. |
| `GET /api/search?q=&type=REELS` | Video gönderiler (açıklama aranır); `SearchHit.durationMs` + `likeCount`, `targetId` = gönderi id. `type` verilmezse gruplu özette `REELS` grubu da gelir. |
| `GET /api/users/{id}/reels?cursor=&size=` | Kullanıcının Reels'leri (`FeedPage`, yeni önce; gizli hesapta `locked:true`). |

- `PostView` yeni alanlar: `commentCount` (görünür yorum + yanıt), `savedByMe`. Profil yanıtlarında (`GET /api/users/me`, `GET /api/users/{id}`) `postCount` (görünür gönderi; Reels dahil) ve `reelCount` — gizli/kilitli hesapta başkasına gelmez, engel gölge profilinde 0.
- `CommentView`: `{id, postId, parentId, author{id,displayName,avatarUrl,department}, text, likeCount, likedByMe, replyCount, createdAt, mine, byPostAuthor, canDelete, replyTo?{commentId,authorId,displayName}}`.
- Şikâyet: `POST /api/reports` `{targetType:"COMMENT", targetId, reason}`. Bildirim: `POST_COMMENT` / `COMMENT_REPLY` (push `data.target=POST`, `postId`, `commentId`).
- Hata kodları (tr/en/ar): `COMMENT_NOT_FOUND` 404, `COMMENT_EMPTY` 400, `COMMENT_TOO_LONG` 422, `COMMENT_FORBIDDEN` 403; küfür `422 CONTENT_PROFANITY` (`field:"text"`).
- Hız sınırları: yorum yazma dakikada 20 / saatte 200, kaydet/beğeni dakikada 120, okuma dakikada 240.

## İçerik paylaşımı (SH-BE, 2026-11-05)
Gönderi / Reels / haber-duyuru / etkinlik: mesajla paylaşım (`POST /api/conversations/{cid}/messages` gövdesinde `share:{type,id}`, yanıtta `MessageView.share` kartı, hata `422 SHARE_TARGET_INVALID`), herkese açık bağlantı `https://bukampus.com.tr/s/{p|r|n|e}/{id}` (OpenGraph önizleme sayfası; uygulama yoksa mağaza) ve uygulamada açma (`bukampus://s/{t}/{id}` + evrensel bağlantı). Tam sözleşme ve JSON örnekleri: [SHARING.md](SHARING.md).
