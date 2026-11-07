import 'dart:async';
import 'dart:io' show Platform;
import '../swallow.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../api.dart';

/// Kullanıcının kendi başlattığı canlı süreçler: iOS Canlı Etkinlik (ActivityKit) ve Android 16 Canlı Güncellemeler.
///
/// KAPSAM (kesin): yalnız [LiveKind.event] (katıldığı etkinliğin geri sayımı) ve [LiveKind.exam] (kendi sınavı).
/// Sohbet, arkadaşlık, duyuru vb. bildirimler ASLA canlı etkinlik olmaz. Hesap yalnız kullanıcı düğmeye basınca başlar.
///
/// Platform sınırları (dürüst):
///  - iOS 16.2+ ve kullanıcı "Canlı Etkinlikler"i kapatmamışsa çalışır; güncelleme jetonu sunucuya kaydedilir
///    (`PUT /live-activities/{id}`), sunucu APNs `.p8` anahtarı girilince etkinlik iptalinde etkinliği bitirebilir.
///    Anahtar yoksa geri sayım yine cihazda yerel olarak doğru akar (sistem zamanlayıcısı).
///  - Android: 16+ ProgressStyle + promoted ongoing (sistem uygun görürse), daha eskide standart ilerleme bildirimi.
///    Arka plan servisi yoktur; geri sayımı sistem kronometresi sürer.
enum LiveKind { event, exam }

extension LiveKindWire on LiveKind {
  String get wire => this == LiveKind.event ? 'EVENT' : 'EXAM';
}

/// Geri sayımın evresi: başlamadan önce başlangıca, sürerken bitişe sayılır.
enum LivePhase { upcoming, live }

/// Saf hesap (testli): hangi evrede olduğumuz ve geri sayımın hedefi.
class LiveSpec {
  const LiveSpec({required this.kind, required this.refId, required this.title, required this.startsAt, required this.endsAt, this.detail = ''});

  final LiveKind kind;
  final int refId;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String detail;

  /// Bitmiş ya da süresi geçersiz bir süreç için null (canlı etkinlik başlatılmaz).
  LivePhase? phaseAt(DateTime now) {
    if (!endsAt.isAfter(startsAt) || !endsAt.isAfter(now)) return null;
    return now.isBefore(startsAt) ? LivePhase.upcoming : LivePhase.live;
  }

  DateTime targetAt(DateTime now) => phaseAt(now) == LivePhase.upcoming ? startsAt : endsAt;

  /// Android kısa kritik metni (en çok 7 karakter): "2sa 5dk" yerine yalnız sayı+birim.
  String shortCritical(DateTime now) {
    final d = targetAt(now).difference(now);
    if (d.inHours >= 1) return '${d.inHours}h';
    return '${d.inMinutes.clamp(0, 999)}m';
  }
}

class LiveLabels {
  const LiveLabels({required this.startsIn, required this.endsIn, required this.channelName});
  final String startsIn, endsIn, channelName;
}

enum LiveStartResult { started, disabledByUser, unsupported, rejected, failed }

class LiveActivityService {
  LiveActivityService._(this._api);

  static LiveActivityService? _instance;

  /// ApiClient ilk bağlandığında kurulur (oturum başına tek örnek yeter; API istemcisi aynıdır).
  static LiveActivityService of(ApiClient api) => _instance ??= LiveActivityService._(api).._listen();

  /// Sızıntısız test için.
  @visibleForTesting
  static void resetForTest() => _instance = null;

  final ApiClient _api;
  static const _ios = MethodChannel('bu_kampus/live_activity');
  static const _android = MethodChannel('bu_kampus/live_updates');

  /// Test düzeneği: platform ve kanal çağrısı değiştirilebilir.
  @visibleForTesting
  static bool? debugIsIos;
  @visibleForTesting
  static bool? debugIsAndroid;
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  static bool get _isIos => debugIsIos ?? (!kIsWeb && Platform.isIOS);
  static bool get _isAndroid => debugIsAndroid ?? (!kIsWeb && Platform.isAndroid);

  void _listen() {
    if (!_isIos) return;
    _ios.setMethodCallHandler((call) async {
      final args = call.arguments;
      if (args is! Map) return null;
      final id = '${args['activityId'] ?? ''}';
      if (id.isEmpty) return null;
      final info = _active[id];
      if (call.method == 'onToken' && info != null) {
        await _register(id, info, token: '${args['token']}');
      } else if (call.method == 'onEnded') {
        _active.remove(id);
        try {
          await _api.delete('/live-activities/$id');
        } catch (e) {
          swallow('live_activity_service.1', e);
        }
      }
      return null;
    });
  }

  final _active = <String, LiveSpec>{};

  /// Bu cihazda canlı takip desteği var mı (düğme yalnız true iken gösterilir).
  Future<bool> supported() async {
    try {
      if (_isIos) return await _ios.invokeMethod<bool>('isSupported') ?? false;
      if (_isAndroid) return await _android.invokeMethod<bool>('isSupported') ?? false;
    } catch (e) {
      swallow('live_activity_service.2', e);
    }
    return false;
  }

  /// Sunucu Canlı Etkinlik push'u yapılandırılmış mı (arayüz durumu dürüst göstersin); hata = false.
  Future<bool> serverPushConfigured() async {
    try {
      final r = await _api.get('/live-activities/status');
      return r is Map && r['apnsConfigured'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isActive(LiveKind kind, int refId) async {
    try {
      if (_isIos) {
        final r = await _ios.invokeMethod<List<dynamic>>('list') ?? const [];
        return r.any((e) => e is Map && e['kind'] == kind.wire && '${e['refId']}' == '$refId');
      }
      if (_isAndroid) {
        return await _android.invokeMethod<bool>('isActive', {'kind': kind.wire, 'refId': refId}) ?? false;
      }
    } catch (e) {
      swallow('live_activity_service.3', e);
    }
    return false;
  }

  Future<LiveStartResult> start(LiveSpec spec, LiveLabels labels) async {
    final now = clock();
    final phase = spec.phaseAt(now);
    if (phase == null) return LiveStartResult.rejected;
    final label = phase == LivePhase.upcoming ? labels.startsIn : labels.endsIn;
    final target = spec.targetAt(now).millisecondsSinceEpoch;
    try {
      if (_isIos) return await _startIos(spec, phase, label, target);
      if (_isAndroid) return await _startAndroid(spec, label, target, labels, now);
    } on PlatformException catch (e) {
      return e.code == 'disabled' ? LiveStartResult.disabledByUser : LiveStartResult.failed;
    } on MissingPluginException {
      return LiveStartResult.unsupported;
    } catch (_) {
      return LiveStartResult.failed;
    }
    return LiveStartResult.unsupported;
  }

  Future<LiveStartResult> _startIos(LiveSpec spec, LivePhase phase, String label, int target) async {
    final r = await _ios.invokeMethod<Map<dynamic, dynamic>>('start', {
      'kind': spec.kind.wire,
      'refId': spec.refId,
      'title': spec.title,
      'phase': phase == LivePhase.upcoming ? 'upcoming' : 'live',
      'targetMs': target,
      'label': label,
      'detail': spec.detail,
      // Sistem, süre dolunca içeriği "eski" işaretler; uç zamanın biraz ötesi.
      'staleMs': spec.endsAt.millisecondsSinceEpoch + 60000,
    });
    final id = r == null ? null : r['activityId'] as String?;
    if (id == null || id.isEmpty) return LiveStartResult.failed;
    _active[id] = spec;
    // Sunucu "kendi sürecin mi" doğrular; olmazsa cihazdaki etkinlik geri alınır (sahte kayıt kalmaz).
    try {
      await _register(id, spec);
    } on ApiError catch (e) {
      await _ios.invokeMethod<bool>('end', {'activityId': id});
      _active.remove(id);
      return e.isTransient ? LiveStartResult.failed : LiveStartResult.rejected;
    }
    return LiveStartResult.started;
  }

  Future<void> _register(String id, LiveSpec spec, {String? token}) async {
    await _api.put('/live-activities/$id', {
      'kind': spec.kind.wire,
      'refId': spec.refId,
      if (token != null && token.isNotEmpty) 'pushToken': token,
    });
  }

  Future<LiveStartResult> _startAndroid(LiveSpec spec, String label, int target, LiveLabels labels, DateTime now) async {
    final ok = await _android.invokeMethod<bool>('start', {
          'kind': spec.kind.wire,
          'refId': spec.refId,
          'title': spec.title,
          'text': spec.detail.isEmpty ? label : '$label - ${spec.detail}',
          'shortText': spec.shortCritical(now),
          'channelName': labels.channelName,
          'startMs': spec.startsAt.millisecondsSinceEpoch,
          'endMs': spec.endsAt.millisecondsSinceEpoch,
          'targetMs': target,
        }) ??
        false;
    return ok ? LiveStartResult.started : LiveStartResult.failed;
  }

  Future<void> stop(LiveKind kind, int refId) async {
    try {
      if (_isIos) {
        final ids = [
          for (final e in _active.entries)
            if (e.value.kind == kind && e.value.refId == refId) e.key
        ];
        final native = await _ios.invokeMethod<List<dynamic>>('list') ?? const [];
        for (final e in native) {
          if (e is Map && e['kind'] == kind.wire && '${e['refId']}' == '$refId') ids.add('${e['activityId']}');
        }
        for (final id in ids.toSet()) {
          await _ios.invokeMethod<bool>('end', {'activityId': id});
          _active.remove(id);
          try {
            await _api.delete('/live-activities/$id');
          } catch (e) {
            swallow('live_activity_service.4', e);
          }
        }
      } else if (_isAndroid) {
        await _android.invokeMethod<bool>('end', {'kind': kind.wire, 'refId': refId});
      }
    } catch (e) {
      swallow('live_activity_service.5', e);
    }
  }

  /// Çıkış / hesap değişimi: kullanıcının canlı etkinlikleri başka hesaba görünmesin ([registerUserDataCleaners]).
  static Future<void> clearUserData() async {
    try {
      if (_isIos) {
        final native = await _ios.invokeMethod<List<dynamic>>('list') ?? const [];
        for (final e in native) {
          if (e is Map) await _ios.invokeMethod<bool>('end', {'activityId': '${e['activityId']}'});
        }
      } else if (_isAndroid) {
        await _android.invokeMethod<bool>('endAll');
      }
    } catch (e) {
      swallow('live_activity_service.6', e);
    }
    _instance?._active.clear();
  }
}
