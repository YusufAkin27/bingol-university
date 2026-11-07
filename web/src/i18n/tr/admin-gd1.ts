// Yönetim paneli Yedekleme (Google Drive) sayfası (GD1): durum kartları + adım adım kurulum rehberi.
// Yönetim paneli YALNIZ Türkçedir: bu dosyanın en/ar karşılığı yazılmaz; i18n/bundles/admin-tr-only.ts en/ar
// sözlüklerine aynı Türkçe metni katar ve scripts/check-i18n.mjs bu dosyayı en/ar eşitliği denetiminden muaf tutar.
export default {
  'admin.gd1.title': 'Yedekleme (Google Drive)',
  'admin.gd1.desc':
    'Veritabanı ve yüklenen dosyaların yedekleri saatlik olarak sunucuda alınır; günde bir kez şifreli olarak Google Drive’a da taşınır. Bu sayfa durumu gösterir ve kurulumu adım adım anlatır; hiçbir parola veya belirteç istemez.',
  'admin.gd1.refresh': 'Yenile',

  'admin.gd1.status.heading': 'Yedek durumu',
  'admin.gd1.sentence.good': 'Her şey yolunda: son yedek {ago} alındı ve Google Drive kopyası doğrulandı.',
  'admin.gd1.sentence.late': 'Yedek gecikmiş olabilir: son başarılı yedek {ago}. Aşağıdaki kartlara bakın.',
  'admin.gd1.sentence.driveError': 'Google Drive kopyası alınamıyor; son yerel yedek {ago}. Ayrıntı Drive kartında.',
  'admin.gd1.status.unavailable': 'Durum bilgisi henüz alınamıyor (sunucu bu bilgiyi vermiyor). Kurulum rehberi aşağıdadır.',
  'admin.gd1.status.error': 'Durum bilgisi alınamadı.',

  'admin.gd1.warn.localOnly.title': 'Yedekler yalnız sunucu diskinde',
  'admin.gd1.warn.localOnly':
    'Google Drive henüz kurulmadı. Sunucu diski ya da hesabı giderse yedekler de gider. Aşağıdaki rehberle Drive’ı bağlayın.',
  'admin.gd1.warn.localOnly.go': 'Kurulum rehberine git',

  'admin.gd1.card.last': 'Son başarılı yedek',
  'admin.gd1.card.last.none': 'Henüz başarılı yedek yok',
  'admin.gd1.card.last.schedule':
    'Yerel yedek zamanlaması (Europe/Istanbul): {cron}',
  'admin.gd1.card.last.verify': 'Geri yükleme doğrulaması: {cron}',
  'admin.gd1.card.last.remoteCron':
    'Drive’a yükleme (günde 1): {cron}',
  'admin.gd1.fresh.FRESH': 'Güncel',
  'admin.gd1.fresh.STALE': 'Gecikmiş',
  'admin.gd1.fresh.OLD': 'Eski',
  'admin.gd1.fresh.FAILED': 'Son deneme başarısız',
  'admin.gd1.fresh.NONE': 'Bilinmiyor',

  'admin.gd1.ago.now': 'az önce',
  'admin.gd1.ago.min': '{n} dk önce',
  'admin.gd1.ago.hour': '{n} sa önce',
  'admin.gd1.ago.day': '{n} gün önce',

  'admin.gd1.card.drive': 'Google Drive durumu',
  'admin.gd1.drive.OK': 'Bağlı ve doğrulandı',
  'admin.gd1.drive.PENDING':
    'Bağlı, ilk yükleme/doğrulama bekleniyor',
  'admin.gd1.drive.NOT_CONFIGURED': 'Kurulmadı',
  'admin.gd1.drive.ERROR': 'Hata',
  'admin.gd1.drive.UNAVAILABLE': 'Bilinmiyor',
  'admin.gd1.drive.target': 'Hedef: {name}',
  'admin.gd1.drive.kind': 'Tür: {kind}',
  'admin.gd1.drive.verified': 'Son doğrulama: {when}',
  'admin.gd1.drive.uploaded': 'Son yükleme: {when}',
  'admin.gd1.drive.lastError': 'Son hata: {error}',
  'admin.gd1.drive.notConfigured': 'Yedekler yalnız sunucu diskinde.',

  'admin.gd1.card.local': 'Sunucudaki yedekler',
  'admin.gd1.card.remote': 'Drive’daki yedekler',
  'admin.gd1.card.count': '{n} yedek',
  'admin.gd1.card.oldest': 'En eski: {when}',
  'admin.gd1.card.remote.none': 'Drive kurulmadığı için yedek yok',

  'admin.gd1.card.retention': 'Saklama özeti',
  'admin.gd1.retention.local': 'Sunucu',
  'admin.gd1.retention.remote': 'Drive',
  'admin.gd1.retention.line':
    'Saatlik {d} · haftalık {w} · aylık {m}',
  'admin.gd1.retention.lineRemote':
    'Günlük {d} · haftalık {w} · aylık {m}',

  'admin.gd1.guide.heading': 'Kurulum rehberi',
  'admin.gd1.guide.intro':
    'Adımları sırayla izleyin. Komutlardaki <...> biçimindeki yerleri kendi değerinizle değiştirin. Sunucu komutları /opt/bukampus/current dizininden çalışır. Bu sayfa hiçbir gizli bilgiyi sizden istemez ve saklamaz.',
  'admin.gd1.guide.done': 'Google Drive bağlı görünüyor. Rehber yalnız başvuru içindir.',
  'admin.gd1.guide.expandAll': 'Tümünü aç',
  'admin.gd1.guide.collapseAll': 'Tümünü kapat',
  'admin.gd1.guide.copy': 'Komutu kopyala: {name}',
  'admin.gd1.guide.codeLabel': 'Komut: {name}',

  'admin.gd1.warn.keyTitle': 'Kurtarma anahtarı sunucuda DEĞİL, kasada olmalı',
  'admin.gd1.warn.key':
    "Yedekler age ile şifrelidir. Kurtarma (özel) anahtarı sunucuda, Drive’da ya da bu depoda durmamalıdır: çevrimdışı kasada ve parola yöneticisinde en az iki yerde saklanır (docs/KEY_MANAGEMENT.md). Anahtar kaybolursa yedekler bir daha açılamaz.",
  'admin.gd1.warn.keyRestore':
    'Geri yükleme için kurtarma age özel anahtarı gerekir; sunucuda bulunmaz, kasadan alınır (docs/KEY_MANAGEMENT.md). CRYPTO_MASTER_KEYS de ayrıca gerekir; yedeğin içinde değildir.',
  'admin.gd1.warn.twoFaTitle': 'Drive hesabında 2 adımlı doğrulama açın',
  'admin.gd1.warn.twoFa':
    'Yedeklerin durduğu Google hesabında 2 adımlı doğrulamayı açın; mümkünse kişisel hesap yerine kuruma ait, ayrılmış bir hesap kullanın. Hesap ele geçirilirse şifreli de olsa yedekler silinebilir.',
  'admin.gd1.warn.testingTitle':
    'OAuth uygulaması "In production" olmalı, "Testing" kalmamalı',
  'admin.gd1.warn.testing':
    'Google Cloud Console > OAuth consent screen > Publishing status değerini "In production" yapın. "Testing" kalırsa Google yenileme belirtecini 7 günde geçersiz kılar ve yedek bir hafta sonra invalid_grant hatasıyla durur. drive.file hassas olmayan bir kapsamdır; üretime almak Google doğrulaması beklemez.',
  'admin.gd1.warn.tokenTitle': 'Çıkan belirteç bir sırdır',
  'admin.gd1.warn.token':
    'Çıkan JSON belirteci Drive erişimi verir. Yalnızca sunucudaki rclone.conf dosyasına yazın; sohbete, e-postaya, destek talebine veya bu panele yapıştırmayın.',
  'admin.gd1.warn.deleteTitle': 'Silme işlemi geri alınamaz',
  'admin.gd1.warn.delete':
    'Sunucudaki yedekler silindikten sonra tek kopya Drive’da kalır. Önce 6. adımda Drive durumunun yeşil olduğunu ve bir geri yükleme denemesinin geçtiğini görün; her zaman önce kuru çalıştırın. Betik yalnız Drive’da doğrulanmış kopyası olan yedekleri siler ve en yeni 2 yedeği her zaman yerelde bırakır.',

  'admin.gd1.step.why.title': '0. Neden ve özet',
  'admin.gd1.step.why.lead':
    'Amaç: yedekleri yalnız sunucu diskinde bırakmayıp Google Drive’a taşımak, sunucuyu rahatlatmak. Drive hesabı 15 GB’a kadar ücretsizdir; Drive’da en çok yaklaşık 15 yedek klasörü tutulur (7 günlük + 4 haftalık + 6 aylık, üst üste biner).',
  'admin.gd1.step.why.enc':
    'Yedekler Drive’a gitmeden önce age ile şifrelenir; Drive yalnız şifreli veriyi görür. Kurulum kendi bilgisayarınızda bir kez izin vermeyi, sonra sunucuda bir ayar dosyası ve birkaç ortam değişkeni eklemeyi kapsar.',
  'admin.gd1.step.why.rpo':
    'Saatlik yedek sunucuda kalır; Drive’a GÜNDE 1 kez (varsayılan 03:35) en yeni yedek gider. Bu yüzden Drive kopyası en kötü durumda yaklaşık 24 saat gerididir (RPO); son saatler yalnız sunucu diskindedir. Her saat tam yükleme Drive kotasını ve günlük yükleme sınırını tüketir, bu yüzden yapılmaz.',

  'admin.gd1.step.install.title':
    '1. Kendi bilgisayarınıza rclone kurun',
  'admin.gd1.step.install.lead': 'Bu adım sunucuda değil, kendi bilgisayarınızda yapılır. Yalnız izin vermek için gereklidir.',
  'admin.gd1.step.install.win': 'Windows',
  'admin.gd1.step.install.mac': 'macOS',
  'admin.gd1.step.install.check': 'Kurulumu denetle',
  'admin.gd1.step.install.alt': 'Paket yöneticisi yoksa rclone.org/downloads adresinden indirin.',
  'admin.gd1.step.client.title':
    '2. (Önerilir) Kendi OAuth istemci kimliğinizi oluşturun',
  'admin.gd1.step.client.lead':
    'rclone’un yerleşik client_id değeri tüm rclone kullanıcılarıyla paylaşılır; yoğun saatlerde 403 rateLimitExceeded alabilirsiniz. Kendi kimliğinizi bir kez, yaklaşık 10 dakikada oluşturun.',
  'admin.gd1.step.client.steps':
    'console.cloud.google.com adresinde yeni proje açın > APIs & Services > Library > Google Drive API > Enable > OAuth consent screen (User type: External, uygulama adı, destek e-postası, kapsam olarak .../auth/drive.file) > Publishing status: In production.',
  'admin.gd1.step.client.creds':
    'Sonra Credentials > Create credentials > OAuth client ID > Application type: Desktop app. Çıkan Client ID ve Client secret’ı not edin; Client secret bir sırdır, yalnız rclone.conf dosyasında ve parola yöneticinizde durur.',
  'admin.gd1.step.client.skip':
    'Bu adımı atlarsanız sonraki adımlardaki client_id ve client_secret değerlerini kullanmayın (rclone yerleşik kimliği kullanır; hız sınırı riskini kabul edersiniz).',

  'admin.gd1.step.authorize.title':
    '3. Google hesabınıza izin verin (rclone authorize)',
  'admin.gd1.step.authorize.lead':
    'Komut tarayıcıyı açar. Yedeklerin duracağı Google hesabıyla giriş yapıp izin verin. İstenen kapsam drive.file’dır: rclone yalnız kendi oluşturduğu dosyaları görür, Drive’daki diğer dosyalarınıza erişemez. Kendi istemci kimliğinizi 2. adımda oluşturduysanız aşağıdaki ilk komutu kullanın.',
  'admin.gd1.step.authorize.cmd':
    'İzin komutu (kendi istemci kimliğinizle)',
  'admin.gd1.step.authorize.cmdBuiltin':
    'İzin komutu (kendi istemci kimliğiniz yoksa)',
  'admin.gd1.step.authorize.after':
    'İşlem bitince terminalde süslü parantezle başlayıp biten tek satırlık JSON çıkar (access_token ve refresh_token içerir). Tamamını kopyalayın; 4. adımda kullanacaksınız.',

  'admin.gd1.step.conf.title':
    '4. Sunucuda rclone.conf dosyasını oluşturun',
  'admin.gd1.step.conf.lead':
    'Sunucuya SSH ile bağlanın. Dosyayı depo içine değil, kalıcı veri dizinine (/opt/bukampus-data/rclone) koyun: her dağıtım yeni bir sürüm dizinine açılır ve depo içindeki deploy/rclone yeni sürümde boş gelir. Şablondaki yer tutucuları 2. ve 3. adımdaki değerlerle değiştirin.',
  'admin.gd1.step.conf.ssh': 'Sunucuya bağlanın',
  'admin.gd1.step.conf.mkdir':
    'Kalıcı dizini oluşturun',
  'admin.gd1.step.conf.edit':
    'Dosyayı açın ve şablonu yapıştırın',
  'admin.gd1.step.conf.template': 'Dosya içeriği (şablon)',
  'admin.gd1.step.conf.perm':
    'İzinleri kısıtlayın',
  'admin.gd1.step.conf.permWhy':
    'İzin ve sahipliği elle ayarlamayın (chown 70:70 / chmod 400 yapmayın). Yedek konteyneri her açılışta dizini ve dosyayı postgres (uid 70) sahipliğine alır ve dosyayı 0600 yapar; başkası okuyamaz. Dizin yazılabilir bağlanır çünkü rclone yenilenen erişim belirtecini dosyaya geri yazar; dosya salt okunur olursa her çalışmada Failed to save new token hatası çıkar. Sonradan düzenlemek için sudo gerekir. Dosya depoya (git) eklenmez.',

  'admin.gd1.step.env.title':
    '5. Ortam değişkenlerini ekleyip yedek servisini yeniden oluşturun',
  'admin.gd1.step.env.lead':
    '/opt/bukampus/.env.prod dosyasına rclone dizinini, Drive hedefini ve Drive saklama sayılarını ekleyin. Sonra yedek ve arka uç servislerini yeniden oluşturun (yeni imaj; kısa kesinti yalnız bu ikisinde olur).',
  'admin.gd1.step.env.edit':
    'Dosyayı açın',
  'admin.gd1.step.env.vars':
    'Eklenecek satırlar',
  'admin.gd1.step.env.up':
    'Yedek ve arka uç servislerini yeniden oluşturun',
  'admin.gd1.step.env.keep':
    'BACKUP_REMOTE_KEEP_* Drive’daki saklamayı (7 günlük + 4 haftalık + 6 aylık), BACKUP_KEEP_* ise sunucudaki saatlik yedeklerin saklamasını belirler (7. adım). BACKUP_REMOTE_SCHEDULE=daily Drive’a günde 1 yükleme demektir (her saat yüklemek için each, önerilmez). Yükleme saati BACKUP_REMOTE_CRON ile değişir (varsayılan 35 3 * * *).',

  'admin.gd1.step.verify.title':
    '6. Denemeyi yapın ve ilk yüklemeyi bekleyin',
  'admin.gd1.step.verify.lead':
    'Önce Drive erişimini ve kuru çalışmayı deneyin: kuru çalışma ne yükleneceğini, boş alanı ve yüklemeden sonra silinecek eski klasörleri yazar, hiçbir şeyi değiştirmez.',
  'admin.gd1.step.verify.access':
    'Drive’a erişimi denetleyin',
  'admin.gd1.step.verify.dry': 'Kuru deneme',
  'admin.gd1.step.verify.run':
    'Gerçek ilk yükleme (boyuta göre dakikalar sürebilir) ve günlük',
  'admin.gd1.step.verify.ls': 'Drive’daki klasörü listeleyin',
  'admin.gd1.step.verify.page':
    'Başarılı çıktıda UZAK KOPYA TAMAM ve dogrulandi satırı görünür. Bu sayfayı yenileyin: Google Drive durumu Bağlı ve doğrulandı olmalı ve Drive’daki yedekler kartında adet görünmelidir. Bundan sonra yükleme her gün kendiliğinden yapılır.',

  'admin.gd1.step.prune.title':
    '7. Doğrulandıktan SONRA sunucudaki eski yedekleri azaltın',
  'admin.gd1.step.prune.lead':
    'Önce en az bir kez yüklemenin UZAK KOPYA TAMAM dediğini, panelde son doğrulamanın dolu olduğunu ve geri yükleme provasının (8. adım) geçtiğini görün. Sonra iki kademe: sunucudaki saatlik pencereyi küçültün; ardından betikle yalnız Drive’da doğrulanmış kopyası olan eski yedekleri toplayın.',
  'admin.gd1.step.prune.keep':
    '1. kademe: sunucudaki saklamayı düşürün (.env.prod)',
  'admin.gd1.step.prune.dry':
    '2. kademe: önce kuru çalıştırma (varsayılan, hiçbir şey silmez)',
  'admin.gd1.step.prune.apply':
    'Çıktıyı denetleyin, sonra gerçekten uygulayın',
  'admin.gd1.step.prune.auto':
    'İsterseniz her günlük yüklemeden sonra otomatik (.env.prod)',
  'admin.gd1.step.prune.rule':
    'Drive’da doğrulanmış kopyası olmayan yedek (saatlik, günlüğe girmeyenler) asla silinmez; her katmanda en yeni 2 yedek yerelde kalır. Sunucudaki tüm yedekleri silmeyin: hızlı geri dönüş için en az birkaç saatlik yedek yerelde durmalıdır.',

  'admin.gd1.step.restore.title':
    '8. Geri yükleme (Drive’dan indirme)',
  'admin.gd1.step.restore.lead':
    'Zorunlu: bu adımı bir kez başka bir bilgisayarda deneyin; denenmemiş uzak kopya kopya sayılmaz. Felaket durumunda yedek önce Drive’dan indirilir, bütünlüğü denetlenir, sonra canlıya geri yüklenir.',
  'admin.gd1.step.restore.download': 'İndirin ve özetleri doğrulayın',
  'admin.gd1.step.restore.apply':
    'Geri yükleyin (uygulamayı durdurur, onay ister; sunucuda çalıştırılır)',
  'admin.gd1.step.restore.docs':
    'Ayrıntılar, süreler ve anahtar bağımlılığı: docs/BACKUP_GDRIVE.md (bölüm 10) ve docs/BACKUP_RESTORE.md.',

  'admin.gd1.step.faq.title':
    '9. Sık sorunlar',

  'admin.gd1.faq.grant.q': 'invalid_grant ya da token expired hatası',
  'admin.gd1.faq.grant.a':
    'Yetkilendirme düştü demektir. En sık neden: OAuth uygulaması Google Cloud’da "Testing" durumunda; yenileme belirteci 7 günde geçersiz olur. Çözüm: Publishing status değerini "In production" yapın (2. adım). Diğer nedenler: erişim myaccount.google.com/permissions üzerinden kaldırıldı, belirteç 6 ay kullanılmadı, hesap parolası/güvenlik olayı. Çözümde 3. adımı yeniden uygulayıp rclone.conf içindeki token satırını değiştirin; sonraki çalışma yeni dosyayı okur.',
  'admin.gd1.faq.rate.q': '403 rateLimitExceeded',
  'admin.gd1.faq.rate.a':
    'Google istek sınırına takıldınız (rclone’un ortak yerleşik anahtarı herkesle paylaşılır). Birkaç dakika bekleyin; sürerse 2. adımdaki gibi kendi client_id değerinizi oluşturun ve uygulamayı "In production" yapın.',
  'admin.gd1.faq.quota.q': 'Kota dolu (storageQuotaExceeded)',
  'admin.gd1.faq.quota.a':
    'Ücretsiz 15 GB doldu. Yükleme başlamaz ve hiçbir şey silinmez. Drive çöp kutusunu boşaltın, BACKUP_REMOTE_KEEP_* sayılarını azaltın ya da ek depolama alın; servis hesabı kullanmayın (kendi kotası yoktur). Drive’daki yedekler kartı toplam boyutu gösterir.',
  'admin.gd1.faq.perm.q': 'rclone.conf okunamıyor (permission denied)',
  'admin.gd1.faq.perm.a':
    'Dosya kalıcı dizinde (/opt/bukampus-data/rclone/rclone.conf) olmalı ve .env.prod içinde RCLONE_CONF_DIR bu dizini göstermelidir. Sahiplik ve izni elle değiştirmeyin: yedek konteyneri açılışta postgres sahipliği ve 0600 yapar (docker compose up -d backup ile düzelir). Dizin salt okunur bağlıysa Failed to save new token hatası çıkar.',
  'admin.gd1.faq.folder.q': 'Klasörü Drive’da elle açtım ama görünmüyor',
  'admin.gd1.faq.folder.a':
    'drive.file kapsamı yalnız rclone’un kendi oluşturduğu klasör ve dosyaları görür. Klasörü elle açmayın; ilk yüklemede rclone BU-Kampus-Yedek klasörünü kendisi oluşturur. Elle açtıysanız silin.',
  'admin.gd1.faq.tz.q': 'Saat dilimi ve zamanlama',
  'admin.gd1.faq.tz.a':
    'Zamanlayıcı Europe/Istanbul saatiyle çalışır; panel zamanları tarayıcı saatinizde gösterir. Sunucu saati kayarsa Drive isteklerinde ve bu sayfadaki ne kadar önce hesaplarında sapma olur: timedatectl ile NTP’nin açık olduğunu denetleyin.',
  'admin.gd1.faq.lost.q':
    'Dağıtımdan sonra Drive yüklemesi "rclone uzak adı rclone.conf içinde yok" diyor',
  'admin.gd1.faq.lost.a':
    'rclone.conf depo içindeki deploy/rclone dizinindeydi ve yeni sürümle birlikte kayboldu. Dosyayı /opt/bukampus-data/rclone dizinine taşıyın ve .env.prod içine RCLONE_CONF_DIR=/opt/bukampus-data/rclone ekleyip docker compose up -d backup çalıştırın (4. ve 5. adım).',
};
