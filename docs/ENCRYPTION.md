# Mesaj şifreleme (T21)

Durum: **Aşama 1 tamamlandı** (şifreleme çekirdeği, yönetici çözme altyapısı, belgeler). **Aşama 2** (messaging entegrasyonu) T2 birleştikten sonra yapılacak; ayrıntılı plan §8'dedir.

## 1. Terminoloji (önemli)

Bu sistem **uçtan uca şifreli (E2EE) DEĞİLDİR.** Doğru ifade:

> **Şifreli iletim (TLS/WSS) ve şifreli saklama (sunucu tarafı, AES-256-GCM).**

Sunucu ana anahtarı tutar; gerektiğinde (gerekçeli, kayıtlı) mesajları çözebilir. Uygulama, web sitesi, gizlilik politikası ve mağaza metinlerinde "uçtan uca şifreli" ya da "kimse okuyamaz" denmemelidir.

## 2. Tasarım

- **Algoritma:** JCE `AES/GCM/NoPadding`, 256-bit anahtar, rastgele 96-bit nonce, 128-bit etiket. Kendi şifre algoritmamız yoktur; bizim kodumuz yalnızca sarmalayıcı ve anahtar yönetimidir.
- **Zarf şifreleme:**
  - Ana anahtar (KEK): ortam değişkeni/dosya (`app.crypto.master-keys`), çoklu sürüm (`id:base64`).
  - Konuşma başına rastgele 256-bit veri anahtarı (DEK): KEK ile AES-GCM'le sarılıp `conversation_key.wrapped_key` (= nonce‖sarılı‖etiket) olarak saklanır. Sarma AAD'si: amaç + konuşma + DEK sürümü.
  - Mesaj: `ciphertext ‖ etiket`, `nonce`, `key_version` saklanır. **AAD** = amaç("msg") + konuşma kimliği + çağıranın verdiği `contextBytes` (uzunluk önekli alanlar, belirsizlik yok). Başka konuşmaya veya başka bağlama taşınan şifreli metin çözülmez.
- **Nonce güvenliği:** her şifrelemede `SecureRandom`; DEK konuşma başınadır, konuşma başına 2^32'den çok mesaj beklenmez. Testte 10^5 şifrelemede tekrar yok.
- **Anahtar sürümü:** `conversation_key (conversation_id, key_version)`. Aktif sürüm yeni mesajları şifreler; eski sürüm eski mesajları çözer. Konuşma başına tek aktif sürüm (kısmi benzersiz indeks).
- **DEK önbelleği:** bellek içi, TTL'li (`app.crypto.dek-cache-ttl-seconds`, varsayılan 300; 0 = kapalı), üst sınırlı. Ham DEK asla diske/loga yazılmaz.
- **Dosya/görsel (`BlobCipher`):** `ChunkedAesGcmBlobCipher`; 64 KiB parçalı AES-GCM. Her dosya için alt anahtar = `HMAC-SHA256(DEK, "bu-blob-v1" ‖ rastgele 16 bayt tuz)`; nonce'lar parça sayacıdır. Parça AAD'si bağlam + başlık + "son parça" bayrağı: sıralama değiştirme, parça silme/kesme (truncation) ve ekleme tespit edilir. Akışla çalışır; **çözme sırasında hata çıkarsa o ana kadar yazılan çıktı atılmalıdır.** T1'in `BlobCipher` arayüzü henüz birleşmedi: birleştirmede uyarlanacak (bu paketteki arayüz: `encrypt/decrypt(conversationId, contextBytes, in, out)`).
- **Açılış denetimi:** üretimde (`prod` profili ya da `app.crypto.require-keys=true`) ana anahtar yoksa uygulama **açılmaz**. Geliştirmede sabit, herkese açık bir "dev" anahtarı kullanılır ve log'a büyük harfli UYARI yazılır (verileri korumaz).
- **Hata/metrik:** çözme başarısızlığı `CryptoException(reason)`: `KEY_UNAVAILABLE`, `AUTH_FAILED`, `MALFORMED`, `CONFIG`. Sayaç `crypto_failures_total{reason}` (Actuator/Micrometer); log satırlarında yalnızca konuşma, sürüm, neden bulunur — **içerik ve anahtar asla.**

### Ayarlar (`application.properties` / ortam)

| Ayar | Ortam | Varsayılan |
|---|---|---|
| `app.crypto.master-keys` | `CRYPTO_MASTER_KEYS` | boş (dev anahtarı) |
| `app.crypto.master-keys-file` | `CRYPTO_MASTER_KEYS_FILE` | boş (Docker secret için aynı biçimde dosya) |
| `app.crypto.active-key-id` | `CRYPTO_ACTIVE_KEY_ID` | listedeki SON anahtar |
| `app.crypto.require-keys` | `CRYPTO_REQUIRE_KEYS` | `false` (`prod` profili zaten zorlar) |
| `app.crypto.admin-decrypt-enabled` | `CRYPTO_ADMIN_DECRYPT_ENABLED` | `true` |
| `app.crypto.dek-cache-ttl-seconds` | — | 300 |
| `app.crypto.admin-decrypt-per-hour` | — | 30 (yönetici başına) |
| `app.crypto.admin-decrypt-max-messages` | — | 200 (istek başına) |

Anahtar üretimi: `openssl rand -base64 32` → `CRYPTO_MASTER_KEYS=k202610:<base64>`. Yardımcı: `scripts/crypto-rotate.sh newkey`.

## 3. Tehdit modeli

**Korur:**
- Veritabanı dökümü / yedek / yanlışlıkla açılmış `pgdata` sızıntısı (ana anahtar veritabanında değildir).
- SQL enjeksiyonu ile yalnızca tablo okuma, kötü niyetli DBA'nın tablo görmesi (anahtar ortamda).
- Bir mesajın başka konuşmaya/mesaja taşınması veya şifreli verinin sessizce değiştirilmesi (GCM etiketi + AAD).
- Redis üzerindeki çok sunuculu yayının (Aşama 2'de şifrelenir) sızması; ağ dinleme (TLS/WSS).

**Korumaz:**
- **Ana anahtara erişimi olan sunucu/işletmeci.** Uygulama çalışırken bellekte düz metin vardır; sunucuya kök erişimi olan her şeyi okur.
- **Yöneticiler:** gerekçeli ve kayıtlı yolla çözebilir (tasarım gereği). Kayıt değiştirilemez ama "kim baktı" bilgisi, bakılmasını engellemez.
- Cihazı ele geçirilmiş kullanıcı, ekran görüntüsü, alıcının mesajı iletmesi.
- Metaveri: kim kime, ne zaman, kaç mesaj, konuşma boyutu, mesaj uzunluğu (şifreli metin uzunluğu ≈ düz metin + 16 bayt).
- Push bildirim önizlemesi (açıksa metin FCM/APNs üzerinden geçer; bkz. §8.6).
- Anahtar ve veritabanı aynı yedekte/ortamda tutulursa sızıntıya karşı koruma kalmaz.

## 4. Yönetici çözme

`POST /api/admin/messages/decrypt` — yalnızca JWT'li ADMIN (Basic auth ile çalışmaz: yönetici kimliği kayda yazılmalıdır).

```json
{ "conversationId": 12, "fromMessageId": 100, "toMessageId": 120, "reason": "Rapor #45 incelemesi" }
```
- Gerekçe zorunlu, kırpılmış ≥ 10 karakter (≤ 500). `toMessageId` yoksa tek mesaj. İstek başına en fazla `admin-decrypt-max-messages`.
- `app.crypto.admin-decrypt-enabled=false` ise `403 ADMIN_DECRYPT_DISABLED`.
- Hız sınırı: yönetici başına saatte 30 (`RATE_LIMITED`).
- Her başarılı çağrı, düz metin dönmeden **önce** `message_access_audit` tablosuna yazılır: yönetici, konuşma, mesaj sayısı, aralık, gerekçe, IP, zaman. Kayıt yazılamazsa düz metin **verilmez**. Aşama 1'de `MessageReader` bean'i yoktur → `501 MESSAGE_READER_UNAVAILABLE`, kayıt yazılmaz.
- Tek bir mesajın çözülememesi (`AUTH_FAILED` vb.) istek hatası değildir; o öğe `text:null, error:"AUTH_FAILED"` döner ve yine kaydedilir.
- `message_access_audit` **yalnızca-ekleme**: PostgreSQL tetikleyicileri `UPDATE`, `DELETE`, `TRUNCATE`'i reddeder; konuşma/mesaj silinse kayıt kalır (FK yok). Not: tablo sahibi/süper kullanıcı tetikleyiciyi kaldırabilir; uygulama veritabanı kullanıcısına `ALTER/DROP TRIGGER` yetkisi verilmemeli ve denetim satırları düzenli olarak dış arşive aktarılmalıdır.
- Ayrıca `GET /api/admin/crypto/status` (anahtar kimlikleri, hangi ana anahtarla kaç DEK sarılı; sır yok) ve `POST /api/admin/crypto/rewrap`.

## 5. Anahtar yönetimi

### Yedekleme — **anahtar kaybı = mesaj kaybı**
- Ana anahtarlar **veritabanı yedeğinden ayrı**, en az iki ayrı güvenli yerde saklanır (parola yöneticisi / kasa / basılı kopya). Aynı yedek setinde olmamalı.
- Eski bir veritabanı yedeğini geri yüklemek, **o yedekteki DEK'leri saran ana anahtar sürümünü** gerektirir: rotasyondan sonra eski anahtarı yedekten SİLME.
- Anahtar yoksa: mesajlar kurtarılamaz; uygulama `KEY_UNAVAILABLE` ile çözme hatası verir, yeni mesaj gönderimi de başarısız olur (Aşama 2'de açık hata kodu).
- Geri yükleme provası yılda en az bir kez: temiz ortamda yedek + anahtar ile bir mesaj çözülür.

### Rotasyon
1. `scripts/crypto-rotate.sh newkey` ile yeni `id:base64` üret; `CRYPTO_MASTER_KEYS` listesinin SONUNA ekle (eskiler kalır). Varsayılan aktif = son anahtar (ya da `CRYPTO_ACTIVE_KEY_ID`).
2. Uygulamayı yeniden başlat. Yeni konuşmalar yeni anahtarla sarılır; eskiler eski anahtarla hâlâ açılır.
3. `TOKEN=<admin> scripts/crypto-rotate.sh rewrap` (= `POST /api/admin/crypto/rewrap`): tüm DEK'ler yeni ana anahtarla yeniden sarılır. **Mesajlara dokunulmaz.** İdempotent, kesilirse tekrar çalıştırılır; yarış durumunda koşullu `UPDATE`.
4. `status` çıktısında eski anahtarla sarılı sayı 0 olunca eski anahtar listeden çıkarılabilir (yedeği saklanarak).
- DEK rotasyonu (konuşma anahtarını değiştirmek) Aşama 1'de yok; şema (`key_version`) buna hazırdır: yeni sürüm satırı eklenir, eski sürüm eski mesajlar için kalır.
- Ana anahtar ele geçirildiyse rotasyon yetmez (eski yedekler eski anahtarla açılır); DEK'leri yeniden üretip mesajları yeniden şifreleme gerekir (Aşama 2 sonrası ayrı bir operasyon).

## 6. TLS / WSS kurulumu (şifreli iletim)

- Örnek: `web/nginx-tls.conf.example` (80→443 yönlendirme, TLS 1.2/1.3, modern şifre takımları, **HSTS** `max-age=31536000; includeSubDomains`, `/ws` için WSS yükseltmesi, `X-Forwarded-Proto: https`).
- Sertifika: Let's Encrypt (certbot) veya kurum sertifikası; otomatik yenilemeyi izleyin.
- Backend yalnızca iç ağda dinlemeli (compose'ta `ports` ile dışarı açılan 8080 üretimde kapatılmalı; yalnızca nginx 443). nginx → backend hattı kapalı Docker ağındadır.
- Spring tarafı: proxy arkasında `server.forward-headers-strategy=framework` (zaten CLAUDE.md §8'de not edilmiş) ve istemci IP'sinin doğru alınması gerekir; yönetici çözme denetimindeki IP buna bağlıdır.
- Mobil/istemci: yalnızca `https://` ve `wss://` adresleri; düz `http/ws` reddedilmeli.
- HSTS `preload` yalnızca tüm alt alanlar HTTPS'e hazırsa eklenmeli.

## 7. KVKK / gizlilik metni notu (T20 için)

Aşağıdaki hususlar gizlilik politikasına, aydınlatma metnine ve mağaza beyanlarına yansıtılmalı (**hukuki inceleme gerekir**):
- Mesajlar iletimde (TLS/WSS) ve saklamada (sunucu tarafı AES-256-GCM) şifrelidir; **uçtan uca şifreleme değildir.**
- Yetkili yöneticiler, yalnızca **şikâyet/güvenlik/yasal yükümlülük** gibi belgelenmiş gerekçeyle, her erişim değiştirilemez biçimde kaydedilerek mesajları görüntüleyebilir; erişim kayıtları [saklama süresi] boyunca tutulur.
- Hesap silme (anonimleştirme) sonrası mesajların akıbeti (Aşama 2'de karar: gönderen anonimleşir, içerik saklama süresine uyar).
- Veri minimizasyonu: bildirim önizlemesi ayarı (§8.6), yedek saklama süresi, anahtar kaybı riski.
- "Verilerimi indir" (`DataExporter`): kullanıcının kendi mesajlarını içermeli (Aşama 2: deşifre edilerek).
- Bu modül (`crypto`) kişisel veri tutmaz (yalnızca anahtar malzemesi ve yönetici erişim kaydı); denetim kaydındaki yönetici kimliği/IP KVKK açısından kayıt amaçlıdır. Bu yüzden `DataExporter` eklenmedi; yönetici silme/anonimleştirmesinde `message_access_audit.admin_id` korunur (FK `app_user`, kullanıcı fiziksel silinmez, anonimleştirilir).

## 8. Entegrasyon planı (Aşama 2 — `messaging/**`, T2 birleştikten sonra)

Aşağıdaki sınıf adları `main` üzerindeki mevcut koda göredir; T2'nin değişikliklerinden sonra satırlar kayabilir, mantık aynıdır.

### 8.1 Şema — V69 (genişlet) ve V69_1 (daralt)

`V69__message_encrypt_expand.sql`:
```sql
ALTER TABLE message
  ADD COLUMN body_ciphertext BYTEA,
  ADD COLUMN body_nonce      BYTEA,
  ADD COLUMN key_version     INT,
  ALTER COLUMN body DROP NOT NULL;
ALTER TABLE message ADD CONSTRAINT message_body_present
  CHECK (body IS NOT NULL OR (body_ciphertext IS NOT NULL AND body_nonce IS NOT NULL AND key_version IS NOT NULL)) NOT VALID;
-- Geçiş işi için taranacak satırlar (kısmi indeks; iş bitince V69_1 siler)
CREATE INDEX idx_message_unencrypted ON message (id) WHERE body_ciphertext IS NULL;
```
(`NOT VALID` + sonradan `VALIDATE`: büyük tabloda kilit süresi kısa kalır.)

`V69_1__message_encrypt_contract.sql` (**ayrı bir sürümde, geçiş işi bitip doğrulandıktan sonra**):
```sql
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM message WHERE body_ciphertext IS NULL) THEN
    RAISE EXCEPTION 'plaintext messages remain; run the encryption job first';
  END IF;
END $$;
ALTER TABLE message DROP CONSTRAINT message_body_present;
DROP INDEX idx_message_unencrypted;
ALTER TABLE message DROP COLUMN body;
ALTER TABLE message ALTER COLUMN body_ciphertext SET NOT NULL, ALTER COLUMN body_nonce SET NOT NULL, ALTER COLUMN key_version SET NOT NULL;
```
Neden iki dosya: Flyway uygulamadan önce çalışır, geçiş işi uygulamanın içindedir. **İki sürümlü yayın:** sürüm N = V69 + çift okuma + geçiş işi; sürüm N+1 = V69_1. Uygulama henüz canlıda mesaj tutmuyorsa (boş/atılabilir veri) ikisi birlikte gönderilebilir (koruma koşulu boş tabloda geçer). `V69_1` sürümü V68–V69 aralığındadır.

**Geri alma:** V69 geri alınabilir (sütunlar eklenmiştir, `body` hâlâ dolu çünkü iş `body`'yi yalnızca V69_1 öncesi *boşaltmaz*, bkz. §8.3 adım 4). V69_1 sonrası geri dönüş yalnızca veritabanı yedeği + ana anahtar ile mümkündür: V69_1 öncesi `pg_dump` zorunlu.

### 8.2 Sınıf değişiklikleri

| Sınıf | Değişiklik |
|---|---|
| `Message` (entity) | `body` kalkar (V69_1'e kadar `@Column(nullable=true)` ve `@Deprecated`); eklenir: `byte[] bodyCiphertext`, `byte[] bodyNonce`, `Integer keyVersion`. `@Lob` kullanma; `@JdbcTypeCode(SqlTypes.VARBINARY)` ya da düz `byte[]` (PostgreSQL `bytea`). |
| yeni `messaging/MessageCodec` | `crypto.MessageCipher`'ı saran tek nokta: `seal(convId, senderId, clientId, text) → (ciphertext, nonce, version)`, `open(Message) → String` (düz metin yedeği: ciphertext yoksa `body`). `contextBytes` = `"m1" ‖ senderId(8B) ‖ clientId(UTF-8)` — mesaj kimliği insert öncesi bilinmediği için kimlik yerine **kalıcı ve benzersiz** (conv, sender, clientId) üçlüsü bağlanır; sıra numarası gerekmez, sequence ön-ayırmaya gerek kalmaz. Düzenleme (T13) aynı bağlamla yeni nonce üretir. `CryptoException` → `ApiException(500, "CRYPTO_DECRYPT_FAILED")`; anahtar yoksa gönderim `503 CRYPTO_UNAVAILABLE` (hata kodları ve 3 dil çevirileri Aşama 1'de hazır). |
| `MessageService.send/persist` | `MessageText.clean` sonrası `codec.seal` → `persist` ciphertext yazar (`body` NULL). Şifreleme **transaction dışında** yapılır (DEK ilk oluşturma tek INSERT, yarışa dayanıklı). |
| `MessageService.deliver` | `MessageView.of(saved)` yerine `MessageView.of(saved, plainText)`: gönderim sırasında düz metin zaten elimizde, tekrar çözme yok. Push önizlemesi §8.6. |
| `MessageService.history` ve `ConversationService` (son mesaj listesi, ~satır 253–267) | Sayfadaki mesajları `codec.openAll(list)` ile çöz (aynı konuşma → DEK bir kez önbellekte). Çok konuşmalı liste (son mesajlar) konuşma başına DEK çözer; önbellek TTL'si bunu karşılar. |
| `MessagingDtos.MessageView.of(Message)` (~satır 53) | `of(Message, String text)` imzası; gizli/engelli metin mantığı aynı kalır. Düz metin sütununa doğrudan erişen başka yer kalmamalı (`grep -rn getBody messaging`). |
| `MessageReportHandler` | Değişmez (yalnızca id/sahip/gizleme). Rapor kuyruğunda içerik gösterimi §8.5. |
| `messaging/ws/ChatEventBus` | Redis yükü şifreleme §8.4. |
| yeni `messaging/MessageStoreReader implements crypto.MessageReader` | `SELECT … WHERE conversation_id=? AND id BETWEEN ? AND ? ORDER BY id LIMIT ?` → `SealedMessage(id, senderId, createdAt, contextBytes (aynı formül, codec üzerinden), Sealed)`. Geçiş sürerken `body` düz metin satırı için `Sealed` yoktur: reader bu satırı geçici olarak o anda şifreleyip döndürmez; düz metni `SealedMessage`'a koymaz — geçiş bitene kadar `MessageReader` yalnızca şifreli satırları verir (kalan düz metin satır sayısı `status`'ta uyarı olur). |
| `ConversationService` (silme/anonimleştirme) | Konuşma silinince `conversation_key` `ON DELETE CASCADE` ile gider: **silinen konuşmanın mesajları kriptografik olarak da yok olur.** Kullanıcı silme (anonimleştirme) mesajı silmez. |
| `export` | Yeni `MessagesExporter implements DataExporter`: kullanıcının kendi gönderdiği mesajlar, `MessageCodec` ile çözülmüş. |

### 8.3 Mevcut düz metin mesajların çevrimiçi toplu şifrelenmesi

`messaging/MessageEncryptionMigrator` (`@Scheduled(fixedDelay=…)` veya açılışta arka planda, `app.crypto.migrate-messages=true`):
1. `SELECT id, conversation_id, sender_id, client_id, body FROM message WHERE body_ciphertext IS NULL AND body IS NOT NULL ORDER BY id LIMIT 500 FOR UPDATE SKIP LOCKED` (kısmi indeksi kullanır; birden çok sunucu aynı anda çalışabilir).
2. Her satır için `codec.seal` → `UPDATE message SET body_ciphertext=?, body_nonce=?, key_version=? WHERE id=? AND body_ciphertext IS NULL` (idempotent; yarışta etkisiz).
3. Parti sonunda commit; partiler arası kısa bekleme (veritabanını boğmamak için). Metrik/log: kalan satır sayısı.
4. **`body` bu aşamada SİLİNMEZ/NULL'lanmaz** (güvenli geri dönüş): düz metin ancak V69_1 ile düşer. İsteğe bağlı bayrak `app.crypto.null-plaintext-after-encrypt=true` ile satır başına `body=NULL` yapılabilir (daha hızlı gizlilik, geri dönüş yedeğe bağlı).
5. Çift okuma: `codec.open` ciphertext varsa onu, yoksa `body`'yi kullanır.
6. Bitiş ölçütü: `SELECT count(*) FROM message WHERE body_ciphertext IS NULL` = 0 → `scripts/crypto-no-plaintext.sh` + V69_1 hazır.
7. Eski düz metin **yedekleri** ve WAL hâlâ düz metin içerir: geçiş sonrası eski yedekler imha edilmeli/şifreli saklanmalı (belgelenecek operasyon adımı).

### 8.4 Redis pub/sub ve çok sunuculu yayın

Şu an `ChatEventBus.publish` `Envelope{dest, userIds, payload}` JSON'unu Redis'e düz yazıyor; `payload` `MessageView` içinde mesaj metni var. Plan:
- `crypto` paketine `BusCipher` eklenir (Aşama 2'de, bu paketin sahibi olarak): çerçeve = `v1 ‖ keyId ‖ nonce ‖ AES-GCM(busKey, AAD="bus"‖keyId, json)`. `busKey` = `HMAC-SHA256(masterKey[keyId], "bu-bus-v1")` (ana anahtar sürümünden türetilir; DEK değil, çünkü olay konuşmaya özel olmayabilir). Redis'e yazılan değer yalnızca Base64 çerçevedir.
- `ChatEventBus.publish`: `mapper.writeValueAsString(env)` → `busCipher.seal(...)`; `onMessage`: çöz → `deliverLocal`. Çözülemeyen çerçeve atlanır (mevcut "Gecersiz sohbet olayi atlandi" log'u; içerik loglanmaz). Sunucular farklı anahtar listesine sahipse eski anahtar kimliği çerçevede olduğundan rotasyonda tüm sunucular aynı listeyi taşımalı.
- Presence/typing/read-receipt olayları metin taşımaz ama aynı yoldan geçer (tek tutarlı kural: Redis'te düz kullanıcı verisi yok).
- WS teslimi: `convertAndSendToUser` ile alıcıya **TLS/WSS üzerinden çözülmüş** `MessageView` gider (istemci düz metin bekler).
- Redis'e erişen biri hâlâ kimin/hangi kanalda olduğunu görür (metaveri); ayrıca Redis ağı gizli tutulmalı (parola/iç ağ).

### 8.5 Moderasyon ve yönetim

- `MessageStoreReader` bean'i gelince `POST /api/admin/messages/decrypt` etkinleşir (501 kalkar). `crypto-smoke.sh` içindeki "501" kontrolü o zaman "200 + denetim satırı +1" olarak güncellenir.
- Rapor kuyruğu: `GET /api/admin/reports/{id}` içinde "mesajı göster" bağlantısı → aynı uç (gerekçe alanı otomatik doldurulmaz; yönetici yazar). Kullanıcı detayındaki "mesaj içeriği gösterilmez" notu güncellenir (web T17).
- Raporlanan mesajın **kanıt anlık görüntüsü**: rapor oluşturulurken mesaj şifreli satırı olduğu gibi kalır; mesaj sonradan silinirse (T13) rapor kanıtı için şifreli gövde `report_evidence` kopyasına alınabilir (karar T13/moderasyona bırakılır).

### 8.6 Push önizleme ayarı ve bildirim tablosu

- Bulgu: `MessageService.deliver` önizleme metnini `notifications.send(id, MESSAGE, title, preview, data)` ile gönderiyor; `NotificationService` bunu **uygulama içi bildirim tablosuna da yazar** → düz metin veritabanında kalır. Çözüm: `app.push.message-preview` (varsayılan **`false` önerilir**).
  - `false`: bildirim gövdesi yerelleştirilmiş sabit metin ("Yeni mesaj" / "New message" / ar çevirisi), `sendLocalized`/şablon ile alıcının dilinde; başlıkta yalnızca gönderen adı (grup başlığı).
  - `true`: önizleme **yalnızca FCM yükünde** gider; veritabanına yazılan bildirim satırının gövdesi sabit metindir. Bunun için `NotificationService`'e "push gövdesi ≠ saklanan gövde" ayrımı gerekir (`notification/**` T16'nın alanı: T16 ile koordine edilip eklenmeli; Aşama 2 başında T16 durumu kontrol edilir).
- FCM/APNs önizleme taşıdığında metin Google/Apple altyapısından geçer: gizlilik metninde belirtilmeli.
- Konuşma listesindeki `lastMessage` önizlemesi API'den çözülmüş döner (kullanıcının kendi oturumu, TLS).

### 8.7 Testler (Aşama 2)

Mevcut messaging testlerinin tümü geçmeli (`MessageCodec` bean'i testlerde gerçek `EnvelopeMessageCipher` + H2 `conversation_key` tablosu ile; `CryptoTestSupport` örnek). Yeni: gönderim → DB satırında düz metin yok (JDBC ile `body_ciphertext` dolu, `body` null), gidiş-dönüş, başka konuşmaya taşıma çözülmez, geçiş işi idempotent/yarım kalıp devam, çift okuma, anahtar yok → 503, `ChatEventBus` şifreli çerçeve gidiş-dönüş + bozuk çerçeve atlanır, `MessageStoreReader` aralık/limit, yönetici uçtan uca (denetim satırı), `scripts/crypto-no-plaintext.sh` (psql + pg_dump kanarya) ve tüm eski duman betikleri.

## 9. Test ve betikler

- Birim testleri (`backend/src/test/java/edu/bingol/backend/crypto/`): gidiş-dönüş (Unicode, boş, 5 MB), etiket/gövde/nonce kurcalama (her bayt), AAD uyumsuzluğu (başka konuşma/başka bağlam), 10^5 şifrelemede nonce tekrarı yok, rotasyon (450 DEK, çok sayfa, idempotent, başarısızlık sayımı), yanlış/eksik anahtar, eşzamanlılık (ilk kullanım yarışı + 2000 karışık işlem), anahtar sağlayıcı doğrulamaları (prod'da zorunlu), blob (sınır boyutları, bit çevirme, kesme, parça sırası, başlık), yönetici çözme (gerekçe, kapalı ayar, aralık, sınır, denetim yazılamazsa düz metin yok).
- `scripts/crypto-smoke.sh` (V68 nesneleri, tetikleyici ile değiştirilemezlik, yetki, uç doğrulamaları, rotasyon ucu), `scripts/crypto-no-plaintext.sh` (Aşama 2 sonrası), `scripts/crypto-rotate.sh` (operasyon yardımcısı).
