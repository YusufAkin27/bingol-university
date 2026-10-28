import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'analytics.dart';
import 'app_gate.dart' show appVersion;

/// Yerel hata günlüğünün tek kaydı. KİŞİSEL VERİ YOK: hata mesajı ve yığın izi tutulmaz;
/// yalnız hata türü, kaynağı, ekran adı ve uygulama sürümü.
class ErrorEntry {
  const ErrorEntry({required this.at, required this.type, required this.source, required this.version, this.screen});

  final DateTime at;
  final String type;

  /// `flutter` (çerçeve hatası) | `platform` (yakalanmayan asenkron hata).
  final String source;
  final String? screen;
  final String version;

  Map<String, Object?> toJson() => {
        'at': at.toUtc().toIso8601String(),
        'type': type,
        'source': source,
        if (screen != null) 'screen': screen,
        'version': version,
      };
}

/// İstemci hata izleme (Crashlytics/Sentry eklenmeden): yerel günlük + isteğe bağlı anonim `app_error`
/// analitik olayı. Üçüncü taraf hizmet yok; olay, mevcut analitik hattıyla yalnız oturum açıkken gider.
class ErrorLog {
  ErrorLog({DateTime Function()? now, this.quiet = false}) : _now = now ?? DateTime.now;

  /// true: konsola yazmaz (testler).
  final bool quiet;

  static final ErrorLog instance = ErrorLog();

  final DateTime Function() _now;

  /// Bellekteki son kayıtlar (en yeni sonda).
  final List<ErrorEntry> entries = [];
  static const maxEntries = 50;

  /// Aynı tür+ekran için olay gönderimi arasındaki en kısa süre.
  static const dedupeWindow = Duration(seconds: 60);

  /// Saatte en çok gönderilecek olay (hata fırtınasında analitiği boğmamak için).
  static const maxEventsPerHour = 10;

  /// Disk günlüğü bu boyutu aşınca eski yarısı atılır.
  static const maxFileBytes = 64 * 1024;

  /// O an görünen ekranın rota adı ([AnalyticsNavigatorObserver] günceller).
  String? currentScreen;

  final Map<String, DateTime> _lastSent = {};
  final List<DateTime> _sentTimes = [];
  File? _file;

  static final _typeBad = RegExp(r'[^A-Za-z0-9_<>?., ]');
  static final _screenOk = RegExp(r'^[A-Za-z0-9_./-]{1,60}$');
  static final _longDigits = RegExp(r'\d{10,}');

  /// `error_log.jsonl` dosyasını hazırlar; başarısızsa yalnız bellek günlüğü kullanılır. Hata fırlatmaz.
  Future<void> init({Directory? dir}) async {
    try {
      final d = dir ?? await getApplicationSupportDirectory();
      _file = File('${d.path}${Platform.pathSeparator}error_log.jsonl');
    } catch (_) {
      _file = null;
    }
  }

  /// Hata türü adını kişisel veri içermeyecek biçime getirir (en çok 80 karakter).
  @visibleForTesting
  static String sanitizeType(Object error) {
    var t = error.runtimeType.toString().replaceAll(_typeBad, '').replaceAll(_longDigits, '');
    if (t.length > 80) t = t.substring(0, 80);
    return t.isEmpty ? 'Unknown' : t;
  }

  /// Ekran adı sunucu desenine (`[A-Za-z0-9_./-]{1,60}`) uymuyorsa null.
  @visibleForTesting
  static String? sanitizeScreen(String? s) => s != null && _screenOk.hasMatch(s) ? s : null;

  /// Hatayı kaydeder; asla fırlatmaz. Dönen değer: analitik olayı kuyruğa alındı mı.
  bool report(Object error, {String source = 'flutter'}) {
    try {
      final now = _now();
      final entry = ErrorEntry(
        at: now,
        type: sanitizeType(error),
        source: source,
        screen: sanitizeScreen(currentScreen),
        version: appVersion,
      );
      entries.add(entry);
      if (entries.length > maxEntries) entries.removeRange(0, entries.length - maxEntries);
      if (!quiet) debugPrint('Yakalanmayan hata: ${entry.type} (${entry.source}, ${entry.screen ?? '-'})');
      unawaited(_append(entry));
      return _maybeSend(entry, now);
    } catch (_) {
      return false;
    }
  }

  bool _maybeSend(ErrorEntry e, DateTime now) {
    final key = '${e.type}|${e.screen}';
    final last = _lastSent[key];
    if (last != null && now.difference(last) < dedupeWindow) return false;
    _sentTimes.removeWhere((t) => now.difference(t) >= const Duration(hours: 1));
    if (_sentTimes.length >= maxEventsPerHour) return false;
    _lastSent[key] = now;
    _sentTimes.add(now);
    if (_lastSent.length > 100) _lastSent.remove(_lastSent.keys.first);
    Analytics.instance.track('app_error', screen: e.screen, props: {'type': e.type, 'source': e.source, 'version': e.version});
    return true;
  }

  Future<void> _append(ErrorEntry e) async {
    final f = _file;
    if (f == null) return;
    try {
      await f.writeAsString('${jsonEncode(e.toJson())}\n', mode: FileMode.append, flush: true);
      if (await f.length() > maxFileBytes) {
        final lines = await f.readAsLines();
        await f.writeAsString('${lines.sublist(lines.length ~/ 2).join('\n')}\n');
      }
    } catch (_) {
      // Günlük yazılamazsa uygulama etkilenmez.
    }
  }

  /// Diskteki günlük satırları (yoksa/okunamazsa boş).
  Future<List<String>> readFile() async {
    try {
      final f = _file;
      return f != null && await f.exists() ? await f.readAsLines() : const [];
    } catch (_) {
      return const [];
    }
  }

  /// Testler için sıfırlama.
  @visibleForTesting
  void reset() {
    entries.clear();
    _lastSent.clear();
    _sentTimes.clear();
    currentScreen = null;
    _file = null;
  }
}
