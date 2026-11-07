import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// iOS: Keşfet'ten açılan gönderi sayfasında soldan sağa (kenardan) kaydırınca Keşfet'e dönülür.

void main() {
  setUpAll(loadTestFonts);

  testWidgets('iOS: soldan sağa kenar kaydırması gönderi sayfasını kapatır', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend();
    final p = samplePost(id: 91, text: 'Kisa bir not', media: [samplePostMedia(id: 910)]);
    b.on('/posts/91', p);
    final s = makeSession(b);
    await tester.pumpWidget(buildApp(
      Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('open'),
              onPressed: () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => PostDetailPage(session: s, postId: 91, initial: Post.fromJson(p)))),
              child: const Text('Kesfet'),
            ),
          ),
        ),
      ),
      size: kPhoneMedium,
    ));
    await tester.tap(find.byKey(const ValueKey('open')));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.byType(PostDetailPage), findsOneWidget);
    final g = await tester.startGesture(const Offset(3, 300));
    await g.moveBy(const Offset(120, 0));
    await tester.pump();
    await g.moveBy(const Offset(200, 0));
    await tester.pump();
    await g.up();
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.byType(PostDetailPage), findsNothing, reason: 'kaydırma Keşfet\'e dönmeli');
    expect(find.text('Kesfet'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
