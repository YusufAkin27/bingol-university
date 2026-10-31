import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart' show AcademicLabels, gradeLabelL;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme_controller.dart';
import '../../widgets/bu.dart';
import '../academic/academic_hub_page.dart';
import '../follow/follow_suggestions.dart';
import '../follow/follow_summary.dart';
import '../posts/post_api.dart';
import '../posts/user_posts_page.dart';
import '../support/support_page.dart';
import 'edit_profile_page.dart';
import 'my_clubs_page.dart';
import 'my_events_page.dart';
import 'notification_prefs_page.dart';
import 'profil_widgets.dart';
import 'settings_page.dart';
import 'saved_news_page.dart';

/// Profil sekmesi (Stitch v3 birebir): "Profilim" + Düzenle çipi, kartsız profil üstü (88 dp avatar, ad, bölüm · sınıf, bio),
/// tek kutuda 3 sütun sayaç (Takipçi · Takip · Gönderi) ve simgesiz 56 dp satır listeleri (İçeriğim, Uygulama tercihleri).
/// Dil, tema, hesap, gizlilik, çıkış Ayarlar sayfasındadır. İlk yüklemede iskelet, çekerek yenile, aşamalı giriş.
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
  String? _clubs, _events, _saved, _posts;

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
      // Gönderi sayısı: mevcut kendi-gönderilerim ucunun toplamı (yeni uç yok); alınamazsa "–" kalır.
      try {
        final pr = await PostApi(widget.session).minePosts(size: 1);
        if (mounted) setState(() => _posts = '${pr.total ?? pr.items.length}');
      } catch (_) {}
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
    final uid = widget.session.userId;
    int? n(String? v) => int.tryParse(v ?? '');
    final extraCells = [
      StatCell(
          label: l.icerikStatPosts,
          value: n(_posts),
          onTap: () => _go(UserPostsPage(session: widget.session))),
    ];
    // Stitch v3: bölüm etiketi + 56 dp simgesiz satırlar, tek kutu; kulüp/etkinlik sayıları satırın sağında (mut).
    return BuStaggerScope(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.fromSTEB(20, top + 12, 20, kNavInset + 24),
        children: [
          BuStaggerItem(index: 0, child: _TitleRow(onEdit: () => _edit(p))),
          const SizedBox(height: 16),
          BuStaggerItem(index: 0, child: _ProfileHero(profile: p)),
          const SizedBox(height: 24),
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
                  label: l.profileMyPosts,
                  onTap: () => _go(UserPostsPage(session: widget.session)),
                ),
                ProfilRow(
                  label: l.profileSaved,
                  value: _saved,
                  onTap: () => _go(SavedNewsPage(session: widget.session)),
                ),
                ProfilRow(
                  label: l.profileMyClubs,
                  value: _clubs,
                  onTap: () => _go(MyClubsPage(session: widget.session)),
                ),
                ProfilRow(
                  label: l.profileMyEvents,
                  value: _events,
                  onTap: () => _go(MyEventsPage(session: widget.session)),
                ),
                ProfilRow(
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
              ProfilCard(children: [
                ProfilRow(
                  label: l.profileAcademic,
                  onTap: () => _go(AcademicHubPage(session: widget.session)),
                ),
                ProfilRow(
                  label: l.notifTitle,
                  onTap: () => _go(NotificationPrefsPage(session: widget.session)),
                ),
                ProfilRow(
                  label: l.settingsTitle,
                  onTap: () => _go(SettingsPage(
                    session: widget.session,
                    themeController: widget.themeController,
                    localeController: widget.localeController,
                  )),
                ),
                ProfilRow(
                  label: l.profil1Support,
                  onTap: () => _go(SupportPage(session: widget.session)),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Sayfa başlığı ("Profilim", 28/700) + sağda "Düzenle" soft çipi (36 dp görünür, 48 dp dokunma alanı).
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
                  .copyWith(fontSize: 28, fontWeight: FontWeight.w700, color: t.ink)),
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
            child: ConstrainedBox(
              key: const ValueKey('profile-edit'),
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: Center(
                widthFactor: 1,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bPill),
                  alignment: Alignment.center,
                  child: ExcludeSemantics(
                    child: Text(l.p18Edit,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(
                            fontSize: 13, color: t.onSoft, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ),
          )),
    ]);
  }
}

/// Profil üstü (Stitch v3): kartsız; ortada 88 dp avatar (halkasız), ad 22/700, "bölüm · sınıf" 15 mut, en çok 2 satır
/// biyografi 15 mut.
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
        : (year != null && year > 0 ? context.l10n.profileGradeYear('$year') : '');
    final facultyCanon = (profile['faculty'] as String?) ?? '';
    final dept = context.departmentName((profile['department'] as String?) ?? '', faculty: facultyCanon);
    final line1 = [dept, grade].where((s) => s.isNotEmpty).join(' · ');
    final bio = (profile['bio'] as String?) ?? '';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      BuAvatar(name: name, url: profile['avatarUrl'] as String?, size: 88),
      const SizedBox(height: 16),
      Text(name ?? '',
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: tx.headlineSmall!.copyWith(fontSize: 22, color: t.ink, fontWeight: FontWeight.w700)),
      if (line1.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(line1, textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(fontSize: 15, color: t.mut)),
      ],
      if (bio.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(bio,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tx.bodyLarge!.copyWith(fontSize: 15, height: 1.4, color: t.mut)),
      ],
    ]);
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
        const Column(children: [
          BuSkeleton.circle(88),
          SizedBox(height: 16),
          BuSkeleton.line(width: 160, height: 18),
          SizedBox(height: 10),
          BuSkeleton.line(width: 200),
        ]),
        const SizedBox(height: 24),
        const BuSkeleton(height: 88, radius: 16),
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
