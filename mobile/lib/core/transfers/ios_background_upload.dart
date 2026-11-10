import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../api.dart' show ApiError;

/// iOS arka plan yükleme köprüsü (kanal `bu_kampus/transfers`, yalnız iOS). Yerel taraf: `BuBackgroundUploads.swift`
/// (kalıcı `URLSession` + dosya tabanlı çok parçalı POST). Dart kuyruğu (TransferQueue) TEK ilerleme kaynağı kalır;
/// burada yalnız "dosyayı sunucuya gönder, sonucu ver" vardır.
///
/// Sözleşme (Dart -> yerel): `bgUpload`, `bgTake`, `bgPending`, `bgCancel`, `bgCancelAll`.
/// Yerel -> Dart: `bgProgress {taskKey, sent, total}`, `bgDone {taskKey, status, body, error}`.
///
/// Kurallar: arka planda token yenilenmez; başlıklar Dart'tan gelir. 401 -> [ApiError] 401 (iş "Hata/giriş gerekli"
/// olur, kullanıcı yeniden dener). DÜRÜST SINIR: kullanıcı uygulamayı zorla kapatırsa iOS oturumu sonlandırır;
/// sonraki açılışta kuyruk aynı `Idempotency-Key` ile yeniden dener.
class IosBackgroundUploader {
  IosBackgroundUploader({MethodChannel? channel}) : _ch = channel ?? const MethodChannel('bu_kampus/transfers') {
    _ch.setMethodCallHandler(_onCall);
  }

  final MethodChannel _ch;
  final Map<String, Completer<Map<String, dynamic>>> _waiting = {};
  final Map<String, void Function(int sent, int total)> _progress = {};

  static bool get supported => !kIsWeb && Platform.isIOS;

  /// Tek örnek (kanal işleyicisi tektir). iOS dışında null.
  static IosBackgroundUploader? get shared => supported ? (_shared ??= IosBackgroundUploader()) : null;
  static IosBackgroundUploader? _shared;

  Future<dynamic> _onCall(MethodCall c) async {
    final a = c.arguments;
    if (a is! Map) return null;
    final key = a['taskKey'];
    if (key is! String) return null;
    if (c.method == 'bgProgress') {
      final cb = _progress[key];
      final sent = (a['sent'] as num?)?.toInt(), total = (a['total'] as num?)?.toInt();
      if (cb != null && sent != null && total != null && total > 0) cb(sent, total);
    } else if (c.method == 'bgDone') {
      final w = _waiting[key];
      if (w != null && !w.isCompleted) w.complete(Map<String, dynamic>.from(a));
    }
    return null;
  }

  /// Dosyayı çok parçalı POST ile gönderir; [taskKey] (iş kimliği) aynıysa süren/biten görev yeniden bağlanır.
  /// Dönüş: çözülmüş JSON gövdesi. Hata: [ApiError] (status 0 = ağ).
  Future<dynamic> upload({
    required String taskKey,
    required String url,
    required String filePath,
    required String fileName,
    required String mime,
    Map<String, String> headers = const {},
    String fileField = 'file',
    void Function(int sent, int total)? onProgress,
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    _waiting[taskKey] = completer;
    if (onProgress != null) _progress[taskKey] = onProgress;
    try {
      // Önce: uygulama kapalıyken bitmiş sonuç var mı (yeniden bağlanma)?
      var done = await _take(taskKey);
      if (done == null) {
        final pending = await _pending();
        if (!pending.contains(taskKey)) {
          await _ch.invokeMethod<void>('bgUpload', {
            'taskKey': taskKey,
            'url': url,
            'method': 'POST',
            'headers': headers,
            'fileField': fileField,
            'fileName': fileName,
            'mime': mime,
            'filePath': filePath,
          });
        }
        // bgDone olayı kaçarsa 20 sn'de bir sonucu yokla.
        done = await _await(taskKey, completer);
      }
      return _result(done);
    } on PlatformException catch (e) {
      throw ApiError(0, 'NETWORK', e.message ?? '');
    } finally {
      _waiting.remove(taskKey);
      _progress.remove(taskKey);
    }
  }

  Future<Map<String, dynamic>> _await(String key, Completer<Map<String, dynamic>> c) async {
    while (true) {
      try {
        return await c.future.timeout(const Duration(seconds: 20));
      } on TimeoutException {
        final r = await _take(key);
        if (r != null) return r;
      }
    }
  }

  Future<Map<String, dynamic>?> _take(String key) async {
    final r = await _ch.invokeMethod<dynamic>('bgTake', {'taskKey': key});
    return r is Map ? Map<String, dynamic>.from(r) : null;
  }

  Future<Set<String>> _pending() async {
    final r = await _ch.invokeMethod<dynamic>('bgPending');
    return r is List ? r.whereType<String>().toSet() : <String>{};
  }

  dynamic _result(Map<String, dynamic> r) {
    final status = (r['status'] as num?)?.toInt() ?? 0;
    final body = r['body'] is String ? r['body'] as String : '';
    dynamic json;
    if (body.isNotEmpty) {
      try {
        json = jsonDecode(body);
      } catch (_) {
        // Bilerek yutulur: gövde JSON değilse durum koduna göre karar verilir.
      }
    }
    if (status >= 200 && status < 300) return json;
    if (status == 0) throw ApiError(0, 'NETWORK', r['error'] is String ? r['error'] as String : '');
    if (json is Map && json['code'] is String) {
      throw ApiError(status, json['code'] as String, json['message'] is String ? json['message'] as String : '');
    }
    throw ApiError(status, status == 401 ? 'UNAUTHORIZED' : 'HTTP_$status', '');
  }

  Future<void> cancel(String taskKey) async {
    try {
      await _ch.invokeMethod<void>('bgCancel', {'taskKey': taskKey});
    } catch (_) {
      // En iyi çaba.
    }
  }

  /// Hesap çıkışı: tüm görevleri iptal eder, geçici dosyaları siler.
  Future<void> cancelAll() async {
    try {
      await _ch.invokeMethod<void>('bgCancelAll');
    } catch (_) {
      // En iyi çaba.
    }
  }
}
