// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart' show AcademicLabels, gradeLabelL;
import '../../core/api.dart' show ApiError;
import '../../core/cache/image_disk_cache.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import '../../widgets/report_sheet.dart';
import '../academic/akad_widgets.dart';
import '../chat/chat_detail_page.dart';
import '../follow/follow_button.dart';
import '../follow/follow_list_page.dart';
import '../follow/locked_profile_block.dart';
import '../posts/social_api.dart';
import '../posts/social_models.dart';
import '../forum/presentation/widgets/forum_profile_section.dart';
import 'profile_content_tabs.dart';

/// Kullanıcı profili sayfasını açan ortak giriş. [fromConversationId], çağıranın zaten açık olan
/// sohbetidir; "Mesaj" aynı birebir sohbete çıkarsa yeni sayfa yığılmaz, geri dönülür.
Future<void> openUserProfile(
  BuildContext context,
  Session session, {
  required int userId,
  String? name,
  String? avatarUrl,
  int? fromConversationId,
}) =>
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(settings: const RouteSettings(name: 'user_profile'), 
        builder: (_) => UserProfilePage(
          session: session,
          userId: userId,
          initialName: name,
          initialAvatarUrl: avatarUrl,
          fromConversationId: fromConversationId,
        ),
      ),
    );

/// Başka bir kullanıcının (ya da kendi) profili (Stitch 47): avatar + çevrimiçi/son görülme, sayaçlar, takip/mesaj,
/// "Hakkında" bilgileri (gizlilik ayarına bağlı, "Gizli"), gönderiler; "⋯" menüsü ile şikâyet/engelleme.
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    required this.session,
    required this.userId,
    this.initialName,
    this.initialAvatarUrl,
    this.fromConversationId,
  });

  final Session session;
  final int userId;
  final String? initialName;
  final String? initialAvatarUrl;
  final int? fromConversationId;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? _p;
  Object? _error;
  Map<String, dynamic>? _presence;
  bool _blocked = false;
  bool _busyMsg = false;
  bool _busyBlock = false;
  FollowStats? _stats;
  String? _postCount;

  /// Profil yanıtındaki sayaçlar (sunucu `postCount`/`reelCount` verirse; yoksa null).
  int? _profileCount(String key) => (_p?[key] as num?)?.toInt();

  bool get _self => widget.userId == widget.session.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _loadStats() async {
    try {
      final st = await SocialApi(widget.session).followStats(widget.userId);
      if (mounted) setState(() => _stats = st);
    } catch (_) {}
  }

  /// Gizli hesap mı (profil yanıtı `isPrivate`; takip yanıtlarından da gelir).
  bool get _isPrivate => _stats?.isPrivate ?? (_p?['isPrivate'] == true);

  /// Gizli hesap ve ben takipçi/kendisi değilim: gönderiler ve listeler kilitli (`locked`).
  bool get _isLocked => !_self && (_stats?.locked ?? (_p?['locked'] == true));

  /// [FollowStateButton] geri çağrısı: durum tek kaynaktır; sayaç ve kilit ondan türetilir.
  /// İyimser adımda `r == null`; sunucu yanıtında kesin sayı gelir. Kilit açılınca (gizli hesap isteği kabul etmiş)
  /// profil yeniden yüklenir ki gönderi ızgarası gelsin.
  void _onFollowState(FollowState st, FollowResult? r) {
    final s = _stats ?? const FollowStats();
    final delta = (st == FollowState.following ? 1 : 0) - (s.followState == FollowState.following ? 1 : 0);
    final wasLocked = _isLocked;
    final priv = _isPrivate;
    setState(() {
      _stats = FollowStats(
        followers: (r?.followerCount ?? (s.followers + delta)).clamp(0, 1 << 30),
        following: s.following,
        followState: st,
        followsMe: s.followsMe,
        isPrivate: priv,
        locked: priv && st != FollowState.following,
      );
    });
    if (wasLocked && st == FollowState.following && r != null) _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final api = widget.session.api;
    try {
      final r = await api.get(_self ? '/users/me' : '/users/${widget.userId}');
      if (!mounted) return;
      final m = Map<String, dynamic>.from(r as Map);
      // Başkasının profil yanıtı takip alanlarını taşır: ikinci istek gerekmez.
      // Kilitli (gizli) profilde sayaçlar null gelir ama `followState`/`locked` vardır: yine ikinci istek gerekmez.
      final hasStats = !_self && (m['followerCount'] != null || m['followState'] is String);
      setState(() {
        _p = m;
        if (hasStats) _stats = FollowStats.fromJson(m);
      });
      if (!hasStats) _loadStats();
    } catch (e) {
      if (mounted) setState(() => _error = e);
      return;
    }
    if (_self) return;
    // Çevrimiçi durumu ve engel durumu isteğe bağlıdır; hata olursa sessizce atlanır.
    try {
      final r = await api.get('/users/${widget.userId}/presence');
      if (mounted && r is Map) setState(() => _presence = Map<String, dynamic>.from(r));
    } catch (_) {
      if (mounted && _presence != null) setState(() => _presence = null);
    }
    // Profil yaniti `blockedByMe` tasiyorsa onu kullan; yoksa engel listesini sayfalayarak (en cok 5 sayfa) tara.
    final byMe = _p?['blockedByMe'];
    if (byMe is bool) {
      if (mounted && byMe != _blocked) setState(() => _blocked = byMe);
      return;
    }
    try {
      String? cursor;
      var found = false;
      for (var page = 0; page < 5 && !found; page++) {
        final q = 'limit=50${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}';
        final r = await api.getResponse('/users/me/blocks?$q');
        final body = r.body;
        final list = body is List ? body : (body is Map ? (body['items'] as List? ?? const []) : const []);
        found = list.any((u) => u is Map && (u['id'] as num?)?.toInt() == widget.userId);
        final next = r.headers['x-next-cursor'];
        cursor = (next == null || next.isEmpty) ? null : next;
        if (cursor == null) break;
      }
      if (mounted && found != _blocked) setState(() => _blocked = found);
    } catch (_) {}
  }

  Map<String, String>? get _headers {
    final tok = widget.session.api.tokens?.access;
    return tok == null ? null : {'Authorization': 'Bearer $tok'};
  }

  Map<String, String>? _headersFor(String? url) => (url != null && url.startsWith('/api/')) ? _headers : null;

  String get _name => ((_p?['displayName'] as String?) ?? widget.initialName ?? context.l10n.profileUserDefault);
  String? get _avatar => (_p?['avatarUrl'] as String?) ?? widget.initialAvatarUrl;

  String _s(String key) => ((_p?[key]) ?? '').toString().trim();

  String _gradeText() {
    final g = _s('grade');
    if (g.isNotEmpty) return gradeLabelL(context.l10n, g);
    final y = (_p?['classYear'] as num?)?.toInt();
    return (y != null && y > 0) ? context.l10n.profileGradeYear('$y') : '';
  }

  Future<void> _message() async {
    if (_busyMsg) return;
    setState(() => _busyMsg = true);
    try {
      final r = await widget.session.api.post('/conversations', {'userId': widget.userId});
      if (!mounted) return;
      setState(() => _busyMsg = false);
      final conv = Map<String, dynamic>.from(r as Map);
      final cid = (conv['id'] as num?)?.toInt();
      if (widget.fromConversationId != null && cid == widget.fromConversationId) {
        Navigator.pop(context);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(settings: const RouteSettings(name: 'chat_detail'), builder: (_) => ChatDetailPage(session: widget.session, conversation: conv)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyMsg = false);
      _toast(errorText(e), kind: BuToastKind.error);
    }
  }

  Future<void> _toggleBlock() async {
    if (_busyBlock) return;
    final unblock = _blocked;
    if (!unblock) {
      final ok = await ReportSheet.confirmBlock(context);
      if (!ok || !mounted) return;
    }
    setState(() => _busyBlock = true);
    try {
      if (unblock) {
        await widget.session.api.delete('/users/${widget.userId}/block');
      } else {
        await widget.session.api.post('/users/${widget.userId}/block');
      }
      if (!mounted) return;
      setState(() {
        _blocked = !unblock;
        _busyBlock = false;
      });
      _toast(unblock ? context.l10n.profileUnblocked : context.l10n.profileBlocked, kind: BuToastKind.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyBlock = false);
      _toast(errorText(e), kind: BuToastKind.error);
    }
  }

  Future<void> _report() => ReportSheet.show(context, widget.session,
      targetType: 'USER', targetId: widget.userId, title: context.l10n.profileReportUser);

  void _toast(String m, {BuToastKind kind = BuToastKind.info}) {
    if (!mounted) return;
    BuToast.show(context, m, kind: kind);
  }

  void _viewAvatar() {
    final url = fileUrl(_avatar);
    if (url == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(settings: const RouteSettings(name: 'avatar_viewer'), 
        fullscreenDialog: true,
        builder: (_) => _AvatarViewer(url: url, headers: _headersFor(_avatar), title: _name),
      ),
    );
  }

  String? _presenceText() {
    final p = _presence;
    if (p == null) return null;
    final l10n = context.l10n;
    if (p['online'] == true) return l10n.profileOnline;
    // "Son görülme" gösterilmez (kullanıcı kararı 2026-11-07); yalnız "Çevrimiçi".
    return null;
  }

  /// "⋯" menüsü: alt sayfa (engelle / engeli kaldır, şikâyet).
  Future<void> _openMenu() async {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    await BuSheet.show<void>(
      context,
      builder: (c) {
        Widget item(Key key, IconData icon, String label, VoidCallback onTap, {bool danger = false}) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: t.sf2,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: key,
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(c);
                    onTap();
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(children: [
                        AkadIconTile(icon: icon, bg: t.sf, fg: danger ? t.danger : t.ink, size: 40, radius: 12, iconSize: 20),
                        const SizedBox(width: 14),
                        Expanded(child: Text(label, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w400, color: danger ? t.danger : t.ink))),
                        Icon(buDirIcon(context, BuIcons.chevronRight), size: 18, color: t.mut),
                      ]),
                    ),
                  ),
                ),
              ),
            );
        return Column(children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Semantics(header: true, child: Text(l.icerikUserMenu, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w400, color: t.ink))),
                  Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.mut)),
                ]),
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: l.commonCancel,
                style: IconButton.styleFrom(backgroundColor: t.sf2),
                icon: Icon(BuIcons.x, size: 18, color: t.ink),
                onPressed: () => Navigator.pop(c),
              ),
            ]),
          ),
          item(const ValueKey('profile-menu-block'), _blocked ? BuIcons.lockOpen : BuIcons.ban, _blocked ? l.profileUnblock : l.profileBlock, _toggleBlock,
              danger: true),
          item(const ValueKey('profile-menu-report'), BuIcons.flag, l.profileReportUser, _report),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final showMenu = !_self && (_p != null || _error == null);
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        DecoratedBox(
          decoration: BoxDecoration(color: t.bg),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(4, MediaQuery.paddingOf(context).top, 8, 0),
            child: SizedBox(
              height: 56,
              child: Row(children: [
                IconButton(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  tooltip: l.commonBack,
                  icon: Icon(buDirIcon(context, BuIcons.chevronLeft), size: 26, color: t.ink),
                  onPressed: () => Navigator.maybePop(context),
                ),
                // Stitch v3: üstte başlık yok (geri + sağda "...").
                const Spacer(),
                if (showMenu)
                  IconButton(
                    key: const ValueKey('profile-more'),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    tooltip: l.icerikUserMenu,
                    icon: Icon(BuIcons.ellipsis, size: 22, color: t.ink),
                    onPressed: _p == null ? null : _openMenu,
                  ),
              ]),
            ),
          ),
        ),
        Expanded(child: _body(t)),
      ]),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) => DecoratedBox(
        decoration: BoxDecoration(color: context.bu.sf, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.bu.bd)),
        child: Padding(padding: padding, child: child),
      );

  Widget _body(BuTokens t) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    if (_error != null && _p == null) {
      final nf = _error is ApiError && (_error as ApiError).status == 404;
      return nf
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(BuIcons.userX, size: 36, color: t.mut),
                  const SizedBox(height: 12),
                  Text(l.profileNotFound, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
                  const SizedBox(height: 16),
                  BuButton(label: l.commonBack, kind: BuButtonKind.soft, compact: true, onPressed: () => Navigator.maybePop(context)),
                ]),
              ),
            )
          : ErrorView(error: _error!, onRetry: _load);
    }
    if (_p == null) return _skeleton(t);

    final dept = context.departmentName(_s('department'), faculty: _s('faculty'));
    final presence = _self ? null : _presenceText();
    final online = _presence?['online'] == true;
    final bio = _s('bio');
    final faculty = context.facultyName(_s('faculty'));
    final grade = _gradeText();
    final email = _s('email');
    final s = _stats;
    final locked = _isLocked;
    // Gizli hesapta SAYILAR herkese açıktır (liste ve gönderiler kapalı). Eski sunucu sayıyı null döndürürse '–'.
    final stat = _blocked ? '—' : null;
    final hasCounts = _p?['followerCount'] != null;
    final lockedNoCount = locked && !hasCounts;
    final avatarHidden = _self && _p?['avatarHidden'] == true;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 32),
      children: [
        if (_blocked && !_self) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.bd)),
            child: Row(children: [
              Icon(BuIcons.shieldBan, size: 20, color: t.danger),
              const SizedBox(width: 12),
              Expanded(child: Text(l.profileBlocked, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w400, color: t.ink))),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        // Kart YOK: avatar, büyük sade ad, sayaç satırı ve eylemler doğrudan sayfa zemininde.
        Column(children: [
            GestureDetector(
              key: const Key('profile-avatar'),
              onTap: _viewAvatar,
              child: Stack(clipBehavior: Clip.none, children: [
                _avatarFace(t),
                if (_blocked)
                  PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: t.danger, shape: BoxShape.circle, border: Border.all(color: t.bg, width: 3)),
                      child: Icon(BuIcons.ban, size: 16, color: t.onMedia),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(_name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.displaySmall!.copyWith(fontWeight: BuType.emphasisWeight, color: t.ink)),
            ),
            if (_blocked && dept.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(dept, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.mut)),
            ],
            if (presence != null && !_blocked) ...[
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                // Stitch v3: "Çevrimiçi" 13 mut + 8 dp yeşil nokta; çevrimdışıysa "Son görülme ..." (saat simgesi).
                if (online)
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: t.ok, shape: BoxShape.circle))
                else
                  Icon(BuIcons.clock, size: 14, color: t.mut),
                const SizedBox(width: 8),
                Flexible(child: Text(presence, style: tx.labelLarge!.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: t.mut))),
              ]),
            ],
            if (!_self && !_blocked && s != null && s.followsMe) ...[
              const SizedBox(height: 8),
              AkadPill(s.followedByMe ? l.profilyardFollowMutual : l.profilyardFollowsYou,
                  key: const ValueKey('followRelationPill'),
                  bg: t.sf2,
                  fg: t.ink,
                  icon: s.followedByMe ? BuIcons.arrowLeftRight : BuIcons.userPlus),
            ],
            const SizedBox(height: 16),
            // Sayaçlar: kart içinde kutu yok; yalnız ince çizgilerle ayrılmış tek satır.
            Divider(height: 1, thickness: 1, color: t.bd),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _stat(t, stat ?? (_profileCount('postCount') != null ? '${_profileCount('postCount')}' : _postCount) ?? (locked ? '–' : '0'), l.icerikStatPosts)),
                VerticalDivider(width: 1, thickness: 1, color: t.bd),
                Expanded(child: _stat(t, stat ?? (lockedNoCount ? '–' : (s == null ? '0' : '${s.followers}')), l.icerikStatFollowers, followers: _blocked || lockedNoCount ? null : true)),
                VerticalDivider(width: 1, thickness: 1, color: t.bd),
                Expanded(child: _stat(t, stat ?? (lockedNoCount ? '–' : (s == null ? '0' : '${s.following}')), l.icerikStatFollowing, followers: _blocked || lockedNoCount ? null : false)),
              ]),
            ),
            Divider(height: 1, thickness: 1, color: t.bd),
            if (!_self) ...[
              const SizedBox(height: 14),
              _actions(t, s),
            ],
          ]),
        if (avatarHidden) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.bd)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(color: t.sf3, shape: BoxShape.circle), child: Icon(BuIcons.info, size: 18, color: t.ink)),
              const SizedBox(width: 12),
              Expanded(child: Text(l.p20AvatarHidden, style: tx.bodyMedium!.copyWith(color: t.ink))),
            ]),
          ),
        ],
        if (!_blocked) ...[
          const SizedBox(height: 14),
          // Kilitli: Hakkında + kilit bilgisi. Açık: içerik (Gönderiler | Reels) ilk ekranda görünsün diye önce gelir;
          // popülerlik ve "Hakkında" altta (eskiden iki kart ızgarayı ilk ekranın dışına itiyordu).
          if (locked) ...[
            _infoCard(t, bio: bio, faculty: faculty, dept: dept, grade: grade, email: email),
            LockedProfileBlock(requested: _stats?.followState == FollowState.requested),
          ] else ...[
            ProfileContentTabs(
              key: ValueKey('profile-tabs-${widget.userId}'),
              session: widget.session,
              userId: widget.userId,
              name: _name,
              gutter: 0,
              pageSize: 9,
              onPostsLoaded: (n, more) {
                if (mounted) setState(() => _postCount = '$n${more ? '+' : ''}');
              },
            ),
            // Kampüs Forum: yalnız herkese açık konu/yorum sayıları (sıfırsa ya da alınamazsa hiç çizilmez).
            if (!_self) ForumProfileSection(key: ValueKey('forum-section-${widget.userId}'), session: widget.session, userId: widget.userId, name: _name),
            const SizedBox(height: 14),
            _infoCard(t, bio: bio, faculty: faculty, dept: dept, grade: grade, email: email),
          ],
        ],
      ],
    );
  }

  /// 96 dp avatar: fotoğraf varsa foto, yoksa varsayılan profil görseli (Stitch v3: durum noktası avatarda değil, metinde).
  Widget _avatarFace(BuTokens t) =>
      BuAvatar(name: _name, url: _avatar, size: 96, headers: _headersFor(_avatar));

  Widget _actions(BuTokens t, FollowStats? s) {
    final l = context.l10n;
    // Kendi profilinde eylem yok: alanlar Profilim sekmesinde yerinde düzenlenir.
    if (_self) return const SizedBox.shrink();
    if (_blocked) {
      return Row(children: [
        Expanded(child: BuButton(label: l.profileUnblock, icon: BuIcons.lockOpen, kind: BuButtonKind.outline, busy: _busyBlock, onPressed: _toggleBlock)),
        const SizedBox(width: 10),
        IconButton(
          constraints: const BoxConstraints(minWidth: 54, minHeight: BuSize.button),
          tooltip: l.icerikUserMenu,
          style: IconButton.styleFrom(backgroundColor: t.sf2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          icon: Icon(BuIcons.ellipsis, size: 20, color: t.ink),
          onPressed: _openMenu,
        ),
      ]);
    }
    return Row(children: [
      Expanded(
        child: FollowStateButton(
          session: widget.session,
          userId: widget.userId,
          state: s?.followState ?? FollowState.none,
          isPrivate: _isPrivate,
          look: FollowLook.block,
          compact: false,
          onState: _onFollowState,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: BuButton(
          key: const ValueKey('profile-message'),
          label: l.icerikMessageSend,
          icon: BuIcons.messageSquare,
          kind: BuButtonKind.outline,
          busy: _busyMsg,
          onPressed: _message,
        ),
      ),
    ]);
  }

  Widget _stat(BuTokens t, String n, String label, {bool? followers}) {
    final tx = Theme.of(context).textTheme;
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(n,
            key: followers == null ? null : ValueKey(followers ? 'followerCount' : 'followingCount'),
            style: tx.titleLarge!.copyWith(fontSize: 20, fontWeight: FontWeight.w400, color: t.ink, fontFeatures: const [FontFeature.tabularFigures()])),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
      ]),
    );
    if (followers == null) return child;
    return Semantics(
      button: true,
      label: '$n $label',
      excludeSemantics: true,
      onTap: () => _openFollowList(followers),
      child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => _openFollowList(followers), child: child),
    );
  }

  Future<void> _openFollowList(bool followers) async {
    await openFollowList(context, widget.session, userId: widget.userId, followers: followers, name: _name);
    if (mounted) _loadStats();
  }

  /// "Hakkında" (ya da hiçbir akademik alan görünmüyorsa "Akademik bilgiler") kartı.
  Widget _infoCard(BuTokens t, {required String bio, required String faculty, required String dept, required String grade, required String email}) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final anyVisible = faculty.isNotEmpty || dept.isNotEmpty || grade.isNotEmpty || email.isNotEmpty;
    final lockedAll = !_self && !anyVisible;
    // Başkasının profilinde boş (gizlilik ya da boş) akademik alanlar kilit ikonlu "Gizli" görünür.
    final rows = <Widget>[
      if (faculty.isNotEmpty || !_self) _tile(t, BuIcons.landmark, l.profileFaculty, faculty),
      if (dept.isNotEmpty || !_self) _tile(t, BuIcons.bookOpen, l.profileDepartment, dept),
      if (grade.isNotEmpty || !_self) _tile(t, BuIcons.graduationCap, lockedAll ? l.p20GradeLevel : l.profileGrade, grade),
      if (email.isNotEmpty) _tile(t, BuIcons.atSign, l.profileEmail, email),
    ];
    if (rows.isEmpty && bio.isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(header: true, child: Text(lockedAll ? l.p20AcademicInfo : l.profileAboutShort, style: tx.titleMedium!.copyWith(fontSize: 18, fontWeight: FontWeight.w400, color: t.ink))),
        if (bio.isNotEmpty && !lockedAll) ...[
          const SizedBox(height: 10),
          Text(bio, style: tx.bodyMedium!.copyWith(fontSize: 15, color: t.mut, height: 1.6)),
        ],
        if (rows.isNotEmpty) const SizedBox(height: 12),
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 12), rows[i]],
        if (lockedAll) ...[
          const SizedBox(height: 16),
          Text(akadUpper(context, l.profileAboutShort), style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w400, color: t.mut)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(BuIcons.textAlignStart, size: 18, color: t.mut),
              const SizedBox(width: 10),
              Expanded(
                child: Text(bio.isEmpty ? l.p20AboutNoBio : bio,
                    style: tx.bodyMedium!.copyWith(color: t.mut, fontStyle: bio.isEmpty ? FontStyle.italic : null)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  /// Akademik bilgi satırı: kutu/simge karosu yok; küçük soluk etiket + değer. Gizli alan: etiket + kilit + "Gizli".
  Widget _tile(BuTokens t, IconData icon, String label, String value) {
    final tx = Theme.of(context).textTheme;
    final hidden = value.isEmpty;
    return Semantics(
      container: true,
      label: hidden ? '$label: ${context.l10n.icerikHidden}' : '$label: $value',
      excludeSemantics: true,
      child: hidden
          ? Row(children: [
              Expanded(child: Text(label, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w400, color: t.mut))),
              Icon(BuIcons.lock, size: 14, color: t.mut),
              const SizedBox(width: 4),
              Text(context.l10n.icerikHidden, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w400, color: t.mut)),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: tx.labelMedium!.copyWith(fontSize: 13, fontWeight: BuType.emphasisWeight, color: t.mut)),
              const SizedBox(height: 4),
              Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontSize: 15, fontWeight: FontWeight.w400, color: t.ink)),
            ]),
    );
  }

  Widget _skeleton(BuTokens t) {
    return Semantics(
      label: context.l10n.commonLoading,
      liveRegion: true,
      child: BuSkeletonScope(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _card(
              child: Column(children: [
                Stack(alignment: Alignment.center, children: [
                  const BuSkeleton.circle(96),
                  Icon(BuIcons.user, size: 28, color: t.mut.withValues(alpha: .5)),
                ]),
                const SizedBox(height: 14),
                const BuSkeleton(width: 160, height: 18, radius: 9),
                const SizedBox(height: 8),
                const BuSkeleton(width: 112, height: 12, radius: 6),
                const SizedBox(height: 18),
                const Row(children: [
                  Expanded(child: BuSkeleton(height: 56, radius: 14)),
                  SizedBox(width: 8),
                  Expanded(child: BuSkeleton(height: 56, radius: 14)),
                  SizedBox(width: 8),
                  Expanded(child: BuSkeleton(height: 56, radius: 14)),
                ]),
                const SizedBox(height: 14),
                const Row(children: [
                  Expanded(child: BuSkeleton(height: 48, radius: 12)),
                  SizedBox(width: 10),
                  Expanded(child: BuSkeleton(height: 48, radius: 12)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            _card(
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                BuSkeleton(width: 120, height: 16, radius: 8),
                SizedBox(height: 14),
                BuSkeleton(height: 10, radius: 5),
                SizedBox(height: 8),
                BuSkeleton(height: 10, radius: 5),
                SizedBox(height: 8),
                BuSkeleton(width: 200, height: 10, radius: 5),
              ]),
            ),
            const SizedBox(height: 14),
            _card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  BuSkeleton(width: 96, height: 14, radius: 7),
                  Spacer(),
                  BuSkeleton(width: 56, height: 14, radius: 7),
                ]),
                const SizedBox(height: 14),
                for (var r = 0; r < 2; r++) ...[
                  if (r > 0) const SizedBox(height: 8),
                  const Row(children: [
                    Expanded(child: BuSkeleton(height: 92, radius: 12)),
                    SizedBox(width: 8),
                    Expanded(child: BuSkeleton(height: 92, radius: 12)),
                    SizedBox(width: 8),
                    Expanded(child: BuSkeleton(height: 92, radius: 12)),
                  ]),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Tam ekran avatar görüntüleyici (Stitch 47-05): siyah zemin, daire kırpılmış büyük fotoğraf, sol üstte kapat, altta ad.
class _AvatarViewer extends StatelessWidget {
  const _AvatarViewer({required this.url, required this.headers, required this.title});

  final String url;
  final Map<String, String>? headers;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final w = MediaQuery.sizeOf(context).width;
    final size = (w - 48).clamp(200.0, 420.0);
    return Scaffold(
      backgroundColor: t.scrim,
      body: Stack(children: [
        Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: ClipOval(
              child: SizedBox(
                width: size,
                height: size,
                child: Image(
                    image: persistentNetworkImage(url, headers: headers, cacheWidth: 1200),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(
                        color: t.onMedia.withValues(alpha: .08), child: Center(child: Icon(BuIcons.imageOff, color: t.onMedia.withValues(alpha: .54), size: 43)))),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          start: 12,
          top: MediaQuery.paddingOf(context).top + 8,
          child: IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: context.l10n.commonCancel,
            style: IconButton.styleFrom(backgroundColor: t.onMedia.withValues(alpha: .16)),
            icon: Icon(BuIcons.x, size: 22, color: t.onMedia),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        PositionedDirectional(
          start: 24,
          end: 24,
          bottom: MediaQuery.paddingOf(context).bottom + 48,
          child: Text(title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w400, color: t.onMedia)),
        ),
      ]),
    );
  }
}
