import 'dart:convert';

import 'package:bu_kampus/core/accounts/account_store.dart';
import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/outbox/outbox.dart';
import 'package:bu_kampus/core/push/active_conversation.dart';
import 'package:bu_kampus/core/push/push_router.dart';
import 'package:bu_kampus/core/push/push_service.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/auth/data/onboarding_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

String _b64(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');
String _jwt(int id) => '${_b64('{"alg":"none"}')}.${_b64('{"sub":"$id"}')}.sig';

/// Hesap bağlamı: giden kutusu sahipliği ve başka hesabın bildirimi.
void main() {
  Outbox make(MemoryOutboxStore store, List<String> sent) => Outbox(
      store: store,
      autoSchedule: false,
      sender: (i) async {
        sent.add('${i.ownerUserId}:${i.clientId}');
        return {'id': 1};
      });

  Session twoAccounts({bool expire2 = false}) {
    mockSecureStorage();
    final s = Session(ApiClient(client: FakeBackend().client, retryDelay: Duration.zero),
        accounts: AccountStore(kv: MemoryAccountKv()));
    return s;
  }

  Future<void> seed(Session s, {bool expire2 = false}) async {
    await s.accounts.upsert(1, Tokens(_jwt(1), 'r1'));
    await s.accounts.upsert(2, Tokens(_jwt(2), 'r2'));
    if (expire2) await s.accounts.markExpired(2);
    s.api.tokens = Tokens(_jwt(1), 'r1');
    s.state = SessionState.signedIn;
    s.userId = 1;
  }

  group('Outbox sahipliği', () {
    test('hesap değişince bekleyen mesaj silinmez, yeni hesapla GİTMEZ, hesaba dönünce gider', () async {
      final store = MemoryOutboxStore();
      final sent = <String>[];
      final ob = make(store, sent);
      ob.bindOwner(1);
      ob.enqueue(conversationId: 5, clientId: 'a', text: 'merhaba');
      expect(ob.items.single.ownerUserId, 1);
      ob.bindOwner(2);
      expect(ob.items, isEmpty);
      expect(ob.pendingCount, 0);
      ob.byClientId('a')!.nextAttemptAt = 0;
      await ob.drain();
      expect(sent, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(store.value, contains('"u":1'));
      ob.bindOwner(1);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      ob.byClientId('a')?.nextAttemptAt = 0;
      await ob.drain();
      expect(sent, ['1:a']);
    });

    test('oturum yok: hiçbir şey gönderilmez, silinmez', () async {
      final sent = <String>[];
      final ob = make(MemoryOutboxStore(), sent);
      ob.bindOwner(1);
      ob.enqueue(conversationId: 5, clientId: 'a', text: 'x');
      ob.bindOwner(null);
      ob.byClientId('a')!.nextAttemptAt = 0;
      await ob.drain();
      expect(sent, isEmpty);
      expect(ob.contains('a'), isTrue);
    });

    test('sahipsiz eski kayıt ilk bağlanan hesaba atanır; purgeOwner yalnız o hesabın kayıtlarını siler', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final store = MemoryOutboxStore()
        ..value = jsonEncode([
          {'c': 'old', 'v': 3, 't': 'eski', 'a': now, 's': 0, 'x': now + 600000},
        ]);
      final ob = make(store, []);
      await ob.load();
      ob.bindOwner(7);
      expect(ob.items.single.ownerUserId, 7);
      ob.enqueue(conversationId: 3, clientId: 'b', text: 'y');
      ob.bindOwner(8);
      ob.enqueue(conversationId: 3, clientId: 'c', text: 'z');
      await ob.purgeOwner(7);
      expect(ob.contains('old'), isFalse);
      expect(ob.contains('b'), isFalse);
      expect(ob.contains('c'), isTrue);
    });

    test('Session: hesap geçişinde etkin hesabın kutusuna bağlanır', () async {
      final s = twoAccounts();
      final ob = make(MemoryOutboxStore(), []);
      s.api.outbox = ob;
      await seed(s);
      expect(ob.owner, 1);
      ob.enqueue(conversationId: 9, clientId: 'k', text: 'bekleyen');
      expect(await s.switchAccount(2), SwitchResult.switched);
      expect(ob.owner, 2);
      expect(ob.items, isEmpty);
      expect(ob.contains('k'), isTrue);
      ob.bindOwner(1);
      expect(ob.items.single.clientId, 'k');
    });
  });

  group('Başka hesabın bildirimi', () {
    test('ön planda şerit/rozet üretmez', () {
      final s = makeSession(FakeBackend());
      final push = PushService(s, active: ActiveConversation.test());
      final before = s.badges.notifications.value;
      final shown = push.handleForeground(
          title: 'Baslik', body: 'Govde', data: {'targetType': 'EVENT', 'targetId': '3', 'recipientId': '99'});
      expect(shown, isFalse);
      expect(s.badges.notifications.value, before);
      final mine = push.handleForeground(
          title: 'Baslik', body: 'Govde', data: {'targetType': 'EVENT', 'targetId': '3', 'recipientId': '1'});
      expect(mine, isTrue);
    });

    test('kayıtlı hesaba ait: o hesaba geçilir, yük giriş sonrası açılmak üzere saklanır', () async {
      PushRouter.resetForTest();
      final s = twoAccounts();
      await seed(s);
      PushRouter.session = s;
      await PushRouter.open({'targetType': 'EVENT', 'targetId': '3', 'recipientId': '2'});
      expect(s.userId, 2);
      expect(PushRouter.hasPending, isTrue);
      PushRouter.resetForTest();
    });

    test('cihazda kayıtlı olmayan hesap: geçiş yok, yük saklanmaz', () async {
      PushRouter.resetForTest();
      final s = makeSession(FakeBackend());
      PushRouter.session = s;
      expect(await PushRouter.open({'targetType': 'EVENT', 'targetId': '3', 'recipientId': '99'}), isFalse);
      expect(s.userId, 1);
      expect(PushRouter.hasPending, isFalse);
      PushRouter.resetForTest();
    });

    test('oturumu dolmuş hesap: geçilmez, yük giriş için saklanır', () async {
      PushRouter.resetForTest();
      final s = twoAccounts();
      await seed(s, expire2: true);
      PushRouter.session = s;
      expect(await PushRouter.open({'targetType': 'EVENT', 'targetId': '3', 'recipientId': '2'}), isFalse);
      expect(s.userId, 1);
      expect(PushRouter.hasPending, isTrue);
      PushRouter.resetForTest();
    });
  });

  group('Onboarding taslağı hesap bazlı', () {
    test('hesaplar birbirinin taslağını görmez; kimlik değişince taslak yerinde kalır', () async {
      mockSecureStorage();
      OnboardingDraftStore.activeUserId = 1;
      await OnboardingDraftStore.save(const OnboardingDraft(firstName: 'Ali'));
      OnboardingDraftStore.activeUserId = 2;
      expect(await OnboardingDraftStore.load(), isNull);
      await OnboardingDraftStore.save(const OnboardingDraft(firstName: 'Veli'));
      OnboardingDraftStore.activeUserId = 1;
      expect((await OnboardingDraftStore.load())!.firstName, 'Ali');
      await OnboardingDraftStore.clearFor(1);
      expect(await OnboardingDraftStore.load(), isNull);
      OnboardingDraftStore.activeUserId = 2;
      expect((await OnboardingDraftStore.load())!.firstName, 'Veli');
      OnboardingDraftStore.activeUserId = null;
    });

    test('Apple adı hesap bilinmeden saklanır, hesap belli olunca o hesabın taslağına geçer', () async {
      mockSecureStorage();
      OnboardingDraftStore.activeUserId = null;
      await OnboardingDraftStore.savePending(firstName: 'Ali', lastName: 'Kaya');
      OnboardingDraftStore.activeUserId = 5;
      await OnboardingDraftStore.savePrefill();
      final d = await OnboardingDraftStore.load();
      expect(d!.firstName, 'Ali');
      expect(d.lastName, 'Kaya');
      OnboardingDraftStore.activeUserId = null;
    });
  });
}
