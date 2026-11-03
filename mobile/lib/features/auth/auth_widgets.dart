import 'package:flutter/widgets.dart';

import '../../core/locale_controller.dart';
import '../../core/pin.dart';

final _emailRe = RegExp(r'^[a-z0-9._%+\-]+@([a-z0-9\-]+\.)*bingol\.edu\.tr$');

String? validateEmail(String? v) {
  final s = (v ?? '').trim().toLowerCase();
  if (s.isEmpty) return 'E-posta adresinizi girin.';
  if (!_emailRe.hasMatch(s)) return 'Yalnızca bingol.edu.tr uzantılı adres kullanılabilir.';
  return null;
}

/// Yeni şifre (6 haneli PIN): sunucudaki `PasswordPolicy` ile aynı kural (bkz. `core/pin.dart`).
String? validateNewPassword(String? v) => switch (checkNewPin(v ?? '')) {
      PinCheck.format => 'Şifre 6 haneli rakamlardan oluşmalı.',
      PinCheck.weak => 'Çok kolay bir şifre; ardışık ya da aynı rakamlar kullanma.',
      PinCheck.ok => null,
    };

/// Dile göre hata metni veren yeni şifre doğrulayıcı (kuralları [validateNewPassword] ile aynı).
String? Function(String?) newPasswordValidator(BuildContext context) {
  final l = context.l10n;
  return (v) {
    return switch (checkNewPin(v ?? '')) {
      PinCheck.format => l.authPwMinErr,
      PinCheck.weak => l.authPinWeak,
      PinCheck.ok => null,
    };
  };
}
