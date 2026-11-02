import 'dart:async';
import 'dart:io' show Directory, Platform;
import 'dart:ui' show DartPluginRegistrant, Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../api.dart';
import '../../device_identity.dart';
import '../../locale_controller.dart' show resolveAppLocale;
import '../../secure_store.dart';
import 'rich_card.dart';
import 'rich_images.dart';
import 'rich_notifier.dart';
import 'rich_runner.dart';

/// Zengin Android bildirimi cephesi: veri-mesajını (`richChat=1`) tasarımdaki karta çevirip `flutter_local_notifications`
/// ile çizer; eylemleri (satır içi yanıt, okundu, sessize al, takip, onay/ret, "ben değilim") arka plan isolate'inde
/// kayıtlı oturum belirteçleriyle mevcut `ApiClient` üzerinden yürütür.
///
/// Test edilebilir saf parçalar: `rich_card.dart` (yük -> kart), `rich_actions.dart` (eylem -> istek),
/// `rich_notifier.dart` (kart -> Android ayrıntıları), `rich_runner.dart` (iş akışı). Bu dosya yalnız eklenti/disk/oturum
/// yapıştırıcısıdır; GERÇEK CİHAZDA denenmemiştir (bkz. docs/MOBILE_PUSH.md "Zengin bildirim").
class RichNotifications {
  RichNotifications({FlutterLocalNotificationsPlugin? plugin, RichImages? images})
      : plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _images = images;

  static final RichNotifications instance = RichNotifications();

  final FlutterLocalNotificationsPlugin plugin;
  RichImages? _images;
  bool _initialized = false;

  /// Yalnız Android (iOS kategorileri ayrı: `RichNotifications.initIos` yok, bkz. docs/IOS_RELEASE.md NSE notu).
  static bool get supported => !kIsWeb && Platform.isAndroid;

  Future<bool> init({
    DidReceiveNotificationResponseCallback? onResponse,
    DidReceiveBackgroundNotificationResponseCallback? onBackground,
  }) async {
    if (!supported) return false;
    if (_initialized) return true;
    try {
      await plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings(kRichSmallIcon)),
        onDidReceiveNotificationResponse: onResponse,
        onDidReceiveBackgroundNotificationResponse: onBackground,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Zengin bildirim baslatilamadi: ${e.runtimeType}');
    }
    return _initialized;
  }

  /// Soğuk başlatmada bildirime dokunarak açıldıysa o yanıt (yoksa null).
  Future<NotificationResponse?> launchResponse() async {
    if (!_initialized) return null;
    try {
      final d = await plugin.getNotificationAppLaunchDetails();
      if (d == null || !d.didNotificationLaunchApp) return null;
      return d.notificationResponse;
    } catch (_) {
      return null;
    }
  }

  Future<RichImages> _img() async {
    final existing = _images;
    if (existing != null) return existing;
    Directory? dir;
    try {
      dir = Directory('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}rich_notif');
    } catch (_) {
      dir = null;
    }
    return _images = RichImages(cacheDir: dir);
  }

  Future<Uint8List?> _tile(RichKind k) async {
    try {
      final name = kRichSpecs[k]?.tile ?? 'generic';
      final d = await rootBundle.load('assets/notif/tile_$name.png');
      return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  /// Yük -> görseller -> kart. Zengin değilse (ya da çizilemezse) false; çağıran standart yolu kullanır.
  Future<bool> showFromData(Map<String, dynamic> data, {AppLocalizations? l10n}) async {
    final card = RichCard.tryParse(data);
    if (card == null || !_initialized) return false;
    try {
      final l = l10n ?? lookupAppLocalizations(await resolveLocale());
      final images = await _img();
      final person = isPersonKind(card.kind);
      final wide = card.imageStyle == RichImageStyle.big || (person && card.imageStyle == RichImageStyle.thumb);
      // Avatar ve görsel birlikte beklenir (ayrı zaman aşımı bütçeleri).
      final results = await Future.wait<Uint8List?>([
        person
            ? images.avatar(card.senderAvatarUrl,
                card.senderName.isNotEmpty ? card.senderName : card.title,
                count: card.kind == RichKind.messageBurst ? card.count : null,
                group: card.kind == RichKind.groupMessage || card.groupBadge)
            : Future<Uint8List?>.value(null),
        card.imageStyle == RichImageStyle.none ? Future<Uint8List?>.value(null) : images.picture(card.imageUrl, wide: wide),
        person ? Future<Uint8List?>.value(null) : _tile(card.kind),
      ]);
      final render = RichRender(card, avatar: results[0], picture: results[1], tile: results[2]);
      final details = buildAndroidDetails(render, l);
      await plugin.show(
        id: card.notificationId,
        title: isMessageKind(card.kind) && card.senderName.isNotEmpty ? card.senderName : card.title,
        body: card.body,
        notificationDetails: NotificationDetails(android: details),
        payload: richPayloadOf(card),
      );
      return true;
    } catch (e) {
      debugPrint('Zengin bildirim cizilemedi: ${e.runtimeType}');
      return false;
    }
  }

  /// Çıkışta: bu uygulamanın gösterdiği tüm bildirimleri kaldırır (başka hesabın içeriği görünmesin).
  Future<void> removeAllShown() async {
    if (!_initialized) return;
    try {
      await plugin.cancelAll();
    } catch (_) {}
  }

  Future<void> remove(RichCard c) async {
    try {
      await plugin.cancel(id: c.notificationId, tag: c.tag);
    } catch (_) {}
  }

  /// Eylem başarısız: aynı kimlik/etiketle kartın yerine kısa hata bildirimi (dokunuş sohbeti/hedefi açar).
  Future<void> showFailure(RichCard c, {AppLocalizations? l10n}) async {
    final l = l10n ?? lookupAppLocalizations(await resolveLocale());
    final meta = channelMeta(c.channelId, l);
    await _plain(
      id: c.notificationId,
      tag: c.tag,
      title: l.notifActFailedTitle,
      body: l.notifActFailed,
      channelId: c.channelId,
      channelName: meta.name,
      payload: richPayloadOf(c),
    );
  }

  /// `not_me` başarılı: oturumlar kapandı + şifre sıfırlama önerisi (güvenlik kanalı).
  Future<void> showNotMeDone(RichCard c, {AppLocalizations? l10n}) async {
    final l = l10n ?? lookupAppLocalizations(await resolveLocale());
    await _plain(
      id: c.notificationId,
      tag: c.tag,
      title: l.notifActNotMeTitle,
      body: l.notifActNotMeBody,
      channelId: 'security',
      channelName: l.bildirimmobilKanalSecurity,
      payload: richPayloadOf(c),
    );
  }

  Future<void> _plain({
    required int id,
    required String tag,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String payload,
  }) async {
    try {
      await plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            icon: kRichSmallIcon,
            color: kRichAccent,
            tag: tag,
            styleInformation: BigTextStyleInformation(body, contentTitle: title),
            visibility: NotificationVisibility.public,
          ),
        ),
        payload: payload,
      );
    } catch (_) {}
  }

  /// Kayıtlı uygulama dili (`app_language`), yoksa cihaz dili.
  static Future<Locale> resolveLocale({FlutterSecureStorage? storage}) async {
    String pref = 'system';
    try {
      pref = await (storage ?? const FlutterSecureStorage()).read(key: 'app_language') ?? 'system';
    } catch (_) {}
    return resolveAppLocale(pref, PlatformDispatcher.instance.locales);
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Arka plan: FCM veri-mesajı + bildirim eylemleri

/// Arka plan isolate'inde oturum belirteçleriyle çalışan API istemcisi.
/// Belirteçler ana uygulamayla AYNI güvenli depodadır (`access`/`refresh`); yenileme yazılırsa depoya geri yazılır.
/// Not: refresh belirteci tek kullanımlıktır; ana isolate bellekteki eskiyi tutuyorsa öne gelince depodan yeniden okur
/// (`Session.reloadTokensFromStore`, PushService çağırır).
Future<ApiClient?> openBackgroundApi({FlutterSecureStorage? storage, ApiClient? client}) async {
  final s = storage ?? kDeviceSecureStorage;
  try {
    final signedOut = await s.read(key: 'signed_out');
    final a = await s.read(key: 'access');
    final r = await s.read(key: 'refresh');
    if (signedOut == '1' || a == null || r == null || a.isEmpty || r.isEmpty) return null;
    try {
      await DeviceIdentity.instance.load();
    } catch (_) {}
    final api = client ?? ApiClient();
    api.tokens = Tokens(a, r);
    api.onTokensChanged = (t) async {
      try {
        if (t == null) {
          await s.delete(key: 'access');
          await s.delete(key: 'refresh');
        } else {
          await s.write(key: 'access', value: t.access);
          await s.write(key: 'refresh', value: t.refresh);
        }
      } catch (_) {}
    };
    final loc = await RichNotifications.resolveLocale();
    api.lang = loc.languageCode;
    return api;
  } catch (_) {
    return null;
  }
}

/// `ApiClient`'ı [RichExec]'e çevirir.
RichExec execOf(ApiClient api) => (method, path, body) {
      switch (method) {
        case 'POST':
          return api.post(path, body);
        case 'PUT':
          return api.put(path, body);
        case 'PATCH':
          return api.patch(path, body ?? const <String, dynamic>{});
        case 'DELETE':
          return api.delete(path, body);
        default:
          return api.get(path);
      }
    };

/// Eylem yürütücüsü: bildirim işlemleri [notifier] ile.
RichActionRunner buildRunner(RichNotifications notifier, RichExec? exec) => RichActionRunner(
      exec: exec,
      remove: notifier.remove,
      fail: (c) => notifier.showFailure(c),
      confirm: (c) => notifier.showNotMeDone(c),
    );

/// FCM arka plan işleyicisinin zengin yolu: `richChat=1` değilse HİÇBİR ŞEY yapmaz (standart sistem bildirimi aynen kalır).
/// true = zengin kart çizildi.
Future<bool> handleRichBackgroundMessage(Map<String, dynamic> data, {RichNotifications? notifier}) async {
  if (!RichCard.isRich(data)) return false;
  if (!RichNotifications.supported) return false;
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (_) {}
  final n = notifier ?? RichNotifications.instance;
  if (!await n.init(onBackground: richBackgroundResponse)) return false;
  return n.showFromData(data);
}

/// Arayüz açmayan bildirim eylemi (satır içi yanıt, okundu, sessize al, takip, onay/ret, "ben değilim"):
/// ayrı isolate'te çalışır (eklenti çağırır). Üst düzey + entry-point olmak ZORUNDADIR.
@pragma('vm:entry-point')
Future<void> richBackgroundResponse(NotificationResponse r) async {
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (_) {}
  final actionId = r.actionId;
  if (actionId == null || actionId.isEmpty) return;
  final data = richPayloadParse(r.payload);
  if (data.isEmpty) return;
  final notifier = RichNotifications.instance;
  await notifier.init();
  final api = await openBackgroundApi();
  final runner = buildRunner(notifier, api == null ? null : execOf(api));
  await runner.run(actionId, data, input: r.input);
}
