import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/report_sheet.dart';
import '../profile/user_profile_page.dart';
import 'chat_info_media.dart';
import 'chat_info_members.dart';
import 'chat_info_tabs.dart';
import 'chat_media_viewer.dart';
import 'sohbety_add_members.dart';
import 'sohbety_widgets.dart';

/// Sohbet bilgisi: avatar + başlık + hızlı eylemler, medya önizlemesi, üyeler, çıkış/engel/şikâyet.
///
/// Sonuç: `Navigator.pop(context, 'search')` (sohbette ara), `'left'` (gruptan ayrıldı).
/// Backend'de ayrı bir medya listesi yok; görseller mesaj geçmişi sayfalanarak süzülür ([ChatMediaFeed]).
class ChatInfoPage extends StatefulWidget {
  const ChatInfoPage({
    super.key,
    required this.session,
    required this.conversation,
    this.members = const [],
    this.subtitle,
    this.onOpenRoom,
    this.saveImage = saveChatImageToGallery,
    this.pickAvatar,
    this.uploadAvatar,
  });

  final Session session;
  final Map<String, dynamic> conversation;
  final List<Map<String, dynamic>> members;

  /// Başlık altındaki durum satırı (çevrimiçi / son görülme).
  final String? subtitle;

  /// Kulüp/etkinlik odasında ilgili sayfayı açar; null ise düğme gösterilmez.
  final VoidCallback? onOpenRoom;
  final SaveImage saveImage;

  /// Grup fotoğrafı seçici (varsayılan: galeri). Testlerde değiştirilir.
  final Future<PreparedImage?> Function()? pickAvatar;

  /// `PUT /conversations/{id}/avatar` yükleyici (varsayılan: multipart PUT).
  final Future<dynamic> Function(String path, PreparedImage image)?
      uploadAvatar;

  @override
  State<ChatInfoPage> createState() => _ChatInfoPageState();
}

class _ChatInfoPageState extends State<ChatInfoPage> {
  static const _previewCount = 9;

  late final Map<String, dynamic> _conv =
      Map<String, dynamic>.from(widget.conversation);
  late final List<Map<String, dynamic>> _members = List.of(widget.members);
  late final ChatMediaFeed _feed;
  int _avatarVersion = 0;

  static const _searchThreshold = 12;
  final _scroll = ScrollController();
  late InfoSection _active =
      _type == 'DIRECT' ? InfoSection.media : InfoSection.members;
  String _query = '';

  ApiClient get _api => widget.session.api;
  int get _cid => (_conv['id'] as num).toInt();
  String get _type => (_conv['type'] as String?) ?? 'GROUP';
  bool get _direct => _type == 'DIRECT';
  bool get _room => _type == 'CLUB' || _type == 'EVENT';
  bool get _userGroup => !_direct && !_room;
  bool get _admin => _userGroup && _conv['admin'] == true;
  bool get _blocked => _conv['blocked'] == true;
  bool get _muted => _conv['muted'] == true || _conv['mutedForever'] == true;
  Map<String, dynamic>? get _peer => _conv['peer'] is Map
      ? Map<String, dynamic>.from(_conv['peer'] as Map)
      : null;
  int? get _peerId => (_peer?['id'] as num?)?.toInt();

  String get _title => _direct
      ? ((_peer?['displayName'] as String?) ??
          (_conv['title'] as String?) ??
          context.l10n.chatInfoChat)
      : ((_conv['title'] as String?) ?? context.l10n.chatInfoGroup);

  String? get _avatarUrl {
    final String? raw = _direct
        ? (_peer?['avatarUrl'] as String?)
        : (_conv['avatarUrl'] as String?);
    if (raw == null || raw.isEmpty) return null;
    if (_avatarVersion == 0) return raw;
    return '$raw${raw.contains('?') ? '&' : '?'}v=$_avatarVersion';
  }

  Map<String, String> get _headers {
    final tok = _api.tokens?.access;
    return tok == null ? const {} : {'Authorization': 'Bearer $tok'};
  }

  @override
  void initState() {
    super.initState();
    _feed =
        ChatMediaFeed(api: _api, conversationId: _cid, senderName: _senderName);
    _feed.addListener(() {
      if (mounted) setState(() {});
    });
    _feed.load(first: true, want: _previewCount);
    if (!_direct && _members.isEmpty) _loadMembers();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _feed.dispose();
    super.dispose();
  }

  String? _senderName(Map<String, dynamic> m) {
    final id = (m['senderId'] as num?)?.toInt();
    if (id == null) return null;
    if (id == widget.session.userId) return context.l10n.chatInfoYou;
    for (final mem in _members) {
      if ((mem['userId'] as num?)?.toInt() == id) {
        return mem['displayName'] as String?;
      }
    }
    if (_direct) return _peer?['displayName'] as String?;
    return (m['senderName'] as String?) ?? context.l10n.chatInfoUser;
  }

  Future<void> _loadMembers() async {
    try {
      final d = await _api.get('/conversations/$_cid');
      if (!mounted || d is! Map) return;
      final ms = (d['members'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final c = d['conversation'];
      setState(() {
        _members
          ..clear()
          ..addAll(ms);
        if (c is Map) _merge(Map<String, dynamic>.from(c));
      });
    } catch (_) {}
  }

  /// Sunucu cevabını yerel kopyaya ve (değiştirilebilirse) çağıranın haritasına yansıtır.
  void _merge(Map<String, dynamic> patch) {
    _conv.addAll(patch);
    try {
      widget.conversation.addAll(patch);
    } catch (_) {}
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final t = context.bu;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: t.sf,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: t.ink)),
        content: Text(body,
            style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: t.mut)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(context.l10n.chatInfoCancel,
                  style: TextStyle(color: t.mut))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(action,
                  style: TextStyle(color: t.pr, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    return ok == true;
  }

  // ---- medya ----

  void _openViewer(int index) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatMediaViewer(
          items: List.of(_feed.items),
          headers: _headers,
          initialIndex: index,
          saveImage: widget.saveImage,
        ),
      ),
    );
  }

  void _openAllMedia() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => ChatMediaGridPage(
              feed: _feed, headers: _headers, onOpen: _openViewer)),
    );
  }

  // ---- eylemler ----

  /// Anahtar: açıkken sessizi kaldırır, kapalıyken süre seçtirir.
  Future<void> _toggleMute() async {
    if (_muted) {
      await _applyMute('off');
    } else {
      await _muteSheet();
    }
  }

  Future<void> _muteSheet() async {
    final t = context.bu;
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.bg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BuMenuRow(
              icon: LucideIcons.bellOff,
              label: context.l10n.chatInfoMute8h,
              showChevron: false,
              onTap: () => Navigator.pop(c, '480')),
          BuMenuRow(
              icon: LucideIcons.bellOff,
              label: context.l10n.chatInfoMute1w,
              showChevron: false,
              onTap: () => Navigator.pop(c, '10080')),
          BuMenuRow(
              icon: LucideIcons.bellOff,
              label: context.l10n.chatInfoMuteForever,
              showChevron: false,
              onTap: () => Navigator.pop(c, 'forever')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    await _applyMute(pick);
  }

  Future<void> _applyMute(String pick) async {
    try {
      dynamic res;
      if (pick == 'off') {
        final r = await _api.delete('/conversations/$_cid/mute');
        res = {
          if (r is Map) ...Map<String, dynamic>.from(r),
          'muted': false,
          'mutedForever': false,
          'mutedUntil': null,
        };
      } else {
        res = await _api.put(
            '/conversations/$_cid/mute',
            pick == 'forever'
                ? {'forever': true}
                : {'durationMinutes': int.parse(pick)});
        if (res is! Map || res.isEmpty) {
          res = {'muted': true, 'mutedForever': pick == 'forever'};
        }
        if (pick != 'forever' && res['mutedUntil'] == null) {
          res = {
            ...Map<String, dynamic>.from(res),
            'mutedUntil': DateTime.now()
                .toUtc()
                .add(Duration(minutes: int.parse(pick)))
                .toIso8601String(),
          };
        }
      }
      if (mounted) {
        setState(() => _merge(Map<String, dynamic>.from(res as Map)));
      }
      _toast(pick == 'off'
          ? context.l10n.chatInfoUnmuted
          : context.l10n.chatInfoMuted);
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _toggleArchive() async {
    final archived = _conv['archived'] == true;
    try {
      if (archived) {
        await _api.delete('/conversations/$_cid/archive');
      } else {
        await _api.put('/conversations/$_cid/archive', {'keepArchived': false});
      }
      if (mounted) setState(() => _merge({'archived': !archived}));
      _toast(archived
          ? context.l10n.chatInfoUnarchived
          : context.l10n.chatInfoArchived);
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _leave() async {
    if (!await _confirm(context.l10n.chatInfoLeaveTitle,
        context.l10n.chatInfoLeaveBody, context.l10n.chatInfoLeave)) {
      return;
    }
    try {
      await _api.post('/conversations/$_cid/leave');
      if (mounted) Navigator.pop(context, 'left');
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _toggleBlock() async {
    final pid = _peerId;
    if (pid == null) return;
    try {
      if (_blocked) {
        await _api.delete('/users/$pid/block');
        if (mounted) setState(() => _merge({'blocked': false}));
        _toast(context.l10n.chatInfoUnblocked);
      } else {
        if (!await _confirm(context.l10n.chatInfoBlockTitle,
            context.l10n.chatInfoBlockBody, context.l10n.chatInfoBlock)) {
          return;
        }
        await _api.post('/users/$pid/block');
        if (mounted) setState(() => _merge({'blocked': true}));
        _toast(context.l10n.chatInfoBlocked);
      }
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _report() async {
    final pid = _peerId;
    if (pid == null) return;
    await ReportSheet.show(context, widget.session,
        targetType: 'USER', targetId: pid, title: context.l10n.chatInfoReportUser);
  }

  Future<bool> _removeMember(Map<String, dynamic> m) async {
    final name = (m['displayName'] as String?) ?? context.l10n.chatInfoUser;
    if (!await _confirm(
        context.l10n.chatInfoRemoveMemberTitle,
        context.l10n.chatInfoRemoveMemberBody(name),
        context.l10n.chatInfoRemove)) {
      return false;
    }
    try {
      await _api.delete(
          '/conversations/$_cid/members/${(m['userId'] as num).toInt()}');
      if (mounted) {
        setState(() {
          _members.remove(m);
          _conv['memberCount'] = _members.length;
        });
      }
      return true;
    } catch (e) {
      _toast(errorText(e));
      return false;
    }
  }

  // ---- grup adı / fotoğrafı (yalnız kullanıcı grubu yöneticisi) ----

  Future<void> _rename() async {
    final name = await showDialog<String>(
        context: context,
        builder: (_) =>
            _RenameDialog(initial: (_conv['title'] as String?) ?? ''));
    if (name == null || !mounted) return;
    try {
      final res = await _api.patch('/conversations/$_cid', {'title': name});
      if (!mounted) return;
      setState(() => _merge(res is Map && res['title'] != null
          ? Map<String, dynamic>.from(res)
          : {'title': name}));
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _avatarSheet() async {
    final t = context.bu;
    final has = _avatarUrl != null;
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.bg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BuMenuRow(
              icon: LucideIcons.image,
              label: context.l10n.chatInfoPickGallery,
              showChevron: false,
              onTap: () => Navigator.pop(c, 'pick')),
          if (has)
            BuMenuRow(
                icon: LucideIcons.trash2,
                label: context.l10n.chatInfoRemovePhoto,
                danger: true,
                showChevron: false,
                onTap: () => Navigator.pop(c, 'remove')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    try {
      if (pick == 'remove') {
        await _api.delete('/conversations/$_cid/avatar');
        if (mounted) setState(() => _merge({'avatarUrl': null}));
        return;
      }
      PreparedImage? img;
      try {
        img = await (widget.pickAvatar ??
            () => ImageService()
                .pickPrepared(ImageSource.gallery, avatar: true))();
      } on ImageException catch (e) {
        _toast(e.code == 'TOO_LARGE'
            ? context.l10n.chatInfoImageTooLarge
            : context.l10n.chatInfoImageTypeOnly);
        return;
      }
      if (img == null || !mounted) return;
      final path = '/conversations/$_cid/avatar';
      final res = await (widget.uploadAvatar ??
          (p, i) => putMultipartImage(widget.session, p, i))(path, img);
      if (!mounted) return;
      setState(() {
        _avatarVersion++;
        if (res is Map && res['avatarUrl'] != null) {
          _merge({'avatarUrl': res['avatarUrl']});
        }
      });
    } catch (e) {
      _toast(errorText(e));
    }
  }

  // ---- üye ekleme (yalnız kullanıcı grubu yöneticisi) ----

  Future<void> _addMembers() async {
    final have = {
      for (final m in _members) (m['userId'] as num?)?.toInt() ?? -1,
    };
    final room = 50 - _members.length;
    if (room <= 0) {
      _toast(context.l10n.chatMiscGroupMax);
      return;
    }
    final ids = await showAddMembersSheet(context, widget.session,
        exclude: have, max: room > 49 ? 49 : room);
    if (ids == null || ids.isEmpty || !mounted) return;
    try {
      await _api.post('/conversations/$_cid/members', {'userIds': ids});
      await _loadMembers();
      _toast(context.l10n.sohbetyAddDone);
    } catch (e) {
      _toast(errorText(e));
    }
  }

  // ---- arayüz ----

  List<InfoSection> get _sections => [
        if (!_direct) InfoSection.members,
        InfoSection.media,
        InfoSection.settings,
      ];

  void _onSegment(InfoSection s) {
    if (s != _active) setState(() => _active = s);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        SohbetyHeader(
            title: context.l10n.chatInfoTitle,
            onBack: () => Navigator.maybePop(context)),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 220),
            builder: (c, v, child) => Opacity(opacity: v, child: child),
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(children: [
                    if (_active == InfoSection.settings)
                      _compactHeader(t)
                    else ...[_header(t), _actions(t)],
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: InfoSegmentBar(
                          sections: _sections,
                          active: _active,
                          onSelect: _onSegment),
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: switch (_active) {
                      InfoSection.members => _membersTab(t),
                      InfoSection.media => _mediaTab(t),
                      InfoSection.settings => _settingsTab(t),
                    },
                  ),
                ),
                SliverToBoxAdapter(
                    child: SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 32)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  /// Başlık altı satırları: birebirde bölüm (+ durum), grupta "tür · n üye".
  List<String> get _subLines {
    final l = context.l10n;
    if (_direct) {
      final dept =
          (_peer?['department'] ?? _peer?['faculty'] ?? '').toString().trim();
      final s = widget.subtitle;
      return [
        if (dept.isNotEmpty) dept,
        if (s != null && s.isNotEmpty) s,
      ];
    }
    final n = (_conv['memberCount'] as num?)?.toInt() ?? _members.length;
    final kind = switch (_type) {
      'CLUB' => l.chatInfoClubRoom,
      'EVENT' => l.chatInfoEventRoom,
      _ => l.chatInfoGroup,
    };
    return [if (n > 0) '$kind · ${l.chatInfoMemberCount(n.toString())}' else kind];
  }

  Widget _avatar(BuTokens t, double size, {bool ring = false}) {
    final tok = _api.tokens?.access;
    final au = _avatarUrl;
    return SohbetyAvatar(
      name: _title,
      url: au,
      size: size,
      ring: ring,
      headers: (tok != null && au != null && au.startsWith('/api/'))
          ? {'Authorization': 'Bearer $tok'}
          : null,
    );
  }

  /// Ayarlar sekmesinde küçük başlık: 56 px avatar + ad + alt satır.
  Widget _compactHeader(BuTokens t) {
    final subs = _subLines;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _avatar(t, 56),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: t.ink)),
                if (subs.isNotEmpty)
                  Text(subs.first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Inter', fontSize: 13, color: t.mut)),
              ]),
        ),
      ]),
    );
  }

  Widget _header(BuTokens t) {
    final subs = _subLines;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          _avatar(t, 96, ring: true),
          if (_admin)
            PositionedDirectional(
              end: -2,
              bottom: -2,
              child: Tooltip(
                message: context.l10n.chatInfoChangePhoto,
                child: Material(
                  color: t.pr,
                  shape: CircleBorder(side: BorderSide(color: t.bg, width: 3)),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _avatarSheet,
                    child: Padding(
                        padding: const EdgeInsets.all(8),
                        child:
                            Icon(LucideIcons.camera, size: 14.5, color: t.onPr)),
                  ),
                ),
              ),
            ),
        ]),
        SizedBox(height: _admin ? 4 : 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_admin) const SizedBox(width: 44),
          Flexible(
              child: Text(_title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: t.ink))),
          if (_admin)
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: context.l10n.chatInfoEditName,
                padding: EdgeInsets.zero,
                onPressed: _rename,
                icon: Icon(LucideIcons.pencil, size: 18, color: t.mut),
              ),
            ),
        ]),
        for (final s in subs)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(s,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: t.mut)),
          ),
      ]),
    );
  }

  /// Hızlı eylemler: Ara, (birebirde) Profil, (odada) Kulüp/Etkinlik sayfası.
  Widget _actions(BuTokens t) {
    final roomLabel = _type == 'CLUB'
        ? context.l10n.chatInfoClub
        : context.l10n.chatInfoEvent;
    final items = <Widget>[
      _QuickAction(
          icon: LucideIcons.search,
          label: context.l10n.chatInfoSearch,
          onTap: () => Navigator.pop(context, 'search')),
      if (_direct && _peerId != null)
        _QuickAction(
            icon: LucideIcons.user,
            label: context.l10n.sohbetyProfile,
            onTap: () => _openProfile(_peer!)),
      if (widget.onOpenRoom != null)
        _QuickAction(
            icon: LucideIcons.arrowUpRight,
            label: roomLabel,
            onTap: widget.onOpenRoom!),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 12,
          children: items),
    );
  }

  // ---- Üyeler ----

  Widget _membersTab(BuTokens t) {
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? _members
        : _members
            .where((m) =>
                ((m['displayName'] as String?) ?? '').toLowerCase().contains(q))
            .toList();
    final n = _members.length;
    final rows = <Widget>[
      if (_admin)
        SohbetyRow(
          key: const ValueKey('info-add-member'),
          onTap: _addMembers,
          child: Row(children: [
            const SohbetyTile(icon: LucideIcons.plus),
            const SizedBox(width: 12),
            Expanded(
                child: Text(context.l10n.sohbetyAddMember,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.pr))),
          ]),
        ),
      for (final m in shown)
        ChatMemberRow(
          member: m,
          selfId: widget.session.userId,
          onTap: () => _openProfile(m),
          onRemove: _admin &&
                  (m['userId'] as num?)?.toInt() != widget.session.userId &&
                  !isAdminRole(m)
              ? () => _removeMember(m)
              : null,
        ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SohbetyLabel(sohbetyUpper(
          context,
          n == 0
              ? context.l10n.chatInfoMembers
              : context.l10n.chatInfoMembersDot(n.toString()))),
      if (n > _searchThreshold)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SohbetyField(
              hint: context.l10n.chatInfoSearchMember,
              height: 48,
              onChanged: (v) => setState(() => _query = v)),
        ),
      if (shown.isEmpty)
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
                _members.isEmpty
                    ? context.l10n.chatInfoNoMembers
                    : context.l10n.chatInfoNoResults,
                style: BuType.body.copyWith(color: t.mut))),
      if (rows.isNotEmpty) SohbetyCard(children: rows),
    ]);
  }

  // ---- Medya ----

  Widget _mediaTab(BuTokens t) {
    final f = _feed;
    final has = f.items.isNotEmpty;
    Widget body;
    if (f.loading) {
      body = const Padding(
          padding: EdgeInsets.symmetric(vertical: 40), child: LoadingView());
    } else if (f.error != null) {
      body = Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ErrorView(
              error: f.error!,
              onRetry: () => f.load(first: true, want: _previewCount)));
    } else if (!has) {
      body = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Text(context.l10n.chatInfoNoMedia,
              style: BuType.body.copyWith(color: t.mut)));
    } else {
      final shown = f.items.take(_previewCount).toList();
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          crossAxisCount: 3,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (var i = 0; i < shown.length; i++)
              ChatInfoThumb(
                  item: shown[i],
                  video: f.isVideo(shown[i]),
                  durationMs: f.videoMeta[shown[i].url],
                  headers: _headers,
                  onTap: () => _openViewer(i)),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          child: Material(
            color: t.sf,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: t.bd)),
            child: InkWell(
              customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onTap: _openAllMedia,
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Text(context.l10n.chatInfoSeeAllMedia,
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: t.pr)),
                ),
              ),
            ),
          ),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SohbetyLabel(sohbetyUpper(
          context,
          has
              ? context.l10n
                  .chatInfoMediaDot('${f.items.length}${f.more ? '+' : ''}')
              : context.l10n.chatInfoMedia)),
      body,
    ]);
  }

  String _muteStatus() {
    final l = context.l10n;
    if (!_muted) return l.chatInfoMuteOn;
    if (_conv['mutedForever'] == true) return l.chatInfoMutedAlways;
    final u = DateTime.tryParse((_conv['mutedUntil'] as String?) ?? '')?.toLocal();
    if (u != null) {
      final d = u.difference(DateTime.now());
      if (!d.isNegative) {
        final h = (d.inMinutes / 60).ceil();
        if (h >= 24) return l.chatInfoMutedDays((h / 24).ceil().toString());
        if (h >= 1) return l.chatInfoMutedHours(h.toString());
        return l.chatInfoMutedSoon;
      }
    }
    return l.chatInfoMutedLabel;
  }

  void _openProfile(Map<String, dynamic> m) {
    final id = (m['userId'] as num?)?.toInt() ?? (m['id'] as num?)?.toInt();
    if (id == null || id == widget.session.userId) return;
    openUserProfile(context, widget.session,
        userId: id,
        name: m['displayName'] as String?,
        avatarUrl: m['avatarUrl'] as String?,
        fromConversationId: _cid);
  }

  // ---- Ayarlar ----

  Widget _settingsTab(BuTokens t) {
    final archived = _conv['archived'] == true;
    final main = <Widget>[
      _SettingsRow(
        icon: _muted ? LucideIcons.bellOff : LucideIcons.bell,
        label: context.l10n.chatInfoMuteNotifications,
        sub: _muteStatus(),
        toggled: _muted,
        onTap: _toggleMute,
      ),
      _SettingsRow(
        icon: LucideIcons.archive,
        label: archived
            ? context.l10n.chatInfoUnarchive
            : context.l10n.chatInfoArchive,
        onTap: _toggleArchive,
      ),
      if (_conv['closed'] == true)
        _SettingsRow(
            icon: LucideIcons.lock,
            label: context.l10n.chatInfoClosed,
            sub: context.l10n.chatInfoClosedSub),
    ];
    final danger = <Widget>[
      if (_userGroup)
        _SettingsRow(
            icon: LucideIcons.logOut,
            label: context.l10n.chatInfoLeaveChat,
            danger: true,
            onTap: _leave),
      if (_direct)
        _SettingsRow(
            icon: LucideIcons.ban,
            label: _blocked
                ? context.l10n.chatInfoUnblock
                : context.l10n.chatInfoBlock,
            sub: _blocked ? null : context.l10n.chatInfoBlockBody,
            danger: true,
            onTap: _toggleBlock),
      if (_direct)
        _SettingsRow(
            icon: LucideIcons.flag,
            label: context.l10n.chatInfoReportUser,
            danger: true,
            onTap: _report),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SohbetyCard(children: main),
      if (danger.isNotEmpty) ...[
        const SizedBox(height: 16),
        SohbetyCard(children: danger),
      ],
    ]);
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow(
      {required this.icon,
      required this.label,
      this.sub,
      this.onTap,
      this.toggled,
      this.danger = false});

  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;
  final bool? toggled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: onTap != null,
      toggled: toggled,
      child: SohbetyRow(
        onTap: onTap,
        child: Row(children: [
          SohbetyTile(icon: icon, danger: danger),
          const SizedBox(width: 12),
          Expanded(
            child: SohbetyTexts(
                title: label,
                sub: sub,
                weight: FontWeight.w600,
                color: danger ? t.danger : t.ink),
          ),
        ]),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 72,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.sf,
                border: Border.all(color: t.bd),
                boxShadow: sohbetyShadow,
              ),
              child: Icon(icon, size: 20, color: t.ink),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.ink)),
          ]),
        ),
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _ctl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final v = _ctl.text.trim();
    return AlertDialog(
      backgroundColor: t.sf,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(context.l10n.chatInfoGroupName,
          style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: t.ink)),
      content: TextField(
        controller: _ctl,
        autofocus: true,
        maxLength: 60,
        onChanged: (_) => setState(() {}),
        cursorColor: t.pr,
        style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: t.ink),
        decoration: InputDecoration(
          hintText: context.l10n.chatInfoGroupName,
          filled: true,
          fillColor: t.bg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: t.bd)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: t.bd)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: t.pr)),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.chatInfoCancel,
                style: TextStyle(color: t.mut))),
        TextButton(
            onPressed: v.isEmpty ? null : () => Navigator.pop(context, v),
            child: Text(context.l10n.chatInfoSave,
                style: TextStyle(
                    color: v.isEmpty ? t.mut : t.pr, fontWeight: FontWeight.w700))),
      ],
    );
  }
}
