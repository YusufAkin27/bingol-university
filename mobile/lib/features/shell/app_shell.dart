import 'dart:async';

import '../news/news_list_page.dart';
import '../../core/locale_controller.dart';
import '../../core/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session.dart';
import '../../core/theme_controller.dart';
import '../../core/theme/bu_motion.dart';
import '../../widgets/bu_overlays.dart' show BuToast;
import '../chat/chat_tab.dart';
import '../clubs/clubs_tab.dart';
import '../discover/discover_tab.dart';
import '../home/home_tab.dart';
import '../profile/profile_tab.dart';
import 'floating_nav.dart';

export 'floating_nav.dart' show FloatingNav;

/// Sekme sırası: 0 Ana Sayfa, 1 Keşfet, 2 Sohbet, 3 Kulüpler, 4 Profil.
abstract final class AppTab {
  static const home = 0, discover = 1, chat = 2, clubs = 3, profile = 4;
}

/// Giriş yapılmış kullanıcının kabuğu: sekmeler TEMBEL kurulur (ilk karede yalnız ana sekme; diğerleri ilk
/// seçimde kurulur, sonra IndexedStack'te canlı kalır: konum ve veri kaybolmaz) + M3 alt gezinme.
/// Sekme geçişi "fade-through" (kısa soluklaşma + hafif ölçek; yalnız seçilen sekme animasyonlanır).
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session, required this.themeController});

  final Session session;
  final ThemeController themeController; // profil -> ayarlar için

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _tab = 0;
  // Bir kez açılmış sekmeler (tembel kurulum; kapanınca da canlı kalır).
  final Set<int> _built = {AppTab.home};
  late final AnimationController _fade = AnimationController(vsync: this, duration: BuMotion.medium, value: 1);
  late final Animation<double> _fadeIn = CurvedAnimation(parent: _fade, curve: BuMotion.emphasizedDecelerate);
  Timer? _poll;
  StreamSubscription<Map<String, dynamic>>? _msgSub;
  final _discoverType = ValueNotifier<String?>(null);

  Session get s => widget.session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    s.realtime?.start();
    _msgSub = s.realtime?.messages.listen(_onRealtimeMessage);
    shellTabRequest.addListener(_onTabRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onTabRequest());
    _refreshBadges();
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => _refreshBadges());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    shellTabRequest.removeListener(_onTabRequest);
    _poll?.cancel();
    _msgSub?.cancel();
    s.realtime?.stop();
    _discoverType.dispose();
    _fade.dispose();
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
    if (state == AppLifecycleState.resumed) _refreshBadges();
  }

  // realtime kendi arka plan/ön plan geçişini yönetir (start sonrası observer).

  /// Başkasından gelen yeni mesajda (kendi ack'i hariç) sohbet rozetini artırır; sohbet sekmesi açıkken artırmaz.
  void _onRealtimeMessage(Map<String, dynamic> m) {
    final sender = (m['senderId'] as num?)?.toInt() ?? ((m['sender'] as Map?)?['id'] as num?)?.toInt();
    if (sender != null && sender == s.userId) return;
    if (_tab == AppTab.chat) return;
    s.badges.chat.value++;
  }

  /// Tek istek: okunmamış bildirim + mesaj sayıları (GET /me/summary).
  Future<void> _refreshBadges() async {
    try {
      final m = await s.api.get('/me/summary') as Map<String, dynamic>;
      s.badges.notifications.value = (m['unreadNotifications'] as num?)?.toInt() ?? 0;
      s.badges.chat.value = (m['unreadMessages'] as num?)?.toInt() ?? 0;
    } catch (_) {}
  }

  void _go(int i, {String? newsType}) {
    if (newsType != null) {
      // Keşfet artık yalnız gönderiler: haber/duyuru/etkinlik listesi ayrı sayfada açılır.
      Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => NewsListPage(session: s, initialType: newsType)));
      return;
    }
    _select(i);
  }

  /// Sekmeyi seçer: ilk seçimde kurar, geçişte fade-through oynatır ("animasyonları azalt" ise anlık).
  void _select(int i) {
    if (i == _tab) return;
    setState(() {
      _tab = i;
      _built.add(i);
    });
    if (BuMotion.reduced(context)) {
      _fade.value = 1;
    } else {
      _fade.forward(from: 0);
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
        return DiscoverTab(session: s, typeRequest: _discoverType);
      case AppTab.chat:
        return ChatTab(session: s);
      case AppTab.clubs:
        return ClubsTab(session: s);
      default:
        return ProfileTab(session: s, themeController: widget.themeController);
    }
  }

  Widget _scaffold() {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          for (var i = 0; i <= AppTab.profile; i++)
            // Kurulmamış sekme boş kalır: ağ isteği/ağaç maliyeti ilk seçime ertelenir.
            if (_built.contains(i))
              _TabFade(
                key: ValueKey('tab-$i'),
                animation: i == _tab ? _fadeIn : null,
                child: _tabBody(i),
              )
            else
              const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: FloatingNav(
        index: _tab,
        onChanged: (i) {
          _go(i);
          if (i == AppTab.chat) _refreshBadges();
        },
        chatBadge: s.badges.chat,
      ),
    );
  }
}

/// Seçilen sekmeyi soluklaştırıp hafifçe ölçekler; animasyon yoksa/bittiğinde ek katman oluşmaz.
class _TabFade extends StatelessWidget {
  const _TabFade({super.key, required this.child, this.animation});

  final Widget child;
  final Animation<double>? animation;

  @override
  Widget build(BuildContext context) {
    final a = animation ?? const AlwaysStoppedAnimation<double>(1);
    return FadeTransition(
      opacity: Tween<double>(begin: .0, end: 1).animate(a),
      child: ScaleTransition(
        scale: Tween<double>(begin: .985, end: 1).animate(a),
        child: child,
      ),
    );
  }
}
