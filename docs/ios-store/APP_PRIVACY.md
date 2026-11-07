# App Store Connect: "App Privacy" (Nutrition Label) cevapları

Kaynak gerçekler: [../legal/privacy_tr.md](../legal/privacy_tr.md) bölüm 2-6, [../store/data_safety.md](../store/data_safety.md) (Play formu, aynı olgular), [../ENCRYPTION.md](../ENCRYPTION.md), [../DATABASE.md](../DATABASE.md). Uygulama düzeyi manifest: `mobile/ios/Runner/PrivacyInfo.xcprivacy` (**bu tabloyla birebir aynı olmalı**; biri değişirse ikisi de güncellenir; `scripts/ios/check-ios-static.py` yapıyı denetler). **Henüz Connect'e girilmedi** (hesap gerekir). Apple arayüzü değişirse anlamca eşleştirin.

## Genel cevaplar

| Soru | Cevap |
|---|---|
| Bu uygulama veri topluyor mu? | **Evet** |
| Takip için kullanılan veri (Tracking)? | **Hayır**: reklam yok, veri komisyoncusu yok, üçüncü taraf analitik/SDK yok, ATT istemi yok (`NSPrivacyTracking=false`, izleme alan adı yok) |
| Üçüncü taraf ortaklar veri topluyor mu? | Hizmet sağlayıcı olarak: Google Firebase Cloud Messaging (bildirim iletimi, cihaz belirteci) ve Apple APNs; Brevo yalnız sunucu tarafında e-posta iletir. Reklam/analitik amacı yok |
| Hesap silme uygulama içinde mi? | **Evet** (Profil > Verilerim ve hesap > Hesabı sil) + web: `https://bukampus.com.tr/tr/delete-account` |

## Veri türleri (hepsi "kullanıcıya bağlı", "takip için DEĞİL")

| Apple kategorisi > tür | Toplanıyor | Kullanıcıya bağlı | Takip | Amaç | Not |
|---|---|---|---|---|---|
| Contact Info > **Email Address** | Evet | Evet | Hayır | App Functionality | bingol.edu.tr; doğrulama, giriş, bildirim e-postası |
| Contact Info > **Name** | Evet | Evet | Hayır | App Functionality | görünen ad |
| Contacts > **Contacts** | Evet (isteğe bağlı) | Evet | Hayır | App Functionality | yalnız e-posta SHA-256 özetleri, istek anında eşleştirme, **saklanmaz**. Apple "gerçek zamanlı işleme" muafiyeti uygulanabilir ama ihtiyatla beyan edilir |
| User Content > **Photos or Videos** | Evet | Evet | Hayır | App Functionality | profil, gönderi, sohbet görseli/videosu |
| User Content > **Audio Data** | Evet | Evet | Hayır | App Functionality | yalnız video kaydının ses kanalı |
| User Content > **Emails or Text Messages** | Evet | Evet | Hayır | App Functionality | sohbet metinleri (sunucuda zarf şifreli) |
| User Content > **Customer Support** | Evet | Evet | Hayır | App Functionality | destek talebi, geri bildirim/öneri |
| User Content > **Other User Content** | Evet | Evet | Hayır | App Functionality | gönderi metni, kulüp/etkinlik başvuru yanıtları, anket oyu (gizli: kimlik hiçbir uçta gösterilmez) |
| Identifiers > **User ID** | Evet | Evet | Hayır | App Functionality | iç kullanıcı numarası, isteğe bağlı okul numarası |
| Identifiers > **Device ID** | Evet | Evet | Hayır | App Functionality | FCM belirteci; uygulamaya özel rastgele cihaz kimliği (`X-Device-Id`, yalnız HMAC özeti, 90 gün; IDFA/IDFV **okunmaz**). Reklam/izleme için kullanılmaz |
| Usage Data > **Product Interaction** | Evet | Evet | Hayır | Analytics, App Functionality | ekran/olay adı, zaman; toplulaştırılmış rapor; ham olaylar 45 gün (`analytics_event` kullanıcıya bağlıdır) |
| Diagnostics > **Crash Data** | Evet | **Hayır** | Hayır | Analytics | anonim çökme raporu (kullanıcı kimliği/e-posta/jeton/mesaj yok; sürüm, cihaz modeli, işletim sistemi sürümü, maskelenmiş yığın), 30 gün |
| Other Data Types | Evet | Evet | Hayır | App Functionality | isteğe bağlı profil alanları (fakülte, bölüm, sınıf) |

**Toplanmayanlar (Hayır):** Location (kesin/yaklaşık), Health & Fitness, Financial Info, Sensitive Info, Purchases, Browsing History, Search History (arama geçmişi yalnız cihazda), Surroundings, Body.

**Açık nokta:** IP adresi güvenlik günlüğünde 90 gün tutulur; Apple "yaklaşık konum" beyanını IP'den türetilen konum için ister. Burada yalnız güvenlik amaçlı kayıt olduğundan Location beyan edilmedi (Play formuyla tutarlı). Gizlilik politikası bunu açıkça söylüyor. Bu bir hukuki görüş değildir; avukata sorun ([../LEGAL_NOTES.md](../LEGAL_NOTES.md)).

## Required Reason API beyanı (PrivacyInfo.xcprivacy)

| Kategori | Neden kodu | Kaynak |
|---|---|---|
| File timestamp | `C617.1` | uygulama kapsayıcısındaki görsel/mesaj disk önbelleği `File.stat()` (`lib/core/cache/*`) |
| System boot time | `35F9.1` | Dart/Flutter monoton zaman sayacı (uygulama içi süre ölçümü) |
| User defaults | (uygulama kodu kullanmıyor) | `firebase_messaging` (CA92.1) ve `permission_handler_apple` (1C8F.1) kendi manifestlerinde bildirir |

Disk alanı API'si kullanılmıyor. Eklentilerin kendi manifestleri paketlerle gelir; birleşik raporu macOS'ta `Product > Archive > Generate Privacy Report` ile alıp bu tabloyla karşılaştırın.

## İhracat uyumluluğu

Info.plist `ITSAppUsesNonExemptEncryption=false`: yalnız standart TLS (HTTPS/WSS), Keychain ve SHA-256 özetleri; özel şifreleme yok ([../IOS_RELEASE.md](../IOS_RELEASE.md) bölüm 4.2). Connect'te soru çıkarsa: "Yes, uses encryption → exempt (standard encryption/authentication only)". Fransa için ek beyan gerekmez.
