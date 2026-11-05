import 'academic_models.dart';

/// Sınav ve ders alarmlarının SAF hesabı (platform yok, test edilebilir). Tüm saatler İstanbul duvar saatidir
/// (akademik modülün genel kuralı); gerçek anlıklar `academic_models.dart` yardımcılarıyla çevrilir.
///
/// Kurallar:
/// - Sınav: bir günün YALNIZ ilk sınavı için, başlangıçtan [kAlarmLeadMin] dk önceye TEK SEFERLİK alarm. O günün
///   diğer sınavları için alarm yoktur. İlk sınavın alarm anı geçmişteyse o gün için hiç alarm kurulmaz.
/// - Ders: her hafta günü için o günün en erken dersi, YALNIZ sabah ise ([kMorningLimitMin] öncesi), başlangıçtan
///   [kAlarmLeadMin] dk önceye, o hafta gününde HER HAFTA tekrarlı.

/// Alarm, başlangıçtan kaç dakika önce çalar.
const kAlarmLeadMin = 60;

/// "Sabah dersi" sınırı: 12:00 (dakika). Başlangıç bu değerden küçükse sabahtır.
const kMorningLimitMin = 12 * 60;

/// Android Saat uygulaması tek seferlik alarmı yalnız "bir sonraki o saat"e kurabilir: alarm anı en çok bu kadar
/// ilerideyse tarih doğru tutar.
const kClockOneShotHorizon = Duration(hours: 24);

/// Bir sınav günü için kurulacak alarm.
class ExamAlarm {
  const ExamAlarm({required this.exam, required this.alarmAt, required this.skipped});

  /// Günün ilk sınavı.
  final Exam exam;

  /// Alarmın çalacağı gerçek an (sınav başlangıcı - [kAlarmLeadMin] dk).
  final DateTime alarmAt;

  /// Aynı günün alarmsız kalan diğer sınavları (başlangıca göre sıralı).
  final List<Exam> skipped;

  DateTime get _wall => istanbulWall(alarmAt);
  int get hour => _wall.hour;
  int get minute => _wall.minute;

  /// Alarmın düştüğü takvim günü (gece yarısına yakın sınavda bir önceki gün olabilir).
  DateTime get alarmDay => DateTime.utc(_wall.year, _wall.month, _wall.day);

  /// Sınavın günü.
  DateTime get examDay {
    final w = istanbulWall(exam.startsAt);
    return DateTime.utc(w.year, w.month, w.day);
  }

  /// Kararlı anahtar (aynı sınav için aynı alarm; iOS bildirim kimliği ve yinelenen kurulum engeli).
  String get key => 'exam-${exam.id}';

  /// Android Saat uygulaması bu alarmı DOĞRU güne kurabilir mi (alarm anı [now]'dan en çok 24 saat sonra).
  bool canSetInClockNow(DateTime now) {
    final d = alarmAt.difference(now);
    return d > Duration.zero && d < kClockOneShotHorizon;
  }

  /// Ertelenmiş alarm için "alarmı kur" hatırlatma anı ([nudgeInstant]).
  DateTime get nudgeAt => nudgeInstant(alarmAt);
}

/// Ertelenmiş alarm için "alarmı kur" hatırlatması: alarm gününden bir önceki akşam 20:00 (alarm 19:00 ve sonrasıysa
/// alarm günü 08:00). Her iki durumda da alarm anı bu andan itibaren 24 saatin içindedir, yani Saat uygulaması
/// tek seferlik alarmı doğru güne kurar.
DateTime nudgeInstant(DateTime alarmAt) {
  final w = istanbulWall(alarmAt);
  final d = DateTime.utc(w.year, w.month, w.day);
  if (w.hour >= 19) return wallToInstant(d.year, d.month, d.day, 8);
  final p = d.subtract(const Duration(days: 1));
  return wallToInstant(p.year, p.month, p.day, 20);
}

/// Sınav alarm planı: gün başına ilk sınav, alarm anı gelecekte olanlar, alarm anına göre sıralı.
List<ExamAlarm> planExamAlarms(List<Exam> exams, DateTime now, {int leadMin = kAlarmLeadMin}) {
  final byDay = <String, List<Exam>>{};
  for (final e in exams) {
    final w = istanbulWall(e.startsAt);
    byDay.putIfAbsent(isoDate(DateTime.utc(w.year, w.month, w.day)), () => []).add(e);
  }
  final out = <ExamAlarm>[];
  for (final list in byDay.values) {
    list.sort((a, b) {
      final c = a.startsAt.compareTo(b.startsAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    final first = list.first;
    final at = first.startsAt.subtract(Duration(minutes: leadMin));
    if (!at.isAfter(now)) continue;
    out.add(ExamAlarm(exam: first, alarmAt: at, skipped: list.sublist(1)));
  }
  out.sort((a, b) => a.alarmAt.compareTo(b.alarmAt));
  return out;
}

/// Bir ders gününün sabah alarmı (hesaplanmış).
class ClassAlarmDay {
  const ClassAlarmDay({required this.classWeekday, required this.alarmWeekday, required this.alarmMin, required this.course, required this.session});

  /// Dersin günü (1=Pzt..7=Paz).
  final int classWeekday;

  /// Alarmın çaldığı gün (ders gece yarısına yakınsa bir önceki gün).
  final int alarmWeekday;

  /// Alarmın günün kaçıncı dakikası olduğu (0..1439).
  final int alarmMin;
  final Course course;
  final CourseSession session;

  int get hour => alarmMin ~/ 60;
  int get minute => alarmMin % 60;
}

/// Her hafta günü için en erken ders; yalnız sabahsa ([kMorningLimitMin] öncesi) alarm günü. Dönem bitmişse boş.
List<ClassAlarmDay> planClassAlarmDays(List<Course> courses, {Semester? semester, DateTime? now, int leadMin = kAlarmLeadMin}) {
  if (now != null && semester?.endDate != null) {
    final w = istanbulWall(now);
    if (DateTime.utc(w.year, w.month, w.day).isAfter(semester!.endDate!)) return const [];
  }
  final out = <ClassAlarmDay>[];
  for (var day = 1; day <= 7; day++) {
    Course? bestCourse;
    CourseSession? best;
    for (final c in courses) {
      for (final s in c.sessions) {
        if (s.dayOfWeek != day) continue;
        if (best == null || s.startMin < best.startMin) {
          best = s;
          bestCourse = c;
        }
      }
    }
    if (best == null || bestCourse == null) continue;
    if (best.startMin >= kMorningLimitMin) continue;
    var m = best.startMin - leadMin;
    var wd = day;
    if (m < 0) {
      m += 1440;
      wd = wd == 1 ? 7 : wd - 1;
    }
    out.add(ClassAlarmDay(classWeekday: day, alarmWeekday: wd, alarmMin: m, course: bestCourse, session: best));
  }
  return out;
}

/// Aynı saatteki günleri tek (tekrarlı) alarmda birleştirir; saate göre sıralı.
class ClassAlarm {
  const ClassAlarm({required this.hour, required this.minute, required this.weekdays, required this.days});

  final int hour, minute;

  /// Alarm günleri (1=Pzt..7=Paz), sıralı.
  final List<int> weekdays;
  final List<ClassAlarmDay> days;

  String get key => 'class-${two(hour)}${two(minute)}';
}

List<ClassAlarm> groupClassAlarms(List<ClassAlarmDay> days) {
  final by = <int, List<ClassAlarmDay>>{};
  for (final d in days) {
    by.putIfAbsent(d.alarmMin, () => []).add(d);
  }
  final keys = by.keys.toList()..sort();
  return [
    for (final k in keys)
      ClassAlarm(
        hour: k ~/ 60,
        minute: k % 60,
        weekdays: (by[k]!.map((d) => d.alarmWeekday).toList()..sort()),
        days: (by[k]!.toList()..sort((a, b) => a.alarmWeekday.compareTo(b.alarmWeekday))),
      )
  ];
}

/// ISO hafta günü (1=Pzt..7=Paz) -> `Calendar.DAY_OF_WEEK` / iOS `weekday` (1=Paz, 2=Pzt..7=Cmt).
int calendarWeekday(int isoWeekday) => isoWeekday % 7 + 1;
