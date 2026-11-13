import 'package:flutter/material.dart';

import 'profile_share.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme_controller.dart';
import '../../widgets/bu.dart';
import '../academic/academic_hub_page.dart';
import '../follow/follow_requests_api.dart';
import '../follow/follow_requests_page.dart';
import '../forum/forum_routes.dart' show openMyForumActivity;
import '../posts/user_posts_page.dart';
import '../support/support_page.dart';
import 'my_clubs_page.dart';
import 'my_events_page.dart';
import 'notification_prefs_page.dart';
import 'privacy_data_page.dart';
import 'profil_widgets.dart';
import '../posts/liked_posts_page.dart';
import '../saved/saved_items_page.dart';
import 'saved_news_page.dart';
import 'settings_page.dart';

/// Profilim sağ üstündeki üç çizgi menüsü: profil sayfasında artık satır listesi yoktur, hepsi burada gruplu durur.
/// İçeriğim (takip istekleri, gönderilerim, kayıtlı haberler, kulüplerim, etkinliklerim) ve Uygulama tercihleri
/// (akademik, bildirimler, gizlilik, ayarlar, yardım). Kulüp / etkinlik / kayıtlı sayıları satırın sağında soluk metin.
/// Dil, tema, hesap güvenliği, engellenenler, hakkında ve çıkış Ayarlar sayfasındadır.
class ProfileMenuPage extends StatefulWidget {
  const ProfileMenuPage({super.key, required this.session, required this.themeController, this.localeController});

  final Session session;
  final ThemeController themeController;

  /// Verilmezse uygulama genelindeki örnek kullanılır.
  final LocaleController? localeController;

  @override
  State<ProfileMenuPage> createState() => _ProfileMenuPageState();
}

class _ProfileMenuPageState extends State<ProfileMenuPage> {
  // null = yüklenmedi / alınamadı (satırda sayı gösterilmez).
  String? _clubs, _events, _saved;
  int _followReq = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final r = await widget.session.api.get('/me/summary') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _clubs = '${(r['communities'] as num?)?.toInt() ?? 0}';
        _events = '${(r['events'] as num?)?.toInt() ?? 0}';
        _saved = '${(r['bookmarks'] as num?)?.toInt() ?? 0}';
      });
    } catch (_) {
      // Sayılar alınamazsa gösterilmez; menü çalışmaya devam eder.
    }
    try {
      final n = await FollowRequestsApi(widget.session).count();
      if (mounted && n != null && n != _followReq) setState(() => _followReq = n);
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
  }

  Future<void> _go(Widget page, [String? screen]) async {
    await Navigator.push(context, MaterialPageRoute(settings: RouteSettings(name: screen), builder: (_) => page));
    if (mounted) _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final s = widget.session;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          ProfilTopBar(title: l.profileMenuTitle),
          Expanded(
            child: BuStaggerScope(
              child: ListView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.paddingOf(context).bottom + 32),
              children: [
BuStaggerItem(index: 0, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ProfilSection(l.profil1SecContent, top: 8),
                ProfilCard(children: [
                  // Takip istekleri (yalnız bekleyen varken): sayı satırın sağında metin, rozet yok.
                  if (_followReq > 0)
                    ProfilRow(
                      key: const ValueKey('profile-follow-requests'),
                      icon: BuIcons.userPlus,
                      label: l.frqReqTitle,
                      value: '$_followReq',
                      onTap: () => _go(FollowRequestsPage(session: s), 'follow_requests'),
                    ),
                  ProfilRow(
                    key: const ValueKey('menu-my-qr'),
                    icon: BuIcons.qrCode,
                    label: l.profileQrMyCode,
                    onTap: () => openMyQr(context, s),
                  ),
                  ProfilRow(
                    key: const ValueKey('menu-qr-scan'),
                    icon: BuIcons.camera,
                    label: l.profileQrScan,
                    onTap: () => openProfileScanner(context, s),
                  ),
                  ProfilRow(
                    key: const ValueKey('menu-my-posts'),
                    icon: BuIcons.image,
                    label: l.profileMyPosts,
                    onTap: () => _go(UserPostsPage(session: s), 'user_posts'),
                  ),
                  ProfilRow(
                    key: const ValueKey('menu-saved'),
                    icon: BuIcons.bookmark,
                    label: l.profileSaved,
                    value: _saved,
                    onTap: () => _go(SavedNewsPage(session: s), 'saved_news'),
                  ),
                  ProfilRow(
                    key: const ValueKey('menu-saved-all'),
                    icon: BuIcons.bookmarkFilled,
                    label: l.svMenuRow,
                    onTap: () => _go(SavedItemsPage(session: s), 'saved_items'),
                  ),
                  ProfilRow(
                    key: const ValueKey('menu-liked'),
                    icon: BuIcons.heart,
                    label: l.profileLiked,
                    onTap: () => _go(LikedPostsPage(session: s), 'liked_posts'),
                  ),
                  ProfilRow(
                    key: const ValueKey('menu-club-hub'),
                    icon: BuIcons.clipboardList,
                    label: l.profileClubHub,
                    onTap: () => _go(MyClubsPage(session: s), 'my_clubs'),
                  ),
                  ProfilRow(
                    key: const ValueKey('menu-my-clubs'),
                    icon: BuIcons.users,
                    label: l.profileMyClubs,
                    value: _clubs,
                    onTap: () => _go(MyClubsPage(session: s), 'my_clubs'),
                  ),
                  ProfilRow(
                    key: const ValueKey('menu-my-events'),
                    icon: BuIcons.calendar,
                    label: l.profileMyEvents,
                    value: _events,
                    onTap: () => _go(MyEventsPage(session: s), 'my_events'),
                  ),
                ]),
])),
BuStaggerItem(index: 1, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ProfilSection(l.p18SecPrefs, top: 24),
                ProfilCard(children: [
                  ProfilRow(
                    key: const ValueKey('menu-academic'),
                    icon: BuIcons.graduationCap,
                    label: l.profileAcademic,
                    onTap: () => _go(AcademicHubPage(session: s), 'academic_hub'),
                  ),
                  ProfilRow(
                    key: const ValueKey('menu-notifications'),
                    icon: BuIcons.bell,
                    label: l.notifTitle,
                    onTap: () => _go(NotificationPrefsPage(session: s), 'notification_prefs'),
                  ),
                  ProfilRow(
                    key: const ValueKey('menu-privacy'),
                    icon: BuIcons.lock,
                    label: l.settingsPrivacyData,
                    onTap: () => _go(PrivacyDataPage(session: s), 'privacy_data'),
                  ),
                  ProfilRow(
                    key: const ValueKey('menu-settings'),
                    icon: BuIcons.settings,
                    label: l.settingsTitle,
                    onTap: () => _go(
                        SettingsPage(session: s, themeController: widget.themeController, localeController: widget.localeController), 'settings'),
                  ),
                  ProfilRow(
                    key: const ValueKey('menu-support'),
                    icon: BuIcons.headset,
                    label: l.profil1Support,
                    onTap: () => _go(SupportPage(session: s), 'support'),
                  ),
                ]),
])),
                // Kampüs Forum faaliyetim: her satır ilgili sekmeyi doğrudan açar.
BuStaggerItem(index: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ProfilSection(l.forumActivitySection, top: 24),
                ProfilCard(children: [
                  ProfilRow(
                    key: const ValueKey('menu-forum-topics'),
                    icon: BuIcons.messageSquareText,
                    label: l.forumActivityTabTopics,
                    onTap: () => openMyForumActivity(context, s, initialTab: 0),
                  ),
                  ProfilRow(
                    key: const ValueKey('menu-forum-comments'),
                    icon: BuIcons.messageCircle,
                    label: l.forumActivityTabComments,
                    onTap: () => openMyForumActivity(context, s, initialTab: 1),
                  ),
                  ProfilRow(
                    key: const ValueKey('menu-forum-saved'),
                    icon: BuIcons.bookmark,
                    label: l.forumActivityTabSaved,
                    onTap: () => openMyForumActivity(context, s, initialTab: 2),
                  ),
                  ProfilRow(
                    key: const ValueKey('menu-forum-following'),
                    icon: BuIcons.bell,
                    label: l.forumActivityTabFollowing,
                    onTap: () => openMyForumActivity(context, s, initialTab: 3),
                  ),
                ]),
])),
              ],
            )),
          ),
        ],
      ),
    );
  }
}
