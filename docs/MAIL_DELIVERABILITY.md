# E-posta teslim edilebilirliği (spam'e düşmemek)

Bu belge, BÜ Kampüs e-postalarının (doğrulama kodu, şifre sıfırlama, güvenlik uyarıları, destek yanıtı, duyurular) gelen kutusuna düşmesi için **koddaki önlemleri** ve **DNS/SMTP tarafında yapılması gerekenleri** anlatır. Örneklerde `kampus.example.edu.tr` gibi örnek alan adları kullanılır; kendi alan adınızla değiştirin. Gerçek anahtar/parola bu belgeye yazılmaz.

İlgili: [DEPLOY.md](DEPLOY.md) (ortam değişkenleri), [changes/mail.md](changes/mail.md) (modül notları).

## 1. Kodda yapılanlar

| Konu | Uygulama |
|---|---|
| Tür ayrımı | `MailCategory`: `TRANSACTIONAL` (kod, şifre, güvenlik, hesap, destek) ve `ANNOUNCEMENT` (duyuru/toplu: `MailTemplate.ANNOUNCEMENT`, yönetici şablonu `CUSTOM`). Yeni toplu şablon `MailCategory.ANNOUNCEMENT_TEMPLATES` listesine eklenmelidir |
| Çok parçalı gövde | Her e-posta `multipart/alternative` (düz metin + HTML); HTML tek sütun, satır içi stil, görsel yok (metin/görsel oranı sorunu yok) |
| Başlıklar | `From` = `app.mail.from` + görünen ad `BÜ Kampüs`; `Date`; `Message-ID` = `<uuid@gönderen-alan-adı>` (varsayılan ana makine adı sızmaz, DMARC hizalamasına yardım eder); `Reply-To` = `MAIL_REPLY_TO` (boşsa eklenmez; destek yanıtlarında admin ayarı `support_email`); `X-Mailer` eklenmez |
| İşlemsel | `Auto-Submitted: auto-generated`, `X-Auto-Response-Suppress: All`. **`List-Unsubscribe` yok** (kod/şifre/güvenlik postasında abonelik anlamsızdır) |
| Duyuru | `Precedence: bulk`, `List-Unsubscribe: <https://…/api/public/mail/unsubscribe?token=…>`, `List-Unsubscribe-Post: List-Unsubscribe=One-Click` (RFC 8058); gövdeye "abonelikten çık" bağlantısı (görünen metin = hedef alan adı). Abonelik adresi yapılandırılmamışsa duyuru **gönderilmez** (SKIPPED) |
| Bastırma listesi | `mail_suppression` (V420): yalnız e-posta SHA-256 özeti + neden (`UNSUBSCRIBED`/`BOUNCED`/`COMPLAINT`). Bastırılmış adrese duyuru gitmez; **işlemsel mail her zaman gider** |
| Abonelikten çıkma ucu | `GET/POST /api/public/mail/unsubscribe?token=` (herkese açık, IP başına saatte 60). GET yalnız onay sayfası gösterir (posta tarayıcıları bağlantıyı önceden açabilir); POST aboneliği bitirir (RFC 8058 tek tık da POST). 3 dilli (`lang` parametresi / `Accept-Language`) basit sayfa; geçersiz/süresi dolmuş jeton hep aynı genel 400 sayfası. Jeton: HMAC-SHA256, tek amaçlı (`mail-unsub|`), `app.mail.unsubscribe-ttl-days` (180 gün), adres değil özet taşır; kullanıcı numaralandırması yok |
| Hız | Duyuru: dakikada en fazla `MAIL_MAX_PER_MINUTE` (varsayılan **30**, ısınma dostu; 0 = sınırsız). Ayrıca aynı adrese iki duyuru arası en az `MAIL_RECIPIENT_GAP_SECONDS` (300 sn; erken kalan ertelenir). İşlemsel mailler önce ve sınırsız alınır (kuyruk `claimDue` yalnız `priority=0`; duyurular ayrı `claimDueAnnouncements`) |
| Bounce | SMTP anında **kalıcı alıcı hatası** (550/551/553 + "kullanıcı bilinmiyor / 5.1.x") → yeniden denenmez, adres `BOUNCED` olarak bastırılır, kayıt `SKIPPED`. Politika/itibar reddi (5.7.x, spam, blocked), 552 (kota), 554 ve tüm 4xx **yeniden denenir** |
| SMTP | Bağlantı 10 sn, okuma/yazma 20 sn zaman aşımı; `MAIL_REQUIRE_TLS=true` (STARTTLS zorunlu) veya `MAIL_SSL=true` (465); sunucu kimliği doğrulanır. `ProdSettingsValidator` prod'da: `MAIL_FROM` boş/yerel ise **başlamaz**; TLS zorunlu değil, `PUBLIC_WEB_URL` https değil/yerel, From alanı SMTP kullanıcı alanından farklı, hız sınırsız ise **uyarır** |
| Çoklu örnek | `MailQueueWorker.poll` zaten atomik (`FOR UPDATE SKIP LOCKED` + kira), kilit gerekmez ve kilitlemek verimi düşürür. Gecelik temizlik `SchedulerLock("mail-purge")` ile tek örnekte çalışır |

Geri bildirim döngüsü (FBL) / şikâyet: SMTP sağlayıcıların çoğu şikâyeti webhook veya e-posta ile bildirir. **Bu sürümde FBL için uç yazılmadı.** Sağlayıcı şikâyet bildirirse adres elle `mail_suppression`'a (`reason='COMPLAINT'`, `email_hash` = küçük harfli adresin SHA-256 özeti; `MailSuppressionService.suppress(email, COMPLAINT)`) eklenmeli; ileride sağlayıcı webhook'u bu servisi çağıran korumalı bir uca bağlanabilir.

## 2. DNS kontrol listesi (kullanıcı/altyapı sahibi yapar)

Önerilen: işlemsel + duyuru postası için **ayrı gönderim alt alanı** (ör. `mail.kampus.example.edu.tr`), `From: no-reply@mail.kampus.example.edu.tr`. Ana kurum alan adının itibarı (öğrenci/personel postası) korunur.

1. **SPF** (gönderim alan adında TXT; yalnız bir SPF kaydı olmalı):
   `mail.kampus.example.edu.tr. TXT "v=spf1 include:_spf.smtp-saglayici.example -all"`
   Sağlayıcının verdiği `include`/IP'yi kullanın; yeni kurulumda önce `~all`, doğrulayınca `-all`. 10 DNS sorgusu sınırını aşmayın.
2. **DKIM**: SMTP sağlayıcıda alan adını ekleyin; sağlayıcı bir veya birkaç **CNAME/TXT** seçici kaydı verir (ör. `s1._domainkey.mail.kampus.example.edu.tr`). Kendi MTA'nızsa: `openssl genrsa -out dkim.key 2048` + `openssl rsa -in dkim.key -pubout` ile 2048 bit anahtar üretin, açık anahtarı TXT'ye yazın, özel anahtarı yalnız MTA'da tutun (repoda/`.env`'de değil). Sağlayıcıda **DKIM imzasını etkinleştirin ve `d=` alanının `From` alan adıyla hizalı olduğunu doğrulayın**. İmza `List-Unsubscribe` ve `List-Unsubscribe-Post` başlıklarını da kapsamalı (RFC 8058; Gmail/Yahoo tek tık için ister).
3. **DMARC** (`_dmarc.kampus.example.edu.tr` TXT) kademeli:
   - Hafta 0-4: `v=DMARC1; p=none; rua=mailto:dmarc-rapor@kampus.example.edu.tr; fo=1` — raporları okuyun, tüm meşru kaynakları (SPF/DKIM hizalı) belirleyin.
   - Sonra: `p=quarantine; pct=25` → `50` → `100`.
   - Son: `p=reject` (alt alan için `sp=`). `rua` raporlarını bir DMARC rapor aracıyla (ücretsiz seçenekler vardır) okunur hale getirin.
4. **PTR / rDNS**: kendi IP'nizden gönderiyorsanız IP'nin ters kaydı gönderen ana makine adına, o ad da IP'ye çözülmeli (forward-confirmed rDNS). Sağlayıcı kullanıyorsanız sağlayıcı yönetir.
5. **MX**: gönderim alt alanı yanıt/bounce alacaksa MX kaydı olmalı (veya `Reply-To` başka bir kutuya işaret etmeli). `no-reply` adresi bile bounce için geçerli bir envelope-from'a sahip olmalıdır.
6. **TLS**: SMTP bağlantısı STARTTLS/TLS; (isteğe bağlı) MTA-STS ve TLS-RPT TXT kayıtları.
7. **Sahiplik/itibar araçları**: Google Postmaster Tools (alan adı itibarı, spam oranı, kimlik doğrulama), Microsoft SNDS + JMRP (IP'ye özgü), Yahoo CFL (şikâyet döngüsü) kayıtlarını açın.
8. **BIMI** (isteğe bağlı): DMARC `quarantine/reject` sonrası marka logosu.

## 3. Isınma (warm-up) planı

Yeni alan adı/IP'de ani yüksek hacim spam'e düşürür. Kuyruk dakikada sınırı (`MAIL_MAX_PER_MINUTE`) ile planı uygulayın; **işlemsel posta bu sınırdan etkilenmez**. Örnek (günlük duyuru):

| Gün | En çok duyuru/gün | `MAIL_MAX_PER_MINUTE` |
|---|---|---|
| 1-3 | 50-100 | 5 |
| 4-7 | 250-500 | 10 |
| 8-14 | 1 000-2 500 | 20 |
| 15-21 | 5 000 | 30-60 |
| 22+ | ihtiyaca göre | sağlayıcı kotasına göre |

Kurallar: önce en etkileşimli (son 30 gün aktif) alıcılara gönderin; bounce < %2, şikâyet < %0,1 değilse bir önceki kademeye dönün; ani hacim artışı yapmayın; her gün düzenli hacim, haftalık dalgalanma değil.

## 4. SMTP sağlayıcı seçenekleri (tarafsız)

- Kurumun kendi SMTP/Exchange'i (alan adı zaten kurumun; SPF/DKIM'i BT yönetir; toplu gönderim kotasını sorun).
- Self-host: Postal, Postfix + OpenDKIM (IP itibarını ve rDNS'i siz yönetirsiniz; en çok iş).
- Yönetilen: Amazon SES, Brevo, Mailgun, SendGrid, Postmark vb. (hazır DKIM, itibar yönetimi, bounce/şikâyet webhook'ları; ücret ve veri konumu — KVKK için sözleşme/aktarım koşullarını değerlendirin).

Seçerken: DKIM + özel gönderim alanı desteği, bounce/şikâyet bildirimi (webhook/e-posta), TLS, günlük kota ve ısınma yardımı, IP paylaşımı (paylaşımlı IP'de komşu itibarı etkiler).

## 5. Ortam değişkenleri

| Değişken | Varsayılan | Anlam |
|---|---|---|
| `MAIL_ENABLED` | `false` | `true` = gerçek gönderim |
| `MAIL_HOST` / `MAIL_PORT` | `localhost` / `587` | SMTP sunucusu |
| `MAIL_USERNAME` / `MAIL_PASSWORD` | boş | SMTP kimliği (sır) |
| `MAIL_FROM` | `no-reply@bingol.edu.tr` | Gönderen; prod'da gerçek, DKIM/SPF'li alan adı |
| `MAIL_REPLY_TO` | boş | Reply-To (insan okuyan kutu) |
| `MAIL_REQUIRE_TLS` | `false` | `true` = STARTTLS zorunlu (prod önerisi) |
| `MAIL_SSL` | `false` | `true` = dolaylı TLS (port 465) |
| `MAIL_MAX_PER_MINUTE` | `30` | Duyuru dakikalık üst sınır (0 = sınırsız) |
| `MAIL_RECIPIENT_GAP_SECONDS` | `300` | Aynı adrese iki duyuru arası (sn; 0 = kapalı) |
| `PUBLIC_WEB_URL` | `http://localhost:8090` | Abonelik bağlantısı kökü; **prod'da https ve herkese açık**, `/api` backend'e vekillenmeli |
| `MAIL_DAILY_LIMIT` | `0` | Sağlayıcı günlük kotası (0 = koruma kapalı). Brevo ücretsiz için `300` (kayıtta doğrulayın) |
| `MAIL_DAILY_RESERVE` | `60` | Kotanın işlemsel postalara (kod/güvenlik) ayrılan kısmı; duyuru/CUSTOM yalnız `limit - reserve` altında gider |
| `MAIL_DAILY_RESET_HOUR_UTC` | `21` | Sağlayıcının kota gününü sıfırladığı UTC saati (21 = 00:00 İstanbul). Belirsizse panelden/destekten doğrulayıp değiştirin |
| `MAIL_UNSUBSCRIBE_KEY` | boş | Abonelik jetonu HMAC anahtarı (boş = JWT sırrından türetilir); anahtar değişirse eski bağlantılar geçersiz olur |

## 6. Test kontrol listesi (mail-tester.com tarzı)

1. Gerçek SMTP ile kendinize gönderip "orijinali göster": `SPF=pass`, `DKIM=pass`, `DMARC=pass`, `Message-ID` alan adınız.
2. mail-tester.com / GlockApps benzeri araçla puan (hedef 9+/10): SPF, DKIM, DMARC, rDNS, kara liste, `List-Unsubscribe`, düz metin alternatifi, HTML doğruluğu.
3. Gmail/Outlook/Yahoo/kurumsal posta kutusu ve Arapça (RTL) örnek: spam klasörü, görünüm, bağlantılar.
4. Duyuruda "abonelikten çık" bağlantısı: onay sayfası → düğme → ikinci duyuruda gönderilmediğini doğrulayın; Gmail'de tek tık "Abonelikten çık" düğmesi görünmeli.
5. Kara liste denetimi (Spamhaus, Barracuda vb.) ve gönderim IP/alan adı için.
6. İçerik: kısaltıcı bağlantı yok, büyük harf/ünlem yağmuru yok, konu kısa ve alıcının dilinde, bağlantı görünen metni hedef alan adı.

## 7. Hedefler ve izleme

- **Şikâyet oranı < %0,1** (Google Postmaster'da spam oranı; %0,3 üstü teslimi bozar), bounce < %2, abonelikten çıkma < %0,5/gönderim.
- Metrikler: `mail.queue.sent|failed|dead|suppressed|bounced|deferred|expired`; sağlık göstergesi `mailQueue` (DEAD/birikim uyarısı; `SKIPPED` alarm üretmez).
- Duyuru kampanyalarında yalnız açık rıza/uygun hukuki dayanağı olan alıcılara gönderin; abonelikten çıkanları (`mail_suppression`) hiçbir araçla yeniden eklemeyin.
- Alan adı itibarı: işlemsel ve duyuru trafiğini ayrı alt alanlara bölmek, duyuru sorunlarının doğrulama kodlarını etkilemesini engeller.

## 8. Doğrulanmayan / bilinen sınırlar

- Gerçek SMTP ile gönderim bu sürümde **denenmedi**; başlıklar birim testle (MimeMessage üretimi) doğrulandı, SPF/DKIM/DMARC sonuçları canlı ortamda sınanmalıdır.
- DKIM imzalama uygulama içinde yapılmaz (sağlayıcı/MTA yapar).
- FBL/şikâyet ve sağlayıcı bounce webhook'ları için uç yok; yalnız SMTP anındaki kalıcı hata (senkron bounce) işlenir. Asenkron bounce (DSN e-postası) okunmaz.
- Kuyruk dakikalık bütçesi aynı örnekte eşzamanlı iki turla bir iki e-posta aşabilir (hafif).

## 9. Brevo ücretsiz SMTP ile üretim kurulumu (`bukampus.net`)

Karar: e-posta Brevo ücretsiz SMTP ile gider; gönderici `noreply@bukampus.net`, Reply-To `destek@bukampus.net`. Kullanım yalnız kayıt doğrulama kodu, şifre sıfırlama kodu ve güvenlik bildirimleridir; toplu duyuru kullanılmaz. Ücretsiz plan yaklaşık günde 300 posta içindir.

> **Kayıt sırasında doğrulayın:** Brevo'nun host adı (`smtp-relay.brevo.com`), port (587), günlük limit (~300), kota sıfırlama saati, SMTP giriş adı biçimi ve DNS kayıt adları zamanla değişebilir. Aşağıdaki servis ayrıntıları bu belge yazılırken bilinenlerdir; Brevo panelindeki ve belgesindeki güncel değer geçerlidir. DKIM/doğrulama kayıtlarının değerini asla uydurmayın: Brevo panelinden aynen kopyalayın.

### 9.1 Brevo tarafı

1. brevo.com'da hesap açın (ücretsiz plan).
2. **Senders, Domains & Dedicated IPs > Domains > Add a domain**: `bukampus.net` ekleyin. Brevo size şu kayıtları gösterir (tam kayıtları panelden kopyalayın):
   - `brevo-code:...` değerli **TXT** doğrulama kaydı (alan adı sahipliği),
   - **DKIM**: `brevo1._domainkey` ve `brevo2._domainkey` adlı kayıtlar (CNAME biçiminde ya da TXT biçiminde sunulabilir; panelde hangisi yazıyorsa onu girin),
   - (varsa) DMARC önerisi.
3. **Senders > Add a sender**: `noreply@bukampus.net` gönderici adresini ekleyin (alan adı doğrulandıktan sonra).
4. **SMTP & API > SMTP** sayfasında **SMTP giriş adını** (genelde `bukampus.net` DEĞİL, Brevo'nun verdiği bir kullanıcı adıdır) ve **SMTP anahtarı** üretin. Anahtar bir sırdır: yalnız sunucudaki `.env.prod` dosyasına yazın; repoya/belgeye/sohbete koymayın.
5. Güvenlik: Brevo'da hesap için 2 adımlı doğrulamayı açın; sunucu IP'si için "Authorized IPs" kısıtı varsa sunucunun çıkış IP'sini ekleyin (Brevo'nun IP kısıtı ayarı hesabınızda açıksa).

### 9.2 DNS kayıtları (Cloudflare DNS)

| Tür | Ad | Değer |
|---|---|---|
| TXT | `@` | Brevo'nun verdiği `brevo-code:...` (panelden kopyalayın) |
| CNAME/TXT | `brevo1._domainkey` | Panelde gösterilen tam değer (kopyalayın) |
| CNAME/TXT | `brevo2._domainkey` | Panelde gösterilen tam değer (kopyalayın) |
| TXT | `@` (SPF) | `v=spf1 include:spf.brevo.com ~all` |
| TXT | `_dmarc` | `v=DMARC1; p=none; rua=mailto:destek@bukampus.net` |

- Cloudflare'de DKIM CNAME kayıtlarını **DNS only (gri bulut)** bırakın; proxy açık olursa doğrulama başarısız olur.
- **SPF tek kayıt olmalıdır.** Alan adında zaten bir SPF TXT varsa ikinci bir `v=spf1` kaydı eklemeyin (iki SPF kaydı SPF'i bozar); mevcut kayda `include:spf.brevo.com` ekleyerek birleştirin.
- **Cloudflare Email Routing** (aşağıda) kullanılıyorsa SPF'te Cloudflare'in include'u da olmalıdır. Birleşik örnek: `v=spf1 include:spf.brevo.com include:_spf.mx.cloudflare.net ~all`. Email Routing'i etkinleştirirken Cloudflare bu kayıtları (MX ve SPF) kendisi önerir; **güncel include adlarının doğruluğunu Brevo ve Cloudflare belgelerinden kontrol edin**.
- DMARC'a `p=none` ile başlayın; birkaç hafta `rua` raporlarında SPF/DKIM hizalamasının geçtiğini gördükten sonra `p=quarantine`'e çıkabilirsiniz.
- Brevo panelinde alan adı "Verified/Authenticated" olana dek bekleyin (DNS yayılımı dakikalar–saatler sürebilir).

### 9.3 Uygulama ayarları (`.env.prod`)

```
MAIL_ENABLED=true
MAIL_HOST=smtp-relay.brevo.com
MAIL_PORT=587
MAIL_USERNAME=<Brevo SMTP giriş adı>
MAIL_PASSWORD=<Brevo SMTP anahtarı>      # SIR
MAIL_FROM=noreply@bukampus.net
MAIL_REPLY_TO=destek@bukampus.net
MAIL_REQUIRE_TLS=true
PUBLIC_WEB_URL=https://bukampus.net
MAIL_MAX_PER_MINUTE=20
MAIL_DAILY_LIMIT=300
MAIL_DAILY_RESERVE=60
MAIL_DAILY_RESET_HOUR_UTC=21
```

`docker-compose.yml` ve `docker-compose.prod.yml` bu değişkenlerin hepsini konteynere geçirir (`MAIL_REPLY_TO`, `MAIL_REQUIRE_TLS`, `MAIL_SSL`, `MAIL_MAX_PER_MINUTE`, `MAIL_RECIPIENT_GAP_SECONDS`, `MAIL_DAILY_*`, `MAIL_UNSUBSCRIBE_KEY` dahil).

`ProdSettingsValidator` bu yapılandırmayla açılışı **reddetmez**: `From` alan adı (`bukampus.net`) ile SMTP kullanıcı alan adı farklı olduğunda yalnızca **uyarı** üretir (hata değil). **Brevo'da bu uyarı beklenir**: SMTP kullanıcı adı `bukampus.net` değildir; hizalama DKIM/SPF'in `bukampus.net` için doğrulanmış olmasıyla sağlanır, Brevo panelinde alan adının "doğrulanmış" görünmesi yeterlidir.

### 9.4 Günlük kota koruması

- Sayaç Redis `mail:daily:<gün>` (INCR, TTL 2 gün; Redis yoksa bellek içi yedek) ve yalnız **başarılı** gerçek gönderimde artar. Gün, `MAIL_DAILY_RESET_HOUR_UTC` saatinde başlar (varsayılan 21:00 UTC = 00:00 İstanbul; Brevo'nun sıfırlama saati UTC mi yerel mi belirsiz: kayıtta doğrulayıp ayarlayın).
- İşlemsel postalar (kod, güvenlik) günlük limite **kadar** gider. Duyuru/CUSTOM postalar yalnız `limit - reserve` (300-60=240) altında gider; kalan kota kodlara ayrılır.
- Limit dolunca kayıt **DEAD olmaz**, `next_attempt_at` ertesi kota gününe (+5 dk) ertelenir ve beklemede kalır. Doğrulama/sıfırlama kodu postaları 10 dk sonra zaten geçersiz olduğundan, ertelenen kod postası o zaman gönderilmeden kapanır (mevcut davranış; beklenen).
- Kota tamamen dolmuşken kayıt (`register`), `resend-code` ve `forgot-password` uçları, e-postadan bağımsız ve hesap sorgusundan ÖNCE, **503 `MAIL_QUOTA_EXHAUSTED`** ("Şu anda doğrulama kodu gönderemiyoruz, lütfen daha sonra tekrar deneyin", tr/en/ar) döner. Karar yalnız küresel kota durumuna bağlı olduğundan hesabın varlığını sızdırmaz (`MAIL_UNAVAILABLE`, kuyruğa yazılamayan tekil hata içindir). Mobil/web bu kodu genel hata olarak gösterebilir.
- Gözlemlenebilirlik: `GET /api/admin/system/overview` içinde `mail.dailyQuota` (kullanım %'si; %80 WARN, %95 CRIT; `MAIL_DAILY_LIMIT=0` ise UNKNOWN). Metrik: `mail.queue.quota_deferred`.

### 9.5 Cloudflare Email Routing ve Gmail ile cevap

1. Cloudflare > `bukampus.net` > **Email > Email Routing** etkinleştirin (MX/SPF kayıtlarını Cloudflare ekler; yukarıdaki SPF birleştirmesini uygulayın).
2. **Routing rules**: `destek@bukampus.net` ve `kvkk@bukampus.net` adreslerini kendi Gmail adresinize yönlendirin; Cloudflare'in gönderdiği doğrulama e-postasındaki bağlantıyı onaylayın.
3. Gmail'den `destek@bukampus.net` adıyla cevap yazmak: Gmail > Ayarlar > **Hesaplar ve İçe Aktarma > Başka bir adresten e-posta gönder (Send mail as) > Başka bir e-posta adresi ekle**: `destek@bukampus.net`, "Takma ad olarak ele al" işaretli. SMTP sunucusu `smtp-relay.brevo.com`, port 587, TLS; kullanıcı adı ve parola Brevo SMTP giriş adı/anahtarı. Gmail adrese bir doğrulama kodu yollar (Email Routing ile Gmail'inize düşer). Not: bu gönderimler de Brevo günlük kotasından yer; destek yazışması az olduğundan sorun değildir. `destek@` Brevo'da gönderici olarak ayrıca tanımlanmalı/doğrulanmalıdır.

### 9.6 Kurulum sonrası kontrol

1. Brevo alan adı durumu "doğrulanmış"; `dig TXT bukampus.net`, `dig TXT _dmarc.bukampus.net`, DKIM kayıtları dönüyor.
2. Backend açılışında `ProdSettingsValidator` hata vermiyor (yalnız "farklı alan adı" uyarısı olabilir).
3. Gerçek bir kayıt denemesi: kod gelir; "orijinali göster" ile SPF/DKIM/DMARC = pass.
4. `GET /api/admin/system/overview` > `mail.dailyQuota` değeri artıyor.
