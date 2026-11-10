# Etkinlik bileti: Apple Wallet / Google Cüzdan dış yapılandırma kontrol listesi

Durum (T1): **uygulama içi "Biletim" ekranı hazır ve çalışır** (sırsız). **Cüzdana ekleme kodu YAZILMADI**: `.pkpass` imzalama ve Google Wallet JWT üretimi için aşağıdaki dış hesaplar ve gizli anahtarlar gerekir; bunlar sizin hesabınızdır ve repoya **asla** girmez. Bu belge hazır olduğunda yapılacakları listeler.

## 0. Bugün kodda olanlar (varsayılan KAPALI)

| Katman | Ne var |
|---|---|
| Sunucu | `GET /api/events/{id}/ticket`: bilet verisi (etkinlik, tarih, konum, düzenleyen, sahip adı, `state` VALID/ENDED/CANCELLED, `attendanceOpen`, `wallet{apple,google}`). Yalnız onaylı (`GOING`) katılımcı; sahip/moderatör 403 `TICKET_NOT_FOR_STAFF`, katılmayan 403 `NOT_RSVPED`. QR bu uçta YOKTUR; kısa ömürlü kişisel QR mevcut `GET /events/{id}/my-ticket` (yoklama sözleşmesi değişmedi). |
| Sunucu bayrakları | `app.wallet.enabled`, `app.wallet.apple-enabled`, `app.wallet.google-enabled` (env: `WALLET_ENABLED`, `WALLET_APPLE_ENABLED`, `WALLET_GOOGLE_ENABLED`; hepsi `false`). Yalnız bayrak: sertifika/anahtar bu sürümde okunmaz. Ana bayrak kapalıyken sağlayıcı bayrakları da kapalı bildirilir. |
| Mobil | "Cüzdana ekle" düğmesi yalnız `--dart-define=WALLET_ENABLED=true` **ve** sunucu `wallet.apple/google` açıksa görünür (`lib/core/wallet_config.dart`). Bu sürümde basınca yalnız "yakında" bildirimi verir. |

## 1. Apple Wallet (.pkpass), ücretli Apple Developer hesabı

1. Certificates, Identifiers & Profiles > Identifiers > **Pass Type IDs** > "+" : örn. `pass.tr.com.bukampus.ticket`.
2. Pass Type ID > **Create Certificate**: Mac'te Keychain Access ile CSR üretin, Apple'dan `.cer` indirin, anahtarla birlikte **`.p12`** olarak dışa aktarın (parola koyun).
3. Apple **WWDR** ara sertifikasını (G4) Apple'ın PKI sayfasından indirin (herkese açık).
4. **Team ID**'yi not edin.
5. Uygulamada (iOS) Wallet için ayrı yetenek gerekmez; paket `.pkpass` dosyasıdır ve cihaz Wallet'ı ile açılır.

Sunucuya gelecek değişkenler (ileride; **şu an okunmaz**): `WALLET_APPLE_PASS_TYPE_ID`, `WALLET_APPLE_TEAM_ID`, `WALLET_APPLE_CERT_P12_FILE` (yol), `WALLET_APPLE_CERT_PASSWORD`, `WALLET_APPLE_WWDR_FILE` (yol).

## 2. Google Cüzdan (Google Wallet API)

1. https://pay.google.com/business/console > **Google Wallet API** için issuer hesabı oluşturun; **Issuer ID**'yi not edin.
2. Google Cloud Console'da (ör. `bu-kampus` projesi) **Google Wallet API**'yi etkinleştirin.
3. IAM > Service Accounts > yeni servis hesabı > **JSON anahtarı** indirin. Wallet konsolunda Users bölümünden bu servis hesabına erişim verin.
4. Etkinlik bileti için bir **Event Ticket class** tanımlanır (ilk yayın "demo" modundadır; üretim için Google onayı gerekir).

Sunucuya gelecek değişkenler (ileride; **şu an okunmaz**): `WALLET_GOOGLE_ISSUER_ID`, `WALLET_GOOGLE_SERVICE_ACCOUNT_FILE` (JSON dosya yolu).

## 3. Güvenli saklama kuralları

- `.p12`, parola ve servis hesabı JSON'u **commit edilmez**; `.env.prod` ve sunucuda `chmod 600`, kalıcı veri dizininde (ör. `/opt/bukampus-data/wallet/`), compose'ta salt okunur bağlama (`:ro`).
- Değerler log'a, hata gövdesine ve API cevabına yazılmaz; `ProdSettingsValidator`'a, bayrak açıkken dosyalar yoksa açılışı reddeden bir kontrol eklenmelidir.
- Anahtar sızarsa: Apple'da sertifikayı iptal edin, Google'da servis hesabı anahtarını silip yenisini üretin.

## 4. Kod tarafında yapılacaklar (anahtarlar hazır olunca)

1. Pass içeriği: etkinlik adı/tarih/konum + barkod. **Dikkat:** yoklama QR'ı 5 dk geçerlidir; cüzdan kartı kalıcı olduğundan barkod olarak bu kod kullanılamaz. Seçenek: Apple için `webServiceURL` + güncelleme uçları ile geçiş sırasında yenilenen barkod (mesaj/`updates`), Google için "rotating barcode"; ya da cüzdan kartı yalnız bilgi taşır, QR uygulamada gösterilir. Karar kullanıcıya aittir.
2. `.pkpass` imzalama (`signature` = PKCS#7, SHA-256 manifest) ve Google Wallet "Save to Wallet" JWT (RS256, servis hesabı) üretimi sunucuda yeni uçlarla (`/api/events/{id}/ticket/wallet/apple|google`), hız sınırı ve aynı yetki (yalnız `GOING` katılımcı) ile.
3. Mobilde düğmenin "yakında" yerine gerçek akışa bağlanması; derleme `--dart-define=WALLET_ENABLED=true`.
4. Duman: gerçek cihazda Wallet'a ekleme; iptal/bitmiş etkinlikte kartı geçersiz kılma.
