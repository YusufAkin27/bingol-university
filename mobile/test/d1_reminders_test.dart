import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ayar anahtari hesap id icerir, bilinmiyorsa eski anahtar', () {
    expect(SecureReminderStore.keyFor(42), 'academic_reminders_42');
    expect(SecureReminderStore.keyFor(null), 'academic_reminders');
    expect(SecureReminderStore.keyFor(1) == SecureReminderStore.keyFor(2), false);
  });

  test('plan iOS 64 sinirinin altinda kalir; kapatinca bos', () {
    final courses = [
      for (var d = 1; d <= 7; d++)
        Course(id: d, name: 'D$d', color: 'blue', sessions: [CourseSession(dayOfWeek: d, start: '09:00', end: '10:00')]),
    ];
    final now = DateTime.utc(2026, 11, 2, 0, 0);
    final on = planReminders(courses: courses, semester: null, exams: [], settings: const ReminderSettings(), now: now);
    expect(on.isNotEmpty && on.length <= 40, true);
    final off = planReminders(courses: courses, semester: null, exams: [], settings: const ReminderSettings(classEnabled: false), now: now);
    expect(off, isEmpty);
    final lead = planReminders(courses: courses, semester: null, exams: [], settings: const ReminderSettings(classLeadMin: 30), now: now);
    expect(lead.first.at, DateTime.utc(2026, 11, 2, 5, 30)); // 09:00 Istanbul - 30 dk
  });
}
