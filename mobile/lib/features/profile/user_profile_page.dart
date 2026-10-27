import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart' show gradeLabel;
import '../../core/api.dart' show ApiError;
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/report_sheet.dart';
import '../chat/chat_detail_page.dart';
import '../follow/follow_summary.dart';
import '../posts/profile_posts_section.dart';
import 'edit_profile_page.dart';

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

  bool get _self => widget.userId == widget.session.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
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

  String get _name => ((_p?['displayName'] as String?) ?? widget.initialName ?? 'Kullanıcı');
  String? get _avatar => (_p?['avatarUrl'] as String?) ?? widget.initialAvatarUrl;

  String _s(String key) => ((_p?[key]) ?? '').toString().trim();

  String _gradeText() {
    final g = _s('grade');
    if (g.isNotEmpty) return gradeLabel(g);
    final y = (_p?['classYear'] as num?)?.toInt();
    return (y != null && y > 0) ? '$y. sınıf' : '';
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
          title: const Text('Kullanıcı engellensin mi?'),
          content: const Text('Engellediğiniz kişiyle mesajlaşamazsınız.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Engelle')),
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
      _toast(unblock ? 'Engel kaldırıldı' : 'Kullanıcı engellendi');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyBlock = false);
      _toast(errorText(e));
    }
  }

  Future<void> _report() => ReportSheet.show(context, widget.session,
      targetType: 'USER', targetId: widget.userId, title: 'Kullanıcıyı şikâyet et');

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
    if (p['online'] == true) return 'Çevrimiçi';
    final d = DateTime.tryParse((p['lastSeenAt'] as String?) ?? '')?.toLocal();
    if (d == null) return null;
    final now = DateTime.now();
    final hm = '${_two(d.hour)}:${_two(d.minute)}';
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Son görülme bugün $hm';
    }
    final y = now.subtract(const Duration(days: 1));
    if (d.year == y.year && d.month == y.month && d.day == y.day) {
      return 'Son görülme dün $hm';
    }
    return 'Son görülme ${_two(d.day)}.${_two(d.month)}.${d.year} $hm';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Profil', style: BuType.heading.copyWith(color: t.ink)),
      ),
      body: _body(t),
    );
  }

  Widget _body(BuTokens t) {
    if (_error != null && _p == null) {
      final nf = _error is ApiError && (_error as ApiError).status == 404;
      return nf
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.userX, size: 36, color: t.mut),
                  const SizedBox(height: 12),
                  Text('Kullanıcı bulunamadı',
                      textAlign: TextAlign.center, style: BuType.heading.copyWith(color: t.ink)),
                ]),
              ),
            )
          : ErrorView(error: _error!, onRetry: _load);
    }
    if (_p == null) return _skeleton(t);

    final sub = [
      _s('department'),
      _gradeText(),
    ].where((e) => e.isNotEmpty).join(' · ');
    final presence = _self ? null : _presenceText();
    final bio = _s('bio');
    final rows = <(IconData, String, String)>[
      if (_s('faculty').isNotEmpty) (LucideIcons.building2, 'Fakülte', _s('faculty')),
      if (_s('department').isNotEmpty) (LucideIcons.graduationCap, 'Bölüm', _s('department')),
      if (_gradeText().isNotEmpty) (LucideIcons.bookOpen, 'Sınıf', _gradeText()),
      if (_s('email').isNotEmpty) (LucideIcons.mail, 'E-posta', _s('email')),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Center(
          child: GestureDetector(
            key: const Key('profile-avatar'),
            onTap: _viewAvatar,
            child: BuAvatar(name: _name, url: _avatar, size: 112, headers: _headersFor(_avatar)),
          ),
        ),
        const SizedBox(height: 14),
        Text(_name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: BuType.title.copyWith(color: t.ink)),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(sub,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BuType.body.copyWith(color: t.mut)),
        ],
        if (presence != null) ...[
          const SizedBox(height: 6),
          Text(presence,
              textAlign: TextAlign.center,
              style: BuType.label.copyWith(
                  color: _presence?['online'] == true ? t.ok : t.mut)),
        ],
        FollowSummary(
            key: ValueKey('follow-${widget.userId}'), session: widget.session, userId: widget.userId, name: _name),
        const SizedBox(height: 20),
        if (_self)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _action(t, LucideIcons.squarePen, 'Profili düzenle', _edit),
          ])
        else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: _action(t, LucideIcons.messageCircle, 'Mesaj', _message, busy: _busyMsg)),
            Expanded(
                child: _action(t, LucideIcons.ban, _blocked ? 'Engeli kaldır' : 'Engelle',
                    _toggleBlock,
                    busy: _busyBlock, danger: !_blocked)),
            Expanded(child: _action(t, LucideIcons.flag, 'Şikâyet et', _report, danger: true)),
          ]),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 20),
          BuCard(
            child: SizedBox(
              width: double.infinity,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hakkında', style: BuType.label.copyWith(color: t.mut)),
                const SizedBox(height: 6),
                Text(bio, style: BuType.body.copyWith(color: t.ink)),
              ]),
            ),
          ),
        ],
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 12),
          BuCard(
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 18, color: t.bd),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(rows[i].$1, size: 16, color: t.mut),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(rows[i].$2, style: BuType.caption.copyWith(color: t.mut)),
                      Text(rows[i].$3, style: BuType.bodyStrong.copyWith(color: t.ink)),
                    ]),
                  ),
                ]),
              ],
            ]),
          ),
        ],
        if (!_blocked) ProfilePostsSection(session: widget.session, userId: widget.userId, name: _name),
      ],
    );
  }

  Widget _action(BuTokens t, IconData icon, String label, VoidCallback onTap,
      {bool busy = false, bool danger = false}) {
    final fg = danger ? t.danger : t.onSoft;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
                  : Icon(icon, size: 20, color: fg),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: BuType.label.copyWith(color: t.ink)),
          ]),
        ),
      ),
    );
  }

  Widget _skeleton(BuTokens t) {
    Widget bar(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(8)));
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Center(
          child: _avatar == null && widget.initialName == null
              ? Container(width: 112, height: 112, decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle))
              : BuAvatar(
                  name: widget.initialName,
                  url: widget.initialAvatarUrl,
                  size: 112,
                  headers: _headersFor(widget.initialAvatarUrl)),
        ),
        const SizedBox(height: 14),
        Center(
            child: widget.initialName != null
                ? Text(widget.initialName!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: BuType.title.copyWith(color: t.ink))
                : bar(160, 20)),
        const SizedBox(height: 10),
        Center(child: bar(200, 14)),
        const SizedBox(height: 28),
        bar(double.infinity, 72),
        const SizedBox(height: 12),
        bar(double.infinity, 120),
      ],
    );
  }
}

/// Basit tam ekran avatar görüntüleyici (yakınlaştırılabilir).
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
