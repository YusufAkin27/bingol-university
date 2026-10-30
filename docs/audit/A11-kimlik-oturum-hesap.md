# A11 - Kimlik / Oturum / Hesap Yaşam Döngüsü QA Raporu

Tarih: 2026-10-31. Ajan: A11 (denetim aşaması: kod değiştirilmedi). Kapsam: `docs/changes/auth.md`, `docs/MOBILE_API_GUIDE.md` auth bölümleri, backend `auth/*`, `profile/*`, `user/*`, `export/*`, `legal/LegalReacceptFilter`, mobil `core/session.dart`, `core/api.dart`, `core/identifier.dart`, `features/auth/*`.
Yöntem: önce statik okuma, sonra A7'nin yalıtılmış QA yığınında (`http://localhost:18081`, HEAD b405782) dinamik doğrulama. Test kullanıcıları `a11_*` önekli; ortak Redis flush edilmedi. Üretim sunucusuna hiçbir istek atılmadı.

"DOĞRULANDI" = QA yığınında yeniden üretildi. "STATİK" = yalnız kod okumasıyla (çalıştırılmadı).

## Özet

| Şiddet | Adet | ID'ler |
|---|---|---|
| Yüksek | 2 | A11-01, A11-02 |
| Orta | 4 | A11-03, A11-04, A11-05, A11-06 |
| Düşük | 11 | A11-07 ... A11-12, A11-14, A11-15, A11-18, A11-19, A11-21 |
| Bilgi | 3 | A11-13, A11-16, A11-20 |

En kritik 5: A11-01 (ADMIN kendi hesabını `DELETE /users/me` ile silebilir), A11-02 (avatar gizliliği + moderasyon "avatarı gizle" sohbet/kulüp/etkinlik uçlarında uygulanmıyor), A11-03 (kayıt görünen ad politikasını atlıyor), A11-04 (parola politikası yalnız 8 karakter), A11-05 (NAT kapsamlı hedefli kilitleme; kod kilidi yeni kodla açılmıyor).

Sağlam çıkanlar (DOĞRULANDI): alan adı kısıtı (evil.com, `bingol.edu.tr.evil.com`, `a@evil.com@bingol.edu.tr`, Unicode homograph `bingоl`, nokta/boşluk varyantları, `+alias` hepsi 400); acceptTerms=false/eksik 400; okul numarası -> e-posta (`226-051-099` 202, 6-12 hane dışı 400); kod 5 deneme sonrası 429 kilit; refresh rotasyonu, çalıntı/yeniden kullanım tespiti (>10 sn sonra tüm oturumlar kapanır); eşzamanlı 4 refresh'ten yalnız biri 200; mobil ikinci giriş birincinin access+refresh'ini `SESSION_REPLACED` yapar, web girişi mobili düşürmez; `logout-all`, `change-password` (yeni çift verir, eskiler 401), şifre sıfırlama (kod/jeton tek kullanımlık, sonrasında tüm oturumlar 401); askıya alma access token'ı anında 401 yapar, giriş `ACCOUNT_SUSPENDED` (yalnız doğru şifreyle); silinen hesap girişi genel `INVALID_CREDENTIALS`; silinen e-postayla yeniden kayıt çalışır; alg=none ve imza dışı payload JWT'leri 401; avatar yükleme 512x512 JPEG, sahte PNG/GIF `INVALID_FILE`, 27 MB `FILE_TOO_LARGE`; hesap silmede cihaz/sohbet adı/e-posta/bio/avatar temizlenir (aşağıdaki istisnalar hariç); mobilde `autofillHints`, OTP `oneTimeCode`, yapıştırma mevcut.

---

## Bulgular

### A11-01 - Yüksek - ADMIN kendi hesabını `DELETE /api/users/me` ile silebilir (son yönetici korunmuyor)
- Yer: `backend/.../profile/ProfileController.java:61-66`, `ProfileService.java:233-240` (`deleteAccount`/`anonymize`). Karşılaştır: `admin/AdminUserService.java` `delete` (CANNOT_MODIFY_SELF + `requireAnotherAdmin`).
- Tekrar: yönetici hesabıyla `DELETE /api/users/me` gövde `{"password":"..."}`.
- Beklenen: CLAUDE.md güvenlik kuralı 6: "Yönetici kendini silemez; son yönetici korunur". Gerçek: DOĞRULANDI. `a11_adm2` panelden ADMIN yapıldı (`PATCH /admin/users/{id}/role`), `DELETE /users/me` -> 204; admin görünümünde `role=ADMIN status=DELETED email=deleted-35@deleted.invalid`. Son aktif yönetici bu yolla kendini silerse sistemde yönetici kalmaz (`ADMIN_EMAILS` hesabı silinince e-posta değiştiği için `promoteIfAdmin` ile geri de gelmez; aynı adresle yeniden kayıt gerekir).
- Etki: yönetici kilitlenmesi / yanlışlıkla ya da çalınan oturum + şifreyle kurumsal yönetici hesabı yok edilebilir; ayrıca yönetici silme akışındaki iki yönetici korumaları atlanmış olur. Silinen hesapta `role=ADMIN` kalır.
- Öneri: `deleteAccount`'ta `u.getRole()==ADMIN` ise önce rol düşürme/aktarım iste (409 `ADMIN_CANNOT_SELF_DELETE`) veya `AdminUserService.delete` ile aynı `requireAnotherAdmin` kontrolü; silme sırasında `role=USER`, `adminProfile=null` yap.

### A11-02 - Yüksek - Avatar gizliliği (`ONLY_ME`/`SHARED_CONTEXT`) ve moderasyon "avatarı gizle" bayrağı sohbet, kulüp, etkinlik, gönderi uçlarında uygulanmıyor
- Yer: yalnız engel süzgeci var, `AvatarVisibility.Field.AVATAR` çağrılmıyor: `messaging/ConversationService.java:195-211, 463-515` (peer + grup üyeleri; yalnız DEPARTMENT/CLASS_YEAR süzülüyor), `community/CommunityService.java:619` (üye listesi), `community/extras/ClubMemberSearchService.java:64`, `community/CommunityPostService.java:190`, `event/EventService.java:677, 879` (katılımcı, düzenleyen), `event/admission/EventAdmissionService.java:281` (başvuranlar), `event/extras/CoOrganizerService.java:83,109`. `docs/PROFILE_PRIVACY.md` satır 14/20 bunu "henüz filtrelenmemiştir, yapılacaklar" diye kabul ediyor; `AvatarVisibility` javadoc'u ise tersini söylüyor.
- Tekrar: `a11_d1` avatar yükler, `PATCH /users/me/privacy {"avatar":"ONLY_ME",...}`; `a11_v1` ile aynı kulüpte/sohbette: `GET /api/communities/{id}/members`, `GET .../members/search?q=`, `GET /api/conversations`.
- Gerçek (DOĞRULANDI): `GET /users/{id}` ve `/users/search` avatarı `null` verir (doğru), fakat kulüp üye listesi, üye araması ve sohbet listesi `peer.avatarUrl` aynı kullanıcının `/files/avatars/....jpg` adresini döner (departman/sınıf `null`, yani aynı DTO'da alanlar tutarsız). Moderasyon `avatar_hidden` bayrağı da aynı uçlarda geçersiz (STATİK, aynı kod yolu): yönetici uygunsuz fotoğrafı "gizle" yapsa bile sohbet/kulüp/etkinlik listelerinde görünmeye devam eder. `/files/avatars/<hash>.jpg` kimliksiz erişilebilir.
- Etki: kullanıcıya sunulan gizlilik kontrolü işlemiyor (KVKK/beklenti ihlali); moderasyon kararı etkisiz.
- Öneri: tüm bu DTO kurucularında `AvatarVisibility.filterAvatars(viewer, map)` (toplu) çağır; uç başına N+1 yok. `PublicProfileMapper` dışındaki her `getAvatarUrl()` kullanımı için bir `ArchUnit/Grep` testi ekle (`QueryRulesTest` benzeri). WS olaylarındaki avatar URL'lerini de süz.

### A11-03 - Orta - Kayıt, görünen ad politikasını (`DisplayNamePolicy`) atlıyor
- Yer: `auth/AuthService.java:154,158` yalnız `ContentGuard.clean` + `displayName.trim()`; `PendingRegistrationStore`/`AccountCreator` doğrudan yazar. Politika yalnız `ProfileService.update` içinde (`profile/naming/DisplayNamePolicy.java`).
- Tekrar: DOĞRULANDI. `POST /auth/register` + doğrulama ile `displayName` = `Sistem Yöneticisi`, `A​dmin‮` (sıfır genişlikli + RLO), `<script>alert(1)</script>` hepsi hesapla sonuçlandı; aynı adı `PATCH /users/me` ile göndermek `RESERVED_DISPLAY_NAME`/`INVALID_DISPLAY_NAME` (400) verir.
- Etki: yönetici/destek taklidi ("Resmî", "Yönetici"), bidi/gizli karakterle sahte ad, mobil/web'de HTML metni; kayıt üzerinden politika tamamen devre dışı. Ayrıca kayıtta `@Size` min yok ("A" tek karakter geçer).
- Öneri: `register`'da `DisplayNamePolicy.normalize(name, false)` çağır (kod gönderiminden önce), hatayı kayıt ekranında göster; mevcut ihlalli adlar için tek seferlik temizlik.

### A11-04 - Orta - Parola politikası yok (yalnız 8-72 karakter)
- Yer: `auth/dto/RegisterRequest.java:13`, `ResetPasswordRequest`, `ChangePasswordRequest` (`@Size(min=8,max=72)`); `AuthService.requirePasswordBytes` yalnız üst sınır.
- Tekrar: DOĞRULANDI. `12345678`, `aaaaaaaa`, `password` ile kayıt başarılı.
- Etki: hesap başına izin verilen 60 başarısız/15 dk ile (bkz. A11-05) yaygın parolalar günler içinde kırılır; credential stuffing zayıf parolalarda etkili.
- Öneri: yaygın-parola listesi (ilk ~10k) + e-posta/ad içermeme + en az iki karakter sınıfı ya da zxcvbn skoru; mobil kayıt ekranında anlık gösterge.

### A11-05 - Orta - NAT kapsamlı hedefli kilitleme; kod doğrulama kilidi yeni kodla açılmıyor
- Yer: `auth/LoginThrottle.java` (`check`: `loginEmailIpFailMax`=30, cihaz anahtarı yok sayılabildiğinde), `AuthController.login`; `auth/token/VerificationService.java:131-147` (`issue()` yalnız `ns:att/lock/gatt` siler; kapsamlı `ns:sc:<email>:<ip>:att|lock` anahtarlarına dokunmaz).
- Tekrar (DOĞRULANDI): (a) hedef e-posta için farklı `X-Device-Id` değerleriyle 31 yanlış giriş (aynı IP) -> 31. istekte 429; sonra gerçek sahibin DOĞRU şifreli girişi, yeni cihaz kimliğiyle bile, `429 RATE_LIMITED` (Retry-After 883 sn). `X-Device-Id` kimliksiz ve serbestçe üretilebilir. (b) `verify-reset-code` ile 5 yanlış kod -> sonra `forgot-password` ile YENİ kod isteyip doğru kod `429 TOO_MANY_ATTEMPTS` (10 dk). `docs/changes/auth.md` "yeni kod kilidi/sayacı sıfırlar" der; mesaj da "Yeni kod isteyin" der; kapsamlı kilitte yanlış.
- Etki: kampüs NAT'ında (tüm öğrenciler aynı IP) içerideki tek kullanıcı, herhangi bir hesabı 15 dk (giriş) / 10 dk (kod) kilitleyebilir; "hedefli kilitleme yok" iddiası NAT içinde geçerli değil. Dönen kullanıcıya düzeltme yolu verilmiyor.
- Öneri: giriş için (e-posta, IP) çift sayacını cihaz kimliği yokken/sahteyken değil, kanıtlanmış cihaz (cihaz kaydı + imza) ile ayrıştır; ya da CAPTCHA/artan gecikme (kilit yerine). `issue()` kapsamlı anahtarları da silmeli (ya da `SCAN`/anahtar listesini `ns:scopes:<email>` kümesine yaz). Kullanıcıya doğru `Retry-After` metni göster.

### A11-06 - Orta - Kaybolan refresh yanıtı sonrası yeniden deneme tüm cihazlardaki oturumları kapatır
- Yer: `auth/AuthService.java:379-395`, `token/RefreshTokenService.java` (`detectReuse`, `reuseGrace`=10 sn); mobil `core/api.dart:492-512` (`_doRefresh`), `core/session.dart:310`.
- Senaryo: sunucu refresh'i tüketir, yanıt ağda kaybolur (ya da yeni çift güvenli depoya yazılmadan uygulama sonlanır); mobil eski refresh ile ≥10 sn sonra yeniden dener.
- Gerçek (DOĞRULANDI, sunucu tarafı): tüketilmiş token 10 sn içinde `401 INVALID_REFRESH_TOKEN` (hesap açık kalır); 10 sn sonra `revokeAll` çalışır, kullanıcının TÜM (web dahil) refresh+access'i kapanır; ardından en yeni refresh `SESSION_REPLACED` ("başka cihazdan giriş yapıldı") döner. Mobil bunu `isAuthRejected` sayıp oturumu kapatır.
- Etki: zayıf mobil ağda hesap-geneli oturum kaybı ve yanıltıcı mesaj; özellikle `refreshUserMax` 60/15 dk ile birlikte kullanıcı tekrar girişe düşer.
- Öneri: tüketimde eski özetin yanına `rtnext:<oldhash>` olarak (kısa TTL, 30-60 sn) yeni çifti şifreli sakla ve aynı eski token tekrar gelirse AYNI çifti döndür (idempotent rotasyon); `revokeAll` yalnız bu pencere dışındaki yeniden kullanımda. Mobil: yeni çifti yazmadan önce `await` ile güvenli depoya yazmayı zaten yapıyor; bu iyi.

### A11-07 - Düşük - Askıya alınan kullanıcı mobilde "başka cihazdan giriş yapıldı" bandı görür
- Yer: `moderation/UserModerationService.suspend` -> `sessions.revokeAll` (mezar taşı); `AuthService.refresh` `wasRevoked` -> `SESSION_REPLACED`; mobil `ApiClient._checkReplaced`.
- DOĞRULANDI: askıdaki kullanıcının access'i 401 `UNAUTHORIZED`, refresh'i `401 SESSION_REPLACED` ("Hesabınıza başka bir cihazdan giriş yapıldı.") döner. Gerçek neden yalnız yeniden girişte (`ACCOUNT_SUSPENDED`, 403) öğrenilir. Destek yükü + kullanıcı güvenlik şüphesi.
- Öneri: refresh'te önce kullanıcı durumunu kontrol et; SUSPENDED ise 403 `ACCOUNT_SUSPENDED` (zaten `isAuthRejected` listesinde), mezar taşı yalnız gerçek "yeni giriş" için.

### A11-08 - Düşük - E-posta yerel kısmında `%` ve RFC dışı karakterler kabul ediliyor
- Yer: `auth/AuthService.java:42-43` `^[a-z0-9._%+\-]+@(...)bingol\.edu\.tr$`; mobil `core/identifier.dart:10` aynı.
- DOĞRULANDI: `a11%evil.com@bingol.edu.tr` ile `register` 202 (kod gönderimi kabul edildi). `..`, baştaki/sondaki nokta da geçer.
- Etki: yalnız hedef posta sunucusu "percent-hack" yönlendirmesi yapıyorsa `evil.com`'a kod gider ve alan adı kısıtı atlanır; modern sunucularda etkisiz, ama savunma derinliği ve geçersiz adrese bounce/kuyruk yükü.
- Öneri: yerel kısım için `[a-z0-9]([a-z0-9._\-]*[a-z0-9])?` (ardışık nokta yok, `%` yok); mevcut `%` içeren hesaplar için sorgu.

### A11-09 - Düşük - Hesap silmede kalıntılar ve oturum temizliği
- (a) `ProfileService.deleteAccount` oturum iptali çağırmaz (`AdminUserService.delete` çağırıyor): refresh özetleri Redis'te `rtu:<id>` kümesinde TTL'e (90 gün) kadar kalır; refresh `isActive` süzgeciyle reddedilir (DOĞRULANDI: silme sonrası eski refresh 401), yani güvenlik açığı değil ama tutarsızlık ve kalıntı.
- (b) DOĞRULANDI: `community_member` satırı `role=OWNER` olarak kalır (`AccountDataPurger.DELETES` OWNER'ı dışlar), kulüp devredilemezse silinse bile satır aktif görünür (yorum "Sahibin üyelik satırı silinir" diyor).
- (c) DOĞRULANDI: `mail_outbox.to_address` silinen kişinin gerçek e-postasını (SENT satırları) 30 gün tutar; `PurgeStep` yok.
- (d) `legal_acceptance` user_id ile kalır (tasarım gereği, belgeli).
- (e) Kulüp sahibi silince, ADMIN/MODERATOR yoksa kulüp kapanır; kalan üyeler kulübü kaybeder (belgeli politika; kullanıcıya silme öncesi uyarı yok - mobil metnine bakılmadı).
- Öneri: `deleteAccount` sonunda `sessions.revokeAll(id)`; OWNER satırını da kapat/sil; `mail_outbox` için e-posta eşleşmeli silme.

### A11-10 - Düşük - Engellenen taraf sohbet görünümünde `blocked:true` görür; engellenmiş/silinmiş hedef 204
- DOĞRULANDI: `a11_v1` `a11_n2`'yi engelledi. `n2`'nin profil görünümü gölge engele uyar (`blockedByMe:false`, alanlar boş), fakat `POST /conversations {userId: v1}` cevabı (n2 için) `blocked: true` içerir; sohbet listesi/detayında aynı alan. Karşı taraf engellendiğini öğrenir (belgelenen "karşı tarafın engeli sızdırılmaz" ilkesi ile çelişir).
- Silinmiş kullanıcıyı engelleme (`POST /users/32/block`) 204 döner (404 olmalı; gereksiz `user_block` satırı).
- Öneri: `ConversationView.blocked` yalnız engelleyen tarafa `true`; engellenen tarafa `false` + gönderim sessizce başarısız/kuyrukta. `block` ucunda hedef `ACTIVE` değilse 404.

### A11-11 - Düşük - Biyografi sınırı: mobil sayaç grafem, sunucu UTF-16
- Yer: `mobile/lib/features/profile/edit_profile_page.dart:30,499-505` (`_bioMax=300`, `characters.length`); sunucu `UpdateProfileRequest.bio @Size(max=300)` (UTF-16 birimi).
- DOĞRULANDI: 160 emoji (160 grafem = sayaçta 160/300) -> `400 VALIDATION_ERROR` "bio: boyut '0' ile '300' arasında olmalı" (ham doğrulama metni). 150 emoji geçer. Sunucu sınırı (300) mobil (300) ile eşit; "referans 150" ile tutarsızlık kod tarafında yok. Kayıt ekranında `displayName` için de aynı sınıf risk (80 UTF-16, politika 80 kod noktası).
- Öneri: sunucuda kod noktası (veya grafem) sayımı (`@Size` yerine servis kontrolü) ya da mobilde `utf16.length` sayacı; doğrulama hata metnini yerelleştir.

### A11-12 - Düşük - Akademik alanlar birbirinden bağımsız güncelleniyor
- DOĞRULANDI: fakülte+bölüm `Mühendislik/Bilgisayar Müh.` iken `PATCH {"faculty":"Fen-Edebiyat Fakültesi"}` -> 200, bölüm `Bilgisayar Mühendisliği` kalır (tutarsız çift). `classYear` (0-8) ile `grade` (PREP..PHD) ilişkisiz (`PHD` + `classYear=1`), `classYear=8` geçer. Bölüm yazılırken fakülte `null` iken (eski hesap) `ACADEMIC_INVALID`.
- Öneri: fakülte değişince bölümü doğrula/temizle; `classYear`'ı `grade`'den türet ya da kaldır.

### A11-13 - Bilgi - Çıkış sonrası access token 15 dk geçerli
- DOĞRULANDI: `POST /auth/logout` sonrası eski access 200 (refresh 401). JWT'nin doğal sınırı; yalnız `logout-all`/parola değişimi/oturum değişimi anında düşürür. İstenirse `logout`'ta `sid` bazlı iptal.

### A11-14 - Düşük - Doğrulama kodu özeti tuzsuz `sha256(email:code)`
- Yer: `VerificationService.hash`. 6 haneli kod için Redis sızıntısı/yedeği 10^6 denemede çözülür (TTL 10 dk, kısıtlı etki). Öneri: HMAC(pepper, email:code). 

### A11-15 - Düşük - Şifre sıfırlamada aynı parola ve bildirim e-postası
- DOĞRULANDI: `reset-password` mevcut parolayla aynı yeni parolayı kabul eder (change-password 422 `PASSWORD_UNCHANGED` verir) ve sıfırlama sonrası "şifreniz değişti" güvenlik e-postası gitmez (`change-password` gönderir; `mail_outbox` `SECURITY_PASSWORD_CHANGED` yalnız o akışta). Posta kutusu ele geçirilmişse sahibi haberdar olmaz.
- Öneri: sıfırlamada da `notifyPasswordChanged`.

### A11-16 - Bilgi - 403 yetki hatası `code`'suz Spring varsayılan gövdesi
- DOĞRULANDI (`GET /api/admin/me`, ADMIN olmayan): `{timestamp,status,error,path}`; `{code,message}` sözleşmesi yok -> mobil `HTTP_403`. `AccessDeniedHandler` için kimlikli kullanıcıda `FORBIDDEN` kodu/yerelleştirilmiş metin. Yalnız admin ucunda görüldü, diğer uçlara bakılmadı.

### A11-18 - Düşük - `unsuspend` silinmiş hesapta `suspended:` işaretini siler (STATİK)
- `UserModerationService.unsuspend`: `status==SUSPENDED` kontrolü yalnız durumu korur, `redis.delete(suspended:<id>)` koşulsuz. Silinmiş (DELETED) hesaba çağrılırsa 15 dk'lık eski access token'lar yeniden geçerli olur ve "hesap yeniden etkinleştirildi" bildirimi gönderilir. Öneri: yalnız SUSPENDED ise sil/bildir.

### A11-19 - Düşük - Redis işareti transaction içinde yazılıyor (STATİK)
- `ProfileService.anonymize` ve `UserModerationService.suspend`: `suspended:<id>` Redis'e transaction commit'inden ÖNCE yazılır; sonraki adım (olay yayımı, purge) hata verip rollback olursa kullanıcı DB'de ACTIVE iken kalıcı (TTL'siz) kilitli olur. Öneri: `TransactionSynchronization.afterCommit` (rol işareti `markRoleChanged` zaten böyle).

### A11-20 - Bilgi - Dokümantasyon / bilinen taviz
- `POST /auth/register` doğrulanmış e-posta için 409 `EMAIL_ALREADY_REGISTERED` (kayıtlı belgeli taviz; enumerasyon). `CLAUDE.md` bekleyen kayıt TTL'ini "1 sa" yazar; kod/mobil 72 sa (`docs/changes/auth.md` ile uyumlu) - CLAUDE.md güncellenmeli.

### A11-21 - Düşük - Rehber eşleştirme: tuzsuz SHA-256 e-posta özetleri
- `profile/ContactMatchService` + `User.emailSha256`: e-posta `<okul numarası>@bingol.edu.tr` biçiminde tahmin edilebilir; kullanıcı başına saatte 6x500 özet (IP başına 30 çağrı) ile öğrenci dizini (ad, avatar, fakülte/bölüm) taranabilir. Sınır "kullanıcı dizinini toplu taramayı zorlaştırma" amacıyla seçilmiş; bingol.edu.tr kutusu olan çok sayıda kullanıcıyla ölçeklenir. Öneri: günlük toplam özet kotası, sonuçta yalnız karşılıklı rehber (sizin kişiniz de sizi rehberinde tutuyor) ya da HMAC'li (sunucu sırlı) eşleştirme değil, onay/gizlilik ayarı ("rehberden bulunabilirim").

---

## DOĞRULANAMADI / bakılamadı

1. Giriş ve `forgot-password` zamanlama farkı (enumerasyon): yığın başka ajanlarla yüklü, ölçüm gürültülü (login 442-910 ms, forgot ayrışma görünse de 12 örnekle istatistiksel sonuç çıkmadı). Statik: `forgotPassword` var olan hesapta ek DB/Redis/posta kuyruğu yazımı yapar (hesap yoksa yapmaz), bu bir zamanlama farkı oluşturabilir; yalıtılmış ortamda gerçek ölçüm gerekir.
2. WebSocket tarafı: tek oturum kuralının WS kapatması (`session-replaced`), askıda anında WS red, `TokenExpiryGuard` (`smoke-single-session.sh`/`ws-test.js` çalıştırılmadı).
3. Cihaz/FCM: mobil girişte `SessionDeviceCleaner` tüm cihaz kayıtlarını silip yeni cihazın `POST /devices` ile yeniden kaydı (gerçek FCM yok); `logout` `fcmToken` ile cihaz silme (`deviceLoggedOut`) yalnız kod okundu; aynı telefonda yeniden girişte push'un geri gelmesi cihazda doğrulanmalı.
4. `LegalReacceptFilter` (`app.legal.enforce-reaccept` açık) ve mobil `LegalReacceptController` akışı çalıştırılmadı; yalnız muafiyet listesi okundu (auth, legal, destek, hesap silme, export serbest - doğru).
5. KVKK dışa aktarma: 36 bölüm, tek boş hesapta 5.7 sn (yük altında); büyük hesapta zaman aşımı/bellek ve `ExtraExporters` 5000 satır sınırının "truncated" bayrağı olmaması (`sentMessages` bayrak veriyor) doğrulanamadı. Alınan/diğer kullanıcılara ait mesajlar kapsam dışı (tasarım); "kendi mesajlarım" düz metin döner (şifreli depodan çözülür).
6. Mobil: gerçek cihazda restore/çevrimdışı açılış (M1), 401 sonrası yeniden giriş akışı, telefon saati yanlışken davranış (istemci JWT süresini hiç doğrulamıyor, yalnız `sub` okuyor; kod geçerliliği sunucu saatindedir; yalnız önbellek tazeliği `cachedAt.isAfter(now)` korumalı - sorun beklenmiyor), çok dilli hata metinleri (Arapça/İngilizce çeviri kapsamı), klavye/RTL.
7. Moderasyon "avatarı gizle" bayrağının uçlardaki etkisi dinamik denenmedi (A11-02'nin ikinci yarısı STATİK; rapor akışı kurulmadı).
8. Eşzamanlı `register` + `verify-email` yarışları, bekleyen kayıt TTL sona ermesi (72 sa), Redis kaybı (AOF açık: `docker-compose.yml` `--appendonly yes`) sonrası `suspended:` işaretlerinin yeniden yüklenmemesi (işaretler TTL'siz ve yalnız Redis'te; AOF/RDB kaybında askıdakiler ≤15 dk access ile geri döner, refresh DB durumuyla reddeder - kod okundu, denenmedi).
9. Basic auth yönetici, RBAC `admin_profile` matrisi ve iki kişi onayı kapsam dışı bırakıldı (başka ajan).

## Notlar
- QA yığınında bıraktığım veri: `a11_*` kullanıcıları (id 30+), `a11_d1` silindi/yeniden kayıtlı, `a11_adm`/`a11_adm2` silindi, kulüp #5 kapalı. Redis'te yalnız kendi giriş/kod sayaçlarım (`lgf:*` e-posta/IP anahtarları, ortak 127.0.0.1 IP sayaçları 15 dk içinde sönümlenir).
- Tekrar komut dosyaları: `scratchpad/a11/t*.py` (stdlib, `a11h.py` yardımcı) - repoya eklenmedi.
