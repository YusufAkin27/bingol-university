import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// `BuIcons.ttf` glifleri Hugeicons (MIT) verisinden türetilmiştir; MIT metni uygulamanın
/// lisans sayfasında (`showLicensePage` / `LicenseRegistry`) görünür olmalıdır.
/// 2. fazda `main()` içinde bir kez çağrılır. Tekrar çağrı zararsızdır.
void registerBuIconLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/licenses/hugeicons-MIT.txt');
    yield LicenseEntryWithLineBreaks(const ['Hugeicons (BuIcons yazı tipi glifleri)'], text);
  });
}
