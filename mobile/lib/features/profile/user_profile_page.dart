// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart' show gradeLabelL;
import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import '../../widgets/report_sheet.dart';
import '../academic/akad_widgets.dart';
import '../chat/chat_detail_page.dart';
import '../follow/follow_list_page.dart';
import '../posts/social_api.dart';
import '../posts/social_models.dart';
import 'edit_profile_page.dart';
import 'icerik_user_posts_grid.dart';

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
      MaterialPageRoute<void>(
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
  bool _busyFollow = false;
  FollowStats? _stats;
  String? _postCount;

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

  Future<void> _toggleFollow() async {
    if (_busyFollow) return;
    final s = _stats ?? const FollowStats();
    final want = !s.followedByMe;
    final api = SocialApi(widget.session);
    setState(() {
      _busyFollow = true;
      _stats = s.copyWith(followedByMe: want, followers: (s.followers + (want ? 1 : -1)).clamp(0, 1 << 30));
    });
    try {
      final res = await (want ? api.follow(widget.userId) : api.unfollow(widget.userId));
      // Sunucunun kesin takipçi sayısı iyimser tahminin yerini alır.
      final c = res.followerCount;
      if (mounted && c != null) setState(() => _stats = (_stats ?? s).copyWith(followers: c));
    } catch (e) {
      if (mounted) setState(() => _stats = s);
      _toast(errorText(e), kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _busyFollow = false);
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final api = widget.session.api;
    try {
      final r = await api.get(_self ? '/users/me' : '/users/${widget.userId}');
      if (!mounted) return;
      final m = Map<String, dynamic>.from(r as Map);
      // Başkasının profil yanıtı takip alanlarını taşır: ikinci istek gerekmez.
      final hasStats = !_self && m['followerCount'] != null;
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
        MaterialPageRoute<void>(builder: (_) => ChatDetailPage(session: widget.session, conversation: conv)),
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

  Future<void> _edit() async {
    final p = _p;
    if (p == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => EditProfilePage(session: widget.session, profile: p)),
    );
    if (changed == true) {
      widget.session.refreshName();
      if (mounted) _load();
    }
  }

  void _toast(String m, {BuToastKind kind = BuToastKind.info}) {
    if (!mounted) return;
    BuToast.show(context, m, kind: kind);
  }

  void _viewAvatar() {
    final url = fileUrl(_avatar);
    if (url == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _AvatarViewer(url: url, headers: _headersFor(_avatar), title: _name),
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  String? _presenceText() {
    final p = _presence;
    if (p == null) return null;
    final l10n = context.l10n;
    if (p['online'] == true) return l10n.profileOnline;
    final d = DateTime.tryParse((p['lastSeenAt'] as String?) ?? '')?.toLocal();
    if (d == null) return null;
    final now = DateTime.now();
    final hm = '${_two(d.hour)}:${_two(d.minute)}';
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return l10n.profileLastSeenToday(hm);
    }
    final y = now.subtract(const Duration(days: 1));
    if (d.year == y.year && d.month == y.month && d.day == y.day) {
      return l10n.profileLastSeenYesterday(hm);
    }
    return l10n.profileLastSeenDate('${_two(d.day)}.${_two(d.month)}.${d.year}', hm);
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
                color: danger ? t.soft : t.sf2,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  key: key,
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pop(c);
                    onTap();
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(children: [
                        AkadIconTile(icon: icon, bg: danger ? t.pr : t.sf, fg: danger ? t.onPr : t.ink, size: 40, radius: 12, iconSize: 20),
                        const SizedBox(width: 14),
                        Expanded(child: Text(label, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: danger ? t.onSoft : t.ink))),
                        Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: danger ? t.pr : t.mut),
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
                  Semantics(header: true, child: Text(l.icerikUserMenu, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
                  Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.mut)),
                ]),
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: l.commonCancel,
                style: IconButton.styleFrom(backgroundColor: t.sf2),
                icon: Icon(LucideIcons.x, size: 18, color: t.ink),
                onPressed: () => Navigator.pop(c),
              ),
            ]),
          ),
          item(const ValueKey('profile-menu-block'), _blocked ? LucideIcons.lockOpen : LucideIcons.ban, _blocked ? l.profileUnblock : l.profileBlock, _toggleBlock,
              danger: true),
          item(const ValueKey('profile-menu-report'), LucideIcons.flag, l.profileReportUser, _report),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
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
                  icon: Icon(buDirIcon(context, LucideIcons.chevronLeft), size: 26, color: t.ink),
                  onPressed: () => Navigator.maybePop(context),
                ),
                Expanded(child: Semantics(header: true, child: Text(l.p20ProfileTitle, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)))),
                if (showMenu)
                  IconButton(
                    key: const ValueKey('profile-more'),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    tooltip: l.icerikUserMenu,
                    icon: Icon(LucideIcons.ellipsis, size: 22, color: t.ink),
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
        decoration: BoxDecoration(color: context.bu.sf, borderRadius: BorderRadius.circular(24), boxShadow: BuElevation.of(context, 1)),
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
                  Icon(LucideIcons.userX, size: 36, color: t.mut),
                  const SizedBox(height: 12),
                  Text(l.profileNotFound, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                  const SizedBox(height: 16),
                  BuButton(label: l.commonBack, kind: BuButtonKind.soft, compact: true, onPressed: () => Navigator.maybePop(context)),
                ]),
              ),
            )
          : ErrorView(error: _error!, onRetry: _load);
    }
    if (_p == null) return _skeleton(t);

    final dept = _s('department');
    final presence = _self ? null : _presenceText();
    final online = _presence?['online'] == true;
    final bio = _s('bio');
    final faculty = _s('faculty');
    final grade = _gradeText();
    final email = _s('email');
    final s = _stats;
    final stat = _blocked ? '—' : null;
    final avatarHidden = _self && _p?['avatarHidden'] == true;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.of(context).padding.bottom + 32),
      children: [
        if (_blocked && !_self) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(LucideIcons.shieldBan, size: 20, color: t.onSoft),
              const SizedBox(width: 12),
              Expanded(child: Text(l.profileBlocked, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.onSoft))),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        _card(
          child: Column(children: [
            GestureDetector(
              key: const Key('profile-avatar'),
              onTap: _viewAvatar,
              child: Stack(clipBehavior: Clip.none, children: [
                _avatarFace(t, online: online && !_blocked),
                if (_blocked)
                  PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle, border: Border.all(color: t.sf, width: 3)),
                      child: Icon(LucideIcons.ban, size: 16, color: t.onPr),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(_name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.headlineSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
            ),
            if (_blocked && dept.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(dept, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.mut)),
            ],
            if (presence != null && !_blocked) ...[
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (online)
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: t.ok, shape: BoxShape.circle))
                else
                  Icon(LucideIcons.clock, size: 14, color: t.mut),
                const SizedBox(width: 6),
                Flexible(child: Text(presence, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w600, color: t.mut))),
              ]),
            ],
            if (!_self && !_blocked && s != null && s.followsMe) ...[
              const SizedBox(height: 8),
              AkadPill(s.followedByMe ? l.profilyardFollowMutual : l.profilyardFollowsYou,
                  key: const ValueKey('followRelationPill'),
                  bg: s.followedByMe ? t.tint(1).bg : t.soft,
                  fg: s.followedByMe ? t.tint(1).fg : t.onSoft,
                  icon: s.followedByMe ? LucideIcons.arrowLeftRight : LucideIcons.userPlus),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Expanded(child: _stat(t, stat ?? _postCount ?? '0', l.icerikStatPosts)),
                Expanded(child: _stat(t, stat ?? (s == null ? '0' : '${s.followers}'), l.icerikStatFollowers, followers: _blocked ? null : true)),
                Expanded(child: _stat(t, stat ?? (s == null ? '0' : '${s.following}'), l.icerikStatFollowing, followers: _blocked ? null : false)),
              ]),
            ),
            const SizedBox(height: 14),
            _actions(t, s),
          ]),
        ),
        if (avatarHidden) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(20)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle), child: Icon(LucideIcons.info, size: 18, color: t.onPr)),
              const SizedBox(width: 12),
              Expanded(child: Text(l.p20AvatarHidden, style: tx.bodyMedium!.copyWith(color: t.onSoft))),
            ]),
          ),
        ],
        if (!_blocked) ...[
          const SizedBox(height: 14),
          _infoCard(t, bio: bio, faculty: faculty, dept: dept, grade: grade, email: email),
          IcerikUserPostsGrid(
            session: widget.session,
            userId: widget.userId,
            name: _name,
            onCount: (c) {
              if (mounted) setState(() => _postCount = c);
            },
          ),
        ],
      ],
    );
  }

  /// 96 dp avatar: fotoğraf varsa BuAvatar, yoksa baş harfli koyu daire (referans); sağ altta durum noktası
  /// (çevrimiçi yeşil, çevrimdışı gri; durum bilinmiyorsa nokta yok).
  Widget _avatarFace(BuTokens t, {required bool online}) {
    final known = _presence != null && !_blocked;
    final face = fileUrl(_avatar) != null
        ? BuAvatar(name: _name, url: _avatar, size: 96, headers: _headersFor(_avatar))
        : Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle),
            child: Text(initialsOf(_name), style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800, color: t.bg)),
          );
    return Stack(clipBehavior: Clip.none, children: [
      face,
      if (known)
        PositionedDirectional(
          end: 2,
          bottom: 2,
          child: Container(width: 20, height: 20, decoration: BoxDecoration(color: online ? t.ok : t.mut.withValues(alpha: .6), shape: BoxShape.circle, border: Border.all(color: t.sf, width: 3))),
        ),
    ]);
  }

  Widget _actions(BuTokens t, FollowStats? s) {
    final l = context.l10n;
    if (_self) return BuButton(label: l.profileEditTitle, icon: LucideIcons.squarePen, onPressed: _edit);
    if (_blocked) {
      return Row(children: [
        Expanded(child: BuButton(label: l.profileUnblock, icon: LucideIcons.lockOpen, kind: BuButtonKind.outline, busy: _busyBlock, onPressed: _toggleBlock)),
        const SizedBox(width: 10),
        IconButton(
          constraints: const BoxConstraints(minWidth: 54, minHeight: 54),
          tooltip: l.icerikUserMenu,
          style: IconButton.styleFrom(backgroundColor: t.sf2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          icon: Icon(LucideIcons.ellipsis, size: 20, color: t.ink),
          onPressed: _openMenu,
        ),
      ]);
    }
    final following = s?.followedByMe ?? false;
    return Row(children: [
      Expanded(
        child: Semantics(
          toggled: following,
          child: following
              ? AkadTonalButton(
                  key: const ValueKey('followButton'),
                  label: l.followButtonFollowing,
                  icon: LucideIcons.check,
                  height: 54,
                  busy: _busyFollow,
                  onPressed: _toggleFollow,
                )
              : BuButton(
                  key: const ValueKey('followButton'),
                  label: l.followButtonFollow,
                  icon: LucideIcons.userPlus,
                  busy: _busyFollow,
                  onPressed: _toggleFollow,
                ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: AkadTonalButton(
          key: const ValueKey('profile-message'),
          label: l.icerikMessageSend,
          icon: LucideIcons.messageSquare,
          height: 54,
          busy: _busyMsg,
          onPressed: _message,
        ),
      ),
    ]);
  }

  Widget _stat(BuTokens t, String n, String label, {bool? followers}) {
    final tx = Theme.of(context).textTheme;
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(n,
            key: followers == null ? null : ValueKey(followers ? 'followerCount' : 'followingCount'),
            style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
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
      if (faculty.isNotEmpty || !_self) _tile(t, LucideIcons.landmark, l.profileFaculty, faculty),
      if (dept.isNotEmpty || !_self) _tile(t, LucideIcons.bookOpen, l.profileDepartment, dept),
      if (grade.isNotEmpty || !_self) _tile(t, LucideIcons.graduationCap, lockedAll ? l.p20GradeLevel : l.profileGrade, grade),
      if (email.isNotEmpty) _tile(t, LucideIcons.atSign, l.profileEmail, email),
    ];
    if (rows.isEmpty && bio.isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(lockedAll ? LucideIcons.graduationCap : LucideIcons.idCard, size: 20, color: t.pr),
          const SizedBox(width: 10),
          Expanded(child: Semantics(header: true, child: Text(lockedAll ? l.p20AcademicInfo : l.profileAboutShort, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)))),
        ]),
        if (bio.isNotEmpty && !lockedAll) ...[
          const SizedBox(height: 10),
          Text(bio, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
        ],
        if (rows.isNotEmpty) const SizedBox(height: 12),
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 8), rows[i]],
        if (lockedAll) ...[
          const SizedBox(height: 16),
          Text(akadUpper(context, l.profileAboutShort), style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: t.mut)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(LucideIcons.textAlignStart, size: 18, color: t.mut),
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

  Widget _tile(BuTokens t, IconData icon, String label, String value) {
    final tx = Theme.of(context).textTheme;
    final hidden = value.isEmpty;
    return Semantics(
      container: true,
      label: hidden ? '$label: ${context.l10n.icerikHidden}' : '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          if (hidden) Icon(icon, size: 20, color: t.mut) else AkadIconTile(icon: icon, bg: t.sf, fg: t.ink, size: 36, radius: 10, iconSize: 18),
          const SizedBox(width: 12),
          if (hidden) ...[
            Expanded(child: Text(label, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w600, color: t.mut))),
            Icon(LucideIcons.lock, size: 14, color: t.mut),
            const SizedBox(width: 4),
            Text(context.l10n.icerikHidden, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.mut)),
          ] else
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: tx.labelSmall!.copyWith(color: t.mut)),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _skeleton(BuTokens t) {
    return Semantics(
      label: context.l10n.commonLoading,
      liveRegion: true,
      child: BuSkeletonScope(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _card(
              child: Column(children: [
                Stack(alignment: Alignment.center, children: [
                  const BuSkeleton.circle(96),
                  Icon(LucideIcons.user, size: 28, color: t.mut.withValues(alpha: .5)),
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
                  Expanded(child: BuSkeleton(height: 48, radius: 24)),
                  SizedBox(width: 10),
                  Expanded(child: BuSkeleton(height: 48, radius: 24)),
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
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: RadialGradient(radius: .85, colors: [BuTokens.light.ink.withValues(alpha: .55), t.scrim])),
          ),
        ),
        Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: ClipOval(
              child: SizedBox(
                width: size,
                height: size,
                child: Image.network(url,
                    headers: headers,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(
                        color: t.onMedia.withValues(alpha: .08), child: Center(child: Icon(LucideIcons.imageOff, color: t.onMedia.withValues(alpha: .54), size: 43)))),
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
            icon: Icon(LucideIcons.x, size: 22, color: t.onMedia),
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
              style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.onMedia)),
        ),
      ]),
    );
  }
}
