import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/platform/image_service.dart';
import '../../core/realtime/chat_realtime.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/report_sheet.dart';
import '../clubs/club_detail_page.dart';
import '../events/event_detail_page.dart';
import 'message_bubble.dart';

/// Sohbet detayı: mesaj geçmişi (imleçli), iyimser gönderim, yanıt/düzenle/sil/tepki, görsel gönderme.
/// Gerçek zamanlı (STOMP) çalışır; bağlı değilken 4 sn'lik `after` yoklamasına düşer.
class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.session,
    required this.conversation,
    @visibleForTesting this.connectRealtime = true,
  });

  final Session session;
  final Map<String, dynamic> conversation;

  /// Testlerde false: gerçek WebSocket bağlantısı kurulmaz.
  final bool connectRealtime;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> with WidgetsBindingObserver {
  static const _maxLen = 2000;
  static const _pollInterval = Duration(seconds: 4);

  late Map<String, dynamic> _conv = Map<String, dynamic>.from(widget.conversation);

  /// En yeni başta (ListView reverse). Yerel bekleyen/başarısız mesajlar `id == null`.
  final List<Map<String, dynamic>> _msgs = [];
  final _names = <int, String>{};
  final _avatars = <int, String?>{};
  List<Map<String, dynamic>> _members = [];

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  late final ChatRealtime _rt = ChatRealtime(widget.session);
  final _subs = <StreamSubscription<dynamic>>[];
  final _ackTimers = <String, Timer>{};
  final _image = ImageService();
  late final _uploader = MultipartUploader(widget.session);
  List<String>? _emojis;
  bool _rtOn = false;

  /// Karşı tarafın okuduğu son mesaj id'si ve "yazıyor" göstergesi (yalnız ilgili widget'ları yeniler).
  final _peerRead = ValueNotifier<int>(0);
  final _typingNow = ValueNotifier<bool>(false);
  Timer? _typingOff;

  Timer? _timer;
  int _tick = 0;
  int _seq = 0;
  int? get _myId => widget.session.userId;
  int? _beforeCursor;
  int _lastRead = 0;

  bool _loading = true;
  bool _loadingMore = false;
  bool _polling = false;
  bool _changed = false;
  Object? _error;

  Map<String, dynamic>? _replyTo;
  Map<String, dynamic>? _editing;
  Map<String, dynamic>? _presence;

  ApiClient get _api => widget.session.api;
  int get _cid => (_conv['id'] as num).toInt();
  String get _type => (_conv['type'] as String?) ?? 'GROUP';
  bool get _direct => _type == 'DIRECT';
  Map<String, dynamic>? get _peer => _conv['peer'] is Map ? Map<String, dynamic>.from(_conv['peer'] as Map) : null;
  bool get _blocked => _conv['blocked'] == true;
  bool get _room => _type == 'CLUB' || _type == 'EVENT';
  int? get _roomTargetId => ((_type == 'CLUB' ? _conv['communityId'] : _conv['eventId']) as num?)?.toInt();
  bool get _roomPage => _room && _roomTargetId != null;

  void _openRoomPage() {
    final id = _roomTargetId;
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _type == 'CLUB'
            ? ClubDetailPage(session: widget.session, communityId: id)
            : EventDetailPage(session: widget.session, eventId: id),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _input.addListener(_onInput);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _typingOff?.cancel();
    for (final t in _ackTimers.values) {
      t.cancel();
    }
    for (final s in _subs) {
      s.cancel();
    }
    _rt.dispose();
    _peerRead.dispose();
    _typingNow.dispose();
    _input.removeListener(_onInput);
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _poll(force: true);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  // ---------- Yükleme ----------

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _api.get('/conversations/$_cid/messages?size=30'),
        _loadDetail(),
      ]);
      final page = results[0] as Map<String, dynamic>;
      final items = _items(page);
      if (!mounted) return;
      setState(() {
        _msgs
          ..clear()
          ..addAll(items);
        _beforeCursor = (page['nextCursor'] as num?)?.toInt();
        _loading = false;
      });
      _markRead();
      _startTimer();
      _loadPresence();
      _startRealtime();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadDetail() async {
    try {
      final d = await _api.get('/conversations/$_cid') as Map<String, dynamic>;
      final c = d['conversation'];
      if (c is Map) _conv = {..._conv, ...Map<String, dynamic>.from(c)};
      final ms = (d['members'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _members = ms;
      for (final m in ms) {
        final id = (m['userId'] as num?)?.toInt();
        if (id == null) continue;
        _names[id] = (m['displayName'] as String?) ?? 'Kullanıcı';
        _avatars[id] = m['avatarUrl'] as String?;
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Üye listesi alınamazsa sohbet yine de çalışır.
    }
  }

  Future<void> _loadPresence() async {
    final pid = (_peer?['id'] as num?)?.toInt();
    if (!_direct || pid == null) return;
    try {
      final p = await _api.get('/users/$pid/presence') as Map<String, dynamic>;
      if (mounted) setState(() => _presence = p);
    } catch (_) {
      if (mounted && _presence != null) setState(() => _presence = null);
    }
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> page) =>
      (page['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  int? get _newestServerId {
    for (final m in _msgs) {
      final id = (m['id'] as num?)?.toInt();
      if (id != null) return id;
    }
    return null;
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadOlder();
  }

  Future<void> _loadOlder() async {
    final before = _beforeCursor;
    if (before == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _api.get('/conversations/$_cid/messages?size=30&before=$before') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _merge(_items(page));
        _beforeCursor = (page['nextCursor'] as num?)?.toInt();
      });
    } catch (_) {
      // Sessizce geç; kullanıcı tekrar kaydırınca yeniden denenir.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Bağlıyken yalnız ~20 sn'de bir son sayfa tazelenir (düzenleme/silme/tepki olayları için);
  /// bağlı değilken her turda `after` ile yeni mesajlar çekilir.
  Future<void> _poll({bool force = false}) async {
    if (_polling || _loading || _error != null || !mounted) return;
    _tick++;
    if (_rtOn && !force && _tick % 5 != 0) return;
    _polling = true;
    try {
      var added = false;
      if (!_rtOn || force) added = await _fetchAfter();
      if (_tick % 5 == 0 || force) {
        final page = await _api.get('/conversations/$_cid/messages?size=30') as Map<String, dynamic>;
        added = _mergeCount(_items(page)) > 0 || added;
      }
      if (_tick % 8 == 0) _loadPresence();
      if (mounted) {
        setState(() {});
        if (added) _markRead();
      }
    } catch (_) {
      // Ağ hatası: bir sonraki turda yeniden dene, oturumu kapatma.
    } finally {
      _polling = false;
    }
  }

  /// Son bilinen id'den sonrasını sayfa sayfa çeker (boşluk kapatma). Yeni mesaj geldiyse true.
  Future<bool> _fetchAfter() async {
    final newest = _newestServerId;
    if (newest == null) {
      final page = await _api.get('/conversations/$_cid/messages?size=30') as Map<String, dynamic>;
      return _mergeCount(_items(page)) > 0;
    }
    var added = false;
    var cursor = newest;
    for (var i = 0; i < 5; i++) {
      final page = await _api.get('/conversations/$_cid/messages?after=$cursor&size=30') as Map<String, dynamic>;
      added = _mergeCount(_items(page)) > 0 || added;
      final next = (page['nextCursor'] as num?)?.toInt();
      if (next == null) break;
      cursor = next;
    }
    return added;
  }

  // ---------- Gerçek zamanlı ----------

  void _startRealtime() {
    if (_subs.isNotEmpty) return;
    _subs.addAll([
      _rt.messages.listen(_onRtMessage),
      _rt.readReceipts.listen((r) {
        if (r.conversationId == _cid && r.userId != _myId && r.lastMessageId > _peerRead.value) {
          _peerRead.value = r.lastMessageId;
        }
      }),
      _rt.typing.listen((e) {
        if (e.conversationId != _cid || e.userId == _myId) return;
        _typingNow.value = true;
        _typingOff?.cancel();
        _typingOff = Timer(const Duration(seconds: 4), () => _typingNow.value = false);
      }),
      _rt.errors.listen((e) {
        final cid = e.clientId;
        if (cid == null) return;
        _ackTimers.remove(cid)?.cancel();
        final i = _msgs.indexWhere((m) => m['id'] == null && m['clientId'] == cid);
        if (i >= 0 && mounted) {
          setState(() {
            _msgs[i]['_state'] = 'failed';
            _msgs[i]['_error'] = null;
          });
        }
      }),
      _rt.connected.listen((on) {
        if (!mounted) return;
        _rtOn = on;
        if (on) _poll(force: true);
      }),
      _rt.resync.listen((_) => _poll(force: true)),
    ]);
    if (widget.connectRealtime) _rt.start();
  }

  void _onRtMessage(Map<String, dynamic> m) {
    if ((m['conversationId'] as num?)?.toInt() != _cid || !mounted) return;
    final cid = m['clientId'] as String?;
    if (cid != null) _ackTimers.remove(cid)?.cancel();
    final mine = (m['senderId'] as num?)?.toInt() == _myId;
    setState(() => _merge([m]));
    if (mine) {
      _changed = true;
    } else {
      _typingNow.value = false;
      _markRead();
    }
  }

  /// Gelen mesajları listeye katar; yeni eklenen sayısını döndürür.
  int _mergeCount(List<Map<String, dynamic>> incoming) {
    final before = _msgs.length;
    _merge(incoming);
    return _msgs.length - before;
  }

  void _merge(List<Map<String, dynamic>> incoming) {
    for (final m in incoming) {
      final id = (m['id'] as num?)?.toInt();
      final cid = m['clientId'] as String?;
      var idx = _msgs.indexWhere((e) => id != null && (e['id'] as num?)?.toInt() == id);
      if (idx < 0 && cid != null) {
        idx = _msgs.indexWhere((e) => e['id'] == null && e['clientId'] == cid);
      }
      if (idx >= 0) {
        _msgs[idx] = m;
      } else {
        _msgs.add(m);
      }
    }
    _msgs.sort((a, b) => _key(b).compareTo(_key(a)));
  }

  int _key(Map<String, dynamic> m) => (m['id'] as num?)?.toInt() ?? (1 << 50) + ((m['_seq'] as int?) ?? 0);

  Future<void> _markRead() async {
    final id = _newestServerId;
    if (id == null || id <= _lastRead) return;
    _lastRead = id;
    _changed = true;
    if (_rtOn && _rt.sendRead(_cid, id)) return;
    try {
      await _api.post('/conversations/$_cid/read', {'lastMessageId': id});
    } catch (_) {
      if (_lastRead == id) _lastRead = 0;
    }
  }

  // ---------- Gönderim ----------

  String _newClientId() => ChatRealtime.newClientId();

  void _onInput() {
    if (_input.text.isNotEmpty && _editing == null && _rtOn) _rt.sendTyping(_cid);
  }

  Future<void> _submit() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    if (text.length > _maxLen) return;
    final editing = _editing;
    if (editing != null) {
      await _saveEdit(editing, text);
      return;
    }
    final local = _newLocal(text);
    setState(() {
      _msgs.insert(0, local);
      _input.clear();
      _replyTo = null;
    });
    _scrollToEnd();
    await _transmit(local);
  }

  Map<String, dynamic> _newLocal(String text) {
    final reply = _replyTo;
    return <String, dynamic>{
      'id': null,
      'clientId': _newClientId(),
      'senderId': _myId,
      'text': text,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'replyToMessageId': reply?['id'],
      'replyTo': reply == null
          ? null
          : {'id': reply['id'], 'senderId': reply['senderId'], 'text': reply['text'], 'deleted': false},
      '_state': 'pending',
      '_seq': _seq++,
    };
  }

  /// Bağlıysa WS ile (8 sn içinde ack gelmezse aynı clientId ile REST yedeği), değilse doğrudan REST.
  /// Görselli mesajlar önce yüklenir, `attachmentIds` ile REST'ten gönderilir.
  Future<void> _transmit(Map<String, dynamic> local) async {
    final cid = local['clientId'] as String;
    final pending = local['_image'] as PreparedImage?;
    try {
      if (pending != null && local['_attId'] == null) {
        final res = await _uploader.upload('/conversations/$_cid/media', pending) as Map;
        local['_attId'] = (res['id'] as num).toInt();
      }
      final attId = local['_attId'] as int?;
      if (attId == null && local['replyToMessageId'] == null && _rtOn && _rt.sendMessage(_cid, local['text'] as String, cid)) {
        _ackTimers[cid]?.cancel();
        _ackTimers[cid] = Timer(const Duration(seconds: 8), () {
          _ackTimers.remove(cid);
          if (mounted && local['_state'] == 'pending' && local['id'] == null) _sendRest(local);
        });
        return;
      }
      await _sendRest(local);
    } catch (e) {
      _fail(local, e);
    }
  }

  Future<void> _sendRest(Map<String, dynamic> local) async {
    try {
      final attId = local['_attId'] as int?;
      final res = await _api.post('/conversations/$_cid/messages', {
        'text': local['text'],
        'clientId': local['clientId'],
        if (local['replyToMessageId'] != null) 'replyToMessageId': local['replyToMessageId'],
        if (attId != null) 'attachmentIds': [attId],
      });
      if (!mounted) return;
      setState(() => _merge([Map<String, dynamic>.from(res as Map)]));
      _changed = true;
      _markRead();
    } catch (e) {
      _fail(local, e);
    }
  }

  void _fail(Map<String, dynamic> local, Object e) {
    if (!mounted || local['id'] != null) return;
    setState(() {
      local['_state'] = 'failed';
      local['_error'] = e is ApiError && !e.isNetwork ? errorText(e) : null;
    });
  }

  Future<void> _retry(Map<String, dynamic> m) async {
    setState(() {
      m['_state'] = 'pending';
      m['_error'] = null;
    });
    await _transmit(m);
  }

  // ---------- Görsel ----------

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.bu.sf,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BuMenuRow(icon: LucideIcons.image, label: 'Galeriden seç', showChevron: false, onTap: () => Navigator.pop(c, ImageSource.gallery)),
          BuMenuRow(icon: LucideIcons.camera, label: 'Fotoğraf çek', showChevron: false, onTap: () => Navigator.pop(c, ImageSource.camera)),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source == null || !mounted) return;
    PreparedImage? img;
    try {
      img = await _image.pickPrepared(source);
    } on ImageException catch (e) {
      _toast(e.code == 'TOO_LARGE'
          ? 'Görsel çok büyük, daha küçük bir görsel seçin.'
          : 'Yalnızca JPEG, PNG veya WebP görseller gönderilebilir.');
      return;
    } catch (_) {
      _toast('Görsel seçilemedi. İzinleri kontrol edin.');
      return;
    }
    if (img == null || !mounted) return;
    final local = _newLocal('')
      ..['_image'] = img
      ..['_bytes'] = img.bytes;
    setState(() {
      _msgs.insert(0, local);
      _replyTo = null;
    });
    _scrollToEnd();
    await _transmit(local);
  }

  Map<String, String> get _authHeaders {
    final tok = _api.tokens?.access;
    return tok == null ? const {} : {'Authorization': 'Bearer $tok'};
  }

  void _openImage(Map<String, dynamic> a) {
    final url = (a['url'] ?? a['thumbUrl']) as String?;
    if (url == null) return;
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ChatImageViewer(url: url, headers: _authHeaders)));
  }

  // ---------- Tepkiler ----------

  Future<List<String>> _loadEmojis() async {
    final cached = _emojis;
    if (cached != null) return cached;
    try {
      final r = await _api.get('/messages/reactions') as Map<String, dynamic>;
      _emojis = (r['emojis'] as List? ?? []).map((e) => '$e').toList();
    } catch (_) {
      return const [];
    }
    return _emojis!;
  }

  Future<void> _react(Map<String, dynamic> m, String emoji) async {
    final id = (m['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      final same = m['myReaction'] == emoji;
      final res = (same ? await _api.delete('/messages/$id/reaction') : await _api.put('/messages/$id/reaction', {'emoji': emoji}))
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        m['reactions'] = res['reactions'];
        m['myReaction'] = res['myReaction'];
      });
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _saveEdit(Map<String, dynamic> target, String text) async {
    final id = (target['id'] as num).toInt();
    try {
      final res = await _api.patch('/messages/$id', {'text': text}) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _merge([res]);
        _editing = null;
        _input.clear();
      });
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> m) async {
    final ok = await _confirm('Mesaj silinsin mi?', 'Bu mesaj herkes için silinir.', 'Sil');
    if (ok != true) return;
    try {
      await _api.delete('/messages/${(m['id'] as num).toInt()}');
      if (!mounted) return;
      setState(() {
        m['deleted'] = true;
        m['text'] = 'Bu mesaj silindi';
        m['removed'] = true;
        m['replyTo'] = null;
      });
    } catch (e) {
      _toast(errorText(e));
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  // ---------- Yardımcılar ----------

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool?> _confirm(String title, String body, String action) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(action, style: TextStyle(color: c.bu.danger)),
          ),
        ],
      ),
    );
  }

  String _nameOf(int? id) {
    if (id != null && id == _myId) return 'Sen';
    if (id != null && _names[id] != null) return _names[id]!;
    final p = _peer;
    if (_direct && p != null && (p['id'] as num?)?.toInt() == id) return (p['displayName'] as String?) ?? 'Kullanıcı';
    return 'Kullanıcı';
  }

  String get _title {
    if (_direct) return (_peer?['displayName'] as String?) ?? (_conv['title'] as String?) ?? 'Sohbet';
    return (_conv['title'] as String?) ?? 'Grup';
  }

  String? get _avatarUrl => _direct ? (_peer?['avatarUrl'] as String?) : null;

  bool _isMine(Map<String, dynamic> m) {
    final s = (m['senderId'] as num?)?.toInt();
    return s != null && s == _myId;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  DateTime? _time(Map<String, dynamic> m) => DateTime.tryParse((m['createdAt'] as String?) ?? '')?.toLocal();

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Dün';
    return '${_two(d.day)}.${_two(d.month)}.${d.year}';
  }

  String? _statusText() {
    if (_direct) {
      final p = _presence;
      if (p == null) return null;
      if (p['online'] == true) return 'Çevrimiçi';
      final seen = DateTime.tryParse((p['lastSeenAt'] as String?) ?? '')?.toLocal();
      if (seen == null) return null;
      final label = _dayLabel(seen);
      return label == 'Bugün' || label == 'Dün'
          ? 'Son görülme: ${label.toLowerCase()} ${_hm(seen)}'
          : 'Son görülme: $label';
    }
    final n = (_conv['memberCount'] as num?)?.toInt() ?? _members.length;
    final kind = _type == 'CLUB' ? 'Kulüp odası · ' : _type == 'EVENT' ? 'Etkinlik odası · ' : '';
    return n > 0 ? '$kind$n üye' : (kind.isEmpty ? null : 'Kulüp/etkinlik odası');
  }

  // ---------- Menüler ----------

  Future<void> _openMessageMenu(Map<String, dynamic> m) async {
    if (m['id'] == null) {
      if (m['_state'] == 'failed') {
        await _failedMenu(m);
      }
      return;
    }
    final deleted = m['deleted'] == true || m['removed'] == true;
    final mine = _isMine(m);
    final canDelete = !deleted && (mine || (!_direct && _conv['admin'] == true));
    final emojis = deleted ? const <String>[] : await _loadEmojis();
    if (!mounted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.bu.sf,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (emojis.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                for (final e in emojis)
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => Navigator.pop(c, 'react:$e'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: m['myReaction'] == e ? c.bu.pr.withValues(alpha: .15) : c.bu.sf2,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ]),
            ),
          if (!deleted && !_blocked) BuMenuRow(icon: LucideIcons.reply, label: 'Yanıtla', showChevron: false, onTap: () => Navigator.pop(c, 'reply')),
          if (!deleted) BuMenuRow(icon: LucideIcons.copy, label: 'Kopyala', showChevron: false, onTap: () => Navigator.pop(c, 'copy')),
          if (!deleted && mine) BuMenuRow(icon: LucideIcons.pencil, label: 'Düzenle', showChevron: false, onTap: () => Navigator.pop(c, 'edit')),
          if (canDelete) BuMenuRow(icon: LucideIcons.trash2, label: 'Sil', danger: true, showChevron: false, onTap: () => Navigator.pop(c, 'delete')),
          if (!deleted && !mine) BuMenuRow(icon: LucideIcons.flag, label: 'Şikâyet et', danger: true, showChevron: false, onTap: () => Navigator.pop(c, 'report')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    if (action.startsWith('react:')) {
      await _react(m, action.substring(6));
      return;
    }
    switch (action) {
      case 'reply':
        setState(() {
          _replyTo = m;
          _editing = null;
        });
        _focus.requestFocus();
      case 'copy':
        await Clipboard.setData(ClipboardData(text: (m['text'] as String?) ?? ''));
        _toast('Mesaj kopyalandı');
      case 'edit':
        setState(() {
          _editing = m;
          _replyTo = null;
          _input.text = (m['text'] as String?) ?? '';
          _input.selection = TextSelection.collapsed(offset: _input.text.length);
        });
        _focus.requestFocus();
      case 'delete':
        await _deleteMessage(m);
      case 'report':
        await ReportSheet.showForMessage(context, widget.session, messageId: (m['id'] as num).toInt());
    }
  }

  Future<void> _failedMenu(Map<String, dynamic> m) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.bu.sf,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BuMenuRow(icon: LucideIcons.rotateCw, label: 'Yeniden dene', showChevron: false, onTap: () => Navigator.pop(c, 'retry')),
          BuMenuRow(icon: LucideIcons.trash2, label: 'Sil', danger: true, showChevron: false, onTap: () => Navigator.pop(c, 'drop')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted) return;
    if (action == 'retry') {
      await _retry(m);
    } else if (action == 'drop') {
      setState(() => _msgs.remove(m));
    }
  }

  Future<void> _openChatMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.bu.sf,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_roomPage) BuMenuRow(icon: LucideIcons.arrowUpRight, label: _type == 'CLUB' ? 'Kulüp sayfası' : 'Etkinlik sayfası', showChevron: false, onTap: () => Navigator.pop(c, 'room')),
          if (!_direct) BuMenuRow(icon: LucideIcons.users, label: 'Üyeler', showChevron: false, onTap: () => Navigator.pop(c, 'members')),
          if (!_direct && !_room) BuMenuRow(icon: LucideIcons.logOut, label: 'Sohbetten ayrıl', danger: true, showChevron: false, onTap: () => Navigator.pop(c, 'leave')),
          if (_direct && !_blocked) BuMenuRow(icon: LucideIcons.ban, label: 'Engelle', danger: true, showChevron: false, onTap: () => Navigator.pop(c, 'block')),
          if (_direct && _blocked) BuMenuRow(icon: LucideIcons.ban, label: 'Engeli kaldır', showChevron: false, onTap: () => Navigator.pop(c, 'unblock')),
          if (_direct) BuMenuRow(icon: LucideIcons.flag, label: 'Kullanıcıyı şikâyet et', danger: true, showChevron: false, onTap: () => Navigator.pop(c, 'report')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    final pid = (_peer?['id'] as num?)?.toInt();
    try {
      switch (action) {
        case 'room':
          _openRoomPage();
        case 'members':
          await _showMembers();
        case 'leave':
          final ok = await _confirm('Sohbetten ayrılınsın mı?', 'Bu sohbetten ayrılırsınız.', 'Ayrıl');
          if (ok != true) return;
          await _api.post('/conversations/$_cid/leave');
          if (mounted) Navigator.pop(context, true);
        case 'block':
          if (pid == null) return;
          final ok = await _confirm('Kullanıcı engellensin mi?', 'Engellediğiniz kişiyle mesajlaşamazsınız.', 'Engelle');
          if (ok != true) return;
          await _api.post('/users/$pid/block');
          _changed = true;
          if (mounted) setState(() => _conv['blocked'] = true);
          _toast('Kullanıcı engellendi');
        case 'unblock':
          if (pid == null) return;
          await _api.delete('/users/$pid/block');
          _changed = true;
          if (mounted) setState(() => _conv['blocked'] = false);
          _toast('Engel kaldırıldı');
        case 'report':
          if (pid == null) return;
          await ReportSheet.show(context, widget.session, targetType: 'USER', targetId: pid, title: 'Kullanıcıyı şikâyet et');
      }
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _showMembers() async {
    if (_members.isEmpty) await _loadDetail();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.bu.sf,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) {
        final t = c.bu;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * .7),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), children: [
              Text('Üyeler (${_members.length})', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (_members.isEmpty) Text('Üye listesi alınamadı.', style: TextStyle(color: t.mut)),
              for (final m in _members)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    BuAvatar(name: m['displayName'] as String?, url: m['avatarUrl'] as String?, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text((m['displayName'] as String?) ?? 'Kullanıcı',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    if ((m['role'] as String?) == 'ADMIN' || (m['role'] as String?) == 'OWNER') const BuBadge('Yönetici'),
                  ]),
                ),
            ]),
          ),
        );
      },
    );
  }

  // ---------- Arayüz ----------

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: t.bg,
        resizeToAvoidBottomInset: true,
        body: Column(children: [
          _topBar(t),
          Expanded(child: _body(t)),
          _composer(t),
        ]),
      ),
    );
  }

  Widget _topBar(BuTokens t) {
    final status = _statusText();
    final online = _direct && _presence?['online'] == true;
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
      decoration: BoxDecoration(color: t.sf, border: Border(bottom: BorderSide(color: t.bd))),
      child: Row(children: [
        BuIconButton(icon: LucideIcons.arrowLeft, tooltip: 'Geri', filled: true, onTap: () => Navigator.pop(context, _changed)),
        const SizedBox(width: 12),
        BuAvatar(name: _title, url: _avatarUrl, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: _roomPage ? _openRoomPage : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.w800)),
              ValueListenableBuilder<bool>(
                valueListenable: _typingNow,
                builder: (c, typing, _) {
                  final text = typing ? 'yazıyor…' : status;
                  if (text == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: (online || typing) ? t.ok : t.mut, fontSize: 12, fontWeight: FontWeight.w700)),
                  );
                },
              ),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        BuIconButton(icon: LucideIcons.ellipsisVertical, tooltip: 'Menü', filled: true, onTap: _openChatMenu),
      ]),
    );
  }

  Widget _body(BuTokens t) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(error: _error!, onRetry: _boot);
    if (_msgs.isEmpty) {
      return const EmptyView(icon: LucideIcons.messageCircle, text: 'Henüz mesaj yok. İlk mesajı sen yaz.');
    }
    return ValueListenableBuilder<int>(
      valueListenable: _peerRead,
      builder: (c, peerRead, _) => _list(t, peerRead),
    );
  }

  Widget _list(BuTokens t, int peerRead) {
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _msgs.length + 1,
      itemBuilder: (c, i) {
        if (i == _msgs.length) {
          return _loadingMore
              ? const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
              : const SizedBox(height: 4);
        }
        final m = _msgs[i];
        final older = i + 1 < _msgs.length ? _msgs[i + 1] : null;
        final d = _time(m);
        final od = older == null ? null : _time(older);
        final newDay = d != null && (od == null || od.year != d.year || od.month != d.month || od.day != d.day);
        // Kronolojik olarak bu mesajdan önce (listede bir altta) gelen mesajla aynı göndericiyse aralık küçük.
        final tight = older != null && older['senderId'] == m['senderId'] && !newDay;
        return Column(children: [
          if (newDay) _dayChip(t, _dayLabel(d)),
          Padding(padding: EdgeInsets.only(top: tight ? 3 : 8), child: _bubble(m, peerRead)),
        ]);
      },
    );
  }

  Widget _dayChip(BuTokens t, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(999)),
          child: Text(label, style: TextStyle(color: t.mut, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _bubble(Map<String, dynamic> m, int peerRead) {
    final mine = _isMine(m) || m['_state'] != null;
    final id = (m['id'] as num?)?.toInt();
    final reply = m['replyTo'] is Map ? m['replyTo'] as Map : null;
    return MessageBubble(
      message: m,
      mine: mine,
      senderName: (!mine && !_direct) ? _nameOf((m['senderId'] as num?)?.toInt()) : null,
      replyName: reply == null ? null : _nameOf((reply['senderId'] as num?)?.toInt()),
      seen: mine && id != null && id <= peerRead,
      authHeaders: _authHeaders,
      onMenu: () => _openMessageMenu(m),
      onRetry: () => _retry(m),
      onOpenImage: _openImage,
      onReact: (e) => _react(m, e),
    );
  }

  Widget _composer(BuTokens t) {
    if (_blocked) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(color: t.sf, border: Border(top: BorderSide(color: t.bd))),
        child: Text('Bu kullanıcıyla mesajlaşamazsınız.', textAlign: TextAlign.center, style: TextStyle(color: t.mut, fontSize: 13, fontWeight: FontWeight.w600)),
      );
    }
    return ListenableBuilder(listenable: _input, builder: (c, _) => _composerBody(t));
  }

  Widget _composerBody(BuTokens t) {
    final len = _input.text.characters.length;
    final canSend = _input.text.trim().isNotEmpty && len <= _maxLen;
    final banner = _editing ?? _replyTo;
    return Container(
      decoration: BoxDecoration(color: t.sf, border: Border(top: BorderSide(color: t.bd))),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (banner != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(_editing != null ? LucideIcons.pencil : LucideIcons.reply, size: 16, color: t.pr),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_editing != null ? 'Mesaj düzenleniyor' : _nameOf((banner['senderId'] as num?)?.toInt()),
                      style: TextStyle(color: t.ink, fontSize: 11, fontWeight: FontWeight.w800)),
                  Text((banner['text'] as String?) ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.mut, fontSize: 12)),
                ]),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Vazgeç',
                icon: Icon(LucideIcons.x, size: 18, color: t.mut),
                onPressed: () => setState(() {
                  if (_editing != null) _input.clear();
                  _editing = null;
                  _replyTo = null;
                }),
              ),
            ]),
          ),
        if (len >= 1500)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('$len/$_maxLen',
                  style: TextStyle(color: len > _maxLen ? t.danger : t.mut, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (_editing == null) ...[
            IconButton(
              tooltip: 'Görsel gönder',
              onPressed: _pickImage,
              icon: Icon(LucideIcons.image, color: t.mut),
            ),
          ],
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(23)),
              alignment: Alignment.center,
              child: TextField(
                controller: _input,
                focusNode: _focus,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                style: TextStyle(color: t.ink, fontSize: 14),
                cursorColor: t.pr,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  hintText: 'Mesaj yaz',
                  hintStyle: TextStyle(color: t.mut, fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: _editing != null ? 'Kaydet' : 'Gönder',
            child: GestureDetector(
              onTap: canSend ? _submit : null,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: canSend ? t.pr : t.pr.withValues(alpha: .4), shape: BoxShape.circle),
                child: Icon(_editing != null ? LucideIcons.check : LucideIcons.send, size: 22, color: t.onPr),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
