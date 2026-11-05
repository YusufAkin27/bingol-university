import 'dart:async';

import '../../core/api.dart';
import '../../core/realtime/chat_realtime.dart';
import 'share_models.dart';

/// Paylaşımın alıcısı: var olan bir sohbet ya da (henüz sohbeti olmayan) bir kişi.
class ShareRecipient {
  const ShareRecipient.conversation({
    required int this.conversationId,
    required this.label,
    this.avatarUrl,
    this.group = false,
  }) : userId = null;

  const ShareRecipient.user({
    required int this.userId,
    required this.label,
    this.avatarUrl,
  })  : conversationId = null,
        group = false;

  final int? conversationId;
  final int? userId;
  final String label;
  final String? avatarUrl;
  final bool group;

  /// Seçim kümesinde benzersiz anahtar.
  String get key => conversationId != null ? 'c$conversationId' : 'u$userId';

  @override
  bool operator ==(Object other) => other is ShareRecipient && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

enum ShareSendState { sent, queued, failed }

class ShareSendSummary {
  const ShareSendSummary(this.results, {this.firstError});

  final Map<ShareRecipient, ShareSendState> results;

  /// İlk sunucu hatası (ör. 422 `SHARE_TARGET_INVALID`: içerik artık paylaşılamıyor; mesaj istek dilindedir).
  final ApiError? firstError;

  int get sent => results.values.where((s) => s == ShareSendState.sent).length;
  int get queued => results.values.where((s) => s == ShareSendState.queued).length;
  int get failed => results.values.where((s) => s == ShareSendState.failed).length;
  bool get allFailed => results.isNotEmpty && failed == results.length;
}

/// Tek mesajda en çok kaç sohbete gönderilir (İlet ile aynı sınır mantığı; toplu istek yağmuru olmasın).
const int kShareMaxRecipients = 10;

/// Not (isteğe bağlı kısa metin) üst sınırı: kod noktası.
const int kShareNoteMax = 200;

/// İçeriği seçilen sohbetlere kart olarak gönderir: `POST /conversations/{id}/messages` gövdesine
/// `share:{type,id}` eklenir (+ varsa kısa not `text`). Her alıcı için ayrı `clientId` üretilir (aynı istek tekrarında çift
/// mesaj olmaz); ağ yoksa [ApiClient] isteği çevrimdışı kuyruğa alır ([Outbox.captureRequest]) ve `queued` döner.
/// Hiçbir koşulda exception sızdırmaz.
Future<ShareSendSummary> sendShare(
  ApiClient api, {
  required List<ShareRecipient> to,
  required ShareTarget target,
  String note = '',
}) async {
  final text = note.trim();
  final recipients = to.take(kShareMaxRecipients).toList();
  final results = <ShareRecipient, ShareSendState>{};
  ApiError? firstError;
  await Future.wait(recipients.map((r) async {
    results[r] = await _sendOne(api, r, target, text, (e) => firstError ??= e);
  }));
  return ShareSendSummary(results, firstError: firstError);
}

Future<ShareSendState> _sendOne(
    ApiClient api, ShareRecipient r, ShareTarget target, String text, void Function(ApiError) onError) async {
  var cid = r.conversationId;
  try {
    if (cid == null) {
      // Kişiyle henüz sohbet yok: birebir sohbet açılır (varsa mevcut olan döner).
      final res = await api.post('/conversations', {'userId': r.userId});
      final conv = res is Map ? (res['conversation'] is Map ? res['conversation'] as Map : res) : null;
      final id = conv?['id'];
      if (id is! num) return ShareSendState.failed;
      cid = id.toInt();
    }
  } catch (_) {
    return ShareSendState.failed;
  }
  final clientId = ChatRealtime.newClientId();
  try {
    await api.post('/conversations/$cid/messages', {
      'text': text,
      'clientId': clientId,
      'share': {'type': target.type.apiName, 'id': target.id},
    });
    return ShareSendState.sent;
  } on ApiError catch (e) {
    // Ağ yok: ApiClient isteği kuyruğa aldıysa gönderim bağlantı gelince kendiliğinden yapılır.
    if (e.isNetwork && (api.outbox?.contains(clientId) ?? false)) return ShareSendState.queued;
    onError(e);
    return ShareSendState.failed;
  } catch (_) {
    return ShareSendState.failed;
  }
}
