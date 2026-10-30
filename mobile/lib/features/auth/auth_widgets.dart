import 'dart:convert' show utf8;

import 'package:flutter/widgets.dart';

import '../../core/locale_controller.dart';

final _emailRe = RegExp(r'^[a-z0-9._%+\-]+@([a-z0-9\-]+\.)*bingol\.edu\.tr$');

String? validateEmail(String? v) {
  final s = (v ?? '').trim().toLowerCase();
  if (s.isEmpty) return 'E-posta adresinizi girin.';
  if (!_emailRe.hasMatch(s)) return 'Yalnızca bingol.edu.tr uzantılı adres kullanılabilir.';
  return null;
}

String? validateNewPassword(String? v) {
  final s = v ?? '';
  if (s.length < 8) return 'Şifre en az 8 karakter olmalı.';
  if (s.length > 72) return 'Şifre en çok 72 karakter olabilir.';
  if (utf8.encode(s).length > 72) return 'Şifre en fazla 72 bayt olabilir.';
  return null;
}

/// Dile göre hata metni veren yeni şifre doğrulayıcı (kuralları [validateNewPassword] ile aynı).
String? Function(String?) newPasswordValidator(BuildContext context) {
  final l = context.l10n;
  return (v) {
    final s = v ?? '';
    if (s.length < 8) return l.authPwMinErr;
    if (s.length > 72) return l.authPwMaxErr;
    // Sunucu sınırı 72 BAYT'tır: Türkçe/Arapça karakterler birden çok bayt tutar (PASSWORD_TOO_LONG).
    if (utf8.encode(s).length > 72) return l.errPasswordTooLong;
    return null;
  };
}
