// Yönetim paneli ortak güvenlik bileşenleri (components/admin/guard). Yönetim paneli YALNIZ Türkçedir:
// bu dosyanın en/ar karşılığı yazılmaz; i18n/index.ts en/ar sözlüklerine aynı Türkçe metni katar ve
// scripts/check-i18n.mjs bu dosyayı en/ar eşitliği denetiminden muaf tutar.
export default {
  'admin.guard.consequence.irreversible': 'Bu işlem geri alınamaz.',
  'admin.guard.consequence.reversible': 'Bu işlem geri alınabilir.',

  'admin.guard.typeToConfirm.prompt': 'Onaylamak için {target} yazın',
  'admin.guard.typeToConfirm.label': 'Onay metni',
  'admin.guard.typeToConfirm.mismatch': 'Yazdığınız metin eşleşmiyor.',
  'admin.guard.typeToConfirm.match': 'Eşleşti.',

  'admin.guard.reason.label': 'Sebep',
  'admin.guard.reason.hint': 'En az {min} karakter yazın.',
  'admin.guard.reason.tooShort': 'Sebep en az {min} karakter olmalı.',
  'admin.guard.reason.counter': '{count}/{max}',
  'admin.guard.reason.templates': 'Hazır sebepler',

  'admin.guard.bulk.noun': 'kayıt',
  'admin.guard.bulk.notice': '{count} {noun} etkilenecek',
  'admin.guard.bulk.confirmPrompt': 'Çok sayıda kayıt etkileneceği için etkilenen sayıyı ({count}) yazarak onaylayın',

  'admin.guard.audit.title': 'Denetim kaydı',
  'admin.guard.audit.empty': 'Denetim kaydı henüz yok',
  'admin.guard.audit.error': 'Denetim kaydı yüklenemedi',
  'admin.guard.audit.unknownAdmin': 'Bilinmeyen yönetici',
  'admin.guard.audit.reason': 'Sebep: {reason}',

  'admin.guard.unsaved.title': 'Kaydedilmemiş değişiklikler var',
  'admin.guard.unsaved.message': 'Sayfadan ayrılırsanız yaptığınız değişiklikler kaybolur.',
  'admin.guard.unsaved.leave': 'Ayrıl',
  'admin.guard.unsaved.stay': 'Sayfada kal',

  'admin.guard.action.success': 'İşlem tamamlandı.',
};
