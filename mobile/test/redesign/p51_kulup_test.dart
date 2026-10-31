import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/clubs/club_form_page.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/clubs/clubs_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// P51 Kulupler Stitch v3 birebir: metin sekmeleri, duz satir, Hakkinda/Uyeler sekmeleri, 3 dil x 320 dp x1.3 tasma.
Map<String, dynamic> _c(int id, String name, {String st = 'NONE', String? role}) =>
    {'id': id, 'name': name, 'category': 'Sanat', 'memberCount': 10 + id, 'myStatus': st, 'myRole': role, 'joinPolicy': 'OPEN', 'visibility': 'PUBLIC'};

FakeBackend _listBe() => FakeBackend()
  ..on('/communities/categories', [
    {'category': 'Sanat', 'count': 2},
  ])
  ..on('/me/communities*', {
    'items': [_c(1, 'Fotoğraf Kulübü', st: 'ACTIVE', role: 'OWNER'), _c(2, 'Müzik Kulübü', st: 'ACTIVE', role: 'MEMBER'), _c(3, 'Satranç Kulübü', st: 'PENDING')],
    'nextCursor': null,
  })
  ..on('/communities*', {
    'items': [_c(1, 'Fotoğraf Kulübü'), _c(2, 'Müzik Kulübü', st: 'ACTIVE', role: 'MEMBER'), _c(3, 'Satranç Kulübü', st: 'PENDING')],
    'nextCursor': null,
  });

FakeBackend _detailBe({String status = 'ACTIVE', String? role = 'OWNER'}) => FakeBackend()
  ..on('/communities/7', {
    'id': 7,
    'name': 'Fotoğraf Kulübü',
    'description': 'Kısa açıklama.',
    'category': 'Sanat',
    'memberCount': 128,
    'visibility': 'PUBLIC',
    'joinPolicy': 'OPEN',
    'myStatus': status,
    'myRole': role,
    'createdAt': '2019-03-12T09:00:00Z',
  })
  ..on('/communities/7/posts*', {'items': <Object>[], 'nextCursor': null})
  ..on('/communities/7/requests*', {'items': <Object>[], 'nextCursor': null})
  ..on('/communities/7/members*', {
    'items': [
      {'userId': 1, 'displayName': 'Elif Yıldız', 'role': 'OWNER'},
      {'userId': 2, 'displayName': 'Ahmet Kaya', 'role': 'MEMBER'},
    ],
    'nextCursor': null,
  })
  ..on('/polls*', {'items': <Object>[], 'nextCursor': null})
  ..on('/events*', {'items': <Object>[], 'nextCursor': null});

void main() {
  setUpAll(loadTestFonts);

  testWidgets('metin sekmeleri: secili marka rengi + 2 dp alt cizgi, dolu hap yok, dokununca degisir', (tester) async {
    var idx = 0;
    await tester.pumpWidget(p00App(
      StatefulBuilder(builder: (c, set) => ClubTextTabs(labels: const ['Keşfet', 'Kulüplerim'], index: idx, onChanged: (i) => set(() => idx = i))),
      lang: 'tr',
      dark: false,
      scale: 1,
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(find.byType(ClubTextTabs)).height, ClubTextTabs.height);
    await tester.tap(find.text('Kulüplerim'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(idx, 1);
    // Secili sekmenin alt cizgisi: 2 dp yuksek renkli kutu.
    final lines = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).where((a) => a.constraints?.maxHeight == 2).toList();
    expect(lines.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kesfet satiri: 48 dp logo, Katil 36 dp cerceveli; Kuluplerim bolumlu rol metinleri', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(ClubsTab(session: makeSession(_listBe())), size: kPhoneMedium));
    await settle(tester, const Duration(seconds: 1));
    expect(tester.getSize(find.byType(ClubsLogo).first), const Size(48, 48));
    expect(find.text('Katıl'), findsOneWidget);
    expect(find.text('Üyesin'), findsOneWidget);
    expect(find.text('İstek gönderildi'), findsOneWidget);
    final btn = tester.getSize(find.byType(ClubJoinButton));
    expect(btn.height, greaterThanOrEqualTo(48)); // 36 dp görünür + dokunma payı
    await tester.tap(find.text('Kulüplerim'));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.text('YÖNETTİKLERİM'), findsOneWidget);
    expect(find.text('ÜYE OLDUKLARIM'), findsOneWidget);
    expect(find.text('BEKLEYEN BAŞVURULAR'), findsOneWidget);
    expect(find.text('Yönetici'), findsOneWidget);
    expect(find.text('Üye'), findsOneWidget);
    expect(find.text('Yanıt bekleniyor'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('detay: Hakkinda varsayilan, Uyeler sekmesinde satir + uc nokta (yonetici), ziyaretcide Katil', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(ClubDetailPage(session: makeSession(_detailBe()), communityId: 7), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 900));
    expect(find.text('Kuruluş'), findsOneWidget);
    expect(find.text('2019'), findsOneWidget);
    expect(find.text('Kulüp sohbeti'), findsOneWidget);
    expect(find.text('Etkinlik oluştur'), findsOneWidget);
    await tester.tap(find.text('Üyeler'));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.text('Elif Yıldız'), findsOneWidget);
    expect(find.byType(ClubsLogo), findsWidgets);
    expect(find.byTooltip('Üye işlemleri'), findsNWidgets(2));
    await unmount(tester);

    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(ClubDetailPage(session: makeSession(_detailBe(status: 'NONE', role: null)), communityId: 7), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 900));
    expect(find.text('Katıl'), findsOneWidget);
    expect(find.text('Kulüp sohbeti'), findsNothing);
    await unmount(tester);
  });

  group('tasma matrisi (3 dil x acik/koyu x 1.0/1.3 x 320/390)', () {
    testWidgets('kulupler sekmesi', (tester) async {
      await p00Matrix(tester, () => ClubsTab(session: makeSession(_listBe())), scaffold: false, settleMs: 700);
    });
    testWidgets('kulup detayi', (tester) async {
      await p00Matrix(tester, () => ClubDetailPage(session: makeSession(_detailBe()), communityId: 7), scaffold: false, settleMs: 700);
    });
    testWidgets('kulup formu', (tester) async {
      await p00Matrix(tester, () => ClubFormPage(session: makeSession(_listBe())), scaffold: false, settleMs: 500);
    });
  });
}
