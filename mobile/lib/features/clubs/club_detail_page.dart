import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/report_sheet.dart';
import '../chat/chat_detail_page.dart';
import '../events/event_detail_page.dart';
import 'club_join_flow.dart';

/// Kulüp detayı: kapak, üyelik, sohbet, gönderiler / etkinlikler / üyeler.
class ClubDetailPage extends StatefulWidget {
  const ClubDetailPage({super.key, required this.session, required this.communityId});

  final Session session;
  final int communityId;

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

/// İmleçli liste durumu (gönderi / etkinlik / üye / istek).
class _Paged {
  final items = <Map<String, dynamic>>[];
  int? next;
  bool loading = false;
  bool loaded = false;
  Object? error;
}

class _ClubDetailPageState extends State<ClubDetailPage> {
  Map<String, dynamic>? _club;
  Object? _error;
  bool _busy = false;
  int _tab = 0;

  final _posts = _Paged();
  final _events = _Paged();
  final _members = _Paged();
  final _requests = _Paged();

  final _scroll = ScrollController();
  final _text = TextEditingController();
  bool _sending = false;
  PreparedImage? _image;
  final _images = ImageService();

  String get _base => '/communities/${widget.communityId}';
  String get _status => (_club?['myStatus'] ?? 'NONE').toString();
  bool get _isMember => _status == 'ACTIVE';
  bool get _isPending => _status == 'PENDING';
  String? get _role => _club?['myRole']?.toString();
  bool get _isManager => _isMember && (_role == 'OWNER' || _role == 'MODERATOR');

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _more();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await widget.session.api.get(_base);
      if (!mounted) return;
      setState(() {
        _club = Map<String, dynamic>.from(r as Map);
        _error = null;
      });
      // Sekmeler tembel yüklenir: yalnız açık olan çekilir, diğerleri açılınca yüklenecek.
      for (final p in [_posts, _events, _members]) {
        if (!identical(p, _cur)) {
          p.items.clear();
          p.next = null;
          p.loaded = false;
          p.error = null;
        }
      }
      _refreshTab(reset: true);
      if (_isManager) {
        _fetch(_requests, _requestsPath, reset: true);
      } else {
        setState(() => _requests.items.clear());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  String get _requestsPath => '$_base/requests?include=answers';

  _Paged get _cur => switch (_tab) { 0 => _posts, 1 => _events, _ => _members };

  String get _curPath => switch (_tab) {
        0 => '$_base/posts',
        1 => '/events?communityId=${widget.communityId}',
        _ => '$_base/members',
      };

  void _refreshTab({bool reset = false}) => _fetch(_cur, _curPath, reset: reset);

  void _more() {
    final p = _cur;
    if (p.next != null && !p.loading) _fetch(p, _curPath);
  }

  Future<void> _fetch(_Paged p, String path, {bool reset = false}) async {
    if (p.loading) return;
    setState(() {
      p.loading = true;
      if (reset) p.error = null;
    });
    try {
      final sep = path.contains('?') ? '&' : '?';
      final cursor = (!reset && p.next != null) ? '&cursor=${p.next}' : '';
      final r = await widget.session.api.get('$path${sep}size=20$cursor') as Map;
      if (!mounted) return;
      setState(() {
        if (reset) p.items.clear();
        p.items.addAll((r['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
        p.next = (r['nextCursor'] as num?)?.toInt();
        p.loaded = true;
        p.loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          p.error = e;
          p.loading = false;
          p.loaded = true;
        });
      }
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      final c = _club!;
      final st = await joinClubFlow(
        context,
        widget.session,
        communityId: widget.communityId,
        clubName: (c['name'] ?? '').toString(),
        needsApproval: c['joinPolicy'] == 'APPROVAL' || c['visibility'] == 'PRIVATE',
      );
      if (st != null) await _load();
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _leave() async {
    final isPending = _isPending;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(isPending ? 'İsteği geri çek' : 'Kulüpten ayrıl'),
        content: Text(isPending
            ? 'Katılma isteğiniz geri çekilsin mi?'
            : '${_club?['name'] ?? 'Bu kulüp'} kulübünden ayrılmak istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(isPending ? 'Geri çek' : 'Ayrıl')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.session.api.delete('$_base/membership');
      await _load();
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openChat() async {
    setState(() => _busy = true);
    try {
      final api = widget.session.api;
      var room = await api.get('$_base/chat-room');
      room = room is Map ? Map<String, dynamic>.from(room) : <String, dynamic>{};
      if (room['joined'] != true) {
        if (room['closed'] == true) {
          if (mounted) _snack('Kulüp sohbeti şu an kapalı.');
          return;
        }
        room = Map<String, dynamic>.from(await api.post('$_base/chat-room/join') as Map);
      }
      final cid = (room['conversationId'] as num?)?.toInt();
      if (cid == null) {
        if (mounted) _snack('Kulüp sohbeti hazırlanıyor, biraz sonra tekrar dene.');
        return;
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailPage(
            session: widget.session,
            conversation: {
              'id': cid,
              'type': 'GROUP',
              'title': (_club?['name'] ?? 'Kulüp sohbeti').toString(),
              'memberCount': room['memberCount'],
              'communityId': widget.communityId,
            },
          ),
        ),
      );
    } on ApiError catch (e) {
      if (mounted) _snack(errorText(e));
    } catch (e) {
      if (mounted) _snack(errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final img = await _images.pickPrepared(ImageSource.gallery);
      if (img != null && mounted) setState(() => _image = img);
    } on ImageException catch (e) {
      if (mounted) {
        _snack(e.code == 'TOO_LARGE'
            ? 'Görsel çok büyük.'
            : e.code == 'UNSUPPORTED_TYPE'
                ? 'Yalnızca JPEG, PNG veya WebP görseller yüklenebilir.'
                : 'Görsel okunamadı.');
      }
    } catch (_) {
      if (mounted) _snack('Görsel seçilemedi.');
    }
  }

  Future<void> _post() async {
    final text = _text.text.trim();
    if ((text.isEmpty && _image == null) || _sending) return;
    setState(() => _sending = true);
    try {
      String? imageUrl;
      if (_image != null) {
        final up = await MultipartUploader(widget.session).upload('$_base/posts/upload', _image!);
        imageUrl = up is Map ? up['url']?.toString() : null;
        if (imageUrl == null) throw ApiError(0, 'UPLOAD', 'Görsel yüklenemedi.');
      }
      await widget.session.api.post('$_base/posts', {
        'text': text,
        if (imageUrl != null) 'imageUrl': imageUrl,
      });
      _text.clear();
      _image = null;
      if (mounted) FocusScope.of(context).unfocus();
      await _fetch(_posts, '$_base/posts', reset: true);
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _deletePost(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Gönderiyi sil'),
        content: const Text('Bu gönderi kalıcı olarak silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.session.api.delete('$_base/posts/${p['id']}');
      if (mounted) setState(() => _posts.items.remove(p));
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
  }

  Future<void> _togglePin(Map<String, dynamic> p) async {
    final pinned = p['pinned'] == true;
    try {
      final path = '$_base/posts/${p['id']}/pin';
      if (pinned) {
        await widget.session.api.delete(path);
      } else {
        await widget.session.api.put(path);
      }
      if (mounted) await _fetch(_posts, '$_base/posts', reset: true);
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
  }

  Future<void> _reportClub() => ReportSheet.show(context, widget.session,
      targetType: 'COMMUNITY', targetId: widget.communityId, title: 'Kulübü şikâyet et');

  Future<void> _reportPost(Map<String, dynamic> p) => ReportSheet.show(context, widget.session,
      targetType: 'POST', targetId: (p['id'] as num).toInt(), title: 'Gönderiyi şikâyet et');

  Future<void> _review(Map<String, dynamic> r, bool approve) async {
    try {
      await widget.session.api.post('$_base/requests/${r['userId']}/${approve ? 'approve' : 'reject'}');
      if (!mounted) return;
      setState(() => _requests.items.remove(r));
      if (approve) {
        final c = Map<String, dynamic>.from(_club!);
        c['memberCount'] = ((c['memberCount'] as num?) ?? 0) + 1;
        setState(() => _club = c);
        _members.loaded = false;
        _members.next = null;
        _members.items.clear();
      }
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
  }

  void _setTab(int i) {
    setState(() => _tab = i);
    if (!_cur.loaded) _refreshTab(reset: true);
  }

  Future<void> _refresh() async {
    await _load();
  }

  String _meta() {
    final c = _club!;
    final parts = <String>[
      if ((c['category'] ?? '').toString().isNotEmpty) c['category'].toString(),
      '${c['memberCount'] ?? 0} üye',
      c['visibility'] == 'PRIVATE' ? 'Özel' : 'Herkese açık',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget body;
    if (_error != null && _club == null) {
      body = Column(children: [
        BuHeader(title: 'Kulüp', onBack: () => Navigator.pop(context)),
        Expanded(child: ErrorView(error: _error!, onRetry: () {
          setState(() => _error = null);
          _load();
        })),
      ]);
    } else if (_club == null) {
      body = Column(children: [
        BuHeader(title: 'Kulüp', onBack: () => Navigator.pop(context)),
        const Expanded(child: LoadingView()),
      ]);
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: 120,
        child: ListView(
          controller: _scroll,
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _cover(t),
            _identity(t),
            _tabs(t),
            ..._content(t),
            const SizedBox(height: 32),
          ],
        ),
      );
    }
    return Scaffold(backgroundColor: t.bg, resizeToAvoidBottomInset: true, body: body);
  }

  Widget _cover(BuTokens t) {
    final cover = fileUrl(_club!['coverUrl']?.toString());
    return SizedBox(
      height: 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            child: Stack(fit: StackFit.expand, children: [
              Container(decoration: BoxDecoration(gradient: t.hero)),
              if (cover != null)
                Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())
              else ...[
                Positioned(
                    right: -40,
                    top: -50,
                    child: Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), shape: BoxShape.circle))),
                Positioned(
                    left: -30,
                    bottom: -60,
                    child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), shape: BoxShape.circle))),
              ],
            ]),
          ),
          Positioned(
            left: 20,
            top: MediaQuery.of(context).padding.top + 8,
            child: _glassBtn(LucideIcons.arrowLeft, () => Navigator.pop(context), 'Geri'),
          ),
          if (_role != 'OWNER')
            Positioned(
              right: 20,
              top: MediaQuery.of(context).padding.top + 8,
              child: _glassBtn(LucideIcons.flag, _reportClub, 'Kulübü şikâyet et'),
            ),
        ],
      ),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap, String tip) => Tooltip(
        message: tip,
        child: Material(
          color: Colors.white.withValues(alpha: .22),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 22, color: Colors.white)),
          ),
        ),
      );

  Widget _identity(BuTokens t) {
    final c = _club!;
    final desc = (c['description'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: const Offset(0, -34),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.sf,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: t.bg, width: 4),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Text(initialsOf(c['name']?.toString()),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: t.pr)),
                ),
                const Spacer(),
                _membershipButton(),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((c['name'] ?? '').toString(),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.3, color: t.ink)),
                const SizedBox(height: 4),
                Text(_meta(), style: TextStyle(fontSize: 13, color: t.mut)),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(desc, style: TextStyle(fontSize: 14, height: 1.5, color: t.ink)),
                ],
                if (_isMember) ...[
                  const SizedBox(height: 14),
                  BuButton(label: 'Kulüp sohbeti', icon: LucideIcons.messageCircle, compact: true, busy: _busy, onPressed: _openChat),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _membershipButton() {
    if (_isMember) {
      return BuButton(
          label: 'Üyesin', icon: LucideIcons.check, kind: BuButtonKind.soft, compact: true, busy: _busy, onPressed: _leave);
    }
    if (_isPending) {
      return BuButton(
          label: 'İstek gönderildi', kind: BuButtonKind.outline, compact: true, busy: _busy, onPressed: _leave);
    }
    if (_status == 'BANNED') {
      return const BuButton(label: 'Katılamazsın', kind: BuButtonKind.outline, compact: true);
    }
    return BuButton(
        label: _club!['joinPolicy'] == 'APPROVAL' ? 'Katılma isteği gönder' : 'Katıl',
        compact: true,
        busy: _busy,
        onPressed: _join);
  }

  Widget _tabs(BuTokens t) {
    const names = ['Gönderiler', 'Etkinlikler', 'Üyeler'];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
      child: Row(
        children: [
          for (var i = 0; i < names.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setTab(i),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: i == _tab ? t.pr : Colors.transparent, width: 2))),
                  child: Text(names[i],
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: i == _tab ? t.pr : t.mut)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _content(BuTokens t) {
    final p = _cur;
    final out = <Widget>[];
    if (_tab == 0) {
      if (_requests.items.isNotEmpty) out.add(_requestsSection(t));
      if (_isMember) out.add(_composer(t));
    }
    if (p.error != null && p.items.isEmpty) {
      out.add(SizedBox(height: 260, child: ErrorView(error: p.error!, onRetry: () => _refreshTab(reset: true))));
      return out;
    }
    if (!p.loaded) {
      out.add(const SizedBox(height: 200, child: LoadingView()));
      return out;
    }
    if (p.items.isEmpty) {
      final (icon, text) = switch (_tab) {
        0 => (LucideIcons.messageSquare, 'Henüz gönderi yok.'),
        1 => (LucideIcons.calendarX, 'Bu kulübün yaklaşan etkinliği yok.'),
        _ => (LucideIcons.users, 'Üye bulunamadı.'),
      };
      out.add(SizedBox(height: 220, child: EmptyView(icon: icon, text: text)));
      return out;
    }
    for (final it in p.items) {
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: switch (_tab) {
          0 => _postCard(t, it),
          1 => _eventCard(t, it),
          _ => _memberRow(t, it),
        },
      ));
    }
    if (p.loading) {
      out.add(const Padding(padding: EdgeInsets.all(16), child: LoadingView()));
    } else if (p.error != null) {
      out.add(Center(child: TextButton(onPressed: _more, child: const Text('Yüklenemedi, tekrar dene'))));
    }
    return out;
  }

  Widget _composer(BuTokens t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: BuCard(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_image != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, right: 6),
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(_image!.bytes,
                            width: double.infinity, height: 150, fit: BoxFit.cover, gaplessPlayback: true),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: _glassBtn(LucideIcons.x, () => setState(() => _image = null), 'Görseli kaldır'),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      style: TextStyle(fontSize: 14, color: t.ink),
                      decoration: InputDecoration(
                        hintText: 'Kulübe bir şeyler yaz',
                        hintStyle: TextStyle(color: t.mut),
                        isCollapsed: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  BuIconButton(
                      icon: LucideIcons.image, size: 40, onTap: _sending ? null : _pickImage, tooltip: 'Görsel ekle'),
                  const SizedBox(width: 4),
                  BuIconButton(
                      icon: LucideIcons.send, filled: true, size: 40, onTap: _sending ? null : _post, tooltip: 'Paylaş'),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _requestsSection(BuTokens t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: BuCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bekleyen istekler (${_requests.items.length}${_requests.next != null ? '+' : ''})',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.ink)),
              const SizedBox(height: 8),
              for (final r in _requests.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(
                    children: [
                      BuAvatar(name: r['displayName']?.toString(), url: r['avatarUrl']?.toString(), size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text((r['displayName'] ?? 'Kullanıcı').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink))),
                      BuIconButton(icon: LucideIcons.x, size: 36, onTap: () => _review(r, false), tooltip: 'Reddet'),
                      const SizedBox(width: 6),
                      BuIconButton(icon: LucideIcons.check, size: 36, filled: true, onTap: () => _review(r, true), tooltip: 'Onayla'),
                    ],
                  ),
                  ..._answersOf(t, r),
                    ],
                  ),
                ),
              if (_requests.next != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _requests.loading ? null : () => _fetch(_requests, _requestsPath),
                    child: const Text('Daha fazla istek'),
                  ),
                ),
            ],
          ),
        ),
      );

  List<Widget> _answersOf(BuTokens t, Map<String, dynamic> r) {
    final answers = r['answers'];
    if (answers is! List || answers.isEmpty) return const [];
    return [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6, left: 46),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final a in answers.whereType<Map>())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((a['question'] ?? '').toString(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.mut)),
                    Text((a['answer'] ?? '').toString(), style: TextStyle(fontSize: 13, color: t.ink)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _postMenu(BuTokens t, Map<String, dynamic> p) {
    final pinned = p['pinned'] == true;
    return PopupMenuButton<String>(
      tooltip: 'Gönderi işlemleri',
      icon: Icon(LucideIcons.ellipsis, size: 18, color: t.mut),
      padding: EdgeInsets.zero,
      onSelected: (v) {
        switch (v) {
          case 'pin':
            _togglePin(p);
          case 'delete':
            _deletePost(p);
          case 'report':
            _reportPost(p);
        }
      },
      itemBuilder: (_) => [
        if (_isManager) PopupMenuItem(value: 'pin', child: Text(pinned ? 'Sabitlemeyi kaldır' : 'Sabitle')),
        if (p['canDelete'] == true) const PopupMenuItem(value: 'delete', child: Text('Sil')),
        if (_isMember && (p['authorId'] as num?)?.toInt() != widget.session.userId) const PopupMenuItem(value: 'report', child: Text('Şikâyet et')),
      ],
    );
  }

  Widget _postCard(BuTokens t, Map<String, dynamic> p) {
    final img = fileUrl(p['imageUrl']?.toString());
    final pinned = p['pinned'] == true;
    return BuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BuAvatar(name: p['authorName']?.toString(), url: p['authorAvatarUrl']?.toString(), size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((p['authorName'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.ink)),
                    Text(relativeTime(p['createdAt']?.toString()), style: TextStyle(fontSize: 12, color: t.mut)),
                  ],
                ),
              ),
              if (pinned) ...[const BuBadge('Sabit', soft: true), const SizedBox(width: 6)],
              if (_isMember) _postMenu(t, p),
            ],
          ),
          if ((p['text'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(p['text'].toString(), style: TextStyle(fontSize: 14, height: 1.5, color: t.ink)),
          ],
          if (img != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(img,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      height: 130,
                      color: t.sf2,
                      alignment: Alignment.center,
                      child: Icon(LucideIcons.image, size: 30, color: t.mut))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _eventCard(BuTokens t, Map<String, dynamic> e) {
    final id = (e['id'] as num?)?.toInt();
    return BuCard(
      onTap: id == null
          ? null
          : () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => EventDetailPage(session: widget.session, eventId: id))),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(16)),
            child: Icon(LucideIcons.calendar, color: t.onSoft, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((e['title'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.ink)),
                const SizedBox(height: 2),
                Text(
                    [
                      niceDate(e['startsAt']?.toString()),
                      if ((e['location'] ?? '').toString().isNotEmpty) e['location'].toString(),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.mut)),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: t.mut),
        ],
      ),
    );
  }

  Widget _memberRow(BuTokens t, Map<String, dynamic> m) {
    final role = m['role']?.toString();
    return BuCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          BuAvatar(name: m['displayName']?.toString(), url: m['avatarUrl']?.toString(), size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Text((m['displayName'] ?? 'Kullanıcı').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink)),
          ),
          if (role == 'OWNER') const BuBadge('Yönetici', soft: true),
          if (role == 'MODERATOR') const BuBadge('Moderatör', soft: true),
        ],
      ),
    );
  }
}
