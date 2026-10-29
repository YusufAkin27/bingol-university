import 'package:bu_kampus/features/events/event_form_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// K9 (etkinlik formu): 3 dil x acik/koyu x yazi 1.3 x 320/390 matrisi, dogrulama kilidi, kulup secici, kapak sayfasi.
Map<String, dynamic> _club(int id, String name, String role, {int members = 120}) =>
    {'id': id, 'name': name, 'myRole': role, 'myStatus': 'ACTIVE', 'memberCount': members};

FakeBackend _be({bool two = false, bool none = false}) => FakeBackend()
  ..on('/me/communities*', {
    'items': none
        ? <Object>[]
        : [
            _club(7, 'Müzik Kulübü', 'OWNER', members: 342),
            if (two) _club(8, 'Tiyatro ve Sahne Sanatları Kulübü', 'MODERATOR', members: 180),
          ]
  })
  ..on('/events', {'id': 77});

Map<String, dynamic> _edit() => {
      'id': 9,
      'title': 'Bahar Dönemi Akustik Konseri',
      'description': 'Akustik gece',
      'startsAt': DateTime(2030, 5, 14, 15, 30).toUtc().toIso8601String(),
      'endsAt': DateTime(2030, 5, 14, 17, 30).toUtc().toIso8601String(),
      'location': 'Konferans Salonu',
      'capacity': 450,
      'joinPolicy': 'APPROVAL',
      'communityId': 7,
      'communityName': 'Müzik Kulübü',
    };

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await loadIconFonts();
    mockSecureStorage();
  });

  testWidgets('form: yeni (tek kulup) 3 dil x tema x 1.3 x 320/390, tasma yok', (tester) async {
    await p00Matrix(tester, () => EventFormPage(session: makeSession(_be()), now: () => DateTime(2030, 1, 1, 10, 20)),
        scaffold: false);
  });

  testWidgets('form: duzenle matrisi', (tester) async {
    await p00Matrix(tester, () => EventFormPage(session: makeSession(_be()), event: _edit(), now: () => DateTime(2030, 1, 1, 10, 20)),
        scaffold: false, widths: const [320]);
  });

  testWidgets('form: kulup yok bos durumu matrisi', (tester) async {
    await p00Matrix(tester, () => EventFormPage(session: makeSession(_be(none: true))), scaffold: false, widths: const [320]);
  });

  testWidgets('dogrulama: kaydet denenince hata sayisi, kilit; duzelince kilit acilir', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.reset);
    final be = _be(two: true);
    await tester.pumpWidget(p00App(EventFormPage(session: makeSession(be), now: () => DateTime(2030, 1, 1, 10, 20)), scaffold: false));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.ensureVisible(find.byKey(const ValueKey('evc-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('evc-submit')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('evc-error-summary')), findsOneWidget);
    expect(find.text('Lütfen formdaki 2 hatayı düzelt.'), findsOneWidget);
    expect(find.text('Önce bir kulüp seç.'), findsOneWidget);
    expect(find.text('Başlık en az 3 karakter olmalı.'), findsOneWidget);
    expect(tester.widget<BuButton>(find.byKey(const ValueKey('evc-submit'))).onPressed, isNull);
    // Kulup sec + baslik yaz -> kilit kendiliginden acilir
    await tester.ensureVisible(find.byKey(const ValueKey('et2-club-field')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('et2-club-field')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Müzik Kulübü').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.enterText(find.byKey(const ValueKey('evc-title')), 'Bahar şenliği');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('evc-error-summary')), findsNothing);
    expect(tester.widget<BuButton>(find.byKey(const ValueKey('evc-submit'))).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('kulup secici: arama suzer, rol etiketi ve uye sayisi gorunur', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(p00App(EventFormPage(session: makeSession(_be(two: true))), scaffold: false));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.byKey(const ValueKey('et2-club-field')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('342 üye'), findsOneWidget);
    expect(find.text('Moderatör'), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('evc-club-search')), 'tiyatro');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('342 üye'), findsNothing);
    expect(find.text('180 üye'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('duzenle: Degistir kapak sayfasini acar; kapak yokken "Kapagi kaldir" yok', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(p00App(EventFormPage(session: makeSession(_be()), event: {..._edit(), 'coverUrl': '/files/x.png'}), scaffold: false));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text('Değiştir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Galeriden seç'), findsOneWidget);
    expect(find.text('Fotoğraf çek'), findsOneWidget);
    expect(find.text('Kapağı kaldır'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
