import '../../core/session.dart';
import 'academic_models.dart';
import '../widgets/widget_snapshots.dart' show WidgetSlug;
import '../widgets/widget_sync_service.dart';

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

  // Ders eklenince/değişince/silinince ana ekran ders widget'ı tazelenir (sessiz, debounce'lu).
  void _widgetTimetable() => WidgetSyncService.instance.request(const {WidgetSlug.timetable});

  Future<Course> createCourse(Map<String, dynamic> body) async {
    final c = Course.fromJson(_map(await session.api.post('/timetable/courses', body)));
    _widgetTimetable();
    return c;
  }

  Future<Course> updateCourse(int id, Map<String, dynamic> body) async {
    final c = Course.fromJson(_map(await session.api.patch('/timetable/courses/$id', body)));
    _widgetTimetable();
    return c;
  }

  Future<void> deleteCourse(int id) async {
    await session.api.delete('/timetable/courses/$id');
    _widgetTimetable();
  }

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

  // ---- akademik takvim
  Future<List<AcademicEvent>> calendar(int year, int month) async =>
      [for (final e in _items(await session.api.get('/academic/calendar?month=$year-${two(month)}'))) AcademicEvent.fromJson(e)];

  /// Tarih aralığı (en çok 366 gün; aralıkla kesişen kayıtlar gelir).
  Future<List<AcademicEvent>> calendarRange(DateTime from, DateTime to) async => [
        for (final e in _items(await session.api.get('/academic/calendar?from=${isoDate(from)}&to=${isoDate(to)}'))) AcademicEvent.fromJson(e)
      ];

  Future<List<AcademicEvent>> nextEvents({int limit = 5}) async =>
      [for (final e in _items(await session.api.get('/academic/calendar/next?limit=$limit'))) AcademicEvent.fromJson(e)];
}
