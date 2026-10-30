import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_info_page.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _profile = {
  'id': 2,
  'displayName': 'Mehmet Kaya',
  'faculty': 'Mühendislik Fakültesi',
  'department': 'Bilgisayar Mühendisliği',
  'classYear': 3,
  'bio': 'Merhaba, ben Mehmet.',
  'avatarUrl': null,
  'email': 'mehmet@bingol.edu.tr',
};

FakeBackend _be({Map<String, dynamic> profile = _profile}) => FakeBackend()..on('/users/2', profile);

Future<void> _open(WidgetTester tester, FakeBackend be,
    {Brightness b = Brightness.light, Size size = kPhoneMedium, int userId = 2, int? from}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(
    UserProfilePage(session: makeSession(be), userId: userId, initialName: 'Mehmet', fromConversationId: from),
    brightness: b,
    size: size,
  ));
  await settle(tester, const Duration(milliseconds: 600));
}

Future<void> _menu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('profile-more')));
  await tester.pump(const Duration(milliseconds: 300));
}

void _ok(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('$e');
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('yükleniyor, sonra profil bilgileri', (tester) async {
    final be = FakeBackend(delay: const Duration(milliseconds: 300))..on('/users/2', _profile);
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(
        buildApp(UserProfilePage(session: makeSession(be), userId: 2, initialName: 'Mehmet'), size: kPhoneMedium));
    await tester.pump();
    expect(find.text('Mehmet'), findsWidgets);
    expect(find.text('Hakkında'), findsNothing);
    await settle(tester);
    expect(find.text('Mehmet Kaya'), findsOneWidget);
    expect(find.text('Bilgisayar Mühendisliği'), findsOneWidget);
    expect(find.text('3. sınıf'), findsOneWidget);
    expect(find.text('Hakkında'), findsOneWidget);
    expect(find.text('Merhaba, ben Mehmet.'), findsOneWidget);
    expect(find.text('Fakülte'), findsOneWidget);
    expect(find.text('Mühendislik Fakültesi'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('mehmet@bingol.edu.tr'), findsOneWidget);
    expect(find.text('Mesaj gönder'), findsOneWidget);
    expect(find.text('Takip et'), findsOneWidget);
    expect(find.text('Engelle'), findsNothing);
    await _menu(tester);
    expect(find.text('Engelle'), findsOneWidget);
    expect(find.text('Raporla'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('gizlenmiş (null) alanlar Gizli görünür', (tester) async {
    final be = _be(profile: {'id': 2, 'displayName': 'Mehmet Kaya'});
    await _open(tester, be);
    expect(find.text('Mehmet Kaya'), findsOneWidget);
    // Gizlenmiş (null) alanlar kilit ikonlu "Gizli" olarak görünür; değer sızmaz.
    expect(find.text('Hakkında'), findsOneWidget);
    expect(find.text('Fakülte'), findsOneWidget);
    expect(find.text('Sınıf'), findsOneWidget);
    expect(find.text('Gizli'), findsNWidgets(3));
    expect(find.text('E-posta'), findsNothing);
    _ok(tester);
    await unmount(tester);
  });

  testWidgets('presence: çevrimiçi, son görülme, 404 gizler', (tester) async {
    final be = _be()..on('/users/2/presence', {'online': true});
    await _open(tester, be);
    expect(find.text('Çevrimiçi'), findsOneWidget);
    await unmount(tester);

    final be2 = _be()..on('/users/2/presence', {'online': false, 'lastSeenAt': '2020-01-05T10:00:00Z'});
    await _open(tester, be2);
    expect(find.textContaining('Son görülme'), findsOneWidget);
    await unmount(tester);

    final be3 = _be()..fail('/users/2/presence', status: 404, code: 'NOT_FOUND');
    await _open(tester, be3);
    expect(find.textContaining('Son görülme'), findsNothing);
    expect(find.text('Çevrimiçi'), findsNothing);
    expect(find.text('Mehmet Kaya'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Mesaj: POST /conversations {userId} sonra sohbet sayfası', (tester) async {
    final be = _be()
      ..on('/conversations', {
        'id': 9,
        'type': 'DIRECT',
        'peer': {'id': 2, 'displayName': 'Mehmet Kaya'},
      });
    await _open(tester, be);
    await tester.tap(find.text('Mesaj gönder'));
    await settle(tester);
    expect(be.bodies['POST /conversations'], {'userId': 2});
    expect(find.byType(ChatDetailPage), findsOneWidget);
    expect(find.byType(UserProfilePage), findsNothing);
    await unmount(tester);
  });

  testWidgets('Mesaj: aynı sohbetten gelindiyse yeni sayfa yığılmaz, geri dönülür', (tester) async {
    final be = _be()..on('/conversations', {'id': 5, 'type': 'DIRECT'});
    final s = makeSession(be);
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(Builder(
      builder: (c) => Scaffold(
        body: TextButton(
          onPressed: () => openUserProfile(c, s, userId: 2, name: 'Mehmet', fromConversationId: 5),
          child: const Text('ac'),
        ),
      ),
    )));
    await tester.tap(find.text('ac'));
    await settle(tester);
    expect(find.byType(UserProfilePage), findsOneWidget);
    await tester.tap(find.text('Mesaj gönder'));
    await settle(tester);
    expect(find.byType(UserProfilePage), findsNothing);
    expect(find.byType(ChatDetailPage), findsNothing);
    expect(find.text('ac'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Engelle onaylı POST, Engeli kaldır DELETE', (tester) async {
    final be = _be();
    await _open(tester, be);
    await _menu(tester);
    await tester.tap(find.text('Engelle'));
    await settle(tester);
    expect(find.text('Kullanıcı engellensin mi?'), findsOneWidget);
    expect(be.count('POST /users/2/block'), 0);
    await tester.tap(find.widgetWithText(TextButton, 'Engelle'));
    await settle(tester);
    expect(be.count('POST /users/2/block'), 1);
    await _menu(tester);
    expect(find.text('Engeli kaldır'), findsOneWidget);
    await tester.tap(find.text('Engeli kaldır'));
    await settle(tester);
    expect(be.count('DELETE /users/2/block'), 1);
    await _menu(tester);
    expect(find.text('Engelle'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Engellenmiş kullanıcı "Engeli kaldır" olarak açılır', (tester) async {
    final be = _be()
      ..on('/users/me/blocks?limit=50', [
        {'id': 2, 'displayName': 'Mehmet Kaya'}
      ]);
    await _open(tester, be);
    await _menu(tester);
    expect(find.text('Engeli kaldır'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Raporla rapor sayfasını açar', (tester) async {
    final be = _be();
    await _open(tester, be);
    await _menu(tester);
    await tester.tap(find.text('Raporla'));
    await settle(tester);
    expect(find.text('Kullanıcıyı şikâyet et'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('kendi profilinde eylem yok, Profili düzenle var', (tester) async {
    final be = FakeBackend()..on('/users/me', {'id': 1, 'displayName': 'Ayşe Yılmaz', 'email': 'ayse@bingol.edu.tr'});
    await _open(tester, be, userId: 1);
    expect(find.text('Mesaj gönder'), findsNothing);
    expect(find.byKey(const ValueKey('profile-more')), findsNothing);
    expect(find.text('Gizli'), findsNothing);
    expect(find.text('Profili düzenle'), findsOneWidget);
    expect(be.count('/presence'), 0);
    await unmount(tester);
  });

  testWidgets('404: Kullanıcı bulunamadı', (tester) async {
    final be = FakeBackend()..fail('/users/2', status: 404, code: 'NOT_FOUND', message: 'x');
    await _open(tester, be);
    expect(find.text('Kullanıcı bulunamadı'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('hata: yeniden dene', (tester) async {
    final be = FakeBackend()..fail('/users/2');
    await _open(tester, be);
    await settle(tester, const Duration(seconds: 3));
    expect(find.text('Yeniden dene'), findsOneWidget);
    be.on('/users/2', _profile);
    await tester.tap(find.text('Yeniden dene'));
    await settle(tester);
    expect(find.text('Mehmet Kaya'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('avatara dokununca tam ekran görüntüleyici', (tester) async {
    final be = _be(profile: {..._profile, 'avatarUrl': '/files/avatars/m.png'});
    await _open(tester, be);
    await tester.tap(find.byKey(const Key('profile-avatar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('dispose sonrası yanıt gelirse hata yok', (tester) async {
    final be = FakeBackend(delay: const Duration(milliseconds: 300))..on('/users/2', _profile);
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(be), userId: 2)));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    _ok(tester);
  });

  group('taşma', () {
    final long = {
      ..._profile,
      'displayName': 'Çok Uzun Bir Kullanıcı Adı Soyadı Örnek Kişi İkinci Soyad',
      'department': 'Elektrik-Elektronik Mühendisliği Çok Uzun Bölüm Adı',
      'bio': 'Uzun bir hakkında metni. ' * 12,
    };
    for (final size in kPhoneSizes) {
      for (final b in Brightness.values) {
        testWidgets('${size.width.toInt()} dp ${b.name}', (tester) async {
          final be = _be(profile: long)..on('/users/2/presence', {'online': true});
          await _open(tester, be, b: b, size: size);
          expect(find.textContaining('Uzun bir hakkında'), findsOneWidget);
          _ok(tester);
          await unmount(tester);
        });
      }
    }
  });

  group('bağlantılar', () {
    testWidgets('grup mesajında gönderen avatarına ve adına dokununca profil açılır', (tester) async {
      final be = FakeBackend()
        ..on('/conversations/7/messages?size=30', {
          'items': [
            {
              'id': 100,
              'conversationId': 7,
              'senderId': 2,
              'text': 'Selam',
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            },
          ],
          'nextCursor': null,
        })
        ..on('/conversations/7', {
          'conversation': {'id': 7},
          'members': [
            {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
            {'userId': 2, 'displayName': 'Mehmet Kaya'},
          ],
        })
        ..on('/users/2', _profile);
      final s = makeSession(be);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
        ChatDetailPage(
          session: s,
          connectRealtime: false,
          conversation: const {'id': 7, 'type': 'GROUP', 'title': 'Proje Grubu'},
        ),
        size: kPhoneMedium,
      ));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Selam'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sender-avatar-100')));
      await settle(tester);
      expect(find.byType(UserProfilePage), findsOneWidget);
      expect(find.text('Hakkında'), findsOneWidget);
      await tester.tap(find.byTooltip('Geri'));
      await settle(tester);
      expect(find.byType(UserProfilePage), findsNothing);
      await tester.tap(find.text('Mehmet Kaya'));
      await settle(tester);
      expect(find.byType(UserProfilePage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('grup bilgisi üye satırından profil açılır, kendi satırı açmaz', (tester) async {
      final be = FakeBackend()
        ..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null})
        ..on('/users/2', _profile);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
        ChatInfoPage(
          session: makeSession(be),
          conversation: const {'id': 5, 'type': 'GROUP', 'title': 'Proje Grubu', 'memberCount': 2},
          members: const [
            {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
            {'userId': 2, 'displayName': 'Mehmet Kaya'},
          ],
          subtitle: '2 üye',
        ),
        size: kPhoneMedium,
      ));
      await settle(tester);
      await tester.tap(find.text('Ayşe Yılmaz (Sen)'));
      await settle(tester);
      expect(find.byType(UserProfilePage), findsNothing);
      await tester.tap(find.text('Mehmet Kaya'));
      await settle(tester);
      expect(find.byType(UserProfilePage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('birebir sohbet bilgisinde "Profil" hızlı eylemi', (tester) async {
      final be = FakeBackend()
        ..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null})
        ..on('/users/2', _profile);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
        ChatInfoPage(
          session: makeSession(be),
          conversation: const {
            'id': 5,
            'type': 'DIRECT',
            'peer': {'id': 2, 'displayName': 'Mehmet Kaya'},
          },
          members: const [],
          subtitle: '',
        ),
        size: kPhoneMedium,
      ));
      await settle(tester);
      await tester.tap(find.text('Profili görüntüle'));
      await settle(tester);
      expect(find.byType(UserProfilePage), findsOneWidget);
      await unmount(tester);
    });
  });
}
