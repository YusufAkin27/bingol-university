import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../notify/local_reminders.dart';
import '../permissions/permission_service.dart';
import 'push_registrar.dart';
import 'push_service.dart';

/// "Bildirimler çalışmıyor mu?" ekranının okuduğu anlık durum.
@immutable
class PushHealth {
  const PushHealth({
    required this.supported,
    required this.osAllowed,
    this.blockedChannels = const [],
    this.registration = PushRegState.idle,
    this.lastRegisteredAt,
    this.manufacturer = '',
    this.isAndroid = false,
  });

  /// Bu derlemede Firebase/FCM var mı (yoksa push hiç çalışmaz).
  final bool supported;

  /// Sistem bildirim izni (uygulama düzeyi) açık mı.
  final bool osAllowed;

  /// Kullanıcının sistem ayarından kapattığı Android bildirim kanalları (kimlik: chat, event, ...).
  final List<String> blockedChannels;

  /// Bu cihazın sunucu kaydı.
  final PushRegState registration;
  final DateTime? lastRegisteredAt;

  /// Üretici (Android; küçük harf): "xiaomi", "huawei", "samsung"... Pil/otomatik başlatma metni için.
  final String manufacturer;
  final bool isAndroid;

  bool get chatBlocked => blockedChannels.contains('chat');

  /// Her şey yolunda mı (pil uyarısı hariç: o ölçülemez).
  bool get allGood =>
      supported && osAllowed && blockedChannels.isEmpty && registration == PushRegState.registered;

  /// Agresif pil yönetimi ile bilinen üreticiler (uygulama kapatılınca bildirim gelmeyebilir).
  bool get aggressiveOem => const {'xiaomi', 'redmi', 'poco', 'huawei', 'honor', 'oppo', 'realme', 'oneplus', 'vivo', 'samsung', 'tecno', 'infinix', 'meizu', 'asus', 'lenovo'}
      .contains(manufacturer);
}

/// Yardım ekranının kaynağı (testte sahtesi kullanılır).
abstract class PushHealthSource {
  Future<PushHealth> read();

  /// Jetonu yeniden alıp sunucuya kaydeder (zorla); sonra güncel durum okunur.
  Future<void> reregister();

  /// Uygulamanın bildirim ayarları (kanallar dahil); açılamazsa false.
  Future<bool> openNotificationSettings();

  /// Pil/arka plan ayarları (Android); açılamazsa false. İzin İSTENMEZ (Play politikası): yalnız ayar sayfası açılır.
  Future<bool> openBatterySettings();
}

/// Gerçek kaynak: [PushService] + Android platform kanalı (`bu_kampus/notify`).
class SystemPushHealthSource implements PushHealthSource {
  SystemPushHealthSource(this.push);

  final PushService? push;

  static const _ch = ChannelReminderBackend.channel;

  Future<Map<Object?, Object?>?> _diag() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      return await _ch.invokeMethod<Map<Object?, Object?>>('pushDiagnostics');
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PushHealth> read() async {
    final d = await _diag();
    var allowed = true;
    if (d != null && d['enabled'] is bool) {
      allowed = d['enabled'] as bool;
    } else {
      allowed = (await PermissionService.instance.status(AppPermission.notifications)).usable;
    }
    final blocked = <String>[
      if (d != null && d['blocked'] is List) for (final b in d['blocked'] as List) '$b',
    ];
    final reg = push?.registrar;
    return PushHealth(
      supported: push?.enabled ?? false,
      osAllowed: allowed,
      blockedChannels: blocked,
      registration: reg?.state ?? PushRegState.idle,
      lastRegisteredAt: reg?.lastOkAt,
      manufacturer: '${d?['manufacturer'] ?? ''}'.toLowerCase(),
      isAndroid: !kIsWeb && Platform.isAndroid,
    );
  }

  @override
  Future<void> reregister() async => push?.refresh(force: true);

  @override
  Future<bool> openNotificationSettings() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        return await _ch.invokeMethod<bool>('openNotificationSettings') ?? false;
      } catch (_) {}
    }
    return PermissionService.instance.openSettings();
  }

  @override
  Future<bool> openBatterySettings() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _ch.invokeMethod<bool>('openBatterySettings') ?? false;
    } catch (_) {
      return false;
    }
  }
}
