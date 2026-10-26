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

Gonderen gorunen adi `BÜ Kampüs` (`app.mail.from-name`). Istege bagli ayarlar (application.properties, varsayilanlar kodda): `app.mail.queue-poll-ms=5000`, `app.mail.max-attempts=5`, `app.mail.batch-size=20`, `app.mail.from-name`.

Dogrulama: `MAIL_ENABLED=true` ile bir kayit yapin; `select status, attempts, last_error from mail_outbox order by id desc;` ile durumu izleyin. Takilan kayit (DEAD) icin `update mail_outbox set status='PENDING', attempts=0, next_attempt_at=now() where id=..` ile yeniden kuyruga alinabilir (degiskenler silindigi icin kod/baglanti yeniden uretilmelidir; pratikte kullanici yeni kod ister).

## Sablon ekleme rehberi

1. `MailTemplate` enum'una yeni deger ekleyin (`NEW_TEMPLATE("anahtar")`).
2. `i18n/mail.properties`, `mail_en.properties`, `mail_ar.properties` dosyalarina `mail.tpl.<anahtar>.subject`, `.title`, `.body` ekleyin. `.body` icinde paragraflar `\n` ile ayrilir. Kod gosterilecekse `.code.label` de ekleyin ve degiskenlerde `code` gecin.
3. Metinlerde `{{degisken}}` kullanin (HTML kacisli; duz metinde oldugu gibi). Kesme isareti kisiti yoktur (MessageFormat kullanilmaz).
4. Cagiran tarafta `mailService.enqueue(to, MailTemplate.NEW_TEMPLATE, lang, Map.of("degisken", "deger"))`. Degiskenler toplam 4000 karakteri gecmemelidir.
5. Gorsel duzen `src/main/resources/mail-templates/layout.html` icindedir (600px, `#C62A20` baslik bandi, `#171E33` metin, `#FAF6F3` zemin, koyu mod meta + medya sorgusu, Arapcada `dir="rtl"`).

Sablonlarin cagrildigi yerler (kayit disindakiler sonraki modullerce baglanmalidir): dogrulama kodu `VerificationService` (bagli). Sifre sifirlama, hesap silindi, yeni cihaz girisi ve sifre degisti bildirimleri icin servis metotlari hazirdir; sifre sifirlama ozelligi eklendiginde cagrilmalidir.
