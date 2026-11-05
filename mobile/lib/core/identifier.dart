import 'package:flutter/widgets.dart' show Locale;

import '../l10n/app_localizations.dart';
import 'locale_controller.dart';

/// Kimlik alanı: okul numarası (6-12 rakam) ya da tam e-posta (Gmail, Outlook, Hotmail, Yahoo, okul... her geçerli
/// sağlayıcı; alan adı kısıtı yoktur, yalnız biçim denetlenir). Yalnız rakam yazılırsa okul numarası sayılır ve
/// `@bingol.edu.tr` eklenir (eski davranış).
const kEmailDomain = 'bingol.edu.tr';

final _digitsRe = RegExp(r'^\d+$');

/// Giriş/şifre sıfırlama: gevşek biçim (eski hesaplar farklı yerel kısımlar taşıyabilir; sunucu karar verir).
final _emailRe = RegExp(r'^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$');

/// Kayıt: sunucunun biçim kuralıyla aynı (yerel kısım harf/rakam/_/-/+ ve tek noktalar; en az iki etiketli alan adı).
final _registerEmailRe = RegExp(
    r'^[a-z0-9_+\-]{1,64}(\.[a-z0-9_+\-]{1,64}){0,15}@([a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?\.){1,10}([a-z]{2,24}|xn--[a-z0-9\-]{2,58})$');

/// Boşluk ve tireleri temizler, küçük harfe çevirir. '@' içermeyen girdide nokta da atılır
/// (numara yapıştırılırken `226.051.015` gibi gelebilir) yalnız rakam kalıyorsa.
String normalizeIdentifier(String? raw) {
  var s = (raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s'), '');
  if (!s.contains('@')) {
    final cleaned = s.replaceAll('-', '').replaceAll('.', '');
    if (_digitsRe.hasMatch(cleaned)) return cleaned;
  }
  return s;
}

/// Yalnız rakamlardan oluşuyorsa (okul numarası yazılıyor).
bool isStudentNumberInput(String? raw) {
  final s = normalizeIdentifier(raw);
  return s.isNotEmpty && _digitsRe.hasMatch(s);
}

/// Numarayı `<numara>@bingol.edu.tr`'ye çevirir; e-posta olduğu gibi kalır.
String fullEmail(String identifier) {
  final s = normalizeIdentifier(identifier);
  return _digitsRe.hasMatch(s) ? '$s@$kEmailDomain' : s;
}

/// Kayıt alanı: yalnız TAM e-posta, herhangi bir sağlayıcı (numara kısayolu yok; kod, yazılan adrese gider). Giriş ve şifre
/// sıfırlama `validateIdentifier` ile numarayı kabul etmeye devam eder.
String? validateRegisterEmail(String? v) {
  final s = normalizeIdentifier(v);
  final l = lookupAppLocalizations(LocaleController.current?.locale ?? const Locale('tr'));
  if (s.isEmpty) return l.authRegIdEmpty;
  if (!s.contains('@')) return l.authRegIdFull;
  return _registerEmailRe.hasMatch(s) ? null : l.coreIdEmail;
}

/// Yalnız okul numarası alanı (6-12 rakam; artık hiçbir sayfada kullanılmaz, geriye dönük).
String? validateSchoolNumber(String? v) {
  final s = normalizeIdentifier(v);
  final l = lookupAppLocalizations(LocaleController.current?.locale ?? const Locale('tr'));
  if (s.isEmpty) return l.authIdNumberEmpty;
  if (_digitsRe.hasMatch(s) && s.length >= 6 && s.length <= 12) return null;
  return l.coreIdNumber;
}

String? validateIdentifier(String? v) {
  final s = normalizeIdentifier(v);
  final l = lookupAppLocalizations(LocaleController.current?.locale ?? const Locale('tr'));
  if (s.isEmpty) return l.coreIdEmpty;
  if (s.contains('@')) {
    return _emailRe.hasMatch(s) ? null : l.coreIdEmail;
  }
  if (_digitsRe.hasMatch(s) && s.length >= 6 && s.length <= 12) return null;
  return l.coreIdNumber;
}
