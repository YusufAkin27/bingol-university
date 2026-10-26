import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../api.dart';
import '../session.dart';
import 'stomp_client.dart';

/// `/user/queue/errors` iletisi: kullanıcı metnini `code`'dan kendi çevirinizle üretin.
class ChatError {
  ChatError(this.code, this.message, this.clientId);
  final String code;
  final String message;
  final String? clientId;
}

class ReadReceipt {
  ReadReceipt(this.conversationId, this.userId, this.lastMessageId);
  final int conversationId;
  final int userId;
  final int lastMessageId;
}

class TypingEvent {
  TypingEvent(this.conversationId, this.userId);
  final int conversationId;
  final int userId;
}

class Presence {
  Presence(this.online, this.lastSeenAt);
  final bool online;
  final DateTime? lastSeenAt;
}

/// Sohbet gerçek zamanlı katmanı (MOBILE_API_GUIDE bölüm 4). Ön planda bağlı kalır,
/// arka planda kapanır, öne gelince yeniden bağlanır. Her (yeniden) bağlanmada
/// [connected] `true` yayar: dinleyiciler `GET /conversations/{id}/messages?after=` ile boşluğu kapatmalı.
class ChatRealtime with WidgetsBindingObserver {
  ChatRealtime(this.session) {
    final origin = Uri.parse(apiOrigin);
    final scheme = origin.scheme == 'https' ? 'wss' : 'ws';
    _client = StompClient(
      url: Uri(scheme: scheme, host: origin.host, port: origin.hasPort ? origin.port : null, path: '/ws').toString(),
      host: origin.host,
      accessToken: () => session.api.tokens?.access,
      refreshToken: () async => (await session.api.refresh()).access,
    );
    _client.states.listen((s) {
      _connected.add(s == StompState.connected);
      if (s == StompState.connected) _resync.add(null);
    });
    _client.fatal.listen((f) {
      _fatal.add(f);
      if (f == StompFatal.sessionExpired) session.api.onSessionExpired?.call();
    });
  }

  final Session session;
  late final StompClient _client;
  final _subs = <StompSubscription>[];

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _reads = StreamController<ReadReceipt>.broadcast();
  final _typing = StreamController<TypingEvent>.broadcast();
  final _errors = StreamController<ChatError>.broadcast();
  final _connected = StreamController<bool>.broadcast();
  final _resync = StreamController<void>.broadcast();
  final _fatal = StreamController<StompFatal>.broadcast();

  bool _started = false;
  final _lastTypingSent = <int, DateTime>{};
  static final _rnd = Random.secure();

  /// Yeni mesaj (MessageView); kendi mesajınızın ack'i de buraya düşer (`clientId` ile eşleyin).
  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<ReadReceipt> get readReceipts => _reads.stream;
  Stream<TypingEvent> get typing => _typing.stream;
  Stream<ChatError> get errors => _errors.stream;
  Stream<bool> get connected => _connected.stream;
  bool get isConnected => _client.isConnected;

  /// Bağlantı her kurulduğunda tetiklenir: boşluk kapatma (resync) zamanı.
  Stream<void> get resync => _resync.stream;

  /// SUSPENDED / oturum bitti gibi kalıcı durumlar.
  Stream<StompFatal> get fatal => _fatal.stream;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _subs
      ..add(_client.subscribe('/user/queue/messages', (f) => _json(f, (m) => _messages.add(m))))
      ..add(_client.subscribe('/user/queue/read-receipts', (f) => _json(f, (m) {
            _reads.add(ReadReceipt(_i(m['conversationId']), _i(m['userId']), _i(m['lastMessageId'])));
          })))
      ..add(_client.subscribe('/user/queue/typing', (f) => _json(f, (m) {
            _typing.add(TypingEvent(_i(m['conversationId']), _i(m['userId'])));
          })))
      ..add(_client.subscribe('/user/queue/errors', (f) => _json(f, (m) {
            _errors.add(ChatError('${m['code'] ?? 'UNKNOWN'}', '${m['message'] ?? ''}', m['clientId'] as String?));
          })));
    _client.connect();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _client.disconnect();
  }

  void dispose() {
    stop();
    _client.dispose();
    for (final c in [_messages, _reads, _typing, _errors, _connected, _resync, _fatal]) {
      c.close();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started) return;
    if (state == AppLifecycleState.resumed) {
      _client.connect();
      _client.reconnectNow();
    } else if (state == AppLifecycleState.paused) {
      _client.disconnect();
    }
  }

  // ---- komutlar ----

  /// UUIDv4 `clientId` üretir (idempotency).
  static String newClientId() {
    final b = List<int>.generate(16, (_) => _rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int s, int e) => b.sublist(s, e).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
  }

  /// WS ile gönderir; bağlı değilse false (çağıran REST yedeğini kullanır, aynı clientId ile).
  bool sendMessage(int conversationId, String text, String clientId) => _client.send(
      '/app/chat.send', jsonEncode({'conversationId': conversationId, 'text': text, 'clientId': clientId}));

  /// Okundu imleci (yalnız ilerler).
  bool sendRead(int conversationId, int lastMessageId) =>
      _client.send('/app/chat.read', jsonEncode({'conversationId': conversationId, 'lastMessageId': lastMessageId}));

  /// "Yazıyor": sunucu 2 sn'de 1 ile sınırlar; burada da aynı sınır uygulanır.
  bool sendTyping(int conversationId) {
    final now = DateTime.now();
    final last = _lastTypingSent[conversationId];
    if (last != null && now.difference(last) < const Duration(seconds: 2)) return false;
    _lastTypingSent[conversationId] = now;
    return _client.send('/app/chat.typing', jsonEncode({'conversationId': conversationId}));
  }

  // ---- çevrimiçi durumu (WS kuyruğu yok: REST) ----

  /// Yalnız ortak konuşması olan kullanıcılar için; aksi (404) null.
  Future<Presence?> fetchPresence(int userId) async {
    try {
      final r = await session.api.get('/users/$userId/presence') as Map<String, dynamic>;
      final ls = r['lastSeenAt'] as String?;
      return Presence(r['online'] == true, ls == null ? null : DateTime.tryParse(ls)?.toLocal());
    } on ApiError {
      return null;
    }
  }

  /// Çevrimiçi durumunu aralıklı yoklayan akış (dinlenmeyince durur).
  Stream<Presence?> watchPresence(int userId, {Duration every = const Duration(seconds: 30)}) async* {
    while (true) {
      yield await fetchPresence(userId);
      await Future<void>.delayed(every);
    }
  }

  void _json(StompFrame f, void Function(Map<String, dynamic>) on) {
    try {
      final v = jsonDecode(f.body);
      if (v is Map<String, dynamic>) on(v);
    } catch (_) {}
  }

  static int _i(Object? v) => (v as num?)?.toInt() ?? 0;
}
