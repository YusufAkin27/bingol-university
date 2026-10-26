import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/theme_controller.dart';
import '../../widgets/bu_widgets.dart';
import '../chat/chat_tab.dart';
import '../clubs/clubs_tab.dart';
import '../discover/discover_tab.dart';
import '../home/home_tab.dart';
import '../profile/profile_tab.dart';

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

  @override
  Widget build(BuildContext context) {
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

/// Yüzen hap gezinme: seçili sekme kırmızı hap + etiket, diğerleri yalnızca ikon.
class FloatingNav extends StatelessWidget {
  const FloatingNav({super.key, required this.index, required this.onChanged, required this.chatBadge});

  final int index;
  final ValueChanged<int> onChanged;
  final ValueNotifier<int> chatBadge;

  static const _items = [
    (LucideIcons.house, 'Ana Sayfa'),
    (LucideIcons.compass, 'Keşfet'),
    (LucideIcons.messageCircle, 'Sohbet'),
    (LucideIcons.users, 'Kulüpler'),
    (LucideIcons.user, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom > 0 ? bottom : 16),
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: t.nav,
          borderRadius: BorderRadius.circular(33),
          border: Border.all(color: t.bg == BuTokens.dark.bg ? t.bd : Colors.transparent),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: .28), blurRadius: 30, offset: const Offset(0, 14)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < _items.length; i++)
              Semantics(
                button: true,
                selected: i == index,
                label: _items[i].$2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 46,
                    constraints: const BoxConstraints(minWidth: 46),
                    padding: EdgeInsets.symmetric(horizontal: i == index ? 16 : 0),
                    decoration: BoxDecoration(
                      color: i == index ? t.pr : Colors.transparent,
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _icon(i, t),
                        if (i == index) ...[
                          const SizedBox(width: 8),
                          Text(_items[i].$2,
                              style: TextStyle(color: t.onPr, fontSize: 13, fontWeight: FontWeight.w800)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _icon(int i, BuTokens t) {
    final color = i == index ? t.onPr : t.onNav.withValues(alpha: .75);
    final icon = Icon(_items[i].$1, size: 24, color: color);
    if (i != AppTab.chat) return icon;
    return ValueListenableBuilder<int>(
      valueListenable: chatBadge,
      builder: (_, n, __) => Badge(
        isLabelVisible: n > 0 && i != index,
        label: Text(n > 99 ? '99+' : '$n'),
        backgroundColor: t.pr,
        textColor: t.onPr,
        child: icon,
      ),
    );
  }
}
