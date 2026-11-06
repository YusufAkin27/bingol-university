import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/emoji_catalog.dart';
import 'package:bu_kampus/features/chat/message_actions.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:bu_kampus/features/chat/message_info_page.dart';
import 'package:bu_kampus/features/chat/recent_reactions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// Tam emoji seçici: kategoriler, arama, son kullanılanlar, sunucu reddi, kapsül çizimi.

const _family = '👨‍👩‍👧‍👦';
const _rainbow = '🏳️‍🌈';
const _tr = '🇹🇷';

Future<String?> _openPicker(WidgetTester tester, Size size,
    {Brightness b = Brightness.light, double scale = 1}) async {
  useScreen(tester, size);
  String? result;
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
    child: buildApp(
        Builder(
            builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showMessageActions(
                      context,
                      anchor: const Rect.fromLTWH(100, 200, 120, 45),
                      preview: const Text('Merhaba'),
                      mine: true,
                      actions: const [],
                      emojis: RecentReactions.defaults,
                    );
                  },
                  child: const Text('open'),
                )),
        brightness: b),
  ));
  await tester.tap(find.text('open'));
  await settle(tester);
  await tester.tap(find.byKey(const ValueKey('msgActions.moreReactions')));
  await settle(tester);
  return result;
}

void main() {
  setUpAll(loadTestFonts);
  setUp(mockSecureStorage);

  test('katalog: kategoriler dolu, ZWJ/bayrak var, arama Turkce ve Ingilizce', () {
    final all = EmojiCatalog.all;
    for (final c in EmojiCategory.values) {
      expect(all[c], isNotEmpty, reason: c.id);
    }
    final flat = [for (final l in all.values) ...l.map((e) => e.emoji)];
    expect(flat, contains(_family));
    expect(flat, contains(_rainbow));
    expect(flat, contains(_tr));
    // Hicbiri 16 UTF-16 biriminden uzun degil ve hepsi tek grafem kumesi.
    for (final e in flat) {
      expect(e.length <= 16, isTrue, reason: e);
      expect(RecentReactions.isEmoji(e), isTrue, reason: e);
    }
    expect(EmojiCatalog.search('türkiye').map((e) => e.emoji), contains(_tr));
    expect(EmojiCatalog.search('TURKIYE').map((e) => e.emoji), contains(_tr));
    expect(EmojiCatalog.search('red heart').map((e) => e.emoji), contains('❤️'));
    expect(EmojiCatalog.search('zzzzqqq'), isEmpty);
  });

  test('son kullanilanlar: en cok 8 saklanir, cubuk 6 gosterir', () async {
    await RecentReactions.clear();
    for (final e in ['🔥', '🎉', '😍', '💯', '✅', '🚀', '🌹', _tr, _family, '🦄']) {
      await RecentReactions.record(e);
    }
    final stored = await RecentReactions.loadRecent();
    expect(stored.length, 8);
    expect(stored.first, '🦄');
    expect(stored[1], _family);
    expect((await RecentReactions.load()).length, 6);
    await RecentReactions.clear();
  });

  for (final size in [kPhoneSmall, kPhoneMedium]) {
    for (final b in Brightness.values) {
      testWidgets(
          '${size.width.toInt()} dp ${b.name} x1.3: secici acilir, sekmeler, tasma yok',
          (tester) async {
        await _openPicker(tester, size, b: b, scale: 1.3);
        expect(find.byKey(const ValueKey('reactionEmojiGrid')), findsOneWidget);
        expect(find.byKey(const ValueKey('reactionEmojiInput')), findsOneWidget);
        expect(find.text('Sık kullanılan'), findsOneWidget);
        for (final id in ['recent', 'faces']) {
          expect(find.byKey(ValueKey('reactionTab_$id')), findsOneWidget);
        }
        await tester.tap(find.byKey(const ValueKey('reactionTab_food')));
        await settle(tester);
        expect(find.text('Yemek ve içecek'), findsWidgets);
        await tester.drag(find.byKey(const ValueKey('reactionEmojiTabs')),
            const Offset(-600, 0));
        await settle(tester);
        await tester.tap(find.byKey(const ValueKey('reactionTab_flags')));
        await settle(tester, const Duration(seconds: 2));
        expect(find.text('Bayraklar'), findsWidgets);
        final e = tester.takeException();
        if (e != null) fail('$e');
      });
    }
  }

  testWidgets('arama: Turkce kelimeyle bayrak bulunur, secimle tepki doner',
      (tester) async {
    await _openPicker(tester, kPhoneMedium);
    await tester.enterText(
        find.byKey(const ValueKey('reactionEmojiInput')), 'türkiye');
    await settle(tester);
    expect(find.byKey(const ValueKey('reactionEmojiTabs')), findsNothing);
    expect(find.byKey(const ValueKey('emoji_$_tr')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('emoji_$_tr')));
    await settle(tester);
    expect(find.byKey(const ValueKey('reactionEmojiGrid')), findsNothing);
  });

  testWidgets('arama: sonuc yoksa bos durum; klavyeden emoji dogrudan aday',
      (tester) async {
    await _openPicker(tester, kPhoneSmall);
    await tester.enterText(
        find.byKey(const ValueKey('reactionEmojiInput')), 'zzzzqqq');
    await settle(tester);
    expect(find.byKey(const ValueKey('reactionEmojiEmpty')), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('reactionEmojiInput')), _family);
    await settle(tester);
    expect(find.byKey(const ValueKey('emoji_$_family')), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    expect(find.byKey(const ValueKey('reactionEmojiGrid')), findsNothing);
  });

  testWidgets('son kullanilanlar bolumu yeni emojileri gosterir', (tester) async {
    await tester.runAsync(() async {
      await RecentReactions.clear();
      await RecentReactions.record(_tr);
      await RecentReactions.record('🦄');
    });
    await _openPicker(tester, kPhoneMedium);
    expect(find.text('Son kullanılan'), findsOneWidget);
    expect(find.byKey(const ValueKey('emoji_🦄')), findsOneWidget);
    expect(find.byKey(const ValueKey('emoji_$_tr')), findsWidgets);
    await tester.runAsync(RecentReactions.clear);
  });

  group('sohbet: tepki istegi', () {
    Map<String, dynamic> msg() => {
          'id': 5,
          'conversationId': 1,
          'senderId': 11,
          'text': 'Merhaba',
          'createdAt': DateTime.now()
              .subtract(const Duration(minutes: 5))
              .toUtc()
              .toIso8601String(),
        };

    Future<FakeBackend> pumpChat(WidgetTester tester,
        {String? rejectCode,
        String query = 'türkiye',
        String emoji = _tr}) async {
      useScreen(tester, kPhoneMedium);
      final be = FakeBackend()
        ..on('/conversations/1/messages?size=30',
            {'items': [msg()], 'nextCursor': null})
        ..on('/conversations/1', {
          'conversation': {'id': 1},
          'members': [
            {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
            {'userId': 11, 'displayName': 'Mehmet Kaya'},
          ],
        })
        ..on('/users/11/presence', {'online': true})
        ..on('/messages/reactions', {
          'emojis': ['👍']
        });
      if (rejectCode != null) {
        be.fail('/messages/5/reaction', status: 400, code: rejectCode);
      } else {
        be.on('/messages/5/reaction', {
          'reactions': [
            {'emoji': _tr, 'count': 1}
          ],
          'myReaction': _tr
        });
      }
      await tester.pumpWidget(buildApp(
          ChatDetailPage(
            session: makeSession(be),
            connectRealtime: false,
            conversation: const {
              'id': 1,
              'type': 'DIRECT',
              'title': 'Mehmet Kaya',
              'peer': {'id': 11, 'displayName': 'Mehmet Kaya'},
            },
          ),
          size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.longPress(find.text('Merhaba'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('msgActions.moreReactions')));
      await settle(tester);
      await tester.enterText(
          find.byKey(const ValueKey('reactionEmojiInput')), query);
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('emoji_$emoji')));
      await settle(tester, const Duration(seconds: 3));
      return be;
    }

    testWidgets('secilen emoji PUT ile gider, kapsul cizilir',
        (tester) async {
      await tester.runAsync(RecentReactions.clear);
      final be = await pumpChat(tester);
      expect(be.requests, contains('PUT /messages/5/reaction'));
      expect(be.bodies['PUT /messages/5/reaction'], {'emoji': _tr});
      expect(find.textContaining(_tr), findsOneWidget); // sayi 1 ise yazilmaz (383bae9d): kapsulda yalniz emoji
      await unmount(tester);
    });

    testWidgets('eski sunucu emojiyi reddederse anlasilir toast, kapsul yok',
        (tester) async {
      await pumpChat(tester,
          rejectCode: 'REACTION_NOT_ALLOWED', query: 'unicorn', emoji: '🦄');
      expect(find.text('Bu emoji şu an desteklenmiyor'), findsOneWidget);
      expect(find.textContaining('🦄 1'), findsNothing);
      expect(await tester.runAsync(RecentReactions.loadRecent),
          isNot(contains('🦄')));
      await unmount(tester);
    });

    testWidgets('farkli emoji siniri asilirsa sinir toast metni',
        (tester) async {
      await pumpChat(tester,
          rejectCode: 'REACTION_LIMIT_REACHED', query: 'unicorn', emoji: '🦄');
      expect(find.text('Bu mesajda daha fazla farklı emoji kullanılamaz'),
          findsOneWidget);
      await unmount(tester);
    });
  });

  group('kapsuller', () {
    final many = <Map<String, dynamic>>[
      for (final e in [
        _family, _rainbow, _tr, '👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '🎉',
        '😍', '💯', '✅', '🚀', '🌹', '🦄', '🧑‍💻', '👩‍🚀', '🏴‍☠️'
      ])
        {'emoji': e, 'count': 12}
    ];

    for (final size in [kPhoneSmall, kPhoneMedium]) {
      for (final b in Brightness.values) {
        for (final rtl in [false, true]) {
          testWidgets(
              'balon ${size.width.toInt()} dp ${b.name}${rtl ? ' rtl' : ''} x1.3: 20 farkli emoji sarar, tasma yok',
              (tester) async {
            useScreen(tester, size);
            final bubble = MessageBubble(
              message: {
                'id': 1,
                'text': 'Çok tepkili mesaj',
                'senderId': 11,
                'createdAt': '2026-11-04T10:00:00Z',
                'reactions': many,
                'myReaction': _rainbow,
              },
              mine: false,
              senderName: null,
              replyName: null,
              seen: false,
              authHeaders: const {},
              onMenu: () {},
              onRetry: () {},
              onOpenImage: (_) {},
              onReact: (_) {},
            );
            await tester.pumpWidget(MediaQuery(
              data:
                  MediaQueryData(size: size, textScaler: const TextScaler.linear(1.3)),
              child: buildApp(
                  Directionality(
                      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                      child: SingleChildScrollView(child: bubble)),
                  brightness: b),
            ));
            await settle(tester, const Duration(milliseconds: 300));
            expect(find.textContaining(_family), findsOneWidget);
            expect(find.textContaining(_rainbow), findsOneWidget);
            expect(find.textContaining(_tr), findsOneWidget);
            final e = tester.takeException();
            if (e != null) fail('$e');
          });
        }
      }
    }

    testWidgets('tepki bilgisi sayfasi cok emojiyi tasmadan gosterir',
        (tester) async {
      useScreen(tester, kPhoneSmall);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(
            size: Size(320, 640), textScaler: TextScaler.linear(1.3)),
        child: buildApp(MessageInfoPage(
            session: makeSession(FakeBackend()),
            message: {
              'id': 1,
              'text': 'x',
              'senderId': 1,
              'createdAt': '2026-11-04T10:00:00Z',
              'reactions': many,
            },
            peerName: 'Mehmet')),
      ));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('infoReaction_$_family')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const ValueKey('infoReaction_$_family')), findsOneWidget);
      final e = tester.takeException();
      if (e != null) fail('$e');
    });
  });
}
