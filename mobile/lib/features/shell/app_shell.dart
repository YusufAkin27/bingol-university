import 'dart:async';

import '../../core/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session.dart';
import '../../core/theme_controller.dart';
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

/// Giriş yapılmış kullanıcının kabuğu: sekmeler IndexedStack'te (konum ve veri kaybolmaz) + yüzen gezinme.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session, required this.themeController});

  final Session session;
  final ThemeController themeController; // profil -> ayarlar için

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _tab = 0;
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
    _refreshBadges();
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => _refreshBadges());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _msgSub?.cancel();
    s.realtime?.stop();
    _discoverType.dispose();
    super.dispose();
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
    if (newsType != null) _discoverType.value = newsType;
    setState(() => _tab = i);
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
      setState(() => _tab = AppTab.home);
      return;
    }
    final now = DateTime.now();
    final last = _lastBack;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(context.l10n.exitAgainHint),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: _scaffold(),
    );
  }

  Widget _scaffold() {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          HomeTab(session: s, onOpenTab: _go),
          DiscoverTab(session: s, typeRequest: _discoverType),
          ChatTab(session: s),
          ClubsTab(session: s),
          ProfileTab(session: s, themeController: widget.themeController),
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
