# Google / Apple ile giriş: dış yapılandırma kontrol listesi

Kod hazır ve **varsayılan KAPALI** (`AUTH_OAUTH_ENABLED=false`: tüm OAuth uçları `404 OAUTH_DISABLED`). Özelliği açmak için bu belgedeki **sizin yapmanız gereken** dış adımlar gerekir. Sunucu davranışı: [changes/auth.md](changes/auth.md) "Google / Apple ile giriş + profil tamamlama", mobil sözleşme: [MOBILE_API_GUIDE.md](MOBILE_API_GUIDE.md) bölüm 1.10.

## 0. Özet: hangi kimlik hangi değişkene yazılır

| Değişken | İçerik | Nereden |
|---|---|---|
| `GOOGLE_CLIENT_IDS` | Virgüllü: **Web** + **Android** + **iOS** OAuth istemci kimlikleri (`....apps.googleusercontent.com`) | Google Cloud Console > APIs & Services > Credentials |
| `APPLE_CLIENT_IDS` | Virgüllü: uygulama bundle id **`tr.com.bukampus.app`** + (web/Android Apple girişi kullanılacaksa) **Services ID** | Apple Developer > Identifiers |
| `AUTH_OAUTH_ENABLED` | `true` (hazır olunca) | .env / .env.prod |

Sunucu bu listeleri ID token'ın **`aud` beyaz listesi** olarak kullanır; listede olmayan istemci için üretilmiş token reddedilir (`400 OAUTH_TOKEN_INVALID`). Bayrak açıkken ikisi de boşsa uygulama **açılmaz** (`ProdSettingsValidator`); yalnız biri doluysa diğer sağlayıcı tüm token'ları reddeder ve açılışta uyarı verilir. Sunucuya **istemci sırrı (client secret) GİRİLMEZ**: sunucu yalnız imza (JWKS) + `aud`/`iss`/`exp` doğrular.

## 1. Google (Google Cloud Console)

1. https://console.cloud.google.com > bir proje seçin/oluşturun (ör. "BU Kampüs").
2. **OAuth consent screen** (Google Auth Platform > Branding): uygulama adı, destek e-postası, gizlilik politikası bağlantısı (`https://<alan-adı>/privacy` benzeri herkese açık sayfa), yetkili alan adı. Kapsamlar yalnız `openid`, `email`, `profile` (hassas kapsam YOK). Yayın durumu **Production** olmalı; "Testing"de yalnız eklenen test kullanıcıları girebilir.
3. **Credentials > Create credentials > OAuth client ID**, üç istemci:
   - **Web application**: sunucu/Flutter `serverClientId` olarak kullanılır. Bu kimlik, mobil istemcinin Google'dan **ID token** alması için gereklidir (`google_sign_in` paketinde `serverClientId` = bu Web istemci kimliği; ID token'ın `aud` değeri bu olur). Authorized redirect URI gerekmez (yalnız web üzerinden giriş eklenirse eklenir).
   - **Android**: paket adı `tr.com.bukampus.app` (Android `applicationId`; farklıysa onu yazın) + **SHA-1** parmak izi. **Hem debug hem release/Play App Signing** sertifikalarının SHA-1 (ve SHA-256) değerlerini ekleyin: `keytool -list -v -keystore <anahtar-deposu>` ve Play Console > Release > Setup > App signing (Google'ın yeniden imzaladığı sertifika için **App signing key certificate** SHA-1). Her imza için ayrı bir Android istemcisi oluşturmak gerekebilir.
   - **iOS**: bundle id `tr.com.bukampus.app`. Verilen **iOS client ID** ve **REVERSED_CLIENT_ID** değerini iOS `Info.plist` içine (`CFBundleURLSchemes`) ve `GIDClientID` anahtarına yazarsınız (mobil tarafın işi; sunucuya yalnız iOS client ID eklenir).
4. Üç kimliği `GOOGLE_CLIENT_IDS` içine **virgülle** yazın. ID token'ın `aud` talebi, tokeni alan istemciye göre bu üçünden biri olabilir (Android'de çoğunlukla Web `serverClientId`); üçünü de eklemek güvenlidir.
5. Doğrulama: `curl -s https://www.googleapis.com/oauth2/v3/certs` JWKS döner (sunucu bunu otomatik önbelleğe alır; sizin bir şey yapmanız gerekmez).

## 2. Apple (Apple Developer, ücretli hesap)

1. https://developer.apple.com/account > Certificates, Identifiers & Profiles > **Identifiers** > App ID **`tr.com.bukampus.app`** > **Capabilities** > **Sign in with Apple** işaretleyin (Enable as a primary App ID) > Save. Xcode tarafında (mobil) aynı capability eklenir (`Runner.entitlements`: `com.apple.developer.applesignin`).
2. **Yalnız iOS uygulamasından giriş için başka bir şey gerekmez**: iOS'ta Apple token'ının `aud` değeri uygulamanın **bundle id**'sidir (`tr.com.bukampus.app`); `APPLE_CLIENT_IDS=tr.com.bukampus.app` yeterlidir.
3. **Android/web üzerinden Apple girişi isterseniz** (şu an planlanmadı): Identifiers > **Services IDs** > yeni bir Services ID (ör. `tr.com.bukampus.app.signin`) oluşturun > Sign in with Apple > Configure: Primary App ID = yukarıdaki, Domains ve **Return URLs** (HTTPS) ekleyin. Bu Services ID'yi `APPLE_CLIENT_IDS` listesine **virgülle** ekleyin (web akışında token `aud` değeri Services ID'dir).
4. **Key (.p8)** ve **Team ID/Key ID**: **bu sürüm için GEREKMEZ.** Yalnızca Apple'ın **token iptali (`/auth/revoke`)** ve yetkilendirme kodu (authorization code) takası için istemci sırrı (JWT ile imzalanmış `client_secret`) gerekir; bu sürüm bunları **uygulamıyor** (bkz. changes/auth.md "Apple token revoke: yapılandırma bekliyor"). Yine de ileride kullanılmak üzere hazırlamak isterseniz: Keys > "+" > Sign in with Apple > Configure (Primary App ID) > Continue > Register > **`AuthKey_XXXX.p8` dosyasını bir kez indirin** (yeniden indirilemez) ve **Key ID** ile **Team ID**'yi güvenli saklayın. Sunucuya **şimdilik girilmez**.
5. Gizli e-posta (Private Email Relay): kullanıcı "E-postamı gizle" derse `...@privaterelay.appleid.com` adresi gelir. Bu adrese posta **gönderilebilmesi** için Apple'a kayıtlı gönderici alan adı/e-posta gerekir: Apple Developer > Certificates, Identifiers & Profiles > **More** > **Configure** (Sign in with Apple for Email Communication) > domain + SPF/DKIM doğrulaması + gönderici adresi (`MAIL_FROM` ile aynı olmalı). **Artık relay adresine posta göndermeniz GEREKMEZ (2026-11-06, V1472):** relay adresli (`@privaterelay.appleid.com`, ayrıca jetonda `is_private_email`) hesap açıldığında sunucu hesabı `email_relay` olarak işaretler ve kullanıcıdan GERÇEK, aktif e-posta adresi ister; adrese 6 haneli kod gider, doğrulanınca hesabın TEK e-postası o adres olur (şifre sıfırlama, 2FA ve bildirim e-postaları artık gerçek adrese gider). Relay adresine hiçbir zaman posta gönderilmez; eski relay adresi kaydedilmez (yalnız Apple `sub` kalır). Yeni relay hesapta gerçek e-posta doğrulanana kadar yazma uçları `403 REAL_EMAIL_REQUIRED` (bayrak `AUTH_REAL_EMAIL_GATE_ENABLED`, varsayılan açık); mevcut relay hesaplar kilitlenmez, uygulama yalnız yumuşak bir adım gösterir. Apple tarafında kullanıcıyı gerçek e-posta paylaşmaya zorlamak mümkün değildir ("E-postamı gizle" kullanıcı hakkıdır); bu yüzden çözüm bizim tarafımızdadır. Yukarıdaki Apple "Sign in with Apple for Email Communication" kaydı artık **isteğe bağlıdır** (yalnız Apple'a kayıtlı alan adından relay'e posta göndermek isterseniz). Ayrıntı: `docs/changes/auth.md` "Gercek e-posta (role) dogrulamasi".

## 3. Sunucu tarafı açma adımları

1. `.env.prod` içine yazın:
   ```
   AUTH_OAUTH_ENABLED=true
   GOOGLE_CLIENT_IDS=<web-id>.apps.googleusercontent.com,<android-id>.apps.googleusercontent.com,<ios-id>.apps.googleusercontent.com
   APPLE_CLIENT_IDS=tr.com.bukampus.app
   ```
2. `docker compose -f docker-compose.prod.yml up -d backend` (compose değişkenleri backend'e iletir). Açılışta `ProdSettingsValidator` listeleri doğrular.
3. Sunucuda çıkış (egress) gerekir: `www.googleapis.com:443` ve `appleid.apple.com:443` (yalnız JWKS okuma; 3 sn zaman aşımı, 1 saat önbellek).
4. Duman: `POST /api/auth/oauth/google` geçersiz token ile `400 OAUTH_TOKEN_INVALID` dönmeli (404 değil = bayrak açık).
5. **Geri alma:** `AUTH_OAUTH_ENABLED=false` ve yeniden başlatma: uçlar kapanır, mevcut OAuth hesapları kalır (parolasız hesaplar `forgot-password` ile parola belirleyebilir).

## 4. Mağaza/hukuk notları

- App Store Kılavuz 4.8: üçüncü taraf sosyal giriş sunan iOS uygulaması **Sign in with Apple da sunmalı** (burada ikisi de var; e-posta+şifre de var).
- App Store Kılavuz 5.1.1(v): uygulama içi hesap silme zorunlu; `DELETE /api/users/me` OAuth hesapları için sağlayıcı token'ı ile yeniden doğrulayarak çalışır. **Apple token iptali (revoke) bu sürümde yok** (yapılandırma bekliyor).
- Gizlilik politikası/KVKK metni "Google ve Apple ile giriş" kapsamında işlenen veriyi (sağlayıcı kimliği, e-posta, ad) içermeli (hukuk incelemesi).
