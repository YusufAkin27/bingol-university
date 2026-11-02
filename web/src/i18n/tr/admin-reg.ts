// Yönetim paneli yönetici hesabı kaydı (DEP2): YALNIZ ADMIN_EMAILS listesindeki adresler kayıt olabilir (bingol.edu.tr olmak zorunda değil;
// listede olmayan adres için sunucu sessizce 202 döner, kod gitmez).
// Yönetim paneli YALNIZ Türkçedir: bu dosyanın en/ar karşılığı yazılmaz; i18n/bundles/admin-tr-only.ts en/ar
// sözlüklerine aynı Türkçe metni katar ve scripts/check-i18n.mjs bu dosyayı en/ar eşitliği denetiminden muaf tutar.
export default {
  'admin.reg.title': 'Yönetici hesabı oluştur',
  'admin.reg.subtitle':
    'Yönetim paneli için hesap açın. Yalnızca yönetici olarak yetkilendirilmiş e-posta adresleri kayıt olabilir.',
  'admin.reg.name': 'Ad soyad',
  'admin.reg.email': 'E-posta',
  'admin.reg.password': 'Şifre',
  'admin.reg.passwordHint': 'En az 12 karakter.',
  'admin.reg.terms': 'Kullanım koşullarını, gizlilik politikasını ve KVKK aydınlatma metnini okudum, kabul ediyorum.',
  'admin.reg.termsLink': 'Metinleri aç',
  'admin.reg.submit': 'Kayıt ol ve kod gönder',
  'admin.reg.submitting': 'Gönderiliyor…',
  'admin.reg.required': 'Bu alan zorunludur.',
  'admin.reg.invalidEmail': 'Geçerli bir e-posta adresi girin.',
  'admin.reg.passwordShort': 'Şifre en az 12 karakter olmalıdır.',
  'admin.reg.termsRequired': 'Devam etmek için kabul etmelisiniz.',
  'admin.reg.codeTitle': 'E-postanızı doğrulayın',
  'admin.reg.codeSubtitle': '{email} adresine 6 haneli bir kod gönderdik. Kod 10 dakika geçerlidir.',
  'admin.reg.code': 'Doğrulama kodu',
  'admin.reg.codeInvalid': '6 haneli kodu girin.',
  'admin.reg.verify': 'Doğrula ve giriş yap',
  'admin.reg.verifying': 'Doğrulanıyor…',
  'admin.reg.resend': 'Kodu yeniden gönder',
  'admin.reg.resendIn': 'Yeniden gönder ({time})',
  'admin.reg.resendWait': 'Yeni kod için yaklaşık {n} dakika bekleyin.',
  'admin.reg.resent': 'Yeni kod gönderildi.',
  'admin.reg.changeEmail': 'E-postayı değiştir',
  'admin.reg.linkFromLogin': 'Hesabınız yok mu? Yönetici hesabı oluşturun',
  'admin.reg.backToLogin': 'Girişe dön',
  'admin.reg.note': 'Kayıt, e-posta doğrulaması gerektirir.',
  'admin.reg.authorizedOnly':
    'Yalnızca yetkilendirilmiş yönetici e-posta adresleri kayıt olabilir. Kod gelmediyse adresiniz yetkili değildir.',
} as const;
