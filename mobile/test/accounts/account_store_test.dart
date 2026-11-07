import 'package:bu_kampus/core/accounts/account_store.dart';
import 'package:bu_kampus/core/api.dart' show Tokens;
import 'package:flutter_test/flutter_test.dart';

Tokens _t(int i) => Tokens('access-secret-$i', 'refresh-secret-$i');

void main() {
  test('ekle, etkin yap, kaldir; yeni ornek ayni depodan yukler', () async {
    final kv = MemoryAccountKv();
    final s = AccountStore(kv: kv);
    await s.load();
    await s.upsert(1, _t(1), displayName: 'Ayse', username: 'ayse', email: 'ayse.yilmaz@gmail.com');
    await s.upsert(2, _t(2), displayName: 'Mehmet');
    await s.setActive(2);
    expect(s.accounts.map((a) => a.userId), [1, 2]);
    expect(s.activeId, 2);
    expect(s.byId(1)!.emailMasked, 'a***@gmail.com');

    final s2 = AccountStore(kv: kv);
    await s2.load();
    expect(s2.accounts.length, 2);
    expect(s2.activeId, 2);
    expect(s2.tokensOf(1)!.refresh, 'refresh-secret-1');

    await s2.remove(1);
    expect(s2.has(1), isFalse);
    expect(kv.data['acct_tokens']!.contains('refresh-secret-1'), isFalse);
    expect(kv.data['acct_tokens']!.contains('refresh-secret-2'), isTrue);
    expect(s2.tokensOf(1), isNull);
  });

  test('cihaz basina en cok 5 hesap; mevcut hesap guncellenebilir', () async {
    final s = AccountStore(kv: MemoryAccountKv());
    for (var i = 1; i <= 5; i++) {
      await s.upsert(i, _t(i));
    }
    expect(s.isFull, isTrue);
    expect(() => s.upsert(6, _t(6)), throwsA(isA<AccountLimitException>()));
    expect(s.accounts.length, 5);
    await s.upsert(3, Tokens('yeni', 'yeni-r'), displayName: 'Guncel');
    expect(s.accounts.length, 5);
    expect(s.tokensOf(3)!.refresh, 'yeni-r');
    expect(s.byId(3)!.displayName, 'Guncel');
    await s.remove(2);
    expect(s.isFull, isFalse);
  });

  test('belirtec ve ham e-posta dizinde/toString/log ciktisinda yer almaz', () async {
    final kv = MemoryAccountKv();
    final s = AccountStore(kv: kv);
    await s.upsert(7, _t(7), displayName: 'Ali', email: 'ali.veli@outlook.com');
    final index = kv.data['acct_index']!;
    expect(index.contains('secret'), isFalse);
    expect(index.contains('ali.veli@outlook.com'), isFalse);
    expect(index.contains('a***@outlook.com'), isTrue);
    expect(s.byId(7).toString().contains('secret'), isFalse);
    expect(s.accounts.toString().contains('secret'), isFalse);
    // Belirtec yalniz hesap basina ayri anahtarda durur.
    expect(kv.data['acct_tokens']!.contains('refresh-secret-7'), isTrue);
    expect(index.contains('acct_tokens'), isFalse);
  });

  test('markExpired belirteci siler, hesap listede kalir ve gecilebilir sayilmaz', () async {
    final kv = MemoryAccountKv();
    final s = AccountStore(kv: kv);
    await s.upsert(1, _t(1));
    await s.upsert(2, _t(2));
    expect(s.nextSwitchable(except: 1)!.userId, 2);
    await s.markExpired(2);
    expect(s.byId(2)!.expired, isTrue);
    expect(s.tokensOf(2), isNull);
    expect(kv.data.containsKey('acct_tokens') ? kv.data['acct_tokens']!.contains('refresh-secret-2') : false, isFalse);
    expect(s.nextSwitchable(except: 1), isNull);
    expect(s.switchableCount(), 1);
    // Yeniden giris: ayni hesap tekrar eklenince isaret kalkar.
    await s.upsert(2, _t(22));
    expect(s.byId(2)!.expired, isFalse);
    expect(s.nextSwitchable(except: 1)!.userId, 2);
  });

  test('nextSwitchable once tercih edilen hesabi dener', () async {
    final s = AccountStore(kv: MemoryAccountKv());
    for (var i = 1; i <= 3; i++) {
      await s.upsert(i, _t(i));
    }
    expect(s.nextSwitchable(except: 1)!.userId, 2);
    expect(s.nextSwitchable(except: 1, prefer: 3)!.userId, 3);
    expect(s.nextSwitchable(except: 3, prefer: 3)!.userId, 1);
  });

  test('maskEmail', () {
    expect(AccountStore.maskEmail('x@y.com'), 'x***@y.com');
    expect(AccountStore.maskEmail('bozuk'), '***');
  });

  test('bozuk belirtec kaydi hesabi oturumu doldu isaretler', () async {
    final kv = MemoryAccountKv();
    final s = AccountStore(kv: kv);
    await s.upsert(1, _t(1));
    kv.data['acct_tokens'] = 'not-json';
    final s2 = AccountStore(kv: kv);
    await s2.load();
    expect(s2.byId(1)!.expired, isTrue);
  });
}
