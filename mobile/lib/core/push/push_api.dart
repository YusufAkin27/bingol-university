import 'dart:async';

import '../api.dart';
import 'active_conversation.dart';

/// Push ile ilgili sunucu çağrıları (FCM'siz test edilebilsin diye ayrı sınıf).
/// Henüz yazılmamış uçlar (404/405/501) bir kez görülünce o uç oturum boyunca sessizce atlanır.
class PushApi {
  PushApi(this.api);
  final ApiClient api;

  bool _noState = false;
  bool _noViewing = false;

  Future<void> register(String token, {required String platform, required String appVersion}) async {
    await api.post('/devices', {
      'fcmToken': token,
      'platform': platform, // ANDROID|IOS
      'appVersion': appVersion,
      'locale': api.lang,
    });
  }

  Future<void> unregister(String token) => api.delete('/devices/${Uri.encodeComponent(token)}');

  bool _missing(Object e) => e is ApiError && (e.status == 404 || e.status == 405 || e.status == 501);

  /// `PUT /devices/{token}/state {foreground}` (uç yoksa sessiz).
  Future<void> setState(String token, bool foreground) async {
    if (_noState) return;
    try {
      await api.put('/devices/${Uri.encodeComponent(token)}/state', {'foreground': foreground});
    } catch (e) {
      if (_missing(e)) _noState = true;
    }
  }

  /// `PUT /conversations/{id}/viewing` (30 sn TTL'li görüntüleme sinyali).
  Future<void> viewing(int conversationId) async {
    if (_noViewing) return;
    try {
      await api.put('/conversations/$conversationId/viewing');
    } catch (e) {
      if (_missing(e)) _noViewing = true;
    }
  }

  Future<void> stopViewing(int conversationId) async {
    if (_noViewing) return;
    try {
      await api.delete('/conversations/$conversationId/viewing');
    } catch (e) {
      if (_missing(e)) _noViewing = true;
    }
  }
}

/// [ActiveConversation] değişince görüntüleme sinyalini yönetir: açıkken [interval]'de bir PUT,
/// kapanınca/arka plana alınınca DELETE.
class ViewingSignaler {
  ViewingSignaler(this.api, this.active, {this.interval = const Duration(seconds: 30)});

  final PushApi api;
  final ActiveConversation active;
  final Duration interval;

  int? _current;
  Timer? _timer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    active.addListener(_sync);
    _sync();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    active.removeListener(_sync);
    _timer?.cancel();
    _timer = null;
    final c = _current;
    _current = null;
    if (c != null) unawaited(api.stopViewing(c));
  }

  void _sync() {
    final next = active.viewingId;
    if (next == _current) return;
    final old = _current;
    _current = next;
    _timer?.cancel();
    _timer = null;
    if (old != null) unawaited(api.stopViewing(old));
    if (next != null) {
      unawaited(api.viewing(next));
      _timer = Timer.periodic(interval, (_) => unawaited(api.viewing(next)));
    }
  }
}
