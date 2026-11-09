# Kullanıcı kullanım analizi — 2026-11-09

Analitik > Davranış > Kullanıcılar: tüm sayfaların ölçülen süresi, ziyaret sayısı, ortalaması, en uzun ziyareti ve payı; günlük kullanım; İstanbul saatine göre 24 saatlik görüntüleme/işlem dağılımı; işlem türleri. Kullanıcı kartındaki bağlantı aynı ayrıntıya gider.

- Seçilen tarih aralığı kullanıcı detayına aynen iletilir; geçmiş aralık son günlerle değiştirilmez.
- Süre özetleri zaman çizelgesindeki 50 oturum / 100 adım sınırından önce hesaplanır. 20.000 ham olay sınırında eksik veri notu gösterilir. Süresi ölçülmeyen ziyaretin ortalaması bilinmiyor olarak kalır.
- Kişi bazlı erişim `users.pii` izni ve denetim kaydı gerektirir; analizi kapatma tercihi korunur.
- 44 backend testi, ilgili 52 web testi, lint, üretim derlemesi ve paket boyutu kontrolü geçti. Önceki sürümün 1.872 web testi de bu oturumda geçti.
- Dört Playwright senaryosu: 1440/390 px, açık/koyu. Sayfa taşması ve tarih parametreleri kontrol edildi. PNG dosyaları sahte test verisidir; gerçek kullanıcı içermez.
