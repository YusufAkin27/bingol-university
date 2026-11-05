import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../notify/local_reminders.dart';
import '../session.dart';

/// "Mesaj içeriğini gizle" tercihinin cihaza (Android yerel koduna) yansıması.
///
/// Kaynak gerçek sunucudur (`GET/PUT /notifications/preferences` > `hideMessagePreview`): açıkken sunucu push
/// gövdesini "Yeni mesaj"a çevirir. Zengin bildirimleri yerel kodun çizdiği Android'de kilit ekranı gizliliği için
/// değer ayrıca `bu_kampus/notify` kanalının `setHidePreview {hide: bool}` yöntemiyle yerel koda iletilir; yerel
/// kod bunu paylaşılan tercihlerde `bu.pref.hide_preview` (boolean) anahtarına yazar. Yerel kod yoksa
/// (eski derleme, iOS) çağrı sessizce yok sayılır: iOS'ta sunucu tarafı gizleme yeterlidir.
class PushPrivacy {
  PushPrivacy._();

  /// Testte değiştirilir.
  @visibleForTesting
  static Future<void> Function(bool hide) sink = _channelSink;

  static Future<void> _channelSink(bool hide) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await ChannelReminderBackend.channel.invokeMethod<void>('setHidePreview', {'hide': hide});
    } on MissingPluginException {
      /* yerel kod yok */
    } on PlatformException {
      /* yerel hata tercihleri bozmaz */
    }
  }

  /// Yerel koda iletir; hata sızdırmaz.
  static Future<void> apply(bool hide) async {
    try {
      await sink(hide);
    } catch (_) {}
  }

  /// Oturum açılınca sunucudaki değeri yerel koda taşır (yeni cihaz/yeniden kurulum/hesap değişimi).
  /// Alan sunucuda yoksa (eski sunucu) hiçbir şey yapmaz.
  static Future<void> syncFromServer(Session session) async {
    try {
      final p = await session.api.get('/notifications/preferences');
      final v = p is Map ? p['hideMessagePreview'] : null;
      if (v is bool) await apply(v);
    } catch (_) {}
  }
}
