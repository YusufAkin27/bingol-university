import 'widgets/bu_swipe_back.dart';
import 'widgets/bu_keyboard.dart' show BuFocusRouteObserver, BuTapOutsideUnfocus;
import 'dart:async';


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/academic_catalog.dart';
import 'core/analytics.dart';
import 'core/api.dart';
import 'core/app_gate.dart';
import 'core/app_hooks.dart';
import 'core/cache/cache_lifecycle.dart';
import 'core/cache/disk_cache.dart';
import 'core/cache/image_disk_cache.dart';
import 'core/cache/message_cache.dart';
import 'core/cache/video_prefetch.dart';
import 'core/connectivity/connectivity_service.dart';
import 'core/language_sync.dart';
import 'core/user_data.dart';
import 'core/crash/crash_reporter.dart';
import 'core/icons/bu_icon_licenses.dart';
import 'core/transfers/transfer_hub.dart';
import 'features/posts/post_transfer.dart' show registerPostTransfer;
import 'core/outbox/outbox.dart';
import 'core/outbox/outbox_uploader.dart';
import 'core/locale_controller.dart';
import 'core/motion/bu_scroll_behavior.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/device_identity.dart';
import 'core/platform/fresh_install.dart';
import 'core/error_log.dart';
import 'core/nav.dart';
import 'core/push/push_service.dart';
import 'core/push/push_reply_headless.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'core/theme_controller.dart';
import 'features/auth/auth_landing_page.dart';
import 'features/auth/permissions_page.dart';
import 'features/auth/profile_setup_page.dart';
import 'features/legal/legal_reaccept_page.dart';
import 'features/share/share_links.dart';
import 'features/shell/app_shell.dart';
import 'features/system/error_views.dart';
import 'features/system/gate_views.dart';
import 'features/system/splash_screen.dart';
import 'features/widgets/widget_sync_service.dart';

/// Yakalanmamış hatayı yerel günlüğe (disk + bellek) ve — oturum açıksa — anonim `app_error` analitik
/// olayına yazar: yalnız hata türü, ekran adı ve sürüm; mesaj/yığın/kişisel veri yok ([ErrorLog]).
/// Ayrıca (ayar açıksa, yalnız release) maskelenmiş yığın izi kendi sunucumuza anonim raporlanır ([CrashReporter]).
void _reportError(Object error, StackTrace? stack, {String source = 'flutter'}) {
  ErrorLog.instance.report(error, source: source);
  CrashReporter.instance.capture(error, stack, source: source);
}

@visibleForTesting
void installErrorHandling({bool release = kReleaseMode}) {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (release) {
      _reportError(details.exception, details.stack);
    } else {
      previous?.call(details); // debug/test: konsolda tam ayrıntı
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _reportError(error, stack, source: 'platform');
    return true; // işlendi: süreç düşmez
  };
  if (release) ErrorWidget.builder = (_) => const RenderErrorView();
}

/// Gecersiz derleme adresinde kullaniciya teknik ayrinti icermeyen erisim ekrani gosterir.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final l = lookupAppLocalizations(resolveAppLocale('system', PlatformDispatcher.instance.locales));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(l.localeName),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: BuTheme.light(),
      darkTheme: BuTheme.dark(),
      home: const ConfigErrorView(),
    );
  }
}

/// Android satır içi yanıt: uygulama kapalıyken native JobScheduler işinin açtığı başlıksız motorun giriş noktası
/// (kök kütüphanede aranır; bkz. push_reply_headless.dart ve android ReplyDispatcher.kt). Arayüz/oturum açılışı yoktur.
@pragma('vm:entry-point')
Future<void> pushReplyMain() => runPushReplyHeadless();

Future<void> main() async {
  // Çerçeve dışında kalan asenkron hatalar da kendi sunucumuza raporlanır (runZonedGuarded).
  await runZonedGuarded<Future<void>>(_bootstrap, (error, stack) => _reportError(error, stack, source: 'zone'));
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBuIconLicenses(); // BuIcons glifleri Hugeicons (MIT): lisans sayfasında görünür
  if (!apiConfigValid()) {
    _reportError(StateError('INVALID_API_CONFIGURATION'), StackTrace.current, source: 'configuration');
    runApp(const ConfigErrorApp());
    return;
  }
  // Telefonda dikey kilit; tablet (kısa kenar >= 600dp) serbest.
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  if (view.physicalSize.shortestSide / view.devicePixelRatio < 600) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }
  installErrorHandling();
  // Push: Firebase + arka plan/kapalı işleyicisi oturumdan bağımsız, runApp'ten önce kaydedilir (bkz. PushService.prepare).
  unawaited(PushService.prepare());
  // Derin bağlantı (paylaşılan gönderi/haber/etkinlik): akış runApp'ten önce başlar ki soğuk açılış bağlantısı kaçmasın;
  // hedef oturum/onay/profil kapıları geçilene kadar bekler (ShareLinkHost).
  unawaited(ShareLinks.instance.start());
  unawaited(ErrorLog.instance.init());
  // Açılış okumaları (güvenli depo/dosya) SERİ değil PARALEL başlar. Cihaz kimliği runApp'i beklemez ama ApiClient
  // kimlik hazır olmadan HİÇBİR istek atmaz (bkz. DeviceIdentity.ready); iOS yeniden-kurulum temizliği Session.restore'dan önce biter.
  unawaited(DeviceIdentity.instance.load()); // hata fırlatmaz
  final freshInstall = FreshInstallGuard.run(); // iOS: yeniden kurulumda Keychain'de kalan eski oturum/kuyruk kayıtlarını siler
  final crashInit = CrashReporter.instance.init(trackSession: true); // ayar + bekleyen raporlar + önceki oturum işareti (hata fırlatmaz)
  final connectivity = ConnectivityService.instance;
  final api = ApiClient(diskCache: DiskCache(), connectivity: connectivity);
  final outbox = Outbox();
  api.outbox = outbox;
  CrashReporter.instance.attach(api);
  // Önceki oturumdan kalan raporlar, açılışla yarışmasın diye biraz sonra gönderilir.
  unawaited(Future<void>.delayed(const Duration(seconds: 8), CrashReporter.instance.flush));
  outbox.attach(api, connectivity);
  final session = Session(api);
  _wireOfflineStorage(api, outbox, session);
  final theme = ThemeController();
  final localeCtl = LocaleController(onResolved: (c) => session.api.lang = c);
  LocaleController.current = localeCtl;
  Analytics.instance.attach(session);
  final push = PushService(session);
  final hooks = AppLifecycleHooks.instance;
  hooks.onSignedIn.add((_) => push.onSignedIn()); // restore sonrası oturum açıksa bir kez tetiklenir
  hooks.onSignedIn.add((_) => outbox.load()); // bekleyen mesajlar yüklenir ve gönderilir (oturum açıkken)
  hooks.onSignedOut.add((_) => push.onSignedOut());
  // Ana ekran widget'ları: oturum açılınca snapshot'lar yazılır, çıkışta silinir (kullanıcı verisi temizleyicisi de siler);
  // dil değişince metinler yeniden hazırlanır. Tüm adımlar sessizdir (WidgetSyncService hata sızdırmaz).
  WidgetSyncService.instance.attach(session);
  hooks.onSignedIn.add((_) => WidgetSyncService.instance.refreshAll(reason: 'signin'));
  hooks.onSignedOut.add((_) => unawaited(WidgetSyncService.clearUserData()));
  localeCtl.addListener(() => WidgetSyncService.instance.refreshAll(reason: 'lang'));
  // Sunucu profil dili (bildirim/e-posta dili) uygulama diliyle eşitlenir; yalnız DEĞİŞİNCE (her açılışta istek yok).
  hooks.onSignedIn.add((_) => LanguageSync.sync(session.api, session.userId, localeCtl.locale.languageCode));
  session.beforeSignOut.add(push.onSignedOut); // cihaz kaydı, token geçerliyken silinir
  TransferHub.instance.attach(session, connectivity); // kalıcı aktarım kuyruğu (G10): giriş/çıkış kancaları
  registerPostTransfer(); // gönderi (foto/video) çalıştırıcısı (G2): yarım kalan paylaşımlar açılışta sürer
  hooks.attach(session);
  // Oturum geri yüklemesi iOS temizliğinden sonra başlar ama runApp'i BEKLETMEZ (splash görünür).
  unawaited(() async {
    await freshInstall;
    await session.restore();
  }());
  // Tema ve dil ilk karede doğru olsun (yanıp sönme yok): paralel yüklenir, runApp yalnız bunları bekler.
  await Future.wait([theme.load(), localeCtl.load(), crashInit, Analytics.instance.init()]);
  runApp(BingolApp(session: session, themeController: theme, push: push, localeController: localeCtl));
}

/// Çevrimdışı depolama bağları (hepsi olay tabanlı, yoklama yok):
/// - bekleyen mesajlar: bağlantı geri gelince (ConnectivityService), STOMP yeniden bağlanınca ve uygulama öne gelince gider;
/// - STOMP'tan gelen/giden mesajlar kaydı olan sohbetlere eklenir, herkes için silinenler kayıtta iskelete iner;
/// - çıkış/hesap değişimi/silme: mesaj kaydı, görsel önbelleği, arama geçmişi, otomatik kayıt ayarı, hatırlatıcılar silinir
///   (ApiClient.setTokens(null) -> registerUserDataCleaners);
/// - arka plana giderken geciktirilmiş yazımlar diske boşaltılır; çözümlenmiş görsel belleği tavanlanır.
void _wireOfflineStorage(ApiClient api, Outbox outbox, Session session) {
  outbox.uploader = outboxUploaderFor(session);
  MessageCache.instance = MessageCache(); // diskli örnekler (varsayılanları yalnız bellek/pasif)
  ImageDiskCache.instance = ImageDiskCache();
  VideoPrefetcher.instance = VideoPrefetcher(); // Keşfet videoları önceden yerel diske iner (arka planda durur)
  VideoPrefetchLifecycle.instance.attach();
  final rt = session.realtime;
  if (rt != null) {
    rt.connected.listen((on) {
      if (on) unawaited(outbox.nudge());
    });
    rt.messages.listen((m) {
      final cid = (m['conversationId'] as num?)?.toInt();
      if (cid != null) unawaited(MessageCache.instance.upsertMessage(cid, m));
    });
    rt.deletedMessages.listen((e) => unawaited(MessageCache.instance.markGone(e.conversationId, e.messageId)));
  }
  registerUserDataCleaners(api); // çıkışta kullanıcıya özel TÜM yerel depolar (bkz. core/user_data.dart)
  api.onBlockedUser.add(MessageCache.instance.clear);
  applyImageCacheLimits();
  CacheLifecycleFlusher([
    MessageCache.instance.flush,
    () async => api.diskCache?.flush(),
  ]).attach();
}

class BingolApp extends StatelessWidget {
  BingolApp({super.key, required this.session, required this.themeController, this.push, this.localeController});

  final LocaleController? localeController;

  final Session session;

  /// İzin sayfasında bildirim izni verilince FCM kaydını başlatmak için.
  final PushService? push;
  final ThemeController themeController;
  final _observer = AnalyticsNavigatorObserver();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeController, if (localeController != null) localeController!]),
      builder: (context, _) => MaterialApp(
        locale: localeController?.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        onGenerateTitle: (_) => 'BÜ Kampüs',
        title: 'BÜ Kampüs',
        debugShowCheckedModeBanner: false,
        navigatorKey: rootNavigatorKey,
        navigatorObservers: [_observer, BuFocusRouteObserver()],
        theme: BuTheme.light(),
        darkTheme: BuTheme.dark(),
        themeMode: themeController.mode,
        scrollBehavior: const BuScrollBehavior(),
        // Sistem/durum çubuğu ikonları temaya uyar (Android: statusBarIconBrightness, iOS: statusBarBrightness);
        // tema değişince alt ağaç yeniden KURULMAZ (anahtar yok), yalnız bu bölge güncellenir.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: Theme.of(context).brightness,
            systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
            systemNavigationBarIconBrightness:
                Theme.of(context).brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          ),
          child: AcademicCatalogScope(
            session: session,
            // Boş alana dokunmak odağı bırakır (klavye kapanır); düğme/alan dokunuşlarını engellemez.
            child: AppGate(api: session.api, child: BuGlobalSwipeBack(child: BuTapOutsideUnfocus(child: child ?? const SizedBox.shrink()))),
          ),
        ),
        home: ListenableBuilder(
          listenable: Listenable.merge([session, session.accessBlocked]),
          builder: (context, _) => session.accessBlocked.value
              ? AccessBlockedScreen(onRetry: session.dismissAccessBlocked)
              : switch (session.state) {
                  SessionState.loading => const SplashScreen(),
                  SessionState.signedOut => _SignedOutRoot(session: session),
                  // İlk girişte (cihaz başına bir kez) izin sayfası; sonra kabuk.
                  // Önce zorunlu profil tamamlama (ad soyad + bölüm + sınıf eksikse atlanamaz), sonra izinler ve kabuk.
                  SessionState.signedIn => ProfileCompletionGate(
                      // Hesap değişiminde tüm alt ağaç (kapılar, kabuk, sekmeler) yeniden kurulur: önceki hesabın ekran durumu kalmaz.
                      key: ValueKey('acct-${session.accountEpoch}'),
                      session: session,
                      child: PostLoginGate(
                        onNotificationsGranted: push == null ? null : () => push!.onSignedIn(),
                        // Yeni sözleşme sürümü onayı bekleniyorsa kabuğun üstüne tam ekran onay (ağ hatasında açılmaz).
                        child: LegalReacceptGate(
                          session: session,
                          child: ShareLinkHost(
                            session: session,
                            child: AppShell(session: session, themeController: themeController),
                          ),
                        ),
                      ),
                    ),
                },
        ),
      ),
    );
  }
}

/// Çıkış yapmış kullanıcı: premium giriş ekranı (Google / Apple / E-posta ile devam et). Eski ilk-açılış karşılaması
/// ([WelcomePage]) artık kökte gösterilmez; e-posta/şifre girişi ve kayıt bu ekrandan açılır.
class _SignedOutRoot extends StatelessWidget {
  const _SignedOutRoot({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) => AuthLandingPage(session: session);
}
