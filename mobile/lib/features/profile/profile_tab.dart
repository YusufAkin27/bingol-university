import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart' show gradeLabelL;
import '../../core/app_gate.dart' show appVersion;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme_controller.dart';
import '../../widgets/bu.dart';
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

/// Profil sekmesi (P18): vitrin başlığı (avatar, ad, bölüm, biyografi, düzenle), takip karoları, kulüp/etkinlik/kayıtlı
/// istatistik karoları ve gruplu ayar kartları. İlk yüklemede iskelet, çekerek yenile, aşamalı giriş.
class ProfileTab extends StatefulWidget {
  const ProfileTab(
      {super.key,
      required this.session,
      required this.themeController,
      this.localeController});

  final Session session;
  final ThemeController themeController;

  /// Verilmezse uygulama genelindeki örnek kullanılır.
  final LocaleController? localeController;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _profile;
  Object? _error;
  bool _loading = true;
  int _gen = 0;
  // İstatistikler: null = yüklenmedi / alınamadı.
  String? _clubs, _events, _saved;

  LocaleController? get _lc =>
      widget.localeController ?? LocaleController.current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Profili yükler; veri varken (yenileme) iskelet gösterilmez, eski içerik kalır.
  Future<void> _load() async {
    final gen = ++_gen;
    if (_profile == null) setState(() => _loading = true);
    try {
      final p =
          await widget.session.api.get('/users/me') as Map<String, dynamic>;
      if (!mounted || gen != _gen) return;
      setState(() {
        _profile = p;
        _error = null;
        _loading = false;
      });
      _loadStats();
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        if (_profile == null) _error = e;
        _loading = false;
      });
    }
  }

  // Tek istekte kulüp / etkinlik / kayıtlı haber sayıları.
  Future<void> _loadStats() async {
    try {
      final r =
          await widget.session.api.get('/me/summary') as Map<String, dynamic>;
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

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _loadStats();
  }

  Future<void> _edit(Map<String, dynamic> p) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => EditProfilePage(session: widget.session, profile: p)),
    );
    if (changed == true) {
      _load();
      widget.session.refreshName();
    }
  }

  Future<void> _confirmSignOut() async {
    final l = context.l10n;
    final ok = await BuDialog.confirm(
      context,
      title: l.profileSignOutTitle,
      message: l.profileSignOutBody,
      confirmLabel: l.profileSignOut,
      cancelLabel: l.profileCancel,
      destructive: true,
      icon: LucideIcons.logOut,
    );
    if (ok) widget.session.signOut();
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
      await widget.session.api
          .patch('/users/me', {'language': lc.locale.languageCode});
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
    widget.themeController.set(const {
      'system': ThemeMode.system,
      'light': ThemeMode.light,
      'dark': ThemeMode.dark
    }[chosen]!);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final top = MediaQuery.paddingOf(context).top;
    final p = _profile;
    Widget body;
    if (p == null && _loading) {
      body = _ProfileSkeleton(top: top);
    } else if (p == null) {
      body = _ProfileSkeleton(top: top, error: _error, onRetry: _load);
    } else {
      body = RefreshIndicator(
        color: t.pr,
        backgroundColor: t.sf3,
        edgeOffset: top,
        onRefresh: () {
          buHaptic(BuHaptic.selection);
          return _load();
        },
        child: _content(p, top),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: AnimatedSwitcher(
        duration: BuMotion.of(context, BuMotion.medium),
        child: KeyedSubtree(
            key: ValueKey(p != null ? 'ready' : (_loading ? 'load' : 'err')),
            child: body),
      ),
    );
  }

  Widget _content(Map<String, dynamic> p, double top) {
    final l = context.l10n;
    final t = context.bu;
    final uid = widget.session.userId;
    return BuStaggerScope(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            EdgeInsetsDirectional.fromSTEB(20, top + 12, 20, kNavInset + 24),
        children: [
          BuStaggerItem(index: 0, child: _TitleRow(onEdit: () => _edit(p))),
          const SizedBox(height: 12),
          BuStaggerItem(index: 0, child: _ProfileHero(profile: p)),
          if (uid != null) ...[
            const SizedBox(height: 12),
            BuStaggerItem(
              index: 1,
              child: FollowSummary(
                  session: widget.session,
                  userId: uid,
                  name: widget.session.displayName),
            ),
          ],
          const SizedBox(height: 12),
          BuStaggerItem(
            index: 2,
            child: IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Expanded(
                    child: _StatTile(
                      accent: true,
                      count: _clubs,
                      label: l.profileMyClubs,
                      onTap: () => _go(MyClubsPage(session: widget.session)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      accent: false,
                      count: _events,
                      label: l.profileMyEvents,
                      onTap: () => _go(MyEventsPage(session: widget.session)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      accent: false,
                      count: _saved,
                      label: l.profileSaved,
                      onTap: () => _go(SavedNewsPage(session: widget.session)),
                    ),
                  ),
                ])),
          ),
          BuStaggerItem(
            index: 3,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfilSection(l.profil1SecContent),
                  ProfilCard(children: [
                    ProfilRow(
                      icon: LucideIcons.newspaper,
                      label: l.profileMyPosts,
                      onTap: () => _go(UserPostsPage(session: widget.session)),
                    ),
                    ProfilRow(
                      icon: LucideIcons.userPlus,
                      tint: t.tint(4),
                      label: l.profileSuggested,
                      onTap: () =>
                          _go(FollowSuggestionsPage(session: widget.session)),
                    ),
                  ]),
                ]),
          ),
          BuStaggerItem(
            index: 4,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfilSection(l.profil1SecAccount),
                  ProfilCard(children: [
                    ProfilRow(
                      icon: LucideIcons.keyRound,
                      tint: t.tint(3),
                      label: l.profil1AccountSecurity,
                      onTap: () =>
                          _go(AccountSecurityPage(session: widget.session)),
                    ),
                    ProfilRow(
                      icon: LucideIcons.lock,
                      tint: t.tint(1),
                      label: l.profil1PrivacyBlocked,
                      onTap: () =>
                          _go(PrivacyDataPage(session: widget.session)),
                    ),
                    ProfilRow(
                      icon: LucideIcons.download,
                      tint: t.tint(5),
                      label: l.profil1MyData,
                      onTap: () => _go(MyDataPage(session: widget.session)),
                    ),
                  ]),
                ]),
          ),
          BuStaggerItem(
            index: 5,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfilSection(l.profil1SecApp),
                  ListenableBuilder(
                    listenable: Listenable.merge(
                        [widget.themeController, if (_lc != null) _lc!]),
                    builder: (context, _) {
                      final lc = _lc;
                      final l10n = context.l10n;
                      final langName = lc == null
                          ? ''
                          : (lc.pref == 'system'
                              ? l10n.languageSystem
                              : (_langNames[lc.pref] ?? lc.pref));
                      return ProfilCard(children: [
                        ProfilRow(
                          icon: LucideIcons.graduationCap,
                          tint: t.tint(2),
                          label: l10n.profileAcademic,
                          onTap: () =>
                              _go(AcademicHubPage(session: widget.session)),
                        ),
                        ProfilRow(
                          icon: LucideIcons.bell,
                          label: l10n.profil1Notifications,
                          onTap: () => _go(
                              NotificationPrefsPage(session: widget.session)),
                        ),
                        ProfilRow(
                          icon: LucideIcons.contact,
                          tint: t.tint(4),
                          label: l10n.settingsFindContacts,
                          onTap: () =>
                              _go(ContactsMatchPage(session: widget.session)),
                        ),
                        ProfilRow(
                          icon: LucideIcons.globe,
                          tint: t.tint(1),
                          label: l10n.settingsLanguage,
                          value: langName,
                          chevron: false,
                          onTap: lc != null ? _pickLang : null,
                        ),
                        ProfilRow(
                          icon: LucideIcons.moon,
                          tint: t.tint(5),
                          label: l10n.profil1Theme,
                          value: _modeName(_modeId()),
                          chevron: false,
                          onTap: _pickTheme,
                        ),
                      ]);
                    },
                  ),
                ]),
          ),
          BuStaggerItem(
            index: 6,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfilSection(l.profil1SecSupport),
                  ProfilCard(children: [
                    ProfilRow(
                      icon: LucideIcons.circleQuestionMark,
                      tint: t.tint(1),
                      label: l.profil1Support,
                      onTap: () => _go(SupportPage(session: widget.session)),
                    ),
                    ProfilRow(
                      icon: LucideIcons.fileText,
                      tint: t.tint(5),
                      label: l.profil1Legal,
                      onTap: () => _go(LegalListPage(session: widget.session)),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _SignOutButton(
                      label: l.profileSignOut, onTap: _confirmSignOut),
                ]),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(l.settingsVersion(appVersion),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium!
                    .copyWith(color: t.mut)),
          ),
        ],
      ),
    );
  }
}

/// Sayfa başlığı ("Profilim") + sağda "Düzenle" hapı (soluk marka tonu).
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Row(children: [
      Expanded(
        child: Semantics(
          container: true,
          header: true,
          child: Text(l.p18ProfileTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium!
                  .copyWith(fontWeight: FontWeight.w800, color: t.ink)),
        ),
      ),
      const SizedBox(width: 12),
      Semantics(
          container: true,
          button: true,
          label: l.profileEditTitle,
          excludeSemantics: true,
          onTap: onEdit,
          child: BuPressable(
            onTap: onEdit,
            haptic: BuHaptic.selection,
            child: Container(
              key: const ValueKey('profile-edit'),
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration:
                  BoxDecoration(color: t.soft, borderRadius: BuRadius.bPill),
              alignment: Alignment.center,
              child: ExcludeSemantics(
                child: Text(l.p18Edit,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: t.onSoft, fontWeight: FontWeight.w700)),
              ),
            ),
          )),
    ]);
  }
}

/// Profil kartı (beyaz): ortada avatar (kırmızı halka), ad, "Bölüm • Sınıf", fakülte, e-posta ve biyografi.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final name = profile['displayName'] as String?;
    final year = (profile['classYear'] as num?)?.toInt();
    final g = profile['grade'];
    final grade = (g is String && g.isNotEmpty)
        ? gradeLabelL(context.l10n, g)
        : (year != null && year > 0
            ? context.l10n.profileGradeYear('$year')
            : '');
    final dept = (profile['department'] as String?) ?? '';
    final faculty = (profile['faculty'] as String?) ?? '';
    final line1 = [dept, grade].where((s) => s.isNotEmpty).join(' • ');
    final email = (profile['email'] as String?) ?? '';
    final bio = (profile['bio'] as String?) ?? '';
    return BuCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      radius: 24,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.pr, width: 2)),
          child: BuAvatar(
              name: name, url: profile['avatarUrl'] as String?, size: 84),
        ),
        const SizedBox(height: 14),
        Text(name ?? '',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: tx.headlineSmall!
                .copyWith(color: t.ink, fontWeight: FontWeight.w800)),
        if (line1.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(line1,
              textAlign: TextAlign.center,
              style: tx.bodyMedium!
                  .copyWith(color: t.tint(1).fg, fontWeight: FontWeight.w600)),
        ],
        if (faculty.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(faculty,
              textAlign: TextAlign.center,
              style: tx.bodySmall!.copyWith(color: t.mut)),
        ],
        if (email.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            ExcludeSemantics(
                child: Icon(LucideIcons.atSign, size: 14, color: t.mut)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tx.bodySmall!
                      .copyWith(color: t.ink, fontWeight: FontWeight.w500)),
            ),
          ]),
        ],
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(bio,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
        ],
      ]),
    );
  }
}

/// Gri, tam genişlik "Çıkış yap" hapı.
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return BuPressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        key: const ValueKey('profile-signout'),
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
        alignment: Alignment.center,
        child: ExcludeSemantics(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.logOut, size: 18, color: t.ink),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall!
                      .copyWith(color: t.ink, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// İstatistik karosu: büyük sayı (ilki marka renginde) + etiket; dokununca ilgili liste.
class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.accent,
      required this.count,
      required this.label,
      required this.onTap});

  final bool accent;
  final String? count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: count == null ? label : '$count $label',
      excludeSemantics: true,
      child: BuCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        radius: 18,
        onTap: () {
          buHaptic(BuHaptic.selection);
          onTap();
        },
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(count ?? '–',
              maxLines: 1,
              style: tx.headlineSmall!.copyWith(
                  color: accent ? t.pr : t.ink, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                maxLines: 1, style: tx.labelMedium!.copyWith(color: t.mut)),
          ),
        ]),
      ),
    );
  }
}

/// İlk yükleme iskeleti: profil kartı + karolar + gruplu satırlar (gerçek düzenle aynı ölçüler, sayfa zıplamaz).
/// [error] doluysa üstte kırmızı hata kartı ("Yüklenemedi, tekrar dene" + "Yeniden dene") görünür.
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton({required this.top, this.error, this.onRetry});

  final double top;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget group(int rows) => BuCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < rows; i++)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  BuSkeleton(width: 36, height: 36, radius: 12),
                  SizedBox(width: 14),
                  Expanded(child: BuSkeleton.line(height: 14)),
                ]),
              ),
          ]),
        );
    final skeleton = BuSkeletonScope(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const BuCard(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 20),
          radius: 24,
          child: Column(children: [
            BuSkeleton.circle(90),
            SizedBox(height: 14),
            BuSkeleton.line(width: 160, height: 18),
            SizedBox(height: 10),
            BuSkeleton.line(width: 200),
            SizedBox(height: 8),
            BuSkeleton.line(width: 120, height: 10),
          ]),
        ),
        const SizedBox(height: 12),
        const Row(children: [
          Expanded(child: BuSkeleton(height: 60, radius: 18)),
          SizedBox(width: 12),
          Expanded(child: BuSkeleton(height: 60, radius: 18)),
        ]),
        const SizedBox(height: 12),
        const Row(children: [
          Expanded(child: BuSkeleton(height: 76, radius: 18)),
          SizedBox(width: 10),
          Expanded(child: BuSkeleton(height: 76, radius: 18)),
          SizedBox(width: 10),
          Expanded(child: BuSkeleton(height: 76, radius: 18)),
        ]),
        const SizedBox(height: 24),
        const BuSkeleton.line(width: 110, height: 12),
        const SizedBox(height: 10),
        group(2),
        const SizedBox(height: 24),
        const BuSkeleton.line(width: 80, height: 12),
        const SizedBox(height: 10),
        group(3),
      ]),
    );
    return Semantics(
      label: error == null ? l.commonLoading : null,
      liveRegion: true,
      container: true,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.fromSTEB(20, top + 12, 20, 24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (error != null) ...[
            Container(
              key: const ValueKey('profile-error'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: cs.errorContainer, borderRadius: BuRadius.bMd),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: t.danger.withValues(alpha: .14),
                      shape: BoxShape.circle),
                  child: Icon(LucideIcons.wifiOff, size: 20, color: t.danger),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.p18ProfileLoadFailed,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tx.titleSmall!.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.onErrorContainer)),
                        Text(errorText(error!),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tx.bodySmall!
                                .copyWith(color: cs.onErrorContainer)),
                      ]),
                ),
                const SizedBox(width: 10),
                BuButton(
                    label: l.profileRetry,
                    icon: LucideIcons.refreshCw,
                    compact: true,
                    onPressed: onRetry),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          skeleton,
        ]),
      ),
    );
  }
}
