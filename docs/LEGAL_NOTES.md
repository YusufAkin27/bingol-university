# Hukuki Metinler: Kullanıcı Notları (V480)

Bu belge **uygulama işleticisi (siz) içindir**; kullanıcıya gösterilmez. Metinlerin kendisinde "taslak" ibaresi yoktur. Ancak metinler yapay zekâ ile, uygulamanın gerçek davranışına (kod, `docs/ENCRYPTION.md`, saklama süreleri) bakılarak hazırlanmış **iyi niyetli ve ayrıntılı** metinlerdir; kesin hukuki güvence sağlamaz. Yayından önce bir avukata kısa kontrol ettirmeniz önerilir (bkz. bölüm 5). Daha geniş liste: `docs/legal/LEGAL_CHECKLIST.md`, iç belgeler: `docs/legal/internal/01-09`.

## 1. Ne var, nasıl çalışıyor?

- **Kaynak:** `docs/legal/<tür>_<dil>.md` (tr esas; en ve ar çevirisi). Dosyalar `scripts/build-legal-migration.js` ile `backend/.../db/migration/V480__legal_texts_v3.sql` dosyasına gömülür (`node scripts/build-legal-migration.js`, `--check` ile güncellik kontrolü). V290 ve V370 dondurulmuştur, dokunmayın. Metin değişirse yeni V48x ekleyin.
- **8 tür:** Kullanım Koşulları (TERMS), Gizlilik Politikası (PRIVACY), KVKK Aydınlatma (KVKK), Topluluk Kuralları (COMMUNITY_RULES), Açık Rıza (EXPLICIT_CONSENT), Çerez/Yerel Depolama (COOKIES), İçerik Bildirimi ve Kaldırma = 5651 yer sağlayıcı prosedürü (CONTENT_REMOVAL), Saklama ve İmha (RETENTION).
- **Sürümleme (V480):** TERMS, PRIVACY ve CONTENT_REMOVAL için yeni sürüm (tr+en+ar aynı numara, eskiler pasif). Diğer beş türde **sürüm değişmez**, mevcut aktif sürüme yalnız Arapça eklenir. `LegalService.pending` TERMS/PRIVACY için eski sürümü onaylamış herkesten **yeniden onay** ister (V480 sonrası ilk girişte). Bunu istemiyorsanız (henüz canlıda kullanıcı yoksa sorun yok) `require_reaccept` değerini V480 çalışmadan önce betikte `FALSE` yapın.
- **Arapça/İngilizce:** Her ikisinin başında "çeviri bilgi amaçlıdır; bağlayıcı metin Türkçedir" notu var. Arapça çeviri yapay zekâ çevirisidir; anadili Arapça olan biri ve hukuk bilen biri gözden geçirmelidir (özellikle KVKK/5651 terimleri, "Kurul", "KEP", "yer sağlayıcı").
- **Yer tutucular:** Metindeki `{{...}}` değerleri sunum anında Yönetici > Ayarlar'daki `app_setting` anahtarlarından doldurulur; boş değer olan kimlik satırları metinden çıkar (ham `{{` hiç görünmez).

## 2. SİZİN DOLDURMANIZ GEREKEN ALANLAR

| Ayar anahtarı | Durum (V481) | Değer / not |
|---|---|---|
| `legal.controller.name` | DOLU | `Yusuf Akın` (gerçek kişi; V290'daki "Bingöl Üniversitesi" varsayılanı V481 ile ezildi) |
| `legal.controller.address` | DOLU | Belkız Mah., 08004 Sk., Saltan Apt. E Blok No:5 D:02, Şehitkamil/Gaziantep (bkz. aşağıdaki gizlilik uyarısı) |
| `legal.controller.email` | DOLU | `ysufakin23@gmail.com` (KVKK ve hukuki bildirim) |
| `support_email` | DOLU | `ysufakin23@gmail.com` (hak başvuruları, içerik bildirimi; `PublicSupportMailer` Reply-To ve `GET /api/app/info` aynı ayarı okur) |
| `legal.hosting.location` | DOLU | `Türkiye` (barındırma gerçekten Türkiye'deyse doğru; değilse güncelleyin, KVKK m.9 anlatımını etkiler) |
| `legal.controller.jurisdiction` | DOLU | `Gaziantep` (boşsa varsayılan Bingöl idi) |
| `legal.controller.relation` | DOLU | Resmî olmayan, kişisel/bağımsız uygulama; üniversiteyle kurumsal bağ/ortaklık/onay yok; ad ve logo üniversiteye aittir (Kullanım Koşulları 15.1) |
| `legal.controller.kep` | **BOŞ** | KEP yok/bilinmiyor; satırlar metinden çıkar |
| `legal.controller.verbis` | **BOŞ** | VERBİS sicil no yok/bilinmiyor; satır çıkar. Muafiyet/eşik avukata sorulacak (bölüm 5) |

Tüm değerler yönetici panelinden (`PUT /api/admin/settings/{anahtar}`, yalnız ADMIN) değiştirilebilir; sözleşme metnine yansıması en geç 60 sn sürer (önbellek). V481 yalnızca ilk değerleri verir; sonradan panelden yapılan değişiklikler, V481 yeniden uygulanmadıkça ezilmez.

### Gizlilik uyarısı: gerçek kişi ve şahsi adres

Veri sorumlusu şirket değil gerçek kişidir. Kullanım Koşulları, Gizlilik ve KVKK metinleri adresi **herkese açık** gösterir (`{{controller.address}}`); KVKK m.10 gereği veri sorumlusunun iletişim adresi aydınlatmada yer almalıdır, ancak bu adres şahsi ikametgâh gibi görünüyorsa tüm kullanıcılar (ve sözleşme sayfasını gören herkes) tarafından görülür. Tercih: ayrı bir posta kutusu, iş/ofis adresi veya paylaşılan bir tebligat adresi kullanmak; bu durumda yalnız `legal.controller.address` ayarı değiştirilir (migration gerekmez). Karar sizin ve avukatınızındır. E-posta da herkese açık görünür.

Not: `relation` ve `jurisdiction` anahtarları V480 ile boş eklendi, V481 ile dolduruldu; yönetici panelinin ayarlar ekranı anahtarları listeliyorsa etiket çevirisi (web `admin-settings` i18n) eklenmemiş olabilir, bu bir web işidir.

## 3. Önemli kararlar ve gerekçeleri

1. **Koruyucu hükümler (eklendi, V480):** "olduğu gibi" sunum ve zımni garanti reddi (kaynak site bilgisinin doğruluğu dahil); doğrudan zarar için bile sorumluluğun kanunun izin verdiği ölçüde ve ispat edilen zararla sınırlanması; kullanıcı arası uyuşmazlıkta taraf olmama; kullanıcı içeriğinden kullanıcının sorumluluğu + sınırlı, devredilemez lisans (önceden vardı); hesap askıya alma/kapatma; hizmeti değiştirme, kısıtlama, sonlandırma hakkı; mücbir sebep; üçüncü taraf bağlantılar; değişiklik bildirimi ve yeniden onay; tazminat (kusur ölçüsünde); delil sözleşmesi (HMK m.193); e-posta ile tebligat; bölünebilirlik, feragat etmeme, devir, Türkçe metnin esas olması; Bingöl (veya sizin şehriniz) mahkeme/icra yetkisi; üniversiteyle ilişkinin netleştirilmesi.
2. **Bilerek YAZILMAYAN aşırı hükümler (yazılsa geçersiz olur ve ters teper):** kasıt/ağır kusur için sorumsuzluk (TBK m.115 gereği kesin hükümsüz); tüketicinin kanuni haklarını ve tüketici mahkemesi/hakem heyeti yetkisini kısıtlama (6502 s. K.; yetki kuralları emredici); "her türlü zarardan sınırsız sorumsuzluk" ve haksız şart niteliğinde tek taraflı hükümler (TBK m.20-25 genel işlem şartları: aşırı, beklenmedik ve karşı tarafı açıkça dezavantajlı hükümler yazılmamış sayılır); KVKK haklarından (m.11) peşin feragat; mesajların "tamamen gizli/uçtan uca şifreli" olduğu iddiası (doğru değil: sunucu tarafı zarf şifreleme, yöneticiler görebilir ve her erişim kayda geçer; metin bunu açıkça söyler); delil sözleşmesinin emredici hukuku bağlaması (HMK m.193 yalnız taraf iradesine bırakılmış delillerde geçerli; metin bunu saklı tutar); kullanıcı içeriğine münhasır, süresiz ve devredilebilir lisans (FSEK uyarınca eser sahibinin hakları; ayrıca KVKK ölçülülük ilkesi).
3. **Açık rıza AYRIDIR.** Kayıtta `acceptTerms=true` yalnızca TERMS, PRIVACY, KVKK ve COMMUNITY_RULES için onay kaydı (`legal_acceptance`) üretir (`LegalType.isSignupRequired`). EXPLICIT_CONSENT (rehber eşleştirme, anlık bildirim ve yurt dışı aktarım) kayıt onayına **gömülü değildir**; isteğe bağlıdır ve işletim sistemi izni / uygulama ayarı ile verilir. Uyum açısından doğru. **Boşluk:** rıza madde bazında (rehber/bildirim ayrı ayrı) veritabanında kayıt altına alınmıyor; yalnız belge düzeyinde (`POST /api/legal/consents`) kaydedilebilir. İspat için istemcinin izin ekranında EXPLICIT_CONSENT'i ayrı onay olarak göndermesi veya madde bazlı kayıt eklenmesi önerilir. (Kod değişikliği bu görevde yapılmadı.)
4. **Mesajlar uçtan uca şifreli değildir**, sunucu tarafı zarf şifreleme (AES-256-GCM, anahtar sunucuda) uygulanır; yönetici erişimi denetim kaydıyla yapılır. Metinler bunu dürüstçe anlatır (yanlış gizlilik vaadi tüketici ve KVKK riski doğurur).
5. **Yurt dışı aktarım (KVKK m.9):** Firebase/FCM (Google) ve iOS için APNs (Apple). Metinler "açık rıza ve/veya uygun güvence" der. 2024 değişikliği sonrası açık rıza yalnızca arızi aktarımlarda dayanak olabilir; düzenli push aktarımı için standart sözleşme / bildirim mekanizması (aşağıda) değerlendirilmelidir.
6. **5651:** Hizmet "yer sağlayıcı" olarak anlatılmıştır; içeriği önceden denetlemez, bildirim üzerine kaldırır; mahkeme kararı (m.9) saklıdır. **Trafik bilgisi saklama süresi için sayı yazılmadı**: "mevzuatın öngördüğü süre" denmiştir, çünkü güncel yönetmelik süresini doğrulayamadım (6 ay / 1-2 yıl gibi rakamlar sınıfa ve değişikliklere göre farklı olabilir). Uygulama cihaz/IP günlüğünü şu an **90 gün** tutuyor; bu mevzuattaki süreden kısa olabilir: avukata sorun, gerekirse `access-ban` ayarındaki süreyi uzatın ve `retention`/`privacy`/`kvkk` metinlerini güncelleyin.
7. **Saklama süreleri koddan doğrulandı** (`CLAUDE.md` ve `LEGAL_CHECKLIST`): analitik 180 gün, cihaz/IP günlüğü 90 gün, mail kuyruğu 30 gün (SENT/DEAD), cihaz token 60 gün, genel destek talebi 365 gün, doğrulama kodu 10 dk, bekleyen kayıt 1 sa, hesap silme = anonimleştirme. Bu rakamlar kodda değişirse metinler de değişmelidir.
8. **Taslak işaretleri temizlendi:** Gizlilik metninde kullanıcıya görünen üç `<DOĞRULANACAK: ...>` notu vardı; kodla karşılığı bulunanlar (anket oyu için ayrı silme süresi yok; konum izni yok) netleştirildi, bilinemeyenler tarafsız ifadeye çevrildi (barındırma sağlayıcısı kendi teknik kayıtlarını tutabilir). Bu cümleleri barındırma sağlayıcınızın gerçeğine göre kontrol edin.

## 4. Açık riskler

- **İşletici kimliği** artık Yusuf Akın (gerçek kişi). Gerçek kişi olarak işlettiğiniz için KVKK sorumluluğu ve VERBİS/sicil yükümlülükleri doğrudan size aittir.
- Üniversiteden **yazılı izin** yoksa, üniversitenin adı/logosu/içeriğini kullanmak ve kaynak siteyi derlemek (haber, yemek) haklar ve marka açısından risklidir (`docs/MVP.md` etik bölümü).
- 18 yaş altı kullanıcı: yasal temsilci onayı yaklaşımı net değil; metin "yasal temsilcinin bilgisi ve izni" der.
- Yönetici mesaj erişimi: kodda serbest gerekçe alanı yok; `docs/legal/internal/04` erişim defteri uygulanmalı. Silinen mesajların süresiz saklanması (varsayılan) KVKK ölçülülük açısından makul bir süreye bağlanmalı. `message_access_audit`/`admin_audit` için saklama süresi kodda yok.
- İstemciler `/legal/...` bağlantılarını sayfa içinde açmıyorsa (mobil `SimpleMarkdown` tablo/alıntıyı çizer; bağlantıları nasıl yönlendirdiği doğrulanmadı) metinler arası atıflar çalışmayabilir.
- EN metinleri Türkçeden kısadır (özet çeviri); AR çeviriler tam. Anlaşmazlıkta Türkçe esastır (metinlerde yazılı).
- Testler bu ortamda koşulamadı (Docker motoru yanıt vermedi); V480 SQL'i PostgreSQL'de çalıştırılmadı.

## 5. Yayın öncesi avukata önerilen kısa kontrol kapsamı

1. **Kimlik/statü:** Kim işleten ve veri sorumlusu? Gerçek kişi mi, dernek/şirket mi, üniversite birimi mi? Üniversiteyle yazılı izin/protokol gerekli mi?
2. **VERBİS:** Yıllık çalışan sayısı/bilanço eşiği veya ana faaliyetin özel nitelikli veri işlemesi gibi koşullar nedeniyle Veri Sorumluları Siciline kayıt yükümlülüğü var mı? (Eşikler her yıl güncellenen Kurul kararlarıyla belirlenir; güncel karara bakılmalı.) **Veri sorumlusu gerçek kişi:** gerçek kişi olmanın VERBİS muafiyet/eşik değerlendirmesine etkisi (çalışan sayısı ve bilanço eşikleri, ana faaliyet) ve şahsi adresin sözleşmelerde yayımlanması (bkz. bölüm 2 uyarısı). Ayrıca KVKK m.10 aydınlatmasında KEP zorunluluğu olup olmadığı. Kayıt gerekmiyorsa `legal.controller.verbis` boş kalır.
3. **Yurt dışı aktarım (m.9):** Firebase/APNs için uygun mekanizma (standart sözleşme imzası ve Kuruma 5 iş günü içinde bildirim, yeterlilik kararı veya arızi aktarım için açık rıza). Barındırma ve SMTP sağlayıcısının ülkesi.
4. **5651:** Yer sağlayıcı bildirimi/yükümlülükleri (örn. bildirim yükümlülüğü ve trafik bilgisi saklama süresi) ve 90 günlük cihaz/IP günlüğü ile çelişki.
5. **Tüketici/genel işlem şartları:** Hizmet ücretsiz ise 6502 kapsamı; sorumluluk sınırlaması ve tazminat maddelerinin TBK m.20-25, m.115 açısından kontrolü; delil sözleşmesi.
6. **18 yaş altı** için yasal temsilci yaklaşımı.
7. **Mesaj erişimi** (yönetici görüntüleme) için aydınlatma ve çalışan/yönetici taahhütnamesi; haberleşme gizliliği (TCK m.132) riski.
8. **Arapça ve İngilizce** çeviriler (ayrıca anadil kontrolü).

## 6. Mobil/web ile uyum (kod değiştirilmedi)

- Metinler sade Markdown (`#`, `##`, listeler, `**kalın**`, `|tablo|`, `> alıntı`, bağlantı). Mobil `SimpleMarkdown` ve web `MarkdownText` bunları işler. Sözleşme metnini `GET /api/legal/{tür}` `Accept-Language` ile üç dilde sunar.
- Kayıt sayfasındaki "sözleşmeyi onaylamış sayılırsın" cümlesi için **öneri** (i18n dosyalarına dokunulmadı): *"Hesap oluşturarak Kullanım Koşulları, Gizlilik Politikası, KVKK Aydınlatma Metni ve Topluluk Kuralları'nı okuduğunu ve kabul ettiğini beyan edersin. Rehber eşleştirme ve anlık bildirim gibi isteğe bağlı izinler ayrıca ve ayrı onayla istenir."* Metin tek onay kutusuyla dört belgeyi kapsıyor; açık rıza cümleye **eklenmemelidir**.
- Mobil kayıt ekranı yeni bilgilendirme türlerini (EXPLICIT_CONSENT, COOKIES, CONTENT_REMOVAL, RETENTION) listeler mi doğrulanmadı; `GET /api/legal` hepsini döndürür.

## 7. Kalan dikkat noktaları (V481 sonrası)

- KVKK metni alıcı tablosunda "Bingöl Üniversitesi ilgili birimleri / yetkili yöneticiler" satırı var (kvkk tr/en/ar). Uygulama bağımsız ve kişisel işletildiği için, verinin gerçekten üniversite birimlerine aktarılıp aktarılmadığı doğrulanmalı; aktarılmıyorsa satır kaldırılmalı (yeni sözleşme sürümü gerekir; `docs/legal/kvkk_*.md` + `scripts/build-legal-migration.js` ile V482). Bu görevde metinlere dokunulmadı.
- Kullanım Koşulları madde 15.1 artık `legal.controller.relation` değerini gösterir (varsayılan cümlenin yerine geçer). Marka/logo maddesi (m.7: "adı ve logosu ilgili kuruma aittir") ve relation değeri birlikte "izin/ortaklık ima edilmez" mesajını verir.
- Üniversiteden yazılı izin yoksa ad/logo/içerik kullanımı riski sürer (bölüm 4).
