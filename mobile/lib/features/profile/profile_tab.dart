import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart' show AcademicLabels, gradeLabelL;
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

/// Profil sekmesi (P18, tur 3 sadeleşmesi): profil kartı (avatar, ad, bölüm, e-posta), TEK satır/TEK yüzey sayaç şeridi
/// (Takipçi · Takip · Kulüp · Etkinlik) ve aynı yüzey ailesinden, tek nötr simge tonlu gruplu listeler; en sonda sakin
/// çıkış düğmesi. İlk yüklemede iskelet, çekerek yenile, aşamalı giriş.
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
      final av = p['avatarUrl'];
      widget.session.avatarUrl.value = av is String && av.isNotEmpty ? av : null; // alt gezinme Profil sekmesi avatarı
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
    int? n(String? v) => int.tryParse(v ?? '');
    final extraCells = [
      StatCell(
          label: l.p18CounterClubs,
          value: n(_clubs),
          onTap: () => _go(MyClubsPage(session: widget.session))),
      StatCell(
          label: l.p18CounterEvents,
          value: n(_events),
          onTap: () => _go(MyEventsPage(session: widget.session))),
    ];
    return BuStaggerScope(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            EdgeInsetsDirectional.fromSTEB(20, top + 12, 20, kNavInset + 24),
        children: [
          BuStaggerItem(index: 0, child: _TitleRow(onEdit: () => _edit(p))),
          const SizedBox(height: 16),
          BuStaggerItem(index: 0, child: _ProfileHero(profile: p)),
          const SizedBox(height: 16),
          // Takipçi · Takip · Kulüp · Etkinlik: tek yüzey, tek satır.
          BuStaggerItem(
            index: 1,
            child: uid != null
                ? FollowSummary(
                    session: widget.session,
                    userId: uid,
                    name: widget.session.displayName,
                    extraCells: extraCells,
                  )
                : StatStrip(cells: extraCells),
          ),
          BuStaggerItem(
            index: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ProfilSection(l.profil1SecContent, top: 24),
              ProfilCard(children: [
                ProfilRow(
                  icon: LucideIcons.newspaper,
                  label: l.profileMyPosts,
                  onTap: () => _go(UserPostsPage(session: widget.session)),
                ),
                ProfilRow(
                  icon: LucideIcons.bookmark,
                  label: l.profileSaved,
                  value: _saved,
                  onTap: () => _go(SavedNewsPage(session: widget.session)),
                ),
                ProfilRow(
                  icon: LucideIcons.userPlus,
                  label: l.profileSuggested,
                  onTap: () => _go(FollowSuggestionsPage(session: widget.session)),
                ),
              ]),
            ]),
          ),
          BuStaggerItem(
            index: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ProfilSection(l.p18SecPrefs, top: 24),
              ListenableBuilder(
                listenable: Listenable.merge([widget.themeController, if (_lc != null) _lc!]),
                builder: (context, _) {
                  final lc = _lc;
                  final l10n = context.l10n;
                  final langName =
                      lc == null ? '' : (lc.pref == 'system' ? l10n.languageSystem : (_langNames[lc.pref] ?? lc.pref));
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
                      label: l10n.settingsLanguage,
                      value: langName,
                      onTap: lc != null ? _pickLang : null,
                    ),
                    ProfilRow(
                      icon: LucideIcons.moon,
                      label: l10n.profil1Theme,
                      value: _modeName(_modeId()),
                      onTap: _pickTheme,
                    ),
                  ]);
                },
              ),
            ]),
          ),
          BuStaggerItem(
            index: 4,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ProfilSection(l.p18SecAccount, top: 24),
              ProfilCard(children: [
                ProfilRow(
                  icon: LucideIcons.keyRound,
                  label: l.profil1AccountSecurity,
                  onTap: () => _go(AccountSecurityPage(session: widget.session)),
                ),
                ProfilRow(
                  icon: LucideIcons.lock,
                  label: l.profil1PrivacyBlocked,
                  onTap: () => _go(PrivacyDataPage(session: widget.session)),
                ),
                ProfilRow(
                  icon: LucideIcons.download,
                  label: l.profil1MyData,
                  onTap: () => _go(MyDataPage(session: widget.session)),
                ),
              ]),
            ]),
          ),
          BuStaggerItem(
            index: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ProfilSection(l.p18SecAbout, top: 24),
              ProfilCard(children: [
                ProfilRow(
                  icon: LucideIcons.circleQuestionMark,
                  label: l.profil1Support,
                  onTap: () => _go(SupportPage(session: widget.session)),
                ),
                ProfilRow(
                  icon: LucideIcons.fileText,
                  label: l.profil1Legal,
                  onTap: () => _go(LegalListPage(session: widget.session)),
                ),
              ]),
              // Listenin sonunda sakin ve net: çıkış, altında soluk sürüm satırı.
              const SizedBox(height: 24),
              _SignOutButton(label: l.profileSignOut, onTap: _confirmSignOut),
              const SizedBox(height: 16),
              Center(
                child: Text(l.settingsVersion(appVersion),
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.mut)),
              ),
            ]),
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

/// Profil kartı: ortada avatar, ad, "Bölüm • Sınıf", fakülte, e-posta ve (varsa) kısa biyografi. Tek ton (nötr);
/// süs yok (kırmızı halka, mavi satır, e-posta simgesi kalktı).
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
    final facultyCanon = (profile['faculty'] as String?) ?? '';
    final dept = context.departmentName((profile['department'] as String?) ?? '', faculty: facultyCanon);
    final faculty = context.facultyName(facultyCanon);
    final line1 = [dept, grade].where((s) => s.isNotEmpty).join(' • ');
    final email = (profile['email'] as String?) ?? '';
    final bio = (profile['bio'] as String?) ?? '';
    return BuCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        BuAvatar(name: name, url: profile['avatarUrl'] as String?, size: 76),
        const SizedBox(height: 16),
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
                  .copyWith(color: t.ink, fontWeight: FontWeight.w600)),
        ],
        if (faculty.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(faculty,
              textAlign: TextAlign.center,
              style: tx.bodySmall!.copyWith(color: t.mut)),
        ],
        if (email.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(email,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tx.bodySmall!.copyWith(color: t.mut)),
        ],
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(bio,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
        ],
      ]),
    );
  }
}

/// Sakin, tam genişlik "Çıkış yap" hapı: soluk yüzey, simgesiz, vurgu rengi yok (dikkat çekmez ama net).
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return BuPressable(
      onTap: onTap,
      haptic: BuHaptic.selection,
      semanticLabel: label,
      child: Container(
        key: const ValueKey('profile-signout'),
        constraints: const BoxConstraints(minHeight: BuSize.button),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
        alignment: Alignment.center,
        child: ExcludeSemantics(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(color: t.ink, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

/// İlk yükleme iskeleti: profil kartı + sayaç şeridi + gruplu satırlar (gerçek düzenle aynı ölçüler, sayfa zıplamaz).
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
          padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(children: [
            BuSkeleton.circle(84),
            SizedBox(height: 16),
            BuSkeleton.line(width: 160, height: 18),
            SizedBox(height: 10),
            BuSkeleton.line(width: 200),
            SizedBox(height: 8),
            BuSkeleton.line(width: 120, height: 10),
          ]),
        ),
        const SizedBox(height: 16),
        const BuSkeleton(height: 72, radius: 20),
        const SizedBox(height: 24),
        const BuSkeleton.line(width: 110, height: 12),
        const SizedBox(height: 8),
        group(3),
        const SizedBox(height: 24),
        const BuSkeleton.line(width: 80, height: 12),
        const SizedBox(height: 8),
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
            const SizedBox(height: 16),
          ],
          skeleton,
        ]),
      ),
    );
  }
}
