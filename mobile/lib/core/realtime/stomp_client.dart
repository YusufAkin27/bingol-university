import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../api.dart' show ApiError;
import 'stomp_frame.dart';

export 'stomp_frame.dart';

enum StompState { disconnected, connecting, connected }

/// Kalıcı bağlantı hatası (yeniden bağlanma durur): askı veya oturum bitti.
enum StompFatal { suspended, sessionExpired, forbidden }

class StompSubscription {
  StompSubscription._(this.id, this.destination, this._onFrame, this._client);

  final String id;
  final String destination;
  final void Function(StompFrame) _onFrame;
  final StompClient _client;

  void cancel() => _client._unsubscribe(this);
}

/// Saf Dart STOMP 1.2 istemcisi (web_socket_channel). Kalp atışı, üstel geri çekilmeyle
/// yeniden bağlanma ve token süresi dolmadan önce yenileme içerir. ACK kullanılmaz.
class StompClient {
  StompClient({
    required this.url,
    required this.host,
    required this.accessToken,
    required this.refreshToken,
    this.heartbeat = const Duration(seconds: 10),
  });

  final String url;
  final String host;

  /// Geçerli access token (yoksa null: bağlanılmaz).
  final String? Function() accessToken;

  /// Tek uçuşlu refresh (session.api.refresh()); yeni access döner, 401'de ApiError atar.
  final Future<String?> Function() refreshToken;
  final Duration heartbeat;

  final _stateCtl = StreamController<StompState>.broadcast();
  final _fatalCtl = StreamController<StompFatal>.broadcast();
  final _subs = <String, StompSubscription>{};
  final _rand = Random();

  StompState _state = StompState.disconnected;
  WebSocketChannel? _ch;
  StreamSubscription? _wsSub;
  Timer? _sendBeat, _recvWatch, _reconnectTimer, _refreshTimer, _connectTimeout;
  DateTime _lastRecv = DateTime.now();
  int _attempt = 0;
  int _subSeq = 0;
  bool _wanted = false;
  int _gen = 0; // eski bağlantının geç gelen olaylarını yok saymak için

  Stream<StompState> get states => _stateCtl.stream;
  Stream<StompFatal> get fatal => _fatalCtl.stream;
  StompState get state => _state;
  bool get isConnected => _state == StompState.connected;

  /// Bağlanmayı başlatır; kopmada kendiliğinden yeniden dener.
  void connect() {
    if (_wanted) return;
    _wanted = true;
    _attempt = 0;
    _open();
  }

  /// İstemci isteğiyle kapatır (arka plana geçiş, çıkış). Abonelik kayıtları korunur.
  void disconnect() {
    _wanted = false;
    _teardown(send: true);
    _setState(StompState.disconnected);
  }

  void dispose() {
    disconnect();
    _subs.clear();
    _stateCtl.close();
    _fatalCtl.close();
  }

  StompSubscription subscribe(String destination, void Function(StompFrame) onMessage) {
    final s = StompSubscription._('sub-${_subSeq++}', destination, onMessage, this);
    _subs[s.id] = s;
    if (isConnected) _sendSubscribe(s);
    return s;
  }

  void _unsubscribe(StompSubscription s) {
    if (_subs.remove(s.id) != null && isConnected) {
      _write(StompFrame('UNSUBSCRIBE', headers: {'id': s.id}));
    }
  }

  /// Bağlı değilse false döner (çağıran REST yedeğine düşer).
  bool send(String destination, String body, {Map<String, String>? headers}) {
    if (!isConnected) return false;
    _write(StompFrame('SEND', headers: {
      'destination': destination,
      'content-type': 'application/json',
      ...?headers,
    }, body: body));
    return true;
  }

  // ---- bağlantı yaşam döngüsü ----

  Future<void> _open() async {
    if (!_wanted || _state != StompState.disconnected) return;
    _setState(StompState.connecting);
    final gen = ++_gen;
    try {
      // Her denemeden önce token süresini denetle.
      var token = accessToken();
      if (token == null) {
        _setState(StompState.disconnected);
        _fatalCtl.add(StompFatal.sessionExpired);
        _wanted = false;
        return;
      }
      final exp = jwtExpiry(token);
      if (exp != null && exp.difference(DateTime.now()) < const Duration(seconds: 60)) {
        token = await refreshToken() ?? token;
        if (gen != _gen || !_wanted) return;
      }
      final ch = WebSocketChannel.connect(Uri.parse(url));
      _ch = ch;
      await ch.ready.timeout(const Duration(seconds: 10));
      if (gen != _gen || !_wanted) {
        ch.sink.close();
        return;
      }
      _lastRecv = DateTime.now();
      _wsSub = ch.stream.listen(
        (d) => _onData(gen, d),
        onError: (_) => _onClosed(gen),
        onDone: () => _onClosed(gen),
        cancelOnError: true,
      );
      _write(StompFrame('CONNECT', headers: {
        'accept-version': '1.2',
        'host': host,
        'heart-beat': '${heartbeat.inMilliseconds},${heartbeat.inMilliseconds}',
        'Authorization': 'Bearer $token',
      }));
      // Sunucu 10 sn içinde CONNECTED gelmezse bağlantıyı bırak.
      _connectTimeout = Timer(const Duration(seconds: 10), () => _onClosed(gen));
    } catch (e) {
      if (gen != _gen) return;
      await _failed(e);
    }
  }

  Future<void> _failed(Object e) async {
    _teardown();
    _setState(StompState.disconnected);
    // Refresh'in kesin reddi (ApiError 401, ağ dışı) oturumun bittiğini gösterir.
    if (e is ApiError && !e.isNetwork && (e.status == 401 || e.status == 400)) {
      _wanted = false;
      _fatalCtl.add(StompFatal.sessionExpired);
      return;
    }
    _scheduleReconnect();
  }

  void _onData(int gen, dynamic data) {
    if (gen != _gen) return;
    _lastRecv = DateTime.now();
    final text = data is String ? data : utf8.decode(data as List<int>);
    for (final f in StompFrame.parse(text)) {
      switch (f.command) {
        case 'CONNECTED':
          _connectTimeout?.cancel();
          _onConnected(gen, f);
        case 'MESSAGE':
          final sid = f.headers['subscription'];
          final sub = sid != null ? _subs[sid] : null;
          sub?._onFrame(f);
        case 'ERROR':
          _onError(gen, f);
      }
    }
  }

  void _onConnected(int gen, StompFrame f) {
    _attempt = 0;
    _setState(StompState.connected);
    for (final s in _subs.values) {
      _sendSubscribe(s);
    }
    // Kalp atışı: gönderim aralığı = max(bizim, sunucunun alma isteği).
    final hb = (f.headers['heart-beat'] ?? '0,0').split(',');
    final sx = int.tryParse(hb.first) ?? 0; // sunucunun gönderme aralığı
    final sy = int.tryParse(hb.length > 1 ? hb[1] : '0') ?? 0; // sunucunun beklediği
    final mine = heartbeat.inMilliseconds;
    if (mine > 0 && sy > 0) {
      _sendBeat = Timer.periodic(Duration(milliseconds: max(mine, sy)), (_) => _raw('\n'));
    }
    if (mine > 0 && sx > 0) {
      final limit = Duration(milliseconds: max(mine, sx) * 3);
      _recvWatch = Timer.periodic(const Duration(seconds: 5), (_) {
        if (DateTime.now().difference(_lastRecv) > limit) _onClosed(gen);
      });
    }
    // Token dolmadan ~60 sn önce yenile ve yeniden bağlan.
    final tok = accessToken();
    final exp = tok == null ? null : jwtExpiry(tok);
    if (exp != null) {
      var wait = exp.difference(DateTime.now()) - const Duration(seconds: 60);
      if (wait < const Duration(seconds: 5)) wait = const Duration(seconds: 5);
      _refreshTimer = Timer(wait, () => _proactiveRefresh(gen));
    }
  }

  Future<void> _proactiveRefresh(int gen) async {
    if (gen != _gen || !_wanted) return;
    try {
      await refreshToken();
    } catch (e) {
      if (gen != _gen) return;
      await _failed(e);
      return;
    }
    if (gen != _gen || !_wanted) return;
    _teardown(send: true);
    _setState(StompState.disconnected);
    _open(); // geri çekilmesiz: yeni token ile hemen
  }

  Future<void> _onError(int gen, StompFrame f) async {
    final code = f.headers['message'] ?? '';
    _teardown();
    _setState(StompState.disconnected);
    switch (code) {
      case 'SUSPENDED':
        _wanted = false;
        _fatalCtl.add(StompFatal.suspended);
      case 'FORBIDDEN_DESTINATION':
        _wanted = false;
        _fatalCtl.add(StompFatal.forbidden);
      case 'UNAUTHORIZED' || 'TOKEN_EXPIRED':
        try {
          await refreshToken();
          if (_wanted) _open();
        } catch (e) {
          await _failed(e);
        }
      default:
        _scheduleReconnect();
    }
  }

  void _onClosed(int gen) {
    if (gen != _gen) return;
    _teardown();
    _setState(StompState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_wanted) return;
    _reconnectTimer?.cancel();
    final secs = min(30, 1 << min(_attempt, 5));
    _attempt++;
    final jitter = 0.8 + _rand.nextDouble() * 0.4; // +-%20
    _reconnectTimer = Timer(Duration(milliseconds: (secs * 1000 * jitter).round()), _open);
  }

  /// Ağ geri geldiğinde beklemeden hemen dene.
  void reconnectNow() {
    if (!_wanted || _state != StompState.disconnected) return;
    _reconnectTimer?.cancel();
    _open();
  }

  void _teardown({bool send = false}) {
    _gen++;
    _reconnectTimer?.cancel();
    _sendBeat?.cancel();
    _recvWatch?.cancel();
    _refreshTimer?.cancel();
    _connectTimeout?.cancel();
    if (send && isConnected) {
      try {
        _write(StompFrame('DISCONNECT'));
      } catch (_) {}
    }
    _wsSub?.cancel();
    try {
      _ch?.sink.close();
    } catch (_) {}
    _wsSub = null;
    _ch = null;
  }

  void _sendSubscribe(StompSubscription s) =>
      _write(StompFrame('SUBSCRIBE', headers: {'id': s.id, 'destination': s.destination}));

  void _write(StompFrame f) => _raw(f.encode());

  void _raw(String s) {
    try {
      _ch?.sink.add(s);
    } catch (_) {}
  }

  void _setState(StompState s) {
    if (_state == s) return;
    _state = s;
    if (!_stateCtl.isClosed) _stateCtl.add(s);
  }

  /// JWT `exp` (UTC); çözülemezse null.
  static DateTime? jwtExpiry(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) return null;
      final json = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map;
      final exp = json['exp'];
      if (exp is num) return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    } catch (_) {}
    return null;
  }
}
