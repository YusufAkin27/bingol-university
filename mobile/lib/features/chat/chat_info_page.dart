import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'chat_media_viewer.dart';
import 'message_bubble.dart' show chatMediaUrl;

/// Sohbet bilgisi: üstte kısa başlık bloğu, altında sohbetin görselleri (3 sütun, sonsuz kaydırma).
///
/// Backend'de ayrı bir medya listesi ucu yok; görseller mesaj geçmişi sayfalanarak (`before` imleci)
/// süzülür. Her yüklemede en çok [_batch] görsel toplanır, hepsi birden çekilmez.
class ChatInfoPage extends StatefulWidget {
  const ChatInfoPage({
    super.key,
    required this.session,
    required this.conversation,
    this.members = const [],
    this.subtitle,
    this.onOpenRoom,
    this.saveImage = saveChatImageToGallery,
  });

  final Session session;
  final Map<String, dynamic> conversation;
  final List<Map<String, dynamic>> members;

  /// Başlık altındaki durum satırı (çevrimiçi / son görülme).
  final String? subtitle;

  /// Kulüp/etkinlik odasında ilgili sayfayı açar; null ise satır gösterilmez.
  final VoidCallback? onOpenRoom;
  final SaveImage saveImage;

  @override
  State<ChatInfoPage> createState() => _ChatInfoPageState();
}

class _ChatInfoPageState extends State<ChatInfoPage> {
  static const _batch = 30;
  static const _pageSize = 40;
  static const _maxRequestsPerLoad = 8;

  final _scroll = ScrollController();
  final _items = <ChatMediaItem>[];
  final _seen = <int>{};
  int? _cursor;
  bool _more = true;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  Object? _moreError;

  ApiClient get _api => widget.session.api;
  int get _cid => (widget.conversation['id'] as num).toInt();
  String get _type => (widget.conversation['type'] as String?) ?? 'GROUP';
  bool get _direct => _type == 'DIRECT';
  Map<String, dynamic>? get _peer =>
      widget.conversation['peer'] is Map ? Map<String, dynamic>.from(widget.conversation['peer'] as Map) : null;

  String get _title => _direct
      ? ((_peer?['displayName'] as String?) ?? (widget.conversation['title'] as String?) ?? 'Sohbet')
      : ((widget.conversation['title'] as String?) ?? 'Grup');

  Map<String, String> get _headers {
    final tok = _api.tokens?.access;
    return tok == null ? const {} : {'Authorization': 'Bearer $tok'};
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(first: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _load();
  }

  String? _senderName(Map<String, dynamic> m) {
    final id = (m['senderId'] as num?)?.toInt();
    if (id == null) return null;
    if (id == widget.session.userId) return 'Sen';
    for (final mem in widget.members) {
      if ((mem['userId'] as num?)?.toInt() == id) return mem['displayName'] as String?;
    }
    if (_direct) return _peer?['displayName'] as String?;
    return (m['senderName'] as String?) ?? 'Kullanıcı';
  }

  void _collect(List items) {
    for (final raw in items) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      if (m['deleted'] == true || m['removed'] == true) continue;
      final at = DateTime.tryParse((m['createdAt'] as String?) ?? '')?.toLocal();
      for (final a in (m['attachments'] as List? ?? const []).whereType<Map>()) {
        if (a['removed'] == true) continue;
        final url = (a['url'] ?? a['thumbUrl']) as String?;
        if (url == null) continue;
        final aid = (a['id'] as num?)?.toInt();
        if (aid != null && !_seen.add(aid)) continue;
        _items.add(ChatMediaItem(
          url: url,
          thumbUrl: (a['thumbUrl'] ?? a['url']) as String?,
          sender: _senderName(m),
          at: at,
          id: aid,
        ));
      }
    }
  }

  Future<void> _load({bool first = false}) async {
    if (_loadingMore && !first) return;
    if (!first && (!_more || _loading || _error != null)) return;
    if (first) {
      setState(() {
        _loading = true;
        _error = null;
        _items.clear();
        _seen.clear();
        _cursor = null;
        _more = true;
      });
    } else {
      setState(() {
        _loadingMore = true;
        _moreError = null;
      });
    }
    final target = _items.length + _batch;
    try {
      var requests = 0;
      while (_more && _items.length < target && requests < _maxRequestsPerLoad) {
        final q = _cursor == null ? '' : '&before=$_cursor';
        final page = await _api.get('/conversations/$_cid/messages?size=$_pageSize$q') as Map<String, dynamic>;
        if (!mounted) return;
        _collect(page['items'] as List? ?? const []);
        _cursor = (page['nextCursor'] as num?)?.toInt();
        _more = _cursor != null;
        requests++;
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      _fillViewport();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (first) {
          _error = e;
        } else {
          _moreError = e;
        }
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  /// Izgara ekranı doldurmuyorsa kaydırma olmayacağından devamını kendimiz iste.
  void _fillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_more || _loadingMore || _moreError != null || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent <= 0) _load();
    });
  }

  void _openViewer(int index) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatMediaViewer(
          items: List.of(_items),
          headers: _headers,
          initialIndex: index,
          saveImage: widget.saveImage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.sf,
        foregroundColor: t.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Sohbet bilgisi', style: BuType.heading.copyWith(color: t.ink)),
      ),
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(child: _header(t)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(children: [
                Text('Medya', style: BuType.heading.copyWith(color: t.ink)),
                const SizedBox(width: 8),
                if (_items.isNotEmpty) Text('${_items.length}${_more ? '+' : ''}', style: BuType.label.copyWith(color: t.mut)),
              ]),
            ),
          ),
          ..._mediaSlivers(t),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16)),
        ],
      ),
    );
  }

  Widget _header(BuTokens t) {
    final conv = widget.conversation;
    final String? avatar = _direct ? (_peer?['avatarUrl'] as String?) : null;
    final n = (conv['memberCount'] as num?)?.toInt() ?? widget.members.length;
    final kind = switch (_type) {
      'CLUB' => 'Kulüp odası',
      'EVENT' => 'Etkinlik odası',
      'DIRECT' => null,
      _ => 'Grup',
    };
    final sub = _direct ? widget.subtitle : [if (kind != null) kind, if (n > 0) '$n üye'].join(' · ');
    final names = widget.members.map((m) => (m['displayName'] as String?) ?? '').where((s) => s.isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(children: [
        BuAvatar(name: _title, url: avatar, size: 84),
        const SizedBox(height: 12),
        Text(_title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.title.copyWith(color: t.ink)),
        if (sub != null && sub.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(sub, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(color: t.mut)),
          ),
        if (!_direct && names.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: InkWell(
              onTap: () => _showMembers(names),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Text(
                      names.take(3).join(', ') + (names.length > 3 ? ' +${names.length - 3}' : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BuType.caption.copyWith(color: t.mut),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Tümünü gör', style: BuType.caption.copyWith(color: t.pr, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        if (widget.onOpenRoom != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton.icon(
              onPressed: widget.onOpenRoom,
              icon: const Icon(LucideIcons.arrowUpRight, size: 16),
              label: Text(_type == 'CLUB' ? 'Kulüp sayfası' : 'Etkinlik sayfası'),
            ),
          ),
      ]),
    );
  }

  void _showMembers(List<String> names) {
    final t = context.bu;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.sf,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * .6),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              for (final m in widget.members)
                ListTile(
                  leading: BuAvatar(name: m['displayName'] as String?, url: m['avatarUrl'] as String?, size: 36),
                  title: Text((m['displayName'] as String?) ?? 'Kullanıcı', maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(color: t.ink)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _mediaSlivers(BuTokens t) {
    if (_loading) {
      return const [SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 48), child: LoadingView()))];
    }
    if (_error != null) {
      return [SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: ErrorView(error: _error!, onRetry: () => _load(first: true))))];
    }
    if (_items.isEmpty && !_more) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: EmptyView(icon: LucideIcons.image, text: 'Bu sohbette henüz görsel yok.'),
          ),
        ),
      ];
    }
    return [
      SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (c, i) => _Thumb(item: _items[i], headers: _headers, onTap: () => _openViewer(i)),
          childCount: _items.length,
        ),
      ),
      SliverToBoxAdapter(
        child: _moreError != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: () => _load(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Yeniden dene'),
                  ),
                ),
              )
            : (_more
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : const SizedBox.shrink()),
      ),
    ];
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item, required this.headers, required this.onTap});

  final ChatMediaItem item;
  final Map<String, String> headers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final thumb = item.thumbUrl ?? item.url;
    return Semantics(
      button: true,
      label: 'Görseli aç',
      child: GestureDetector(
        onTap: onTap,
        child: ColoredBox(
          color: t.sf2,
          child: Image.network(
            chatMediaUrl(thumb),
            headers: headers,
            fit: BoxFit.cover,
            cacheWidth: 360,
            gaplessPlayback: true,
            errorBuilder: (c, e, s) => Center(child: Icon(LucideIcons.imageOff, color: t.mut)),
          ),
        ),
      ),
    );
  }
}
