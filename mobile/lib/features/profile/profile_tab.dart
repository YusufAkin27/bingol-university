import '../../core/analytics.dart';
import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart' show ImageSource;
import '../../core/session.dart';
import '../../core/theme_controller.dart';
import '../../widgets/bu.dart';
import '../follow/follow_requests_api.dart';
import '../follow/follow_summary.dart';
import '../posts/post_api.dart';
import '../posts/user_posts_page.dart';
import 'avatar_upload.dart';
import 'profile_content_tabs.dart';
import 'profile_inline_edit.dart';
import 'profile_menu_page.dart';
import 'verify_email_card.dart';

/// Profil sekmesi: "Profilim" + sağ üstte üç çizgi menüsü ([ProfileMenuPage]: tüm liste satırları orada), satır içi düzenlenen kimlik kartı
/// (88 dp avatar, ad, bölüm/sınıf çipleri, bio), tek kutuda 3 sütun sayaç (Takipçi · Takip · Gönderi) ve Gönderiler | Reels sekmeleri.
/// Altta satır listesi yoktur. Dil, tema, hesap, gizlilik (e-posta gösterme anahtarı dahil), çıkış Ayarlar sayfasındadır.
/// İlk yüklemede iskelet, çekerek yenile, aşamalı giriş.
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
  String? _posts;

  /// Bekleyen takip isteği sayısı (menü düğmesinde nokta rozeti yalnız > 0 iken görünür).
  int _followReq = 0;

  /// Çekerek yenilemede artar: içerik sekmeleri (Gönderiler | Reels) baştan yüklenir.
  int _tabsVersion = 0;

  /// Avatar değişimi (yükle/kaldır) sürerken true: çift dokunuş engellenir, avatar üstünde ilerleme halkası görünür.
  bool _avatarBusy = false;
  final _avatarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Profili yükler; veri varken (yenileme) iskelet gösterilmez, eski içerik kalır.
  Future<void> _load({bool refresh = false}) async {
    final gen = ++_gen;
    if (_profile == null) setState(() => _loading = true);
    try {
      final p = await widget.session.api.get('/users/me') as Map<String, dynamic>;
      if (!mounted || gen != _gen) return;
      widget.session.noteProfile(p); // e-posta doğrulanmamışsa üstte doğrulama kartı
      final av = p['avatarUrl'];
      widget.session.avatarUrl.value = av is String && av.isNotEmpty ? av : null; // alt gezinme Profil sekmesi avatarı
      setState(() {
        _profile = p;
        _error = null;
        _loading = false;
        if (refresh) _tabsVersion++;
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

  // Gönderi sayısı (sayaç şeridi) ve bekleyen takip isteği; alınamazsa gösterilmez, sayfa çalışmaya devam eder.
  Future<void> _loadStats() async {
    _loadFollowRequests();
    // Mevcut kendi-gönderilerim ucunun toplamı (yeni uç yok); alınamazsa "–" kalır.
    try {
      final pr = await PostApi(widget.session).minePosts(size: 1);
      if (mounted) setState(() => _posts = '${pr.total ?? pr.items.length}');
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
  }

  /// Bekleyen takip isteği sayısı; alınamazsa rozet gizli kalır.
  Future<void> _loadFollowRequests() async {
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

  Future<void> _openMenu() => _go(
      ProfileMenuPage(session: widget.session, themeController: widget.themeController, localeController: widget.localeController), 'profile_menu');

  // -------------------------------------------------------------------------------------------------------------
  // Hızlı profil fotoğrafı: kamera rozeti -> doğrudan galeri; uzun basma -> küçük menü (çek / kaldır)

  void _applyAvatar(String? url) {
    final p = _profile;
    if (p == null) return;
    widget.session.avatarUrl.value = url; // alt gezinme Profil sekmesi avatarı anında
    widget.session.api.invalidate('/users/me');
    setState(() => _profile = {...p, 'avatarUrl': url});
  }

  /// Kamera rozeti / avatara dokunma: ara menü yok, doğrudan sistem fotoğraf seçicisi -> kırpma ekranı -> yükleme.
  Future<void> _pickAvatar(ImageSource source) async {
    final p = _profile;
    if (p == null || _avatarBusy) return;
    final l = context.l10n;
    await _avatarJob(() async {
      final r = await pickCropUploadAvatar(context, widget.session, source, hooks: widget.avatarHooks);
      // Yalnız başarıdan sonra uygulanır: yükleme hatasında mevcut fotoğraf aynen kalır.
      return r == null ? null : () => r.url != null ? _applyAvatar(r.url) : _load();
    }, okMessage: l.avatarUpdated);
  }

  Future<void> _removeAvatar() async {
    final l = context.l10n;
    await _avatarJob(() async {
      await removeAvatar(widget.session);
      return () => _applyAvatar(null);
    }, okMessage: l.avatarRemoved);
  }

  /// Uzun basma: küçük menü; yalnız "Fotoğraf çek" ve (fotoğraf varsa) "Fotoğrafı kaldır".
  Future<void> _avatarMenu() async {
    final p = _profile;
    if (p == null || _avatarBusy) return;
    final l = context.l10n;
    final t = context.bu;
    final has = (p['avatarUrl'] as String?)?.isNotEmpty ?? false;
    final box = _avatarKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final pos = RelativeRect.fromRect(
        Rect.fromPoints(box.localToGlobal(Offset(0, box.size.height), ancestor: overlay), box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay)),
        Offset.zero & overlay.size);
    PopupMenuItem<int> item(Key k, int v, IconData icon, String label, {bool danger = false}) => PopupMenuItem<int>(
          key: k,
          value: v,
          height: 48,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: danger ? t.danger : t.ink),
            const SizedBox(width: 12),
            Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: danger ? t.danger : t.ink, fontWeight: BuType.emphasisWeight)),
          ]),
        );
    final v = await showMenu<int>(
      context: context,
      position: pos,
      color: t.sf,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.md), side: BorderSide(color: t.bd)),
      items: [
        item(const ValueKey('avatarMenuCamera'), 1, BuIcons.camera, l.p04SrcCamera),
        if (has) item(const ValueKey('avatarMenuRemove'), 2, BuIcons.trash2, l.p04SrcRemove, danger: true),
      ],
    );
    if (!mounted) return;
    if (v == 1) await _pickAvatar(ImageSource.camera);
    if (v == 2) await _removeAvatar();
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

  /// Satır içi düzenleme: alanlar profil yanıtına birleşir (iyimser güncelleme ve hata halinde geri alma).
  void _patchProfile(Map<String, dynamic> patch) {
    if (!mounted) return;
    final p = _profile;
    if (p == null) return;
    setState(() => _profile = {...p, ...patch});
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
          Analytics.instance.action('pull_refresh');
          buHaptic(BuHaptic.selection);
          return _load(refresh: true);
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
      StatCell(label: l.icerikStatPosts, value: n(p['postCount']?.toString()) ?? n(_posts), onTap: () => _go(UserPostsPage(session: widget.session), 'user_posts')),
    ];
    return BuStaggerScope(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.fromSTEB(20, top + 12, 20, kNavInset + 24),
        children: [
          BuStaggerItem(index: 0, child: _TitleRow(onMenu: _openMenu, badge: _followReq > 0)),
          const SizedBox(height: 16),
          VerifyEmailCard(session: widget.session),
          BuStaggerItem(
            index: 0,
            child: InlineProfileHero(
              session: widget.session,
              profile: p,
              onPatch: _patchProfile,
              avatar: _TappableAvatar(
                  key: _avatarKey, name: p['displayName'] as String?, url: p['avatarUrl'] as String?, busy: _avatarBusy,
                  onTap: () => _pickAvatar(ImageSource.gallery), onLongPress: _avatarMenu),
            ),
          ),
          const SizedBox(height: 16),
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
          // Gönderiler | Reels (ilk 9 kare, "Daha fazla göster"): Instagram profili gibi kimlik ve sayaç şeridinin altında.
          if (uid != null)
            BuStaggerItem(
              index: 2,
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: ProfileContentTabs(
                  key: ValueKey('profile-tabs-$_tabsVersion'),
                  session: widget.session,
                  userId: uid,
                  name: widget.session.displayName,
                  gutter: 0,
                  pageSize: 9,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Üst satır (başlık metni görünmez, yalnız anlamsal etiket) + sağ üstte üç çizgi menü düğmesi (tüm liste satırları [ProfileMenuPage]'de).
/// Düzenleme düğmesi yok: alanlar kimlik kartında yerinde düzenlenir. [badge]: bekleyen takip isteği noktası.
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.onMenu, this.badge = false});

  final VoidCallback onMenu;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(children: [
      Expanded(
        child: Semantics(header: true, label: l.p18ProfileTitle, child: const SizedBox(height: 48)),
      ),
      const SizedBox(width: 12),
      BuIconButton(key: const ValueKey('profile-menu-button'), icon: BuIcons.menu, tooltip: l.profileMenuTitle, badge: badge, onTap: onMenu),
    ]);
  }
}

/// Dokunulabilir 88 dp avatar: dokununca fotoğraf alt sayfası; sağ altta ince (gölgesiz) kamera rozeti; yüklenirken ince ilerleme
/// halkası; fotoğraf değişince yumuşak çapraz geçiş.
class _TappableAvatar extends StatelessWidget {
  const _TappableAvatar({super.key, required this.name, required this.url, required this.busy, required this.onTap, required this.onLongPress});

  final String? name;
  final String? url;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
      onLongPress: busy ? null : onLongPress,
      child: BuPressable(
        key: const ValueKey('profile-avatar'),
        onTap: busy ? null : onTap,
        onLongPress: busy ? null : onLongPress,
        haptic: BuHaptic.selection,
        child: SizedBox(
          width: _size,
          height: _size,
          child: Stack(clipBehavior: Clip.none, children: [
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
                    child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: t.onMedia))),
                  ),
                ),
              ),
            BuAvatarBadge(avatarSize: _size, onTap: busy ? null : onTap, tooltip: l.profileChangePhotoSemantic),
          ]),
        ),
      ),
    );
  }
}

/// İlk yükleme iskeleti: profil kartı + sayaç şeridi + sekme çubuğu ve ızgara (gerçek düzenle aynı ölçüler, sayfa zıplamaz).
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
    const skeleton = BuSkeletonScope(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          BuSkeleton.circle(88),
          SizedBox(height: 16),
          BuSkeleton.line(width: 160, height: 18),
          SizedBox(height: 10),
          BuSkeleton.line(width: 200),
        ]),
        SizedBox(height: 24),
        BuSkeleton(height: 88, radius: 16),
        SizedBox(height: 24),
        BuSkeleton(height: 40, radius: 12),
        SizedBox(height: 12),
        BuSkeletonList(variant: BuSkeletonVariant.grid, itemCount: 6, shrinkWrap: true, padding: EdgeInsets.zero),
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
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w400, color: cs.onErrorContainer)),
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
