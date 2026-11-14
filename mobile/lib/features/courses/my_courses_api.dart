import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../../core/session.dart';
import 'my_courses_models.dart';

/// Öğrenci "Derslerim" uçları. Tek HTTP katmanı: `Session.api`.
class MyCoursesApi {
  MyCoursesApi(this.session);

  final Session session;

  Future<List<MyCourse>> courses() async =>
      [for (final j in listOfMaps(await session.api.get('/my-courses'))) MyCourse.fromJson(j)];

  /// Bir sayfa duyuru (yeniden eskiye); sonraki sayfa için önceki yanıtın `nextCursor` değeri verilir.
  Future<NoticePage> notices(int courseId, {String? cursor}) async {
    final q = cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}';
    return NoticePage.fromJson(await session.api.get('/my-courses/$courseId/notices?size=50$q'));
  }

  Future<List<CourseNotice>> upcoming() async =>
      [for (final j in listOfMaps(await session.api.get('/my-courses/upcoming'))) CourseNotice.fromJson(j)];

  /// Eki yetkili istemciyle indirir (sunucu `Content-Disposition: attachment` döner; hiçbir zaman herkese açık adres yoktur).
  Future<List<int>> fileBytes(int courseId, int noticeId, int fileId) =>
      session.api.getBytes('/my-courses/$courseId/notices/$noticeId/files/$fileId', accept: '*/*');
}

/// Test kancası: sistem paylaşım sayfası çağrısı. Varsayılan `share_plus` (uygulamanın var olan belge/dosya teslim yolu:
/// profil QR görseli de böyle verilir). Bellekten verilir: diske dosya yazılmaz, önbellek kuralları değişmez.
Future<void> Function(ShareParams)? debugNoticeFileShare;

/// Dosya adını güvenli hale getirir: yol ayırıcı ve denetim karakterleri atılır, boşsa varsayılan ad verilir.
String safeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[/\\\u0000-\u001f\u007f]'), '_').trim();
  return cleaned.isEmpty ? 'ek' : cleaned;
}

/// Eki indirir ve sistem paylaşım sayfasıyla "aç / kaydet" için sunar. Hata fırlatabilir ([ApiError] ya da başka).
Future<void> openNoticeFile(Session session, int courseId, int noticeId, NoticeFile file, {String? title}) async {
  final bytes = await MyCoursesApi(session).fileBytes(courseId, noticeId, file.id);
  final name = safeFileName(file.name);
  // `getBytes` zaten Uint8List döndürür (yanıt gövdesi): gereksiz üçüncü kopya yapılmaz.
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final params = ShareParams(
    title: title,
    files: [
      XFile.fromData(data,
          mimeType: file.contentType.isEmpty ? 'application/octet-stream' : file.contentType, name: name),
    ],
    fileNameOverrides: [name],
  );
  await (debugNoticeFileShare ?? (p) => SharePlus.instance.share(p))(params);
}
