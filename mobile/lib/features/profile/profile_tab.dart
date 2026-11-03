import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart' show AcademicLabels, gradeLabelL;
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart' show ImageSource;
import '../../core/session.dart';
import '../../core/theme_controller.dart';
import '../../widgets/bu.dart';
import '../academic/academic_hub_page.dart';
import '../follow/follow_requests_api.dart';
import '../follow/follow_requests_page.dart';
import '../follow/follow_suggestions.dart';
import '../follow/follow_summary.dart';
import '../posts/post_api.dart';
import '../posts/user_posts_page.dart';
import '../support/support_page.dart';
import '../media_crop/media_crop.dart' show PhotoSource, showPhotoSourceSheet;
import 'avatar_upload.dart';
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
  const ProfileTab({super.key, required this.session, required this.themeController, this.localeController, this.avatarHooks = const AvatarHooks()});

  final Session session;
  final ThemeController themeController;

  /// Verilmezse uygulama genelindeki örnek kullanılır.
  final LocaleController? localeController;

  /// Yalnız testler: avatar seç/düzenle/yükle/indir kancaları.
  final AvatarHooks avatarHooks;

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

  /// Bekleyen takip isteği sayısı (satır yalnız > 0 iken görünür).
  int _followReq = 0;

  /// Avatar değişimi (yükle/kaldır) sürerken true: çift dokunuş engellenir, avatar üstünde ilerleme halkası görünür.
  bool _avatarBusy = false;

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
      final p = await widget.session.api.get('/users/me') as Map<String, dynamic>;
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
      final r = await widget.session.api.get('/me/summary') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _clubs = '${(r['communities'] as num?)?.toInt() ?? 0}';
        _events = '${(r['events'] as num?)?.toInt() ?? 0}';
        _saved = '${(r['bookmarks'] as num?)?.toInt() ?? 0}';
      });
      _loadFollowRequests();
      // Gönderi sayısı: mevcut kendi-gönderilerim ucunun toplamı (yeni uç yok); alınamazsa "–" kalır.
      try {
        final pr = await PostApi(widget.session).minePosts(size: 1);
        if (mounted) setState(() => _posts = '${pr.total ?? pr.items.length}');
      } catch (_) {}
    } catch (_) {
      // Sayılar alınamazsa gösterilmez; sayfa çalışmaya devam eder.
    }
  }

  /// Bekleyen takip isteği sayısı; alınamazsa satır gizli kalır.
  Future<void> _loadFollowRequests() async {
    try {
      final n = await FollowRequestsApi(widget.session).count();
      if (mounted && n != null && n != _followReq) setState(() => _followReq = n);
    } catch (_) {}
  }

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _loadStats();
  }

  // -------------------------------------------------------------------------------------------------------------
  // Hızlı profil fotoğrafı: avatara dokun -> alt sayfa (çek / seç / düzenle / kaldır)

  void _applyAvatar(String? url) {
    final p = _profile;
    if (p == null) return;
    widget.session.avatarUrl.value = url; // alt gezinme Profil sekmesi avatarı anında
    widget.session.api.invalidate('/users/me');
    setState(() => _profile = {...p, 'avatarUrl': url});
  }

  Future<void> _avatarTap() async {
    final p = _profile;
    if (p == null || _avatarBusy) return;
    final l = context.l10n;
    final cur = p['avatarUrl'] as String?;
    final has = cur != null && cur.isNotEmpty;
    final choice = await showPhotoSourceSheet(context, title: l.avatarSheetTitle, cameraFirst: true, removable: has, editable: has);
    if (choice == null || !mounted || _avatarBusy) return;
    final hooks = widget.avatarHooks;
    switch (choice) {
      case PhotoSource.camera:
      case PhotoSource.gallery:
        await _avatarJob(() async {
          final r = await uploadAvatarFrom(context, widget.session, choice == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
              previewName: (p['displayName'] as String?) ?? '', cropPhoto: hooks.cropPhoto, images: hooks.images, uploader: hooks.uploader);
          return r == null ? null : () => r.url != null ? _applyAvatar(r.url) : _load();
        }, okMessage: l.avatarUpdated);
      case PhotoSource.edit:
        await _avatarJob(() async {
          final r = await editExistingAvatar(context, widget.session, cur!, hooks: hooks);
          return r == null ? null : () => r.url != null ? _applyAvatar(r.url) : _load();
        }, okMessage: l.avatarUpdated);
      case PhotoSource.remove:
        final ok = await BuConfirmSheet.show(context,
            title: l.avatarRemoveTitle, message: l.avatarRemoveBody, confirmLabel: l.avatarRemoveConfirm, destructive: true);
        if (!ok || !mounted) return;
        await _avatarJob(() async {
          await removeAvatar(widget.session);
          return () => _applyAvatar(null);
        }, okMessage: l.avatarRemoved);
    }
  }

  /// [job] başarıyla bir "uygula" işlevi döndürürse uygulanır (null = kullanıcı vazgeçti); hata toast ile gösterilir.
  Future<void> _avatarJob(Future<VoidCallback?> Function() job, {required String okMessage}) async {
    if (_avatarBusy) return;
    setState(() => _avatarBusy = true);
    try {
      final apply = await job();
      if (!mounted) return;
      if (apply != null) {
        apply();
        BuToast.show(context, okMessage, kind: BuToastKind.success);
      }
    } catch (e) {
      if (mounted) BuToast.show(context, avatarUploadErrorText(context, e), kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> p) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditProfilePage(session: widget.session, profile: p)),
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
        child: KeyedSubtree(key: ValueKey(p != null ? 'ready' : (_loading ? 'load' : 'err')), child: body),
      ),
    );
  }

  Widget _content(Map<String, dynamic> p, double top) {
    final l = context.l10n;
    final uid = widget.session.userId;
    int? n(String? v) => int.tryParse(v ?? '');
    final extraCells = [
      StatCell(label: l.icerikStatPosts, value: n(_posts), onTap: () => _go(UserPostsPage(session: widget.session))),
    ];
    // Stitch v3: bölüm etiketi + 56 dp simgesiz satırlar, tek kutu; kulüp/etkinlik sayıları satırın sağında (mut).
    return BuStaggerScope(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.fromSTEB(20, top + 12, 20, kNavInset + 24),
        children: [
          BuStaggerItem(index: 0, child: _TitleRow(onEdit: () => _edit(p))),
          const SizedBox(height: 16),
          BuStaggerItem(index: 0, child: _ProfileHero(profile: p, busy: _avatarBusy, onAvatarTap: _avatarTap)),
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
                // Takip istekleri (yalnız bekleyen varken): sayı satırın sağında metin, rozet yok.
                if (_followReq > 0)
                  ProfilRow(
                    key: const ValueKey('profile-follow-requests'),
                    icon: BuIcons.userPlus,
                    label: l.frqReqTitle,
                    value: '$_followReq',
                    onTap: () => _go(FollowRequestsPage(session: widget.session)),
                  ),
                ProfilRow(
                  icon: BuIcons.image,
                  label: l.profileMyPosts,
                  onTap: () => _go(UserPostsPage(session: widget.session)),
                ),
                ProfilRow(
                  icon: BuIcons.bookmark,
                  label: l.profileSaved,
                  value: _saved,
                  onTap: () => _go(SavedNewsPage(session: widget.session)),
                ),
                ProfilRow(
                  icon: BuIcons.users,
                  label: l.profileMyClubs,
                  value: _clubs,
                  onTap: () => _go(MyClubsPage(session: widget.session)),
                ),
                ProfilRow(
                  icon: BuIcons.calendar,
                  label: l.profileMyEvents,
                  value: _events,
                  onTap: () => _go(MyEventsPage(session: widget.session)),
                ),
                ProfilRow(
                  icon: BuIcons.userPlus,
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
                  icon: BuIcons.graduationCap,
                  label: l.profileAcademic,
                  onTap: () => _go(AcademicHubPage(session: widget.session)),
                ),
                ProfilRow(
                  icon: BuIcons.bell,
                  label: l.notifTitle,
                  onTap: () => _go(NotificationPrefsPage(session: widget.session)),
                ),
                ProfilRow(
                  icon: BuIcons.settings,
                  label: l.settingsTitle,
                  onTap: () => _go(SettingsPage(
                    session: widget.session,
                    themeController: widget.themeController,
                    localeController: widget.localeController,
                  )),
                ),
                ProfilRow(
                  icon: BuIcons.headset,
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
          child: BuFeatureTitle(title: l.p18ProfileTitle, icon: BuIcons.user),
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
                        maxLines: 1, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 13, color: t.onSoft, fontWeight: FontWeight.w500)),
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
  const _ProfileHero({required this.profile, required this.busy, required this.onAvatarTap});

  final Map<String, dynamic> profile;
  final bool busy;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final name = profile['displayName'] as String?;
    final year = (profile['classYear'] as num?)?.toInt();
    final g = profile['grade'];
    final grade = (g is String && g.isNotEmpty) ? gradeLabelL(context.l10n, g) : (year != null && year > 0 ? context.l10n.profileGradeYear('$year') : '');
    final facultyCanon = (profile['faculty'] as String?) ?? '';
    final dept = context.departmentName((profile['department'] as String?) ?? '', faculty: facultyCanon);
    final line1 = [dept, grade].where((s) => s.isNotEmpty).join(' · ');
    final bio = (profile['bio'] as String?) ?? '';
    return BuCard(
        radius: 24,
        style: BuCardStyle.elevated,
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _TappableAvatar(name: name, url: profile['avatarUrl'] as String?, busy: busy, onTap: onAvatarTap),
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
        ]));
  }
}

/// Dokunulabilir 88 dp avatar: dokununca fotoğraf alt sayfası; sağ altta ince (gölgesiz) kamera rozeti; yüklenirken ince ilerleme
/// halkası; fotoğraf değişince yumuşak çapraz geçiş.
class _TappableAvatar extends StatelessWidget {
  const _TappableAvatar({required this.name, required this.url, required this.busy, required this.onTap});

  final String? name;
  final String? url;
  final bool busy;
  final VoidCallback onTap;

  static const _size = 88.0;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Semantics(
      container: true,
      button: true,
      enabled: !busy,
      label: l.profileChangePhotoSemantic,
      excludeSemantics: true,
      onTap: busy ? null : onTap,
      child: BuPressable(
        key: const ValueKey('profile-avatar'),
        onTap: busy ? null : onTap,
        haptic: BuHaptic.selection,
        child: SizedBox(
          width: _size,
          height: _size,
          child: Stack(children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: BuMotion.of(context, BuMotion.medium),
                child: KeyedSubtree(key: ValueKey(url ?? 'none'), child: BuAvatar(name: name, url: url, size: _size)),
              ),
            ),
            if (busy)
              Positioned.fill(
                child: ClipOval(
                  child: ColoredBox(
                    key: const ValueKey('profile-avatar-busy'),
                    color: t.scrim.withValues(alpha: .45),
                    child: Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2.5, color: t.onMedia))),
                  ),
                ),
              ),
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: ExcludeSemantics(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: t.sf3, shape: BoxShape.circle, border: Border.all(color: t.bg, width: 2)),
                  child: Icon(BuIcons.camera, size: 14, color: t.ink),
                ),
              ),
            ),
          ]),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (error != null) ...[
            Container(
              key: const ValueKey('profile-error'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BuRadius.bMd),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: t.danger.withValues(alpha: .14), shape: BoxShape.circle),
                  child: Icon(BuIcons.wifiOff, size: 20, color: t.danger),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(l.p18ProfileLoadFailed,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: cs.onErrorContainer)),
                    Text(errorText(error!), maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: cs.onErrorContainer)),
                  ]),
                ),
                const SizedBox(width: 10),
                BuButton(label: l.profileRetry, icon: BuIcons.refreshCw, compact: true, onPressed: onRetry),
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
