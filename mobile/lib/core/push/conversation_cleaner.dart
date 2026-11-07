import 'package:flutter/services.dart';

import 'active_conversation.dart';
import 'push_actions.dart';

/// Sohbet okununca YALNIZ o sohbetin tepsideki bildirimlerini temizler; diğer sohbetlerin bildirimleri korunur.
///
/// Anahtar sunucu sözleşmesidir: Android'de bildirim etiketi `conv:<id>` (MessagingStyle birikimi + tepsi),
/// iOS'ta `aps.thread-id = conv:<id>` (teslim edilmiş bildirimler `threadIdentifier` ile süzülür). Her ikisi de yerel
/// kodda `dismissConversation` yöntemindedir. Platform sınırı: iOS uzaktan gönderilmiş bildirimi yalnız uygulama
/// çalışırken silebilir; uygulama zorla kapatılmışsa ya da arka planda hiç çalışmıyorsa temizlik bir sonraki açılışa kalır.
class ConversationNotificationCleaner {
  ConversationNotificationCleaner({
    required ActiveConversation active,
    Future<void> Function(String method, Map<String, Object?> args)? invoke,
  })  : _active = active,
        _invoke = invoke ?? _defaultInvoke {
    _active.addListener(_onChanged);
  }

  final ActiveConversation _active;
  final Future<void> Function(String method, Map<String, Object?> args) _invoke;
  int? _last;

  static Future<void> _defaultInvoke(String method, Map<String, Object?> args) =>
      PushActions.channel.invokeMethod<void>(method, args);

  /// Kullanıcının GERÇEKTEN baktığı sohbet (ön plan + açık) değiştiğinde o sohbetin bildirimleri silinir.
  void _onChanged() {
    final id = _active.viewingId;
    if (id == null) {
      _last = null;
      return;
    }
    if (id == _last) return;
    _last = id;
    dismissConversation(id);
  }

  /// Tek sohbetin bildirimlerini siler. Yerel kod yoksa (eski sürüm/test) ya da hata olursa sessiz.
  Future<void> dismissConversation(int conversationId) async {
    if (conversationId <= 0) return;
    try {
      await _invoke('dismissConversation', {'conversationId': conversationId});
    } on MissingPluginException {
      /* yerel kod yok */
    } on PlatformException {
      /* temizlik hatası akışı bozmaz */
    }
  }

  void dispose() => _active.removeListener(_onChanged);
}
