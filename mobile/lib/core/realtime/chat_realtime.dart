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

/// `/user/queue/message-events` `viewed`: tek gösterimlik fotoğraf alıcıda açıldı (gönderenin baloncuğu "Açıldı" olur).
class ViewedEvent {
  ViewedEvent(this.conversationId, this.messageId, this.attachmentId, this.userId);
  final int conversationId;
  final int messageId;
  final int attachmentId;
  final int userId;
}

/// `/user/queue/message-events` `receipt`: kendi mesajlarınız `upToMessageId`'ye kadar iletildi/okundu.
/// `/user/queue/message-events` `deleted`: mesaj herkes için silindi ya da yönetici tarafından gizlendi/silindi (P08).
/// Olay yalnız kimliği taşır; yer tutucu metni için sohbet mesaj sayfasını yeniden çekin. Geri gösterme (unhide)
/// için olay YOKTUR: sohbet açılınca/yenilenince taze çekim yeterlidir.
class MessageDeletedEvent {
  MessageDeletedEvent(this.conversationId, this.messageId);
  final int conversationId;
  final int messageId;
}

class ReceiptEvent {
  ReceiptEvent(this.conversationId, this.kind, this.upToMessageId, this.status);
  final int conversationId;

  /// `delivered` | `read`
  final String kind;
  final int upToMessageId;

  /// Sunucunun bildirdiği durum (`SENT`|`DELIVERED`|`READ`); yoksa null ([kind]'dan türetilir).
  final String? status;

  /// Bu olayın taşıdığı durum.
  String get effectiveStatus => status ?? (kind == 'read' ? 'READ' : 'DELIVERED');
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
    debugInstanceCount++;
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
      if (s != StompState.connected) _awaitingAck.clear(); // koptu: ack beklenenler artık yalnız Outbox'a güvenir
      if (s == StompState.connected) _resync.add(null);
    });
    _client.fatal.listen((f) {
      _fatal.add(f);
      if (f == StompFatal.sessionExpired) session.api.onSessionExpired?.call();
      if (f == StompFatal.sessionReplaced) session.forceSignOut(reason: SignOutReason.replaced);
    });
  }

  /// Yalnız testler: oluşturulan örnek sayısı (tek soket kuralı: ekranlar `session.realtime`'ı paylaşır, yenisini
  /// kurmaz; her örnek kendi WebSocket'ini açar).
  @visibleForTesting
  static int debugInstanceCount = 0;

  final Session session;
  late final StompClient _client;
  final _subs = <StompSubscription>[];

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _reads = StreamController<ReadReceipt>.broadcast();
  final _typing = StreamController<TypingEvent>.broadcast();
  final _errors = StreamController<ChatError>.broadcast();
  final _viewed = StreamController<ViewedEvent>.broadcast();
  final _receipts = StreamController<ReceiptEvent>.broadcast();
  final _deleted = StreamController<MessageDeletedEvent>.broadcast();
  final _removed = StreamController<int>.broadcast();
  final _connected = StreamController<bool>.broadcast();
  final _resync = StreamController<void>.broadcast();
  final _fatal = StreamController<StompFatal>.broadcast();

  bool _started = false;
  final _awaitingAck = <String>{};
  final _lastTypingSent = <int, DateTime>{};
  static final _rnd = Random.secure();

  /// Yeni mesaj (MessageView); kendi mesajınızın ack'i de buraya düşer (`clientId` ile eşleyin).
  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<ReadReceipt> get readReceipts => _reads.stream;
  Stream<TypingEvent> get typing => _typing.stream;
  Stream<ChatError> get errors => _errors.stream;
  Stream<ViewedEvent> get viewed => _viewed.stream;
  Stream<ReceiptEvent> get receipts => _receipts.stream;
  Stream<MessageDeletedEvent> get deletedMessages => _deleted.stream;

  /// `conversation-removed`: bu kullanıcı konuşmadan çıkarıldı/ayrıldı/konuşma kapandı (konuşma kimliği).
  /// Açık sohbet ekranı kendini kapatmalı; liste ayrıca [resync] ile yenilenir.
  Stream<int> get removedConversations => _removed.stream;
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
      ..add(_client.subscribe('/user/queue/messages', (f) => _json(f, _onMessage)))
      ..add(_client.subscribe('/user/queue/read-receipts', (f) => _json(f, (m) {
            _reads.add(ReadReceipt(_i(m['conversationId']), _i(m['userId']), _i(m['lastMessageId'])));
          })))
      ..add(_client.subscribe('/user/queue/typing', (f) => _json(f, (m) {
            _typing.add(TypingEvent(_i(m['conversationId']), _i(m['userId'])));
          })))
      ..add(_client.subscribe('/user/queue/message-events', (f) => _json(f, _onMessageEvent)))
      ..add(_client.subscribe('/user/queue/errors', (f) => _json(f, (m) {
            final cid = m['clientId'] as String?;
            if (cid != null) _awaitingAck.remove(cid);
            _errors.add(ChatError('${m['code'] ?? 'UNKNOWN'}', '${m['message'] ?? ''}', cid));
          })));
    _client.connect();
  }

  /// Gelen mesaj: akışa verilir; kendi metin mesajımızın ack'iyse kalıcı kuyruktaki (Outbox) yedeği de silinir.
  /// Bu iş sayfadan bağımsızdır: sohbet ekranı kapalıyken gelen ack da kuyruğu temizler (T-093).
  void _onMessage(Map<String, dynamic> m) {
    _messages.add(m);
    ackOutbox(m);
  }

  /// WS ile gönderilen metin mesajı sunucuda oluştu (ack ya da başka cihazdan yayın): Outbox'taki `clientId`
  /// kaydı silinir. Yalnız kendi mesajımız ve yalnız metin öğesi (medya öğeleri kendi akışında teslim olur).
  @visibleForTesting
  void ackOutbox(Map<String, dynamic> m) {
    final cid = m['clientId'];
    if (cid is! String || cid.isEmpty) return;
    _awaitingAck.remove(cid);
    final uid = session.userId;
    if (uid == null || _i(m['senderId']) != uid) return;
    final ob = session.api.outbox;
    final it = ob?.byClientId(cid);
    if (ob == null || it == null || it.media.isNotEmpty) return;
    unawaited(ob.remove(cid));
  }

  void _onMessageEvent(Map<String, dynamic> m) {
    // Başka cihazda giriş: oturumu kapat (stop() yeniden bağlanmayı da durdurur).
    if (m['type'] == 'session-replaced') {
      session.forceSignOut(reason: SignOutReason.replaced);
      return;
    }
    if (m['type'] == 'receipt') {
      final kind = '${m['kind'] ?? ''}';
      if (kind != 'delivered' && kind != 'read') return;
      _receipts.add(ReceiptEvent(_i(m['conversationId']), kind, _i(m['upToMessageId']), m['status'] as String?));
      return;
    }
    // Ayrılma/çıkarılma/kulüp silinmesi: sohbet listesi yeniden çekilsin.
    if (m['type'] == 'conversation-removed') {
      final cid = _i(m['conversationId']);
      if (cid != 0) _removed.add(cid);
      _resync.add(null);
      return;
    }
    if (m['type'] == 'deleted') {
      _deleted.add(MessageDeletedEvent(_i(m['conversationId']), _i(m['messageId'])));
      return;
    }
    if (m['type'] != 'viewed') return;
    _viewed.add(ViewedEvent(_i(m['conversationId']), _i(m['messageId']), _i(m['attachmentId']), _i(m['userId'])));
  }

  /// Yalnız testler: bir kuyruk iletisini bağlantısız taklit eder.
  @visibleForTesting
  void debugEmitMessageEvent(Map<String, dynamic> m) => _onMessageEvent(m);

  @visibleForTesting
  void debugEmitMessage(Map<String, dynamic> m) => _onMessage(m);

  /// Yalnız testler: bağlantı durumu değişimini taklit eder (`connected` akışı + `resync`).
  @visibleForTesting
  void debugEmitConnected(bool on) {
    _connected.add(on);
    if (on) _resync.add(null);
  }

  @visibleForTesting
  void debugEmitError(ChatError e) => _errors.add(e);

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
    for (final c in [_messages, _reads, _typing, _errors, _viewed, _receipts, _deleted, _removed, _connected, _resync, _fatal]) {
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
  bool sendMessage(int conversationId, String text, String clientId) {
    final ok = _client.send(
        '/app/chat.send', jsonEncode({'conversationId': conversationId, 'text': text, 'clientId': clientId}));
    if (ok) _awaitingAck.add(clientId);
    return ok;
  }

  /// [sendMessage] ile giden mesajın ack'i (ya da hatası) henüz gelmedi mi? Ack bekleyen Outbox öğesi gerçek bir
  /// "çevrimdışı birikim" sayılmaz: yeni mesajlar arkasına kuyruklanmaz, WS'den hızla gider.
  bool isAwaitingAck(String clientId) => _awaitingAck.contains(clientId);

  /// Yalnız testler: sahte [sendMessage] gönderimi ack bekliyor diye işaretler.
  @visibleForTesting
  void debugMarkAwaitingAck(String clientId) => _awaitingAck.add(clientId);

  /// Okundu imleci (yalnız ilerler).
  bool sendRead(int conversationId, int lastMessageId) =>
      _client.send('/app/chat.read', jsonEncode({'conversationId': conversationId, 'lastMessageId': lastMessageId}));

  /// İletildi imleci: karşı tarafın en son mesaj id'si ekrana ulaştığında (yalnız ilerler).
  bool sendDelivered(int conversationId, int lastMessageId) => _client.send(
      '/app/chat.delivered', jsonEncode({'conversationId': conversationId, 'lastMessageId': lastMessageId}));

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
