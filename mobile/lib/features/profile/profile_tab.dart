import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart' show gradeLabelL;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/theme_controller.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../academic/academic_hub_page.dart';
import '../chat/contacts_match_page.dart';
import '../follow/follow_suggestions.dart';
import '../follow/follow_summary.dart';
import '../posts/user_posts_page.dart';
import '../support/support_page.dart';
import 'account_security_page.dart';
import 'edit_profile_page.dart';
import 'legal_pages.dart';
import 'my_clubs_page.dart';
import 'my_events_page.dart';
import 'notification_prefs_page.dart';
import 'privacy_data_page.dart';
import 'profil2_my_data_page.dart';
import 'profil_widgets.dart';
import 'saved_news_page.dart';

const _langNames = {'tr': 'Türkçe', 'en': 'English', 'ar': 'العربية'};

/// Profil sekmesi (P9): avatar + ad, "Profili düzenle", gruplu ayar kartları, çıkış.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.session, required this.themeController, this.localeController});

  final Session session;
  final ThemeController themeController;

  /// Verilmezse uygulama genelindeki örnek kullanılır.
  final LocaleController? localeController;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late Future<Map<String, dynamic>> _future = _fetch();
  // İstatistikler: null = yüklenmedi / alınamadı.
  String? _clubs, _events, _saved;

  LocaleController? get _lc => widget.localeController ?? LocaleController.current;

  Future<Map<String, dynamic>> _fetch() async {
    final p = await widget.session.api.get('/users/me') as Map<String, dynamic>;
    _loadStats();
    return p;
  }

  // Tek istekte kulüp / etkinlik / kayıtlı haber sayıları.
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
      // Sayılar alınamazsa gösterilmez; sayfa çalışmaya devam eder.
    }
  }

  void _reload() => setState(() {
        _future = _fetch();
      });

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _loadStats();
  }

  Future<void> _edit(Map<String, dynamic> p) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditProfilePage(session: widget.session, profile: p)),
    );
    if (changed == true) {
      _reload();
      widget.session.refreshName();
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.l10n.profileSignOutTitle),
        content: Text(c.l10n.profileSignOutBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.l10n.profileCancel)),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(c.l10n.profileSignOut)),
        ],
      ),
    );
    if (ok == true) widget.session.signOut();
  }

  Future<void> _pickLang() async {
    final lc = _lc;
    if (lc == null) return;
    final l10n = context.l10n;
    final chosen = await showProfilChoiceSheet(
      context,
      title: l10n.settingsLanguageHint,
      selected: lc.pref,
      options: [
        ('system', l10n.languageSystem),
        for (final e in _langNames.entries) (e.key, e.value),
      ],
    );
    if (chosen == null || chosen == lc.pref) return;
    await lc.set(chosen);
    // Sunucu profil dili (bildirim/e-posta) uygulama diliyle eşitlenir; hata sessizdir.
    try {
      await widget.session.api.patch('/users/me', {'language': lc.locale.languageCode});
    } catch (_) {}
  }

  static const _modes = ['system', 'light', 'dark'];

  String _modeId() => switch (widget.themeController.mode) {
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
      };

  String _modeName(String id) => switch (id) {
        'light' => context.l10n.themeLight,
        'dark' => context.l10n.themeDark,
        _ => context.l10n.themeSystem,
      };

  Future<void> _pickTheme() async {
    final chosen = await showProfilChoiceSheet(
      context,
      title: context.l10n.profil1Theme,
      selected: _modeId(),
      options: [for (final m in _modes) (m, _modeName(m))],
    );
    if (chosen == null) return;
    widget.themeController
        .set(const {'system': ThemeMode.system, 'light': ThemeMode.light, 'dark': ThemeMode.dark}[chosen]!);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final p = snap.data!;
          return RefreshIndicator(
            color: t.pr,
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, kNavInset + 24),
              children: [
                _HeaderBlock(profile: p),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _edit(p),
                    icon: const Icon(LucideIcons.user, size: 16),
                    label: Text(context.l10n.profileEditTitle),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.ink,
                      backgroundColor: t.sf,
                      side: BorderSide(color: t.bd, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      textStyle: BuType.bodyStrong.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (widget.session.userId != null)
                  FollowSummary(
                      session: widget.session, userId: widget.session.userId!, name: widget.session.displayName),
                ProfilSection(context.l10n.profil1SecContent),
                ProfilCard(children: [
                  ProfilRow(
                    icon: LucideIcons.newspaper,
                    label: context.l10n.profileMyPosts,
                    onTap: () => _go(UserPostsPage(session: widget.session)),
                  ),
                  ProfilRow(
                    icon: LucideIcons.userPlus,
                    label: context.l10n.profileSuggested,
                    onTap: () => _go(FollowSuggestionsPage(session: widget.session)),
                  ),
                  ProfilRow(
                    icon: LucideIcons.newspaper,
                    label: context.l10n.profileSaved,
                    value: _saved,
                    onTap: () => _go(SavedNewsPage(session: widget.session)),
                  ),
                  ProfilRow(
                    icon: LucideIcons.calendar,
                    label: context.l10n.profileMyEvents,
                    value: _events,
                    onTap: () => _go(MyEventsPage(session: widget.session)),
                  ),
                  ProfilRow(
                    icon: LucideIcons.users,
                    label: context.l10n.profileMyClubs,
                    value: _clubs,
                    onTap: () => _go(MyClubsPage(session: widget.session)),
                  ),
                ]),
                ProfilSection(context.l10n.profil1SecAccount),
                ProfilCard(children: [
                  ProfilRow(
                    icon: LucideIcons.keyRound,
                    label: context.l10n.profil1AccountSecurity,
                    onTap: () => _go(AccountSecurityPage(session: widget.session)),
                  ),
                  ProfilRow(
                    icon: LucideIcons.lock,
                    label: context.l10n.profil1PrivacyBlocked,
                    onTap: () => _go(PrivacyDataPage(session: widget.session)),
                  ),
                  ProfilRow(
                    icon: LucideIcons.download,
                    label: context.l10n.profil1MyData,
                    onTap: () => _go(MyDataPage(session: widget.session)),
                  ),
                ]),
                ProfilSection(context.l10n.profil1SecApp),
                ListenableBuilder(
                  listenable: Listenable.merge([widget.themeController, if (_lc != null) _lc!]),
                  builder: (context, _) {
                    final lc = _lc;
                    final l10n = context.l10n;
                    final langName = lc == null
                        ? ''
                        : (lc.pref == 'system' ? l10n.languageSystem : (_langNames[lc.pref] ?? lc.pref));
                    return ProfilCard(children: [
                      ProfilRow(
                        icon: LucideIcons.graduationCap,
                        label: l10n.profileAcademic,
                        onTap: () => _go(AcademicHubPage(session: widget.session)),
                      ),
                      ProfilRow(
                        icon: LucideIcons.bell,
                        label: l10n.profil1Notifications,
                        onTap: () => _go(NotificationPrefsPage(session: widget.session)),
                      ),
                      ProfilRow(
                        icon: LucideIcons.contact,
                        label: l10n.settingsFindContacts,
                        onTap: () => _go(ContactsMatchPage(session: widget.session)),
                      ),
                      ProfilRow(
                        icon: LucideIcons.globe,
                        blue: true,
                        label: l10n.settingsLanguage,
                        value: langName,
                        chevron: false,
                        onTap: lc != null ? _pickLang : null,
                      ),
                      ProfilRow(
                        icon: LucideIcons.moon,
                        blue: true,
                        label: l10n.profil1Theme,
                        value: _modeName(_modeId()),
                        chevron: false,
                        onTap: _pickTheme,
                      ),
                    ]);
                  },
                ),
                ProfilSection(context.l10n.profil1SecSupport),
                ProfilCard(children: [
                  ProfilRow(
                    icon: LucideIcons.circleQuestionMark,
                    blue: true,
                    label: context.l10n.profil1Support,
                    onTap: () => _go(SupportPage(session: widget.session)),
                  ),
                  ProfilRow(
                    icon: LucideIcons.fileText,
                    blue: true,
                    label: context.l10n.profil1Legal,
                    onTap: () => _go(LegalListPage(session: widget.session)),
                  ),
                  ProfilRow(
                    icon: LucideIcons.logOut,
                    label: context.l10n.profileSignOut,
                    danger: true,
                    onTap: _confirmSignOut,
                  ),
                ]),
                const SizedBox(height: 18),
                Center(child: Text(context.l10n.settingsVersion('1.0.0'), style: BuType.caption.copyWith(color: t.mut))),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final name = profile['displayName'] as String?;
    final url = fileUrl(profile['avatarUrl'] as String?);
    final year = (profile['classYear'] as num?)?.toInt();
    final g = profile['grade'];
    final grade = (g is String && g.isNotEmpty)
        ? gradeLabelL(context.l10n, g)
        : (year != null && year > 0 ? context.l10n.profileGradeYear('$year') : '');
    final dept = (profile['department'] as String?) ?? '';
    final faculty = (profile['faculty'] as String?) ?? '';
    // Özet: "Bölüm · sınıf"; bölüm yoksa yalnız sınıf. Fakülte ayrı satırda.
    final line1 = [dept, grade].where((s) => s.isNotEmpty).join(' · ');
    final bio = (profile['bio'] as String?) ?? '';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final initials = Container(
      width: 66,
      height: 66,
      alignment: Alignment.center,
      color: t.soft,
      child: Text(initialsOf(name), style: BuType.display.copyWith(fontSize: 24, color: dark ? t.onSoft : t.pr)),
    );
    final avatar = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: t.sf, width: 3),
        boxShadow: dark
            ? null
            : const [BoxShadow(color: Color(0x59171E33), blurRadius: 24, offset: Offset(0, 10), spreadRadius: -12)],
      ),
      child: ClipOval(
        child: url == null
            ? initials
            : Image.network(url, width: 66, height: 66, fit: BoxFit.cover, errorBuilder: (_, __, ___) => initials),
      ),
    );
    // Büyük yazı ölçeğinde avatar üstte, bilgiler altta: ad kırpılmaz.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 14;
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name ?? '',
            maxLines: stacked ? null : 3,
            overflow: TextOverflow.ellipsis,
            style: BuType.display.copyWith(fontSize: 21, letterSpacing: -.3, color: t.ink)),
        if (line1.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(line1, style: BuType.body.copyWith(fontSize: 14, color: t.mut)),
        ],
        if (faculty.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(faculty, style: BuType.body.copyWith(fontSize: 13, color: t.mut)),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stacked) ...[
          avatar,
          const SizedBox(height: 12),
          info,
        ] else
          Row(children: [avatar, const SizedBox(width: 16), Expanded(child: info)]),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(bio, style: BuType.body.copyWith(height: 1.45, color: t.mut)),
        ],
      ],
    );
  }
}
