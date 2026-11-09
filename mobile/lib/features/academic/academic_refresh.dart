import 'dart:async';

import '../../core/session.dart';
import '../widgets/widget_snapshots.dart' show WidgetSlug;
import '../widgets/widget_sync_service.dart';
import 'academic_api.dart';
import 'reminders.dart';

/// Sınıf veya bölüm değişti (profil kaydı): sunucu resmi ders programını yeni profile göre yeniden kurar. İstemcide
/// eski programı gösterebilecek her şey burada tazelenir: ağ önbelleği (ETag/LRU), açık ekranlar (`academicRevision`),
/// ana ekran widget'ları ve yerel ders/sınav hatırlatmaları. Hata sızdırmaz.
void notifyAcademicProfileChanged(Session session) {
  session.api.invalidate('/timetable');
  session.academicRevision.value++;
  WidgetSyncService.instance.request(const {WidgetSlug.timetable, WidgetSlug.exams});
  unawaited(ReminderService.sync(AcademicApi(session)));
}
