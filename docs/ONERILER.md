# Öneriler (öncelik sırasıyla)

Durum: ✅ yapıldı · 🔜 sırada · 💡 öneri (onay bekliyor)

## A. Yayına çıkmadan önce şart
1. 💡 **Şifre sıfırlama (şifremi unuttum)** — SSS'de "yakında" yazıyor; backend'de yok. Kod e‑postayla, yeni şifre sonrası tüm oturumlar kapanır.
2. 💡 **Hukuki inceleme** — KVKK, gizlilik, kullanım koşulları taslak; veri sorumlusu bilgileri, VERBİS kontrolü, EN/AR çeviriler.
3. 💡 **Gerçek e‑posta altyapısı** — üniversite SMTP'si veya servis (SPF/DKIM). Şimdi kod yalnızca loga yazılıyor.
4. 💡 **Firebase (FCM) + iOS APNs** — kimlik dosyası yoksa push gitmez.
5. 💡 **Canlı ortam sertleştirme** — HTTPS + ters vekil, `X-Forwarded-For` (rate limit IP'si), DB yedeği, sır yönetimi, izleme (Sentry/Prometheus).
6. 💡 **CI hattı** — GitHub Actions: derleme, birim testler, duman betikleri; Testcontainers entegrasyon testleri.
7. 💡 **Mobil uygulama** — (durduruldu) giriş/kayıt/doğrulama, haber, yemek, profil, bildirim, mesajlaşma, topluluk, etkinlik+QR, destek, dil.

## B. Güvenlik ve güven
8. 💡 Yönetici için **TOTP 2FA**; Basic auth yönetici girişinin kaldırılması.
9. 💡 **Oturum yönetimi** — aktif cihazlar, tümünden çıkış, refresh token yeniden kullanım tespiti, hesap kilitleme.
10. 💡 **Otomatik içerik filtresi** — küfür/spam listesi, görsel moderasyonu, itiraz akışı.
11. 💡 **Rol ayrıntısı** — MODERATÖR, DESTEK, EDİTÖR.
12. 💡 **Öğrenci/personel ayrımı** — `ogr.` alan adına göre rozet ve hedefli bildirim.
13. 💡 E‑posta değiştirme, bildirim sessiz saatleri.

## C. Veri ve içerik
14. 💡 **Haber geçmişi doldurma** (şimdi yalnızca ilk sayfa).
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
25. 💡 Bildirim/toplu gönderim kuyruğu; WebSocket çok sunuculu yük testi.
26. 💡 Bulanık kullanıcı araması, Türkçe stemming, arama önerileri.

## F. Mağaza/uyumluluk
27. 💡 Play Veri Güvenliği formu, App Store gizlilik etiketleri (hesap silme ve raporlama hazır).
28. 💡 Uzaktan yapılandırma / özellik bayrakları, erişilebilirlik, RTL cilası.

## Yapılanlar ✅
Haber/duyuru/etkinlik + yemek listesi (zamanlayıcı, bakım modu), üyelik (bingol.edu.tr, e‑posta doğrulama, JWT access/refresh, Redis rate limit), profil, bildirimler (FCM, tercihler), yönetici push kampanyaları, engelleme/raporlama/moderasyon, mesajlaşma (WebSocket), topluluklar, etkinlikler (QR + elle yoklama), favoriler, tam metin arama, geri bildirim/öneri panosu, destek talepleri, SSS, sözleşmeler (sürümlü + onay kaydı), uygulama bilgisi/sürüm kontrolü, KVKK veri dışa aktarma, çok dillilik (tr/en/ar).
