# Bildirim görünümü (Android emülatör kanıtı)

Kapsam: bir push bildirimi cihaza ulaşınca NASIL göründüğü. Üretim sunucusuna/FCM'e hiçbir istek atılmadı; FCM'in cihaza teslim ettiği mesaj emülatörde yerelde simüle edildi. Görüntü klasörü: `C:\bu_qa\shots\tasarim\bildirim\` (aşağıda yalnız dosya adı verilir; ad kalıbı `android_<kanal>_<durum>_<dil>.png`).

## Nasıl simüle edildi
- Cihaz: `emulator-5554`, Android 15 (API 35, Google APIs), 1080x2400, açık tema, cihaz dili İngilizce (uygulama dili İngilizce; bildirim metinleri yükte kendi dilinde).
- Yük, backend'in gerçekte gönderdiğiyle aynıdır (`FirebaseFcmSender.android` + `PushMessages.of` + `PushPayload.build`): `notification{title,body}` bloğu + `android_channel_id` + `tag` (= sohbet için `conv:<id>`, `news-3`, `event-7`, `poll-5`, `post-9`...) + `sound=default` + `data` (`type`, `target/value`, `targetType/targetId`, `conversationId`..., `channelId`, `threadId`, `tag`). Renk ve küçük simge yükte YOKTUR; manifestteki varsayılanlar (`default_notification_icon=ic_stat_bu`, `default_notification_color=#F73B2E`, `default_notification_channel_id=announcement`) kullanılır.
- Teslim: `adb root` + `am broadcast -p tr.com.bukampus.app -a com.google.android.c2dm.intent.RECEIVE ...` (tüm alıcılara gider: hem `FirebaseInstanceIdReceiver` = arka planda sistem bildirimini çizer, hem `FlutterFirebaseMessagingReceiver` = ön planda Dart `onMessage`). Dikkat: yalnız `FirebaseInstanceIdReceiver`'a `-n` ile göndermek ön plan şeridini TETİKLEMEZ (ilk denemede bu yüzden şerit görünmedi; hata uygulamada değil, simülasyondaydı). Metinler UTF-8 betik dosyasıyla (cihazda `sh`) geçirildi.
- Yerel hatırlatma: uygulamanın kendi `ReminderReceiver` yolu (`LocalReminderStore` ile aynı ekstralar). Alıcı manifestte `.ReminderReceiver` (ad alanı `edu.bingol.bu_kampus`); `am` ile tam sınıf adı gerekir.
- Dokunma testleri yalnız gezidir (kimliği olmayan sahte kayıtlara gidildiği için "bulunamadı" ekranları beklenen davranıştır); oturumda hiçbir yazma/ayar değişikliği yapılmadı. Kilit ekranı için emülatöre geçici PIN konup görüntüden sonra kaldırıldı.

## Görüntüler

| Durum | Dosya | Ne görünüyor |
|---|---|---|
| Sohbet, başlık üstü (heads-up), TR | `android_chat_headsup_tr.png` | Kırmızı daire içinde beyaz "BÜ" küçük simge (durum çubuğunda da beyaz tek renkli "BÜ"), "BÜ Kampüs" uygulama adı, başlık "Ayşe Yılmaz", gövde "Yeni mesaj", çan simgesi (ses/titreşim), sağda aç/kapa oku. Vurgu rengi marka kırmızısı. |
| Sohbet heads-up, EN | `android_chat_headsup_en.png` | Aynı kart; "Ayse Yilmaz / New message". |
| Sohbet heads-up, AR | `android_chat_headsup_ar.png` | Arapça başlık/gövde doğru bağlanmış ve okunur; hizalamayı Android cihaz dili (EN, soldan sağa) belirler, metin kırpılmaz. |
| Sohbet, uzun metin heads-up | `android_chat_headsup_tr_long.png` | Başlık "Bilgisayar Mühendisliği 3. Sınıf D…" tek satırda üç nokta ile kırpılır, gövde tek satır + "…". |
| Sohbet, uzun metin gölgede açılmış | `android_chat_golge_tr_long.png` | Kapalıyken iki satır kırpılı; açılınca (BigText) tüm gövde görünür. |
| Duyuru/haber, gölge (genişletilmiş), TR | `android_announcement_golge_tr.png` | "3 yeni duyuru" + 3 satıra yayılan tam gövde (BigText), marka rengi simge. Kanal önemi normal: başlık üstü çıkmaz, sesli. |
| Duyuru, EN / AR | `android_announcement_golge_en.png`, `android_announcement_golge_ar.png` | EN düzgün; AR gövde 2 satıra sarılır, Arapça-Hint rakamlar (٢٠٢٥-٢٠٢٦) doğru. |
| Etkinlik, gölge TR / EN / AR | `android_event_golge_tr.png`, `_en.png`, `_ar.png` | "Etkinlik 1 saat içinde başlıyor / Event starts in 1 hour / تبدأ الفعالية خلال ساعة" + etkinlik adı. Kanal "event" normal önem (heads-up yok). |
| Anket, gölge TR / AR | `android_poll_golge_tr.png`, `_ar.png` | "Yeni anket / استطلاع جديد" + soru metni. |
| Sosyal (beğeni), gölge TR / EN | `android_social_golge_tr.png`, `_en.png` | "Silent" bölümünde sessiz kart (LOW): çan simgesi yok, ses/titreşim yok, yalnız başlık (gövde boş). |
| Akademik push, gölge | `android_academic_golge_tr.png` | "Sınav hatırlatması / Veri Yapıları vizesi yarın 10:00, B-204". |
| Yerel hatırlatma (ReminderReceiver), heads-up + gölge | `android_academic_headsup_yerel_hatirlatma_tr.png`, `android_academic_golge_yerel_hatirlatma_tr.png` | "Veri Yapıları dersi 30 dk sonra / B-204 • 10:00 • Dr. Öğr. Üyesi Ahmet Yıldırı…": academic kanalı HIGH olduğu için başlık üstü; tek renkli BÜ simge, kırmızı vurgu. |
| Hepsi bir arada, gölge (kapalı grup) | `android_hepsi_golge_tr.png` | Android aynı uygulamanın bildirimlerini tek grupta toplar ("10" sayacı); başlıklar tek satır özet olarak sıralanır. |
| Grup genişletilmiş | `android_grup_genisletilmis_tr.png`, `android_grup_genisletilmis_tr_2.png` | Her bildirim ayrı kart; sohbet başına yalnız TEK kart (aynı `tag` eskisinin yerine geçer: `conv:42` tekrarlanınca çoğalmaz). |
| Kilit ekranı | `android_hepsi_kilit_ekrani_tr.png` | Kilitli cihazda 3 bildirim tek kartta ("3" sayacı), ilk iki satır: "Ayşe Yılmaz / Yeni mesaj", "Etkinlik 1 saat içinde başlıyor". Sohbette mesaj metni YOKTUR (önizleme varsayılan kapalı, KVKK dostu). |
| Ön plan şeridi (PushBanner), sohbet TR | `android_chat_onplan_banner_tr.png` | Üstten inen beyaz kart: kişi avatarı + sohbet rozeti, kalın başlık, gövde, "now", kapat (X), altta "Tap to reply". |
| Ön plan şeridi, sohbet AR | `android_chat_onplan_banner_ar.png` | Arapça başlık/gövde, kart bozulmaz. |
| Ön plan şeridi, uzun metin | `android_chat_onplan_banner_tr_long.png` | Başlık 1 satır + "…", gövde 2 satır + "…". |
| Ön plan şeridi, sohbet dışı (düzeltme sonrası) | `android_event_onplan_banner_tr.png`, `android_announcement_onplan_banner_ar.png`, `android_poll_onplan_banner_tr.png`, `android_social_onplan_banner_tr.png`, `android_academic_onplan_banner_tr.png` | Kişi silueti yerine hedefe uygun simge karosu (takvim / megafon / anket listesi / görsel / mezuniyet kepi). Sosyalde gövde yok: başlık 2 satıra kadar açılır ("Mehmet Demir gönderini beğendi"). |
| Dokunma: haber | `android_announcement_dokun_haber_tr.png` | Haber detayı açılır (gerçek kayıt). |
| Dokunma: etkinlik | `android_event_dokun_etkinlik_tr.png` | Etkinlik sayfası ("Event not found": sahte kimlik). |
| Dokunma: anket | `android_poll_dokun_anket_tr.png` | Anket sayfası ("Poll not found": sahte kimlik). |
| Dokunma: sınav (akademik push) | `android_academic_dokun_sinav_tr.png` | Sınavlar ekranı. |
| Dokunma: sohbet | `android_chat_dokun_sohbet_tr.png` | Kimlik 42 sunucuda yok -> kural gereği Bildirimler listesine düşer (`PushRouter`); gerçek sohbet kimliğiyle doğrudan sohbet açılır (kod yolu `push_notify_test`). |
| Dokunma: yerel hatırlatma | `android_academic_dokun_yerel_hatirlatma_tr.png` | Ders programı ekranı. |

## Bulgular ve düzeltmeler
1. **Küçük simge / vurgu rengi / kanallar: kusur yok.** `ic_stat_bu` (5 yoğunlukta) yalnız beyaz + saydam (tek renkli silüet), durum çubuğunda ve kartta renkli kutu çıkmıyor; `notification_accent` #F73B2E uygulanıyor (FCM yükü renk göndermese de manifest varsayılanı çalışıyor); 6 kanal oluşuyor, önemler beklendiği gibi: chat/academic HIGH (4), event/announcement/poll DEFAULT (3), social LOW (2). Kanal adı/açıklaması `strings.xml` (tr/en/ar) + Dart `setChannelNames`.
2. **Düzeltildi: ön plan şeridinde sohbet dışı bildirimler kişi silueti gösteriyordu** (etkinlik, anket, haber, beğeni... için yanıltıcı). `push_banner.dart`: sohbet değilse hedef türünden (`resolvePushTarget`) simge karosu (`bannerIcon`, saf fonksiyon + test). Sohbet şeridi aynı. Gövdesi boş olan bildirimde başlık 2 satıra açılır. Rota/hedef çözümleme mantığına DOKUNULMADI.
3. Bilinçli/bilinen (değiştirilmedi): (a) Android'de FCM sohbet başına tek kart bırakır (`tag`), gruplama "Mesajlar" altında InboxStyle toplamı yoktur; son mesaj öncekinin yerine geçer. (b) `event` kanalı DEFAULT; backend `PushMessages` yorumu "event HIGH" der ama kanal önemi istemcide DEFAULT'tur ve kanal oluştuktan sonra kod tarafından yükseltilemez (yalnız yeni kurulumlarda değişir); etkinlik hatırlatmasının başlık üstü çıkması istenirse kanal kimliği/önemi ayrı bir kararla (yeni kanal kimliği) değişmeli. (c) Yükte büyük simge/avatar yoktur (FCM `notification` bloğu bunu desteklemez; iOS gibi uygulama simgesi küçük simge olarak gelir). (d) Sessiz saat ve tür tercihi SUNUCUDA uygulanır; bu doğrulamada sunucu yoktu.

## Doğrulanamayanlar
- Gerçek FCM teslimi (Firebase -> Play Hizmetleri -> cihaz) ve sunucudan gerçek bildirim: üretime istek atılmadığı için denenmedi; yük biçimi koddan çıkarılıp yerelde taklit edildi.
- Gerçek cihaz (Redmi 13C vb.) üretici katmanları (MIUI otomatik başlatma/pil), ses/titreşim duyulması, Android 13+ izin istemi (emülatörde izin zaten verilmiş; akış kod okunarak incelendi), kilit ekranı gizli içerik ayarları farklı üreticilerde.
- iOS: Windows'ta derlenemez; görünüm `docs/MOBILE_PUSH.md` "iOS'ta bildirim nasıl görünür" bölümünde koddan türetilmiştir, cihazda DENENMEDİ; iOS için görüntü/maket üretilmedi.
