import 'dart:async';
import 'dart:ui' show ImageFilter;

import '../../core/push/active_conversation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart' show VideoPlayerController;

import '../../core/api.dart';
import '../../core/cache/message_cache.dart';
import '../../core/closed_conversations.dart';
import '../../core/locale_controller.dart';
import '../../core/outbox/outbox.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/platform/image_service.dart';
import '../../core/platform/video_service.dart';
import '../../core/realtime/chat_realtime.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import '../../widgets/report_sheet.dart';
import '../clubs/club_detail_page.dart';
import '../profile/user_profile_page.dart';
import '../events/event_detail_page.dart';
import 'chat_attach_sheet.dart';
import 'chat_info_page.dart';
import 'chat_media.dart';
import 'chatd_parts.dart' show ChatTypingDots;
import 'chatlist_widgets.dart' show ChatlistAvatar;
import 'chat_media_viewer.dart';
import 'chat_video_player.dart';
import 'chat_wallpaper.dart';
import 'forward_sheet.dart';
import 'view_once_viewer.dart';
import 'sohbety_widgets.dart'
    show SohbetyNoticeCard, SohbetyNoticeKind, SohbetyVideoPrepareCard;
import 'message_actions.dart';
import 'media_camera_page.dart';
import 'media_library.dart';
import 'media_pick.dart';
import 'media_picker_page.dart';
import 'media_preview_page.dart';
import 'message_bubble.dart';
import 'photo_autosave.dart';

/// "Video hazırlanıyor… %N" penceresi (Stitch 25-6; iptal edilebilir). Kapatmayı çağıran yapar.
class _VideoPrepareDialog extends StatelessWidget {
  const _VideoPrepareDialog({required this.progress, required this.cancel});

  final ValueListenable<double> progress;
  final VideoCancel cancel;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        key: const ValueKey('videoPrepare'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (c, v, _) => SohbetyVideoPrepareCard(
            title: c.l10n.chatDetailVideoPreparing('${(v * 100).round()}'),
            subtitle: c.l10n.p10VideoPrepareSub,
            cancelLabel: c.l10n.chatDetailCancel,
            onCancel: cancel.cancel,
            progress: v > 0 ? v : null,
          ),
        ),
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

  /// Yalnız testler: kurulan balon sayısı (gereksiz yeniden kurulum denetimi, A5-04).
  @visibleForTesting
  static int debugBubbleBuilds = 0;

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

  /// Tek soket kuralı (T-095): enjekte edilen (test) ya da oturumun paylaşılan [Session.realtime]'ı. Kabuk başlatır/durdurur;
  /// bu sayfa yalnız abone olur, ASLA dispose etmez ve (paylaşılanı) başlatmaz. Oturumda yoksa yedek olarak kendi örneği.
  late final ChatRealtime _rt = widget.realtime ?? widget.session.realtime ?? (_ownRt = ChatRealtime(widget.session));
  ChatRealtime? _ownRt;
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

  /// "+" menüsü açık (düğme 45 derece dönük "x" görünür).
  bool _attachOpen = false;
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

  /// Yönetici sohbeti kapattı (P08): yazma alanı kapanır, "kapatıldı" bandı görünür (sebep gösterilmez).
  bool get _closed => ClosedConversations.instance.isClosed(_cid);
  void _onClosedChanged() {
    if (!mounted) return;
    setState(() {
      if (_closed) {
        _editing = null;
        _replyTo = null;
      }
    });
  }
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
    if (_conv['id'] is num) ActiveConversation.instance.enter(_cid); // bu sohbet açık: ön plan bildirimi/şeridi bastırılır
    _scroll.addListener(_onScroll);
    _input.addListener(_onInput);
    ClosedConversations.instance.addListener(_onClosedChanged);
    _watchOutbox();
    _boot();
  }

  // ---------- Çevrimdışı kuyruk (Outbox) ----------

  Outbox? get _outbox => _api.outbox;
  StreamSubscription<OutboxDelivery>? _deliverySub;

  /// Kuyruktan teslim edilen mesajı clientId ile eşleyip balonu sunucu mesajıyla değiştirir;
  /// kalıcı hatalı kuyruk öğesini balonda kırmızıya çevirir.
  void _watchOutbox() {
    final ob = _outbox;
    if (ob == null) return;
    _deliverySub = ob.deliveries.listen((d) {
      if (!mounted || d.item.conversationId != _cid) return;
      final res = d.response;
      if (res is! Map) return;
      setState(() => _merge([Map<String, dynamic>.from(res)]));
      _changed = true;
    });
    ob.addListener(_onOutboxChanged);
  }

  void _onOutboxChanged() {
    final ob = _outbox;
    if (ob == null || !mounted) return;
    var dirty = false;
    for (final m in _msgs) {
      if (m['id'] != null || m['_queued'] != true) continue;
      final it = ob.byClientId('${m['clientId']}');
      if (it == null) {
        // Teslim akışı gelmediyse (ör. engel nedeniyle sessizce atıldı) balon gönderilmiş görünür.
        if (m['_state'] == 'pending') {
          m['_state'] = null;
          dirty = true;
        }
      } else if (it.status == OutboxStatus.failed && m['_state'] != 'failed') {
        m['_state'] = 'failed';
        m['_error'] = it.errorCode == 'CONVERSATION_CLOSED' ? context.l10n.chatClosedBanner : null;
        dirty = true;
      }
    }
    if (dirty) setState(() {});
  }

  /// Kuyruktaki fotoğraf/video mesajlarının önizleme baytları (görsel: dosya, video: poster); yeniden açılışta
  /// balon yerel önizlemeyle çizilsin diye `_boot` içinde setState'ten önce yüklenir.
  final _obThumbs = <String, List<Uint8List?>>{};

  Future<void> _loadOutboxThumbs() async {
    final ob = _outbox;
    if (ob == null) return;
    for (final it in List.of(ob.items)) {
      if (it.conversationId != _cid || it.media.isEmpty || it.viewOnce || _obThumbs.containsKey(it.clientId)) continue;
      final list = <Uint8List?>[];
      for (final m in it.media) {
        try {
          final f = await ob.mediaFileOf(m, poster: m.isVideo);
          list.add(f == null ? null : await f.readAsBytes());
        } catch (_) {
          list.add(null);
        }
      }
      _obThumbs[it.clientId] = list;
    }
  }

  /// Sohbet yeniden açıldığında kuyrukta bekleyen/hatalı mesajları balon olarak geri getirir.
  void _restoreOutboxBubbles() {
    final ob = _outbox;
    if (ob == null) return;
    for (final it in ob.items) {
      if (it.conversationId != _cid) continue;
      if (_msgs.any((m) => m['clientId'] == it.clientId)) continue;
      final bubble = <String, dynamic>{
        'id': null,
        'clientId': it.clientId,
        'senderId': _myId,
        'text': it.text,
        'createdAt': DateTime.fromMillisecondsSinceEpoch(it.createdAt, isUtc: true).toIso8601String(),
        'replyToMessageId': it.replyToMessageId,
        '_state': it.status == OutboxStatus.failed ? 'failed' : 'pending',
        '_queued': true,
        '_seq': _seq++,
      };
      if (it.media.isNotEmpty) {
        if (it.viewOnce) {
          bubble['_viewOnce'] = true; // tek gösterimlikte yerel önizleme de tutulmaz
        } else {
          final thumbs = _obThumbs[it.clientId] ?? const <Uint8List?>[];
          bubble['_localItems'] = [
            for (var i = 0; i < it.media.length; i++)
              {
                'bytes': i < thumbs.length ? thumbs[i] : null,
                'video': it.media[i].isVideo,
                'durationMs': it.media[i].durationMs,
              }
          ];
          if (thumbs.isNotEmpty && thumbs.first != null) bubble['_bytes'] = thumbs.first;
          final first = it.media.first;
          if (first.isVideo && it.media.length == 1) {
            bubble
              ..['_isVideo'] = true
              ..['_durationMs'] = first.durationMs
              ..['_vw'] = first.width
              ..['_vh'] = first.height;
          }
        }
      }
      _msgs.add(bubble);
    }
  }

  /// Bu sayfanın rotası: üstte başka sayfa varken (`!isCurrent`) arka plan yoklaması duraklatılır.
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    if (_conv['id'] is num) ActiveConversation.instance.leave(_cid);
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _deliveredTimer?.cancel();
    _typingOff?.cancel();
    _hiOff?.cancel();
    _deliverySub?.cancel();
    _outbox?.removeListener(_onOutboxChanged);
    ClosedConversations.instance.removeListener(_onClosedChanged);
    for (final tm in _noticeTimers.values) {
      tm.cancel();
    }
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
    // WS ack zamanlayıcıları artık Outbox'tadır (sayfadan bağımsız); yalnız yedek yoldakiler yukarıda iptal edilir.
    _ownRt?.dispose();
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
    if (_leaving) return;
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  // ---------- Yükleme ----------

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Önce cihazdaki son mesajlar (anlık çizim); engellenmiş sohbette kayıt kullanılmaz.
    var shownCached = false;
    await _loadOutboxThumbs();
    if (!_blocked) {
      final cached = await MessageCache.instance.readMessages(_cid);
      if (!mounted) return;
      if (cached.isNotEmpty) {
        shownCached = true;
        setState(() {
          _msgs
            ..clear()
            ..addAll(cached);
          _restoreOutboxBubbles();
          _msgs.sort((a, b) => _key(b).compareTo(_key(a)));
          // Sunucu yanıtı gelmezse eskiyi yüklemek için en eski kayıtlı mesajdan devam edilir.
          _beforeCursor = (cached.last['id'] as num?)?.toInt();
          _loading = false;
        });
      }
    }
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
        _restoreOutboxBubbles();
        _msgs.sort((a, b) => _key(b).compareTo(_key(a)));
        _beforeCursor = (page['nextCursor'] as num?)?.toInt();
        _loading = false;
      });
      _persist();
      _markRead();
      _scheduleDelivered();
      _startTimer();
      _loadPresence();
      _startRealtime();
    } catch (e) {
      if (!mounted) return;
      // Çıkarıldık/ayrıldık (404 CONVERSATION_NOT_FOUND): önbellekli açılış 404'ü yutmaz, sayfa kapanır.
      if (_isGone(e)) {
        _onRemovedFromConversation();
        return;
      }
      if (shownCached) {
        // Sunucuya ulaşılamadı: kayıtlı mesajlar sessizce kalır; bağlantı gelince poll/STOMP boşluğu kapatır.
        _startTimer();
        _startRealtime();
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Sunucu bu konuşmayı artık tanımıyor: çıkarıldık, gruptan ayrıldık, kulüp/etkinlik odası kapandı ya da konuşma silindi.
  static bool _isGone(Object e) => e is ApiError && e.status == 404 && e.code == 'CONVERSATION_NOT_FOUND';

  bool _leaving = false;

  /// `conversation-removed` olayı ya da 404 CONVERSATION_NOT_FOUND: yoklamayı durdurur, cihazdaki kaydı siler,
  /// kullanıcıyı bilgilendirir ve sayfayı kapatır (liste yenilensin diye `true` ile). Birden çok çağrıda tek sefer çalışır.
  void _onRemovedFromConversation() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    _timer = null;
    unawaited(MessageCache.instance.removeConversation(_cid));
    widget.session.badges.conversationsDirty.value++;
    BuToast.show(context, context.l10n.p31ChatRemovedToast, kind: BuToastKind.warning);
    final route = _route;
    if (route == null) return;
    if (route.isCurrent) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).removeRoute(route); // üstte başka sayfa (bilgi/medya) açıkken sessizce sökülür
    }
  }

  /// En yeni ~20 sunucu mesajını cihaza yazar (yazma MessageCache'te geciktirilir ve toplanır).
  void _persist() {
    if (_blocked) return;
    final top = <Map<String, dynamic>>[];
    for (final m in _msgs) {
      if (m['id'] == null) continue;
      top.add(m);
      if (top.length >= 25) break;
    }
    if (top.isEmpty) return;
    MessageCache.instance.saveMessages(_cid, top);
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
        final dn = m['displayName'] as String?;
        if (dn != null) _names[id] = dn; // yoksa _nameOf yerelleştirilmiş yedeği verir
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
      // Değişmediyse yeniden kurma: bu setState tüm balonları da kuruyordu (A5-04).
      final same = _presence != null && _sameContent(_presence!, p);
      if (mounted && !same) setState(() => _presence = p);
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
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
      _loadOlder();
    }
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
    if (_polling || _loading || _error != null || !mounted || _leaving) return;
    // Üstte başka sayfa (profil, medya, bilgi...) varken arka planda yoklama yapılmaz; geri dönünce sıradaki tur çalışır.
    if (!force && _route != null && !_route!.isCurrent) return;
    _tick++;
    if (_rtOn && !force && _tick % 5 != 0) return;
    // Çevrimdışıyken her 4 sn'de ölü ağa vurma (pil): yaklaşık 30 sn'de bir dener; bağlantı gelince STOMP/öne gelme
    // `force` ile hemen tetikler.
    if (!force && !_api.connectivity.online && _tick % 8 != 0) return;
    _polling = true;
    var added = false;
    var changed = false;
    try {
      if (!_rtOn || force) {
        final r = await _fetchAfter();
        added = r.added > 0;
        changed = r.changed;
      }
      if (_tick % 5 == 0 || force) {
        final page = await _api.get('/conversations/$_cid/messages?size=30')
            as Map<String, dynamic>;
        final r = _mergeCount(_items(page));
        added = r.added > 0 || added;
        changed = r.changed || changed;
      }
      if (_tick % 8 == 0) _loadPresence();
      if (mounted) {
        if (added) _markRead();
        _scheduleDelivered();
      }
    } catch (e) {
      // Ağ hatası: bir sonraki turda yeniden dene, oturumu kapatma. Çıkarıldıysak (404) sessiz ölü yoklama yerine kapan.
      if (mounted && _isGone(e)) _onRemovedFromConversation();
    } finally {
      _polling = false;
      // Yalnız listede görünür bir değişiklik olduysa yeniden kur (A5-04: her turda tüm balonlar kuruluyordu).
      if (changed && mounted) setState(() {});
    }
  }

  /// Son bilinen id'den sonrasını sayfa sayfa çeker (boşluk kapatma).
  Future<({int added, bool changed})> _fetchAfter() async {
    final newest = _newestServerId;
    if (newest == null) {
      final page = await _api.get('/conversations/$_cid/messages?size=30')
          as Map<String, dynamic>;
      return _mergeCount(_items(page));
    }
    var added = 0;
    var changed = false;
    var cursor = newest;
    for (var i = 0; i < 5; i++) {
      final page =
          await _api.get('/conversations/$_cid/messages?after=$cursor&size=30')
              as Map<String, dynamic>;
      final r = _mergeCount(_items(page));
      added += r.added;
      changed = r.changed || changed;
      final next = (page['nextCursor'] as num?)?.toInt();
      if (next == null) break;
      cursor = next;
    }
    return (added: added, changed: changed);
  }

  // ---------- Gerçek zamanlı ----------

  void _startRealtime() {
    if (_subs.isNotEmpty) return;
    // Paylaşılan soket zaten bağlı olabilir: `connected` akışı yeniden yayın yapmaz, durumu buradan al.
    _rtOn = _rt.isConnected;
    _subs.addAll([
      _rt.removedConversations.listen((id) {
        if (id == _cid) _onRemovedFromConversation();
      }),
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
      _rt.deletedMessages.listen((e) {
        // Gizleme/silme olayı yalnız kimlik taşır: yer tutucu metni için son sayfayı tazele.
        if (e.conversationId == _cid) _poll(force: true);
      }),
      _rt.errors.listen((e) {
        final cid = e.clientId;
        if (e.code == 'CONVERSATION_CLOSED') {
          ClosedConversations.instance.markClosed(_cid);
        }
        if (cid == null) return;
        _ackTimers.remove(cid)?.cancel();
        // WS gönderimi reddedildi ama mesaj kalıcı kuyrukta: kırmızı hata yerine kuyruk hemen REST'ten dener ve gerçek
        // sonucu (teslim ya da kalıcı hata) balona yansıtır.
        final ob = _outbox;
        if (ob != null && ob.contains(cid)) {
          for (final m in _msgs) {
            if (m['id'] == null && m['clientId'] == cid) m['_queued'] = true;
          }
          unawaited(ob.retry(cid));
          return;
        }
        final i =
            _msgs.indexWhere((m) => m['id'] == null && m['clientId'] == cid);
        if (i >= 0 && mounted) {
          setState(() {
            _msgs[i]['_state'] = 'failed';
            _msgs[i]['_error'] =
                e.code == 'CONVERSATION_CLOSED' ? context.l10n.chatClosedBanner : null;
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
    // Paylaşılan soketi kabuk başlatır (start/stop yalnız orada); yalnız enjekte edilen/yedek örnek burada başlar.
    if (widget.connectRealtime && (widget.realtime != null || _ownRt != null)) _rt.start();
  }

  void _onRtMessage(Map<String, dynamic> m) {
    if ((m['conversationId'] as num?)?.toInt() != _cid || !mounted) return;
    final cid = m['clientId'] as String?;
    if (cid != null) _ackTimers.remove(cid)?.cancel();
    final mine = (m['senderId'] as num?)?.toInt() == _myId;
    // Kapalı sohbette canlı yeni mesaj = sohbet yeniden açılmış.
    ClosedConversations.instance.markOpen(_cid);
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
  ({int added, bool changed}) _mergeCount(List<Map<String, dynamic>> incoming) {
    final before = _msgs.length;
    final changed = _merge(incoming);
    return (added: _msgs.length - before, changed: changed);
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

  /// Gelen mesajları listeye katar (id ya da clientId ile eşler). Listede görünür bir değişiklik olduysa true döner;
  /// içeriği aynı olan sunucu mesajı (yoklama) listeye dokunmaz, böylece çağıran gereksiz `setState` yapmaz.
  bool _merge(List<Map<String, dynamic>> incoming) {
    final newest = _newestServerId ?? 0;
    var changed = false;
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
        // Gönderenin yerel görseli: sunucu görseli gelene dek balonda net önizleme kalır (flaş/bulanıklık yok).
        if (old['_bytes'] is Uint8List && old['_localItems'] is List && (old['_localItems'] as List).length < 2) {
          m['_ph'] = old['_bytes'];
        }
        if (old['id'] != null && _sameContent(old, m)) continue;
        changed = true;
        if (_key(old) == _key(m)) {
          _msgs[idx] = m;
        } else {
          // Yerel balon sunucu kimliğine kavuştu: sıralama anahtarı değişir.
          _msgs.removeAt(idx);
          _insertSorted(m);
        }
      } else {
        changed = true;
        _insertSorted(m);
        // Aşağıda değilken gelen yeni (başkasının) mesajlar düğmedeki rozeti artırır.
        if (id != null && id > newest && !_isMine(m) && _showDown.value) {
          _newBelow.value++;
        }
      }
    }
    if (changed) {
      _trimRowKeys();
      _persist();
      unawaited(_autoSaveReceived(incoming));
    }
    return changed;
  }

  /// Liste en yeni başta ve `_key`e göre azalan sıralıdır: ikili aramayla yerine ekler (her birleştirmede tam sıralama yok).
  void _insertSorted(Map<String, dynamic> m) {
    final k = _key(m);
    var lo = 0;
    var hi = _msgs.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_key(_msgs[mid]) > k) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    _msgs.insert(lo, m);
  }

  /// İki mesaj haritası yerel (`_` önekli) alanlar hariç aynı mı? (Yoklama aynı sunucu cevabını getirdiğinde balonu
  /// yeniden kurmamak için.)
  static bool _sameContent(Map<String, dynamic> a, Map<String, dynamic> b) {
    bool eq(Object? x, Object? y) {
      if (x is Map && y is Map) {
        final kx = x.keys.where((k) => !(k is String && k.startsWith('_'))).toSet();
        final ky = y.keys.where((k) => !(k is String && k.startsWith('_'))).toSet();
        if (kx.length != ky.length || !kx.containsAll(ky)) return false;
        for (final k in kx) {
          if (!eq(x[k], y[k])) return false;
        }
        return true;
      }
      if (x is List && y is List) {
        if (x.length != y.length) return false;
        for (var i = 0; i < x.length; i++) {
          if (!eq(x[i], y[i])) return false;
        }
        return true;
      }
      return x == y;
    }

    return eq(a, b);
  }

  /// Satır `GlobalKey`leri yalnız ekranda kurulu satırlar için tutulur (kaydırılıp geçilen binlerce mesaj anahtar sızdırmasın).
  void _trimRowKeys() {
    if (_rowKeys.length <= 64) return;
    _rowKeys.removeWhere((_, k) => k.currentContext == null);
  }

  /// Gelen fotoğrafları (ayar açıksa) galeriye kaydeder; kendi mesajlarım gönderimde kaydedilir (bkz. [_sendRest]).
  Future<void> _autoSaveReceived(List<Map<String, dynamic>> incoming) async {
    try {
      final res = await PhotoAutoSave.instance.considerReceived(incoming,
          headers: _authHeaders,
          isMine: (m) => _isMine(m) || m['_state'] != null,
          blocked: _blocked,
          direct: _direct); // yalnız birebir sohbet fotoğrafları galeriye kaydedilir
      if (res.contains(AutoSaveResult.denied)) await _autoSaveDenied();
    } catch (_) {}
  }

  /// Galeri izni yok: tek seferlik bilgi + Ayarlar'a yönlendirme (ayar sessizce kapatılmaz).
  Future<void> _autoSaveDenied() async {
    if (!mounted || !await PhotoAutoSave.instance.takeDeniedNotice() || !mounted) return;
    BuToast.show(context, context.l10n.p22SaveDeniedToast,
        kind: BuToastKind.warning,
        actionLabel: context.l10n.p22OpenSettings,
        onAction: () => unawaited(PermissionService.instance.openSettings()),
        duration: const Duration(seconds: 6));
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
    if (_input.text.isNotEmpty && _editing == null && _rtOn) {
      _rt.sendTyping(_cid);
    }
  }

  /// Mesaj uzunluğu tek ölçüyle sayılır: Unicode kod noktası (`runes.length`); sunucu da kod noktası sayar. UTF-16
  /// `length` emojiyi 2 sayar, `characters.length` ise birleşik işaretleri 1 sayar: ikisi de sunucuyla uyuşmaz.
  static int _len(String s) => s.runes.length;

  /// Sınır aşıldıysa uyarı gösterir ve true döner.
  bool _overLimit(String text) {
    if (_len(text) <= _maxLen) return false;
    if (mounted) {
      BuToast.show(context, context.l10n.p31ChatMsgTooLong('$_maxLen'), kind: BuToastKind.warning);
    }
    return true;
  }

  Future<void> _submit() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    if (_overLimit(text)) return; // görünür uyarı verir (sessizce yutulmaz, A10-05)
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
    // Konuşmada gerçekten bekleyen (çevrimdışı/yeniden denenen) kuyruk öğesi varsa yeni mesaj da kuyruğa girer:
    // doğrudan gönderim araya girip sırayı bozmasın. WS ack bekleyen öğeler (ChatRealtime.isAwaitingAck) sayılmaz.
    final backlog = _outbox?.items.any((e) =>
            e.conversationId == _cid &&
            e.status == OutboxStatus.pending &&
            !_rt.isAwaitingAck(e.clientId)) ??
        false;
    // Bağlantı yok: fotoğraf/video yerel kuyruğa alınır, bağlantı gelince kendiliğinden yüklenip gider.
    // Balon normal "gönderiliyor" görünür (bekliyor/kuyrukta metni yok).
    if (uploads.isNotEmpty && (!_api.connectivity.online || backlog) && await _queueMedia(local)) return;
    if (uploads.isEmpty && backlog && _queueText(local)) return;
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
        // Ack gelene kadar kalıcı yedek: mesaj Outbox'a yazılır (ChatRealtime ack'te siler; sayfa kapansa, soket ölü
        // olsa, uygulama ölse de REST ile gider). Zamanlayıcı sayfaya değil Outbox'a bağlıdır (A10-01/A15-02).
        if (_queueText(local, hold: _ackWindow)) return;
        // Outbox yok/reddetti (yalnız testler ya da çok uzun metin): sayfaya bağlı eski yedek.
        _ackTimers[cid]?.cancel();
        _ackTimers[cid] = Timer(const Duration(seconds: 8), () {
          _ackTimers.remove(cid);
          if (mounted && local['_state'] == 'pending' && local['id'] == null) {
            _sendRest(local);
          }
        });
        return;
      }
      await _sendRest(local);
    } catch (e) {
      _fail(local, e);
    }
  }

  /// WS ack penceresi: bu süre içinde ack gelmezse Outbox aynı clientId ile REST'ten dener (sunucu çift mesaj üretmez).
  static const _ackWindow = Duration(seconds: 8);

  /// Salt metin mesajını kalıcı kuyruğa (Outbox) alır; [hold] doluysa ilk deneme o kadar geciktirilir (WS ack penceresi).
  /// Kuyruk yoksa/reddederse false (çağıran eski yola düşer).
  bool _queueText(Map<String, dynamic> local, {Duration? hold}) {
    final ob = _outbox;
    if (ob == null) return false;
    final cid = '${local['clientId']}';
    final ok = ob.enqueue(
      conversationId: _cid,
      clientId: cid,
      text: (local['text'] as String?) ?? '',
      replyToMessageId: (local['replyToMessageId'] as num?)?.toInt(),
    );
    if (!ok) return false;
    if (hold != null) {
      ob.byClientId(cid)?.nextAttemptAt = DateTime.now().millisecondsSinceEpoch + hold.inMilliseconds;
    }
    local['_queued'] = true; // kuyruk kalıcı hatayı/teslimi balona yansıtır (_onOutboxChanged)
    return true;
  }

  /// Hazırlanmış ekleri uygulama diskine kopyalayıp kalıcı gönderme kuyruğuna alır. Başarısızsa false.
  Future<bool> _queueMedia(Map<String, dynamic> local) async {
    final ob = _outbox;
    if (ob == null) return false;
    final sources = <OutboxMediaSource>[];
    for (final u in _uploadsOf(local)) {
      final img = u['image'] as PreparedImage?;
      final vid = u['video'] as PreparedVideo?;
      if (img != null) {
        sources.add(OutboxMediaSource(kind: 'image', mime: img.mime, bytes: img.bytes));
      } else if (vid != null) {
        sources.add(OutboxMediaSource(
          kind: 'video',
          mime: 'video/mp4',
          bytes: vid.bytes,
          path: vid.bytes == null ? vid.path : null,
          poster: vid.poster,
          width: vid.width,
          height: vid.height,
          durationMs: vid.durationMs,
        ));
      }
    }
    if (sources.isEmpty) return false;
    final ok = await ob.enqueueMedia(
      conversationId: _cid,
      clientId: '${local['clientId']}',
      text: (local['text'] as String?) ?? '',
      replyToMessageId: (local['replyToMessageId'] as num?)?.toInt(),
      viewOnce: local['_viewOnce'] == true,
      sources: sources,
    );
    if (ok && mounted) {
      setState(() {
        local['_state'] = 'pending';
        local['_queued'] = true;
        local['_error'] = null;
      });
    }
    return ok;
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
      // Gönderilen fotoğraflar (tek gösterimlik değil) yerel baytlardan galeriye kaydedilir.
      if (local['_viewOnce'] != true) {
        final sent = res is Map ? (res['attachments'] as List? ?? const []).whereType<Map>().toList() : const <Map>[];
        for (final u in _uploadsOf(local)) {
          final img = u['image'] as PreparedImage?;
          final aid = (u['attId'] as num?)?.toInt();
          if (img == null || aid == null || sent.any((a) => (a['id'] as num?)?.toInt() == aid && a['viewOnce'] == true)) continue;
          unawaited(PhotoAutoSave.instance.saveSent(aid, img.bytes, direct: _direct).then((r) {
            if (r == AutoSaveResult.denied) return _autoSaveDenied();
          }));
        }
      }
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
    // Yönetici kapattı (409): yazma alanı kapanır; mesaj kalıcı hatalı (kuyruktaysa kuyruk da failed yapar).
    if (e is ApiError && e.code == 'CONVERSATION_CLOSED') {
      ClosedConversations.instance.markClosed(_cid);
      setState(() {
        local['_state'] = 'failed';
        local['_error'] = context.l10n.chatClosedBanner;
      });
      return;
    }
    // Ağ yok, fotoğraf/video yüklenemedi: yerel kuyruğa alınır (balon "gönderiliyor" kalır).
    if (e is ApiError &&
        e.isNetwork &&
        _uploadsOf(local).isNotEmpty &&
        !(_outbox?.contains('${local['clientId']}') ?? false)) {
      unawaited(_queueMedia(local).then((ok) {
        if (!ok && mounted) {
          setState(() {
            local['_state'] = 'failed';
            local['_error'] = null;
          });
        }
      }));
      return;
    }
    // Ağ yok ve mesaj çevrimdışı kuyruğa alındı: kırmızı hata değil, normal "gönderiliyor" (bağlantı gelince gider).
    if (e is ApiError && e.isNetwork && (_outbox?.contains('${local['clientId']}') ?? false)) {
      setState(() {
        local['_state'] = 'pending';
        local['_queued'] = true;
        local['_error'] = null;
      });
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
    final ob = _outbox;
    final cid = '${m['clientId']}';
    if (ob != null && ob.contains(cid)) {
      // Kuyruktaki öğe: kuyruk yeniden dener (aynı clientId, çift mesaj olmaz).
      m['_queued'] = true;
      await ob.retry(cid);
      return;
    }
    await _transmit(m);
  }

  // ---------- Medya (galeri / kamera / önizleme) ----------

  /// Ek düğmesi: doğrudan tüm galeriyi açar; seçim önizlemeden geçip gönderilir. Çevrimdışıyken de seçilebilir:
  /// fotoğraf/video yerel kuyruğa alınır ve bağlantı gelince kendiliğinden gider.
  Future<void> _openAttach() async {
    if (_attachOpen) return;
    final library = widget.mediaLibrary ?? PhotoManagerLibrary();
    setState(() => _attachOpen = true);
    ChatAttachResult? choice;
    try {
      choice = await showChatAttachSheet(context, library: library, ensureAccess: widget.ensureAccess);
    } finally {
      if (mounted) setState(() => _attachOpen = false);
    }
    if (choice == null || !mounted) return;
    MediaSendPlan? plan;
    switch (choice) {
      case ChatAttachGallery():
        plan = await Navigator.push<MediaSendPlan>(
          context,
          MaterialPageRoute(
            builder: (_) => MediaPickerPage(
              library: library,
              ensureAccess: widget.ensureAccess,
              openCamera: widget.openCamera,
              // Stitch v3: ilk karo Kamera ("+" menüsünde de var).
            ),
          ),
        );
      case ChatAttachCamera():
        final launcher = widget.openCamera;
        final pick = launcher != null ? await launcher(context) : await openMediaCamera(context);
        if (pick == null || !mounted) return;
        plan = await _previewPlan(pick);
      case ChatAttachRecent(:final pick):
        plan = await _previewPlan(pick);
    }
    if (plan == null || !mounted) return;
    await _sendPlan(plan);
  }

  Future<MediaSendPlan?> _previewPlan(MediaPick pick) => Navigator.push<MediaSendPlan>(
        context,
        MaterialPageRoute(builder: (_) => MediaPreviewPage(picks: [pick])),
      );

  static String _videoErrorText(AppLocalizations l, String code) =>
      switch (code) {
        'TOO_LONG' => l.chatDetailVideoTooLong,
        'TOO_LARGE' => l.chatDetailVideoTooLarge,
        'UNSUPPORTED' => l.chatDetailVideoUnsupported,
        _ => l.chatDetailVideoFailed,
      };

  /// Planı mesajlara böler (bkz. [planMessages]), öğeleri hazırlar, yerel baloncukları sırayla ekler ve yükler.
  Future<void> _sendPlan(MediaSendPlan plan) async {
    final lc = context.l10n;
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
        _notice(lc.chatDetailVideosSplit, SohbetyNoticeKind.info);
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
    final l = context.l10n;
    if (!p.isVideo) {
      try {
        final bytes = await p.imageBytes?.call();
        if (bytes == null) throw ImageException('EMPTY');
        return {'image': await _image.prepare(bytes)};
      } on ImageException catch (e) {
        _notice(
            e.code == 'TOO_LARGE'
                ? l.chatDetailImageTooLarge
                : l.chatDetailImageTypes,
            SohbetyNoticeKind.error);
      } catch (_) {
        _notice(l.chatDetailImageUnreadable, SohbetyNoticeKind.error);
      }
      return null;
    }
    String? path;
    try {
      path = await p.videoPath?.call();
    } catch (_) {}
    if (path == null) {
      _notice(l.chatDetailVideoUnreadable, SohbetyNoticeKind.error);
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
    var errorKind = SohbetyNoticeKind.error;
    try {
      prepared = await _video.prepare(PickedVideo(path),
          onProgress: (v) => progress.value = v, cancel: cancel);
    } on VideoException catch (e) {
      if (e.code != 'CANCELLED') {
        error = _videoErrorText(l, e.code);
        if (e.code == 'TOO_LONG') errorKind = SohbetyNoticeKind.warning;
      }
    } catch (_) {
      error = _videoErrorText(l, 'FAILED');
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
    if (!mounted) return null;
    if (error != null) {
      _notice(error, errorKind);
      return null;
    }
    if (prepared == null) return null;
    return {'video': prepared, 'progress': ValueNotifier<double>(0)};
  }

  Future<void> _saveVideo(String url) async {
    final l = context.l10n;
    String msg;
    try {
      await saveChatVideoToGallery(url, _authHeaders);
      msg = l.chatDetailSavedToGallery;
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
      _toastError(e);
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
    if (_overLimit(text)) return;
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
      _toastError(e);
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> m) async {
    final l = context.l10n;
    final ok = await _confirm(
        l.chatDetailDeleteTitle, l.chatDetailDeleteBody, l.chatDetailDelete,
        icon: LucideIcons.trash2);
    if (!ok) return;
    try {
      await _api.delete('/messages/${(m['id'] as num).toInt()}');
      if (!mounted) return;
      setState(() {
        m['deleted'] = true;
        m['text'] = l.chatDetailMsgDeleted;
        m['removed'] = true;
        m['replyTo'] = null;
      });
    } catch (e) {
      _toastError(e);
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

  /// Medya hazırlama bildirimleri (Stitch 25-6): yazma alanının üstünde yığılı, kapatılabilir kartlar.
  final _notices = <({int id, String text, SohbetyNoticeKind kind})>[];
  final _noticeTimers = <int, Timer>{};
  int _noticeSeq = 0;

  void _notice(String text, SohbetyNoticeKind kind) {
    if (!mounted) return;
    final id = ++_noticeSeq;
    setState(() {
      _notices.removeWhere((n) => n.text == text);
      _notices.add((id: id, text: text, kind: kind));
      if (_notices.length > 3) _notices.removeAt(0);
    });
    _noticeTimers[id] = Timer(const Duration(seconds: 6), () => _dropNotice(id));
  }

  void _dropNotice(int id) {
    _noticeTimers.remove(id)?.cancel();
    if (!mounted) return;
    setState(() => _notices.removeWhere((n) => n.id == id));
  }

  Widget _noticeStack() {
    if (_notices.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final n in _notices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SohbetyNoticeCard(
                key: ValueKey('notice-${n.id}'),
                message: n.text,
                kind: n.kind,
                onClose: () => _dropNotice(n.id)),
          ),
      ]),
    );
  }

  /// Çevrimdışıyken kullanıcı eylemi (düzenle/sil/tepki/engelle...) için kısa "bağlantı yok"; diğer hatalar sunucu metniyle.
  void _toastError(Object e) {
    _toast(e is ApiError && e.isNetwork ? context.l10n.cevrimdisiInternetYok : errorText(e));
  }

  void _toast(String msg, {BuToastKind kind = BuToastKind.info}) {
    if (!mounted) return;
    BuToast.show(context, msg, kind: kind);
  }

  /// Silme / ayrılma / engelleme onayı: solda kırmızı simge karosu + başlık, gövde, iki tam genişlik düğme.
  Future<bool> _confirm(String title, String body, String action,
      {IconData? icon}) async {
    final r = await BuDialog.show<bool>(
      context,
      builder: (c) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: _ChatConfirmDialog(
            title: title,
            body: body,
            confirmLabel: action,
            cancelLabel: c.l10n.chatDetailNevermind,
            icon: icon),
      ),
    );
    return r ?? false;
  }

  String _nameOf(int? id) {
    if (id != null && id == _myId) return context.l10n.chatDetailYou;
    if (id != null && _names[id] != null) return _names[id]!;
    final p = _peer;
    if (_direct && p != null && (p['id'] as num?)?.toInt() == id) {
      return (p['displayName'] as String?) ?? context.l10n.chatDetailUserFallback;
    }
    return context.l10n.chatDetailUserFallback;
  }

  String get _title {
    if (_direct) {
      return (_peer?['displayName'] as String?) ??
          (_conv['title'] as String?) ??
          context.l10n.chatDetailChatFallback;
    }
    return (_conv['title'] as String?) ?? context.l10n.chatDetailGroupFallback;
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

  /// Bugünden gün farkı (0 bugün, 1 dün).
  int _dayDiff(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    return today.difference(day).inDays;
  }

  /// "5 Mart" / "5 Mart 2025" biçimi (ay adı dile göre).
  String _dateLabel(DateTime d) {
    final l = context.l10n;
    final months = [
      l.chatDetailMonth1,
      l.chatDetailMonth2,
      l.chatDetailMonth3,
      l.chatDetailMonth4,
      l.chatDetailMonth5,
      l.chatDetailMonth6,
      l.chatDetailMonth7,
      l.chatDetailMonth8,
      l.chatDetailMonth9,
      l.chatDetailMonth10,
      l.chatDetailMonth11,
      l.chatDetailMonth12,
    ];
    final base = '${d.day} ${months[d.month - 1]}';
    return d.year == DateTime.now().year ? base : '$base ${d.year}';
  }

  String _dayLabel(DateTime d) {
    final diff = _dayDiff(d);
    if (diff == 0) return context.l10n.chatDetailToday;
    if (diff == 1) return context.l10n.chatDetailYesterday;
    return _dateLabel(d);
  }

  bool _sameDay(DateTime? a, DateTime? b) =>
      a != null &&
      b != null &&
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  String? _statusText() {
    final l = context.l10n;
    if (_direct) {
      final p = _presence;
      if (p == null) return null;
      if (p['online'] == true) return l.chatDetailOnline;
      final seen =
          DateTime.tryParse((p['lastSeenAt'] as String?) ?? '')?.toLocal();
      if (seen == null) return null;
      final diff = _dayDiff(seen);
      if (diff == 0) return l.chatDetailLastSeenToday(_hm(seen));
      if (diff == 1) return l.chatDetailLastSeenYesterday(_hm(seen));
      return l.chatDetailLastSeenOn(_dateLabel(seen));
    }
    final n = (_conv['memberCount'] as num?)?.toInt() ?? _members.length;
    final isRoom = _type == 'CLUB' || _type == 'EVENT';
    if (n > 0) {
      return _type == 'CLUB'
          ? l.chatDetailClubRoomMembers(n.toString())
          : _type == 'EVENT'
              ? l.chatDetailEventRoomMembers(n.toString())
              : l.chatDetailMembersCount(n.toString());
    }
    return isRoom ? l.chatDetailClubEventRoom : null;
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
    // Başkasının mesajını silme: grup yöneticisi (`admin`) ya da kulüp/etkinlik odası moderatörü (`canModerate`, C1);
    // alan eski sunucuda yoksa false.
    final canDelete = !failed &&
        !deleted &&
        (mine || (!_direct && (_conv['admin'] == true || _conv['canModerate'] == true)));

    final l = context.l10n;
    final actions = <MessageAction>[
      if (failed) ...[
        MessageAction('retry', l.chatDetailResend, LucideIcons.rotateCw),
        MessageAction('drop', l.chatDetailDelete, LucideIcons.trash2,
            danger: true),
      ] else ...[
        if (!deleted)
          MessageAction('reply', l.chatDetailReply, LucideIcons.reply),
        if (!deleted && hasText)
          MessageAction('copy', l.chatDetailCopy, LucideIcons.copy),
        if (!deleted && hasText && !hasAtt)
          MessageAction('forward', l.chatDetailForward, LucideIcons.forward),
        if (!deleted && mine && hasText)
          MessageAction('edit', l.chatDetailEdit, LucideIcons.pencil),
        if (canDelete)
          MessageAction(
              'delete',
              mine ? l.chatDetailDeleteForAll : l.chatDetailDeleteMessage,
              LucideIcons.trash2,
              danger: true),
        if (!deleted && !mine)
          MessageAction('report', l.chatDetailReport, LucideIcons.flag,
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
        _toast(l.chatDetailCopied, kind: BuToastKind.success);
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
        final ob = _outbox;
        if (ob != null) await ob.remove('${m['clientId']}');
        if (mounted) setState(() => _msgs.remove(m));
    }
  }

  /// Metin mesajını seçilen sohbetlere (en çok 5) aynen gönderir.
  Future<void> _forward(Map<String, dynamic> m) async {
    final l = context.l10n;
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
    _toast(
        failed == 0
            ? l.chatDetailForwarded
            : (failed == ids.length
                ? l.chatDetailForwardFailedAll
                : l.chatDetailForwardFailedSome(failed.toString())),
        kind: failed == 0 ? BuToastKind.success : BuToastKind.error);
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

  /// Sohbet menüsü satırı: solda 40 dp simge karosu, etiket, sonda ok (tehlikeli satırda kırmızı).
  Widget _menuRow(BuildContext c,
      {required IconData icon,
      required String label,
      required String id,
      bool danger = false,
      bool card = false}) {
    final t = c.bu;
    final tx = Theme.of(c).textTheme;
    final color = danger ? t.danger : t.ink;
    final row = InkWell(
      key: ValueKey('menu-$id'),
      borderRadius: BuRadius.bMd,
      onTap: () => Navigator.pop(c, id),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
        child: Row(children: [
          ExcludeSemantics(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: danger ? t.soft : (card ? t.ink : t.sf2),
                  borderRadius: BuRadius.bSm),
              child: Icon(icon,
                  size: 20, color: danger ? t.danger : (card ? t.bg : t.ink)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tx.titleSmall!
                    .copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          if (card)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle),
              child: Icon(LucideIcons.arrowUpRight, size: 18, color: t.ink),
            )
          else
            ExcludeSemantics(
              child: Icon(
                  danger
                      ? buDirIcon(c, LucideIcons.arrowRight)
                      : buDirIcon(c, LucideIcons.chevronRight),
                  size: danger ? 18 : 16,
                  color: danger ? t.danger.withValues(alpha: .7) : t.mut),
            ),
        ]),
      ),
    );
    if (!card) return row;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
      child: Material(type: MaterialType.transparency, child: row),
    );
  }

  Future<void> _openChatMenu() async {
    final l = context.l10n;
    final action = await BuSheet.show<String>(
      context,
      builder: (c) => Material(
        type: MaterialType.transparency,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _menuRow(c,
              icon: LucideIcons.search,
              label: l.chatDetailSearchInChat,
              id: 'search'),
          if (!_direct)
            _menuRow(c,
                icon: LucideIcons.users,
                label: l.chatDetailMembers,
                id: 'members'),
          _menuRow(c,
              icon: LucideIcons.image, label: l.chatDetailMedia, id: 'media'),
          if (_roomPage)
            _menuRow(c,
                icon: _type == 'CLUB' ? LucideIcons.star : LucideIcons.calendar,
                label: _type == 'CLUB'
                    ? l.chatDetailClubPage
                    : l.chatDetailEventPage,
                id: 'room',
                card: true),
          _menuRow(c,
              icon: LucideIcons.settings,
              label: l.chatDetailSettings,
              id: 'settings'),
          _menuRow(c,
              icon: LucideIcons.info, label: l.chatDetailChatInfo, id: 'about'),
          if (_direct || !_room)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 3, thickness: 3, color: c.bu.sf2),
            ),
          if (!_direct && !_room)
            _menuRow(c,
                icon: LucideIcons.logOut,
                label: l.chatDetailLeaveChat,
                id: 'leave',
                danger: true),
          if (_direct)
            _menuRow(c,
                icon: LucideIcons.ban,
                label: _blocked ? l.chatDetailUnblock : l.chatDetailBlock,
                id: _blocked ? 'unblock' : 'block',
                danger: !_blocked),
          if (_direct)
            _menuRow(c,
                icon: LucideIcons.flag,
                label: l.chatDetailReportUser,
                id: 'report',
                danger: true),
        ]),
      ),
    );
    if (action == 'media' || action == 'settings' || action == 'about') {
      if (mounted) await _openInfo();
      return;
    }
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
          final ok = await _confirm(l.chatDetailLeaveTitle,
              l.chatDetailLeaveBody, l.chatDetailLeave,
              icon: LucideIcons.logOut);
          if (!ok) return;
          await _api.post('/conversations/$_cid/leave');
          unawaited(MessageCache.instance.removeConversation(_cid));
          if (mounted) Navigator.pop(context, true);
        case 'block':
          if (pid == null) return;
          final ok = await _confirm(l.chatDetailBlockTitle,
              l.chatDetailBlockBody, l.chatDetailBlock,
              icon: LucideIcons.ban);
          if (!ok) return;
          await _api.post('/users/$pid/block');
          unawaited(MessageCache.instance.removeConversation(_cid)); // engellenen kişiyle mesaj kaydı cihazda kalmaz
          _changed = true;
          if (mounted) setState(() => _conv['blocked'] = true);
          _toast(l.chatDetailUserBlocked);
        case 'unblock':
          await _unblockPeer();
        case 'report':
          if (pid == null) return;
          await ReportSheet.show(context, widget.session,
              targetType: 'USER',
              targetId: pid,
              title: l.chatDetailReportUser);
      }
    } catch (e) {
      _toastError(e);
    }
  }

  Future<void> _showMembers() async {
    if (_members.isEmpty) await _loadDetail();
    if (!mounted) return;
    await BuSheet.show<void>(
      context,
      title: context.l10n.chatDetailMembersTitle(_members.length.toString()),
      builder: (c) {
        final t = c.bu;
        final tx = Theme.of(c).textTheme;
        if (_members.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(c.l10n.chatDetailMembersLoadFailed,
                style: tx.bodyMedium!.copyWith(color: t.mut)),
          );
        }
        return Column(mainAxisSize: MainAxisSize.min, children: [
          for (final m in _members)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(children: [
                BuAvatar(
                    name: m['displayName'] as String?,
                    url: m['avatarUrl'] as String?,
                    size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                      (m['displayName'] as String?) ??
                          c.l10n.chatDetailUserFallback,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tx.titleSmall!.copyWith(color: t.ink)),
                ),
                if ((m['role'] as String?) == 'ADMIN' ||
                    (m['role'] as String?) == 'OWNER')
                  BuBadge(c.l10n.chatDetailAdmin),
              ]),
            ),
        ]);
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
          // Duvar kağıdı yalnız mesaj alanının arkasında (üst çubuk/yazma alanı düz kalır).
          Expanded(child: ChatWallpaper(child: _body(t))),
          _noticeStack(),
          _closed
              ? _closedBar(t)
              : _searching
                  ? SizedBox(height: MediaQuery.paddingOf(context).bottom)
                  : (_direct && _blocked)
                      ? _blockedBar(t)
                      : _composer(t),
        ]),
      ),
    );
  }

  /// Üst çubuk ve altındaki arama çubuğu aynı gölgeli, sayfa zeminli çerçeveyi kullanır.
  Widget _barFrame(BuTokens t, Widget child) {
    // Stitch v3: gölge yok, altta 1 dp `bd` çizgi (duvar kağıdı ile mesaj alanı arasında net sınır).
    return Container(
      decoration: BoxDecoration(color: t.bg, border: Border(bottom: BorderSide(color: t.bd))),
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: child,
    );
  }

  Widget _topBar(BuTokens t) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final status = _statusText();
    final online = _direct && _presence?['online'] == true;
    final openHeader = _direct
        ? () => _openProfileOf((_peer?['id'] as num?)?.toInt())
        : _openInfo;
    return _barFrame(
      t,
      Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        SizedBox(
          height: BuSize.appBar,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
            child: Row(children: [
              Tooltip(
                message: l.chatDetailBack,
                child: Semantics(
                  button: true,
                  label: l.chatDetailBack,
                  excludeSemantics: true,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(context, _changed),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(buDirIcon(context, LucideIcons.arrowLeft),
                          size: 24, color: t.ink),
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: _direct ? l.chatDetailOpenProfile : l.chatDetailChatInfo,
                excludeSemantics: true,
                onTap: openHeader,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: openHeader,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(child: _headerAvatar()),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  onTap: _openInfo,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
                        ValueListenableBuilder<bool>(
                          valueListenable: _typingNow,
                          builder: (c, typing, _) {
                            final text = typing
                                ? c.l10n.chatDetailTyping.replaceAll('…', '')
                                : status;
                            if (text == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: AnimatedSwitcher(
                                duration: BuMotion.of(c, BuMotion.short),
                                child: Row(
                                  key: ValueKey(typing),
                                  children: [
                                if (online && !typing) ...[
                                  Container(
                                    key: const ValueKey('onlineDot'),
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                        color: t.ok, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tx.labelMedium!.copyWith(
                                          color: typing ? t.pr : t.mut,
                                          fontWeight: FontWeight.w400)),
                                ),
                                if (typing) ...[
                                  const SizedBox(width: 4),
                                  ChatTypingDots(color: t.pr),
                                ],
                              ]),
                              ),
                            );
                          },
                        ),
                      ]),
                ),
              ),
              Tooltip(
                message: l.chatDetailMenu,
                child: Semantics(
                  button: true,
                  label: l.chatDetailMenu,
                  excludeSemantics: true,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _openChatMenu,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(LucideIcons.ellipsis,
                          size: 24, color: t.ink),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        if (_roomPage)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
              child: _roomChip(t),
            ),
          ),
      ]),
    );
  }

  /// Üst çubuk avatarı; sohbet listesindeki avatarla aynı Hero etiketini (`chat-avatar-<id>`) taşır.
  Widget _headerAvatar() => ChatlistAvatar(
        name: _title,
        url: _avatarUrl,
        size: 40,
        group: !_direct,
        headers: _avatarHeaders(_avatarUrl),
        heroTag: _conv['id'] is num ? 'chat-avatar-$_cid' : null,
      );

  /// Kulüp/etkinlik odası başlığının altındaki sayfa bağlantısı hapı.
  Widget _roomChip(BuTokens t) {
    final l = context.l10n;
    final label =
        _type == 'CLUB' ? l.chatDetailClubPage : l.chatDetailEventPage;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('roomPageChip'),
        borderRadius: BuRadius.bPill,
        onTap: _openRoomPage,
        child: SizedBox(
          height: 48,
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration:
                  BoxDecoration(color: t.soft, borderRadius: BuRadius.bPill),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge!
                        .copyWith(color: t.onSoft, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Icon(
                    _type == 'CLUB'
                        ? LucideIcons.arrowUpRight
                        : buDirIcon(context, LucideIcons.arrowRight),
                    size: 14,
                    color: t.onSoft),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBar(BuTokens t) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final hasMatches = _matches.isNotEmpty;
    final status = _searchOlderBusy
        ? l.chatDetailSearching
        : (_query.isEmpty ? l.chatDetailTypeToSearch : l.chatDetailNoMatch);
    Widget navButton(IconData icon, String tip, VoidCallback? onTap) {
      return Tooltip(
        message: tip,
        child: Semantics(
          button: true,
          enabled: onTap != null,
          label: tip,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BuRadius.bSm,
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration:
                      BoxDecoration(color: t.sf2, borderRadius: BuRadius.bSm),
                  child: Icon(icon, size: 20, color: t.ink),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return _barFrame(
      t,
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
              decoration:
                  BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
              child: Row(children: [
                Icon(LucideIcons.search, size: 20, color: t.pr),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('chatSearchField'),
                    controller: _searchCtl,
                    focusNode: _searchFocus,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    style: tx.bodyLarge!.copyWith(color: t.ink),
                    cursorColor: t.pr,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      hintText: l.chatDetailSearchInChat,
                      hintStyle: tx.bodyLarge!.copyWith(color: t.mut),
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  Tooltip(
                    message: l.p07ChatSearchClear,
                    child: Semantics(
                      button: true,
                      label: l.p07ChatSearchClear,
                      excludeSemantics: true,
                      child: InkWell(
                        key: const ValueKey('chatSearchClear'),
                        customBorder: const CircleBorder(),
                        onTap: () {
                          _searchCtl.clear();
                          _onSearchChanged('');
                        },
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(LucideIcons.x, size: 18, color: t.mut),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
            child: SizedBox(
              height: 52,
              child: Row(children: [
                if (hasMatches) ...[
                  Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration:
                        BoxDecoration(color: t.pr, borderRadius: BuRadius.bPill),
                    child: Text('${_matchPos + 1} / ${_matches.length}',
                        textDirection: TextDirection.ltr,
                        style: tx.labelMedium!.copyWith(
                            color: t.onPr, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 4),
                  navButton(LucideIcons.chevronUp, l.chatDetailPrevMatch,
                      () => _stepMatch(1)),
                  navButton(LucideIcons.chevronDown, l.chatDetailNextMatch,
                      () => _stepMatch(-1)),
                  const Spacer(),
                ] else
                  Expanded(
                    child: Text(status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tx.labelLarge!.copyWith(color: t.mut)),
                  ),
                TextButton(
                  key: const ValueKey('chatSearchClose'),
                  onPressed: _stopSearch,
                  style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: t.pr,
                      padding: const EdgeInsets.symmetric(horizontal: 12)),
                  child: Text(l.chatDetailClose,
                      style: tx.labelLarge!.copyWith(
                          color: t.pr, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
          if (_beforeCursor != null && _query.isNotEmpty && !_searchOlderBusy)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BuRadius.bPill,
                onTap: _searchOlder,
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                          color: t.sf2, borderRadius: BuRadius.bPill),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.history, size: 16, color: t.pr),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(l.chatDetailSearchOlder,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tx.labelLarge!.copyWith(
                                  color: t.onSoft, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _body(BuTokens t) {
    if (_loading) return _skeleton(t);
    if (_error != null) return ErrorView(error: _error!, onRetry: _boot);
    if (_msgs.isEmpty) {
      return BuEmptyState(
          illustration: BuIllustration.message,
          title: context.l10n.p07ChatEmptyTitle);
    }
    return Stack(children: [
      Positioned.fill(
        child: ValueListenableBuilder<int>(
          valueListenable: _peerRead,
          builder: (c, peerRead, _) => _list(t, peerRead),
        ),
      ),
      PositionedDirectional(end: 20, bottom: 12, child: _downButton(t)),
    ]);
  }

  /// Yükleniyor: sohbet düzenine benzeyen balon iskeleti (çember yok).
  Widget _skeleton(BuTokens t) {
    Widget bubble(bool mine, double w, double h) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
              mainAxisAlignment:
                  mine ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!mine) ...[
                  const BuSkeleton.circle(28),
                  const SizedBox(width: 8),
                ],
                BuSkeleton(width: w, height: h, radius: 18),
              ]),
        );
    return BuSkeletonScope(
      child: SingleChildScrollView(
        reverse: true,
        physics: const NeverScrollableScrollPhysics(),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          bubble(false, 220, 64),
          bubble(true, 190, 48),
          bubble(false, 150, 44),
          bubble(true, 230, 64),
          bubble(false, 200, 48),
        ]),
      ),
    );
  }

  Widget _downButton(BuTokens t) {
    return ValueListenableBuilder<bool>(
      valueListenable: _showDown,
      builder: (c, show, _) {
        // Belirme/kaybolma: 150 ms solma + %80 -> %100 ölçek (yalnız transform/opacity; "azalt"ta anında).
        return AnimatedSwitcher(
          duration: BuMotion.of(c, BuMotion.short),
          transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim, child: ScaleTransition(scale: Tween<double>(begin: .8, end: 1).animate(anim), child: child)),
          child: show
              ? KeyedSubtree(key: const ValueKey('down-shown'), child: _downBody(t))
              : const SizedBox.shrink(key: ValueKey('down-hidden')),
        );
      },
    );
  }

  Widget _downBody(BuTokens t) {
    return Builder(
      builder: (c) {
        return ValueListenableBuilder<int>(
          valueListenable: _newBelow,
          builder: (c, n, _) => Semantics(
            button: true,
            label: n > 0
                ? c.l10n.chatDetailScrollDownNew(n.toString())
                : c.l10n.chatDetailScrollDown,
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
                  width: BuSize.iconBtn,
                  height: BuSize.iconBtn,
                  decoration: BoxDecoration(
                    color: t.sf,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.bd),
                  ),
                  child: Icon(LucideIcons.chevronDown, size: 20, color: t.ink),
                ),
                if (n > 0)
                  PositionedDirectional(
                    top: -6,
                    end: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: t.pr, borderRadius: BorderRadius.circular(8)),
                      child: Text(n > 99 ? '99+' : '$n',
                          style: BuType.caption.copyWith(color: t.onPr, fontWeight: FontWeight.w500)),
                    ),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }

  /// Satırın kararlı kimliği: sunucu kimliği; yerel (henüz kimliksiz) balonda clientId. Yeni mesaj eklenince/liste
  /// kayınca Flutter satırları konuma göre değil kimliğe göre eşler (durum ve alt ağaç korunur).
  static String _rowId(Map<String, dynamic> m) {
    // Kendi mesajım: clientId yerel balondan sunucu mesajına geçerken de aynı kalır (alt ağaç/önizleme korunur).
    final c = m['clientId'];
    if (c is String && c.isNotEmpty) return 'c$c';
    final id = (m['id'] as num?)?.toInt();
    return id != null ? 'm$id' : 'q${m['_seq']}';
  }

  Widget _list(BuTokens t, int peerRead) {
    // findChildIndexCallback için kimlik -> konum (yapı başına bir kez).
    final indexOf = <String, int>{
      for (var i = 0; i < _msgs.length; i++) _rowId(_msgs[i]): i,
    };
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true, // klavye kapatma jesti: ekran okuyucuya boş bir düğme olarak çıkmasın
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView.builder(
          controller: _scroll,
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          itemCount: _msgs.length + 1,
          findChildIndexCallback: (key) {
            if (key is ValueKey<String>) return indexOf[key.value];
            return null;
          },
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
            return Column(key: ValueKey<String>(_rowId(m)), children: [
              if (newDay) _dayChip(t, _dayLabel(_time(m)!)),
              id == null
                  ? row
                  : KeyedSubtree(
                      key: _rowKeys.putIfAbsent(id, GlobalKey.new),
                      child: row),
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
          // Duvar kağıdı üstünde okunur kalsın: dolu yüzey + ince çizgi (balonlarla aynı dil).
          decoration: BoxDecoration(
              color: t.sf2,
              border: Border.all(color: t.bd),
              borderRadius: BorderRadius.circular(999)),
          child: Text(label,
              style: BuType.caption.copyWith(
                  color: t.mut, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );

  /// Satır: gelen mesajlarda solda 28 px avatar sütunu (yalnız serinin son mesajında avatar görünür,
  /// baloncuğun altına hizalı); giden mesajlarda yalnız baloncuk.
  Widget _rowFor(BuTokens t, Map<String, dynamic> m, int i, int peerRead) {
    final bubble =
        _bubble(m, peerRead, first: _firstOfRun(i), last: _lastOfRun(i));
    final mine = _isMine(m) || m['_state'] != null;
    if (mine) return bubble;
    final sid = _direct
        ? (_peer?['id'] as num?)?.toInt()
        : (m['senderId'] as num?)?.toInt();
    final name = _direct ? _title : _nameOf(sid);
    final url = _direct ? _avatarUrl : (sid == null ? null : _avatars[sid]);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      SizedBox(
        width: 28,
        child: _lastOfRun(i)
            ? GestureDetector(
                key: ValueKey('sender-avatar-${m['id']}'),
                onTap: () => _openProfileOf(sid),
                child: ChatlistAvatar(
                    name: name, url: url, size: 28, circle: true))
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
    if (!preview) ChatDetailPage.debugBubbleBuilds++;
    final mine = _isMine(m) || m['_state'] != null;
    final id = (m['id'] as num?)?.toInt();
    final reply = m['replyTo'] is Map ? m['replyTo'] as Map : null;
    final replyId = (reply?['id'] as num?)?.toInt();
    Widget make(bool hl) => MessageBubble(
      message: m,
      mine: mine,
      highlighted: hl,
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
    if (preview || id == null) return make(false);
    // Atlama vurgusu (2 dp çerçeve) yalnız bu mesajı yeniler.
    return ValueListenableBuilder<int?>(
      valueListenable: _hi,
      builder: (c, hi, _) => make(hi == id),
    );
  }

  /// Kapalı sohbet bandı: yazma alanı yerine geçer (sebep gösterilmez).
  Widget _closedBar(BuTokens t) {
    return Container(
      key: const ValueKey('chatClosedBanner'),
      width: double.infinity,
      decoration: BoxDecoration(color: t.sf, border: Border(top: BorderSide(color: t.bd))),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.of(context).padding.bottom),
      child: Row(children: [
        Icon(LucideIcons.lock, size: 18, color: t.mut),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(context.l10n.chatClosedBanner,
                style: BuType.body.copyWith(color: t.mut, height: 1.4)),
          ),
        ),
      ]),
    );
  }

  Widget _composer(BuTokens t) {
    return ListenableBuilder(
        listenable: _input, builder: (c, _) => _composerBody(t));
  }

  Future<void> _unblockPeer() async {
    final pid = (_peer?['id'] as num?)?.toInt();
    if (pid == null) return;
    try {
      await _api.delete('/users/$pid/block');
      _changed = true;
      if (!mounted) return;
      setState(() => _conv['blocked'] = false);
      _toast(context.l10n.chatDetailUserUnblocked);
    } catch (e) {
      if (mounted) _toastError(e);
    }
  }

  /// Engellenen kişiyle birebir sohbette yazma alanı yerine geçer.
  Widget _blockedBar(BuTokens t) {
    final tx = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('chatBlockedBar'),
      width: double.infinity,
      decoration: BoxDecoration(color: t.bg, boxShadow: _topShadow(t)),
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 8 + MediaQuery.paddingOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Semantics(
          liveRegion: true,
          child: Text(context.l10n.p07ChatBlockedLine,
              textAlign: TextAlign.center,
              style: tx.bodyMedium!.copyWith(color: t.mut)),
        ),
        TextButton(
          key: const ValueKey('chatUnblockButton'),
          onPressed: _unblockPeer,
          style: TextButton.styleFrom(
              minimumSize: const Size(48, 48), foregroundColor: t.pr),
          child: Text(context.l10n.chatDetailUnblock,
              style:
                  tx.labelLarge!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  /// Alt çubuklar (yazma alanı, engelli/kapalı bandı): gölge yok, üstte 1 dp `bd` çizgi.
  List<BoxShadow> _topShadow(BuTokens t) => const [];

  /// Tek "+" düğmesi (Ekle): 44 dp yumuşak nötr daire, 48 dp dokunma alanı; menü açıkken 45 derece dönüp "x" olur
  /// (yalnız transform; "animasyonları azalt"ta anında). Kamera ve galeri bu menüdedir.
  Widget _plusButton(BuTokens t) {
    final label = context.l10n.chatDetailAdd;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: BuPressable(
          key: const ValueKey('attachButton'),
          onTap: _openAttach,
          scale: .92,
          haptic: BuHaptic.selection,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bControl),
                child: AnimatedRotation(
                  turns: _attachOpen ? .125 : 0,
                  duration: BuMotion.of(context, BuMotion.short),
                  curve: Curves.easeOutCubic,
                  child: Icon(LucideIcons.plus, size: 24, color: t.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Yanıt / düzenleme çubuğu: solda kırmızı çizgi, ad ya da "Mesaj düzenleniyor", alıntı, kapat.
  Widget _replyBar(BuTokens t, Map<String, dynamic> banner) {
    final tx = Theme.of(context).textTheme;
    final editing = _editing != null;
    return Container(
      key: ValueKey(editing ? 'editBar' : 'replyBar'),
      width: double.infinity,
      color: t.sf2,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 4, 6),
      child: Row(children: [
        Container(
          width: 3,
          height: 40,
          decoration: BoxDecoration(
              color: t.pr, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(editing ? LucideIcons.pencil : LucideIcons.reply,
                      size: 14, color: t.mut),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        editing
                            ? context.l10n.chatDetailEditing
                            : _nameOf((banner['senderId'] as num?)?.toInt()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tx.labelMedium!.copyWith(
                            color: t.ink, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text((banner['text'] as String?) ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx.labelMedium!
                        .copyWith(color: t.mut, fontWeight: FontWeight.w400)),
              ]),
        ),
        IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip: context.l10n.chatDetailNevermind,
          icon: Icon(LucideIcons.x, size: 20, color: t.ink),
          onPressed: () => setState(() {
            if (_editing != null) _input.clear();
            _editing = null;
            _replyTo = null;
          }),
        ),
      ]),
    );
  }

  Widget _composerBody(BuTokens t) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final trimmed = _input.text.trim();
    final len = _len(trimmed); // gönderilen metinle aynı ölçü (kod noktası, kırpılmış)
    final canSend = trimmed.isNotEmpty && len <= _maxLen;
    final banner = _editing ?? _replyTo;
    // Yukarı ok: yönsüz simge (RTL'de çevirmeye gerek yok).
    final Widget sendIcon = Icon(
        _editing != null ? LucideIcons.check : LucideIcons.arrowUp,
        size: 24,
        color: canSend ? t.onPr : t.mut);
    return Container(
      decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.bd))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (banner != null) _replyBar(t, banner),
        if (len >= 1500)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4, start: 16, end: 16),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text('$len/$_maxLen',
                  style: tx.labelSmall!.copyWith(
                      color: len > _maxLen ? t.danger : t.mut,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
              12, 8, 20, 8 + MediaQuery.paddingOf(context).bottom),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (_editing == null) ...[
              _plusButton(t),
              const SizedBox(width: 4),
            ] else
              const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 46),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                      color: t.sf, borderRadius: BorderRadius.circular(24)),
                  child: TextField(
                    key: const ValueKey('composerField'),
                    controller: _input,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    style: tx.bodyLarge!.copyWith(color: t.ink),
                    cursorColor: t.pr,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      hintText: l.chatDetailWriteMessage,
                      hintStyle: tx.bodyLarge!.copyWith(color: t.mut),
                    ),
                  ),
                ),
              ),
            ),
            // Gönder yalnız metin varken görünür (Stitch v3); boşken alan genişler. 150 ms ölçek + solma, basınca küçülür.
            AnimatedSwitcher(
              duration: BuMotion.of(context, BuMotion.short),
              // Başlangıç opaklığı .4: ilk karede de dokunulabilir ve ekran okuyucuya görünür.
              transitionBuilder: (child, anim) => FadeTransition(
                  opacity: Tween<double>(begin: .4, end: 1).animate(anim),
                  child: ScaleTransition(scale: Tween<double>(begin: .6, end: 1).animate(anim), child: child)),
              child: trimmed.isEmpty
                  ? const SizedBox.shrink(key: ValueKey('noSend'))
                  : Padding(
                      key: const ValueKey('sendSlot'),
                      padding: const EdgeInsetsDirectional.only(start: 6),
                      child: Semantics(
                        button: true,
                        label: _editing != null ? l.chatDetailSave : l.chatDetailSend,
                        excludeSemantics: true,
                        child: BuPressable(
                          key: const ValueKey('sendButton'),
                          enabled: canSend,
                          onTap: canSend ? _submit : null,
                          scale: .9,
                          haptic: BuHaptic.light,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              // Sınır aşıldıysa (2000+) düğme görünür ama soluk ve devre dışı; sayaç kırmızı uyarır.
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(color: canSend ? t.pr : t.sf2, borderRadius: BuRadius.bControl),
                                child: sendIcon,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Sohbet onay diyaloğu (referans 21/22): 28 dp köşe, başlık satırında simge karosu, tonal "Vazgeç" + kırmızı eylem.
class _ChatConfirmDialog extends StatelessWidget {
  const _ChatConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    this.icon,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    Widget button(String label, VoidCallback onTap,
        {required bool primary, Key? key}) {
      return Expanded(
        child: Material(
          color: primary ? t.danger : t.sf2,
          borderRadius: BuRadius.bMd,
          elevation: 0,
          child: InkWell(
            key: key,
            borderRadius: BuRadius.bMd,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: primary
                  ? BoxDecoration(borderRadius: BuRadius.bMd, boxShadow: [
                      BoxShadow(
                          color: t.danger.withValues(alpha: .3),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ])
                  : null,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (primary && icon != null) ...[
                  Icon(icon, size: 18, color: t.onPr),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tx.titleSmall!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: primary ? t.onPr : t.ink)),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return Dialog(
      key: const ValueKey('chatConfirmDialog'),
      backgroundColor: t.sf3,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: const RoundedRectangleBorder(borderRadius: BuRadius.bXl),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            if (icon != null) ...[
              ExcludeSemantics(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration:
                      BoxDecoration(color: t.soft, borderRadius: BuRadius.bSm),
                  child: Icon(icon, size: 22, color: t.danger),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(title,
                  style: tx.titleLarge!
                      .copyWith(color: t.ink, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(body,
                style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
          ),
          const SizedBox(height: 22),
          Row(children: [
            button(cancelLabel, () => Navigator.pop(context, false),
                primary: false, key: const ValueKey('chatConfirmCancel')),
            const SizedBox(width: 12),
            button(confirmLabel, () => Navigator.pop(context, true),
                primary: true, key: const ValueKey('chatConfirmOk')),
          ]),
        ]),
      ),
    );
  }
}
