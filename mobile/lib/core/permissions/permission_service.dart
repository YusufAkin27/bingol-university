import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Uygulamanın istediği izinler (paket türlerinden bağımsız; testte sahte servisle değiştirilir).
enum AppPermission { notifications, contacts, camera, microphone, photos }

/// İzin durumu. [unavailable]: bu platformda/ortamda sorgulanamadı (örn. test, masaüstü);
/// çağıran engellemez, işlemi dener (image_picker gibi kendi istemini yapan paketler devralır).
enum PermState { granted, denied, permanentlyDenied, restricted, unavailable }

extension PermStateX on PermState {
  /// Özelliği kullanmaya devam edilebilir mi.
  bool get usable => this == PermState.granted || this == PermState.unavailable;

  /// Sistem istemi artık çıkmaz; yalnız Ayarlar'dan açılabilir.
  bool get needsSettings => this == PermState.permanentlyDenied || this == PermState.restricted;
}

/// İzin sorgu/istek arayüzü. Uygulama [PermissionService.instance] üzerinden kullanır;
/// testlerde `PermissionService.instance = FakePermissionService()` ile platform kanalı çağrılmaz.
abstract class PermissionService {
  static PermissionService instance = SystemPermissionService();

  Future<PermState> status(AppPermission p);

  /// Sistem iznini ister (zaten verilmiş/kalıcı reddedilmişse istem çıkmaz, güncel durum döner).
  Future<PermState> request(AppPermission p);

  /// Uygulamanın sistem ayarları sayfasını açar.
  Future<bool> openSettings();
}

/// `permission_handler` (Android + iOS; iOS SwiftPM destekli: izin anahtarları Info.plist'ten okunur).
class SystemPermissionService implements PermissionService {
  ph.Permission _map(AppPermission p) => switch (p) {
        AppPermission.notifications => ph.Permission.notification,
        AppPermission.contacts => ph.Permission.contacts,
        AppPermission.camera => ph.Permission.camera,
        AppPermission.microphone => ph.Permission.microphone,
        AppPermission.photos => ph.Permission.photos,
      };

  PermState _state(ph.PermissionStatus s) => switch (s) {
        ph.PermissionStatus.granted ||
        ph.PermissionStatus.limited ||
        ph.PermissionStatus.provisional =>
          PermState.granted,
        ph.PermissionStatus.denied => PermState.denied,
        ph.PermissionStatus.permanentlyDenied => PermState.permanentlyDenied,
        ph.PermissionStatus.restricted => PermState.restricted,
      };

  @override
  Future<PermState> status(AppPermission p) async {
    try {
      return _state(await _map(p).status);
    } catch (e) {
      debugPrint('Izin durumu okunamadi: ${e.runtimeType}');
      return PermState.unavailable;
    }
  }

  @override
  Future<PermState> request(AppPermission p) async {
    try {
      return _state(await _map(p).request());
    } catch (e) {
      debugPrint('Izin istenemedi: ${e.runtimeType}');
      return PermState.unavailable;
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await ph.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}

/// Testler ve geliştirme için bellekte çalışan servis.
class FakePermissionService implements PermissionService {
  FakePermissionService({Map<AppPermission, PermState>? initial, Map<AppPermission, PermState>? onRequest})
      : states = {...?initial},
        _onRequest = {...?onRequest};

  /// Güncel durumlar (yoksa [PermState.denied]).
  final Map<AppPermission, PermState> states;
  final Map<AppPermission, PermState> _onRequest;

  /// `request` çağrılan izinler (sırayla).
  final List<AppPermission> requested = [];
  int settingsOpened = 0;

  /// `request` sonucu: verilmediyse [PermState.granted].
  void willAnswer(AppPermission p, PermState s) => _onRequest[p] = s;

  @override
  Future<PermState> status(AppPermission p) async => states[p] ?? PermState.denied;

  @override
  Future<PermState> request(AppPermission p) async {
    requested.add(p);
    final cur = states[p] ?? PermState.denied;
    if (cur.needsSettings || cur == PermState.granted) return cur;
    final next = _onRequest[p] ?? PermState.granted;
    states[p] = next;
    return next;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}
