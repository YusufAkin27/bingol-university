import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/report_sheet.dart';
import '../chat/chat_detail_page.dart';
import '../events/event_detail_page.dart';
import '../events/event_form_page.dart';
import 'club_actions.dart';
import 'club_form_page.dart';
import 'club_join_flow.dart';
import 'club_members_page.dart';
import 'club_requests_page.dart';
import '../polls/poll_routes.dart';
import '../posts/post_text_rules.dart';
import 'kulup_widgets.dart';
import '../../core/typography.dart';

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
  int _pollGen = 0; // çekme-yenilemede anket sekmesini yeniden yükler

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
  bool get _isOwner => _isMember && _role == 'OWNER';
  bool get _isManager => _isMember && isClubManagerRole(_role);

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
    _pollGen++;
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

  void _refreshTab({bool reset = false}) {
    if (_tab == 3) return; // Anketler sekmesi kendi içeriğini yükler
    _fetch(_cur, _curPath, reset: reset);
  }

  void _more() {
    if (_tab == 3) return;
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

  String _imageError(ImageException e) {
    final l10n = context.l10n;
    return e.code == 'TOO_LARGE'
        ? l10n.clubImageTooLarge
        : e.code == 'UNSUPPORTED_TYPE'
            ? l10n.clubImageUnsupported
            : l10n.clubImageUnreadable;
  }

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

  /// Bekleyen katılma isteğini geri çeker.
  Future<void> _withdraw() async {
    final ok = await confirmDialog(context,
        title: context.l10n.clubWithdrawTitle,
        message: context.l10n.clubWithdrawMessage,
        confirmLabel: context.l10n.clubWithdrawConfirm);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.session.api.delete('$_base/membership');
      await _load();
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Kulüpten ayrıl: onay + DELETE membership; başarıda sayfa "Katıl" durumuna döner.
  Future<void> _leave() async {
    final left = await leaveClubFlow(
      context,
      widget.session,
      communityId: widget.communityId,
      clubName: (_club?['name'] ?? '').toString(),
      isOwner: _isOwner,
    );
    if (!left || !mounted) return;
    setState(() => _busy = true);
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _edit() async {
    final res = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => ClubFormPage(session: widget.session, club: _club)),
    );
    if (res != null && mounted) await _load();
  }

  Future<void> _openRequests() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ClubRequestsPage(session: widget.session, communityId: widget.communityId)),
    );
    if (mounted) await _load();
  }

  Future<void> _openMembers() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => ClubMembersPage(
              session: widget.session,
              communityId: widget.communityId,
              myRole: _role,
              clubName: (_club?['name'] ?? '').toString(),
              memberCount: (_club?['memberCount'] as num?)?.toInt())),
    );
    if (mounted) await _load();
  }

  Future<void> _changeCover() async {
    try {
      final img = await _images.pickPrepared(ImageSource.gallery);
      if (img == null || !mounted) return;
      setState(() => _busy = true);
      await MultipartUploader(widget.session).upload('$_base/cover', img);
      if (mounted) await _load();
    } on ImageException catch (e) {
      if (mounted) {
        _snack(_imageError(e));
      }
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  /// İki aşamalı silme: uyarı + kulüp adını yazarak onay.
  Future<void> _delete() async {
    final name = (_club?['name'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteClubDialog(name: name),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.session.api.delete(_base);
      widget.session.badges.conversationsDirty.value++;
      if (!mounted) return;
      _snack(context.l10n.clubDeleted);
      Navigator.pop(context, 'deleted');
      return;
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
          if (mounted) _snack(context.l10n.clubChatClosed);
          return;
        }
        room = Map<String, dynamic>.from(await api.post('$_base/chat-room/join') as Map);
      }
      final cid = (room['conversationId'] as num?)?.toInt();
      if (cid == null) {
        if (mounted) _snack(context.l10n.clubChatPreparing);
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
              'title': (_club?['name'] ?? context.l10n.clubChat).toString(),
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
        _snack(_imageError(e));
      }
    } catch (_) {
      if (mounted) _snack(context.l10n.clubImagePickFailed);
    }
  }

  Future<void> _post() async {
    final text = _text.text.trim();
    if ((text.isEmpty && _image == null) || _sending) return;
    final uploadFailed = context.l10n.clubImageUploadFailed;
    setState(() => _sending = true);
    try {
      String? imageUrl;
      if (_image != null) {
        final up = await MultipartUploader(widget.session).upload('$_base/posts/upload', _image!);
        imageUrl = up is Map ? up['url']?.toString() : null;
        if (imageUrl == null) throw ApiError(0, 'UPLOAD', uploadFailed);
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
        title: Text(c.l10n.clubDeletePostTitle),
        content: Text(c.l10n.clubDeletePostMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.l10n.clubCancel)),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(c.l10n.clubDelete)),
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
      targetType: 'COMMUNITY', targetId: widget.communityId, title: context.l10n.clubReportClub);

  Future<void> _reportPost(Map<String, dynamic> p) => ReportSheet.show(context, widget.session,
      targetType: 'POST', targetId: (p['id'] as num).toInt(), title: context.l10n.clubReportPost);

  void _setTab(int i) {
    setState(() => _tab = i);
    if (i != 3 && !_cur.loaded) _refreshTab(reset: true);
  }

  Future<void> _refresh() async {
    await _load();
  }

  String _meta() {
    final c = _club!;
    final l10n = context.l10n;
    final parts = <String>[
      if ((c['category'] ?? '').toString().isNotEmpty) c['category'].toString(),
      l10n.clubMemberCount('${c['memberCount'] ?? 0}'),
      c['visibility'] == 'PRIVATE' ? l10n.clubPrivate : l10n.clubPublic,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget body;
    if (_error != null && _club == null) {
      body = Column(children: [
        BuHeader(title: context.l10n.clubTitle, onBack: () => Navigator.pop(context)),
        Expanded(child: ErrorView(error: _error!, onRetry: () {
          setState(() => _error = null);
          _load();
        })),
      ]);
    } else if (_club == null) {
      body = Column(children: [
        BuHeader(title: context.l10n.clubTitle, onBack: () => Navigator.pop(context)),
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
          PositionedDirectional(
            start: 20,
            top: MediaQuery.of(context).padding.top + 8,
            child: BuIconButton(icon: LucideIcons.arrowLeft, onTap: () => Navigator.pop(context), tooltip: context.l10n.clubBack),
          ),
          PositionedDirectional(
            end: 20,
            top: MediaQuery.of(context).padding.top + 8,
            child: _menu(),
          ),
        ],
      ),
    );
  }

  /// Kulüp seçenekleri (⋯): yönetim (yalnız yetkili), ayrılma (üye), şikâyet (sahip değilse).
  Widget _menu() {
    final pendingCount = _requests.items.length;
    final t = context.bu;
    return PopupMenuButton<String>(
      tooltip: context.l10n.clubOptions,
      color: t.sf,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: .4),
      shape: kulupMenuShape(context),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      onSelected: (v) {
        switch (v) {
          case 'edit':
            _edit();
          case 'event':
            Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => EventFormPage(session: widget.session, communityId: widget.communityId)));
          case 'requests':
            _openRequests();
          case 'members':
            _openMembers();
          case 'cover':
            _changeCover();
          case 'delete':
            _delete();
          case 'leave':
            _leave();
          case 'report':
            _reportClub();
        }
      },
      itemBuilder: (_) {
        final l10n = context.l10n;
        return [
          if (_isManager) ...[
            PopupMenuItem(value: 'event', height: 44, child: KulupMenuRow(l10n.eventListCreate)),
            PopupMenuItem(value: 'edit', height: 44, child: KulupMenuRow(l10n.clubEdit)),
            PopupMenuItem(
                value: 'requests',
                height: 44,
                child: KulupMenuRow(l10n.kulupdetayRequestsTitle, count: pendingCount)),
            PopupMenuItem(value: 'members', height: 44, child: KulupMenuRow(l10n.clubManageMembers)),
            PopupMenuItem(value: 'cover', height: 44, child: KulupMenuRow(l10n.clubChangeCover)),
          ],
          if (_isManager && (_isOwner || _isMember)) const PopupMenuDivider(height: 9),
          if (_isOwner) PopupMenuItem(value: 'delete', height: 44, child: KulupMenuRow(l10n.clubDeleteClub, danger: true)),
          if (_isMember) PopupMenuItem(value: 'leave', height: 44, child: KulupMenuRow(l10n.clubLeave, danger: true)),
          if (!_isOwner) PopupMenuItem(value: 'report', height: 44, child: KulupMenuRow(l10n.clubReportClub)),
        ];
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: t.sf,
          shape: BoxShape.circle,
          border: Border.all(color: t.bd),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Icon(LucideIcons.ellipsis, size: 20, color: t.ink),
      ),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap, String tip) => Tooltip(
        message: tip,
        child: Material(
          color: Colors.black.withValues(alpha: .45),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 44, height: 44, child: Icon(buDirIcon(context, icon), size: 20, color: Colors.white)),
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
                      style: BuType.title.copyWith(color: t.pr)),
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
                    style: BuType.display.copyWith(letterSpacing: -.3, color: t.ink)),
                const SizedBox(height: 4),
                Text(_meta(), style: BuType.caption.copyWith(color: t.mut)),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(desc, style: BuType.body.copyWith(height: 1.5, color: t.ink)),
                ],
                if (_isMember) ...[
                  const SizedBox(height: 14),
                  KulupPillButton(label: context.l10n.clubChat, icon: LucideIcons.messageCircle, busy: _busy, onPressed: _openChat),
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
      // Ayrılma eylemi belirgin değil: ⋯ menüsündeki "Kulüpten ayrıl".
      return KulupPillButton(
          label: context.l10n.clubIsMember, icon: LucideIcons.check, kind: KulupPillKind.soft, staticLook: true);
    }
    if (_isPending) {
      return KulupPillButton(
          label: context.l10n.clubRequestSent, kind: KulupPillKind.outline, busy: _busy, onPressed: _withdraw);
    }
    if (_status == 'BANNED') {
      return KulupPillButton(label: context.l10n.clubCannotJoin, kind: KulupPillKind.outline, staticLook: true);
    }
    return KulupPillButton(
        label: _club!['joinPolicy'] == 'APPROVAL' ? context.l10n.clubSendJoinRequest : context.l10n.clubJoin,
        busy: _busy,
        onPressed: _join);
  }

  Widget _tabs(BuTokens t) {
    final l10n = context.l10n;
    final names = [l10n.clubTabPosts, l10n.clubTabEvents, l10n.clubTabMembers, l10n.clubTabPolls];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
      child: Row(
        children: [
          for (var i = 0; i < names.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == _tab,
                child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setTab(i),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: i == _tab ? t.pr : Colors.transparent, width: 2))),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(names[i],
                        maxLines: 1, style: BuType.bodyStrong.copyWith(color: i == _tab ? t.pr : t.mut)),
                  ),
                ),
              )),
            ),
        ],
      ),
    );
  }

  List<Widget> _content(BuTokens t) {
    if (_tab == 3) {
      return [
        PollClubSection(
            key: ValueKey('polls-$_pollGen'),
            session: widget.session,
            communityId: widget.communityId,
            canCreate: _isManager),
      ];
    }
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
        0 => (LucideIcons.messageSquare, context.l10n.clubNoPosts),
        1 => (LucideIcons.calendarX, context.l10n.clubNoEvents),
        _ => (LucideIcons.users, context.l10n.clubNoMembers),
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
      out.add(Center(child: TextButton(onPressed: _more, child: Text(context.l10n.clubLoadFailedRetry))));
    }
    return out;
  }

  Widget _composer(BuTokens t) {
    final l10n = context.l10n;
    final words = postWordCount(_text.text);
    final ok = postTextOk(_text.text);
    final canSend = !_sending && ok && (_text.text.trim().isNotEmpty || _image != null);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: BuCard(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_image != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8, end: 8, top: 4),
                child: Stack(
                  alignment: AlignmentDirectional.topEnd,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(_image!.bytes,
                          width: double.infinity, height: 150, fit: BoxFit.cover, gaplessPlayback: true),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: _glassBtn(LucideIcons.x, () => setState(() => _image = null), l10n.clubRemoveImage),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 1,
                    onChanged: (_) => setState(() {}),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(kPostMaxChars),
                      FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
                    ],
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => canSend ? _post() : null,
                    style: BuType.body.copyWith(fontSize: 14.5, color: t.ink),
                    decoration: InputDecoration(
                      hintText: l10n.clubWriteHint,
                      hintStyle: TextStyle(color: t.mut),
                      isCollapsed: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                _squareBtn(t, LucideIcons.image, _sending ? null : _pickImage, l10n.clubAddImage, filled: false),
                const SizedBox(width: 6),
                _squareBtn(t, LucideIcons.send, canSend ? _post : null, l10n.clubShare, filled: true),
              ],
            ),
            if (_text.text.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 4, end: 8),
                child: Text(
                  ok
                      ? l10n.gonderiWordCount(words.toString(), kPostMaxWords.toString())
                      : l10n.gonderiWordLimit(kPostMaxWords.toString()),
                  style: BuType.caption.copyWith(color: ok ? t.mut : t.pr),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 44 dp, 14 dp köşeli kare ikon düğmesi (yazma kutusu).
  Widget _squareBtn(BuTokens t, IconData icon, VoidCallback? onTap, String tip, {required bool filled}) => Semantics(
        button: true,
        enabled: onTap != null,
        label: tip,
        child: Tooltip(
          message: tip,
          excludeFromSemantics: true,
          child: Material(
            color: filled ? (onTap == null ? t.pr.withValues(alpha: .5) : t.pr) : t.bg,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: filled ? t.onPr : t.ink)),
            ),
          ),
        ),
      );

  /// Başvurular özeti: ayrı sayfada yönetilir.
  Widget _requestsSection(BuTokens t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: BuCard(
          onTap: _openRequests,
          color: t.soft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(LucideIcons.inbox, size: 20, color: t.pr),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    context.l10n.kulupdetayPendingBanner('${_requests.items.length}${_requests.next != null ? '+' : ''}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.bodyStrong.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
              ),
              Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.pr),
            ],
          ),
        ),
      );

  Widget _postMenu(BuTokens t, Map<String, dynamic> p) {
    final pinned = p['pinned'] == true;
    return PopupMenuButton<String>(
      tooltip: context.l10n.clubPostActions,
      icon: Icon(LucideIcons.ellipsis, size: 16, color: t.mut),
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
      itemBuilder: (_) {
        final l10n = context.l10n;
        return [
          if (_isManager) PopupMenuItem(value: 'pin', child: Text(pinned ? l10n.clubUnpin : l10n.clubPin)),
          if (p['canDelete'] == true) PopupMenuItem(value: 'delete', child: Text(l10n.clubDelete)),
          if (_isMember && (p['authorId'] as num?)?.toInt() != widget.session.userId)
            PopupMenuItem(value: 'report', child: Text(l10n.clubReport)),
        ];
      },
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
              KulupAvatar(name: p['authorName']?.toString(), url: p['authorAvatarUrl']?.toString(), size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((p['authorName'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BuType.bodyStrong.copyWith(color: t.ink)),
                    Text(relativeTime(p['createdAt']?.toString()), style: BuType.caption.copyWith(color: t.mut)),
                  ],
                ),
              ),
              if (pinned) ...[BuBadge(context.l10n.clubPinned, soft: true), const SizedBox(width: 6)],
              if (_isMember) _postMenu(t, p),
            ],
          ),
          if ((p['text'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(p['text'].toString(), style: BuType.body.copyWith(height: 1.5, color: t.ink)),
          ],
          if (img != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(img,
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      height: 130,
                      color: t.sf2,
                      alignment: Alignment.center,
                      child: Icon(LucideIcons.image, size: 27, color: t.mut))),
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
            child: Icon(LucideIcons.calendar, color: t.onSoft, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((e['title'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.bodyStrong.copyWith(color: t.ink)),
                const SizedBox(height: 2),
                Text(
                    [
                      niceDate(e['startsAt']?.toString()),
                      if ((e['location'] ?? '').toString().isNotEmpty) e['location'].toString(),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.caption.copyWith(color: t.mut)),
              ],
            ),
          ),
          Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: t.mut),
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
          KulupAvatar(name: m['displayName']?.toString(), url: m['avatarUrl']?.toString(), size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Text((m['displayName'] ?? context.l10n.clubUser).toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BuType.bodyStrong.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
          ),
          if (role == 'OWNER' || role == 'ADMIN') KulupRoleBadge(context.l10n.clubRoleOwner),
          if (role == 'MODERATOR') KulupRoleBadge(context.l10n.clubRoleModerator),
        ],
      ),
    );
  }
}

/// Kulübü silmeden önce son onay: uyarı + kulüp adını yazma.
class _DeleteClubDialog extends StatefulWidget {
  const _DeleteClubDialog({required this.name});

  final String name;

  @override
  State<_DeleteClubDialog> createState() => _DeleteClubDialogState();
}

class _DeleteClubDialogState extends State<_DeleteClubDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final match = _c.text.trim() == widget.name.trim();
    return AlertDialog(
      title: Text(context.l10n.clubDeleteClub),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.clubDeleteBody,
                style: BuType.body.copyWith(color: t.ink)),
            const SizedBox(height: 12),
            Text(context.l10n.clubDeleteTypeName(widget.name), style: BuType.caption.copyWith(color: t.mut)),
            const SizedBox(height: 8),
            TextField(
              controller: _c,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: context.l10n.clubNameHint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.clubCancel)),
        TextButton(
          onPressed: match ? () => Navigator.pop(context, true) : null,
          child: Text(context.l10n.clubDelete, style: match ? TextStyle(color: t.pr) : null),
        ),
      ],
    );
  }
}
