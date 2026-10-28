import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api.dart';
import '../connectivity/connectivity_service.dart';

enum OutboxStatus { pending, failed }

/// Kuyruktaki tek sohbet metin mesajı. Sunucu `(konuşma, gönderen, clientId)` tekrarını yeni mesaj saymaz,
/// bu yüzden aynı öğeyi yeniden göndermek çift mesaj üretmez.
class OutboxItem {
  OutboxItem({
    required this.clientId,
    required this.conversationId,
    required this.text,
    required this.createdAt,
    this.replyToMessageId,
    this.status = OutboxStatus.pending,
    this.attempts = 0,
    this.serverFails = 0,
    this.nextAttemptAt = 0,
    this.errorCode,
  });

  final String clientId;
  final int conversationId;
  final String text;
  final int createdAt; // epoch ms
  final int? replyToMessageId;
  OutboxStatus status;

  /// Tüm başarısız denemeler (geri çekilmeyi belirler).
  int attempts;

  /// Yalnız sunucu 5xx hataları: [Outbox.maxServerFails]'te kalıcı hata sayılır (ağ yokluğu sayılmaz).
  int serverFails;
  int nextAttemptAt; // epoch ms
  String? errorCode;

  Map<String, dynamic> toJson() => {
        'c': clientId,
        'v': conversationId,
        't': text,
        'a': createdAt,
        if (replyToMessageId != null) 'r': replyToMessageId,
        's': status.index,
        'n': attempts,
        'f': serverFails,
        'x': nextAttemptAt,
        if (errorCode != null) 'e': errorCode,
      };

  static OutboxItem? fromJson(Object? j) {
    if (j is! Map) return null;
    final c = j['c'], v = j['v'], t = j['t'], a = j['a'];
    if (c is! String || v is! int || t is! String || a is! int) return null;
    final s = j['s'];
    return OutboxItem(
      clientId: c,
      conversationId: v,
      text: t,
      createdAt: a,
      replyToMessageId: j['r'] is int ? j['r'] as int : null,
      status: s is int && s >= 0 && s < OutboxStatus.values.length ? OutboxStatus.values[s] : OutboxStatus.pending,
      attempts: j['n'] is int ? j['n'] as int : 0,
      serverFails: j['f'] is int ? j['f'] as int : 0,
      nextAttemptAt: j['x'] is int ? j['x'] as int : 0,
      errorCode: j['e'] is String ? j['e'] as String : null,
    );
  }
}

/// Başarıyla iletilen mesaj (ekranlar `clientId` ile balonu eşleyebilir).
class OutboxDelivery {
  OutboxDelivery(this.item, this.response);
  final OutboxItem item;
  final Object? response;
}

/// Kalıcı depo soyutlaması (testlerde bellek içi).
abstract class OutboxStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class MemoryOutboxStore implements OutboxStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async => value = v;
}

/// Platformun şifreli deposu (iOS Keychain / Android Keystore): bekleyen mesaj metni düz dosyada durmaz.
class SecureOutboxStore implements OutboxStore {
  const SecureOutboxStore();
  static const _key = 'outbox_v1';
  static const _s = FlutterSecureStorage();

  @override
  Future<String?> read() => _s.read(key: _key);

  @override
  Future<void> write(String? value) async {
    if (value == null) {
      await _s.delete(key: _key);
    } else {
      await _s.write(key: _key, value: value);
    }
  }
}

typedef OutboxSender = Future<Object?> Function(OutboxItem item);

/// Çevrimdışı sohbet mesajı kuyruğu: yalnız METİN (yanıt dahil). Medya kuyruğa alınmaz (büyük + yükleme aşamalı).
///
/// - Kalıcı (uygulama kapansa da kalır), en çok [maxItems] öğe, [maxAge]'den eski olanlar atılır.
/// - Gönderim sırası korunur; ağ hatasında kuyruğun başında durur (sıra bozulmaz), üstel geri çekilmeyle tekrar dener.
/// - 4xx (doğrulama vb.) kalıcı hata: öğe `failed` olur, elle [retry]/[remove] beklenir.
/// - Periyodik yoklama yok: yalnızca "bir sonraki deneme" zamanlayıcısı ve bağlantı geri geldiğinde tetikleme.
class Outbox extends ChangeNotifier {
  Outbox({
    OutboxStore? store,
    this.maxItems = 100,
    this.maxAge = const Duration(days: 7),
    this.maxServerFails = 8,
    this.maxTextLength = 2000,
    DateTime Function()? now,
    this.autoSchedule = true,
    OutboxSender? sender,
  })  : _store = store ?? const SecureOutboxStore(),
        _now = now ?? DateTime.now,
        _sender = sender;

  static final RegExp _messagesPath = RegExp(r'^/conversations/(\d+)/messages$');

  final OutboxStore _store;
  final DateTime Function() _now;
  final int maxItems;
  final Duration maxAge;
  final int maxServerFails;
  final int maxTextLength;
  final bool autoSchedule;
  OutboxSender? _sender;

  final List<OutboxItem> _items = [];
  final _deliveries = StreamController<OutboxDelivery>.broadcast();
  Timer? _timer;
  bool _draining = false;
  bool _loaded = false;
  ConnectivityService? _connectivity;

  /// Geri çekilme: 2 sn, 5 sn, 15 sn, 1 dk, sonra 5 dk.
  static Duration backoff(int attempts) {
    const steps = [2, 5, 15, 60, 300];
    return Duration(seconds: steps[(attempts - 1).clamp(0, steps.length - 1)]);
  }

  Stream<OutboxDelivery> get deliveries => _deliveries.stream;
  List<OutboxItem> get items => List.unmodifiable(_items);
  int get pendingCount => _items.where((e) => e.status == OutboxStatus.pending).length;
  int get failedCount => _items.where((e) => e.status == OutboxStatus.failed).length;
  bool contains(String clientId) => _items.any((e) => e.clientId == clientId);

  OutboxItem? byClientId(String clientId) {
    for (final e in _items) {
      if (e.clientId == clientId) return e;
    }
    return null;
  }

  /// ApiClient'a bağlar: gönderim `POST /conversations/{id}/messages`, bağlantı gelince tetiklenir.
  void attach(ApiClient api, ConnectivityService connectivity) {
    _connectivity?.reconnects.removeListener(_onReconnect);
    _connectivity = connectivity;
    connectivity.reconnects.addListener(_onReconnect);
    _sender ??= (i) => api.post('/conversations/${i.conversationId}/messages', {
          'text': i.text,
          'clientId': i.clientId,
          if (i.replyToMessageId != null) 'replyToMessageId': i.replyToMessageId,
        });
  }

  void _onReconnect() {
    for (final e in _items) {
      if (e.status == OutboxStatus.pending) e.nextAttemptAt = 0;
    }
    unawaited(drain());
  }

  /// Diskten yükler (açılışta bir kez); eski öğeleri atar.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await _store.read();
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw);
        if (j is List) {
          for (final e in j) {
            final it = OutboxItem.fromJson(e);
            if (it != null && !contains(it.clientId)) _items.add(it);
          }
        }
      }
    } catch (_) {
      _items.clear();
    }
    _items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _prune();
    await _save();
    notifyListeners();
    unawaited(drain());
  }

  void _prune() {
    final cutoff = _now().millisecondsSinceEpoch - maxAge.inMilliseconds;
    _items.removeWhere((e) => e.createdAt < cutoff);
    while (_items.length > maxItems) {
      // Önce kalıcı hatalı en eskiyi, yoksa en eski bekleyeni at.
      final i = _items.indexWhere((e) => e.status == OutboxStatus.failed);
      _items.removeAt(i >= 0 ? i : 0);
    }
  }

  Future<void> _save() async {
    try {
      await _store.write(_items.isEmpty ? null : jsonEncode([for (final e in _items) e.toJson()]));
    } catch (_) {}
  }

  /// ApiClient'ın ağ hatasında çağırdığı kanca: yalnız metin mesajı POST'u kuyruğa alınır.
  /// Öğe alındıysa true.
  bool captureRequest(String path, Object? body) {
    final m = _messagesPath.firstMatch(path);
    if (m == null || body is! Map) return false;
    final text = body['text'], cid = body['clientId'];
    if (text is! String || text.trim().isEmpty || cid is! String || cid.isEmpty || cid.length > 64) return false;
    final att = body['attachmentIds'];
    if ((att is List && att.isNotEmpty) || body['viewOnce'] == true) return false; // medya: kuyruğa alınmaz
    final reply = body['replyToMessageId'];
    return enqueue(
      conversationId: int.parse(m.group(1)!),
      clientId: cid,
      text: text,
      replyToMessageId: reply is int ? reply : null,
    );
  }

  bool enqueue({required int conversationId, required String clientId, required String text, int? replyToMessageId}) {
    if (text.length > maxTextLength || contains(clientId)) return false;
    _items.add(OutboxItem(
      clientId: clientId,
      conversationId: conversationId,
      text: text,
      createdAt: _now().millisecondsSinceEpoch,
      replyToMessageId: replyToMessageId,
      nextAttemptAt: _now().millisecondsSinceEpoch + backoff(1).inMilliseconds,
    ));
    _prune();
    unawaited(_save());
    notifyListeners();
    _scheduleNext();
    return true;
  }

  /// Kalıcı hatalı öğeyi yeniden denemeye alır.
  Future<void> retry(String clientId) async {
    final it = byClientId(clientId);
    if (it == null) return;
    it.status = OutboxStatus.pending;
    it.serverFails = 0;
    it.errorCode = null;
    it.nextAttemptAt = 0;
    await _save();
    notifyListeners();
    await drain();
  }

  Future<void> remove(String clientId) async {
    _items.removeWhere((e) => e.clientId == clientId);
    await _save();
    notifyListeners();
  }

  /// Oturum kapanışı/hesap silme: bütün bekleyen mesajlar silinir.
  Future<void> clear() async {
    _timer?.cancel();
    _items.clear();
    await _save();
    notifyListeners();
  }

  /// Bekleyenleri sırayla göndermeyi dener (eşzamanlı çağrılar tek çalışmaya birleşir).
  Future<void> drain() async {
    final send = _sender;
    if (send == null || _draining) return;
    _draining = true;
    try {
      final blocked = <int>{}; // sırası bozulmasın: sorunlu konuşmanın sonraki mesajları beklesin
      for (final it in List.of(_items)) {
        if (it.status != OutboxStatus.pending || blocked.contains(it.conversationId)) continue;
        if (it.nextAttemptAt > _now().millisecondsSinceEpoch) {
          blocked.add(it.conversationId);
          continue;
        }
        try {
          final res = await send(it);
          _items.removeWhere((e) => e.clientId == it.clientId);
          _deliveries.add(OutboxDelivery(it, res));
          await _save();
          notifyListeners();
        } on ApiError catch (e) {
          if (!_items.any((x) => x.clientId == it.clientId)) continue; // iptal/oturum kapandı
          final stop = _onError(it, e);
          await _save();
          notifyListeners();
          if (stop) break; // ağ yok: geri kalanı denemenin anlamı yok
          blocked.add(it.conversationId);
        } catch (_) {
          it.attempts++;
          it.nextAttemptAt = _now().millisecondsSinceEpoch + backoff(it.attempts).inMilliseconds;
          blocked.add(it.conversationId);
        }
      }
    } finally {
      _draining = false;
      _scheduleNext();
    }
  }

  /// true: ağ sorunu (drain'i durdur).
  bool _onError(OutboxItem it, ApiError e) {
    final now = _now().millisecondsSinceEpoch;
    it.attempts++;
    if (e.isNetwork) {
      it.nextAttemptAt = now + backoff(it.attempts).inMilliseconds;
      return true;
    }
    // Engel bilgisi sızdırılmaz (sohbet ekranındaki davranışla aynı): sessizce kuyruktan çıkar.
    if (e.code == 'BLOCKED' || e.code == 'USER_BLOCKED') {
      _items.removeWhere((x) => x.clientId == it.clientId);
      return false;
    }
    if (e.status == 429 || e.status == 408 || e.status == 401) {
      final wait = e.retryAfter != null ? Duration(seconds: e.retryAfter!) : backoff(it.attempts);
      it.nextAttemptAt = now + wait.inMilliseconds;
      return e.status == 401; // 401: oturum yenilenemedi; oturum kapanışı kuyruğu zaten temizler
    }
    if (e.status >= 500) {
      it.serverFails++;
      if (it.serverFails >= maxServerFails) {
        it.status = OutboxStatus.failed;
        it.errorCode = e.code;
      } else {
        it.nextAttemptAt = now + backoff(it.attempts).inMilliseconds;
      }
      return false;
    }
    // Diğer 4xx: kalıcı hata (içerik/izin); kullanıcı elle yeniden dener ya da siler.
    it.status = OutboxStatus.failed;
    it.errorCode = e.code;
    return false;
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (!autoSchedule || _sender == null) return;
    int? next;
    for (final e in _items) {
      if (e.status != OutboxStatus.pending) continue;
      if (next == null || e.nextAttemptAt < next) next = e.nextAttemptAt;
    }
    if (next == null) return;
    final ms = next - _now().millisecondsSinceEpoch;
    _timer = Timer(Duration(milliseconds: ms < 1000 ? 1000 : ms), () => unawaited(drain()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivity?.reconnects.removeListener(_onReconnect);
    _deliveries.close();
    super.dispose();
  }
}
