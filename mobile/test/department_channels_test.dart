import 'package:bu_kampus/widgets/bu.dart';
import 'package:bu_kampus/features/chat/all_departments_page.dart';
import 'package:bu_kampus/features/chat/department_chat_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

Map<String, dynamic> _dept(String key, String name, String faculty,
        {bool own = false, bool joined = false, bool closed = false, int members = 0, int? cid}) =>
    {
      'key': key,
      'name': name,
      'nameEn': '$name EN',
      'nameAr': '$name AR',
      'faculty': faculty,
      'facultyEn': '$faculty EN',
      'facultyAr': '$faculty AR',
      'own': own,
      'joined': joined,
      'closed': closed,
      'memberCount': members,
      'conversationId': joined ? (cid ?? 50) : null,
    };

Map<String, dynamic> _mineItem(String key, String name, {int unread = 0, String? text}) => {
      'key': key,
      'name': name,
      'nameEn': '$name EN',
      'nameAr': '$name AR',
      'faculty': 'Mühendislik Fakültesi',
      'own': false,
      'conversation': {
        'id': 50,
        'type': 'DEPARTMENT',
        'title': name,
        'unreadCount': unread,
        'lastMessage': text == null ? null : {'id': 1, 'text': text},
      },
    };

final _ownDept = _dept('bilgisayar-muhendisligi', 'Bilgisayar Mühendisliği', 'Mühendislik Fakültesi', own: true);

void main() {
  setUpAll(loadTestFonts);

  group('DepartmentChannelsStrip', () {
    Future<FakeBackend> pumpStrip(WidgetTester tester, Map<String, dynamic> mine, {FakeBackend? backend}) async {
      useScreen(tester, kPhoneMedium);
      final b = backend ?? (FakeBackend()..on('/chat/departments/mine', mine));
      await tester.pumpWidget(p00App(SingleChildScrollView(child: DepartmentChannelsStrip(session: makeSession(b)))));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      return b;
    }

    testWidgets('katildigi kanallar kart olarak: ad, okunmamis rozeti, son mesaj', (tester) async {
      await pumpStrip(tester, {
        'items': [_mineItem('matematik', 'Matematik', unread: 3, text: 'Sınav ne zaman?')],
        'own': _ownDept,
      });
      expect(find.byKey(const ValueKey('department-channels')), findsOneWidget);
      expect(find.text('Matematik'), findsOneWidget);
      expect(find.text('Sınav ne zaman?'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byKey(const ValueKey('department-channels-suggest')), findsNothing);
      expect(find.byKey(const ValueKey('department-channels-all')), findsOneWidget);
    });

    testWidgets('hic kanal yok + kendi bolum acik: oneri karti + Katil', (tester) async {
      await pumpStrip(tester, {'items': <Object>[], 'own': _ownDept});
      expect(find.byKey(const ValueKey('department-channels-suggest')), findsOneWidget);
      expect(find.textContaining('Bilgisayar Mühendisliği'), findsOneWidget);
      expect(find.byKey(const ValueKey('department-channels-join-own')), findsOneWidget);
    });

    testWidgets('hic kanal yok + bolum yok: gozat karti, Katil yok', (tester) async {
      await pumpStrip(tester, {'items': <Object>[], 'own': null});
      expect(find.byKey(const ValueKey('department-channels-suggest')), findsOneWidget);
      expect(find.byKey(const ValueKey('department-channels-join-own')), findsNothing);
      expect(find.byKey(const ValueKey('department-channels-browse')), findsOneWidget);
    });

    testWidgets('kendi bolum kapali: Katil yok', (tester) async {
      await pumpStrip(tester, {'items': <Object>[], 'own': {..._ownDept, 'closed': true}});
      expect(find.byKey(const ValueKey('department-channels-join-own')), findsNothing);
    });

    testWidgets('Katil: POST join cagrilir', (tester) async {
      final b = FakeBackend()
        ..on('/chat/departments/mine', {'items': <Object>[], 'own': _ownDept})
        ..on('/chat/departments/bilgisayar-muhendisligi/join', {'key': 'bilgisayar-muhendisligi', 'joined': true, 'conversationId': 50});
      await pumpStrip(tester, const {}, backend: b);
      await tester.tap(find.byKey(const ValueKey('department-channels-join-own')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(b.count('POST /chat/departments/bilgisayar-muhendisligi/join'), 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('hata: alan sessizce gizli kalir', (tester) async {
      final b = FakeBackend()..fail('/chat/departments/mine', status: 500);
      await pumpStrip(tester, const {}, backend: b);
      expect(find.byKey(const ValueKey('department-channels')), findsNothing);
    });

    testWidgets('tr/en/ar x acik/koyu x 1.0/1.3 x 320/390: tasma yok (kartlar ve oneri)', (tester) async {
      final cards = FakeBackend()
        ..on('/chat/departments/mine', {
          'items': [
            _mineItem('matematik', 'Elektrik-Elektronik Mühendisliği ve Haberleşme Teknolojileri', unread: 120, text: 'Çok uzun bir mesaj önizlemesi ' * 4),
            _mineItem('fizik', 'Fizik'),
          ],
          'own': _ownDept,
        });
      await p00Matrix(tester, () => SingleChildScrollView(child: DepartmentChannelsStrip(session: makeSession(cards))));
      final suggest = FakeBackend()..on('/chat/departments/mine', {'items': <Object>[], 'own': _ownDept});
      await p00Matrix(tester, () => SingleChildScrollView(child: DepartmentChannelsStrip(session: makeSession(suggest))));
    });
  });

  group('AllDepartmentsPage', () {
    FakeBackend backend(List<Map<String, dynamic>> items) => FakeBackend()
      ..on('/chat/departments?page=0&size=200', {'items': items, 'page': 0, 'size': 200, 'total': items.length, 'ownKey': 'bilgisayar-muhendisligi'});

    Future<void> pumpPage(WidgetTester tester, FakeBackend b) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(p00App(AllDepartmentsPage(session: makeSession(b)), scaffold: false));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }

    final data = [
      _dept('bilgisayar-muhendisligi', 'Bilgisayar Mühendisliği', 'Mühendislik Fakültesi', own: true, members: 4),
      _dept('makine-muhendisligi', 'Makine Mühendisliği', 'Mühendislik Fakültesi', members: 1),
      _dept('matematik', 'Matematik', 'Fen-Edebiyat Fakültesi', joined: true, members: 9),
      _dept('fizik', 'Fizik', 'Fen-Edebiyat Fakültesi', closed: true),
    ];

    testWidgets('fakulteye gore gruplu, kendi bolum ustte Senin bolumun etiketiyle', (tester) async {
      await pumpPage(tester, backend(data));
      expect(find.text('Senin bölümün'), findsOneWidget);
      expect(find.text('Mühendislik Fakültesi'), findsOneWidget);
      expect(find.text('Fen-Edebiyat Fakültesi'), findsOneWidget);
      expect(find.text('Bilgisayar Mühendisliği'), findsOneWidget);
      expect(find.text('4 üye'), findsOneWidget);
      expect(find.text('1 üye'), findsOneWidget);
      // Katil / Ayril / Kapali
      expect(find.byKey(const ValueKey('dept-toggle-matematik')), findsOneWidget);
      expect(find.text('Ayrıl'), findsOneWidget);
      expect(find.text('Kapalı'), findsWidgets);
    });

    testWidgets('arama aksan duyarsiz suzer, eslesme yoksa bos durum', (tester) async {
      await pumpPage(tester, backend(data));
      await tester.enterText(find.byType(TextField), 'MUHENDISLIGI');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Makine Mühendisliği'), findsOneWidget);
      expect(find.text('Matematik'), findsNothing);
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('department-channels-empty')), findsOneWidget);
    });

    testWidgets('Katil: iyimser guncelleme + POST join', (tester) async {
      final b = backend(data)
        ..on('/chat/departments/makine-muhendisligi/join', {..._dept('makine-muhendisligi', 'Makine Mühendisliği', 'Mühendislik Fakültesi', joined: true, members: 2), 'conversationId': 77});
      await pumpPage(tester, b);
      await tester.tap(find.byKey(const ValueKey('dept-toggle-makine-muhendisligi')));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('2 üye'), findsOneWidget); // iyimser sayac
      await tester.pump(const Duration(milliseconds: 200));
      expect(b.count('POST /chat/departments/makine-muhendisligi/join'), 1);
      expect(find.text('Ayrıl'), findsNWidgets(2));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Ayril: onay sormadan POST leave, sayac dusuyor', (tester) async {
      final b = backend(data)..on('/chat/departments/matematik/leave', <String, dynamic>{});
      await pumpPage(tester, b);
      await tester.tap(find.byKey(const ValueKey('dept-toggle-matematik')));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('8 üye'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(b.count('POST /chat/departments/matematik/leave'), 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Ayrıl'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Katil hatasi: iyimser guncelleme geri alinir', (tester) async {
      final b = backend(data)..fail('/chat/departments/makine-muhendisligi/join', status: 403, code: 'DEPARTMENT_JOIN_FORBIDDEN');
      await pumpPage(tester, b);
      await tester.tap(find.byKey(const ValueKey('dept-toggle-makine-muhendisligi')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('1 üye'), findsOneWidget);
      expect(find.text('Ayrıl'), findsOneWidget); // yalniz matematik
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('liste hatasi: hata durumu + yeniden dene', (tester) async {
      final b = FakeBackend()..fail('/chat/departments?page=0&size=200', status: 500);
      await pumpPage(tester, b);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(BuErrorState), findsOneWidget);
      expect(b.count('/chat/departments'), greaterThanOrEqualTo(1));
    });

    testWidgets('tr/en/ar x acik/koyu x 1.0/1.3 x 320/390: tasma yok', (tester) async {
      final b = backend([
        ...data,
        _dept('x', 'Elektrik-Elektronik Mühendisliği ve Haberleşme Teknolojileri Bölümü', 'Çok Uzun Adlı Bir Fakülte Adı Burada', members: 123456, joined: true),
      ]);
      await p00Matrix(tester, () => AllDepartmentsPage(session: makeSession(b)), scaffold: false);
    });
  });

  test('foldDeptSearch Turkce harfleri sadelestirir', () {
    expect(foldDeptSearch('İSTANBUL Şğüöç ı'), 'istanbul sguoc i');
  });
}
