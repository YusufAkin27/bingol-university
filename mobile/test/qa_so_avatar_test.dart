import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/chatlist_widgets.dart';
import 'package:bu_kampus/widgets/profile_photo_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_media.dart';

/// QA-SO: AvatarLongPress tutarlılığı: sohbet listesi / başlık / gönderen avatarı (ChatlistAvatar.preview).

const _vBackdrop = ValueKey('profilePhotoViewerBackdrop');

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(20).join('\n')}');
}

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _row(int id, String title, {String? avatar}) => {
      'id': id,
      'type': 'DIRECT',
      'title': title,
      'peer': {'id': 10 + id, 'displayName': title, if (avatar != null) 'avatarUrl': avatar},
      'unreadCount': 0,
      'lastMessage': {'id': 100 + id, 'conversationId': id, 'senderId': 10 + id, 'text': 'selam', 'attachments': const [], 'createdAt': _iso(DateTime.now())},
    };

void main() {
  setUpAll(loadTestFonts);
  setUp(() => ProfilePhotoViewer.providerOverride = (_, __, ___) => MemoryImage(fakePng));
  tearDown(() => ProfilePhotoViewer.providerOverride = null);

  testWidgets('ChatlistAvatar(preview): fotoğraf varsa uzun basma önizleme açar, dokunuş üst öğeye düşer; yoksa hiçbir şey', (tester) async {
    useScreen(tester, kPhoneMedium);
    var taps = 0;
    await tester.pumpWidget(buildApp(Scaffold(
      body: Center(
        child: GestureDetector(
          onTap: () => taps++,
          child: Column(mainAxisSize: MainAxisSize.min, children: const [
            ChatlistAvatar(key: ValueKey('with'), name: 'Mehmet', url: '/files/avatars/m.jpg', preview: true),
            SizedBox(height: 24),
            ChatlistAvatar(key: ValueKey('without'), name: 'Zeynep', preview: true),
            SizedBox(height: 24),
            ChatlistAvatar(key: ValueKey('plain'), name: 'Ali', url: '/files/avatars/a.jpg'),
          ]),
        ),
      ),
    )));
    await tester.tap(find.byKey(const ValueKey('with')));
    expect(taps, 1, reason: 'dokunuş sarmalayan öğeye geçer');
    await tester.longPress(find.byKey(const ValueKey('without')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_vBackdrop), findsNothing);
    await tester.longPress(find.byKey(const ValueKey('plain')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_vBackdrop), findsNothing, reason: 'preview kapalıyken (varsayılan) önizleme yok');
    await tester.longPress(find.byKey(const ValueKey('with')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_vBackdrop), findsOneWidget);
    await tester.tapAt(const Offset(10, 300));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.byKey(_vBackdrop), findsNothing);
    noErr(tester);
  });

  testWidgets('sohbet listesi: avatara uzun basma fotoğraf önizler; satıra uzun basma menüyü açar', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend()
      ..on('/conversations/unread-count', {'total': 0})
      ..on('/conversations*', {
        'items': [_row(1, 'Mehmet Kaya', avatar: '/files/avatars/m.jpg'), _row(2, 'Zeynep Demir')],
        'nextCursor': null,
      });
    await tester.pumpWidget(buildApp(ChatTab(session: makeSession(b), connectRealtime: false), size: kPhoneMedium));
    await settle(tester, const Duration(seconds: 1));
    final avatars = find.byType(ChatlistAvatar);
    expect(avatars, findsNWidgets(2));
    // Fotoğrafsız avatar: uzun basma satırın menüsüne düşer (önizleme yok).
    await tester.longPress(avatars.last);
    await settle(tester, const Duration(milliseconds: 400));
    expect(find.byKey(_vBackdrop), findsNothing);
    await tester.tapAt(const Offset(10, 60));
    await settle(tester, const Duration(milliseconds: 400));
    // Fotoğraflı avatar: önizleme.
    await tester.longPress(avatars.first);
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.byKey(_vBackdrop), findsOneWidget);
    noErr(tester);
  });
}
