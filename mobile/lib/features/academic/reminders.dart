import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import '../../core/locale_controller.dart';
import '../../core/notify/local_reminders.dart';
import '../../l10n/app_localizations.dart';
import 'academic_api.dart';
import 'academic_models.dart';

/// Ders programı ekranlarının dile duyarlı yardımcıları (1=Pazartesi..7=Pazar).
String acadDayName(AppLocalizations l, int d) => switch (d) {
      1 => l.acadTimeDay1,
      2 => l.acadTimeDay2,
      3 => l.acadTimeDay3,
      4 => l.acadTimeDay4,
      5 => l.acadTimeDay5,
      6 => l.acadTimeDay6,
      _ => l.acadTimeDay7,
    };

String acadDayShort(AppLocalizations l, int d) => switch (d) {
      1 => l.acadTimeDayShort1,
      2 => l.acadTimeDayShort2,
      3 => l.acadTimeDayShort3,
      4 => l.acadTimeDayShort4,
      5 => l.acadTimeDayShort5,
      6 => l.acadTimeDayShort6,
      _ => l.acadTimeDayShort7,
    };

String acadColorName(AppLocalizations l, String key) => switch (key) {
      'red' => l.acadTimeColorRed,
      'orange' => l.acadTimeColorOrange,
      'amber' => l.acadTimeColorAmber,
      'green' => l.acadTimeColorGreen,
      'teal' => l.acadTimeColorTeal,
      'blue' => l.acadTimeColorBlue,
      'indigo' => l.acadTimeColorIndigo,
      'purple' => l.acadTimeColorPurple,
      'pink' => l.acadTimeColorPink,
      _ => l.acadTimeColorGray,
    };

String acadExamTypeName(AppLocalizations l, String t) => switch (t) {
      'VIZE' => l.acadTimeExamVize,
      'FINAL' => l.acadTimeExamFinal,
      'BUT' => l.acadTimeExamBut,
      'QUIZ' => l.acadTimeExamQuiz,
      'ODEV' => l.acadTimeExamOdev,
      _ => l.acadTimeExamOther,
    };

/// "28 Ekim 2026" (dile göre ay adı); [d] duvar saati (UTC işaretli) olabilir.
String acadDate(BuildContext context, DateTime d) =>
    DateFormat('d MMMM y', Localizations.localeOf(context).toString()).format(d);

/// "28 Ekim, Çarşamba" (dile göre).
String acadLongDate(BuildContext context, DateTime d) =>
    DateFormat('d MMMM, EEEE', Localizations.localeOf(context).toString()).format(d);

/// Yerel hatırlatmalar (sunucu ders/sınav bildirimi göndermez). Plan saf Dart'ta hesaplanır,
/// zamanlama platform kanalıyla (Android: AlarmManager, yaklaşık zaman) yapılır.

class ReminderSettings {
  const ReminderSettings({
    this.classEnabled = true,
    this.classLeadMin = 10,
    this.examDayBefore = true,
    this.examHourBefore = true,
  });

  final bool classEnabled;
  final int classLeadMin; // 5/10/15/30/60
  final bool examDayBefore, examHourBefore;

  static const leadOptions = [5, 10, 15, 30, 60];

  ReminderSettings copyWith({bool? classEnabled, int? classLeadMin, bool? examDayBefore, bool? examHourBefore}) =>
      ReminderSettings(
        classEnabled: classEnabled ?? this.classEnabled,
        classLeadMin: classLeadMin ?? this.classLeadMin,
        examDayBefore: examDayBefore ?? this.examDayBefore,
        examHourBefore: examHourBefore ?? this.examHourBefore,
      );

  Map<String, dynamic> toJson() => {
        'classEnabled': classEnabled,
        'classLeadMin': classLeadMin,
        'examDayBefore': examDayBefore,
        'examHourBefore': examHourBefore,
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> j) {
    final lead = j['classLeadMin'];
    return ReminderSettings(
      classEnabled: j['classEnabled'] != false,
      classLeadMin: lead is int && leadOptions.contains(lead) ? lead : 10,
      examDayBefore: j['examDayBefore'] != false,
      examHourBefore: j['examHourBefore'] != false,
    );
  }
}

class PlannedReminder {
  const PlannedReminder(this.id, this.at, this.title, this.body);

  final int id;
  final DateTime at; // gerçek anlık
  final String title, body;

  Map<String, dynamic> toMap() => {'id': id, 'at': at.millisecondsSinceEpoch, 'title': title, 'body': body};

  @override
  String toString() => 'PlannedReminder($id, $at, $title)';
}

int _hash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

/// Önümüzdeki [horizonDays] günün ders ve sınav hatırlatmaları (yalnız gelecek olanlar), zamana göre sıralı.
List<PlannedReminder> planReminders({
  required List<Course> courses,
  required Semester? semester,
  required List<Exam> exams,
  required ReminderSettings settings,
  required DateTime now,
  int horizonDays = 14,
  int maxCount = 60,
  AppLocalizations? l10n,
}) {
  final l = l10n ?? lookupAppLocalizations(const Locale('tr'));
  final out = <PlannedReminder>[];
  final nowWall = istanbulWall(now);
  final today = DateTime.utc(nowWall.year, nowWall.month, nowWall.day);
  if (settings.classEnabled) {
    for (var i = 0; i < horizonDays; i++) {
      final day = today.add(Duration(days: i));
      for (final s in slotsForDay(courses, semester, day)) {
        final startAt = wallToInstant(day.year, day.month, day.day).add(Duration(minutes: s.session.startMin));
        final at = startAt.subtract(Duration(minutes: settings.classLeadMin));
        if (!at.isAfter(now)) continue;
        final room = s.session.room != null ? ' · ${s.session.room}' : '';
        out.add(PlannedReminder(
          _hash('c${s.course.id}:${s.session.id ?? s.session.startMin}:${isoDate(day)}'),
          at,
          s.course.name,
          l.acadTimeRemClass(settings.classLeadMin.toString(), s.session.start, room),
        ));
      }
    }
  }
  for (final e in exams) {
    final room = e.room != null ? ' · ${e.room}' : '';
    final label = l.acadTimeRemExamLabel(acadExamTypeName(l, e.type), e.title);
    if (settings.examDayBefore) {
      final at = e.startsAt.subtract(const Duration(days: 1));
      if (at.isAfter(now)) {
        out.add(PlannedReminder(_hash('e${e.id}:d'), at, label, l.acadTimeRemExamTomorrow('${two(istanbulWall(e.startsAt).hour)}:${two(istanbulWall(e.startsAt).minute)}', room)));
      }
    }
    if (settings.examHourBefore) {
      final at = e.startsAt.subtract(const Duration(hours: 1));
      if (at.isAfter(now)) {
        out.add(PlannedReminder(_hash('e${e.id}:h'), at, label, l.acadTimeRemExamHour(room)));
      }
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out.length > maxCount ? out.sublist(0, maxCount) : out;
}

/// Zamanlama arka ucu. Varsayılan: yerel kanal; yoksa sessizce hiçbir şey yapmaz.
abstract class ReminderPlatform {
  /// Önceki tüm hatırlatmaları siler, [items]'i kurar.
  Future<void> replaceAll(List<PlannedReminder> items);

  /// Dışa aktarma için metin paylaşma; desteklenmiyorsa false.
  Future<bool> shareText(String text, String subject);
}

/// Ortak yerel hatırlatma servisi (`core/notify/local_reminders.dart`, grup 'academic') üzerinden zamanlar.
/// Metin paylaşımı için `bu_kampus/academic` kanalı denenir; yerel kod yoksa false (panoya kopyalanır).
class ChannelReminderPlatform implements ReminderPlatform {
  const ChannelReminderPlatform();

  static const _ch = MethodChannel('bu_kampus/academic');
  static const group = 'academic';

  @override
  Future<void> replaceAll(List<PlannedReminder> items) => LocalReminders.instance.replaceGroup(group, [
        for (final i in items)
          LocalReminder(
            id: i.id,
            at: i.at,
            title: i.title,
            body: i.body,
            channel: ReminderChannel.academic,
            payload: const {'targetType': 'TIMETABLE'},
          )
      ]);

  @override
  Future<bool> shareText(String text, String subject) async {
    try {
      await _ch.invokeMethod<void>('shareText', {'text': text, 'subject': subject});
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

abstract class ReminderStore {
  Future<ReminderSettings> load();
  Future<void> save(ReminderSettings s);
}

class SecureReminderStore implements ReminderStore {
  const SecureReminderStore();
  static const _key = 'academic_reminders';

  @override
  Future<ReminderSettings> load() async {
    try {
      final raw = await const FlutterSecureStorage().read(key: _key);
      if (raw == null) return const ReminderSettings();
      return ReminderSettings.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return const ReminderSettings();
    }
  }

  @override
  Future<void> save(ReminderSettings s) async {
    try {
      await const FlutterSecureStorage().write(key: _key, value: jsonEncode(s.toJson()));
    } catch (_) {}
  }
}

class MemoryReminderStore implements ReminderStore {
  MemoryReminderStore([this.value = const ReminderSettings()]);
  ReminderSettings value;

  @override
  Future<ReminderSettings> load() async => value;

  @override
  Future<void> save(ReminderSettings s) async => value = s;
}

/// Hatırlatmaları sunucudaki güncel ders/sınav verisiyle yeniden kurar. Hiçbir zaman exception sızdırmaz.
class ReminderService {
  ReminderService._();

  static ReminderPlatform platform = const ChannelReminderPlatform();
  static ReminderStore store = const SecureReminderStore();

  /// Sunucudaki güncel ders/sınav verisinden plan üretir (ağ hatasında exception fırlatır).
  static Future<List<PlannedReminder>> build(AcademicApi api, {ReminderSettings? settings}) async {
    final s = settings ?? await store.load();
    final tt = await api.timetable();
    final exams = await api.upcomingExams(days: 30);
    // Bağlam yok: kayıtlı uygulama dilinde (yoksa Türkçe) bildirim metni üretilir.
    final l = lookupAppLocalizations(LocaleController.current?.locale ?? const Locale('tr'));
    return planReminders(courses: tt.courses, semester: tt.semester, exams: exams, settings: s, now: academicClock(), l10n: l);
  }

  static Future<void> sync(AcademicApi api, {ReminderSettings? settings}) async {
    try {
      await platform.replaceAll(await build(api, settings: settings));
    } catch (e) {
      debugPrint('reminder sync failed: $e');
    }
  }

  /// Açılışta / saat değişiminde `LocalReminders.rescheduleAll` bu sağlayıcıyı çağırır.
  static void registerProvider(AcademicApi api) {
    LocalReminders.instance.registerProvider(ChannelReminderPlatform.group, () async => [
          for (final i in await build(api))
            LocalReminder(
                id: i.id,
                at: i.at,
                title: i.title,
                body: i.body,
                channel: ReminderChannel.academic,
                payload: const {'targetType': 'TIMETABLE'})
        ]);
  }
}
