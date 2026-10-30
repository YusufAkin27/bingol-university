# A16 - Kötüye kullanım / moderasyon / spam / güven-etik denetimi

Tarih: 2026-10-31. Denetçi: A16. Kapsam: backend `moderation`, `post`, `support`, `messaging`, `community`, `event`, `profile`, `auth` (kayıt/kod akışları), mobil/web ilgili metinler.
Yöntem: statik kod incelemesi + A7 test yığını (`http://localhost:18081`, yalnız izole QA yığını; üretime erişilmedi). Kendi hesaplarım: `a16_a`, `a16_b`, `a16_c`, `a16_d` (+ `a16_victim1`, `a16_pub1`). Kod DEĞİŞTİRİLMEDİ. Ortak Redis flush edilmedi, yıkıcı/DoS testi yapılmadı (sınırın varlığı kanıtlandı, zorlanmadı).
Filtre atlatma denemeleri, filtrenin gerçek sınıfları (`ProfanityText`, `ProfanityMatcher`) ve gerçek kelime listeleriyle çevrimdışı bir Java koşum düzeneğinde (Docker `eclipse-temurin:17`) ve QA API'sinde (`PATCH /api/users/me` bio, `POST /api/posts`) yapıldı.

Etiketler: KANITLANDI = QA yığınında çalıştırıldı; STATİK = yalnız kod okuması.

## Özet

| Şiddet | Adet |
|---|---|
| KRİTİK | 0 |
| YÜKSEK | 3 |
| ORTA | 9 |
| DÜŞÜK | 8 |

Genel izlenim: kimlik doğrulama kod postası, herkese açık destek formu, rapor/engel mekaniği, gönderi kuralları (1 fotoğraf, 7 kelime/60 karakter) ve yazma uçlarının hız sınırı kapsamı olgun ve sunucuda zorlanıyor (aşağıda "İyi çalışanlar"). Asıl riskler: (a) kayıt sırasında görünen ad politikasının atlanması, (b) rızasız DM/grup ekleme, (c) içerik filtresinin e-posta/bağlantı biçimli parçaları tümden atlaması ve izin listesinin gerçek küfrü gölgelemesi, (d) kulüp/etkinlik adlarında kurum taklidi denetimi olmaması.

## En kritik 5

1. A16-01 Kayıtta `DisplayNamePolicy` uygulanmıyor: "Rektörlük Duyuru", "Admin Destek", `KAZANDIN bit.ly/x9 tikla` adlı hesaplar açıldı; ad takip bildirimi push metnine giriyor.
2. A16-02 DM ve grup eklemede rıza/istek yok; kullanıcıyı gruptan çıksa da tekrar tekrar ekleyebiliyorsunuz (3/3 başarılı).
3. A16-03 Filtre, `@` ve `.` içeren ya da `://` içeren boşluksuz parçayı tümden atlıyor: `orospu@x.y gelin` Keşfet gönderisi olarak yayınlandı (201).
4. A16-04 İzin listesi gevşek biçimi gerçek küfrü açıyor: `sikis`, `siki`, `sikici`, `amina koydum` geçiyor.
5. A16-06 Kulüp adı `Bingöl Üniversitesi Rektörlüğü` ve `BU Kampus Resmi Duyuru` anında ACTIVE; kurum taklidi denetimi yok.

---

## Bulgular

### A16-01 - YÜKSEK - Kayıtta görünen ad politikası atlanıyor (KANITLANDI)
- Uç/dosya: `POST /api/auth/register` -> `backend/.../auth/AuthService.java:154-158` (yalnız `ContentGuard.clean`), `auth/AccountCreator.java:34` (`user.setDisplayName(p.displayName())`). `DisplayNamePolicy.normalize` yalnızca `ProfileService.update` (`profile/ProfileService.java:136`) ve `AdminUserProfileService` içinde çağrılıyor; `RegisterRequest.displayName` yalnız `@NotBlank @Size(max=80)`.
- Senaryo: (1) `a16_a` ... `displayName="Rektörlük Duyuru"`, `a16_d` ... `"Admin Destek"`, `a16_b` ... `"KAZANDIN bit.ly/x9 tikla"` ile kayıt ol, e-posta kodunu doğrula (hepsi 202 -> 200). (2) Aynı adlar profil güncellemesinde reddedilir (`RESERVED_DISPLAY_NAME`, `INVALID_DISPLAY_NAME`) - yani politika var ama kayıt yolu onu atlıyor. (3) `a16_b` ile `qa-user1`'i takip et: alıcının bildirimi `"KAZANDIN bit.ly/x9 tikla seni takip etti"` (push metni de aynı gövde).
- Etki: yönetici/rektörlük/destek taklidi, bildirim/push üzerinden oltalama metni ve bağlantı taşıma (takip 60/dk, günlük üst sınır yok; bildirim aynı takipçi için tek sefer ama her yeni hesap yeni bildirim). Kayıtta ayrıca sıfır genişlikli/bidi/görünmez karakter, 3+ emoji ve Latin+Kiril karışımı da engellenmiyor (politika yalnız profil güncellemesinde). Taklit hesap, sohbet/grup/kulüp üye listesinde görünür.
- Öneri: `AuthService.register` içinde `DisplayNamePolicy.normalize(displayName, adminEmail)` çağırıp normalize edilmiş adı `Pending`'e yazın (ADMIN_EMAILS adresleri muaf). Mevcut hesaplar için tek seferlik tarama (admin sorgusu) ile ihlalli adları işaretleyin.

### A16-02 - YÜKSEK - Rızasız DM / grup ekleme; çıkışa rağmen tekrar ekleme (KANITLANDI)
- Uç/dosya: `POST /api/conversations` (`messaging/ConversationService.openDirect` 117-135, `createGroup` 137-165), `POST /api/conversations/{id}/members` (`ConversationService` ~283). Korumalar: yalnızca engelleme (`requireNotBlocked`), `conv:create` 30/gün, mesaj 30/dk.
- Senaryo: `a16_c`, hiç ilişkisi olmayan `qa-user1`'e DM açıp mesaj gönderdi (201); `{"title":"Kazan Grubu","memberIds":[2,22,23,25]}` ile 4 kişiyi izinsiz gruba ekledi (memberCount 5) ve mesaj yazdı; hedefin bildirimlerinde "Yeni mesaj" x2 belirdi. Hedef gruptan çıktı (204), saldırgan aynı kullanıcıyı 3 kez art arda yeniden ekledi (3/3 HTTP 200). Tek kaçış: saldırganı engellemek (sonra 403 `BLOCKED`).
- Etki: gün başına 30 yeni sohbet x 49 üye = binlerce kişiye taciz/spam (grup başlığı küfür filtresinden geçer ama grup mesajı muaftır). Ad kayıtta denetlenmediği için (A16-01) tacizci adı da serbest. Grup başlığı/avatarı ve grubun kendisi raporlanamıyor (bkz. A16-11).
- Öneri: (1) "mesaj isteği" modeli: ilk DM/ilk grup daveti `PENDING`, alıcı kabul edene kadar bildirim/push yok, tek taraflı mesaj sınırı (ör. yanıtsız en fazla 3). (2) Gruba ekleme: "davet" -> kabul; en azından kullanıcının çıktığı gruba aynı kişi tarafından yeniden eklenmesini yasaklayın. (3) Gizlilik ayarı: "Kim bana yazabilir? Herkes / Takip ettiklerim / Ortak kulüp-etkinlik". (4) Günlük "yeni karşı taraf" sınırını düşürün (örn. 10) ve grup üyesi başına günlük ekleme tavanı.

### A16-03 - YÜKSEK - İçerik filtresi bağlantı/e-posta biçimli parçayı tümden atlıyor (KANITLANDI)
- Uç/dosya: `moderation/profanity/ProfanityMatcher.java:isLinkLike` (tokenize içinde `continue`). Kural: boşluksuz parça `://` içeriyorsa, `www.` ile başlıyorsa ya da `@` sonrasında nokta varsa hiç denetlenmez.
- Senaryo: `PATCH /api/users/me {"bio":"orospu@x.y"}` -> 200; `siktir@a.b gidin` -> 200; `www.orospu` -> 200; `orospu://x` -> 200. `POST /api/posts {"text":"orospu@x.y gelin","mediaIds":[1]}` -> 201 (Keşfet'te herkese açık yayınlandı; gönderi 1). Karşılaştırma: aynı kelime çıplak yazılınca 422.
- Etki: tüm `ContentGuard` korumalı alanlar (gönderi, profil, kulüp/etkinlik adı-açıklaması, anket, duyuru, geri bildirim) tek bir ek karakterle (`@x.y`) atlatılıyor; ayrıca gerçek bağlantıların kendisi (oltalama URL'leri) hiç incelenmiyor.
- Öneri: bağlantı/e-postayı atlamak yerine parçayı `@`, `/`, `.`, `:` üzerinden de bölerek aynı eşleştirmeden geçirin (URL/alan adı ayrıca kendi kara liste/izin listesiyle denetlensin); en azından atlama yalnızca tam geçerli bir URL/e-posta ayrıştırması başarılı olursa yapılsın. Gönderi/profil gibi kısa alanlarda bağlantıyı tümden yasaklamayı değerlendirin.

### A16-04 - ORTA - Filtre atlatma/izin listesi boşlukları (KANITLANDI + çevrimdışı koşum)
Aşağıdakiler QA API'sinde bio alanında 200 verdi (temiz sayıldı) ya da çevrimdışı koşumda `clean` çıktı:
1. İzin listesi gölgelemesi: `ProfanityMatcher.addAllow` meşru "sıkış/sıkı/sıkıntı" için gevşek (ı->i) biçimi de tam eşleşme izni olarak ekliyor; sonuç: ASCII `sikis`, `siki`, `sikici` (gerçek küfür biçimleri) temiz sayılıyor. Ayrıca `sikmişim`, `sikilmiş`, `SIKIŞIK`.
2. İki uzun sözcüklü sabit ifade: bitişik sözcük birleştirme yalnız bir sözcük <=4 harfse çalışıyor; `amına koyayım`, `amina koydum`, `amina koyayim`, `amına koyayım` temiz. `anan`, `bacını`, `sülaleni` listede yok.
3. Homoglif eşleme eksik: Kiril `ѕ` (U+0455) ve `і` birlikte `ѕіktіr` temiz (`ѕiktir` temiz); Kiril `ф`(`фuck`) ve Yunan/Kiril `у` bileşimleri (`fуck`) temiz. `ProfanityText.map` yalnız belirli bir alt küme kapsıyor.
4. Leet/ünsüz atma: `fvck`, `phuck`, `mthrfckr`, `amnskm`, `a.q`, `kahbe`, `pezeveng`, `orosbu` (yalnız kısmi), tek harfli arama `g ö t` temiz; `göt`, `oç`, `piç` (yalnız "piç kurusu" ikilisinde) temiz.
5. Ters yazım (`ritkis`), emoji ile kodlama, Latin dışı yazıda araya harf sokma doğası gereği yakalanmıyor (bilinen sınır; bilgi amaçlı).
Doğru çalışanlar: boşluk/nokta/yıldız/alt çizgi ayırıcı (`s.i.k.t.i.r`, `s*k*t*r`), sıfır genişlikli karakter ve yumuşak tire, tam genişlik ve matematik-kalın harfler (NFKD), `İ/I/i/ı` büyük-küçük harf, 1/3/0/@/$ leet, harf tekrarı (`siiiiktir`), Arapça harekeli/tatweelli yazım.
- Etki: küfür filtresi motive bir kullanıcıyı durdurmaz; yine de sohbet muaf olduğundan asıl risk herkese açık alanlardadır (gönderi, bio, kulüp/etkinlik).
- Öneri: izin listesi gevşek biçimini yalnızca "sıkıntı/sıkışık" gibi uzun sözcüklere tam eşleşme için ekleyin, `sikis/siki` için engelleme satırı + izin girdisini ayrı tutun; ek homoglif tablosu (confusables) ve `phuck/fvck` türevleri; "amına koy*" ifadesi için ayrı kalıp (sözcük-başı eşleşme); `piç`, `göt`, `oç` için bağlama dayalı (`=` tam eşleşme + yan sözcük kuralı) kural değerlendirin.

### A16-05 - ORTA - Nefret söylemi/kurum taklidi için içerik listesi yok; Kürtçe/Zazaca kapsanmıyor (KANITLANDI)
- Senaryo: `nazi hitler`, `zenci gavur` bio olarak 200. Listede (`profanity-tr/en/ar.txt`, LDNOOBW tabanlı) etnik/dinî aşağılama terimleri, terör örgütü övgüsü, intihara yönlendirme yok. Bingöl'de yaygın Kürtçe (Kurmancî/Zazakî) küfür ve hakaret hiç kapsanmıyor.
- Etki: nefret söylemi yalnızca kullanıcı raporu + admin incelemesiyle yakalanır; filtre yanlışlıkla "temiz damgası" verir.
- Öneri: ayrı "nefret/terör" kelime kümesi (admin panelinden `profanity_term` ile genişletilebilir, mevcut altyapı yeterli), Kürtçe liste; hit günlüğü (`ProfanityHitLog`) üzerinden periyodik gözden geçirme.

### A16-06 - ORTA - Kulüp/etkinlik adlarında kurum taklidi denetimi yok (KANITLANDI)
- Uç/dosya: `community/CommunityService.create` (134-136: yalnız `ContentGuard`), `event/EventService.create` (195-197). `DisplayNamePolicy` rezerve kelime/ifade listesi (`rektor`, `resmi`, `bingoluniversitesi`, `bukampus`, `destek`...) yalnızca kullanıcı adı için kullanılıyor.
- Senaryo: `a16_c` `POST /api/communities` `name="Bingöl Üniversitesi Rektörlüğü"` -> 201 `ACTIVE` (anında yayın, `app.community.auto-approve=true`); `name="BU Kampus Resmi Duyuru"` -> 201 `ACTIVE`. Ad aranabilir/Keşfet'te listelenir, sahip üyelere duyuru + push yollayabilir (10/sa, kulüp başına günlük limit var). Ad için görünmez karakter/bidi normalizasyonu da yok.
- Etki: öğrencileri yanıltan "resmî" görünümlü kulüp/etkinlik; mağaza "taklit" politikasına aykırı kullanıcı içeriği; hukuki risk (üniversite adı kullanımı izni henüz alınmamış: `docs/LAUNCH_CHECKLIST.md`).
- Öneri: `DisplayNamePolicy.isReserved` benzeri bir "rezerve ifade" denetimini kulüp adı, etkinlik başlığı ve duyuru başlığına da uygulayın; eşleşenler `PENDING_REVIEW`'e düşsün (otomatik onay yalnızca temiz adlarda). Ad alanlarında `FORMAT`/bidi/görünmez karakter reddi ekleyin.

### A16-07 - ORTA - Rehber eşleştirme ile kayıtlı kullanıcı/ad taraması (KANITLANDI)
- Uç/dosya: `POST /api/users/contacts/match` (`profile/ContactMatchController`: kullanıcı başına 6/sa, IP başına 30/sa; her istek <=500 SHA-256). `ContactMatchService.match` yanıtı `hash, userId, displayName, avatarUrl, faculty, department` döner; kullanıcı için "rehberden bulunmayı kapat" ayarı yok (`ProfilePrivacy` alanları yalnız avatar/bio/bölüm kitlesi).
- Senaryo: `a16_c` `sha256("qa-user1@bingol.edu.tr")` ve `sha256("a16_b@bingol.edu.tr")` gönderdi; iki kullanıcı ad ve `userId` ile döndü (200); 7. istek 429 (sınır doğrulandı). Okul numaraları e-posta kullanıcı adıdır (`226051015@bingol.edu.tr`, `LoginIdentifier`), dolayısıyla aday uzayı küçük ve tahmin edilebilir.
- Etki: yeni bir hesapla saatte 3000 aday, birkaç IP'yle saatte on binlerce aday: öğrenci listesi (ad, bölüm, id) toplanır; çıkan `userId`'ler A16-02'deki rızasız DM için hazır hedeftir. Her hesap başka bir `@bingol.edu.tr` posta kutusu ister, bu da hızı sınırlar ama engellemez.
- Öneri: "Rehberden bulunabilirim" gizlilik anahtarı (varsayılan kapalı ya da yalnızca karşılıklı rehber), yanıtta `userId`'yi yalnız karşılıklı eşleşmede ver, hesap başına günlük toplam aday tavanı (örn. 2000/gün), `numara@` biçimini rehber eşleşmesinden çıkar.

### A16-08 - ORTA - Kolektif şikâyetle otomatik gizleme (STATİK; 24 sa yaş koşulu nedeniyle dinamik denenemedi)
- Uç/dosya: `moderation/ReportService.applyPolicy` (73-95), `ModerationProperties` varsayılanları: `autoHideThreshold=3`, `newAccountMinAgeHours=24`, `rejectRestrictThreshold=5`.
- Senaryo: aynı kişinin kontrolündeki 3 hesap (24 saatten eski), rakibin etkinliğine/kulübüne/Keşfet gönderisine 3 şikâyet yollar -> hedef (geri alınabilir tür: EVENT, POST, FEED_POST, MESSAGE_IMAGE) otomatik gizlenir ve sahibine bildirim gider, admin inceleyene kadar kapalı kalır. 3 hesabın ilişkisi (aynı cihaz/IP/aynı kulüp) kontrol edilmiyor; rapor nedeni tipi ne olursa olsun sayılıyor. Sınırlar: kişi başına 20 şikâyet/gün, 5/dk, 5 reddedilen şikâyetten sonra 7 gün şikâyet yasağı, itiraz var, kendi içeriğini şikâyet 400 ve tekrar 409 (bunlar KANITLANDI: `CANNOT_REPORT_SELF`, `ALREADY_REPORTED`).
- "Şikâyet edilen gönderi otomatik silinir mi?" Hayır: otomatik işlem silme değil, geçici GİZLEME (`HiddenBy.AUTO`); silme/askıya alma yalnız yönetici kararıyla. CLAUDE.md'deki "açık şikâyetler silmeyle sonuçlanır" ifadesi, gönderi silindiğinde açık şikâyetlerin kapanması anlamında okunmalı; dokümantasyonu netleştirin.
- Etki: kulüp/etkinlik rekabetinde itibar saldırısı; seçim döneminde kulüp gizleme. `USER` türü geri alınamaz olduğundan kullanıcıya karşı otomatik askı yok (iyi).
- Öneri: eşiğe sayılan raporlayıcıları cihaz/IP kümesine göre tekilleştirin (aynı `device_hash`/IP /24 tek sayılsın); gizleme eşiğini hedef türüne göre ayarlayın (kulüp: 5 ve ayrıca admin onayı); otomatik gizleme sonrası 24 saat içinde admin kuyruğu önceliği; tekrar eden "çete" raporlayıcılar için uyarı.

### A16-09 - ORTA - Hesabı silip aynı e-postayla yeniden kayıt: ihlal geçmişi sıfırlanıyor (STATİK)
- Uç/dosya: `ProfileService.anonymize` (247-278): `email = "deleted-<id>@deleted.invalid"`, hesap `DELETED`; `AuthService.register` yalnızca `users.findByEmail(email)` ile `isEmailVerified()` çakışmasına bakıyor.
- Senaryo: kullanıcının 2 ihlali (strike) ya da açık şikâyetleri var -> `DELETE /api/users/me` (şifre ile, 5/sa) -> aynı `@bingol.edu.tr` ile yeniden kayıt -> temiz hesap, strike/şikâyet sayacı/rapor yasağı sıfır, 24 saatlik "yeni hesap" kısıtı da dolaşılır. Askıya alınmış kullanıcı bu yolu kullanamaz (JWT anında reddedilir ve askıdaki satır e-postayı tutar), yani açık olan yalnız "askı eşiğine ulaşmamış" suistimalcidir.
- Etki: tek posta kutusu = ardışık sınırsız hesap; strike/şikâyet yaptırımı etkisiz.
- Öneri: silinen hesabın e-posta özetini (`email_sha256`) ve strike sayısını (anonim) bir "yasak/strike" tablosunda saklayın; yeniden kayıtta özet eşleşirse strike devralınsın ya da kayıt N gün beklesin; açık şikâyeti/strike'ı olan hesabın silinmesini kararlaştırılana dek askıya alın.

### A16-10 - ORTA - Erişim engeli kaçışı kolay (STATİK)
- Uç/dosya: `accessban/ClientContexts.java` (cihaz kimliği istemcinin gönderdiği `X-Device-Id` başlığının HMAC'i), `AccessBanFilter`.
- Senaryo: cihaz yasağı yiyen kullanıcı başlığı değiştirir/atlar (yeni değer yeni özet; başlıksız istek `deviceHash=null`, cihaz kuralı hiç eşleşmez); IP yasağı için VPN/mobil veri. Yeni hesap açma yalnız yeni bir `@bingol.edu.tr` kutusu gerektirir (A16-09).
- Etki: yasaklı kullanıcı geri döner; admin tarafında yeni hesap-cihaz bağlama sinyali yok.
- Öneri: cihaz kuralını yalnız ek sinyal olarak kullanın; ban hedefi e-posta alan/okul numarası + doğrulanmış e-posta özeti olsun (A16-09); cihaz özetine ek olarak Play Integrity/App Attest ile doğrulanmış kimlik (uzun vade).

### A16-11 - ORTA - Raporlanamayan içerik türleri (KANITLANDI + STATİK)
- `ReportTargetType`: `USER, MESSAGE, POST (kulüp gönderisi), COMMUNITY, EVENT, MESSAGE_IMAGE, USER_AVATAR, FEED_POST` kayıtlı; `COMMUNITY_COVER`/`EVENT_COVER` enum'da olduğu halde işleyici yok (`TARGET_TYPE_UNSUPPORTED`, KANITLANDI; `SmokeReportTargetHandler` yalnız `app.moderation.smoke-handler=true`).
- Raporlanamayanlar: grup sohbeti (başlık/avatar/grubun kendisi), kulüp ve etkinlik duyuruları, anketler (GLOBAL yalnız admin, kulüp anketi kulüp yöneticisi), öneri panosu gönderileri, etkinlik geri bildirimleri. Mobilde şikâyet girişleri: mesaj, kullanıcı, kulüp, kulüp gönderisi, etkinlik, Keşfet gönderisi (yeterli ama yukarıdaki boşluklar var).
- Etki: A16-02 ile birlikte: rızasız eklenen kullanıcı, kötü niyetli bir grubu (başlık/avatar) şikâyet edemez; yalnızca tek tek mesajı ya da kullanıcıyı.
- Öneri: `CONVERSATION` hedef türü (grup başlığı + avatar + toplu üye kaynaklı şikâyet), `ANNOUNCEMENT` (kulüp/etkinlik duyurusu), `POLL`; kapak türleri için ya ilgili handler ya da enum'dan kaldırma.

### A16-12 - ORTA - Genel destek formu: istemci kontrollü bot korumaları, ortak tavan (KANITLANDI + STATİK)
- Uç/dosya: `support/ticket/PublicSupportService.submit`. `elapsedMs` istemci tarafından gelir ve `website` honeypot'tur; bir bot `elapsedMs=30000, website=""` ile ikisini de geçer (denendi, 202). Hız sınırları: IP 5/sa, 15/gün, e-posta 5/gün, ortak `pubsup:global` 100/sa.
- Senaryo 1 (hedefli kod postası): herhangi bir (kampüs dışı dahil) adrese, kurumsal gönderenden sabit metinli "doğrulama kodu" postası: günde en çok 5/adres (sabit konu/gövde: kullanıcı adı/mesajı posta gövdesine GİRMEZ, yani oltalama metni taşıyamaz - iyi).
- Senaryo 2 (form kilitleme): 20 farklı IP (ya da IPv6 /64 çevirisi) saatte 100 isteği dolduran biri, sitedeki herkese 429 verir; kampüs NAT'ında tek öğrenci 15/gün IP tavanını tüketip aynı NAT'tan gelen herkesi engelleyebilir.
- Doğru olanlar: 6 haneli kod hash'li, 10 dk, 5 deneme (`MAX_ATTEMPTS`), izleme anahtarı 32 bayt rastgele, yalnız SHA-256 saklanıyor, geçersiz anahtar denemesi IP başına 20/sa, yönetici yanıtı HTML kaçışlı, ad yalnız harf/rakam. 3 kez geçersiz `track` anahtarı 404 (KANITLANDI).
- Küçük ek: her yanıtta yeni izleme anahtarı üretiliyor (`sendStaffReplyMail` -> `mintToken`), eski anahtarlar silinene dek geçerli kalıyor (bağlantı sızıntısında süre sınırı yok).
- Öneri: `elapsedMs` yerine sunucu tarafı zaman damgalı imzalı form jetonu (formu açınca verilen HMAC'li token, gönderimde en az N sn geçmiş olmalı); küresel tavan yerine kimliksiz kod bütçesini (`mail.requireCodeQuota(SUPPORT)`) kullanın; izleme anahtarına son kullanma/ticket kapanınca iptal.

### A16-13 - DÜŞÜK - Takip/engelleme/profil yazma uçlarında hız sınırı yok veya zayıf (KANITLANDI)
- `PATCH /api/users/me`: sınırsız. 40 ardışık görünen ad değişikliği 40/40 200 (`ProfileController.update`). Sonuç: raporlanan kişinin adı sürekli değişir (rapor iziyle eşleştirme zorlaşır), taklit adı deneme-yanılma, ad değişiminde cooldown/geçmiş yok.
- `POST/DELETE /api/users/{id}/block`: sınır yok; 30 ardışık `POST /users/{101..130}/block` 404 (var olmayan kimliğe 404, var olana 204: kullanıcı kimliği varlık oracle'ı, ama kimlikler zaten sıralı ve aranabilir).
- `POST /api/users/{id}/follow`: 60/dk, günlük tavan yok (A16-01 ile bileşik risk: günde on binlerce takip bildirimi).
- Öneri: `profile:update` 10/sa, görünen ad değişimi için 7 gün cooldown (+ `display_name_history`), `block` 60/sa, `follow` ek günlük 500 tavanı.

### A16-14 - DÜŞÜK - Kişisel veri (telefon/IBAN/TC kimlik) metin filtresi yok (KANITLANDI)
- `PATCH /api/users/me {"bio":"tel 05551234567 TR330006100519786457841326"}` -> 200. Herkese açık bio'da, gönderide, kulüp/etkinlik açıklamasında telefon/IBAN/TC kimlik no serbest. Sohbet muaf olduğundan orada sorun değil, ama herkese açık alanlarda KVKK riski.
- Öneri: `ContentGuard`'a ayrı "PII" kontrolü (TR telefon, IBAN, 11 haneli TC kimlik no checksum) - engelleme yerine uyarı ya da maskeleme.

### A16-15 - DÜŞÜK - Görsel moderasyonu yok; kötü içerik özet listesi yalnız tam eşleşme (STATİK; bilinen)
- Fotoğraf yüklemeleri (gönderi, avatar, kapak, sohbet görseli) otomatik taranmıyor (yetişkin/şiddet/CSAM). `ContentBlocklist` yalnız tam SHA-256: tek piksel değişimi veya yeniden kodlama (medya hattı zaten yeniden kodlar, özet yeniden kodlanmış bayt üzerinden) listeyi atlatır.
- Hafifletici: ilk gönderi onayı yok ama yönetici sonradan denetliyor, 3 bağımsız şikâyetle otomatik gizleme, Çocuk güvenliği sayfası (web) ve iletişim kanalı var.
- Öneri: perceptual hash (pHash/PDQ) ile kara liste; sağlayıcıdan NSFW/CSAM taraması (hash eşleştirme); kısa vadede ilk 3 gönderi/yeni hesap fotoğrafları için "inceleme bekliyor" bayrağı. Risk kabulü olarak `docs/MODERATION.md`'ye yazın.

### A16-16 - DÜŞÜK - Kendine zarar/kriz yönlendirmesi ve yaş doğrulaması yok (STATİK)
- Uygulamada intihar/kendine zarar ifadelerinde destek yönlendirmesi (112/ALO 182 vb.) yok; yalnız web Çocuk Güvenliği sayfasında 112 geçiyor. Kayıtta doğum tarihi/yaş beyanı yok; "18+" yalnızca Kullanım Koşulları 4. madde ve çocuk güvenliği sayfasında, `acceptTerms` kutusuna bağlı.
- Öneri: raporlama ekranında "Acil durumdaysanız 112" notu, destek ekranında psikolojik destek (üniversite PDR birimi) bağlantısı; kayıtta "18 yaşını doldurdum" açık beyanı.

### A16-17 - DÜŞÜK - "Resmî" ifadesi / resmî olmama beyanı tutarlılığı (STATİK + KANITLANDI)
- ARB anahtarları `eventListOfficial`, `homeOfficialEvent`, `akademik2OfficialTag` (tr/en/ar) tanımlı ama Dart kodunda HİÇ KULLANILMIYOR (grep: yalnız `.arb`); ekranda görünmüyor. Önerilen: ölü anahtarları silin.
- Ekranda görünen "Resmi" kullanımları yasal/akademik anlamda doğru: `RESMI_TATIL` ("Resmi tatil"), "Resmi program" (sınav), "Resmi dönem" (akademik takvim). Kullanıcı içeriğini "resmî" gibi gösteren bir rozet/etiket YOK; "doğrulanmış" rozeti de yok (`LucideIcons.badgeCheck` yalnız rıza satırı ve "kulüp adına anında yayın" simgesi olarak kullanılıyor).
- Tutarsızlık: `docs/store/data_safety.md` satır 59 "açıklamada ve ekranda 'resmî değildir' ifadesi var" diyor; mobil ARB'de (tr/en) böyle bir metin YOK (`grep resmî değil|bağımsız` boş). İfade yalnızca Kullanım Koşulları madde 15.1 (`legal.controller.relation`, sözleşme ekranından okunuyor) ve web `child-safety` sayfasında. Web ana sayfada "Resmî kaynaklardan derleme" ifadesi doğru ama sayfada kısa bir "resmî uygulama değildir" şeridi yok (`site.ts`).
- Öneri: mobil Ayarlar > Hakkında ve web alt bilgisine tek satır "Bağımsız bir uygulamadır; Bingöl Üniversitesi'nin resmî uygulaması değildir." ekleyin ya da `data_safety.md` ifadesini düzeltin (mağaza beyanı ile ekran tutarlı olmalı).

### A16-18 - DÜŞÜK - Yanlış pozitifler (ÇEVRİMDIŞI KOŞUM)
Engellenenler: `Pornografi Semineri` (akademik), `Gerzek Dağı`, `Ibne Haldun`, `Boktan Film Kulübü` (kasıtlı), `Sikkim`, `taşaklı`, `Bastard`. Doğru geçenler: Sosyoloji, Mühendislik, Bingöl, Amasya, Malatya, Kasım, Sikke, Sinop, Scunthorpe, Cumartesi, Titanic, Bitcoin, Basement, Penistone, Dickens, Aşkale, Meme Kanseri Farkındalık, Cinsel Eğitim Semineri. Yanlış pozitif oranı düşük; kulüp adı "pornografi" içeren bir sağlık semineri engellenir ve kullanıcının itiraz yolu yok (422 yalnız alan adını bildirir).
- Öneri: admin paneli "metni dene" kutusuyla izin listesi güncellemesi; kullanıcıya "Destek'e yazın" bağlantısı.

### A16-19 - DÜŞÜK - Kayıt/kod posta bütçesinin tek IP ile tüketilmesi (STATİK; ortak yığını zorlamamak için denenmedi)
- `MailService.requireCodeQuota`: kimliksiz kod bütçesi günlük kotanın %60'ı (kayıt/destek) ve %85'i (şifre sıfırlama), IP başına günde 3000 kod isteği. Tek IP, geçerli `@bingol.edu.tr` adresleri (her adrese günde en çok 20 posta; 60 sn bekleme, 5/sa doğrulandı: 7 denemede 1x202 ardından 6x429) üzerinden bütçeyi harcayıp yeni kayıtları `MAIL_QUOTA_EXHAUSTED` (503) ile durdurabilir. Hedef adres başına posta yağmuru iyi sınırlanmış (KANITLANDI).
- Öneri: IP başına günlük kod isteğini 3000'den düşürün (örn. 300) ya da kampüs NAT'ı için ayrı yapılandırın; bütçe doluluk uyarısı (`SystemAlertService`) tanımlıysa kontrol edin.

### A16-20 - DÜŞÜK - Yönetici işlemleri denetimi: bu denetimde derinlemesine incelenmedi
- `AuditInterceptor`/`AuditAccessDeniedHandler` ve içerik/kullanıcı karar günlükleri kapsam dışı kaldı (A1/A8 kapsamında). Moderasyon karar zinciri (`ReportService.resolve`, `strikes.record`, `HiddenContentAdminService`) kod olarak okundu: karar nedeni, bildirim ve itiraz akışı tutarlı.

---

## İyi çalışanlar (KANITLANDI veya STATİK)

- Gönderi kuralları sunucuda zorlanıyor: 8 kelime 422, 66 karakterlik tek kelime 422, satır sonu 422, fotoğrafsız 400 `POST_PHOTO_REQUIRED`, aynı medya iki kez 400 `POST_SINGLE_PHOTO_ONLY`; `/api/posts/media` video reddeder; yorum/hikâye/#etiket/kaydet uçları 404.
- Kayıt posta yağmuru: hedef adres başına 60 sn bekleme + 5/sa + 20/gün (register+resend+forgot ortak) ve `+etiket` yasağı (`EMAIL_ALIAS_NOT_ALLOWED`); kayıt "son yazan kazanır" + parola kanıtı doğrulaması.
- Herkese açık destek: kod postası sabit metin (kullanıcı adı girmez), HTML kaçışı, token yalnız hash.
- Rapor mekaniği: kendi içeriği 400, tekrar 409, günlük 20 / dakikada 5, mesaj raporu yalnız o sohbetin üyesi ve yalnız ulaşan mesaj, yaş koşulu (24 sa), reddedilen raporlara 7 günlük şikâyet yasağı, itiraz.
- Engelleme: engellenen kişi takip edemez (404), gruba ekleyemez (403 `BLOCKED`), kişi/rehber aramasında engel ilişkisi hariç tutulur, bildirim tetikleyemez (`PostNotifier.shouldNotify`), profil boş döner, grup mesajları ve WS teslimi `hiddenFrom` ile süzülür. DM'de "gölge engel" bilinçli tasarım.
- Takip bildirimi tekrar takip-bırak-al ile spam edilemez (`follow:<id>` toplama anahtarı); beğeni bildirimleri 10 dk'lık pencerede birleştirilir.

---

## Hız sınırı kapsamı tablosu (kullanıcı yüzlü yazma uçları, statik tarama + ek doğrulama)

Yöntem: tüm `@RestController`'larda `Post/Put/Patch/DeleteMapping` yöntemleri tarandı; yönetim uçları (`/api/admin/**`) hariç. 138 yazma yöntemi gövdesinde `RateLimiter` var (denetleyici içinde ya da yardımcı metotla); kalanlar servis katmanında limitli olabilir (tek tek doğrulandı).

| Modül | Durum |
|---|---|
| auth (register/resend/forgot/verify/login/refresh/change-password/logout-all) | Tam (IP + e-posta + cihaz + günlük posta tavanı). `POST /auth/logout` limitsiz (jeton gerektirir; risk düşük) |
| messaging (sohbet açma 30/gün, mesaj 30/dk + 120/dk kaba, düzenle/sil/tepki, grup yönetimi 30/dk, avatar) | Tam |
| post (oluştur 20/sa, yaz 30/dk, beğeni 120/dk, takip 60/dk, medya yükleme saatlik) | Tam; takip günlük tavan yok (A16-13) |
| community/club (oluştur 5/sa, katıl 20/sa, gönderi 10/dk, duyuru 10/sa, yazma 60/sa) | Tam |
| event (oluştur 10/sa, RSVP 30/dk, check-in 20/dk, duyuru 10/sa, başvuru 20/dk + 60/sa) | Tam; `applications/{id}/accept|reject|waitlist` (EventAdmissionController 110-125) yöntem gövdesinde limit yok, `decisions` toplu ucu limitli (60/dk): doğrulanmalı |
| poll (oluştur 10/sa, oy 60/dk, yaz 60/dk) | Tam |
| moderation (rapor 20/gün + 5/dk) | Tam; engelleme `POST/DELETE /users/{id}/block` YOK (A16-13) |
| profile | `PATCH /users/me` YOK (A16-13); avatar 10/sa, hesap silme 5/sa, arama 60/dk + 500/gün, rehber eşleşme 6/sa + 30/IP |
| support (ticket 5/gün, yanıt 30/sa, geri bildirim 10/gün, oy 60/sa) | `DELETE /suggestions/{id}/vote` ve `POST /support/tickets/{id}/close` limitsiz (düşük etki) |
| public support | Servis katmanında (IP 5/sa+15/gün, e-posta 5/gün, global 100/sa, izleme 60/sa, yanıt 20/sa) |
| academic/timetable | Tam (`acd:write` 60/sa, içe aktarma 5/sa) + üst sınırlar (40 ders, 8 dönem); `POST /announcements/{id}/read`, `read-all` limitsiz |
| legal | `POST /legal/consents|accept` limitsiz (kimlik doğrulamalı, kendi kaydı) |
| analytics olay alımı, crash raporu | Kendi limitleri var (kapsam dışı) |

---

## Bakılamayanlar / sınırlar

- Otomatik gizleme eşiği (3 bağımsız rapor) dinamik olarak denenemedi: raporlayıcı hesapların 24 saat yaşı gerekir (A16-08 statik).
- Etkinlik QR/kod paylaşımıyla yoklama sahteciliği, anket çoklu hesap oyu, push kampanya yetkileri ve yönetici işlem denetim zinciri bu turda kapsam dışı/yüzeysel.
- Gerçek SMTP/FCM yok (QA: `MAIL_ENABLED=false`); bildirim gövdesi API'den doğrulandı, push metni kod okumasıyla (`PostNotifier`) eşlendi.
- Mobil/web ekran görüntüsü ya da erişilebilirlik testi yapılmadı; yalnız ARB/i18n ve kod taraması.
- Admin panelinden ban/askı akışı (A16-10) yalnız kod okuması.
- Test verisi QA yığınında kaldı (hesaplar `a16_*`, kulüp 1-2, gönderi 1, sohbet 16-17); yığın koordinatör tarafından kapatılacak.
