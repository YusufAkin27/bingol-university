import 'dart:async';

import 'package:flutter/widgets.dart';

import 'error_log.dart';
import 'session.dart';

/// Toplulaştırılmış, kişisel veri içermeyen kullanım olayları.
class Analytics {
  Analytics._();
  static final Analytics instance = Analytics._();

  static const maxBatch = 50;
  static const flushCount = 20;
  static const flushEvery = Duration(seconds: 20);

  Session? _session;
  Timer? _timer;
  final List<Map<String, dynamic>> _queue = [];
  bool _sending = false;

  /// Oturum sonlanınca bekleyen olayları gönderilmeden atar.
  void discard() => _queue.clear();

  void attach(Session session) {
    _session = session;
    _timer ??= Timer.periodic(flushEvery, (_) => flush());
  }

  /// '@' içeren değer kişisel veri sayılır: olay tümüyle atılır.
  static bool isSafe(Object? v) {
    if (v == null) return true;
    if (v is String) return !v.contains('@');
    if (v is Map) return v.values.every(isSafe) && v.keys.every(isSafe);
    if (v is Iterable) return v.every(isSafe);
    return true;
  }

  void track(String name, {String? screen, Map<String, dynamic>? props}) {
    if (!isSafe(name) || !isSafe(screen) || !isSafe(props)) return;
    // Oturum yokken biriktirme/gönderme yok.
    if (_session?.state != SessionState.signedIn) return;
    _queue.add({
      'name': name,
      if (screen != null) 'screen': screen,
      if (props != null && props.isNotEmpty) 'props': props,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    if (_queue.length > 200) _queue.removeRange(0, _queue.length - 200);
    if (_queue.length >= flushCount) flush();
  }

  void appOpen() => track('app_open');
  void screenView(String screen) => track('screen_view', screen: screen);
  void search() => track('search');

  Future<void> flush() async {
    final s = _session;
    if (_sending || _queue.isEmpty || s == null || s.state != SessionState.signedIn) return;
    _sending = true;
    final n = _queue.length < maxBatch ? _queue.length : maxBatch;
    final batch = _queue.sublist(0, n);
    _queue.removeRange(0, n);
    try {
      await s.api.post('/analytics/events', {'events': batch});
    } catch (_) {
      // Sessizce at.
    } finally {
      _sending = false;
    }
    if (_queue.length >= flushCount) unawaited(flush());
  }
}

/// Rota adlarından screen_view üretir (adsız rotalar atlanır).
class AnalyticsNavigatorObserver extends NavigatorObserver {
  void _view(Route<dynamic>? r) {
    final n = r?.settings.name;
    if (n == null || n.isEmpty || n == '/') return;
    ErrorLog.instance.currentScreen = n;
    Analytics.instance.screenView(n);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _view(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _view(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _view(previousRoute);
}
