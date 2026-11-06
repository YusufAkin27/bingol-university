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

    test('alan adi kisiti yok: her gecerli bicimli e-posta (gmail, outlook, okul...)', () {
      expect(isMatchableEmail('a@bingol.edu.tr'), isTrue);
      expect(isMatchableEmail('a@ogr.bingol.edu.tr'), isTrue);
      expect(isMatchableEmail('a@gmail.com'), isTrue);
      expect(isMatchableEmail('a@outlook.com'), isTrue);
      expect(isMatchableEmail('a@hotmail.com'), isTrue);
      expect(isMatchableEmail('a@yahoo.com'), isTrue);
      expect(isMatchableEmail('bingol.edu.tr'), isFalse);
      expect(isMatchableEmail('@bingol.edu.tr'), isFalse);
      expect(isMatchableEmail('a@'), isFalse);
      expect(isMatchableEmail('a@gmail'), isFalse);
      expect(isMatchableEmail('a@gmail..com'), isFalse);
      expect(isMatchableEmail('a@x y.com'), isFalse);
    });
  });

  group('ContactsMatchPage', () {
    testWidgets('gecersiz bicim gonderilmez, kendi adres haric, sonuclar listelenir', (tester) async {
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
        'bozuk-adres', // geçersiz biçim: gönderilmez
        'veli@bingol.edu.tr', // tekrar
      ]);
      await _pump(tester, ContactsMatchPage(session: s, provider: provider, permissions: _granted()));

      expect(find.text('Rehberden kişi bul'), findsNothing); // sayfa başlığı görünmez (sadeleştirme)
      expect(find.text('Veli Demir'), findsOneWidget);
      expect(find.text('Ali Kaya'), findsOneWidget);
      expect(find.text('Bilgisayar Mühendisliği'), findsOneWidget);
      expect(find.text('Mesaj'), findsNWidgets(2));
      expect(find.textContaining('yalnızca e-posta özetleri eşleştirilir'), findsOneWidget);

      final body = be.bodies['POST /users/contacts/match'] as Map;
      final hashes = (body['hashes'] as List).cast<String>();
      expect(hashes.toSet(), {emailHash('veli@bingol.edu.tr'), emailHash('ali@ogr.bingol.edu.tr'), emailHash('x@gmail.com')});
      expect(hashes.length, 3);
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

    testWidgets('rehberde gecerli e-posta yoksa bos durum, istek atilmaz', (tester) async {
      final be = FakeBackend();
      final s = makeSession(be);
      await _pump(tester,
          ContactsMatchPage(session: s, provider: _FakeContacts(['bozuk-adres', 'a@gmail']), permissions: _granted()));
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

    // QA-CHAT-01: sunucu karsilikli riza ister (varsayilan KAPALI); mobilde rizayi acan arayuz yoktu.
    testWidgets('QA-CHAT-01: bulunabilirim kapaliyken riza karti, rehber/izin istenmez; Ac ve devam et PUT + eslestirme', (tester) async {
      final be = FakeBackend()
        ..on('/users/contacts/discoverable', {'enabled': false})
        ..on('/users/contacts/match', {
          'matches': [_match('veli@bingol.edu.tr', 7, 'Veli Demir')],
        });
      final s = makeSession(be);
      final provider = _FakeContacts(['veli@bingol.edu.tr']);
      final perms = FakePermissionService();
      await _pump(tester, ContactsMatchPage(session: s, provider: provider, permissions: perms));
      expect(find.text('Rehberden bulunabilirim'), findsOneWidget);
      expect(provider.reads, 0);
      expect(perms.requested, isEmpty);
      expect(be.count('POST /users/contacts/match'), 0);

      be.on('/users/contacts/discoverable', {'enabled': true});
      await tester.tap(find.text('Aç ve devam et'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(be.bodies['PUT /users/contacts/discoverable'], {'enabled': true});
      // Riza verildikten sonra normal akis (izin gerekcesi)
      expect(find.textContaining('rehbere erişmemiz gerekir'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('QA-CHAT-01: eslestirme 403 CONTACTS_DISCOVERABLE_REQUIRED donerse riza kartina doner', (tester) async {
      final be = FakeBackend()
        ..on('/users/contacts/discoverable', {'enabled': true})
        ..fail('/users/contacts/match', status: 403, code: 'CONTACTS_DISCOVERABLE_REQUIRED');
      final s = makeSession(be);
      await _pump(tester,
          ContactsMatchPage(session: s, provider: _FakeContacts(['veli@bingol.edu.tr']), permissions: _granted()));
      expect(find.text('Aç ve devam et'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsNothing);
      _noErrors(tester);
    });

    testWidgets('QA-CHAT-01: bulunabilirligi kapat PUT enabled=false ve riza kartina doner', (tester) async {
      final be = FakeBackend()
        ..on('/users/contacts/discoverable', {'enabled': true})
        ..on('/users/contacts/match', {
          'matches': [_match('veli@bingol.edu.tr', 7, 'Veli Demir')],
        });
      final s = makeSession(be);
      await _pump(tester,
          ContactsMatchPage(session: s, provider: _FakeContacts(['veli@bingol.edu.tr']), permissions: _granted()));
      expect(find.text('Veli Demir'), findsOneWidget);
      await tester.ensureVisible(find.text('Rehberden bulunabilirliği kapat'));
      await tester.tap(find.text('Rehberden bulunabilirliği kapat'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(be.bodies['PUT /users/contacts/discoverable'], {'enabled': false});
      expect(find.text('Veli Demir'), findsNothing);
      expect(find.text('Aç ve devam et'), findsOneWidget);
      _noErrors(tester);
    });

    // QA-CHAT-02: gunluk aday tavani 2000 = 4 parca; 5. parca 429 iken ilk 4 parcanin eslesmeleri atiliyordu.
    testWidgets('QA-CHAT-02: 5. parca 429 (gunluk tavan) ise onceki eslesmeler korunur + kismi uyari', (tester) async {
      final be = FakeBackend()..on('/users/contacts/discoverable', {'enabled': true});
      var n = 0;
      be.handlers.add((req, path) {
        if (path != '/users/contacts/match') return null;
        n++;
        if (n >= 5) return const FakeResult.json({'code': 'RATE_LIMITED', 'message': 'x'}, status: 429);
        return FakeResult.json({
          'matches': n == 1 ? [_match('u0@bingol.edu.tr', 7, 'Veli Demir')] : <Object>[]
        });
      });
      final s = makeSession(be);
      final provider = _FakeContacts([for (var i = 0; i < 2600; i++) 'u$i@bingol.edu.tr']);
      await _pump(tester, ContactsMatchPage(session: s, provider: provider, permissions: _granted()));
      expect(n, 5);
      expect(find.text('Veli Demir'), findsOneWidget);
      expect(find.textContaining('Saatlik istek sınırına ulaşıldı'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsNothing);
      _noErrors(tester);
    });

    testWidgets('QA-CHAT-02: ilk parca 429 ise hata ekrani (kismi sonuc yok)', (tester) async {
      final be = FakeBackend()
        ..on('/users/contacts/discoverable', {'enabled': true})
        ..fail('/users/contacts/match', status: 429, code: 'RATE_LIMITED');
      final s = makeSession(be);
      await _pump(tester,
          ContactsMatchPage(session: s, provider: _FakeContacts(['veli@bingol.edu.tr']), permissions: _granted()));
      expect(find.text('Yeniden dene'), findsOneWidget);
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
