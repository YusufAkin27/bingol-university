import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bildirim ayarları köprüsü (Android `BuNotifSettings.kt`, kanal `bu_kampus/notif_settings`).
///
/// - [openChannelSettings]: o bildirim kanalının sistem ayar sayfası (ses, titreşim, önem). Kanal kimlikleri:
///   chat, event, announcement, social, poll, academic, security. Android 8 altında uygulama ayarına düşer.
/// - [openAppNotificationSettings]: uygulamanın sistem bildirim ayarı (izin reddedildiyse buradan açılır).
/// - [setHidePreview]: kilit ekranında mesaj önizlemesini gizle (varsayılan KAPALI). Sunucu tercihiyle birlikte
///   çağrılır; açıkken native kart kilit ekranında "Yeni mesaj" gösterir.
///
/// Native kod yoksa (iOS/test) hepsi sessizce false/null döner; uygulama etkilenmez.
abstract class NotifSettings {
  static NotifSettings instance = ChannelNotifSettings();

  Future<bool> openChannelSettings(String channelId);
  Future<bool> openAppNotificationSettings();
  Future<bool> setHidePreview(bool hide);
  Future<bool> hidePreview();
  Future<bool> notificationsEnabled();
}

class ChannelNotifSettings implements NotifSettings {
  ChannelNotifSettings({bool? android}) : _android = android ?? _defaultAndroid();

  static const channel = MethodChannel('bu_kampus/notif_settings');

  final bool _android;

  static bool _defaultAndroid() {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _call(String method, [Object? args, bool fallback = false]) async {
    if (!_android) return fallback;
    try {
      return await channel.invokeMethod<bool>(method, args) ?? fallback;
    } on MissingPluginException {
      return fallback;
    } on PlatformException catch (e) {
      debugPrint('notif settings $method: ${e.code}');
      return fallback;
    }
  }

  @override
  Future<bool> openChannelSettings(String channelId) => _call('openChannelSettings', {'channelId': channelId});

  @override
  Future<bool> openAppNotificationSettings() => _call('openAppNotificationSettings');

  @override
  Future<bool> setHidePreview(bool hide) => _call('setHidePreview', {'hide': hide});

  @override
  Future<bool> hidePreview() => _call('hidePreview');

  @override
  Future<bool> notificationsEnabled() => _call('notificationsEnabled', null, true);
}

/// Testler için bellekte çalışan sahte uygulama.
class FakeNotifSettings implements NotifSettings {
  FakeNotifSettings({this.canOpen = true});

  final bool canOpen;
  final List<String> openedChannels = [];
  int appSettingsOpened = 0;
  bool hide = false;
  bool enabled = true;

  @override
  Future<bool> openChannelSettings(String channelId) async {
    if (!canOpen) return false;
    openedChannels.add(channelId);
    return true;
  }

  @override
  Future<bool> openAppNotificationSettings() async {
    if (!canOpen) return false;
    appSettingsOpened++;
    return true;
  }

  @override
  Future<bool> setHidePreview(bool value) async {
    hide = value;
    return true;
  }

  @override
  Future<bool> hidePreview() async => hide;

  @override
  Future<bool> notificationsEnabled() async => enabled;
}
