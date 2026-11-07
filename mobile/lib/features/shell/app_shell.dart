import 'dart:async';

import '../news/news_list_page.dart';
import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/haptics.dart';
import '../../core/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session.dart';
import '../../core/notification_counts.dart';
import '../../core/theme.dart';
import '../../core/theme_controller.dart';
import '../../core/theme/bu_motion.dart';
import '../../widgets/bu_overlays.dart' show BuToast;
import '../chat/chat_tab.dart';
import '../clubs/clubs_tab.dart';
import '../discover/discover_tab.dart';
import '../home/home_tab.dart';
import '../profile/profile_tab.dart';
import '../posts/post_routes.dart' show openComposePost;
import '../widgets/widget_sync_service.dart';
import 'bukampus_bottom_navigation_bar.dart';

export 'bukampus_bottom_navigation_bar.dart' show BukampusBottomNavigationBar;

/// Sekme sırası: 0 Ana Sayfa, 1 Keşfet, 2 Sohbet, 3 Kulüpler, 4 Profil.
abstract final class AppTab {
  static const home = 0, discover = 1, chat = 2, clubs = 3, profile = 4;

  /// Kullanım analizi için sekme anahtarları (ekran adı `tab_<anahtar>`).
  static const analyticsKeys = ['home', 'discover', 'chat', 'clubs', 'profile'];
}

/// Giriş yapılmış kullanıcının kabuğu: sekmeler TEMBEL kurulur (ilk karede yalnız ana sekme; diğerleri ilk
/// seçimde kurulur, sonra Offstage'te canlı kalır: konum ve veri kaybolmaz) + M3 alt gezinme.
/// Sekmeler arası geçiş MİNİMAL (docs/MOBILE_MOTION_TABS.md): içerik yandan 12 dp kayarak 220 ms'de belirir, eskisi
/// 140 ms'de solar; boş/dikey alanda sağa-sola sürükleme (eşik 60 dp ya da hızlı fırlatma) komşu sekmeye geçirir, sürüklerken
/// içerik 12-16 dp paralaksla parmağı izler. Yatay kaydırılan iç bileşenler (haber şeridi) sürüklemeyi kendisi alır.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session, required this.themeController, this.initialTab = AppTab.discover});

  /// Uygulama açıldığında seçili sekme: varsayılan KEŞFET (her girişte ilgi çekici içerikle başla).
  final int initialTab;

  final Session session;
  final ThemeController themeController; // profil -> ayarlar için

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver, TickerProviderStateMixin {
  late int _tab = widget.initialTab;
  int _publishedVersion = 0;
  bool _publishing = false;
  // Bir kez açılmış sekmeler (tembel kurulum; kapanınca da canlı kalır).
  late final Set<int> _built = {widget.initialTab};
  // Geçiş: 0 -> 1 (220 ms). Gelen sekme `enter` eğrisiyle, giden sekme ilk 140 ms'de solar.
  late final AnimationController _anim = AnimationController(vsync: this, duration: AppMotion.normal, value: 1);
  late final AnimationController _snap = AnimationController(vsync: this, duration: AppMotion.fast);
  final _drag = ValueNotifier<double>(0); // sürükleme (dp, işaretli)
  int? _prev; // geçiş boyunca hâlâ görünen giden sekme
  double _enterDir = 1; // gelen içeriğin geldiği yan (+1: fiziksel sağ)
  double _leaveFrom = 0; // giden içeriğin bıraktığı paralaks konumu
  double _snapFrom = 0;
  Timer? _poll;
  Timer? _msgBadgeTimer;
  StreamSubscription<Map<String, dynamic>>? _msgSub;
  final _discoverType = ValueNotifier<String?>(null);

  Session get s => widget.session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Analytics.instance.setTab('tab_${AppTab.analyticsKeys[_tab]}'); // açılış sekmesi ekran süresi için
    s.realtime?.start();
    _msgSub = s.realtime?.messages.listen(_onRealtimeMessage);
    shellTabRequest.addListener(_onTabRequest);
    _anim.addStatusListener((st) {
      if (st == AnimationStatus.completed && _prev != null && mounted) setState(() => _prev = null);
    });
    _snap.addListener(() => _drag.value = _snapFrom * (1 - AppMotion.standard.transform(_snap.value)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _onTabRequest());
    _refreshBadges();
    WidgetSyncService.instance.refreshAll(reason: 'shell');
    _loadAvatar();
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => _refreshBadges());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Analytics.instance.setTab(null);
    shellTabRequest.removeListener(_onTabRequest);
    _poll?.cancel();
    _msgBadgeTimer?.cancel();
    _msgSub?.cancel();
    s.realtime?.stop();
    _discoverType.dispose();
    _anim.dispose();
    _snap.dispose();
    _drag.dispose();
    super.dispose();
  }

  /// Push yönlendirmesinden gelen "sekmeye geç" isteği (ör. sohbetten çıkarıldı -> Sohbet listesi).
  void _onTabRequest() {
    final v = shellTabRequest.value;
    if (v == null) return;
    shellTabRequest.value = null;
    if (mounted && v >= 0 && v <= AppTab.profile) _select(v);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshBadges();
      WidgetSyncService.instance.refreshAll(reason: 'resume'); // ana ekran widget'ları (debounce'lu, sessiz)
    }
  }

  // realtime kendi arka plan/ön plan geçişini yönetir (start sonrası observer).

  /// Başkasından gelen yeni mesajda (kendi ack'i hariç) sohbet rozeti sunucudan tazelenir; sohbet sekmesi açıkken
  /// sekmenin kendisi tazeler. Kör `++` yapılmaz: sessiz ve ARŞİVLİ sohbetler rozete girmez (sunucu `total` doğrudur).
  void _onRealtimeMessage(Map<String, dynamic> m) {
    final sender = (m['senderId'] as num?)?.toInt() ?? ((m['sender'] as Map?)?['id'] as num?)?.toInt();
    if (sender != null && sender == s.userId) return;
    if (_tab == AppTab.chat) return;
    _msgBadgeTimer?.cancel();
    _msgBadgeTimer = Timer(const Duration(milliseconds: 400), _refreshChatBadge);
  }

  /// Sohbet rozeti: GET /conversations/unread-count -> total (sessiz + arşivli olmayanlar; önbelleksiz, anlık).
  Future<void> _refreshChatBadge() async {
    try {
      final r = await s.api.get('/conversations/unread-count', force: true);
      final n = r is Map ? r['total'] : null;
      if (n is num && mounted) s.badges.chat.value = n.toInt();
    } catch (_) {}
  }

  /// Tek istek: okunmamış bildirim + mesaj sayıları (GET /me/summary).
  Future<void> _refreshBadges() async {
    try {
      final m = await s.api.get('/me/summary') as Map<String, dynamic>;
      if (!applyNotificationCounts(s, m)) {
        s.badges.notifications.value = (m['unreadNotifications'] as num?)?.toInt() ?? 0;
      }
      s.badges.chat.value = (m['unreadMessages'] as num?)?.toInt() ?? 0;
    } catch (_) {}
  }

  /// Alt gezinmedeki Profil sekmesi avatarı için kendi fotoğraf adresi (sessiz; hata varsayılan görseli korur).
  Future<void> _loadAvatar() async {
    try {
      final m = await s.api.get('/users/me');
      if (m is! Map) return;
      final av = m['avatarUrl'];
      s.avatarUrl.value = av is String && av.isNotEmpty ? av : null;
    } catch (_) {}
  }

  void _go(int i, {String? newsType}) {
    if (newsType != null) {
      // Keşfet artık yalnız gönderiler: haber/duyuru/etkinlik listesi ayrı sayfada açılır.
      Navigator.of(context).push<void>(
          MaterialPageRoute<void>(settings: const RouteSettings(name: 'news_list'), builder: (_) => NewsListPage(session: s, initialType: newsType)));
      return;
    }
    _select(i);
  }

  /// Alt çubuktaki sıra (Kulüpler çubukta yok; o sekmedeyken komşuları Sohbet ve Profil sayılır).
  List<int> get _order => _tab == AppTab.clubs
      ? const [AppTab.home, AppTab.discover, AppTab.chat, AppTab.clubs, AppTab.profile]
      : const [AppTab.home, AppTab.discover, AppTab.chat, AppTab.profile];

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  /// Sekmeyi seçer: ilk seçimde kurar, geçişi oynatır ("animasyonları azalt" ise anlık). Sürükleme konumu giden
  /// içeriğin başlangıcı olur (içerik bırakıldığı yerden sürer).
  void _select(int i) {
    if (i == _tab) return;
    Analytics.instance.tabSwitch(AppTab.analyticsKeys[i]);
    final reduce = BuMotion.reduced(context);
    final from = _parallax(_drag.value);
    _snap.stop();
    setState(() {
      _prev = reduce ? null : _tab;
      // Sekme numarası alt çubuk sırasıyla aynıdır: büyük = ileri (LTR'de sağdan gelir, RTL'de soldan).
      _enterDir = (i > _tab ? 1.0 : -1.0) * (_rtl ? -1.0 : 1.0);
      _leaveFrom = from;
      _tab = i;
      _built.add(i);
    });
    _drag.value = 0;
    if (reduce) {
      _anim.value = 1;
    } else {
      _anim.forward(from: 0);
    }
  }

  /// Sürükleme -> paralaks: 12-16 dp (dx * 0.08, +-16 ile sınırlı).
  static double _parallax(double dx) => (dx * .08).clamp(-16.0, 16.0);

  // --- sağa/sola sürükleyerek sekme değiştirme ---

  void _dragStart(DragStartDetails _) {
    _snap.stop();
    _drag.value = 0;
  }

  void _dragUpdate(DragUpdateDetails d) => _drag.value += d.delta.dx;

  /// Sürükleme yönündeki komşu sekme (yoksa null). LTR'de sola sürükleme sonraki sekmedir; RTL'de tersi.
  int? _neighbor(double dir) {
    if (dir == 0) return null;
    final order = _order;
    final to = order.indexOf(_tab) + ((dir < 0) != _rtl ? 1 : -1);
    return to < 0 || to >= order.length ? null : order[to];
  }

  void _dragEnd(DragEndDetails d) {
    final dx = _drag.value;
    final v = d.primaryVelocity ?? 0;
    final fling = v.abs() > 700;
    final to = (dx.abs() >= 60 || fling) ? _neighbor(fling ? v : dx) : null;
    if (to != null) {
      BuHaptics.selection();
      _select(to);
      return;
    }
    _snapBack();
  }

  void _snapBack() {
    _snapFrom = _drag.value;
    if (_snapFrom == 0) return;
    if (BuMotion.reduced(context)) {
      _drag.value = 0;
    } else {
      _snap.forward(from: 0);
    }
  }

  DateTime? _lastBack;

  /// Kök ekranda geri: sekmedeyse Ana Sayfa'ya; Ana Sayfa'da 2 sn içinde ikinci basışta çıkış.
  void _onBack(bool didPop, Object? result) {
    if (didPop) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(); // Savunma: üstte açık rota varsa önce o kapanır.
      return;
    }
    if (_tab != AppTab.home) {
      _select(AppTab.home);
      return;
    }
    final now = DateTime.now();
    final last = _lastBack;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    BuToast.show(context, context.l10n.exitAgainHint, duration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: _scaffold(),
    );
  }

  Widget _tabBody(int i) {
    switch (i) {
      case AppTab.home:
        return HomeTab(session: s, onOpenTab: _go);
      case AppTab.discover:
        return DiscoverTab(
            key: ValueKey(_publishedVersion), session: s, typeRequest: _discoverType, tabActive: _tab == AppTab.discover);
      case AppTab.chat:
        return ChatTab(session: s);
      case AppTab.clubs:
        return ClubsTab(session: s);
      default:
        return ProfileTab(session: s, themeController: widget.themeController);
    }
  }

  Widget _scaffold() {
    // Sekmelerde AppBar yok: durum çubuğu simge rengini burada tema parlaklığına göre sabitleriz. Aksi halde kapaklı
    // bir sayfanın (açık renk simge) bıraktığı stil geri dönüşte açık temada beyaz simge olarak takılı kalır.
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Reels (sürükleyici mod) koyu video üstünde olduğundan durum çubuğu simgeleri her temada açık renk olur.
    return ValueListenableBuilder<bool>(
      valueListenable: shellImmersive,
      builder: (context, immersive, child) {
        final light = dark || immersive;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: light ? Brightness.light : Brightness.dark,
            statusBarBrightness: light ? Brightness.dark : Brightness.light,
          ),
          child: child!,
        );
      },
      child: _scaffoldBody(),
    );
  }

  Future<void> _publish() async {
    if (_publishing) return;
    _publishing = true;
    try {
      final post = await openComposePost(context, s);
      if (!mounted || post == null) return;
      setState(() => _publishedVersion++);
      _select(AppTab.discover);
    } finally {
      _publishing = false;
    }
  }

  /// Sekme katmanı: yalnız seçili (ve geçişte giden) sekme çizilir/dokunulur; diğerleri Offstage'de canlı kalır
  /// (konum ve veri korunur, yeniden kurulmaz). Çocuk her zaman aynı sarmalayıcı zincirindedir (durum kaybolmaz).
  Widget _tabLayer(int i) {
    final active = i == _tab;
    final leaving = i == _prev;
    return Offstage(
      key: ValueKey('tab-$i'),
      offstage: !(active || leaving),
      child: TickerMode(
        enabled: active || leaving,
        child: ExcludeSemantics(
          excluding: !active,
          child: IgnorePointer(
            ignoring: !active,
            child: AnimatedBuilder(
              animation: Listenable.merge([_anim, _drag]),
              child: _tabBody(i),
              builder: (context, child) {
                final v = _anim.value;
                var dx = 0.0;
                var opacity = 1.0;
                if (active) {
                  final enter = AppMotion.enter.transform(v);
                  final dragging = _drag.value;
                  dx = (1 - enter) * 12 * _enterDir + _parallax(dragging);
                  opacity = (_prev != null ? enter : 1.0) * (1 - (dragging.abs() / 240).clamp(0.0, .25));
                } else if (leaving) {
                  // Giden içerik ilk 140 ms'de solar ve 8 dp ters yöne kayar.
                  final out = AppMotion.exit.transform((v * 220 / 140).clamp(0.0, 1.0));
                  dx = _leaveFrom - 8 * _enterDir * out;
                  opacity = 1 - out;
                }
                return Opacity(opacity: opacity, child: Transform.translate(offset: Offset(dx, 0), child: child));
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _scaffoldBody() {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              // Çocuklar (yatay kaydırılan şerit) önce kazanır; boş ve dikey alanda yatay sürükleme sekme değiştirir.
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _dragStart,
              onHorizontalDragUpdate: _dragUpdate,
              onHorizontalDragEnd: _dragEnd,
              onHorizontalDragCancel: _snapBack,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (var i = 0; i <= AppTab.profile; i++)
                    // Kurulmamış sekme boş kalır: ağ isteği/ağaç maliyeti ilk seçime ertelenir.
                    if (_built.contains(i)) _tabLayer(i) else const SizedBox.shrink(),
                ],
              ),
            ),
          ),
          // Edge-to-edge: kaydırılan içerik saat/simgelerin altında okunmaz kalmasın diye durağan zemin örtüsü.
          // Reels'te (sürükleyici mod) zemin örtüsü video üstünde parlak şerit olurdu: kalkar.
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: shellImmersive,
              builder: (context, immersive, _) => immersive ? const SizedBox.shrink() : const _StatusBarScrim(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ValueListenableBuilder<bool>(
          valueListenable: shellImmersive,
          builder: (context, immersive, _) => BukampusBottomNavigationBar(
            index: _tab,
            immersive: immersive && _tab == AppTab.discover,
            onPublish: _publish,
            onChanged: (i) {
              _go(i);
              if (i == AppTab.chat) _refreshBadges();
            },
            chatBadge: s.badges.chat,
          ),
        ),
      ),
    );
  }
}

/// Durum çubuğu alanında zemin renginden saydamlığa inen örtü: dokunmayı geçirir, dururken görünmez
/// (başlıklar zaten güvenli alanın altından başlar), kaydırılan içeriği saat/simgelerden ayırır.
class _StatusBarScrim extends StatelessWidget {
  const _StatusBarScrim();

  @override
  Widget build(BuildContext context) {
    final bg = context.bu.bg;
    final top = MediaQuery.paddingOf(context).top;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          key: const ValueKey('status-bar-scrim'),
          height: top + 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, .78, 1],
                colors: [bg, bg.withValues(alpha: .94), bg.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
