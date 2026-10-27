import 'package:flutter/material.dart';

import '../../core/api.dart';
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
  final _barKey = GlobalKey();
  final _sectionKeys = {
    for (final s in InfoSection.values) s: GlobalKey(),
  };
  late InfoSection _active =
      _type == 'DIRECT' ? InfoSection.media : InfoSection.members;
  bool _spyLock = false;
  bool _spyQueued = false;
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
          'Sohbet')
      : ((_conv['title'] as String?) ?? 'Grup');

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
    if (id == widget.session.userId) return 'Sen';
    for (final mem in _members) {
      if ((mem['userId'] as num?)?.toInt() == id) {
        return mem['displayName'] as String?;
      }
    }
    if (_direct) return _peer?['displayName'] as String?;
    return (m['senderName'] as String?) ?? 'Kullanıcı';
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(c, true), child: Text(action)),
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
      backgroundColor: t.sf,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BuMenuRow(
              icon: LucideIcons.bellOff,
              label: '8 saat',
              showChevron: false,
              onTap: () => Navigator.pop(c, '480')),
          BuMenuRow(
              icon: LucideIcons.bellOff,
              label: '1 hafta',
              showChevron: false,
              onTap: () => Navigator.pop(c, '10080')),
          BuMenuRow(
              icon: LucideIcons.bellOff,
              label: 'Her zaman',
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
          ? 'Bildirimlerin sesi açıldı'
          : 'Sohbet sessize alındı');
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
      _toast(archived ? 'Sohbet arşivden çıkarıldı' : 'Sohbet arşivlendi');
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _leave() async {
    if (!await _confirm(
        'Sohbetten ayrılınsın mı?', 'Bu sohbetten ayrılırsınız.', 'Ayrıl')) {
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
        _toast('Engel kaldırıldı');
      } else {
        if (!await _confirm('Kullanıcı engellensin mi?',
            'Engellediğiniz kişiyle mesajlaşamazsınız.', 'Engelle')) {
          return;
        }
        await _api.post('/users/$pid/block');
        if (mounted) setState(() => _merge({'blocked': true}));
        _toast('Kullanıcı engellendi');
      }
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _report() async {
    final pid = _peerId;
    if (pid == null) return;
    await ReportSheet.show(context, widget.session,
        targetType: 'USER', targetId: pid, title: 'Kullanıcıyı şikâyet et');
  }

  Future<bool> _removeMember(Map<String, dynamic> m) async {
    final name = (m['displayName'] as String?) ?? 'Kullanıcı';
    if (!await _confirm(
        'Üye çıkarılsın mı?', '$name gruptan çıkarılır.', 'Çıkar')) {
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
      backgroundColor: t.sf,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BuMenuRow(
              icon: LucideIcons.image,
              label: 'Galeriden seç',
              showChevron: false,
              onTap: () => Navigator.pop(c, 'pick')),
          if (has)
            BuMenuRow(
                icon: LucideIcons.trash2,
                label: 'Fotoğrafı kaldır',
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
            ? 'Görsel çok büyük, daha küçük bir görsel seçin.'
            : 'Yalnızca JPEG, PNG veya WebP görseller kullanılabilir.');
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

  // ---- arayüz ----

  List<InfoSection> get _sections => [
        if (!_direct) InfoSection.members,
        InfoSection.media,
        InfoSection.settings,
      ];

  GlobalKey _keyOf(InfoSection s) => _sectionKeys[s]!;

  void _onSegment(InfoSection s) async {
    if (_scroll.hasClients == false) return;
    setState(() => _active = s);
    _spyLock = true;
    try {
      Future<void> go() async {
        final ctx = _keyOf(s).currentContext;
        if (ctx == null) return;
        final vh = _scroll.position.viewportDimension;
        await Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOutCubic,
            alignment: vh <= 0 ? 0 : (InfoSegmentBar.height + 4) / vh);
      }

      if (_keyOf(s).currentContext == null) {
        // Tembel liste yüzünden hedef henüz üretilmedi: önce uca git, sonra yeniden dene.
        await _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
      await go();
    } finally {
      _spyLock = false;
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || _spyLock || n is! ScrollUpdateNotification) return false;
    // Düzen güncellendikten sonra ölç (bildirim anında geometri eskidir).
    if (!_spyQueued) {
      _spyQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _spyQueued = false;
        if (mounted && !_spyLock) _spy();
      });
    }
    return false;
  }

  /// Çubuğun altına ulaşmış son bölümü etkin yapar.
  void _spy() {
    final barBox = _barKey.currentContext?.findRenderObject();
    if (barBox is! RenderBox || !barBox.attached) return;
    final limit = barBox.localToGlobal(Offset.zero).dy + barBox.size.height + 12;
    InfoSection? found;
    for (final s in _sections) {
      final box = _keyOf(s).currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      if (box.localToGlobal(Offset.zero).dy <= limit) found = s;
    }
    if (_scroll.hasClients &&
        _scroll.position.maxScrollExtent > 0 &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 1) {
      found = _sections.last;
    }
    if (found != null && found != _active) setState(() => _active = found!);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? _members
        : _members
            .where((m) =>
                ((m['displayName'] as String?) ?? '').toLowerCase().contains(q))
            .toList();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Sohbet bilgisi',
            style: BuType.heading.copyWith(color: t.ink)),
      ),
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        builder: (c, v, child) => Opacity(opacity: v, child: child),
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                  child: Column(children: [_header(t), _actions(t)])),
              SliverPersistentHeader(
                pinned: true,
                delegate: InfoSegmentDelegate(
                  barKey: _barKey,
                  sections: _sections,
                  active: _active,
                  onSelect: _onSegment,
                ),
              ),
              if (!_direct) ...[
                SliverToBoxAdapter(child: _membersHead(t)),
                if (shown.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: Text(
                            _members.isEmpty ? 'Üye listesi yok.' : 'Sonuç yok.',
                            style: BuType.body.copyWith(color: t.mut))),
                  )
                else
                  SliverList.builder(
                    itemCount: shown.length,
                    itemBuilder: (c, i) {
                      final m = shown[i];
                      return ChatMemberRow(
                        member: m,
                        selfId: widget.session.userId,
                        onTap: () => _openProfile(m),
                        onRemove: _admin &&
                                (m['userId'] as num?)?.toInt() !=
                                    widget.session.userId &&
                                !isAdminRole(m)
                            ? () => _removeMember(m)
                            : null,
                      );
                    },
                  ),
              ],
              SliverToBoxAdapter(child: _mediaSection(t)),
              SliverToBoxAdapter(child: _settingsSection(t)),
              SliverToBoxAdapter(
                  child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuTokens t) {
    final n = (_conv['memberCount'] as num?)?.toInt() ?? _members.length;
    final kind = switch (_type) {
      'CLUB' => 'Kulüp odası',
      'EVENT' => 'Etkinlik odası',
      'DIRECT' => null,
      _ => 'Grup',
    };
    Widget? sub;
    if (_direct) {
      final s = widget.subtitle;
      if (s != null && s.isNotEmpty) {
        sub = Text(s,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BuType.label.copyWith(color: t.mut));
      }
    } else {
      sub = Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            if (kind != null) BuBadge(kind, soft: true),
            if (n > 0)
              Text('$n üye', style: BuType.label.copyWith(color: t.mut)),
          ]);
    }
    final tok = _api.tokens?.access;
    final au = _avatarUrl;
    final avatar = BuAvatar(
        name: _title,
        url: au,
        size: 96,
        group: _conv['type'] != 'DIRECT',
        headers: (tok != null && au != null && au.startsWith('/api/'))
            ? {'Authorization': 'Bearer $tok'}
            : null);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          avatar,
          if (_admin)
            PositionedDirectional(
              end: -2,
              bottom: -2,
              child: Tooltip(
                message: 'Fotoğrafı değiştir',
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
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(
              child: Text(_title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BuType.title.copyWith(color: t.ink))),
          if (_admin)
            IconButton(
              tooltip: 'Adı düzenle',
              visualDensity: VisualDensity.compact,
              onPressed: _rename,
              icon: Icon(LucideIcons.pencil, size: 14.5, color: t.mut),
            ),
        ]),
        if (sub != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: sub),
      ]),
    );
  }

  /// Başlıkta yalnızca "Ara" ve (oda ise) ilgili sayfa kısayolu; sessize alma Ayarlar'da.
  Widget _actions(BuTokens t) {
    final roomLabel = _type == 'CLUB' ? 'Kulüp' : 'Etkinlik';
    final items = <Widget>[
      _QuickAction(
          icon: LucideIcons.search,
          label: 'Ara',
          onTap: () => Navigator.pop(context, 'search')),
      if (widget.onOpenRoom != null)
        _QuickAction(
            icon: LucideIcons.arrowUpRight,
            label: roomLabel,
            onTap: widget.onOpenRoom!),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 20),
          items[i],
        ],
      ]),
    );
  }

  Widget _sectionHead(BuTokens t, GlobalKey key, String title,
      {String? action, VoidCallback? onAction}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(children: [
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BuType.label.copyWith(color: t.mut, letterSpacing: .3)),
        ),
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(action, style: BuType.label.copyWith(color: t.pr))),
          ),
      ]),
    );
  }

  Widget _membersHead(BuTokens t) {
    final n = _members.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionHead(t, _keyOf(InfoSection.members),
          n == 0 ? 'Üyeler' : 'Üyeler · $n'),
      if (n > _searchThreshold)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: BuSearchField(
              hint: 'Üye ara', onChanged: (v) => setState(() => _query = v)),
        ),
    ]);
  }

  Widget _mediaSection(BuTokens t) {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text('Bu sohbette henüz görsel yok.',
              style: BuType.body.copyWith(color: t.mut)));
    } else {
      final shown = f.items.take(_previewCount).toList();
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
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
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: OutlinedButton(
            onPressed: _openAllMedia,
            style: OutlinedButton.styleFrom(
              foregroundColor: t.ink,
              side: BorderSide(color: t.bd),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Tüm medyayı gör', style: BuType.bodyStrong),
          ),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionHead(
          t,
          _keyOf(InfoSection.media),
          has ? 'Medya · ${f.items.length}${f.more ? '+' : ''}' : 'Medya',
          action: has ? 'Tümü' : null,
          onAction: _openAllMedia),
      body,
    ]);
  }

  String _muteStatus() {
    if (!_muted) return 'Açık';
    if (_conv['mutedForever'] == true) return 'Sessiz · her zaman';
    final u = DateTime.tryParse((_conv['mutedUntil'] as String?) ?? '')?.toLocal();
    if (u != null) {
      final d = u.difference(DateTime.now());
      if (!d.isNegative) {
        final h = (d.inMinutes / 60).ceil();
        if (h >= 24) return 'Sessiz · ${(h / 24).ceil()} gün sonra açılır';
        if (h >= 1) return 'Sessiz · $h saat sonra açılır';
        return 'Sessiz · birazdan açılır';
      }
    }
    return 'Sessiz';
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

  Widget _settingsSection(BuTokens t) {
    final archived = _conv['archived'] == true;
    final roomPage = _type == 'CLUB' ? 'Kulüp sayfasını aç' : 'Etkinlik sayfasını aç';
    final main = <Widget>[
      if (_direct && _peerId != null)
        _SettingsRow(
          icon: LucideIcons.user,
          label: 'Profili görüntüle',
          onTap: () => _openProfile(_peer!),
        ),
      _SettingsRow(
        icon: _muted ? LucideIcons.bellOff : LucideIcons.bell,
        label: 'Bildirimleri sessize al',
        sub: _muteStatus(),
        onTap: _toggleMute,
        trailing: Switch(value: _muted, onChanged: (_) => _toggleMute()),
      ),
      _SettingsRow(
        icon: LucideIcons.archive,
        label: archived ? 'Arşivden çıkar' : 'Arşivle',
        onTap: _toggleArchive,
      ),
      if (_conv['closed'] == true)
        const _SettingsRow(
            icon: LucideIcons.lock, label: 'Bu sohbet kapalı', sub: 'Yeni mesaj gönderilemez'),
      if (_room && widget.onOpenRoom != null)
        _SettingsRow(
            icon: LucideIcons.arrowUpRight,
            label: roomPage,
            onTap: widget.onOpenRoom),
    ];
    final danger = <Widget>[
      if (_userGroup)
        _SettingsRow(
            icon: LucideIcons.logOut,
            label: 'Sohbetten çık',
            danger: true,
            onTap: _leave),
      if (_direct)
        _SettingsRow(
            icon: LucideIcons.ban,
            label: _blocked ? 'Engeli kaldır' : 'Engelle',
            danger: true,
            onTap: _toggleBlock),
      if (_direct)
        _SettingsRow(
            icon: LucideIcons.flag,
            label: 'Şikâyet et',
            danger: true,
            onTap: _report),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionHead(t, _keyOf(InfoSection.settings), 'Ayarlar'),
      _SettingsCard(rows: main),
      if (danger.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SettingsCard(rows: danger),
      ],
    ]);
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.bd),
      ),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: t.bd),
          rows[i],
        ],
      ]),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow(
      {required this.icon,
      required this.label,
      this.sub,
      this.onTap,
      this.trailing,
      this.danger = false});

  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final color = danger ? t.danger.withValues(alpha: .85) : t.ink;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Icon(icon, size: 17, color: danger ? color : t.mut),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: BuType.body.copyWith(color: color)),
                    if (sub != null)
                      Text(sub!, style: BuType.caption.copyWith(color: t.mut)),
                  ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ]),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 76,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.sf,
                border: Border.all(color: t.bd),
              ),
              child: Icon(icon, size: 19, color: t.ink),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BuType.caption.copyWith(color: t.mut)),
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
    final v = _ctl.text.trim();
    return AlertDialog(
      title: const Text('Grup adı'),
      content: TextField(
        controller: _ctl,
        autofocus: true,
        maxLength: 60,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: 'Grup adı'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç')),
        TextButton(
            onPressed: v.isEmpty ? null : () => Navigator.pop(context, v),
            child: const Text('Kaydet')),
      ],
    );
  }
}
