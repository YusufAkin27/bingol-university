import '../../core/session.dart';
import 'academic_models.dart';

/// Akademik uçlar (docs/API_CONTRACTS_V2.md, "Akademik"). Tek HTTP katmanı: `Session.api`.
class AcademicApi {
  AcademicApi(this.session);

  final Session session;

  Map<String, dynamic> _map(dynamic v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
  List<Map<String, dynamic>> _items(dynamic v) =>
      [for (final e in (_map(v)['items'] as List? ?? const [])) if (e is Map) e.cast<String, dynamic>()];

  // ---- ders programı
  Future<TimetableData> timetable({int? semesterId}) async =>
      TimetableData.fromJson(_map(await session.api.get('/timetable${semesterId == null ? '' : '?semesterId=$semesterId'}')));

  Future<Course> createCourse(Map<String, dynamic> body) async =>
      Course.fromJson(_map(await session.api.post('/timetable/courses', body)));

  Future<Course> updateCourse(int id, Map<String, dynamic> body) async =>
      Course.fromJson(_map(await session.api.patch('/timetable/courses/$id', body)));

  Future<void> deleteCourse(int id) async => session.api.delete('/timetable/courses/$id');

  // ---- dönemler
  Future<({List<Semester> items, Map<String, dynamic>? official})> semesters() async {
    final m = _map(await session.api.get('/timetable/semesters'));
    return (
      items: [for (final e in _items(m)) Semester.fromJson(e)],
      official: m['officialCurrent'] is Map ? (m['officialCurrent'] as Map).cast<String, dynamic>() : null,
    );
  }

  Future<Semester> createSemester(String name, DateTime start, DateTime end, {bool current = true}) async =>
      Semester.fromJson(_map(await session.api.post('/timetable/semesters',
          {'name': name, 'startDate': isoDate(start), 'endDate': isoDate(end), 'current': current})));

  Future<Semester> semesterFromOfficial() async =>
      Semester.fromJson(_map(await session.api.post('/timetable/semesters/from-official')));

  Future<void> makeCurrent(int id) async => session.api.patch('/timetable/semesters/$id', {'current': true});

  Future<void> deleteSemester(int id) async => session.api.delete('/timetable/semesters/$id');

  // ---- sınavlar
  Future<List<Exam>> exams() async => [for (final e in _items(await session.api.get('/timetable/exams'))) Exam.fromJson(e)];

  Future<List<Exam>> upcomingExams({int days = 30}) async =>
      [for (final e in _items(await session.api.get('/timetable/exams/upcoming?days=$days'))) Exam.fromJson(e)];

  Future<Exam> createExam(Map<String, dynamic> body) async => Exam.fromJson(_map(await session.api.post('/timetable/exams', body)));

  Future<Exam> updateExam(int id, Map<String, dynamic> body) async =>
      Exam.fromJson(_map(await session.api.patch('/timetable/exams/$id', body)));

  Future<void> deleteExam(int id) async => session.api.delete('/timetable/exams/$id');

  Future<({List<OfficialExam> items, bool profileComplete})> officialExams({bool all = false}) async {
    final m = _map(await session.api.get('/exams/official${all ? '?scope=all' : ''}'));
    return (items: [for (final e in _items(m)) OfficialExam.fromJson(e)], profileComplete: m['profileComplete'] != false);
  }

  // ---- akademik takvim
  Future<List<AcademicEvent>> calendar(int year, int month) async =>
      [for (final e in _items(await session.api.get('/academic/calendar?month=$year-${two(month)}'))) AcademicEvent.fromJson(e)];

  Future<List<AcademicEvent>> nextEvents({int limit = 5}) async =>
      [for (final e in _items(await session.api.get('/academic/calendar/next?limit=$limit'))) AcademicEvent.fromJson(e)];

  // ---- duyurular
  Future<({List<Announcement> items, String? next})> announcements({bool mine = true, String? cursor, int size = 20}) async {
    final q = 'scope=${mine ? 'mine' : 'all'}&size=$size${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}';
    final m = _map(await session.api.get('/announcements?$q'));
    final next = m['nextCursor'];
    return (items: [for (final e in _items(m)) Announcement.fromJson(e)], next: next is String && next.isNotEmpty ? next : null);
  }

  Future<Announcement> announcement(int id) async => Announcement.fromJson(_map(await session.api.get('/announcements/$id')));

  Future<void> markRead(int id) async => session.api.post('/announcements/$id/read');

  Future<void> readAll() async => session.api.post('/announcements/read-all');

  Future<int> unreadCount() async {
    final c = _map(await session.api.get('/announcements/unread-count'))['count'];
    return c is num ? c.toInt() : 0;
  }
}
