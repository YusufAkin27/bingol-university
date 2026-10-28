import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../features/auth/permissions_page.dart';
import '../locale_controller.dart';
import '../notify/local_reminders.dart';
import '../session.dart';
import '../../l10n/app_localizations.dart';
import 'active_conversation.dart';
import 'push_api.dart';
import 'push_banner.dart';
import 'push_router.dart';

const _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

/// Arka plan / kapalı durum işleyicisi: top-level + entry-point olmalı (ayrı isolate'ta çalışır).
/// Sunucu `notification` bloklu mesaj gönderdiği için sistem bildirimi kendisi gösterir; burada yalnız
/// Firebase hazırlanır (yük işlenmez, UI/oturuma dokunulmaz). Dokunuş [PushService] ile yönlendirilir.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// FCM jetonunu alır. iOS'ta APNs belirteci (anahtar/izin/imza hazırsa) birkaç saniye içinde gelir; gelmeden
/// FCM jetonu istenirse eklenti `apns-token-not-set` fırlatır veya null döner. Bu yüzden önce APNs beklenir
/// ([attempts] x [delay]), sonra jeton alınır; hata/null olursa sınırlı sayıda yeniden denenir. Hâlâ yoksa null
/// döner (APNs anahtarı/imza yok): uygulama etkilenmez, jeton sonradan `onTokenRefresh` ile gelir.
@visibleForTesting
Future<String?> fetchPushToken({
  required bool isIOS,
  required Future<String?> Function() apns,
  required Future<String?> Function() fcm,
  int attempts = 20,
  Duration delay = const Duration(milliseconds: 500),
}) async {
  if (isIOS) {
    for (var i = 0; i < attempts; i++) {
      try {
        if (await apns() != null) break;
      } catch (_) {}
      await Future<void>.delayed(delay);
    }
  }
  final tries = isIOS ? 3 : 1;
  for (var i = 0; i < tries; i++) {
    try {
      final t = await fcm();
      if (t != null && t.isNotEmpty) return t;
    } catch (_) {}
    if (i < tries - 1) await Future<void>.delayed(delay);
  }
  return null;
}

/// Ön plan bildirimi için uygulama içi şerit. Sessiz saat ve tür tercihleri SUNUCUDA uygulanır (kapalı
/// türde/sessiz saatte push hiç gelmez); gelen her ön plan mesajı gösterilir. Başlık+gövde boşsa gösterilmez.
/// Aynı anda tek şerit; [onOpen] "Aç" eylemidir. Gösterildiyse true.
bool showPushBanner(
  BuildContext? ctx, {
  required String title,
  required String body,
  required VoidCallback onOpen,
  String? actionLabel,
}) {
  if (ctx == null || (title.isEmpty && body.isEmpty)) return false;
  final messenger = ScaffoldMessenger.maybeOf(ctx);
  if (messenger == null) return false;
  messenger
    ..hideCurrentSnackBar()
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
      action: SnackBarAction(label: actionLabel ?? ctx.l10n.coreOpen, onPressed: onOpen),
    ));
  return true;
}

/// FCM kaydı + ön plan şeridi + dokunuşla yönlendirme. Firebase yapılandırılmamışsa
/// (GoogleService-Info.plist yok) sessizce devre dışı kalır; uygulama etkilenmez.
class PushService with WidgetsBindingObserver {
  PushService(this.session, {ActiveConversation? active})
      : active = active ?? ActiveConversation.instance,
        _api = PushApi(session.api);

  final Session session;
  final ActiveConversation active;
  final PushApi _api;
  ViewingSignaler? _viewing;
  bool _observing = false;

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
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _enabled = true;
    } catch (e) {
      debugPrint('Push devre disi (Firebase yapilandirilmamis): ${e.runtimeType}');
    }
    return _enabled;
  }

  bool _tapBridge = false;

  /// Yerel hatırlatma dokunuşları (soğuk başlatma: bekleyen yük; ön plan: 'onTap') push ile aynı yönlendiriciye gider.
  Future<void> _attachReminderTaps() async {
    if (!_tapBridge) {
      _tapBridge = true;
      ChannelReminderBackend.channel.setMethodCallHandler((call) async {
        if (call.method == 'onTap' && call.arguments is Map) {
          _open((call.arguments as Map).map((k, v) => MapEntry('$k', v)));
        }
        return null;
      });
    }
    try {
      final p = await LocalReminders.instance.backend.takeLaunchPayload();
      if (p != null && p.isNotEmpty) _open(Map<String, dynamic>.from(p));
    } catch (_) {}
  }

  Future<void> onSignedIn() async {
    PushRouter.session = session;
    unawaited(_attachReminderTaps());
    if (!await _ensureInit()) return;
    try {
      final fm = FirebaseMessaging.instance;
      // İlk giriş izin sayfası henüz gösterilmediyse sistem istemini o sayfa yönetir (çift istem olmaz);
      // izin verilince sayfa onSignedIn'i yeniden çağırır.
      final cur = await fm.getNotificationSettings();
      if (cur.authorizationStatus == AuthorizationStatus.notDetermined && !await PermissionOnboarding.isDone()) {
        return;
      }
      final perm = await fm.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      // Ön planda sistem şeridi yerine uygulama içi şerit gösteriyoruz.
      await fm.setForegroundNotificationPresentationOptions(alert: false, badge: false, sound: false);

      // Yenileme dinleyicisi jetondan ONCE: iOS'ta FCM jetonu APNs belirteci gelince sonradan da oluşabilir.
      // ignore: deprecated_member_use
      _refreshSub ??= fm.onTokenRefresh.listen(_register, onError: (_) {});
      // iOS: APNs belirteci gelmeden FCM jetonu istenirse null/hata döner; [fetchPushToken] bekler ve yeniden dener.
      final token = await fetchPushToken(
        isIOS: Platform.isIOS,
        apns: fm.getAPNSToken,
        // Yeni register()/onRegistered FCM jetonu değil Firebase Installation ID verir; sunucu FCM jetonu bekler.
        // ignore: deprecated_member_use
        fcm: fm.getToken,
      );
      if (token != null) await _register(token);

      _fgSub ??= FirebaseMessaging.onMessage.listen(_showBanner);
      _openSub ??= FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data));
      _startForegroundTracking();
      unawaited(_syncChannelNames());
      final initial = await fm.getInitialMessage(); // soğuk açılış
      if (initial != null) _open(initial.data);
    } catch (e) {
      debugPrint('Push baslatilamadi: ${e.runtimeType}');
    }
  }

  /// Ön plan/arka plan durumu cihaz olarak sunucuya bildirilir; açık sohbet için görüntüleme sinyali başlar.
  void _startForegroundTracking() {
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    active.setForeground(true);
    _viewing ??= ViewingSignaler(_api, active)..start();
    final t = _token;
    if (t != null) unawaited(_api.setState(t, true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed;
    // inactive (iOS geçişleri) ön plan sayılır; yalnız paused/hidden/detached arka plandır.
    final bg = state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.detached;
    if (!fg && !bg) return;
    active.setForeground(fg);
    final t = _token;
    if (t != null && session.state == SessionState.signedIn) unawaited(_api.setState(t, fg));
  }

  /// Kanal adları kullanıcının dilinde (Android; kanal başına sistem ayarı adı). Hata sessizdir.
  Future<void> _syncChannelNames() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final l = lookupAppLocalizations(Locale(session.api.lang));
      await ChannelReminderBackend.channel.invokeMethod('setChannelNames', {
        'names': {
          'chat': l.bildirimmobilKanalChat,
          'event': l.bildirimmobilKanalEvent,
          'announcement': l.bildirimmobilKanalAnnouncement,
          'social': l.bildirimmobilKanalSocial,
          'poll': l.bildirimmobilKanalPoll,
          'academic': l.bildirimmobilKanalAcademic,
        }
      });
    } on MissingPluginException {
      // platform kodu yok
    } catch (_) {}
  }

  Future<void> onSignedOut() async {
    _viewing?.stop();
    _viewing = null;
    if (_observing) {
      _observing = false;
      WidgetsBinding.instance.removeObserver(this);
    }
    // Kullanıcıya özel yerel hatırlatmalar çıkışta silinir (başka hesapta görünmesin).
    unawaited(LocalReminders.instance.cancelAll());
    final t = _token;
    _token = null;
    await _refreshSub?.cancel();
    await _fgSub?.cancel();
    await _openSub?.cancel();
    _refreshSub = _fgSub = _openSub = null;
    if (t == null) return;
    // Oturum zorla kapandıysa (başka cihaz) token yok: sunucu kaydı zaten silmiştir.
    if (session.api.tokens == null) {
      if (_enabled) {
        try {
          // ignore: deprecated_member_use
          await FirebaseMessaging.instance.deleteToken();
        } catch (_) {}
      }
      return;
    }
    try {
      // Çıkışta belirteç oturum kapanmadan silinmeli; token yoksa sessizce geçer.
      await _api.unregister(t);
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
      await _api.register(token, platform: Platform.isIOS ? 'IOS' : 'ANDROID', appVersion: _appVersion);
      unawaited(_api.setState(token, active.foreground)); // uç yoksa sessiz
    } catch (_) {
      // Ağ hatasında bir sonraki açılışta yeniden denenir.
    }
  }

  void _showBanner(RemoteMessage m) => handleForeground(
        title: m.notification?.title ?? '',
        body: m.notification?.body ?? '',
        data: m.data,
      );

  /// Ön plan mesajı: açık sohbetse hiçbir şey gösterme; değilse kısa uygulama içi şerit. Rozetler güncellenir.
  /// Dönüş: şerit gösterildi mi (test için).
  bool handleForeground({required String title, required String body, required Map<String, dynamic> data}) {
    if (active.shouldSuppress(data)) return false;
    final type = '${data['type'] ?? ''}'.toUpperCase();
    if (type == 'MESSAGE' || data['conversationId'] != null) {
      session.badges.conversationsDirty.value++; // sohbet listesi/okunmamış sayacı yenilenir
    } else {
      session.badges.notifications.value++;
    }
    if (title.isEmpty && body.isEmpty) return false;
    PushBannerCenter.instance.show(
      BannerItem(key: bannerKey(data, title), title: title, body: body, data: data),
      onTap: _open,
    );
    return true;
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
