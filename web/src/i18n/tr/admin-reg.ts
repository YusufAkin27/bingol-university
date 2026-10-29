// Yönetim paneli yönetici hesabı kaydı (DEP2): ADMIN_EMAILS listesindeki adresler bingol.edu.tr dışında da kayıt olabilir.
// Yönetim paneli YALNIZ Türkçedir: bu dosyanın en/ar karşılığı yazılmaz; i18n/bundles/admin-tr-only.ts en/ar
// sözlüklerine aynı Türkçe metni katar ve scripts/check-i18n.mjs bu dosyayı en/ar eşitliği denetiminden muaf tutar.
export default {
  'admin.reg.title': 'Yönetici hesabı oluştur',
  'admin.reg.subtitle':
    'Yönetim paneli için hesap açın. Yalnızca sunucuda yönetici olarak tanımlı e-posta adresleri yönetici yetkisi alır; diğer hesaplar panele giremez.',
  'admin.reg.name': 'Ad soyad',
  'admin.reg.email': 'E-posta',
  'admin.reg.password': 'Şifre',
  'admin.reg.passwordHint': 'En az 8 karakter.',
  'admin.reg.terms': 'Kullanım koşullarını, gizlilik politikasını ve KVKK aydınlatma metnini okudum, kabul ediyorum.',
  'admin.reg.termsLink': 'Metinleri aç',
  'admin.reg.submit': 'Kayıt ol ve kod gönder',
  'admin.reg.submitting': 'Gönderiliyor…',
  'admin.reg.required': 'Bu alan zorunludur.',
  'admin.reg.invalidEmail': 'Geçerli bir e-posta adresi girin.',
  'admin.reg.passwordShort': 'Şifre en az 8 karakter olmalıdır.',
  'admin.reg.termsRequired': 'Devam etmek için kabul etmelisiniz.',
  'admin.reg.codeTitle': 'E-postanızı doğrulayın',
  'admin.reg.codeSubtitle': '{email} adresine 6 haneli bir kod gönderdik. Kod 10 dakika geçerlidir.',
  'admin.reg.code': 'Doğrulama kodu',
  'admin.reg.codeInvalid': '6 haneli kodu girin.',
  'admin.reg.verify': 'Doğrula ve giriş yap',
  'admin.reg.verifying': 'Doğrulanıyor…',
  'admin.reg.resend': 'Kodu yeniden gönder',
  'admin.reg.resent': 'Yeni kod gönderildi.',
  'admin.reg.changeEmail': 'E-postayı değiştir',
  'admin.reg.linkFromLogin': 'Hesabınız yok mu? Yönetici hesabı oluşturun',
  'admin.reg.backToLogin': 'Girişe dön',
  'admin.reg.note': 'Kayıt, e-posta doğrulaması gerektirir. Yönetici yetkisi yalnızca sunucu yapılandırmasındaki adreslere verilir.',
} as const;
