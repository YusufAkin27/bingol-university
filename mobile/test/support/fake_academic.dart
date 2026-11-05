import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fake_app.dart';

/// Akademik uçların durumlu sahte uygulaması (docs/API_CONTRACTS_V2.md "Akademik").
class FakeAcademic {
  FakeAcademic(this.b) {
    b.handlers.add(handle);
  }

  final FakeBackend b;
  int _id = 100;

  Map<String, dynamic>? semester = {
    'id': 3,
    'name': '2026-2027 Güz',
    'startDate': '2026-09-14',
    'endDate': '2027-01-15',
    'current': true,
  };
  final List<Map<String, dynamic>> courses = [];
  final List<Map<String, dynamic>> exams = [];
  List<Map<String, dynamic>> events = [];

  /// Çakışma 409'u üretmek için: true iken `force` yoksa her yazma 409 döner.
  bool conflictOnce = false;

  Map<String, dynamic> addCourse(String name, int day, String start, String end,
      {String? room, String? instructor, String color = 'blue', String? code}) {
    final c = {
      'id': ++_id,
      'name': name,
      'code': code,
      'instructor': instructor,
      'color': color,
      'note': null,
      'semesterId': 3,
      'sessions': [
        {'id': ++_id, 'dayOfWeek': day, 'start': start, 'end': end, 'room': room}
      ],
    };
    courses.add(c);
    return c;
  }

  Map<String, dynamic> addExam(String title, String startsAt, {String type = 'VIZE', int? courseId}) {
    final e = {
      'id': ++_id,
      'courseId': courseId,
      'courseName': null,
      'title': title,
      'type': type,
      'startsAt': startsAt,
      'endsAt': null,
      'room': 'B-204',
      'note': null,
    };
    exams.add(e);
    return e;
  }

  FakeResult _j(Object? j, [int status = 200]) => FakeResult.json(j, status: status);

  FakeResult? handle(http.Request req, String path) {
    final m = req.method;
    Map<String, dynamic> body() => req.body.isEmpty ? {} : (jsonDecode(req.body) as Map).cast<String, dynamic>();

    if (path == '/timetable' && m == 'GET') return _j({'semester': semester, 'courses': courses});
    if (path == '/timetable/courses' && m == 'POST') {
      final bd = body();
      if (conflictOnce && bd['force'] != true) {
        return _j({'code': 'COURSE_CONFLICT', 'message': 'Veri Yapıları ile çakışıyor (09:00-10:50).'}, 409);
      }
      final c = {
        'id': ++_id,
        'name': bd['name'],
        'code': bd['code'],
        'instructor': bd['instructor'],
        'color': bd['color'] ?? 'blue',
        'note': bd['note'],
        'semesterId': bd['semesterId'],
        'sessions': [for (final s in (bd['sessions'] as List)) {...(s as Map).cast<String, dynamic>(), 'id': ++_id}],
      };
      courses.add(c);
      return _j(c, 201);
    }
    final cm = RegExp(r'^/timetable/courses/(\d+)$').firstMatch(path);
    if (cm != null) {
      final id = int.parse(cm.group(1)!);
      final i = courses.indexWhere((c) => c['id'] == id);
      if (i < 0) return _j({'code': 'COURSE_NOT_FOUND', 'message': 'Ders yok'}, 404);
      if (m == 'DELETE') {
        courses.removeAt(i);
        return const FakeResult.json(null, status: 204);
      }
      if (m == 'PATCH') {
        courses[i] = {...courses[i], ...body()};
        return _j(courses[i]);
      }
    }
    if (path == '/timetable/semesters' && m == 'GET') {
      return _j({
        'items': [if (semester != null) semester],
        'officialCurrent': {'name': '2026-2027 Güz', 'startDate': '2026-09-14', 'endDate': '2027-01-15'},
      });
    }
    if (path == '/timetable/exams' && m == 'GET') return _j({'items': exams});
    if (path == '/timetable/exams/upcoming') return _j({'items': exams});
    if (path == '/timetable/exams' && m == 'POST') {
      final bd = body();
      final e = {'id': ++_id, 'courseName': null, 'endsAt': null, 'room': null, 'note': null, ...bd};
      exams.add(e);
      return _j(e, 201);
    }
    final em = RegExp(r'^/timetable/exams/(\d+)$').firstMatch(path);
    if (em != null && m == 'DELETE') {
      exams.removeWhere((e) => e['id'] == int.parse(em.group(1)!));
      return const FakeResult.json(null, status: 204);
    }
    if (path == '/academic/calendar') return _j({'from': '2026-11-01', 'to': '2026-11-30', 'items': events});
    if (path == '/academic/calendar/next') return _j({'items': events});
    return null;
  }
}

FakeAcademic fakeAcademic(FakeBackend b) => FakeAcademic(b);
