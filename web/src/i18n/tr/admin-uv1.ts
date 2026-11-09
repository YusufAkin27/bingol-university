// Yönetim paneli Uygulama güncelleme zorlama (UPDATEGATE): sürüm dağılımı, tek tıkla zorlama, ekran önizlemesi.
// Yönetim paneli YALNIZ Türkçedir: bu dosyanın en/ar karşılığı yazılmaz; i18n/bundles/admin-tr-only.ts en/ar
// sözlüklerine aynı Türkçe metni katar ve scripts/check-i18n.mjs bu dosyayı en/ar eşitliği denetiminden muaf tutar.
export default {
  'admin.uv.nav': 'Uygulama güncelleme',
  'admin.uv.title': 'Uygulama güncelleme',
  'admin.uv.desc':
    'Yeni sürümü yayınladıktan sonra eski sürümleri güncellemeye zorlayabilir ya da yalnız öneri gösterebilirsiniz. Kullanıcı "Güncelle" düğmesine basınca Play Store / App Store açılır.',
  'admin.uv.sourceTitle': 'Cihaz sayıları nereden geliyor?',
  'admin.uv.sourceWindow': 'Son {n} gün',
  'admin.uv.refresh': 'Yenile',
  'admin.uv.platform.android': 'Android',
  'admin.uv.platform.ios': 'iOS',

  'admin.uv.state.FORCE': 'Zorunlu güncelleme AÇIK',
  'admin.uv.state.SOFT': 'Yalnız öneri',
  'admin.uv.state.OFF': 'Kapalı',

  'admin.uv.stat.latest': 'Yayındaki sürüm',
  'admin.uv.stat.min': 'Zorunlu en düşük sürüm',
  'admin.uv.stat.devices': 'Sayılan cihaz',
  'admin.uv.stat.belowMin': 'Zorunlu güncelleme görecek',
  'admin.uv.stat.belowLatest': 'Güncelleme önerisi görecek',
  'admin.uv.stat.unknown': 'Sürümü bilinmeyen',
  'admin.uv.belowMin': 'Bu sürümün altında: {n} cihaz',
  'admin.uv.belowMinNone': 'Zorunlu en düşük sürümün altında cihaz yok.',
  'admin.uv.inverted': 'Zorunlu en düşük sürüm yayındaki sürümden büyük görünüyor. Değerleri kontrol edin.',

  'admin.uv.table.caption': 'Sürüm dağılımı: {platform}',
  'admin.uv.table.version': 'Sürüm',
  'admin.uv.table.devices': 'Cihaz',
  'admin.uv.table.status': 'Durum',
  'admin.uv.table.empty': 'Bu platform için son {n} günde kayıtlı cihaz yok.',
  'admin.uv.table.unknownVersion': 'Bilinmiyor',
  'admin.uv.row.FORCED': 'Zorunlu güncelleme görür',
  'admin.uv.row.SUGGESTED': 'Güncelleme önerilir',
  'admin.uv.row.CURRENT': 'Güncel',
  'admin.uv.row.UNKNOWN': 'Sürüm bilinmiyor',

  'admin.uv.publish': 'Yeni sürümü yayınla',
  'admin.uv.preview': 'Güncelleme ekranını önizle',

  'admin.uv.wizard.title': 'Yeni sürümü yayınla: {platform}',
  'admin.uv.wizard.intro':
    'Mağazada yayınladığınız sürüm numarasını girin, sonra bu sürümün altındaki uygulamalara ne olacağını seçin.',
  'admin.uv.wizard.version': 'Sürüm numarası',
  'admin.uv.wizard.versionHint': 'Mağazadaki sürümle aynı olmalı. Örnek: 2.0.5',
  'admin.uv.wizard.mode': 'Bu sürümün altındakiler',
  'admin.uv.wizard.mode.FORCE': 'Zorunlu güncelle',
  'admin.uv.wizard.mode.FORCE.hint': 'Güncelleme yapılmadan uygulama kullanılamaz.',
  'admin.uv.wizard.mode.SOFT': 'Yalnız öner',
  'admin.uv.wizard.mode.SOFT.hint': '"Yeni sürüm var" uyarısı gösterilir; uygulama kullanılmaya devam eder.',
  'admin.uv.wizard.mode.OFF': 'Zorunluluğu kaldır',
  'admin.uv.wizard.mode.OFF.hint': 'Zorunlu güncelleme kapanır; yayındaki sürüm değişmez.',
  'admin.uv.wizard.impact.FORCE': 'Etki: yaklaşık {n} cihaz güncelleme ekranını görür.',
  'admin.uv.wizard.impact.SOFT': 'Etki: yaklaşık {n} cihaz güncelleme önerisi görür.',
  'admin.uv.wizard.impact.OFF': 'Etki: Zorunluluk kalkar; hiçbir cihaz güncelleme ekranı görmez.',
  'admin.uv.wizard.impactNote': 'Sayı yaklaşıktır; kaynak notuna bakın.',
  'admin.uv.wizard.next': 'Devam',
  'admin.uv.wizard.cancel': 'Vazgeç',

  'admin.uv.issue.VERSION_INVALID': 'Sürüm numarası geçersiz. Örnek: 2.0.5',
  'admin.uv.issue.BELOW_LATEST':
    'Zorunlu sürüm, yayındaki sürümden ({latest}) düşük olamaz.',
  'admin.uv.issue.BELOW_MIN': 'Önerilen sürüm, zorunlu en düşük sürümün ({min}) altında olamaz.',
  'admin.uv.issue.NO_STORE_LINK':
    'Bu platform için mağaza bağlantısı yok: "Güncelle" düğmesi çalışmaz, kullanıcı ekranda takılı kalır. Önce Ayarlar > Mağaza ve sürümler bölümünden bağlantı / kimlik girin.',
  'admin.uv.issue.IOS_NOT_PUBLISHED':
    'iOS uygulaması henüz mağazada değilse zorlama önerilmez: kullanıcılar güncelleyemez.',
  'admin.uv.issue.ABOVE_EVERYONE':
    'Girdiğiniz sürüm şu an hiçbir cihazda yok. Mağazada gerçekten yayında olduğundan emin olun; aksi halde herkes kilitlenir.',

  'admin.uv.confirm.title.FORCE': 'Zorunlu güncelleme açılsın mı? ({platform} {version})',
  'admin.uv.confirm.title.SOFT': 'Güncelleme önerisi yayınlansın mı? ({platform} {version})',
  'admin.uv.confirm.title.OFF': 'Zorunlu güncelleme kaldırılsın mı? ({platform})',
  'admin.uv.confirm.message.FORCE':
    '{platform} üzerinde {version} sürümünün altındaki tüm uygulamalar güncelleme yapılmadan kullanılamaz.',
  'admin.uv.confirm.message.SOFT': '{platform} üzerinde {version} sürümünün altındaki uygulamalara yalnız öneri gösterilir.',
  'admin.uv.confirm.message.OFF': '{platform} için zorunlu güncelleme kapatılır; eski sürümler yeniden kullanılabilir.',
  'admin.uv.confirm.consequence.FORCE':
    'Değişiklik anında geçerlidir. Uygulama bir sonraki açılışta ya da öne geldiğinde kontrol eder; çevrimdışı cihazlar kilitlenmez. Geri almak için "Zorunluluğu kaldır" kullanın.',
  'admin.uv.confirm.consequence.SOFT': 'Değişiklik anında geçerlidir. Zorunlu en düşük sürüm değişmez.',
  'admin.uv.confirm.consequence.OFF': 'Değişiklik anında geçerlidir.',
  'admin.uv.confirm.btn.FORCE': 'Zorunlu güncelle',
  'admin.uv.confirm.btn.SOFT': 'Öneriyi yayınla',
  'admin.uv.confirm.btn.OFF': 'Zorunluluğu kaldır',
  'admin.uv.confirm.diff': 'Zorunlu en düşük sürüm: {minFrom} → {minTo}; yayındaki sürüm: {latestFrom} → {latestTo}',
  'admin.uv.confirm.impact': 'Etkilenecek cihaz (yaklaşık): {n}',
  'admin.uv.confirm.typeWord': 'ZORLA',
  'admin.uv.confirm.success.FORCE': 'Zorunlu güncelleme açıldı: {platform} {version}',
  'admin.uv.confirm.success.SOFT': 'Güncelleme önerisi yayınlandı: {platform} {version}',
  'admin.uv.confirm.success.OFF': 'Zorunlu güncelleme kaldırıldı: {platform}',

  'admin.uv.err.VERSION_BELOW_LATEST': 'Zorunlu sürüm, yayındaki sürümden düşük olamaz.',
  'admin.uv.err.VERSION_BELOW_MIN': 'Önerilen sürüm, zorunlu en düşük sürümün altında olamaz.',
  'admin.uv.err.INVALID_VERSION': 'Sürüm numarası geçersiz. Örnek: 2.0.5',

  'admin.settings.err.PACKAGE': 'Geçerli bir paket adı girin. Örnek: tr.com.bukampus.app',
  'admin.settings.err.APPLE_ID': 'Apple uygulama kimliği yalnız rakamlardan oluşmalıdır (5-15 hane).',
  'admin.settings.err.MESSAGE':
    'Metin en çok 280 karakter olabilir; HTML, bağlantı ve satır sonu içeremez.',
  'admin.uv.settingsLink':
    'Zorunlu güncelleme, sürüm dağılımı ve ekran önizlemesi için "Uygulama güncelleme" sayfasını kullanın.',
  'admin.uv.settingsLinkBtn': 'Uygulama güncelleme sayfası',
  'admin.uv.settings.messagesTitle': 'Güncelleme ekranı metni',
  'admin.uv.settings.messagesIntro':
    'İsteğe bağlı kısa metin (en çok 280 karakter; HTML ve bağlantı olmaz). Boşsa uygulamanın varsayılan metni gösterilir; seçili dilde boşsa Türkçe kullanılır.',
  'admin.uv.settings.storeHint':
    'Boş bırakırsanız Android için paket adından, iOS için Apple kimliğinden adres üretilir.',
  'admin.settings.key.store_package_android': 'Android paket adı',
  'admin.uv.settings.packageHint': 'Örnek: tr.com.bukampus.app (boşsa bu varsayılan kullanılır)',
  'admin.settings.key.apple_app_id_ios': 'Apple uygulama kimliği',
  'admin.uv.settings.appleHint': 'Yalnız rakam (App Store Connect > Uygulama bilgileri). Boşsa iOS için mağaza adresi üretilmez.',
  'admin.settings.key.update_message_tr': 'Güncelleme ekranı metni (Türkçe)',
  'admin.settings.key.update_message_en': 'Güncelleme ekranı metni (İngilizce)',
  'admin.settings.key.update_message_ar': 'Güncelleme ekranı metni (Arapça)',

  'admin.uv.preview.title': 'Güncelleme ekranı önizlemesi: {platform}',
  'admin.uv.preview.lang': 'Önizleme dili',
  'admin.uv.preview.screenTitle.tr': 'Güncelleme gerekli',
  'admin.uv.preview.screenTitle.en': 'Update required',
  'admin.uv.preview.screenTitle.ar': 'التحديث مطلوب',
  'admin.uv.preview.defaultBody.tr': 'Uygulamayı kullanmaya devam etmek için yeni sürüme güncellemeniz gerekiyor.',
  'admin.uv.preview.defaultBody.en': 'Update to the latest version to keep using the app.',
  'admin.uv.preview.defaultBody.ar': 'يجب تحديث التطبيق إلى أحدث إصدار لمتابعة استخدامه.',
  'admin.uv.preview.button.tr': 'Güncelle',
  'admin.uv.preview.button.en': 'Update',
  'admin.uv.preview.button.ar': 'تحديث',
  'admin.uv.preview.noLink.tr': 'Mağazadan güncelleyin',
  'admin.uv.preview.noLink.en': 'Please update from the store',
  'admin.uv.preview.noLink.ar': 'يرجى التحديث من المتجر',
  'admin.uv.preview.target': 'Düğmenin gideceği yer: {target}',
  'admin.uv.preview.target.play': 'Google Play ({pkg})',
  'admin.uv.preview.target.apple': 'App Store (kimlik {id})',
  'admin.uv.preview.target.custom': 'Yazdığınız mağaza bağlantısı',
  'admin.uv.preview.target.none': 'Bağlantı yok: düğme yerine "Mağazadan güncelleyin" yazısı görünür',
  'admin.uv.preview.close': 'Kapat',
  'admin.uv.loadError': 'Sürüm bilgisi yüklenemedi.',

  'admin.uv.dev.title': 'Cihaz sayıları',
  'admin.uv.dev.total': 'Toplam benzersiz cihaz',
  'admin.uv.dev.total.info':
    'Son {n} günde giriş yapmış kullanıcılardan istek alan farklı cihaz sayısı. Cihaz kimliği özetine göre tekildir: aynı telefondaki birden çok hesap ya da aynı cihazın farklı IP adresleri tek sayılır. Silinmiş hesaplar sayılmaz. Hiç giriş yapmamış cihazlar bu kayıtta yoktur; Android\'de uygulama silinip yeniden kurulursa yeni cihaz gibi görünebilir.',
  'admin.uv.dev.active30': 'Aktif cihaz (30 gün)',
  'admin.uv.dev.active30.info': 'Toplam benzersiz cihazlardan son {n} gün içinde sunucuya ulaşanlar.',
  'admin.uv.dev.active7': 'Aktif cihaz (7 gün)',
  'admin.uv.dev.active7.info': 'Toplam benzersiz cihazlardan son {n} gün içinde sunucuya ulaşanlar.',
  'admin.uv.dev.push': 'Bildirim alabilen cihaz',
  'admin.uv.dev.push.info':
    'Son {n} günde görülmüş geçerli bildirim jetonu (FCM) olan cihaz sayısı. Bildirim izni vermeyen cihazlar burada yoktur. Jeton cihaz kimliğine bağlı olmadığından bu sayı yukarıdakilerden çıkarılmaz; uygulama yeniden kurulumunda jeton değişirse biraz fazla görünebilir.',
  'admin.uv.dev.latest': 'En güncel sürümde',
  'admin.uv.dev.latest.info':
    'Aktif (30 gün) Android ve iOS cihazlarından, o platformun yayındaki sürümünde ya da daha yenisinde olanların oranı. Sürümü bilinmeyen cihazlar paydaya girer, paya girmez.',
  'admin.uv.dev.unknown': 'Sürümü bilinmeyen',
  'admin.uv.dev.unknown.info':
    'Aktif Android ve iOS cihazlarından sürüm başlığı göndermeyen ya da sürümü okunamayanlar. Sürüm tablolarında "Bilinmiyor" satırı olarak ayrıca görünür.',
  'admin.uv.dev.byPlatform': 'Platform kırılımı',
  'admin.uv.dev.col.platform': 'Platform',
  'admin.uv.dev.col.push': 'Bildirim alabilen',
  'admin.uv.dev.platform.android': 'Android',
  'admin.uv.dev.platform.ios': 'iOS',
  'admin.uv.dev.platform.other': 'Diğer (web / bilinmiyor)',
  'admin.uv.dev.unidentified':
    'Aktif cihazların {n} tanesi cihaz kimliği göndermeyen eski sürümlerden gelir; bunlar kullanıcı başına bir cihaz olarak sayılır.',
  'admin.uv.dev.pushNote': 'Bildirim jetonu ile cihaz kimliği birbirine bağlanmadığından iki sayı ayrı kaynaklardan gelir.',
};
