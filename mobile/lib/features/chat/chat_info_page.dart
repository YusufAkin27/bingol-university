import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/closed_conversations.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/report_sheet.dart';
import '../media_crop/media_crop.dart';
import '../profile/user_profile_page.dart';
import 'chat_info_media.dart';
import 'chat_info_members.dart';
import 'chat_info_parts.dart';
import 'chat_sheet_parts.dart';
import 'chat_media_viewer.dart';
import 'chatlist_widgets.dart';
import 'sohbety_add_members.dart';
import '../../core/academic_catalog.dart';

/// Sohbet bilgisi (Stitch 24): birebir, kullanıcı grubu ve kulüp/etkinlik odası için tek kaydırmalı sayfa.
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

  /// Çağıranın durum satırı (çevrimiçi / son görülme). Tasarımda bilgi sayfasında gösterilmez.
  final String? subtitle;

  /// Kulüp/etkinlik odasında ilgili sayfayı açar; null ise satır gösterilmez.
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
  /// Medya şeridi için istenen görsel sayısı; birebirde 4 karo, grupta 3 karo çizilir.
  static const _previewCount = 9;

  /// Üye önizlemesinde gösterilen satır sayısı (gerisi "Tümü" ile).
  static const _memberPreview = 4;

  late final Map<String, dynamic> _conv =
      Map<String, dynamic>.from(widget.conversation);
  late final List<Map<String, dynamic>> _members = List.of(widget.members);
  late final ChatMediaFeed _feed;
  Map<String, dynamic>? _profile;
  bool _membersFailed = false;
  int _avatarVersion = 0;

  ApiClient get _api => widget.session.api;
  int get _cid => (_conv['id'] as num).toInt();
  String get _type => (_conv['type'] as String?) ?? 'GROUP';
  bool get _direct => _type == 'DIRECT';
  bool get _room => _type == 'CLUB' || _type == 'EVENT';
  bool get _userGroup => !_direct && !_room;
  bool get _admin => _userGroup && _conv['admin'] == true;
  bool get _blocked => _conv['blocked'] == true;
  bool get _muted => _conv['muted'] == true || _conv['mutedForever'] == true;
  bool get _closed =>
      _conv['closed'] == true || ClosedConversations.instance.isClosed(_cid);
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
    if (_direct && _peerId != null) _loadPeerProfile();
  }

  @override
  void dispose() {
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

  /// Karşı kişinin bölüm/sınıf bilgisi (sohbet özetinde yok); alınamazsa alt satır boş kalır.
  Future<void> _loadPeerProfile() async {
    try {
      final d = await _api.get('/users/$_peerId');
      if (!mounted || d is! Map) return;
      setState(() => _profile = Map<String, dynamic>.from(d));
    } catch (_) {}
  }

  /// Sunucudan üyeleri çeker ve yerel listeyi günceller; hata atar.
  Future<List<Map<String, dynamic>>> _fetchMembers() async {
    final d = await _api.get('/conversations/$_cid');
    if (d is! Map) return _members;
    final ms = (d['members'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final c = d['conversation'];
    if (mounted) {
      setState(() {
        _membersFailed = false;
        _members
          ..clear()
          ..addAll(ms);
        if (c is Map) _merge(Map<String, dynamic>.from(c));
      });
    }
    return List.of(_members);
  }

  Future<void> _loadMembers() async {
    try {
      await _fetchMembers();
    } catch (_) {
      if (mounted) setState(() => _membersFailed = true);
    }
  }

  /// Sunucu cevabını yerel kopyaya ve (değiştirilebilirse) çağıranın haritasına yansıtır.
  void _merge(Map<String, dynamic> patch) {
    _conv.addAll(patch);
    try {
      widget.conversation.addAll(patch);
    } catch (_) {}
  }

  void _toast(String text, {BuToastKind kind = BuToastKind.info}) {
    if (!mounted) return;
    BuToast.show(context, text, kind: kind);
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

  /// Açıkken sessizi kaldırır, kapalıyken süre seçtirir.
  Future<void> _toggleMute() async {
    if (_muted) {
      await _applyMute('off');
    } else {
      await _muteSheet();
    }
  }

  Future<void> _muteSheet() async {
    final pick = await showChatMuteSheet(context, chatName: _title);
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
      if (!mounted) return;
      setState(() => _merge(Map<String, dynamic>.from(res as Map)));
      _toast(pick == 'off'
          ? context.l10n.chatInfoUnmuted
          : context.l10n.chatInfoMuted);
    } catch (e) {
      _toast(errorText(e), kind: BuToastKind.error);
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
      if (!mounted) return;
      setState(() => _merge({'archived': !archived}));
      _toast(archived
          ? context.l10n.chatInfoUnarchived
          : context.l10n.chatInfoArchived);
    } catch (e) {
      _toast(errorText(e), kind: BuToastKind.error);
    }
  }

  Future<void> _leave() async {
    final l = context.l10n;
    if (!await showChatInfoConfirm(context,
        icon: LucideIcons.logOut,
        title: l.chatInfoLeaveTitle,
        body: l.chatInfoLeaveBody,
        confirmLabel: l.chatInfoLeave,
        confirmIcon: LucideIcons.logOut,
        layout: ChatConfirmLayout.iconBeside,
        cancelLabel: l.chatInfoCancel)) {
      return;
    }
    try {
      await _api.post('/conversations/$_cid/leave');
      if (!mounted) return;
      Navigator.pop(context, 'left');
    } catch (e) {
      _toast(errorText(e), kind: BuToastKind.error);
    }
  }

  Future<void> _toggleBlock() async {
    final pid = _peerId;
    if (pid == null) return;
    final l = context.l10n;
    try {
      if (_blocked) {
        await _api.delete('/users/$pid/block');
        if (!mounted) return;
        setState(() => _merge({'blocked': false}));
        _toast(l.chatInfoUnblocked);
      } else {
        if (!await showChatInfoConfirm(context,
            icon: LucideIcons.ban,
            title: l.chatInfoBlockTitle,
            body: l.chatInfoBlockBody,
            confirmLabel: l.chatInfoBlock,
            cancelLabel: l.chatInfoCancel)) {
          return;
        }
        await _api.post('/users/$pid/block');
        if (!mounted) return;
        setState(() => _merge({'blocked': true}));
        _toast(context.l10n.chatInfoBlocked);
      }
    } catch (e) {
      _toast(errorText(e), kind: BuToastKind.error);
    }
  }

  Future<void> _report() async {
    final pid = _peerId;
    if (pid == null) return;
    await ReportSheet.show(context, widget.session,
        targetType: 'USER', targetId: pid, title: context.l10n.chatInfoReportUser);
  }

  /// Onay (Stitch 24-5) + çıkarma. Başarılıysa true; üye yerel listeden düşer.
  Future<bool> _removeMember(Map<String, dynamic> m) async {
    final l = context.l10n;
    final name = (m['displayName'] as String?) ?? l.chatInfoUser;
    if (!await showChatInfoConfirm(context,
        icon: LucideIcons.userMinus,
        title: l.chatInfoRemoveMemberTitle,
        body: l.chatInfoRemoveMemberBody(name),
        bold: name,
        confirmLabel: l.chatInfoRemove,
        confirmIcon: LucideIcons.trash2,
        cancelLabel: l.chatInfoCancel)) {
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
        _toast(context.l10n.p09MemberRemoved(name), kind: BuToastKind.success);
      }
      return true;
    } catch (e) {
      _toast(errorText(e), kind: BuToastKind.error);
      return false;
    }
  }

  // ---- grup adı / fotoğrafı (yalnız kullanıcı grubu yöneticisi) ----

  Future<void> _rename() async {
    final name = await showChatRenameDialog(context, initial: (_conv['title'] as String?) ?? '');
    if (name == null || !mounted) return;
    try {
      final res = await _api.patch('/conversations/$_cid', {'title': name});
      if (!mounted) return;
      setState(() => _merge(res is Map && res['title'] != null
          ? Map<String, dynamic>.from(res)
          : {'title': name}));
    } catch (e) {
      _toast(errorText(e), kind: BuToastKind.error);
    }
  }

  /// Grup fotoğrafı (22-6): kaynak sayfası (Galeriden seç / Fotoğraf çek / kaldır) + 1:1 daire kırpma.
  Future<void> _avatarSheet() async {
    final has = _avatarUrl != null;
    String? error;
    while (mounted) {
      final tok = _api.tokens?.access;
      final au = _avatarUrl;
      final src = await showChatPhotoSheet(context,
          name: _title,
          avatarUrl: au,
          headers: (tok != null && au != null && au.startsWith('/api/')) ? {'Authorization': 'Bearer $tok'} : null,
          removable: has,
          error: error);
      if (src == null || !mounted) return;
      error = null;
      try {
        if (src == PhotoSource.remove) {
          await _api.delete('/conversations/$_cid/avatar');
          if (mounted) setState(() => _merge({'avatarUrl': null}));
          return;
        }
        PreparedImage? img;
        if (widget.pickAvatar != null) {
          img = await widget.pickAvatar!();
        } else {
          final bytes = await pickAndCrop(context, CropSpec.profile(previewName: _title),
              source: src == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery);
          if (bytes != null) img = await ImageService().prepare(bytes, avatar: true);
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
        return;
      } on ImageException catch (e) {
        if (!mounted) return;
        // Biçim/boyut hatası: kaynak sayfası uyarıyla yeniden açılır.
        error = e.code == 'TOO_LARGE' ? context.l10n.chatInfoImageTooLarge : context.l10n.chatInfoImageTypeOnly;
      } catch (e) {
        _toast(errorText(e), kind: BuToastKind.error);
        return;
      }
    }
  }

  // ---- üye ekleme (yalnız kullanıcı grubu yöneticisi) ----

  /// Üye seçtirir ve ekler; güncel listeyi döner (iptal/hatada null).
  Future<List<Map<String, dynamic>>?> _addMembers() async {
    final have = {
      for (final m in _members) (m['userId'] as num?)?.toInt() ?? -1,
    };
    final room = 50 - _members.length;
    if (room <= 0) {
      _toast(context.l10n.chatMiscGroupMax);
      return null;
    }
    final ids = await showAddMembersSheet(context, widget.session,
        exclude: have, max: room > 49 ? 49 : room);
    if (ids == null || ids.isEmpty || !mounted) return null;
    try {
      await _api.post('/conversations/$_cid/members', {'userIds': ids});
      await _loadMembers();
      if (!mounted) return null;
      _toast(context.l10n.sohbetyAddDone, kind: BuToastKind.success);
      return List.of(_members);
    } catch (e) {
      _toast(errorText(e), kind: BuToastKind.error);
      return null;
    }
  }

  void _openMembers() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatMembersPage(
          members: List.of(_members),
          selfId: widget.session.userId,
          onRemove: _admin ? _removeMember : null,
          onAdd: _admin ? _addMembers : null,
          onReload: _fetchMembers,
          onOpenProfile: _openProfile,
        ),
      ),
    );
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

  // ---- arayüz ----

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final List<Widget> body;
    if (_direct) {
      body = _directBody(t);
    } else if (_room) {
      body = _roomBody(t);
    } else {
      body = _groupBody(t);
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ChatInfoBar(title: context.l10n.chatInfoTitle),
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 32),
            children: body,
          ),
        ),
      ]),
    );
  }

  Widget _pad(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: kChatInfoMargin),
      child: child);

  /// Tam genişlik bantlar, aralarında 24 dp sayfa zemini (Stitch v3).
  Widget _gap(List<Widget> cards) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 24),
          cards[i],
        ],
      ]);

  /// Ara · Sessize al · Arşivle.
  Widget _quickRow({required bool dense}) {
    final l = context.l10n;
    final archived = _conv['archived'] == true;
    return ChatInfoQuickRow(dense: dense, actions: [
      ChatInfoQuickAction(
          dense: dense,
          icon: LucideIcons.search,
          label: l.chatInfoSearch,
          onTap: () => Navigator.pop(context, 'search')),
      ChatInfoQuickAction(
          dense: dense,
          icon: _muted ? LucideIcons.bell : LucideIcons.bellOff,
          label: _muted ? l.chatInfoUnmute : l.chatInfoMute,
          onTap: _toggleMute),
      ChatInfoQuickAction(
          dense: dense,
          icon: archived ? LucideIcons.archiveRestore : LucideIcons.archive,
          label: archived ? l.chatInfoUnarchive : l.chatInfoArchive,
          onTap: _toggleArchive),
    ]);
  }

  Widget _bigAvatar({bool badge = false}) {
    final t = context.bu;
    final tok = _api.tokens?.access;
    final au = _avatarUrl;
    final avatar = DecoratedBox(
      decoration: const BoxDecoration(),
      child: ChatlistAvatar(
        name: _title,
        url: au,
        size: 96,
        monogram: true,
        cornerRadius: 20,
        group: !_direct,
        headers: (tok != null && au != null && au.startsWith('/api/'))
            ? {'Authorization': 'Bearer $tok'}
            : null,
      ),
    );
    if (!badge) return avatar;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(clipBehavior: Clip.none, children: [
        avatar,
        PositionedDirectional(
          end: -8,
          bottom: -8,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Tooltip(
                message: context.l10n.chatInfoChangePhoto,
                child: BuPressable(
                  onTap: _avatarSheet,
                  haptic: BuHaptic.selection,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: t.danger,
                        shape: BoxShape.circle,
                        boxShadow: BuElevation.of(context, 2)),
                    child: Icon(LucideIcons.camera, size: 18, color: t.onPr),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  TextStyle _nameStyle(BuTokens t) => Theme.of(context)
      .textTheme
      .headlineSmall!
      .copyWith(fontWeight: FontWeight.w700, fontSize: 22, height: 1.27, color: t.ink);

  // ---- Birebir ----

  /// "Bölüm · 3. sınıf" (profilden); yoksa boş.
  String get _directSub {
    final p = _profile;
    final dept = context.departmentOrFacultyName(
        (p?['department'] ?? _peer?['department'])?.toString(), (p?['faculty'] ?? _peer?['faculty'])?.toString());
    final year = (p?['classYear'] as num?)?.toInt();
    return [
      if (dept.isNotEmpty) dept,
      if (year != null && year > 0) context.l10n.p09GradeYear(year.toString()),
    ].join(' · ');
  }

  List<Widget> _directBody(BuTokens t) {
    final l = context.l10n;
    final sub = _directSub;
    final name = (_peer?['displayName'] as String?) ?? _title;
    final lang = l.localeName;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(kChatInfoMargin, 16, kChatInfoMargin, 24),
        child: Column(children: [
          _bigAvatar(),
          const SizedBox(height: 12),
          Text(_title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: _nameStyle(t)),
          if (sub.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sub, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: chatInfoBody14(context)),
            ),
        ]),
      ),
      _quickRow(dense: false),
      const SizedBox(height: 24),
      _gap([
        if (_peerId != null)
          ChatInfoRows(children: [
            ChatInfoRow(
                icon: LucideIcons.idCard,
                label: l.chatInfoViewProfile,
                onTap: () => _openProfile({'userId': _peerId, 'displayName': _title, 'avatarUrl': _peer?['avatarUrl']})),
          ]),
        _mediaCard(t, direct: true),
        ChatInfoRows(children: [
          ChatInfoRow(
              icon: _muted ? LucideIcons.bellOff : LucideIcons.bell,
              label: l.chatInfoMuteNotifications,
              // Kısa "Açık" sağda, uzun "Sessiz · 8 saat sonra açılır" alt satırda.
              value: _muted ? null : _muteStatus(),
              sub: _muted ? _muteStatus() : null,
              onTap: _toggleMute),
        ]),
        ChatInfoRows(children: [
          ChatInfoRow(
              icon: LucideIcons.ban,
              label: _blocked ? l.chatInfoUnblock : l.p09BlockNamed(chatInfoAccusative(name, lang)),
              danger: true,
              onTap: _toggleBlock),
          ChatInfoRow(icon: LucideIcons.octagonAlert, label: l.chatInfoReportUser, danger: true, onTap: _report),
        ]),
      ]),
    ];
  }

  // ---- Kullanıcı grubu ----

  List<Widget> _groupBody(BuTokens t) {
    final l = context.l10n;
    final n = (_conv['memberCount'] as num?)?.toInt() ?? _members.length;
    final count = _members.length > n ? _members.length : n;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(kChatInfoMargin, 16, kChatInfoMargin, 20),
        child: Column(children: [
          _bigAvatar(badge: _admin),
          SizedBox(height: _admin ? 6 : 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(
              child: Text(_title,
                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: _nameStyle(t)),
            ),
            if (_admin)
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: l.chatInfoEditName,
                  padding: EdgeInsets.zero,
                  onPressed: _rename,
                  icon: Icon(LucideIcons.pencil, size: 20, color: t.mut),
                ),
              ),
          ]),
          if (count > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(l.chatInfoMemberCount(count.toString()), style: chatInfoLabel12(context, color: t.mut)),
            ),
        ]),
      ),
      _quickRow(dense: true),
      const SizedBox(height: 24),
      _gap([
        if (_admin)
          ChatInfoCard(
            child: ChatInfoRow(
              key: const ValueKey('info-add-member'),
              icon: LucideIcons.userPlus,
              label: l.sohbetyAddMember,
              soft: true,
              dotSize: 44,
              iconSize: 24,
              minHeight: 76,
              padding: 16,
              onTap: _addMembers,
            ),
          ),
        _membersCard(t),
        _mediaCard(t, direct: false),
        if (_userGroup)
          ChatInfoCard(
            padding: const EdgeInsets.all(4),
            child: ChatInfoRow(
              icon: LucideIcons.logOut,
              label: l.chatInfoLeaveChat,
              danger: true,
              chevronDanger: true,
              dotSize: 40,
              iconSize: 22,
              minHeight: 72,
              padding: 16,
              onTap: _leave,
            ),
          ),
      ]),
    ];
  }

  // ---- Kulüp / etkinlik odası ----

  List<Widget> _roomBody(BuTokens t) {
    return [
      _pad(_roomHeader(t)),
      const SizedBox(height: 16),
      _quickRow(dense: true),
      const SizedBox(height: 16),
      _gap([
        _membersCard(t),
        _mediaCard(t, direct: false),
      ]),
    ];
  }

  Widget _roomHeader(BuTokens t) {
    final l = context.l10n;
    final club = _type == 'CLUB';
    final n = (_conv['memberCount'] as num?)?.toInt() ?? _members.length;
    final au = _avatarUrl;
    final tok = _api.tokens?.access;
    final tile = SizedBox(
      width: 80,
      height: 80,
      child: Stack(clipBehavior: Clip.none, children: [
        DecoratedBox(
          decoration: BoxDecoration(borderRadius: BuRadius.bMd, boxShadow: BuElevation.of(context, 2)),
          child: au != null
              ? ChatlistAvatar(
                  name: _title,
                  url: au,
                  size: 80,
                  group: true,
                  headers: (tok != null && au.startsWith('/api/')) ? {'Authorization': 'Bearer $tok'} : null)
              : Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(color: club ? t.ink : t.pr, borderRadius: BuRadius.bMd),
                  child: Icon(club ? LucideIcons.users : LucideIcons.calendarDays, size: 40, color: club ? t.bg : t.onPr),
                ),
        ),
        if (!club && _closed)
          PositionedDirectional(
            end: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle, boxShadow: BuElevation.of(context, 1)),
              child: Icon(LucideIcons.lock, size: 14, color: t.mut),
            ),
          ),
      ]),
    );
    return ChatInfoCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: tile),
        const SizedBox(height: 16),
        Text(_title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700, height: 1.33)),
        const SizedBox(height: 4),
        Center(child: ChatInfoTag(club ? l.chatInfoClubRoom : l.chatInfoEventRoom, roomRed: !club)),
        if (n > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.chatInfoMemberCount(n.toString()), textAlign: TextAlign.center, style: chatInfoBody14(context)),
          ),
        if (_closed) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bSm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.bd, borderRadius: BuRadius.bXs),
                child: Icon(LucideIcons.lockKeyhole, size: 22, color: t.ink),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.chatInfoClosed, style: chatInfoTitle16(context).copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(l.chatInfoClosedSub, style: chatInfoBody14(context)),
                ]),
              ),
            ]),
          ),
        ],
        if (widget.onOpenRoom != null) ...[
          const SizedBox(height: 16),
          _roomLink(t, club),
        ],
      ]),
    );
  }

  Widget _roomLink(BuTokens t, bool club) {
    final l = context.l10n;
    return Semantics(
      button: true,
      child: Material(
        color: t.sf2,
        borderRadius: BuRadius.bSm,
        child: InkWell(
          borderRadius: BuRadius.bSm,
          onTap: widget.onOpenRoom,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bXs),
                child: Icon(club ? LucideIcons.users : LucideIcons.calendarDays, size: 20, color: club ? t.ink : t.pr),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(club ? l.chatInfoOpenClubPage : l.chatInfoOpenEventPage, style: chatInfoTitle16(context)),
                  if (club) Text(l.p09ClubPageSub, style: chatInfoBody12(context)),
                ]),
              ),
              Icon(buDirIcon(context, LucideIcons.chevronRight), size: 20, color: t.mut),
            ]),
          ),
        ),
      ),
    );
  }

  // ---- Üyeler kartı ----

  Widget _membersCard(BuTokens t) {
    final l = context.l10n;
    final n = (_conv['memberCount'] as num?)?.toInt() ?? _members.length;
    final count = _members.length > n ? _members.length : n;
    final shown = _members.take(_memberPreview).toList();
    return ChatInfoCard(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ChatInfoSectionHead(
          title: l.chatInfoMembers,
          count: count > 0 ? '$count' : null,
          actionLabel: _members.length > _memberPreview ? l.chatInfoAll : null,
          onAction: _openMembers,
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _membersFailed
                ? Row(children: [
                    Expanded(child: Text(l.p09MembersLoadFailed, style: chatInfoBody14(context))),
                    BuButton(label: l.commonRetry, kind: BuButtonKind.text, compact: true, onPressed: _loadMembers),
                  ])
                : Text(l.chatInfoNoMembers, style: chatInfoBody14(context)),
          )
        else
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.sf2),
            ChatMemberRow(
              member: shown[i],
              selfId: widget.session.userId,
              onTap: () => _openProfile(shown[i]),
              onRemove: _admin &&
                      (shown[i]['userId'] as num?)?.toInt() != widget.session.userId &&
                      !isAdminRole(shown[i])
                  ? () => _removeMember(shown[i])
                  : null,
            ),
          ],
      ]),
    );
  }

  // ---- Medya kartı ----

  Widget _mediaCard(BuTokens t, {required bool direct}) {
    final l = context.l10n;
    final f = _feed;
    final n = f.items.length;
    final total = '$n${f.more ? '+' : ''}';
    final cols = direct ? 4 : 3;
    final Widget body;
    if (f.loading) {
      body = BuSkeletonScope(
        child: Row(children: [
          for (var i = 0; i < cols; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            const Expanded(child: AspectRatio(aspectRatio: 1, child: BuSkeleton(radius: 12, height: 200))),
          ],
        ]),
      );
    } else if (f.error != null) {
      body = Row(children: [
        Expanded(child: Text(l.p09MediaErrorBody, style: chatInfoBody14(context))),
        BuButton(
            label: l.chatInfoRetry,
            kind: BuButtonKind.text,
            compact: true,
            onPressed: () => f.load(first: true, want: _previewCount)),
      ]);
    } else if (n == 0) {
      body = Text(l.chatInfoNoMedia, style: chatInfoBody14(context));
    } else {
      final tiles = f.items.take(cols).toList();
      // Birebir şerit: 4'ten fazla görselde son karo "+N" örtüsü taşır.
      final overflow = direct && n > cols ? n - (cols - 1) : null;
      body = GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        crossAxisCount: cols,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (var i = 0; i < tiles.length; i++)
            ChatInfoThumb(
              item: tiles[i],
              video: f.isVideo(tiles[i]),
              durationMs: f.videoMeta[tiles[i].url],
              headers: _headers,
              moreCount: overflow != null && i == cols - 1 ? overflow : null,
              onTap: overflow != null && i == cols - 1 ? _openAllMedia : () => _openViewer(i),
            ),
        ],
      );
    }
    return ChatInfoCard(
      padding: EdgeInsets.fromLTRB(direct ? 16 : 20, 12, direct ? 16 : 20, direct ? 16 : 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ChatInfoSectionHead(
          title: direct && n > 0 ? l.chatInfoMediaDot(total) : l.chatInfoMedia,
          count: !direct && n > 0 ? total : null,
          actionLabel: n > 0 ? l.chatInfoSeeAllMedia : null,
          largeAction: direct,
          onAction: _openAllMedia,
        ),
        const SizedBox(height: 4),
        body,
      ]),
    );
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
}
