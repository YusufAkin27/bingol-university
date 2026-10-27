import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../l10n/app_localizations.dart';

/// Desteklenen arayüz dilleri.
const kSupportedLangs = ['tr', 'en', 'ar'];

/// Çözüm sırası: kullanıcı seçimi (tr/en/ar) > cihaz dili (destekleniyorsa) > İngilizce.
/// [pref] 'system' ya da dil kodudur; [deviceLocales] cihazın tercih sırasıdır.
Locale resolveAppLocale(String pref, Iterable<Locale> deviceLocales) {
  if (kSupportedLangs.contains(pref)) return Locale(pref);
  for (final l in deviceLocales) {
    if (kSupportedLangs.contains(l.languageCode)) return Locale(l.languageCode);
  }
  return const Locale('en');
}

/// Uygulama dili: Sistem / Türkçe / English / العربية. Seçim cihazda saklanır;
/// çözülen kod [onResolved] ile ApiClient.lang'a (Accept-Language) aktarılır.
class LocaleController extends ChangeNotifier {
  LocaleController({this.onResolved, List<Locale> Function()? deviceLocales})
      : _device = deviceLocales ?? (() => PlatformDispatcher.instance.locales) {
    onResolved?.call(locale.languageCode);
  }

  /// Uygulama genelinde tek örnek (main kurar); ayarlar sayfası buradan okur.
  static LocaleController? current;

  final void Function(String code)? onResolved;
  final List<Locale> Function() _device;
  final _storage = const FlutterSecureStorage();
  static const _key = 'app_language';

  /// 'system' | 'tr' | 'en' | 'ar'
  String pref = 'system';

  Locale get locale => resolveAppLocale(pref, _device());

  Future<void> load() async {
    try {
      final v = await _storage.read(key: _key);
      if (v != null && (v == 'system' || kSupportedLangs.contains(v))) pref = v;
    } catch (_) {}
    _apply();
  }

  Future<void> set(String p) async {
    pref = p;
    _apply();
    try {
      await _storage.write(key: _key, value: p);
    } catch (_) {}
  }

  /// Cihaz dili değişti (sistem seçiliyse etkili olur).
  void deviceLocalesChanged() {
    if (pref == 'system') _apply();
  }

  void _apply() {
    onResolved?.call(locale.languageCode);
    notifyListeners();
  }
}

/// Test/eski widget ağaçlarında temsilci yoksa Türkçe metne düşer.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this) ?? lookupAppLocalizations(const Locale('tr'));
}
