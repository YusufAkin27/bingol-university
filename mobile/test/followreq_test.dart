import 'package:bu_kampus/core/push/push_banner.dart';
import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:bu_kampus/features/follow/follow_button.dart';
import 'package:bu_kampus/features/follow/follow_list_page.dart';
import 'package:bu_kampus/features/follow/follow_requests_entry.dart';
import 'package:bu_kampus/features/follow/follow_requests_page.dart';
import 'package:bu_kampus/features/follow/follow_suggestions.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/posts/social_models.dart';
import 'package:bu_kampus/features/profile/privacy_data_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'redesign/p00_support.dart';
import 'support/fake_app.dart';
import 'package:bu_kampus/core/icons/bu_icons.dart';

/// FOLLOWREQ-MB: gizli hesap, üç durumlu takip düğmesi, kilitli profil, takip istekleri ekranı, girişler, push yönlendirme.

const _btn = ValueKey('followButton');

/// `/users/9/follow`: POST sunucu durumu [postState]; DELETE her zaman NONE.
FakeBackend _followBe({String postState = 'FOLLOWING'}) {
  final b = FakeBackend();
  b.handlers.add((req, path) {
    if (path != '/users/9/follow') return null;
    if (req.method == 'POST') {
      return FakeResult.json({'following': postState == 'FOLLOWING', 'followerCount': 5, 'followState': postState});
    }
    return const FakeResult.json({'following': false, 'followerCount': 4, 'followState': 'NONE'});
  });
  return b;
}

Future<List<String>> _mountButton(
  WidgetTester tester,
  FakeBackend b, {
  FollowState state = FollowState.none,
  bool isPrivate = false,
  FollowLook look = FollowLook.row,
}) async {
  final log = <String>[];
  useScreen(tester, kPhoneMedium);
  await tester.pumpWidget(buildApp(
    Scaffold(
      body: Center(
        child: SizedBox(
          width: 200,
          child: FollowStateButton(
            session: makeSession(b),
            userId: 9,
            state: state,
            isPrivate: isPrivate,
            look: look,
            compact: false,
            onState: (s, r) => log.add('${s.name}${r == null ? '' : '*'}'),
          ),
        ),
      ),
    ),
    size: kPhoneMedium,
  ));
  await settle(tester, const Duration(milliseconds: 300));
  return log;
}

void main() {
  setUpAll(loadTestFonts);

  group('modeller', () {
    test('followState çözülür; alan yoksa followedByMe devreye girer', () {
      expect(followStateOf('REQUESTED'), FollowState.requested);
      expect(followStateOf('following'), FollowState.following);
      expect(followStateOf('SELF'), FollowState.self);
      expect(followStateOf(null), FollowState.none);
      expect(followStateOf(null, fallbackFollowing: true), FollowState.following);
      final legacy = SocialUser.fromJson({'id': 3, 'displayName': 'A', 'followedByMe': true});
      expect(legacy.followState, FollowState.following);
      expect(legacy.hasFollowState, isFalse);
      final fresh = SocialUser.fromJson({'id': 4, 'displayName': 'B', 'followState': 'REQUESTED', 'isPrivate': true, 'locked': true});
      expect(fresh.followState, FollowState.requested);
      expect(fresh.followedByMe, isFalse);
      expect(fresh.isPrivate, isTrue);
      expect(fresh.locked, isTrue);
      expect(fresh.hasFollowState, isTrue);
    });

    test('FollowStats ve FollowResult followState taşır', () {
      final s = FollowStats.fromJson({'followerCount': 3, 'followingCount': 1, 'followState': 'REQUESTED', 'isPrivate': true, 'locked': true});
      expect(s.followState, FollowState.requested);
      expect(s.followedByMe, isFalse);
      expect(s.locked, isTrue);
      expect(FollowStats.fromJson({'followedByMe': true}).followState, FollowState.following);
      expect(FollowResult.fromJson({'following': false, 'followState': 'REQUESTED'}).followState, FollowState.requested);
      expect(FollowResult.fromJson({'following': true}).followState, isNull);
    });
  });

  group('üç durumlu takip düğmesi', () {
    testWidgets('açık hesap: Takip et -> Takiptesin, onay sheeti yok', (tester) async {
      final b = _followBe();
      final log = await _mountButton(tester, b);
      expect(find.text('Takip et'), findsOneWidget);
      await tester.tap(find.byKey(_btn));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('POST /users/9/follow'), 1);
      expect(find.text('Takip ediliyor'), findsOneWidget); // satır görünümü
      expect(find.text('Takibi bırak?'), findsNothing);
      expect(log, ['following', 'following*']);
      await unmount(tester);
    });

    testWidgets('gizli hesap: Takip et -> İstek gönderildi (iyimser, sunucu REQUESTED)', (tester) async {
      final b = _followBe(postState: 'REQUESTED');
      final log = await _mountButton(tester, b, isPrivate: true);
      await tester.tap(find.byKey(_btn));
      await tester.pump(); // iyimser: yanıt gelmeden istek durumu
      expect(find.text('İstek gönderildi'), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('İstek gönderildi'), findsOneWidget);
      expect(log, ['requested', 'requested*']);
      await unmount(tester);
    });

    testWidgets('sunucu açık sanılan hesabı gizli bulursa İstek gönderildi gösterir', (tester) async {
      final b = _followBe(postState: 'REQUESTED');
      final log = await _mountButton(tester, b); // isPrivate: false (eski veri)
      await tester.tap(find.byKey(_btn));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('İstek gönderildi'), findsOneWidget);
      expect(log.last, 'requested*');
      await unmount(tester);
    });

    testWidgets('İstek gönderildi: dokununca geri çekme sheeti; vazgeç DELETE atmaz, onay atar', (tester) async {
      final b = _followBe();
      await _mountButton(tester, b, state: FollowState.requested, isPrivate: true);
      expect(find.text('İstek gönderildi'), findsOneWidget);
      await tester.tap(find.byKey(_btn));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('İsteği geri çek?'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('DELETE /users/9/follow'), 0);
      expect(find.text('İstek gönderildi'), findsOneWidget);
      await tester.tap(find.byKey(_btn));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('İsteği geri çek'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('DELETE /users/9/follow'), 1);
      expect(find.text('Takip et'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Takiptesin (açık): sheet düz metin; onayla DELETE', (tester) async {
      final b = _followBe();
      await _mountButton(tester, b, state: FollowState.following);
      await tester.tap(find.byKey(_btn));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Takibi bırak?'), findsOneWidget);
      expect(find.text('Bu kişiyi artık takip etmeyeceksin.'), findsOneWidget);
      expect(find.textContaining('yeniden istek'), findsNothing);
      expect(b.count('DELETE'), 0);
      await tester.tap(find.text('Takibi bırak'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('DELETE /users/9/follow'), 1);
      expect(find.text('Takip et'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Takiptesin (GİZLİ): sheet yeniden istek uyarısı verir', (tester) async {
      final b = _followBe();
      await _mountButton(tester, b, state: FollowState.following, isPrivate: true);
      await tester.tap(find.byKey(_btn));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.textContaining('Takibi bırakırsan yeniden istek göndermen gerekir'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hata: önceki duruma döner', (tester) async {
      final b = FakeBackend()..fail('/users/9/follow', status: 500, code: 'SERVER_ERROR', message: 'Hata oldu');
      final log = await _mountButton(tester, b, isPrivate: true);
      await tester.tap(find.byKey(_btn));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Takip et'), findsOneWidget);
      expect(find.text('İstek gönderildi'), findsNothing);
      expect(log, ['requested', 'none']);
      await unmount(tester);
    });

    testWidgets('self: düğme çizilmez', (tester) async {
      final b = _followBe();
      await _mountButton(tester, b, state: FollowState.self);
      expect(find.byKey(_btn), findsNothing);
      await unmount(tester);
    });

    for (final look in FollowLook.values) {
      testWidgets('görünüm ${look.name}: üç durum etiketi', (tester) async {
        final b = _followBe();
        await _mountButton(tester, b, state: FollowState.requested, look: look);
        expect(find.text('İstek gönderildi'), findsOneWidget);
        await unmount(tester);
        await _mountButton(tester, b, state: FollowState.following, look: look);
        expect(find.text(look == FollowLook.row || look == FollowLook.media ? 'Takip ediliyor' : 'Takiptesin'), findsOneWidget);
        await unmount(tester);
        await _mountButton(tester, b, look: look);
        expect(find.text(look == FollowLook.chip ? 'Takip Et' : 'Takip et'), findsOneWidget);
        await unmount(tester);
      });
    }
  });

  group('takip listeleri / öneriler', () {
    FakeBackend listBe() => FakeBackend()
      ..on('/users/7/followers*', {
        'items': [
          {'id': 11, 'displayName': 'Emre Yılmaz', 'followState': 'FOLLOWING', 'isPrivate': false},
          {'id': 12, 'displayName': 'Selin Kaya', 'followState': 'REQUESTED', 'isPrivate': true},
          {'id': 13, 'displayName': 'Burak Çelik', 'followState': 'NONE', 'isPrivate': true},
          {'id': 1, 'displayName': 'Ben', 'followState': 'SELF'},
        ],
        'nextCursor': null,
        'total': 4,
      })
      ..on('/users/7/following*', {'items': <Object>[], 'nextCursor': null, 'total': 0})
      ..on('/users/me/follow-suggestions*', {
        'items': [
          {'id': 21, 'displayName': 'Deniz Aksoy', 'followState': 'REQUESTED', 'isPrivate': true},
        ],
      });

    testWidgets('takipçi satırları durumu gösterir; kendi satırında düğme yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = listBe();
      b.handlers.add((req, path) => path == '/users/13/follow'
          ? const FakeResult.json({'following': false, 'followerCount': 2, 'followState': 'REQUESTED'})
          : null);
      await tester.pumpWidget(buildApp(FollowListPage(session: makeSession(b), userId: 7, followers: true, name: 'Ayşe'), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Takip ediliyor'), findsOneWidget); // satır düğmesi (altındaki ilişki satırı "Takiptesin" der)
      expect(find.text('Takiptesin'), findsOneWidget);
      expect(find.text('İstek gönderildi'), findsOneWidget);
      expect(find.text('Takip et'), findsOneWidget);
      expect(find.byKey(_btn), findsNWidgets(3)); // Ben (SELF) için yok
      // Gizli hesapta Takip et -> İstek gönderildi (iyimser)
      await tester.tap(find.text('Takip et'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('İstek gönderildi'), findsNWidgets(2));
      expect(b.count('POST /users/13/follow'), 1);
      await unmount(tester);
    });

    testWidgets('gizli hesabın listesi locked:true ise kilit kartı gösterilir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/users/7/followers*', {'items': <Object>[], 'nextCursor': null, 'locked': true})
        ..on('/users/7/following*', {'items': <Object>[], 'nextCursor': null, 'locked': true});
      await tester.pumpWidget(buildApp(FollowListPage(session: makeSession(b), userId: 7, followers: true, name: 'Ayşe'), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('follow-list-locked')), findsOneWidget);
      expect(find.text('Bu hesap gizli'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('öneriler: gizli hesap İstek gönderildi gösterir', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(FollowSuggestionsPage(session: makeSession(listBe())), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Deniz Aksoy'), findsOneWidget);
      expect(find.text('İstek gönderildi'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('kilitli (gizli) profil', () {
    const base = {
      'id': 2,
      'displayName': 'Mert Kaya',
      'department': 'Bilgisayar Mühendisliği',
      'bio': 'Merhaba',
      'followerCount': 12,
      'followingCount': 7,
      'followsMe': false,
    };

    FakeBackend profileBe(Map<String, dynamic> over) {
      final b = FakeBackend()..on('/users/2', {...base, ...over});
      b.handlers.add((req, path) {
        if (path != '/users/2/follow') return null;
        return req.method == 'POST'
            ? const FakeResult.json({'following': false, 'followerCount': 12, 'followState': 'REQUESTED'})
            : const FakeResult.json({'following': false, 'followerCount': 12, 'followState': 'NONE'});
      });
      return b;
    }

    testWidgets('locked + ESKİ sunucu (sayılar null): kilit bloğu, sayılar –, listeler tıklanmaz, gönderi isteği yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      // Eski sunucu kilitli profilde sayaçları null yollar; yeni sunucu sayıları açar (aşağıdaki test).
      final b = profileBe({'isPrivate': true, 'locked': true, 'followState': 'NONE', 'followerCount': null, 'followingCount': null});
      await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(b), userId: 2), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 900));
      expect(b.count('GET /users/2'), 2); // profil + presence (/users/2/presence); ikinci sayaç isteği yok
      expect(find.text('Mert Kaya'), findsOneWidget);
      expect(find.text('Bu hesap gizli'), findsOneWidget);
      expect(find.text('Gönderilerini görmek için takip isteği gönder.'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('locked-profile-block')), matching: find.byIcon(BuIcons.lock)), findsOneWidget);
      expect(find.text('–'), findsNWidgets(3)); // gönderi, takipçi, takip sayıları gizli
      expect(find.byKey(const ValueKey('followerCount')), findsNothing);
      expect(find.text('Merhaba'), findsOneWidget); // bio görünür
      await tester.tap(find.text('Takipçi'));
      await tester.tap(find.text('Takip'), warnIfMissed: false);
      await settle(tester, const Duration(milliseconds: 300));
      expect(b.requests.any((r) => r.contains('/followers')), isFalse);
      expect(b.requests.any((r) => r.contains('/posts')), isFalse);
      expect(find.byKey(const ValueKey('profile-message')), findsOneWidget); // Mesaj gönder mevcut kurallarla
      await unmount(tester);
    });

    testWidgets('locked + sayılar açık: takipçi/takip/gönderi sayısı görünür, ızgara kapalı, liste dürüstçe gizli', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = profileBe({'isPrivate': true, 'locked': true, 'followState': 'NONE', 'postCount': 5});
      b.on('/users/2/followers*', {'items': <Object>[], 'nextCursor': null, 'locked': true});
      await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(b), userId: 2), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.text('12'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('–'), findsNothing);
      expect(find.byKey(const ValueKey('locked-profile-block')), findsOneWidget);
      expect(b.requests.any((r) => r.contains('/posts')), isFalse, reason: 'gönderi içeriği istenmez');
      await tester.tap(find.byKey(const ValueKey('followerCount')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('follow-list-locked')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('istek gönder: İstek gönderildi + kilit metni onay bekler; geri çekince tekrar Takip et', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = profileBe({'isPrivate': true, 'locked': true, 'followState': 'NONE'});
      await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(b), userId: 2), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 900));
      await tester.tap(find.byKey(_btn));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('POST /users/2/follow'), 1);
      expect(find.text('İstek gönderildi'), findsOneWidget);
      expect(find.text('İsteğin onaylanınca gönderileri görebilirsin.'), findsOneWidget);
      expect(find.text('Bu hesap gizli'), findsOneWidget);
      // sayılar gizli hesapta da görünür (12 takipçi, 7 takip); gönderi sayısı sunucu vermedi -> –
      expect(find.text('12'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('–'), findsOneWidget);
      await tester.tap(find.byKey(_btn));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('İsteği geri çek'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('DELETE /users/2/follow'), 1);
      expect(find.text('Takip et'), findsOneWidget);
      expect(find.text('Gönderilerini görmek için takip isteği gönder.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('gizli ama takipçi (locked:false): sayılar ve gönderi ızgarası açık; Takibi bırak uyarısı', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = profileBe({'isPrivate': true, 'locked': false, 'followState': 'FOLLOWING'});
      await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(b), userId: 2), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.text('Bu hesap gizli'), findsNothing);
      expect(tester.widget<Text>(find.byKey(const ValueKey('followerCount'))).data, '12');
      expect(b.requests.any((r) => r.contains('/users/2/posts')), isTrue);
      expect(find.text('Takiptesin'), findsOneWidget);
      await tester.tap(find.byKey(_btn));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.textContaining('yeniden istek göndermen gerekir'), findsOneWidget);
      await tester.tap(find.text('Takibi bırak'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('DELETE /users/2/follow'), 1);
      // gizli hesabı bırakınca profil yeniden kilitlenir
      expect(find.text('Bu hesap gizli'), findsOneWidget);
      expect(find.text('Takip et'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('açık hesap: kilit yok, Takip et doğrudan Takiptesin olur', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/users/2', {...base, 'isPrivate': false, 'locked': false, 'followState': 'NONE'})
        ..on('/users/2/follow', {'following': true, 'followerCount': 13, 'followState': 'FOLLOWING'});
      await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(b), userId: 2), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.text('Bu hesap gizli'), findsNothing);
      await tester.tap(find.byKey(_btn));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Takiptesin'), findsOneWidget);
      expect(find.text('İstek gönderildi'), findsNothing);
      expect(tester.widget<Text>(find.byKey(const ValueKey('followerCount'))).data, '13');
      await unmount(tester);
    });
  });

  group('takip istekleri ekranı', () {
    Map<String, dynamic> row(int id, String name, {String? dept}) => {
          'userId': id,
          'displayName': name,
          'avatarUrl': null,
          'department': dept,
          'requestedAt': DateTime.now().subtract(const Duration(minutes: 5)).toUtc().toIso8601String(),
        };

    FakeBackend reqBe({int n = 2}) {
      final b = FakeBackend()
        ..on('/users/me/follow-requests*', {
          'items': [for (var i = 0; i < n; i++) row(30 + i, i == 0 ? 'Selin Kaya' : 'Burak Çelik', dept: 'Hukuk')],
          'nextCursor': null,
          'total': n,
        });
      return b;
    }

    testWidgets('liste: başlık, sayı, satırlar; Onayla POST accept ve satırı kaldırır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = reqBe();
      await tester.pumpWidget(buildApp(FollowRequestsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Takip istekleri'), findsNothing); // sayfa başlığı görünmez (sadeleştirme)
      expect(find.text('BEKLEYEN İSTEKLER (2)'), findsOneWidget);
      expect(find.text('Selin Kaya'), findsOneWidget);
      expect(find.textContaining('Hukuk'), findsNWidgets(2));
      expect(find.text('Onayla'), findsNWidgets(2));
      expect(find.text('Sil'), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('follow-request-accept-30')));
      await settle(tester, const Duration(seconds: 1));
      expect(b.count('POST /users/me/follow-requests/30/accept'), 1);
      expect(find.text('Selin Kaya'), findsNothing);
      expect(find.text('Burak Çelik'), findsOneWidget);
      expect(find.text('BEKLEYEN İSTEKLER (1)'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Sil: POST decline; son satır gidince boş durum', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = reqBe(n: 1);
      await tester.pumpWidget(buildApp(FollowRequestsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('follow-request-decline-30')));
      await settle(tester, const Duration(seconds: 1));
      expect(b.count('POST /users/me/follow-requests/30/decline'), 1);
      expect(find.text('Selin Kaya'), findsNothing);
      expect(find.text('Bekleyen takip isteği yok.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kabul hatasında satır geri gelir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = reqBe(n: 1)..fail('/users/me/follow-requests/30/accept', status: 500, code: 'SERVER_ERROR', message: 'Olmadı');
      await tester.pumpWidget(buildApp(FollowRequestsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('follow-request-accept-30')));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Selin Kaya'), findsOneWidget);
      expect(find.text('Bekleyen takip isteği yok.'), findsNothing);
      await unmount(tester);
    });

    testWidgets('boş: tek cümle; hata: yeniden dene; çevrimdışı hata gösterir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..on('/users/me/follow-requests*', {'items': <Object>[], 'nextCursor': null, 'total': 0});
      await tester.pumpWidget(buildApp(FollowRequestsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('follow-requests-empty')), findsOneWidget);
      expect(find.text('Bekleyen takip isteği yok.'), findsOneWidget);
      await unmount(tester);

      final off = reqBe()..offline = true;
      await tester.pumpWidget(buildApp(FollowRequestsPage(session: makeSession(off)), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Yeniden dene'), findsOneWidget);
      expect(find.text('Selin Kaya'), findsNothing);
      off.offline = false;
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Selin Kaya'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yükleniyor: iskelet, sonra içerik', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = reqBe()..delay = const Duration(milliseconds: 400);
      await tester.pumpWidget(buildApp(FollowRequestsPage(session: makeSession(b)), size: kPhoneMedium));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Selin Kaya'), findsNothing);
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Selin Kaya'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sayfalama: ikinci sayfa imleçle gelir', (tester) async {
      useScreen(tester, const Size(390, 500));
      final b = FakeBackend();
      b.handlers.add((req, path) {
        if (path != '/users/me/follow-requests') return null;
        final cursor = req.url.queryParameters['cursor'];
        if (cursor == null) {
          return FakeResult.json({'items': [for (var i = 0; i < 12; i++) row(100 + i, 'Kişi $i')], 'nextCursor': 'c2', 'total': 14});
        }
        return FakeResult.json({'items': [row(200, 'Son Kişi'), row(201, 'Son Kişi 2')], 'nextCursor': null, 'total': 14});
      });
      await tester.pumpWidget(buildApp(FollowRequestsPage(session: makeSession(b)), size: const Size(390, 500)));
      await settle(tester, const Duration(seconds: 1));
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await settle(tester, const Duration(seconds: 1));
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await settle(tester, const Duration(seconds: 1));
      expect(b.requests.any((r) => r.contains('cursor=c2')), isTrue);
      expect(find.text('Son Kişi 2'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('giriş noktaları', () {
    testWidgets('Bildirimler: n>0 iken "Takip istekleri (n)" satırı, dokununca ekran; n=0 iken yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/users/me/follow-requests/count', {'count': 3})
        ..on('/users/me/follow-requests*', {
          'items': [
            {'userId': 30, 'displayName': 'Selin Kaya', 'requestedAt': DateTime.now().toUtc().toIso8601String()}
          ],
          'nextCursor': null,
          'total': 1,
        });
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(b), socialOnly: true), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Takip istekleri (3)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('follow-requests-entry')));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Selin Kaya'), findsOneWidget);
      expect(find.text('BEKLEYEN İSTEKLER (1)'), findsOneWidget);
      await unmount(tester);

      final z = FakeBackend()..on('/users/me/follow-requests/count', {'count': 0});
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(z), socialOnly: true), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('follow-requests-entry')), findsNothing);
      await unmount(tester);
    });

    testWidgets('Bildirim satırı: FOLLOW_REQUEST / FOLLOW_ACCEPTED tür etiketi "Takip"', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/notifications', {
          'items': [
            {
              'id': 1,
              'type': 'FOLLOW_REQUEST',
              'title': 'Yeni takip isteği',
              'body': 'Selin seni takip etmek istiyor',
              'read': false,
              'createdAt': DateTime.now().toUtc().toIso8601String(),
              'data': {'targetType': 'FOLLOW_REQUESTS'},
            },
            {
              'id': 2,
              'type': 'FOLLOW_ACCEPTED',
              'title': 'İstek kabul edildi',
              'body': 'Burak isteğini kabul etti',
              'read': true,
              'createdAt': DateTime.now().toUtc().toIso8601String(),
              'data': {'targetType': 'USER', 'targetId': 31},
            },
          ],
          'nextCursor': null,
          'unreadCount': 1,
        });
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(b), socialOnly: true), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      // Tür etiketi satırda çizilmez (tasarım 08); ekran okuyucu etiketinde kalır.
      expect(find.text('İstek kabul edildi'), findsOneWidget);
      expect(find.text('Yeni takip isteği'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Profil menüsü: n>0 iken İçeriğim kutusunda sayı metinli satır (Profilim sayfasında yok); n=0 iken yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      FakeBackend be(int n) => FakeBackend()
        ..on('/me/summary', {'communities': 1, 'events': 2, 'bookmarks': 3})
        ..on('/users/me', {'id': 1, 'displayName': 'Ayşe Yılmaz', 'department': 'Bilgisayar Mühendisliği'})
        ..on('/users/1', {'id': 1, 'followerCount': 5, 'followingCount': 2})
        ..on('/users/me/follow-requests/count', {'count': n})
        ..on('/users/me/follow-requests*', {'items': <Object>[], 'nextCursor': null, 'total': 0});
      await tester.pumpWidget(buildApp(ProfileTab(session: makeSession(be(4)), themeController: ThemeController()), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('profile-follow-requests')), findsNothing); // Profilim'in altında satır yok
      await tester.tap(find.byKey(const ValueKey('profile-menu-button')));
      await settle(tester, const Duration(seconds: 1));
      final rowFinder = find.byKey(const ValueKey('profile-follow-requests'));
      expect(rowFinder, findsOneWidget);
      expect(find.descendant(of: rowFinder, matching: find.text('Takip istekleri')), findsOneWidget);
      expect(find.descendant(of: rowFinder, matching: find.text('4')), findsOneWidget);
      await unmount(tester);
      await tester.pumpWidget(buildApp(ProfileTab(session: makeSession(be(0)), themeController: ThemeController()), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('profile-menu-button')));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Kayıtlı haberler'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-follow-requests')), findsNothing);
      await unmount(tester);
    });

    test('push yönlendirme: FOLLOW_REQUESTS -> istekler ekranı, USER -> profil', () {
      expect(resolvePushTarget({'targetType': 'FOLLOW_REQUESTS'}).dest, PushDest.followRequests);
      expect(resolvePushTarget({'targetType': 'follow_requests', 'targetId': '5'}).dest, PushDest.followRequests);
      expect(resolvePushTarget({'targetType': 'FOLLOW_REQUESTS'}).id, isNull);
      // Sunucunun bildirim verisi (`target`/`value`/`userId`): istek sahibinin kimliği hedefi profile çevirmez.
      expect(resolvePushTarget({'target': 'FOLLOW_REQUESTS', 'value': '7', 'userId': '7'}).dest, PushDest.followRequests);
      expect(resolvePushTarget({'target': 'USER', 'value': '9', 'userId': '9'}), const PushTarget(PushDest.user, id: 9));
      final t = resolvePushTarget({'targetType': 'USER', 'targetId': '31'});
      expect(t.dest, PushDest.user);
      expect(t.id, 31);
      // bozuk yük hâlâ Bildirimler'e düşer
      expect(resolvePushTarget({'targetType': 'FOLLOW_REQUESTS_X'}).dest, PushDest.notifications);
      expect(bannerIcon({'targetType': 'FOLLOW_REQUESTS'}), BuIcons.userPlus);
      expect(bannerIcon({'targetType': 'USER', 'targetId': 3}), BuIcons.user);
    });
  });

  group('Gizli hesap anahtarı (Gizlilik ve veriler)', () {
    FakeBackend privBe({bool priv = false}) => FakeBackend()
      ..on('/users/me/privacy', {'avatar': 'EVERYONE', 'privateAccount': priv})
      ..on('/users/me', {'id': 1, 'displayName': 'Ayşe', 'showEmail': false});

    Future<void> mount(WidgetTester tester, FakeBackend b) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(PrivacyDataPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
    }

    testWidgets('açıklama metni; açarken onay yok, PATCH privateAccount:true', (tester) async {
      final b = privBe();
      await mount(tester, b);
      expect(find.text('Gizli hesap'), findsOneWidget);
      expect(
          find.text('Gizli hesapta yalnız onayladığın kişiler gönderilerini ve takipçi listeni görür. Mevcut takipçilerin kalır.'),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('privacy-private-switch')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.bodies['PATCH /users/me/privacy'], {'privateAccount': true});
      expect(find.text('Hesap herkese açılsın mı?'), findsNothing);
      expect(tester.widget<Switch>(find.descendant(of: find.byKey(const ValueKey('privacy-private-switch')), matching: find.byType(Switch))).value, isTrue);
      await unmount(tester);
    });

    testWidgets('kapatırken bilgi sheeti: vazgeç değiştirmez, onay PATCH false', (tester) async {
      final b = privBe(priv: true);
      await mount(tester, b);
      Switch sw() => tester.widget<Switch>(find.descendant(of: find.byKey(const ValueKey('privacy-private-switch')), matching: find.byType(Switch)));
      expect(sw().value, isTrue);
      await tester.tap(find.byKey(const ValueKey('privacy-private-switch')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Hesap herkese açılsın mı?'), findsOneWidget);
      expect(find.textContaining('Bekleyen takip istekleri otomatik kabul edilir'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.bodies.containsKey('PATCH /users/me/privacy'), isFalse);
      expect(sw().value, isTrue);
      await tester.tap(find.byKey(const ValueKey('privacy-private-switch')));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('Herkese aç'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.bodies['PATCH /users/me/privacy'], {'privateAccount': false});
      expect(sw().value, isFalse);
      await unmount(tester);
    });

    testWidgets('kayıt hatasında eski değere döner ve Tekrar dene sunulur', (tester) async {
      final b = privBe();
      await mount(tester, b);
      b.fail('/users/me/privacy', status: 500);
      await tester.tap(find.byKey(const ValueKey('privacy-private-switch')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Değişiklik kaydedilemedi.'), findsOneWidget);
      expect(tester.widget<Switch>(find.descendant(of: find.byKey(const ValueKey('privacy-private-switch')), matching: find.byType(Switch))).value, isFalse);
      await unmount(tester);
    });
  });

  group('Matris (tr/en/ar x açık/koyu x 1.0/1.3 x 320/390): taşma yok', () {
    FakeBackend allBe() {
      final b = FakeBackend()
        ..on('/users/me/follow-requests/count', {'count': 2})
        ..on('/users/me/follow-requests*', {
          'items': [
            {
              'userId': 30,
              'displayName': 'Selin Kaya Çok Uzun Bir Soyadı Olan Öğrenci',
              'department': 'Bilgisayar Mühendisliği',
              'requestedAt': DateTime.now().subtract(const Duration(hours: 3)).toUtc().toIso8601String(),
            },
            {'userId': 31, 'displayName': 'Burak', 'requestedAt': DateTime.now().toUtc().toIso8601String()},
          ],
          'nextCursor': null,
          'total': 2,
        })
        ..on('/users/2', {
          'id': 2,
          'displayName': 'Mert Kaya',
          'department': 'Bilgisayar Mühendisliği',
          'followerCount': 0,
          'followingCount': 0,
          'isPrivate': true,
          'locked': true,
          'followState': 'REQUESTED',
        })
        ..on('/users/7/followers*', {
          'items': [
            {'id': 12, 'displayName': 'Selin Kaya Çok Uzun Bir Soyadı Olan Öğrenci', 'followState': 'REQUESTED', 'isPrivate': true},
            {'id': 13, 'displayName': 'Burak Çelik', 'followState': 'FOLLOWING', 'department': 'Hukuk'},
          ],
          'nextCursor': null,
          'total': 2,
        })
        ..on('/users/7/following*', {'items': <Object>[], 'nextCursor': null, 'total': 0})
        ..on('/users/me/privacy', {'avatar': 'EVERYONE', 'privateAccount': true})
        ..on('/users/me', {'id': 1, 'displayName': 'Ayşe', 'showEmail': false});
      return b;
    }

    final screens = <String, Widget Function()>{
      'FollowRequestsPage': () => FollowRequestsPage(session: makeSession(allBe())),
      'UserProfilePage (kilitli, istek gönderildi)': () => UserProfilePage(session: makeSession(allBe()), userId: 2),
      'FollowListPage (REQUESTED satırı)': () => FollowListPage(session: makeSession(allBe()), userId: 7, followers: true, name: 'Ayşe'),
      'PrivacyDataPage': () => PrivacyDataPage(session: makeSession(allBe())),
      'NotificationsPage + giriş': () => NotificationsPage(session: makeSession(allBe())),
      'FollowRequestsEntry': () => FollowRequestsEntry(session: makeSession(allBe())),
    };
    for (final e in screens.entries) {
      testWidgets(e.key, (tester) async {
        await p00Matrix(tester, e.value, scaffold: false, settleMs: 800);
      });
    }
  });
}
