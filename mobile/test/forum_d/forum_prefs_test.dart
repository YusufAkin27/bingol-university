import 'package:bu_kampus/features/forum/presentation/pages/forum_prefs_page.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart' show PrefSwitch;
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_forum.dart';
import '../support/fake_forum_extras.dart';
import '../support/forum_d_harness.dart';

void main() {
  late FakeBackend b;
  late FakeForum f;
  late FakeForumExtras x;

  setUp(() {
    b = FakeBackend();
    f = fakeForum(b, count: 3);
    x = fakeForumExtras(f);
  });

  Future<void> open(WidgetTester tester, {Brightness brightness = Brightness.light, double scale = 1, Size size = const Size(390, 1200)}) async {
    useScreen(tester, size);
    await tester.pumpWidget(forumDApp(ForumPrefsPage(session: makeSession(b)), brightness: brightness, textScale: scale));
    await settle(tester, const Duration(milliseconds: 500));
  }

  bool on(WidgetTester tester, String key) =>
      tester.widget<PrefSwitch>(find.descendant(of: find.byKey(ValueKey('forum-pref-$key')), matching: find.byType(PrefSwitch))).value;

  bool enabled(WidgetTester tester, String key) =>
      tester.widget<PrefSwitch>(find.descendant(of: find.byKey(ValueKey('forum-pref-$key')), matching: find.byType(PrefSwitch))).onChanged != null;

  testWidgets('sunucudaki durumu gosterir; moderasyon bildirimi icin kapatilamaz notu var', (tester) async {
    x.prefs = {'all': true, 'topicComments': true, 'commentReplies': false, 'likes': true, 'followedTopics': false};
    await open(tester);
    expect(on(tester, 'all'), isTrue);
    expect(on(tester, 'commentReplies'), isFalse);
    expect(on(tester, 'followedTopics'), isFalse);
    expect(find.byKey(const ValueKey('forum-pref-moderation-note')), findsOneWidget);
    expect(find.textContaining('kapatılamaz'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('alt anahtar: iyimser degisir ve PUT gider; moderasyon alani gonderilmez', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('forum-pref-likes')));
    await tester.pump();
    expect(on(tester, 'likes'), isFalse, reason: 'sunucu yanıtından önce iyimser');
    await settle(tester, const Duration(milliseconds: 300));
    expect(x.prefsPuts.last['likes'], isFalse);
    expect(x.prefsPuts.last.containsKey('moderation'), isFalse);
    expect(x.prefs['likes'], isFalse);
  });

  testWidgets('ana anahtar kapaliyken alt anahtarlar pasif ve kapali gorunur; acinca eski secimler korunur', (tester) async {
    x.prefs = {'all': true, 'topicComments': true, 'commentReplies': false, 'likes': true, 'followedTopics': true};
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('forum-pref-all')));
    await settle(tester, const Duration(milliseconds: 300));
    expect(x.prefsPuts.last['all'], isFalse);
    for (final k in ['topicComments', 'commentReplies', 'likes', 'followedTopics']) {
      expect(enabled(tester, k), isFalse, reason: '$k pasif olmalı');
      expect(on(tester, k), isFalse, reason: '$k kapalı görünmeli');
    }
    final puts = x.prefsPuts.length;
    await tester.tap(find.byKey(const ValueKey('forum-pref-likes')));
    await settle(tester, const Duration(milliseconds: 300));
    expect(x.prefsPuts.length, puts, reason: 'pasif satır istek atmaz');

    await tester.tap(find.byKey(const ValueKey('forum-pref-all')));
    await settle(tester, const Duration(milliseconds: 300));
    expect(on(tester, 'likes'), isTrue);
    expect(on(tester, 'commentReplies'), isFalse, reason: 'önceki kapalı seçim korunur');
  });

  testWidgets('kaydetme hatasinda anahtar geri doner ve hata gosterilir', (tester) async {
    await open(tester);
    x.failPrefsPut = true;
    await tester.tap(find.byKey(const ValueKey('forum-pref-topicComments')));
    await settle(tester, const Duration(milliseconds: 400));
    expect(b.requests, contains('PUT /forum/notification-prefs'), reason: 'kaydetme denendi');
    expect(on(tester, 'topicComments'), isTrue, reason: 'hata: önceki duruma dönmeli');
    expect(x.prefsPuts, isEmpty);
    expect(find.byIcon(BuIcons.circleAlert), findsOneWidget);
  });

  testWidgets('hizli ardisik dokunuslar sirayla gider; son durum sunucuyla ayni', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('forum-pref-topicComments')));
    await tester.tap(find.byKey(const ValueKey('forum-pref-likes')));
    await tester.tap(find.byKey(const ValueKey('forum-pref-followedTopics')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(x.prefsPuts.length, 3);
    expect(x.prefs['topicComments'], isFalse);
    expect(x.prefs['likes'], isFalse);
    expect(x.prefs['followedTopics'], isFalse);
    expect(on(tester, 'topicComments'), isFalse);
    expect(on(tester, 'likes'), isFalse);
    expect(on(tester, 'followedTopics'), isFalse);
  });

  testWidgets('yukleme hatasi: hata ekrani + yeniden dene', (tester) async {
    x.failPrefsGet = true;
    await open(tester);
    expect(find.byType(BuErrorState), findsOneWidget);
    x.failPrefsGet = false;
    await tester.tap(find.text('Yeniden dene'));
    await settle(tester, const Duration(milliseconds: 400));
    expect(find.byType(BuErrorState), findsNothing);
    expect(find.byKey(const ValueKey('forum-pref-all')), findsOneWidget);
  });

  group('sessize alinanlar', () {
    testWidgets('bos metin; liste; sessizden cikar', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('forum-muted-empty')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      x.mutes.addAll([
        {'userId': 31, 'displayName': 'Selin Aksoy', 'avatarUrl': null},
        {'userId': 32, 'displayName': 'Burak Demir', 'avatarUrl': null},
      ]);
      await open(tester);
      expect(find.text('Selin Aksoy'), findsOneWidget);
      expect(find.text('Burak Demir'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('forum-unmute-31')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests, contains('DELETE /forum/mutes/31'));
      expect(find.text('Selin Aksoy'), findsNothing);
      expect(find.text('Burak Demir'), findsOneWidget);
      expect(find.text('Sessizden çıkarıldı'), findsOneWidget);
    });

    testWidgets('liste yuklenemezse tercihler yine calisir, tekrar dene satiri cikar', (tester) async {
      x.failMutesGet = true;
      await open(tester);
      expect(find.byKey(const ValueKey('forum-pref-all')), findsOneWidget);
      expect(find.byKey(const ValueKey('forum-muted-empty')), findsNothing);
      x.failMutesGet = false;
      x.mutes.add({'userId': 31, 'displayName': 'Selin Aksoy', 'avatarUrl': null});
      await tester.ensureVisible(find.text('Yeniden dene'));
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Selin Aksoy'), findsOneWidget);
    });
  });

  testWidgets('koyu tema + buyuk yazi + dar ekran: tasma yok', (tester) async {
    x.mutes.add({'userId': 31, 'displayName': 'Çok uzun bir kullanıcı adı ${'soyad ' * 6}', 'avatarUrl': null});
    await open(tester, brightness: Brightness.dark, scale: 2.0, size: kPhoneSmall);
    expectNoException(tester);
  });
}
