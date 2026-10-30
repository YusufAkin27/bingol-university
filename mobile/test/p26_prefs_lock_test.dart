import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Bildirim tercihleri: Anketler ve Akademik duyurular ana "Duyurular" bayrağına bağlıdır
/// (backend kuralı); kulüp anketi için ayrıca "Kulüpler" gerekir.
void main() {
  setUpAll(loadTestFonts);

  /// PUT gövdesini durumla birleştiren dinamik tercih ucu.
  FakeBackend backend({required bool announcements, bool communities = true}) {
    final prefs = <String, dynamic>{
      'news': true,
      'announcements': announcements,
      'events': true,
      'communities': communities,
      'messages': true,
      'polls': true,
      'academicAnnouncements': true,
    };
    final b = FakeBackend();
    b.handlers.add((req, path) {
      if (path != '/notifications/preferences') return null;
      if (req.method == 'PUT') {
        // Gövde fake_app tarafından `bodies`e de yazılır; burada yalnız anahtar/değer birleştirilir.
        final body = b.bodies['PUT /notifications/preferences'];
        if (body is Map) prefs.addAll(body.cast<String, dynamic>());
      }
      return FakeResult.json(Map<String, dynamic>.from(prefs));
    });
    return b;
  }

  /// Satırdaki anahtarın (Switch) dokunulabilir olup olmadığı.
  bool switchEnabled(WidgetTester tester, String label) {
    final row = find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
    final sw = tester.widget<Switch>(find.descendant(of: row, matching: find.byType(Switch)));
    return sw.onChanged != null;
  }

  Future<void> open(WidgetTester tester, FakeBackend b) async {
    useScreen(tester, const Size(390, 1800));
    await tester.pumpWidget(buildApp(NotificationPrefsPage(session: makeSession(b)), size: const Size(390, 1800)));
    await settle(tester);
  }

  testWidgets('Duyurular kapalıyken Anketler ve Akademik duyurular pasif, açıklamalı, dokunulamaz', (tester) async {
    final b = backend(announcements: false);
    await open(tester, b);

    expect(switchEnabled(tester, 'Anketler'), isFalse);
    expect(switchEnabled(tester, 'Akademik duyurular'), isFalse);
    expect(find.text('Duyurular kapalıyken bildirim gelmez'), findsOneWidget);
    expect(find.text('Duyurular veya Kulüpler kapalıysa ilgili anket bildirimleri gelmez'), findsOneWidget);
    // Anket açıklaması: genel anket Duyurular'a, kulüp anketi Kulüpler'e bağlı.
    expect(find.textContaining('anket bildirimleri gelmez'), findsOneWidget);

    await tester.tap(find.text('Anketler'));
    await tester.tap(find.text('Akademik duyurular'));
    await settle(tester);
    expect(b.bodies['PUT /notifications/preferences'], isNull);

    // Ana bayrak hâlâ dokunulabilir.
    expect(switchEnabled(tester, 'Duyurular'), isTrue);
    await unmount(tester);
  });

  testWidgets('Duyurular açılınca iki satır etkinleşir ve değişiklik gönderilir', (tester) async {
    final b = backend(announcements: false);
    await open(tester, b);

    await tester.tap(find.text('Duyurular'));
    await settle(tester);
    expect(b.bodies['PUT /notifications/preferences'], {'announcements': true});

    expect(switchEnabled(tester, 'Anketler'), isTrue);
    expect(switchEnabled(tester, 'Akademik duyurular'), isTrue);
    expect(find.text('Duyurular kapalıyken bildirim gelmez'), findsNothing);

    await tester.tap(find.text('Akademik duyurular'));
    await settle(tester);
    expect(b.bodies['PUT /notifications/preferences'], {'academicAnnouncements': false});
    await unmount(tester);
  });

  testWidgets('Duyurular açık, Kulüpler kapalı: Anketler etkin kalır, anket açıklaması görünür', (tester) async {
    final b = backend(announcements: true, communities: false);
    await open(tester, b);

    expect(switchEnabled(tester, 'Anketler'), isTrue);
    expect(switchEnabled(tester, 'Akademik duyurular'), isTrue);
    expect(find.text('Duyurular kapalıyken bildirim gelmez'), findsNothing);
    expect(find.textContaining('anket bildirimleri gelmez'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Duyurular ve Kulüpler açık: bağımlılık notu yok', (tester) async {
    final b = backend(announcements: true);
    await open(tester, b);

    expect(switchEnabled(tester, 'Anketler'), isTrue);
    expect(find.text('Duyurular kapalıyken bildirim gelmez'), findsNothing);
    expect(find.textContaining('anket bildirimleri gelmez'), findsNothing);
    expect(find.text('Öğrenci ve personel anketleri'), findsOneWidget);
    await unmount(tester);
  });
}
