# Bingöl Üniversitesi Mobil Uygulaması — Ürün ve MVP Yol Haritası

Son güncelleme: 2026-10-23
Kapsam: `backend/` (Spring Boot 4.1.2, Java 17) ve `mobile/` (Flutter, Android).

---

## 1. Vizyon ve hedef kullanıcılar

### 1.1 Vizyon

Bingöl Üniversitesi topluluğunun (öğrenci, akademisyen, idari personel) günlük kampüs ihtiyaçlarını tek, hızlı ve güvenilir bir mobil uygulamada toplamak:

1. **Bilgi:** Resmi site (bingol.edu.tr) ve SKS (sks.bingol.edu.tr) içeriğini mobilde okunur, aranabilir ve bildirimli hale getirmek. Kaynak siteler çoğu zaman mobilde zahmetlidir; biz onları değiştirmeden okuyup sunarız.
2. **İletişim:** Yalnızca doğrulanmış `@bingol.edu.tr` hesaplarının bulunduğu kapalı bir ortamda mesajlaşma. Üyelik zaten alan adıyla sınırlı olduğu için "yalnızca üniversite mensupları" güvencesi ürünün temel farkıdır.
3. **Kampüs yaşamı:** Zamanla ders programı, akademik takvim, kampüs haritası gibi günlük kullanım alışkanlığı yaratan özellikler.

Not: Uygulama **resmi bir kurum uygulaması değildir** (şimdilik). Resmi içerik "kaynak: bingol.edu.tr" ibaresiyle ve orijinal sayfaya bağlantıyla gösterilir. Resmi statü, bir üniversite birimiyle (Bilgi İşlem Daire Başkanlığı / Strateji / Öğrenci İşleri) anlaşma gerektirir; bkz. Bölüm 3, açık sorular.

### 1.2 Hedef kullanıcılar ve temel ihtiyaçlar

| Kullanıcı | Temel ihtiyaç | Uygulamadan beklentisi | Not |
|---|---|---|---|
| **Öğrenci** (ana kitle, en kalabalık) | Duyuru/etkinlik kaçırmamak, bugünün yemeği, arkadaş/sınıf ile yazışma | Hızlı açılış, bildirim, WhatsApp'a alternatif değil tamamlayıcı olmalı | Ders/bölüm bazlı filtre en değerli özellik olacak |
| **Akademisyen** | Öğrencilere ulaşmak, duyuru takibi, meslektaşlarla yazışma | Düşük gürültü, güvenilir kimlik (hocanın gerçekten hoca olduğu belli olmalı) | Kimlik/rol ayrımı gerekir: e-posta alan adı öğrenci/personel ayrımını vermiyor olabilir (bkz. açık sorular) |
| **İdari personel** | Duyuru, etkinlik, personel yemeği, birimler arası iletişim | Basit arayüz, az özellik | Ana hedef olmayabilir; ilk sürümlerde özel özellik yok |

### 1.3 Ürün ilkeleri

- **Eski veri her zaman görünür:** Kaynak site çökse de uygulama son veriyi ve "bakımda" bandını gösterir (mevcut `GET /api/status` davranışı korunur).
- **Önce okuma, sonra yazma:** Kullanıcı içeriği (mesaj) üretmeyen özellikler önce gelir; çünkü moderasyon, hukuki ve operasyonel yükü yoktur.
- **Gizlilik varsayılanı kapalı:** Bir kullanıcının diğerleri tarafından bulunabilirliği ve ad/fotoğraf görünürlüğü kullanıcı kontrolünde olmalıdır.
- **Küçük ekip gerçekliği:** Her aşama, tek/iki geliştiriciyle bakımı yapılabilir olmalı. Yeni altyapı bileşeni (ör. mesaj kuyruğu, ayrı arama motoru) yalnızca zorunluysa eklenir.

---

## 2. MVP aşamaları

Efor ölçeği (tek tam zamanlı geliştirici varsayımıyla): **Küçük** ≈ 1–3 gün, **Orta** ≈ 1–2 hafta, **Büyük** ≈ 3–5 hafta. Tahminler test ve temel hata ayıklamayı içerir; mağaza yayını süreci ve hukuki metin hazırlığı dahil değildir.

### Önerilen sıralama (özet) ve gerekçe

Verilen ilk öneri (1 giriş → 2 mesajlaşma → 3 bildirim → 4 favori/arama → 5 grup/moderasyon) yerine şu sıralamayı öneriyorum:

| Sıra | Aşama | Önerilen fark |
|---|---|---|
| MVP-0 | Mevcut durum | Aynı |
| **MVP-0.5** | **Üretim hazırlığı (yeni)** | Mesajlaşmadan önce veri/altyapı borçlarını kapat |
| MVP-1 | Mobilde giriş/kayıt/doğrulama + token yenileme | Aynı, profil alanları (rol, bölüm) eklenir |
| **MVP-2** | **Bildirimler (FCM) + favori/filtre/arama** (eski 3 ve 4 birleşik) | **Mesajlaşmadan önce** |
| **MVP-3** | **Birebir mesajlaşma + temel engelle/raporla** | Eski 2; moderasyonun asgari kısmı içine alındı |
| MVP-4 | Grup/topluluk sohbetleri + tam moderasyon paneli | Eski 5 |
| Sonrası | Akademik takvim, ders programı, harita vb. | Aynı |

**Gerekçeler:**

1. **Bildirim ve arama, mesajlaşmadan önce gelmeli.** Bunlar mevcut içerik (haber/duyuru/yemek) üzerinde çalışır, kullanıcı içeriği üretmez, dolayısıyla moderasyon/KVKK/kötüye kullanım riski taşımaz. Kullanıcıya "uygulamayı günde birkaç kez aç" nedenini mesajlaşmadan daha düşük riskle verir. Mesajlaşma tek başına, kullanıcı sayısı kritik kütleye ulaşmadan (kimse mesajlaşacak kimseyi bulamaz) değer üretmez; duyuru bildirimi ise ilk günden değer üretir ve kullanıcıyı mesajlaşmaya getirecek kitleyi oluşturur.
2. **Engelleme ve raporlama, mesajlaşmanın ilk sürümüne dahil olmalı.** Gerçek isimli, kapalı bir topluluk içinde taciz ve spam ilk haftada ortaya çıkar. Google Play'in kullanıcı üretimli içerik (UGC) politikası da, kullanıcı içeriği barındıran uygulamalarda raporlama ve engelleme mekanizması bekler; yani bunlar "sonra eklenir" değil yayın şartıdır. Panel, otomatik filtre, ceza sistemi gibi ağır kısımlar MVP-4'e kalır.
3. **MVP-0.5 gerekli, çünkü mevcut kodda mesajlaşma öncesi kapatılması gereken somut borçlar var** (aşağıda).
4. **Favoriler ve bildirim aynı veri modelini kullanır** (kullanıcının abone olduğu kategori/konu). Ayrı aşamalarda yazılırsa aynı tablo iki kez tasarlanır.

---

### MVP-0 — Mevcut durum (tamamlandı, referans)

**Var olanlar**
- Backend: haber/duyuru/etkinlik scraping (`news` paketi, her gece 00:00, `news.sync.cron`), yemek listesi scraping (`menu` paketi, ayın son günü 23:30), `status` paketi ile kaynak başına `maintenance` bayrağı.
- REST: `GET /api/news`, `/api/news/{id}`, `/api/menu`, `/api/menu/today`, `/api/status`.
- Üyelik: `/api/auth/register`, `resend-code`, `verify-email`, `login`, `refresh`, `logout`, `me`. Yalnızca `@bingol.edu.tr`, 6 haneli e-posta kodu, JWT access + opak refresh token (Redis), BCrypt, Redis tabanlı rate limit (Bucket4j; kayıt, giriş, kod doğrulama IP ve e-posta bazlı).
- Mobil: 4 sekme (Haberler, Duyurular, Etkinlikler, Yemek), sonsuz kaydırma, çekerek yenileme, "bakımda" bandı, detay sayfası, kaynak sayfayı açma.
- WebSocket (STOMP) ve Redis bağımlılıkları pom.xml'de var; mesajlaşma kodu yok.

**Bilinen eksikler/borçlar (MVP-0.5'in girdisi)**
- `User` varlığında rol, bölüm/fakülte, profil durumu alanı yok (`id, email, passwordHash, displayName, emailVerified, createdAt`). Yönetim uçları `/api/admin/**` için `hasRole("ADMIN")` + Basic auth (`spring.security.user.*`) kullanılıyor; JWT içinde rol kavramı yok. Öğrenci/akademisyen/personel ayrımı yapılamıyor.
- Mobil `apiBase` sabit `http://10.0.2.2:8080/api` (yalnızca emülatör, düz HTTP). Ortam yapılandırması ve HTTPS yok.
- README "Spring Boot 3" diyor; pom.xml `4.1.2` (Spring Boot 4). Dokümantasyon güncel değil.
- Veri tabanı geliştirme için H2; şema yönetimi (Flyway/Liquibase) görünmüyor. Mesaj tablosu gibi büyüyen veriler için migration şart.
- Test kapsamı belirsiz (yalnızca test starter'ları eklenmiş). Scraper'lar için sabit HTML örneğiyle test yoksa, kaynak site değişimi sessizce veri bozabilir.
- Haber içeriği (`content`) mobilde düz metin gösteriliyor; HTML/resim içeren haberler eksik görünebilir.

---

### MVP-0.5 — Üretim hazırlığı (önerilen yeni aşama)

**Hedef:** Kullanıcı verisi toplamaya başlamadan önce altyapıyı kalıcı ve güvenli hale getirmek.

**Kapsam**
- PostgreSQL'e geçiş (prod profili), Flyway ile şema migration'ları (mevcut tablolar baseline).
- `User`'a `role` (`STUDENT`, `STAFF`, `ACADEMIC`, `ADMIN`) ve `status` (`ACTIVE`, `SUSPENDED`) alanları. Rol başlangıçta kayıt sırasında kullanıcı beyanıyla, "doğrulanmamış" olarak etiketlenir; JWT'ye `role` claim'i eklenir. Basic auth ile admin yerine JWT + `ADMIN` rolüne geçiş.
- Ortam yapılandırması: Redis ve DB için prod `application-prod.yml`, JWT gizli anahtarı ortam değişkeninden, SMTP ayarları, CORS/HTTPS (ters vekil arkasında TLS).
- Mobil: `--dart-define` ile `API_BASE`; Android `usesCleartextTraffic` yalnızca debug.
- Scraper güvenliği: kaynak HTML'den alınan örnek sayfalarla birim testleri ("sabit fixture"), istek aralığı ve `User-Agent` politikası, hata durumunda `maintenance` bayrağı.
- Günlük (log) politikası: e-posta ve kod loglanmaz.
- README'yi güncelle (Spring Boot sürümü, yeni API'ler).
- KVKK taslağı: aydınlatma metni, gizlilik politikası, saklama süreleri (bkz. Bölüm 3).

**Kapsam dışı:** Yeni son kullanıcı özelliği, mesajlaşma, bildirim.

**Kabul kriterleri**
- Sunucu yeniden başlatıldığında kullanıcılar, haberler, yemek verisi kaybolmaz (PostgreSQL).
- Boş bir veritabanına `flyway migrate` ile tüm şema sıfırdan kurulur; CI'da bu test çalışır.
- `/api/admin/sync` yalnızca `ADMIN` rollü JWT ile çağrılır; Basic auth devre dışı (prod).
- Her iki scraper için, kayıtlı HTML örneğiyle çalışan en az birer test vardır ve "beklenen yapı yoksa boş liste + `maintenance`" davranışı test edilmiştir.
- Mobil uygulama, tek bir derleme parametresiyle prod API adresine bağlanabilir.

**Efor:** Orta
**Bağımlılıklar:** Bir barındırma ortamı (VPS/bulut), alan adı, SMTP hesabı (üniversite SMTP'si ya da Gmail/Brevo vb. gönderici; `@bingol.edu.tr` adreslerine teslim edilebilirlik test edilmeli).

---

### MVP-1 — Mobilde giriş / kayıt / e-posta doğrulama + token yenileme

**Hedef:** Kullanıcı uygulamadan hesap açıp giriş yapabilsin, oturumu açık kalsın; backend'deki mevcut auth uçlarının tamamı mobilde kullanılsın.

**Kapsam**
- Ekranlar: karşılama, kayıt (ad, e-posta, parola, rol beyanı), 6 haneli kod girişi (yeniden gönder + geri sayım), giriş, "parolamı unuttum" (bkz. aşağıda), profil (ad, rol, çıkış).
- Token saklama: `flutter_secure_storage` (access + refresh). Access token yalnızca bellekte tutulabilir.
- HTTP istemcisi: `Authorization` başlığı ekleyen tek bir sarmalayıcı; 401 alınca tek seferlik (eşzamanlı isteklerde kilitli) `POST /api/auth/refresh`, başarısızsa girişe yönlendirme. Refresh rotasyonu backend'de varsa yeni refresh token'ın saklanması.
- Uygulama açılışında oturum durumu: token varsa `GET /api/auth/me` ile doğrula, yoksa karşılama.
- Misafir modu: haber/yemek **girişsiz** okunabilir kalır (SecurityConfig'te zaten `permitAll`). Giriş yalnızca mesajlaşma/bildirim kişiselleştirme gibi özellikler için istenir. Bu, kullanıcı kazanımı için kritik: ilk açılışta zorunlu kayıt duvarı koymayız.
- Hata mesajları Türkçe ve belirli: geçersiz alan adı ("Yalnızca @bingol.edu.tr"), yanlış kod, hız sınırı aşıldı (HTTP 429 → "X dakika sonra tekrar deneyin").
- Backend eki: **parola sıfırlama** (`POST /api/auth/forgot-password`, `reset-password`; aynı 6 haneli kod mekanizması, rate limit'li) ve **hesap silme** (`DELETE /api/auth/me`; KVKK için, bkz. Bölüm 3). Backend'de bu uçlar yoksa eklenir.

**Kapsam dışı:** Sosyal giriş (Google/Apple), biyometrik kilit, çok cihaz yönetimi ekranı, profil fotoğrafı, iki faktörlü doğrulama.

**Kabul kriterleri**
- Yeni kullanıcı: kayıt → e-postadaki kod → doğrulama → otomatik giriş akışı, 2 dakikada tamamlanabiliyor (gerçek `@bingol.edu.tr` kutusuyla denendi).
- `@gmail.com` ile kayıt denemesi sunucu ve istemcide anlaşılır hata veriyor.
- Access token süresi doldurulmuş senaryoda (test için kısa TTL) kullanıcı fark etmeden yenileme oluyor; refresh geçersizse giriş ekranına dönüyor; aynı anda 3 istek 401 alsa bile tek refresh çağrısı yapılıyor.
- Çıkış yapınca refresh token Redis'ten siliniyor (`/logout`), cihazda veri kalmıyor.
- Uygulama kapatılıp açıldığında oturum korunuyor.
- Parola sıfırlama ve hesap silme uçtan uca çalışıyor; silinen hesabın e-postasıyla yeniden kayıt mümkün.
- Widget/entegrasyon testi: giriş, 401→refresh→tekrar dene akışı.

**Efor:** Orta
**Bağımlılıklar:** MVP-0.5 (rol alanı, prod SMTP). SMTP teslim edilebilirliği; kodun spam'e düşmesi en büyük kayıt kaybı nedenidir.

---

### MVP-2 — Bildirimler (FCM) + favoriler / kategori filtreleri / arama

**Hedef:** Kullanıcının ilgilendiği içeriği kaçırmaması; uygulamaya geri dönüş nedeni üretmek.

**Kapsam — Bildirim**
- Firebase projesi, Android `google-services.json`, `firebase_messaging` (mobil); backend'de FCM HTTP v1 (Firebase Admin SDK) ile gönderim.
- `device_token` tablosu (kullanıcı, token, platform, son görülme); giriş yapınca kaydet, çıkışta sil, FCM "geçersiz token" yanıtında temizle. Misafir kullanıcılar için anonim token + konu (topic) abonelikleri de desteklenmeli, çünkü içerik girişsiz okunuyor.
- Tetikleyici: `NewsSyncService` gece senkronundan sonra **yeni** kayıtlar (daha önce DB'de olmayanlar) için bildirim. İlk doldurmada (boş DB) bildirim **gönderilmez** (yoksa tüm arşiv için bildirim gider).
- Toplu gönderim: gece 00:00'da bildirim göndermek kullanıcıyı uyandırır. Bildirimler günlük bir saat penceresine (ör. 09:00) ertelenir veya özet halinde gönderilir ("3 yeni duyuru").
- Bildirim tercihleri ekranı: Haber / Duyuru / Etkinlik anahtarları; yemek hatırlatması (ör. 11:30 "Bugün yemekte: ...", isteğe bağlı).
- Bildirime dokununca ilgili detay sayfasına yönlendirme (data payload'da `newsId`).

**Kapsam — Favoriler / filtre / arama**
- Favori: `user_favorite(user_id, news_id, created_at)`; `POST/DELETE /api/me/favorites/{newsId}`, `GET /api/me/favorites`. Mobilde yıldız simgesi ve "Kaydedilenler" sayfası. Favoriler girişsizken yerelde (cihazda) tutulup girişte senkronlanabilir (ikinci aşama olarak bırakılabilir).
- Filtre: tarih aralığı ve (varsa) kaynak birim/kategori. Önce kaynak sitede hangi kategorilerin gerçekten ayrıştırılabildiği doğrulanmalı (bkz. açık sorular); ayrıştırılamıyorsa yalnızca tür + tarih filtresi sunulur.
- Arama: başlangıç için PostgreSQL ile yeterli. `title`/`content` üzerinde `pg_trgm` + GIN indeksi veya Türkçe `to_tsvector('turkish', ...)`; `GET /api/news?q=...`. Türkçe karakter ve büyük/küçük harf (İ/ı) duyarsızlığı açıkça test edilmeli. Ayrı bir arama motoru (Elasticsearch vb.) **eklenmez**; hacim buna ihtiyaç duyurmuyor.

**Kapsam dışı:** iOS bildirimleri (iOS hedeflenirse APNs yapılandırması ayrı iş), e-posta bildirimi, kişiye özel öneri, bölüm bazlı hedefleme (veri kaynağı yoksa), ses/zengin bildirim.

**Kabul kriterleri**
- Yeni bir duyuru senkronlandıktan sonra, ilgili tercihi açık kullanıcıların cihazlarına en geç 15 dakika içinde bildirim ulaşır (test cihazı ve topic ile ölçülür).
- Aynı duyuru için aynı cihaza birden fazla bildirim gitmez (idempotans: bildirimin gönderildiği haber ID'si kaydedilir).
- Boş DB'de ilk doldurma sırasında hiç bildirim gönderilmez (otomatik test).
- Geçersiz token'lar bir sonraki gönderimde temizlenir.
- Arama: "burs", "Burs", "BURS" ve "bursu" gibi biçimler anlamlı sonuç döndürür (Türkçe stemming ile); 10 bin kayıtta p95 < 300 ms.
- Favori ekleme/çıkarma çevrimdışıyken kuyruğa alınmaz ama hata kullanıcıya açıkça gösterilir.

**Efor:** Büyük (bildirim ≈ orta, favori+arama ≈ orta; ikisi paralel yürütülebilir)
**Bağımlılıklar:** MVP-1 (kimlik, cihaz-kullanıcı eşlemesi); Firebase hesabı; Google Play geliştirici hesabı (bildirim izin akışı Android 13+ `POST_NOTIFICATIONS` için); prod PostgreSQL.

---

### MVP-3 — Birebir mesajlaşma (WebSocket/STOMP + Redis pub/sub) + temel engelle/raporla

**Hedef:** İki doğrulanmış kullanıcı birbirine gerçek zamanlı ve güvenilir şekilde yazabilsin; çevrimdışı kalan mesajı kaybetmesin.

**Kapsam — Backend**
- Veri modeli: `conversation(id, user_a, user_b, created_at, last_message_at)` (iki kullanıcı için benzersiz çift kısıtı, küçük ID önce), `message(id, conversation_id, sender_id, body, created_at, client_msg_id, delivered_at?, read_at?)`; indeks `(conversation_id, id DESC)`.
- STOMP over WebSocket (`/ws`), el sıkışmada JWT doğrulaması (`ChannelInterceptor` ile CONNECT'te; süresi dolan token için bağlantı kapatılıp istemci refresh sonrası yeniden bağlanır). Hedefler: `/app/chat.send`, kişiye özel `/user/queue/messages`, `/user/queue/receipts`.
- Çok örnekli çalışma: Spring'in basit bellek içi broker'ı yerine Redis pub/sub ile dağıtım. Not: Spring'in STOMP "full broker relay"i RabbitMQ/ActiveMQ gibi STOMP broker ister; Redis pub/sub bunu doğrudan karşılamaz, bu yüzden Redis kanalına yayınlayan ve her örnekte dinleyip yerel kullanıcı oturumlarına ileten bir **özel köprü** yazılır. Tek sunucuyla başlanıp köprü, ikinci örnek gerçekten gerektiğinde eklenebilir (Redis zaten var; bu iş en riskli teknik kalem, bkz. riskler).
- Mesaj kalıcılığı: önce DB'ye yaz, sonra dağıt (kaybolmayan mesaj). `client_msg_id` ile idempotans (yeniden gönderimde çift mesaj oluşmaz).
- REST: `GET /api/conversations` (son mesaj + okunmamış sayısı), `GET /api/conversations/{id}/messages?before=<id>&size=30` (imleç tabanlı sayfalama), `POST /api/conversations` (kullanıcıyla sohbet başlat), `POST /api/conversations/{id}/read` (okundu işareti).
- Okundu bilgisi: "iletildi" (alıcı bağlıyken veya cihaz alınca) ve "okundu" (sohbet ekranı açıkken) durumları; yazıyor göstergesi **kapsam dışı**.
- Çevrimdışı mesaj: alıcı çevrimdışıysa mesaj DB'de bekler; bağlanınca/uygulama açılınca `GET .../messages?after=<lastId>` ile eksikler çekilir; MVP-2'deki FCM altyapısıyla "yeni mesaj" bildirimi gönderilir (içerik önizlemesi kullanıcı ayarına bağlı; varsayılan "Yeni mesajınız var").
- Rate limit (mevcut Bucket4j/Redis): kullanıcı başına dakikada N mesaj (öneri 30), saniyede en fazla birkaç; mesaj uzunluğu üst sınırı (ör. 2000 karakter); yeni hesaplar için daha sıkı sınır; günlük yeni sohbet başlatma sınırı (ör. 20).
- **Temel moderasyon:** `block(blocker, blocked)` ve `report(reporter, message_id/user_id, reason, details, status)`. Engellenen kullanıcı engelleyene mesaj gönderemez (sunucuda zorunlu kılınır, sessizce reddedilir), sohbet listesinden gizlenir. Raporlar bir `ADMIN` uçta listelenir (panel yok; ilk aşamada SQL/basit admin ucu yeterli).
- Kullanıcı arama/keşfi: kullanıcı e-posta ile (tam eşleşme) ya da görünen ad ile bulunur; **tüm kullanıcı listesi dönülmez** (taramaya karşı). Bulunabilirlik ayarı: "Beni arama sonuçlarında göster" (varsayılan kapalı veya kullanıcıya sorulur).

**Kapsam — Mobil**
- Sohbet listesi, sohbet ekranı (ters sıralı liste, imleç tabanlı eski mesaj yükleme), gönderiliyor/iletildi/okundu simgeleri, yeniden bağlanma (üssel geri çekilme + jitter), uygulama arka plana atılınca bağlantıyı kapatıp FCM'e güvenme, yerel önbellek (SQLite/drift veya hive) ile çevrimdışı okuma.
- Mesaja uzun basınca "Raporla", sohbet menüsünde "Engelle".

**Kapsam dışı:** Resim/dosya/ses gönderimi (depolama + zararlı içerik taraması gerektirir), uçtan uca şifreleme (sunucu moderasyonu ile çelişir; bunun yerine aktarımda TLS + saklamada erişim kontrolü), mesaj düzenleme/silme (yalnızca "benden sil" sonraya), yazıyor göstergesi, çevrimiçi durumu (presence), mesaj arama, yanıt/tepki, sesli/görüntülü arama.

**Kabul kriterleri**
- İki gerçek cihaz arasında bağlıyken mesaj teslim gecikmesi p95 < 1 sn (aynı bölgede barındırılan sunucu).
- Alıcı çevrimdışıyken gönderilen 50 mesaj, alıcı uygulamayı açtığında sırayla ve eksiksiz görünür; hiçbiri çift veya kayıp değil (otomatik test: bağlantı kes–gönder–bağlan).
- Gönderen ağ kesintisinde aynı mesajı yeniden denerse sunucuda tek kayıt oluşur (`client_msg_id`).
- Geçersiz/süresi dolmuş JWT ile STOMP CONNECT reddedilir; başka bir kullanıcının sohbetine abone olma/mesaj çekme denemesi 403 ile sonuçlanır (yetkilendirme testi, IDOR).
- Engellenen kullanıcı mesaj gönderemez; engel kaldırılınca yeniden gönderebilir.
- Rate limit aşıldığında istemciye anlaşılır hata dönülür; sunucu çökmez (kaba yük testi: 200 eşzamanlı bağlantı, ortalama bir VPS).
- Sunucu yeniden başlatılınca istemci otomatik yeniden bağlanır ve eksik mesajları çeker.
- Rapor oluşturulabiliyor ve admin ucu üzerinden listelenebiliyor.

**Efor:** Büyük (muhtemelen 4–5 hafta; WebSocket güvenilirliği ve mobil yeniden bağlanma mantığı en çok zaman alan kısımlardır)
**Bağımlılıklar:** MVP-1, MVP-2 (FCM, cihaz token'ları), MVP-0.5 (PostgreSQL, Flyway). Kullanıcı keşfi için gizlilik kararı (açık sorular). Hukuki metinler (kullanım koşulları, topluluk kuralları) yayından önce hazır olmalı.

---

### MVP-4 — Grup / topluluk sohbetleri ve tam moderasyon

**Hedef:** Bölüm, sınıf ve öğrenci topluluğu odaklı grup sohbetleri; topluluğun kendi kendini yönetebilmesi ve ekibin kötüye kullanımı yönetebilmesi.

**Kapsam**
- Veri modeli: `chat_room(type: GROUP|COMMUNITY, name, description, visibility: PUBLIC|PRIVATE, owner_id)`, `room_member(role: OWNER|MODERATOR|MEMBER, muted_until, joined_at)`. 1:1 sohbetler aynı mesaj tablosunu kullanacak şekilde `conversation` → `room` olarak genelleştirilir (MVP-3 tasarımında buna açık bırakılmalı, yoksa göç gerekir).
- Oda oluşturma: başlangıçta yalnızca `ADMIN`/onaylı kullanıcılar (kontrolsüz oda çoğalmasını önler); resmi odalar (bölüm, fakülte) admin tarafından açılır.
- Katılım: açık odaya doğrudan, özel odaya davet bağlantısı/kodu. Üye sayısı üst sınırı (ör. 500) ve büyük odalarda yazma hızı sınırı.
- Mesaj dağıtımı: odalara fan-out Redis pub/sub kanalı üzerinden; gelmeyen üyeler için okunmamış sayacı (mesajın her üyeye ayrı satırı **tutulmaz**; üye başına `last_read_message_id` yeterli).
- Moderasyon (sahip/moderatör): üyeyi susturma, çıkarma, mesaj silme, odayı kilitleme, sabitlenmiş duyuru.
- Moderasyon (platform): admin web paneli veya en azından yetkili uçlar: rapor kuyruğu (açık/çözüldü), kullanıcıyı askıya alma (`status = SUSPENDED` → refresh token'ları iptal, WebSocket bağlantısı kapatılır), içerik silme, denetim kaydı (kim neyi ne zaman yaptı). Raporlama gerekçeleri (spam, taciz, uygunsuz içerik, kimliğe bürünme).
- Otomatik koruma: tekrar eden aynı mesaj / bağlantı spam'i tespiti, yeni üyeler için bağlantı gönderme kısıtı, basit yasaklı sözcük listesi (yönetilebilir yapılandırma).
- Bildirim denetimi: oda başına sessize alma.

**Kapsam dışı:** Ses/video odaları, anketler, dosya paylaşımı, bot/entegrasyon API'si, yapay zekâ ile içerik denetimi, kanal/alt başlık (thread) yapısı, topluluk başvuru iş akışı.

**Kabul kriterleri**
- 200 üyeli odada bir mesaj tüm çevrimiçi üyelere p95 < 2 sn'de ulaşır; çevrimdışı üyeler FCM ve geri yükleme ile alır.
- Susturulmuş üye gönderemez, çıkarılan üye geçmişi/odayı göremez (sunucuda yetki kontrolü, testli).
- Askıya alınan kullanıcının açık WebSocket'i en geç 1 dakikada kapanır ve yeniden giriş yapamaz.
- Her rapor için bir admin eylemi (kapat/uyar/askıya al) kaydedilir; rapor ilk yanıt süresi hedefi 48 saat (insan süreci için de sahibi belirlenmiş olmalı).
- Yetkisiz kullanıcı özel odanın mesajlarını okuyamaz (IDOR testi).

**Efor:** Büyük
**Bağımlılıklar:** MVP-3. Moderasyonu yürütecek **insanlar** (kim bakacak, hangi saatte; bu kod değil operasyon bağımlılığıdır). Resmi odalar için üniversite birimleriyle anlaşma.

---

### Sonrası (öncelik sırası önerisiyle; her biri ayrı MVP olarak planlanır)

| Özellik | Değer | Zorluk / bağımlılık | Not |
|---|---|---|---|
| **Akademik takvim** | Yüksek, düşük risk | Küçük–orta; veri kaynağı: resmi PDF/sayfa. Büyük olasılıkla bir kez elle girilen yıllık veri (`academic_event` tablosu) | Takvimi cihaz takvimine ekleme, sınav haftası hatırlatıcısı |
| **Ders programı** | Çok yüksek (öğrenci için günlük kullanım) | Büyük; veri kaynağı belirsiz (OBS/UBYS entegrasyonu üniversite iznine bağlı; scraping öğrenci oturumu gerektirir ve **önerilmez**) | Kullanıcının dersleri elle seçmesi (manuel giriş) bir ara çözümdür; resmi entegrasyon için üniversite ile API anlaşması |
| **Kampüs haritası / yönlendirme** | Orta (yeni öğrenci, ziyaretçi) | Orta; bina koordinatları elle toplanır, `google_maps_flutter` veya OpenStreetMap (`flutter_map`) | Çevrimdışı karo (tile) önbelleği zor; OSM ile başlamak maliyet açısından güvenli |
| **Yemek geliştirmeleri** | Orta | Küçük | Kalori/alerjen (kaynakta varsa), "bugünün yemeği" widget'ı, yemek puanlama |
| **Personel/akademisyen rehberi** | Orta | Orta; kaynak sitelerde herkese açık iletişim bilgisi varsa listelenebilir (KVKK ve kurum onayı gerekli) | Telefon/e-posta kopyala-ara |
| **Ring/servis saatleri, ulaşım** | Orta | Küçük–orta; veri elle girilir | |
| **Kütüphane, sınav sonuçları, ilan/kulüp panosu** | Değişken | Entegrasyon bağımlı | Pano, UGC moderasyonu gerektirir |
| **iOS sürümü** | Yüksek (kitle) | Orta; Apple Developer ücreti, APNs | Flutter kod tabanı hazır, mağaza süreci iş yükü |
| **Çok dillilik (EN/AR)** | Düşük–orta | Küçük | Uluslararası öğrenciler için |
| **Yönetim web paneli** | Gerekli hale gelir | Orta | MVP-4'te asgari düzeyde başlar |

---

## 3. Riskler ve açık sorular

### 3.1 KVKK / kişisel veri

Bu uygulama e-posta, ad, (ileride) rol/bölüm, cihaz token'ı ve **özel yazışma içeriği** işler. KVKK kapsamında veri sorumlusu kim olacak sorusu cevaplanmadan yayın yapılmamalı.

| Konu | Risk / gereksinim | Önerilen yaklaşım |
|---|---|---|
| Veri sorumlusu | Uygulamayı kim işletiyor: kişi, öğrenci topluluğu mu, üniversite mi? Sorumluluk ve iletişim bilgisi belirsiz | Yayından önce işletici ve sorumlu netleştirilir; aydınlatma metninde yazılır. Üniversite sahipliği alırsa üniversitenin KVKK birimi sürece dahil olur |
| Aydınlatma metni ve açık rıza | Kayıt ekranında aydınlatma metni; mesaj içeriği ve bildirim tercihleri için ayrı bilgilendirme | Rıza onay kutusu, sürümlü metin, kabul zamanı `user_consent` tablosunda |
| VERBİS | Veri sorumlusu sicil yükümlülüğü eşiğe (çalışan sayısı/mali) bağlıdır | Hukuki görüş al |
| Veri minimizasyonu | Yalnızca gerekli alan: e-posta, ad, rol | Telefon, TC kimlik no, öğrenci no **toplanmaz** |
| Saklama süresi | Mesajlar ne kadar tutulur? Silinen hesabın verisi? | Öneri: hesap silmede kişisel veri silinir/anonimleştirilir (mesajlar karşı tarafta "Silinmiş kullanıcı" olarak kalabilir); mesaj saklama süresi politikaya yazılır (ör. 12 ay sonra silme/anonimleştirme) |
| Silme ve erişim hakkı | Kullanıcı verisini görme/silme talebi | MVP-1'de hesap silme; "verilerimi indir" sonraya (yasal talep gelirse manuel) |
| Özel yazışmaya erişim | Yöneticiler mesajları okuyabilir mi? | Varsayılan: **hayır**. Yalnızca raporlanan mesajlar ve çevresindeki sınırlı bağlam moderatöre gösterilir; erişimler denetim kaydına yazılır. Kullanıcıya bu açıkça söylenir |
| Aktarım ve depolama | Firebase (FCM) yurtdışı sunucu kullanır; barındırma konumu | Bildirimde yalnızca asgari veri (mesaj içeriği değil); yurt dışına aktarım KVKK m.9 kapsamında aydınlatma/rızaya yansıtılır. Barındırma için Türkiye veya AB bölgesi tercih edilir |
| Güvenlik | Parola BCrypt, JWT, TLS, Redis'te token | Redis kalıcılığı ve şifreli yedekleme, DB yedek şifrelemesi, erişim günlükleri; ihlal bildirimi prosedürü (72 saat) yazılı olmalı |
| Reşit olmayanlar | Üniversite öğrencileri çoğunlukla reşit; ancak 18 yaş altı olabilir | Kullanım koşullarında yaş beyanı; şüphede hukuki görüş |
| Öğrenci/personel ayrımı verisi | Rol beyanı kişisel veri | Doğrulanmış rol (kurumdan gelen) ile beyan edilen rol ayrı gösterilir; yanlış beyan yaptırımı koşullarda yazılır |

### 3.2 Kaynak sitelerin yapısı ve scraping — hukuki / etik / teknik

| Risk | Etki | Önlem |
|---|---|---|
| **HTML yapısı değişir** (bingol.edu.tr, sks.bingol.edu.tr tema veya CMS değişikliği) | Scraper sessizce boş/yanlış veri üretir | Fixture testleri; ayrıştırma sonucu beklenenden çok az ise (ör. 0 kayıt veya >%70 düşüş) **eski veriyi silme**, `maintenance` bayrağını aç, yöneticiye uyarı (e-posta/log). Zaten "hata verme, eski veriyi sun" ilkesi var; buna "anormal sonuç = hata" kontrolünü ekle |
| **Hukuki durum** | Üniversite içeriği telif/kullanım koşuluna tabi olabilir; `robots.txt` ve site şartları kontrol edilmeli | Yalnızca herkese açık sayfalar, düşük sıklık (gecede bir), tanımlayıcı `User-Agent` ve iletişim adresi, başlık/özet + **kaynağa bağlantı** (tam metni yeniden yayınlamama veya kaynağı açıkça belirtme), görselleri kaynaktan hotlink yerine aynen kaynak URL ile gösterme. Şu an detayda `content` tam metin gösteriliyor; bu telif açısından değerlendirilmeli |
| **Etik / kurum ilişkisi** | Kurumun izni olmadan "resmiymiş gibi" görünme | Uygulama içinde "Resmi uygulama değildir; içerik bingol.edu.tr'den alınmıştır" notu; mümkünse Bilgi İşlem'den yazılı onay ya da bir RSS/JSON besleme/API talebi |
| **IP engelleme** | Sunucu IP'si kaynak tarafından engellenebilir | Düşük hacim, makul zaman aşımı; engelde `maintenance` + yöneticiyi bilgilendirme. Kalıcı çözüm üniversiteden resmi besleme almak |
| **Yemek listesi formatı** | Ayın son günü 23:30 tek sefer çekim; o gün hata olursa ay boyunca veri yok | Başarısızlıkta saatlik yeniden deneme (örn. ertesi gün 08:00'e kadar), manuel `POST /api/admin/sync-menu` yedeği, ayın ilk gününde "liste yok" kontrolü |
| **İçerik güvenliği** | Kaynaktan gelen HTML'de betik/zararlı bağlantı | HTML'i temizle (jsoup `Safelist`), mobilde yalnızca düz metin/güvenli biçimler |

### 3.3 Kötüye kullanım ve spam

| Tehdit | Mevcut | Eklenecek |
|---|---|---|
| Toplu sahte kayıt / kod bombardımanı (e-posta gönderimi maliyeti, SMTP itibarı) | IP bazlı rate limit (kayıt 10/saat, tekrar kod 10/saat), e-posta alan adı kısıtı | E-posta başına kod gönderim sınırı (şu an `resend` yalnızca IP bazlı görünüyor), CAPTCHA/cihaz doğrulama (Play Integrity) gerekirse; kod deneme sayısı sınırı (kod başına en çok 5 yanlış) |
| Başkası adına hesap açma | Kod e-postaya gidiyor, kutu sahibini doğrular | `@bingol.edu.tr` kutusunun bir kişiye ait olduğu varsayılır; ortak/bölüm kutuları kayıt olabilir (bkz. açık sorular) |
| Mesaj spam'i / taciz | — | MVP-3: kullanıcı başı hız sınırı, engelle/raporla; MVP-4: otomatik tespit, askıya alma |
| Kimliğe bürünme (sahte "Prof. X") | Görünen ad serbest | Görünen ad doğrulanmış rol rozetiyle birlikte gösterilir; ad değiştirme sınırlı; resmi odalarda yalnızca admin onaylı hesaplar |
| Hesap ele geçirme | Parola + e-posta | Parola sıfırlamada tüm refresh token'lar iptal, giriş denemesi sınırı (var), şüpheli giriş bildirimi (sonra) |
| WebSocket kaynak tüketimi | — | Kullanıcı başına bağlantı sayısı sınırı, mesaj boyutu sınırı, kimlik doğrulamasız bağlantıyı kısa sürede kapatma |
| Enumeration (hangi e-posta kayıtlı) | `resend-code` yanıtı "hesap uygunsa" diyerek genel | Giriş/kayıt/sıfırlama yanıtlarında aynı genel ifade ve eşit yanıt süreleri |

### 3.4 Ölçekleme ve operasyon

- **Gerçekçi ölçek:** Üniversite öğrenci+personel sayısı on binler mertebesinde; eşzamanlı WebSocket bağlantısı muhtemelen yüzler (bin) düzeyini geçmez. **Tek sunucu + Redis + PostgreSQL** MVP-3/4 için yeterli olmalı; erken yatay ölçekleme yapılmaz. Redis pub/sub köprüsü, ikinci örnek gerçekten gerekene dek ertelenebilir (MVP-3 tasarımı buna uygun yazılırsa).
- **Zirve yükler:** Sınav sonuçları/kayıt haftası ve yeni dönem başı (kayıt kodu e-postaları), akşam saatleri. Bu dönemlerde SMTP günlük gönderim kotası (örn. Gmail ~500/gün) darboğaz olur → transactional e-posta servisi gerekir.
- **Bildirim fırtınası:** Bir duyuru tüm kullanıcılara aynı anda gidince API/arka plan yoğunluğu → FCM topic kullanımı ve kuyruğa alınmış gönderim.
- **Veri büyümesi:** Mesaj tablosu en hızlı büyüyen veridir; indeks, imleç tabanlı sayfalama ve saklama politikası baştan konulur. Bölümleme (partitioning) ancak yüz milyon satır yaklaşırsa.
- **Tek hata noktası:** Redis düşerse hem oturum yenileme (opak refresh token Redis'te) hem rate limit hem pub/sub etkilenir. Redis kalıcılığı (AOF), refresh token'ları için PostgreSQL yedeği düşünülebilir; rate limit için "Redis yoksa izin ver/reddet" politikası (fail-open/closed) bilinçli seçilmeli (kimlik doğrulama uçlarında fail-closed önerilir).
- **Gözlemlenebilirlik:** Actuator zaten var; sağlık, scraper son başarı zamanı, WebSocket bağlantı sayısı, FCM hata oranı metrikleri; hata izleme (Sentry vb.). Scraper başarısızlığı için uyarı kanalı.
- **Yedekleme ve geri yükleme:** Günlük PostgreSQL yedeği ve **geri yükleme provası**.
- **Mobil sürümleme:** Eski uygulama sürümleri sunucuyla uyumsuz hale gelmesin; API sürümü (`/api/v1`) veya `min_supported_version` kontrolü ve "güncelle" ekranı (MVP-1'de eklenmesi ucuzdur).

### 3.5 Açık sorular (karar bekleyenler)

1. **Uygulamanın sahibi ve statüsü kim?** Kişisel proje mi, öğrenci topluluğu mu, üniversite onaylı mı? Bu; KVKK sorumluluğunu, mağaza hesabı sahipliğini, adı/logoyu ("Bingöl Üniversitesi" adı ve armasının izinsiz kullanımı sorun olabilir) ve moderasyon yetkisini belirler.
2. **`@bingol.edu.tr` alan adında öğrenci ile personel ayrışıyor mu?** Öğrenci e-postası `ogr.bingol.edu.tr` gibi bir alt alan adı mı kullanıyor, hepsi aynı alan adında mı? Mevcut doğrulama yalnızca `@bingol.edu.tr` kabul ediyorsa **öğrencilerin kayıt olabildiği doğrulanmalı**. Rol çıkarımı buna bağlı.
3. **Ortak/bölüm kutuları** (örn. `bilgiislem@bingol.edu.tr`) kayıt olabilmeli mi? Önerilen: hayır (kişi kutusu kalıbı yoksa bir engelleme listesi).
4. **Mezunlar ve ayrılan personel:** E-posta kapandığında hesap ne olur? Periyodik yeniden doğrulama gerekli mi?
5. **Mesajlaşmada kimler kimlere yazabilir?** Herkes herkese mi, yoksa öğrenciden akademisyene yazma/ilk mesaj kısıtlı mı? Akademisyenler için "ilk mesaj için istek (message request)" modeli taciz riskini azaltır.
6. **Kullanıcı keşfi:** Ad ile arama serbest mi, yalnızca tam e-posta mı? Varsayılan görünürlük?
7. **Mesaj saklama süresi ve yönetici erişimi** (bkz. 3.1).
8. **Hedef platform:** Yalnızca Android mi (README öyle diyor)? Türkiye'deki üniversite öğrencilerinde iOS payı önemli; iOS'u hesaba katmadan "tüm öğrenciler" hedefi iddialıdır.
9. **Kaynak sitelerde kategori/bölüm bilgisi var mı?** MVP-2'deki "kategori filtresi" buna bağlı; kaynak sayfalar yalnızca tür (haber/duyuru/etkinlik) veriyorsa filtre kapsamı küçülür.
10. **Barındırma bütçesi ve yeri:** Üniversite sunucusu mu, ticari bulut mu? Mail, FCM, domain, Play Console (tek seferlik ücret) maliyetleri kim karşılıyor?
11. **Dil:** Yalnızca Türkçe mi? Uluslararası öğrenciler için İngilizce gerekli mi?
12. **Moderasyonu kim, hangi sürede yapacak?** İnsan kaynağı olmadan MVP-3/4 yayınlanmamalı.

---

## 4. Başarı ölçütleri

Ölçütler aşama sonunda **ölçülebilir** olmalı. Aşağıdaki hedefler, kullanıcı tabanı bilinmediği için başlangıç tahminleridir; ilk 4–6 haftalık veriden sonra gözden geçirilir. Temel olay verisi için gizliliğe duyarlı, kimliksiz (anonim) ürün analitiği (ör. Firebase Analytics ya da kendi sunucu sayaçları) kullanılır; bu da aydınlatma metnine yazılır.

### 4.1 Ürün ölçütleri

| Ölçüt | Tanım | MVP-1 sonu | MVP-2 sonu | MVP-3/4 sonu |
|---|---|---|---|---|
| Kurulum / aday kitle | Aktif öğrenci+personel içinde kurulum oranı | %5 | %15 | %25 |
| Haftalık aktif kullanıcı (WAU) | Son 7 günde uygulamayı açan benzersiz kullanıcı | Kurulumun %30'u | %40 | %45 |
| 30. gün tutundurma (retention) | Kurulumdan 30 gün sonra hâlâ açan | %15 | %25 | %30 |
| Kayıt tamamlama oranı | Kayıt başlatan → kodu doğrulayan | ≥ %70 | ≥ %75 | ≥ %80 |
| Giriş yapan kullanıcı oranı | Haftalık aktiflerden giriş yapmış olanlar | %20 | %35 | %50 |
| Bildirim izin oranı | Bildirim izni veren | — | ≥ %60 | ≥ %60 |
| Bildirim açılma oranı | Gönderilen bildirimin dokunulma oranı | — | ≥ %8 | ≥ %8 |
| Bildirimi kapatma/uygulamayı silme | Bildirimi kapatan oranı (aşırı bildirimin göstergesi) | — | < %10 / ay | < %10 / ay |
| Mesajlaşma benimsemesi | Giriş yapmış WAU içinde haftada ≥ 1 mesaj gönderen | — | — | %20 (MVP-3), %30 (MVP-4) |
| Sohbet çift başarı oranı | Sohbet başlatan kullanıcıların karşılıklı yanıt aldığı sohbet oranı | — | — | ≥ %50 |
| Arama başarı oranı | Aramadan sonra sonuç açılan oturum | — | ≥ %50 | ≥ %50 |

Kritik uyarı: Mesajlaşma bir **ağ etkisi** ürünüdür. Giriş yapmış aktif kullanıcı sayısı yaklaşık 300–500'ün altındayken mesajlaşma yayına alınırsa boş görünür ve ürünün değerli çıkış noktası olmaktan çıkar. Bu sayı MVP-3 için **başlama eşiği** olarak kullanılır; eşik sağlanmadıysa MVP-2 kazanım çalışmalarına (tanıtım, tanıtım afişi, bölüm temsilcileri) devam edilir.

### 4.2 Teknik / güvenilirlik ölçütleri

| Ölçüt | Hedef |
|---|---|
| API kullanılabilirliği (aylık) | ≥ %99,5 (yaklaşık 3,6 saat/ay kesinti) |
| Okuma uçları (haber/menü) gecikme | p95 < 400 ms |
| Mesaj teslim gecikmesi (bağlıyken) | p95 < 1 sn |
| Mesaj kaybı / çift teslimat | 0 (otomatik testle; üretimde `client_msg_id` çakışma sayacıyla izlenir) |
| Çökmesiz oturum oranı (crash-free) | ≥ %99 |
| Scraper başarı oranı | Haber ≥ %98 gece çalışması; yemek: her ay 1. günde veri hazır |
| Kaynak değişikliğinin fark edilme süresi | ≤ 24 saat (uyarı ile) |
| Bildirim teslim başarısı (FCM kabul oranı) | ≥ %95 (geçersiz token hariç) |
| Rate limit yanlış engelleme | Gerçek kullanıcı şikâyeti < 5 / ay |

### 4.3 Güven ve güvenlik ölçütleri

| Ölçüt | Hedef |
|---|---|
| Rapor ilk yanıt süresi | ≤ 48 saat (MVP-4'te ≤ 24 saat) |
| Raporlanan içerik oranı | < %1 mesaj (aşırı yüksekse moderasyon ölçeği yetersiz demektir) |
| Doğrulanmamış / sahte hesap vakası | Ayda 0 doğrulanmış kimliğe bürünme olayı ya da hepsi 48 saatte kapatılmış |
| Güvenlik testi | Yayın öncesi yetkilendirme (IDOR) ve JWT testleri geçti; bilinen kritik bağımlılık açığı yok (Dependabot/`mvn dependency-check`) |
| KVKK talepleri | Silme/erişim talepleri en çok 30 gün (yasal süre) içinde yanıtlanır, hedef 7 gün |

### 4.4 Aşama bazlı "bitti" tanımı

Bir aşama, ilgili kabul kriterleri sağlandığında **ve** şunlar tamamlandığında kapanır: (1) otomatik testler CI'da yeşil, (2) gerçek cihazda elle duman testi, (3) README/API dokümanı güncel, (4) izleme ve uyarılar açık, (5) geri alma planı (önceki sürüme dönüş, migration geri alma) yazılı.

---

## 5. Hemen yapılacaklar (önerilen ilk 2 hafta)

1. Açık soru 1, 2 ve 8'i cevapla (sahiplik, öğrenci alan adı, platform). Bu üçü kapsamı en çok etkiler.
2. Gerçek bir öğrenci hesabıyla kayıt akışını elle dene (e-posta alan adı ve teslim edilebilirlik).
3. MVP-0.5 görevlerini aç: PostgreSQL + Flyway, `role`/`status` alanları, scraper fixture testleri, `apiBase` yapılandırması, README düzeltmesi.
4. Üniversite Bilgi İşlem'e içerik besleme/izin talebi gönderilecek kısa bir yazı hazırla (scraping riskini azaltmanın en etkili yolu).
5. KVKK aydınlatma/gizlilik metni taslağını MVP-1 başlamadan hazırla (hukuki görüş alınarak).
