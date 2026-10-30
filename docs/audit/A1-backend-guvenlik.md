# AUDIT-A1: Backend guvenlik denetimi (2026-10-31)

Kapsam: `backend/` (Spring Boot 4.1.2, Java 17). Denetim asamasi: kod DEGISTIRILMEDI. Uretim sunucusuna (77.83.37.160 / bukampus.com.tr) HICBIR erisim yapilmadi.
Dinamik dogrulama yalnizca A7'nin yalitilmis test yiginda (`C:\bu_qa\QA-STACK.txt`, BASE `http://localhost:18081`, HEAD b405782) yapildi; kendi olusturdugum hesaplarla (`qa-a1-*@bingol.edu.tr`). Yikici/DoS testi yok.

Yontem ve guven duzeyi:
- **PoC** = test yiginda calistirilip dogrulandi (curl kaniti raporda).
- **STATIK** = kod okunarak dogrulandi (yol:satir verildi), PoC calistirilmadi.
- 3 alt ajan salt-okunur kod incelemesi yapti (mesajlasma/medya/bildirim; topluluk/etkinlik/anket/gonderi/destek/profil; /api/admin RBAC). Raporlarindaki YUKSEK ve ORTA bulgularin tamamini ben tekrar kontrol ettim (PoC veya satir okuma). Emin olunamayanlar en sonda "DOGRULANAMADI".

## 0. Ozet

| Siddet | Adet |
|---|---|
| KRITIK | 0 |
| YUKSEK | 4 |
| ORTA | 17 |
| DUSUK | 18 |
| Bilgi / tasarim notu | 8 |
| DOGRULANAMADI | 7 |

En kritik 5:
1. A1-01 Yuzde-kodlu yol segmenti (`/%63onversations`, `/%65xport.csv`) ile admin RBAC izin eslemesi, gerekce/hiz korumasi ve denetim kaydi atlatiliyor; VIEWER profilli yonetici ozel mesajlari okuyor ve tum kullanici CSV'sini denetimsiz aliyor (PoC).
2. A1-02 Sistem ADMIN rolu, kullanici API'lerinde (kulup/etkinlik/anket/gonderi silme-yonetme) RBAC profilini ve admin denetim kaydini tamamen atliyor (VIEWER bile kulup siler).
3. A1-03 Etkinlik olusturucusu / ortak organizator, kulupten yasaklansa ya da izni dusse bile etkinlik uzerinde tam yetkide kaliyor (katilimci PII, 1000 kisiye push duyurusu, seri ile onaysiz etkinlik) (L6 genisledi).
4. A1-04 Yetkili yonetici `users.pii` olmayan profillerde (SUPPORT/VIEWER/EDITOR) birden cok uctan maskesiz e-posta/IP aliyor (push kitle onizleme, destek/kulup CSV, rapor, erisim engeli).
5. A1-05 Yonetici, kod olmadan bekleyen kaydi "dogrulayabiliyor" (MODERATOR, `users.write`) = e-posta sahipligi kanitsiz hesap acma; ADMIN_EMAILS adresiyse sabit FULL yonetici.

---

## 1. Onceki denetimin (docs/SECURITY_AUDIT_2026-10-28.md) guvenlik maddelerinin durumu

Yalnizca guvenlikle ilgili maddeler (mobil/UX/altyapi maddeleri A4/A8 kapsaminda). "Dogrulandi" = bu denetimde kodda/yiginda goruldu.

| Madde | Onceki durum | Simdi | Not |
|---|---|---|---|
| H1 kayitta hesap devralma | DUZELTILDI | COZULDU (dogrulandi) | `AuthService.verifyEmail` parola kaniti `encoder.matches(password, p.passwordHash())`, yanlis denemede kod tuketilmez |
| M1/L37 Basic auth | DUZELTILDI/ACIK | COZULDU (kismen: tek paylasilan parola kaldi, prod'da varsayilan KAPALI) | `BasicAuthThrottleFilter` fail-closed; bkz. A1-31 |
| M2 avatar gizliligi atlaniyor | ACIK | **HALA ACIK** | A1-12 (mesajlasma + topluluk/etkinlik/gonderi) |
| M3 izinsiz DM + presence | ACIK | **HALA ACIK (PoC)** | A1-11 |
| M4/M16/M27 govde siniri | DUZELTILDI | COZULDU (PoC) | 70 KB login govdesi -> 413 |
| M5/M15 genel destek postasi | DUZELTILDI | COZULDU (statik) | |
| M6/M7/M29 yukleme DoS, goruntu bombasi | DUZELTILDI | COZULDU (statik) | `ImageProcessor` baslikta w*h ve `maxPixels` denetler; yeniden kodlama |
| M8 silinen gonderi gorseli | DUZELTILDI | COZULDU (statik) | |
| M10 KVKK export kapsami | DUZELTILDI | COZULDU (statik) | silme kapsami icin bkz. A1-26 |
| M11/L9 sohbet videosu yeniden kodlanmiyor, GPS meta | ACIK | **HALA ACIK** | A1-18; `messaging` icinde transcode yok, `application.properties` "sunucu yeniden kodlamaz" |
| M12/M13/M14/M18/L1-L5/L15/L16 rate limit, alias, refresh yeniden kullanim | DUZELTILDI | COZULDU (statik) | `+alias` yasagi, `/64` IPv6 anahtari, `detectReuse`, `ProdSettingsValidator` yer tutucu denetimi goruldu |
| M17/M19/M31 mesaj/analitik/cihaz sinirlari | DUZELTILDI | COZULDU (statik) | |
| M20-M22 yaris/sayac | ACIK | Bu denetimde bakilmadi | Guvenlik degil butunluk |
| L6 etkinlik organizatoru yetkisi kaybi | ACIK | **HALA ACIK, kapsam genis** | A1-03 |
| L7 rapor hedefi gorunurluk | ACIK | **HALA ACIK** (MESSAGE/MESSAGE_IMAGE duzeldi) | A1-15 |
| L8 bcrypt 72 bayt | DUZELTILDI | COZULDU | `fitsBcrypt` her yerde |
| L14 master anahtar tutarlilik kontrolu | ACIK | Bakilmadi (kripto kullanim yonu temiz, bkz. bilgi notlari) | |
| L22 TicketService.ownTicket NPE | ACIK | **HALA ACIK (PoC)** | A1-22 |
| L24 rate limit eksigi | KISMEN | **HALA KISMEN ACIK** | A1-25 |
| L45 yonetici kendini silebilir | ACIK | **HALA ACIK** | A1-23 |
| L12/L13 saklama, L44 sahiplik | DUZELTILDI | Statik gorundu | |

---

## 2. YUKSEK bulgular

### A1-01 YUKSEK (CVSS ~7.2: AV:N/AC:L/PR:H/UI:N/S:C/C:H/I:H/A:L) Yuzde-kodlu yol ile admin RBAC, gerekce ve denetim atlatma
- Dosya: `admin/rbac/AdminPermissionInterceptor.java:36` (`AdminPermissionPolicy.required(method, req.getRequestURI())`), `admin/AdminGuardInterceptor.java:43-52`, `admin/AuditRecorder.java:31-39` (`shouldAudit`), `admin/AuditInterceptor.java:22`, `admin/rbac/AdminPermissionPolicy.java` (regex'ler).
- Neden: `getRequestURI()` cozulmemis ham yoldur; Spring MVC ise segmenti cozerek (`%63onversations` -> `conversations`) eslestirir. `StrictHttpFirewall` `%63` gibi harf kodlamalarini reddetmez. Politikanin ozel (dar) kurali kodlu segmentte eslesmez, daha genis `area(...)` kurali (daha dusuk izin) eslesir. `RbacCoverageTest`/`AdminPermissionPolicyTest` kodlu yol denemiyor.
- Saldiri (adim adim, PoC):
  1. VIEWER profilli bir yonetici hesabi (rol ADMIN, `adminProfile=VIEWER`; panelden USER->ADMIN yapilan her hesap VIEWER baslar).
  2. `GET /api/admin/users/2/conversations` -> **403** (dogru). `GET /api/admin/users/export.csv` -> **403**.
  3. `GET /api/admin/users/2/%63onversations` + `X-Admin-Reason: aaaaaaaaaaaa` -> **200** `{"user":{...,"email":"qa-user1@..."},"items":[],"nextCursor":null}` (chat.read yalniz FULL/MODERATOR'da).
  4. `GET /api/admin/users/%65xport.csv` -> **200** ve tum kullanicilarin `id,email,displayName,faculty,...` CSV'si (users.export yalniz FULL).
  5. `GET /api/admin/users/2/%64evices` -> 200 (users.pii gerekir; dogru yol 403).
- Kanit (qa yigini; token yalniz bu yigina ait):
  ```
  $ curl $B/api/admin/rbac/me -H "$VIEWER"   -> "profile":"VIEWER","permissions":["dashboard.read",...,"users.read",...]   (chat.read/users.export/users.pii YOK)
  GET /users/2/conversations      -> 403      GET /users/2/%63onversations -> 200 {"user":{"id":2,...},"items":[],...}
  GET /users/export.csv           -> 403      GET /users/%65xport.csv      -> 200 id,email,displayName,... (maskesiz e-posta)
  admin_audit: yalniz 403'luk duz yol satirlari (id 304,319); basarili %-kodlu 200 istekler icin SATIR YOK
  ```
- Etki: Profil bazli RBAC (V/S/M/E) ve CSV/KVKK denetim guvencesi bypass. Alt ajan taramasina gore ayni kok neden: `PATCH /users/{id}/%72ole` (MODERATOR rol degistirir; `USER_ROLE` gerekce/limit kurali da duser), `POST /users/{id}/%65xport`, `POST /sources/%73ync`, `/pending-registrations/%65xport.csv`, ~60 yikici uctan gerekce+saatlik limit kaybi, tum `export.csv` ve `access-bans` listelerinde denetim kaybi (STATIK + yukaridaki PoC'ler; rol degistirme PoC'si yikici olacagindan calistirilmadi).
- Duzeltme: Tek cozumleyici `AdminPaths.of(req)` = `ServletRequestPathUtils.getParsedRequestPath(req)` (segmentler cozulmus) veya `UrlPathHelper.defaultInstance.getPathWithinApplication`; AdminPermissionInterceptor, AdminGuardInterceptor, AuditRecorder/AuditInterceptor, AuditAccessDeniedHandler hepsi bunu kullansin. Daha saglami: izni yola degil eslesen kalibi baglamak (`HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE`). Ek savunma: `/api/admin/**`'de yolda `%` (e-posta icin `%40` haric) gorursen 400 donen filtre.
- Regresyon: `AdminPermissionPolicyTest` her `(method,path)` icin her alfabetik literal segmentin ilk harfini `%xx` yaparak turetsin; izin kumesi, `AdminGuardPolicy.reasonMin/destructive` ve `shouldAudit` degismemeli. MockMvc: VIEWER JWT ile `/api/admin/users/1/%63onversations` -> 403; MODERATOR ile `PATCH /users/1/%72ole` -> 403.

### A1-02 YUKSEK Sistem ADMIN rolu kullanici API'lerinde RBAC profilini ve admin denetimini atliyor
- Dosya: `common/CurrentUser.java:27` (`isAdmin()` yalniz `ROLE_ADMIN`), `community/Actor.java:9`, `community/permissions/ClubPermissions.java:63-66` (sistem ADMIN = tum izinli OWNER), `community/CommunityService.java:197,285,554`, `event/EventService.java:724,898`, `poll/PollAccess.java:77,86`, `post/PostController.java:71` (`service.delete(uid,id,CurrentUser.isAdmin())`), `config/ApiWebMvcConfig.java:36-40` (AuditInterceptor/AdminPermissionInterceptor yalniz `/api/admin/**`).
- Senaryo: VIEWER (salt okuma) profilli yonetici normal mobil JWT'siyle `DELETE /api/communities/{id}` (kulup silinir, uyelere bildirim), `DELETE /communities/{id}/members/{uid}?ban=true`, `PUT .../role`, `POST .../announcements` (5000 uyeye bildirim), `DELETE /api/posts/{herhangi}`, `/api/polls/{id}` kapat/sil, etkinlik yonetimi yapar. Izin matrisi, gerekce zorunlulugu ve `admin_audit` hic devreye girmez (yalniz kulup ici `ClubAudit`).
- Kanit: STATIK (yukaridaki satirlar; interceptor kayitlari `/api/admin/**` ile sinirli). PoC calistirilmadi (yikici).
- Duzeltme: `Actor.admin`/`CurrentUser.isAdmin()` yerine ilgili izne bagli `systemAdmin(perm)` (JWT `ap` + `PermissionMatrix`, ornek `content.write`/`content.hide`); bu kolun kullanimi `AuditContext` ile denetime + gerekceye baglansin, ya da admin mudahalesi yalniz `/api/admin/**`'e tasinsin.
- Regresyon: VIEWER profilli admin JWT ile `DELETE /api/posts/{baskasininki}` -> 403; FULL ile 204 ve `admin_audit` satiri.

### A1-03 YUKSEK Etkinlik yonetimi canli kulup yetkisine bagli degil (L6 genisledi)
- Dosya: `event/EventService.java:723-745` (`canManage`: `a.id().equals(e.getCreatedBy())` veya herhangi bir `isCoOrganizer` icin kosulsuz `true`; `requireManager` `canManage` true ise `ensureVisible`'a girmez), `event/extras/CoOrganizerService.java:48-84,114-117` (hedef kulupte uye olmak zorunda degil), `event/extras/SeriesService.java:57-71` (kopyalarda `createdBy`+`status` kopyalanir), `event/AttendanceService.java:155`.
- Senaryo 1 (yasakli/cikarilan): X kulupte MODERATOR iken etkinlik acar, sonra yasaklanir/izni dusurulur. X halen `GET /events/{id}/attendees`, `/attendance(.csv)` (ad+bolum), `PUT /attendance/{uid}`, `/checkin-code`, `POST /events/{id}/announcements` (1000 kisiye push -> phishing/spam), PATCH/DELETE etkinlik, ortak organizator ekleme yapar.
- Senaryo 2 (izinsiz etkinlik acma): yaratici herhangi bir kullaniciyi ortak organizator yapar; o kisi `POST /events/{id}/series` ile 11 kopya ACTIVE etkinlik uretir = `MANAGE_EVENTS` olmadan etkinlik acma.
- Senaryo 3 (onay kapisi): `MANAGE_EVENTS` izinli sade uye etkinligi `PENDING_REVIEW` acar; admin onaylayinca ACTIVE olur; sonra seri ile 11 kopya dogrudan ACTIVE (inceleme yok), PATCH ile baslik/aciklama onaysiz degisir (`EventService.update:226` yeniden inceleme yok).
- Kanit: STATIK (`canManage` kodu yukarida okundu).
- Duzeltme: `canManage`: creator/co-organizer ise ek olarak `e.getCommunityId()!=null ? communities.can(a,cid,MANAGE_EVENTS) : true` (BANNED/uye degilse false); `requireManager`'da once `ensureVisible`; `CoOrganizerService.add` hedefin kulupte ACTIVE uye olmasini istesin; `SeriesService` kopya `status`unu staff degilse `PENDING_REVIEW` yapsin; `ClubMemberLeftEvent`'te o kisinin co-organizer kayitlari silinsin; ACTIVE etkinligin non-staff icerik degisikliginde yeniden `PENDING_REVIEW`.
- Regresyon: (1) creator ban sonrasi attendees/mark/announce/series/checkin-code 403/404; (2) kulup disi co-organizer series -> 403; (3) PENDING onayli etkinligin seri kopyalari PENDING_REVIEW.

### A1-04 YUKSEK `users.pii` maskelemesi yalniz kullanici liste/detayinda; toplu kisisel veri baska uclardan maskesiz
- Dosya (STATIK): `PermissionAwareMasking` yalniz `AdminDtos` ve retention servislerinde kullaniliyor; `opaque()` (IP/cihaz) hic kullanilmiyor.

| Uc (izin -> profil) | Ham alan | Kaynak |
|---|---|---|
| `POST /push/audience/preview` (comms.read -> S,E,V) | 10 kisilik ornekte ham e-posta + id listesi, 120 istek/dk | `notification/campaign/CampaignService.java:159-161`, `AudienceResolver.java:51-55,86-88` |
| `/communities/{id}/members`, `communities/export.csv` (content.read -> S,E,V) | e-posta | `community/admin/ClubAdminQueryService.java:57,114,172` |
| `/community-posts`, `/posts` (content.read) | yazar e-postasi | `ClubContentAdminService.java:271`, `AdminPostService.java:245` |
| `/moderation/strikes`, `/reports` (moderation.read -> V) | e-posta | `moderation/admin/ModAdminDtos.java:28`, `AdminReportContextService.java:326` |
| `/support/tickets`, `/feedback`, `*/export.csv` (support.read -> S,V) | e-posta, 50.000 satirlik CSV | `TicketService.java:102`, `SupportExportController.java:100-128` |
| `GET /mail/suppressions/{id}` (system.read -> V) | `fullEmail` | `mail/admin/MailSuppressionAdminService.java:~170` |
| `/access-bans`, `/{id}/attempts` (moderation.read -> V) | IP, userId | `accessban/AccessBanDtos.java:27,45` |
| `/audit`, `audit/export.csv` (audit.read -> V) | yonetici e-postasi, IP | `AuditRepository.java:23-27` |

- Etki: Dusuk profilli bir yonetici (ya da ele gecirilmis hesap) kullanici dizinini kisisel veri izni olmadan cikarabilir (KVKK).
- Duzeltme: Her e-posta/IP alanini DTO fabrikalarinda `PermissionAwareMasking.email/opaque` ile maskele; CSV'lerde `canSeePii()` yoksa maskeli deger ya da `users.export` iste; `AudienceResolver.SamplePerson` maskelensin.
- Regresyon: S/V/E JWT ile `/api/admin/**` GET uclarini gezip yanitta `@` iceren maskesiz e-posta arayan genel sizinti testi.

---

## 3. ORTA bulgular

### A1-05 ORTA Yonetici kodsuz "bekleyen kayit dogrulama" = e-posta sahipligini atlayan hesap acma (+ ADMIN_EMAILS terfisi)
- Dosya: `admin/AdminAccountVerificationService.java:50-71` (`verifyPending`), `auth/AccountCreator.java:40-43` (`ADMIN_EMAILS` ise ADMIN + FULL), politika `POST /pending-registrations/{email}/verify` -> `users.write` (F,M); gerekce/limit kurali yok.
- Senaryo: Saldirgan (kayit ucundan) baskasinin `bingol.edu.tr` adresine kendi parolasiyla bekleyen kayit acar; MODERATOR (isbirlikci/ele gecirilmis) panelden `verify` der -> hesap saldirganin parolasiyla acilir (kimlik taklidi). Adres `ADMIN_EMAILS` icindeyse ve henuz hesabi yoksa saldirgan sabit FULL yonetici olur (domain muafiyeti `AuthService.register`). `verifyUser(Long)` (DB'deki dogrulanmamis satir) ayni mantik.
- Kanit: STATIK.
- Duzeltme: `verifyPending`'te `adminProperties.isAdminEmail(email)` ise reddet; ucu yeni `users.verify` iznine (yalniz FULL) ve `AdminGuardPolicy` gerekce>=5 + yikici kuralina bagla; `AccountCreator` ADMIN_EMAILS terfisini yalniz e-posta kodu dogrulamasiyla gelen cagrida yapsin.
- Regresyon: M profili ile `.../pending-registrations/{adminEmail}/verify` -> 403/409.

### A1-06 ORTA Rol degistirme/silme uclari iki kisi onayi ve "son FULL" korumasini atliyor
- Dosya: `admin/AdminUserService.java:104-122` (`changeRole`), `:125-142` (`delete`), `:145-150` (`requireAnotherAdmin` ADMIN sayar, FULL degil) vs `RbacService.check`.
- Senaryo: FULL yonetici A, baska bir (pinned olmayan) FULL yonetici B'yi tek basina USER'a dusurur/anonimlestirir; onay akisi yalniz `/rbac/**` yolunda.
- Duzeltme: hedefin etkin profili FULL ise `RbacService` onay akisina yonlendir veya `countFullAdmins()<=1` -> 409.

### A1-07 ORTA `users.write` (MODERATOR) yonetici hesaplarina karsi korumasiz
- Dosya: `AdminAccountVerificationService.java:90-114`, `AdminUserExtrasController.patchProfile`, `AdminUserSessionService.revoke`, `AdminPushDeviceService.delete` (hedef ADMIN/pinned mi kontrolu yok; `AdminUserBulkService.one:99-104` ve suspend/block-access kontrol ediyor).
- Senaryo: M profili FULL yoneticinin tum oturumlarini surekli kapatir, ad/avatarini degistirir, sifre sifirlama kodunu tetikler (denetim kaydi karisikligi/sosyal muhendislik).
- Duzeltme: `Targets` icinde "hedef ADMIN ise yalniz FULL" kurali; bu uclara gerekce zorunlulugu.

### A1-08 ORTA Sohbet sifre cozmede belgelenen saatlik/mesaj kotasi uygulanmiyor
- Dosya: `application.properties` (`app.crypto.admin-decrypt-per-hour=30`, `admin-decrypt-max-messages=200`) ve `CryptoProperties.java:28-29` kodda kullanilmiyor (STATIK, kullanim grep ile yok). Gercek limit `AdminChatViewerController.PAGES_PER_MINUTE` = 120 sayfa/dk x 50 mesaj; `GET /api/admin/chat-messages` (F,M) `userId` suzgecsiz tum akisi gezdirir; gerekce yalniz >=10 karakter ("aaaaaaaaaa" gecer).
- Etki: Tek M/F hesabi saatlerde yuzbinlerce ozel mesaja ulasabilir (denetim satiri yazilir, ancak onleyici kota yok).
- Duzeltme: `AdminDecryptService.record` oncesi `limiter.check("admindecrypt:"+adminId, props.adminDecryptPerHour(), 1h)`, genel akista zorunlu `userId/conversationId`, gerekce >=20 karakter, hacim esiginde `SystemAlertService` uyarisi.

### A1-09 ORTA Yoklama isaretleme ile keyfi kullanici PII sizintisi, gizlilik ve engel atlama
- Dosya: `event/AttendanceService.java:143,154-174,180,211-235` (`markOne` yalniz ACTIVE kontrol eder; OPEN modda RSVP aranmaz).
- Senaryo: Organizator `PUT /events/{id}/attendance/{herhangi uid}` / `attendance/bulk` (500 kayit, 20/dk) ile RSVP'siz kullanicilari isaretler, sonra `GET /attendance(.csv)` o kullanicilarin ad + bolumunu (department gizlilik ayari ONLY_ME ve engel yok sayilarak) alir; ID taramasi ile dizin cikarilir. Hedefe sahte yoklama yazilir.
- Duzeltme: `markOne` yalniz o etkinlikte GOING/yoklama kaydi olana izin versin; liste bolumu `AvatarVisibility.visibleOwners(DEPARTMENT)` ile suzulsun; engelli ciftler gizlensin.

### A1-10 ORTA Etkinlik sohbetinde legacy uc INTERESTED ile onaysiz giris (A2)
- Dosya: `event/EventChatService.java:40` (`GET /api/events/{id}/chat`: `rsvps.findByEventIdAndUserId(...).isPresent() || canManage`), karsilastir `event/chat/EventChatService.eligible` (yalniz GOING/organizator). Dogrulandi (kod okundu).
- Senaryo: APPROVAL modlu etkinlikte saldirgan `PUT /events/{id}/rsvp {status:INTERESTED}` (onay istemez, kontenjan harcamaz) -> `GET /events/{id}/chat` -> `rooms.addMember` ile odaya girer ve yazar; organizator REJECT/cikarma yapsa bile ayni yolla geri girer.
- Duzeltme: `allowed = rsvp.status==GOING || canManage`; legacy ucu `event.chat.EventChatService`'e yonlendir.

### A1-11 ORTA (M3 HALA ACIK, PoC) Izinsiz DM acma + online/lastSeen izleme
- Dosya: `messaging/ConversationService.java:118-135` (`openDirect`: onay/gizlilik yok), `messaging/ws/PresenceService.java:104-120` (`shareConversation` yeterli), `messaging/MessageController.java:137-140` (hiz siniri yok), gizlilikte presence alani yok.
- Kanit (PoC): kullanici A (id 37) `POST /api/conversations {"userId":38}` -> 201 DM acildi (B'ye bildirim yok); `GET /api/users/38/presence` -> `{"online":false,"lastSeenAt":null}` (B online olsa donecekti). ID'ler ardisik, `openDirect` olmayan kullanici icin 404 verdigi icin varlik oraklidir. 500 kisilik kulup/etkinlik odasi ya da grup ortakligi da `shareConversation`'i saglar.
- Duzeltme: `ProfilePrivacy`'ye `presenceAudience` (varsayilan guvenli), `AvatarVisibility.Field.PRESENCE`; DM "istek" durumu (karsi taraf mesaj atmadan presence yok); presence ucuna `limiter.check("presence:"+uid,60,1dk)`.

### A1-12 ORTA (M2 HALA ACIK) Avatar gizliligi ve moderasyon `avatar_hidden` sohbet/kulup/etkinlik/gonderi yuzeylerinde atlaniyor
- Dosya: `messaging/ConversationService.java:207-214,514-518` (AvatarVisibility enjekte ama AVATAR alani kullanilmiyor; push'ta dogru: `MessageService.java:415-417`), `community/CommunityService.java:619`, `community/CommunityPostService.java:190`, `community/extras/ClubMemberSearchService.java:64`, `event/EventService.java:677,879`, `event/extras/CoOrganizerService.java:83,109`, `event/admission/EventAdmissionService.java:281`.
- Etki: `ONLY_ME`/`SHARED_CONTEXT` olan veya moderasyonla gizlenen fotograf liste yuzeylerinde herkese gorunur; `/files/avatars/<hash>.jpg` herkese acik oldugundan indirilir.
- Duzeltme: tum bu yerlerde `visibility.visibleOwners(viewer, ids, AVATAR)`; `visibility==null` iken avatar gonderme (fail-closed).

### A1-13 ORTA (PoC) Golge engel sizdiriyor: engellenen taraf engellendigini ogreniyor
- Dosya: `messaging/ConversationService.java:539` (`blocked = related.contains(peerId)` - `relatedIds` IKI YONLUDUR), `:386-391` (`requireNotBlocked` 403 BLOCKED), `messaging/ws/PresenceService.java:105-107`, `MessageService.java:462`/`MessageViewAssembler.java:88`, `profile/ProfileService.java:97`, `post/follow/FollowService.java:90`, `event/admission/EventAdmissionService.java:179`, `event/extras/CoOrganizerService.java:62`.
- Kanit (PoC): B (id 38) A'yi (id 37) engeller (204). A (engellenen):
  ```
  GET /api/users/38/presence      -> 404 USER_NOT_FOUND   (engel yokken 200)
  POST /api/users/38/follow       -> 404 USER_NOT_FOUND   (kontrol: baska kullanici 200 {"following":true,...})
  GET /api/users/38               -> followerCount/followingCount/followedByMe/followsMe = null (normal profilde sayi)
  ```
  Ek (STATIK): grup gecmisinde "Engellediginiz kullanicinin mesaji gizlendi" metni; DM `blocked:true`; `POST /conversations` ile `memberIds:[hedef]` 403 BLOCKED = herkes icin engel sondaji.
- Etki: Golge engelin amaci bosa cikiyor, taciz/misilleme riski; profil testi (`ShadowBlockProfileTest`) ile tutarsiz.
- Duzeltme: "ben engelledim" kumesini ayri kullan (`blocks.blockedBy(me)`); beni engelleyen icin ayni sekilde normal yanit (sabit sayac 0/false, follow no-op 200, presence sabit offline, createGroup/openDirect sessiz no-op); `requireNotBlocked` yalniz benim engellediklerim icin.
- Regresyon: `ConversationShadowTest`: `hiddenFrom(1)={2}` ama `hasBlocked(1,2)=false` iken `blocked==false`, presence 200 offline, follow 200.

### A1-14 ORTA Oturum iptalinde (logout-all, sifre degisimi/sifirlama) FCM cihaz kaydi silinmiyor
- Dosya: `notification/SessionDeviceCleaner.java:26-37` (yalniz `newLogin && client=="mobile"`), `auth/token/SessionService.java:41` (`revokeAll`: `newLogin=false`).
- Senaryo: Telefon calinir; kullanici sifre sifirlar/"tum cihazlardan cik" yapar; refresh/WS kapanir ama `device` satiri kalir (temizleme yalniz 60 gun, `last_seen` tazeyse hic); yeni mesajlarin push'lari (gonderen adi, grup basligi, onizleme acikse metin) kilit ekraninda gorunmeye devam eder.
- Duzeltme: `onSessionsRevoked`'da `client==null && !newLogin` ise `devices.deleteAllByUser(userId)`.

### A1-15 ORTA (L7 HALA ACIK) Rapor uclari hedefi gorme yetkisini denetlemiyor
- Dosya: `moderation/ReportService.java:72` (`h.exists`), `community/CommunityReportHandlers.java:30,65`, `event/EventReportHandler.java:27`, `post/admin/PostReportHandlers.java:39`, `moderation/UserReportHandler.java`, `profile/privacy/AvatarReportHandler.java`.
- Senaryo: A, 404 aldigi (PENDING/REJECTED/HIDDEN etkinlik, ozel kulup yazisi, engelleyenin gonderisi, silinmis kullanici) hedefe `POST /api/reports` yapar: 201 = var, 404 = yok (varlik oraklisi). EVENT/FEED_POST geri alinabilir turler; otomatik gizleme esigi (hesap yasina dayali) gorunmeyen hedefe bile birden cok sahte hesapla asilabilir -> rakip etkinlik/gonderi gizlenir.
- Duzeltme: `ReportTargetHandler.exists(viewerId,id)`; her handler ilgili loadVisible/engel/uyelik kuralini uygulasin.

### A1-16 ORTA Gizlilik ayarlari yan kanallardan atlaniyor (bolum/sinif/kulup)
- Dosya: `post/follow/FollowService.java:216-228` (follow-suggestions `reason` CASE: `u.department=me.department` gizlilige bakmaz; bolum PATCH ile serbest degistirilebildiginden her bolumun ONLY_ME uyeleri listelenir), `post/social/SocialFeedRepository.java:20` (DEPARTMENT feed), `profile/privacy/SharedContextRepository.java:29,45` ("ortak baglam" = ayni etkinlige herhangi RSVP, INTERESTED dahil, onaysiz).
- Duzeltme: `reason`'i yalniz alan gorunuruse hesapla; ortak baglamda etkinlik icin GOING; departman feed'inde yazar gorunurlugunu suz.

### A1-17 ORTA Anket hedef kitlesi (audience) yalniz listede suzuluyor; ID ile dogrudan acik
- Dosya: `poll/PollAccess.java:97-106` (`canView` GLOBAL icin true), `poll/PollService.java:85-91` (`get`), karsilastir `list()` `audienceMatches` (`PollService.java:134-135`).
- Senaryo: Bolum/fakulte hedefli GLOBAL ankete baska bolumden kullanici `GET /api/polls/{ardisik id}` ile baslik, secenek ve (showResults=ALWAYS) sonuclari gorur.
- Duzeltme: `canView`'a `audienceMatches(p,user) || canManage`.

### A1-18 ORTA (M11/L9 HALA ACIK) Sohbet videolari yeniden kodlanmiyor/meta temizlenmiyor
- Dosya: `application.properties` ("Video mesaj: sunucu yeniden kodlamaz"), `messaging/media/*` + `media/Mp4Info.java` (yalniz `ftyp/moov/mvhd` ayristirir). Gonderi videosu ffmpeg ile donusturuluyor, sohbet videosu degil.
- Etki: Gomulu GPS/cihaz meta verisi alicilara gider; ham istemci MP4'u dogrudan sunulur (kodek ayristirici saldiri yuzeyi alici cihazda).
- Duzeltme: Sohbet videosunu da `transcode` hattindan gecir (`-map_metadata -1`, `-movflags +faststart`) veya en azindan `udta/meta/©xyz` kutularini kaldir.

### A1-19 ORTA Zayif parola politikasi + hesap basina yuksek tahmin butcesi
- Dosya: `auth/dto/RegisterRequest.java`, `ResetPasswordRequest.java`, `ChangePasswordRequest.java` (yalniz `@Size(min=8,max=72)`); kod tabaninda yaygin parola/ihlal listesi kontrolu yok (grep: `commonPassword|PASSWORD_WEAK` bos). `auth/LoginThrottle.java`: hesap basina istemciden bagimsiz tavan 60 hatali deneme / 15 dk (~5760 tahmin/gun/hesap).
- Senaryo: Ogrenci numarasi giris tanimlayicisi olarak bilinir/tahmin edilir (`226051015@bingol.edu.tr`); "12345678", "bingol1234" gibi parolalar kabul edilir; saldirgan farkli X-Device-Id/IP ile hesap basina gunde binlerce tahmin yapar. Test yiginda `Sifre1234` kabul edildi.
- Etki: Kullanici hesabi devralma (credential guessing), ozellikle ADMIN_EMAILS dahil yonetici hesaplarinda.
- Duzeltme: Yaygin parola listesi (top 10k) + e-posta/ogrenci numarasi iceren parolalari reddet; yonetici hesaplarinda 12+ karakter; hesap basina artan bekleme (uzayan kilit) ve basarili girisin farkli cihazdan oldugunda bildirim (`NewLoginNotifier` var, kapsamini dogrula).
- Regresyon: `AuthServiceTest`: `12345678`, `password1`, `<ogrenci no>` kayit/reset/change -> 400 `PASSWORD_TOO_WEAK`.

### A1-20 ORTA Hesap kilidi kasti (saldirgan kurbanin girisini kilitleyebilir)
- Dosya: `auth/LoginThrottle.java` `check`: `requireBelow(emailKey(email), loginEmailFailMax=60)` istemciden bagimsiz; ayrica `(email,ip)` cifti 30 hata (`login-email-ip-fail-max`).
- Senaryo: Saldirgan kurban e-postasiyla 60 hatali deneme (2 IP veya cihaz kimligi yeterli: cift sayaclari 30'da dolar) yapar -> kurban 15 dk giris yapamaz; saldirgan tekrarlar (surekli kilit). `X-Device-Id` istemci kontrollu. Onceki denetim L4/L15 "cift basina" duzeltmesi yaptı ama hesap geneli tavan kaldı.
- Etki: Hedefli hizmet reddi (ornegin sinav gunu bir hesabi kilitle). Ayni tavan `/verify-reset-code` icin yok (bu iyi).
- Duzeltme: Hesap geneli tavani "bilinen cihaz/IP" ayrimi ile (kullanicinin son basarili giris cihazlari muaf) veya CAPTCHA/PoW adimi; kilit yerine artan gecikme.

### A1-21 ORTA /files/** herkese acik; ozel kulup gonderi gorselleri URL ile sonsuz acik (C6)
- Dosya: `config/SecurityConfig.java` (`/files/**` permitAll), `common/storage/FileController.java` (`Cache-Control: public, immutable, 30 gun`), kulup gonderi gorseli `/files/posts/<uuid>.jpg`.
- Etki: Ozel kulubun gorselinin URL'si sizarsa/eski uye bilirse sonsuza kadar kimliksiz erisilir; URL tahmin edilemez (UUID/ozet) bu yuzden ORTA-DUSUK. Gizlilik ayari ONLY_ME avatarlar da bu yolla (A1-12).
- Duzeltme: Ozel kulup gorselleri icin imzali/yetkili sunum (sohbet medyasindaki `MediaUrlSigner` deseni).

---

## 4. DUSUK bulgular

### A1-22 DUSUK (PoC) Herkese acik destek talebi kimligi icin 500 (NPE) = varlik oraklisi
- `support/ticket/TicketService.java:177` `ownTicket`: `t.getUserId().equals(userId)`; public talepte `userId=null`.
- Kanit (PoC): `GET /api/support/tickets/1` (baska ajanin public talebi) normal kullanici ile -> **500** `{"timestamp":...,"status":500,"error":"Internal Server Error","path":...}`; ID 2..5 (yok) -> 404 `TICKET_NOT_FOUND`. Log: `NullPointerException ... SupportTicket.getUserId() is null`. Ayrica 500 yaniti `ApiExceptionHandler` bicimi (traceId) disinda dusuyor (Spring varsayilani).
- Duzeltme: `Objects.equals(t.getUserId(), userId)`; null -> 404. Test: public talep ID'si ile GET/reply/close 404. Genel: yakalanmamis `Exception` icin `ApiExceptionHandler`'a catch-all (500 + traceId).

### A1-23 DUSUK (L45 HALA ACIK) Yonetici `DELETE /api/users/me` ile kendini siler
- `profile/ProfileService.java:233-239` `deleteAccount`: LAST_ADMIN/ADMIN korumasi yok (korumali yol yalniz `AdminUserService.java:134-158`). Son aktif ADMIN hesabi anonimlestirebilir -> panel kilitlenir.
- Duzeltme: `role==ADMIN && countByRoleAndStatus(ADMIN,ACTIVE)<=1` -> 409 `LAST_ADMIN`; ADMIN_EMAILS/pinned icin ek koruma.

### A1-24 DUSUK Imzali sohbet medyasi adresi silme/uye cikarmadan sonra TTL boyunca gecerli (MSG-06)
- `messaging/media/MessageAttachmentService.java:690-701`, `media/MediaUrlSigner.java:31-44`, `media/PrivateMediaController.java:25-33`: bearer link kullaniciya bagli degil; TTL 5 dk (config <=1 sa). Silme anahtari degistirmiyor.
- Duzeltme: delete/removeMember sonrasi anahtari rotasyonla veya TTL 60 sn.

### A1-25 DUSUK (L24 HALA KISMEN ACIK) Hiz siniri eksik yazma/okuma uclari
- `BlockController.java:34-44` (`POST/DELETE /api/users/{id}/block`: limit yok; var olmayan id 404 vs 204 = kimlik oraklisi), `LegalController.java:91` (`POST /api/legal/consents|accept`, `AcceptRequest.items` icin `@Size` ust siniri yok, her kalem DB sorgusu), `ProfileController.update` (`PATCH /api/users/me`), `ProfileController.get` (`GET /api/users/{id}`: user-search gunluk 500 kotasini atlatarak ID taramasiyla dizin cekilir), `DELETE /api/suggestions/{id}/vote`, `POST /api/support/tickets/{id}/close`, `GET /api/users/{id}/presence`, `GET /api/conversations`, `GET /api/notifications`, `/api/bookmarks*`, `POST /api/auth/logout` (kimliksiz).
- Duzeltme: ilgili uclara `limiter.check`; `AcceptRequest.items @Size(max=10)`; `/users/{id}` icin dakika/gun kotasi. Test: `RateLimitCoverageTest` (her yazma ucunda limiter cagrisi).

### A1-26 DUSUK Hesap silme kapsami: IP/cihaz izleri
- `profile/AccountDataPurger.java` listesinde `blocked_attempt_log` (ip, device_hash, user_id), `profanity_hit_log`, `moderation_strike`, `suspend_recommendation`, `club_audit.target_user_id`, `message_access_audit.target_user_id` yok (QA yigininda `information_schema` taramasiyla kullanici sutunlu tablolar listelendi). Bir kismi hukuki saklama/moderasyon izi olarak tutulabilir ama beyan edilmeli; `blocked_attempt_log` icin saklama suresi `DbMaintenanceJob`'ta dogrulanmadi.
- Duzeltme: Her tablo icin "sil / anonimlestir / yasal saklama" karari `docs/DATABASE.md`'ye + `AccountDataPurgerCoverageTest` (yeni user-sutunlu tablo listede degilse basarisiz).

### A1-27 DUSUK Mesaj icerigi / silinen mesaj saklama ve view-once suresi
- `app.chat.deleted-retention-days=0` (silinen mesajlar sifreli ama SURESIZ), `app.chat.media.view-once-retention-days=365` (tek gosterimlik gorsel bayti alici actiktan sonra 1 yil diskte; `MessageAttachmentService.java:603-606`), `edit-window=0/delete-window=0` (sinirsiz duzenleme/silme). Kullanici beyani ("bir kez") ve KVKK ile celisme riski.
- Duzeltme: sureleri sinirla (ornek 30/90 gun) ve aydinlatma metniyle hizala.

### A1-28 DUSUK Engelli taraf eski mesajlara tepki/duzenleme yapabiliyor (MSG-05)
- `messaging/MessageActionService.java:254-262` (`requireDirectNotBlocked` hesaplar ama kullanmaz), `MessageReactionRepository.java:16-18`, `MessageViewAssembler.java:66-69`. Engelleyenin history'sinde engellenenin tepki sayaci/duzenlenmis metni gorunur.

### A1-29 DUSUK FCM token URL yolunda ve sahiplik kanitsiz devralma (MSG-08)
- `messaging/ws/ClientStateController.java:64-70`, `notification/NotificationController.java:63-69`, `notification/DeviceService.java:48-59` (token baska kullaniciya aitse tasinir). Token proxy/erisim loguna dusebilir; bilen kisi `POST /api/devices` ile bildirimleri kendine cevirir. Duzeltme: token body'de, logda maskele.

### A1-30 DUSUK JWT ve oturum tasarim notlari
- `auth/jwt/JwtService.java`: `iss`/`aud` yok (tek servis, dusuk risk); access token'da `email` talebi (PII, base64 okunur); `suspended:<id>` yalniz Redis'te TTL'siz (AOF aciksa kalir; Redis verisi kaybolursa askiya alinanlar max 15 dk access token ile devam eder; refresh `isActive` ile engellenir). `/api/auth/logout` rate limit'siz. Test: `alg:none` ve dev-varsayilan sirla uretilmis HS256 token -> 401 (PoC).

### A1-31 DUSUK Basic auth (acikken) sartlari
- `config/BasicAuthThrottleFilter.java`: fail-closed, IP 10 / kullanici adi 30 hata sinirli (iyi). Kullanici adi sayaci IP'den bagimsiz oldugundan herhangi biri `admin` adiyla 30 hatali deneme yaparak 15 dk acil durum girisini kilitleyebilir; Basic yonetici tek ortak kimlik (`basic-admin`), her zaman FULL; iki kisi onay ve sohbet goruntuleyici JWT ister. Prod'da varsayilan KAPALI (`application-prod.properties`).

### A1-32 DUSUK Sunucu arama kehaneti (maskeli profillerde)
- `admin/UserFilter.java:51-53` ve `mail/admin/MailSuppressionAdminService.hashesFor`: `users.pii` olmayan profil `q=` ile e-postayi ILIKE araya araya yeniden kurabilir. Duzeltme: `canSeePii()` yoksa `q` yalniz `display_name`.

### A1-33 DUSUK Denetim ve gerekce kapsami bosluklari
- Kisisel veri okuyan GET'ler denetimsiz (`/users`, `/users/{id}/sessions`, `/push-devices`, `/pending-registrations`, `/support/tickets/{id}`, `/moderation/strikes`, `/reports`; `@AuditRead` yok). Denetim `afterCompletion`'da ve hata yutularak yaziliyor (sohbet icerigi haric fail-closed). `admin_audit` `RetentionTables`'ta silinebilir (FULL; `data_purge_log` iz birakir). Gerekce/limit eksik: `POST /users/{id}/verify-email|send-reset|revoke-sessions`, `POST /access-bans` (CIDR ile yonetici IP'lerini engelleyebilir; oz-kilit korumasi yalniz aktor), `POST /push/campaigns`, `mail/campaigns/*`, `POST /crypto/rewrap`, `PUT /settings/{key}`, `POST /moderation/appeals/{id}/decide`. `X-Admin-Reason` icerigi dogrulanmiyor.

### A1-34 DUSUK Kulup yasam dongusu: silinmis/gizli kulupte islem devami
- `community/permissions/ClubRoleService.java:204`, `ClubOwnershipService.java:209`, `ClubInviteService.java:162`: `findById` ile yuklenir, DELETED/REJECTED/HIDDEN kontrolu yok; `CommunityService.update:292` moderasyonla gizlenen kulupte sahibin ad/gorsel guncellemesine izin verir.

### A1-35 DUSUK Etkinlik spam siniri uygulanmiyor; QR yoklama kodu kullaniciya bagli degil
- `EventAdmissionHooks.beforeCreate` (kullanici basina acik/gunluk limit) hicbir yerden cagrilmiyor; yalniz limiter 10/saat. QR kodu 30 sn pencerede ekran goruntusuyle baskasi adina yoklamaya izin verir (tasarim sinirlamasi).

### A1-36 DUSUK Rehber eslestirme (ContactMatchService) ve oz-beyan bolum
- `profile/ContactMatchService.java`: `showEmail=false` kullanicinin e-posta SHA-256'siyla varligi/id'si dogrulanabilir (6 istek/saat x 500 hash; tuzsuz hash, bingol.edu.tr tahmin edilebilir). `AcademicAudience`: bolum oz-beyan (PATCH /users/me) iken akademik duyuru/anket hedeflemesinde yetki olarak kullaniliyor.

### A1-37 DUSUK Bos eleman 500 riski ve HEAD davranisi
- `ConversationService.java:144,278` `memberIds/userIds` icinde `null` eleman -> `findAllById([null])` istisnasi (500 mu 400 mu DOGRULANAMADI). Alt ajan S-08 (HEAD istekleri GET-yalniz kurallari atlar): PoC'de duz `HEAD /api/admin/users/2/conversations` 400, kodlu yol HEAD 200 dondu (A1-01 ile ayni kok neden); bagimsiz HEAD bypass'i bu yigin davranisiyla dogrulanamadi.

### A1-38 DUSUK Gunluk/log ve yapilandirma
- `AdminAccountVerificationService.java:70` `log.info("ADMIN_VERIFY ... email={}")` ham e-posta (LogMasking kullanilmiyor).
- Dev/staging log-only modunda (`MAIL_ENABLED=false`) dogrulama kodu ve destek takip tokeni log'a yazilir (belgelenmis; prod `allow-log-only` bilincli verilmedikce acilmaz).
- `prod` profilinde `logging.pattern.console` tum desenin yerine gectiginden `X-Request-Id` (MDC `requestId`) log satirinda yok (`application.properties` `logging.pattern.level` etkisiz); korelasyon icin `%X{requestId}` ekleyin.
- `/api/hello` kimliksiz (surum/ic bilgi yok; zararsiz).
- `mobile/android/app/google-services.json` repoda Firebase istemci API anahtari (`AIza...`) iceriyor: istemci anahtari tasarimi geregi herkese aciktir ama Google Cloud konsolunda Android paket/SHA-1 ve API kisiti zorunlu olmali (konsol tarafi DOGRULANAMADI).

### A1-39 DUSUK Rate limit anahtar butcesi tasma kovasi
- `common/RateLimiter.java`: saatlik 200k yeni anahtar butcesi asilinca ilgili onek ortak tasma kovasina (limit x 50) duser. Dagitik bir saldirgan butceyi bitirirse tum `register:email:*` gibi kovalar paylasimli hale gelir (hizmet duser; kasitli tasarim, belgelenmeli). Redis hatasinda (`increment` istisnasi) istek 500 olur (fail-closed, kabul edilebilir).

---

## 5. Bilgi / tasarim notlari (ihlal degil)
1. Kripto (`crypto`): AES-256-GCM, 96-bit rastgele nonce, AAD uzunluk onekli (`Aad.java`), DEK sohbet basina, KEK sarma AAD'li; parcali blob sayac nonce + son parca bayragi -> IV tekrari bulunamadi. Notlar: `BusCipher`/`MediaBlobCipherAdapter` tek turetilmis anahtarla cok sayida rastgele nonce uretiyor (2^32 siniri uzun vadede; aktif master anahtar rotasyonu planlayin); `MediaBlobCipherAdapter.decrypt` MAGIC yoksa duz bayti oldugu gibi doner (gecis donemi; disk yazma gerektirir).
2. Yukleme: `.jpg` icerigi HTML, SVG, `GIF89a<?php` -> 400 `INVALID_FILE`; PNG + sonuna `<?php`/`<script>` eklenmis dosya kabul edildi ama yeniden kodlanip temiz `.jpg`ye cevrildi (PoC: ciktida `php|script` yok, JFIF baslik, `nosniff`, `image/jpeg`). Dosya adi icerik ozeti, yol gezinme regex'i + `startsWith(root)`.
3. WebSocket/STOMP: CONNECT'te JWT + askida + erisim engeli + oturum iptali; SEND yalniz `/app/**`; SUBSCRIBE yalniz 5 sabit `/user/queue/*`; kare hiz siniri; allowed-origins bos = same-origin; kimlik cerezde degil (CSWSH yok).
4. CORS: `allowCredentials=false`, yalniz `/api/**` ve `/files/**`; evil origin preflight 403 (PoC). CSRF kapali (stateless Bearer) uygun. `ProdSettingsValidator` `*` reddeder.
5. Actuator/Swagger: anonim yalniz `/actuator/health`; `/actuator/env|prometheus`, `/v3/api-docs`, `/swagger-ui.html` anonim 401, normal kullanici 403 (PoC); Caddy ayrica `/actuator*`, `/swagger-ui*`, `/v3/api-docs*` icin 404.
6. XFF sahteciligi: `ClientIp` yalniz guvenilir proxy'den XFF alir, sagdan sola; Caddy `header_up X-Forwarded-For {client_ip}` istemci basligini ezer. Varsayilan guvenilir ag tum ozel araliklari (10/8, 172.16/12, 192.168/16, fc00::/7) kapsar: arka uc dogrudan erisilebilir (host portu yayinlanir ya da ozel aga bagli baska konteyner) olursa XFF sahtelenir; prod compose `8080` yayinlamiyor (A4/A8 CI kapisi). QA yiginda host gateway ozel aralik oldugu icin bu davranis beklenir.
7. Hata govdeleri: `server.error.include-*=never`; 4xx `{message,code,traceId}`; yigin izi sizmiyor (PoC malformed JSON, 500 NPE govdesi bos ayrinti).
8. Mass assignment: `PATCH /api/users/me` govdesine `role/status/emailVerified/adminProfile/email` eklendi -> yok sayildi (yanit `role:USER`, e-posta degismedi) (PoC). Kod taramasinda entity bind eden uc yok.

---

## 6. Alt bilesen dogrulama ozetleri (temiz bulunanlar)
- Mesaj/ek/bildirim/favori IDOR: tum yollar `requireMember`/user_id kapsamli; baskasinin sohbeti `404` (PoC: kullanici `/api/conversations/21` -> 404, `/messages` -> 404). View-once: gonderen 403, ikinci acis 410. Imzali URL HMAC-SHA256 sabit zamanli karsilastirma.
- Kulup rol/izin yonetimi, sahiplik devri, davet kodu (SHA-256, atomik), QR/elle yoklama kodu (HMAC, 30 sn, `isEqual`), sertifika dogrulama (100 bit `SecureRandom`, IP basina 20/dk), anket oy atomikligi ve gizli oy (kimlik hicbir API'de donmez), gonderi/profil/KVKK export, destek/oneri panosu, arama gizli icerik suzmesi.
- Admin: dinamik SQL parametreli (`UserFilter` siralama beyaz liste + LIKE kacirma, `RetentionTables` sabit liste), CSV formul kacisi (`Csv.cell`) tum export'larda, `MailTemplateSanitizer` jsoup Safelist https-only, push/duyuru/banner URL `https://` zorunlu, SSRF yok (scraper yalniz `www.bingol.edu.tr`/sabit menu URL'si), veri saklama purge (gerekce + tablo adi onayi + `Idempotency-Key` + makbuz), RBAC iki kisi onayi (`/rbac` yolunda).
- Haber icerigi duz metin (`Element.text()`), HTML saklanmiyor (stored XSS yok); mail sablonlari HtmlUtils ile kacisli.
- Cache (`common/cache/CacheService`): anahtar beyaz listesi `[A-Za-z0-9:_.,=@-]{1,160}` + `ns` regex; onbellege yalniz "herkese ayni" uclar giriyor; kullanici girdili arama metni onbelleklenmez; cache zehirlenmesi bulunmadi.
- Regex'ler: `UNIVERSITY_EMAIL` dogrusal (ReDoS yok; `matches()` tam eslesme; `a@bingol.edu.tr.evil.com`/`evilbingol.edu.tr` reddedilir - statik analiz).
- Dockerfile: `eclipse-temurin:17-jre`, `USER app` (uid 1001, root degil), HEALTHCHECK; floating etiket (digest sabitlenmemis; onceki L40).
- Depo gecmisi: `git log -S` ile `BEGIN PRIVATE KEY`, `AKIA...`, `ghp_`, `xox[bp]-`, `private_key_id` arandi; kaynak kodda sir yok (yalniz `google-services.json` istemci anahtari ve belgelerde yer tutucu); izlenen `.env*` dosyalari yalniz `.example`.

---

## 7. Bagimlilik incelemesi (elle surum incelemesi)
OWASP dependency-check calistirilmadi (NVD erisimi/API anahtari yok, sure). Elle surumler (`backend/pom.xml`): Spring Boot parent 4.1.2, jjwt 0.12.6, jsoup 1.18.3, firebase-admin 9.4.1, bucket4j 8.14.0, imageio-webp 3.12.0, springdoc 3.2.0, sentry (`${sentry.version}`), postgresql/flyway/h2(test) yonetilen surum. H2 yalniz `test` kapsaminda (uretim jar'ina girmez, H2 konsolu yok).
- jsoup 1.18.3 ve firebase-admin 9.4.1 (gecisli bagimlilik: netty/grpc/protobuf/guava) icin guncel CVE listesi hafizadan DOGRULANAMADI; `mvn org.owasp:dependency-check-maven:check` (NVD anahtariyla) CI'da zorunlu tutulmali (onceki L41). Oneri: `jsoup` ve `firebase-admin`'i en son kararli surume yukseltin, `mvn dependency:tree | grep -E "netty|grpc|protobuf|guava"` ile gecisli surumleri kontrol edin.

---

## 8. DOGRULANAMADI
1. Alt ajan S-08 (HEAD ile GET-yalniz kurallar): bagimsiz bypass PoC'de gorulmedi (A1-37).
2. A1-02, A1-03, A1-10, A1-15, A1-16, A1-17 PoC ile degil kod okumasiyla dogrulandi (yikici/kurulum maliyeti); duzeltme sonrasi regresyon testleri yazilirken PoC uretilmeli.
3. A1-01'de `PATCH /users/{id}/%72ole` ve `POST /sources/%73ync` ile yetki yukseltme PoC calistirilmadi (yikici/dis kaynak).
4. `ADMIN_EMAILS` icinde hesabi olmayan adres olup olmadigi (A1-05 on kosulu) uretimde kontrol edilmedi (erisim yasak).
5. jsoup 1.18.3 / firebase-admin 9.4.1 / gecisli bagimliliklarin bilinen CVE'leri (bolum 7).
6. Firebase API anahtari kisitlari (Google Cloud konsolu, A1-38).
7. `ClubJoinAnswer` onay sonrasi silinmesi (KVKK veri azaltma, `decide(approve)` `dropAnswers` cagirmiyor gibi) ve hesap silmede `device` kayitlari/`tokensForUsers` status filtresi (alt ajan dogrulayamadi; `AccountDataPurger` `DELETE FROM device` icerir, yani cihaz silme kapsami iyi gorunuyor).

## 9. Oncelik onerisi
1) A1-01 (tek `AdminPaths` cozumleyicisi + test; kolay, yuksek etki), 2) A1-02 + A1-04 (admin yetki/PII), 3) A1-03/A1-10/A1-09 (etkinlik yetkisi), 4) A1-05/A1-06/A1-07/A1-08 (yonetici hesap guvenligi), 5) A1-19/A1-20 (kimlik dogrulama), 6) A1-11..A1-18 (gizlilik/engel/avatar/video), 7) kalan DUSUK maddeler.
