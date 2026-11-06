import 'package:bu_kampus/features/clubs/club_categories.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/clubs/clubs_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

Map<String, dynamic> _c(int id, String name,
        {String st = 'NONE', String? role, int n = 10, String cat = 'Sanat', String? desc, String? created, String policy = 'OPEN'}) =>
    {
      'id': id,
      'name': name,
      'category': cat,
      'description': desc ?? '$name açıklaması',
      'memberCount': n,
      'myStatus': st,
      'myRole': role,
      'joinPolicy': policy,
      'visibility': 'PUBLIC',
      'createdAt': created ?? '2024-01-${(id % 27 + 1).toString().padLeft(2, '0')}T10:00:00Z',
    };

final _all = [
  _c(1, 'Fotoğraf Kulübü', n: 40, st: 'ACTIVE', role: 'OWNER'),
  _c(2, 'Satranç Kulübü', n: 90, cat: 'Spor', created: '2025-06-01T10:00:00Z'),
  _c(3, 'Tiyatro Kulübü', n: 15, st: 'PENDING', policy: 'APPROVAL', created: '2023-01-01T10:00:00Z'),
  _c(4, 'Çevre Kulübü', n: 60, cat: 'Sosyal', created: '2025-12-01T10:00:00Z'),
  _c(5, 'Müzik Kulübü', n: 25, st: 'ACTIVE', role: 'MEMBER'),
];

/// Sunucuyu taklit eder: `q` ad/açıklamada, `category` tam eşleşme süzer.
FakeBackend _be({List<Map<String, dynamic>>? items}) {
  final data = items ?? _all;
  final b = FakeBackend()
    ..on('/communities/categories', [
      {'key': 'Sanat', 'name': 'Sanat', 'count': 2},
      {'key': 'Spor', 'name': 'Spor', 'count': 1},
      {'key': 'Sosyal', 'name': 'Sosyal', 'count': 1},
    ])
    ..on('/me/communities*', {'items': [for (final c in data) if (c['myStatus'] == 'ACTIVE' || c['myStatus'] == 'PENDING') c], 'nextCursor': null});
  b.handlers.add((req, path) {
    if (path != '/communities' || req.method != 'GET') return null;
    final q = (req.url.queryParameters['q'] ?? '').toLowerCase();
    final cat = req.url.queryParameters['category'];
    final out = [
      for (final c in data)
        if ((cat == null || c['category'] == cat) && (q.isEmpty || '${c['name']} ${c['description']}'.toLowerCase().contains(q))) c,
    ];
    return FakeResult.json({'items': out, 'nextCursor': null});
  });
  return b;
}

Future<void> _pump(WidgetTester tester, FakeBackend b, {Size size = kPhoneMedium, Brightness brightness = Brightness.light}) async {
  ClubCategories.reset();
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(ClubsTab(session: makeSession(b)), size: size, brightness: brightness));
  await settle(tester, const Duration(milliseconds: 900));
}

double _y(WidgetTester t, String text) => t.getTopLeft(find.text(text)).dy;

void main() {
  setUpAll(loadTestFonts);

  group('saf islevler', () {
    test('clubFold: Turkce karakterleri sadelestirir', () {
      expect(clubFold('Kulüp ÇEVRE Işık İstanbul ğış'), 'kulup cevre isik istanbul gis');
    });

    test('sortClubs: populer / yeni / A-Z, esitlikte sunucu sirasi', () {
      final l = [
        {'name': 'b', 'memberCount': 5, 'createdAt': '2024-01-01T00:00:00Z'},
        {'name': 'Ç', 'memberCount': 9, 'createdAt': '2025-01-01T00:00:00Z'},
        {'name': 'a', 'memberCount': 5},
      ];
      expect(sortClubs(l, ClubSort.popular).map((c) => c['name']), ['Ç', 'b', 'a']);
      expect(sortClubs(l, ClubSort.newest).map((c) => c['name']), ['Ç', 'b', 'a'], reason: 'createdAt yoksa sunucu sirasi korunur');
      expect(sortClubs(l, ClubSort.az).map((c) => c['name']), ['a', 'b', 'Ç']);
      expect(l.first['name'], 'b', reason: 'girdi degismez');
    });
  });

  testWidgets('arama kutusu hep gorunur; baslik yalniz semantik; satirda aciklama, uye sayisi, kategori', (tester) async {
    final sem = tester.ensureSemantics();
    await _pump(tester, _be());
    expect(find.byKey(const ValueKey('clubsSearch')), findsOneWidget);
    expect(find.text('Kulüp ara'), findsOneWidget); // ipucu
    expect(find.text('Kulüpler'), findsNothing); // ekran adi gorunmez (tasarim sadelestirmesi), yalniz semantik baslik
    expect(find.bySemanticsLabel('Kulüpler'), findsOneWidget);
    expect(find.text('Fotoğraf Kulübü açıklaması'), findsOneWidget);
    expect(find.text('Spor · 90 üye'), findsOneWidget);
    expect(tester.getSize(find.byType(ClubsLogo).first), const Size(48, 48));
    expect(find.text('5 kulüp'), findsOneWidget);
    expect(tester.takeException(), isNull);
    sem.dispose();
    await unmount(tester);
  });

  testWidgets('varsayilan siralama Populer (uye sayisi azalan)', (tester) async {
    await _pump(tester, _be());
    expect(find.text('Sırala: Popüler'), findsOneWidget);
    final order = ['Satranç Kulübü', 'Çevre Kulübü', 'Fotoğraf Kulübü', 'Müzik Kulübü', 'Tiyatro Kulübü'];
    final ys = [for (final n in order) _y(tester, n)];
    expect(ys, [...ys]..sort(), reason: 'dikey sira $ys');
    await unmount(tester);
  });

  testWidgets('siralama: A-Z ve Yeni alt sayfadan secilir', (tester) async {
    await _pump(tester, _be());
    await tester.tap(find.byKey(const ValueKey('clubsSortButton')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Sıralama'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clubSort-az')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Sırala: A-Z'), findsOneWidget);
    var order = ['Çevre Kulübü', 'Fotoğraf Kulübü', 'Müzik Kulübü', 'Satranç Kulübü', 'Tiyatro Kulübü'];
    var ys = [for (final n in order) _y(tester, n)];
    expect(ys, [...ys]..sort(), reason: 'A-Z $ys');

    await tester.tap(find.byKey(const ValueKey('clubsSortButton')));
    await settle(tester, const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('clubSort-newest')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Sırala: Yeni'), findsOneWidget);
    order = ['Çevre Kulübü', 'Satranç Kulübü', 'Tiyatro Kulübü']; // 2025-12, 2025-06, 2023 (digerleri 2024 -> aradadir)
    ys = [for (final n in order) _y(tester, n)];
    expect(ys, [...ys]..sort(), reason: 'Yeni $ys');
    await unmount(tester);
  });

  testWidgets('arama: yazarken ANINDA istemci suzgeci, bekleme sonrasi sunucu q=', (tester) async {
    final b = _be();
    await _pump(tester, b);
    final before = b.count('GET /communities?');
    await tester.enterText(find.byKey(const ValueKey('clubsSearch')).evaluate().isEmpty ? find.byType(TextField) : find.descendant(of: find.byKey(const ValueKey('clubsSearch')), matching: find.byType(TextField)), 'satranc');
    await tester.pump(); // bekleme dolmadan
    expect(find.text('Satranç Kulübü'), findsOneWidget);
    expect(find.text('Fotoğraf Kulübü'), findsNothing, reason: 'anlik suzgec (Turkce karakter sadelestirme)');
    expect(find.text('1 kulüp'), findsOneWidget);
    expect(b.count('GET /communities?'), before, reason: 'sunucu isteği beklemeden once atilmaz');
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester, const Duration(milliseconds: 400));
    expect(b.requests.where((r) => r.contains('q=satranc')), isNotEmpty, reason: 'bekleme sonrasi sunucu aramasi');
    expect(find.text('Satranç Kulübü'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('arama sonuc yok: "Kulup bulunamadi"; silince liste geri gelir', (tester) async {
    final b = _be();
    await _pump(tester, b);
    final field = find.descendant(of: find.byKey(const ValueKey('clubsSearch')), matching: find.byType(TextField));
    await tester.enterText(field, 'zzzz');
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester, const Duration(milliseconds: 400));
    expect(find.text('Kulüp bulunamadı.'), findsOneWidget);
    await tester.enterText(field, '');
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Satranç Kulübü'), findsOneWidget);
    expect(find.text('Kulüp bulunamadı.'), findsNothing);
    await unmount(tester);
  });

  testWidgets('kategori cipleri: Tumu + kategoriler; secince sunucu category= ile suzulur', (tester) async {
    final b = _be();
    await _pump(tester, b);
    expect(find.byKey(const ValueKey('clubsCategoryChips')), findsOneWidget);
    expect(find.text('Tümü'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('clubsCategoryChips')), matching: find.text('Spor')));
    await settle(tester, const Duration(milliseconds: 700));
    expect(b.requests.where((r) => r.contains('category=Spor')), isNotEmpty);
    expect(find.text('Satranç Kulübü'), findsOneWidget);
    expect(find.text('Fotoğraf Kulübü'), findsNothing);
    // Kategori + sonuc yok -> Tumu eylemi
    await tester.tap(find.text('Tümü'));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.text('Fotoğraf Kulübü'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Katil akisi (acik kulup): POST join -> Uyesin', (tester) async {
    final b = _be()..on('/communities/2/join', {'status': 'ACTIVE'});
    await _pump(tester, b);
    expect(find.text('Katıl'), findsNWidgets(2)); // Satranc + Cevre
    expect(find.text('İstek gönderildi'), findsOneWidget);
    await tester.tap(find.text('Katıl').first); // populer sirada Satranc ilk
    await settle(tester, const Duration(milliseconds: 600));
    expect(b.count('POST /communities/2/join'), 1);
    expect(find.text('Katıl'), findsOneWidget);
    expect(find.text('Spor · 91 üye'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Kuluplerim: bolumler; arama yalniz istemcide (sunucu istegi yok), cipler/siralama gizli', (tester) async {
    final b = _be();
    await _pump(tester, b);
    await tester.tap(find.text('Kulüplerim'));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.text('YÖNETTİKLERİM'), findsOneWidget);
    expect(find.text('ÜYE OLDUKLARIM'), findsOneWidget);
    expect(find.text('BEKLEYEN BAŞVURULAR'), findsOneWidget);
    expect(find.byKey(const ValueKey('clubsSortButton')), findsNothing);
    expect(find.byKey(const ValueKey('clubsCategoryChips')), findsNothing);
    final n = b.count('GET /communities?');
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('clubsSearch')), matching: find.byType(TextField)), 'müzik');
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester, const Duration(milliseconds: 400));
    expect(find.text('Müzik Kulübü'), findsOneWidget);
    expect(find.text('Fotoğraf Kulübü'), findsNothing);
    expect(b.count('GET /communities?'), n, reason: 'Kuluplerim aramasi sunucuya gitmez');
    // Keşfet'e donunce arama sunucuya da yansir
    await tester.tap(find.text('Keşfet'));
    await settle(tester, const Duration(milliseconds: 800));
    expect(b.requests.where((r) => r.contains('q=m')), isNotEmpty);
    await unmount(tester);
  });

  testWidgets('Kuluplerim bos: "Tum kulupler" eylemi Kesfet sekmesine doner', (tester) async {
    final b = _be(items: [_c(2, 'Satranç Kulübü')]);
    await _pump(tester, b);
    await tester.tap(find.text('Kulüplerim'));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.text('Henüz hiçbir kulübe üye değilsin.'), findsOneWidget);
    await tester.tap(find.text('Tüm kulüpler'));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.text('Satranç Kulübü'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('kulup yok: bos durum + Kulup kur', (tester) async {
    await _pump(tester, _be(items: const []));
    expect(find.text('Henüz kulüp yok.'), findsOneWidget);
    expect(find.text('Kulüp kur'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('hata: Yuklenemedi + tekrar dene; ag yoksa ag metni', (tester) async {
    final b = FakeBackend()
      ..on('/communities/categories', [])
      ..on('/me/communities*', {'items': <Object>[], 'nextCursor': null})
      ..fail('/communities*', status: 500, code: 'SERVER_ERROR');
    await _pump(tester, b);
    expect(find.text('Yüklenemedi, tekrar dene'), findsOneWidget);
    b.on('/communities*', {
      'items': [_c(2, 'Satranç Kulübü')],
      'nextCursor': null
    });
    await tester.tap(find.text('Yeniden dene'));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.text('Satranç Kulübü'), findsOneWidget);
    await unmount(tester);

    final off = FakeBackend()..offline = true;
    await _pump(tester, off);
    expect(find.text('Yeniden dene'), findsOneWidget);
    expect(find.text('Yüklenemedi, tekrar dene'), findsNothing, reason: 'ag hatasi: ag metni');
    await unmount(tester);
  });

  testWidgets('imlec: sonraki sayfa kaydirinca yuklenir', (tester) async {
    final b = FakeBackend()
      ..on('/communities/categories', [])
      ..on('/me/communities*', {'items': <Object>[], 'nextCursor': null});
    b.handlers.add((req, path) {
      if (path != '/communities') return null;
      final cursor = req.url.queryParameters['cursor'];
      if (cursor == null) {
        return FakeResult.json({'items': [for (var i = 1; i <= 12; i++) _c(i, 'Kulüp A$i', n: 100 - i)], 'nextCursor': 'p2'});
      }
      return FakeResult.json({'items': [for (var i = 13; i <= 14; i++) _c(i, 'Kulüp A$i', n: 100 - i)], 'nextCursor': null});
    });
    await _pump(tester, b, size: kPhoneSmall);
    expect(b.requests.where((r) => r.contains('cursor=')), isEmpty);
    await tester.drag(find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical).first, const Offset(0, -2500));
    await settle(tester, const Duration(milliseconds: 700));
    expect(b.requests.where((r) => r.contains('cursor=p2')), hasLength(1));
    await tester.drag(find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical).first, const Offset(0, -2500));
    await settle(tester, const Duration(milliseconds: 400));
    expect(find.text('Kulüp A14'), findsOneWidget);
    await unmount(tester);
  });

  group('tasma matrisi (3 dil x acik/koyu x 1.0/1.3 x 320/390)', () {
    testWidgets('liste + uzun metinler', (tester) async {
      final b = _be(items: [
        _c(1, 'Bingöl Üniversitesi Bilgisayar Mühendisliği Öğrenci Topluluğu', n: 12034, desc: 'Çok uzun bir açıklama ' * 12, st: 'ACTIVE', role: 'OWNER'),
        ..._all.skip(1),
      ]);
      await p00Matrix(tester, () => ClubsTab(session: makeSession(b)), scaffold: false, settleMs: 700);
    });
  });

  testWidgets('dar ekran + buyuk yazi (320 x1.3): sirala satiri ve cipler tasmaz', (tester) async {
    final b = _be();
    ClubCategories.reset();
    useScreen(tester, kPhoneSmall);
    await tester.pumpWidget(buildApp(
      MediaQuery(data: const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.3)), child: ClubsTab(session: makeSession(b))),
      size: kPhoneSmall,
    ));
    await settle(tester, const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
