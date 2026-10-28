import 'package:flutter/foundation.dart';

/// Yönetici tarafından KAPATILMIŞ sohbetler (P08). Sunucu `ConversationView`'da "kapalı" alanı vermez;
/// kapalılık şu kaynaklardan öğrenilir: (1) gönderimde `409 CONVERSATION_CLOSED`, (2) SYSTEM bildirimi
/// `data.event = CONVERSATION_CLOSED | CONVERSATION_REOPENED`, (3) çevrimdışı kuyruğun kalıcı hatası.
/// Yalnız bellekte tutulur; bayat kalmasın diye kayıt [ttl] sonra düşer, kapalı sohbette canlı yeni mesaj
/// gelirse ya da yeniden açma bildirimi gelirse hemen silinir. Sebep (`closed_reason`) istemciye ASLA gelmez.
class ClosedConversations extends ChangeNotifier {
  ClosedConversations._() : _now = DateTime.now;
  static final ClosedConversations instance = ClosedConversations._();

  /// Testlerde yeni örnek kullanılabilsin.
  @visibleForTesting
  ClosedConversations.test({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Bildirimi kaçıran istemci sonsuza dek kilitli kalmasın.
  static const ttl = Duration(hours: 12);

  final Map<int, DateTime> _closedAt = {};

  bool isClosed(int conversationId) {
    final at = _closedAt[conversationId];
    if (at == null) return false;
    if (_now().difference(at) > ttl) {
      _closedAt.remove(conversationId);
      return false;
    }
    return true;
  }

  void markClosed(int conversationId) {
    final had = _closedAt.containsKey(conversationId);
    _closedAt[conversationId] = _now();
    if (!had) notifyListeners();
  }

  void markOpen(int conversationId) {
    if (_closedAt.remove(conversationId) != null) notifyListeners();
  }

  /// Bildirim `data` yükünü uygular (push dokunuşu, ön plan, bildirim listesi). Durum değiştiyse true.
  bool applyPushData(Map<String, dynamic>? data) {
    final ev = pushEvent(data);
    if (ev == null) return false;
    final id = _conversationId(data);
    if (id == null) return false;
    switch (ev) {
      case ConversationPushEvent.closed:
        final changed = !isClosed(id);
        markClosed(id);
        return changed;
      case ConversationPushEvent.reopened:
        final changed = isClosed(id);
        markOpen(id);
        return changed;
      case ConversationPushEvent.removed:
        final changed = _closedAt.remove(id) != null;
        if (changed) notifyListeners();
        return changed;
    }
  }

  /// SYSTEM bildiriminin `data.event` değeri; tanınmıyorsa null.
  static ConversationPushEvent? pushEvent(Map<String, dynamic>? data) {
    switch ('${data?['event'] ?? ''}'.toUpperCase()) {
      case 'CONVERSATION_CLOSED':
        return ConversationPushEvent.closed;
      case 'CONVERSATION_REOPENED':
        return ConversationPushEvent.reopened;
      case 'CONVERSATION_REMOVED':
        return ConversationPushEvent.removed;
    }
    return null;
  }

  static int? _conversationId(Map<String, dynamic>? d) {
    if (d == null) return null;
    final raw = d['conversationId'] ?? ('${d['targetType']}'.toUpperCase() == 'CONVERSATION' ? d['targetId'] : null);
    final n = raw == null ? null : int.tryParse('$raw');
    return n != null && n > 0 ? n : null;
  }
}

enum ConversationPushEvent { closed, reopened, removed }
