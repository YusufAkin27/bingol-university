# Yayın Öncesi Hukuki Kontrol Listesi

Bu klasördeki metinler, uygulamanın **gerçek davranışına** dayanılarak Türk hukukuna göre titizlikle hazırlanmış üretim-seviyesi metinlerdir; ancak bunları hazırlayan bir avukat değildir. **Yayın öncesi bir hukuk danışmanı (KVKK/bilişim hukuku) tüm metinleri incelemeli ve onaylamalıdır.** Kullanıcıya gösterilen metinlerde "taslak" ibaresi yoktur; bu liste iç kullanım içindir.

## 0. Yapı

- Tek doğruluk kaynağı: `docs/legal/<tür>_<dil>.md` (tr esas, en bilgi amaçlı; Arapça yok, Türkçe sunulur).
- Üretim: `node scripts/build-legal-migration.js` → `backend/src/main/resources/db/migration/V370__legal_texts_v4.sql` (metin değişince yeniden üretin; `--check` ile güncellik kontrolü; V290 ilk nesildir, dondurulmuştur). Uygulanmış V290/V370 elle düzenlenmez; sonraki değişiklikte yeni V37x eklenir.
- Sunum anında `{{...}}` yer tutucuları `app_setting`'ten doldurulur (`LegalService.render`, 60 sn önbellek). Boş değerli kimlik satırı/cümle metinden çıkar; ham `{{…}}` hiçbir zaman gösterilmez.
- İç belgeler: `docs/legal/internal/01…09` (kullanıcıya gösterilmez).

## 1. Doldurulacak alanlar (Yönetici paneli > Ayarlar > Genel > "Sözleşme kimlik alanları")

| Yer tutucu | `app_setting` anahtarı | Varsayılan | Zorunlu mu? | Not |
|---|---|---|---|---|
| `{{controller.name}}` | `legal.controller.name` | "Bingöl Üniversitesi" | Evet | İşleten tüzel kişinin tam unvanı (kullanıcı güncelleyecek) |
| `{{controller.address}}` | `legal.controller.address` | boş | **Evet (KVKK m.10 için veri sorumlusu adresi)** | Boşsa adres satırları metinden çıkar |
| `{{controller.email}}` | `legal.controller.email` | boş | Önerilir | Boşsa uygulama içi Destek gösterilir |
| `{{controller.kep}}` | `legal.controller.kep` | boş | Kamu/tüzel kişi için önerilir | Başvuru kanalı |
| `{{controller.verbis}}` | `legal.controller.verbis` | boş | VERBİS'e kayıtlıysa | Satır boşken çıkar |
| `{{support.email}}` | `support_email` (mevcut) | boş | Önerilir | Boşsa "uygulama içi Destek bölümü" |
| `{{hosting.location}}` | `legal.hosting.location` | boş | **Evet (barındırma/SMTP ülkesi)** | Boşsa genel ifade çıkar |

Diğer: Destek formu "Kişisel veri başvurusu" konusunu desteklemelidir; `/data-request` sayfasının yönlendirmesi kontrol edilmelidir.

## 2. KARAR GEREKİR

1. **5651 trafik bilgisi saklama süresi ↔ 90 günlük cihaz/IP temizliği.** 5651 sayılı Kanun m.2/m.5 ve ikincil mevzuat, yer/erişim sağlayıcı sınıfına göre trafik bilgisinin belirli süre (mevzuatta en az 1, en çok 2 yıl) saklanmasını öngörür. Uygulama `user_device_log` / `blocked_attempt_log` kayıtlarını **90 gün** (ayarlanabilir) tutar. Çelişki olabilir. Seçenekler: (a) hukuk danışmanı, hizmetin 5651 kapsamında "yer sağlayıcı" olup olmadığını ve sürenin hangi kayıtlara uygulanacağını belirler; (b) süre ayarlanır (ayar adı access-ban modülünde; kod bu görevde **değiştirilmedi**); (c) imza/zaman damgalı ayrı erişim günlüğü sistemi kurulur. Kullanıcı metinleri **gerçek süreyi (90 gün) anlatır**; süre değişirse `privacy`, `kvkk`, `retention`, `explicit_consent` metinleri, `01` ve `06` güncellenmelidir.
2. **Silinen mesajlar süresiz mi?** `app.chat.deleted-retention-days` varsayılanı 0 = süresiz. Metinler "varsayılan süresiz, ayarlanabilir" der. KVKK m.4 (ölçülülük) açısından makul bir süre (ör. 1-2 yıl) belirlenmesi önerilir.
3. **Yönetici mesaj erişim kaydı (`message_access_audit`) ve `admin_audit` saklama süresi.** Kod bu tabloları temizlemez. Süre ve dış arşiv/imha kararı verilmeli (öneri: 2 yıl+arşiv).
4. **Yönetici erişim gerekçesi.** Kodda serbest metin gerekçe alanı yoktur (sistem sabit gerekçe yazar). Metinler "gerekçeli durumlarda" der; bu taahhüdü fiilen sağlamak için `04` numaralı politikadaki erişim defteri uygulanmalı (veya panele zorunlu gerekçe/dayanak no alanı eklenmeli).
5. **Yurt dışı aktarım dayanağı.** Firebase/APNs için rıza tek başına yeterli sayılmamalı; standart sözleşme (5 iş günü içinde Kurum'a bildirim) kararı (`05`).
6. **VERBİS yükümlülüğü ve sicil bilgileri** (`06`): işleten tüzel kişinin statüsü.
7. **Ekran görüntüsü engeli.** Tek gönderimlik fotoğraf için "teknik engel var" ifadesi kullanılmadan "mutlak garanti verilmez" denmiştir; mobilde gerçekten engel (Android FLAG_SECURE / iOS) uygulanıyorsa doğrulanmalı.
8. **18 yaş altı.** Üniversite öğrencileri arasında 18 yaş altı olabilir (ör. erken kayıtlı); yasal temsilci onayı yaklaşımı kararlaştırılmalı.
9. **Hesap silmede mesajların kalması** ve analitik olaylarının silinmemesi (aşağıda "uyum bulguları").
10. **Kamu kurumu statüsü ve hukuki sebep:** İşleten kamu tüzel kişisi ise KVKK m.5/2-(ç)/(e) ve görev-yetki mevzuatı dayanağı hukuk danışmanıyla doğrulanmalı (kamu kurumları için "meşru menfaat" kısıtlı olabilir).

## 3. Uyum bulguları (metin ↔ kod)

| Bulgu | Etki | Aksiyon |
|---|---|---|
| `analytics_event` hesap silmede (`AccountDataPurger`) silinmez; kullanıcı anonimleştiği için kimliksiz, en fazla 180 gün kalır | Metin "180 gün" der, doğru | İsteğe bağlı: silmede olay silme |
| `message_access_audit`/`admin_audit` için saklama süresi kodda yok | Metin "denetim/yasal süre boyunca" der | Karar 2.3 |
| Yönetici serbest gerekçe alanı kodda yok | Metin "gerekçeli durumlarda" (politika düzeyi) | Karar 2.4 |
| Konum izni var, konum sunucuya gönderilmiyor | Metinler "gönderilmez" der; özellik eklenirse güncelle + yeniden rıza | Gelecek özellik |
| `access_ban`/`user_device_log` modülü başka bir iş kolunda geliştiriliyor; 90 gün ve anonimleştirici engeli bu görevin girdisidir | Metinler 90 gün, HMAC özeti, anonimleştirici kısıtı, engel kaydı der | Modül tamamlanınca süre/davranış tekrar doğrulanmalı (`DEVICE_HMAC_KEY` prod gerekliliği) |
| Tek gönderimlik alıcı erişimi "ilk açılış veya 24 saat" | Metinlerle uyumlu (docs/MOBILE_API_GUIDE) | — |
| Push önizleme varsayılan kapalı (`app.push.message-preview=false`) | Metinlerle uyumlu | Ayar açılırsa metinler ve `05` güncellenmeli |
| Mail kuyruğu 30 gün, bildirim 90/365, FCM 60 gün, analitik 180, kod 10 dk, bekleyen kayıt 1 sa, yenileme 30 gün | Koddan/ayarlardan doğrulandı | — |
| Rehber eşleştirme: hash/sonuç saklanmaz ve loglanmaz (Javadoc), ≤500 özet, 6/saat/kullanıcı | Metinlerle uyumlu | — |
| Verilerimi indir: günde 3 | Metinde belirtildi | — |
| KVKK dışa aktarımı silinmiş mesajları içermez | Metinde belirtildi | — |
| Web: izleme çerezi yok; `bu.lang`, `bu.theme`, `bu.cookies` (localStorage), token'lar sessionStorage; yönetici paneli `bu.admin.*` | Çerez metniyle uyumlu | — |

## 4. Yayın öncesi kontrol listesi

- [ ] Hukuk danışmanı tüm 8 türü (tr) onayladı; EN çevirileri bilgi amaçlı olarak gözden geçirildi.
- [ ] Bölüm 1'deki alanlar (özellikle adres, e-posta/KEP, barındırma konumu) panelden dolduruldu; web'de `/legal/*` sayfaları kontrol edildi (ham `{{` yok).
- [ ] Bölüm 2 kararları verildi ve gerekirse ayarlar/kod/metinler güncellendi.
- [ ] VERBİS kaydı (gerekliyse) yapıldı; envanter (`06`) kodla eşitlendi.
- [ ] Yurt dışı aktarım mekanizması belirlendi (`05`), standart sözleşme gerekiyorsa imzalandı/bildirildi.
- [ ] Yönetici/moderatörler taahhütname (`07`) imzaladı; erişim defteri (`04`) başladı.
- [ ] Tedarikçi sözleşmeleri (`08`) tamamlandı; mağaza gizlilik beyanları (Play Data Safety, App Store) metinlerle tutarlı.
- [ ] Başvuru kanalı (Destek konusu "Kişisel veri başvurusu"), KEP, 30 gün süre süreci test edildi (`02`).
- [ ] İhlal planı (`03`) tatbikatı yapıldı.
- [ ] Mobil: kayıt ekranı ve İzinler ekranı yeni türleri gösteriyor (aşağıda).
- [ ] Yeni sürüm yayınlandığında `require_reaccept`: TERMS/PRIVACY/KVKK/COMMUNITY_RULES için mevcut kullanıcılardan yeniden onay isteyecektir (V290 bu dört türde `true`).

## 5. Teknik notlar

- **V99 ve yerel veritabanı:** V99 (`legal_texts_v2`) sabit sürüm 2 ve `active=TRUE` ekler. Yerel veritabanlarında V99 atlanır/uygulanmamıştır (ve sahte test sürümleri 2-5 olabilir). V290 DO bloğu `MAX(version)+1` hesaplar, tüm önceki sürümleri pasife alır ve bu yüzden V99'dan bağımsız çalışır. **Ancak V99 sonradan (out-of-order) uygulanırsa** sabit `2` sürümü benzersiz kısıtını (`uq_legal_version`, `uq_legal_active`) ihlal eder: yerelde V99'u uygulamayın ("yerelde V99 atlanır"); Flyway `outOfOrder` açıksa V99'u `flyway repair/ignoreMigrationPatterns` ile hariç tutun. Üretimde V99 V290'dan önce uygulanır (sorun yok).
- **Kayıtta zorunlu onay:** `LegalService.recordSignupConsent` ve `pending` yalnızca TERMS/PRIVACY/KVKK/COMMUNITY_RULES için çalışır (`LegalType.isSignupRequired`). Diğer dört tür bilgilendirmedir (kullanıcıya gösterilir, onay kaydı oluşmaz); `POST /api/legal/consents` ile isterse yine kaydedilebilir.
- **Markdown:** Metinler başlık, liste, `**kalın**`, bağlantı, `|tablo|` ve `> alıntı` kullanır. Web `MarkdownText` bunları destekler. Mobil istemci tablo ve alıntı bloklarını işleyemiyorsa düz metin gösterir; mobilde işleme gerekir.
- **Önbellek:** Ayar değişikliği metinlerde en geç 60 sn sonra görünür.
