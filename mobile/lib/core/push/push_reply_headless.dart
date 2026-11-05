import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../api.dart';
import '../device_identity.dart';
import '../session.dart';
import 'push_actions.dart';

/// Android bildirimindeki satır içi yanıtın, uygulama KAPALIYKEN gönderimi (başlıksız Dart motoru).
///
/// Native `ReplyDispatcher` (Kotlin) yanıtı kalıcı kuyruğa yazar; ağ varken JobScheduler işi bu giriş noktasını
/// (`pushReplyMain`, main.dart'ta kök kütüphane sarmalayıcısı) çalıştıran motoru açar. Kanal `bu_kampus/push_reply_bg`:
/// Dart `ready` der; native her yanıt için `send` çağırır; Dart `ok` | `retry` | `fail` döner.
///  - `ok`: sunucu kabul etti (ya da aynı clientId daha önce işlendi: sunucuda tekil, çift mesaj olmaz).
///  - `retry`: ağ/5xx/429/408/beklenmeyen hata; native üstel geri çekilmeyle yeniden dener.
///  - `fail`: kesin red (oturum yok, 4xx, başka alıcı); native "dokunarak gönder" bildirimine düşer.
/// Jetonlar mevcut [Session] yoluyla (güvenli depo + tek uçuşlu refresh) yönetilir; native jeton okumaz.
const pushReplyChannelName = 'bu_kampus/push_reply_bg';

/// Saf sınıflandırma (testli): [run] true = tamamlandı, false = yetkisiz/uygun değil; istisna = geçici ya da kesin hata.
Future<String> classifyReply(Future<bool> Function() run) async {
  try {
    return await run() ? 'ok' : 'fail';
  } on ApiError catch (e) {
    return e.isTransient ? 'retry' : 'fail';
  } on FormatException {
    return 'fail';
  } catch (_) {
    return 'retry';
  }
}

/// Native `send` bağımsız değişkenlerini [PushActions.perform] yüküne çevirir; geçersizse null.
Map<String, dynamic>? replyPayloadFrom(Object? args) {
  if (args is! Map) return null;
  final clientId = '${args['clientId'] ?? ''}';
  final conversation = int.tryParse('${args['conversationId'] ?? ''}');
  final text = args['text'];
  if (clientId.isEmpty || conversation == null || conversation <= 0 || text is! String || text.trim().isEmpty) return null;
  final replyTo = args['replyToMessageId'];
  final recipient = args['recipientId'];
  return {
    'notificationAction': 'reply',
    'actionId': clientId,
    'conversationId': '$conversation',
    'replyText': text,
    if (replyTo != null && '$replyTo'.isNotEmpty) 'messageId': '$replyTo',
    if (recipient != null && '$recipient'.isNotEmpty) 'recipientId': '$recipient',
  };
}

/// Tek yanıtı işler (oturum hazır olmalı).
Future<String> handleReplySend(Object? args, PushActions actions) async {
  final payload = replyPayloadFrom(args);
  if (payload == null) return 'fail';
  return classifyReply(() => actions.perform(payload));
}

/// Başlıksız motorun gövdesi: kimlik + oturum yüklenir, native hazır olunca `send` çağrıları işlenir.
Future<void> runPushReplyHeadless() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(pushReplyChannelName);
  final ready = Completer<PushActions?>();
  Future<PushActions?> boot() async {
    try {
      await DeviceIdentity.instance.load();
      final api = ApiClient();
      final session = Session(api);
      await session.restore();
      if (session.state != SessionState.signedIn) return null;
      return PushActions(session, open: (data, {compose = false}) async => throw StateError('headless: no UI'));
    } catch (_) {
      return null;
    }
  }

  unawaited(boot().then(ready.complete));
  channel.setMethodCallHandler((call) async {
    if (call.method != 'send') return null;
    final actions = await ready.future;
    if (actions == null) return 'fail';
    final result = await handleReplySend(call.arguments, actions);
    // Yenilenen jetonların güvenli depoya yazımı bitsin (motor hemen kapatılabilir).
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return result;
  });
  try {
    await channel.invokeMethod<void>('ready');
  } catch (_) {
    /* native yoksa (test/öndeki motor) sessizce biter */
  }
}
