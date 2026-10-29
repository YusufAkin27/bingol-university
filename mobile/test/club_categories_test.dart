import 'package:bu_kampus/core/cache/cache_policy.dart';
import 'package:bu_kampus/features/clubs/club_categories.dart';
import 'package:bu_kampus/features/clubs/club_form_page.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _cats = [
  {'category': 'spor', 'count': 3, 'key': 'spor', 'name': 'Sports', 'icon': 'sports', 'sortOrder': 20},
  {'category': 'bos', 'count': 0, 'key': 'bos', 'name': 'Empty One', 'icon': 'tag', 'sortOrder': 30},
  {'category': 'sanat', 'count': 2, 'key': 'sanat', 'name': 'Arts', 'icon': 'yeni-bilinmeyen', 'sortOrder': 10, 'extra': 1},
];

Map<String, dynamic> _club({String? category = 'spor'}) => {
      'id': 7,
      'name': 'Robotik',
      'description': 'Aciklama',
      'category': category,
      'visibility': 'PUBLIC',
      'joinPolicy': 'OPEN',
      'memberCount': 4,
      'myStatus': 'NONE',
    };

Future<void> _pump(WidgetTester tester, Widget w) async {
  useScreen(tester, kPhoneMedium);
  await tester.pumpWidget(buildApp(w, size: kPhoneMedium));
  await settle(tester, const Duration(milliseconds: 600));
}

/// Kategori acilir alanini acip [name] satirini secer (K7: cip yerine acilir liste).
Future<void> pickCategory(WidgetTester tester, String name) async {
  const hint = 'Listeden seç ya da yaz (isteğe bağlı)';
  await tester.ensureVisible(find.text(hint));
  await tester.tap(find.text(hint));
  await settle(tester, const Duration(milliseconds: 700));
  await tester.tap(find.text(name));
  await settle(tester, const Duration(milliseconds: 600));
}

void main() {
  setUp(ClubCategories.reset);

  group('ayristirma', () {
    test('name/key/count/icon/sortOrder okunur, bilinmeyen alan sorun cikarmaz', () {
      final l = ClubCategory.parseList(_cats);
      expect(l.map((c) => c.key), ['spor', 'bos', 'sanat']);
      expect(l.first.name, 'Sports');
      expect(l.first.count, 3);
      expect(l.first.icon, 'sports');
      expect(l.first.sortOrder, 20);
      expect(l[1].isEmpty, isTrue);
    });
    test('eski/eksik bicim: ad yoksa anahtar buyuk harfle, bozuk satir atlanir', () {
      final l = ClubCategory.parseList([
        {'category': 'spor'},
        'x',
        {'name': 'anahtarsiz'},
        {'key': 'spor'},
      ]);
      expect(l.length, 1);
      expect(l.first.name, 'Spor');
      expect(l.first.isEmpty, isFalse); // count yoksa bos sayilmaz
      expect(ClubCategory.parseList('yanlis'), isEmpty);
    });
    test('bilinmeyen ikon varsayilana duser', () {
      expect(ClubCategory.iconFor('yeni-bilinmeyen'), ClubCategory.iconFor(''));
      expect(ClubCategory.iconFor('sports'), isNot(ClubCategory.iconFor('')));
    });
    test('pasif kategorili kulup: ad bulunamazsa anahtar buyuk harfle', () {
      ClubCategories.set(ClubCategory.parseList(_cats));
      expect(ClubCategories.labelFor('spor'), 'Sports');
      expect(ClubCategories.labelFor('eskikat'), 'Eskikat');
      expect(ClubCategories.labelFor(null), '');
    });
  });

  test('onbellek: /communities/categories diskte 1 gun', () {
    expect(CachePolicy.diskTtl('/communities/categories'), const Duration(days: 1));
  });

  testWidgets('kulup karti etiketi aktif listeden ad, yoksa anahtar', (tester) async {
    ClubCategories.set(ClubCategory.parseList(_cats));
    final be = FakeBackend()
      ..on('/communities/categories', _cats)
      ..on('/me/communities*', {'items': [], 'nextCursor': null})
      ..on('/communities*', {
        'items': [
          {..._club(category: 'spor'), 'id': 1, 'name': 'Birinci', 'description': ''},
          {..._club(category: 'eskikat'), 'id': 2, 'name': 'Ikinci', 'description': ''},
        ],
        'nextCursor': null,
      });
    await _pump(tester, ClubsTab(session: makeSession(be)));
    expect(find.textContaining('Sports'), findsWidgets);
    expect(find.textContaining('Eskikat'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('sekme: cip adi name, bos kategori gizli, suzme key ile', (tester) async {
    final be = FakeBackend()
      ..on('/communities/categories', _cats)
      ..on('/me/communities*', {'items': [], 'nextCursor': null})
      ..on('/communities*', {'items': [], 'nextCursor': null});
    await _pump(tester, ClubsTab(session: makeSession(be)));
    expect(find.text('Sports'), findsOneWidget);
    expect(find.text('Arts'), findsOneWidget);
    expect(find.text('Empty One'), findsNothing);
    await tester.tap(find.text('Sports'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(be.requests.any((r) => r.contains('category=spor')), isTrue);
    await unmount(tester);
  });

  group('form', () {
    FakeBackend base() => FakeBackend()..on('/communities/categories', _cats);

    testWidgets('secilmedi varsayilan: kategori gonderilmez', (tester) async {
      final be = base()..on('/communities', {'id': 9, 'status': 'PENDING_REVIEW'}, status: 202);
      await _pump(tester, ClubFormPage(session: makeSession(be)));
      await tester.ensureVisible(find.text('Listeden seç ya da yaz (isteğe bağlı)'));
      await tester.tap(find.text('Listeden seç ya da yaz (isteğe bağlı)'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Seçilmedi'), findsOneWidget);
      expect(find.text('Sports'), findsOneWidget);
      await tester.tap(find.text('Seçilmedi'));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.enterText(find.byType(TextField).at(0), 'Yeni Kulüp');
      await tester.ensureVisible(find.text('Kulübü oluştur'));
      await tester.tap(find.text('Kulübü oluştur'));
      await settle(tester, const Duration(seconds: 1));
      expect((be.bodies['POST /communities'] as Map).containsKey('category'), isFalse);
      await unmount(tester);
    });

    testWidgets('secili kategori key olarak gonderilir', (tester) async {
      final be = base()..on('/communities', {'id': 9, 'status': 'PENDING_REVIEW'}, status: 202);
      await _pump(tester, ClubFormPage(session: makeSession(be)));
      await tester.enterText(find.byType(TextField).at(0), 'Yeni Kulüp');
      await pickCategory(tester, 'Sports');
      await tester.ensureVisible(find.text('Kulübü oluştur'));
      await tester.tap(find.text('Kulübü oluştur'));
      await settle(tester, const Duration(seconds: 1));
      expect((be.bodies['POST /communities'] as Map)['category'], 'spor');
      await unmount(tester);
    });

    testWidgets('kullanim disi kategori gosterilir ve degismediyse aynen gonderilir', (tester) async {
      final be = base()
        ..on('/communities/7', _club(category: 'eskikat'))
        ..on('/communities/7/join-questions', [])
        ..on('/communities/7', {'ok': true}); // PATCH yaniti
      final club = _club(category: 'eskikat');
      await _pump(tester, ClubFormPage(session: makeSession(be), club: club));
      expect(find.text('Eskikat'), findsOneWidget); // alandaki deger
      await tester.tap(find.text('Eskikat'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Eskikat (kullanım dışı)'), findsOneWidget); // listede
      await tester.tapAt(const Offset(10, 10)); // perdeye dokun: kapat
      await settle(tester, const Duration(milliseconds: 600));
      final save = find.text('Kaydet');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await settle(tester, const Duration(seconds: 1));
      expect((be.bodies['PATCH /communities/7'] as Map)['category'], 'eskikat');
      await unmount(tester);
    });

    testWidgets('400 COMMUNITY_CATEGORY_INVALID kategori altinda gosterilir', (tester) async {
      final be = base()..fail('/communities', status: 400, code: 'COMMUNITY_CATEGORY_INVALID', message: '');
      await _pump(tester, ClubFormPage(session: makeSession(be)));
      await tester.enterText(find.byType(TextField).at(0), 'Yeni Kulüp');
      await pickCategory(tester, 'Sports');
      await tester.ensureVisible(find.text('Kulübü oluştur'));
      await tester.tap(find.text('Kulübü oluştur'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.textContaining('Seçilen kategori geçerli değil'), findsOneWidget);
      await unmount(tester);
    });
  });
}
