import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/message_requests_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

/// FOLLOWREQ-MB: mesaj istekleri kutusu (W2-D uçları) ve sohbet listesindeki giriş satırı.

String _iso() => DateTime.now().toUtc().toIso8601String();

Map<String, dynamic> _direct(int id, String name, String text) => {
      'id': id,
      'type': 'DIRECT',
      'requestState': 'PENDING',
      'peer': {'id': 50 + id, 'displayName': name},
      'unreadCount': 0,
      'lastMessage': {'id': 900 + id, 'conversationId': id, 'senderId': 50 + id, 'text': text, 'attachments': const [], 'createdAt': _iso()},
    };

Map<String, dynamic> _group(int id, String title) => {
      'id': id,
      'type': 'GROUP',
      'title': title,
      'requestState': 'PENDING',
      'unreadCount': 0,
      'lastMessage': {'id': 900 + id, 'conversationId': id, 'senderId': 77, 'text': 'Gruba hoş geldin', 'attachments': const [], 'createdAt': _iso()},
    };

FakeBackend _be({int n = 2}) {
  final b = FakeBackend()
    // Önek rotaları ekleme sırasıyla eşlenir: istekler `/conversations*` genel rotasından ÖNCE gelmeli.
    ..on('/conversations/requests/count', {'count': n})
    ..on('/conversations/requests*', {
      'items': [
        if (n > 0) _direct(41, 'Zeynep Demir', 'Merhaba, ders notları için yazıyorum'),
        if (n > 1) _group(42, 'Proje Grubu'),
      ],
      'nextCursor': null,
    })
    ..on('/conversations/unread-count', {'total': 0})
    ..on('/conversations*', {'items': <Object>[], 'nextCursor': null});
  return b;
}

void main() {
  setUpAll(loadTestFonts);

  group('Sohbet listesi girişi', () {
    testWidgets('n>0 iken "Mesaj istekleri (n)" satırı; dokununca istekler ekranı', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _be();
      await tester.pumpWidget(buildApp(ChatTab(session: makeSession(b), connectRealtime: false), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Mesaj istekleri (2)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('message-requests-entry')));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Mesaj istekleri'), findsOneWidget);
      expect(find.text('Zeynep Demir'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('n=0 iken satır yok; sayı alınamazsa sohbet listesi yine çalışır', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ChatTab(session: makeSession(_be(n: 0)), connectRealtime: false), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('message-requests-entry')), findsNothing);
      await unmount(tester);
      final b = _be()..fail('/conversations/requests/count', status: 500);
      await tester.pumpWidget(buildApp(ChatTab(session: makeSession(b), connectRealtime: false), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('message-requests-entry')), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('Mesaj istekleri ekranı', () {
    Future<void> mount(WidgetTester tester, FakeBackend b) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(MessageRequestsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
    }

    testWidgets('açıklama, satırlar, önizleme ve "Grup daveti" etiketi', (tester) async {
      await mount(tester, _be());
      expect(find.byKey(const ValueKey('message-requests-info')), findsOneWidget);
      expect(find.textContaining('Seninle ortak kulübü ya da etkinliği olmayan'), findsOneWidget);
      expect(find.textContaining('okunup okunmadığını görmez'), findsOneWidget);
      expect(find.text('Zeynep Demir'), findsOneWidget);
      expect(find.text('Merhaba, ders notları için yazıyorum'), findsOneWidget);
      expect(find.text('Proje Grubu'), findsOneWidget);
      expect(find.text('Grup daveti'), findsOneWidget);
      expect(find.text('Kabul et'), findsNWidgets(2));
      expect(find.text('Sil'), findsNWidgets(2));
      await unmount(tester);
    });

    testWidgets('Kabul et: POST accept, satır kalkar, sohbet listesi yenilenmek üzere işaretlenir', (tester) async {
      final b = _be();
      final s = makeSession(b);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(MessageRequestsPage(session: s), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      final before = s.badges.conversationsDirty.value;
      await tester.tap(find.byKey(const ValueKey('message-request-accept-41')));
      await settle(tester, const Duration(seconds: 1));
      expect(b.count('POST /conversations/41/accept'), 1);
      expect(find.text('Zeynep Demir'), findsNothing);
      expect(find.text('Proje Grubu'), findsOneWidget);
      expect(s.badges.conversationsDirty.value, before + 1);
      await unmount(tester);
    });

    testWidgets('Sil (birebir): onaysız POST decline', (tester) async {
      final b = _be();
      await mount(tester, b);
      await tester.tap(find.byKey(const ValueKey('message-request-decline-41')));
      await settle(tester, const Duration(seconds: 1));
      expect(b.count('POST /conversations/41/decline'), 1);
      expect(find.text('Zeynep Demir'), findsNothing);
      await unmount(tester);
    });

    testWidgets('Sil (grup daveti): önce onay, sonra POST decline; vazgeçince istek atılmaz', (tester) async {
      final b = _be();
      await mount(tester, b);
      await tester.tap(find.byKey(const ValueKey('message-request-decline-42')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Grup daveti silinsin mi?'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('/decline'), 0);
      expect(find.text('Proje Grubu'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('message-request-decline-42')));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('Daveti sil'));
      await settle(tester, const Duration(seconds: 1));
      expect(b.count('POST /conversations/42/decline'), 1);
      expect(find.text('Proje Grubu'), findsNothing);
      await unmount(tester);
    });

    testWidgets('kabul hatasında satır geri gelir', (tester) async {
      final b = _be()..fail('/conversations/41/accept', status: 409, code: 'REQUEST_NOT_PENDING', message: 'Bekleyen istek yok');
      await mount(tester, b);
      await tester.tap(find.byKey(const ValueKey('message-request-accept-41')));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Zeynep Demir'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('boş, hata ve yükleniyor durumları', (tester) async {
      await mount(tester, _be(n: 0));
      expect(find.byKey(const ValueKey('message-requests-empty')), findsOneWidget);
      expect(find.text('Bekleyen mesaj isteği yok.'), findsOneWidget);
      await unmount(tester);

      final off = _be()..offline = true;
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(MessageRequestsPage(session: makeSession(off)), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Yeniden dene'), findsOneWidget);
      off.offline = false;
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Zeynep Demir'), findsOneWidget);
      await unmount(tester);

      final slow = _be()..delay = const Duration(milliseconds: 400);
      await tester.pumpWidget(buildApp(MessageRequestsPage(session: makeSession(slow)), size: kPhoneMedium));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Zeynep Demir'), findsNothing);
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Zeynep Demir'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('satıra dokunmak sohbeti açar (okuma)', (tester) async {
      final b = _be()
        ..on('/conversations/41/messages*', {'items': <Object>[], 'nextCursor': null})
        ..on('/conversations/41', {'conversation': _direct(41, 'Zeynep Demir', 'Merhaba'), 'members': <Object>[]});
      await mount(tester, b);
      await tester.tap(find.byKey(const ValueKey('message-request-open-41')));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(ChatDetailPage), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Matris (tr/en/ar x açık/koyu x 1.0/1.3 x 320/390): taşma yok', () {
    FakeBackend wide() => _be()
      ..on('/conversations/requests*', {
        'items': [
          _direct(41, 'Zeynep Demir Çok Uzun Bir Soyadı Olan Öğrenci', 'Merhaba, ders notları için yazıyorum, uzun bir önizleme metni burada devam ediyor'),
          _group(42, 'Proje Grubu Çok Uzun Bir Grup Adı Taşma Denemesi İçin'),
        ],
        'nextCursor': null,
      });
    final screens = <String, Widget Function()>{
      'MessageRequestsPage': () => MessageRequestsPage(session: makeSession(wide())),
      'ChatTab + giriş satırı': () => ChatTab(session: makeSession(wide()), connectRealtime: false),
    };
    for (final e in screens.entries) {
      testWidgets(e.key, (tester) async {
        await p00Matrix(tester, e.value, scaffold: false, settleMs: 800);
      });
    }
  });
}
