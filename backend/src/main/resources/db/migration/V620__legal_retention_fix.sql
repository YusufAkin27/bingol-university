-- V620: Saklama/aydinlatma metinleri duzeltmesi (docs/legal/*.md'den scripts/build-legal-migration-v620.js ile URETILDI; elle duzenlemeyin).
-- * RETENTION, PRIVACY ve KVKK icin yeni surum (COALESCE(MAX(version),0)+1) tr+en+ar ayni numarayla aktif eklenir, onceki aktif surumler pasife alinir.
-- * Duzeltmeler koddaki gercek degerlere gore: analitik ham olay 45 gun, bildirim kutusu okunmus 30 / okunmamis 90 gun (+200 sinir),
--   e-posta kuyrugu gonderilen 7 / basarisiz 30 gun, kampanya kayitlari 180 gun, gunluk aktiflik 400 gun, admin islem kaydi 365 gun,
--   mesaj erisim ve kulup islem kaydi 730 gun; hikaye/yorum/etiket ifadeleri kaldirildi (V470); e-posta saglayicisi (Brevo) ve
--   bildirim saglayicisi (Firebase) aktarim satirlari; hesap silme kapsami (sahipsiz kulup, etkinlik basvurulari, gorseller).
-- * require_reaccept = FALSE (bilgilendirme duzeltmesi; yeni veri isleme yok, sureler kisaldi). Gerekce: docs/LEGAL_NOTES.md.

DO $do_retention$
DECLARE
    v INTEGER;
BEGIN
    SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = 'RETENTION';
    UPDATE legal_document SET active = FALSE WHERE type = 'RETENTION' AND active;
    INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active) VALUES
    ('RETENTION', 'tr', v, $t_retention_tr$Kişisel Veri Saklama ve İmha Politikası (Özet)$t_retention_tr$, $c_retention_tr$Bu özet, kişisel verilerinizin ne kadar süre saklandığını ve süre sonunda ne olduğunu gösterir. Kurum içi ayrıntılı politika bu özetin dayanağıdır. Süreler uygulamanın ayarlarında tanımlıdır; işletici bunları değiştirebilir, değişiklikte bu metin güncellenir.

## 1. İlkeler

1. Veriler, işleme amacı için gerekli süre kadar ve mevzuatın izin verdiği süre boyunca saklanır.
2. Süre dolunca veri otomatik gece işleriyle **silinir**, **yok edilir** veya **anonim** hale getirilir.
3. Yasal bir saklama yükümlülüğü varsa ilgili süre boyunca saklanır.
4. Periyodik imha: otomatik temizleme işleri günlük/saatlik çalışır; kişisel veri imhası kayıt altına alınır.

## 2. Saklama süreleri

| Veri | Süre | Süre sonunda |
|---|---|---|
| Bekleyen kayıt (doğrulanmamış) | 1 saat | Silinir |
| E-posta doğrulama / şifre sıfırlama kodu | 10 dakika (en çok 5 deneme) | Geçersiz olur / silinir |
| Erişim anahtarı | 15 dakika | Geçersiz olur |
| Yenileme anahtarı (özet olarak) | En çok 30 gün; çıkış/şifre değişimi/yeni mobil girişte erken silinir | Silinir |
| Bildirim kutusu | Okunmuş 30 gün, okunmamış 90 gün; kullanıcı başına en yeni 200 bildirim tutulur | Silinir |
| Cihaz bildirim anahtarı | 60 gün görülmezse | Silinir |
| Cihaz kimliği (özet) ve IP kayıtları | 90 gün (hesap silinince hemen) | Silinir |
| Uygunsuz ifade filtresi kaydı (alan, kullanıcı, zaman; metin yok) | 90 gün | Silinir |
| Push bildirim kuyruğu | Bekleyen en çok 24 saat denenir; gönderilen 7 gün, başarısız 30 gün | Silinir |
| Silinen gönderinin (Keşfet) medya dosyaları | 30 gün | Diskten ve veritabanından silinir |
| Kulüp gönderisine eklenen görsel | Gönderi silinince, kulüp kapanınca veya hesap silinince hemen | Diskten silinir |
| Gönderiye bağlanmamış yüklenen medya | 24 saat | Silinir |
| Takip ilişkileri, favori haberler, kişisel ders programı ve sınav kayıtları | Hesap açık olduğu sürece | Hesap silinince silinir |
| Anket oy kaydı | Hesap açık olduğu sürece | Hesap silinince kullanıcı bağlantısı kopar (kimliksiz sayaç kalır); katılım kaydı silinir |
| Erişim engeli kaydı | Engel sürdükçe ve denetim için gerekli süre | Silinir / pasifleşir |
| Analitik ham olaylar (ekran/olay adı, zaman) | 45 gün (hesap silinince hemen) | Silinir; kalıcı olarak yalnızca kişiye bağlı olmayan, toplulaştırılmış günlük özetler kalır |
| Günlük aktiflik kaydı (hangi günlerde uygulamayı açtığınız) | 400 gün (hesap silinince hemen) | Silinir |
| E-posta kuyruğu | Gönderilenler 7 gün, gönderilemeyenler (başarısız) 30 gün | Silinir |
| Yönetici duyuru e-postası (kampanya) kayıtları: kampanya ve alıcı satırları | Kampanya bitiminden 180 gün (hesap silinince alıcı satırınız hemen silinir) | Silinir |
| Mesajlar | Hesap açık olduğu sürece; hesap silinse de sohbet bağlamı için kalır (yazar anonim) | Ayarlanırsa süre sonunda silinir |
| Silinen mesajların ve düzenleme geçmişinin şifreli kopyası | Varsayılan süresiz (ayarlanabilir) | Süre ayarlıysa kalıcı silinir |
| Tek gönderimlik fotoğrafın şifreli kopyası | 365 gün (ayarlanabilir) | Silinir; görüntüleme kaydı kalır |
| Sohbette gönderilmemiş (yüklenip bağlanmamış) medya | 24 saat | Silinir |
| Etkinlik sohbet odası | Etkinlik bitiminden 7 gün sonra kapanır | Oda kapanır |
| Herkese açık (girişsiz) destek talebi | 365 gün | Silinir |
| Destek / geri bildirim / itiraz / rapor notları | Hesap silinince metinler temizlenir | Kimliksiz kayıt kalır |
| Sözleşme ve rıza onay kayıtları | Hesap silinse de ispat için | Yasal zamanaşımı sonuna kadar |
| Moderasyon ihlal ve yasak izleri | Hesap silinse de kimliksiz | Güvenlik/ispat süresince |
| Yönetici işlem kaydı (IP dahil) | 365 gün | Silinir |
| Mesaj erişim kaydı ve kulüp yönetim işlem kaydı | 730 gün (kayıtlar yalnız eklenir, değiştirilemez) | Süre sonunda silinir |
| Rehber eşleştirme özetleri | **Saklanmaz** | — |
| Konum | **Toplanmaz ve saklanmaz** (uygulama konum izni istemez) | — |

## 3. Hesap silinince

Hesap silme **anonimleştirmedir**. Silinenler: bildirim cihaz anahtarları ve bekleyen push kayıtları, bildirim kutusu ve tercihleri, takip ilişkileri, ders programı ve sınav kayıtları, anket katılım kaydı, beğeniler, Keşfet gönderileri (medya 30 gün sonra), favoriler, oy ve etkinlik geri bildirimleri, engel listesi, kulüp başvuru yanıtları, topluluk üyelikleri, e-posta kampanyası alıcı satırları, yüklenen sohbet fotoğrafları, **cihaz/IP kayıtları ve analitik olaylarınız ile günlük aktiflik kaydınız (hemen)**, kulüp gönderilerine eklediğiniz görseller (hemen diskten). Etkinlik başvurularınız kapatılır (bekleme listesindeki sıradaki kişi yer alır) ve oluşturduğunuz, kulübe bağlı olmayan bitmemiş etkinlikler iptal edilir. Kulüp sahibiyseniz sahiplik, kulübün en eski aktif yöneticisine devredilir; yönetici yoksa kulüp kapatılır ve üyelere bildirilir. Anonimleştirilenler: ad, e-posta, profil. Korunanlar (kimliksiz/sınırlı): mesajlar ve topluluk gönderilerinin metni (başkalarının bağlamı), sözleşme onayları, moderasyon izleri, yönetici kayıtları, anonim etkinlik sayaçları. Diğer kayıtlar yukarıdaki tablodaki sürelerde silinir. Ayrıntı: [Gizlilik Politikası](/legal/privacy).

## 4. Yasal saklama yükümlülükleri

Hizmet sağlayıcı olarak, yürürlükteki mevzuat (özellikle 5651 sayılı Kanun ve ikincil düzenlemeleri) gereği bazı erişim/trafik kayıtlarını belirli süre saklamak zorunda kalabiliriz. Böyle bir yükümlülük doğduğunda ilgili kayıtlar mevzuatta belirtilen süre boyunca saklanır ve bu metin güncellenir. Mevcut sürede cihaz/IP güvenlik kayıtlarının saklama süresi yukarıdaki tabloda belirtilen süredir.

## 5. İmha yöntemleri

Veritabanı kayıtları güvenli silme ile kaldırılır; dosyalar depolamadan silinir; anonimleştirmede kimliği belirleyen alanlar geri döndürülemez şekilde değiştirilir; şifreli verilerde anahtarla birlikte erişim kapatılır. Yedeklerden silinme, yedek döngüsü içinde gerçekleşir.

## 6. Haklarınız

Verilerinizin silinmesini veya anonim hale getirilmesini [KVKK Aydınlatma Metni](/legal/kvkk) bölüm 11'deki yollarla (Destek, yazılı, KEP) isteyebilirsiniz; başvurular en geç 30 gün içinde yanıtlanır.

> **Özetle:** Çoğu teknik kayıt günler veya aylar içinde otomatik silinir; mesajlar ve hukuki ispat kayıtları ise sınırlı biçimde, kimliksiz olarak daha uzun kalabilir. Rehber özetleri saklanmaz; konum hiç toplanmaz.$c_retention_tr$, FALSE, TRUE),
    ('RETENTION', 'en', v, $t_retention_en$Personal Data Retention and Destruction (Summary)$t_retention_en$, $c_retention_en$*This English text is provided for information only. The Turkish text is authoritative.*

This summary shows how long your personal data is kept and what happens afterwards. Periods are defined in application settings and may be changed by the Operator, in which case this text is updated.

## 1. Principles

Data is kept for the time needed for its purpose and as permitted by law, then **deleted**, **destroyed** or **anonymised** by nightly jobs. Where a legal retention duty exists, data is kept for that period.

## 2. Retention periods

| Data | Period | After |
|---|---|---|
| Pending (unverified) registration | 1 hour | Deleted |
| Verification / reset code | 10 minutes (max 5 attempts) | Invalid / deleted |
| Access token | 15 minutes | Expires |
| Refresh token (as digest) | At most 30 days; removed earlier on logout, password change or new mobile login | Deleted |
| Notification inbox | Read 30 days, unread 90 days; the newest 200 notifications per user are kept | Deleted |
| Push token | If unseen for 60 days | Deleted |
| Device identifier digest and IP records | 90 days (immediately on account deletion) | Deleted |
| Inappropriate-language filter log (field, user, time; no text) | 90 days | Deleted |
| Push notification queue | Pending retried for at most 24 hours; sent 7 days, failed 30 days | Deleted |
| Media files of a deleted post (Discover) | 30 days | Removed from disk and database |
| Image attached to a club post | Immediately when the post is deleted, the club is closed or the account is deleted | Removed from disk |
| Uploaded media not attached to a post | 24 hours | Deleted |
| Follows, bookmarked news, personal timetable and exam data | While the account is open | Deleted with the account |
| Poll vote record | While the account is open | On deletion the link to the user is removed (anonymous counter remains); participation record deleted |
| Access-ban record | While the ban lasts and as needed for audit | Deleted / deactivated |
| Raw analytics events (screen/event name, time) | 45 days (immediately on account deletion) | Deleted; only non-personal, aggregated daily summaries remain permanently |
| Daily activity record (which days you opened the app) | 400 days (immediately on account deletion) | Deleted |
| E-mail queue | Sent 7 days, failed (undeliverable) 30 days | Deleted |
| Administrator announcement e-mail (campaign) records: campaign and recipient rows | 180 days after the campaign ends (your recipient row is deleted at once when you delete your account) | Deleted |
| Messages | While the account is open; remain as chat context after deletion (author anonymous) | Deleted if a limit is configured |
| Encrypted copy of deleted messages and edit history | Default indefinite (configurable) | Permanently deleted if a limit is set |
| Encrypted copy of view-once photos | 365 days (configurable) | Deleted; open record remains |
| Uploaded but unattached chat media | 24 hours | Deleted |
| Event chat room | Closes 7 days after the event | Room closed |
| Public (logged-out) support request | 365 days | Deleted |
| Support / feedback / appeal / report notes | Scrubbed when the account is deleted | Anonymous record remains |
| Agreement and consent records | Kept after deletion as proof | Until limitation periods end |
| Moderation violation and ban traces | Kept anonymously after deletion | While needed for security/evidence |
| Administrator action log (including IP) | 365 days | Deleted |
| Message-access log and club administration action log | 730 days (entries are append-only and cannot be altered) | Deleted when the period ends |
| Contact matching digests | **Not stored** | — |
| Location | **Not collected or stored** (the app does not ask for location permission) | — |

## 3. When you delete your account

Deletion is **anonymisation**. Deleted: push tokens and pending push entries, inbox and preferences, follows, timetable and exam data, poll participation record, likes, Discover posts (media after 30 days), bookmarks, votes and event feedback, block list, club application answers, community memberships, e-mail campaign recipient rows, uploaded chat photos, **your device/IP records, analytics events and daily activity record (immediately)**, and images you attached to club posts (immediately, from disk). Your event applications are closed (the next person on the waiting list moves up) and unfinished events you created that are not tied to a club are cancelled. If you own a club, ownership passes to its longest-standing active administrator; if there is none, the club is closed and its members are notified. Anonymised: name, e-mail, profile. Kept (anonymous/limited): the text of messages and community posts (others' context), agreement acceptances, moderation traces, administrator records, anonymous event counters. Other records are removed within the periods in the table above. See the [Privacy Policy](/legal/privacy).

## 4. Legal retention duties

As a service provider we may be required by law (notably Law No. 5651 and its regulations) to retain certain access/traffic records for a fixed period. If such a duty applies, those records are kept for the legally required period and this text is updated. In the current version, device/IP security records are kept for the period stated above.

## 5. Destruction methods

Database records are deleted securely; files are removed from storage; anonymisation irreversibly replaces identifying fields; for encrypted data, access is closed together with the key. Removal from backups occurs within the backup cycle.

## 6. Your rights

Request deletion or anonymisation through the routes in the [KVKK Notice](/legal/kvkk) section 11; applications are answered within 30 days.

> **In short:** Most technical records are deleted automatically within days or months; messages and legal-proof records may remain longer in limited, anonymous form. Contact digests are not stored and location is never collected.$c_retention_en$, FALSE, TRUE),
    ('RETENTION', 'ar', v, $t_retention_ar$الاحتفاظ بالبيانات وإتلافها$t_retention_ar$, $c_retention_ar$*هذا النص العربي ترجمة للاطلاع فقط؛ النص التركي هو المرجع الملزم عند أي اختلاف.*

يبيّن هذا الملخص المدة التي تُحفظ فيها بياناتكم الشخصية وما يحدث لها عند انتهاء المدة. وتُعدّ السياسة التفصيلية الداخلية للمؤسسة أساسًا لهذا الملخص. والمدد معرَّفة في إعدادات التطبيق؛ ويجوز للمشغّل تغييرها، وعند التغيير يُحدَّث هذا النص.

## 1. المبادئ

1. تُحفظ البيانات للمدة اللازمة لغاية المعالجة وطوال المدة التي تسمح بها التشريعات.
2. عند انقضاء المدة تُ**حذف** البيانات أو **تُتلف** أو تُجعل **مجهولة الهوية** تلقائيًا بمهام ليلية.
3. إذا وُجد التزام قانوني بالحفظ فتُحفظ البيانات طوال المدة المعنية.
4. الإتلاف الدوري: تعمل مهام التنظيف الآلي يوميًا/كل ساعة؛ ويُسجَّل إتلاف البيانات الشخصية.

## 2. مدد الاحتفاظ

| البيانات | المدة | عند انتهاء المدة |
|---|---|---|
| التسجيل المعلّق (غير الموثَّق) | ساعة واحدة | يُحذف |
| رمز توثيق البريد الإلكتروني / إعادة تعيين كلمة المرور | 10 دقائق (5 محاولات كحد أقصى) | يصبح غير صالح / يُحذف |
| مفتاح الوصول | 15 دقيقة | يصبح غير صالح |
| مفتاح التجديد (على شكل ملخص) | 30 يومًا كحد أقصى؛ ويُحذف مبكرًا عند تسجيل الخروج/تغيير كلمة المرور/تسجيل دخول جديد من الجوال | يُحذف |
| صندوق الإشعارات | المقروء 30 يومًا، وغير المقروء 90 يومًا؛ ويُحتفظ بأحدث 200 إشعار لكل مستخدم | يُحذف |
| مفتاح إشعارات الجهاز | إذا لم يُرَ لمدة 60 يومًا | يُحذف |
| معرّف الجهاز (ملخص) وسجلات IP | 90 يومًا (فورًا عند حذف الحساب) | يُحذف |
| سجل مرشح العبارات غير اللائقة (الحقل، المستخدم، الوقت؛ دون النص) | 90 يومًا | يُحذف |
| طابور الإشعارات الفورية (Push) | تُجرَّب المعلّقة 24 ساعة كحد أقصى؛ المرسلة 7 أيام، والفاشلة 30 يومًا | يُحذف |
| ملفات الوسائط الخاصة بمنشور محذوف (اكتشاف) | 30 يومًا | تُحذف من القرص ومن قاعدة البيانات |
| الصورة المرفقة بمنشور نادٍ | فورًا عند حذف المنشور أو إغلاق النادي أو حذف الحساب | تُحذف من القرص |
| الوسائط المرفوعة غير المرتبطة بمنشور | 24 ساعة | تُحذف |
| علاقات المتابعة، والأخبار المفضلة، والجدول الدراسي الشخصي وسجلات الامتحانات | ما دام الحساب مفتوحًا | تُحذف عند حذف الحساب |
| سجل التصويت في الاستبيان | ما دام الحساب مفتوحًا | عند حذف الحساب ينقطع ارتباطه بالمستخدم (يبقى عدّاد مجهول الهوية)؛ ويُحذف سجل المشاركة |
| سجل حظر الوصول | ما دام الحظر قائمًا والمدة اللازمة للتدقيق | يُحذف / يُعطَّل |
| أحداث التحليلات الخام (اسم الشاشة/الحدث، الوقت) | 45 يومًا (فورًا عند حذف الحساب) | تُحذف؛ وتبقى دائمًا ملخصات يومية مجمّعة غير مرتبطة بالأشخاص فقط |
| سجل النشاط اليومي (الأيام التي فتحت فيها التطبيق) | 400 يوم (فورًا عند حذف الحساب) | يُحذف |
| طابور البريد الإلكتروني | المرسل 7 أيام، والفاشل (غير القابل للتسليم) 30 يومًا | يُحذف |
| سجلات رسائل الإعلانات الإدارية (الحملات): صفوف الحملة والمستلمين | 180 يومًا بعد انتهاء الحملة (يُحذف صف المستلم الخاص بك فورًا عند حذف حسابك) | تُحذف |
| الرسائل | ما دام الحساب مفتوحًا؛ وتبقى حتى بعد حذف الحساب من أجل سياق المحادثة (الكاتب مجهول) | تُحذف عند انتهاء المدة إذا جرى ضبطها |
| النسخة المشفّرة للرسائل المحذوفة وسجل التعديل | افتراضيًا دون أجل (قابل للضبط) | تُحذف نهائيًا إذا ضُبطت مدة |
| النسخة المشفّرة للصورة ذات الإرسال الواحد | 365 يومًا (قابل للضبط) | تُحذف؛ ويبقى سجل المشاهدة |
| الوسائط غير المرسلة في المحادثة (المرفوعة وغير المرتبطة) | 24 ساعة | تُحذف |
| غرفة محادثة الفعالية | تُغلق بعد 7 أيام من انتهاء الفعالية | تُغلق الغرفة |
| طلب الدعم العام (بدون تسجيل دخول) | 365 يومًا | يُحذف |
| طلبات الدعم / الملاحظات / الاعتراضات / ملاحظات البلاغات | تُمسح النصوص عند حذف الحساب | يبقى سجل مجهول الهوية |
| سجلات الموافقة على الاتفاقيات والإقرارات | تبقى حتى بعد حذف الحساب لأغراض الإثبات | حتى نهاية التقادم القانوني |
| آثار مخالفات الإشراف والحظر | تبقى مجهولة الهوية حتى بعد حذف الحساب | طوال مدة الأمان/الإثبات |
| سجل إجراءات المديرين (بما فيه IP) | 365 يومًا | يُحذف |
| سجل الوصول إلى الرسائل وسجل إجراءات إدارة النوادي | 730 يومًا (السجلات للإضافة فقط ولا تُعدَّل) | تُحذف عند انتهاء المدة |
| ملخصات مطابقة جهات الاتصال | **لا تُحفظ** | — |
| الموقع | **لا يُجمع ولا يُحفظ** (لا يطلب التطبيق إذن الموقع) | — |

## 3. عند حذف الحساب

حذف الحساب هو **إخفاء للهوية**. المحذوف: مفاتيح إشعارات الأجهزة وسجلات الإشعارات الفورية المعلّقة، وصندوق الإشعارات وتفضيلاته، وعلاقات المتابعة، والجدول الدراسي وسجلات الامتحانات، وسجل المشاركة في الاستبيان، والإعجابات، ومنشورات اكتشاف (الوسائط بعد 30 يومًا)، والمفضلات، والأصوات وملاحظات تقييم الفعاليات، وقائمة الحظر، وردود طلبات الانضمام إلى النوادي، وعضويات المجتمعات، وصفوف مستلمي حملات البريد الإلكتروني، وصور المحادثة المرفوعة، و**سجلات الجهاز/IP وأحداث التحليلات وسجل النشاط اليومي (فورًا)**، والصور التي أرفقتها بمنشورات النوادي (فورًا ومن القرص). وتُغلق طلبات مشاركتك في الفعاليات (ويتقدّم التالي في قائمة الانتظار)، وتُلغى الفعاليات غير المنتهية التي أنشأتها وغير المرتبطة بنادٍ. وإذا كنت مالكًا لنادٍ فتنتقل الملكية إلى أقدم مدير نشط فيه؛ وإن لم يوجد يُغلق النادي ويُبلَّغ أعضاؤه. ما يُجعل مجهول الهوية: الاسم والبريد الإلكتروني والملف الشخصي. ما يُحفظ (دون هوية/بشكل محدود): نصوص الرسائل ومنشورات المجتمع (لأنها سياق الآخرين)، وإقرارات الاتفاقيات، وآثار الإشراف، وسجلات المديرين، وعدّادات الفعاليات المجهولة. وتُحذف السجلات الأخرى في المدد الواردة في الجدول أعلاه. للتفصيل: [سياسة الخصوصية](/legal/privacy).

## 4. التزامات الاحتفاظ القانونية

بصفتنا مزوّد خدمة، قد نضطر بموجب التشريعات النافذة (ولا سيما القانون رقم 5651 ولوائحه الثانوية) إلى حفظ بعض سجلات الوصول/حركة البيانات لمدة معينة. وعند نشوء التزام كهذا تُحفظ السجلات المعنية طوال المدة المنصوص عليها في التشريعات ويُحدَّث هذا النص. وفي الوضع الحالي فإن مدة الاحتفاظ بسجلات أمان الجهاز/IP هي المدة المبينة في الجدول أعلاه.

## 5. طرق الإتلاف

تُزال سجلات قاعدة البيانات بالحذف الآمن؛ وتُحذف الملفات من التخزين؛ وفي إخفاء الهوية تُستبدل الحقول المحددة للهوية بصورة لا رجعة فيها؛ وفي البيانات المشفّرة يُغلق الوصول مع المفتاح. ويتم الحذف من النسخ الاحتياطية ضمن دورة النسخ الاحتياطي.

## 6. حقوقكم

يمكنكم طلب حذف بياناتكم أو جعلها مجهولة الهوية بالطرق المبينة في القسم 11 من [إشعار الإفصاح بموجب قانون حماية البيانات الشخصية (KVKK)](/legal/kvkk) (الدعم، كتابةً، KEP)؛ وتُجاب الطلبات في أجل أقصاه 30 يومًا.

> **باختصار:** تُحذف معظم السجلات التقنية تلقائيًا خلال أيام أو أشهر؛ أما الرسائل وسجلات الإثبات القانوني فقد تبقى لمدة أطول بصورة محدودة ودون هوية. لا تُحفظ ملخصات جهات الاتصال؛ ولا يُجمع الموقع إطلاقًا.$c_retention_ar$, FALSE, TRUE);
END
$do_retention$;

DO $do_privacy$
DECLARE
    v INTEGER;
BEGIN
    SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = 'PRIVACY';
    UPDATE legal_document SET active = FALSE WHERE type = 'PRIVACY' AND active;
    INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active) VALUES
    ('PRIVACY', 'tr', v, $t_privacy_tr$Gizlilik Politikası$t_privacy_tr$, $c_privacy_tr$Bu politika, BÜ Kampüs uygulaması ve web sitesini kullanırken hangi verilerinizin işlendiğini, neden, ne kadar süre saklandığını ve haklarınızı sade bir dille anlatır. Hukuki çerçeve ve başvuru usulü için [KVKK Aydınlatma Metni](/legal/kvkk) ile birlikte okuyun.

Veri sorumlusu: {{controller.name}}{{?controller.address}}, {{controller.address}}{{/controller.address}}. İletişim: {{controller.email|uygulama içi Destek bölümü}}.

## 1. Kısaca

1. Verilerinizi **satmayız**, reklam amacıyla üçüncü kişilerle paylaşmayız.
2. Yalnızca hizmeti sunmak, güvenliği sağlamak ve yasal yükümlülükler için gerekli veriyi işleriz.
3. Rehber eşleştirme ve anlık bildirim gibi isteğe bağlı izinler **açık rızanıza** bağlıdır ve istediğiniz zaman geri alınabilir ([Açık Rıza Metni](/legal/explicit-consent)). Uygulama **cihaz konumunuzu istemez, toplamaz ve saklamaz**.
4. Mesajlarınız sunucuda şifreli saklanır; ancak sistem **uçtan uca şifreli değildir** ve yetkili yöneticiler, kayda alınarak, gerekçeli durumlarda mesajları görüntüleyebilir.
5. Hesabınızı silerseniz kişisel verileriniz anonimleştirilir; bazı kayıtlar yasal sebeplerle ve başkalarının haklarını korumak için sınırlı şekilde kalır.

## 2. Hangi verileri işliyoruz?

| Veri | Neden | Hukuki sebep | Saklama süresi |
|---|---|---|---|
| **Hesap:** e-posta (bingol.edu.tr), ad-soyad, şifre (yalnızca tek yönlü özet olarak), dil tercihi | Üyelik, kimlik doğrulama, hizmetin sunulması | Sözleşmenin ifası (KVKK m.5/2-c) | Hesap açık olduğu sürece; silinince anonimleştirilir |
| **Profil:** fakülte, bölüm, sınıf, biyografi, profil fotoğrafı, gizlilik ayarlarınız | Profilinizin diğer kullanıcılara gösterilmesi (alan bazında gizlenebilir) | Sözleşmenin ifası; isteğe bağlı alanlarda açık rıza (m.5/1) | Hesap açık olduğu sürece |
| **Bekleyen kayıt ve doğrulama kodu:** e-posta, kodun özeti | E-posta doğrulaması | Sözleşme öncesi işlem / sözleşmenin ifası | Bekleyen kayıt 1 saat; doğrulama kodu 10 dakika |
| **Oturum:** yenileme anahtarının özeti, oturum durumu | Güvenli oturum yönetimi | Meşru menfaat (m.5/2-f) | Yenileme anahtarı en çok 30 gün; çıkışta/şifre değişiminde silinir |
| **Mesajlar:** metin, fotoğraf, video, düzenleme geçmişi, tepkiler, okundu bilgisi, sohbet ayarları (sessiz/arşiv) | Mesajlaşma hizmeti | Sözleşmenin ifası | Hesap açık olduğu sürece; silinen mesajların şifreli kopyası ve düzenleme geçmişi güvenlik amacıyla saklanır (varsayılan süresiz, ayarlanabilir) |
| **Tek gönderimlik fotoğraf:** şifreli dosya, açılma kaydı | Mesajlaşma ve güvenlik incelemesi | Sözleşmenin ifası; meşru menfaat | Alıcı erişimi bir kez / en çok 24 saat; şifreli kopya yönetici incelemesi için **365 gün** (ayarlanabilir) |
| **Topluluk ve etkinlik verileri:** üyelikler, gönderiler, RSVP, yoklama (QR/elle), başvuru yanıtları, etkinlik geri bildirimi | Topluluk ve etkinlik hizmetleri | Sözleşmenin ifası | Hesap açık olduğu sürece; yoklama/gönderi kayıtları anonim biçimde kalabilir |
| **Gönderiler (Keşfet):** metin, fotoğraf, video, beğeniler | Gönderi paylaşımı ve etkileşim | Sözleşmenin ifası | Hesap açık olduğu sürece; gönderi silinince medya dosyası 30 gün sonra diskten silinir; gönderiye bağlanmamış yüklemeler 24 saat sonra silinir. Kulüp gönderisine eklenen görsel, gönderi/kulüp/hesap silinince hemen diskten silinir |
| **Takip ilişkileri ve favori haberler** | Akışınızı oluşturma, içerikleri sonra okumak üzere saklama | Sözleşmenin ifası | Hesap açık olduğu sürece; hesap silinince silinir |
| **Anketler:** katılım kaydı ve oyunuz | Oylama hizmeti | Sözleşmenin ifası | Hesap açık olduğu sürece; hesap silinince katılım kaydı silinir, oy kaydı kimliksizleşir. Gizli ankette oyunuzun hangi seçeneğe verildiği diğer kullanıcılara ve yöneticilere gösterilmez. Bitmiş anketlerin oy kayıtları için ayrı bir otomatik silme süresi uygulanmaz. |
| **Ders programı, ders ve sınav bilgileri:** kendi girdiğiniz dersler, oturumlar, dönem ve sınav kayıtları; duyuru okundu bilgisi | Kişisel ders programı ve sınav takibi | Sözleşmenin ifası | Hesap açık olduğu sürece; hesap silinince silinir |
| **Bildirim kutusu ve tercihler:** bildirim içerikleri, sessiz saatler, tür tercihleri | Bildirim hizmeti | Sözleşmenin ifası | Okunmuş bildirim 30 gün, okunmamış 90 gün sonra silinir; kullanıcı başına en yeni 200 bildirim tutulur |
| **Cihaz bildirim anahtarı (FCM):** anahtar, platform, uygulama sürümü, dil, son görülme | Anlık bildirim göndermek | Sözleşmenin ifası; açık rıza (bildirim izni) | 60 gün görülmeyen anahtar gece temizlenir; çıkışta/hesap silmede silinir |
| **Push bildirim kuyruğu:** hedef kullanıcı/cihaz, bildirim başlığı ve kısa metni, gönderim durumu | Anlık bildirimin kalıcı kuyruktan, yeniden denemeyle gönderilmesi | Sözleşmenin ifası | Bekleyen kayıt en çok 24 saat denenir; gönderilenler 7 gün, başarısız olanlar 30 gün sonra silinir; çıkışta/hesap silmede silinir |
| **Cihaz kimliği ve IP kayıtları:** cihaz tanımlayıcısının geri döndürülemez özeti (HMAC), platform, uygulama sürümü, IP adresi, son görülme ve olay türü (kayıt/giriş/istek) | Güvenlik, kötüye kullanım ve yasaklı kullanıcı engelinin dolanılmasını önleme | Meşru menfaat (m.5/2-f); hukuki yükümlülük (m.5/2-ç) | Varsayılan **90 gün**; engel kayıtları engel sürdükçe (bkz. 6) |
| **Kullanım olayları (analitik):** ekran adı, olay adı, sınırlı özellik değerleri, zaman; son görülme ve günlük aktiflik | Hizmeti iyileştirme, hata/performans takibi; raporlar toplulaştırılmıştır | Meşru menfaat (m.5/2-f) | Ham olaylar **45 gün** (hesap silinince hemen); sonrasında yalnızca kişiye bağlı olmayan, toplulaştırılmış günlük özetler kalır. Günlük aktiflik kaydı (hangi günlerde uygulamayı açtığınız) **400 gün** (hesap silinince hemen) |
| **Destek, geri bildirim, itiraz, rapor:** metinleriniz ve iletişim e-postanız | Taleplerin yanıtlanması, moderasyon | Sözleşmenin ifası; meşru menfaat; hukuki yükümlülük | Hesap silinince metinler temizlenir, kayıt kimliksiz kalır; herkese açık (girişsiz) destek talepleri 365 gün |
| **Uygunsuz ifade filtresi kaydı:** hangi alanda, hangi kullanıcının içeriğinin reddedildiği/işaretlendiği ve zamanı (reddedilen metin kaydedilmez) | Herkese açık alanlarda kötüye kullanımın önlenmesi | Meşru menfaat (m.5/2-f) | 90 gün |
| **Engelleme ve moderasyon kayıtları:** engellediğiniz kişiler, ihlal kayıtları, rapor kararları, yasak izleri | Güvenlik ve moderasyon | Meşru menfaat; hukuki yükümlülük | Moderasyon izi hesap silindikten sonra da kimliksiz tutulur |
| **Yönetici erişim ve işlem kayıtları** (mesaj görüntüleme kaydı dahil) | Hesap verebilirlik, yetkisiz erişimin önlenmesi | Meşru menfaat; hukuki yükümlülük | Yönetici işlem kaydı (IP dahil) 365 gün; mesaj erişim kaydı ve kulüp yönetim işlem kaydı 730 gün (kayıtlar yalnız eklenir, değiştirilemez); süre sonunda silinir |
| **Sözleşme onayları:** belge türü, sürüm, zaman | Rızanın/onayın ispatı | Hukuki yükümlülük; meşru menfaat | Hesap silindikten sonra da saklanır |
| **E-posta kuyruğu:** alıcı, konu, gönderim durumu | Doğrulama/şifre sıfırlama/güvenlik e-postaları ve yönetici duyuruları | Sözleşmenin ifası; duyurularda meşru menfaat | Gönderilen kayıtlar 7 gün, başarısız (gönderilemeyen) kayıtlar 30 gün sonra silinir |
| **Yönetici duyuru e-postaları (kampanya) kayıtları:** kampanya adı ve durumu, alıcı olarak kullanıcı kimliğiniz ve gönderim durumu | Hizmet ve topluluk duyurularının gönderilmesi (reklam/pazarlama değildir; e-postalardaki bağlantıdan abonelikten çıkabilirsiniz). Duyuruda ad, bölüm, fakülte, sınıf gibi profil alanları kişiselleştirme için kullanılabilir | Meşru menfaat (m.5/2-f); sözleşmenin ifası | Kampanya bitiminden 180 gün sonra silinir; hesap silinince alıcı satırınız hemen silinir |
| **Rehber eşleştirme:** rehberinizdeki e-postaların SHA-256 özeti (yalnızca istek sırasında) | Rehberinizde tanıdıklarınızı bulmak | **Açık rıza** (m.5/1) | **Saklanmaz, kaydedilmez**; yalnızca isteğin işlenmesi süresince bellekte |
| **Cihaz konumu** | — | — | Uygulama konum izni **istemez**; cihaz konumu (GPS/ağ) **toplanmaz, sunucuya gönderilmez ve saklanmaz** (bkz. 5) |

> **Özetle:** İşlediğimiz her veri bir amaca bağlıdır; çoğu hesabınız açık olduğu sürece tutulur. Cihaz/IP kayıtları 90 gün, analitik ham olaylar 45 gün, günlük aktiflik kaydı 400 gün, bildirimler okunmuşsa 30/okunmamışsa 90 gün, e-posta kuyruğu 7 gün (başarısızsa 30 gün), duyuru kampanyası kayıtları 180 gün saklanır.

## 3. Mesajlarınız nasıl saklanır ve kim görebilir?

1. **İletim:** Mesajlar TLS/WSS ile şifreli iletilir.
2. **Saklama:** Sunucuda her sohbet için ayrı bir anahtarla AES-256-GCM ile şifreli saklanır. Anahtarlar ayrı bir ana anahtar ile korunur ve veritabanında değil sunucu ortamında tutulur. Bu, veritabanı yedeği ele geçirilse bile mesajların okunmasını zorlaştırır.
3. **Uçtan uca şifreleme DEĞİLDİR.** Ana anahtar bizde olduğundan, sistem mesajları çözebilir. Bunu bilerek kullanın.
4. **Yönetici erişimi:** Yalnızca yetkili yöneticiler; şikâyet incelemesi, güvenlik/kötüye kullanım, yasal talepler ve benzeri gerekçelerle, mesajların ve medyanın içeriğini görüntüleyebilir. Yönetici arayüzü; silinmiş, düzenlenmiş ve moderasyonla gizlenmiş mesajlar ile "tek gönderimlik" fotoğrafları ve engellenen kullanıcıya iletilmeyen mesajları da gösterebilir. **Her görüntüleme**, içerik gösterilmeden önce otomatik olarak değiştirilemez bir kayda yazılır: kim baktı, kimin sohbetine baktı, kaç mesaj, hangi IP'den, ne zaman. Kayıt yazılamazsa içerik gösterilmez.
5. **Silinen mesajlar:** "Herkes için sil" diğer kullanıcılar için mesajı gizler; mesajın şifreli kopyası ve eski sürümleri güvenlik incelemesi için saklanabilir. Saklama süresi işletici tarafından ayarlanır (varsayılan: süresiz).
6. **Tek gönderimlik fotoğraflar:** Alıcı bir kez görür, sonra erişimi kapanır; ancak yönetici incelemesi için şifreli dosya 365 gün (ayarlanabilir) saklanır ve sonra silinir. Ekran görüntüsünün engellenmesi için teknik önlemler olsa da mutlak garanti verilmez.
7. **Bildirim önizlemesi:** Varsayılan olarak anlık bildirimde mesaj metni gösterilmez (ayar açılırsa metin Google FCM/Apple APNs üzerinden geçer). Uygulama içi bildirim kutusuna mesaj içeriği hiçbir zaman yazılmaz.
8. **Fotoğraf ve video işleme:** Fotoğraflar türü/boyutu doğrulanıp yeniden kodlanır, EXIF (konum vb.) temizlenir. **Sohbet videoları** cihazınızda sıkıştırılır; sunucu bunları yeniden kodlamaz, sohbete özgü anahtarla şifreli saklanır. **Gönderi (Keşfet) videoları** yüklendikten sonra sunucuda yeniden kodlanır (H.264 video, en çok 720p yükseklik, AAC ses; GPS gibi meta veriler atılır) ve diskte dosya başına rastgele üretilen bir anahtarla şifreli saklanır; bu anahtar da ana anahtarla sarılarak veritabanında tutulur. Yeniden kodlama bitene kadar yüklediğiniz özgün (şifreli) dosya oynatılabilir, bitince özgün dosya silinir. Görsellerin özeti, yasaklı içerik özet listesiyle karşılaştırılır; görsel içeriği otomatik analiz edilmez.
9. **Engelleme:** Engellediğiniz kişinin size yazdığı mesajlar size iletilmez; engellenen kişiye bildirim yapılmaz. Bu mesajlar sistemde kalır ve yalnızca yetkili yöneticilerce, şikâyet incelemesi gibi gerekçelerle görülebilir.

> **Özetle:** Mesajlar şifreli saklanır ama uçtan uca değil. Yetkili yöneticiler yalnızca gerekçeli durumda, her seferinde kayda alınarak görüntüleyebilir. Silinen mesajlar ve tek gönderimlik fotoğrafların şifreli kopyası güvenlik için bir süre saklanabilir.

## 4. Verilerinizi kimlerle paylaşırız?

| Alıcı | Ne paylaşılır? | Amaç | Konum |
|---|---|---|---|
| **Google Firebase Cloud Messaging (FCM)** (ve iOS için Apple APNs) | Cihaz bildirim anahtarı, bildirim başlığı/kısa metni, hedef bilgisi | Anlık bildirim iletimi | Yurt dışı (Google/Apple altyapısı); bkz. KVKK Aydınlatma Metni |
| **E-posta gönderim hizmeti sağlayıcısı: Brevo (SMTP)** (veri işleyen) | Alıcı e-posta adresi, e-posta içeriği (doğrulama kodu, duyuru metni; duyurularda kişiselleştirme için ad ve bölüm/fakülte/sınıf bilgisi) | Doğrulama, şifre sıfırlama, güvenlik e-postaları ve yönetici duyuruları | Yurt dışı olabilir (sağlayıcının sunucuları Avrupa'da veya başka ülkelerde bulunabilir); bkz. KVKK Aydınlatma Metni |
| **Barındırma / sunucu sağlayıcısı** | Tüm hizmet verisi (şifreli mesajlar dahil) | Hizmetin barındırılması | {{hosting.location|Barındırma konumu yayın öncesi belirtilir}} |
| **Yetkili kamu kurumları** (mahkeme, savcılık, kolluk, KVKK Kurulu vb.) | Talep kapsamındaki veri | Hukuki yükümlülük | Yurt içi |
| **Üniversite yönetimi / yetkili yöneticiler** | Moderasyon ve destek için gerekli veri | Hizmetin yönetimi, güvenlik | Yurt içi |

Reklam ağları, veri komisyoncuları veya sosyal medya takip araçlarıyla veri paylaşmayız.

## 5. İzinler ve isteğe bağlı özellikler

1. **Bildirim izni:** İsterseniz anlık bildirim alırsınız. Reddederseniz uygulama içi bildirim kutusu çalışmaya devam eder. Bildirim türlerini ve **sessiz saatleri** ayarlardan yönetirsiniz.
2. **Rehber eşleştirme:** Rehber erişimi izni verirseniz, tanıdıklarınızı bulmak için rehberinizdeki e-posta adreslerinin **yalnızca SHA-256 özeti** (en çok 500 adet / istek) sunucuya gönderilir. Özetler **saklanmaz ve kayda geçirilmez**; yalnızca eşleşen kullanıcılar (gizlilik ayarlarına saygı gösterilerek) cevap olarak size döner. Rehber isimleriniz, telefon numaralarınız sunucuya gönderilmez. Kötüye kullanım için saatlik istek sınırı vardır.
3. **Konum:** Uygulama cihazınızdan konum (GPS/ağ tabanlı) **izni istemez**; konumunuzu toplamaz, sunucuya göndermez ve saklamaz. Güvenlik amacıyla kaydedilen IP adresi (bkz. 6) cihaz konumu değildir; uygulama kodunda IP adresinden konum veya bölge çıkarımı yapılmaz. Barındırma ve ağ altyapısı sağlayıcıları kendi teknik kayıtlarını kendi politikalarına göre tutabilir; bu kayıtlar tarafımızca konum belirlemek için kullanılmaz. Gelecekte konum işlenecekse bu metin güncellenir ve yeniden açık rızanız alınır.
4. İzinleri istediğiniz an cihaz ayarlarından veya uygulamadaki İzinler ekranından geri alabilirsiniz. Geri alma, geri alma anından önceki işlemlerin hukuka uygunluğunu etkilemez.

## 6. Cihaz ve IP kayıtları, erişim engelleri

1. Güvenlik amacıyla; kayıt, giriş, oturum yenileme ve istekler sırasında cihaz tanımlayıcınızın geri döndürülemez özeti, platform, uygulama sürümü, IP adresi ve zaman bilgisi kaydedilir. Ham cihaz tanımlayıcısı saklanmaz.
2. Bu kayıtlar varsayılan **90 gün** saklanır ve gecelik olarak temizlenir. Süre işletici tarafından ayarlanabilir; yasal bir saklama yükümlülüğü doğarsa (ör. 5651 sayılı Kanun kapsamında trafik bilgisi) süre buna göre belirlenebilir ve bu politika güncellenir.
3. Kötüye kullanım nedeniyle yasaklanan bir kullanıcının IP adresi, ağ aralığı, cihaz özeti veya kullanıcı kimliği için **erişim engeli** tanımlanabilir. Engel kaydı (neden kodu, tarih, varsa süre ve notlar) engel sürdükçe ve itiraz/denetim için gerekli süre boyunca saklanır. Engele takılan denemeler (IP, cihaz özeti, istek yolu, zaman) güvenlik kaydı olarak tutulur ve cihaz/IP kayıtlarıyla aynı temizleme ilkesine tabidir. VPN/Tor/veri merkezi gibi anonimleştirici aralıklardan gelen istekler güvenlik amacıyla kısıtlanabilir.
4. Engellendiğinizi düşünüyorsanız Destek bölümünden veya itiraz özelliğinden başvurabilirsiniz.

## 7. Hesap silme ve veri taşınabilirliği

**Verilerimi indir:** Profil > Verilerimi indir ile kendi verilerinizi (günde 3 kez sınırla) JSON olarak indirebilirsiniz. Çıktı; profil ve gizlilik ayarlarınızı, onay kayıtlarınızı, mesajlarınızı ve sohbet üyeliklerinizi, gönderi ve beğenilerinizi, takiplerinizi, favori haberlerinizi, topluluk üyeliklerinizi ve gönderilerinizi, etkinlik katılım, başvuru ve yoklama kayıtlarınızı, oluşturduğunuz etkinlikleri, size gelen duyuru e-postası kampanyalarını, bildirimlerinizi ve cihaz kayıtlarınızı, destek taleplerinizi ve cihaz/IP geçmişinizi içerir. Silinmiş mesajlar çıktıya dahil değildir. Bir bölüm geçici olarak hazırlanamazsa o bölümde hata işareti görünür, diğer bölümler yine verilir.

**Hesap silme = anonimleştirme.** Hesabınızı sildiğinizde:

| Ne olur? | Hangi veriler |
|---|---|
| **Silinir** | Bildirim cihaz anahtarlarınız ve bekleyen push kayıtlarınız, bildirim kutunuz ve tercihleriniz, takip ilişkileriniz, ders programı ve sınav kayıtlarınız, anket katılım kaydınız, beğenileriniz, Keşfet gönderileriniz (medya dosyaları 30 gün sonra diskten kalkar), favori haberleriniz, geri bildirim oylarınız, etkinlik geri bildirimleriniz, engelleme listeniz, kulüp başvuru yanıtlarınız, topluluk üyelikleriniz, duyuru e-postası kampanyalarındaki alıcı satırlarınız, yüklediğiniz sohbet fotoğrafları, **cihaz/IP kayıtlarınız, analitik olaylarınız ve günlük aktiflik kaydınız (hemen)**, kulüp gönderilerine eklediğiniz görseller (hemen, diskten). Etkinlik başvurularınız kapatılır (bekleme listesindeki sıradaki kişi yer alır) ve oluşturduğunuz, kulübe bağlı olmayan bitmemiş etkinlikler iptal edilir. **Kulüp sahibiyseniz:** sahiplik kulübün en eski aktif yöneticisine (yoksa moderatörüne) devredilir; devralacak kimse yoksa kulüp kapatılır ve üyelerine bildirilir |
| **Anonimleştirilir** | Ad, e-posta, profil bilgileri, biyografi, fotoğraf; anket oy kayıtları (kullanıcı bağlantısı koparılır); destek, geri bildirim, itiraz, rapor ve etkinlik başvurusu metinleri temizlenir (kayıt kimliksiz kalır) |
| **Korunur (sınırlı)** | Gönderdiğiniz mesajlar ve topluluk gönderileri (başkalarının sohbet bağlamının parçası; yazar "Silinmiş kullanıcı" gibi anonim görünür); sözleşme onay kayıtları (hukuki kanıt); moderasyon ihlal/rapor ve yasak izleri; anonim yoklama/RSVP sayaçları; yönetici işlem ve erişim kayıtları |
| **Süreyle temizlenir** | Cihaz/IP kayıtları (90 gün), uygunsuz ifade filtresi kaydı (90 gün), analitik ham olaylar (45 gün), günlük aktiflik kaydı (400 gün), e-posta kuyruğu (gönderilen 7 gün, başarısız 30 gün), duyuru kampanyası kayıtları (180 gün), yönetici işlem kaydı (365 gün), mesaj erişim ve kulüp işlem kaydı (730 gün) |

> **Özetle:** Hesabınızı silince kimliğiniz çıkar, kişisel veriniz silinir veya anonimleşir. Başkalarının haklarını ve yasal delil/güvenlik ihtiyacını korumak için bazı kayıtlar kimliksiz ve sınırlı olarak kalır.

## 8. Güvenlik önlemleri

1. Şifreler tek yönlü özet olarak saklanır; doğrulama kodları ve yenileme anahtarları özet olarak tutulur.
2. Erişim anahtarı 15 dakikalıdır; yenileme anahtarı tek kullanımlıktır; şifre değişiminde tüm oturumlar kapanır.
3. Giriş, kayıt, doğrulama ve yazma işlemlerinde hız sınırı uygulanır; kullanıcı varlığını sızdırmayan genel yanıtlar verilir.
4. Mesajlar şifreli saklanır; yönetici erişimi kayıt altındadır; yönetim paneli yalnızca yönetici rolüyle çalışır.
5. Yüklenen dosyalar tür/boyut doğrulanır, dosya adları sunucuda üretilir.
6. Hiçbir sistem mutlak güvenli değildir. Bir veri ihlali olursa mevzuata uygun şekilde Kurul'a ve etkilenen kişilere bildirim yaparız.

## 9. Çerezler ve yerel depolama

Web sitesinde **izleme/reklam çerezi kullanılmaz**. Yalnızca dil/tema tercihiniz ve oturum bilgisi gibi zorunlu yerel depolama kullanılır. Ayrıntı için [Çerez ve Yerel Depolama Politikası](/legal/cookies).

## 10. Çocukların verileri

Hizmet 18 yaşından küçükler için tasarlanmamıştır; yalnızca üniversite öğrenci/personel e-postasıyla kayıt olunur. 18 yaşından küçük bir kullanıcının kaydı tespit edilirse yasal temsilcinin bilgisi ve onayı aranabilir; gerekirse hesap kapatılır ve veriler silinir/anonimleştirilir.

## 11. Haklarınız

KVKK m.11 uyarınca verilerinize erişme, düzeltme, silme, itiraz ve diğer haklarınız vardır. Başvuru yolları ve 30 gün yanıt süresi [KVKK Aydınlatma Metni](/legal/kvkk) ve [Saklama ve İmha](/legal/retention) metinlerindedir. Hızlı yollar: Profil bilgilerini düzenleme, gizlilik ayarları, Verilerimi indir, Hesabı sil, Destek bölümü.

## 12. Değişiklikler

Bu politikayı güncelleyebiliriz. Önemli değişikliklerde sizden yeniden onay alırız; güncel sürüm ve geçmiş bu sayfada yer alır.

## 13. Gönderiler ve içerik denetimi

1. **Kimler görür?** Gönderiler uygulamaya giriş yapmış diğer kullanıcılara gösterilir; engellediğiniz veya sizi engelleyen kullanıcılarla karşılıklı görünürlük kapanır. Uygulamada sunulan görünürlük seçenekleri ilgili ekranda gösterilir.
2. **Kulüp gönderisi görselleri.** Kulüp gönderisine eklediğiniz görsel, gönderiyi sildiğinizde, kulüp kapandığında veya hesabınızı sildiğinizde bağlantısı kaldırılır ve dosya diskten silinir.
3. **Uygunsuz ifade filtresi.** Topluluk, etkinlik, profil ve gönderi gibi herkese açık alanlarda küfür, hakaret ve benzeri ifadeler otomatik olarak reddedilebilir. **Sohbet mesajları (birebir ve grup) ön denetimden geçirilmez.** Filtre yalnızca kayıt anında çalışır; hangi alanın, hangi kullanıcının içeriğinin reddedildiği 90 gün saklanır, reddedilen metin kaydedilmez. Reddedilen içerik yayımlanmaz; karar insan incelemesi olmadan otomatik verilir ve itirazınızı Destek bölümünden iletebilirsiniz.
4. **Şikâyet ve kaldırma.** Gönderi ve mesajlar **Bildir** ile şikâyet edilebilir; yetkili yöneticiler inceler, içeriği gizleyebilir veya kaldırabilir. Usul için [İçerik Bildirimi ve Kaldırma](/legal/content-removal) ve [Topluluk Kuralları](/legal/community-rules) metinlerine bakın.

## 14. İletişim

{{support.email|Uygulama içi Destek bölümü}}{{?controller.email}} · {{controller.email}}{{/controller.email}}{{?controller.kep}} · KEP: {{controller.kep}}{{/controller.kep}}$c_privacy_tr$, FALSE, TRUE),
    ('PRIVACY', 'en', v, $t_privacy_en$Privacy Policy$t_privacy_en$, $c_privacy_en$*This English text is provided for information only. The Turkish text is authoritative.*

This policy explains which of your data is processed, why, for how long, and your rights. Read it together with the [KVKK Notice](/legal/kvkk).

Controller: {{controller.name}}{{?controller.address}}, {{controller.address}}{{/controller.address}}. Contact: {{controller.email|in-app Support section}}.

## 1. In short

1. We do **not sell** your data or share it for advertising.
2. We process only what is needed to provide the service, keep it secure and meet legal obligations.
3. Optional permissions (contacts, push notifications) rely on your **explicit consent** and can be withdrawn at any time ([Explicit Consent](/legal/explicit-consent)). The app does **not ask for, collect or store your device location**.
4. Messages are stored encrypted but the system is **not end-to-end encrypted**; authorised administrators may view them for stated reasons, with every access logged.
5. Deleting your account anonymises your data; some records remain in limited form for legal reasons and to protect others.

## 2. Data we process

| Data | Why | Legal basis | Retention |
|---|---|---|---|
| **Account:** e-mail (bingol.edu.tr), name, password (one-way hash only), language | Membership, authentication | Contract (KVKK 5/2-c) | While the account is open; anonymised on deletion |
| **Profile:** faculty, department, year, bio, avatar, privacy settings | Showing your profile (field-level visibility) | Contract; explicit consent for optional fields | While the account is open |
| **Pending registration / code:** e-mail, code digest | E-mail verification | Contract | Pending registration 1 hour; code 10 minutes |
| **Session:** refresh token digest | Secure sessions | Legitimate interest | At most 30 days; removed on logout/password change |
| **Messages:** text, photos, videos, edit history, reactions, read state, chat settings | Messaging | Contract | While the account is open; encrypted copies of deleted messages and edit history kept for security (default indefinite, configurable) |
| **View-once photo:** encrypted file, open record | Messaging; security review | Contract; legitimate interest | Recipient access once / max 24 h; encrypted copy for admin review **365 days** (configurable) |
| **Community and event data:** memberships, posts, RSVP, attendance, application answers | Community and event features | Contract | While the account is open; some records stay anonymous |
| **Posts (Discover):** text, photos, videos, likes | Posting and interaction | Contract | While the account is open; after a post is deleted its media files are removed from disk after 30 days; uploads not attached to a post are deleted after 24 hours. An image attached to a club post is deleted from disk at once when the post, the club or the account is deleted |
| **Follows and bookmarked news** | Building your feed, saving items for later | Contract | While the account is open; deleted with the account |
| **Polls:** participation record and your vote | Voting | Contract | While the account is open; on account deletion the participation record is deleted and the vote is detached from you. In a secret poll, which option you chose is not shown to other users or administrators. No separate automatic deletion period applies to the vote records of finished polls. |
| **Timetable, course and exam data:** courses, sessions, semester and exams you enter yourself; announcement read marks | Personal timetable and exam tracking | Contract | While the account is open; deleted with the account |
| **Notification inbox and preferences** | Notifications | Contract | Read 30 days, unread 90 days; the newest 200 notifications per user are kept |
| **Device push token (FCM):** token, platform, app version, language, last seen | Push notifications | Contract; explicit consent (notification permission) | Removed after 60 days unseen; on logout/deletion |
| **Push notification queue:** target user/device, title and short text, delivery status | Delivering push notifications from a durable queue with retries | Contract | Pending entries are retried for at most 24 hours; sent entries are deleted after 7 days, failed ones after 30 days; deleted on logout/account deletion |
| **Inappropriate-language filter log:** which field, which user's content was rejected/flagged, and when (the rejected text is not stored) | Preventing abuse in public areas | Legitimate interest | 90 days |
| **Device and IP records:** non-reversible HMAC digest of device identifier, platform, app version, IP, last seen and event type | Security, abuse prevention, ban evasion | Legitimate interest; legal obligation | Default **90 days**; ban records while a ban lasts |
| **Usage events (analytics):** screen, event name, limited values, time | Improving the service; reports are aggregated | Legitimate interest | Raw events **45 days** (immediately on account deletion); afterwards only non-personal, aggregated daily summaries remain. Daily activity record (which days you opened the app) **400 days** (immediately on account deletion) |
| **Support, feedback, appeals, reports** | Handling requests, moderation | Contract; legitimate interest; legal obligation | Texts scrubbed on account deletion; public (logged-out) tickets 365 days |
| **Blocks and moderation records** | Safety and moderation | Legitimate interest; legal obligation | Moderation trail kept anonymously |
| **Administrator action and message-access logs** | Accountability | Legitimate interest; legal obligation | Administrator action log (including IP) 365 days; message-access log and club administration action log 730 days (entries are append-only and cannot be altered); deleted when the period ends |
| **Agreement acceptances:** document, version, time | Proof of acceptance | Legal obligation; legitimate interest | Kept after account deletion |
| **E-mail queue:** recipient, subject, status | Verification, reset and security e-mails and administrator announcements | Contract; legitimate interest for announcements | Sent entries deleted after 7 days, failed (undeliverable) entries after 30 days |
| **Administrator announcement e-mail (campaign) records:** campaign name and status, your user ID as recipient and delivery status | Sending service and community announcements (not advertising or marketing; every e-mail has an unsubscribe link). Profile fields such as name, department, faculty and year may be used to personalise the message | Legitimate interest (Art. 5/2-f); contract | Deleted 180 days after the campaign ends; your recipient row is deleted at once when you delete your account |
| **Contact matching:** SHA-256 digests of e-mails in your address book | Finding people you know | **Explicit consent** | **Not stored or logged**; in memory only while the request is processed |
| **Device location** | — | — | The app does **not ask for location permission**; device location (GPS/network) is **not collected, sent or stored** (see 5) |

> **In short:** Device/IP records 90 days, raw analytics events 45 days, daily activity record 400 days, notifications 30 days (read) / 90 days (unread), e-mail queue 7 days (30 if failed), announcement campaign records 180 days.

## 3. How messages are stored and who can see them

1. Transit: TLS/WSS. Storage: AES-256-GCM with a separate key per conversation, protected by a master key held in the server environment, not in the database.
2. **Not end-to-end encrypted.** Because we hold the master key, the system can decrypt messages.
3. Authorised administrators may view messages and media for report reviews, security/abuse, and legal requests. The admin view can also show deleted, edited and moderation-hidden messages, view-once photos and messages not delivered because of a block. **Every view is automatically written to a tamper-resistant record before content is shown** (who, whose chat, how many messages, IP, time); if logging fails, content is not shown.
4. "Delete for everyone" hides the message from users; the encrypted copy and previous versions may be retained for security (default indefinite).
5. View-once photos: recipient sees once; the encrypted file is kept 365 days (configurable) for administrator review, then deleted. No absolute guarantee against screenshots.
6. Push previews: by default message text is not shown in push notifications; the in-app inbox never stores message content.
7. Photos are validated and re-encoded, EXIF removed; chat videos are compressed on your device and are not re-encoded by the server (they are stored encrypted with a per-conversation key). Post (Discover) videos are re-encoded on the server after upload (H.264, at most 720p, AAC audio, metadata such as GPS removed) and stored on disk encrypted with a random per-file key that is itself wrapped by the master key; until re-encoding finishes the encrypted original stays playable and is then deleted. Image digests are matched against a prohibited-content digest list; images are not analysed automatically.
8. Blocking: messages from someone you blocked are not delivered to you and the blocked person is not notified; they remain stored and visible to authorised administrators during report reviews.

## 4. Who we share data with

| Recipient | What | Purpose | Location |
|---|---|---|---|
| **Google Firebase Cloud Messaging** (and Apple APNs for iOS) | Device push token, notification title/short text, target | Push delivery | Outside Türkiye |
| **E-mail delivery service provider: Brevo (SMTP)** (processor) | Recipient address, e-mail content (verification code, announcement text; for announcements, name and department/faculty/year for personalisation) | Verification, reset, security e-mails and administrator announcements | May be outside Türkiye (the provider's servers may be in Europe or other countries); see the KVKK Notice |
| **Hosting provider** | All service data (messages encrypted) | Hosting | {{hosting.location|Stated before publication}} |
| **Competent public authorities** | Data within the request | Legal obligation | Türkiye |
| **University / authorised administrators** | Data needed for moderation and support | Service administration | Türkiye |

We do not share data with ad networks, data brokers or social-media trackers.

## 5. Permissions

1. **Notifications:** optional; notification types and **quiet hours** are configurable. Without permission, the in-app inbox still works.
2. **Contact matching:** only SHA-256 digests of e-mails (up to 500 per request) are sent; they are **not stored or logged**; names and phone numbers are never sent.
3. **Location:** the app does **not ask for location permission** and does not collect, send or store your location. The IP address recorded for security (see 6) is not device location, and the application code does not infer location or region from IP addresses. Hosting and network infrastructure providers may keep their own technical logs under their own policies; we do not use them to determine location. If location is ever processed we will update this text and ask for consent again.

## 6. Device/IP records and access bans

Device-identifier digest, platform, app version, IP and time are recorded on registration, login, refresh and requests for security. The raw identifier is not stored. Records are kept **90 days** by default (configurable); if a legal retention duty arises (e.g. Law No. 5651 traffic data) the period may change and this policy will be updated. Access bans (IP, network range, device digest or user) keep reason code, date, optional expiry and notes while the ban lasts; blocked attempts are logged as security records. Requests from anonymising networks may be restricted. You may contest a ban via Support or the appeal feature.

## 7. Account deletion and data export

**Download my data:** Profile > Download my data (JSON, up to 3 per day; deleted messages excluded). The file covers your profile and privacy settings, consent records, messages and chat memberships, posts and likes, follows, bookmarked news, community memberships and posts, event attendance, application and check-in records, events you created, announcement e-mail campaigns you received, notifications and device records, support requests and your device/IP history. If a section cannot be prepared temporarily, an error marker appears in that section and the others are still delivered.

**Account deletion = anonymisation**

| What happens | Data |
|---|---|
| **Deleted** | Push tokens and pending push entries, notification inbox and preferences, follows, timetable and exam data, poll participation record, likes, Discover posts (media files removed after 30 days), bookmarks, feedback votes and event feedback, block list, club application answers, community memberships, your rows in announcement e-mail campaigns, chat photos you uploaded, **your device/IP records, analytics events and daily activity record (immediately)**, images you attached to club posts (immediately, from disk). Your event applications are closed (the next person on the waiting list moves up) and unfinished events you created that are not tied to a club are cancelled. **If you own a club:** ownership passes to its longest-standing active administrator (or moderator); if nobody can take over, the club is closed and its members are notified |
| **Anonymised** | Name, e-mail, profile, bio, photo; poll vote records (link to you removed); support, feedback, appeal, report and event application texts are scrubbed |
| **Kept (limited)** | Messages and community posts (others' context; author appears anonymous), agreement acceptances, moderation records, anonymous attendance/RSVP counters, administrator action and access logs |
| **Cleaned by time** | Device/IP records (90 days), language-filter log (90 days), raw analytics events (45 days), daily activity record (400 days), e-mail queue (sent 7 days, failed 30 days), announcement campaign records (180 days), administrator action log (365 days), message-access and club action logs (730 days) |

## 8. Security

One-way password hashes; digests of codes and refresh tokens; 15-minute access tokens; single-use refresh tokens; rate limits; generic responses that do not reveal whether an account exists; encrypted message storage; logged administrator access; validated uploads. No system is perfectly secure; in a breach we notify the Board and affected persons as required.

## 9. Cookies and local storage

No tracking or advertising cookies. See the [Cookie Policy](/legal/cookies).

## 10. Children

The service is not designed for persons under 18; if such a registration is found we may require a legal representative's consent or close the account.

## 11. Posts and content moderation

1. Posts are shown to other signed-in users; visibility is mutually closed with users you block or who block you. Any visibility options offered in the app are shown on the relevant screen.
2. **Club post images.** An image attached to a club post is unlinked and deleted from disk when you delete the post, when the club is closed or when you delete your account.
3. **Language filter.** Insults, abuse, hate speech or sexually explicit expressions in public areas (communities, events, profiles, group titles, posts) may be rejected automatically. **Chat messages (one-to-one and group) are not pre-screened.** The filter acts at submission time; which field and which user's content was rejected is kept for 90 days, the rejected text is not stored. The decision is automatic without human review; you may contest it through Support.
4. **Reports and removal.** Posts and messages can be reported with **Report**; authorised administrators review and may hide or remove content. See [Content Notice and Removal](/legal/content-removal) and the [Community Rules](/legal/community-rules).

## 12. Your rights, changes, contact

Your KVKK Article 11 rights and the application route (30-day response) are in the [KVKK Notice](/legal/kvkk). We may update this policy; for material changes we ask for re-acceptance. Contact: {{support.email|in-app Support section}}{{?controller.email}} · {{controller.email}}{{/controller.email}}{{?controller.kep}} · KEP: {{controller.kep}}{{/controller.kep}}$c_privacy_en$, FALSE, TRUE),
    ('PRIVACY', 'ar', v, $t_privacy_ar$سياسة الخصوصية$t_privacy_ar$, $c_privacy_ar$*هذا النص العربي ترجمة للاطلاع فقط؛ النص التركي هو المرجع الملزم عند أي اختلاف.*

توضح هذه السياسة بلغة بسيطة أي بياناتك تُعالَج عند استخدام تطبيق «BÜ Kampüs» (جامعة بينغول) وموقعه الإلكتروني، ولماذا تُعالَج، وكم من الوقت تُحفَظ، وما هي حقوقك. للاطلاع على الإطار القانوني وإجراءات التقدّم بالطلبات، اقرأها مع [نص الإفصاح وفق قانون حماية البيانات الشخصية (KVKK)](/legal/kvkk).

المسؤول عن البيانات: {{controller.name}}{{?controller.address}}، {{controller.address}}{{/controller.address}}. وسيلة التواصل: {{controller.email|قسم الدعم داخل التطبيق}}.

## 1. باختصار

1. **لا نبيع** بياناتك، ولا نشاركها مع أطراف ثالثة لأغراض إعلانية.
2. لا نعالج إلا البيانات اللازمة لتقديم الخدمة وضمان الأمن والوفاء بالالتزامات القانونية.
3. الأذونات الاختيارية مثل مطابقة دفتر العناوين والإشعارات الفورية تعتمد على **موافقتك الصريحة**، ويمكن سحبها في أي وقت ([نص الموافقة الصريحة](/legal/explicit-consent)). لا يطلب التطبيق **موقع جهازك ولا يجمعه ولا يخزّنه**.
4. تُخزَّن رسائلك على الخادم مشفّرة؛ غير أن النظام **غير مشفّر من طرف إلى طرف**، ويمكن للمسؤولين المخوَّلين الاطلاع على الرسائل في حالات مسبَّبة، مع تسجيل ذلك.
5. إذا حذفت حسابك فإن بياناتك الشخصية تُجهَّل هويتها؛ وتبقى بعض السجلات بشكل محدود لأسباب قانونية ولحماية حقوق الآخرين.

## 2. ما البيانات التي نعالجها؟

| البيانات | السبب | السند القانوني | مدة الحفظ |
|---|---|---|---|
| **الحساب:** البريد الإلكتروني (bingol.edu.tr)، الاسم واللقب، كلمة المرور (كملخّص أحادي الاتجاه فقط)، تفضيل اللغة | العضوية، والتحقق من الهوية، وتقديم الخدمة | تنفيذ العقد (KVKK م.5/2-ج) | ما دام الحساب مفتوحًا؛ وتُجهَّل هويتها عند الحذف |
| **الملف الشخصي:** الكلية، القسم، الصف، النبذة التعريفية، صورة الملف الشخصي، إعدادات الخصوصية الخاصة بك | عرض ملفك الشخصي للمستخدمين الآخرين (يمكن إخفاؤه حسب الحقل) | تنفيذ العقد؛ وفي الحقول الاختيارية الموافقة الصريحة (م.5/1) | طوال مدة بقاء الحساب مفتوحًا |
| **الحساب الجاري تسجيله ورمز التحقق:** البريد الإلكتروني، ملخّص الرمز | التحقق من البريد الإلكتروني | إجراء سابق للعقد / تنفيذ العقد | التسجيل المعلّق ساعة واحدة؛ ورمز التحقق 10 دقائق |
| **الجلسة:** ملخّص مفتاح التجديد، حالة الجلسة | إدارة آمنة للجلسات | المصلحة المشروعة (م.5/2-و) | مفتاح التجديد 30 يومًا كحد أقصى؛ ويُحذف عند تسجيل الخروج / تغيير كلمة المرور |
| **الرسائل:** النص، الصور، الفيديو، سجل التعديل، التفاعلات، معلومة القراءة، إعدادات المحادثة (كتم/أرشفة) | خدمة المراسلة | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وتُحفَظ النسخة المشفّرة للرسائل المحذوفة وسجل التعديل لأغراض أمنية (الافتراضي غير محدد المدة، وقابل للضبط) |
| **الصورة ذات الإرسال الواحد:** الملف المشفّر، سجل الفتح | المراسلة والمراجعة الأمنية | تنفيذ العقد؛ المصلحة المشروعة | وصول المستلم مرة واحدة / 24 ساعة كحد أقصى؛ والنسخة المشفّرة لمراجعة المسؤول **365 يومًا** (قابلة للضبط) |
| **بيانات المجتمعات والفعاليات:** العضويات، المنشورات، تأكيد الحضور (RSVP)، تسجيل الحضور (QR/يدويًا)، ردود طلبات الانضمام، تقييمات الفعاليات | خدمات المجتمعات والفعاليات | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وقد تبقى سجلات الحضور/المنشورات مجهولة الهوية |
| **المنشورات (اكتشف):** النص، الصور، الفيديو، الإعجابات | نشر المحتوى والتفاعل | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وعند حذف المنشور يُحذف ملف الوسائط من القرص بعد 30 يومًا؛ وتُحذف الملفات المرفوعة غير المرتبطة بمنشور بعد 24 ساعة. وتُحذف الصورة المرفقة بمنشور نادٍ من القرص فورًا عند حذف المنشور أو النادي أو الحساب |
| **علاقات المتابعة والأخبار المفضلة** | تكوين خلاصتك، وحفظ المحتوى لقراءته لاحقًا | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وتُحذف عند حذف الحساب |
| **الاستطلاعات:** سجل المشاركة وصوتك | خدمة التصويت | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وعند حذف الحساب يُحذف سجل المشاركة ويصبح سجل الصوت مجهول الهوية. في الاستطلاع السري لا يُعرَض للمستخدمين الآخرين ولا للمسؤولين الخيار الذي صوّتَّ له. لا تُطبَّق مدة حذف تلقائي منفصلة على سجلات أصوات الاستطلاعات المنتهية. |
| **الجدول الدراسي ومعلومات المقررات والامتحانات:** المقررات والحصص وسجلات الفصل والامتحانات التي أدخلتها بنفسك؛ معلومة قراءة الإعلانات | متابعة الجدول الدراسي والامتحانات الشخصية | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وتُحذف عند حذف الحساب |
| **صندوق الإشعارات والتفضيلات:** محتوى الإشعارات، ساعات الصمت، تفضيلات الأنواع | خدمة الإشعارات | تنفيذ العقد | تُحذف الإشعارات المقروءة بعد 30 يومًا وغير المقروءة بعد 90 يومًا؛ ويُحتفَظ بأحدث 200 إشعار لكل مستخدم |
| **مفتاح إشعارات الجهاز (FCM):** المفتاح، المنصة، إصدار التطبيق، اللغة، آخر ظهور | إرسال الإشعارات الفورية | تنفيذ العقد؛ الموافقة الصريحة (إذن الإشعارات) | المفتاح الذي لم يُرَ منذ 60 يومًا يُنظَّف ليلًا؛ ويُحذف عند تسجيل الخروج/حذف الحساب |
| **طابور الإشعارات الفورية (push):** المستخدم/الجهاز المستهدف، عنوان الإشعار ونصه القصير، حالة الإرسال | إرسال الإشعار الفوري من طابور دائم مع إعادة المحاولة | تنفيذ العقد | يُحاوَل السجل المعلّق 24 ساعة كحد أقصى؛ وتُحذف المرسَلة بعد 7 أيام والفاشلة بعد 30 يومًا؛ وتُحذف عند تسجيل الخروج/حذف الحساب |
| **معرّف الجهاز وسجلات IP:** ملخّص غير قابل للعكس لمعرّف الجهاز (HMAC)، المنصة، إصدار التطبيق، عنوان IP، آخر ظهور ونوع الحدث (تسجيل/دخول/طلب) | الأمن، ومنع إساءة الاستخدام، ومنع الالتفاف على حظر المستخدمين المحظورين | المصلحة المشروعة (م.5/2-و)؛ الالتزام القانوني (م.5/2-ç) | الافتراضي **90 يومًا**؛ وسجلات الحظر ما دام الحظر قائمًا (انظر 6) |
| **أحداث الاستخدام (التحليلات):** اسم الشاشة، اسم الحدث، قيم خصائص محدودة، الوقت؛ آخر ظهور والنشاط اليومي | تحسين الخدمة، ومتابعة الأخطاء والأداء؛ والتقارير مجمَّعة | المصلحة المشروعة (م.5/2-و) | الأحداث الخام **45 يومًا** (فورًا عند حذف الحساب)؛ وبعدها تبقى فقط ملخصات يومية مجمّعة غير مرتبطة بالأشخاص. وسجل النشاط اليومي (الأيام التي فتحت فيها التطبيق) **400 يوم** (فورًا عند حذف الحساب) |
| **الدعم والملاحظات والاعتراض والبلاغ:** نصوصك وبريدك الإلكتروني للتواصل | الرد على الطلبات، والإشراف | تنفيذ العقد؛ المصلحة المشروعة؛ الالتزام القانوني | عند حذف الحساب تُمحى النصوص ويبقى السجل مجهول الهوية؛ وطلبات الدعم العامة (دون تسجيل دخول) 365 يومًا |
| **سجل مرشّح الألفاظ غير اللائقة:** في أي حقل، ومحتوى أي مستخدم رُفض/وُسم، ووقت ذلك (لا يُحفَظ النص المرفوض) | منع إساءة الاستخدام في المساحات العامة | المصلحة المشروعة (م.5/2-و) | 90 يومًا |
| **سجلات الحظر والإشراف:** الأشخاص الذين حظرتهم، سجلات المخالفات، قرارات البلاغات، آثار الحظر | الأمن والإشراف | المصلحة المشروعة؛ الالتزام القانوني | يُحتفَظ بأثر الإشراف مجهول الهوية حتى بعد حذف الحساب |
| **سجلات وصول المسؤولين وإجراءاتهم** (بما فيها سجل الاطلاع على الرسائل) | المساءلة، ومنع الوصول غير المصرّح به | المصلحة المشروعة؛ الالتزام القانوني | سجل إجراءات المسؤولين (بما فيه IP) 365 يومًا؛ وسجل الوصول إلى الرسائل وسجل إجراءات إدارة النوادي 730 يومًا (السجلات للإضافة فقط ولا تُعدَّل)؛ وتُحذف عند انتهاء المدة |
| **الموافقات على العقود والنصوص:** نوع الوثيقة، الإصدار، الوقت | إثبات الموافقة/القبول | الالتزام القانوني؛ المصلحة المشروعة | تُحفَظ حتى بعد حذف الحساب |
| **طابور البريد الإلكتروني:** المستلم، الموضوع، حالة الإرسال | رسائل التحقق/إعادة تعيين كلمة المرور/الأمن وإعلانات المسؤولين | تنفيذ العقد؛ المصلحة المشروعة في الإعلانات | تُحذف السجلات المرسَلة بعد 7 أيام، والفاشلة (غير القابلة للتسليم) بعد 30 يومًا |
| **سجلات رسائل الإعلانات الإدارية (الحملات):** اسم الحملة وحالتها، ومعرّف مستخدمك بصفة مستلم وحالة التسليم | إرسال إعلانات الخدمة والمجتمعات (ليست إعلانًا تجاريًا أو تسويقًا؛ وفي كل رسالة رابط لإلغاء الاشتراك). وقد تُستخدم حقول الملف الشخصي كالاسم والقسم والكلية والسنة لتخصيص الرسالة | المصلحة المشروعة (م.5/2-و)؛ تنفيذ العقد | تُحذف بعد 180 يومًا من انتهاء الحملة؛ ويُحذف صف المستلم الخاص بك فورًا عند حذف حسابك |
| **مطابقة دفتر العناوين:** ملخّص SHA-256 للبريد الإلكتروني الموجودة في دفتر عناوينك (أثناء الطلب فقط) | العثور على معارفك في دفتر عناوينك | **الموافقة الصريحة** (م.5/1) | **لا يُخزَّن ولا يُسجَّل**؛ يبقى في الذاكرة طوال معالجة الطلب فقط |
| **موقع الجهاز** | — | — | لا يطلب التطبيق إذن الموقع؛ وموقع الجهاز (GPS/الشبكة) **لا يُجمع ولا يُرسَل إلى الخادم ولا يُخزَّن** (انظر 5) |

> **باختصار:** كل بيانات نعالجها مرتبطة بغرض؛ ومعظمها يُحتفَظ به ما دام حسابك مفتوحًا. تُحفَظ سجلات الجهاز/IP 90 يومًا، وأحداث التحليلات الخام 45 يومًا، وسجل النشاط اليومي 400 يوم، والإشعارات 30 يومًا (المقروءة) / 90 يومًا (غير المقروءة)، وطابور البريد الإلكتروني 7 أيام (30 يومًا إن فشل)، وسجلات حملات الإعلانات 180 يومًا.

## 3. كيف تُخزَّن رسائلك ومن يمكنه الاطلاع عليها؟

1. **النقل:** تُنقَل الرسائل مشفّرة عبر TLS/WSS.
2. **التخزين:** تُخزَّن على الخادم مشفّرة بـ AES-256-GCM بمفتاح مستقل لكل محادثة. وتُحمى المفاتيح بمفتاح رئيسي منفصل، ويُحتفَظ بها في بيئة الخادم لا في قاعدة البيانات. وهذا يصعّب قراءة الرسائل حتى لو وقعت نسخة احتياطية من قاعدة البيانات في يد الغير.
3. **النظام ليس مشفّرًا من طرف إلى طرف.** وبما أن المفتاح الرئيسي لدينا، فإن النظام قادر على فك تشفير الرسائل. فاستخدمه وأنت على علم بذلك.
4. **وصول المسؤولين:** لا يمكن إلا للمسؤولين المخوَّلين الاطلاع على محتوى الرسائل والوسائط، وذلك لأسباب مثل مراجعة الشكاوى، والأمن/إساءة الاستخدام، والطلبات القانونية وما شابهها. وقد تعرض واجهة المسؤول أيضًا الرسائل المحذوفة والمعدَّلة والمخفية بالإشراف، والصور «ذات الإرسال الواحد»، والرسائل التي لا تُسلَّم إلى المستخدم المحظور. و**كل اطلاع** يُكتب تلقائيًا في سجل غير قابل للتعديل قبل عرض المحتوى: من اطلع، ومحادثة من اطلع عليها، وكم رسالة، ومن أي IP، ومتى. وإذا تعذّر كتابة السجل فلا يُعرَض المحتوى.
5. **الرسائل المحذوفة:** «الحذف للجميع» يخفي الرسالة عن المستخدمين الآخرين؛ وقد تُحفَظ النسخة المشفّرة للرسالة وإصداراتها السابقة لأغراض المراجعة الأمنية. وتُحدَّد مدة الحفظ من قِبل المشغّل (الافتراضي: غير محددة المدة).
6. **الصور ذات الإرسال الواحد:** يراها المستلم مرة واحدة ثم يُغلَق وصوله؛ غير أن الملف المشفّر يُحفَظ 365 يومًا (قابلة للضبط) لمراجعة المسؤول ثم يُحذف. ورغم وجود تدابير تقنية لمنع لقطات الشاشة، فلا تُعطى ضمانة مطلقة.
7. **معاينة الإشعار:** افتراضيًا لا يظهر نص الرسالة في الإشعار الفوري (وإذا فُعِّل الإعداد فإن النص يمر عبر Google FCM/Apple APNs). ولا يُكتب محتوى الرسالة في صندوق الإشعارات داخل التطبيق إطلاقًا.
8. **معالجة الصور والفيديو:** يُتحقَّق من نوع الصور وحجمها وتُعاد ترميزها، وتُزال بيانات EXIF (الموقع وغيره). أما **فيديوهات المحادثة** فتُضغط على جهازك؛ ولا يعيد الخادم ترميزها، وتُخزَّن مشفّرة بمفتاح خاص بالمحادثة. وأما **فيديوهات المنشورات (اكتشف)** فيعيد الخادم ترميزها بعد الرفع (فيديو H.264، بارتفاع 720p كحد أقصى، وصوت AAC؛ وتُهمَل البيانات الوصفية مثل GPS) وتُخزَّن على القرص مشفّرة بمفتاح يُولَّد عشوائيًا لكل ملف؛ ويُغلَّف هذا المفتاح أيضًا بالمفتاح الرئيسي ويُحفَظ في قاعدة البيانات. وإلى أن تنتهي إعادة الترميز يمكن تشغيل الملف الأصلي (المشفّر) الذي رفعته، وعند انتهائها يُحذف الملف الأصلي. ويُقارَن ملخّص الصور بقائمة ملخّصات المحتوى المحظور؛ ولا يُحلَّل المحتوى المرئي للصور آليًا.
9. **الحظر:** لا تُسلَّم إليك الرسائل التي يكتبها لك من حظرتَه؛ ولا يُرسَل إشعار إلى الشخص المحظور. وتبقى هذه الرسائل في النظام ولا يراها إلا المسؤولون المخوَّلون لأسباب مثل مراجعة الشكاوى.

> **باختصار:** تُخزَّن الرسائل مشفّرة لكن ليس من طرف إلى طرف. ولا يمكن للمسؤولين المخوَّلين الاطلاع عليها إلا في حالات مسبَّبة، مع التسجيل في كل مرة. وقد تُحفَظ لفترة النسخة المشفّرة للرسائل المحذوفة والصور ذات الإرسال الواحد لأغراض الأمن.

## 4. مع من نشارك بياناتك؟

| المستلم | ما الذي يُشارَك؟ | الغرض | الموقع |
|---|---|---|---|
| **Google Firebase Cloud Messaging (FCM)** (وApple APNs لنظام iOS) | مفتاح إشعارات الجهاز، عنوان الإشعار/نصه القصير، معلومات الهدف | إيصال الإشعارات الفورية | خارج البلاد (بنية Google/Apple التحتية)؛ انظر نص الإفصاح وفق KVKK |
| **مزوّد خدمة إرسال البريد الإلكتروني: Brevo (SMTP)** (جهة معالجة) | عنوان البريد الإلكتروني للمستلم، محتوى البريد (رمز التحقق، نص الإعلان؛ وفي الإعلانات الاسم والقسم/الكلية/السنة لأغراض التخصيص) | رسائل التحقق وإعادة تعيين كلمة المرور والأمن وإعلانات المسؤولين | قد يكون خارج البلاد (قد توجد خوادم المزوّد في أوروبا أو بلدان أخرى)؛ انظر نص الإفصاح وفق KVKK |
| **مزوّد الاستضافة / الخوادم** | جميع بيانات الخدمة (بما فيها الرسائل المشفّرة) | استضافة الخدمة | {{hosting.location|يُعلَن موقع الاستضافة قبل النشر}} |
| **الجهات العامة المختصة** (المحكمة، النيابة العامة، الضابطة العدلية، مجلس KVKK وغيرها) | البيانات الواقعة ضمن نطاق الطلب | الالتزام القانوني | داخل البلاد |
| **إدارة الجامعة / المسؤولون المخوَّلون** | البيانات اللازمة للإشراف والدعم | إدارة الخدمة والأمن | داخل البلاد |

لا نشارك البيانات مع شبكات الإعلانات أو سماسرة البيانات أو أدوات التتبع في وسائل التواصل الاجتماعي.

## 5. الأذونات والميزات الاختيارية

1. **إذن الإشعارات:** إن شئت تتلقى الإشعارات الفورية. وإذا رفضت يستمر صندوق الإشعارات داخل التطبيق في العمل. وتدير أنواع الإشعارات و**ساعات الصمت** من الإعدادات.
2. **مطابقة دفتر العناوين:** إذا منحت إذن الوصول إلى دفتر العناوين، فإنه للعثور على معارفك يُرسَل إلى الخادم **ملخّص SHA-256 فقط** لعناوين البريد الإلكتروني الموجودة في دفتر عناوينك (500 عنوان كحد أقصى / في الطلب الواحد). **ولا تُخزَّن الملخّصات ولا تُسجَّل**؛ ولا يعود إليك في الرد إلا المستخدمون المطابقون (مع احترام إعدادات الخصوصية). ولا تُرسَل أسماء دفتر عناوينك ولا أرقام هواتفك إلى الخادم. ويوجد حد ساعي للطلبات لمنع إساءة الاستخدام.
3. **الموقع:** لا يطلب التطبيق **إذن الموقع** (المعتمد على GPS/الشبكة) من جهازك؛ ولا يجمع موقعك ولا يرسله إلى الخادم ولا يخزّنه. وعنوان IP المسجَّل لأغراض أمنية (انظر 6) ليس موقع الجهاز؛ ولا يُستنتَج في كود التطبيق موقع أو منطقة من عنوان IP. قد يحتفظ مزوّدو الاستضافة وبنية الشبكة بسجلاتهم الفنية الخاصة وفق سياساتهم؛ ولا نستخدمها لتحديد الموقع. وإذا قرّرنا في المستقبل معالجة الموقع فسيُحدَّث هذا النص وتُؤخَذ موافقتك الصريحة من جديد.
4. يمكنك سحب الأذونات في أي وقت من إعدادات الجهاز أو من شاشة الأذونات في التطبيق. ولا يؤثر السحب في مشروعية العمليات التي تمت قبل لحظة السحب.

## 6. سجلات الجهاز وIP وحالات حظر الوصول

1. لأغراض الأمن؛ يُسجَّل أثناء التسجيل والدخول وتجديد الجلسة والطلبات: الملخّص غير القابل للعكس لمعرّف جهازك، والمنصة، وإصدار التطبيق، وعنوان IP، ومعلومات الوقت. ولا يُحفَظ معرّف الجهاز الخام.
2. تُحفَظ هذه السجلات افتراضيًا **90 يومًا** وتُنظَّف ليلًا. ويمكن للمشغّل ضبط المدة؛ وإذا نشأ التزام قانوني بالحفظ (مثل بيانات حركة المرور وفق القانون رقم 5651) فقد تُحدَّد المدة وفقًا لذلك ويُحدَّث هذا النص.
3. يمكن تعريف **حظر وصول** على عنوان IP المستخدم المحظور بسبب إساءة الاستخدام، أو نطاق شبكته، أو ملخّص جهازه، أو معرّف المستخدم. ويُحفَظ سجل الحظر (رمز السبب، التاريخ، المدة إن وُجدت، الملاحظات) ما دام الحظر قائمًا وللمدة اللازمة للاعتراض/الرقابة. وتُحفَظ المحاولات التي اصطدمت بالحظر (IP، ملخّص الجهاز، مسار الطلب، الوقت) كسجل أمني وتخضع لمبدأ التنظيف نفسه المطبَّق على سجلات الجهاز/IP. وقد تُقيَّد الطلبات الواردة من نطاقات إخفاء الهوية مثل VPN/Tor/مراكز البيانات لأغراض أمنية.
4. إذا رأيت أنك محظور فيمكنك التقدّم من قسم الدعم أو من خاصية الاعتراض.

## 7. حذف الحساب وقابلية نقل البيانات

**تنزيل بياناتي:** يمكنك من الملف الشخصي > تنزيل بياناتي تنزيل بياناتك بصيغة JSON (بحد 3 مرات في اليوم). ولا تدخل الرسائل المحذوفة في المخرجات. ويشمل الملف ملفك الشخصي وإعدادات الخصوصية وسجلات الموافقة والرسائل وعضويات المحادثات والمنشورات والإعجابات والمتابعات والأخبار المفضلة وعضويات المجتمعات ومنشوراتها وسجلات المشاركة والتقديم والحضور في الفعاليات والفعاليات التي أنشأتها وحملات الإعلانات البريدية التي وصلتك والإشعارات وسجلات الأجهزة وطلبات الدعم وسجل الجهاز/IP. وإذا تعذّر إعداد قسم مؤقتًا تظهر علامة خطأ في ذلك القسم وتُسلَّم الأقسام الأخرى.

**حذف الحساب = تجهيل الهوية.** عند حذف حسابك:

| ماذا يحدث؟ | أي البيانات |
|---|---|
| **تُحذف** | مفاتيح إشعارات أجهزتك وسجلات push المعلّقة، وصندوق إشعاراتك وتفضيلاتك، وعلاقات المتابعة، وسجلات الجدول الدراسي والامتحانات، وسجل مشاركتك في الاستطلاعات، وإعجاباتك، ومنشورات اكتشف الخاصة بك (تُزال ملفات الوسائط من القرص بعد 30 يومًا)، وأخبارك المفضلة، وأصوات الملاحظات التي أدليت بها، وتقييمات الفعاليات، وقائمة الحظر، وردود طلبات الانضمام إلى النوادي، وعضوياتك في المجتمعات، وصفوفك في حملات الإعلانات البريدية، وصور المحادثة التي رفعتها، و**سجلات الجهاز/IP وأحداث التحليلات وسجل النشاط اليومي (فورًا)**، والصور التي أرفقتها بمنشورات النوادي (فورًا ومن القرص). وتُغلق طلبات مشاركتك في الفعاليات (ويتقدّم التالي في قائمة الانتظار) وتُلغى الفعاليات غير المنتهية التي أنشأتها وغير المرتبطة بنادٍ. **إذا كنت مالكًا لنادٍ:** تنتقل الملكية إلى أقدم مدير نشط فيه (أو مشرف)؛ وإن لم يوجد من يتولاها يُغلق النادي ويُبلَّغ أعضاؤه |
| **تُجهَّل هويتها** | الاسم، والبريد الإلكتروني، ومعلومات الملف الشخصي، والسيرة الذاتية المختصرة، والصورة؛ وسجلات أصوات الاستطلاعات (يُقطَع الارتباط بالمستخدم)؛ وتُمحى نصوص الدعم والملاحظات والاعتراض والبلاغ وطلبات الانضمام إلى الفعاليات (يبقى السجل مجهول الهوية) |
| **يُحتفَظ بها (بشكل محدود)** | الرسائل التي أرسلتَها ومنشورات المجتمعات (جزء من سياق محادثة الآخرين؛ يظهر الكاتب بشكل مجهول مثل «مستخدم محذوف»)؛ وسجلات الموافقة على العقود (دليل قانوني)؛ وآثار مخالفات الإشراف/البلاغات والحظر؛ وعدّادات الحضور/RSVP المجهولة؛ وسجلات إجراءات المسؤولين ووصولهم |
| **تُنظَّف بمرور المدة** | سجلات الجهاز/IP (90 يومًا)، وسجل مرشّح الألفاظ غير اللائقة (90 يومًا)، وأحداث التحليلات الخام (45 يومًا)، وسجل النشاط اليومي (400 يوم)، وطابور البريد الإلكتروني (المرسل 7 أيام، والفاشل 30 يومًا)، وسجلات حملات الإعلانات (180 يومًا)، وسجل إجراءات المسؤولين (365 يومًا)، وسجلات الوصول إلى الرسائل وإجراءات النوادي (730 يومًا) |

> **باختصار:** عند حذف حسابك تزول هويتك، وتُحذف بياناتك الشخصية أو تُجهَّل هويتها. ولحماية حقوق الآخرين والحاجة القانونية للأدلة والأمن تبقى بعض السجلات مجهولة الهوية وبشكل محدود.

## 8. تدابير الأمن

1. تُخزَّن كلمات المرور كملخّص أحادي الاتجاه؛ وتُحفَظ رموز التحقق ومفاتيح التجديد كملخّصات.
2. مفتاح الوصول صالح 15 دقيقة؛ ومفتاح التجديد للاستخدام مرة واحدة؛ وعند تغيير كلمة المرور تُغلَق جميع الجلسات.
3. يُطبَّق حد للمعدّل على الدخول والتسجيل والتحقق وعمليات الكتابة؛ وتُعطى ردود عامة لا تكشف وجود المستخدم.
4. تُخزَّن الرسائل مشفّرة؛ ووصول المسؤولين مسجَّل؛ ولا تعمل لوحة الإدارة إلا بدور المسؤول.
5. يُتحقَّق من نوع الملفات المرفوعة وحجمها، وتُولَّد أسماؤها على الخادم.
6. لا يوجد نظام آمن أمانًا مطلقًا. وإذا حدث خرق للبيانات فسنبلّغ المجلس (Kurul) والأشخاص المتضررين وفق التشريعات.

## 9. ملفات تعريف الارتباط والتخزين المحلي

**لا تُستخدم** في الموقع الإلكتروني ملفات تعريف ارتباط للتتبع/الإعلان. ولا يُستخدم إلا التخزين المحلي الضروري مثل تفضيل اللغة/السمة ومعلومات الجلسة. وللتفاصيل انظر [سياسة ملفات تعريف الارتباط والتخزين المحلي](/legal/cookies).

## 10. بيانات الأطفال

لم تُصمَّم الخدمة لمن هم دون 18 عامًا؛ ولا يتم التسجيل إلا ببريد إلكتروني لطالب/موظف في الجامعة. وإذا اكتُشف تسجيل مستخدم دون 18 عامًا فقد يُطلَب علم الممثل القانوني وموافقته؛ وعند الاقتضاء يُغلَق الحساب وتُحذف البيانات/تُجهَّل هويتها.

## 11. حقوقك

وفقًا للمادة 11 من KVKK لديك حقوق الوصول إلى بياناتك وتصحيحها وحذفها والاعتراض وغيرها من الحقوق. وسبل التقدّم بالطلبات ومهلة الرد البالغة 30 يومًا واردة في [نص الإفصاح وفق KVKK](/legal/kvkk) ونص [الحفظ والإتلاف](/legal/retention). الطرق السريعة: تعديل معلومات الملف الشخصي، إعدادات الخصوصية، تنزيل بياناتي، حذف الحساب، قسم الدعم.

## 12. التغييرات

يجوز لنا تحديث هذه السياسة. وفي حال التغييرات المهمة نطلب منك الموافقة من جديد؛ ويتوفر الإصدار الحالي والسجل السابق في هذه الصفحة.

## 13. المنشورات والإشراف على المحتوى

1. **من يراها؟** تُعرَض المنشورات للمستخدمين الآخرين الذين سجّلوا الدخول إلى التطبيق؛ ويُغلَق الظهور المتبادل مع المستخدمين الذين حظرتَهم أو حظروك. تُعرض خيارات الظهور المتاحة في التطبيق على الشاشة المعنية.
2. **صور منشورات النوادي.** تُفصَل الصورة المرفقة بمنشور نادٍ وتُحذف من القرص عند حذفك المنشور أو إغلاق النادي أو حذف حسابك.
3. **مرشّح الألفاظ غير اللائقة.** في المساحات العامة مثل المجتمعات والفعاليات والملف الشخصي والمنشورات قد تُرفَض آليًا الشتائم والإهانات وما شابهها من العبارات. و**رسائل المحادثة (الفردية والجماعية) لا تخضع لفحص مسبق.** ويعمل المرشّح لحظة الحفظ فقط؛ ويُحفَظ 90 يومًا أي حقل ومحتوى أي مستخدم رُفض، ولا يُحفَظ النص المرفوض. ولا يُنشَر المحتوى المرفوض؛ ويصدر القرار آليًا دون مراجعة بشرية، ويمكنك تقديم اعتراضك من قسم الدعم.
4. **الشكوى والإزالة.** يمكن الإبلاغ عن المنشورات والرسائل عبر **إبلاغ**؛ ويراجعها المسؤولون المخوَّلون ويمكنهم إخفاء المحتوى أو إزالته. وللإجراءات انظر نصَّي [الإبلاغ عن المحتوى وإزالته](/legal/content-removal) و[قواعد المجتمع](/legal/community-rules).

## 14. التواصل

{{support.email|قسم الدعم داخل التطبيق}}{{?controller.email}} · {{controller.email}}{{/controller.email}}{{?controller.kep}} · KEP: {{controller.kep}}{{/controller.kep}}$c_privacy_ar$, FALSE, TRUE);
END
$do_privacy$;

DO $do_kvkk$
DECLARE
    v INTEGER;
BEGIN
    SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = 'KVKK';
    UPDATE legal_document SET active = FALSE WHERE type = 'KVKK' AND active;
    INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active) VALUES
    ('KVKK', 'tr', v, $t_kvkk_tr$KVKK Aydınlatma Metni$t_kvkk_tr$, $c_kvkk_tr$6698 sayılı Kişisel Verilerin Korunması Kanunu'nun ("**Kanun**" / "**KVKK**") 10. maddesi ve Aydınlatma Yükümlülüğünün Yerine Getirilmesinde Uyulacak Usul ve Esaslar Hakkında Tebliğ uyarınca, BÜ Kampüs uygulaması ve web sitesini kullanırken kişisel verilerinizin nasıl işlendiği hakkında sizi bilgilendiririz. Bu metin bilgilendirme amaçlıdır; açık rıza gerektiren işlemler ayrıca [Açık Rıza Metni](/legal/explicit-consent) ile sizden ayrı ayrı istenir.

## 1. Veri sorumlusu

| | |
|---|---|
| Veri sorumlusu | {{controller.name}} |
{{?controller.address}}| Adres | {{controller.address}} |{{/controller.address}}
{{?controller.email}}| E-posta | {{controller.email}} |{{/controller.email}}
{{?controller.kep}}| KEP adresi | {{controller.kep}} |{{/controller.kep}}
{{?controller.verbis}}| VERBİS sicil no | {{controller.verbis}} |{{/controller.verbis}}
| Uygulama içi başvuru | Destek bölümü{{?support.email}} · {{support.email}}{{/support.email}} |

## 2. İşlenen kişisel veri kategorileri

| Kategori | Örnekler |
|---|---|
| Kimlik | Ad-soyad |
| İletişim | Kurumsal e-posta adresi (bingol.edu.tr), destek taleplerinde iletişim e-postası |
| Eğitim/mesleki bilgi | Fakülte, bölüm, sınıf, öğrenci/personel rolü |
| Görsel | Profil fotoğrafı; sohbet/gönderi fotoğrafları ve videoları (gönderi videoları sunucuda yeniden kodlanır ve şifreli saklanır) |
| Kullanıcı içeriği | Mesajlar, topluluk ve Keşfet gönderileri, anket oyları, etkinlik başvuru yanıtları, geri bildirim, destek ve itiraz metinleri, biyografi |
| Müşteri işlem / kullanım | Topluluk üyelikleri, etkinlik katılımı ve yoklama, favoriler, takip ilişkileri, bildirim ve gizlilik tercihleri, engelleme listesi, aldığınız yönetici duyuru e-postası kampanyalarının kaydı (kampanya ve gönderim durumu) |
| Kişisel plan | Kullanıcının kendi girdiği ders programı, ders, dönem ve sınav kayıtları |
| İşlem güvenliği | Oturum bilgisi, şifre özeti, cihaz tanımlayıcısının geri döndürülemez özeti, IP adresi, platform ve uygulama sürümü, erişim engeli kayıtları, hata ve giriş denemeleri |
| Hukuki işlem / uyum | Sözleşme onay kayıtları, şikâyet/rapor ve moderasyon kayıtları, yönetici erişim kayıtları |
| Pazarlama | İşlenmez (reklam/pazarlama amacıyla işleme yapılmaz). Yöneticilerin gönderdiği duyuru e-postaları hizmet ve topluluk duyurusudur; her e-postada abonelikten çıkış bağlantısı bulunur |
| Özel nitelikli veri | Bilerek talep edilmez. Kullanıcı içeriği içinde (ör. mesajda) paylaşılan özel nitelikli veriler, yalnızca sizin paylaşımınız çerçevesinde barındırılır; bunları işlemeyi amaçlamayız. |

## 3. İşleme amaçları

1. Üyelik oluşturma, kimlik ve e-posta doğrulama, hesap güvenliği.
2. Haber, duyuru, etkinlik, yemek listesi, topluluk, etkinlik, yoklama, mesajlaşma, arama ve favori hizmetlerinin sunulması.
3. Bildirimlerin (uygulama içi, anlık, e-posta) gönderilmesi.
4. Destek, geri bildirim ve itiraz taleplerinin yürütülmesi.
5. Güvenlik, kötüye kullanımın ve yasaklı kullanıcı engelinin dolanılmasının önlenmesi, moderasyon.
6. Hizmetin iyileştirilmesi, hata ve performans takibi (toplulaştırılmış analiz).
7. Hukuki yükümlülüklerin yerine getirilmesi, yetkili makam taleplerinin karşılanması, hakların kullanılması ve savunulması.
8. Sözleşme ve rıza kayıtlarının tutulması.
9. Gönderi, takip, favori, anket ve kişisel ders programı hizmetlerinin sunulması; yönetici duyuru e-postalarının gönderilmesi.
10. Herkese açık alanlarda uygunsuz ifadenin otomatik filtrelenmesi ve şikâyetlerin yürütülmesi.

## 4. Hukuki sebepler

| Hukuki sebep | Örnek işleme faaliyetleri |
|---|---|
| m.5/2-(a) Kanunlarda açıkça öngörülmesi | Yetkili makamlara bilgi verilmesi, mevzuatın zorunlu kıldığı kayıtlar |
| m.5/2-(c) Sözleşmenin kurulması veya ifası | Üyelik, profil, mesajlaşma, topluluk/etkinlik hizmetleri, bildirim ve e-posta gönderimi |
| m.5/2-(ç) Hukuki yükümlülüğün yerine getirilmesi | Sözleşme onay kayıtları, yasal talepler, ilgili mevzuat gereği saklama |
| m.5/2-(e) Bir hakkın tesisi, kullanılması veya korunması | Moderasyon izleri, itiraz ve uyuşmazlık için delil niteliğindeki kayıtlar |
| m.5/2-(f) Meşru menfaat (temel hak ve özgürlüklere zarar vermemek şartıyla) | Güvenlik, cihaz/IP kaydı, hız sınırlama, yönetici erişim denetimi, analitik |
| m.5/1 Açık rıza | Rehber eşleştirme, anlık bildirim izni, isteğe bağlı profil alanlarının yayımı gibi **isteğe bağlı** işlemler |

(m.5/2-(ç) ve m.5/2-(e) bendleri ilgili işlemlerde birlikte dayanak olabilir.)

## 5. Kişisel verilerin aktarılması

| Alıcı grubu | Aktarılan veri | Amaç | Yurt içi / yurt dışı |
|---|---|---|---|
| Barındırma ve altyapı hizmet sağlayıcıları (veri işleyen) | Hizmet verisi (mesajlar şifreli) | Hizmetin barındırılması | {{hosting.location|Barındırma konumu veri sorumlusunca ayrıca bildirilir}} |
| E-posta gönderim hizmeti sağlayıcısı: Brevo (SMTP; veri işleyen) | Alıcı e-posta, e-posta içeriği; duyuru e-postalarında ad ve bölüm/fakülte/sınıf gibi kişiselleştirme alanları | Doğrulama/şifre sıfırlama/güvenlik e-postaları ve yönetici duyuruları | **Yurt dışı olabilir** (sağlayıcının sunucuları Avrupa'da veya başka ülkelerde bulunabilir) |
| Bildirim sağlayıcısı: Google LLC (Firebase Cloud Messaging) ve iOS için Apple Inc. (APNs) | Cihaz bildirim anahtarı, bildirim başlığı/kısa metni, hedef bilgisi, platform | Anlık bildirim iletimi | **Yurt dışı** |
| Yetkili kamu kurum ve kuruluşları (mahkeme, savcılık, kolluk, Kurul vb.) | Talep kapsamındaki veri | Hukuki yükümlülük | Yurt içi |
| Bingöl Üniversitesi ilgili birimleri / yetkili yöneticiler | Moderasyon, destek ve güvenlik için gerekli veri | Hizmet yönetimi | Yurt içi |

**Yurt dışına aktarım (m.9).** Anlık bildirim için cihaz bildirim anahtarınız ve bildirim içeriği Firebase/APNs üzerinden yurt dışına aktarılır. Bu aktarım; Kanun'un 9. maddesi ve ilgili Kurul düzenlemeleri çerçevesinde, **bildirim iznine dayanan açık rızanıza** ve/veya yeterlilik/uygun güvence mekanizmalarına (standart sözleşme vb.) dayanır. Bildirim iznini vermemeniz halinde anlık bildirim almazsınız ancak uygulama içi bildirim kutusu ve diğer hizmetler çalışmaya devam eder. Rızanızı cihaz ayarlarından veya uygulamadaki İzinler/Bildirim ayarlarından istediğiniz zaman geri alabilirsiniz. E-posta gönderim hizmeti sağlayıcısının (Brevo) sunucuları da yurt dışında bulunabilir; doğrulama, şifre sıfırlama ve duyuru e-postalarının iletimi için e-posta adresiniz ve e-posta içeriği bu sağlayıcıya aktarılabilir ve bu aktarım da yukarıdaki m.9 çerçevesindeki mekanizmalara dayanır.

## 6. Kişisel verilerin toplanma yöntemi

Verileriniz; uygulama ve web sitesi üzerinden elektronik ortamda, kayıt/profil formları, mesajlaşma ve içerik paylaşımı, destek formları, cihazınızın teknik iletişimi (IP, cihaz özeti, uygulama sürümü), çerez benzeri yerel depolama ve (izin verirseniz) rehber eşleştirme isteği yoluyla otomatik ve kısmen otomatik yöntemlerle toplanır. Haber ve yemek listesi içerikleri kişisel veri içermeyen kamuya açık kaynaklardan derlenir.

## 7. Saklama süresi

Kişisel veriler, işleme amacı için gerekli süre ve ilgili mevzuatta öngörülen süre boyunca saklanır, süre bitiminde silinir, yok edilir veya anonim hale getirilir. Başlıca süreler: bekleyen kayıt 1 saat; doğrulama kodu 10 dakika; yenileme anahtarı en çok 30 gün; okunmuş bildirim 30 gün, okunmamış 90 gün (kullanıcı başına en yeni 200); cihaz bildirim anahtarı 60 gün görülmezse; cihaz/IP güvenlik kayıtları 90 gün; uygunsuz ifade filtresi kaydı 90 gün; push kuyruğu kaydı gönderildikten 7 gün (başarısızsa 30 gün); analitik ham olaylar 45 gün (ardından yalnızca kişiye bağlı olmayan toplulaştırılmış özetler); günlük aktiflik kaydı 400 gün; e-posta kuyruğu gönderilenler 7 gün, başarısızlar 30 gün; yönetici duyuru e-postası (kampanya) kayıtları kampanya bitiminden 180 gün; yönetici işlem kaydı 365 gün; mesaj erişim ve kulüp işlem kaydı 730 gün; tek gönderimlik fotoğrafın şifreli kopyası 365 gün; herkese açık destek talebi 365 gün. Hesap açık olduğu sürece profil ve içerikleriniz saklanır; silinen mesajların şifreli kopyası ve sözleşme onay kayıtları güvenlik/ispat amacıyla ayrıca tutulabilir. Ayrıntılı tablo: [Saklama ve İmha](/legal/retention).

## 8. Mesajlara yönetici erişimi (şeffaflık notu)

Mesajlar sunucuda şifreli saklanır ancak sistem uçtan uca şifreli değildir. Yetkili yöneticiler, şikâyet incelemesi, güvenlik, kötüye kullanım ve yasal talepler gibi gerekçelerle mesajları ve medyayı görüntüleyebilir; her görüntüleme otomatik ve değiştirilemez biçimde kaydedilir. Bu işleme faaliyetinin hukuki sebebi meşru menfaat ve hukuki yükümlülüktür (m.5/2-(f), (ç), (e)); ayrıntı [Gizlilik Politikası](/legal/privacy) bölüm 3'tedir.

## 9. Otomatik karar verme

Hizmet, hakkınızda yalnızca otomatik işleme ile hukuki sonuç doğuran bir karar vermez. Aynı hesapla ilgili birden çok ihlal kaydı birikmesi halinde sistem yalnızca bir yöneticiye **öneri** üretir; askıya alma kararını bir yönetici verir. Hız sınırlama, yasaklı içerik özeti kontrolü ve herkese açık alanlardaki uygunsuz ifade filtresi gibi otomatik önlemler vardır; filtre bir içeriği otomatik reddedebilir (sohbet mesajları bu denetime tabi değildir), itirazınızı Destek bölümünden iletebilirsiniz. Hesabınıza yönelik kalıcı sonuç doğuran kararlar yönetici tarafından verilir.

## 10. Haklarınız (m.11)

Veri sorumlusuna başvurarak şunları talep edebilirsiniz:

1. Kişisel verilerinizin işlenip işlenmediğini öğrenme,
2. İşlenmişse buna ilişkin bilgi talep etme,
3. İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme,
4. Yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme,
5. Eksik veya yanlış işlenmişse düzeltilmesini isteme,
6. Kanun'un 7. maddesindeki şartlar çerçevesinde silinmesini veya yok edilmesini isteme,
7. (5) ve (6) kapsamındaki işlemlerin aktarıldığı üçüncü kişilere bildirilmesini isteme,
8. İşlenen verilerin münhasıran otomatik sistemler ile analiz edilmesi sonucu aleyhinize bir sonuç çıkmasına itiraz etme,
9. Kanuna aykırı işleme nedeniyle zarara uğramanız halinde zararın giderilmesini talep etme.

Uygulama içi kısa yollar: Profil düzenleme ve gizlilik ayarları (düzeltme/yayım kontrolü), **Verilerimi indir** (erişim/kopya), **Hesabı sil** (silme/anonimleştirme).

## 11. Başvuru yolu

1. **Uygulama içi:** Destek bölümünden "Kişisel veri başvurusu" konusuyla talep oluşturun (oturum açmış kullanıcının kimliği hesap üzerinden doğrulanır).
2. **Yazılı:** Islak imzalı dilekçe ile{{?controller.address}} {{controller.address}} adresine{{/controller.address}} elden veya noter vasıtasıyla.
{{?controller.kep}}3. **KEP:** {{controller.kep}} adresine güvenli elektronik imzalı başvuru.{{/controller.kep}}
{{?controller.email}}4. **E-posta:** {{controller.email}} adresine, kayıtlı kurumsal e-posta adresinizden.{{/controller.email}}

Başvurunuzda; ad-soyad, kimlik doğrulamaya yarayan bilgi (hesap e-postası), tebligat adresi, talep konusu belirtilmelidir. Kimliğinizi doğrulamak için ek bilgi isteyebiliriz. Başvurular talebin niteliğine göre **en geç 30 gün** içinde ücretsiz sonuçlandırılır; işlemin ayrıca bir maliyet gerektirmesi halinde Kurul'un belirlediği tarifedeki ücret alınabilir.

Başvurunun reddedilmesi, cevabın yetersiz bulunması veya süresinde cevap verilmemesi halinde, cevabı öğrendiğiniz tarihten itibaren 30 gün ve her halde başvuru tarihinden itibaren 60 gün içinde **Kişisel Verileri Koruma Kurulu'na şikâyet** hakkınız saklıdır.$c_kvkk_tr$, FALSE, TRUE),
    ('KVKK', 'en', v, $t_kvkk_en$KVKK Privacy Notice$t_kvkk_en$, $c_kvkk_en$*This English text is provided for information only. The Turkish text is authoritative.*

Under Article 10 of the Personal Data Protection Law No. 6698 ("**KVKK**") and the Communiqué on Procedures and Principles of the Obligation to Inform, we inform you how your personal data is processed. Operations requiring explicit consent are requested separately in the [Explicit Consent text](/legal/explicit-consent).

## 1. Data controller

| | |
|---|---|
| Controller | {{controller.name}} |
{{?controller.address}}| Address | {{controller.address}} |{{/controller.address}}
{{?controller.email}}| E-mail | {{controller.email}} |{{/controller.email}}
{{?controller.kep}}| KEP address | {{controller.kep}} |{{/controller.kep}}
{{?controller.verbis}}| VERBİS registry no. | {{controller.verbis}} |{{/controller.verbis}}
| In-app application | Support section{{?support.email}} · {{support.email}}{{/support.email}} |

## 2. Categories of personal data

Identity (name); contact (university e-mail, contact e-mail in support requests); education/professional (faculty, department, year, role); visual (profile photo, chat/post photos and videos; post videos are re-encoded and stored encrypted on the server); user content (messages, community and Discover posts, poll votes, application answers, feedback, support and appeal texts, bio); personal plan (timetable, courses, semester and exams entered by you); usage (memberships, attendance, bookmarks, follows, notification and privacy preferences, block list, record of the administrator announcement e-mail campaigns you received (campaign and delivery status)); transaction security (session data, password hash, non-reversible device-identifier digest, IP address, platform, app version, ban records); legal/compliance (agreement acceptances, reports and moderation records, administrator access records). Marketing: not processed (administrator announcement e-mails are service and community announcements and carry an unsubscribe link). Special categories: not requested; any shared by you inside content is only hosted as you shared it.

## 3. Purposes

Membership and verification; providing news, announcements, events, menu, communities, events, attendance, messaging, search and bookmarks; notifications; support and appeals; security, abuse prevention and moderation; improving the service (aggregate analytics); legal obligations and defence of rights; keeping agreement and consent records; providing posts, follows, bookmarks, polls and personal timetable features; sending administrator announcement e-mails; automatic filtering of inappropriate language in public areas and handling reports.

## 4. Legal bases

| Basis | Examples |
|---|---|
| Art. 5/2-(a) Provided for by law | Information to authorities, mandatory records |
| Art. 5/2-(c) Performance of a contract | Membership, profile, messaging, communities/events, notifications |
| Art. 5/2-(ç) Legal obligation | Acceptance records, legal requests |
| Art. 5/2-(e) Establishment, exercise or protection of a right | Moderation trail, evidence for disputes |
| Art. 5/2-(f) Legitimate interest | Security, device/IP records, rate limiting, administrator access audit, analytics |
| Art. 5/1 Explicit consent | Optional: contact matching, push notifications, optional profile visibility |

## 5. Transfers

| Recipient group | Data | Purpose | Domestic / abroad |
|---|---|---|---|
| Hosting and infrastructure providers (processors) | Service data (messages encrypted) | Hosting | {{hosting.location|Notified separately by the controller}} |
| E-mail delivery service provider: Brevo (SMTP; processor) | Recipient address, content; in announcement e-mails name and department/faculty/year used for personalisation | Verification/reset/security e-mails and administrator announcements | **May be abroad** (the provider's servers may be in Europe or other countries) |
| Notification provider: Google LLC (Firebase Cloud Messaging) and Apple Inc. (APNs) | Push token, notification title/short text, target, platform | Push delivery | **Abroad** |
| Competent public authorities | Data within the request | Legal obligation | Domestic |
| University units / authorised administrators | Data needed for moderation, support, security | Administration | Domestic |

**Transfer abroad (Art. 9).** Push delivery transfers your device token and notification content abroad via Firebase/APNs. This relies on your **explicit consent given through the notification permission** and/or adequacy/appropriate-safeguard mechanisms (e.g. standard contract) under Article 9 and the Board's rules. Without notification permission you receive no push notifications but the in-app inbox and other services continue. You can withdraw consent at any time. The servers of the e-mail delivery provider (Brevo) may also be abroad; your e-mail address and the e-mail content may be passed to this provider to deliver verification, reset and announcement e-mails, and this transfer relies on the same Article 9 mechanisms described above.

## 6. Method of collection

Electronically through the app and website: registration/profile forms, messaging and content, support forms, technical communication of your device (IP, device digest, app version), local storage, and (if you allow) contact matching requests. News and menu content comes from public sources without personal data.

## 7. Retention

Data is kept for the time required by the purpose and applicable law, then deleted, destroyed or anonymised. Main periods: pending registration 1 hour; verification code 10 minutes; refresh token at most 30 days; read notifications 30 days, unread 90 (newest 200 per user); push token after 60 days unseen; device/IP records 90 days; language-filter log 90 days; push queue entries 7 days after sending (30 if failed); raw analytics events 45 days (then only non-personal aggregated summaries); daily activity record 400 days; e-mail queue 7 days when sent, 30 days when failed; administrator announcement e-mail (campaign) records 180 days after the campaign ends; administrator action log 365 days; message-access and club action logs 730 days; view-once photo encrypted copy 365 days; public support request 365 days. See [Retention](/legal/retention).

## 8. Administrator access to messages (transparency)

Messages are stored encrypted but the system is not end-to-end encrypted. Authorised administrators may view messages and media for report review, security, abuse and legal requests; every access is automatically recorded in a tamper-resistant log. Legal basis: legitimate interest and legal obligation. See the [Privacy Policy](/legal/privacy) section 3.

## 9. Automated decisions

No decision with legal effect is made solely by automated means. Accumulating violations only generates a **recommendation** to an administrator, who decides on suspension. Rate limits, prohibited-content digest checks and the inappropriate-language filter in public areas are automated measures; the filter may reject content automatically (chat messages are not subject to it) and you may contest through Support. Decisions with lasting effect on your account are made by an administrator.

## 10. Your rights (Art. 11)

You may apply to learn whether your data is processed; request information; learn the purpose and whether it is used accordingly; know recipients at home and abroad; request correction; request deletion or destruction under Article 7; request notification of those operations to third parties; object to an adverse result arising from exclusively automated analysis; and claim compensation for damage from unlawful processing. In-app shortcuts: profile and privacy settings, **Download my data**, **Delete account**.

## 11. How to apply

1. **In-app:** create a Support request titled "Personal data request".
2. **Written:** wet-signed petition{{?controller.address}} to {{controller.address}}{{/controller.address}}, by hand or notary.
{{?controller.kep}}3. **KEP:** to {{controller.kep}} with a secure electronic signature.{{/controller.kep}}
{{?controller.email}}4. **E-mail:** to {{controller.email}} from your registered university address.{{/controller.email}}

State your name, identifying information, notification address and request. We may ask for further information to verify identity. We answer free of charge **within 30 days at the latest**; if the action needs a cost, the Board's tariff may be charged. If your application is rejected, the reply is insufficient or not given in time, you may complain to the **Personal Data Protection Board** within 30 days of learning the reply and in any case within 60 days of applying.$c_kvkk_en$, FALSE, TRUE),
    ('KVKK', 'ar', v, $t_kvkk_ar$نص الإفصاح بموجب KVKK$t_kvkk_ar$, $c_kvkk_ar$*هذا النص العربي ترجمة للاطلاع فقط؛ النص التركي هو المرجع الملزم عند أي اختلاف.*

عملاً بالمادة 10 من قانون حماية البيانات الشخصية رقم 6698 ("**القانون**" / "**KVKK**") وبالبلاغ المتعلق بالإجراءات والأسس الواجب اتباعها في الوفاء بالتزام الإفصاح، نحيطكم علماً بكيفية معالجة بياناتكم الشخصية عند استخدامكم تطبيق BÜ Kampüs وموقعه الإلكتروني. هذا النص لأغراض الإعلام؛ أما العمليات التي تتطلب الموافقة الصريحة فتُطلب منكم لها موافقة منفصلة بموجب [نص الموافقة الصريحة](/legal/explicit-consent).

## 1. المسؤول عن البيانات

| | |
|---|---|
| المسؤول عن البيانات | {{controller.name}} |
{{?controller.address}}| العنوان | {{controller.address}} |{{/controller.address}}
{{?controller.email}}| البريد الإلكتروني | {{controller.email}} |{{/controller.email}}
{{?controller.kep}}| عنوان KEP (البريد الإلكتروني المسجّل) | {{controller.kep}} |{{/controller.kep}}
{{?controller.verbis}}| رقم السجل في VERBİS | {{controller.verbis}} |{{/controller.verbis}}
| التقديم عبر التطبيق | قسم الدعم{{?support.email}} · {{support.email}}{{/support.email}} |

## 2. فئات البيانات الشخصية المعالَجة

| الفئة | أمثلة |
|---|---|
| الهوية | الاسم واللقب |
| الاتصال | عنوان البريد الإلكتروني المؤسسي (bingol.edu.tr)، وبريد التواصل في طلبات الدعم |
| المعلومات التعليمية/المهنية | الكلية، القسم، الصف الدراسي، صفة الطالب/الموظف |
| المرئية | صورة الملف الشخصي؛ صور ومقاطع فيديو المحادثات/المنشورات (يُعاد ترميز مقاطع فيديو المنشورات على الخادم وتُخزَّن مشفّرة) |
| محتوى المستخدم | الرسائل، منشورات المجتمعات والاستكشاف (Keşfet)، أصوات الاستطلاعات، ردود طلبات المشاركة في الفعاليات، الملاحظات والاقتراحات، ونصوص الدعم والاعتراض، والنبذة التعريفية |
| معاملات العميل / الاستخدام | عضويات المجتمعات، المشاركة في الفعاليات وتسجيل الحضور، المفضلات، علاقات المتابعة، تفضيلات الإشعارات والخصوصية، قائمة الحظر، سجل حملات الإعلانات البريدية للمسؤولين التي وصلتك (الحملة وحالة التسليم) |
| الخطة الشخصية | جدول الدروس والمقررات والفصول الدراسية وسجلات الامتحانات التي يدخلها المستخدم بنفسه |
| أمن المعاملات | معلومات الجلسة، الملخص المجزّأ لكلمة المرور، الملخص غير القابل للعكس لمعرّف الجهاز، عنوان IP، المنصة وإصدار التطبيق، سجلات حظر الوصول، الأخطاء ومحاولات تسجيل الدخول |
| الإجراءات القانونية / الامتثال | سجلات الموافقة على الاتفاقيات، سجلات الشكاوى/البلاغات والإشراف، سجلات وصول المديرين |
| التسويق | لا يُعالَج (لا تجري أي معالجة لأغراض الإعلان/التسويق). والرسائل البريدية التي يرسلها المسؤولون هي إعلانات خدمة ومجتمع، وفي كل رسالة رابط لإلغاء الاشتراك |
| البيانات ذات الطبيعة الخاصة | لا تُطلب عمداً. أما البيانات ذات الطبيعة الخاصة التي تشاركونها ضمن محتوى المستخدم (مثل الرسائل) فتُستضاف في حدود مشاركتكم فقط، ولا نهدف إلى معالجتها. |

## 3. أغراض المعالجة

1. إنشاء العضوية، والتحقق من الهوية والبريد الإلكتروني، وأمن الحساب.
2. تقديم خدمات الأخبار والإعلانات والفعاليات وقائمة الطعام والمجتمعات وتسجيل الحضور والمراسلة والبحث والمفضلات.
3. إرسال الإشعارات (داخل التطبيق، الفورية، البريد الإلكتروني).
4. تنفيذ طلبات الدعم والملاحظات والاعتراضات.
5. الأمن، ومنع إساءة الاستخدام والتحايل على حظر المستخدمين المحظورين، والإشراف.
6. تحسين الخدمة، ومتابعة الأخطاء والأداء (تحليل مجمَّع).
7. الوفاء بالالتزامات القانونية، والاستجابة لطلبات الجهات المختصة، وممارسة الحقوق والدفاع عنها.
8. حفظ سجلات الاتفاقيات والموافقات.
9. تقديم خدمات المنشورات والمتابعة والمفضلات والاستطلاعات والجدول الدراسي الشخصي؛ وإرسال الإعلانات البريدية للمسؤولين.
10. التصفية الآلية للألفاظ غير اللائقة في المساحات العامة وتنفيذ الشكاوى.

## 4. الأسس القانونية

| السبب القانوني | أمثلة على أنشطة المعالجة |
|---|---|
| م.5/2-(a) النص عليه صراحةً في القوانين | إعطاء المعلومات للجهات المختصة، والسجلات التي تفرضها التشريعات |
| م.5/2-(c) إبرام العقد أو تنفيذه | العضوية، الملف الشخصي، المراسلة، خدمات المجتمعات/الفعاليات، إرسال الإشعارات والبريد الإلكتروني |
| م.5/2-(ç) وفاء المسؤول عن البيانات بالتزامه القانوني | سجلات الموافقة على الاتفاقيات، الطلبات القانونية، الحفظ وفق التشريعات ذات الصلة |
| م.5/2-(e) تقرير حق أو ممارسته أو حمايته | آثار الإشراف، والسجلات ذات القيمة الإثباتية للاعتراضات والنزاعات |
| م.5/2-(f) المصلحة المشروعة (بشرط عدم الإضرار بالحقوق والحريات الأساسية) | الأمن، سجل الجهاز/IP، تحديد المعدل، رقابة وصول المديرين، التحليلات |
| م.5/1 الموافقة الصريحة | العمليات **الاختيارية** مثل مطابقة جهات الاتصال، وإذن الإشعارات الفورية، ونشر حقول الملف الشخصي الاختيارية |

(يجوز أن يكون البندان م.5/2-(ç) وم.5/2-(e) أساساً مشتركاً في العمليات ذات الصلة.)

## 5. نقل البيانات الشخصية

| فئة المستلمين | البيانات المنقولة | الغرض | داخل البلاد / خارجها |
|---|---|---|---|
| مزوّدو الاستضافة والبنية التحتية (معالج البيانات) | بيانات الخدمة (الرسائل مشفّرة) | استضافة الخدمة | {{hosting.location|يُبلَّغ موقع الاستضافة لاحقاً من المسؤول عن البيانات}} |
| مزوّد خدمة إرسال البريد الإلكتروني: Brevo (SMTP؛ معالج البيانات) | البريد الإلكتروني للمستلم، محتوى الرسالة؛ وفي الإعلانات الاسم والقسم/الكلية/السنة لأغراض التخصيص | رسائل التحقق/إعادة تعيين كلمة المرور/الأمن وإعلانات المسؤولين | **قد يكون خارج البلاد** (قد توجد خوادم المزوّد في أوروبا أو بلدان أخرى) |
| مزوّد الإشعارات: Google LLC (Firebase Cloud Messaging) وApple Inc. (APNs) لنظام iOS | مفتاح إشعارات الجهاز، عنوان الإشعار/نصه القصير، معلومة الوجهة، المنصة | إيصال الإشعارات الفورية | **خارج البلاد** |
| الجهات والمؤسسات العامة المختصة (المحكمة، النيابة، الضابطة العدلية، هيئة حماية البيانات الشخصية وغيرها) | البيانات ضمن نطاق الطلب | الالتزام القانوني | داخل البلاد |
| الوحدات المعنية في جامعة بينغول / المديرون المخوَّلون | البيانات اللازمة للإشراف والدعم والأمن | إدارة الخدمة | داخل البلاد |

**النقل إلى الخارج (م.9).** لأجل الإشعارات الفورية، يُنقل مفتاح إشعارات جهازكم ومحتوى الإشعار إلى الخارج عبر Firebase/APNs. ويستند هذا النقل، في إطار المادة 9 من القانون وأنظمة هيئة حماية البيانات الشخصية ذات الصلة، إلى **موافقتكم الصريحة المبنية على إذن الإشعارات** و/أو إلى آليات الكفاية/الضمانات المناسبة (العقد النموذجي وغيره). وإن لم تمنحوا إذن الإشعارات فلن تتلقوا إشعارات فورية، لكن صندوق الإشعارات داخل التطبيق وسائر الخدمات تواصل العمل. ويمكنكم سحب موافقتكم في أي وقت من إعدادات الجهاز أو من إعدادات الأذونات/الإشعارات في التطبيق. وقد توجد خوادم مزوّد خدمة إرسال البريد الإلكتروني (Brevo) خارج البلاد أيضًا؛ وقد يُنقل عنوان بريدكم ومحتوى الرسالة إلى هذا المزوّد لإيصال رسائل التحقق وإعادة تعيين كلمة المرور والإعلانات، ويستند هذا النقل كذلك إلى آليات المادة 9 المذكورة أعلاه.

## 6. طريقة جمع البيانات الشخصية

تُجمع بياناتكم عبر التطبيق والموقع الإلكتروني في البيئة الإلكترونية، بطرق آلية وشبه آلية، من خلال نماذج التسجيل/الملف الشخصي، والمراسلة ومشاركة المحتوى، ونماذج الدعم، والاتصال التقني لجهازكم (IP، ملخص الجهاز، إصدار التطبيق)، والتخزين المحلي الشبيه بملفات تعريف الارتباط، و(إذا منحتم الإذن) طلب مطابقة جهات الاتصال. أما محتويات الأخبار وقائمة الطعام فتُجمع من مصادر عامة لا تتضمن بيانات شخصية.

## 7. مدة الحفظ

تُحفظ البيانات الشخصية للمدة اللازمة لغرض المعالجة وللمدة المنصوص عليها في التشريعات ذات الصلة، وعند انتهاء المدة تُحذف أو تُتلف أو تُجعل مجهولة الهوية. أبرز المدد: التسجيل المعلّق ساعة واحدة؛ رمز التحقق 10 دقائق؛ مفتاح التجديد 30 يوماً على الأكثر؛ الإشعار المقروء 30 يوماً وغير المقروء 90 يوماً (أحدث 200 لكل مستخدم)؛ مفتاح إشعارات الجهاز إذا لم يُشاهَد 60 يوماً؛ سجلات أمن الجهاز/IP 90 يوماً؛ سجل مرشّح الألفاظ غير اللائقة 90 يوماً؛ سجل طابور push بعد 7 أيام من الإرسال (30 يوماً إن فشل)؛ أحداث التحليلات الخام 45 يوماً (وبعدها تبقى فقط ملخصات مجمّعة غير مرتبطة بالأشخاص)؛ سجل النشاط اليومي 400 يوم؛ طابور البريد الإلكتروني: المرسل 7 أيام والفاشل 30 يوماً؛ سجلات حملات الإعلانات البريدية للمسؤولين 180 يوماً بعد انتهاء الحملة؛ سجل إجراءات المسؤولين 365 يوماً؛ سجلات الوصول إلى الرسائل وإجراءات النوادي 730 يوماً؛ النسخة المشفّرة من الصورة ذات الإرسال الواحد 365 يوماً؛ طلب الدعم العام 365 يوماً. وما دام الحساب مفتوحاً يُحفظ ملفكم الشخصي ومحتوياتكم؛ وقد تُحفظ بشكل مستقل لأغراض الأمن/الإثبات النسخة المشفّرة من الرسائل المحذوفة وسجلات الموافقة على الاتفاقيات. الجدول التفصيلي: [الحفظ والإتلاف](/legal/retention).

## 8. وصول المديرين إلى الرسائل (ملاحظة شفافية)

تُخزَّن الرسائل مشفّرة على الخادم، لكن النظام ليس مشفّراً من طرف إلى طرف. يجوز للمديرين المخوَّلين عرض الرسائل والوسائط لأسباب مثل مراجعة الشكاوى والأمن وإساءة الاستخدام والطلبات القانونية، ويُسجَّل كل عرض تلقائياً وبشكل غير قابل للتعديل. والسبب القانوني لهذا النشاط هو المصلحة المشروعة والالتزام القانوني (م.5/2-(f)، (ç)، (e))؛ والتفصيل في البند 3 من [سياسة الخصوصية](/legal/privacy).

## 9. اتخاذ القرارات الآلية

لا تتخذ الخدمة بحقكم قراراً يرتب نتيجة قانونية بالمعالجة الآلية وحدها. فإذا تراكمت سجلات انتهاك متعددة على الحساب نفسه، فإن النظام يولّد لمدير **توصية** فقط؛ أما قرار التعليق فيتخذه مدير. وتوجد تدابير آلية مثل تحديد المعدل، والتحقق من ملخص المحتوى المحظور، ومرشّح الألفاظ غير اللائقة في المساحات العامة؛ ويجوز للمرشّح أن يرفض محتوى تلقائياً (رسائل المحادثات غير خاضعة لهذه الرقابة)، ويمكنكم تقديم اعتراضكم من قسم الدعم. أما القرارات التي ترتب نتائج دائمة على حسابكم فيتخذها مدير.

## 10. حقوقكم (م.11)

يمكنكم بالتقدم إلى المسؤول عن البيانات أن تطلبوا ما يأتي:

1. معرفة ما إذا كانت بياناتكم الشخصية قد عُولجت،
2. طلب المعلومات المتعلقة بها إن كانت قد عُولجت،
3. معرفة غرض المعالجة وما إذا كانت تُستخدم وفق غرضها،
4. معرفة الأطراف الثالثة التي نُقلت إليها داخل البلاد أو خارجها،
5. طلب تصحيحها إن كانت ناقصة أو غير صحيحة،
6. طلب حذفها أو إتلافها في إطار الشروط الواردة في المادة 7 من القانون،
7. طلب إبلاغ الأطراف الثالثة التي نُقلت إليها البيانات بالعمليات المنفَّذة وفق البندين (5) و(6)،
8. الاعتراض على ظهور نتيجة ضدكم بسبب تحليل البيانات المعالَجة حصراً بوساطة أنظمة آلية،
9. المطالبة بتعويض الضرر إذا لحق بكم ضرر بسبب معالجة مخالفة للقانون.

الاختصارات داخل التطبيق: تعديل الملف الشخصي وإعدادات الخصوصية (التصحيح/التحكم في النشر)، **تنزيل بياناتي** (الاطلاع/النسخة)، **حذف الحساب** (الحذف/إخفاء الهوية).

## 11. طريق التقديم

1. **داخل التطبيق:** أنشئوا طلباً من قسم الدعم بموضوع "طلب بشأن البيانات الشخصية" (يُتحقق من هوية المستخدم المسجّل دخوله عبر الحساب).
2. **كتابةً:** بعريضة موقّعة بخط اليد{{?controller.address}} إلى العنوان {{controller.address}}{{/controller.address}} تسليماً باليد أو عبر كاتب العدل.
{{?controller.kep}}3. **KEP:** تقديم موقّع بتوقيع إلكتروني آمن إلى العنوان {{controller.kep}}.{{/controller.kep}}
{{?controller.email}}4. **البريد الإلكتروني:** إلى العنوان {{controller.email}} من عنوان بريدكم المؤسسي المسجّل.{{/controller.email}}

يجب أن يتضمن طلبكم: الاسم واللقب، ومعلومة تفيد في التحقق من الهوية (بريد الحساب الإلكتروني)، وعنوان التبليغ، وموضوع الطلب. وقد نطلب معلومات إضافية للتحقق من هويتكم. وتُنجَز الطلبات مجاناً **في موعد أقصاه 30 يوماً** بحسب طبيعة الطلب؛ وإن استلزمت العملية كلفة إضافية فقد تُتقاضى الرسوم وفق التعرفة التي تحددها الهيئة.

وفي حال رفض الطلب، أو عدم كفاية الرد، أو عدم الرد في المدة المحددة، يحق لكم **تقديم شكوى إلى هيئة حماية البيانات الشخصية** خلال 30 يوماً من تاريخ علمكم بالرد، وعلى أي حال خلال 60 يوماً من تاريخ التقدم بالطلب.$c_kvkk_ar$, FALSE, TRUE);
END
$do_kvkk$;
