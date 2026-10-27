import 'package:bu_kampus/features/chat/chat_info_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

Map<String, dynamic> _msg(int id) => {
      'id': id,
      'senderId': id.isEven ? 1 : 2,
      'createdAt': '2026-10-20T10:${(id % 60).toString().padLeft(2, '0')}:00Z',
      'attachments': [
        {'id': id, 'kind': 'IMAGE', 'url': '/api/conversations/5/media/$id', 'thumbUrl': '/api/conversations/5/media/$id/thumb'},
      ],
    };

const _conv = {
  'id': 5,
  'type': 'DIRECT',
  'peer': {'id': 2, 'displayName': 'Mehmet Kaya'},
};

const _members = [
  {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
  {'userId': 2, 'displayName': 'Mehmet Kaya'},
];

void main() {
  setUpAll(loadTestFonts);

  Future<void> pump(WidgetTester tester, FakeBackend be,
      {Brightness b = Brightness.light, Size size = kPhoneMedium, List<String>? saved, Map<String, dynamic> conv = _conv}) async {
    useScreen(tester, size);
    await tester.pumpWidget(buildApp(
      ChatInfoPage(
        session: makeSession(be),
        conversation: conv,
        members: _members.map((e) => Map<String, dynamic>.from(e)).toList(),
        subtitle: 'Çevrimiçi',
        saveImage: (url, h) async => saved?.add(url),
      ),
      brightness: b,
      size: size,
    ));
  }

  testWidgets('yükleniyor, sonra 3 sütunlu ızgara', (tester) async {
    final be = FakeBackend(delay: const Duration(milliseconds: 200));
    be.on('/conversations/5/messages?size=40', {
      'items': [for (var i = 12; i > 0; i--) _msg(i)],
      'nextCursor': null,
    });
    await pump(tester, be);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await settle(tester);
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final d = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(d.crossAxisCount, 3);
    expect(find.text('Medya'), findsOneWidget);
    expect(find.text('Mehmet Kaya'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('boş durum', (tester) async {
    final be = FakeBackend()..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null});
    await pump(tester, be);
    await settle(tester);
    expect(find.text('Bu sohbette henüz görsel yok.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('hata ve yeniden dene', (tester) async {
    final be = FakeBackend()..fail('/conversations/5/messages?size=40');
    await pump(tester, be);
    await settle(tester, const Duration(seconds: 3));
    expect(find.text('Yeniden dene'), findsOneWidget);
    be.on('/conversations/5/messages?size=40', {
      'items': [_msg(3), _msg(2)],
      'nextCursor': null,
    });
    await tester.tap(find.text('Yeniden dene'));
    await settle(tester);
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.text('Yeniden dene'), findsNothing);
    await unmount(tester);
  });

  testWidgets('sonsuz kaydırma ikinci sayfayı çeker', (tester) async {
    final be = FakeBackend();
    be.on('/conversations/5/messages?size=40', {
      'items': [for (var i = 100; i > 60; i--) _msg(i)],
      'nextCursor': 61,
    });
    be.on('/conversations/5/messages?size=40&before=61', {
      'items': [for (var i = 60; i > 20; i--) _msg(i)],
      'nextCursor': null,
    });
    await pump(tester, be);
    await settle(tester);
    expect(be.count('before='), 0);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await settle(tester);
    expect(be.count('before=61'), 1);
    await unmount(tester);
  });

  testWidgets('dokununca görüntüleyici açılır, sayaç doğru, İndir saveImage çağırır', (tester) async {
    final saved = <String>[];
    final be = FakeBackend()
      ..on('/conversations/5/messages?size=40', {
        'items': [for (var i = 8; i > 0; i--) _msg(i)],
        'nextCursor': null,
      });
    await pump(tester, be, saved: saved);
    await settle(tester);
    await tester.tap(find.byType(Image).first);
    await settle(tester);
    expect(find.textContaining(' / 8'), findsOneWidget);
    await tester.tap(find.byTooltip('İndir'));
    await settle(tester);
    expect(saved.length, 1);
    expect(find.text('Galeriye kaydedildi'), findsOneWidget);
    await tester.tap(find.byTooltip('Kapat'));
    await settle(tester);
    expect(find.textContaining(' / 8'), findsNothing);
    await unmount(tester);
  });

  testWidgets('kaydetme hatasında hata mesajı', (tester) async {
    final be = FakeBackend()
      ..on('/conversations/5/messages?size=40', {
        'items': [_msg(2), _msg(1)],
        'nextCursor': null,
      });
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(
      ChatInfoPage(
        session: makeSession(be),
        conversation: _conv,
        saveImage: (u, h) async => throw UnsupportedError('x'),
      ),
      size: kPhoneMedium,
    ));
    await settle(tester);
    await tester.tap(find.byType(Image).first);
    await settle(tester);
    await tester.tap(find.byTooltip('İndir'));
    await settle(tester);
    expect(find.text('Bu cihazda desteklenmiyor.'), findsOneWidget);
    await unmount(tester);
  });

  for (final b in Brightness.values) {
    for (final size in kPhoneSizes) {
      testWidgets('taşma yok: ${b.name} ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        final be = FakeBackend()
          ..on('/conversations/5/messages?size=40', {
            'items': [for (var i = 20; i > 0; i--) _msg(i)],
            'nextCursor': null,
          });
        await pump(tester, be, b: b, size: size, conv: {
          'id': 5,
          'type': 'GROUP',
          'title': 'Çok uzun bir grup sohbeti adı burada çok uzun bir grup sohbeti adı',
          'memberCount': 2,
        });
        await settle(tester);
        expect(tester.takeException(), isNull);
        await unmount(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('yükleme sürerken kaldırılınca istisna yok', (tester) async {
    final be = FakeBackend(delay: const Duration(milliseconds: 500));
    await pump(tester, be);
    await tester.pump(const Duration(milliseconds: 50));
    await unmount(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
