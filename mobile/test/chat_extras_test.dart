import 'dart:io';

import 'package:bu_kampus/features/chat/sohbety_widgets.dart';
import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/realtime/chat_realtime.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_media.dart';
import 'package:bu_kampus/features/chat/chat_media_viewer.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/view_once_viewer.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_media.dart';

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _msg(int id, int sender, String text, {Map<String, dynamic>? extra}) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': _iso(DateTime.now().subtract(Duration(minutes: 600 - id))),
      ...?extra,
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> items, {int? next}) => {'items': items, 'nextCursor': next};

const _emojis = ['👍', '❤️'];

// 1x1 PNG
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Map<String, dynamic> _onceIn(int id, {bool viewed = false, bool withUrl = true}) => _msg(id, 11, '', extra: {
      'attachments': [
        {
          'id': 50,
          'kind': 'IMAGE',
          'viewOnce': true,
          'viewed': viewed,
          'thumbUrl': null,
          'url': withUrl ? '/api/conversations/1/media/50' : null,
        },
      ],
    });

Map<String, dynamic> _onceOut(int id, {bool viewed = false}) => _msg(id, 1, '', extra: {
      'attachments': [
        {'id': 51, 'kind': 'IMAGE', 'viewOnce': true, 'viewed': viewed, 'thumbUrl': null, 'url': null},
      ],
    });

Future<void> _loadFonts() async {
  await loadTestFonts();
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter';
  final loader = FontLoader('Inter');
  var any = false;
  for (final f in ['regular', 'medium', 'bold']) {
    final file = File('$root/bin/cache/artifacts/material_fonts/roboto-$f.ttf');
    if (!file.existsSync()) continue;
    any = true;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  if (any) await loader.load();
}

FakeBackend _backend(List<Map<String, dynamic>> msgs, {int? next}) => FakeBackend()
  ..on('/conversations/1/messages?size=30', _page(msgs, next: next))
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Ali Veli'},
    ],
  })
  ..on('/users/11/presence', {'online': true})
  ..on('/messages/reactions', {'emojis': _emojis});

ChatDetailPage _detail(Session s,
        {ChatRealtime? rt, Map<String, dynamic>? conv, FakeMediaLibrary? library, FakeBackend? upload}) =>
    ChatDetailPage(
      session: s,
      connectRealtime: false,
      realtime: rt,
      mediaLibrary: library ?? FakeMediaLibrary.photos(3),
      ensureAccess: (c, p, {rationale}) async => true,
      uploadClient: upload?.client,
      conversation: conv ??
          {
            'id': 1,
            'type': 'DIRECT',
            'title': 'Ali Veli',
            'peer': {'id': 11, 'displayName': 'Ali Veli'},
          },
    );

Future<void> _pump(WidgetTester tester, Widget page, {Brightness b = Brightness.light, Size size = kPhoneMedium}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(page, brightness: b, size: size));
  await settle(tester, const Duration(milliseconds: 600));
}

void _ok(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('$e');
}

const _card = ValueKey('msgActions.card');
const _root = ValueKey('msgActions.root');

bool _hasHighlight(WidgetTester tester) {
  var found = false;
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    w.text.visitChildren((s) {
      if (s is TextSpan && s.style?.backgroundColor != null) found = true;
      return true;
    });
  }
  return found;
}

void main() {
  setUpAll(_loadFonts);

  group('Menu: cizgi hatasi ve modal', () {
    testWidgets('menudeki hicbir metinde alt cizgi yok, Material atasi var', (tester) async {
      await _pump(tester, _detail(makeSession(_backend([_msg(2, 1, 'Selam'), _msg(1, 11, 'Merhaba')]))));
      await tester.longPress(find.text('Selam'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(_card), findsOneWidget);
      expect(find.ancestor(of: find.byKey(_card), matching: find.byType(Material)), findsWidgets);
      final texts = find.descendant(of: find.byKey(_root), matching: find.byType(Text));
      expect(texts, findsWidgets);
      for (final el in texts.evaluate()) {
        final w = el.widget as Text;
        final d = DefaultTextStyle.of(el).style.merge(w.style).decoration;
        expect(d == null || d == TextDecoration.none, isTrue, reason: '"${w.data}" decoration=$d');
      }
      // Tepki emojileri dahil
      expect(find.text('👍'), findsWidgets);
      _ok(tester);
    });

    testWidgets('modal: bariyer kapatir, alttaki liste etkilesmez, geri tusu kapatir', (tester) async {
      await _pump(tester, _detail(makeSession(_backend([_msg(2, 1, 'Selam'), _msg(1, 11, 'Merhaba')]))));
      await tester.longPress(find.text('Selam'));
      await settle(tester, const Duration(milliseconds: 500));
      final route = ModalRoute.of(tester.element(find.byKey(_root)))!;
      expect(route.barrierDismissible, isTrue);
      // Menü açıkken alttaki mesajı sağa sürükleme yanıt başlatmaz (etkileşim yok).
      await tester.dragFrom(const Offset(40, 560), const Offset(120, 0));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byTooltip('Vazgeç'), findsNothing);
      // Bariyer dokunuşu kapatır.
      await tester.tapAt(const Offset(4, 4));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(_card), findsNothing);
      await tester.longPress(find.text('Selam'));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.binding.handlePopRoute();
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(_card), findsNothing);
      _ok(tester);
    });
  });

  group('Klavye ve kaydirma', () {
    testWidgets('liste surukleyince klavye kapanir', (tester) async {
      final msgs = [for (var i = 40; i > 0; i--) _msg(i, i.isEven ? 1 : 11, 'Mesaj $i')];
      await _pump(tester, _detail(makeSession(_backend(msgs))));
      final list = tester.widget<ListView>(find.byType(ListView).first);
      expect(list.keyboardDismissBehavior, ScrollViewKeyboardDismissBehavior.onDrag);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      bool focused() => tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;
      expect(focused(), isTrue);
      await tester.drag(find.byType(ListView).first, const Offset(0, 120));
      await settle(tester, const Duration(milliseconds: 300));
      expect(focused(), isFalse);
      _ok(tester);
    });

    testWidgets('asagi kaydir dugmesi: rozet sayar, dokununca en alta iner', (tester) async {
      final msgs = [for (var i = 40; i > 0; i--) _msg(i, 11, 'Mesaj $i')];
      final s = makeSession(_backend(msgs));
      final rt = ChatRealtime(s);
      await _pump(tester, _detail(s, rt: rt));
      expect(find.byKey(const ValueKey('scrollDown')), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, 500));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('scrollDown')), findsOneWidget);
      rt.debugEmitMessage(_msg(41, 11, 'Yeni mesaj'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.descendant(of: find.byKey(const ValueKey('scrollDown')), matching: find.text('1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scrollDown')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('scrollDown')), findsNothing);
      expect(find.text('Yeni mesaj'), findsOneWidget);
      await unmount(tester);
      _ok(tester);
    });
  });

  group('Tek gosterimlik', () {
    testWidgets('alicida onizleme yok; dokununca goruntuleyici, kapaninca Acildi', (tester) async {
      final be = _backend([_onceIn(7)])..onBytes('/conversations/1/media/50', _png, once: true);
      await _pump(tester, _detail(makeSession(be)));
      expect(find.text('Fotoğraf · Açmak için dokun'), findsOneWidget);
      expect(contentImages(), findsNothing);
      await tester.tap(find.byKey(const ValueKey('viewOnceCard')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(be.count('GET /conversations/1/media/50'), 1);
      expect(find.text('Tek gösterimlik'), findsOneWidget);
      expect(contentImages(), findsOneWidget);
      expect(find.byTooltip('İndir'), findsNothing);
      expect(find.byType(InteractiveViewer), findsNothing);
      await tester.tap(find.byTooltip('Kapat'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Fotoğraf · Açıldı'), findsOneWidget);
      expect(find.byKey(const ValueKey('viewOnceCard')), findsNothing);
      expect(contentImages(), findsNothing);
      await unmount(tester);
      _ok(tester);
    });

    testWidgets('goruntuleyici: ikinci acilis 410 -> artik goruntulenemez; sayac bir kez', (tester) async {
      final be = FakeBackend()..onBytes('/conversations/1/media/50', _png, once: true);
      final s = makeSession(be);
      var consumed = 0;
      Future<void> open() async {
        await tester.pumpWidget(buildApp(ViewOnceViewer(api: s.api, conversationId: 1, attachmentId: 50, onConsumed: () => consumed++)));
        await settle(tester, const Duration(milliseconds: 400));
      }

      await open();
      expect(contentImages(), findsOneWidget);
      await unmount(tester);
      await open();
      expect(find.text('Bu fotoğraf artık görüntülenemez.'), findsOneWidget);
      expect(contentImages(), findsNothing);
      expect(consumed, 2); // 200 ve 410 ikisi de "tüketildi" sayılır
      await unmount(tester);
    });

    testWidgets('goruntuleyici: ag hatasi uyari + yeniden dene; 403 kendi fotografim', (tester) async {
      final be = FakeBackend()..network('/conversations/1/media/50');
      final s = makeSession(be);
      await tester.pumpWidget(buildApp(ViewOnceViewer(api: s.api, conversationId: 1, attachmentId: 50)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.textContaining('yeniden açılamayabilir'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      be.fail('/conversations/1/media/50', status: 403, code: 'MEDIA_VIEW_ONCE_OWN');
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.textContaining('Kendi gönderdiğiniz'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('gonderen: Gonderildi -> viewed olayi -> Acildi', (tester) async {
      final s = makeSession(_backend([_onceOut(8)]));
      final rt = ChatRealtime(s);
      await _pump(tester, _detail(s, rt: rt));
      expect(find.text('Fotoğraf · Gönderildi'), findsOneWidget);
      expect(find.byKey(const ValueKey('viewOnceCard')), findsNothing);
      rt.debugEmitMessageEvent({'type': 'viewed', 'conversationId': 1, 'messageId': 8, 'attachmentId': 51, 'userId': 11, 'at': 'x'});
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Fotoğraf · Açıldı'), findsOneWidget);
      expect(find.text('Fotoğraf · Gönderildi'), findsNothing);
      await unmount(tester);
      _ok(tester);
    });

    testWidgets('acilmis ve suresi dolmus (url yok) alici mesaji Acildi gosterir', (tester) async {
      await _pump(tester, _detail(makeSession(_backend([_onceIn(7, viewed: true, withUrl: false), _onceIn(6, withUrl: false)]))));
      expect(find.text('Fotoğraf · Açıldı'), findsNWidgets(2));
      await unmount(tester);
    });

    testWidgets('gonderim govdesinde viewOnce:true; yerel baloncuk onizleme gostermez', (tester) async {
      final be = _backend([_msg(1, 11, 'Merhaba')])
        ..on('/conversations/1/media', {'id': 77})
        ..on('/conversations/1/messages', _onceOut(9));
      final s = makeSession(be);
      await _pump(
        tester,
        _detail(s, upload: be),
      );
      be.delay = const Duration(milliseconds: 1500);
      expect(find.byKey(const ValueKey('viewOnceToggle')), findsNothing); // eski anahtar kalktı
      await tester.tap(find.byKey(const ValueKey('attachButton')));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('galleryTile_p1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pickerPreview')));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('onceButton_0')));
      await tester.pump();
      expect(find.text('Tek gönderimlik: alıcı yalnızca bir kez görebilir'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('previewSend')));
      await settle(tester, const Duration(milliseconds: 1100)); // sayfalar kapanır, yükleme başlar
      expect(contentImages(), findsNothing); // yerel önizleme yok
      expect(find.textContaining('Fotoğraf · Gönder'), findsOneWidget);
      await settle(tester, const Duration(seconds: 10));
      final body = be.bodies['POST /conversations/1/messages'] as Map? ?? fail('istekler: ${be.requests}');
      expect(body['viewOnce'], true);
      expect(body['attachmentIds'], [77]);
      await unmount(tester);
    });

    testWidgets('onizlemede isaretlenmeyen gorsel viewOnce gonderilmez', (tester) async {
      final be = _backend([_msg(1, 11, 'Merhaba')])
        ..on('/conversations/1/media', {'id': 78})
        ..on('/conversations/1/messages', _msg(9, 1, ''));
      await _pump(tester, _detail(makeSession(be), upload: be));
      await tester.tap(find.byKey(const ValueKey('attachButton')));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('galleryTile_p1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pickerSend')));
      await settle(tester, const Duration(seconds: 2));
      final body = be.bodies['POST /conversations/1/messages'] as Map;
      expect(body.containsKey('viewOnce'), isFalse);
      await unmount(tester);
    });

    test('galleryAttachments tek gosterimlik ekleri hic listelemez', () {
      final m = {
        'attachments': [
          {'id': 1, 'url': '/a', 'viewOnce': true},
          {'id': 2, 'url': '/b'},
          {'id': 3, 'url': '/c', 'removed': true},
        ],
      };
      expect(galleryAttachments(m).map((a) => a['id']), [2]);
      expect(ChatMediaItem.tryFromAttachment({'id': 1, 'url': '/a', 'viewOnce': true}), isNull);
      expect(ChatMediaItem.tryFromAttachment({'id': 2, 'url': '/b'}), isNotNull);
    });

    testWidgets('sohbet listesi onizlemesi: Fotograf (tek gosterimlik)', (tester) async {
      final be = FakeBackend()
        ..on('/conversations', {
          'items': [
            {
              'id': 1,
              'type': 'DIRECT',
              'title': 'Ali Veli',
              'peer': {'id': 11, 'displayName': 'Ali Veli'},
              'unreadCount': 0,
              'lastMessage': {
                'id': 5,
                'text': '',
                'senderId': 11,
                'createdAt': _iso(DateTime.now()),
                'attachments': [
                  {'id': 1, 'viewOnce': true, 'viewed': false}
                ],
              },
            },
          ],
          'nextCursor': null,
        });
      await _pump(tester, ChatTab(session: makeSession(be), connectRealtime: false), size: kPhoneSmall);
      expect(find.text('Fotoğraf (tek gösterimlik)'), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });
  });

  group('Iletme', () {
    FakeBackend fwd() => _backend([_msg(2, 1, 'Selam'), _onceIn(7), _msg(1, 11, 'Merhaba')])
      ..on('/conversations?size=50', {
        'items': [
          for (var i = 2; i <= 7; i++)
            {'id': i, 'type': 'GROUP', 'title': 'Grup $i', 'unreadCount': 0},
        ],
        'nextCursor': null,
      });

    testWidgets('menuden Ilet: coklu secim, arama, gonderim ve limit', (tester) async {
      final be = fwd();
      await _pump(tester, _detail(makeSession(be)));
      await tester.longPress(find.text('Selam'));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('İlet'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Grup 2'), findsOneWidget);
      // Arama
      await tester.enterText(find.descendant(of: find.byType(SohbetyField), matching: find.byType(TextField)), 'grup 3');
      await tester.pump();
      expect(find.text('Grup 2'), findsNothing);
      expect(find.text('Grup 3'), findsOneWidget);
      await tester.enterText(find.descendant(of: find.byType(SohbetyField), matching: find.byType(TextField)), '');
      await tester.pump();
      // 6 seçim: ilk 5 alınır
      for (var i = 2; i <= 7; i++) {
        await tester.tap(find.byKey(ValueKey('fwd-$i')));
        await tester.pump();
      }
      expect(find.text('Gönder (5)'), findsOneWidget);
      expect(find.text('En fazla 5 sohbet seçilebilir.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fwd-7'))); // seçili değil, sınır
      await tester.tap(find.byKey(const ValueKey('fwd-6'))); // seçimi kaldır
      await tester.pump();
      expect(find.text('Gönder (4)'), findsOneWidget);
      await tester.tap(find.text('Gönder (4)'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('İletildi'), findsOneWidget);
      expect((be.bodies['POST /conversations/2/messages'] as Map)['text'], 'Selam');
      expect(be.bodies.containsKey('POST /conversations/6/messages'), isFalse);
      await unmount(tester);
      _ok(tester);
    });

    testWidgets('gorsel/tek gosterimlik mesajda Ilet gizli', (tester) async {
      await _pump(tester, _detail(makeSession(fwd())));
      await tester.longPress(find.text('Fotoğraf · Açmak için dokun'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(_card), findsOneWidget);
      expect(find.text('İlet'), findsNothing);
      expect(find.text('Kopyala'), findsNothing);
      await unmount(tester);
    });
  });

  group('Sohbet icinde arama', () {
    Future<void> openSearch(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Menü'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Sohbette ara'));
      await settle(tester, const Duration(milliseconds: 400));
    }

    testWidgets('eslesmeleri vurgular, oklarla gezer, geri tusu aramayi kapatir', (tester) async {
      final msgs = [
        _msg(4, 11, 'selam'),
        _msg(3, 1, 'kahve mi çay mı'),
        _msg(2, 11, 'tamam'),
        _msg(1, 1, 'kahve içelim'),
      ];
      await _pump(tester, _detail(makeSession(_backend(msgs))));
      await openSearch(tester);
      expect(find.byKey(const ValueKey('chatSearchField')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('chatSearchField')), 'kahve');
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('1 / 2'), findsOneWidget);
      expect(_hasHighlight(tester), isTrue);
      await tester.tap(find.byTooltip('Önceki eşleşme'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Sonraki eşleşme'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('chatSearchField')), 'yok yok');
      await tester.pump();
      expect(find.text('Eşleşme yok'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('chatSearchField')), findsNothing);
      expect(_hasHighlight(tester), isFalse);
      await unmount(tester);
      _ok(tester);
    });

    testWidgets('Daha eski mesajlarda ara bir sayfa daha ceker', (tester) async {
      final be = _backend([_msg(10, 11, 'selam')], next: 10)
        ..on('/conversations/1/messages?size=30&before=10', _page([_msg(5, 1, 'eski kahve')]));
      await _pump(tester, _detail(makeSession(be)), size: kPhoneSmall);
      await openSearch(tester);
      await tester.enterText(find.byKey(const ValueKey('chatSearchField')), 'kahve');
      await tester.pump();
      expect(find.text('Eşleşme yok'), findsOneWidget);
      await tester.tap(find.text('Daha eski mesajlarda ara'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(be.count('before=10'), greaterThanOrEqualTo(1));
      expect(find.text('1 / 1'), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });
  });

  group('Grup avatari basligi', () {
    testWidgets('yetkili /api avatari Bearer ile, /files acik', (tester) async {
      final s = makeSession(_backend([_msg(1, 11, 'Merhaba')]));
      s.api.tokens = Tokens('acc', 'ref');
      Map<String, String>? headersFor(String url) {
        final f = find.byWidgetPredicate((w) => w is BuAvatar && w.url == url);
        return f.evaluate().isEmpty ? null : tester.widget<BuAvatar>(f.first).headers;
      }

      await _pump(tester, _detail(s, conv: {'id': 1, 'type': 'GROUP', 'title': 'Grup', 'avatarUrl': '/api/conversations/1/avatar'}));
      expect(headersFor('/api/conversations/1/avatar'), {'Authorization': 'Bearer acc'});
      await unmount(tester);
      await _pump(tester, _detail(s, conv: {'id': 1, 'type': 'GROUP', 'title': 'Grup', 'avatarUrl': '/files/avatars/g.png'}));
      expect(headersFor('/files/avatars/g.png'), isNull);
      await unmount(tester);
    });
  });
}
