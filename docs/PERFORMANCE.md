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

## 20k olcek (sentetik veri)

`scripts/perf/seed-20k.sql` 20.000 sentetik kullanici (`seedN@bingol.edu.tr`, gecersiz parola hash'i), ~60 bin birebir konusma, ~1.2 M mesaj (varsayilan 20/konusma), 800 bin bildirim, 3 M analitik olay, 100 bin denetim kaydi uretir (parametreler: `-v users= msgs_per_conv= events_per_user= notifs_per_user=`). **Yalniz gelistirme/test veritabani:** `-v confirm=I_AM_DEV_ONLY` verilmezse veya seed disi 50'den fazla kullanici varsa durur.

```bash
# ayri gecici proje, port cakismasi olmasin (mevcut yigina dokunmaz)
COMPOSE_PROJECT_NAME=bu_dbscale BACKEND_PORT=18080 WEB_PORT=18090 CRYPTO_MIGRATE_MESSAGES=false docker compose -p bu_dbscale up -d postgres redis backend
docker compose -p bu_dbscale exec -T postgres psql -U bingol -d bingol -v confirm=I_AM_DEV_ONLY -f - < scripts/perf/seed-20k.sql
docker compose -p bu_dbscale exec -T postgres psql -U bingol -d bingol -c "EXPLAIN (ANALYZE, BUFFERS) SELECT ..."
docker compose -p bu_dbscale down -v   # isi bitince
```

Hedefler (20k seed ile, tek istek, sicak onbellek): kullanici-yuzlu uclar **p95 < 400 ms** (mevcut esik), bildirim listesi/sohbet listesi/kesfet sayfasi sorgulari **<50 ms** (veritabani suresi), `statement_timeout` (8 s) asan sorgu yok. Gece bakimi (`DbMaintenanceJob`) seed verisinde birkac dakikada bitmeli; `bu_dbmaint_deleted_total` ve log satiri `dbmaint tamam` ile izlenir.

Durum ve ham `EXPLAIN` ciktilari asagida (bu bolum calistirildikca guncellenir):

**Durum (2026-10-28): DENENDI, gercek PostgreSQL 16 uzerinde** (gecici `postgres:16-alpine` konteyneri; tum `V*.sql` migration'lari Flyway sirasiyla psql ile hatasiz uygulandi, V520 dahil; backend uygulamasi bu denemede calistirilmadi, API p95 olculmedi). Seed suresi 3 dk 14 sn. Seed sonrasi boyutlar (VACUUM sonrasi): `message` 1,2 M satir = 188 MB yigin + 307 MB indeks (~410 B/satir, plaintext govde; sifreli govde ~+100 B), `analytics_event` 3 M = 411 MB, `notification` 0,8 M = 232 MB.

`EXPLAIN (ANALYZE)` ozeti (sicak onbellek, tek sorgu):

| Sorgu | Sure | Not |
|---|---|---|
| Bildirim listesi (keyset, kullanici basina ~40 satir) | 0,24 ms | `idx_notification_user` |
| Okunmamis bildirim sayaci | 0,10 ms | `prf160_notification_unread` kismi indeks |
| Sohbet listesi (kullanici) | 0,11 ms | `idx_conv_member_user` + siralama bellekte (kullanici basina ~3 konusma) |
| Konusma basina okunmamis sayaci | 0,12 ms | `idx_perf_message_unread` |
| Mesaj gecmisi sayfasi (31 satir) | 0,11 ms | `idx_message_conversation` |
| Admin kullanici listesi (son gorulme sirali, LIMIT 20) | 0,08 ms | `idx_app_user_last_seen` |
| `topEvents` 30 gun, ESKI (ham 3 M satirdan `GROUP BY`) | **2640 ms** (disk tasmasi: temp 16 k blok) | 8 sn `statement_timeout` sinirina yaklasiyordu |
| `topEvents` 30 gun, YENI (ozet tablo + son 2 gun ham) | 276 ms | Ozet kismi 0,1 ms (378 satir); kalan 270 ms ham son 2 gunu **seri tarar** cunku seed zamanlari rastgele (BRIN korelasyonu yok). Uretimde `created_at` ekleme sirasina yakin: BRIN ile yalniz son blok araligi okunur (bu olcum en kotu durumdur) |
| Rollup, tek gun (3 M satirlik tabloda) | 262-484 ms | gecede 1 kez |
| Saklama silme parcasi (5000'lik, BRIN rastgele veride) | 70 ms | kayipli BRIN taramasi; zaman-sirali veride cok daha kucuk |
| Bildirim kullanici ust siniri tespiti (800 k satir) | 65 ms | `idx_notification_user` uzerinden |

Not: veri seed ile uretildigi icin zaman kolonlari rastgele; BRIN/saklama sonuclari en kotu durum sayilmalidir. Mesaj/bildirim sorgulari yerel makinede birkac yuz mikrosaniyedir; 20k kullanici icin darbogaz ag, JSON serilestirme ve Redis gidis-donuslerinde aranmalidir (`perf-api.js`).

## 20k yük testi (k6, paket LD, 2026-10-29)

Paket: [`scripts/perf/load/`](../scripts/perf/load/README.md) (k6; `run-load.sh` yığını kurar, seed eder, koşar, `docs/perf-results/<tarih>/` altına yazar). Ham sonuçlar ve ayrıntılı tablolar: [`docs/perf-results/2026-10-29/SUMMARY.md`](perf-results/2026-10-29/SUMMARY.md) (+ koşu başına `*.db.txt`: `pg_stat_statements`, seq scan, önbellek, kilit; `*.res.summary.json`: CPU/heap/GC/Hikari).

### Düzen ve sınırlar (sonuçlar YAKLAŞIKTIR)

VPS'i **taklit eden** yerel Docker yığını: PostgreSQL 16 `-m 2g --cpus 2` (üretim `postgresql.conf` değerleri, `pg_stat_statements` açık), Redis `-m 300m` (`maxmemory 200mb volatile-lru`), uygulama `-m 2g --cpus 2 -Xmx1g`, Hikari 30, hız sınırları üretim varsayılanı. Veri: 20.000 kullanıcı, 1,2 M mesaj (düz metin eski satırlar), 60 bin konuşma, 800 bin bildirim, 3 M analitik olay, 100 bin denetim kaydı, 100 kulüp/5 bin üyelik, 200 etkinlik/20 bin RSVP, 30 bin gönderi/90 bin beğeni/300 bin takip, 3000 haber, 21 anket.
Yük üreticisi (k6, 2 GB) **aynı makinede** (12 çekirdek, Docker 7,6 GB) çalıştı: k6'nın CPU'su sunucu sınırlarının dışındadır ama disk/bellek/zamanlayıcı paylaşılır, mutlak değerler ±%20 oynayabilir. Uygulama `dev` profilinde (actuator metrics için), log INFO. Access token'lar test sırrıyla üretildi (gerçek bcrypt yalnız A senaryosunda). Ölçüm penceresi: 60 sn ısınma sonrası; **JVM ayrıca 4 dk ısıtıldı** (bkz. "Soğuk JVM"). Gerçek VPS (4 vCPU/8 GB) farklı olacağından **çıkarım aşağıdadır, gerçek ölçüm VPS'te yapılmalıdır** (komut: en altta).

### Sonuç tablosu (ısınmış JVM; hedef p95: okuma < 400 ms, yazma < 800 ms)

| Senaryo | Yük | RPS | p50 / p95 / p99 (ms) | Hata | 429 | Not |
|---|---|---:|---|---:|---:|---|
| B okuma karışımı | 100 VU | ~104 | 6 / 11 / 15 | 0 | 0 | uygulama CPU %32, PG %21 (200 = 2 çekirdek) |
| B | 200 VU | ~205 | 6 / 13 / 19 | 0 | 0 | app %72, PG %43 |
| B | **300 VU** (5 dk) | ~305 | 7 / 58 / 100 | 0 | 0 | app %133, PG %86; en yavaş uç p95 91 ms (arama) |
| B | 400 VU | ~363 | 106 / 338 / 584 | 0 | 0 | **diz çökme**: Hikari 29/30 + 85 bekleyen; mesaj geçmişi p95 677 ms, arama 512 ms (hedef aşıldı) |
| B doygunluk | 400 VU, düşünme ~0,15 sn | ~364 | 696 / 1997 / 3086 | 0 | 0 | app %197, PG %158, Hikari 30/30 + 150 bekleyen; hata yok, yalnız kuyruklanma |
| C1 yazma karışımı | 150 VU (mesaj REST+clientId, beğeni, takip, RSVP) | ~110 | 14 / 31 / 71 | 0 | 0 | mesaj gönderme p95 39 ms |
| C2 yarış | 100 kişi son 10 koltuk; 300 oy aynı ankette; 50 kişi çift oy | - | RSVP p95 213; oy p95 2373 (max 2526) | 0 | 0 | **bütünlük: 10 başarılı/90 dolu, 100/100, çift oy ve sayaç ihlali 0** |
| D WebSocket | 1000 STOMP bağlantısı, 500 çift, 90 sn | - | teslim 13 / 23 / 34 (ack p95 24) | bağlantı hatası 0 | - | 4000 mesaj gönderildi, 4000 teslim, kayıp 0; bağlantı kurma p95 10 ms |
| E yönetim | 8 yönetici + CSV | - | liste p95 ≤ 25 ms; `engagement` p95 1134, `overview` 166 | 0 | 0 | CSV ~35 bin satır / 4,2 MB: p50 122 ms, max 285 ms |
| A giriş patlaması | 500 eşzamanlı giriş (istemci 429'da `Retry-After` bekler) | - | giriş uçtan uca p50 18 s, p95 31 s; **aynı anda arka plan trafiği p95 110 ms** | 0 | 2081 (kasıtlı yük atma) | bcrypt ~12 giriş/sn (1 izin); 500'ü de girdi |
| H soğuk açılış | yeniden başlatır başlatmaz 150 VU | ~97 | 460 / 1410 / 2226 | 0 | 0 | aynı yük ısınmış JVM'de p95 ~13 ms |
| G uç başına | 32 VU kapalı döngü | notifications 619, menu 485, unread-count 441, communities 401, news 354, me/summary 296, calendar 255, conversations 196, feed top 195, events 191, messages 102, **search 93** | | 0 | 0 | tablo SUMMARY.md |

**Kapasite çıkarımı (bu makine):** p95 < 400 ms ile **~350 VU ≈ 300-340 RPS** (VU = ortalama 2 sn düşünme süreli kullanıcı); p95 < 100 ms için 300 VU. Doygunluk ~360 RPS: uygulama 2 çekirdek %100, PostgreSQL ~1,6 çekirdek ve Hikari 30/30 birlikte tükenir (ikinci darboğaz PG CPU).
**VPS çıkarımı (4 vCPU/8 GB, ÖLÇÜLMEDİ):** uygulama ve PG aynı 4 çekirdeği paylaşır; burada 2+2 çekirdek ~360 RPS verdi, VPS'te ~300-400 RPS beklenir (±%30; fsync/disk, Caddy/TLS ve ağ dahil değil). Gerçek kullanım: 5 bin aktif kullanıcının ~%10'u eşzamanlı = ~500 kullanıcı x 1 istek/5 sn ≈ **100 RPS** → **5 bin aktif kullanıcıda ~3x pay**. 20 bin kayıtlı kullanıcının zirvesi (~1500 çevrimiçi) ≈ 300 RPS: sınırda; o ölçekte arama önbelleği ve sorgu sayısı azaltma (kalan riskler 3-4) ya da ikinci uygulama örneği önerilir.

### Soğuk JVM (en büyük tek bulgu)

Aynı yük (150 VU) yeni başlamış JVM'de p50 460 ms / p95 1410 ms; ısınmış JVM'de p95 ~13 ms. İlk dakikalarda aynı iş 10-20 kat yavaş (`menu/today` tek başına dört dakikada 91 → 1156 RPS'e tırmandı): JIT (C2) derleyici iş parçacıkları aynı 2 çekirdeği paylaşıyor. Önlem: dağıtımı/yeniden başlatmayı düşük trafikte yapın, ilk 3-5 dk için yük dengeleyicide yavaş giriş ya da el ile ısıtma (`scripts/perf/load/run-load.sh` `WARM_MIN`), `docker-compose` `start_period` yeterli. Bu önlem olmadan "ilk koşu" tabloları yanıltıcıdır (eski sonuç dosyalarında soğuk koşular vardı).

### Darboğazlar ve düzeltmeler (önce / sonra)

| # | Bulgu (kök neden) | Düzeltme | Önce | Sonra |
|---|---|---|---|---|
| 1 | **Gönderi araması** (`PostSearchProvider`): `to_tsvector(body) @@ ... OR body ILIKE '%q%'` indekssiz; 30 bin gönderide paralel seq scan, her satırda `to_tsvector`. Yük altında tek çağrı 1,1-5,3 sn, arama p95 2,7-5 sn, PG CPU doygun | V800: `ld_post_body_fts` + `ld_post_body_trgm` (GIN); sorgu metni aynı (BitmapOr) | `EXPLAIN`: **562 ms** | **8,6 ms** (65x) |
| 2 | **Haber araması** (`NewsRepository`): `ts_rank` her eşleşen satırda `to_tsvector`'u yeniden hesaplıyordu (yük altında toplam DB süresinin ~%55'i: 2210 çağrı x 193 ms) | V800: saklı `news_item.search_vec` + GIN `ld_news_search_vec`; `VEC = n.search_vec` | `EXPLAIN` (tüm satırlar eşleşir): **24,3 ms**; nadir terim 1,6 ms | **1,4 ms** (17x); 0,4 ms |
| 3 | **Giriş patlaması**: 500 eşzamanlı bcrypt tüm çekirdekleri dolduruyor; aynı anda okuma isteği p95 **4,3 sn + 39 hata**, yenileme p95 4,6 sn | `BoundedPasswordEncoder`: en çok (çekirdek-1) eşzamanlı özet, 32 kişilik sıra, taşan/10 sn aşan anında 429 + `Retry-After: 3` | arka plan p95 4263 ms | arka plan **p95 110 ms**, 0 hata; giriş ~12/sn (4 çekirdekte ~37/sn) |
| 4 | **Anket oyu yarışı**: `PESSIMISTIC_WRITE` kilidi görünüm kurulana kadar tutuluyor; 300 eşzamanlı oy Hikari havuzunu dolduruyor (aktif 29-30/30, bekleyen 131) | `PollVoteService.vote`: doğrulama/seçenek çözümü kilitsiz, kilit yalnız yazma için, görünüm kilit sonrası | p95 2746 / max 2927 ms (lock_timeout 3 sn'ye 73 ms kala) | p95 2373 / max 2526 (**kısmi iyileşme**, bkz. kalan risk 1) |
| 5 | **JWT ayrıştırıcı** her istekte yeniden kuruluyordu (CPU profilinde `JwtService.parse` ~%4-6) | `JwtParser` alan olarak bir kez | - | tek başına ölçülmedi |
| 6 | **Havuz tükenmesinde 500**: DB 36 sn donunca `@Transactional` metotlar bağlantı alamayınca `CannotCreateTransactionException` işleyicide yoktu, istemci Spring varsayılan **500** (5 sn) alıyordu | `ApiExceptionHandler.dbTimeout`'a `CannotCreateTransactionException`/`TransactionTimedOutException` (503 `DB_TIMEOUT` + `Retry-After`) | 500 | 503 (birim testli; uçtan uca yeniden koşulmadı) |
| 7 | DB tamamen donarsa `statement_timeout` işleyemez; JDBC soket zaman aşımı yoktu | `socketTimeout=30`, `connectTimeout=10`, `tcpKeepAlive` | sınırsız | 30 sn (donma testi 36 sn'de havuz sınırı önce devreye girdi) |

Kontrol edilip **sorun çıkmayanlar:** `statement_timeout`/`lock_timeout` uygulama oturumunda etkin (kilit testi: `notification` 12 sn kilitlenince istek tam **3,0 sn**'de 503 `DB_TIMEOUT`); DB 5 sn dondurulunca (docker pause) süreç çökmedi, istek 4,8 sn sonra 200 döndü, yeniden başlama yok, sağlık UP; Redis 5 sn dondurulunca istek 5,5 sn bekleyip 200; yazma yolları p95 ≤ 39 ms; WebSocket 1000 bağlantıda kayıpsız; yönetici listeleri ve 35 bin satır CSV < 300 ms; veri bütünlüğü ihlali **0** (`integrity.txt`).

### Kalan riskler ve açık maddeler

1. **Tek ankete eşzamanlı oy:** satır kilidi seri işler (~120 oy/sn/anket). 300 aynı-anlı oy 2,4 sn; ~600+ aynı-anlı oy `lock_timeout` (3 sn) aşıp 503 verir ve havuzu doldurur (diğer kullanıcılar da etkilenir). Anketi push ile duyururken bildirimleri parça parça gönderin; kalıcı çözüm: oy sayaçlarını kilitsiz (kovalı sayaç/Redis) tutmak.
2. **Giriş patlaması:** 500 eşzamanlı giriş istemci geri çekilmesiyle ~30 sn'de biter (2 çekirdek). Mobil istemci 429 `Retry-After`'a saygı göstermeli. **Kampüs NAT:** hız sınırları IP başına (giriş 200/15 dk, yenileme 300/15 dk); yüzlerce kullanıcı tek NAT çıkış adresindeyse takılabilir (test `X-Forwarded-For` ile IP'leri ayırdığından bu riski ölçmez; ölçüm için tek IP'den tekrar koşun).
3. **Arama** en pahalı uç (~93 RPS, istek başına ~20 ms CPU, 5 sağlayıcı sırayla): sağlayıcıları paralel çalıştırın ya da herkese açık parçaları (haber/etkinlik/kulüp) 30 sn önbellekleyin (gönderi sonuçları kullanıcıya özgü engel süzgeci içerir, önbelleklenmez).
4. **CPU/istek ~15-20 ms** (küçük sorgu sayısı, Hibernate `IN (...)` listeli sorgularda plan yeniden çevirisi, Jackson): 2 çekirdekte tavan ~360 RPS. İlk adaylar: akış (`PostViewAssembler`, ~10 sorgu), sohbet listesi/geçmişi, `me/summary`.
5. Sohbet geçmişi 400 VU'da p95 677 ms: eski düz metin mesajlarda satır başına `SELECT body` (N+1, 30/istek) test verisinin yapaylığıdır (üretimde mesajlar şifreli); gerçek şifreli veriyle yeniden ölçülmeli. Not: 1,2 M mesajın şifreleme geçişi tek iş parçacığıyla ~290 satır/sn (1,2 M için ~70 dk); canlı sisteme sonradan açılırsa planlayın.
6. `PostRankService` 5 dakikada bir penceredeki TÜM gönderileri tek tek günceller (30 bin gönderide ~14 bin UPDATE/tur); haftalık gönderi sayısı yüzlerceyken önemsiz, on binlerce olursa toplu `UPDATE ... FROM` gerekir.
7. Yönetici `engagement` raporu p95 1,1 sn (seed zamanları rastgele; en kötü durum).
8. Migration sırası: V800 repoda V820'den düşük; `prod`'da `out-of-order=false` olduğundan V800'ü V820'den **önce** dağıtın.
9. Kapsam dışı/doğrulanmadı: gerçek VPS ağı/diski (fsync, SSD), Caddy/TLS yükü, ffmpeg/medya yükleme, FCM/SMTP, 20k eşzamanlı WebSocket (1000 test edildi), şifreli mesajlarla geçmiş okuması, madde 6'daki 503 düzeltmesinin uçtan uca doğrulaması.

### VPS'te yeniden ölçme

```bash
# staging (üretim veritabanı DEĞİL) + ayrı yük makinesi; ayrıntı: scripts/perf/load/README.md
export MODE=remote BASE=https://staging.ornek.net JWT_SECRET='<staging-sirri>' SEED=1 SCENARIOS="G B C D E"
export PSQL_CMD='ssh vps "docker compose -f docker-compose.prod.yml exec -T postgres psql -U bingol -d bingol"' K6_CMD='k6 run'
bash scripts/perf/load/run-load.sh            # sonuç: docs/perf-results/<tarih>/SUMMARY.md
```


## Sunucu önbelleği (C1)

Okuma ağırlıklı, **herkese aynı cevabı veren** uçlar veritabanına her istekte gitmesin diye servis katmanında önbelleklenir. Kod: `common/cache/` (`CacheService`, `CacheTier`, `CacheInvalidationListener`), ayarlar `app.cache.*` (`CacheProperties`), HTTP başlıkları `config/PublicCacheInterceptor`.

### Mimari
- **L1** JVM içi (LRU, en çok `l1-max-entries`=1000, tazelik `l1-ttl`=15 sn) + **L2** Redis üzerinde JSON (`cache:<ad>:<sürüm>:<anahtar>`, her kayıt TTL'li; `cache:<ad>:v` sürüm sayacı 7 gün TTL). Redis yoksa/hatadaysa yalnız L1 + yükleyici (10 sn L2 atlanır); istek asla düşmez.
- **Tek uçuş (single-flight)**: aynı anahtar için aynı anda tek yükleyici çalışır, diğerleri sonucu bekler (thundering herd yok; `load-wait` 10 sn, aşılırsa kendi yükler).
- **Stale-while-error**: yükleyici sunucu/altyapı hatası verirse (DB_TIMEOUT 503, bağlantı havuzu vb.) süresi dolmuş kayıt `stale-ttl`=1 sa içinde sunulur. İstemci hatası (4xx `ApiException`) maskelenmez; **geçersiz kılınmış kayıt asla bayat sunulmaz** (gizlenen haber hata anında bile görünmez).
- **Geçersiz kılma**: ad alanı sürümü artar (INCR) + L1 temizlenir; commit'ten SONRA çalışır (`afterCommit`), geri alınan işlemde çalışmaz. Yükleme sırasında olan geçersiz kılma o yüklemenin sonucunu önbelleğe sokmaz (eski sürüm anahtarı). Her açılışta (`ApplicationReadyEvent`) tüm ad alanları geçersiz kılınır: Redis kayıtları yeniden dağıtımdan sağ çıkar, **migration ile (SQL) değişen veri (ör. sözleşme metni) bayat kalmaz**.
- **Yazma yolu güvencesi**: `CacheInvalidationListener` (JPA `@EntityListeners`) ilgili varlıkta her ekleme/güncelleme/silmede ad alanını geçersiz kılar. Yönetici ucu, senkron işi, toplu işlem, dev tohum fark etmez; elle `invalidate` çağrısı unutulamaz. Kapsam dışı: JPQL `@Modifying`/JdbcTemplate yazımları (şu an bu tablolarda yalnız `DocumentRepository.deactivate`, hemen ardından `save` var). Yeni önbelleklenen veri = varlığa `@EntityListeners` + `CacheInvalidationListener.NAMESPACES` + `CacheService.NAMESPACES`.
- **Güvenlik**: ad alanı ve anahtar beyaz listeyle sınırlı (`[A-Za-z0-9:_.,=@-]{1,160}`; uygunsuzsa önbellek atlanır), anahtar yalnız doğrulanmış değerlerden (dil kodu, enum, sınırlı sayı, `YearMonth`) üretilir; kullanıcı arama metni (`q`) ASLA anahtar olmaz. Kişisel veri önbelleğe girmez (yalnız kurum ayarları, haber/menü/SSS/sözleşme metni, kategori adı). Tek kayıt `max-entry-bytes`=256 KB'ı aşarsa önbelleğe alınmaz. Rate limit, kimlik doğrulama, erişim engeli filtreleri **önbellekten önce** çalışır (önbellek yalnız servis sonucu seviyesinde).
- **Gözlem**: Micrometer `bu.cache.requests{ns,result}` (`hit_l1`, `hit_l2`, `hit_wait`, `miss`, `stale`, `error`, `bypass`, `invalidate`, `oversize`, `l2_corrupt`, `wait_fallback`); DEBUG günlüğü `cache <ad> <sonuç>`. Prometheus'ta isabet oranı: `sum(rate(bu_cache_requests_total{result=~"hit.*"}[5m])) / sum(rate(bu_cache_requests_total{result=~"hit.*|miss"}[5m]))`.
- **Acil kapatma**: `CACHE_ENABLED=false` (veya `app.cache.enabled=false`): her istek yükleyiciye (DB) gider, HTTP önbellek başlıkları eklenmez. Yönetici "önbelleği temizle" ucu YOKTUR (gerek yok: yazmalar otomatik geçersiz kılar, açılışta tam temizlik).

### Envanter
| Uç | Sınıf | Sunucu TTL | Anahtar | Geçersiz kılan yazma yolları | HTTP (`Cache-Control`) |
|---|---|---|---|---|---|
| `GET /api/news` (ilk 21 sayfa, `q` boş) | GÜNLÜK | 20 dk | `news:list:<tür\|all>:<sayfa>:<boyut>` | `NewsSyncService.syncType`/`retryMissingContent` (kayıt ekleme/güncelleme), `AdminNewsController.setHidden`, `NewsBulkService.run` | public 60 sn, swr 120 |
| `GET /api/news/{id}` (yalnız bulunan) | GÜNLÜK | 20 dk | `news:d:<id>` | aynı (gizleme anında 404) | public 300 sn |
| `GET /api/news?q=…`, derin sayfa | CANLI/kullanıcı girdisi | yok | - | - | 60 sn (ETag) |
| `GET /api/menu?month=`, `/menu/today` | GÜNLÜK | 20 dk (yok sonucu 60 sn) | `menu:m:<yyyy-MM>`, `menu:d:<tarih>` | `MenuSyncService.sync`, `MenuCalorieService.applyDay/applyBulk` (`menu_item_calorie`), `MenuAdminService.setImage/deleteImage`, `MenuBulkService.delete` | public 300 sn |
| `GET /api/status` | KISA | 5 dk | `status:v:<dil>` | `StatusService.markOk/markMaintenance` (`SyncStatus`) | public 30 sn |
| `GET /api/app/info`, `/api/app/version` | SABİT | 6 sa | `appinfo:all` (ayar haritası; dil yalnız projeksiyon) | `AppInfoService.set` (`PUT /api/admin/settings/{key}`) | public 60 sn |
| `GET /api/legal`, `/api/legal/{type}` | SABİT | 6 sa | `legal:s:<dil>`, `legal:c:<TÜR>:<dil>` (yer tutucular önbellekte HAM, sunumda doldurulur; mevcut 60 sn ayar önbelleği korunur) | `LegalService.publish` (yeni sürüm) | public 600 sn |
| `GET /api/faq` | SABİT | 6 sa | `faq:l:<dil>` | `FaqController` create/update/delete, `FeedbackAdminService.reorderFaq` | public 600 sn |
| `GET /api/communities/categories` (giriş gerekli, herkese aynı) | KISA | 5 dk | `categories:l:<dil>`, `categories:v` | `CommunityCategoryService` CRUD/sıralama; kulüp (`Community`) ekleme/güncelleme/silme (sayılar) | private 60 sn (Authorization var) |
| `GET /api/catalog/academic`, `/catalog/departments` | SABİT (zaten bellekte, classpath JSON) | - | - | - | mevcut: public 1 gün |

Authorization başlığı olan istekte `public` YOKTUR: `private, max-age=N` döner (paylaşımlı önbellek/CDN'e girmez). `Vary: Accept-Language` her zaman. Başlıklar yalnız GET + 200 yanıtlara ve `WebConfig` ETag filtresinin kapsadığı yollara eklenir (gövde tamponlu → başlık commit öncesi yazılır); 304 yolu da artık servis önbelleğinden beslenir (DB yok).

**Önbelleğe ALINMAYANLAR (bilinçli):** mesajlar, bildirimler, profil, üyelik/RSVP/oy durumu, okunmamış sayaçları, engel/gölge-engel filtreli her şey, `GET /api/events*` (kullanıcıya özel `myRsvp`/gizlilik; `events/featured` dahil), kulüp listesi/detayı (üyelik alanları), anketler (oy durumu), akademik takvim/sınav/duyuru akışı (kitle/bölüm filtreli), arama, `/api/legal/consents*`/`acceptance-status`. Bunların kullanıcıdan bağımsız alt parçaları ileride ayrıca önbelleklenebilir.

### Beklenen yük azalması (TAHMİN, ölçülmedi)
Ana sayfa/açılış yolundaki çağrılar (`app/info`, `status`, `menu/today`, `news` ilk sayfa, `faq`, `categories`) kullanıcıdan bağımsız olduğundan, TTL penceresi içinde istek sayısından bağımsız olarak **ad alanı/anahtar başına ~1 DB turu** kalır (20 dk'da bir, yazmada bir). 20k kullanıcı ve açılış başına ~5 bu tür çağrı varsayımıyla bu uçların DB sorgusunun **%95+ azalması** beklenir; toplam DB yükündeki payı (mesajlaşma/bildirim/yazma yolları baskın) bu varsayımla ~%10-25 aralığındadır. Gerçek etki için `bu_cache_requests_total` ve `pg_stat_statements` (önce/sonra) karşılaştırılmalıdır.

### Riskler ve dağıtım notları
- Çok örnekli çalışmada başka örneğin geçersiz kılması en geç `l1-ttl` (15 sn) sonra görülür (L2 sürümü anında). Tek örnekte yoktur.
- HTTP tarafı: yönetici değişikliği (haber gizleme, menü kalorisi) tarayıcı/CDN'de en geç `max-age` (30-600 sn) sonra yansır; sunucuda anında.
- Redis belleği: kayıtlar küçük (haber sayfası ~10 KB, sözleşme ≤256 KB, toplam tahmini <10 MB) ve TTL'li; `volatile-lru` politikasıyla uyumlu. Redis dolarsa L2 yazması hata verir → L1'e düşer.
- Bayat göstermek yerine hata tercih edilen durumlar: geçersiz kılınmış kayıt, 4xx. Kaynak sitede değişiklik olursa mevcut "bakımda" mekanizması (eski veri sunulur) aynen sürer.
- Dağıtım: yeni ortam değişkeni zorunlu değil (`CACHE_ENABLED` isteğe bağlı, compose'a eklendi). Deploy sonrası ilk istekler soğuktur (tüm ad alanları açılışta temizlenir); migration ile veri değişimi ek işlem gerektirmez.
