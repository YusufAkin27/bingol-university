import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/swallow.dart';

import '../../core/notify/local_reminders.dart';
import '../../core/platform/device_alarm.dart';
import '../../l10n/app_localizations.dart';
import 'alarm_planner.dart';
import 'academic_models.dart';

/// Sınav ve ders alarmlarını cihaza kuran servis (planı `alarm_planner.dart` hesaplar, kurulumu
/// [DeviceAlarmService] yapar).
///
/// ANDROID tarihli alarm sorunu: Saat uygulaması (`ACTION_SET_ALARM`) tarih bilmez, tekrarsız alarm "bir sonraki o
/// saat"te çalar. Çözüm: alarm anı 24 saat içindeyse doğrudan kurulur; daha ilerideyse alarm ERTELENİR: kayıt
/// saklanır ve alarm gününden bir önceki akşam (20:00) "Alarmı kur" yerel bildirimi gelir; kullanıcı Sınavlar
/// sayfasına girince tek dokunuşla kurar (24 saat içinde olduğu için artık tarih doğrudur). Ders alarmı haftalık
/// tekrarlı olduğundan bu sorundan etkilenmez.
/// iOS: alarm yerine uygulamanın tarihli yerel bildirimi (sınav) / haftalık tekrarlı bildirimi (ders) kurulur.

/// Ertelenmiş sınav alarmı kaydı.
class PendingExamAlarm {
  const PendingExamAlarm({required this.key, required this.alarmAtMs, required this.examStartMs, required this.title, required this.label});

  final String key;
  final int alarmAtMs, examStartMs;
  final String title, label;

  DateTime get alarmAt => DateTime.fromMillisecondsSinceEpoch(alarmAtMs, isUtc: true);
  DateTime get examStart => DateTime.fromMillisecondsSinceEpoch(examStartMs, isUtc: true);

  int get hour => istanbulWall(alarmAt).hour;
  int get minute => istanbulWall(alarmAt).minute;

  Map<String, Object?> toJson() => {'k': key, 'a': alarmAtMs, 's': examStartMs, 't': title, 'l': label};

  factory PendingExamAlarm.fromJson(Map<String, dynamic> j) => PendingExamAlarm(
        key: '${j['k']}',
        alarmAtMs: j['a'] is int ? j['a'] as int : 0,
        examStartMs: j['s'] is int ? j['s'] as int : 0,
        title: '${j['t'] ?? ''}',
        label: '${j['l'] ?? ''}',
      );
}

/// Alarm durum kaydı: ertelenen sınav alarmları + son kurulan ders alarmı imzası (çift alarm uyarısı için).
class AlarmState {
  const AlarmState({this.pending = const [], this.classSignature, this.classSetAtMs});

  final List<PendingExamAlarm> pending;
  final String? classSignature;
  final int? classSetAtMs;

  Map<String, Object?> toJson() => {
        'p': [for (final p in pending) p.toJson()],
        if (classSignature != null) 'cs': classSignature,
        if (classSetAtMs != null) 'ct': classSetAtMs,
      };

  factory AlarmState.fromJson(Map<String, dynamic> j) => AlarmState(
        pending: [
          for (final p in (j['p'] as List? ?? const []))
            if (p is Map) PendingExamAlarm.fromJson(p.cast<String, dynamic>())
        ],
        classSignature: j['cs'] is String ? j['cs'] as String : null,
        classSetAtMs: j['ct'] is int ? j['ct'] as int : null,
      );
}

abstract class AlarmStateStore {
  Future<AlarmState> load();
  Future<void> save(AlarmState s);
  Future<void> clear();
}

class SecureAlarmStateStore implements AlarmStateStore {
  const SecureAlarmStateStore();
  static const _key = 'academic_alarms';

  @override
  Future<AlarmState> load() async {
    try {
      final raw = await const FlutterSecureStorage().read(key: _key);
      if (raw == null) return const AlarmState();
      return AlarmState.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (e) {
      swallow('alarm.load', e);
      return const AlarmState();
    }
  }

  @override
  Future<void> save(AlarmState s) async {
    try {
      await const FlutterSecureStorage().write(key: _key, value: jsonEncode(s.toJson()));
    } catch (e) {
      swallow('alarm.save', e);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await const FlutterSecureStorage().delete(key: _key);
    } catch (e) {
      swallow('alarm.clear', e);
    }
  }
}

class MemoryAlarmStateStore implements AlarmStateStore {
  AlarmState value = const AlarmState();

  @override
  Future<AlarmState> load() async => value;

  @override
  Future<void> save(AlarmState s) async => value = s;

  @override
  Future<void> clear() async => value = const AlarmState();
}

class ExamAlarmOutcome {
  const ExamAlarmOutcome({this.set = const [], this.deferred = const [], this.failed = const []});

  /// Kurulan (Android: Saat uygulaması, iOS: bildirim).
  final List<ExamAlarm> set;

  /// Android: ileri tarihli, alarm gününden önce hatırlatılıp kurulacak.
  final List<ExamAlarm> deferred;
  final List<ExamAlarm> failed;
}

class ClassAlarmOutcome {
  const ClassAlarmOutcome({this.set = const [], this.failed = const []});

  final List<ClassAlarm> set, failed;
}

const _nudgeGroup = 'examalarm';
const _nudgeMax = 30;

String _clip(String s, int n) => s.length <= n ? s : '${s.substring(0, n - 1)}…';

int _hash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

class AlarmService {
  AlarmService({DeviceAlarmService? alarms, AlarmStateStore? store, LocalReminders? reminders, Duration? gap, DateTime Function()? clock})
      : _alarms = alarms,
        _store = store ?? const SecureAlarmStateStore(),
        _reminders = reminders,
        gap = gap ?? const Duration(milliseconds: 700),
        _clock = clock ?? academicClock;

  static AlarmService instance = AlarmService();

  final DeviceAlarmService? _alarms;
  final AlarmStateStore _store;
  final LocalReminders? _reminders;

  /// Art arda Saat uygulaması çağrıları arasındaki bekleme (her çağrı Saat'i öne getirebilir).
  final Duration gap;
  final DateTime Function() _clock;

  DeviceAlarmService get alarms => _alarms ?? DeviceAlarmService.instance;
  LocalReminders get reminders => _reminders ?? LocalReminders.instance;

  Future<AlarmState> state() => _store.load();

  /// Çıkış / hesap değişimi: ertelenmiş sınav alarmları ve hatırlatıcıları silinir. Hata sızdırmaz.
  static Future<void> clearUserData() async {
    try {
      await instance._store.clear();
      await instance.reminders.cancelGroup(_nudgeGroup);
      await instance.alarms.cancelFallback();
    } catch (e) {
      swallow('alarm.clearall', e);
    }
  }

  // ------------------------------------------------------------------ sınav

  AlarmSpec examSpec(ExamAlarm a, AppLocalizations l) {
    final w = istanbulWall(a.exam.startsAt);
    final time = hhmm(w.hour * 60 + w.minute);
    final room = a.exam.room != null ? ' · ${a.exam.room}' : '';
    return AlarmSpec(
      key: a.key,
      hour: a.hour,
      minute: a.minute,
      label: _clip(l.alarmExamLabel(time, a.exam.title), 60),
      date: a.alarmDay,
      title: l.alarmExamNotifTitle,
      body: '${a.exam.title} · $time$room',
      payload: const {'targetType': 'EXAM'},
    );
  }

  /// Planı uygular. Android: 24 saat içindekiler Saat'e kurulur, ileridekiler ertelenir; iOS: hepsi bildirim olarak.
  Future<ExamAlarmOutcome> applyExams(List<ExamAlarm> plans, AppLocalizations l) async {
    final now = _clock();
    final set = <ExamAlarm>[], deferred = <ExamAlarm>[], failed = <ExamAlarm>[];
    final st = await _store.load();
    final pending = {for (final p in st.pending) p.key: p};
    var first = true;
    for (final a in plans) {
      if (alarms.usesClockApp && !a.canSetInClockNow(now)) {
        final spec = examSpec(a, l);
        pending[a.key] = PendingExamAlarm(
          key: a.key,
          alarmAtMs: a.alarmAt.millisecondsSinceEpoch,
          examStartMs: a.exam.startsAt.millisecondsSinceEpoch,
          title: a.exam.title,
          label: spec.label,
        );
        deferred.add(a);
        continue;
      }
      if (!first) await Future<void>.delayed(gap);
      first = false;
      if (await alarms.set(examSpec(a, l))) {
        set.add(a);
        pending.remove(a.key);
      } else {
        failed.add(a);
      }
    }
    await _savePending(pending.values.toList(), st, l);
    return ExamAlarmOutcome(set: set, deferred: deferred, failed: failed);
  }

  Future<void> _savePending(List<PendingExamAlarm> list, AlarmState prev, AppLocalizations l) async {
    final now = _clock();
    final live = list.where((p) => p.alarmAt.isAfter(now)).toList()..sort((a, b) => a.alarmAtMs.compareTo(b.alarmAtMs));
    final kept = live.length > _nudgeMax ? live.sublist(0, _nudgeMax) : live;
    await _store.save(AlarmState(pending: kept, classSignature: prev.classSignature, classSetAtMs: prev.classSetAtMs));
    await reminders.replaceGroup(_nudgeGroup, [
      for (final p in kept)
        LocalReminder(
          id: _hash('nudge-${p.key}'),
          at: nudgeInstant(p.alarmAt),
          title: l.alarmNudgeTitle,
          body: l.alarmNudgeBody(p.title, hhmm(p.hour * 60 + p.minute)),
          channel: ReminderChannel.academic,
          payload: const {'targetType': 'EXAM'},
        )
    ]);
  }

  /// Şimdi kurulabilir (alarm anı 24 saat içinde) ertelenmiş alarmlar.
  Future<List<PendingExamAlarm>> dueNow() async {
    if (!alarms.usesClockApp) return const [];
    final now = _clock();
    final st = await _store.load();
    return [
      for (final p in st.pending)
        if (p.alarmAt.isAfter(now) && p.alarmAt.difference(now) < kClockOneShotHorizon) p
    ]..sort((a, b) => a.alarmAtMs.compareTo(b.alarmAtMs));
  }

  /// Ertelenen alarmlardan zamanı gelenleri Saat uygulamasına kurar; kurulan sayısı.
  Future<({int set, int failed})> setDue(AppLocalizations l) async {
    final due = await dueNow();
    final st = await _store.load();
    final pending = {for (final p in st.pending) p.key: p};
    var ok = 0, bad = 0;
    for (var i = 0; i < due.length; i++) {
      if (i > 0) await Future<void>.delayed(gap);
      final p = due[i];
      final spec = AlarmSpec(key: p.key, hour: p.hour, minute: p.minute, label: p.label, date: DateTime.utc(istanbulWall(p.alarmAt).year, istanbulWall(p.alarmAt).month, istanbulWall(p.alarmAt).day));
      if (await alarms.set(spec)) {
        ok++;
        pending.remove(p.key);
      } else {
        bad++;
      }
    }
    await _savePending(pending.values.toList(), st, l);
    return (set: ok, failed: bad);
  }

  // ------------------------------------------------------------------ ders

  AlarmSpec classSpec(ClassAlarm a, AppLocalizations l) {
    final startMin = a.days.first.session.startMin;
    final startTime = hhmm(startMin);
    return AlarmSpec(
      key: a.key,
      hour: a.hour,
      minute: a.minute,
      label: _clip(l.alarmClassLabel(startTime), 60),
      weekdays: a.weekdays,
      title: l.alarmClassNotifTitle,
      body: l.alarmClassNotifBody(startTime),
      payload: const {'targetType': 'TIMETABLE'},
    );
  }

  static String classSignature(List<ClassAlarm> plans) =>
      plans.map((p) => '${p.key}:${p.weekdays.join(',')}').join('|');

  /// Önceki ders alarmı kurulumu (aynı imza) varsa kurulum anı; yoksa null. Android'de çift alarm uyarısı içindir.
  Future<DateTime?> previousClassSetup(List<ClassAlarm> plans) async {
    if (!alarms.usesClockApp) return null;
    final st = await _store.load();
    if (st.classSignature == null || st.classSetAtMs == null) return null;
    if (st.classSignature != classSignature(plans)) return null;
    return DateTime.fromMillisecondsSinceEpoch(st.classSetAtMs!, isUtc: true);
  }

  Future<ClassAlarmOutcome> applyClasses(List<ClassAlarm> plans, AppLocalizations l) async {
    final set = <ClassAlarm>[], failed = <ClassAlarm>[];
    for (var i = 0; i < plans.length; i++) {
      if (i > 0) await Future<void>.delayed(gap);
      if (await alarms.set(classSpec(plans[i], l))) {
        set.add(plans[i]);
      } else {
        failed.add(plans[i]);
      }
    }
    if (set.isNotEmpty) {
      final st = await _store.load();
      await _store.save(AlarmState(pending: st.pending, classSignature: classSignature(plans), classSetAtMs: _clock().millisecondsSinceEpoch));
    }
    return ClassAlarmOutcome(set: set, failed: failed);
  }
}
