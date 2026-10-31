import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// K6: sohbet başlığı, oda bağlantısı, arama çubuğu, yazma alanı (yanıt/düzenleme), engelli ve boş durum.
String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _m(int id, int sender, String text) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': _iso(DateTime.now().subtract(Duration(minutes: 600 - id))),
    };

FakeBackend _backend(List<Map<String, dynamic>> msgs, {int? peer = 11, Map<String, dynamic>? presence}) {
  final b = FakeBackend()
    ..on('/conversations/1/messages?size=30', {'items': msgs, 'nextCursor': null})
    ..on('/conversations/1', {
      'conversation': {'id': 1},
      'members': [
        {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
        {'userId': 11, 'displayName': 'Ali Veli'},
        {'userId': 12, 'displayName': 'Can Er'},
      ],
    })
    ..on('/messages/reactions', {'emojis': ['👍']});
  if (peer != null) b.on('/users/$peer/presence', presence ?? {'online': true});
  return b;
}

Map<String, dynamic> _direct({bool blocked = false}) => {
      'id': 1,
      'type': 'DIRECT',
      'title': 'Ali Veli',
      'blocked': blocked,
      'peer': {'id': 11, 'displayName': 'Ali Veli'},
    };

ChatDetailPage _page(FakeBackend b, Map<String, dynamic> conv) =>
    ChatDetailPage(session: makeSession(b), conversation: conv, connectRealtime: false);

Future<void> _pump(WidgetTester t, Widget page, {bool dark = false}) async {
  useScreen(t, kPhoneMedium);
  await t.pumpWidget(buildApp(page, brightness: dark ? Brightness.dark : Brightness.light, size: kPhoneMedium));
  await settle(t, const Duration(milliseconds: 700));
}

void _ok(WidgetTester t) {
  final e = t.takeException();
  if (e != null) fail('$e');
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('birebir sohbet: başlık, çevrimiçi noktası ve yazma alanı öğeleri', (t) async {
    await _pump(t, _page(_backend([_m(1, 11, 'Selam')]), _direct()));
    expect(find.text('Ali Veli'), findsWidgets);
    expect(find.text('Çevrimiçi'), findsOneWidget);
    expect(find.byKey(const ValueKey('onlineDot')), findsOneWidget);
    expect(find.byKey(const ValueKey('roomPageChip')), findsNothing);
    for (final k in ['attachButton', 'composerField']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
    expect(find.byKey(const ValueKey('sendButton')), findsNothing, reason: 'metin yokken gönder görünmez (Stitch v3)');
    expect(find.byKey(const ValueKey('cameraShortcut')), findsNothing); // Q1: sohbet barinda kamera ikonu yok
    expect(find.byTooltip('Ekle'), findsOneWidget);
    expect(find.byTooltip('Kamera'), findsNothing);
    expect(find.byTooltip('Menü'), findsOneWidget);
    await unmount(t);
    _ok(t);
  });

  // Mesaj balonu/avatarı (K5) kapsam dışı: yalnız başlık + yazma alanı için mesajsız sohbet denetlenir.
  testWidgets('başlık ve yazma alanı: dokunma hedefleri 48 dp ve etiketli (açık/koyu)', (t) async {
    for (final dark in [false, true]) {
      final h = t.ensureSemantics();
      await _pump(t, _page(_backend([]), _direct()), dark: dark);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await unmount(t);
      h.dispose();
    }
    _ok(t);
  });

  testWidgets('kulüp ve etkinlik odası: sayfa bağlantı hapı', (t) async {
    final club = {'id': 1, 'type': 'CLUB', 'title': 'Robotik Kulübü', 'communityId': 5, 'memberCount': 86};
    await _pump(t, _page(_backend([_m(1, 11, 'Selam')], peer: null), club));
    expect(find.text('Robotik Kulübü'), findsWidgets);
    expect(find.text('Kulüp odası · 86 üye'), findsOneWidget);
    expect(find.byKey(const ValueKey('roomPageChip')), findsOneWidget);
    expect(find.text('Kulüp sayfası'), findsOneWidget);
    await unmount(t);

    final event = {'id': 1, 'type': 'EVENT', 'title': 'Bahar Şenliği', 'eventId': 7, 'memberCount': 42};
    await _pump(t, _page(_backend([_m(1, 11, 'Selam')], peer: null), event));
    expect(find.text('Etkinlik odası · 42 üye'), findsOneWidget);
    expect(find.text('Etkinlik sayfası'), findsOneWidget);
    await unmount(t);

    // Hedef kimliği yoksa bağlantı hapı çizilmez.
    await _pump(t, _page(_backend([_m(1, 11, 'Selam')], peer: null), {...club, 'communityId': null}));
    expect(find.byKey(const ValueKey('roomPageChip')), findsNothing);
    await unmount(t);
    _ok(t);
  });

  testWidgets('yanıt çubuğu: ad + alıntı, kapatınca kalkar; düzenleme çubuğu gönder = onay', (t) async {
    await _pump(t, _page(_backend([_m(2, 1, 'Benim mesajım'), _m(1, 11, 'Yarın sınav kaçta?')]), _direct()));
    await t.longPress(find.text('Yarın sınav kaçta?'));
    await settle(t, const Duration(milliseconds: 500));
    await t.tap(find.byKey(const ValueKey('act-reply')));
    await settle(t, const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('replyBar')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('replyBar')), matching: find.text('Yarın sınav kaçta?')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('replyBar')), matching: find.text('Ali Veli')), findsOneWidget);
    await t.tap(find.descendant(of: find.byKey(const ValueKey('replyBar')), matching: find.byIcon(LucideIcons.x)));
    await settle(t, const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('replyBar')), findsNothing);

    await t.longPress(find.text('Benim mesajım'));
    await settle(t, const Duration(milliseconds: 500));
    await t.tap(find.byKey(const ValueKey('act-edit')));
    await settle(t, const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('editBar')), findsOneWidget);
    expect(find.text('Mesaj düzenleniyor'), findsOneWidget);
    expect(find.byKey(const ValueKey('attachButton')), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('sendButton')), matching: find.byIcon(LucideIcons.check)), findsOneWidget);
    await unmount(t);
    _ok(t);
  });

  testWidgets('arama: sayaç, temizle, kapat; eşleşme yok / yazın metinleri', (t) async {
    await _pump(t, _page(_backend([_m(2, 11, 'kahve içelim'), _m(1, 1, 'kahve mi çay mı')]), _direct()));
    await t.tap(find.byTooltip('Menü'));
    await settle(t, const Duration(milliseconds: 400));
    await t.tap(find.text('Sohbette ara'));
    await settle(t, const Duration(milliseconds: 400));
    expect(find.text('Aramak için yazın'), findsOneWidget);
    expect(find.byKey(const ValueKey('chatSearchClear')), findsNothing);
    await t.enterText(find.byKey(const ValueKey('chatSearchField')), 'kahve');
    await settle(t, const Duration(milliseconds: 500));
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('chatSearchClear')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('chatSearchClear')));
    await settle(t, const Duration(milliseconds: 300));
    expect(find.text('Aramak için yazın'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('chatSearchField')), 'yok');
    await t.pump();
    expect(find.text('Eşleşme yok'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('chatSearchClose')));
    await settle(t, const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('chatSearchField')), findsNothing);
    await unmount(t);
    _ok(t);
  });

  testWidgets('engelli kişi: yazma alanı yerine satır + Engeli kaldır', (t) async {
    final b = _backend([_m(1, 11, 'Selam')]);
    await _pump(t, _page(b, _direct(blocked: true)));
    expect(find.byKey(const ValueKey('chatBlockedBar')), findsOneWidget);
    expect(find.text('Engellediğiniz kişiyle mesajlaşamazsınız.'), findsOneWidget);
    expect(find.byKey(const ValueKey('composerField')), findsNothing);
    await t.tap(find.byKey(const ValueKey('chatUnblockButton')));
    await settle(t, const Duration(milliseconds: 500));
    expect(b.count('DELETE /users/11/block'), 1);
    expect(find.byKey(const ValueKey('chatBlockedBar')), findsNothing);
    expect(find.byKey(const ValueKey('composerField')), findsOneWidget);
    await unmount(t);
    _ok(t);
  });


  testWidgets('mesaj silme onayı: BuDialog benzeri onay, Sil çağrısı yapar; Vazgeç yapmaz', (t) async {
    final b = _backend([_m(2, 1, 'Silinecek mesaj'), _m(1, 11, 'Selam')]);
    await _pump(t, _page(b, _direct()));
    Future<void> openDialog() async {
      await t.longPress(find.text('Silinecek mesaj'));
      await settle(t, const Duration(milliseconds: 500));
      await t.tap(find.byKey(const ValueKey('act-delete')));
      await settle(t, const Duration(milliseconds: 500));
    }

    await openDialog();
    expect(find.byKey(const ValueKey('chatConfirmDialog')), findsOneWidget);
    expect(find.text('Mesaj silinsin mi?'), findsOneWidget);
    expect(find.text('Bu mesaj herkes için silinir.'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('chatConfirmCancel')));
    await settle(t, const Duration(milliseconds: 400));
    expect(b.count('DELETE /messages/2'), 0);
    await openDialog();
    await t.tap(find.byKey(const ValueKey('chatConfirmOk')));
    await settle(t, const Duration(milliseconds: 500));
    expect(b.count('DELETE /messages/2'), 1);
    await unmount(t);
    _ok(t);
  });

  testWidgets('sohbet menüsü: satırlar, oda kartı; arama açılınca yazma alanı gizlenir', (t) async {
    final club = {'id': 1, 'type': 'CLUB', 'title': 'Yazılım Kulübü', 'communityId': 5, 'memberCount': 86};
    await _pump(t, _page(_backend([_m(1, 11, 'Selam')], peer: null), club));
    await t.tap(find.byTooltip('Menü'));
    await settle(t, const Duration(milliseconds: 500));
    for (final k in ['search', 'members', 'media', 'room', 'settings', 'about']) {
      expect(find.byKey(ValueKey('menu-$k')), findsOneWidget, reason: k);
    }
    expect(find.byKey(const ValueKey('menu-leave')), findsNothing);
    await t.tap(find.byKey(const ValueKey('menu-search')));
    await settle(t, const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('chatSearchField')), findsOneWidget);
    expect(find.byKey(const ValueKey('composerField')), findsNothing);
    await t.tap(find.byKey(const ValueKey('chatSearchClose')));
    await settle(t, const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('composerField')), findsOneWidget);

    // Birebir sohbette engelle + şikâyet satırları.
    await unmount(t);
    await _pump(t, _page(_backend([_m(1, 11, 'Selam')]), _direct()));
    await t.tap(find.byTooltip('Menü'));
    await settle(t, const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('menu-block')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-report')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-members')), findsNothing);
    await unmount(t);
    _ok(t);
  });

  testWidgets('boş sohbet: tek cümle (P3-CHAT: açıklama satırı kalktı)', (t) async {
    await _pump(t, _page(_backend([]), _direct()));
    expect(find.text('Henüz mesaj yok'), findsOneWidget);
    expect(find.text('İlk mesajı sen yaz.'), findsNothing);
    expect(find.byKey(const ValueKey('composerField')), findsOneWidget);
    await unmount(t);
    _ok(t);
  });

  testWidgets('tasma matrisi (tr/en/ar x açık/koyu x 1.0/1.3 x 320/390): kulüp odası, engelli, boş', (t) async {
    final club = {'id': 1, 'type': 'CLUB', 'title': 'Robotik Mühendisliği ve Otomasyon Kulübü', 'communityId': 5, 'memberCount': 86};
    for (final build in <Widget Function()>[
      () => _page(_backend([_m(2, 11, 'Merhaba, toplantı ne zaman?'), _m(1, 12, 'Cumartesi 14.00')], peer: null), club),
      () => _page(_backend([_m(1, 11, 'Selam')]), _direct(blocked: true)),
      () => _page(_backend([]), _direct()),
    ]) {
      await p00Matrix(t, build, scaffold: false, settleMs: 700);
    }
  });
}
