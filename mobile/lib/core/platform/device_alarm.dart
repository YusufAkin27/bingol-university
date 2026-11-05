import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cihaz alarmı arayüzü (sınav ve ders alarmları).
///
/// ANDROID: sistem Saat uygulamasına `AlarmClock.ACTION_SET_ALARM` ile alarm yazılır (`BuAlarm.kt`, kanal
/// `bu_kampus/alarm`). Saat uygulaması tarih bilmez: tekrarsız alarm "bir sonraki o saat"te çalar; bu yüzden
/// tek seferlik alarm yalnız 24 saat içindeki bir ana kurulabilir (bkz. `alarm_planner.dart`). Kurulan alarmı silme
/// API'si yoktur: kullanıcı Saat uygulamasından siler.
///
/// iOS: Saat uygulamasına alarm ekleyen genel bir API YOKTUR. Yedek: uygulamanın kendi yerel bildirimi
/// (`UNCalendarNotificationTrigger`; ders için haftalık tekrar, sınav için tarihli tek sefer, zamana duyarlı).
/// Sessiz modda çalmayabilir; arayüz bunu açıkça söyler.
class AlarmSpec {
  const AlarmSpec({
    required this.key,
    required this.hour,
    required this.minute,
    required this.label,
    this.weekdays = const [],
    this.date,
    this.title = '',
    this.body = '',
    this.payload = const {},
  });

  /// Kararlı kimlik (iOS bildirim kimliği: aynı anahtar yeniden kurulunca eskisinin yerini alır).
  final String key;
  final int hour, minute;

  /// Saat uygulamasındaki alarm etiketi (kısa).
  final String label;

  /// Tekrar günleri (ISO 1=Pzt..7=Paz). Boş = tek seferlik.
  final List<int> weekdays;

  /// Tek seferlik alarmın günü (İstanbul duvar tarihi; yalnız iOS bildirimi kullanır, Android tarih bilmez).
  final DateTime? date;

  /// iOS yedek bildirimi metni.
  final String title, body;
  final Map<String, String> payload;

  bool get repeats => weekdays.isNotEmpty;

  @override
  String toString() => 'AlarmSpec($key ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $weekdays $date)';
}

abstract class DeviceAlarmService {
  static DeviceAlarmService instance = ChannelDeviceAlarmService();

  /// true: alarm sistem Saat uygulamasına yazılır (Android). false: yedek yerel bildirim (iOS).
  bool get usesClockApp;

  /// Saat uygulamasını karşılayan bir etkinlik var mı (yoksa kurulamaz). Bildirim yedeğinde her zaman true.
  Future<bool> isAvailable();

  /// Alarmı kurar; kurulduysa true.
  Future<bool> set(AlarmSpec spec);

  /// Bildirim yedeğiyle kurulmuş alarmları siler (Android'de işlem yok: Saat uygulamasından silinir).
  Future<void> cancelFallback();
}

class ChannelDeviceAlarmService implements DeviceAlarmService {
  ChannelDeviceAlarmService({bool? clockApp}) : _clockApp = clockApp ?? _defaultClockApp();

  static const channel = MethodChannel('bu_kampus/alarm');

  final bool _clockApp;

  static bool _defaultClockApp() {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get usesClockApp => _clockApp;

  Future<T?> _call<T>(String m, [Object? args]) async {
    try {
      return await channel.invokeMethod<T>(m, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('device alarm $m: ${e.code}');
      return null;
    }
  }

  @override
  Future<bool> isAvailable() async => (await _call<bool>('isAvailable')) ?? false;

  @override
  Future<bool> set(AlarmSpec spec) async {
    final d = spec.date;
    final ok = await _call<bool>('setAlarm', {
      'key': spec.key,
      'hour': spec.hour,
      'minute': spec.minute,
      'label': spec.label,
      // Calendar.DAY_OF_WEEK / iOS weekday: 1=Paz, 2=Pzt..7=Cmt.
      'days': [for (final w in spec.weekdays) w % 7 + 1],
      if (d != null) 'date': {'year': d.year, 'month': d.month, 'day': d.day},
      'title': spec.title,
      'body': spec.body,
      'payload': spec.payload,
    });
    return ok ?? false;
  }

  @override
  Future<void> cancelFallback() async {
    await _call<void>('cancelFallback');
  }
}

/// Testler için bellekte çalışan sahte servis.
class FakeDeviceAlarmService implements DeviceAlarmService {
  FakeDeviceAlarmService({this.clockApp = true, this.available = true, this.failKeys = const {}});

  final bool clockApp;
  final bool available;

  /// Bu anahtarlı alarmlar başarısız olur.
  final Set<String> failKeys;
  final List<AlarmSpec> requests = [];
  int cancelled = 0;

  @override
  bool get usesClockApp => clockApp;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> set(AlarmSpec spec) async {
    if (failKeys.contains(spec.key)) return false;
    requests.add(spec);
    return true;
  }

  @override
  Future<void> cancelFallback() async => cancelled++;
}
