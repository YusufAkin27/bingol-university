import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/post_stream.dart';
import 'package:bu_kampus/widgets/bu.dart' show BuAvatar, BuHero, BuIconButton, BuSkeleton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'package:bu_kampus/core/icons/bu_icons.dart';

// KESFET2-MB: SARTNAME (C:\bu_design\stitch\v3_kesfet2) ve PNG referanslarindan okunan olculer, uygulama +-2 dp.
// Referans PNG 780x1688 (390x844 dp @2x); "ref" degerleri PNG'den piksel/2 ile olculmustur (SARTNAME'de olanlar SARTNAME'den).
// Mutlak ust ofset (durum cubugu/guvenli alan) tum sekmelerde ortaktir ve karsilastirilmaz: dikey olculer baslik satirina
// goreli verilir. Tablo `docs/design/BIREBIR_FEED.md` "Kesfet v2"de.

final _rows = <String>[];

void row(String name, num ref, num app, {double tol = 2}) {
  final d = (app - ref).toDouble();
  _rows.add('| $name | ${ref.toStringAsFixed(1)} | ${app.toStringAsFixed(1)} | ${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)} |');
  expect(d.abs(), lessThanOrEqualTo(tol), reason: '$name: ref $ref, uygulama $app');
}

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split(String.fromCharCode(10)).take(30).join(String.fromCharCode(10))}');
}

Map<String, dynamic> post(int i, int w, int h, {bool liked = false, int likes = 284, String? name}) {
  final p = samplePost(
    id: 500 - i,
    media: [samplePostMedia(id: i, width: w, height: h)],
    text: 'Bahar geldi kampüse',
    likeCount: likes,
    liked: liked,
    authorId: 20 + i,
    authorName: name ?? 'Emre Kaya',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
  );
  (p['author'] as Map)['department'] = 'Makine Mühendisliği';
  return p;
}

void main() {
  setUpAll(loadTestFonts);
  tearDownAll(() {
    // ignore: avoid_print
    print('\n--- OLCU TABLOSU ---\n| Olcu | Referans dp | Uygulama dp | Fark |\n|---|---|---|---|\n${_rows.join('\n')}\n--- /OLCU TABLOSU ---');
  });

  testWidgets('Kesfet masonry: yerlesim, kutu, gradyan, yazar, kalp (390 dp)', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    b.on('/feed*', {
      'items': [post(1, 1080, 1440, liked: true), post(2, 1080, 1080, name: 'Zeynep Arslan'), post(3, 1080, 1620), post(4, 1080, 1350, name: 'Elif Yıldız'), post(5, 1080, 1080)],
      'nextCursor': null,
    });
    b.on('/users/me/follow-suggestions*', {'items': <Object>[]});
    await tester.pumpWidget(buildApp(DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null))));
    await settle(tester, const Duration(milliseconds: 900));

    Finder box(int i) => find.byKey(ValueKey('discover-post-${500 - i}'));
    final r1 = tester.getRect(box(1)); // 3:4 sol
    final r2 = tester.getRect(box(2)); // 1:1 sag
    final r3 = tester.getRect(box(3)); // 2:3 sag
    final r4 = tester.getRect(box(4)); // 4:5 sol

    // Baslik + ust alan (baslik satirina goreli)
    final title = tester.widget<Text>(find.text('Keşfet'));
    row('Başlık punto (sp)', 28, title.style!.fontSize!);
    expect(title.style!.fontWeight, FontWeight.w700);
    final titleCy = tester.getRect(find.text('Keşfet')).center.dy;
    final search = tester.widget<BuIconButton>(find.byKey(const ValueKey('discoverSearch')));
    row('Arama düğmesi görünür boyut', 44, search.size);
    row('İlk kutu üstü - başlık merkezi (dikey)', 76, r1.top - titleCy);

    // Izgara
    row('Yan kenar (sol)', 12, r1.left);
    row('Yan kenar (sağ)', 12, 390 - r2.right);
    row('Sütun genişliği', 179, r1.width);
    row('Sütun arası', 8, r2.left - r1.right);
    row('Satır arası (sütun içi)', 8, r3.top - r2.bottom);
    row('Kutu yüksekliği 3:4', 238.7, r1.height);
    row('Kutu yüksekliği 1:1', 179, r2.height);
    row('Kutu yüksekliği 2:3', 268.5, r3.height);
    row('Kutu yüksekliği 4:5', 223.8, r4.height);
    row('Kutu yüksekliği 1:1 (5.)', 179, tester.getRect(box(5)).height);

    // Kutu: kose + gradyan
    final hero = tester.widget<BuHero>(find.descendant(of: box(1), matching: find.byType(BuHero)));
    row('Köşe yarıçapı', 16, hero.radius);
    final scrim = tester.widget<FractionallySizedBox>(find.descendant(of: box(1), matching: find.byWidgetPredicate((w) => w is FractionallySizedBox && w.heightFactor != null)));
    row('Gradyan yüksekliği (% kutu)', 42, scrim.heightFactor! * 100, tol: .5);
    final deco = tester.widget<DecoratedBox>(find.descendant(of: box(1), matching: find.byKey(const ValueKey('discoverBoxScrim')))).decoration as BoxDecoration;
    final g = deco.gradient! as LinearGradient;
    row('Gradyan alfa üst (%)', 0, g.colors[0].a * 100, tol: .5);
    row('Gradyan alfa orta (%)', 28, g.colors[1].a * 100, tol: .5);
    row('Gradyan alfa alt (%)', 62, g.colors[2].a * 100, tol: .5);
    expect(g.colors[0].withValues(alpha: 1), BuTokens.light.scrim);

    // Yazar (sol alt)
    final av = find.descendant(of: box(1), matching: find.byType(BuAvatar));
    final avRect = [for (final e in find.ancestor(of: av, matching: find.byType(DecoratedBox)).evaluate()) tester.getRect(find.byWidget(e.widget))].firstWhere((r) => r.width > 28);
    row('Avatar boyutu (halka dahil)', 29, avRect.width);
    row('Avatar sol boşluk', 9, avRect.left - r1.left);
    row('Avatar merkezi alttan', 22, r1.bottom - avRect.center.dy);
    final nameFinder = find.descendant(of: box(1), matching: find.text('Emre Kaya'));
    final name = tester.widget<Text>(nameFinder);
    row('Ad punto (sp)', 13, name.style!.fontSize!);
    expect(name.style!.fontWeight, FontWeight.w600);
    expect(name.maxLines, 1);
    row('Ad başlangıcı (kutu soluna)', 42, tester.getRect(nameFinder).left - r1.left);
    row('Ad merkezi alttan', 22, r1.bottom - tester.getRect(nameFinder).center.dy);

    // Kalp + sayi (sag alt)
    final heart = find.descendant(of: box(1), matching: find.byKey(const ValueKey('like-heart')));
    row('Kalp boyutu', 20, tester.getSize(heart).width);
    row('Kalp merkezi alttan', 22, r1.bottom - tester.getRect(heart).center.dy);
    final countF = find.descendant(of: box(1), matching: find.byKey(const ValueKey('like-count')));
    final count = tester.widget<Text>(countF);
    row('Sayı punto (sp)', 13, count.style!.fontSize!);
    expect(count.style!.fontWeight, FontWeight.w600);
    row('Sayı sağ boşluk', 10, r1.right - tester.getRect(countF).right);
    row('Kalp ile sayı arası', 5, tester.getRect(countF).left - tester.getRect(heart).right, tol: 2);
    final tap = tester.getSize(find.ancestor(of: heart, matching: find.byType(GestureDetector)).first);
    row('Beğeni dokunma yüksekliği (≥44)', 44, tap.height < 44 ? tap.height : 44);
    final authorTap = tester.getSize(find.byKey(const ValueKey('discover-author-499')));
    row('Yazar dokunma yüksekliği (≥44)', 44, authorTap.height < 44 ? authorTap.height : 44);
    // Beğenilmiş: dolu beyaz kalp
    expect(find.descendant(of: box(1), matching: find.byIcon(BuIcons.heartFilled)), findsOneWidget);
    noErr(tester);
  });

  testWidgets('Kesfet iskeleti: 6 kutu (238/179/268/224/179/238 dp), kose 16, kenar 12', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend()..delay = const Duration(seconds: 2);
    b.on('/feed*', {'items': <Object>[], 'nextCursor': null});
    await tester.pumpWidget(buildApp(DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null))));
    await tester.pump(const Duration(milliseconds: 100));
    final blocks = find.descendant(of: find.byKey(const ValueKey('discoverSkeleton')), matching: find.byType(BuSkeleton));
    final exp = [238.7, 179, 268.5, 223.8, 179, 238.7];
    // Kutu bloklari (avatar/cubuk degil): genisligi 179 olanlar.
    final big = [for (final e in blocks.evaluate()) tester.getRect(find.byWidget(e.widget))].where((r) => r.width > 100).toList()
      ..sort((a, c) => a.top == c.top ? a.left.compareTo(c.left) : a.top.compareTo(c.top));
    expect(big.length, 6);
    // Yerlesim sirasi (top, left) siralidir; sutun sirasina gore eslestir: sol 238.7, 223.8, 238.7; sag 179, 268.5, 179.
    final left = big.where((r) => r.left < 100).map((r) => r.height).toList();
    final right = big.where((r) => r.left > 100).map((r) => r.height).toList();
    for (var i = 0; i < 3; i++) {
      row('İskelet sol sütun ${i + 1}. kutu', [exp[0], exp[3], exp[5]][i], left[i]);
      row('İskelet sağ sütun ${i + 1}. kutu', [exp[1], exp[2], exp[4]][i], right[i]);
    }
    row('İskelet sol kenar', 12, big.first.left);
    final sk = tester.widget<BuSkeleton>(blocks.first);
    row('İskelet köşe', 16, sk.radius);
    await settle(tester, const Duration(seconds: 3));
    noErr(tester);
  });

  testWidgets('Oneri bandi (07): tam genislik, baslik 16/600, avatar 56, Takip et 36 dp', (tester) async {
    useScreen(tester, const Size(390, 1500));
    final b = FakeBackend();
    b.on('/feed*', {'items': [for (var i = 1; i <= 8; i++) post(i, 1080, i.isEven ? 1080 : 1350)], 'nextCursor': null});
    b.on('/users/me/follow-suggestions*', {
      'items': [
        {'id': 31, 'displayName': 'Burak Çelik', 'department': 'Bilgisayar Müh.', 'followedByMe': false},
        {'id': 32, 'displayName': 'Ayşe Demir', 'department': 'Hemşirelik', 'followedByMe': false},
        {'id': 33, 'displayName': 'Deniz Öztürk', 'department': 'İşletme', 'followedByMe': false},
      ],
    });
    await tester.pumpWidget(buildApp(DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null))));
    await settle(tester, const Duration(milliseconds: 900));
    final band = tester.getRect(find.byKey(const ValueKey('discoverSuggestions')));
    row('Bant genişliği', 390, band.width);
    final t = tester.widget<Text>(find.text('Tanıyor Olabilirsin'));
    row('Bant başlık punto (sp)', 16, t.style!.fontSize!);
    final above = [for (var i = 1; i <= 8; i++) tester.getRect(find.byKey(ValueKey('discover-post-${500 - i}')))].where((r) => r.bottom <= band.top + 1).map((r) => r.bottom);
    final prevBottom = above.reduce((a, c) => a > c ? a : c);
    final avatar = tester.getRect(find.descendant(of: find.byKey(const ValueKey('discoverSuggestions')), matching: find.byType(BuAvatar)).first);
    row('Bant avatar boyutu', 56, avatar.width);
    final follow = tester.getSize(find.descendant(of: find.byKey(const ValueKey('discover-follow-31')), matching: find.byType(AnimatedContainer)));
    row('Takip et yüksekliği', 36, follow.height);
    // Referans 07: bant basligi merkezi onceki kutu altindan 28 dp; avatar ustu basliktan 11 dp altta; buton alti sonraki kutuya 24 dp.
    final tc = tester.getRect(find.text('Tanıyor Olabilirsin')).center.dy;
    row('Önceki kutu altı -> bant başlığı merkezi', 28, tc - prevBottom);
    row('Bant başlığı merkezi -> avatar üstü', 22, avatar.top - tc);
    final next = tester.getRect(find.byKey(const ValueKey('discover-post-${500 - 5}')));
    row('Takip et altı -> sonraki kutu', 24, next.top - tester.getRect(find.byKey(const ValueKey('discover-follow-31'))).bottom);
    noErr(tester);
  });

  testWidgets('Gonderi sayfasi (08/09): baslik, yazar satiri, 4:5 foto, kalp satiri, ayirici, geri dugmesi', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    final p0 = Post.fromJson(post(1, 1080, 1350, likes: 128, name: 'Mehmet Kaya'));
    final items = [Post.fromJson(post(2, 1080, 1350, name: 'Elif Yıldız', likes: 86)), Post.fromJson(post(3, 1080, 1350, name: 'Can Aydın', likes: 198))];
    b.on('/posts/*', post(1, 1080, 1350, likes: 128, name: 'Mehmet Kaya'));
    await tester.pumpWidget(buildApp(PostDetailPage(
      session: makeSession(b),
      postId: p0.id,
      initial: p0,
      stream: PostStreamSeed(items: items, hasMore: false),
    )));
    await settle(tester, const Duration(milliseconds: 900));
    final card = find.byKey(ValueKey('stream-post-${p0.id}'));
    // Baslik: 18/600, x=60, merkez y=28-29
    final title = tester.widget<Text>(find.text('Gönderi'));
    row('Başlık punto (sp)', 18, title.style!.fontSize!);
    expect(title.style!.fontWeight, FontWeight.w600);
    row('Başlık sol (x)', 60, tester.getRect(find.text('Gönderi')).left);
    row('Başlık merkezi (y)', 29, tester.getRect(find.text('Gönderi')).center.dy);
    row('Geri düğmesi dokunma alanı', 48, tester.getSize(find.byKey(const ValueKey('postBack'))).width);
    // Yazar satiri
    final avatar = tester.getRect(find.descendant(of: card, matching: find.byType(BuAvatar)).first);
    row('Yazar avatar boyutu', 40, avatar.width);
    row('Yazar avatar sol', 20, avatar.left);
    row('Yazar avatar üstü', 64, avatar.top);
    final name = tester.widget<Text>(find.descendant(of: card, matching: find.text('Mehmet Kaya')));
    row('Yazar adı punto (sp)', 15, name.style!.fontSize!);
    expect(name.style!.fontWeight, FontWeight.w600);
    row('Yazar adı sol', 72, tester.getRect(find.descendant(of: card, matching: find.text('Mehmet Kaya'))).left, tol: 3);
    // Foto
    final photo = tester.getRect(find.descendant(of: card, matching: find.byKey(ValueKey('post-photo-${p0.id}'))));
    row('Foto sol', 20, photo.left);
    row('Foto genişliği', 350, photo.width);
    row('Foto yüksekliği (4:5)', 437, photo.height);
    row('Foto üstü', 120, photo.top);
    // Kalp satiri + ayirici
    final heart = tester.getRect(find.descendant(of: card, matching: find.byKey(const ValueKey('like-heart'))));
    row('Kalp satırı merkezi (foto altından)', 25, heart.center.dy - photo.bottom, tol: 3);
    final div = tester.getRect(find.byKey(const ValueKey('postStreamDivider')).first);
    row('Ayırıcı (foto altından)', 61, div.top - photo.bottom);
    row('Ayırıcı kalınlığı', 1, div.height, tol: .1);
    row('Ayırıcı sol', 20, div.left);
    final next = tester.getRect(find.descendant(of: find.byKey(ValueKey('stream-post-${items[0].id}')), matching: find.byType(BuAvatar)).first);
    row('Ayırıcı -> sonraki avatar üstü', 32.5, next.top - div.bottom);
    row('Gönderi aralığı (avatar üstü -> avatar üstü)', 586, next.top - avatar.top, tol: 3);

    // Kaydirilinca (09): baslik kaybolur, geri dugmesi yuvarlak zemin 40 dp, sol 9 ust 8,5
    tester.state<ScrollableState>(find.descendant(of: find.byKey(const ValueKey('postStream')), matching: find.byType(Scrollable)).first).position.jumpTo(500);
    await settle(tester, const Duration(milliseconds: 400));
    final circle = tester.getRect(find.byKey(const ValueKey('postBackCircle')));
    row('Geri dairesi çapı', 40, circle.width);
    row('Geri dairesi sol', 9, circle.left);
    row('Geri dairesi üst', 8.5, circle.top);
    final op = tester.widget<AnimatedOpacity>(find.ancestor(of: find.byKey(const ValueKey('postBackCircle')), matching: find.byType(AnimatedOpacity)).first);
    row('Daire zemin opaklığı (%)', 94, op.opacity * 100, tol: .5);
    noErr(tester);
  });
}
