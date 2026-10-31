import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/push/active_conversation.dart';
import 'package:bu_kampus/core/push/push_api.dart';
import 'package:bu_kampus/core/push/push_banner.dart';
import 'package:bu_kampus/core/push/push_channels.dart';
import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void main() {
  setUpAll(loadTestFonts);

  group('kanal tablosu', () {
    test('sunucu kimlikleri tabloda ve onem dogru', () {
      final ids = pushChannels.map((c) => c.id).toList();
      expect(ids, containsAll(['chat', 'event', 'announcement']));
      expect(pushChannels.firstWhere((c) => c.id == 'chat').importance, PushImportance.high);
      expect(pushChannels.firstWhere((c) => c.id == 'social').importance, PushImportance.low);
      expect(ids.toSet().length, ids.length);
    });
    test('tur -> kanal', () {
      expect(channelForType('MESSAGE'), 'chat');
      expect(channelForType('event'), 'event');
      expect(channelForType('NEWS'), 'announcement');
      expect(channelForType(null), 'announcement');
    });
  });

  group('yonlendirme eslemesi', () {
    test('turler dogru hedefe', () {
      PushDest d(Map<String, dynamic> m) => resolvePushTarget(m).dest;
      expect(d({'targetType': 'CONVERSATION', 'targetId': '4'}), PushDest.conversation);
      expect(d({'targetType': 'MESSAGE', 'targetId': '4'}), PushDest.conversation);
      expect(d({'targetType': 'USER', 'targetId': '9'}), PushDest.user);
      expect(d({'targetType': 'EVENT', 'targetId': '2'}), PushDest.event);
      expect(d({'targetType': 'COMMUNITY', 'targetId': '2'}), PushDest.community);
      expect(d({'targetType': 'POLL', 'targetId': '2'}), PushDest.poll);
      expect(d({'targetType': 'ANNOUNCEMENT', 'targetId': '2'}), PushDest.news);
      expect(d({'targetType': 'POST', 'targetId': '2'}), PushDest.post);
      expect(d({'targetType': 'TICKET', 'targetId': '2'}), PushDest.ticket);
      expect(d({'targetType': 'YOK', 'targetId': 'x'}), PushDest.notifications);
      expect(d({}), PushDest.notifications);
    });
  });

  group('ActiveConversation bastirma karari', () {
    test('acik sohbet + on plan -> bastir; baska sohbet/arka plan -> gosterilir', () {
      final a = ActiveConversation.test();
      expect(a.shouldSuppress({'conversationId': '5'}), false); // hicbiri acik degil
      a.enter(5);
      expect(a.shouldSuppress({'conversationId': '5'}), true);
      expect(a.shouldSuppress({'targetType': 'CONVERSATION', 'targetId': '5'}), true);
      expect(a.shouldSuppress({'conversationId': '6'}), false);
      expect(a.shouldSuppress({'targetType': 'EVENT', 'targetId': '5'}), false);
      a.setForeground(false);
      expect(a.shouldSuppress({'conversationId': '5'}), false);
      expect(a.viewingId, isNull);
      expect(a.openId, 5);
      a.setForeground(true);
      a.leave(7); // baska sohbetin leave'i etkilemez
      expect(a.openId, 5);
      a.leave(5);
      expect(a.openId, isNull);
    });
  });

  group('banner birlesme', () {
    BannerItem it(String k, String body) => BannerItem(key: k, title: 'T', body: body, data: {'conversationId': k});
    test('ayni anahtar sayaci artirir, farkli anahtar degistirir', () {
      var c = mergeBanner(null, it('1', 'a'));
      expect(c.count, 1);
      c = mergeBanner(c, it('1', 'b'));
      c = mergeBanner(c, it('1', 'c'));
      expect(c.count, 3);
      expect(c.body, 'c');
      c = mergeBanner(c, it('2', 'x'));
      expect(c.count, 1);
    });
    test('anahtar', () {
      expect(bannerKey({'conversationId': '3'}, 'x'), 'conv-3');
      expect(bannerKey({'targetType': 'EVENT', 'targetId': '8'}, 'x'), 'EVENT-8');
      expect(bannerKey({}, 'Baslik'), 'title-Baslik');
    });
    test('sohbet disi seridin simgesi hedef turune gore (kisi silueti degil)', () {
      final ev = bannerIcon({'targetType': 'EVENT', 'targetId': '7'});
      final news = bannerIcon({'targetType': 'NEWS', 'targetId': '3'});
      final poll = bannerIcon({'pollId': '5'});
      final like = bannerIcon({'type': 'POST_LIKE', 'postId': '9'});
      final chat = bannerIcon({'conversationId': '4'});
      final unknown = bannerIcon({});
      expect({ev, news, poll, like, chat, unknown}.length, 6, reason: 'her tur ayri simge; bos yuk cana duser');
      expect(bannerIcon({'targetType': 'ACADEMIC_EXAM'}), bannerIcon({'targetType': 'TIMETABLE'}));
    });

    testWidgets('sere gorunur, birlesir, 4 sn sonra kaybolur, dokunus yonlendirir', (tester) async {
      final center = PushBannerCenter();
      Map<String, dynamic>? tapped;
      await tester.pumpWidget(MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: BuTheme.light(),
        home: const Scaffold(body: Text('kabuk')),
      ));
      void show(String body) => center.show(
            BannerItem(key: 'conv-1', title: 'Ayşe', body: body, data: {'conversationId': '1'}),
            onTap: (d) => tapped = d,
          );
      show('merhaba');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Ayşe'), findsOneWidget);
      show('naber');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('+1 yeni mesaj daha'), findsOneWidget);
      expect(find.text('naber'), findsOneWidget);
      await tester.tap(find.text('naber'));
      await tester.pump();
      expect(tapped?['conversationId'], '1');
      expect(find.text('Ayşe'), findsNothing);

      show('tekrar');
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Ayşe'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('Ayşe'), findsNothing);
    });
  });

  group('PushApi (sahte backend)', () {
    test('kayit: token, platform, surum, dil; cikista silme', () async {
      final b = FakeBackend()..on('/devices', null, status: 204);
      final s = makeSession(b);
      s.api.lang = 'en';
      final api = PushApi(s.api);
      await api.register('tok/1', platform: 'ANDROID', appVersion: '1.2.3');
      final body = b.bodies['POST /devices'] as Map;
      expect(body['fcmToken'], 'tok/1');
      expect(body['platform'], 'ANDROID');
      expect(body['appVersion'], '1.2.3');
      expect(body['locale'], 'en');
      await api.unregister('tok/1');
      expect(b.requests.any((r) => r.startsWith('DELETE /devices/tok%2F1')), true);
    });

    test('state ve viewing: uc yoksa (404) sessiz ve bir kez denenir', () async {
      final b = FakeBackend()
        ..fail('/devices/t/state', status: 404, code: 'NOT_FOUND')
        ..fail('/conversations/3/viewing', status: 404, code: 'NOT_FOUND');
      final api = PushApi(makeSession(b).api);
      await api.setState('t', false);
      await api.setState('t', true);
      expect(b.count('/devices/t/state'), 1);
      await api.viewing(3);
      await api.viewing(3);
      await api.stopViewing(3);
      expect(b.count('/conversations/3/viewing'), 1);
    });

    test('state gonderimi', () async {
      final b = FakeBackend()..on('/devices/t/state', null, status: 204);
      await PushApi(makeSession(b).api).setState('t', false);
      expect(b.bodies['PUT /devices/t/state'], {'foreground': false});
    });

    test('ViewingSignaler: ac -> PUT, periyodik, kapat -> DELETE, arka plan -> DELETE', () async {
      final b = FakeBackend()
        ..on('/conversations/3/viewing', null, status: 204);
      final active = ActiveConversation.test();
      final sig = ViewingSignaler(PushApi(makeSession(b).api), active, interval: const Duration(milliseconds: 50))..start();
      active.enter(3);
      await Future<void>.delayed(const Duration(milliseconds: 180));
      expect(b.requests.where((r) => r.startsWith('PUT /conversations/3/viewing')).length, greaterThanOrEqualTo(3));
      active.setForeground(false);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(b.requests.where((r) => r.startsWith('DELETE /conversations/3/viewing')).length, 1);
      final puts = b.count('PUT /conversations/3/viewing');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(b.count('PUT /conversations/3/viewing'), puts); // arka planda sinyal yok
      sig.stop();
    });
  });
}
