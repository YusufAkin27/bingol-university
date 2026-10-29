# Mail modulu: e-posta kuyrugu ve sablonlar

API sozlesmesinde degisiklik yoktur (yeni uc eklenmedi). Dogrulama kodu gonderimi artik senkron degil: `register` / `resend-code` e-postayi kuyruga yazar ve hemen doner; gonderim arka planda yapilir. Kuyruga yazma basarisiz olursa eskisi gibi `503 MAIL_UNAVAILABLE` doner. Kod yanlis adrese gitmis olsa bile yanit enumerasyona karsi genel kalir.

## Mimari

- Tablo `mail_outbox` (Flyway V110): `status` PENDING / SENT / FAILED / DEAD, `attempts`, `next_attempt_at`, `last_error`, `vars_json`.
- `MailService.enqueue(to, template, lang, vars)` genel giris. Kisayollar: `sendVerificationCode`, `sendPasswordResetCode`, `sendAccountDeleted`, `sendNewLoginAlert`, `sendPasswordChanged`, `sendAnnouncement`. `sendRich` (destek talepleri) kuyruk disi, aninda gonderimdir.
- `MailQueueWorker`: `app.mail.queue-poll-ms` araliginda ve yeni kayit yazilinca calisir. `FOR UPDATE SKIP LOCKED` + 5 dk kira ile cok sunucu guvenlidir.
- Geri cekilme: 1 dk, 5 dk, 30 dk, 2 sa, 12 sa. `app.mail.max-attempts` (varsayilan 5) basarisiz denemeden sonra kayit DEAD olur.
- Gonderilen/olu kayitlarin `vars_json` alani (kod vb.) temizlenir; 30 gunden eski SENT/DEAD kayitlar her gece silinir.
- Loglarda alici adresi maskelenir (`a***@bingol.edu.tr`), kod asla loglanmaz. Tek istisna: `app.mail.enabled=false` iken (yalnizca gelistirme) dogrulama kodu `<adres> icin dogrulama kodu: <kod>` bicimiyle log'a yazilir (duman betikleri bunu okur).
- Metrikler: `mail.queue.sent`, `mail.queue.failed`, `mail.queue.dead`.
- Saglik: actuator `mailQueue` gostergesi; DEAD > 0 veya bekleyen+yeniden denenecek > 100 ise ayrintida `WARN` (genel durum DOWN olmaz).
- Dahili durum sayilari: `MailService.queueStats()`.

## SMTP kurulumu

Ortam degiskenleri (`.env`):

| Degisken | Anlam | Ornek |
|---|---|---|
| `MAIL_ENABLED` | `true` = gercek gonderim | `true` |
| `MAIL_HOST` | SMTP sunucusu | `smtp.example.com` |
| `MAIL_PORT` | Port (STARTTLS) | `587` |
| `MAIL_USERNAME` / `MAIL_PASSWORD` | SMTP kimligi | |
| `MAIL_FROM` | Gonderen adresi | `no-reply@bingol.edu.tr` |

Gonderen gorunen adi `BÜ Kampüs` (`app.mail.from-name`, ortam: `MAIL_FROM_NAME`). `MAIL_FROM` yalniz adrestir (`noreply@bukampus.online`); `"Ad <adres>"` bicimi verilirse adres ayrilir ve ad CIFT uretilmez. Oncelik: acik `MAIL_FROM_NAME` > `MAIL_FROM` icindeki ad > varsayilan `BÜ Kampüs` (bos `MAIL_FROM_NAME` = varsayilan/gomulu ad). Ad RFC 2047 (`=?UTF-8?...?=`) ile kodlanir (`MimeMessageHelper` UTF-8), satir sonlari temizlenir. `docker-compose*.yml` `MAIL_FROM_NAME`'i konteynere gecirir; `deploy.sh` `.env.prod`'a yazar. UYARI: Gmail'deki yuvarlak profil resmi (avatar) BIMI + dogrulanmis marka sertifikasi (VMC/CMC) olmadan DEGISMEZ; kodla cozulemez (bkz. MAIL_DELIVERABILITY.md). Istege bagli ayarlar (application.properties, varsayilanlar kodda): `app.mail.queue-poll-ms=5000`, `app.mail.max-attempts=5`, `app.mail.batch-size=20`, `app.mail.from-name`.

Dogrulama: `MAIL_ENABLED=true` ile bir kayit yapin; `select status, attempts, last_error from mail_outbox order by id desc;` ile durumu izleyin. Takilan kayit (DEAD) icin `update mail_outbox set status='PENDING', attempts=0, next_attempt_at=now() where id=..` ile yeniden kuyruga alinabilir (degiskenler silindigi icin kod/baglanti yeniden uretilmelidir; pratikte kullanici yeni kod ister).

## Sablon ekleme rehberi

1. `MailTemplate` enum'una yeni deger ekleyin (`NEW_TEMPLATE("anahtar")`).
2. `i18n/mail.properties`, `mail_en.properties`, `mail_ar.properties` dosyalarina `mail.tpl.<anahtar>.subject`, `.title`, `.body` ekleyin. `.body` icinde paragraflar `\n` ile ayrilir. Kod gosterilecekse `.code.label` de ekleyin ve degiskenlerde `code` gecin.
3. Metinlerde `{{degisken}}` kullanin (HTML kacisli; duz metinde oldugu gibi). Kesme isareti kisiti yoktur (MessageFormat kullanilmaz).
4. Cagiran tarafta `mailService.enqueue(to, MailTemplate.NEW_TEMPLATE, lang, Map.of("degisken", "deger"))`. Degiskenler toplam 4000 karakteri gecmemelidir.
5. Gorsel duzen `src/main/resources/mail-templates/layout.html` icindedir (600px, `#C62A20` baslik bandi, `#171E33` metin, `#FAF6F3` zemin, koyu mod meta + medya sorgusu, Arapcada `dir="rtl"`).

Sablonlarin cagrildigi yerler (kayit disindakiler sonraki modullerce baglanmalidir): dogrulama kodu `VerificationService` (bagli). Sifre sifirlama, hesap silindi, yeni cihaz girisi ve sifre degisti bildirimleri icin servis metotlari hazirdir; sifre sifirlama ozelligi eklendiginde cagrilmalidir.

## Marka logosu (DEP2)

- `layout.html` ust bandi (kirmizi `#C62A20`, tum temalarda ayni) beyaz yatay logo gosterir: `mail-templates/logo.png` (`brand/dist/horizontal-white.png`'den 276x72 px = 138x36 CSS px, 2x yogunluk, ~8 KB; kaynak `brand/` PNG'si degistirildiginde yeniden uretin). `MailBrand.headerHtml(brand)` hem `MailRenderer` hem `CustomMailRenderer` (yonetici sablonlari) icin ust bant HTML'ini uretir; `{{{brandHtml}}}` yer tutucusu.
- **Neden CID (gomulu ek), neden harici URL degil:** Gmail `data:` URI'yi engeller; harici URL (`PUBLIC_WEB_URL/brand/...`) web dagitimina/CDN'e, DNS'e ve alicinin "gorselleri goster" ayarina baglidir, yerel/staging'de kirilir ve her acista bir istek (izleme sinyali) uretir. `MailTransport` zaten `multipart` + `MimeMessageHelper` kullandigindan `helper.addInline("bu-logo", ...)` ile `multipart/related` icinde tek bir gomulu parca eklemek en saglam yoldur (web/sunucu bagimsiz). Maliyet: her postaya ~8 KB; Gmail inline CID'yi ek olarak gostermez. HTML'de `cid:bu-logo` YOKSA (destek yanitlari gibi `sendRich` HTML'i) ek eklenmez.
- Gorsel yuklenmezse `alt="BÜ Kampüs"` beyaz+kalin 20 px olarak kirmizi bant uzerinde okunur (acik ve koyu kipte ayni; koyu kipte `.brandbar` rengi `!important` ile sabit). Duz metin parcasinda logo/gorsel yoktur. Arapcada bant `dir="rtl"` ve `text-align:start` ile saga yaslanir; kod kutusu LTR kalir.
- Yonetim panelindeki sablon onizlemesinde (`MailTemplateAdminService`) `cid:` kaynagi `MailBrand.forPreview` ile `data:` URI'ye cevrilir (yalniz onizleme; gonderimde kullanilmaz).
- Testler: `MailBrandTest` (From RFC 2047, cift ad yok, MIME yapisi: related/alternative, `Content-ID <bu-logo>`, duz metinde logo yok, tr/en/ar, onizleme); `target/mail-preview/*.html|*.eml` elle inceleme dosyalari uretir.

## Teslim edilebilirlik (spam'e dusmeme) - V420/V421

- `MailCategory` (TRANSACTIONAL/ANNOUNCEMENT; `MailCategory.of(template)`): duyuru turu `List-Unsubscribe` + `List-Unsubscribe-Post` (RFC 8058) + `Precedence: bulk`, govdede abonelikten cik baglantisi; islemsel `Auto-Submitted: auto-generated`. `Message-ID` gonderen alan adiyla, `Date`, `Reply-To` (`MAIL_REPLY_TO`).
- Bastirma listesi `mail_suppression` (V420, yalniz SHA-256 ozeti; UNSUBSCRIBED/BOUNCED/COMPLAINT): duyuru gitmez, islemsel gider. Uc: `GET/POST /api/public/mail/unsubscribe?token=` (herkese acik, IP basina saatte 60; GET durum degistirmez; 3 dilli sayfa; HMAC jeton, 180 gun).
- Kuyruk (V421 `mail_outbox.priority`): islemsel once ve sinirsiz; duyuru `app.mail.max-per-minute` (30) ve ayni aliciya `app.mail.recipient-gap-seconds` (300) ile sinirli. Yeni durum `SKIPPED` (bastirilmis/bounce/abonelik adresi yok; saglik alarmi uretmez).
- SMTP anindaki kalici alici hatasi (550/551/553 + kullanici yok) yeniden denenmez, adres BOUNCED bastirilir; gecici/politika hatalari yeniden denenir.
- `MailTransport.send(...)` eski 5 parametreli imza korunur (islemsel); yeni imza `(…, MailCategory, unsubscribeUrl)`. `MailProperties` eski 7 alanli kurucuyu korur. `MailQueueWorker.purgeOld` `SchedulerLock("mail-purge")` ile sarili.
- Yeni toplu sablon (kendi enum degeri) eklenirse `MailCategory.ANNOUNCEMENT_TEMPLATES`'e adi eklenmelidir (aksi halde islemsel sayilir).
- `ProdSettingsValidator`: `MAIL_FROM` bos/yerel ise hata; TLS zorunlu degil, `PUBLIC_WEB_URL` https degil, From/SMTP alan adi farki, sinirsiz hiz icin uyari. Ayrinti ve DNS listesi: [../MAIL_DELIVERABILITY.md](../MAIL_DELIVERABILITY.md).


## Yonetici sablonlari ve toplu/secili e-posta kampanyalari (V430, `mail/campaign`)

Yeni uclar: `/api/admin/mail/templates|campaigns|variables` (ayrinti ve ornekler: docs/ADMIN_API.md "Mail sablonlari ve kampanyalari").

- `MailTemplate.CUSTOM`: kuyruk satiri yalniz `tplId`, `tplVer` ve alici degiskenlerini (`ad`, `eposta`, `bolum`, `fakulte`, `sinif`, `uygulamaUrl`, `abonelikCikUrl`) tasir; icerik gonderim aninda `CustomMailRenderer` ile veritabanindaki **sabit surumden** cozulur (`MailRenderer` bu sablonda `CustomMailContent`'e devreder, ayni `layout.html`). Kategori ANNOUNCEMENT (`MailCategory`): abonelikten cik alt bilgisi, bastirma listesi ve hiz siniri kuyruk iscisindedir; sablon govdesinde ikinci bir alt bilgi eklenmez.
- HTML kaydedilirken jsoup Safelist ile temizlenir; degerler HTML icin kacislanir. Konu tek satira indirilir (baslik enjeksiyonu).
- `MailCampaignDispatcher` (`app.mail.campaign-poll-ms`=10000, `app.mail.campaign-batch`=200, `SchedulerLock` + `FOR UPDATE SKIP LOCKED`): zamani gelen kampanyayi cozer (`MailAudienceResolver`: tum/filtre/secili kullanicilar/e-posta listesi -> yalniz kayitli kullanicilar), bastirilmis (`MailSuppressionGateImpl` -> `MailSuppressionService`), askidaki/silinmis/dogrulanmamis ve tekrar eden adresleri atlar, kalanlari `MailService.enqueue` ile yazar. Her alici `mail_campaign_recipient (campaign_id,user_id)` UNIQUE; "QUEUED" isareti ile kuyruk satiri ayni transaction'dadir (tekrar gonderim olmaz).
- KVKK: kampanyada yalniz kullanici kimligi; `app.mail.campaign-retention-days` (180) sonra gece silinir; hesap silmede `AccountDataPurger` alici satirlarini siler.
- Hata kodlari `i18n/mailadmin*.properties` (basename'e eklendi).


## Yonetici mail altyapisi: bastirma listesi, kuyruk, gunluk kota (P13, V750, `mail/admin`)

Yeni uclar (`/api/admin/mail/**`, yalniz ADMIN; yazmalar sebep ister ve `AuditContext` ile `MAIL_SUPPRESSION`/`MAIL_OUTBOX` hedefiyle denetlenir):

- Bastirma: `GET /suppressions` (sebep, kategori, `q`, tarih, sayfali; liste MASKELI), `GET /suppressions/{id}` (`@AuditRead`; tam adres yalniz bir kullanici hesabi `email_sha256` ile eslesiyorsa), `POST /suppressions` ({email, reason?:MANUAL, note>=5}), `DELETE /suppressions/{id}`, `GET /suppressions/export.csv` (maskeli, formul kacisli, <=50 bin).
- Kaldirma kurali: UNSUBSCRIBED/COMPLAINT (kullanicinin kendi iradesi) icin `X-Admin-Confirm: <kayit id>` basligi (yoksa 409 `MAILOPS_USER_OPTED_OUT`) + sebep >= 20; BOUNCED/MANUAL icin sebep >= 5.
- Kuyruk: `GET /outbox` (durum, sablon, kategori, tarih, `q` = tam e-posta | `@alan` eki | kayit no; alici maskeli), `GET /outbox/{id}` (`@AuditRead`; durum gecmisi, deneme, hata [e-posta/sir maskeli], sonraki deneme; **icerik ve degiskenler hicbir yanitta yoktur**), `POST /outbox/{id}/retry`, `POST /outbox/{id}/cancel`, `POST /outbox/bulk` ({action RETRY|CANCEL, ids<=200, reason}; kismi basari `failed[]`).
- Durum gecisleri tek atomik UPDATE (kosul: beklenen durum). Yeniden deneme yalniz DEAD/SKIPPED -> PENDING ve **guvenli olmayan denemeyi reddeder**: kod postasi 10 dk sonra (`MAILOPS_RETRY_STALE_CODE`), degiskenleri silinmis kayit (`MAILOPS_RETRY_NO_CONTENT`; DEAD/SKIPPED/iptal olurken `varsJson` KVKK geregi `{}` yapildigindan fiilen yalniz degisken gerektirmeyen `ACCOUNT_DELETED` ya da degiskeni duran kayit), bastirilmis adrese duyuru (`MAILOPS_RETRY_SUPPRESSED`). Iptal: PENDING/FAILED -> SKIPPED (+ degiskenler temizlenir). Isleyici ayni kaydi tam o anda gonderiyorsa iptal gecersiz kalabilir (mail gitmis olur); dar yaris penceresi.
- Kota: `GET /quota` (salt okunur): limit, rezerv, duyuru ust siniri, kullanilan/kalan, yuzde ve duzey (OK / WARN >= 80 / CRITICAL >= 95 / OFF), sifirlama saati ve sonraki sifirlama, kimliksiz kod butcesi, dun/bugun sayaci (Redis anahtari 2 gun yasar; 7 gunluk gecmis tutulmaz), kuyruk ozeti.
- `V750`: `mail_suppression` + `category`, `note`, `email_masked`, `created_by`; kuyruk arama indeksleri (`p13_*`). `SuppressionReason.MANUAL` eklendi. Adres hala DUZ saklanmaz (yalniz ozet + maskeli gosterim).
- `AdminGuardPolicy`: elle bastirma, bastirma kaldirma, tek/toplu retry-cancel sebep ister ve "yikici" (saatlik sinir) sayilir. Hata kodlari `i18n/mailops*.properties` (`MAILOPS_*`).
- Web: `/admin/mail/queue` (kuyruk + kota karti), `/admin/mail/suppressions`; yalniz Turkce (`i18n/tr/admin-p13.ts`).
- Duman: `scripts/smoke-admin-mailops.sh`.
