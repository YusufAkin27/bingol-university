// B4: yeni sunucu sözleşmeleri — kapalı sohbet (P08), yönetici gizlemesi yer tutucusu (P08),
// push yönlendirme olayları, sertifika iptali (P07), kulüp kapatma (P06), hesap silme uyarısı (B1).
import 'dart:io';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/closed_conversations.dart';
import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/outbox/outbox.dart';
import 'package:bu_kampus/core/push/push_router.dart';
import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:bu_kampus/core/realtime/chat_realtime.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/shell/app_shell.dart';
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/profile/profil2_delete_account_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_media.dart';

const _adminText = 'Bu mesaj yönetici tarafından kaldırıldı';
const _modText = 'Bu mesaj kaldırıldı';
const _deletedText = 'Bu mesaj silindi';

String _iso(int minsAgo) => DateTime.now().subtract(Duration(minutes: minsAgo)).toUtc().toIso8601String();

Map<String, dynamic> _msg(int id, int sender, String text, {Map<String, dynamic>? extra}) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': _iso(600 - id),
      ...?extra,
    };

FakeBackend _backend(List<Map<String, dynamic>> msgs) => FakeBackend()
  ..on('/conversations/1/messages?size=30', {'items': msgs, 'nextCursor': null})
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Ali Veli'},
    ],
  })
  ..on('/users/11/presence', {'online': true})
  ..on('/messages/reactions', {
    'emojis': ['👍']
  });

ChatDetailPage _detail(Session s, {ChatRealtime? rt}) => ChatDetailPage(
      session: s,
      connectRealtime: false,
      realtime: rt,
      mediaLibrary: FakeMediaLibrary.photos(1),
      ensureAccess: (c, p, {rationale}) async => true,
      conversation: {
        'id': 1,
        'type': 'DIRECT',
        'title': 'Ali Veli',
        'peer': {'id': 11, 'displayName': 'Ali Veli'},
      },
    );

Future<void> _pump(WidgetTester tester, Widget page, {Locale? locale}) async {
  useScreen(tester, kPhoneMedium);
  if (locale == null) {
    await tester.pumpWidget(buildApp(page, size: kPhoneMedium));
  } else {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: page,
    ));
  }
  await settle(tester, const Duration(milliseconds: 600));
}

const _banner = ValueKey('chatClosedBanner');
const _field = ValueKey('composerField');
const _card = ValueKey('msgActions.card');

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

void main() {
  setUpAll(_loadFonts);
  tearDown(() {
    for (final id in [1, 5, 9]) {
      ClosedConversations.instance.markOpen(id);
    }
    shellTabRequest.value = null;
  });

  group('ClosedConversations (saf mantik)', () {
    test('push olaylari: kapandi / yeniden acildi / kaldirildi', () {
      final c = ClosedConversations.test();
      final data = {'conversationId': '7', 'targetType': 'CONVERSATION', 'targetId': '7'};
      expect(c.isClosed(7), isFalse);
      expect(c.applyPushData({...data, 'event': 'CONVERSATION_CLOSED'}), isTrue);
      expect(c.isClosed(7), isTrue);
      expect(c.applyPushData({...data, 'event': 'CONVERSATION_CLOSED'}), isFalse); // zaten kapali
      expect(c.applyPushData({...data, 'event': 'CONVERSATION_REOPENED'}), isTrue);
      expect(c.isClosed(7), isFalse);
      c.markClosed(7);
      expect(c.applyPushData({...data, 'event': 'CONVERSATION_REMOVED'}), isTrue);
      expect(c.isClosed(7), isFalse);
    });

    test('tanimsiz olay / kimliksiz yuk / bozuk veri yok sayilir', () {
      final c = ClosedConversations.test();
      expect(c.applyPushData(null), isFalse);
      expect(c.applyPushData({'event': 'SOMETHING', 'conversationId': '7'}), isFalse);
      expect(c.applyPushData({'event': 'CONVERSATION_CLOSED'}), isFalse);
      expect(c.applyPushData({'event': 'CONVERSATION_CLOSED', 'conversationId': 'abc'}), isFalse);
      // targetType/targetId ile de kimlik cozulur
      expect(c.applyPushData({'event': 'CONVERSATION_CLOSED', 'targetType': 'CONVERSATION', 'targetId': '3'}), isTrue);
      expect(c.isClosed(3), isTrue);
    });

    test('bayat kayit 12 saat sonra duser (bildirimi kacirmis istemci kilitli kalmaz)', () {
      var now = DateTime(2026, 10, 28, 12);
      final c = ClosedConversations.test(now: () => now);
      c.markClosed(4);
      now = now.add(const Duration(hours: 11));
      expect(c.isClosed(4), isTrue);
      now = now.add(const Duration(hours: 2));
      expect(c.isClosed(4), isFalse);
    });

    test('dinleyiciler yalniz durum degisince tetiklenir', () {
      final c = ClosedConversations.test();
      var n = 0;
      c.addListener(() => n++);
      c.markClosed(1);
      c.markClosed(1);
      c.markOpen(1);
      c.markOpen(1);
      expect(n, 2);
    });
  });

  group('Kapali sohbet (P08)', () {
    testWidgets('gonderimde 409 CONVERSATION_CLOSED: yazma alani kapanir, bant gorunur, mesaj hatali', (tester) async {
      final be = _backend([_msg(1, 11, 'Merhaba')])
        ..fail('/conversations/1/messages', status: 409, code: 'CONVERSATION_CLOSED', message: 'Sebep: gizli');
      await _pump(tester, _detail(makeSession(be)));
      expect(find.byKey(_field), findsOneWidget);
      expect(find.byKey(_banner), findsNothing);

      await tester.enterText(find.byKey(_field), 'selam');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sendButton')));
      await settle(tester, const Duration(milliseconds: 600));

      expect(ClosedConversations.instance.isClosed(1), isTrue);
      expect(find.byKey(_banner), findsOneWidget);
      expect(find.text('Bu sohbet yönetici tarafından kapatıldı.'), findsWidgets);
      expect(find.byKey(_field), findsNothing); // yazma alani yok
      expect(find.byKey(const ValueKey('sendButton')), findsNothing);
      expect(find.text('Sebep: gizli'), findsNothing); // sebep/sunucu metni gosterilmez
      expect(tester.takeException(), isNull);
    });

    testWidgets('push: kapatildi -> bant canli acilir; yeniden acildi -> yazma alani geri gelir', (tester) async {
      await _pump(tester, _detail(makeSession(_backend([_msg(1, 11, 'Merhaba')]))));
      expect(find.byKey(_field), findsOneWidget);

      ClosedConversations.instance
          .applyPushData({'conversationId': '1', 'targetType': 'CONVERSATION', 'event': 'CONVERSATION_CLOSED'});
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byKey(_banner), findsOneWidget);
      expect(find.byKey(_field), findsNothing);

      ClosedConversations.instance.applyPushData({'conversationId': '1', 'event': 'CONVERSATION_REOPENED'});
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byKey(_banner), findsNothing);
      expect(find.byKey(_field), findsOneWidget);
    });

    testWidgets('sohbet zaten kapaliyken acilirsa bant ilk karede gorunur', (tester) async {
      ClosedConversations.instance.markClosed(1);
      await _pump(tester, _detail(makeSession(_backend([_msg(1, 11, 'Merhaba')]))));
      expect(find.byKey(_banner), findsOneWidget);
      expect(find.byKey(_field), findsNothing);
      expect(find.text('Merhaba'), findsOneWidget); // gecmis okunabilir
    });

    testWidgets('kapali sohbette canli yeni mesaj gelirse sohbet yeniden acilmis sayilir', (tester) async {
      final be = _backend([_msg(1, 11, 'Merhaba')]);
      final s = makeSession(be);
      final rt = ChatRealtime(s);
      await _pump(tester, _detail(s, rt: rt));
      ClosedConversations.instance.markClosed(1);
      await settle(tester, const Duration(milliseconds: 200));
      expect(find.byKey(_banner), findsOneWidget);
      rt.debugEmitMessage(_msg(2, 11, 'Yeniden acildik'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byKey(_banner), findsNothing);
      expect(find.byKey(_field), findsOneWidget);
    });

    testWidgets('STOMP /user/queue/errors CONVERSATION_CLOSED: sohbet kapanir, giden balon hatali', (tester) async {
      final s = makeSession(_backend([_msg(1, 11, 'Merhaba')]));
      final rt = ChatRealtime(s);
      await _pump(tester, _detail(s, rt: rt));
      rt.debugEmitError(ChatError('CONVERSATION_CLOSED', 'x', null));
      await settle(tester, const Duration(milliseconds: 300));
      expect(ClosedConversations.instance.isClosed(1), isTrue);
      expect(find.byKey(_banner), findsOneWidget);
      expect(find.byKey(_field), findsNothing);
    });

    test('cevrimdisi kuyruk: 409 CONVERSATION_CLOSED kalici hata (failed) ve sohbet kapali isaretlenir', () async {
      final ob = Outbox(
          store: MemoryOutboxStore(),
          autoSchedule: false,
          sender: (i) async => throw ApiError(409, 'CONVERSATION_CLOSED', 'x'));
      ob.enqueue(conversationId: 5, clientId: 'c1', text: 'bekleyen');
      expect(ob.pendingCount, 1);
      await ob.retry('c1');
      expect(ob.failedCount, 1);
      expect(ob.byClientId('c1')!.errorCode, 'CONVERSATION_CLOSED');
      expect(ClosedConversations.instance.isClosed(5), isTrue);
      // Kalici hata: kendiliginden yeniden denenmez (drain atlar).
      await ob.drain();
      expect(ob.failedCount, 1);
      ob.dispose();
    });

    test('errorText: CONVERSATION_CLOSED yerel metin; sunucu sebebi sizmaz', () {
      expect(errorText(ApiError(409, 'CONVERSATION_CLOSED', 'gizli sebep')), 'Bu sohbet yönetici tarafından kapatıldı.');
    });
  });

  group('Yonetici gizlemesi yer tutucusu (P08)', () {
    final msgs = [
      _msg(6, 11, 'Cevap', extra: {
        'replyToMessageId': 3,
        'replyTo': {'id': 3, 'senderId': 11, 'text': _adminText, 'deleted': true},
      }),
      _msg(5, 11, _modText, extra: {'removed': true}),
      _msg(4, 1, _deletedText, extra: {'removed': true, 'deleted': true}),
      _msg(3, 11, _adminText, extra: {'removed': true}), // yonetici gizlemesi
      _msg(2, 1, _adminText, extra: {'removed': true, 'deleted': true}), // yonetici kalici silme
      _msg(1, 11, 'Normal mesaj'),
    ];

    testWidgets('yer tutucu baloncuklar (tr): yonetici / moderasyon / kullanici silmesi ayri metinler', (tester) async {
      await _pump(tester, _detail(makeSession(_backend(msgs))));
      // Yonetici metni: 2 baloncuk + 1 yanit onizlemesi
      expect(find.text(_adminText), findsNWidgets(3));
      expect(find.text(_modText), findsOneWidget);
      expect(find.text(_deletedText), findsOneWidget);
      expect(find.text('Normal mesaj'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('yer tutucu baloncuk uzun basista menu ACILMAZ (yanitla/duzenle/tepki yok); normal mesajda acilir', (tester) async {
      await _pump(tester, _detail(makeSession(_backend(msgs))));
      await tester.longPress(find.text(_modText));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(_card), findsNothing);
      expect(find.text('Yanıtla'), findsNothing);
      expect(find.text('👍'), findsNothing);

      // Yonetici kalici silmesi KENDI mesajimda bile duzenle/sil secenegi sunmaz
      // (0: yanit onizlemesi, 1: yonetici gizlemesi, 2: yonetici kalici silmesi — agac sirasi yeniden eskiye)
      for (final i in [1, 2]) {
        await tester.longPress(find.text(_adminText).at(i));
        await settle(tester, const Duration(milliseconds: 400));
        expect(find.byKey(_card), findsNothing, reason: 'yer tutucu #$i');
      }

      await tester.longPress(find.text('Normal mesaj'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(_card), findsOneWidget);
      expect(find.text('Yanıtla'), findsOneWidget);
    });

    testWidgets('yer tutucu EN dilinde cevrilir (sunucunun sabit Turkce metni degil)', (tester) async {
      await _pump(tester, _detail(makeSession(_backend(msgs))), locale: const Locale('en'));
      expect(find.text('This message was removed by an administrator'), findsNWidgets(3));
      expect(find.text('This message was removed'), findsOneWidget);
      expect(find.text(_adminText), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('yer tutucu AR dilinde cevrilir', (tester) async {
      await _pump(tester, _detail(makeSession(_backend(msgs))), locale: const Locale('ar'));
      expect(find.text('أزال أحد المشرفين هذه الرسالة'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('STOMP deleted olayi: son sayfa yeniden cekilir; geri gosterilen mesaj normal gelir', (tester) async {
      final be = _backend([_msg(3, 11, _adminText, extra: {'removed': true}), _msg(1, 11, 'Ilk')]);
      final s = makeSession(be);
      final rt = ChatRealtime(s);
      await _pump(tester, _detail(s, rt: rt));
      expect(find.text(_adminText), findsOneWidget);
      final before = be.count('GET /conversations/1/messages?size=30');

      // Yonetici geri gosterdi: sunucu artik normal mesaj doner; olay yok -> yenilemede gorunur
      be.on('/conversations/1/messages?size=30', {
        'items': [_msg(3, 11, 'Geri geldi'), _msg(1, 11, 'Ilk')],
        'nextCursor': null
      });
      rt.debugEmitMessageEvent({'type': 'deleted', 'conversationId': 1, 'messageId': 3, 'userId': 99, 'at': 'x'});
      await settle(tester, const Duration(milliseconds: 500));
      expect(be.count('GET /conversations/1/messages?size=30'), greaterThan(before));
      expect(find.text('Geri geldi'), findsOneWidget);
      expect(find.text(_adminText), findsNothing);
      // Baska sohbetin olayi yenileme tetiklemez
      final n = be.count('GET /conversations/1/messages?size=30');
      rt.debugEmitMessageEvent({'type': 'deleted', 'conversationId': 2, 'messageId': 3});
      await settle(tester, const Duration(milliseconds: 300));
      expect(be.count('GET /conversations/1/messages?size=30'), n);
    });

    test('ChatRealtime deleted olayi MessageDeletedEvent olarak yayinlanir', () async {
      final rt = ChatRealtime(makeSession(FakeBackend()));
      final got = <MessageDeletedEvent>[];
      final sub = rt.deletedMessages.listen(got.add);
      rt.debugEmitMessageEvent({'type': 'deleted', 'conversationId': 4, 'messageId': 9});
      rt.debugEmitMessageEvent({'type': 'edited', 'conversationId': 4, 'messageId': 9}); // yok sayilir
      await Future<void>.delayed(Duration.zero);
      expect(got.length, 1);
      expect(got.single.conversationId, 4);
      expect(got.single.messageId, 9);
      await sub.cancel();
      rt.dispose();
    });
  });

  group('Push yonlendirme: sohbet olaylari (P08)', () {
    test('CLOSED / REOPENED hedef sohbettir; REMOVED sohbet listesidir', () {
      final base = {'conversationId': '5', 'targetType': 'CONVERSATION', 'targetId': '5'};
      expect(resolvePushTarget({...base, 'event': 'CONVERSATION_CLOSED'}), const PushTarget(PushDest.conversation, id: 5));
      expect(resolvePushTarget({...base, 'event': 'CONVERSATION_REOPENED'}), const PushTarget(PushDest.conversation, id: 5));
      expect(resolvePushTarget({...base, 'event': 'CONVERSATION_REMOVED'}), const PushTarget(PushDest.chatList));
      // Olaysiz eski yuk degismedi
      expect(resolvePushTarget(base), const PushTarget(PushDest.conversation, id: 5));
    });

    test('kulup bildirimleri yalniz communityId ile kulube gider (kapatma / devir)', () {
      expect(resolvePushTarget({'communityId': '12'}), const PushTarget(PushDest.community, id: 12));
      expect(resolvePushTarget({'targetType': 'COMMUNITY', 'targetId': '12'}), const PushTarget(PushDest.community, id: 12));
    });

    Future<FakeBackend> pumpShell(WidgetTester tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/notifications', {'items': <Object>[], 'unreadCount': 0, 'nextCursor': null})
        ..on('/conversations/5', {
          'conversation': {'id': 5, 'type': 'GROUP', 'title': 'Grup'},
          'members': <Object>[],
        })
        ..on('/conversations/5/messages*', {'items': <Object>[], 'nextCursor': null});
      PushRouter.session = makeSession(b);
      await tester.pumpWidget(MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: BuTheme.light(),
        home: const Scaffold(body: Text('kabuk')),
      ));
      return b;
    }

    testWidgets('CONVERSATION_CLOSED dokunusu: sohbet acilir ve kapali bantla gelir', (tester) async {
      await pumpShell(tester);
      PushRouter.open({'conversationId': '5', 'targetType': 'CONVERSATION', 'targetId': '5', 'event': 'CONVERSATION_CLOSED'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(ChatDetailPage), findsOneWidget);
      expect(find.byKey(_banner), findsOneWidget);
      expect(find.byKey(_field), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CONVERSATION_REOPENED dokunusu: sohbet acilir, yazma alani acik', (tester) async {
      await pumpShell(tester);
      ClosedConversations.instance.markClosed(5);
      PushRouter.open({'conversationId': '5', 'targetType': 'CONVERSATION', 'targetId': '5', 'event': 'CONVERSATION_REOPENED'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(ChatDetailPage), findsOneWidget);
      expect(find.byKey(_banner), findsNothing);
      expect(find.byKey(_field), findsOneWidget);
    });

    testWidgets('CONVERSATION_REMOVED dokunusu: sohbet acilmaz, Sohbet sekmesi istenir, acik rotalar kapanir', (tester) async {
      final b = await pumpShell(tester);
      rootNavigatorKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('ustte'))));
      await tester.pumpAndSettle();
      expect(find.text('ustte'), findsOneWidget);
      PushRouter.open({'conversationId': '5', 'targetType': 'CONVERSATION', 'targetId': '5', 'event': 'CONVERSATION_REMOVED'});
      await tester.pumpAndSettle();
      expect(shellTabRequest.value, 2);
      expect(find.byType(ChatDetailPage), findsNothing);
      expect(find.text('ustte'), findsNothing);
      expect(find.text('kabuk'), findsOneWidget);
      expect(b.count('GET /conversations/5'), 0); // olmayan sohbet cekilmez
    });
  });

  group('Sohbet listesi / kabuk (P08)', () {
    testWidgets('son mesaj yonetici kaldirmasiysa listede yer tutucu onizleme', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/conversations/unread-count', {'total': 0})
        ..on('/conversations*', {
          'items': [
            {
              'id': 1,
              'type': 'DIRECT',
              'title': 'Ali Veli',
              'peer': {'id': 11, 'displayName': 'Ali Veli'},
              'unreadCount': 0,
              'lastMessage': {
                'id': 5,
                'conversationId': 1,
                'senderId': 11,
                'text': _adminText,
                'removed': true,
                'createdAt': _iso(1),
              },
            }
          ],
          'nextCursor': null,
        });
      await tester.pumpWidget(buildApp(ChatTab(session: makeSession(b), connectRealtime: false), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text(_adminText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shellTabRequest = Sohbet: kabuk Sohbet sekmesine gecer ve istegi tuketir', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(AppShell(session: makeSession(FakeBackend()), themeController: ThemeController())));
      await settle(tester);
      expect(tester.widget<FloatingNav>(find.byType(FloatingNav)).index, 0);
      shellTabRequest.value = AppTab.chat;
      await settle(tester, const Duration(milliseconds: 400));
      expect(tester.widget<FloatingNav>(find.byType(FloatingNav)).index, AppTab.chat);
      expect(shellTabRequest.value, isNull);
    });
  });

  group('Sertifika iptali (P07)', () {
    test('CERTIFICATE_REVOKED 409 yerel metinle gosterilir', () {
      final t = errorText(ApiError(409, 'CERTIFICATE_REVOKED', ''));
      expect(t, 'Bu sertifika yönetici tarafından iptal edildi.');
      // Sunucu metni olsa bile yerel (uygulama dilindeki) metin onceliklidir
      expect(errorText(ApiError(409, 'CERTIFICATE_REVOKED', 'Bu sertifika yönetici tarafından iptal edildi.')), t);
    });

    test('3 dilde metin var', () {
      for (final code in ['tr', 'en', 'ar']) {
        final l = lookupAppLocalizations(Locale(code));
        expect(l.errCertificateRevoked, isNotEmpty);
        expect(l.chatClosedBanner, isNotEmpty);
        expect(l.clubUnavailable, isNotEmpty);
      }
      expect(lookupAppLocalizations(const Locale('en')).errCertificateRevoked, 'This certificate was revoked by an administrator.');
    });
  });

  group('Kulup kapatma (P06)', () {
    FakeBackend clubBackend() => FakeBackend()
      ..fail('/communities/3', status: 404, code: 'COMMUNITY_NOT_FOUND', message: 'Topluluk bulunamadı.');

    testWidgets('kapatilmis kulup 404: "Kulup su an kullanilamiyor", yeniden dene dugmesi yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ClubDetailPage(session: makeSession(clubBackend()), communityId: 3), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('clubUnavailable')), findsOneWidget);
      expect(find.text('Kulüp şu an kullanılamıyor.'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsNothing);
      expect(find.byType(RefreshIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('baska hatada (500) yeniden dene gorunur (kapali sayilmaz)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..fail('/communities/3', status: 500, code: 'SERVER_ERROR');
      await tester.pumpWidget(buildApp(ClubDetailPage(session: makeSession(b), communityId: 3), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('clubUnavailable')), findsNothing);
      expect(find.text('Yeniden dene'), findsOneWidget);
    });

    test('clubIsGone: 404 ve COMMUNITY_NOT_FOUND', () {
      expect(clubIsGone(ApiError(404, 'X', '')), isTrue);
      expect(clubIsGone(ApiError(400, 'COMMUNITY_NOT_FOUND', '')), isTrue);
      expect(clubIsGone(ApiError(500, 'SERVER_ERROR', '')), isFalse);
      expect(clubIsGone(ApiError(0, 'NETWORK', '')), isFalse);
    });

    test('COMMUNITY_NOT_FOUND her kulup isteginde yerel metne cevrilir (sohbet odasi dahil)', () {
      expect(errorText(ApiError(404, 'COMMUNITY_NOT_FOUND', 'Topluluk bulunamadı.')), 'Kulüp şu an kullanılamıyor.');
    });
  });

  group('Hesap silme uyarisi (B1)', () {
    for (final e in {
      const Locale('tr'): ['Sahibi olduğun kulüpler yönetici üyeye devredilir; aday yoksa kulüp kapatılır.', 'Cihaz, IP ve kullanım (analitik) kayıtların anında silinir.'],
      const Locale('en'): ['Clubs you own are transferred to an admin member; if there is no candidate, the club is closed.', 'Your device, IP and usage (analytics) records are deleted immediately.'],
    }.entries) {
      testWidgets('silme sayfasi kulup devri + anlik silinenler maddeleri (${e.key.languageCode})', (tester) async {
        useScreen(tester, const Size(390, 1400));
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BuTheme.light(),
          locale: e.key,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DeleteAccountPage(session: makeSession(FakeBackend())),
        ));
        await settle(tester, const Duration(milliseconds: 500));
        expect(find.text(e.value[0]), findsOneWidget);
        expect(find.text(e.value[1]), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
