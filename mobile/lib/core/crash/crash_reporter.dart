import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../api.dart';
import '../app_gate.dart' show appVersion;
import '../device_identity.dart';
import '../error_log.dart';

/// Yakalanan hata/çökmeleri KENDİ sunucumuza (`POST /api/app/crash-reports`) anonim gönderir; Firebase
/// Crashlytics/Sentry gibi üçüncü tarafa veri gitmez. Gönderilen: uygulama sürümü, platform, işletim sistemi
/// sürümü, hata türü, MASKELENMİŞ yığın izi, ekran adı, zaman. Gönderilmeyen: e-posta, jeton, mesaj içeriği,
/// hata iletisi, kullanıcı kimliği. Çevrimdışıysa yerelde (en çok [maxQueue] kayıt, dosya) biriktirir; bağlantı
/// gelince gönderir. Aynı hata (imza) oturum başına yalnız bir kez gönderilir. Ayarlardan kapatılabilir
/// (kapalıyken hiçbir şey kaydedilmez/gönderilmez). Hiçbir yöntem fırlatmaz.
class CrashReporter extends ChangeNotifier {
  CrashReporter({bool? active, FlutterSecureStorage? storage, DateTime Function()? now, String? osVersion})
      : active = active ?? kReleaseMode,
        _storage = storage ?? const FlutterSecureStorage(),
        _now = now ?? DateTime.now,
        _osVersion = osVersion;

  static final CrashReporter instance = CrashReporter();

  /// Yerelde biriktirilen en çok rapor.
  static const maxQueue = 20;

  static const settingKey = 'crash_reports_enabled';
  static const endpoint = '/app/crash-reports';

  /// false: hata kaydedilmez/gönderilmez (debug/test derlemesi; testler true verir).
  final bool active;

  final FlutterSecureStorage _storage;
  final DateTime Function() _now;
  final String? _osVersion;

  bool _enabled = true;
  Future<void>? _flushing;
  File? _file;
  ApiClient? _api;
  final List<Map<String, Object?>> _queue = [];
  final Set<String> _seen = {};

  /// Kullanıcı ayarı (varsayılan açık).
  bool get enabled => _enabled;

  /// Bekleyen (gönderilmemiş) rapor sayısı.
  int get pending => _queue.length;

  @visibleForTesting
  List<Map<String, Object?>> get queue => List.unmodifiable(_queue);

  static final _typeBad = RegExp(r'[^A-Za-z0-9_<>?., ]');
  static final _longDigits = RegExp(r'\d{10,}');
  static final _screenOk = RegExp(r'^[A-Za-z0-9_./-]{1,60}$');
  static final _email = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');
  static final _urlQuery = RegExp(r'(https?://[^\s?#"<>)]*)[?#][^\s"<>)]*', caseSensitive: false);
  static final _jwt = RegExp(r'eyJ[A-Za-z0-9_\-]{5,}\.[A-Za-z0-9_\-]{5,}\.[A-Za-z0-9_\-]*');
  static final _bearer = RegExp(r'bearer\s+[A-Za-z0-9._~+/=\-]+', caseSensitive: false);
  static final _homeDir = RegExp(r'(/Users/|/home/|[A-Za-z]:\\Users\\)[^/\\\s)]+', caseSensitive: false);
  static final _androidUser = RegExp(r'/data/(?:user|data)/\d+/');
  static final _uuid = RegExp(r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b', caseSensitive: false);
  static final _longToken = RegExp(r'(?<![A-Za-z0-9_\-])(?=[A-Za-z0-9_\-]*\d)(?=[A-Za-z0-9_\-]*[A-Za-z])[A-Za-z0-9_\-]{32,}');
  static final _digits7 = RegExp(r'(?<![\w.:])\d{7,}(?![\w.])');
  static final _frameIndex = RegExp(r'^\s*#\d+\s+');
  static final _lineCol = RegExp(r':\d+(?::\d+)?(?=\)|\s|$)');
  static final _hex = RegExp(r'\b(?:0x)?[0-9a-fA-F]{8,}\b');

  /// Yığın izi sınırları (sunucu gövde sınırı 16 KB).
  static const maxStackLines = 40;
  static const maxLineChars = 240;
  static const maxStackChars = 6000;

  /// Ayarı ve diskteki kuyruğu yükler. Hata fırlatmaz.
  Future<void> init({Directory? dir}) async {
    try {
      _enabled = (await _storage.read(key: settingKey)) != '0';
    } catch (_) {
      _enabled = true;
    }
    try {
      final d = dir ?? await getApplicationSupportDirectory();
      _file = File('${d.path}${Platform.pathSeparator}crash_queue.json');
      if (!_enabled) {
        await _deleteFile();
      } else if (await _file!.exists()) {
        final raw = jsonDecode(await _file!.readAsString());
        if (raw is List) {
          for (final e in raw) {
            if (e is Map && _queue.length < maxQueue) _queue.add(Map<String, Object?>.from(e));
          }
        }
      }
    } catch (_) {
      _file = null;
    }
    notifyListeners();
  }

  /// Gönderimde kullanılacak API katmanı; yeniden bağlanınca bekleyenler gönderilir.
  void attach(ApiClient api) {
    _api?.connectivity.reconnects.removeListener(_onReconnect);
    _api = api;
    api.connectivity.reconnects.addListener(_onReconnect);
  }

  void _onReconnect() => unawaited(flush());

  /// Ayarlar anahtarı. Kapatınca bekleyen raporlar da silinir.
  Future<void> setEnabled(bool v) async {
    _enabled = v;
    if (!v) {
      _queue.clear();
      _seen.clear();
      await _deleteFile();
    }
    notifyListeners();
    try {
      await _storage.write(key: settingKey, value: v ? '1' : '0');
    } catch (_) {}
  }

  /// Hatayı yakalar; kuyruğa alır ve göndermeyi dener. Dönen değer: kuyruğa alındı mı.
  bool capture(Object error, StackTrace? stack, {String source = 'flutter', bool fatal = false}) {
    if (!active || !_enabled) return false;
    try {
      final type = sanitizeType(error);
      final stackText = scrubStack(stack?.toString() ?? '');
      final sig = signature(type, stackText);
      if (!_seen.add(sig)) return false; // aynı hata bu oturumda zaten kaydedildi
      if (_seen.length > 200) _seen.remove(_seen.first);
      final cs = ErrorLog.instance.currentScreen;
      final screen = cs != null && _screenOk.hasMatch(cs) ? cs : null;
      _queue.add({
        'appVersion': appVersion,
        'platform': DeviceIdentity.platform.toUpperCase(),
        if (_osVersion != null || _defaultOs() != null) 'osVersion': _osVersion ?? _defaultOs(),
        'errorType': type,
        'stackTrace': stackText.isEmpty ? '(yığın yok)' : stackText,
        if (screen != null) 'screen': screen,
        'fatal': fatal || source != 'flutter',
        'occurredAt': _now().toUtc().toIso8601String(),
      });
      while (_queue.length > maxQueue) {
        _queue.removeAt(0);
      }
      unawaited(_persist());
      unawaited(flush());
      return true;
    } catch (_) {
      return false;
    }
  }

  String? _defaultOs() {
    try {
      final v = scrubText(Platform.operatingSystemVersion);
      return v.length > 64 ? v.substring(0, 64) : v;
    } catch (_) {
      return null;
    }
  }

  /// Bekleyenleri sırayla gönderir. Geçici hata (ağ yok, 408/429/5xx) kuyruğu korur ve durur; kalıcı 4xx raporu atar.
  Future<void> flush() => _flushing ??= _doFlush().whenComplete(() => _flushing = null);

  Future<void> _doFlush() async {
    final api = _api;
    if (api == null || _queue.isEmpty || !_enabled || !api.connectivity.online) return;
    try {
      while (_queue.isNotEmpty && _enabled) {
        final item = _queue.first;
        try {
          await api.post(endpoint, item, false); // anonim: Authorization gönderilmez
        } on ApiError catch (e) {
          if (e.isTransient) break;
          // kalıcı ret (400/403/413...): bu rapor bir daha denenmez
        } catch (_) {
          break;
        }
        _queue.remove(item);
        await _persist();
      }
    } catch (_) {
      // gönderim hatası uygulamayı etkilemez
    }
  }

  Future<void> _persist() async {
    final f = _file;
    if (f == null) return;
    try {
      if (_queue.isEmpty) {
        await _deleteFile();
      } else {
        await f.writeAsString(jsonEncode(_queue), flush: true);
      }
    } catch (_) {}
  }

  Future<void> _deleteFile() async {
    try {
      final f = _file;
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ---- saf yardımcılar (testli) ----

  /// Hata türü adı: yalnız güvenli karakterler, en çok 80 karakter.
  @visibleForTesting
  static String sanitizeType(Object error) {
    var t = error.runtimeType.toString().replaceAll(_typeBad, '').replaceAll(_longDigits, '');
    if (t.length > 80) t = t.substring(0, 80);
    return t.isEmpty ? 'Unknown' : t;
  }

  /// Serbest metni maskeler: e-posta, jeton, sorgu dizesi, ev dizini, uzun sayı.
  @visibleForTesting
  static String scrubText(String s) {
    var t = s.replaceAll(_email, '[eposta]');
    t = t.replaceAllMapped(_urlQuery, (m) => '${m[1]}?[gizli]');
    t = t.replaceAll(_uuid, '[uuid]').replaceAll(_jwt, '[jwt]').replaceAll(_bearer, 'Bearer [gizli]');
    t = t.replaceAllMapped(_homeDir, (m) => '${m[1]}[kullanici]').replaceAll(_androidUser, '/data/user/_/');
    t = t.replaceAll(_longToken, '[gizli]').replaceAll(_digits7, '[sayi]');
    return t;
  }

  /// Yığın izi: maskeli, satır/karakter sınırlı. Dosya yolları ve kare adları KALIR.
  @visibleForTesting
  static String scrubStack(String raw) {
    final out = <String>[];
    for (final line in raw.replaceAll('\r', '').split('\n')) {
      if (out.length >= maxStackLines) break;
      var s = scrubText(line).trimRight();
      if (s.trim().isEmpty) continue;
      if (s.length > maxLineChars) s = s.substring(0, maxLineChars);
      out.add(s);
    }
    final joined = out.join('\n');
    return joined.length > maxStackChars ? joined.substring(0, maxStackChars) : joined;
  }

  /// Aynı hatayı ayırt eden imza: tür + ilk 6 normalize kare (satır/sütun ve adres olmadan).
  @visibleForTesting
  static String signature(String type, String stack) {
    final b = StringBuffer(type);
    var n = 0;
    for (final line in stack.split('\n')) {
      final f = line.replaceFirst(_frameIndex, '').replaceAll(_hex, '').replaceAll(_lineCol, '').trim();
      if (f.isEmpty || f.startsWith('<asynchronous')) continue;
      b..write('|')..write(f);
      if (++n >= 6) break;
    }
    return b.toString();
  }
}
