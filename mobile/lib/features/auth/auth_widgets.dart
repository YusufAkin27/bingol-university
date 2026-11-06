import 'dart:convert' show utf8;

import 'package:flutter/widgets.dart';

import '../../core/locale_controller.dart';

/// Dile göre hata metni veren yeni şifre doğrulayıcı (6-72 karakter ve en çok 72 bayt; sunucu ile aynı).
String? Function(String?) newPasswordValidator(BuildContext context) {
  final l = context.l10n;
  return (v) {
    final s = v ?? '';
    if (s.length < 6) return l.authPwMinErr;
    if (s.length > 72) return l.authPwMaxErr;
    // Sunucu sınırı 72 BAYT'tır: Türkçe/Arapça karakterler birden çok bayt tutar (PASSWORD_TOO_LONG).
    if (utf8.encode(s).length > 72) return l.errPasswordTooLong;
    return null;
  };
}
