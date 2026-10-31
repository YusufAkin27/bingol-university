import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/academic/reminders.dart';
import '../features/chat/photo_autosave.dart';
import '../features/search/recent_searches.dart';
import 'api.dart';
import 'cache/image_disk_cache.dart';
import 'cache/message_cache.dart';
import 'language_sync.dart';

/// Çıkış / hesap değişimi / hesap silme / oturum iptalinde silinmesi gereken kullanıcıya özel yerel depoların
/// TEK kayıt noktası ([ApiClient.setTokens] bu kancaları çalıştırır). Kural: kullanıcıya özel veri tutan her yeni
/// yerel depo buraya bir temizleyici ekler ve `test/a15/a15_cache_test.dart` S2.9 envanterine girer
/// (docs/MOBILE_UI.md 4.2). Bekleyen mesaj kuyruğu, ETag/disk önbelleği ve oturum belirteçleri zaten
/// [ApiClient.setTokens] / `Session` içinde temizlenir.
///
/// Cihaza özel (hesaptan bağımsız) anahtarlar bilerek KALIR: device_id, welcome_seen, perms_onboarded,
/// theme_mode, app_language, crash_reports_enabled, update_notice_shown.
void registerUserDataCleaners(ApiClient api) {
  api.onUserDataCleared
    ..add(() => MessageCache.instance.clear())
    ..add(() => ImageDiskCache.instance.clear())
    ..add(RecentSearches.clear) // arama geçmişi (kişi adı olabilir)
    ..add(() => PhotoAutoSave.instance.reset()) // galeriye otomatik kayıt ayarı + kaydedilen ek kimlikleri
    ..add(ReminderService.clearUserData) // ders hatırlatıcı ayarı + kurulu yerel hatırlatmalar
    ..add(LanguageSync.clear) // son eşitlenen profil dili
    ..add(_clearLegalLater); // "sözleşme onayını sonra yap" işareti (kullanıcı kimliği içerir)
}

/// `LegalReacceptController` `legal_later` anahtarı (`<kullanıcı>|<imza>`); çıkışta kalmasın.
Future<void> _clearLegalLater() async {
  try {
    await const FlutterSecureStorage().delete(key: 'legal_later');
  } catch (_) {}
}
