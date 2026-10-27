import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart' show VideoPlayerController;

import '../../core/api.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/platform/image_service.dart';
import '../../core/platform/video_service.dart';
import '../../core/realtime/chat_realtime.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/report_sheet.dart';
import '../clubs/club_detail_page.dart';
import '../profile/user_profile_page.dart';
import '../events/event_detail_page.dart';
import 'chat_info_page.dart';
import 'chat_media.dart';
import 'chat_media_viewer.dart';
import 'chat_video_player.dart';
import 'forward_sheet.dart';
import 'view_once_viewer.dart';
import 'message_actions.dart';
import 'media_camera_page.dart';
import 'media_library.dart';
import 'media_pick.dart';
import 'media_picker_page.dart';
import 'media_preview_page.dart';
import 'message_bubble.dart';

/// "Video hazırlanıyor… %N" penceresi (iptal edilebilir). Kapatmayı çağıran yapar.
class _VideoPrepareDialog extends StatelessWidget {
  const _VideoPrepareDialog({required this.progress, required this.cancel});

  final ValueListenable<double> progress;
  final VideoCancel cancel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const ValueKey('videoPrepare'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (c, v, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Video hazırlanıyor… %${(v * 100).round()}',
                    style: BuType.bodyStrong.copyWith(color: t.ink)),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                    value: v > 0 ? v : null,
                    color: t.pr,
                    backgroundColor: t.sf2),
              ]),
        ),
        actions: [
          TextButton(onPressed: cancel.cancel, child: const Text('İptal')),
        ],
      ),
    );
  }
}

/// Sohbet detayı: mesaj geçmişi (imleçli), iyimser gönderim, yanıt/düzenle/sil/tepki, görsel gönderme.
/// Gerçek zamanlı (STOMP) çalışır; bağlı değilken 4 sn'lik `after` yoklamasına düşer.
class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.session,
    required this.conversation,
    @visibleForTesting this.connectRealtime = true,
    @visibleForTesting this.realtime,
    @visibleForTesting this.mediaLibrary,
    @visibleForTesting this.openCamera,
    @visibleForTesting this.uploadClient,
    @visibleForTesting this.videoService,
    @visibleForTesting this.ensureAccess,
    @visibleForTesting this.videoControllerFactory,
  });

  final Session session;
  final Map<String, dynamic> conversation;

  /// Testlerde false: gerçek WebSocket bağlantısı kurulmaz.
  final bool connectRealtime;

  /// Testlerde enjekte edilen gerçek zamanlı katman (yoksa kendisi oluşturur).
  final ChatRealtime? realtime;

  /// Testlerde galeri sağlayıcısı (yoksa `photo_manager`).
  final MediaLibrary? mediaLibrary;

  /// Testlerde kamera ekranı yerine kullanılır.
  final MediaCameraLauncher? openCamera;

  /// Testlerde görsel yükleme istemcisi.
  final http.Client? uploadClient;

  /// Testlerde video seçici/sıkıştırıcı (yoksa platform uygulaması).
  final VideoService? videoService;

  /// Testlerde izin istemi yerine kullanılır (yoksa [ensurePermission]).
  final Future<bool> Function(BuildContext context, AppPermission permission,
      {String? rationale})? ensureAccess;

  /// Testlerde sahte oynatıcı denetleyicisi.
  final VideoControllerFactory? videoControllerFactory;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage>
    with WidgetsBindingObserver {
  static const _maxLen = 2000;
  static const _pollInterval = Duration(seconds: 4);

  late Map<String, dynamic> _conv =
      Map<String, dynamic>.from(widget.conversation);

  /// En yeni başta (ListView reverse). Yerel bekleyen/başarısız mesajlar `id == null`.
  final List<Map<String, dynamic>> _msgs = [];
  final _names = <int, String>{};
  final _avatars = <int, String?>{};
  List<Map<String, dynamic>> _members = [];

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  late final ChatRealtime _rt = widget.realtime ?? ChatRealtime(widget.session);
  final _subs = <StreamSubscription<dynamic>>[];
  final _ackTimers = <String, Timer>{};
  final _image = ImageService();
  late final _uploader = MultipartUploader(widget.session, client: widget.uploadClient);
  late final _videoUploader = VideoUploader(widget.session, client: widget.uploadClient);
  late final VideoService _video = widget.videoService ?? VideoService();

  /// "İletildi" ack'i: gönderilen en yüksek karşı taraf mesaj id'si ve 1 sn'lik debounce zamanlayıcısı.
  int _lastDelivered = 0;
  Timer? _deliveredTimer;
  List<String>? _emojis;
  bool _rtOn = false;

  /// Aşağı kaydır düğmesi: liste en altta değilken görünür; arka planda gelen okunmamış sayısı.
  final _showDown = ValueNotifier<bool>(false);
  final _newBelow = ValueNotifier<int>(0);

  /// Sohbet içi arama: eşleşen mesaj id'leri (yeniden eskiye), geçerli sıra.
  bool _searching = false;
  String _query = '';
  List<int> _matches = [];
  int _matchPos = -1;
  bool _searchOlderBusy = false;
  final _searchCtl = TextEditingController();
  final _searchFocus = FocusNode();

  /// Karşı tarafın okuduğu son mesaj id'si ve "yazıyor" göstergesi (yalnız ilgili widget'ları yeniler).
  final _peerRead = ValueNotifier<int>(0);
  final _typingNow = ValueNotifier<bool>(false);
  Timer? _typingOff;

  /// Alıntıya dokununca kaydırılan mesajın kısa süreli vurgusu; satır anahtarları kaydırma için.
  final _hi = ValueNotifier<int?>(null);
  Timer? _hiOff;
  final _rowKeys = <int, GlobalKey>{};

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
  Map<String, dynamic>? get _peer => _conv['peer'] is Map
      ? Map<String, dynamic>.from(_conv['peer'] as Map)
      : null;
  bool get _blocked => _conv['blocked'] == true;
  bool get _room => _type == 'CLUB' || _type == 'EVENT';
  int? get _roomTargetId =>
      ((_type == 'CLUB' ? _conv['communityId'] : _conv['eventId']) as num?)
          ?.toInt();
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

  /// Gönderen avatarı/adı ya da birebirde karşı kişinin avatarı: kullanıcı profili.
  void _openProfileOf(int? uid) {
    if (uid == null || uid == _myId) return;
    openUserProfile(context, widget.session,
        userId: uid,
        name: _nameOf(uid),
        avatarUrl: (_direct && (_peer?['id'] as num?)?.toInt() == uid)
            ? (_peer?['avatarUrl'] as String?)
            : _avatars[uid],
        fromConversationId: _cid);
  }

  /// Başlığa dokununca: sohbet bilgisi + medya ızgarası.
  Future<void> _openInfo() async {
    final res = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => ChatInfoPage(
          session: widget.session,
          conversation: _conv,
          members: _members,
          subtitle: _statusText(),
          onOpenRoom: _roomPage ? _openRoomPage : null,
        ),
      ),
    );
    if (!mounted) return;
    if (res == 'search') {
      _startSearch();
    } else if (res == 'left') {
      Navigator.pop(context, true); // liste yenilensin
    }
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
    _deliveredTimer?.cancel();
    _typingOff?.cancel();
    _hiOff?.cancel();
    _hi.dispose();
    _showDown.dispose();
    _newBelow.dispose();
    _searchCtl.dispose();
    _searchFocus.dispose();
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
      _scheduleDelivered();
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
      final ms = (d['members'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
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
      (page['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  int? get _newestServerId {
    for (final m in _msgs) {
      final id = (m['id'] as num?)?.toInt();
      if (id != null) return id;
    }
    return null;
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300)
      _loadOlder();
    final away = _scroll.position.pixels > 200;
    if (_showDown.value != away) _showDown.value = away;
    if (!away && _newBelow.value != 0) _newBelow.value = 0;
  }

  Future<void> _loadOlder() async {
    final before = _beforeCursor;
    if (before == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page =
          await _api.get('/conversations/$_cid/messages?size=30&before=$before')
              as Map<String, dynamic>;
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
        final page = await _api.get('/conversations/$_cid/messages?size=30')
            as Map<String, dynamic>;
        added = _mergeCount(_items(page)) > 0 || added;
      }
      if (_tick % 8 == 0) _loadPresence();
      if (mounted) {
        setState(() {});
        if (added) _markRead();
        _scheduleDelivered();
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
      final page = await _api.get('/conversations/$_cid/messages?size=30')
          as Map<String, dynamic>;
      return _mergeCount(_items(page)) > 0;
    }
    var added = false;
    var cursor = newest;
    for (var i = 0; i < 5; i++) {
      final page =
          await _api.get('/conversations/$_cid/messages?after=$cursor&size=30')
              as Map<String, dynamic>;
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
        if (r.conversationId == _cid && r.userId != _myId) {
          _advanceStatus(r.lastMessageId, 'READ');
          if (r.lastMessageId > _peerRead.value) {
            _peerRead.value = r.lastMessageId;
          }
        }
      }),
      _rt.receipts.listen((e) {
        if (e.conversationId == _cid) {
          _advanceStatus(e.upToMessageId, e.effectiveStatus);
        }
      }),
      _rt.viewed.listen((e) {
        if (e.conversationId != _cid) return;
        final i =
            _msgs.indexWhere((m) => (m['id'] as num?)?.toInt() == e.messageId);
        if (i < 0 || !mounted) return;
        setState(() => _markViewed(_msgs[i], e.attachmentId));
      }),
      _rt.typing.listen((e) {
        if (e.conversationId != _cid || e.userId == _myId) return;
        _typingNow.value = true;
        _typingOff?.cancel();
        _typingOff =
            Timer(const Duration(seconds: 4), () => _typingNow.value = false);
      }),
      _rt.errors.listen((e) {
        final cid = e.clientId;
        if (cid == null) return;
        _ackTimers.remove(cid)?.cancel();
        final i =
            _msgs.indexWhere((m) => m['id'] == null && m['clientId'] == cid);
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
      _scheduleDelivered();
    }
  }

  // ---------- Makbuz (tik) durumu ----------

  static const _statusRank = {'SENT': 1, 'DELIVERED': 2, 'READ': 3};

  int _rankOf(Object? status) => _statusRank[status] ?? 1;

  /// Kendi mesajlarımın durumunu `upTo` id'sine kadar [status]'a ilerletir (asla geri gitmez).
  void _advanceStatus(int upTo, String status) {
    final r = _statusRank[status];
    if (r == null) return;
    var changed = false;
    for (final m in _msgs) {
      final id = (m['id'] as num?)?.toInt();
      if (id == null || id > upTo || !_isMine(m)) continue;
      if (_rankOf(m['status']) < r) {
        m['status'] = status;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  int? get _newestPeerId {
    for (final m in _msgs) {
      final id = (m['id'] as num?)?.toInt();
      if (id != null && !_isMine(m)) return id;
    }
    return null;
  }

  /// Karşı tarafın en yeni mesajı ekrana ulaştığında "iletildi" bilgisini (1 sn debounce) gönderir;
  /// yalnız en yüksek id ilerlediğinde.
  void _scheduleDelivered() {
    final id = _newestPeerId;
    if (id == null || id <= _lastDelivered) return;
    if (_deliveredTimer?.isActive == true) return;
    _deliveredTimer = Timer(const Duration(seconds: 1), _sendDelivered);
  }

  Future<void> _sendDelivered() async {
    final id = _newestPeerId;
    if (id == null || id <= _lastDelivered || !mounted) return;
    _lastDelivered = id;
    if (_rtOn && _rt.sendDelivered(_cid, id)) return;
    try {
      await _api.post('/conversations/$_cid/delivered', {'lastMessageId': id});
    } catch (_) {
      if (_lastDelivered == id) _lastDelivered = 0; // sonraki turda yeniden denenir
    }
  }

  /// Gelen mesajları listeye katar; yeni eklenen sayısını döndürür.
  int _mergeCount(List<Map<String, dynamic>> incoming) {
    final before = _msgs.length;
    _merge(incoming);
    return _msgs.length - before;
  }

  /// Ekin "açıldı" bilgisini yerelde işler (gönderen baloncuğu "Açıldı" olur).
  void _markViewed(Map<String, dynamic> m, int attachmentId) {
    final atts = m['attachments'];
    if (atts is! List) return;
    for (final a in atts) {
      if (a is Map && (a['id'] as num?)?.toInt() == attachmentId) {
        a['viewed'] = true;
        if (!_isMine(m)) a['url'] = null;
      }
    }
  }

  void _merge(List<Map<String, dynamic>> incoming) {
    final newest = _newestServerId ?? 0;
    for (final m in incoming) {
      final id = (m['id'] as num?)?.toInt();
      final cid = m['clientId'] as String?;
      var idx = _msgs
          .indexWhere((e) => id != null && (e['id'] as num?)?.toInt() == id);
      if (idx < 0 && cid != null) {
        idx = _msgs.indexWhere((e) => e['id'] == null && e['clientId'] == cid);
      }
      if (idx >= 0) {
        // Gecikmiş bir yanıt, gerçek zamanlı olayla ilerlemiş durumu geri almasın.
        final old = _msgs[idx];
        if (old['status'] != null && _rankOf(old['status']) > _rankOf(m['status'])) {
          m['status'] = old['status'];
        }
        _msgs[idx] = m;
      } else {
        _msgs.add(m);
        // Aşağıda değilken gelen yeni (başkasının) mesajlar düğmedeki rozeti artırır.
        if (id != null && id > newest && !_isMine(m) && _showDown.value)
          _newBelow.value++;
      }
    }
    _msgs.sort((a, b) => _key(b).compareTo(_key(a)));
  }

  int _key(Map<String, dynamic> m) =>
      (m['id'] as num?)?.toInt() ?? (1 << 50) + ((m['_seq'] as int?) ?? 0);

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
    if (_input.text.isNotEmpty && _editing == null && _rtOn)
      _rt.sendTyping(_cid);
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
          : {
              'id': reply['id'],
              'senderId': reply['senderId'],
              'text': reply['text'],
              'deleted': false
            },
      '_state': 'pending',
      '_seq': _seq++,
    };
  }

  /// Bağlıysa WS ile (8 sn içinde ack gelmezse aynı clientId ile REST yedeği), değilse doğrudan REST.
  /// Görselli mesajlar önce yüklenir, `attachmentIds` ile REST'ten gönderilir.
  Future<void> _transmit(Map<String, dynamic> local) async {
    final cid = local['clientId'] as String;
    final uploads = _uploadsOf(local);
    try {
      for (final u in uploads) {
        if (u['attId'] != null) continue;
        final image = u['image'] as PreparedImage?;
        final video = u['video'] as PreparedVideo?;
        if (image != null) {
          final res =
              await _uploader.upload('/conversations/$_cid/media', image) as Map;
          u['attId'] = (res['id'] as num).toInt();
        } else if (video != null) {
          final prog = u['progress'];
          if (prog is ValueNotifier<double>) prog.value = 0;
          final res = await _videoUploader.upload(
              '/conversations/$_cid/media', video, onProgress: (p) {
            if (prog is ValueNotifier<double>) prog.value = p;
          }) as Map;
          u['attId'] = (res['id'] as num).toInt();
        }
      }
      if (uploads.isEmpty &&
          local['replyToMessageId'] == null &&
          _rtOn &&
          _rt.sendMessage(_cid, local['text'] as String, cid)) {
        _ackTimers[cid]?.cancel();
        _ackTimers[cid] = Timer(const Duration(seconds: 8), () {
          _ackTimers.remove(cid);
          if (mounted && local['_state'] == 'pending' && local['id'] == null)
            _sendRest(local);
        });
        return;
      }
      await _sendRest(local);
    } catch (e) {
      _fail(local, e);
    }
  }

  List<Map<String, dynamic>> _uploadsOf(Map<String, dynamic> local) =>
      (local['_uploads'] as List?)?.cast<Map<String, dynamic>>() ??
      const <Map<String, dynamic>>[];

  Future<void> _sendRest(Map<String, dynamic> local) async {
    try {
      final ids = [
        for (final u in _uploadsOf(local))
          if (u['attId'] != null) u['attId'] as int
      ];
      final res = await _api.post('/conversations/$_cid/messages', {
        'text': local['text'],
        'clientId': local['clientId'],
        if (local['replyToMessageId'] != null)
          'replyToMessageId': local['replyToMessageId'],
        if (ids.isNotEmpty) 'attachmentIds': ids,
        if (ids.isNotEmpty && local['_viewOnce'] == true) 'viewOnce': true,
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
    // Engel bilgisi sızdırılmaz: olası engel hata kodları yok sayılır (mesaj gönderilmiş görünür).
    if (e is ApiError && (e.code == 'BLOCKED' || e.code == 'USER_BLOCKED')) {
      setState(() => local['_state'] = null);
      return;
    }
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

  // ---------- Medya (galeri / kamera / önizleme) ----------

  /// Ek düğmesi: doğrudan tüm galeriyi açar; seçim önizlemeden geçip gönderilir.
  Future<void> _openGallery() async {
    final plan = await Navigator.push<MediaSendPlan>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPickerPage(
          library: widget.mediaLibrary ?? PhotoManagerLibrary(),
          ensureAccess: widget.ensureAccess,
          openCamera: widget.openCamera,
        ),
      ),
    );
    if (plan == null || !mounted) return;
    await _sendPlan(plan);
  }

  /// Yazı alanındaki kamera kısayolu: kamera -> önizleme -> gönder.
  Future<void> _openCameraShortcut() async {
    final pick = await (widget.openCamera ?? openMediaCamera)(context);
    if (pick == null || !mounted) return;
    final plan = await Navigator.push<MediaSendPlan>(
      context,
      MaterialPageRoute(builder: (_) => MediaPreviewPage(picks: [pick])),
    );
    if (plan == null || !mounted) return;
    await _sendPlan(plan);
  }

  static String _videoErrorText(String code) => switch (code) {
        'TOO_LONG' => 'Video en fazla 60 saniye olabilir',
        'TOO_LARGE' => 'Video çok büyük, daha kısa bir video seçin',
        'UNSUPPORTED' => 'Bu cihazda video gönderilemiyor.',
        _ => 'Video hazırlanamadı.',
      };

  /// Planı mesajlara böler (bkz. [planMessages]), öğeleri hazırlar, yerel baloncukları sırayla ekler ve yükler.
  Future<void> _sendPlan(MediaSendPlan plan) async {
    final locals = <Map<String, dynamic>>[];
    var splitNotified = false;
    for (final mp in planMessages(plan)) {
      final prepared = <Map<String, dynamic>>[];
      for (final p in mp.picks) {
        final u = await _prepareUpload(p);
        if (!mounted) return;
        if (u != null) prepared.add(u);
      }
      if (prepared.isEmpty) continue;
      // Mesaj başına video bayt toplamı sınırı: gerekirse birden çok mesaja bölünür.
      final parts = splitByVideoBytes<Map<String, dynamic>>(
          prepared, (u) => (u['video'] as PreparedVideo?)?.sizeBytes ?? 0);
      if (parts.length > 1 && !splitNotified) {
        splitNotified = true;
        _toast('Videolar büyük olduğu için birden fazla mesaj olarak gönderilecek');
      }
      for (var pi = 0; pi < parts.length; pi++) {
        final uploads = parts[pi];
        final local = _newLocal(pi == 0 ? mp.caption : '')..['_uploads'] = uploads;
        if (locals.isNotEmpty) {
          local['replyToMessageId'] = null; // yanıt yalnız ilk mesajda
          local['replyTo'] = null;
        }
        if (mp.once) {
          // Tek gösterimlikte yerel önizleme de tutulmaz (baloncukta yalnız kart görünür).
          local['_viewOnce'] = true;
        } else {
          // Yerel önizleme: tüm öğeler (ızgara) + ilk öğenin eski alanları.
          local['_localItems'] = [
            for (final u in uploads)
              {
                'bytes': (u['image'] as PreparedImage?)?.bytes ??
                    (u['video'] as PreparedVideo?)?.poster,
                'video': u['video'] != null,
                'durationMs': (u['video'] as PreparedVideo?)?.durationMs,
              }
          ];
          final first = uploads.first;
          final img = first['image'] as PreparedImage?;
          final vid = first['video'] as PreparedVideo?;
          if (img != null) local['_bytes'] = img.bytes;
          if (vid != null) {
            if (vid.poster != null) local['_bytes'] = vid.poster;
            if (uploads.length == 1) {
              local
                ..['_isVideo'] = true
                ..['_durationMs'] = vid.durationMs
                ..['_vw'] = vid.width
                ..['_vh'] = vid.height
                ..['_progress'] = first['progress'];
            }
          }
        }
        locals.add(local);
      }
    }
    if (locals.isEmpty || !mounted) return;
    setState(() {
      for (final l in locals) {
        _msgs.insert(0, l);
      }
      _replyTo = null;
    });
    _scrollToEnd();
    for (final l in locals) {
      await _transmit(l);
    }
  }

  /// Tek öğeyi yüklemeye hazırlar (fotoğraf doğrulama/sıkıştırma, video sıkıştırma). Hata olursa toast + null.
  Future<Map<String, dynamic>?> _prepareUpload(MediaPick p) async {
    if (!p.isVideo) {
      try {
        final bytes = await p.imageBytes?.call();
        if (bytes == null) throw ImageException('EMPTY');
        return {'image': await _image.prepare(bytes)};
      } on ImageException catch (e) {
        _toast(e.code == 'TOO_LARGE'
            ? 'Görsel çok büyük, daha küçük bir görsel seçin.'
            : 'Yalnızca JPEG, PNG veya WebP görseller gönderilebilir.');
      } catch (_) {
        _toast('Görsel okunamadı.');
      }
      return null;
    }
    String? path;
    try {
      path = await p.videoPath?.call();
    } catch (_) {}
    if (path == null) {
      _toast('Video okunamadı.');
      return null;
    }
    if (!mounted) return null;
    final progress = ValueNotifier<double>(0);
    final cancel = VideoCancel();
    // Hazırlık penceresi (iptal edilebilir); iş bitince aşağıda kapatılır.
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VideoPrepareDialog(progress: progress, cancel: cancel),
    ));
    PreparedVideo? prepared;
    String? error;
    try {
      prepared = await _video.prepare(PickedVideo(path),
          onProgress: (v) => progress.value = v, cancel: cancel);
    } on VideoException catch (e) {
      if (e.code != 'CANCELLED') error = _videoErrorText(e.code);
    } catch (_) {
      error = _videoErrorText('FAILED');
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
    if (!mounted) return null;
    if (error != null) {
      _toast(error);
      return null;
    }
    if (prepared == null) return null;
    return {'video': prepared, 'progress': ValueNotifier<double>(0)};
  }

  Future<void> _saveVideo(String url) async {
    String msg;
    try {
      await saveChatVideoToGallery(url, _authHeaders);
      msg = 'Galeriye kaydedildi';
    } catch (e) {
      msg = chatVideoSaveErrorText(e);
    }
    _toast(msg);
  }

  void _openVideo(Map<String, dynamic> a) {
    final url = a['url'] as String?;
    if (url == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatVideoPlayerPage(
          url: url,
          headers: _authHeaders,
          durationMs: (a['durationMs'] as num?)?.toInt(),
          onSave: () => _saveVideo(url),
          controllerFactory: widget.videoControllerFactory ??
              (uri, h) => VideoPlayerController.networkUrl(uri, httpHeaders: h),
        ),
      ),
    );
  }

  Map<String, String> get _authHeaders {
    final tok = _api.tokens?.access;
    return tok == null ? const {} : {'Authorization': 'Bearer $tok'};
  }

  /// Tek gösterimlik fotoğrafı açar: bayt yetkili GET ile alınır; istek tüketilince baloncuk "Açıldı" olur.
  void _openViewOnce(Map<String, dynamic> m, Map<String, dynamic> att) {
    final aid = (att['id'] as num?)?.toInt();
    if (aid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ViewOnceViewer(
          api: _api,
          conversationId: _cid,
          attachmentId: aid,
          onConsumed: () {
            if (!mounted) return;
            setState(() => _markViewed(m, aid));
          },
        ),
      ),
    );
  }

  /// Çok öğeli mesajın tüm medyası; dokunulan öğeden başlayan galeri.
  void _openMessageGallery(List<Map<String, dynamic>> atts, int index) {
    final items = <ChatMediaItem>[];
    var start = 0;
    for (var i = 0; i < atts.length; i++) {
      final it = ChatMediaItem.tryFromAttachment(atts[i]);
      if (it == null) continue;
      if (i == index) start = items.length;
      items.add(it);
    }
    if (items.isEmpty) return;
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => ChatMediaViewer(
                items: items,
                headers: _authHeaders,
                initialIndex: start,
                videoControllerFactory: widget.videoControllerFactory)));
  }

  void _openImage(Map<String, dynamic> a) {
    if (isVideoAttachment(a)) {
      _openVideo(a);
      return;
    }
    final url = (a['url'] ?? a['thumbUrl']) as String?;
    if (url == null) return;
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => ChatImageViewer(url: url, headers: _authHeaders)));
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

  /// Tepki sayaçlarını yerelde günceller (iyimser): eskisini düşer, yenisini ekler.
  List<Map<String, dynamic>> _applyReaction(
      Object? current, String? old, String? next) {
    final list = (current as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    void bump(String emoji, int delta) {
      final i = list.indexWhere((r) => r['emoji'] == emoji);
      if (i < 0) {
        if (delta > 0) list.add({'emoji': emoji, 'count': delta});
        return;
      }
      final c = ((list[i]['count'] as num?)?.toInt() ?? 0) + delta;
      if (c <= 0) {
        list.removeAt(i);
      } else {
        list[i]['count'] = c;
      }
    }

    if (old != null) bump(old, -1);
    if (next != null) bump(next, 1);
    return list;
  }

  Future<void> _react(Map<String, dynamic> m, String emoji) async {
    final id = (m['id'] as num?)?.toInt();
    if (id == null) return;
    final prevList = m['reactions'];
    final prevMine = m['myReaction'] as String?;
    final same = prevMine == emoji;
    setState(() {
      m['reactions'] = _applyReaction(prevList, prevMine, same ? null : emoji);
      m['myReaction'] = same ? null : emoji;
    });
    try {
      final res = (same
              ? await _api.delete('/messages/$id/reaction')
              : await _api.put('/messages/$id/reaction', {'emoji': emoji}))
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        if (res.containsKey('reactions')) m['reactions'] = res['reactions'];
        if (res.containsKey('myReaction')) m['myReaction'] = res['myReaction'];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        m['reactions'] = prevList;
        m['myReaction'] = prevMine;
      });
      _toast(errorText(e));
    }
  }

  /// Alıntılanan mesaja kaydırır ve kısa süre vurgular (yüklü değilse sessizce geçer).
  Future<void> _jumpTo(int id) async {
    var ctx = _rowKeys[id]?.currentContext;
    if (ctx == null) {
      final idx = _msgs.indexWhere((e) => (e['id'] as num?)?.toInt() == id);
      if (idx < 0 || !_scroll.hasClients) return;
      final target = (idx * 76.0).clamp(0.0, _scroll.position.maxScrollExtent);
      await _scroll.animateTo(target,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      ctx = _rowKeys[id]?.currentContext;
    }
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(ctx,
          alignment: .5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut);
    }
    if (!mounted) return;
    _hi.value = id;
    _hiOff?.cancel();
    _hiOff = Timer(const Duration(milliseconds: 1400), () => _hi.value = null);
  }

  Future<void> _saveEdit(Map<String, dynamic> target, String text) async {
    final id = (target['id'] as num).toInt();
    try {
      final res = await _api.patch('/messages/$id', {'text': text})
          as Map<String, dynamic>;
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
    final ok = await _confirm(
        'Mesaj silinsin mi?', 'Bu mesaj herkes için silinir.', 'Sil');
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
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
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
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç')),
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
    if (_direct && p != null && (p['id'] as num?)?.toInt() == id)
      return (p['displayName'] as String?) ?? 'Kullanıcı';
    return 'Kullanıcı';
  }

  String get _title {
    if (_direct)
      return (_peer?['displayName'] as String?) ??
          (_conv['title'] as String?) ??
          'Sohbet';
    return (_conv['title'] as String?) ?? 'Grup';
  }

  String? get _avatarUrl => _direct
      ? (_peer?['avatarUrl'] as String?)
      : (_conv['avatarUrl'] as String?);

  /// Yetkili uçtan (`/api/...`) gelen avatar için Bearer başlığı.
  Map<String, String>? _avatarHeaders(String? url) =>
      (url != null && url.startsWith('/api/')) ? _authHeaders : null;

  bool _isMine(Map<String, dynamic> m) {
    final s = (m['senderId'] as num?)?.toInt();
    return s != null && s == _myId;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  DateTime? _time(Map<String, dynamic> m) =>
      DateTime.tryParse((m['createdAt'] as String?) ?? '')?.toLocal();

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Dün';
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    final base = '${d.day} ${months[d.month - 1]}';
    return d.year == now.year ? base : '$base ${d.year}';
  }

  bool _sameDay(DateTime? a, DateTime? b) =>
      a != null &&
      b != null &&
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  String? _statusText() {
    if (_direct) {
      final p = _presence;
      if (p == null) return null;
      if (p['online'] == true) return 'Çevrimiçi';
      final seen =
          DateTime.tryParse((p['lastSeenAt'] as String?) ?? '')?.toLocal();
      if (seen == null) return null;
      final label = _dayLabel(seen);
      return label == 'Bugün' || label == 'Dün'
          ? 'Son görülme: ${label.toLowerCase()} ${_hm(seen)}'
          : 'Son görülme: $label';
    }
    final n = (_conv['memberCount'] as num?)?.toInt() ?? _members.length;
    final kind = _type == 'CLUB'
        ? 'Kulüp odası · '
        : _type == 'EVENT'
            ? 'Etkinlik odası · '
            : '';
    return n > 0
        ? '$kind$n üye'
        : (kind.isEmpty ? null : 'Kulüp/etkinlik odası');
  }

  // ---------- Menüler ----------

  /// Mesaja uzun basış / dokunuş: tepki hapı + eylem kartı (bkz. message_actions.dart).
  Future<void> _openMessageMenu(Map<String, dynamic> m, Rect anchor) async {
    final failed = m['id'] == null;
    if (failed && m['_state'] != 'failed') return;
    final deleted = m['deleted'] == true || m['removed'] == true;
    final mine = _isMine(m) || m['_state'] != null;
    final hasText = ((m['text'] as String?) ?? '').trim().isNotEmpty;
    final hasAtt = ((m['attachments'] as List?)?.isNotEmpty ?? false) ||
        m['_viewOnce'] == true ||
        m['_uploads'] != null ||
        m['_isVideo'] == true ||
        m['_bytes'] != null;
    final canDelete =
        !failed && !deleted && (mine || (!_direct && _conv['admin'] == true));

    final actions = <MessageAction>[
      if (failed) ...const [
        MessageAction('retry', 'Yeniden gönder', LucideIcons.rotateCw),
        MessageAction('drop', 'Vazgeç', LucideIcons.x, danger: true),
      ] else ...[
        if (!deleted)
          const MessageAction('reply', 'Yanıtla', LucideIcons.reply),
        if (!deleted && hasText)
          const MessageAction('copy', 'Kopyala', LucideIcons.copy),
        if (!deleted && hasText && !hasAtt)
          const MessageAction('forward', 'İlet', LucideIcons.forward),
        if (!deleted && mine && hasText)
          const MessageAction('edit', 'Düzenle', LucideIcons.pencil),
        if (canDelete)
          MessageAction('delete', mine ? 'Herkesten sil' : 'Mesajı sil',
              LucideIcons.trash2,
              danger: true),
        if (!deleted && !mine)
          const MessageAction('report', 'Şikâyet et', LucideIcons.flag,
              danger: true),
      ],
    ];
    final emojis = (deleted || failed) ? const <String>[] : await _loadEmojis();
    if (!mounted || (actions.isEmpty && emojis.isEmpty)) return;

    final action = await showMessageActions(
      context,
      anchor: anchor,
      mine: mine,
      actions: actions,
      emojis: emojis,
      myReaction: m['myReaction'] as String?,
      preview: _bubbleFor(m, preview: true),
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
        await Clipboard.setData(
            ClipboardData(text: (m['text'] as String?) ?? ''));
        _toast('Kopyalandı');
      case 'forward':
        await _forward(m);
      case 'edit':
        setState(() {
          _editing = m;
          _replyTo = null;
          _input.text = (m['text'] as String?) ?? '';
          _input.selection =
              TextSelection.collapsed(offset: _input.text.length);
        });
        _focus.requestFocus();
      case 'delete':
        await _deleteMessage(m);
      case 'report':
        await ReportSheet.showForMessage(context, widget.session,
            messageId: (m['id'] as num).toInt());
      case 'retry':
        await _retry(m);
      case 'drop':
        setState(() => _msgs.remove(m));
    }
  }

  /// Metin mesajını seçilen sohbetlere (en çok 5) aynen gönderir.
  Future<void> _forward(Map<String, dynamic> m) async {
    final text = (m['text'] as String?) ?? '';
    if (text.trim().isEmpty) return;
    final ids = await showForwardSheet(context, _api);
    if (!mounted || ids == null || ids.isEmpty) return;
    var failed = 0;
    for (final id in ids) {
      try {
        final res = await _api.post('/conversations/$id/messages',
            {'text': text, 'clientId': _newClientId()});
        if (id == _cid && res is Map && mounted) {
          setState(() => _merge([Map<String, dynamic>.from(res)]));
          _changed = true;
        }
      } catch (_) {
        failed++;
      }
    }
    _changed = true;
    _toast(failed == 0
        ? 'İletildi'
        : (failed == ids.length
            ? 'İletilemedi'
            : '$failed sohbete iletilemedi'));
  }

  // ---------- Sohbet içi arama ----------

  void _startSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _stopSearch() {
    _searchCtl.clear();
    setState(() {
      _searching = false;
      _query = '';
      _matches = [];
      _matchPos = -1;
    });
  }

  List<int> _findMatches(String needle) {
    if (needle.isEmpty) return [];
    return [
      for (final m in _msgs)
        if (m['id'] != null &&
            m['deleted'] != true &&
            m['removed'] != true &&
            ((m['text'] as String?) ?? '').toLowerCase().contains(needle))
          (m['id'] as num).toInt(),
    ];
  }

  void _onSearchChanged(String q) {
    final needle = q.trim().toLowerCase();
    final ids = _findMatches(needle);
    setState(() {
      _query = needle;
      _matches = ids;
      _matchPos = ids.isEmpty ? -1 : 0;
    });
    if (ids.isNotEmpty) _jumpTo(ids.first);
  }

  /// delta +1: daha eski eşleşme (yukarı ok), -1: daha yeni (aşağı ok).
  Future<void> _stepMatch(int delta) async {
    if (_matches.isEmpty) return;
    var pos = _matchPos + delta;
    if (pos >= _matches.length) {
      if (_beforeCursor != null) {
        await _searchOlder();
        return;
      }
      pos = 0;
    } else if (pos < 0) {
      pos = _matches.length - 1;
    }
    setState(() => _matchPos = pos);
    _jumpTo(_matches[pos]);
  }

  /// Bir sayfa daha eski mesaj çeker ve eşleşmeleri yeniler; mevcut eşleşmeden sonraki eskiye geçer.
  Future<void> _searchOlder() async {
    if (_searchOlderBusy) return;
    setState(() => _searchOlderBusy = true);
    final before = _matches.length;
    await _loadOlder();
    if (!mounted) return;
    final ids = _findMatches(_query);
    setState(() {
      _searchOlderBusy = false;
      _matches = ids;
      _matchPos = ids.isEmpty
          ? -1
          : (ids.length > before
              ? before
              : (_matchPos < 0 ? 0 : _matchPos.clamp(0, ids.length - 1)));
    });
    if (_matchPos >= 0) _jumpTo(_matches[_matchPos]);
  }

  Future<void> _openChatMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.bu.sf,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BuMenuRow(
              icon: LucideIcons.search,
              label: 'Sohbette ara',
              showChevron: false,
              onTap: () => Navigator.pop(c, 'search')),
          if (_roomPage)
            BuMenuRow(
                icon: LucideIcons.arrowUpRight,
                label: _type == 'CLUB' ? 'Kulüp sayfası' : 'Etkinlik sayfası',
                showChevron: false,
                onTap: () => Navigator.pop(c, 'room')),
          if (!_direct)
            BuMenuRow(
                icon: LucideIcons.users,
                label: 'Üyeler',
                showChevron: false,
                onTap: () => Navigator.pop(c, 'members')),
          if (!_direct && !_room)
            BuMenuRow(
                icon: LucideIcons.logOut,
                label: 'Sohbetten ayrıl',
                danger: true,
                showChevron: false,
                onTap: () => Navigator.pop(c, 'leave')),
          if (_direct && !_blocked)
            BuMenuRow(
                icon: LucideIcons.ban,
                label: 'Engelle',
                danger: true,
                showChevron: false,
                onTap: () => Navigator.pop(c, 'block')),
          if (_direct && _blocked)
            BuMenuRow(
                icon: LucideIcons.ban,
                label: 'Engeli kaldır',
                showChevron: false,
                onTap: () => Navigator.pop(c, 'unblock')),
          if (_direct)
            BuMenuRow(
                icon: LucideIcons.flag,
                label: 'Kullanıcıyı şikâyet et',
                danger: true,
                showChevron: false,
                onTap: () => Navigator.pop(c, 'report')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    final pid = (_peer?['id'] as num?)?.toInt();
    try {
      switch (action) {
        case 'search':
          _startSearch();
        case 'room':
          _openRoomPage();
        case 'members':
          await _showMembers();
        case 'leave':
          final ok = await _confirm('Sohbetten ayrılınsın mı?',
              'Bu sohbetten ayrılırsınız.', 'Ayrıl');
          if (ok != true) return;
          await _api.post('/conversations/$_cid/leave');
          if (mounted) Navigator.pop(context, true);
        case 'block':
          if (pid == null) return;
          final ok = await _confirm('Kullanıcı engellensin mi?',
              'Engellediğiniz kişiyle mesajlaşamazsınız.', 'Engelle');
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
          await ReportSheet.show(context, widget.session,
              targetType: 'USER',
              targetId: pid,
              title: 'Kullanıcıyı şikâyet et');
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
            constraints:
                BoxConstraints(maxHeight: MediaQuery.of(c).size.height * .7),
            child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                children: [
                  Text('Üyeler (${_members.length})',
                      style: BuType.heading.copyWith(color: t.ink)),
                  const SizedBox(height: 10),
                  if (_members.isEmpty)
                    Text('Üye listesi alınamadı.',
                        style: BuType.body.copyWith(color: t.mut)),
                  for (final m in _members)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        BuAvatar(
                            name: m['displayName'] as String?,
                            url: m['avatarUrl'] as String?,
                            size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                              (m['displayName'] as String?) ?? 'Kullanıcı',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BuType.bodyStrong.copyWith(color: t.ink)),
                        ),
                        if ((m['role'] as String?) == 'ADMIN' ||
                            (m['role'] as String?) == 'OWNER')
                          const BuBadge('Yönetici'),
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
        if (didPop) return;
        if (_searching) {
          _stopSearch();
          return;
        }
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: t.bg,
        resizeToAvoidBottomInset: true,
        body: Column(children: [
          _searching ? _searchBar(t) : _topBar(t),
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
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 8, 16, 12),
      decoration: BoxDecoration(
          color: t.sf, border: Border(bottom: BorderSide(color: t.bd))),
      child: Row(children: [
        BuIconButton(
            icon: LucideIcons.arrowLeft,
            tooltip: 'Geri',
            filled: true,
            onTap: () => Navigator.pop(context, _changed)),
        const SizedBox(width: 12),
        GestureDetector(
            onTap: _direct
                ? () => _openProfileOf((_peer?['id'] as num?)?.toInt())
                : _openInfo,
            child: BuAvatar(
                name: _title,
                url: _avatarUrl,
                size: 42,
                group: !_direct,
                headers: _avatarHeaders(_avatarUrl))),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: _openInfo,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BuType.heading.copyWith(color: t.ink)),
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
                        style: BuType.caption.copyWith(
                            color: (online || typing) ? t.ok : t.mut,
                            fontWeight: FontWeight.w600)),
                  );
                },
              ),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        BuIconButton(
            icon: LucideIcons.ellipsisVertical,
            tooltip: 'Menü',
            filled: true,
            onTap: _openChatMenu),
      ]),
    );
  }

  Widget _searchBar(BuTokens t) {
    final count = _query.isEmpty
        ? 'Aramak için yazın'
        : (_matches.isEmpty
            ? 'Eşleşme yok'
            : '${_matchPos + 1} / ${_matches.length}');
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 8, 16, 8),
      decoration: BoxDecoration(
          color: t.sf, border: Border(bottom: BorderSide(color: t.bd))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          BuIconButton(
              icon: LucideIcons.x,
              tooltip: 'Aramayı kapat',
              onTap: _stopSearch),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  color: t.sf2, borderRadius: BorderRadius.circular(22)),
              alignment: Alignment.center,
              child: TextField(
                key: const ValueKey('chatSearchField'),
                controller: _searchCtl,
                focusNode: _searchFocus,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                style: BuType.body.copyWith(color: t.ink),
                cursorColor: t.pr,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  hintText: 'Sohbette ara',
                  hintStyle: BuType.body.copyWith(color: t.mut),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
              child: Text(count,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BuType.label.copyWith(color: t.mut))),
          IconButton(
            tooltip: 'Önceki eşleşme',
            visualDensity: VisualDensity.compact,
            icon: Icon(LucideIcons.chevronUp,
                color: _matches.isEmpty ? t.bd : t.ink),
            onPressed: _matches.isEmpty ? null : () => _stepMatch(1),
          ),
          IconButton(
            tooltip: 'Sonraki eşleşme',
            visualDensity: VisualDensity.compact,
            icon: Icon(LucideIcons.chevronDown,
                color: _matches.isEmpty ? t.bd : t.ink),
            onPressed: _matches.isEmpty ? null : () => _stepMatch(-1),
          ),
        ]),
        if (_beforeCursor != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _searchOlderBusy ? null : _searchOlder,
              child: Text(
                  _searchOlderBusy ? 'Aranıyor…' : 'Daha eski mesajlarda ara',
                  style: BuType.label.copyWith(color: t.pr)),
            ),
          ),
      ]),
    );
  }

  Widget _body(BuTokens t) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(error: _error!, onRetry: _boot);
    if (_msgs.isEmpty) {
      return const EmptyView(
          icon: LucideIcons.messageCircle,
          text: 'Henüz mesaj yok. İlk mesajı sen yaz.');
    }
    return Stack(children: [
      Positioned.fill(
        child: ValueListenableBuilder<int>(
          valueListenable: _peerRead,
          builder: (c, peerRead, _) => _list(t, peerRead),
        ),
      ),
      PositionedDirectional(end: 16, bottom: 12, child: _downButton(t)),
    ]);
  }

  Widget _downButton(BuTokens t) {
    return ValueListenableBuilder<bool>(
      valueListenable: _showDown,
      builder: (c, show, _) {
        if (!show) return const SizedBox.shrink();
        return ValueListenableBuilder<int>(
          valueListenable: _newBelow,
          builder: (c, n, _) => Semantics(
            button: true,
            label: n > 0 ? 'En alta in, $n yeni mesaj' : 'En alta in',
            child: GestureDetector(
              key: const ValueKey('scrollDown'),
              onTap: () {
                _newBelow.value = 0;
                _scroll.animateTo(0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut);
              },
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: t.sf,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.bd),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: .12),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Icon(LucideIcons.chevronDown, size: 20, color: t.ink),
                ),
                if (n > 0)
                  PositionedDirectional(
                    top: -6,
                    end: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: t.pr, borderRadius: BorderRadius.circular(10)),
                      child: Text(n > 99 ? '99+' : '$n',
                          style: BuType.micro.copyWith(color: t.onPr)),
                    ),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _list(BuTokens t, int peerRead) {
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView.builder(
          controller: _scroll,
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          itemCount: _msgs.length + 1,
          itemBuilder: (c, i) {
            if (i == _msgs.length) {
              return _loadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))))
                  : const SizedBox(height: 4);
            }
            final m = _msgs[i];
            final newDay = _startsDay(i);
            // Kronolojik olarak bu mesajdan önce (listede bir altta) gelen mesajla aynı göndericiyse aralık küçük.
            final tight = !_firstOfRun(i);
            final id = (m['id'] as num?)?.toInt();
            final row = Padding(
                padding: EdgeInsets.only(top: tight ? 2 : 8),
                child: _rowFor(t, m, i, peerRead));
            return Column(children: [
              if (newDay) _dayChip(t, _dayLabel(_time(m)!)),
              id == null
                  ? row
                  : ValueListenableBuilder<int?>(
                      valueListenable: _hi,
                      child: row,
                      builder: (c, hi, child) => AnimatedContainer(
                        key: _rowKeys.putIfAbsent(id, GlobalKey.new),
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: hi == id
                              ? t.pr.withValues(alpha: .12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: child,
                      ),
                    ),
            ]);
          },
        ));
  }

  // Liste ters sıralıdır: i+1 daha eski, i-1 daha yeni mesajdır.
  bool _startsDay(int i) {
    final d = _time(_msgs[i]);
    if (d == null) return false;
    return i + 1 >= _msgs.length || !_sameDay(d, _time(_msgs[i + 1]));
  }

  bool _firstOfRun(int i) {
    if (i + 1 >= _msgs.length) return true;
    return _msgs[i + 1]['senderId'] != _msgs[i]['senderId'] || _startsDay(i);
  }

  bool _lastOfRun(int i) {
    if (i == 0) return true;
    return _msgs[i - 1]['senderId'] != _msgs[i]['senderId'] ||
        _startsDay(i - 1);
  }

  Widget _dayChip(BuTokens t, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: t.sf2, borderRadius: BorderRadius.circular(999)),
          child: Text(label,
              style: BuType.micro
                  .copyWith(color: t.mut, fontWeight: FontWeight.w600)),
        ),
      );

  /// Satır: grup sohbetinde gelen mesajlarda solda avatar sütunu (yalnız serinin ilk mesajında avatar görünür).
  Widget _rowFor(BuTokens t, Map<String, dynamic> m, int i, int peerRead) {
    final bubble =
        _bubble(m, peerRead, first: _firstOfRun(i), last: _lastOfRun(i));
    final mine = _isMine(m) || m['_state'] != null;
    if (_direct || mine) return bubble;
    final sid = (m['senderId'] as num?)?.toInt();
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 28,
        child: _firstOfRun(i)
            ? GestureDetector(
                key: ValueKey('sender-avatar-${m['id']}'),
                onTap: () => _openProfileOf(sid),
                child: BuAvatar(
                    name: _nameOf(sid),
                    url: sid == null ? null : _avatars[sid],
                    size: 28,
                    headers: _avatarHeaders(sid == null ? null : _avatars[sid])))
            : null,
      ),
      const SizedBox(width: 8),
      Expanded(child: bubble),
    ]);
  }

  /// Menü önizlemesi için: mesajı listedeki konumuna göre kurar.
  Widget _bubbleFor(Map<String, dynamic> m, {bool preview = false}) {
    final i = _msgs.indexOf(m);
    return _bubble(m, _peerRead.value,
        first: i < 0 || _firstOfRun(i),
        last: i < 0 || _lastOfRun(i),
        preview: preview);
  }

  Widget _bubble(Map<String, dynamic> m, int peerRead,
      {bool first = true, bool last = true, bool preview = false}) {
    final mine = _isMine(m) || m['_state'] != null;
    final id = (m['id'] as num?)?.toInt();
    final reply = m['replyTo'] is Map ? m['replyTo'] as Map : null;
    final replyId = (reply?['id'] as num?)?.toInt();
    return MessageBubble(
      message: m,
      mine: mine,
      senderName: (!mine && !_direct && first)
          ? _nameOf((m['senderId'] as num?)?.toInt())
          : null,
      onSenderTap: (!mine && !_direct)
          ? () => _openProfileOf((m['senderId'] as num?)?.toInt())
          : null,
      replyName:
          reply == null ? null : _nameOf((reply['senderId'] as num?)?.toInt()),
      replyMine: reply != null && (reply['senderId'] as num?)?.toInt() == _myId,
      seen: mine && id != null && id <= peerRead,
      authHeaders: _authHeaders,
      tail: last,
      preview: preview,
      onSwipeReply: (preview ||
              id == null ||
              m['_state'] != null ||
              m['deleted'] == true ||
              m['removed'] == true)
          ? null
          : () {
              setState(() {
                _replyTo = m;
                _editing = null;
              });
              _focus.requestFocus();
            },
      onMenu: () {},
      onMenuRect: (r) => _openMessageMenu(m, r),
      onReplyTap: replyId == null ? null : () => _jumpTo(replyId),
      onRetry: () => _retry(m),
      onOpenImage: _openImage,
      onOpenGallery: _openMessageGallery,
      onOpenViewOnce: (a) => _openViewOnce(m, a),
      highlight: (_searching && _query.isNotEmpty) ? _query : null,
      onReact: (e) => _react(m, e),
    );
  }

  Widget _composer(BuTokens t) {
    return ListenableBuilder(
        listenable: _input, builder: (c, _) => _composerBody(t));
  }

  Widget _composerBody(BuTokens t) {
    final len = _input.text.characters.length;
    final canSend = _input.text.trim().isNotEmpty && len <= _maxLen;
    final banner = _editing ?? _replyTo;
    return Container(
      decoration: BoxDecoration(
          color: t.sf, border: Border(top: BorderSide(color: t.bd))),
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (banner != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
                color: t.sf2, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(_editing != null ? LucideIcons.pencil : LucideIcons.reply,
                  size: 14.5, color: t.pr),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _editing != null
                              ? 'Mesaj düzenleniyor'
                              : _nameOf((banner['senderId'] as num?)?.toInt()),
                          style: BuType.micro.copyWith(
                              color: t.ink, fontWeight: FontWeight.w700)),
                      Text((banner['text'] as String?) ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BuType.caption.copyWith(color: t.mut)),
                    ]),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Vazgeç',
                icon: Icon(LucideIcons.x, size: 16, color: t.mut),
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
                  style: BuType.micro.copyWith(
                      color: len > _maxLen ? t.danger : t.mut,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (_editing == null) ...[
            Semantics(
              button: true,
              label: 'Ekle',
              child: GestureDetector(
                key: const ValueKey('attachButton'),
                onTap: _openGallery,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                  child: Icon(LucideIcons.plus, size: 21.5, color: t.ink),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: EdgeInsetsDirectional.only(
                  start: 18, end: _editing == null ? 4 : 18),
              decoration: BoxDecoration(
                  color: t.sf2, borderRadius: BorderRadius.circular(23)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('composerField'),
                    controller: _input,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    style: BuType.body.copyWith(color: t.ink),
                    cursorColor: t.pr,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      hintText: 'Mesaj yaz',
                      hintStyle: BuType.body.copyWith(color: t.mut),
                    ),
                  ),
                ),
                if (_editing == null)
                  SizedBox(
                    width: 38,
                    height: 46,
                    child: IconButton(
                      key: const ValueKey('cameraShortcut'),
                      tooltip: 'Kamera',
                      padding: EdgeInsets.zero,
                      onPressed: _openCameraShortcut,
                      icon: Icon(LucideIcons.camera, size: 18, color: t.mut),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            enabled: canSend,
            label: _editing != null ? 'Kaydet' : 'Gönder',
            child: GestureDetector(
              key: const ValueKey('sendButton'),
              onTap: canSend ? _submit : null,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: canSend ? t.pr : t.pr.withValues(alpha: .4),
                    shape: BoxShape.circle),
                child: Icon(
                    _editing != null ? LucideIcons.check : LucideIcons.send,
                    size: 20,
                    color: t.onPr),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
