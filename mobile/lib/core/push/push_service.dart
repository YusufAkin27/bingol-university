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
import '../closed_conversations.dart';
import '../session.dart';
import '../../l10n/app_localizations.dart';
import 'active_conversation.dart';
import 'icon_badge.dart';
import 'push_api.dart';
import 'push_banner.dart';
import 'push_registrar.dart';
import 'push_router.dart';

const _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '2.0.3');

/// Arka plan / kapalı durum işleyicisi: top-level + entry-point olmalı (ayrı isolate'ta çalışır) ve
/// `main()` içinde ([PushService.prepare]) oturumdan bağımsız kaydedilir.
/// Sunucu her zaman `notification` bloklu (+ Android kanal/etiket) mesaj gönderdiği için uygulama kapalıyken
/// bildirimi SİSTEM gösterir (işleyici gerekmez); işleyici yalnız ileride veri-yüklü mesaj gelirse Firebase'i
/// hazır tutar (yük işlenmez, UI/oturuma dokunulmaz). Dokunuş [PushService] ile yönlendirilir.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// FCM jetonunu alır. iOS'ta APNs belirteci (anahtar/izin/imza hazırsa) birkaç saniye içinde gelir; gelmeden
/// FCM jetonu istenirse eklenti `apns-token-not-set` fırlatır veya null döner. Bu yüzden önce APNs beklenir
/// ([attempts] x [delay]), sonra jeton alınır; hata/null olursa (her platformda) 3 kez denenir. Hâlâ yoksa null
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
  // Android'de de birkaç deneme: Play Hizmetleri/ağ o an hazır değilse getToken hata verir ve (jeton
  // değişmediği için) onTokenRefresh da tetiklenmez; tek deneme jetonu sunucuya hiç ulaştırmayabiliyordu.
  const tries = 3;
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
  PushService(this.session, {ActiveConversation? active, PushRegistrar? registrar})
      : active = active ?? ActiveConversation.instance,
        _api = PushApi(session.api) {
    this.registrar = registrar ?? PushRegistrar(send: _send);
    session.pushToken = () => _token ?? this.registrar.token;
  }

  final Session session;
  final ActiveConversation active;
  final PushApi _api;

  /// Jeton -> `POST /devices` kaydı (yeniden deneme + tazeleme).
  late final PushRegistrar registrar;
  ViewingSignaler? _viewing;
  final IconBadge _iconBadge = IconBadge(); // iOS simge rozeti = okunmamış bildirim sayısı
  bool _observing = false;

  bool _initTried = false;
  bool _enabled = false;
  bool _active = false; // onSignedIn çalıştı, onSignedOut henüz çalışmadı
  bool _permDenied = false;
  bool _refreshing = false;
  bool _initialHandled = false;
  String? _token;
  StreamSubscription? _refreshSub, _fgSub, _openSub;

  bool get enabled => _enabled;

  /// Bildirim izni (OS) verilmemiş mi (son kontrole göre).
  bool get permissionDenied => _permDenied;

  /// main.dart'ın AppLifecycleHooks listelerine bağlar. Örnek:
  /// `push.attach(onSignedIn: hooks.onSignedIn, onSignedOut: hooks.onSignedOut);`
  /// Listeler `Future<void> Function()` (veya `void Function()`) kabul eder. Oturum zaten
  /// açıksa çağrıyı kendisi yapmaz; gerekirse [onSignedIn] elle çağrılır.
  void attach({required List<Function> onSignedIn, required List<Function> onSignedOut}) {
    onSignedIn.add(() => this.onSignedIn());
    onSignedOut.add(() => this.onSignedOut());
  }

  static Future<bool>? _prepare;

  /// Firebase'i hazırlar ve arka plan/kapalı işleyicisini KAYDEDER. `main()` içinde `runApp`'ten önce çağrılır
  /// (FlutterFire kuralı: işleyici üst düzey olmalı ve uygulama açılışında, oturumdan bağımsız kaydedilmeli);
  /// birden çok çağrı tek iş yapar. Firebase yapılandırılmamışsa false döner, uygulama etkilenmez.
  static Future<bool> prepare() => _prepare ??= _doPrepare();

  static Future<bool> _doPrepare() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return false;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      return true;
    } catch (e) {
      debugPrint('Push devre disi (Firebase yapilandirilmamis): ${e.runtimeType}');
      return false;
    }
  }

  Future<bool> _ensureInit() async {
    if (_initTried) return _enabled;
    _initTried = true;
    _enabled = await prepare();
    return _enabled;
  }

  final _seenMessageIds = <String>{}; // ön plan şeridi tekilleştirmesi (son 60 mesaj)

  bool _tapBridge = false;

  /// Yerel hatırlatma dokunuşları (soğuk başlatma: bekleyen yük; ön plan: 'onTap') push ile aynı yönlendiriciye gider.
  Future<void> _attachReminderTaps() async {
    if (!_tapBridge) {
      _tapBridge = true;
      ChannelReminderBackend.channel.setMethodCallHandler((call) async {
        if (call.method == 'onTap' && call.arguments is Map) {
          _open((call.arguments as Map).map((k, v) => MapEntry('$k', v)), localReminder: true);
        }
        return null;
      });
    }
    try {
      final p = await LocalReminders.instance.backend.takeLaunchPayload();
      if (p != null && p.isNotEmpty) _open(Map<String, dynamic>.from(p), localReminder: true);
    } catch (_) {}
  }

  Future<void> onSignedIn() async {
    _active = true;
    PushRouter.session = session;
    unawaited(_attachReminderTaps());
    unawaited(_syncChannelNames()); // FCM'den bağımsız: kanal adları/açıklamaları kullanıcının dilinde
    _iconBadge.attach(session.badges.notifications); // iOS: push'un bıraktığı eski rozet düzeltilir, okununca düşer
    if (!await _ensureInit()) return;
    try {
      final fm = FirebaseMessaging.instance;
      // Dinleyiciler ve soğuk açılış yönlendirmesi izin/jetondan ÖNCE: izin sayfası bekleniyorsa, izin
      // reddedildiyse ya da ağ yavaşsa bile bildirime dokunuşla açılış kaybolmasın.
      // Ön planda sistem şeridi yerine uygulama içi şerit gösteriyoruz (iOS; Android zaten göstermez).
      await fm.setForegroundNotificationPresentationOptions(alert: false, badge: false, sound: false);
      _fgSub ??= FirebaseMessaging.onMessage.listen(_showBanner);
      _openSub ??= FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data));
      _startForegroundTracking();
      unawaited(_openInitialMessage(fm));

      // İlk giriş izin sayfası henüz gösterilmediyse sistem istemini o sayfa yönetir (çift istem olmaz);
      // izin verilince sayfa onSignedIn'i yeniden çağırır.
      final cur = await fm.getNotificationSettings();
      if (cur.authorizationStatus == AuthorizationStatus.notDetermined && !await PermissionOnboarding.isDone()) {
        return;
      }
      final perm = await fm.requestPermission();
      _permDenied = perm.authorizationStatus == AuthorizationStatus.denied;
      // İzin yoksa jeton kaydedilmez (sunucu boşuna göndermesin); kullanıcı sistem ayarından açıp uygulamaya
      // dönünce [refresh] jetonu kaydeder.
      if (_permDenied) return;
      await _fetchAndRegister(fm);
    } catch (e) {
      debugPrint('Push baslatilamadi: ${e.runtimeType}');
    }
  }

  /// Soğuk açılış (bildirime dokunarak açıldı): süreç başına yalnız bir kez yönlendirir.
  Future<void> _openInitialMessage(FirebaseMessaging fm) async {
    if (_initialHandled) return;
    _initialHandled = true;
    try {
      final initial = await fm.getInitialMessage();
      if (initial != null) _open(initial.data);
    } catch (_) {}
  }

  /// FCM jetonunu alıp kaydeder; yenilenme dinleyicisi jetondan ÖNCE bağlanır (iOS'ta jeton APNs belirteci
  /// gelince sonradan da oluşabilir).
  Future<void> _fetchAndRegister(FirebaseMessaging fm) async {
    // ignore: deprecated_member_use
    _refreshSub ??= fm.onTokenRefresh.listen((t) {
      if (!_permDenied) unawaited(_register(t));
    }, onError: (_) {});
    final token = await fetchPushToken(
      isIOS: Platform.isIOS,
      apns: fm.getAPNSToken,
      // Yeni register()/onRegistered FCM jetonu değil Firebase Installation ID verir; sunucu FCM jetonu bekler.
      // ignore: deprecated_member_use
      fcm: fm.getToken,
      delay: Platform.isIOS ? const Duration(milliseconds: 500) : const Duration(seconds: 2),
    );
    if (token != null) await _register(token);
  }

  /// Ön plana dönüşte ve yardım ekranından: izin sonradan verildiyse jetonu kaydeder; kayıt eskidiyse
  /// (sunucu `lastSeenAt`, sürüm, dil) ya da önceki deneme başarısızsa yeniler. Hızlı çağrılar birleşir.
  Future<void> refresh({bool force = false}) async {
    if (!_enabled || !_active || _refreshing || session.state != SessionState.signedIn) return;
    _refreshing = true;
    try {
      unawaited(_syncChannelNames()); // dil değişmiş olabilir
      final fm = FirebaseMessaging.instance;
      final st = (await fm.getNotificationSettings()).authorizationStatus;
      _permDenied = st == AuthorizationStatus.denied;
      final ok = st == AuthorizationStatus.authorized || st == AuthorizationStatus.provisional;
      if (!ok) return;
      if (!force && !registrar.needsRefresh) return;
      if (force) registrar.reset();
      await _fetchAndRegister(fm);
    } catch (_) {
      // sessiz: bir sonraki ön plana dönüşte yeniden denenir
    } finally {
      _refreshing = false;
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
    if (fg) unawaited(refresh());
  }

  /// Kanal adları + açıklamaları kullanıcının dilinde (Android; kanal başına sistem ayarı adı). Hata sessizdir.
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
        },
        'descriptions': {
          'chat': l.p21ChanChatDesc,
          'event': l.p21ChanEventDesc,
          'announcement': l.p21ChanAnnouncementDesc,
          'social': l.p21ChanSocialDesc,
          'poll': l.p21ChanPollDesc,
          'academic': l.p21ChanAcademicDesc,
        },
      });
    } on MissingPluginException {
      // platform kodu yok
    } catch (_) {}
  }

  Future<void> onSignedOut() async {
    if (!_active) return; // kanca iki kez (beforeSignOut + durum değişimi) gelebilir
    _active = false;
    _permDenied = false;
    _iconBadge.detach(); // rozeti sıfırla (başka hesabın sayısı kalmasın)
    _viewing?.stop();
    _viewing = null;
    if (_observing) {
      _observing = false;
      WidgetsBinding.instance.removeObserver(this);
    }
    // Kullanıcıya özel yerel hatırlatmalar çıkışta silinir (başka hesapta görünmesin).
    unawaited(LocalReminders.instance.cancelAll());
    final t = _token ?? registrar.token;
    _token = null;
    registrar.reset();
    await _refreshSub?.cancel();
    await _fgSub?.cancel();
    await _openSub?.cancel();
    _refreshSub = _fgSub = _openSub = null;
    // Oturum zorla kapandıysa (başka cihaz) token yok: sunucu kaydı zaten silmiştir.
    if (t != null && session.api.tokens != null) {
      try {
        // Çıkışta belirteç oturum kapanmadan silinmeli; token yoksa sessizce geçer.
        await _api.unregister(t);
      } catch (_) {}
    }
    // Jeton her durumda geçersiz kılınır (kayıt başarısız/eksik olsa bile sunucudaki eski kayıt FCM
    // UNREGISTERED ile temizlenir; bu cihaz çıkış yapmış kullanıcının bildirimini almaz).
    if (_enabled) {
      try {
        // ignore: deprecated_member_use
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
  }

  /// [PushRegistrar.send]: oturum açıkken `POST /devices` (+ ön plan durumu).
  Future<void> _send(String token) async {
    if (session.state != SessionState.signedIn) throw StateError('signed out');
    await _api.register(token, platform: Platform.isIOS ? 'IOS' : 'ANDROID', appVersion: _appVersion);
    unawaited(_api.setState(token, active.foreground)); // uç yoksa sessiz
  }

  Future<void> _register(String token) async {
    if (session.state != SessionState.signedIn) return;
    _token = token;
    await registrar.register(token);
  }

  void _showBanner(RemoteMessage m) => handleForeground(
        title: m.notification?.title ?? '',
        body: m.notification?.body ?? '',
        data: m.data,
      );

  /// Ön plan mesajı: açık sohbetse hiçbir şey gösterme; değilse kısa uygulama içi şerit. Rozetler güncellenir.
  /// Dönüş: şerit gösterildi mi (test için).
  bool handleForeground({required String title, required String body, required Map<String, dynamic> data}) {
    // Kapatma/yeniden açma durumu, sohbet açıkken şerit bastırılsa bile işlenir (bant canlı görünsün).
    ClosedConversations.instance.applyPushData(data);
    if (active.shouldSuppress(data)) return false;
    // Aynı mesaj push'u iki kez gelirse (yeniden deneme / çoklu yol) şerit tekrar çıkmaz (data.messageId, sunucu yükünde).
    final mid = '${data['messageId'] ?? ''}';
    if (mid.isNotEmpty) {
      if (_seenMessageIds.contains(mid)) return false;
      _seenMessageIds.add(mid);
      if (_seenMessageIds.length > 60) _seenMessageIds.remove(_seenMessageIds.first);
    }
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

  /// [localReminder]: yük yerel hatırlatma dokunuşundan geldi (güvenilmez kaynak; bkz. [PushRouter.open]).
  void _open(Map<String, dynamic> data, {bool localReminder = false}) {
    final url = data['value'];
    if (('${data['target']}').toUpperCase() == 'URL') {
      // Yalnız https şemasına güvenilir; tarayıcı açma çağıran tarafın işi, burada bildirim listesine düşer.
      if (url is! String || !url.startsWith('https://')) return;
    }
    // Soğuk açılışta kabuk çizildikten sonra yönlendir.
    WidgetsBinding.instance.addPostFrameCallback((_) => PushRouter.open(data, localReminder: localReminder));
    WidgetsBinding.instance.scheduleFrame();
  }
}
