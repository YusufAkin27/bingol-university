import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../nav.dart';
import '../session.dart';
import 'push_router.dart';

const _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

/// FCM kaydı + ön plan şeridi + dokunuşla yönlendirme. Firebase yapılandırılmamışsa
/// (GoogleService-Info.plist yok) sessizce devre dışı kalır; uygulama etkilenmez.
class PushService {
  PushService(this.session);

  final Session session;

  bool _initTried = false;
  bool _enabled = false;
  String? _token;
  StreamSubscription? _refreshSub, _fgSub, _openSub;

  bool get enabled => _enabled;

  /// main.dart'ın AppLifecycleHooks listelerine bağlar. Örnek:
  /// `push.attach(onSignedIn: hooks.onSignedIn, onSignedOut: hooks.onSignedOut);`
  /// Listeler `Future<void> Function()` (veya `void Function()`) kabul eder. Oturum zaten
  /// açıksa çağrıyı kendisi yapmaz; gerekirse [onSignedIn] elle çağrılır.
  void attach({required List<Function> onSignedIn, required List<Function> onSignedOut}) {
    onSignedIn.add(() => this.onSignedIn());
    onSignedOut.add(() => this.onSignedOut());
  }

  Future<bool> _ensureInit() async {
    if (_initTried) return _enabled;
    _initTried = true;
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return false;
    try {
      await Firebase.initializeApp();
      _enabled = true;
    } catch (e) {
      debugPrint('Push devre disi (Firebase yapilandirilmamis): ${e.runtimeType}');
    }
    return _enabled;
  }

  Future<void> onSignedIn() async {
    PushRouter.session = session;
    if (!await _ensureInit()) return;
    try {
      final fm = FirebaseMessaging.instance;
      final perm = await fm.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      // Ön planda sistem şeridi yerine uygulama içi şerit gösteriyoruz.
      await fm.setForegroundNotificationPresentationOptions(alert: false, badge: false, sound: false);

      if (Platform.isIOS) {
        // APNs belirteci gecikebilir; kısa süre bekle.
        for (var i = 0; i < 10 && await fm.getAPNSToken() == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      // Yeni register()/onRegistered FCM jetonu değil Firebase Installation ID verir; sunucu FCM jetonu bekler.
      // ignore: deprecated_member_use
      final token = await fm.getToken();
      if (token != null) await _register(token);

      // ignore: deprecated_member_use
      _refreshSub ??= fm.onTokenRefresh.listen(_register, onError: (_) {});
      _fgSub ??= FirebaseMessaging.onMessage.listen(_showBanner);
      _openSub ??= FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data));
      final initial = await fm.getInitialMessage(); // soğuk açılış
      if (initial != null) _open(initial.data);
    } catch (e) {
      debugPrint('Push baslatilamadi: ${e.runtimeType}');
    }
  }

  Future<void> onSignedOut() async {
    final t = _token;
    _token = null;
    await _refreshSub?.cancel();
    await _fgSub?.cancel();
    await _openSub?.cancel();
    _refreshSub = _fgSub = _openSub = null;
    if (t == null) return;
    try {
      // Çıkışta belirteç oturum kapanmadan silinmeli; token yoksa sessizce geçer.
      await session.api.delete('/devices/${Uri.encodeComponent(t)}');
    } catch (_) {}
    if (_enabled) {
      try {
        // ignore: deprecated_member_use
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
  }

  Future<void> _register(String token) async {
    if (session.state != SessionState.signedIn) return;
    _token = token;
    try {
      await session.api.post('/devices', {
        'fcmToken': token,
        'platform': Platform.isIOS ? 'IOS' : 'ANDROID', // sunucu deseni: ANDROID|IOS|WEB
        'appVersion': _appVersion,
        'locale': session.api.lang,
      });
    } catch (_) {
      // Ağ hatasında bir sonraki açılışta yeniden denenir.
    }
  }

  void _showBanner(RemoteMessage m) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    final n = m.notification;
    final title = n?.title ?? '';
    final body = n?.body ?? '';
    if (title.isEmpty && body.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (body.isNotEmpty) Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        action: SnackBarAction(label: 'Aç', onPressed: () => _open(m.data)),
      ));
  }

  void _open(Map<String, dynamic> data) {
    final url = data['value'];
    if (('${data['target']}').toUpperCase() == 'URL') {
      // Yalnız https şemasına güvenilir; tarayıcı açma çağıran tarafın işi, burada bildirim listesine düşer.
      if (url is! String || !url.startsWith('https://')) return;
    }
    // Soğuk açılışta kabuk çizildikten sonra yönlendir.
    WidgetsBinding.instance.addPostFrameCallback((_) => PushRouter.open(data));
    WidgetsBinding.instance.scheduleFrame();
  }
}
