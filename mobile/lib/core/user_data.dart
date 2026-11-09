import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/academic/alarm_service.dart';
import '../features/academic/reminders.dart';
import '../features/menu/menu_reminder.dart';
import '../features/auth/data/onboarding_api.dart' show OnboardingDraftStore;
import '../features/auth/help/public_support_api.dart' show TrackTokenStore;
import '../features/chat/chat_wallpaper.dart';
import '../features/chat/photo_autosave.dart';
import '../features/chat/recent_reactions.dart';
import '../features/forum/data/forum_draft_store.dart';
import '../features/forum/data/forum_recent_searches.dart';
import '../features/home/home_layout.dart';
import '../features/search/recent_searches.dart';
import '../features/widgets/widget_sync_service.dart';
import 'api.dart';
import 'cache/image_disk_cache.dart';
import 'cache/message_cache.dart';
import 'cache/video_cover_cache.dart';
import 'cache/video_prefetch.dart';
import 'language_sync.dart';
import 'live/live_activity_service.dart';
import 'swallow.dart';

/// Çıkış / hesap değişimi / hesap silme / oturum iptalinde silinmesi gereken kullanıcıya özel yerel depoların
/// TEK kayıt noktası ([ApiClient.setTokens] bu kancaları çalıştırır). Kural: kullanıcıya özel veri tutan her yeni
/// yerel depo buraya bir temizleyici ekler ve `test/a15/a15_cache_test.dart` S2.9 envanterine girer
/// (docs/MOBILE_UI.md 4.2). Bekleyen mesaj kuyruğu, ETag/disk önbelleği ve oturum belirteçleri zaten
/// [ApiClient.setTokens] / `Session` içinde temizlenir.
///
/// Cihaza özel (hesaptan bağımsız) anahtarlar bilerek KALIR: device_id, welcome_seen, perms_onboarded,
/// theme_mode, app_language, crash_reports_enabled, analytics_enabled, update_notice_shown.
void registerUserDataCleaners(ApiClient api) {
  api.onUserDataCleared
    ..add(() => MessageCache.instance.clear())
    ..add(() => ImageDiskCache.instance.clear())
    ..add(() => VideoCoverCache.instance.clear()) // istemcinin ürettiği video kapakları (bellek; disk yukarıda)
    ..add(() => VideoPrefetcher.instance.clear()) // Keşfet önyüklenmiş videoları (yetkili, kullanıcıya özel içerik)
    ..add(RecentSearches.clear) // arama geçmişi (kişi adı olabilir)
    ..add(ForumRecentSearches.clear) // forum son aramaları (cihazda, kullanıcıya özel)
    ..add(ForumDraftStore.clearAll) // yarım kalan forum konu taslakları (başlık/metin/görsel adresi)
    ..add(() => PhotoAutoSave.instance.reset()) // galeriye otomatik kayıt ayarı + kaydedilen ek kimlikleri
    ..add(ReminderService.clearUserData) // ders hatırlatıcı ayarı + kurulu yerel hatırlatmalar
    ..add(() => MenuReminderService.instance.clearUserData()) // günlük menü hatırlatıcısı tercihi + bildirimleri
    ..add(AlarmService.clearUserData) // ertelenmiş sınav alarmları + hatırlatmaları + iOS alarm bildirimleri
    ..add(LanguageSync.clear) // son eşitlenen profil dili
    ..add(ChatBackgroundPrefs.clear) // sohbet arka planı tercihi (Desen/Hafif/Orta/Düz)
    ..add(RecentReactions.clear) // hesaba ozel son alti tepki
    ..add(_clearRemovedMapData) // kaldırılan harita özelliğinin eski sürümlerden kalan yerel verisi
    ..add(WidgetSyncService.clearUserData) // ana ekran widget snapshot'ları + kısayol sırası (widget "Giriş yap" durumuna döner)
    ..add(HomeLayoutStore.clear) // Ana Sayfa düzeni (bölüm sırası/görünürlüğü + Hızlı Erişim kısayolları)
    ..add(LiveActivityService.clearUserData) // iOS Canlı Etkinlik / Android canlı güncelleme (kullanıcının kendi geri sayımları)
    ..add(OnboardingDraftStore.clearShared) // Apple'ın bir kez verdiği geçici ad (hesap taslakları hesap bazlıdır, Session.signOut siler)
    ..add(TrackTokenStore.clear) // herkese açık destek talebinin takip jetonu (e-postaya bağlı)
    ..add(_clearLegalLater); // "sözleşme onayını sonra yap" işareti (kullanıcı kimliği içerir)
}

/// Kaldırılan kampüs haritasının eski sürümlerde yazdığı yerel anahtarlar (favori yerler, son aramalar, izin kartı
/// tercihi); güncelleme sonrası ilk çıkışta cihazdan silinir. Yeni kod bu anahtarları yazmaz.
Future<void> _clearRemovedMapData() async {
  try {
    const s = FlutterSecureStorage();
    for (final k in const ['campus_favorites', 'campus_recent_searches', 'campus_loc_prompt_dismissed']) {
      await s.delete(key: k);
    }
  } catch (e) {
    swallow('user_data.1', e);
  }
}

/// `LegalReacceptController` `legal_later` anahtarı (`<kullanıcı>|<imza>`); çıkışta kalmasın.
Future<void> _clearLegalLater() async {
  try {
    await const FlutterSecureStorage().delete(key: 'legal_later');
  } catch (e) {
    swallow('user_data.2', e);
  }
}
