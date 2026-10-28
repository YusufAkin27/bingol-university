// Yönetim paneli yıkıcı eylem onayları (P05): sebep, yazılı onay, fark önizlemesi. Yönetim paneli YALNIZ Türkçedir:
// bu dosyanın en/ar karşılığı yazılmaz; i18n/index.ts en/ar sözlüklerine aynı Türkçe metni katar ve
// scripts/check-i18n.mjs bu dosyayı en/ar eşitliği denetiminden muaf tutar.
export default {
  'admin.p05.reason.optional': 'Sebep (isteğe bağlı)',
  'admin.p05.reason.optionalHint': 'Denetim kaydına yazılır; boş bırakabilirsiniz.',

  'admin.p05.user.suspend.message':
    '{name} hesabı askıya alınacak: kullanıcı giriş yapamaz ve açık oturumları anında reddedilir.',
  'admin.p05.user.revoke.consequence':
    'Kullanıcı tüm cihazlarda oturumdan çıkarılır; yeniden giriş yapabilir.',
  'admin.p05.user.role.promote':
    'Bu kullanıcı yönetim panelinin tüm verilerine ve yıkıcı işlemlerine erişebilir. Rol daha sonra tekrar düşürülebilir.',
  'admin.p05.user.role.demote':
    'Kullanıcı yönetim paneline erişimini kaybeder. Rol daha sonra tekrar verilebilir.',
  'admin.p05.user.role.adminEmailsWarning':
    'Not: ADMIN_EMAILS listesindeki bir hesap panelden düşürülse bile giriş sırasında yeniden yönetici olur. Kalıcı olarak düşürmek için önce adresi o listeden çıkarın.',
  'admin.p05.user.delete.consequence':
    'Hesap anonimleştirilecek: kişisel veriler silinir ve kullanıcı bir daha giriş yapamaz.',

  'admin.p05.settings.confirmTitle': 'Ayar değişikliğini onayla: {name}',
  'admin.p05.settings.confirmText':
    'Aşağıdaki değişiklik kaydedilecek ve uygulamaya hemen yansıyacak.',
  'admin.p05.settings.confirmBtn': 'Değişikliği kaydet',
  'admin.p05.settings.diffTitle': 'Değişiklik: {name}',
  'admin.p05.settings.old': 'Eski değer',
  'admin.p05.settings.new': 'Yeni değer',
  'admin.p05.settings.empty': '(boş)',
  'admin.p05.settings.maintenanceOffTitle': 'Bakım modu kapatılsın mı?',
  'admin.p05.settings.maintenanceOffText':
    'Uygulama normal çalışmaya döner; bakım mesajı artık gösterilmez.',
  'admin.p05.settings.maintenanceOffBtn': 'Bakım modunu kapat',
  'admin.p05.settings.minVersionWarning':
    'Bu sürümden eski uygulamalar güncellenene kadar kullanılamaz. Değeri güncel sürümden büyük girmeyin.',

  'admin.p05.legal.consequence': 'Yeni sürüm hemen yayınlanır ve güncel sürümün yerine geçer.',
  'admin.p05.legal.impactReaccept':
    'Yeniden onay istenecek: {total} etkin kullanıcının her biri yeni sürümü onaylamak zorunda kalacak (şu an {accepted} kullanıcı güncel sürümü onaylamış).',
  'admin.p05.legal.impactReacceptUnknown':
    'Yeniden onay istenecek: tüm etkin kullanıcılar yeni sürümü onaylamak zorunda kalacak. Kullanıcı sayısı yüklenemedi.',
  'admin.p05.legal.impactNoReaccept': 'Yeniden onay istenmeyecek; mevcut onaylar geçerli kalır.',

  'admin.p05.ops.retryTitle': 'Ölü kayıtlar yeniden denensin mi?',
  'admin.p05.ops.retryMessage':
    'Kalıcı olarak başarısız sayılan kayıtlar kuyruğa geri alınır ve yeniden gönderilmeye çalışılır.',
  'admin.p05.ops.retryConsequence':
    'Gönderim yeniden başlar; eski kayıtlar için alıcılara geç de olsa e-posta veya bildirim gidebilir.',
  'admin.p05.ops.noun': 'ölü kayıt',

  'admin.p05.news.hideTitle': 'Haber gizlensin mi?',
  'admin.p05.news.showTitle': 'Haber yeniden gösterilsin mi?',
  'admin.p05.news.hideConsequence':
    'Haber herkese açık liste, detay, arama ve favorilerden kalkar.',
  'admin.p05.news.showConsequence': 'Haber herkese açık listelere geri döner.',

  'admin.p05.faq.loadMore': 'Daha fazla yükle',
  'admin.p05.faq.moreHint': 'Liste 50 kayıtlık sayfalarla yüklenir; kalan kayıtlar için devam edin.',
  'admin.p05.faq.moreOtherLang':
    'Bu dilde henüz kayıt görünmüyor; kalan sayfalarda olabilir. Yüklemeye devam edin.',
};
