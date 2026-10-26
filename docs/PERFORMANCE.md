# Performans Rehberi

Bu belge BÜ Kampüs için mobil performans bütçesini, backend hedeflerini ve ölçüm yöntemini tanımlar. Sayısal hedefler başlangıç değerleridir; ilk gerçek ölçümlerden sonra güncellenmelidir.

## 1. Mobil performans bütçesi

| Metrik | Hedef |
|---|---|
| Soğuk açılış -> ilk anlamlı içerik (orta seviye Android) | < 2,5 sn (önbellekli açılışta < 1,5 sn) |
| Sıcak açılış | < 1 sn |
| Liste kaydırma | 60 fps hedef; kare başına < 16 ms, takılan kare oranı < %1 |
| Ana ekran için ağ isteği sayısı | <= 4 (haber, menü, bildirim özeti, profil); ekran başına gereksiz tekrar yok |
| Tek yanıt boyutu (liste, sıkıştırılmış) | < 50 KB |
| Görsel | Liste küçük resmi < 100 KB, ekran genişliğine uygun boyut, disk önbelleği |
| Hata/yükleniyor durumu | Her ağ çağrısında yükleniyor/hata/boş/bakım durumu görünür |

İlkeler: ETag/`If-None-Match` ile 304 kullanın; önce önbelleği gösterip arka planda yenileyin; sayfalama ile ekrana sığandan fazlasını çekmeyin; kaynak sitelere doğrudan istek yok.

## 2. Backend hedefleri

- p95 < 400 ms (yerel Docker yığını, 5 eşzamanlı istek), okuma uçlarının çoğu için p95 < 150 ms beklenir.
- Hata oranı %0 (429 hata sayılmaz, ayrı izlenir).
- ETag destekli uçlarda 304 yanıtı gövdesiz ve tam yanıttan belirgin hızlı olmalı.
- Haber/menü okuma uçları kaynak siteye veya Redis'e dokunmaz.
- Arama (PostgreSQL tam metin) p95 < 400 ms; yavaşsa indeks/sorgu planına bakın.

## 3. API hız testini çalıştırma

```bash
docker compose up -d --build
BASE=http://localhost:8080 node scripts/perf/perf-api.js
```

Ayrıntılı ortam değişkenleri: [scripts/perf/README.md](../scripts/perf/README.md). Test kullanıcısı (`mobil.test@bingol.edu.tr`) önceden kayıtlı ve doğrulanmış olmalıdır.

Yorumlama:
- **p50** tipik deneyim, **p95/p99** kuyruk gecikmesi; eşik p95 üzerinden denetlenir (`PERF_P95_MS`). Çıkış kodu 1 = eşik aşımı veya hata.
- **p99 / p50 oranı yüksek** ise aralıklı yavaşlık: GC, bağlantı havuzu, soğuk önbellek, kilit beklemesi.
- **Sayfa 3, sayfa 0'dan belirgin yavaşsa**: OFFSET maliyeti; keyset (cursor) sayfalamaya geçmeyi düşünün.
- **bayt** sütunu yük büyüklüğüdür; büyükse alan sayısını azaltın, gzip açık olmalı.
- **etag** sütunu: `304/xms` beklenir. `yok` ise uç ETag üretmiyordur; `200` ise ETag eşleşmiyordur (yanıt her seferinde değişiyor olabilir).
- **429** sütunu sıfırdan büyükse rate limit tetiklenmiştir; betik geri çekilir, sonuçlar yine geçerlidir ama `PERF_C`/`PERF_N` düşürülebilir.
- Aynı makinede çalışan istemci ve sunucu birbirini etkiler; karşılaştırma için hep aynı koşulları kullanın ve önceki `last-run.json` ile kıyaslayın. İlk çalıştırma JIT ısınmasından yavaş olabilir.

## 4. Flutter tarafı ölçüm adımları

Bu makinede Flutter kurulu değildir ve profile derleyicisi/cihaz yoktur; bu nedenle kare süresi ölçümü Flutter kurulu bir makinede yapılır (`flutter run --profile`, DevTools Performance sekmesi). Bu ortamda uygulanabilir alternatifler:

1. **Ağ istek sayımı:** API katmanına (tek HTTP istemcisi) hafif bir sayaç/interceptor ekleyin; ekran açılışı başına istek sayısını ve toplam bayt'ı loglayın. Ana ekran bütçesi <= 4 istek.
2. **Widget testiyle yeniden çizim sayımı:** `testWidgets` içinde sahte (fake) depo ile ekranı kurup `build` çağrılarını sayan bir `Builder`/sayaç sarmalayıcı kullanın; bir etkileşimden sonra yeniden çizim sayısının üst sınırını doğrulayın. `const` widget, `ListView.builder`, seçici `select`/`Consumer` kullanımı yeniden çizimi azaltır.
3. **Backend tarafı ölçüm:** `perf-api.js` mobilin kullandığı yolları ölçer; mobilde algılanan gecikme ≈ ağ + sunucu + ayrıştırma.
4. **Elle kontrol listesi (cihazda):** soğuk açılış kronometresi, ilk liste kaydırma takılması, uçak modunda önbellekli açılış.
5. Flutter kurulu makinede: `flutter run --profile` + DevTools (Frame Chart, Rebuild Stats), `flutter build apk --analyze-size` ile paket boyutu.

## 5. Bilinen darboğaz kontrol listesi

- [ ] **N+1 sorgu:** liste ucunda her satır için ek sorgu yok mu? (`fetch join`/toplu `IN` sorgusu; Hibernate SQL logu veya sorgu sayacıyla kontrol.)
- [ ] **İndeksler:** filtre/sıralama sütunlarında (tür, tarih, kullanıcı id, okundu durumu) indeks var mı? Yavaş sorguda `EXPLAIN ANALYZE`. İndeks adları şemada benzersizdir, önek kullanın.
- [ ] **Sayfalama:** her liste sınırlı (`size` üst sınırı); akan listelerde `CursorPage`; büyük OFFSET'ten kaçının.
- [ ] **Yanıt boyutu:** liste DTO'su yalnızca ekranın ihtiyacı olan alanları taşır; gövde HTML'i listede yok; gzip açık.
- [ ] **Önbellek:** ETag/304, uygun `Cache-Control`; menü gibi nadiren değişen veride sunucu/istemci önbelleği.
- [ ] **Görseller:** boyutlandırılmış küçük resim, WebP/JPEG sıkıştırma, istemci disk önbelleği, liste için tembel yükleme.
- [ ] **Tam metin arama:** GIN indeksi kullanılıyor mu; `LIKE '%...%'` taraması yok.
- [ ] **Bağlantı havuzu / thread:** Hikari havuz boyutu eşzamanlılığa yeterli; yavaş dış çağrı (SMTP/FCM) istek iş parçacığını bloklamıyor.
- [ ] **Redis çağrıları:** istek başına gereksiz Redis gidiş-dönüşü yok (rate limit, aktivite izleme dahil).
- [ ] **Mobil:** gereksiz yeniden çizim, ana iş parçacığında JSON ayrıştırma (büyük yanıtta `compute`), ekran başına tekrarlayan istek.

## Olcum sonucu (2026-10-26, yerel docker yigini, V190)

`node scripts/perf/perf-api.js` (N=50, C=5, esik p95<400 ms): 15 ucun tamami esik icinde, hata ve 429 yok.
En yavas p95: takvim 81 ms, etkinlikler 78 ms, topluluklar 79 ms, haber p0 79 ms. Haber/menu ETag ile 304 donusu 9-24 ms.
Not: yerel makine olcumudur; uretim agi ve veri hacmi icin yeniden olculmelidir.
