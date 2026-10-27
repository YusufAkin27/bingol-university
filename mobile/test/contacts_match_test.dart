import 'package:bu_kampus/core/contacts/contacts_service.dart';
import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/contacts_match_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

class _FakeContacts implements ContactsProvider {
  _FakeContacts(this.emails);
  final List<String> emails;
  int reads = 0;

  @override
  Future<List<String>> readEmails() async {
    reads++;
    return emails;
  }
}

Map<String, dynamic> _match(String email, int id, String name, {String? dept}) => {
      'hash': emailHash(email),
      'userId': id,
      'displayName': name,
      'avatarUrl': null,
      'faculty': 'Mühendislik Fakültesi',
      'department': dept,
    };

void _noErrors(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('$e');
}

FakePermissionService _granted() => FakePermissionService(initial: {AppPermission.contacts: PermState.granted});

Future<void> _pump(WidgetTester tester, ContactsMatchPage page,
    {Brightness b = Brightness.light, Size size = kPhoneMedium}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(page, brightness: b, size: size));
  await settle(tester, const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });
  setUp(ContactsMatcher.resetLimiter);

  group('ozet ve suzme', () {
    test('bilinen e-posta icin bilinen SHA-256', () {
      const known = '3d77f00c84be3df1d2287bcce89d12bd3bcdc97103f858d2a6ad97b3806e4c60';
      expect(emailHash('ayse@bingol.edu.tr'), known);
      expect(emailHash('  AYSE@Bingol.edu.TR '), known);
    });

    test('yalniz bingol.edu.tr ve alt alanlari', () {
      expect(isCampusEmail('a@bingol.edu.tr'), isTrue);
      expect(isCampusEmail('a@ogr.bingol.edu.tr'), isTrue);
      expect(isCampusEmail('a@gmail.com'), isFalse);
      expect(isCampusEmail('a@evilbingol.edu.tr'), isFalse);
      expect(isCampusEmail('a@bingol.edu.tr.evil.com'), isFalse);
      expect(isCampusEmail('bingol.edu.tr'), isFalse);
      expect(isCampusEmail('@bingol.edu.tr'), isFalse);
    });
  });

  group('ContactsMatchPage', () {
    testWidgets('alan disi e-posta gonderilmez, kendi adres haric, sonuclar listelenir', (tester) async {
      final be = FakeBackend()
        ..on('/users/contacts/match', {
          'matches': [
            _match('veli@bingol.edu.tr', 7, 'Veli Demir', dept: 'Bilgisayar Mühendisliği'),
            _match('ali@ogr.bingol.edu.tr', 8, 'Ali Kaya'),
          ],
        });
      final s = makeSession(be);
      final provider = _FakeContacts([
        'Veli@Bingol.edu.tr ',
        'ali@ogr.bingol.edu.tr',
        'ayse@bingol.edu.tr', // kendi adresim
        'x@gmail.com',
        'y@evilbingol.edu.tr',
        'veli@bingol.edu.tr', // tekrar
      ]);
      await _pump(tester, ContactsMatchPage(session: s, provider: provider, permissions: _granted()));

      expect(find.text('Rehberden kişi bul'), findsOneWidget);
      expect(find.text('Veli Demir'), findsOneWidget);
      expect(find.text('Ali Kaya'), findsOneWidget);
      expect(find.text('Bilgisayar Mühendisliği'), findsOneWidget);
      expect(find.text('Mesaj'), findsNWidgets(2));
      expect(find.textContaining('yalnızca e-posta özetleri eşleştirilir'), findsOneWidget);

      final body = be.bodies['POST /users/contacts/match'] as Map;
      final hashes = (body['hashes'] as List).cast<String>();
      expect(hashes.toSet(), {emailHash('veli@bingol.edu.tr'), emailHash('ali@ogr.bingol.edu.tr')});
      expect(hashes.length, 2);
      expect(be.count('POST /users/contacts/match'), 1);

      // Arama
      await tester.enterText(find.byType(TextField), 'bilgisayar');
      await tester.pump();
      expect(find.text('Veli Demir'), findsOneWidget);
      expect(find.text('Ali Kaya'), findsNothing);
      _noErrors(tester);
    });

    testWidgets('500luk parcalara bolunur', (tester) async {
      final be = FakeBackend()..on('/users/contacts/match', {'matches': <Object>[]});
      final s = makeSession(be);
      final provider = _FakeContacts([for (var i = 0; i < 1100; i++) 'u$i@ogr.bingol.edu.tr']);
      await _pump(tester, ContactsMatchPage(session: s, provider: provider, permissions: _granted()));
      expect(be.count('POST /users/contacts/match'), 3);
      expect((be.bodies['POST /users/contacts/match'] as Map)['hashes'], hasLength(100)); // son parca
      expect(find.text('Eşleşen kişi yok'), findsOneWidget);
      _noErrors(tester);
    });

    testWidgets('saatlik limit asilirsa kalan parcalar atlanir', (tester) async {
      final be = FakeBackend()..on('/users/contacts/match', {'matches': <Object>[]});
      final s = makeSession(be);
      final provider = _FakeContacts([for (var i = 0; i < 4000; i++) 'u$i@bingol.edu.tr']); // 8 parca
      await _pump(tester, ContactsMatchPage(session: s, provider: provider, permissions: _granted()));
      expect(be.count('POST /users/contacts/match'), contactsHourlyLimit);
    });

    testWidgets('Mesaj birebir konusma acar', (tester) async {
      final be = FakeBackend()
        ..on('/users/contacts/match', {
          'matches': [_match('veli@bingol.edu.tr', 7, 'Veli Demir')],
        })
        ..on('/conversations', {
          'id': 5,
          'type': 'DIRECT',
          'title': 'Veli Demir',
          'peer': {'id': 7, 'displayName': 'Veli Demir'},
        });
      final s = makeSession(be);
      await _pump(
          tester, ContactsMatchPage(session: s, provider: _FakeContacts(['veli@bingol.edu.tr']), permissions: _granted()));
      await tester.tap(find.text('Mesaj'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(be.bodies['POST /conversations'], {'userId': 7});
      expect(find.byType(ChatDetailPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('rehberde kampus adresi yoksa bos durum, istek atilmaz', (tester) async {
      final be = FakeBackend();
      final s = makeSession(be);
      await _pump(tester,
          ContactsMatchPage(session: s, provider: _FakeContacts(['a@gmail.com']), permissions: _granted()));
      expect(find.text('Eşleşen kişi yok'), findsOneWidget);
      expect(be.count('contacts/match'), 0);
      _noErrors(tester);
    });

    testWidgets('izin yoksa gerekce + izin akisi', (tester) async {
      final be = FakeBackend()
        ..on('/users/contacts/match', {
          'matches': [_match('veli@bingol.edu.tr', 7, 'Veli Demir')],
        });
      final s = makeSession(be);
      final perms = FakePermissionService();
      final provider = _FakeContacts(['veli@bingol.edu.tr']);
      await _pump(tester, ContactsMatchPage(session: s, provider: provider, permissions: perms));
      expect(find.textContaining('rehbere erişmemiz gerekir'), findsOneWidget); // gerekce sheeti
      await tester.tap(find.text('Şimdi değil'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Rehber izni gerekli'), findsOneWidget);
      expect(provider.reads, 0);

      await tester.tap(find.text('İzin ver'));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('Devam'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(perms.requested, [AppPermission.contacts]);
      expect(find.text('Veli Demir'), findsOneWidget);
      _noErrors(tester);
    });

    testWidgets('hata + yeniden dene', (tester) async {
      final be = FakeBackend()..network('/users/contacts/match');
      final s = makeSession(be);
      await _pump(tester,
          ContactsMatchPage(session: s, provider: _FakeContacts(['veli@bingol.edu.tr']), permissions: _granted()));
      expect(find.text('Yeniden dene'), findsOneWidget);

      be.on('/users/contacts/match', {
        'matches': [_match('veli@bingol.edu.tr', 7, 'Veli Demir')],
      });
      ContactsMatcher.resetLimiter();
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Veli Demir'), findsOneWidget);
      _noErrors(tester);
    });

    for (final b in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('tasma yok ${b.name} ${size.width.toInt()}', (tester) async {
          final be = FakeBackend()
            ..on('/users/contacts/match', {
              'matches': [
                _match('veli@bingol.edu.tr', 7,
                    'Çok Uzun Bir İsim Soyisim Örnek Kişi Adı Burada Devam Ediyor',
                    dept: 'Elektrik-Elektronik Mühendisliği ve Bilgisayar Bilimleri Çok Uzun Bölüm Adı'),
                _match('ali@bingol.edu.tr', 8, 'Ali Kaya'),
              ],
            });
          final s = makeSession(be);
          await _pump(
              tester,
              ContactsMatchPage(
                  session: s, provider: _FakeContacts(['veli@bingol.edu.tr', 'ali@bingol.edu.tr']), permissions: _granted()),
              b: b,
              size: size);
          expect(find.text('Ali Kaya'), findsOneWidget);
          _noErrors(tester);
          await unmount(tester);
        });
      }
    }
  });
}
