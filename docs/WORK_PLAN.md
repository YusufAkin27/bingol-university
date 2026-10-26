# Çalışma planı: sohbet + görsel, etkinlik yönetimi, kulüpler, profil fotoğrafı (20 görev)

Hedef (kullanıcı isteği): kullanıcılar birbirine anlık mesaj atar, sohbet eder, **görsel gönderir**; her kullanıcı **etkinlik başlatır ve katılımcı alımını kendisi yönetir**; kullanıcılar **profil fotoğrafı** koyar; **kulüp kurar, yönetir ve yetki devreder**. Her şey test edilir, eksikler kodlanır.

## Mevcut durum (tespit)
| Alan | Var | Eksik |
|---|---|---|
| Sohbet | birebir/grup, WS, okundu, presence, engel, rapor | **görsel yok** (yalnız metin), yanıtlama/düzenleme/silme/tepki yok |
| Etkinlik | oluşturma, RSVP (GOING/INTERESTED), kapasite, QR+elle yoklama | **organizatör kabul/ret yok**, bağımsız etkinlik ADMIN onayı bekliyor, ortak organizatör yok |
| Kulüp (topluluk) | oluşturma, katılım, MEMBER/MODERATOR/OWNER, gönderiler, rol atama | **ayrıntılı yetki yok**, sahiplik devri yok, kulüp sohbeti yok |
| Profil fotoğrafı | yükleme (jpg/png/webp 2 MB) | **sunucuda içerik doğrulaması/yeniden boyutlandırma/EXIF temizliği yok** |

## Varsayılan kararlar (değiştirmek için söyleyin)
1. **Bağımsız etkinlikler yönetici onayı beklemez**: hemen yayınlanır; şikâyet + hız sınırı ile denetlenir (`events_require_approval` ayarı, varsayılan `false`). Kulüp etkinliği yetkisi olan üyelerce açılır.
2. **Sohbet görselleri özeldir**: herkese açık `/files/**` altında DEĞİL; yalnızca konuşma katılımcılarına, yetkili uçtan servis edilir.
3. **Görsel işleme**: yalnızca JPEG/PNG/WebP; sihirli bayt doğrulaması, yeniden kodlama (EXIF/GPS temizliği), **sıkıştırma**, küçük resim. Tüm görseller **sunucunun yerel diskinde** (S3/bulut yok); **boyut ve kalite sınırları `application.properties`'ten ayarlanır** (tür bazlı: avatar/cover/chat; yüklenen ham üst sınır + sıkıştırma sonrası saklanan üst sınır + uzun kenar + JPEG kalitesi).
4. **Mesaj şifreleme (T21)**: mesaj metinleri ve sohbet görselleri **veritabanında/diskte şifreli** saklanır (AES-256-GCM, JCE'nin standart ilkeli; kendi şifre algoritması YAZILMAZ — şifreleme *servisini/anahtar yönetimini* biz yazarız). Zarf şifreleme: konuşma başına veri anahtarı, ana anahtar ortam değişkeni/dosyadan. Sunucular arası (Redis) yayın da şifreli. İletim şifresi = TLS/WSS (nginx örneği + HSTS).
5. **Yönetici mesaj çözme**: istenildiğinde mümkün; ancak **zorunlu gerekçe + değiştirilemez erişim kaydı + hız sınırı** ile. Bu **uçtan uca şifreleme DEĞİLDİR** (sunucu anahtarı tutar): gizlilik politikası/KVKK metni buna göre güncellenmelidir (T20 taslağı hazırlar, hukuki inceleme gerekir).
6. **Mesaj araması** sunucuda yapılmaz (şifreli veri aranamaz); T13'te yalnızca açık konuşma içinde bellekte çözerek sınırlı arama düşünülür.

## Dalgalar ve bağımlılıklar
Aynı dosyalara dokunan görevler aynı dalgada çalıştırılmaz. Her dalga bitince ben birleştirir, tüm testleri koşar, sonraki dalgayı başlatırım.

| Dalga | Görevler | Not |
|---|---|---|
| **1 — Temel + QA** (7 paralel) | T1–T7 | Medya hattı, mevcut modüllerin test/denetimi, güvenlik, performans, API belgesi |
| **2 — Şifreleme + özellikler** (5 paralel) | **T21** (mesaj şifreleme), T9, T10, T11, T12 | T21 mesajlaşma çekirdeğine dokunduğu için sohbet görevleri (T8, T13) bunun ARDINDAN |
| **3 — Tamamlama** (9 paralel) | T8, T13, T14, T15, T16, T17, T18, T19, T20 | Sohbet görseli/özellikleri (şifreli altyapı üzerinde), ikinci geçişler, web paneli, uçtan uca QA, sertleştirme, yayın |

## Sürüm aralıkları, portlar, proje adları
| Görev | Flyway | Port | Compose adı |
|---|---|---|---|
| T1 | V50–V51 | 8101 | wt_t1 |
| T2 | — | 8102 | wt_t2 |
| T3 | — | 8103 | wt_t3 |
| T4 | — | 8104 | wt_t4 |
| T5 | — | 8105 | wt_t5 |
| T6 | V59 (yalnız ek indeks) | 8106 | wt_t6 |
| T7 | — | 8107 | wt_t7 |
| T8 | V60–V61 | 8108 | wt_t8 |
| T9 | V62–V63 | 8109 | wt_t9 |
| T10 | V64–V65 | 8110 | wt_t10 |
| T11 | V66 | 8111 | wt_t11 |
| T12 | V67 | 8112 | wt_t12 |
| T13 | V70 | 8113 | wt_t13 |
| T14 | V71 | 8114 | wt_t14 |
| T15 | V72 | 8115 | wt_t15 |
| T16 | V73 | 8116 | wt_t16 |
| T17 | — (web; backend'e dokunmaz) | 5201 (Vite) | — |
| T18 | — | 8118 | wt_t18 |
| T19 | V80 | 8119 | wt_t19 |
| T20 | — | 8120 | wt_t20 |
| T21 | V68–V69 | 8121 | wt_t21 |

---

## Dalga 1

## T1 — Medya hattı (görsel doğrulama/işleme) + profil fotoğrafı güvenliği
**Amaç:** Yüklenen tüm görseller için ortak, güvenli bir hat. **Sahip olduğun dosyalar:** yeni `edu.bingol.backend.media` paketi, `common/storage/*` (gerekirse genişlet), `profile` içindeki avatar yolu, `V50–V51`, `scripts/media-*.sh`, `pom.xml` (yalnız görsel kod çözücü bağımlılığı).
**İş:** (1) Sihirli bayt doğrulaması (JPEG/PNG/WebP; SVG, GIF, HEIC, polyglot, yanlış uzantı/Content-Type reddedilir). (2) ImageIO ile çözüp **yeniden kodlama** (EXIF/GPS/ICC metaverisi temizlenir), piksel sınırı (ör. 25 MP; decompression bomb koruması), uzun kenar sınırı (avatar 512, kapak 1600, sohbet 1600), küçük resim (320) üretimi, çıktı biçimi normalizasyonu. (3) `MediaService.storeImage(MultipartFile, ImageKind)` → `{url, thumbUrl, width, height, bytes, contentType}`; `FileStorage` üzerinden; içerik özetiyle adlandırma (yinelenenleri tekrar yazma), yetim dosya temizliği (zamanlayıcı). (4) **Özel (herkese açık olmayan) depolama alanı** + yetkili servis arayüzü (sohbet görselleri için T8 kullanacak): `PrivateMediaStore` ve imzalı/kimlikli erişim yardımcıları. (5) Profil avatarını bu hatta geçir (`POST /api/users/me/avatar` aynı sözleşme; `DELETE /api/users/me/avatar` ekle; eski dosya silinir; varsayılan baş harf avatarı için `GET /api/users/{id}/avatar` gerekmez — yalnız `avatarUrl` null kalır). (6) Saldırı testleri: sahte uzantı, boyut bombası, EXIF içeren dosya (çıktıda EXIF olmadığını doğrula), çok büyük dosya, bozuk dosya, eşzamanlı yükleme. **Kabul:** `scripts/media-attacks.sh` geçer; avatar akışı smoke'ları geçer; mevcut `/files/**` URL'leri çalışır.

## T2 — Sohbet: test + denetim + hata düzeltme
**Amaç:** Mevcut mesajlaşmayı (REST + WebSocket) kırmaya çalış, hataları düzelt. **Sahip olduğun dosyalar:** `messaging/**` (yalnızca hata düzeltmeleri; yeni özellik YOK), `scripts/qa-chat-*`, mevcut mesajlaşma testleri.
**Test matrisi:** birebir yarış (iki kullanıcı aynı anda başlatır), grup yaşam döngüsü (ekle/çıkar/ayrıl/başlık/yönetici devri), **IDOR** (başkasının konuşmasını/mesajlarını okuma/gönderme, ayrılmış/çıkarılmış üyenin erişimi), sıralama ve `clientId` idempotency, imeç sayfalama sınırları, okundu imleci geriye gitmez, engel iki yönde, askıya alınan kullanıcı (WS ortasında), token süresi dolması (WS), rate limit, Unicode (emoji, RTL, bileşik karakterler, 2000 karakter sınırı UTF-16/kod noktası ayrımı), WS yeniden bağlanma + `after=` ile boşluk kapatma, 200 eşzamanlı bağlantı, çevrimdışı alıcıya bildirim, silinen/anonimleştirilen kullanıcı konuşmaları, rapor/gizleme. **Kabul:** her madde için otomatik test; bulunan hatalar düzeltilmiş + regresyon testli.

## T3 — Etkinlik: test + denetim + hata düzeltme
**Sahip:** `event/**` (yalnızca düzeltme; yeni özellik YOK), `scripts/qa-event-*`. **Matris:** kapasite yarışı (N eşzamanlı RSVP), QR imza sahteciliği/yeniden oynatma/pencere sınırları, elle yoklama yetkileri, CSV enjeksiyonu, saat dilimi/DST/ay sınırı (takvim), hatırlatma tekrarı, iptal/güncelleme bildirimleri, RSVP açma-kapama, IDOR (başkasının etkinliğini düzenleme/katılımcı listesi), imeç sayfalama, geçmiş/uzak gelecek tarihleri, kapak yükleme, engelli kullanıcı davranışı, silinen kullanıcının etkinlikleri.

## T4 — Kulüp (topluluk): test + denetim + hata düzeltme
**Sahip:** `community/**` (yalnızca düzeltme), `scripts/qa-club-*`. **Matris:** rol matrisi (OWNER/MODERATOR/MEMBER/PENDING/BANNED/yabancı) × her uç, katılım politikaları (açık/onaylı), özel kulüp görünürlüğü ve sızıntı (liste/arama/akış/üye listesi/etkinlik), gönderi yetkileri ve sabitleme sınırı, ban-yeniden katılım, sahibin ayrılması, 3 kulüp sınırı yarışı, slug çakışması, yönetici onay akışı, engelli kullanıcıların görünürlüğü, silinen sahip, kapak/gönderi görseli yükleme, rapor/gizleme entegrasyonu.

## T5 — Güvenlik denetimi (kod okuma + saldırı betikleri)
**Sahip:** `scripts/security/**`, `docs/SECURITY_AUDIT.md`. **Kaynak kodu DEĞİŞTİRME** (düzeltmeler T19'da); kritik bulgu varsa hemen rapor et. **Kapsam:** OWASP API Top 10 — her `{id}` ucunda BOLA/IDOR (kontrolörlerden uç listesini çıkaran otomatik tarayıcı betiği), mass assignment, yetki atlatma (JWT `alg:none`, süresi dolmuş, rol claim kurcalama, askı/rol değişimi bayrakları), WebSocket (token'sız CONNECT, başka kullanıcının `/user/queue`'suna abonelik, SEND ile gönderici sahteciliği), yükleme saldırıları (SVG/XSS, polyglot, yol gezintisi, Content-Type sahteciliği), rate limit boşlukları ve IP/XFF taklidi, kayıt/doğrulama kodu kaba kuvvet, kullanıcı enumerasyonu, hata sızıntıları, loglarda sır, native sorgularda SQL enjeksiyonu fuzz'ı, CORS, başlıklar, `npm audit` (web) ve Maven bağımlılık sürüm uyarıları. **Çıktı:** tekrar çalıştırılabilir betikler + önem sırasıyla bulgu listesi (yeniden üretim, etki, önerilen düzeltme).

## T6 — Performans / yük testi
**Sahip:** `scripts/load/**`, `docs/PERF.md`, `V59__perf_indexes.sql` (yalnızca ek indeks). **İş:** gerçekçi veri tohumlama (20k kullanıcı, 500k mesaj, 50k RSVP...), REST sıcak yolları (haber listesi, arama, bildirim listesi, konuşma listesi, mesaj geçmişi) için eşzamanlı yük betiği (kendi küçük fetch/undici tabanlı, harici araç yok), WebSocket yayın yükü (200–500 bağlantı, mesaj dağıtım gecikmesi), `EXPLAIN (ANALYZE)` ile yavaş sorgu avı, eksik indeks önerisi (V59'da, EXPLAIN ile kanıtlı), Hikari/Tomcat ayar önerileri, bellek/GC gözlemi. **Çıktı:** ölçüm tabloları + düzeltilen darboğazlar (yalnız indeks; kod değişikliği önerisi olarak rapor).

## T7 — OpenAPI + mobil geliştirici rehberi
**Sahip:** `config/OpenApiConfig.java`, `pom.xml` (springdoc bağımlılığı), `docs/openapi.json`, `docs/MOBILE_API_GUIDE.md`, `scripts/openapi-check.*`. **İş:** springdoc-openapi (Spring Boot 4 uyumlu sürümü doğrula), Bearer güvenlik şeması, herkese açık/kimlikli/yönetici gruplama, canlı sunucudan `openapi.json` üretimi (üretimde swagger arayüzü kapalı, yalnızca ADMIN), **mobil rehber:** kimlik akışı (kayıt→kod→giriş→refresh tek-uçuş), WebSocket protokolü (STOMP çerçeve örnekleri, yeniden bağlanma, `clientId`), sayfalama, hata kodları tablosu (tr/en/ar), rate limit başlıkları, push yük formatı (`data.type/target/value`), dosya yükleme sözleşmesi, sürüm kontrolü/bakım modu. Sözleşme testi: `openapi.json` ile gerçek yanıtların uyumu.

---

## Dalga 2 (T1 ve dalga-1 düzeltmeleri birleştikten sonra; T21 burada, T8 Dalga 3'te)

## T8 — Sohbette görsel gönderme (özel medya)
**Dalga 3** (T21 sonrası). Görseller yerel diskte **şifreli** (T21 `BlobCipher`), T1 sıkıştırma/boyut ayarlarına (`app.media.chat.*`) tabidir.
**Sahip:** `messaging/media/**`, `Message` varlığına tür/ek alanları (`V60–V61`), yeni uçlar. **İş:** `POST /api/conversations/{id}/media` (T1 hattıyla işlenir, özel depoya), mesaj türü `IMAGE` (+ isteğe bağlı başlık metni), WS ile teslim (medya meta verisi + küçük resim URL'si), **yalnızca katılımcılar erişir** (kimlikli medya ucu; engel/ayrılma sonrası erişim kuralı, ör. ayrılan üye eski görselleri göremez), push önizleme ("📷 Fotoğraf" yerelleştirilmiş), mesaj başına en çok N görsel, kullanıcı başına yükleme kotası/hız sınırı, rapor edilen görselin gizlenmesi (MESSAGE handler), silinen/askıdaki kullanıcı, retention + yetim temizliği, KVKK dışa aktarım. Testler: yetkisiz erişim, boyut/tür saldırıları, iki kullanıcı arası uçtan uca (WS + REST), engel sonrası.

## T9 — Etkinlik katılım yönetimi (organizatör alımı)
**Sahip:** `event/**` (T3 düzeltmeleri birleşmiş olmalı), `V62–V63`. **İş:** her kullanıcı etkinlik açar (varsayılan: yönetici onayı yok, `events_require_approval` ayarı); etkinlik `admission` modu: `OPEN` (herkes katılır) / `APPROVAL` (başvuru → organizatör kabul/ret); başvuru durumları `PENDING/ACCEPTED/REJECTED/WAITLISTED/CANCELLED`; başvuru notu/soruları; organizatör uçları (başvuru listesi, kabul/ret/toplu, bekleme listesine alma), kontenjan dolunca bekleme listesi ve iptalde **otomatik terfi**, bildirimler (3 dil), kapasite yarışı güvenliği, yoklama/QR yalnızca ACCEPTED'a, başvuruyu geri çekme, organizatörün katılımcı çıkarması, spam/kötüye kullanım sınırları (kullanıcı başına açık etkinlik sayısı, günlük açma limiti), DataExporter.

## T10 — Kulüp ayrıntılı yetkiler ve sahiplik
**Sahip:** `community/**` (T4 düzeltmeleri birleşmiş), `V64–V65`. **İş:** roller `OWNER/ADMIN/MODERATOR/MEMBER` + **ince yetki bayrakları** (`MANAGE_MEMBERS`, `MANAGE_POSTS`, `MANAGE_EVENTS`, `EDIT_INFO`, `MANAGE_ROLES`, `INVITE`); sahip yetki devreder/geri alır (üye başına özel yetki kümesi + hazır rol şablonları); sahiplik devri (onaylı, geri alınamaz uyarı), yetki değişikliklerinin kulüp denetim kaydı (`club_audit`), yetki kontrolünün tek yerde (`ClubPermissions`) toplanması ve tüm uçlara uygulanması, yetki yükseltme saldırılarına karşı testler (MODERATOR kendini/başkasını yükseltemez, sahibi çıkaramaz), davet bağlantısı/kodu, bildirimler 3 dilde.

## T11 — Profil fotoğrafı ve profil cilası
**Sahip:** `profile/**` (T1 ile uyumlu), `V66`. **İş:** avatar yükleme/silme/değiştirme akışı testleri; avatar gizlilik ayarı (herkes/yalnız ortak kulüp-sohbet/yalnız ben), yönetici avatar moderasyonu için rapor hedefi (`USER_AVATAR`), profil tamamlama yüzdesi, profil görüntüleme yetkileri (engelli/askıdaki), kapak görseli (isteğe bağlı), `GET /api/users/{id}` yanıtında gizlilik uygulaması, hesap silmede tüm görsellerin silinmesi (KVKK), DataExporter'a avatar bilgisi.

## T12 — Yeni içerikler için moderasyon
**Sahip:** `moderation/**`, `V67`. **İş:** görsel mesaj, avatar, kulüp/etkinlik kapağı raporlanabilir; `ReportTargetHandler` genişletmeleri; otomatik gizleme eşiği (aynı hedefe N bağımsız rapor → geçici gizleme + yönetici kuyruğu), tekrarlayan ihlalde otomatik uyarı/askı önerisi, yasaklı görsel özet (hash) listesi (yönetici ekler), moderasyon kuyruğu için görsel önizleme uç(ları), denetim kaydı, bildirimler 3 dilde, istismara karşı limitler (rapor spamı).

## T21 — Mesaj şifreleme (veritabanında şifreli) + yönetici çözme
**Sahip:** yeni `edu.bingol.backend.crypto` paketi, `messaging/**` içinde saklama/okuma/yayın katmanı (yeni özellik ekleme yok), `V68–V69`, `scripts/crypto-*`, `docs/ENCRYPTION.md`. **Tasarım (zorunlu ilkeler):** (1) Şifreleme ilkeli olarak **JCE AES-256-GCM** (rastgele 96-bit nonce, 128-bit etiket); *kendi şifre algoritmanı icat etme*; sarmalayıcı servis ve anahtar yönetimi bizim kodumuz: `CryptoService`, `KeyProvider`. (2) **Zarf şifreleme:** konuşma başına rastgele 256-bit veri anahtarı (DEK), ana anahtarla (KEK) sarılıp `conversation_key` tablosunda saklanır; mesaj gövdesi `ciphertext+nonce+key_version` olarak saklanır, **AAD** = konuşma/mesaj kimliği bağlamı (başka mesaja taşınan şifreli metin çözülmez). (3) **Ana anahtar** ortam değişkeni/dosya (`app.crypto.master-keys`, çoklu sürüm: `id:base64`), repoda ASLA; üretimde yoksa uygulama açılmaz; geliştirme için açıkça uyarılı varsayılan. **Anahtar rotasyonu:** yeni ana anahtar sürümü → DEK'ler yeniden sarılır (mesajlara dokunulmaz), yönetici betiği/ucu. (4) **Mevcut düz metin mesajlar** için çevrimiçi, idempotent toplu şifreleme geçişi, ardından düz metin sütunu silinir (iki aşamalı migration; geri alma planı belgeli). (5) **Redis pub/sub** ve çok sunuculu yayın yükleri şifreli; WS teslimi alıcıya TLS üzerinden çözülmüş gider. (6) Günlüklerde, hata gövdelerinde, bildirim önizlemesi dışında düz metin YOK; push önizlemesi ayarla kapatılabilir (`app.push.message-preview`). (7) **Yönetici çözme:** `POST /api/admin/messages/decrypt` (konuşma + mesaj/aralık, **zorunlu gerekçe ≥ 10 karakter**), yanıtta düz metin; her çağrı **değiştirilemez** `message_access_audit` kaydı (yönetici, konuşma, adet, gerekçe, zaman, IP) yazar, hız sınırı, `app.crypto.admin-decrypt-enabled` ile kapatılabilir; raporlanan mesajlar moderasyon görünümünde aynı yolla (kayıtlı) çözülür; kullanıcı detayındaki "mesaj içeriği gösterilmez" notu güncellenir (web T17). (8) Şifre çözme başarısızlığı (anahtar yok/etiket hatası) açık hata kodu + metrik/log (içeriksiz). (9) Görseller için ortak `BlobCipher` (T1) uygulaması: akış şifreleme, aynı AES-GCM (parça başına), özel medya diske şifreli yazılır (T8 kullanacak). **Testler:** gidiş-dönüş, kurcalama (etiket bozma) tespiti, AAD uyumsuzluğu, nonce tekrarı yok, rotasyon, yanlış anahtar, eşzamanlılık, geçiş betiği, **veritabanında düz metin bulunmadığını psql ile doğrulayan betik**, mevcut tüm sohbet testleri geçmeye devam eder. **docs/ENCRYPTION.md:** tehdit modeli (ne korur: veritabanı/yedek sızıntısı; ne korumaz: ana anahtara sahip sunucu/yönetici), anahtar yedekleme (anahtar kaybı = mesaj kaybı), TLS/WSS kurulumu (nginx TLS örneği, HSTS), KVKK notu.

---

## Dalga 3

## T13 — Sohbet özellikleri
(Şifreli mesaj altyapısı üzerinde; düzenleme/silme yeni şifreli gövde yazar, silinen şifreli içerik ve DEK ilişkisi temizlenir; arama notu için karar 6.)
Yanıtlama (reply-to), mesaj düzenleme/silme (herkes için, süre sınırlı; silinen içerik kaldırılır), tepkiler (emoji), konuşma bazlı okunmamış sayaçları, sessize alma, mesaj arama (yalnız kendi konuşmaları), konuşmayı arşivleme. `messaging/**`, `V70`.

## T14 — Etkinlik ekstraları
Ortak organizatörler (yetki paylaşımı), katılımcılara toplu duyuru (organizatörden ACCEPTED katılımcılara bildirim/sohbet), ICS dışa aktarma, tekrarlayan etkinlik (haftalık), etkinlik sonrası kısa anket/geri bildirim, etkinlik sohbeti (grup konuşması), katılım sertifikası verisi (PDF için temel). `event/**`, `V71`.

## T15 — Kulüp ekstraları
Kulüp sohbet odası (bağlı grup konuşması, üyelikle otomatik senkron), duyuru gönderileri (tüm üyelere bildirim), katılım soruları (onaylı kulüpte başvuru formu), kulüp kapağı/logosu (T1 hattı), üye listesi filtreleri/arama, kulüp istatistikleri (yalnız yetkililere). `community/**`, `V72`.

## T16 — Bildirimler cilası
Yeni özellikler için tüm şablonlar 3 dilde, tercih ayrıntısı (sohbet/etkinlik/kulüp alt türleri), sessiz saatler, bildirim gruplama (aynı konuşma için tek bildirim), okundu/silme uçları, bildirim saklama süresi, test için sahte FCM gönderici ve içerik doğrulaması. `notification/**`, `V73`.

## T17 — Web yönetim paneli güncellemeleri
Backend'e DOKUNMAZ. Yeni özelliklerin yönetici görünümleri: medya moderasyon kuyruğu (görsel önizleme), avatar raporları, etkinlik ayarı (`events_require_approval`), kulüp yetki/denetim görünümü, kullanıcı detayında yeni sayaçlar, tr/en/ar, birim + Playwright testleri. `web/**`.

## T18 — Uçtan uca QA (tüm yeni akışlar)
Çok kullanıcılı senaryolar: iki kullanıcı sohbet + görsel (WS+REST), etkinlik açma → başvuru → kabul/ret → bekleme listesi → yoklama, kulüp kurma → yetki devri → yetki kötüye kullanım denemeleri, avatar yükleme; hepsi 3 dilde bildirim kontrolüyle; tam regresyon (tüm betikler + web e2e). `scripts/e2e-*`, `web/e2e/new-flows.spec.ts`.

## T19 — Sertleştirme: güvenlik + performans düzeltmeleri
T5 bulgularının ve T6 önerilerinin düzeltilmesi (önem sırasıyla), regresyon testleri; yalnızca bulgularla ilgili dosyalar. `V80`.

## T20 — Belgeler, yayın ve temizlik
`CLAUDE.md`/`README`/`ADMIN_API`/`MOBILE_API_GUIDE`/`ONERILER` güncelleme, OpenAPI yeniden üretimi, migration/indeks adı benzersizlik denetim betiği (`scripts/check-migrations.sh`), kullanılmayan kod/bağımlılık taraması, CI örneğinin güncellenmesi, tam regresyon, sürüm notları (`docs/CHANGELOG.md`).
