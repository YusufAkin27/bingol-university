import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart' show gradeLabel;
import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/report_sheet.dart';
import '../chat/chat_detail_page.dart';
import '../follow/follow_list_page.dart';
import '../news/icerik_parts.dart';
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

/// Başka bir kullanıcının (ya da kendi) profili: bilgiler, çevrimiçi durumu, mesaj/engelle/şikâyet.
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
  bool _menuOpen = false;
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
      await (want ? api.follow(widget.userId) : api.unfollow(widget.userId));
    } catch (e) {
      if (mounted) setState(() => _stats = s);
      _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _busyFollow = false);
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    _loadStats();
    final api = widget.session.api;
    try {
      final r = await api.get(_self ? '/users/me' : '/users/${widget.userId}');
      if (!mounted) return;
      setState(() => _p = Map<String, dynamic>.from(r as Map));
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
    try {
      final r = await api.get('/users/me/blocks?limit=50');
      final list = r is List ? r : (r is Map ? (r['items'] as List? ?? const []) : const []);
      final b = list.any((u) => u is Map && (u['id'] as num?)?.toInt() == widget.userId);
      if (mounted && b != _blocked) setState(() => _blocked = b);
    } catch (_) {}
  }

  Map<String, String>? get _headers {
    final tok = widget.session.api.tokens?.access;
    return tok == null ? null : {'Authorization': 'Bearer $tok'};
  }

  Map<String, String>? _headersFor(String? url) =>
      (url != null && url.startsWith('/api/')) ? _headers : null;

  String get _name => ((_p?['displayName'] as String?) ?? widget.initialName ?? context.l10n.profileUserDefault);
  String? get _avatar => (_p?['avatarUrl'] as String?) ?? widget.initialAvatarUrl;

  String _s(String key) => ((_p?[key]) ?? '').toString().trim();

  String _gradeText() {
    final g = _s('grade');
    if (g.isNotEmpty) return gradeLabel(g);
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
        MaterialPageRoute<void>(
            builder: (_) => ChatDetailPage(session: widget.session, conversation: conv)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyMsg = false);
      _toast(errorText(e));
    }
  }

  Future<void> _toggleBlock() async {
    if (_busyBlock) return;
    final unblock = _blocked;
    if (!unblock) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(c.l10n.profileBlockTitle),
          content: Text(c.l10n.profileBlockBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.l10n.profileCancel)),
            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(c.l10n.profileBlock)),
          ],
        ),
      );
      if (ok != true || !mounted) return;
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
      _toast(unblock ? context.l10n.profileUnblocked : context.l10n.profileBlocked);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyBlock = false);
      _toast(errorText(e));
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

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final top = MediaQuery.of(context).padding.top;
    final showMenu = _p != null && !_self;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          Positioned.fill(child: _body(t)),
          Positioned(
            left: 20,
            right: 20,
            top: top + 8,
            child: Row(children: [
              IcerikIconButton(
                  icon: buDirIcon(context, LucideIcons.arrowLeft),
                  label: l.commonBack,
                  shadow: true,
                  onTap: () => Navigator.maybePop(context)),
              const Spacer(),
              if (showMenu)
                IcerikIconButton(
                  key: const ValueKey('profile-more'),
                  icon: LucideIcons.ellipsis,
                  label: l.icerikMoreActions,
                  on: _menuOpen,
                  onTap: () => setState(() => _menuOpen = !_menuOpen),
                ),
            ]),
          ),
          if (showMenu && _menuOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _menuOpen = false),
                child: const SizedBox.expand(),
              ),
            ),
            PositionedDirectional(
              end: 20,
              top: top + 60,
              width: 208,
              child: _menu(t),
            ),
          ],
        ],
      ),
    );
  }

  Widget _menu(BuTokens t) {
    final l = context.l10n;
    Widget item(Key key, IconData icon, String label, VoidCallback onTap, {bool danger = false, bool first = false}) {
      final fg = danger ? t.danger : t.ink;
      return InkWell(
        key: key,
        onTap: () {
          setState(() => _menuOpen = false);
          onTap();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: first ? null : BoxDecoration(border: Border(top: BorderSide(color: t.bd.withValues(alpha: .6)))),
          child: Row(children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BuType.bodyStrong.copyWith(fontSize: 15, color: fg)),
            ),
          ]),
        ),
      );
    }

    return Semantics(
      container: true,
      label: l.icerikUserMenu,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.bd),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF171E33).withValues(alpha: icerikDark(context) ? .5 : .3),
                blurRadius: 40,
                offset: const Offset(0, 18),
                spreadRadius: -16),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: t.sf,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              item(const ValueKey('profile-menu-report'), LucideIcons.flag, l.icerikReport, _report, first: true),
              item(const ValueKey('profile-menu-block'), LucideIcons.ban, _blocked ? l.profileUnblock : l.profileBlock,
                  _toggleBlock,
                  danger: !_blocked),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _body(BuTokens t) {
    final top = MediaQuery.of(context).padding.top;
    if (_error != null && _p == null) {
      final nf = _error is ApiError && (_error as ApiError).status == 404;
      return Padding(
        padding: EdgeInsets.only(top: top + 56),
        child: nf
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.userX, size: 36, color: t.mut),
                    const SizedBox(height: 12),
                    Text(context.l10n.profileNotFound,
                        textAlign: TextAlign.center, style: BuType.heading.copyWith(color: t.ink)),
                  ]),
                ),
              )
            : ErrorView(error: _error!, onRetry: _load),
      );
    }
    if (_p == null) return _skeleton(t);

    final l = context.l10n;
    final dept = _s('department');
    final presence = _self ? null : _presenceText();
    final bio = _s('bio');
    final faculty = _s('faculty');
    final grade = _gradeText();
    final email = _s('email');
    final s = _stats;
    // Başkasının profilinde dolu olmayan (gizlilik ya da boş) alanlar kilit ikonlu "Gizli" görünür.
    final rows = <_InfoRow>[
      if (faculty.isNotEmpty || !_self) _InfoRow(l.profileFaculty, faculty),
      if (grade.isNotEmpty || !_self) _InfoRow(l.profileGrade, grade),
      if (bio.isNotEmpty || !_self) _InfoRow(l.profileAboutShort, bio, block: true),
      if (email.isNotEmpty) _InfoRow(l.profileEmail, email),
    ];
    return ListView(
      padding: EdgeInsets.fromLTRB(0, top + 60, 0, MediaQuery.of(context).padding.bottom + 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            GestureDetector(
              key: const Key('profile-avatar'),
              onTap: _viewAvatar,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: t.sf, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF171E33).withValues(alpha: .35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                        spreadRadius: -12),
                  ],
                ),
                child: BuAvatar(name: _name, url: _avatar, size: 82, headers: _headersFor(_avatar)),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(_name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BuType.display.copyWith(fontSize: 22, letterSpacing: -.3, height: 1.25, color: t.ink)),
            ),
            if (dept.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(dept,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BuType.body.copyWith(fontSize: 14, color: t.mut)),
            ],
            if (presence != null) ...[
              const SizedBox(height: 4),
              Text(presence,
                  textAlign: TextAlign.center,
                  style: BuType.label.copyWith(color: _presence?['online'] == true ? t.ok : t.mut)),
            ],
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 28,
              runSpacing: 4,
              children: [
                if (_postCount != null) _stat(t, _postCount!, l.icerikStatPosts),
                if (s != null) _stat(t, '${s.followers}', l.icerikStatFollowers, followers: true),
                if (s != null) _stat(t, '${s.following}', l.icerikStatFollowing, followers: false),
              ],
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: _self
              ? Row(children: [
                  Expanded(child: _pill(t, LucideIcons.squarePen, l.profileEditTitle, _edit, primary: true)),
                ])
              : Row(children: [
                  Expanded(
                    child: _pill(
                      t,
                      (s?.followedByMe ?? false) ? LucideIcons.userCheck : LucideIcons.plus,
                      (s?.followedByMe ?? false) ? l.followButtonFollowing : l.followButtonFollow,
                      _toggleFollow,
                      primary: !(s?.followedByMe ?? false),
                      busy: _busyFollow,
                      key: const ValueKey('followButton'),
                      toggled: s?.followedByMe ?? false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _pill(t, LucideIcons.messageCircle, l.icerikMessageSend, _message,
                        busy: _busyMsg, key: const ValueKey('profile-message')),
                  ),
                ]),
        ),
        if (rows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: IcerikCard(
              child: Column(children: [
                for (var i = 0; i < rows.length; i++) _infoRow(t, rows[i], first: i == 0),
              ]),
            ),
          ),
        if (!_blocked)
          IcerikUserPostsGrid(
            session: widget.session,
            userId: widget.userId,
            name: _name,
            onCount: (c) {
              if (mounted) setState(() => _postCount = c);
            },
          ),
      ],
    );
  }

  Widget _stat(BuTokens t, String n, String label, {bool? followers}) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: n, style: BuType.heading.copyWith(fontSize: 17, fontWeight: FontWeight.w800, color: t.ink)),
        TextSpan(text: ' $label', style: BuType.body.copyWith(fontSize: 13, color: t.mut)),
      ]), key: followers == null ? null : ValueKey(followers ? 'followerCount' : 'followingCount')),
    );
    if (followers == null) return child;
    return Semantics(
      button: true,
      label: '$n $label',
      excludeSemantics: true,
      onTap: () => _openFollowList(followers),
      child: InkWell(borderRadius: BorderRadius.circular(10), onTap: () => _openFollowList(followers), child: child),
    );
  }

  Future<void> _openFollowList(bool followers) async {
    await openFollowList(context, widget.session, userId: widget.userId, followers: followers, name: _name);
    if (mounted) _loadStats();
  }

  Widget _pill(BuTokens t, IconData icon, String label, VoidCallback onTap,
      {bool primary = false, bool busy = false, Key? key, bool? toggled}) {
    final fg = primary ? t.onPr : t.ink;
    return Semantics(
      button: true,
      toggled: toggled,
      label: label,
      excludeSemantics: true,
      enabled: !busy,
      onTap: busy ? null : onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: primary ? t.pr : t.sf,
          borderRadius: BorderRadius.circular(16),
          border: primary ? null : Border.all(color: t.bd, width: 1.5),
          boxShadow: primary
              ? [BoxShadow(color: t.pr.withValues(alpha: .6), blurRadius: 22, offset: const Offset(0, 12), spreadRadius: -12)]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(16),
            onTap: busy ? null : onTap,
            child: SizedBox(
              height: 48,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (busy)
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
                else
                  Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BuType.heading.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuTokens t, _InfoRow r, {required bool first}) {
    final hidden = r.value.isEmpty;
    final valueStyle = BuType.bodyStrong.copyWith(fontSize: 14, color: hidden ? t.mut : t.ink);
    final label = Text(r.label, style: BuType.body.copyWith(fontSize: 14, color: t.mut));
    final value = hidden
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.lock, size: 15, color: t.mut),
            const SizedBox(width: 6),
            Text(context.l10n.icerikHidden, style: valueStyle),
          ])
        : null;
    final decoration = first ? null : BoxDecoration(border: Border(top: BorderSide(color: t.bd.withValues(alpha: .6))));
    if (r.block && !hidden) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: decoration,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          label,
          const SizedBox(height: 4),
          Text(r.value, style: valueStyle.copyWith(fontWeight: FontWeight.w500, height: 1.4)),
        ]),
      );
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: decoration,
      child: Row(children: [
        Expanded(child: label),
        const SizedBox(width: 10),
        if (value != null)
          value
        else
          Flexible(
            flex: 2,
            child: Text(r.value, textAlign: TextAlign.end, maxLines: 3, overflow: TextOverflow.ellipsis, style: valueStyle),
          ),
      ]),
    );
  }

  Widget _skeleton(BuTokens t) {
    final top = MediaQuery.of(context).padding.top;
    Widget bar(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(8)));
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, top + 60, 20, 32),
      children: [
        Center(
          child: _avatar == null && widget.initialName == null
              ? Container(width: 88, height: 88, decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle))
              : BuAvatar(
                  name: widget.initialName,
                  url: widget.initialAvatarUrl,
                  size: 88,
                  headers: _headersFor(widget.initialAvatarUrl)),
        ),
        const SizedBox(height: 12),
        Center(
            child: widget.initialName != null
                ? Text(widget.initialName!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: BuType.display.copyWith(fontSize: 22, letterSpacing: -.3, color: t.ink))
                : bar(160, 20)),
        const SizedBox(height: 10),
        Center(child: bar(200, 14)),
        const SizedBox(height: 28),
        bar(double.infinity, 48),
        const SizedBox(height: 14),
        bar(double.infinity, 132),
      ],
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value, {this.block = false});

  final String label;
  final String value;
  final bool block;
}

// Basit tam ekran avatar görüntüleyici (yakınlaştırılabilir).
class _AvatarViewer extends StatelessWidget {
  const _AvatarViewer({required this.url, required this.headers, required this.title});

  final String url;
  final Map<String, String>? headers;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(color: Colors.white)),
      ),
      body: SizedBox.expand(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.network(url,
                headers: headers,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 43)),
          ),
        ),
      ),
    );
  }
}
