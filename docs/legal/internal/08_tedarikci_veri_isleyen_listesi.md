# Tedarikçi / Veri İşleyen Listesi (İç Belge)

Her tedarikçi için yazılı veri işleme sözleşmesi (KVKK m.12/2: veri sorumlusu, veri işleyenin tedbirleri almasını sağlar) ve güvenlik değerlendirmesi gerekir. Aşağıdaki "Doldurulacak" alanları yayın öncesi tamamlanmalıdır.

| Tedarikçi | Hizmet | Kişisel veri | Konum | Rol | Sözleşme / şartlar | Durum |
|---|---|---|---|---|---|---|
| Barındırma / sunucu sağlayıcısı: **Doldurulacak** | VPS/bulut, PostgreSQL, Redis, dosya deposu | Tüm hizmet verisi (mesajlar şifreli) | **Doldurulacak** | Veri işleyen | Veri işleme eki + güvenlik şartları | Açık |
| SMTP / e-posta sağlayıcısı: **Doldurulacak** (`MAIL_HOST`) | Doğrulama, şifre sıfırlama, güvenlik e-postaları | Alıcı e-posta, içerik | **Doldurulacak** | Veri işleyen | Sağlayıcı DPA | Açık |
| Google LLC (Firebase Cloud Messaging) | Android/iOS push | FCM token, bildirim yükü | Yurt dışı | Veri işleyen / altyapı sağlayıcı | Google Cloud/Firebase veri işleme şartları (Data Processing and Security Terms) + Kurul standart sözleşmesi (05) | Açık |
| Apple Inc. (APNs) | iOS push (APNs anahtarı bekleniyor) | Cihaz token'ı, bildirim yükü | Yurt dışı | Altyapı sağlayıcı | Apple Developer Program şartları + 05 | Açık (iOS yayın öncesi) |
| Alan adı / CDN / DNS / TLS (ör. Let's Encrypt, ters vekil): **Doldurulacak** | Alan adı, TLS | IP/erişim günlükleri | **Doldurulacak** | Veri işleyen | Sağlayıcı şartları | Açık |
| Yedekleme hizmeti: **Doldurulacak** | Veritabanı ve dosya yedeği | Şifreli yedek (anahtar ayrı) | **Doldurulacak** | Veri işleyen | DPA | Açık |
| Mağazalar (Google Play, App Store) | Dağıtım | Mağaza kullanıcı verisi (bağımsız sorumlu) | Yurt dışı | Bağımsız veri sorumlusu | Mağaza şartları; gizlilik beyanı (data safety / nutrition label) | Beyan formları doldurulacak |

**Veri işleyen olmayanlar:** Haber/yemek kaynak siteleri (bingol.edu.tr, sks.bingol.edu.tr) yalnızca kamuya açık içerik kaynağıdır; kişisel veri aktarılmaz.

**Gözden geçirme:** Yılda bir; yeni tedarikçi eklenmeden önce 05 (yurt dışı) ve 06 (VERBİS) güncellenir. Mağaza gizlilik beyanları (Play Data Safety, App Store gizlilik etiketleri) bu envanter ve Gizlilik Politikası ile **tutarlı** doldurulur: toplanan veriler — e-posta, ad, profil, mesajlar, fotoğraf/video, cihaz kimliği (özet), IP, bildirim token'ı, analitik olaylar; konum: toplanmaz (gönderilmez); rehber: yalnızca özetler, saklanmaz.
