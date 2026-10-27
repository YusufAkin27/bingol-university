# VERBİS Kayıt Rehberi ve Veri Envanteri (İç Belge)

VERBİS'e kayıt yükümlülüğü olup olmadığı (çalışan sayısı/bilanço eşikleri, kamu kurumu/kuruluşu statüsü, ana faaliyet konusu) **hukuk danışmanıyla belirlenir**. Yükümlüyse bu envanter kayda temel olur. Kamu tüzel kişileri için de kayıt gerekebilir; işleten tüzel kişinin statüsü belirlenmeli (LEGAL_CHECKLIST).

## 1. Envanter

| # | Veri kategorisi | Örnek alanlar | İşleme amacı | Hukuki sebep | Alıcı grubu | Yurt dışı | Saklama | Güvenlik önlemi |
|---|---|---|---|---|---|---|---|---|
| 1 | Kimlik | Ad-soyad | Üyelik, profil | m.5/2-c | Barındırma, yönetici | Hayır | Hesap süresi + anonimleştirme | Erişim kontrolü, rol, TLS |
| 2 | İletişim | bingol.edu.tr e-posta; destek iletişim e-postası | Doğrulama, bildirim, destek | m.5/2-c | SMTP sağlayıcı, barındırma | Sağlayıcıya bağlı | Hesap süresi; mail kuyruğu 30 gün | TLS/STARTTLS, hız sınırı, hash'li kod |
| 3 | Eğitim/mesleki | Fakülte, bölüm, sınıf, rol | Profil, topluluk | m.5/2-c; isteğe bağlı rıza | Diğer kullanıcılar (gizlilik ayarına göre) | Hayır | Hesap süresi | Alan bazlı gizlilik |
| 4 | Görsel | Avatar, sohbet/gönderi görseli ve videosu | Profil, mesajlaşma | m.5/2-c | Barındırma, yönetici (moderasyon) | Hayır | Hesap süresi; tek gönderimlik 365 gün | Yeniden kodlama, EXIF temizliği, şifreli saklama (sohbet) |
| 5 | Kullanıcı içeriği | Mesaj, gönderi, geri bildirim, destek/itiraz metni | Hizmet, moderasyon | m.5/2-c, f | Barındırma, yönetici | Hayır | Hesap süresi; silinen mesaj kopyası ayarlanabilir | AES-256-GCM, erişim denetimi, değiştirilemez erişim kaydı |
| 6 | Müşteri işlem / kullanım | Üyelikler, RSVP, yoklama, favori, tercih, engel listesi | Hizmet | m.5/2-c | Barındırma | Hayır | Hesap süresi (silmede temizlenir) | Erişim kontrolü |
| 7 | İşlem güvenliği | Şifre hash, oturum, cihaz özeti (HMAC), IP, platform, sürüm, ban kayıtları | Güvenlik, kötüye kullanım | m.5/2-f, ç | Barındırma, yönetici | Hayır | 90 gün (karar: 5651) | Hash/HMAC, kısıtlı panel, rate limit |
| 8 | Cihaz bildirim kaydı | FCM token, platform, sürüm, dil | Push | m.5/2-c; açık rıza | **Google/Apple** | **Evet** | 60 gün görülmezse | TLS, token temizliği |
| 9 | Analitik | Ekran/olay adı, sınırlı değerler | Hizmet iyileştirme | m.5/2-f | Barındırma | Hayır | 180 gün | Toplulaştırılmış rapor |
| 10 | Hukuki işlem / uyum | Sözleşme onayı, rapor, ihlal kaydı, yönetici erişim ve işlem kaydı | İspat, güvenlik | m.5/2-ç, e, f | Yetkili makamlar | Hayır | Hesap silmede korunur; erişim kaydı yalnızca-ekleme | DB tetikleyicisi, dış arşiv |
| 11 | Rehber özeti (geçici) | E-posta SHA-256 özetleri | Tanıdık bulma | Açık rıza | — | Hayır | **Saklanmaz** | Hız sınırı, bellek içi |

Özel nitelikli veri **hedeflenmez**; kullanıcı içeriğinde tesadüfen bulunabilir (veri sorumlusu tarafından sistematik işlenmez).

## 2. Kayıt alanları için notlar

- **Veri sorumlusu irtibat kişisi** ve **veri sorumlusu temsilcisi** bilgileri gerekir (LEGAL_CHECKLIST).
- Alıcı grupları: kamu kurumları (talep halinde), hizmet sağlayıcılar (barındırma, SMTP, Google/Apple), yetkili yöneticiler.
- Yurt dışı aktarım: Google/Apple (veri kategorisi: cihaz bildirim kaydı). Barındırma/SMTP yurt dışındaysa eklenir.
- Güvenlik tedbirleri listesi (VERBİS alt bölümü): erişim yetkilendirmesi, şifreleme (saklama + iletim), kayıt/izleme (denetim kaydı), yedekleme, ağ güvenliği, anahtar yönetimi, çalışan taahhüdü, olay müdahale planı.
- Saklama süresi VERBİS'te "azami süre" olarak girilir; envanterdeki süreler kod ve `01` numaralı politika ile tutarlı tutulur. Değişiklikte 7 gün içinde VERBİS güncellenir; yılda bir gözden geçirilir.
