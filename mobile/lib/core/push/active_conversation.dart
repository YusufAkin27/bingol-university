import 'dart:async';

import 'package:flutter/foundation.dart';

/// Şu an AÇIK sohbet kimliği + uygulamanın ön planda olup olmadığı.
/// Sohbet sayfası açılınca [enter], kapanınca [leave] çağırır (başka hiçbir şey gerekmez).
/// [PushService] ön plan/arka plan durumunu [setForeground] ile besler ve `viewing` sinyalini bağlar.
class ActiveConversation extends ChangeNotifier {
  ActiveConversation._();
  static final ActiveConversation instance = ActiveConversation._();

  /// Testlerde yeni örnek kullanılabilsin.
  @visibleForTesting
  ActiveConversation.test();

  int? _open;
  bool _foreground = true;

  /// Açık sohbet (ön plan/arka plan fark etmeksizin ekranda olan).
  int? get openId => _open;

  /// Kullanıcının GERÇEKTEN baktığı sohbet: yalnız uygulama ön plandayken.
  int? get viewingId => _foreground ? _open : null;

  bool get foreground => _foreground;

  void enter(int id) {
    if (_open == id) return;
    _open = id;
    notifyListeners();
  }

  /// Yalnız o sohbet hâlâ açıksa kapatır (hızlı sohbet geçişlerinde yarış olmasın).
  void leave(int id) {
    if (_open != id) return;
    _open = null;
    // dispose sırasında çağrılabilir: dinleyicileri çerçeve sonrasına bırak.
    scheduleMicrotask(notifyListeners);
  }

  void setForeground(bool v) {
    if (_foreground == v) return;
    _foreground = v;
    notifyListeners();
  }

  /// Ön plan mesajı için yerel bildirim/şerit bastırılsın mı? (saf karar)
  bool shouldSuppress(Map<String, dynamic> data) {
    final v = viewingId;
    if (v == null) return false;
    final c = int.tryParse('${data['conversationId'] ?? ''}');
    if (c != null) return c == v;
    final t = '${data['targetType'] ?? data['target'] ?? ''}'.toUpperCase();
    if (t == 'CONVERSATION' || t == 'MESSAGE' || t == 'CHAT') {
      return int.tryParse('${data['targetId'] ?? data['value'] ?? ''}') == v;
    }
    return false;
  }
}
