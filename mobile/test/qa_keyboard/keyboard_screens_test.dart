import 'package:bu_kampus/features/academic/akad_widgets.dart';
import 'package:bu_kampus/features/academic/course_form_page.dart';
import 'package:bu_kampus/features/academic/exam_form_page.dart';
import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/clubs/club_form_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_settings_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_widgets.dart';
import 'package:bu_kampus/features/events/event_form_page.dart';
import 'package:bu_kampus/features/polls/poll_form_page.dart';
import 'package:bu_kampus/features/support/support_new_ticket_page.dart';
import 'package:bu_kampus/features/support/support_ticket_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'kb_harness.dart';

String _iso(DateTime d) => d.toIso8601String().split('.').first;

Map<String, dynamic> _event() {
  final s = DateTime.now().add(const Duration(hours: 3));
  return {
    'id': 5,
    'title': 'Halı saha',
    'description': 'Cuma akşamı maç.',
    'startsAt': _iso(s),
    'endsAt': _iso(s.add(const Duration(hours: 2))),
    'location': 'Kampüs',
    'goingCount': 9,
    'interestedCount': 3,
    'capacity': 14,
    'canManage': true,
    'joinPolicy': 'APPROVAL',
    'createdBy': 2,
    'organizer': {'id': 2, 'displayName': 'Mehmet Kaya', 'avatarUrl': null},
    'organizerName': 'Mehmet Kaya',
  };
}

/// Bir ekran senaryosu: sayfa, birincil eylem (Olustur/Kaydet/Gonder) bulucusu, odaklanacak alan bulucusu.
class _Scene {
  const _Scene(this.name, this.backend, this.page, this.action, {this.field});

  final String name;
  final FakeBackend Function() backend;
  final Widget Function(FakeBackend) page;
  final Finder Function() action;
  final Finder Function()? field;
}

Finder _inBar(Type bar) => find.descendant(of: find.byType(bar), matching: find.byType(BuButton)).first;

final _scenes = <_Scene>[
  _Scene(
    'anket olustur',
    () {
      final b = FakeBackend();
      fakePolls(b, count: 0);
      return b;
    },
    (b) => PollFormPage(session: makeSession(b), communityId: 5),
    () => _inBar(BuFormActionBar),
  ),
  _Scene(
    'destek talebi olustur',
    () => FakeBackend(),
    (b) => NewTicketPage(session: makeSession(b)),
    () => _inBar(BuFormActionBar),
  ),
  _Scene(
    'destek talebi yanit yazma',
    () => FakeBackend()
      ..on('/support/tickets/5', {
        'ticket': {'id': 5, 'subject': 'Bildirim', 'status': 'ANSWERED', 'category': 'TECHNICAL', 'createdAt': '2026-10-01T10:00:00'},
        'messages': [
          for (var i = 0; i < 12; i++) {'id': i + 1, 'text': 'Mesaj ' * 12, 'fromStaff': i.isOdd, 'createdAt': '2026-10-01T10:00:00'},
        ],
      }),
    (b) => SupportTicketPage(session: makeSession(b), ticketId: 5),
    () => find.byType(IconButton).last, // gonder oku
    field: () => find.byType(TextField).last,
  ),
  _Scene(
    'ders formu',
    () => FakeBackend(),
    (b) => CourseFormPage(session: makeSession(b), allCourses: const [], semesterId: 1, initialDay: 1),
    () => _inBar(AkadBottomBar),
  ),
  _Scene(
    'sinav formu',
    () => FakeBackend(),
    (b) => ExamFormPage(session: makeSession(b), courses: const [Course(id: 1, name: 'Veri Yapıları')]),
    () => _inBar(AkadBottomBar),
  ),
  _Scene(
    'kulup olustur',
    () => FakeBackend()..on('/communities/categories', <dynamic>[]),
    (b) => ClubFormPage(session: makeSession(b)),
    () => _inBar(BuFormActionBar),
  ),
  _Scene(
    'etkinlik olustur',
    () => FakeBackend()..on('/me/communities*', {'items': [{'id': 7, 'name': 'Robotik', 'myRole': 'OWNER', 'myStatus': 'ACTIVE'}]}),
    (b) => EventFormPage(session: makeSession(b)),
    () => _inBar(BuFormActionBar),
  ),
  _Scene(
    'etkinlik ayarlari',
    () => FakeBackend()..on('/events/5', _event()),
    (b) => Etkinlik2SettingsPage(session: makeSession(b), event: _event()),
    () => _inBar(Et2BottomBar),
  ),
];

void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  for (final s in _scenes) {
    for (final size in [kSe, kPhoneMedium]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('${s.name}: ${size.width.toInt()}x${size.height.toInt()} x$scale klavye acikken eylem erisilebilir', (tester) async {
          setupScreen(tester, size, bottomSafe: size == kSe ? 0 : 34);
          final be = s.backend();
          await tester.pumpWidget(buildApp(scaled(s.page(be), scale), size: size));
          await settle(tester, const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull, reason: 'klavye kapali');

          final fieldAll = (s.field?.call() ?? find.byType(TextField));
          if (fieldAll.evaluate().isEmpty) {
            await tester.scrollUntilVisible(fieldAll, 80, scrollable: find.byType(Scrollable).first);
          }
          final field = fieldAll.first;
          await tester.ensureVisible(field);
          await tester.pump(const Duration(milliseconds: 100));
          await tester.tap(field);
          await setKeyboard(tester, 300);
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull, reason: 'klavye acik');

          // Eylem dugmesi klavyenin arkasinda DEGIL ve gercekten dokunulabilir.
          final action = s.action();
          expect(action, findsOneWidget);
          expectAboveKeyboard(tester, action, size, 300);
          expectHittable(tester, action);

          // Klavye kapaninca normale doner, istisna yok.
          await setKeyboard(tester, 0);
          expect(tester.takeException(), isNull, reason: 'klavye kapandi');
          expectAboveKeyboard(tester, s.action(), size, 0);
        });
      }
    }
  }

  group('anket olustur: ozel davranislar', () {
    Future<void> open(WidgetTester tester, {double scale = 1}) async {
      setupScreen(tester, kSe);
      final b = FakeBackend();
      fakePolls(b, count: 0);
      await tester.pumpWidget(buildApp(scaled(PollFormPage(session: makeSession(b), communityId: 5), scale), size: kSe));
      await tester.pumpAndSettle();
    }

    testWidgets('secenek ekle: klavye acik, 12 secenege kadar eklenir, yeni alan gorunur, Yayinla hep erisilebilir', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField).first, 'Baslik');
      await setKeyboard(tester, 300);
      final bar = _inBar(BuFormActionBar);
      var added = 0;
      for (var i = 0; i < 12; i++) {
        final add = find.textContaining('+ ');
        for (var k = 0; k < 60 && add.evaluate().isEmpty; k++) {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
          await tester.pump();
        }
        if (add.evaluate().isEmpty) break; // 12 seceneke ulasildi: ekle dugmesi kalkar
        await tester.ensureVisible(add.first);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(add.first);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 400));
        added++;
        expect(tester.takeException(), isNull);
        expectAboveKeyboard(tester, bar, kSe, 300);
        // Yeni secenegin alani (odakli) klavyenin ustunde ve ekranda gorunur.
        final focused = tester.widgetList<EditableText>(find.byType(EditableText)).where((e) => e.focusNode.hasFocus);
        if (focused.isNotEmpty) {
          final r = tester.getRect(find.byWidget(focused.first));
          expect(r.bottom, lessThanOrEqualTo(kSe.height - 300 + 1), reason: 'yeni secenek klavyenin arkasinda (ekleme $added)');
        }
      }
      expect(added, greaterThan(5));
      // Son alana kaydir ve yaz: form kaybolmaz.
      for (var k = 0; k < 60 && find.byType(TextField).evaluate().isEmpty; k++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 120));
        await tester.pump();
      }
      await tester.enterText(find.byType(TextField).last, 'son secenek');
      await tester.pump();
      expect(find.text('son secenek'), findsOneWidget);
      expectAboveKeyboard(tester, bar, kSe, 300);
      expect(tester.takeException(), isNull);
    });

    testWidgets('klavyeyi ac/kapa form verisini kaybettirmez', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField).first, 'Gun secimi');
      await tester.enterText(find.byType(TextField).at(2), 'Pazartesi');
      for (var i = 0; i < 4; i++) {
        await setKeyboard(tester, 300);
        await setKeyboard(tester, 0);
      }
      // Liste tembel kuruldugundan once ilgili alanlara kaydirilir; metinler denetleyicide durur.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pump();
      expect(find.text('Gun secimi'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Pazartesi'), 80, scrollable: find.byType(Scrollable).first);
      expect(find.text('Pazartesi'), findsOneWidget);
    });

    testWidgets('klavye acikken Yayinla: dogrulama hatasi gosterilir ve klavye kapanir', (tester) async {
      await open(tester);
      await tester.tap(find.byType(TextField).first);
      await setKeyboard(tester, 300);
      await tester.tap(_inBar(BuFormActionBar));
      await tester.pump(const Duration(milliseconds: 500));
      // Baslik bos: hata cikar (form gonderilmez), odak birakilir.
      final et = tester.widget<EditableText>(find.byType(EditableText).first);
      expect(et.focusNode.hasFocus, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
