import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/post_save_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

class _Host extends StatefulWidget {
  const _Host(this.session, this.initial);
  final Session session;
  final Post initial;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Post p = widget.initial;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SingleChildScrollView(
          child: PostCard(session: widget.session, post: p, onChanged: (v) => setState(() => p = v), onDeleted: (_) {}),
        ),
      );
}

void main() {
  setUpAll(loadTestFonts);

  Map<String, dynamic> json({bool saved = false}) => {
        ...samplePost(id: 91, text: 'Not', media: [samplePostMedia(id: 910)], authorId: 12),
        'savedByMe': saved,
      };

  testWidgets('fotografli gonderi kartinda kaydet: PUT /posts/{id}/save, simge dolar', (t) async {
    useScreen(t, const Size(390, 844));
    final b = FakeBackend();
    b.handlers.add((req, path) => path == '/posts/91/save' ? FakeResult.json({'saved': req.method == 'PUT'}) : null);
    await t.pumpWidget(buildApp(_Host(makeSession(b), Post.fromJson(json()))));
    await settle(t, const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('post-save')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('post-save')));
    await settle(t, const Duration(milliseconds: 600));
    expect(b.requests, contains('PUT /posts/91/save'));
    await t.tap(find.byKey(const ValueKey('post-save')));
    await settle(t, const Duration(milliseconds: 600));
    expect(b.requests, contains('DELETE /posts/91/save'));
    await unmount(t);
  });

  testWidgets('kaydet hata verirse iyimser durum geri alinir', (t) async {
    useScreen(t, const Size(390, 844));
    final b = FakeBackend()..fail('/posts/91/save', status: 500);
    await t.pumpWidget(buildApp(_Host(makeSession(b), Post.fromJson(json()))));
    await settle(t, const Duration(milliseconds: 300));
    await t.tap(find.byKey(const ValueKey('post-save')));
    await settle(t, const Duration(milliseconds: 600));
    final host = t.state<_HostState>(find.byType(_Host));
    expect(host.p.savedByMe, isFalse);
    await unmount(t);
  });

  testWidgets('kaydetme ucustayken yapilan baska degisiklik (begeni) eski goruntuyle ezilmez', (t) async {
    useScreen(t, const Size(390, 844));
    final b = FakeBackend();
    final snap = Post.fromJson(json());
    var current = snap;
    // Sunucu yanıtı gelmeden önce kullanıcı beğeniyi değiştirdi: güncel nesne eski anlık görüntüden farklıdır.
    b.handlers.add((req, path) {
      if (path != '/posts/91/save') return null;
      current = current.copyWith(likedByMe: !(current.likedByMe));
      return FakeResult.json({'saved': true});
    });
    late BuildContext ctx;
    await t.pumpWidget(buildApp(Scaffold(body: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }))));
    await togglePostSaved(ctx, makeSession(b), snap, (v) => current = v, latest: () => current);
    await settle(t, const Duration(milliseconds: 300));
    expect(current.savedByMe, isTrue);
    expect(current.likedByMe, isNot(snap.likedByMe), reason: 'beğeni değişikliği korunmalı');
    await unmount(t);
  });
}
