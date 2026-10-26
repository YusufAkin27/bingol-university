# Öneriler (öncelik sırasıyla)

Durum: ✅ yapıldı · 🔜 sırada · 💡 öneri (onay bekliyor)

## A. Yayına çıkmadan önce şart
1. ✅ **Şifre sıfırlama** — 3 adım (`forgot-password` → `verify-reset-code` → `reset-password`), sonrasında tüm oturumlar kapanır. Kalan: SSS'deki "yakında" ifadesini güncellemek.
2. 💡 **Hukuki inceleme** — KVKK, gizlilik, kullanım koşulları taslak; veri sorumlusu bilgileri, VERBİS kontrolü, EN/AR çeviriler.
3. 🔜 **Gerçek e‑posta altyapısı** — kuyruk, yeniden deneme ve şablonlar hazır (`docs/changes/mail.md`); eksik olan üniversite SMTP'si/servis bilgisi (`MAIL_*`, SPF/DKIM). Bilgi gelene kadar kod loga yazılır.
4. 🔜 **Firebase (FCM) + iOS APNs bilgileri** — backend ve mobil kod hazır (`docs/PUSH_SETUP.md`, `docs/MOBILE_PUSH.md`); `FCM_CREDENTIALS_JSON`/`FILE`, `GoogleService-Info.plist`/`google-services.json` ve APNs anahtarı (ücretli Apple Developer hesabı) bekleniyor.
5. 🔜 **Canlı ortam sertleştirme** — ✅ `prod` profili, `ProdSettingsValidator`, güvenlik başlıkları ve kurulum/yedek rehberi (`docs/DEPLOY.md`). Kalan: gerçek HTTPS + ters vekil kurulumu, yedek otomasyonu, izleme/uyarı (Sentry/Prometheus), çok örnek için `SchedulerLock` sarmalama.
6. 💡 **CI hattı** — GitHub Actions: derleme, birim testler, duman betikleri; Testcontainers entegrasyon testleri.
7. ✅ **Mobil uygulama** — giriş/kayıt/doğrulama/şifre sıfırlama, haber, yemek, profil, bildirim, gerçek zamanlı mesajlaşma, topluluk, etkinlik+QR, destek, arama. Kalan: mağaza yayını için uygulama simgesi/imza ve TestFlight (ücretli Apple hesabı), push bilgileri.
7a. 💡 **Uygulama içi dil (EN/AR)** — mobil arayüz metinleri çevrilmedi; API zaten EN/AR hata ve bildirim metni üretiyor. RTL doğrulaması gerekir.
7b. 💡 **xcross sınırlamaları** — simge işlenmiyor, debug sürüm ana ekrandan açılmıyor; macOS/Xcode veya CI derleme hattı düşünülmeli.

## B. Güvenlik ve güven
8. 💡 Yönetici için **TOTP 2FA**; Basic auth yönetici girişinin kaldırılması.
9. 🔜 **Oturum yönetimi** — ✅ tümünden çıkış (`logout-all`) ve şifre sıfırlamada oturum iptali. Kalan: aktif cihaz listesi, refresh token yeniden kullanım tespiti, hesap kilitleme.
10. 💡 **Otomatik içerik filtresi** — küfür/spam listesi, görsel moderasyonu, itiraz akışı.
11. 💡 **Rol ayrıntısı** — MODERATÖR, DESTEK, EDİTÖR.
12. 💡 **Öğrenci/personel ayrımı** — `ogr.` alan adına göre rozet ve hedefli bildirim.
13. 💡 E‑posta değiştirme. (Bildirim sessiz saatleri ✅ yapıldı.)

## C. Veri ve içerik
14. 💡 **Haber geçmişi doldurma** (şimdi yalnızca ilk sayfa). Etkinlik tarihi (`eventDate`) ✅ ayrıştırılıyor.
15. 💡 **Kaynak site değişim uyarısı** — 24 saatten uzun bakımda kalırsa yöneticiye bildirim; gerçek HTML ile sözleşme testleri.
16. 💡 **Haber/duyuru otomatik çeviri (EN/AR)** — uluslararası öğrenciler için.
17. 💡 Harici alt sitelerdeki duyuruların içeriği.

## D. Kampüs özellikleri
18. 💡 Ders programı, akademik takvim (+hatırlatma).
19. 💡 **E‑sertifika** — yoklamayla katılan için otomatik PDF.
20. 💡 Etkinlik: ICS/Takvim'e ekle, bekleme listesi, etkinlik sonrası anket.
21. 💡 Ring/servis saatleri, kampüs haritası.
22. 💡 Kayıp eşya, kampüs pazarı, anket, yemek puanlama, soru‑cevap, çalışma arkadaşı.
23. 💡 Bölüm/sınıfa göre otomatik ders grupları.

## E. Performans ve ölçek
24. 💡 Redis önbelleği (haber, menü); S3/MinIO + CDN (yerel disk ölçeklenmez).
25. 💡 Push kuyruğunu kalıcı yapma (şimdi bellek içi, yeniden başlatmada kaybolabilir); WebSocket çok sunuculu yük testi. (API hız ölçümü ✅ `scripts/perf/perf-api.js`.)
26. 💡 Bulanık kullanıcı araması, Türkçe stemming, arama önerileri.

## F. Mağaza/uyumluluk
27. 💡 Play Veri Güvenliği formu, App Store gizlilik etiketleri (hesap silme ve raporlama hazır).
28. 💡 Uzaktan yapılandırma / özellik bayrakları, erişilebilirlik, RTL cilası.

## G. Mesajlaşma ve şifreleme
29. 💡 **Mesaj şifreleme anahtar yönetimi** — şifreleme hazır (`docs/ENCRYPTION.md`); ana anahtarlar ortam değişkeninde. KMS/HSM entegrasyonu, anahtar döndürme prosedürünün canlıda denenmesi ve yedek/kurtarma provası.
30. 💡 Sohbet: ses/dosya eki, çok sunuculu presence, mesaj arama.

## Yapılanlar ✅
Haber/duyuru/etkinlik + yemek listesi (zamanlayıcı, bakım modu), üyelik (bingol.edu.tr, e‑posta doğrulama, JWT access/refresh, Redis rate limit), profil, bildirimler (FCM, tercihler), yönetici push kampanyaları, engelleme/raporlama/moderasyon, mesajlaşma (WebSocket), topluluklar, etkinlikler (QR + elle yoklama), favoriler, tam metin arama, geri bildirim/öneri panosu, destek talepleri, SSS, sözleşmeler (sürümlü + onay kaydı), uygulama bilgisi/sürüm kontrolü, KVKK veri dışa aktarma, çok dillilik (tr/en/ar), şifre sıfırlama + tüm oturumları kapatma, e‑posta kuyruğu (outbox) ve şablonlar, push altyapısı (async gönderim, cihaz temizliği, hedef yükü), mobil uygulama (gerçek zamanlı sohbet, görsel, QR, açılış kapısı, analitik, ETag önbelleği), prod profili + başlangıç doğrulayıcı + DEPLOY rehberi, performans test betiği, mesaj şifreleme ve medya hattı.
