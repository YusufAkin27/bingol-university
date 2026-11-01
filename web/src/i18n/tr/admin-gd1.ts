// Yönetim paneli Yedekleme (Google Drive) sayfası (GD1): durum kartları + adım adım kurulum rehberi.
// Yönetim paneli YALNIZ Türkçedir: bu dosyanın en/ar karşılığı yazılmaz; i18n/bundles/admin-tr-only.ts en/ar
// sözlüklerine aynı Türkçe metni katar ve scripts/check-i18n.mjs bu dosyayı en/ar eşitliği denetiminden muaf tutar.
export default {
  'admin.gd1.title': 'Yedekleme (Google Drive)',
  'admin.gd1.desc':
    'Veritabanı ve yüklenen dosyaların yedekleri, sunucu rahatlasın diye şifreli olarak Google Drive’a taşınabilir. Bu sayfa durumu gösterir ve kurulumu adım adım anlatır; hiçbir parola veya belirteç istemez.',
  'admin.gd1.refresh': 'Yenile',

  'admin.gd1.status.heading': 'Yedek durumu',
  'admin.gd1.status.unavailable': 'Durum bilgisi henüz alınamıyor (sunucu bu bilgiyi vermiyor). Kurulum rehberi aşağıdadır.',
  'admin.gd1.status.error': 'Durum bilgisi alınamadı.',

  'admin.gd1.warn.localOnly.title': 'Yedekler yalnız sunucu diskinde',
  'admin.gd1.warn.localOnly':
    'Google Drive henüz kurulmadı. Sunucu diski ya da hesabı giderse yedekler de gider. Aşağıdaki rehberle Drive’ı bağlayın.',
  'admin.gd1.warn.localOnly.go': 'Kurulum rehberine git',

  'admin.gd1.card.last': 'Son başarılı yedek',
  'admin.gd1.card.last.none': 'Henüz başarılı yedek yok',
  'admin.gd1.card.last.schedule': 'Zamanlama (Europe/Istanbul): {cron}',
  'admin.gd1.card.last.verify': 'Geri yükleme doğrulaması: {cron}',
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
  'admin.gd1.drive.PENDING': 'Bağlı, ilk doğrulama bekleniyor',
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
  'admin.gd1.retention.line': 'Saatlik {d} · haftalık {w} · aylık {m}',

  'admin.gd1.guide.heading': 'Kurulum rehberi',
  'admin.gd1.guide.intro':
    'Adımları sırayla izleyin. Komutlardaki <...> biçimindeki yerleri kendi değerinizle değiştirin. Bu sayfa hiçbir gizli bilgiyi sizden istemez ve saklamaz.',
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
  'admin.gd1.warn.tokenTitle': 'Çıkan belirteç bir sırdır',
  'admin.gd1.warn.token':
    'Çıkan JSON belirteci Drive erişimi verir. Yalnızca sunucudaki rclone.conf dosyasına yazın; sohbete, e-postaya, destek talebine veya bu panele yapıştırmayın.',
  'admin.gd1.warn.deleteTitle': 'Silme işlemi geri alınamaz',
  'admin.gd1.warn.delete':
    'Sunucudaki yedekler silindikten sonra tek kopya Drive’da kalır. Önce 6. adımda Drive durumunun yeşil olduğunu ve bir geri yükleme denemesinin geçtiğini görün; önce hep kuru çalıştırın.',

  'admin.gd1.step.why.title': '0. Neden ve özet',
  'admin.gd1.step.why.lead':
    'Amaç: yedekleri sunucu diskinden çıkarıp Google Drive’a taşımak, sunucuyu rahatlatmak. Drive hesabı 15 GB’a kadar ücretsizdir; saatlik yedekler için saklama sayıları küçük tutulur.',
  'admin.gd1.step.why.enc':
    'Yedekler Drive’a gitmeden önce age ile şifrelenir; Drive yalnız şifreli veriyi görür. Kurulum kendi bilgisayarınızda bir kez izin vermeyi, sonra sunucuda bir ayar dosyası ve iki satırlık bir ortam değişikliği yapmayı kapsar.',

  'admin.gd1.step.install.title': '1. Kendi bilgisayarınıza rclone kurun',
  'admin.gd1.step.install.lead': 'Bu adım sunucuda değil, kendi bilgisayarınızda yapılır. Yalnız izin vermek için gereklidir.',
  'admin.gd1.step.install.win': 'Windows',
  'admin.gd1.step.install.mac': 'macOS',
  'admin.gd1.step.install.check': 'Kurulumu denetle',
  'admin.gd1.step.install.alt': 'Paket yöneticisi yoksa rclone.org/downloads adresinden indirin.',

  'admin.gd1.step.authorize.title': '2. Google hesabınıza izin verin (rclone authorize)',
  'admin.gd1.step.authorize.lead':
    'Komut tarayıcıyı açar. Yedeklerin duracağı Google hesabıyla giriş yapıp izin verin. İstenen kapsam drive.file’dır: rclone yalnız kendi oluşturduğu dosyaları görür, Drive’daki diğer dosyalarınıza erişemez.',
  'admin.gd1.step.authorize.cmd': 'İzin komutu',
  'admin.gd1.step.authorize.after':
    'İşlem bitince terminalde süslü parantezle başlayıp biten tek satırlık JSON çıkar (access_token ve refresh_token içerir). Tamamını kopyalayın; 3. adımda kullanacaksınız.',

  'admin.gd1.step.conf.title': '3. Sunucuda rclone.conf dosyasını oluşturun',
  'admin.gd1.step.conf.lead': 'Sunucuya SSH ile bağlanın ve ayar dosyasını oluşturun. Belirteç yer tutucusunu 2. adımdaki JSON ile değiştirin.',
  'admin.gd1.step.conf.ssh': 'Sunucuya bağlanın',
  'admin.gd1.step.conf.edit': 'Dosyayı açın',
  'admin.gd1.step.conf.template': 'Dosya içeriği (şablon)',
  'admin.gd1.step.conf.perm': 'İzinleri kısıtlayın',
  'admin.gd1.step.conf.permWhy':
    'Yedek konteynerindeki zamanlayıcı postgres (uid 70) kullanıcısıyla çalışır; dosya yalnız ona okunur olmalı, başkasına kapalı kalmalıdır. Dosya depoya (git) eklenmez.',

  'admin.gd1.step.env.title': '4. Ortam değişkenlerini ekleyip yedek servisini yeniden başlatın',
  'admin.gd1.step.env.lead': '.env.prod dosyasına Drive hedefini ve saklama sayılarını ekleyin.',
  'admin.gd1.step.env.edit': 'Dosyayı açın',
  'admin.gd1.step.env.vars': 'Eklenecek satırlar',
  'admin.gd1.step.env.up': 'Yedek servisini yeniden başlatın',
  'admin.gd1.step.env.keep':
    'Saklama sayıları yalnız sunucudaki (yerel) kopyaları sınırlar. Drive tarafındaki saklama ayarı varsa docs/BACKUP_GDRIVE.md dosyasındadır.',

  'admin.gd1.step.verify.title': '5. Denemeyi yapın ve ilk yüklemeyi bekleyin',
  'admin.gd1.step.verify.lead': 'Önce hiçbir şey yazmayan deneme çalıştırın; bağlantı, anahtar ve Drive erişimi denetlenir.',
  'admin.gd1.step.verify.dry': 'Kuru deneme',
  'admin.gd1.step.verify.run': 'İlk yedeği hemen alıp yükleyin',
  'admin.gd1.step.verify.ls': 'Drive’daki klasörü listeleyin',
  'admin.gd1.step.verify.page':
    'Bu sayfayı yenileyin: Google Drive durumu Bağlı ve doğrulandı olmalı ve Drive’daki yedekler kartında adet görünmelidir.',

  'admin.gd1.step.prune.title': '6. Doğrulandıktan SONRA sunucudaki eski yedekleri azaltın',
  'admin.gd1.step.prune.lead': 'Betik sunucu diskindeki yedekleri Drive ile karşılaştırır ve yalnız Drive’da doğrulanmış kopyası olanları siler.',
  'admin.gd1.step.prune.dry': 'Önce kuru çalıştırma (varsayılan, hiçbir şey silmez)',
  'admin.gd1.step.prune.apply': 'Çıktıyı denetleyin, sonra gerçekten uygulayın',
  'admin.gd1.step.prune.rule': 'Drive’da doğrulanmış kopyası olmayan yedek asla silinmez. Betiğin seçenekleri için betiği --help ile çalıştırın.',

  'admin.gd1.step.restore.title': '7. Geri yükleme (Drive’dan indirme)',
  'admin.gd1.step.restore.lead': 'Felaket durumunda yedek önce Drive’dan indirilir, bütünlüğü denetlenir, sonra canlıya geri yüklenir.',
  'admin.gd1.step.restore.download': 'İndirin ve özetleri doğrulayın',
  'admin.gd1.step.restore.apply': 'Geri yükleyin (uygulamayı durdurur, onay ister)',
  'admin.gd1.step.restore.docs': 'Ayrıntılar, süreler ve anahtar bağımlılığı: docs/BACKUP_RESTORE.md (bölüm 5 ve 9).',

  'admin.gd1.step.faq.title': '8. Sık sorunlar',

  'admin.gd1.faq.grant.q': 'invalid_grant ya da token expired hatası',
  'admin.gd1.faq.grant.a':
    'Yedek bir süre çalıştıktan sonra yetkilendirme düştü demektir. Sık neden: kendi Google bulut projenizin OAuth uygulaması Test modunda; refresh belirteci 7 günde dolar. Çözüm: rclone’un yerleşik anahtarını kullanın (kendi client_id yazmayın) ya da uygulamayı Yayında durumuna alın. Ayrıca Google parolası değişti veya erişim iptal edildi ise. Yeniden 2. adımı uygulayıp rclone.conf içindeki token satırını değiştirin ve yedek servisini yeniden başlatın.',
  'admin.gd1.faq.rate.q': '403 rateLimitExceeded',
  'admin.gd1.faq.rate.a':
    'Google istek sınırına takıldınız (rclone’un ortak anahtarı herkesle paylaşılır). Birkaç dakika bekleyin; sürerse kendi Google bulut projenizde client_id oluşturun (rclone.org/drive, Making your own client ID bölümü) ve yayında durumuna alın.',
  'admin.gd1.faq.quota.q': 'Kota dolu (storageQuotaExceeded)',
  'admin.gd1.faq.quota.a':
    'Ücretsiz 15 GB doldu. Drive çöp kutusunu boşaltın, saklama sayılarını azaltın (.env.prod BACKUP_KEEP_* ve Drive tarafı) ya da ek depolama alın. Sayfadaki Drive’daki yedekler kartı toplam boyutu gösterir.',
  'admin.gd1.faq.perm.q': 'rclone.conf okunamıyor (permission denied)',
  'admin.gd1.faq.perm.a':
    'Dosya sahibi 70:70 ve izin 400 olmalı (3. adım). Dosya konteynerde /config/rclone/rclone.conf olarak salt okunur bağlanır; rclone yenilenen belirteci dosyaya yazamayıp uyarı verebilir, bu zararsızdır.',
  'admin.gd1.faq.folder.q': 'Klasörü Drive’da elle açtım ama görünmüyor',
  'admin.gd1.faq.folder.a':
    'drive.file kapsamı yalnız rclone’un kendi oluşturduğu klasör ve dosyaları görür. Klasörü elle açmayın; ilk yüklemede rclone BU-Kampus-Yedek klasörünü kendisi oluşturur.',
  'admin.gd1.faq.tz.q': 'Saat dilimi ve zamanlama',
  'admin.gd1.faq.tz.a':
    'Zamanlayıcı Europe/Istanbul saatiyle çalışır; panel zamanları tarayıcı saatinizde gösterir. Sunucu saati kayarsa Drive isteklerinde ve bu sayfadaki ne kadar önce hesaplarında sapma olur: timedatectl ile NTP’nin açık olduğunu denetleyin.',
};
