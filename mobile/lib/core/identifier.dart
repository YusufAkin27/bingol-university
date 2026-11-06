import 'package:flutter/widgets.dart' show Locale;

import '../l10n/app_localizations.dart';
import 'locale_controller.dart';

// Kimlik alanı: yalnız tam e-posta (Gmail, Outlook, Hotmail, Yahoo, okul... her geçerli sağlayıcı). İstemci hiçbir alan
// adı eklemez ve engellemez: kullanıcı ne yazarsa o gider, yalnız biçim denetlenir. (Sunucu eski "okul numarası" kısayolunu
// hâlâ kabul eder; istemci artık rakam-only göndermez, bkz. docs/MOBILE_API_GUIDE.md.)

/// Giriş/şifre sıfırlama: gevşek biçim (eski hesaplar farklı yerel kısımlar taşıyabilir; sunucu karar verir).
final _emailRe = RegExp(r'^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$');

/// Kayıt: sunucunun biçim kuralıyla aynı (yerel kısım harf/rakam/_/-/+ ve tek noktalar; en az iki etiketli alan adı).
final _registerEmailRe = RegExp(
    r'^[a-z0-9_+\-]{1,64}(\.[a-z0-9_+\-]{1,64}){0,15}@([a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?\.){1,10}([a-z]{2,24}|xn--[a-z0-9\-]{2,58})$');

/// Boşlukları temizler, küçük harfe çevirir. Başka hiçbir dönüşüm yoktur (alan adı eklenmez).
String normalizeIdentifier(String? raw) => (raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s'), '');

/// Kayıt alanı: yalnız TAM e-posta, herhangi bir sağlayıcı; kod, yazılan adrese gider.
String? validateRegisterEmail(String? v) {
  final s = normalizeIdentifier(v);
  final l = lookupAppLocalizations(LocaleController.current?.locale ?? const Locale('tr'));
  if (s.isEmpty) return l.authRegIdEmpty;
  if (!s.contains('@')) return l.authRegIdFull;
  // Tek posta kutusu = tek hesap: sunucu +etiketi 400 EMAIL_ALIAS_NOT_ALLOWED ile reddeder; istemci istek atmadan söyler.
  if (s.substring(0, s.indexOf('@')).contains('+')) return l.errEmailAliasNotAllowed;
  return _registerEmailRe.hasMatch(s) ? null : l.coreIdEmail;
}

/// Giriş ve şifre sıfırlama alanı: gevşek e-posta biçimi; geçerli e-posta yoksa "Geçerli bir e-posta adresi girin".
String? validateIdentifier(String? v) {
  final s = normalizeIdentifier(v);
  final l = lookupAppLocalizations(LocaleController.current?.locale ?? const Locale('tr'));
  if (s.isEmpty) return l.coreIdEmpty;
  return _emailRe.hasMatch(s) ? null : l.coreIdEmail;
}
