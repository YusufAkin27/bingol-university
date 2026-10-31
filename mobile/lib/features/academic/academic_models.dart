import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Akademik modül veri modelleri ve saf mantık (çakışma, günün dersleri, ICS).
/// Tüm saatler Europe/Istanbul (+03:00, yaz saati yok): sunucu ofsetli ISO verir, burada duvar saatine çevrilir.

/// Test edilebilirlik için saat kaynağı.
DateTime Function() academicClock = DateTime.now;

const _istanbul = Duration(hours: 3);

/// Anlık -> İstanbul duvar saati (UTC işaretli DateTime; yalnız alanları kullanın).
DateTime istanbulWall(DateTime instant) => instant.toUtc().add(_istanbul);

/// İstanbul duvar saati alanları -> gerçek anlık.
DateTime wallToInstant(int y, int m, int d, [int h = 0, int min = 0]) => DateTime.utc(y, m, d, h, min).subtract(_istanbul);

DateTime? parseInstant(Object? v) {
  if (v is! String || v.isEmpty) return null;
  final hasOffset = RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(v);
  final p = DateTime.tryParse(hasOffset ? v : '$v+03:00');
  return p;
}

DateTime? parseDate(Object? v) {
  if (v is! String || v.length < 10) return null;
  final p = v.substring(0, 10).split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime.utc(y, m, d);
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int minutesOf(String hhmm) {
  final p = hhmm.split(':');
  if (p.length < 2) return 0;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

String hhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String _s(Object? v) => v is String ? v : '';
String? _sn(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

const dayNames = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
const dayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const monthNames = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

/// Dile göre ay adı (1..12).
String monthNameL(AppLocalizations l, int month) => switch (month) {
      1 => l.acadMonth1,
      2 => l.acadMonth2,
      3 => l.acadMonth3,
      4 => l.acadMonth4,
      5 => l.acadMonth5,
      6 => l.acadMonth6,
      7 => l.acadMonth7,
      8 => l.acadMonth8,
      9 => l.acadMonth9,
      10 => l.acadMonth10,
      11 => l.acadMonth11,
      _ => l.acadMonth12,
    };

/// Dile göre gün adı (1=Pazartesi..7=Pazar).
String dayNameL(AppLocalizations l, int weekday) => switch (weekday) {
      1 => l.acadDay1,
      2 => l.acadDay2,
      3 => l.acadDay3,
      4 => l.acadDay4,
      5 => l.acadDay5,
      6 => l.acadDay6,
      _ => l.acadDay7,
    };

/// Dile göre kısa gün adı (1=Pzt..7=Paz).
String dayShortL(AppLocalizations l, int weekday) => switch (weekday) {
      1 => l.acadDayShort1,
      2 => l.acadDayShort2,
      3 => l.acadDayShort3,
      4 => l.acadDayShort4,
      5 => l.acadDayShort5,
      6 => l.acadDayShort6,
      _ => l.acadDayShort7,
    };

/// Ders rengi anahtarları (sunucu ile aynı).
/// Seçicide gösterilen 6 renk (palet: mavi, su mavisi, yeşil, amber, kırmızı, nötr). Sunucu eski anahtarları
/// (orange/indigo/purple/pink) hâlâ saklayabilir; [courseColor] bunları en yakın aileye eşler.
const courseColorKeys = ['blue', 'teal', 'green', 'amber', 'red', 'gray'];

/// Ders rengi tabanı: tema duyarsız ana tonlar (akadTint açık/koyu zemini bunlardan türetir; hepsi AA).
Color courseColor(String? key) => switch (key) {
      'red' || 'pink' => const Color(0xFFBC3A2D),
      'amber' || 'orange' => const Color(0xFF9A5700),
      'green' => const Color(0xFF1E7A50),
      'teal' => const Color(0xFF0B6E86),
      'blue' || 'indigo' => const Color(0xFF1F4E96),
      _ => const Color(0xFF5C5A56),
    };

String colorLabel(String key) => switch (key) {
      'red' => 'Kırmızı',
      'orange' => 'Turuncu',
      'amber' => 'Sarı',
      'green' => 'Yeşil',
      'teal' => 'Turkuaz',
      'blue' => 'Mavi',
      'indigo' => 'Çivit',
      'purple' => 'Mor',
      'pink' => 'Pembe',
      _ => 'Gri',
    };

/// Dile göre renk adı.
String colorLabelL(AppLocalizations l, String key) => switch (key) {
      'red' => l.acadColorRed,
      'orange' => l.acadColorOrange,
      'amber' => l.acadColorAmber,
      'green' => l.acadColorGreen,
      'teal' => l.acadColorTeal,
      'blue' => l.acadColorBlue,
      'indigo' => l.acadColorIndigo,
      'purple' => l.acadColorPurple,
      'pink' => l.acadColorPink,
      _ => l.acadColorGray,
    };

class CourseSession {
  const CourseSession({this.id, required this.dayOfWeek, required this.start, required this.end, this.room});

  final int? id;
  final int dayOfWeek; // 1=Pzt..7=Paz
  final String start; // HH:mm
  final String end;
  final String? room;

  int get startMin => minutesOf(start);
  int get endMin => minutesOf(end);

  factory CourseSession.fromJson(Map<String, dynamic> j) => CourseSession(
        id: j['id'] is num ? _i(j['id']) : null,
        dayOfWeek: _i(j['dayOfWeek']),
        start: _s(j['start']).isEmpty ? _s(j['startTime']) : _s(j['start']),
        end: _s(j['end']).isEmpty ? _s(j['endTime']) : _s(j['end']),
        room: _sn(j['room']),
      );

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'start': start,
        'end': end,
        if (room != null && room!.trim().isNotEmpty) 'room': room!.trim(),
      };

  CourseSession copyWith({int? dayOfWeek, String? start, String? end, String? room}) => CourseSession(
      id: id, dayOfWeek: dayOfWeek ?? this.dayOfWeek, start: start ?? this.start, end: end ?? this.end, room: room ?? this.room);
}

class Course {
  const Course({
    required this.id,
    required this.name,
    this.code,
    this.instructor,
    this.color = 'blue',
    this.note,
    this.semesterId,
    this.sessions = const [],
  });

  final int id;
  final String name;
  final String? code, instructor, note;
  final String color;
  final int? semesterId;
  final List<CourseSession> sessions;

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: _i(j['id']),
        name: _s(j['name']),
        code: _sn(j['code']),
        instructor: _sn(j['instructor']),
        color: _sn(j['color']) ?? 'blue',
        note: _sn(j['note']),
        semesterId: j['semesterId'] is num ? _i(j['semesterId']) : null,
        sessions: [
          for (final s in (j['sessions'] as List? ?? const []))
            if (s is Map) CourseSession.fromJson(s.cast<String, dynamic>())
        ],
      );
}

class Semester {
  const Semester({required this.id, required this.name, this.startDate, this.endDate, this.current = false});

  final int id;
  final String name;
  final DateTime? startDate, endDate;
  final bool current;

  factory Semester.fromJson(Map<String, dynamic> j) => Semester(
        id: _i(j['id']),
        name: _s(j['name']),
        startDate: parseDate(j['startDate']),
        endDate: parseDate(j['endDate']),
        current: j['current'] == true,
      );

  bool covers(DateTime day) {
    final d = DateTime.utc(day.year, day.month, day.day);
    if (startDate != null && d.isBefore(startDate!)) return false;
    if (endDate != null && d.isAfter(endDate!)) return false;
    return true;
  }
}

class TimetableData {
  const TimetableData({this.semester, this.courses = const []});

  final Semester? semester;
  final List<Course> courses;

  factory TimetableData.fromJson(Map<String, dynamic> j) => TimetableData(
        semester: j['semester'] is Map ? Semester.fromJson((j['semester'] as Map).cast<String, dynamic>()) : null,
        courses: [
          for (final c in (j['courses'] as List? ?? const []))
            if (c is Map) Course.fromJson(c.cast<String, dynamic>())
        ],
      );
}

enum SlotStatus { past, ongoing, upcoming }

/// Bir günün tek ders oturumu.
class DaySlot {
  const DaySlot(this.course, this.session, this.date, this.status);

  final Course course;
  final CourseSession session;
  final DateTime date; // duvar tarihi (UTC işaretli, saat 00:00)
  final SlotStatus status;
}

/// [day] gününe düşen oturumlar (saate göre). Dönem aralığı dışındaki günlerde boş.
List<DaySlot> slotsForDay(List<Course> courses, Semester? semester, DateTime day, {DateTime? nowWall}) {
  final d = DateTime.utc(day.year, day.month, day.day);
  if (semester != null && !semester.covers(d)) return const [];
  final isToday = nowWall != null && nowWall.year == d.year && nowWall.month == d.month && nowWall.day == d.day;
  final nowMin = nowWall == null ? 0 : nowWall.hour * 60 + nowWall.minute;
  final out = <DaySlot>[];
  for (final c in courses) {
    for (final s in c.sessions) {
      if (s.dayOfWeek != d.weekday) continue;
      var st = SlotStatus.upcoming;
      if (isToday) {
        if (nowMin >= s.endMin) {
          st = SlotStatus.past;
        } else if (nowMin >= s.startMin) {
          st = SlotStatus.ongoing;
        }
      }
      out.add(DaySlot(c, s, d, st));
    }
  }
  out.sort((a, b) => a.session.startMin.compareTo(b.session.startMin));
  return out;
}

/// Şimdiden sonra başlayan ilk oturum (bugün, yoksa sonraki 7 gün). null: yok.
({DaySlot slot, int minutesUntil})? nextSlot(List<Course> courses, Semester? semester, DateTime nowWall) {
  final today = DateTime.utc(nowWall.year, nowWall.month, nowWall.day);
  for (var i = 0; i <= 7; i++) {
    final day = today.add(Duration(days: i));
    for (final s in slotsForDay(courses, semester, day, nowWall: nowWall)) {
      final startAbs = day.add(Duration(minutes: s.session.startMin));
      final diff = startAbs.difference(nowWall).inMinutes;
      if (diff > 0) return (slot: s, minutesUntil: diff);
    }
  }
  return null;
}

/// İki oturum çakışır mı: aynı gün, `startA < endB && startB < endA` (bitişik dersler çakışmaz).
bool sessionsOverlap(CourseSession a, CourseSession b) =>
    a.dayOfWeek == b.dayOfWeek && a.startMin < b.endMin && b.startMin < a.endMin;

class CourseConflict {
  const CourseConflict(this.course, this.session, this.other);

  final Course course; // çakışılan mevcut ders
  final CourseSession session; // mevcut dersin oturumu
  final CourseSession other; // aday oturum
}

/// [candidate] oturumlarının mevcut derslerle ve kendi aralarındaki çakışmaları. [excludeCourseId] düzenlenen ders.
List<CourseConflict> findConflicts(List<Course> existing, List<CourseSession> candidate, {int? excludeCourseId}) {
  final out = <CourseConflict>[];
  for (final c in existing) {
    if (c.id == excludeCourseId) continue;
    for (final s in c.sessions) {
      for (final n in candidate) {
        if (sessionsOverlap(s, n)) out.add(CourseConflict(c, s, n));
      }
    }
  }
  return out;
}

/// Aday oturumların kendi aralarında çakışan çiftleri (indeks).
List<(int, int)> selfConflicts(List<CourseSession> s) {
  final out = <(int, int)>[];
  for (var i = 0; i < s.length; i++) {
    for (var j = i + 1; j < s.length; j++) {
      if (sessionsOverlap(s[i], s[j])) out.add((i, j));
    }
  }
  return out;
}

class Exam {
  const Exam({
    required this.id,
    this.courseId,
    this.courseName,
    required this.title,
    this.type = 'DIGER',
    required this.startsAt,
    this.endsAt,
    this.room,
    this.note,
  });

  final int id;
  final int? courseId;
  final String? courseName, room, note;
  final String title, type;
  final DateTime startsAt;
  final DateTime? endsAt;

  factory Exam.fromJson(Map<String, dynamic> j) => Exam(
        id: _i(j['id']),
        courseId: j['courseId'] is num ? _i(j['courseId']) : null,
        courseName: _sn(j['courseName']),
        title: _s(j['title']),
        type: _sn(j['type']) ?? 'DIGER',
        startsAt: parseInstant(j['startsAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        endsAt: parseInstant(j['endsAt']),
        room: _sn(j['room']),
        note: _sn(j['note']),
      );
}

class OfficialExam {
  const OfficialExam({
    required this.id,
    required this.title,
    this.type = 'DIGER',
    this.courseCode,
    this.department,
    this.grade,
    required this.startsAt,
    this.endsAt,
    this.room,
    this.note,
  });

  final int id;
  final String title, type;
  final String? courseCode, department, grade, room, note;
  final DateTime startsAt;
  final DateTime? endsAt;

  factory OfficialExam.fromJson(Map<String, dynamic> j) => OfficialExam(
        id: _i(j['id']),
        title: _s(j['title']),
        type: _sn(j['type']) ?? 'DIGER',
        courseCode: _sn(j['courseCode']),
        department: _sn(j['department']),
        grade: _sn(j['grade']),
        startsAt: parseInstant(j['startsAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        endsAt: parseInstant(j['endsAt']),
        room: _sn(j['room']),
        note: _sn(j['note']),
      );
}

String examTypeLabel(String t) => switch (t) {
      'VIZE' => 'Vize',
      'FINAL' => 'Final',
      'BUT' => 'Bütünleme',
      'QUIZ' => 'Quiz',
      'ODEV' => 'Ödev',
      _ => 'Diğer',
    };

/// Dile göre sınav türü adı.
String examTypeLabelL(AppLocalizations l, String t) => switch (t) {
      'VIZE' => l.acadExamTypeVize,
      'FINAL' => l.acadExamTypeFinal,
      'BUT' => l.acadExamTypeBut,
      'QUIZ' => l.acadExamTypeQuiz,
      'ODEV' => l.acadExamTypeOdev,
      _ => l.acadExamTypeDiger,
    };

const examTypes = ['VIZE', 'FINAL', 'BUT', 'QUIZ', 'ODEV', 'DIGER'];

/// Dile göre geri sayım metni; geçmişse null.
String? countdownTextL(AppLocalizations l, DateTime startsAt, DateTime nowInstant) {
  final diff = startsAt.difference(nowInstant);
  if (diff.isNegative) return null;
  if (diff.inDays >= 1) return l.acadCountdownDays(diff.inDays.toString());
  if (diff.inHours >= 1) return l.acadCountdownHours(diff.inHours.toString());
  return l.acadCountdownMinutes((diff.inMinutes < 1 ? 1 : diff.inMinutes).toString());
}

/// Sınava kalan süre: "2 gün", "5 saat", "40 dk"; geçmişse null.
String? countdownText(DateTime startsAt, DateTime nowInstant) {
  final diff = startsAt.difference(nowInstant);
  if (diff.isNegative) return null;
  if (diff.inDays >= 1) return '${diff.inDays} gün kaldı';
  if (diff.inHours >= 1) return '${diff.inHours} saat kaldı';
  return '${diff.inMinutes < 1 ? 1 : diff.inMinutes} dk kaldı';
}

class AcademicEvent {
  const AcademicEvent({
    required this.id,
    required this.kind,
    required this.title,
    required this.startsAt,
    this.endsAt,
    this.allDay = true,
    this.scopeDepartment,
    this.note,
  });

  final int id;
  final String kind, title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool allDay;
  final String? scopeDepartment, note;

  factory AcademicEvent.fromJson(Map<String, dynamic> j) => AcademicEvent(
        id: _i(j['id']),
        kind: _sn(j['kind']) ?? 'DIGER',
        title: _s(j['title']),
        startsAt: parseInstant(j['startsAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        endsAt: parseInstant(j['endsAt']),
        allDay: j['allDay'] != false,
        scopeDepartment: _sn(j['scopeDepartment']),
        note: _sn(j['note']),
      );

  /// Başlangıç ve bitiş duvar tarihi (bitiş yoksa başlangıç).
  DateTime get startDay {
    final w = istanbulWall(startsAt);
    return DateTime.utc(w.year, w.month, w.day);
  }

  DateTime get endDay {
    final e = endsAt;
    if (e == null) return startDay;
    final w = istanbulWall(e);
    final d = DateTime.utc(w.year, w.month, w.day);
    return d.isBefore(startDay) ? startDay : d;
  }

  bool coversDay(DateTime day) {
    final d = DateTime.utc(day.year, day.month, day.day);
    return !d.isBefore(startDay) && !d.isAfter(endDay);
  }
}

String eventKindLabel(String k) => switch (k) {
      'DONEM_BASLANGIC' => 'Dönem başlangıcı',
      'DERS_KAYIT' => 'Ders kaydı',
      'VIZE' => 'Vize',
      'FINAL' => 'Final',
      'BUT' => 'Bütünleme',
      'TATIL' => 'Tatil',
      'RESMI_TATIL' => 'Resmi tatil',
      _ => 'Diğer',
    };

/// Dile göre takvim kaydı türü adı.
String eventKindLabelL(AppLocalizations l, String k) => switch (k) {
      'DONEM_BASLANGIC' => l.acadEventKindSemesterStart,
      'DERS_KAYIT' => l.acadEventKindRegistration,
      'VIZE' => l.acadExamTypeVize,
      'FINAL' => l.acadExamTypeFinal,
      'BUT' => l.acadExamTypeBut,
      'TATIL' => l.acadEventKindHoliday,
      'RESMI_TATIL' => l.acadEventKindPublicHoliday,
      _ => l.acadExamTypeDiger,
    };

Color eventKindColor(String k) => switch (k) {
      // Tek vurgu: sınavlar (vize/final/büt) vurgulu, geri kalan her şey nötr. Tür simgeyle/etiketle ayrışır.
      'VIZE' || 'FINAL' || 'BUT' => courseColor('red'),
      _ => courseColor('gray'),
    };

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    this.body = '',
    this.truncated = false,
    this.department,
    this.faculty,
    this.grade,
    this.pinned = false,
    this.publishAt,
    this.attachmentUrl,
    this.read = false,
  });

  final int id;
  final String title, body;
  final bool truncated, pinned, read;
  final String? department, faculty, grade, attachmentUrl;
  final DateTime? publishAt;

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: _i(j['id']),
        title: _s(j['title']),
        body: _s(j['body']),
        truncated: j['bodyTruncated'] == true,
        department: _sn(j['department']),
        faculty: _sn(j['faculty']),
        grade: _sn(j['grade']),
        pinned: j['pinned'] == true,
        publishAt: parseInstant(j['publishAt'] ?? j['createdAt']),
        attachmentUrl: _sn(j['attachmentUrl']),
        read: j['read'] == true,
      );

  Announcement asRead() => Announcement(
      id: id,
      title: title,
      body: body,
      truncated: truncated,
      department: department,
      faculty: faculty,
      grade: grade,
      pinned: pinned,
      publishAt: publishAt,
      attachmentUrl: attachmentUrl,
      read: true);
}

String two(int n) => n.toString().padLeft(2, '0');

/// "10 Kasım 2026 · 10:00" (İstanbul)
String fmtInstant(DateTime i, {bool time = true}) {
  final w = istanbulWall(i);
  final d = '${w.day} ${monthNames[w.month - 1]} ${w.year}';
  return time ? '$d · ${two(w.hour)}:${two(w.minute)}' : d;
}

String fmtWallDate(DateTime d) => '${d.day} ${monthNames[d.month - 1]} ${d.year}';

/// Dile göre "10 Kasım 2026 · 10:00" (İstanbul).
String fmtInstantL(AppLocalizations l, DateTime i, {bool time = true}) {
  final w = istanbulWall(i);
  final d = '${w.day} ${monthNameL(l, w.month)} ${w.year}';
  return time ? '$d · ${two(w.hour)}:${two(w.minute)}' : d;
}

String fmtWallDateL(AppLocalizations l, DateTime d) => '${d.day} ${monthNameL(l, d.month)} ${d.year}';

// ---------------------------------------------------------------- ICS

String _icsEscape(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll(';', '\\;').replaceAll(',', '\\,').replaceAll('\r\n', '\\n').replaceAll('\n', '\\n');

String _icsLocal(DateTime wall, int minutes) {
  final d = wall.add(Duration(minutes: minutes));
  return '${d.year.toString().padLeft(4, '0')}${two(d.month)}${two(d.day)}T${two(d.hour)}${two(d.minute)}00';
}

String _icsUtc(DateTime instant) {
  final d = instant.toUtc();
  return '${d.year.toString().padLeft(4, '0')}${two(d.month)}${two(d.day)}T${two(d.hour)}${two(d.minute)}${two(d.second)}Z';
}

/// Ders programı + sınavlar için `.ics` metni. Her oturum haftalık tekrarlanır (dönem sonuna ya da 16 haftaya kadar).
String buildIcs(List<Course> courses, Semester? semester, List<Exam> exams, {DateTime? now, AppLocalizations? l}) {
  final stamp = _icsUtc(now ?? academicClock());
  final nowWall = istanbulWall(now ?? academicClock());
  final b = StringBuffer()
    ..write('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BU Kampus//Ders Programi//TR\r\nCALSCALE:GREGORIAN\r\n')
    ..write('X-WR-TIMEZONE:Europe/Istanbul\r\n')
    ..write('BEGIN:VTIMEZONE\r\nTZID:Europe/Istanbul\r\nBEGIN:STANDARD\r\nDTSTART:19700101T000000\r\n'
        'TZOFFSETFROM:+0300\r\nTZOFFSETTO:+0300\r\nTZNAME:+03\r\nEND:STANDARD\r\nEND:VTIMEZONE\r\n');
  final base = semester?.startDate ?? DateTime.utc(nowWall.year, nowWall.month, nowWall.day);
  for (final c in courses) {
    for (final s in c.sessions) {
      var first = DateTime.utc(base.year, base.month, base.day);
      while (first.weekday != s.dayOfWeek) {
        first = first.add(const Duration(days: 1));
      }
      final desc = [if (c.instructor != null) c.instructor!, if (c.code != null) c.code!, if (c.note != null) c.note!].join(' - ');
      final until = semester?.endDate;
      final rule = until != null
          ? 'RRULE:FREQ=WEEKLY;UNTIL=${_icsUtc(wallToInstant(until.year, until.month, until.day, 23, 59))}'
          : 'RRULE:FREQ=WEEKLY;COUNT=16';
      b
        ..write('BEGIN:VEVENT\r\nUID:bu-ders-${c.id}-${s.id ?? s.dayOfWeek}-${s.start.replaceAll(':', '')}@bingol.edu.tr\r\n')
        ..write('DTSTAMP:$stamp\r\n')
        ..write('DTSTART;TZID=Europe/Istanbul:${_icsLocal(first, s.startMin)}\r\n')
        ..write('DTEND;TZID=Europe/Istanbul:${_icsLocal(first, s.endMin)}\r\n')
        ..write('$rule\r\n')
        ..write('SUMMARY:${_icsEscape(c.name)}\r\n');
      if (s.room != null) b.write('LOCATION:${_icsEscape(s.room!)}\r\n');
      if (desc.isNotEmpty) b.write('DESCRIPTION:${_icsEscape(desc)}\r\n');
      b.write('END:VEVENT\r\n');
    }
  }
  for (final e in exams) {
    final st = istanbulWall(e.startsAt);
    final en = e.endsAt != null ? istanbulWall(e.endsAt!) : st.add(const Duration(hours: 1));
    final day = DateTime.utc(st.year, st.month, st.day);
    b
      ..write('BEGIN:VEVENT\r\nUID:bu-sinav-${e.id}@bingol.edu.tr\r\nDTSTAMP:$stamp\r\n')
      ..write('DTSTART;TZID=Europe/Istanbul:${_icsLocal(day, st.hour * 60 + st.minute)}\r\n')
      ..write('DTEND;TZID=Europe/Istanbul:${_icsLocal(DateTime.utc(en.year, en.month, en.day), en.hour * 60 + en.minute)}\r\n')
      ..write('SUMMARY:${_icsEscape('${l != null ? examTypeLabelL(l, e.type) : examTypeLabel(e.type)}: ${e.title}')}\r\n');
    if (e.room != null) b.write('LOCATION:${_icsEscape(e.room!)}\r\n');
    b.write('END:VEVENT\r\n');
  }
  b.write('END:VCALENDAR\r\n');
  return b.toString();
}
