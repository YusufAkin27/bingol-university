const m = {
  // Giriş: kod adımı
  'admin.login.2fa.title': 'Giriş kodu',
  'admin.login.2fa.subtitle': 'Doğrulama kodu şu adrese gönderildi:',
  'admin.login.2fa.code': 'Giriş kodu',
  'admin.login.2fa.codeRequired': '6 haneli kodu girin.',
  'admin.login.2fa.remaining': 'Kodun geçerlilik süresi: {time}',
  'admin.login.2fa.expired': 'Kodun süresi doldu. Yeni kod isteyin ya da girişe dönün.',
  'admin.login.2fa.trust': 'Bu tarayıcıya güven (sonraki girişte kod istenmesin)',
  'admin.login.2fa.submit': 'Doğrula ve giriş yap',
  'admin.login.2fa.submitting': 'Doğrulanıyor…',
  'admin.login.2fa.resend': 'Kodu yeniden gönder',
  'admin.login.2fa.resent': 'Yeni kod e-postanıza gönderildi.',
  'admin.login.2fa.back': 'Girişe dön',
  'common.error.TWO_FACTOR_CODE_INVALID': 'Kod hatalı. Kontrol edip yeniden deneyin.',
  'common.error.TWO_FACTOR_CHALLENGE_EXPIRED':
    'Kodun süresi doldu. Yeni kod isteyin ya da yeniden giriş yapın.',
  'common.error.TWO_FACTOR_NOT_ENABLED': 'Bu hesapta iki faktörlü doğrulama açık değil.',
  'common.error.TWO_FACTOR_ALREADY_ENABLED': 'İki faktörlü doğrulama zaten açık.',

  // Menü ve sayfa
  'admin.twoFactor.title': 'İki faktörlü doğrulama',
  'admin.twoFactor.intro':
    'İki faktörlü doğrulamayı açan kullanıcılar, tanınmayan bir cihazdan girişte e-postalarına gelen 6 haneli kodu girer.',
  'admin.twoFactor.sum.enabled': 'Açan kullanıcı',
  'admin.twoFactor.sum.percent': 'Etkin kullanıcıların yüzdesi',
  'admin.twoFactor.sum.percentHint': '{n} etkin kullanıcıdan',
  'admin.twoFactor.sum.last7': 'Son 7 günde açan',
  'admin.twoFactor.sum.devices': 'Güvenilen cihaz (toplam)',
  'admin.twoFactor.searchPlaceholder': 'Ad veya e-posta ara',
  'admin.twoFactor.count': '{n} kullanıcı',
  'admin.twoFactor.col.name': 'Ad',
  'admin.twoFactor.col.email': 'E-posta',
  'admin.twoFactor.col.role': 'Rol',
  'admin.twoFactor.col.enabledAt': 'Açılış tarihi',
  'admin.twoFactor.col.devices': 'Güvenilen cihaz',
  'admin.twoFactor.col.lastLogin': 'Son giriş',
  'admin.twoFactor.col.detail': 'Ayrıntı',
  'admin.twoFactor.openUser': '{name} ayrıntısını aç',
  'admin.twoFactor.never': 'Hiç',
  'admin.twoFactor.empty.title': 'Kullanıcı bulunamadı',
  'admin.twoFactor.empty.hint': 'İki faktörlü doğrulamayı açan kullanıcı yok ya da aramanızla eşleşmedi.',

  // Kullanıcı listesi
  'admin.users.col.twoFactor': '2FA',
  'admin.users.twoFactor.on': 'Açık',
  'admin.users.twoFactor.onDevices': 'Açık · {n} cihaz',
  'admin.users.twoFactor.off': 'Kapalı',
  'admin.users.filter.twoFactor': 'İki faktörlü',
  'admin.users.filter.twoFactor.true': 'Açık',
  'admin.users.filter.twoFactor.false': 'Kapalı',

  // Kullanıcı ayrıntısı
  'admin.users.tf.title': 'İki faktörlü doğrulama',
  'admin.users.tf.status': 'Durum',
  'admin.users.tf.enabledAt': 'Açılış tarihi',
  'admin.users.tf.devices': 'Güvenilen cihaz',
  'admin.users.tf.offNote': 'Kullanıcı iki faktörlü doğrulamayı açmamış.',
  'admin.users.tf.disable': '2FA’yı kapat',
  'admin.users.tf.disable.title': 'İki faktörlü doğrulamayı kapat',
  'admin.users.tf.disable.explain':
    'Hesap kurtarma işlemidir: kullanıcı e-postasına erişemediğinde kullanılır. Kapatınca tüm güvenilen cihazlar silinir, kullanıcının tüm oturumları kapanır, kullanıcıya bildirim ve e-posta gider, işlem denetim kaydına yazılır. Yalnız FULL ve SUPPORT yöneticileri yapabilir; kendi hesabınız ve FULL yönetici hesapları panelden kapatılamaz.',
  'admin.users.tf.selfNote':
    'Kendi iki faktörlü doğrulamanızı panelden kapatamazsınız; hesap ayarlarından şifrenizle kapatın.',
  'admin.users.tf.disable.confirm': '{name} için iki faktörlü doğrulama kapatılsın mı?',
  'admin.users.tf.disable.reason': 'Gerekçe',
  'admin.users.tf.disable.reasonHint':
    'Denetim kaydına yazılır (örn. kullanıcı kurumsal e-postasına erişemiyor).',
  'admin.users.tf.disable.reasonRequired': 'Gerekçeyi yazın (en az 5 karakter).',
  'admin.users.tf.disable.done': 'İki faktörlü doğrulama kapatıldı.',
} as const;
export default m;
