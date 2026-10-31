# A14 — Yönetim paneli işlevsel + RBAC QA raporu

Tarih: 2026-10-31. Ortam: A7'nin yalıtılmış yığını (`http://localhost:18081` backend, `http://localhost:18190` web; HEAD b405782). Canlı panele/sunucuya erişilmedi. Kod değiştirilmedi. Ekran görüntüleri: `C:\bu_qa\shots\a14\` (repo dışı). Betikler: `C:\bu_qa\a14\*.mjs` (repo dışı).

Yöntem: 5 yönetici hesabı kuruldu (FULL = `qa-admin` ADMIN_EMAILS; MODERATOR/SUPPORT/EDITOR/VIEWER = `qa-a14-<profil>@bingol.edu.tr`, panelden USER→ADMIN→profil atama; ikinci FULL yalnız SQL ile verilebildi, bkz. A14-17). `docs/openapi.json` içindeki **329** `/api/admin/**` işleminin tamamı 5 profille çağrıldı (FULL için yalnız GET, diğerleri geçersiz/boş gövde ve olmayan kimlikle; yıkıcı FULL çağrıları atlandı). Beklenen izin `AdminPermissionPolicy` JS portundan + gerçek `/rbac/matrix` çıktısından hesaplandı. Ardından PII sızıntı taraması (146 GET uç x 5 profil), 20+ uçtan uca işlev senaryosu ve Playwright ile VIEWER/EDITOR arayüz denemesi yapıldı.

## 1. RBAC matrisi (beklenen ↔ gerçek)

**Sonuç: 329 işlem x 5 profil için 0 uyuşmazlık (backend izin kapısı `PermissionMatrix` ile birebir), 0 adet 5xx, `admin.full` (eşlenmemiş) uç yok.** Sunucunun 403 mesajındaki "gereken izin" değeri de her ucta politika kuralıyla aynı çıktı.

İzinli işlem sayısı (329 içinde, yazma = GET dışı):

| Profil | İzinli | Yazma | Not |
|---|---|---|---|
| FULL | 329 | 183 | (yazma sayısı politikadan; çağrılmadı) |
| MODERATOR | 146 | 55 | users.pii + users.write + moderation.write + chat.read/write + content.hide |
| SUPPORT | 90 | 13 | support.write + comms.single; e-posta maskeli profil |
| EDITOR | 155 | 86 | content.write + comms.write/announce; users.read YOK |
| VIEWER | 133 | 4 | yalnız önizleme/kontrol POST'ları (audience preview x3, profanity/check) |

Alan bazında (X = 200/4xx doğrulama, yani 403 değil; - = 403 `ADMIN_PERMISSION_DENIED`):

| İzin (uç sayısı) | FULL | MOD | SUP | EDT | VWR |
|---|---|---|---|---|---|
| dashboard/analytics.read (4/10), legal.read (2), content.read (40) | X | X | X | X | X |
| users.read (3) | X | X | X | - | X |
| users.pii (4: sessions, push-devices, devices, pending list) | X | X | - | - | - |
| users.write (13: suspend, verify-email, send-reset, revoke-sessions, profile, bulk, pending-*) | X | X | - | - | - |
| users.role / users.delete / users.export (1/1/3) | X | - | - | - | - |
| moderation.read (20) | X | X | - | - | X |
| moderation.write (23) | X | X | - | - | - |
| chat.read (9, rapor ayrıntısı dahil) / chat.write (7) | X | X | - | - | - |
| content.write (59) | X | - | - | X | - |
| content.hide (11) | X | X | - | X | - |
| support.read (5) | X | - | X | - | X |
| support.write (9) | X | - | X | - | - |
| comms.read (16) | X | - | X | X | X |
| comms.write (8) / comms.announce (5) | X | - | - | X | - |
| comms.single (1) | X | - | X | - | - |
| comms.send (11) | X | - | - | - | - |
| system.read (22) / audit.read (3) / settings.read (1) / data.retention.read (7) | X | - | - | - | X |
| system.write (21), settings.write, legal.publish, data.retention.export/purge, rbac.manage (6) | X | - | - | - | - |

Menü (adminNav `perm`) ↔ backend: menü öğeleri VIEWER için doğru süzülüyor (`pending-users`, `chat-feed` gizli, 45 öğe görünür; hepsi açılıyor). Uyumsuzluklar A14-10'da.

RBAC iş akışı (hepsi beklenen gibi): USER→ADMIN = VIEWER başlıyor; doğrudan FULL ataması 409 `RBAC_APPROVAL_REQUIRED`; öneren onaylayamaz (`RBAC_SAME_APPROVER`); hedef onaylayamaz; süresi dolan öneri `EXPIRED` kalıyor (yeniden onay 409 `RBAC_CHANGE_DECIDED`); eski token profil değişince 401; ADMIN_EMAILS sabitli (`ADMIN_EMAIL_PINNED`); kendi profili (`RBAC_SELF_CHANGE`); USER hedefi (`RBAC_TARGET_NOT_ADMIN`); Basic auth ile profil yazma 401; yinelenen öneri `RBAC_CHANGE_PENDING`; bayat öneri `RBAC_CHANGE_STALE`. Erişim engeli kilitlenme koruması (192.168/16, 172.16/12, 127.0.0.1, ::1, ::/0, 0.0.0.0/0) hepsi 400 `BAN_SELF_LOCKOUT`. Silme/askı/rol için kendini koruma çalışıyor. Veri saklama hata yolları (Idempotency-Key zorunlu, tarih çok yeni 422, gerekçe zorunlu) çalışıyor.

## 2. Bulgular

Özet: KRITIK 3, YUKSEK 4, ORTA 7, DUSUK 5 (toplam 19).

### A14-01 — KRITIK — Hedef kitle önizlemesi ile PII maskelemesi tamamen aşılıyor
- Uç: `POST /api/admin/push/audience/preview` (izin `comms.read`: FULL, SUPPORT, EDITOR, VIEWER). Profil: VIEWER, SUPPORT, EDITOR.
- Adımlar: VIEWER ile `{"audience":{"type":"USERS","value":"49"},"type":"ANNOUNCEMENT"}` (ya da `type:EMAILS`, ya da `ALL`) gönder.
- Beklenen: e-posta maskeli (`q***@bingol.edu.tr`; `GET /users/49` VIEWER'a böyle dönüyor) ya da uç `users.pii` ister.
- Gerçek: `sample[]` tam e-posta döner (ALL için ilk 10 kişi; USERS kimlik listesiyle tek tek istenerek tüm kullanıcıların e-postası, `EMAILS` türüyle de varlık doğrulama + id çözümleme). Maskeli profilin tüm dayanağı boşa çıkıyor.
- Ekran/veri: yanıt `{"sample":[{"id":49,"displayName":"A14 Kullanici Iki","email":"qa-a14-user2@bingol.edu.tr",...}],"notFound":["yok@bingol.edu.tr"]}`.
- Düzeltme: `SamplePerson.email`'i `PermissionAwareMasking.email` ile maskele (ya da `users.pii` yoksa e-postayı hiç döndürme); aynı denetim mail kampanyası önizlemesinde de (`/mail/campaigns/audience/preview`, geçerli gövdeyle denenemedi) uygulansın.

### A14-02 — KRITIK — PII maskeleme yalnız kullanıcı liste/ayrıntısında var; diğer uçlar tam e-posta döndürüyor
- Profil: SUPPORT, VIEWER (ve çoğunda EDITOR; EDITOR `users.read` bile almıyor).
- Etkilenen JSON uçlar (VIEWER ile doğrulandı, hepsi 200 ve maskesiz): `GET /api/admin/support/tickets` (+ `/{id}`, `userEmail`), `GET /api/admin/feedback`, `GET /api/admin/reports` (`reporter.email`, `reportedUser.email`), `GET /api/admin/moderation/strikes` (`userEmail`), `GET /api/admin/communities/{id}` (`ownerEmail`, `staff[].email`), `GET /api/admin/communities/{id}/members` (tüm üyelerin e-postası; EDITOR/SUPPORT/VIEWER hepsi `content.read` ile), `GET /api/admin/events/{id}` (`organizerEmail`), `GET /api/admin/posts` + `/{id}` (`author.email`; EDITOR dahil), `GET /api/admin/audit` + `/audit/message-access` (yönetici e-postaları). `GET /users/{id}/notifications` (users.read) başka kullanıcıların adlarını içeren bildirim metni gösteriyor. Maskeleme yalnızca `AdminDtos.AdminUserRow/Detail` ve DS1 (`Retention*`) içinde.
- Çelişki: `docs/ADMIN_API.md` "Maskeleme" ve `/admin/roles` sayfası VIEWER için "kullanıcı e-postaları maskeli" diyor (ekran: `viewer-roles.png`).
- Düzeltme: maskelemeyi DTO üretiminde merkezileştir (ortak `EmailView` serializer'ı ya da `ResponseBodyAdvice`); `RbacCoverageTest` benzeri bir test: maskesiz profil ile tüm admin GET çıktılarında `@bingol.edu.tr` tam adres regex'i bulunursa kırmızı. Destek talebinde yanıt e-postası gerekiyorsa SUPPORT için bilinçli istisna olarak belgelensin, VIEWER/EDITOR için maske şart.

### A14-03 — KRITIK — `users.export` yalnız FULL, ama aynı veri başka CSV uçlarından salt-okur profillere açık
- Uç: `GET /api/admin/support/tickets/export.csv`, `.../support/feedback/export.csv` (SUPPORT, VIEWER), `GET /api/admin/communities/export.csv`, `GET /api/admin/events/export.csv` (EDITOR, SUPPORT, VIEWER, `content.read`), `GET /api/admin/audit/export.csv` (VIEWER; yönetici e-postası + IP sütunu).
- Beklenen: `users.export` yok → e-posta içeren toplu dışa aktarma 403 ya da maskeli sütun.
- Gerçek: 200, tam e-posta (`eposta`, `sahipEposta`), audit CSV'sinde `ip`. `GET /api/admin/users/export.csv` doğru biçimde 403.
- Düzeltme: A14-02 ile aynı merkezî maske; CSV uçlarına `users.export` ya da maskeleme uygula; audit CSV'de `ip` için `users.pii` iste.

### A14-04 — YUKSEK — İki kişi onayı kuralı `PATCH /users/{id}/role` ile atlanıyor
- Uç: `PATCH /api/admin/users/{id}/role {role:"USER", reason}`. Profil: FULL (tek yönetici).
- Adımlar: ikinci FULL (id 17) varken tek FULL ile rolü USER yap → **204**; FULL yönetici tek kişiyle, onaysız, yönetici olmaktan çıkarıldı (`app_user` 17: `role=USER`, profil boş). RBAC'ta aynı sonuç `POST /rbac/changes` + ikinci onay ister (doğrudan PUT 409).
- Beklenen: FULL hedefin rolünü düşürmek `RBAC_APPROVAL_REQUIRED`/öneri akışı ister (ya da en azından aynı kısıt `AdminUserService.setRole`'da).
- Not: `DELETE /users/{id}` ve `users/bulk` için aynı atlama denenmedi (askı yönetici hedefte `CANNOT_SUSPEND_ADMIN` ile doğru korunuyor); kodda kontrol edilmeli.
- Düzeltme: `AdminUserService.setRole/delete` içinde hedef etkin profili FULL ise 409 `RBAC_APPROVAL_REQUIRED` fırlat (RbacService.needsApproval ile paylaş).

### A14-05 — YUKSEK — MODERATOR bekleyen kaydı kodsuz ve gerekçesiz doğrulayıp başkası adına hesap açabiliyor
- Uç: `POST /api/admin/pending-registrations/{email}/verify` (izin `users.write`: FULL, MODERATOR). Profil: MODERATOR.
- Adımlar: herkes `register` ile `qa-a14-victim@bingol.edu.tr` + kendi şifresiyle kayıt başlatır (kod hedefe gider); MODERATOR gövdesiz `verify` çağırır → **201**, hesap oluşur, saldırgan şifresiyle `login` 200. `reason` zorunlu değil (denetim kaydında gerekçe boş).
- Beklenen: e-posta sahipliği doğrulaması kritik güvenlik kuralı (CLAUDE.md 4.2). Bu işlem FULL'a özel olmalı ya da en az gerekçe + iki kişi.
- Düzeltme: izni `users.write`'tan ayır (yeni `users.verify`, yalnız FULL), gerekçe zorunlu (`AdminGuardPolicy` PENDING_* kuralı), denetime "kod atlandı" özeti. Aynısı `POST /users/{id}/verify-email` için de geçerli (MODERATOR 204 aldı).

### A14-06 — YUKSEK — `/api/admin/**` 401 yanıtı `WWW-Authenticate: Basic` taşıyor; süresi dolan token ile panel donuyor (A3 ile ortak olabilir)
- Tekrar: panelde oturum açıkken access token'ı geçersiz kıl (süre dolumu eşdeğeri; sessionStorage `bu.admin.access` son 5 karakteri değiştir) ve yeniden yükle ya da menüden başka sayfaya git.
- Gerçek: `curl -i -H "Authorization: Bearer abc.def.ghi" http://localhost:18190/api/admin/me` → `401` + `WWW-Authenticate: Basic realm="Realm"` + gövde Spring varsayılanı (`{"timestamp","status","error","path"}`, `{code,message}` DEĞİL). Tarayıcıda (Playwright/Chromium) istek yanıtsız askıda kalıyor, SPA'nın 401→refresh mantığı hiç tetiklenmiyor: sonsuz yükleniyor ekranı (`C:\bu_qa\shots\a14\corrupt-token.png`, `midsession-expired.png`; 20 sn sonra bile `GET /api/admin/me` yanıtsız). Gerçek Chrome'da bunun yerel Basic oturum penceresi olarak görünmesi beklenir. Access token 15 dk olduğundan her yönetici gün içinde karşılaşır.
- Beklenen: `{code:"UNAUTHORIZED"}` 401, `WWW-Authenticate` yok (Bearer isteklerinde), SPA sessizce refresh eder.
- Düzeltme: Bearer başlığı olan ya da `X-Requested-With`/`Accept: application/json` isteklerde Basic entry point'i kapat (`ApiAuthenticationEntryPoint` zincirde admin yolunda da kullanılsın), `WWW-Authenticate` başlığını yalnız gerçekten Basic isteyen (başlıksız) isteklere ver. Gerçek süresi dolmuş JWT ile ayrıca doğrulanmadı (yalnız bozuk imza).

### A14-07 — YUKSEK — Gönderi gizleme ve KALICI silme gerekçesiz çalışıyor
- Uç: `POST /api/admin/posts/{id}/hide` → 200 gövdesiz; `DELETE /api/admin/posts/{id}` → **204 (kalıcı silindi)**; sonrasında `PATCH` aynı id 404 `POST_NOT_FOUND`. Profil: FULL (EDITOR/MODERATOR da `content.hide` ile).
- Beklenen (CLAUDE.md "gizle, gerekçeli sil" ve görev tanımı): gerekçe zorunlu (`REASON_REQUIRED`). Etkinlikte (`/events/{id}/hide`) zorunlu çalışıyor, gönderide yok; `AdminGuardPolicy` yalnız `community-posts` DELETE'ini kapsıyor, `posts` DELETE/hide kuralı eksik.
- Not: bu testte A16'nın gönderisi (id 1) yanlışlıkla silindi (paylaşımlı yığında veri kaybı; test verisi).
- Düzeltme: `AdminGuardPolicy`'ye `^/api/admin/posts/[^/]+(/hide|/unhide)?$` kuralı (DELETE + hide gerekçe ister, yıkıcı hız sınırı). Haber gizleme (`PATCH /news/{id}`) ve askıya alma da gerekçesiz kabul ediliyor (A14-12).

### A14-08 — ORTA — Profil hiyerarşisi yok: MODERATOR, FULL yönetici hesabına müdahale edebiliyor
- Uç: `PATCH /users/{id}/profile`, `POST /users/{id}/revoke-sessions`, `/send-reset`, `/verify-email` (`users.write`). Profil: MODERATOR; hedef: FULL yönetici (id 17).
- Gerçek: profil müdahalesi 200 (görünen ad "Hacked by mod" kalıcı oldu), oturumlar kapatıldı 204, şifre sıfırlama e-postası gitti 204. Yalnız askıya alma yönetici hedefte engelli (`CANNOT_SUSPEND_ADMIN`; toplu askı `ADMIN_TARGET` ile atlıyor).
- Düzeltme: `users.write` işlemlerinde hedef ADMIN ise yalnız FULL'a izin ver (askıdaki kural gibi).

### A14-09 — ORTA — Push kampanyası çift gönderim koruması yarışta çalışmıyor
- Uç: `POST /api/admin/push/campaigns`. Aynı gövde art arda 409 `CAMPAIGN_DUPLICATE` (iyi), ama iki eşzamanlı istek ikisi de 202 oldu ve 2 kampanya oluştu (`cift gonderim` başlığı 2 kez). Çift tıklama/ağ yeniden denemesi tüm kullanıcılara iki bildirim gönderebilir.
- Düzeltme: duplicate kontrolünü atomikleştir (Redis `SET NX` ya da benzersiz indeks `requestKey`/içerik özeti) ve istemci `requestKey` gönder. Ayrıca duplicate kontrolü hedef URL doğrulamasından önce çalışıyor (https dışı URL testi bu yüzden 409 aldı; doğrulama sırası ayrıca denetlenmeli, Service satır ~352'de https kuralı var).

### A14-10 — ORTA — Arayüz ↔ backend yetki uyumsuzlukları (VIEWER)
- `/admin/users/{id}`: "Cihazlar" sekmesi 403 (`GET /users/{id}/devices`, `users.pii`) → "Tekrar dene" hata kutusu; "Bildirim gönder" ve "Veri dışa aktarma" görünür (`users.export`/`comms.single` yok). Ekran: `viewer-user-detail.png`.
- `/admin/reports`: rapor ayrıntısı `GET /reports/{id}` 403 (`chat.read`), karar kartları (Reddet/İçeriği gizle/Askıya al) görünüyor, "Kararı uygula" pasif; ekran: `viewer-reports.png`.
- `/admin/security/access-bans`: "Engel ekle", "Toplu IP/CIDR ekle", Düzenle/Etkinleştir/Kaldır düğmeleri VIEWER'a etkin görünüyor (`moderation.write` yok; tıklama 403). `GuardedAction permission` kapsamı yalnız ~15 yerde (users, settings, menü kalori, kampanya, ops, legal, event, poll, club); tickets/support, posts, mail kuyruğu, push ops, access-bans, appeals, blocklist vb. korunmuyor.
- `/admin/support/tickets`: VIEWER'a "CSV indir" görünür (A14-03).
- `/admin/roles` metni VIEWER için "e-postalar maskeli" iddiasını taşıyor (A14-02).
- Düzeltme: yazma düğmelerini `GuardedAction`/`useCan` ile sar; sekmeleri `perm` ile gizle; rapor ayrıntısını yetkisizde "mesaj bağlamı gizli" moduna düşür.

### A14-11 — ORTA — Destek e-postası/iletişim ayarları doğrulanmıyor
- Uç: `PUT /api/admin/settings/support_email` `"not-an-email"` → 204; `contact_email` `<script>x</script>` → 204. `support_email` herkese açık destek yanıtlarında `Reply-To` olarak kullanılıyor; değer e-posta biçimi/başlık ayracı (CRLF) için denetlenmiyor (CRLF denemesi hız sınırına takıldı, test edilemedi). Değerler testten sonra SQL ile eski haline döndürüldü.
- Düzeltme: e-posta anahtarlarında (`support_email`, `contact_email`) biçim doğrulaması + satır sonu reddi; URL anahtarlarında (`store_url_*`, `banner_url`, `instagram`) https şeması (store_url için `javascript:` doğru reddedildi).

### A14-12 — ORTA — Denetim kaydı yanıltıcı özet + gerekçesiz hassas işlemler
- `DELETE /users/1` ve `PATCH /users/1/role` reddedildiği halde (400) denetimde özet "hesap anonimlestirildi" / "rol -> USER" yazıldı (başarısız denemeyi başarılı sandıran kayıt). Denetim 4xx'leri de listeliyor, ama özet isteğin sonucunu yansıtmalı (özeti yalnız başarıda yaz).
- `POST /users/{id}/suspend` gövdesiz → 204, gerekçe boş (kullanıcıyı askıya alma gerekçesiz); `PATCH /news/{id}` gizleme gerekçesiz 204.
- Düzeltme: `AuditContext.summary` çağrılarını işlem tamamlandıktan sonra yap; `suspend` ve haber gizleme için `REASON_REQUIRED`.

### A14-13 — ORTA — Kişisel veri okumaları denetlenmiyor
- Denetime düşen GET'ler: `users/{id}`, `users/{id}/devices`, `users/{id}/notifications`, `support/tickets/{id}`, `communities/{id}/members`, `reports/{id}`, `audit/message-access`, `users/{id}/conversations`. Düşmeyenler: `users/{id}/sessions`, `users/{id}/push-devices` (ikisi RBAC'ta `users.pii`), `pending-registrations` listesi (e-posta), `support/tickets` listesi, `mail/outbox`, `users/{id}/strikes`.
- Düzeltme: `AuditRecorder.shouldAudit`/`@AuditRead` kapsamını `users.pii` uçlarının tümüne genişlet.

### A14-14 — ORTA — Panelde yeni backend yetenekleri eksik (A3 ile ortak)
- `PushDevice` tipi/`PushDevicesTab` P1'in `lastPushStatus`, `lastPushErrorCode`, `lastPushAt` alanlarını göstermiyor (backend `GET /users/{id}/push-devices` dönüyor). `GET /push/fcm/status` kapalıyken `error:"NO_CREDENTIALS"` dönüyor; web `FcmCheck` bu nedeni göstermiyor; `pushQueue` göstergesindeki `errorCodes` ve `disabledReason` hiçbir web dosyasında yok (`grep` 0 sonuç).
- Düzeltme: PushDevicesTab'a son gönderim durumu/hata kodu sütunu; sistem/push-ops sayfasına kapalılık nedeni ve hata kodu dağılımı.

### A14-15 — DUSUK — Yemek kalorisi girişinde gevşek tip dönüşümü
- `PUT /menu/{date}/calories`: `kcal:1.5` → 200 ve **1**'e kısalıyor; `kcal:"77"` (metin) kabul. Dokümana göre "tam sayı değilse 400 `MENU_KCAL_INVALID`". Boş `items:[]` → 400 `MENU_KCAL_LIMIT` ("en çok 62 gün…" mesajı yanıltıcı). 0 ve 5000 kabul, -1/5001 reddediliyor (doğru). Kullanıcı ucu (`/api/menu`, `/menu/today`) değişikliği hemen yansıtıyor (doğrulandı); ancak `Cache-Control: private, max-age=300` nedeniyle istemci yönetici düzeltmesini 5 dk'ya kadar eski görebilir.
- Düzeltme: Jackson `ALLOW_COERCION_OF_SCALARS` kapat/`kcal` için `@Digits`; boş liste için ayrı hata kodu.

### A14-16 — DUSUK — Hız sınırı geçersiz/reddedilen istekleri de sayıyor
- `POST /data-retention/purges` (saatte 10): 7 doğrulama hatası (400) sınırı tüketti, sonraki meşru deneme 429 aldı. İşleyiş gerekçesi olabilir (yıkıcı uç) ama operatör hatasında kendini kilitler; en azından `Retry-After`/kalan hak gösterilsin.

### A14-17 — DUSUK (operasyonel) — Tek sabit FULL ile ikinci FULL panelden yaratılamıyor
- `ADMIN_EMAILS`'te yalnız bir hesap varsa USER→ADMIN→FULL öneri onayı için ikinci FULL yok (kendini onaylayamaz); `scripts/smoke-admin-rbac.sh` iki sabit yönetici gerektiriyor. Üretimde ADMIN_EMAILS en az 2 adres olmalı; `DEPLOY.md`/`ProdSettingsValidator` uyarısı eklenebilir.

### A14-18 — DUSUK — `GET /users?q=` maskeli profile e-posta varlık testi veriyor
- VIEWER `q=qa-user1@bingol.edu.tr` ile satır buluyor (maskeli `q***@…` dönüyor); başlangıç harfleri deneyerek e-posta yeniden kurulabilir. `q` araması `users.pii` olmayan profilde ad/okul no ile sınırlansın ya da en az uzunluk/oran sınırı.

### A14-19 — DUSUK — Sınırlı sayıda doğrulanan olumlu davranışlar (bilgi)
- Haber gizleme/geri açma kullanıcı ucuna anında yansıdı (C1 önbelleği geçersiz kılıyor; liste ve detay 404). Etkinlik gizle/iptal/toplu işlem, kulüp kapat/aç/sil, kullanıcı askıya alma (oturum anında düşüyor), destek yanıtı (kullanıcıya görünür, HTML metin olduğu gibi saklanıyor ama React kaçışlıyor), analitik tarih aralıkları (366 gün üst sınır, ters aralık 400), CSV formül kaçışı (bilet/geri bildirim/kulüp CSV'lerinde `=`,`+`,`@` başlangıçlı hücre yok), kullanıcı listesinde `size=100000` kırpılıyor, DS1 hata yolları, çökme raporu maskeleme (e-posta/JWT `[eposta]` olarak temizlendi).

## 3. Bakılamayan / eksik kalan
- Eşzamanlı iki yönetici düzenlemesi (ETag/versiyon): ayarlarda `If-Match`/sürüm alanı görülmedi, son yazan kazanır; ayrıntılı çakışma testi yapılmadı.
- 10 bin satırlık tablo performansı, tarayıcı geri/yenile (yalnız oturum yenileme senaryosu denendi), iki kez form gönderimi (yalnız push kampanyası API'de denendi).
- Anket yönetimi, SSS CRUD, sözleşme sürümü yayını (yalnız doğrulama hata yolu), push outbox/mail DEAD "retry-dead" akışları (uçlar RBAC taramasında 200/404 aldı, içerik doğrulanmadı), haber/menü satır içi arayüz düzenleme (yalnız API), `POST /mail/campaigns/audience/preview` geçerli gövdesi, `DELETE /users/{id}` ve `users/bulk` FULL-hedef kuralları, Basic auth (prod'da kapalı olması gerekiyor; yığında açık, `/rbac` yazma 401 doğrulandı).
- Gerçek süresi dolmuş JWT ile A14-06 doğrulanmadı (bozuk imza ile), SUPPORT/MODERATOR/EDITOR için arayüz gezintisi yalnız kısmen (VIEWER tam, EDITOR kısmi).
- Not (A3'e): `docs/openapi.json` içindeki bazı şemalar kodla uyuşmuyor (ör. `Audience` push kampanyası DTO'sunda `type/value` var, openapi'de `faculty/department/grade`).
