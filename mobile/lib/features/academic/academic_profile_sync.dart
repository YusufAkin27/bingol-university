import 'dart:async';

import '../../core/session.dart';
import '../widgets/widget_snapshots.dart' show WidgetSlug;
import '../widgets/widget_sync_service.dart';
import 'academic_api.dart';
import 'reminders.dart';

/// Profildeki fakülte/bölüm/sınıf değişti (PATCH /users/me başarılı). Sunucu resmi programdan kopyalanmış kişisel ders
/// programını yeni bölüme göre kendisi yeniler; burada istemci tarafı hemen eşitlenir: ders/sınav/akademik önbelleği
/// bayatlar, açık ekranlar [Session.academicProfileSignal] ile yeniden yüklenir, ana ekran widget'ları tazelenir ve
/// kurulu ders hatırlatıcıları yeni programdan yeniden kurulur. Hatalar yutulur (en iyi çaba).
void onAcademicProfileChanged(Session session) {
  final api = session.api;
  for (final p in const ['/timetable', '/academic', '/news/unit', '/me/summary', '/users/me']) {
    api.invalidate(p);
  }
  session.academicProfileSignal.value++;
  WidgetSyncService.instance.request(const {WidgetSlug.timetable, WidgetSlug.exams});
  unawaited(ReminderService.sync(AcademicApi(session)));
}
