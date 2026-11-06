import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/clubs/clubs_widgets.dart' show ClubJoinButton;
import 'package:bu_kampus/features/home/home_clubs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

Map<String, dynamic> _c(int id, String name, {String st = 'NONE', String? role, int n = 10, String policy = 'OPEN'}) =>
    {'id': id, 'name': name, 'category': 'Sanat', 'memberCount': n, 'myStatus': st, 'myRole': role, 'joinPolicy': policy, 'visibility': 'PUBLIC'};

FakeBackend _be({List<Map<String, dynamic>> mine = const [], List<Map<String, dynamic>> all = const []}) => FakeBackend()
  ..on('/communities/categories', [
    {'category': 'Sanat', 'count': 3},
  ])
  ..on('/me/communities*', {'items': mine, 'nextCursor': null})
  ..on('/communities*', {'items': all, 'nextCursor': null});

Widget _home(FakeBackend b, {VoidCallback? onAll, Object? token}) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: HomeClubs(session: makeSession(b), onOpenAll: onAll ?? () {}, refreshToken: token),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget w, {Size size = kPhoneMedium}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(Scaffold(body: w), size: size));
  await settle(tester, const Duration(milliseconds: 900));
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('uyelik durumlari: once Kuluplerim (Uyesin / istek), sonra populer; Katil yalniz uye olmayana', (tester) async {
    final b = _be(
      mine: [_c(1, 'Fotoğraf Kulübü', st: 'ACTIVE', role: 'OWNER', n: 12), _c(3, 'Tiyatro Kulübü', st: 'PENDING', n: 5, policy: 'APPROVAL')],
      all: [
        _c(1, 'Fotoğraf Kulübü', st: 'ACTIVE', role: 'OWNER', n: 12),
        _c(2, 'Satranç Kulübü', n: 30),
        _c(3, 'Tiyatro Kulübü', st: 'PENDING', n: 5, policy: 'APPROVAL'),
        _c(4, 'Müzik Kulübü', n: 99),
        _c(5, 'Yasaklı Kulüp', st: 'BANNED', n: 500),
      ],
    );
    await _pump(tester, _home(b), size: const Size(900, 800)); // genis ekran: yatay seritte 4 kart da kurulu
    // Sira: uye oldugum, bekleyen, sonra populer (Muzik 99 > Satranc 30); yasakli gizli; tekrar yok.
    final names = ['Fotoğraf Kulübü', 'Tiyatro Kulübü', 'Müzik Kulübü', 'Satranç Kulübü'];
    final xs = [for (final n in names) tester.getTopLeft(find.text(n)).dx];
    expect(xs, [...xs]..sort(), reason: 'yatay sira: $xs');
    expect(find.text('Fotoğraf Kulübü'), findsOneWidget);
    expect(find.text('Yasaklı Kulüp'), findsNothing);
    expect(find.text('Üyesin'), findsOneWidget);
    expect(find.text('İstek gönderildi'), findsOneWidget);
    expect(find.text('Katıl'), findsNWidgets(2));
    expect(find.text('Sanat · 12 üye'), findsOneWidget);
    expect(find.text('Kulüpler'), findsOneWidget);
    expect(find.text('Tümünü gör'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Tumunu gor geri cagrisi; karta dokununca kulup detayi', (tester) async {
    var all = 0;
    final b = _be(all: [_c(2, 'Satranç Kulübü', n: 30)])
      ..on('/communities/2', {..._c(2, 'Satranç Kulübü', n: 30), 'description': 'Aciklama', 'createdAt': '2020-01-01T00:00:00Z'})
      ..on('/communities/2/posts*', {'items': <Object>[], 'nextCursor': null})
      ..on('/events*', {'items': <Object>[], 'nextCursor': null});
    await _pump(tester, _home(b, onAll: () => all++));
    await tester.tap(find.text('Tümünü gör'));
    expect(all, 1);
    await tester.tap(find.text('Satranç Kulübü'));
    await settle(tester, const Duration(milliseconds: 900));
    expect(find.byType(ClubDetailPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Katil: POST join, kart Uyesin olur ve uye sayisi artar', (tester) async {
    final b = _be(all: [_c(2, 'Satranç Kulübü', n: 30)])..on('/communities/2/join', {'status': 'ACTIVE'});
    await _pump(tester, _home(b));
    expect(find.text('Sanat · 30 üye'), findsOneWidget);
    await tester.tap(find.text('Katıl'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(b.count('POST /communities/2/join'), 1);
    expect(find.text('Üyesin'), findsOneWidget);
    expect(find.text('Katıl'), findsNothing);
    expect(find.text('Sanat · 31 üye'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('kulup yok: bolum gizlenmez, "Henuz kulup yok" + Kulup kur', (tester) async {
    await _pump(tester, _home(_be()));
    expect(find.byKey(const ValueKey('homeClubsEmpty')), findsOneWidget);
    expect(find.text('Henüz kulüp yok'), findsOneWidget);
    expect(find.text('Kulüp kur'), findsOneWidget);
    expect(find.text('Kulüpler'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('ag/sunucu hatasi: yuklenemedi + yeniden dene; sonra basarili', (tester) async {
    final b = FakeBackend()
      ..fail('/me/communities*', status: 500, code: 'SERVER_ERROR')
      ..fail('/communities*', status: 500, code: 'SERVER_ERROR');
    await _pump(tester, _home(b));
    expect(find.byKey(const ValueKey('homeClubsError')), findsOneWidget);
    expect(find.text('Kulüpler yüklenemedi.'), findsOneWidget);
    b
      ..on('/me/communities*', {'items': <Object>[], 'nextCursor': null})
      ..on('/communities*', {
        'items': [_c(2, 'Satranç Kulübü', n: 30)],
        'nextCursor': null
      });
    await tester.tap(find.text('Yeniden dene'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Satranç Kulübü'), findsOneWidget);
    expect(find.byKey(const ValueKey('homeClubsError')), findsNothing);
    await unmount(tester);
  });

  testWidgets('kismi hata: Kuluplerim dustu ama kesfet geldi -> kartlar gosterilir', (tester) async {
    final b = _be(all: [_c(2, 'Satranç Kulübü', n: 30)])..fail('/me/communities*', status: 500, code: 'SERVER_ERROR');
    await _pump(tester, _home(b));
    expect(find.text('Satranç Kulübü'), findsOneWidget);
    expect(find.byKey(const ValueKey('homeClubsError')), findsNothing);
    await unmount(tester);
  });

  testWidgets('yukleniyor: iskelet (dongu yok), sonra kartlar', (tester) async {
    final b = _be(all: [_c(2, 'Satranç Kulübü', n: 30)])..delay = const Duration(milliseconds: 400);
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(Scaffold(body: _home(b)), size: kPhoneMedium));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Satranç Kulübü'), findsNothing);
    expect(find.byKey(const ValueKey('homeClubsStrip')), findsNothing);
    await settle(tester, const Duration(milliseconds: 1500));
    expect(find.text('Satranç Kulübü'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('dokunma hedefleri >= 48 dp (Katil satiri ve Tumunu gor)', (tester) async {
    final b = _be(all: [_c(2, 'Satranç Kulübü', n: 30)]);
    await _pump(tester, _home(b));
    expect(tester.getSize(find.byType(ClubJoinButton)).height, greaterThanOrEqualTo(48));
    await unmount(tester);
  });

  group('tasma matrisi (3 dil x acik/koyu x 1.0/1.3 x 320/390)', () {
    testWidgets('dolu', (tester) async {
      final b = _be(
        mine: [_c(1, 'Bingöl Üniversitesi Bilgisayar Mühendisliği Öğrenci Topluluğu', st: 'ACTIVE', role: 'OWNER', n: 1204)],
        all: [_c(2, 'Satranç', n: 30), _c(3, 'Tiyatro', st: 'PENDING', n: 5), _c(4, 'Müzik', n: 99)],
      );
      await p00Matrix(tester, () => _home(b), settleMs: 700);
    });
    testWidgets('bos', (tester) async {
      final b = _be();
      await p00Matrix(tester, () => _home(b), settleMs: 700);
    });
    testWidgets('hata', (tester) async {
      final b = FakeBackend()
        ..fail('/me/communities*', status: 500, code: 'SERVER_ERROR')
        ..fail('/communities*', status: 500, code: 'SERVER_ERROR');
      await p00Matrix(tester, () => _home(b), settleMs: 700);
    });
  });
}
