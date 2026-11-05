import 'package:bu_kampus/features/chat/chat_info_page.dart';
import 'package:bu_kampus/features/chat/message_actions.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:bu_kampus/features/chat/message_info_page.dart';
import 'package:bu_kampus/features/chat/recent_reactions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void main() {
  setUpAll(loadTestFonts);
  setUp(mockSecureStorage);

  test(
      'recent reactions: six unique values, newest first, red heart, account reset',
      () async {
    expect(await RecentReactions.load(), RecentReactions.defaults);
    for (final emoji in ['🔥', '🎉', '😍', '💯', '✅', '🚀', '🌹']) {
      await RecentReactions.record(emoji);
    }
    expect(await RecentReactions.load(), ['🌹', '🚀', '✅', '💯', '😍', '🎉']);
    await RecentReactions.record('🚀');
    expect((await RecentReactions.load()).first, '🚀');
    expect((await RecentReactions.load()).toSet().length, 6);
    await RecentReactions.record('❤');
    expect((await RecentReactions.load()).first, '❤️');
    await RecentReactions.clear();
    expect(await RecentReactions.load(), RecentReactions.defaults);
    expect(RecentReactions.isEmoji('hello'), isFalse);
    expect(RecentReactions.isEmoji('🔥🔥'), isFalse);
    expect(RecentReactions.isEmoji('👨‍👩‍👧‍👦'), isTrue);
  });

  testWidgets(
      'info photo opens a zoomable preview; close returns to info',
      (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = FakeBackend()
      ..on('/conversations/5/messages?size=40',
          {'items': [], 'nextCursor': null});
    await tester.pumpWidget(buildApp(ChatInfoPage(
      session: makeSession(be),
      conversation: const {
        'id': 5,
        'type': 'DIRECT',
        'peer': {
          'id': 2,
          'displayName': 'Mehmet',
          'avatarUrl': '/files/profile.jpg'
        }
      },
      members: const [],
    )));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('chatInfoAvatarPreview')));
    await settle(tester);
    expect(find.byKey(const ValueKey('chatAvatarPreview')), findsOneWidget);
    expect(find.byKey(const ValueKey('chatAvatarPreviewZoom')), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing); // monochrome: bulanıklık yok, düz karartma
    await tester.tap(find.byKey(const ValueKey('chatAvatarPreviewClose')));
    await settle(tester);
    expect(find.byKey(const ValueKey('chatAvatarPreview')), findsNothing);
    await unmount(tester);
  });

  testWidgets('reaction plus opens emoji picker and returns chosen emoji',
      (tester) async {
    useScreen(tester, kPhoneSmall);
    String? result;
    await tester.pumpWidget(buildApp(Builder(
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
            ))));
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.text('❤️'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('msgActions.moreReactions')));
    await settle(tester);
    expect(find.byKey(const ValueKey('reactionEmojiGrid')), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('reactionEmojiInput')), '🔥');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(result, 'react:🔥');
    await unmount(tester);
  });

  testWidgets(
      'opposite swipe actions do not conflict or trigger for cancelled drags',
      (tester) async {
    int replies = 0, infos = 0;
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(Center(
        child: MessageBubble(
      message: const {
        'id': 1,
        'text': 'Kendi mesajım',
        'senderId': 1,
        'createdAt': '2026-11-04T10:00:00Z'
      },
      mine: true,
      senderName: null,
      replyName: null,
      seen: false,
      authHeaders: const {},
      onMenu: () {},
      onRetry: () {},
      onOpenImage: (_) {},
      onReact: (_) {},
      onSwipeReply: () => replies++,
      onSwipeInfo: () => infos++,
    ))));
    await tester.drag(find.text('Kendi mesajım'), const Offset(-110, 0));
    await settle(tester);
    expect(infos, 1);
    expect(replies, 0);
    await tester.drag(find.text('Kendi mesajım'), const Offset(110, 0));
    await settle(tester);
    expect(infos, 1);
    expect(replies, 1);
    final drag =
        await tester.startGesture(tester.getCenter(find.text('Kendi mesajım')));
    await drag.moveBy(const Offset(-110, 0));
    await drag.cancel();
    await settle(tester);
    expect(infos, 1);
    await unmount(tester);
  });

  testWidgets(
      'message details show server times and replies without inventing old timestamps',
      (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = FakeBackend()
      ..on('/messages/10/info', {
        'message': {
          'id': 10,
          'senderId': 1,
          'text': 'Kütüphanede buluşalım',
          'createdAt': '2026-11-04T10:00:00Z'
        },
        'sentAt': '2026-11-04T10:00:00Z',
        'deliveredAt': null,
        'readAt': null,
        'status': 'READ',
        'replies': {
          'items': [
            {
              'id': 11,
              'senderId': 2,
              'text': 'Tamam, geliyorum',
              'createdAt': '2026-11-04T10:02:00Z'
            }
          ],
          'nextCursor': null
        },
      });
    await tester.pumpWidget(buildApp(MessageInfoPage(
      session: makeSession(be),
      message: const {'id': 10, 'senderId': 1, 'text': 'Kütüphanede buluşalım'},
      peerName: 'Mehmet',
    )));
    await settle(tester);
    expect(find.text('Zaman kaydı bulunmuyor'), findsNWidgets(2));
    expect(find.text('Tamam, geliyorum'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
