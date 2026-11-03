import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/reminders.dart';
import 'package:bu_kampus/features/academic/timetable_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Sözleşme A (mobil): resmî ders programından gelen program, birim seçici ve "yeniden yükle" akışı.
/// Pazartesi 2026-11-02 08:00 (İstanbul) = 05:00Z.
final _now = DateTime.utc(2026, 11, 2, 5, 0);

class _Platform implements ReminderPlatform {
  @override
  Future<void> replaceAll(List<PlannedReminder> items) async {}

  @override
  Future<bool> shareText(String text, String subject) async => true;
}

Map<String, dynamic> _course(String name, int day, String start, String end, {String? instructor, String color = 'teal'}) => {
      'name': name,
      'code': null,
      'instructor': instructor,
      'color': color,
      'note': null,
      'semesterId': 3,
      'sessions': [
        {'id': 1, 'dayOfWeek': day, 'start': start, 'end': end, 'room': null}
      ],
    };

/// Çocuk Gelişimi iki MYO'da var: boş kişisel program + iki birim.
FakeAcademic _twoUnits(FakeBackend b) {
  final f = fakeAcademic(b);
  f.officialByUnit['Bingöl MYO'] = [_course('Çocuk Gelişimine Giriş', 1, '09:00', '10:50', instructor: 'Dr. Öğr. Üyesi A')];
  f.officialByUnit['Genç MYO'] = [_course('Çocuk Psikolojisi', 1, '13:00', '14:50', instructor: 'Dr. Öğr. Üyesi B')];
  return f;
}

Future<void> _load(WidgetTester tester, FakeBackend b, {Size size = kPhoneMedium, Brightness br = Brightness.light}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(TimetablePage(session: makeSession(b)), brightness: br, size: size));
  await settle(tester, const Duration(seconds: 2));
}

void main() {
  setUpAll(loadTestFonts);
  setUp(() {
    academicClock = () => _now;
    ReminderService.platform = _Platform();
    ReminderService.store = MemoryReminderStore();
  });
  tearDown(() {
    academicClock = DateTime.now;
    ReminderService.platform = const ChannelReminderPlatform();
    ReminderService.store = const SecureReminderStore();
  });

  group('model', () {
    test('durum ayrıştırma ve needsUnitPick', () {
      final st = OfficialTimetableStatus.fromJson({'available': true, 'applied': false, 'term': '2026-2027 Güz', 'units': ['A MYO', 'B MYO', '']});
      expect(st.units, ['A MYO', 'B MYO']);
      expect(st.needsUnitPick, isTrue);
      expect(const OfficialTimetableStatus(available: true, units: ['A']).needsUnitPick, isFalse);
      expect(const OfficialTimetableStatus(available: true, applied: true, units: ['A', 'B']).needsUnitPick, isFalse);
      expect(OfficialTimetableStatus.fromJson(const {}).available, isFalse);
    });

    test('ders modeli kod/not/derslik okumaz', () {
      final c = Course.fromJson({
        'id': 1,
        'name': 'Fizik',
        'code': 'FIZ101',
        'note': 'x',
        'color': 'green',
        'sessions': [
          {'id': 2, 'dayOfWeek': 1, 'start': '09:00', 'end': '10:00', 'room': 'B-204'}
        ],
      });
      expect(c.sessions.single.toJson().keys, unorderedEquals(['dayOfWeek', 'start', 'end']));
      expect(c.color, 'green');
    });
  });

  group('birim seçici', () {
    testWidgets('boş program + birden çok birim: alt sayfa açılır, seçim apply gönderir', (tester) async {
      final b = FakeBackend();
      final f = _twoUnits(b);
      await _load(tester, b);
      expect(b.requests, contains('GET /timetable/official/status'));
      expect(find.text('Birimini seç'), findsOneWidget); // alt sayfa başlığı
      expect(find.text('2026-2027 Güz'), findsWidgets); // dönem alt başlığı
      expect(find.text('Bingöl MYO'), findsOneWidget);
      expect(find.text('Genç MYO'), findsOneWidget);
      await tester.tap(find.text('Genç MYO'));
      await settle(tester, const Duration(seconds: 2));
      expect(b.bodies['POST /timetable/official/apply'], {'unit': 'Genç MYO'});
      expect(f.courses.single['name'], 'Çocuk Psikolojisi');
      expect(find.text('Çocuk Psikolojisi'), findsOneWidget);
      expect(find.text('Dr. Öğr. Üyesi B'), findsOneWidget);
      expect(find.textContaining('Henüz ders eklemedin'), findsNothing);
      await unmount(tester);
    });

    testWidgets('alt sayfa kapatılırsa boş durum birim seçtirmeye devam eder, elle ders ekleme açık kalır', (tester) async {
      final b = FakeBackend();
      _twoUnits(b);
      await _load(tester, b);
      await tester.tapAt(const Offset(195, 40)); // sheet dışı: kapat
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Resmî ders programı hazır'), findsOneWidget);
      expect(find.text('Birimi seç'), findsOneWidget);
      expect(find.text('İlk dersini ekle'), findsOneWidget);
      expect(b.bodies.containsKey('POST /timetable/official/apply'), isFalse);
      await tester.tap(find.text('Birimi seç'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Bingöl MYO'), findsOneWidget);
      await tester.tap(find.text('Bingöl MYO'));
      await settle(tester, const Duration(seconds: 2));
      expect(b.bodies['POST /timetable/official/apply'], {'unit': 'Bingöl MYO'});
      expect(find.text('Çocuk Gelişimine Giriş'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('apply hatası toast gösterir, boş durum kalır', (tester) async {
      final b = FakeBackend();
      final f = _twoUnits(b);
      await _load(tester, b);
      f.officialByUnit.clear(); // sunucu: resmî program artık yok -> 404
      await tester.tap(find.text('Bingöl MYO'));
      await settle(tester, const Duration(seconds: 2));
      expect(f.courses, isEmpty);
      expect(find.text('Resmî program yok.'), findsWidgets);
      await unmount(tester);
    });

    testWidgets('tek birim / resmî yok / uygulanmış: kendiliğinden sayfa açılmaz', (tester) async {
      // resmî program yok -> mevcut boş durum
      final b = FakeBackend();
      fakeAcademic(b);
      await _load(tester, b);
      expect(find.textContaining('Henüz ders eklemedin'), findsOneWidget);
      expect(find.byTooltip('Daha fazla'), findsNothing);
      await unmount(tester);

      // tek birim: sunucu tohumlar; istemci birim sormaz
      final b2 = FakeBackend();
      final f2 = fakeAcademic(b2);
      f2.officialByUnit['Bingöl MYO'] = [_course('Fizik', 1, '09:00', '10:50')];
      await _load(tester, b2);
      expect(find.text('Birimini seç'), findsNothing);
      expect(find.text('Resmî ders programı hazır'), findsNothing);
      await unmount(tester);

      // iki birim ama daha önce uygulanmış (kullanıcı hepsini sildi): yeniden sorulmaz
      final b3 = FakeBackend();
      final f3 = _twoUnits(b3)..officialApplied = true;
      expect(f3.courses, isEmpty);
      await _load(tester, b3);
      expect(find.text('Birimini seç'), findsNothing);
      expect(find.textContaining('Henüz ders eklemedin'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('durum ucu hata verirse program yine çizilir (menü yok)', (tester) async {
      final b = FakeBackend();
      final f = fakeAcademic(b)..addCourse('Fizik', 1, '09:00', '10:50');
      expect(f.courses, hasLength(1));
      b.handlers.insert(0, (req, path) => path == '/timetable/official/status' ? const FakeResult.json({'code': 'X', 'message': 'x'}, status: 500) : null);
      await _load(tester, b);
      expect(find.text('Fizik'), findsOneWidget);
      expect(find.byTooltip('Daha fazla'), findsNothing);
      await unmount(tester);
    });
  });

  group('yeniden yükle', () {
    FakeBackend dolu({int units = 1}) {
      final b = FakeBackend();
      final f = fakeAcademic(b);
      f.officialByUnit['Bingöl MYO'] = [_course('Resmî Ders', 1, '09:00', '10:50')];
      if (units > 1) f.officialByUnit['Genç MYO'] = [_course('Genç Resmî Ders', 1, '09:00', '10:50')];
      f.officialApplied = true;
      f.addCourse('Kendi Eklediğim', 1, '13:00', '14:50');
      return b;
    }

    testWidgets('menü -> onay -> replace:true; kişisel dersler gider', (tester) async {
      final b = dolu();
      await _load(tester, b);
      expect(find.text('Kendi Eklediğim'), findsOneWidget);
      await tester.tap(find.byTooltip('Daha fazla'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Resmî programı yeniden yükle'), findsOneWidget);
      await tester.tap(find.text('Resmî programı yeniden yükle'));
      await settle(tester, const Duration(seconds: 1));
      // onay: kişisel değişiklikler silinir uyarısı
      expect(find.text('Resmî program yeniden yüklensin mi?'), findsOneWidget);
      expect(find.textContaining('kişisel değişiklikler'), findsOneWidget);
      expect(b.bodies.containsKey('POST /timetable/official/apply'), isFalse);
      await tester.tap(find.text('Yeniden yükle'));
      await settle(tester, const Duration(seconds: 2));
      expect(b.bodies['POST /timetable/official/apply'], {'unit': 'Bingöl MYO', 'replace': true});
      expect(find.text('Kendi Eklediğim'), findsNothing);
      expect(find.text('Resmî Ders'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('onayda vazgeçilirse istek gitmez', (tester) async {
      final b = dolu();
      await _load(tester, b);
      await tester.tap(find.byTooltip('Daha fazla'));
      await settle(tester, const Duration(seconds: 1));
      await tester.tap(find.text('Resmî programı yeniden yükle'));
      await settle(tester, const Duration(seconds: 1));
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, const Duration(seconds: 1));
      expect(b.bodies.containsKey('POST /timetable/official/apply'), isFalse);
      expect(find.text('Kendi Eklediğim'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('birden çok birimde önce birim sorulur, sonra onay', (tester) async {
      final b = dolu(units: 2);
      await _load(tester, b);
      await tester.tap(find.byTooltip('Daha fazla'));
      await settle(tester, const Duration(seconds: 1));
      await tester.tap(find.text('Resmî programı yeniden yükle'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Birimini seç'), findsOneWidget);
      await tester.tap(find.text('Genç MYO'));
      await settle(tester, const Duration(seconds: 1));
      await tester.tap(find.text('Yeniden yükle'));
      await settle(tester, const Duration(seconds: 2));
      expect(b.bodies['POST /timetable/official/apply'], {'unit': 'Genç MYO', 'replace': true});
      expect(find.text('Genç Resmî Ders'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('taşma (320/390, açık/koyu)', () {
    for (final br in Brightness.values) {
      for (final size in [kPhoneSmall, kPhoneMedium]) {
        testWidgets('birim seçici + boş durum ${br.name} ${size.width.toInt()}', (tester) async {
          final b = FakeBackend();
          final f = fakeAcademic(b);
          f.officialByUnit['Çok Uzun İsimli Meslek Yüksekokulu Çocuk Gelişimi Programı Bingöl Kampüsü'] = [_course('A', 1, '09:00', '10:00')];
          f.officialByUnit['Genç Meslek Yüksekokulu'] = [_course('B', 1, '09:00', '10:00')];
          await _load(tester, b, size: size, br: br);
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(10, 20));
          await settle(tester, const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          expect(find.text('Resmî ders programı hazır'), findsOneWidget);
          await unmount(tester);
        });

        testWidgets('sade ders kartı ${br.name} ${size.width.toInt()}', (tester) async {
          final b = FakeBackend();
          final f = fakeAcademic(b)
            ..addCourse('Çok Uzun Bir Ders Adı: Sayısal Analiz ve Programlama Uygulamaları', 1, '09:00', '10:50',
                instructor: 'Prof. Dr. Mehmet Ali Yıldırım Karaca');
          expect(f.courses, hasLength(1));
          await _load(tester, b, size: size, br: br);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });
}
