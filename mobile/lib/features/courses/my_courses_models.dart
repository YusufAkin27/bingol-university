/// "Derslerim" (öğrenci) veri modelleri: `GET /my-courses`, `/my-courses/{id}/notices`, `/my-courses/upcoming`.
/// Ayrıştırma bilerek hoşgörülüdür: eksik/yeni alanlar ve bilinmeyen duyuru türleri eski uygulamayı bozmaz.
library;

/// Duyuru türleri (sunucu sabitleri). Bilinmeyen tür metni olduğu gibi tutulur ve genel satır olarak çizilir.
abstract final class NoticeType {
  static const lessonStarted = 'LESSON_STARTED';
  static const attendanceStarted = 'ATTENDANCE_STARTED';
  static const exam = 'EXAM';
  static const assignment = 'ASSIGNMENT';
  static const material = 'MATERIAL';
  static const lessonCancelled = 'LESSON_CANCELLED';
  static const roomChanged = 'ROOM_CHANGED';
}

String _s(Object? v) => v is String ? v : '';
String? _sn(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
bool _b(Object? v) => v == true;
DateTime? _d(Object? v) => v is String ? DateTime.tryParse(v) : null;

Map<String, dynamic> _m(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

/// Listeyi çıkarır: düz dizi ya da `{items: [...]}` sarmalayıcısı.
List<Map<String, dynamic>> listOfMaps(Object? v) {
  final raw = v is Map ? v['items'] : v;
  return [for (final e in (raw is List ? raw : const [])) if (e is Map) e.cast<String, dynamic>()];
}

class AbsenceLimit {
  const AbsenceLimit(this.type, this.value);

  /// `COUNT` (ders sayısı) ya da `PERCENT` (yüzde).
  final String type;
  final int value;

  bool get isPercent => type.toUpperCase() == 'PERCENT';

  static AbsenceLimit? fromJson(Object? v) {
    if (v is! Map) return null;
    final m = _m(v);
    return AbsenceLimit(_s(m['type']), _i(m['value']));
  }
}

class MyCourse {
  const MyCourse({
    required this.courseId,
    required this.courseName,
    this.code,
    this.term,
    this.academicianName,
    this.presentCount = 0,
    this.absentCount = 0,
    this.sessionCount = 0,
    this.limit,
    this.atRisk = false,
    this.overLimit = false,
  });

  final int courseId;
  final String courseName;
  final String? code;
  final String? term;
  final String? academicianName;
  final int presentCount;
  final int absentCount;
  final int sessionCount;
  final AbsenceLimit? limit;
  final bool atRisk;
  final bool overLimit;

  factory MyCourse.fromJson(Map<String, dynamic> j) => MyCourse(
        courseId: _i(j['courseId']),
        courseName: _s(j['courseName']),
        code: _sn(j['code']),
        term: _sn(j['term']),
        academicianName: _sn(j['academicianName']),
        presentCount: _i(j['presentCount']),
        absentCount: _i(j['absentCount']),
        sessionCount: _i(j['sessionCount']),
        limit: AbsenceLimit.fromJson(j['limit']),
        atRisk: _b(j['atRisk']),
        overLimit: _b(j['overLimit']),
      );
}

class NoticeFile {
  const NoticeFile({required this.id, required this.name, this.contentType = '', this.sizeBytes = 0});

  final int id;
  final String name;
  final String contentType;
  final int sizeBytes;

  factory NoticeFile.fromJson(Map<String, dynamic> j) => NoticeFile(
        id: _i(j['id']),
        name: _s(j['name']),
        contentType: _s(j['contentType']),
        sizeBytes: _i(j['sizeBytes']),
      );
}

/// Ders duyurusu; `upcoming` yanıtında [courseId] ve [courseName] da dolar.
class CourseNotice {
  const CourseNotice({
    required this.id,
    required this.type,
    this.title,
    this.note,
    this.eventAt,
    this.createdAt,
    this.files = const [],
    this.courseId,
    this.courseName,
  });

  final int id;
  final String type;
  final String? title;
  final String? note;
  final DateTime? eventAt;
  final DateTime? createdAt;
  final List<NoticeFile> files;
  final int? courseId;
  final String? courseName;

  factory CourseNotice.fromJson(Map<String, dynamic> j) => CourseNotice(
        id: _i(j['id']),
        type: _s(j['type']).toUpperCase(),
        title: _sn(j['title']),
        note: _sn(j['note']),
        eventAt: _d(j['eventAt']),
        createdAt: _d(j['createdAt']),
        files: [for (final f in listOfMaps(j['files'])) NoticeFile.fromJson(f)],
        courseId: j['courseId'] == null ? null : _i(j['courseId']),
        courseName: _sn(j['courseName']),
      );
}

/// Duyuru sayfası: sunucu `{items, nextCursor}` döner (sayfa boyutu en çok 50); [nextCursor] null ise son sayfadır.
class NoticePage {
  const NoticePage(this.items, this.nextCursor);

  final List<CourseNotice> items;
  final String? nextCursor;

  factory NoticePage.fromJson(Object? v) {
    final cursor = v is Map ? v['nextCursor'] : null;
    return NoticePage(
      [for (final j in listOfMaps(v)) CourseNotice.fromJson(j)],
      cursor == null || '$cursor'.isEmpty ? null : '$cursor',
    );
  }
}

/// Yaklaşanları en yakın tarih önde olacak biçimde sıralar (tarihsizler sona).
List<CourseNotice> sortUpcoming(List<CourseNotice> items) {
  final out = [...items];
  out.sort((a, b) {
    final x = a.eventAt, y = b.eventAt;
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  });
  return out;
}

/// "1,2 MB" / "340 KB" / "12 B" biçiminde okunur boyut.
String humanSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
}
