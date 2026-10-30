import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/follow/follow_list_page.dart';
import 'package:bu_kampus/features/profile/blocked_users_page.dart';
import 'package:bu_kampus/features/profile/my_clubs_page.dart';
import 'package:bu_kampus/features/profile/my_events_page.dart';
import 'package:bu_kampus/features/support/support_feedback_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _long = 'Bingöl Üniversitesi Mühendislik Fakültesi Bilgisayar Mühendisliği Öğrenci Topluluğu Büyük Buluşma';

Future<void> _pump(WidgetTester tester, Widget w,
    {Brightness b = Brightness.light, Size size = kPhoneMedium, String? lang}) async {
  useScreen(tester, size);
  await tester.pumpWidget(const SizedBox()); // önceki sayfanın durumu taşınmasın
  if (lang == null) {
    await tester.pumpWidget(buildApp(w, brightness: b, size: size));
  } else {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: b == Brightness.dark ? BuTheme.dark() : BuTheme.light(),
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: w,
    ));
  }
  await settle(tester, const Duration(milliseconds: 800));
}

FakeBackend _blocks() => FakeBackend()
  ..on('/users/me/blocks', [
    {'id': 5, 'displayName': _long, 'department': 'Bilgisayar Mühendisliği'},
    {'id': 6, 'displayName': 'Selin Kaya'},
  ]);

FakeBackend _clubs() => FakeBackend()
  ..on('/me/communities*', {
    'items': [
      {'id': 1, 'name': 'Fotoğrafçılık Kulübü', 'memberCount': 128, 'myStatus': 'ACTIVE', 'myRole': 'OWNER'},
      {'id': 2, 'name': 'Yazılım Topluluğu', 'memberCount': 214, 'myStatus': 'ACTIVE', 'myRole': 'ADMIN'},
      {'id': 3, 'name': 'Tiyatro Kulübü', 'memberCount': 76, 'myStatus': 'ACTIVE', 'myRole': 'MEMBER'},
      {'id': 4, 'name': _long, 'category': 'Sanat', 'myStatus': 'PENDING'},
    ],
    'nextCursor': null,
  });

FakeBackend _events({bool pending = false}) => FakeBackend()
  ..on('/me/events?mode=attending*', {
    'items': [
      {'id': 1, 'title': 'Kariyer Günleri ' * 4, 'startsAt': '2098-11-14T14:00:00', 'location': 'Konferans Salonu', 'myRsvp': 'GOING'},
      {'id': 2, 'title': 'Atölye', 'startsAt': '2098-11-21T19:30:00', 'location': 'Sanat Atölyesi', 'myRsvp': 'REQUESTED'},
      {'id': 3, 'title': 'Toplantı', 'startsAt': '2098-11-28T16:00:00', 'myRsvp': 'INTERESTED'},
    ],
    'nextCursor': null,
  })
  ..on('/me/events?mode=past*', {'items': [], 'nextCursor': null})
  ..on('/me/events?mode=organizing*', {
    'items': [
      {'id': 9, 'title': 'Kodlama Maratonu', 'startsAt': '2098-12-05T10:00:00', 'location': 'Bilgisayar Lab.', if (pending) 'pendingRequestCount': 3},
    ],
    'nextCursor': null,
  });

FakeBackend _follow({required bool followsMe}) => FakeBackend()
  ..on('/users/7/followers*', {
    'items': [
      {'id': 11, 'displayName': 'Emre Yılmaz', 'department': 'Bilgisayar Mühendisliği', 'followedByMe': true, if (followsMe) 'followsMe': true},
      {'id': 12, 'displayName': 'Selin Kaya', 'department': 'İktisat', 'followedByMe': false, if (followsMe) 'followsMe': true},
      {'id': 13, 'displayName': 'Burak Çelik', 'followedByMe': false, if (followsMe) 'followsMe': false},
    ],
    'nextCursor': null,
    'total': 128,
  })
  ..on('/users/7/following*', {'items': [], 'nextCursor': null, 'total': 94})
  ..on('/feedback/mine*', {'items': [], 'nextCursor': null});

void main() {
  setUpAll(loadTestFonts);

  final pages = <String, Widget Function()>{
    'Engellenenler': () => BlockedUsersPage(session: makeSession(_blocks())),
    'Kuluplerim': () => MyClubsPage(session: makeSession(_clubs())),
    'Etkinliklerim': () => MyEventsPage(session: makeSession(_events(pending: true))),
    'TakipListesi': () => FollowListPage(session: makeSession(_follow(followsMe: true)), userId: 7, followers: true, name: 'Ayşe Demir'),
    'GeriBildirim': () => FeedbackPage(session: makeSession(_follow(followsMe: true))),
  };

  for (final e in pages.entries) {
    for (final br in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('${e.key} ${br.name} ${size.width.toInt()} taşma yok', (tester) async {
          await _pump(tester, e.value(), b: br, size: size);
          expect(tester.takeException(), isNull);
        });
      }
    }
    testWidgets('${e.key} ar RTL 320 taşma yok', (tester) async {
      await _pump(tester, e.value(), size: kPhoneSmall, lang: 'ar');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Engellenenler: not, ad, bolum, engeli kaldir semantigi, bos durum', (tester) async {
    final sem = tester.ensureSemantics();
    await _pump(tester, BlockedUsersPage(session: makeSession(_blocks())));
    expect(find.textContaining('Engellediğin kişiler'), findsOneWidget);
    expect(find.text('Bilgisayar Mühendisliği'), findsOneWidget);
    expect(find.text('Engeli kaldır'), findsNWidgets(2));
    expect(find.bySemanticsLabel(RegExp('Selin Kaya engelini kaldır')), findsOneWidget);
    final empty = FakeBackend()..on('/users/me/blocks', <Object>[]);
    await _pump(tester, BlockedUsersPage(session: makeSession(empty)));
    expect(find.text('Kimseyi engellemedin'), findsOneWidget);
    sem.dispose();
  });

  testWidgets('Kuluplerim: bolumler, rol ve onay rozetleri', (tester) async {
    await _pump(tester, MyClubsPage(session: makeSession(_clubs())));
    expect(find.text('Başkan'), findsOneWidget);
    expect(find.text('Yönetici'), findsOneWidget);
    expect(find.text('Üye'), findsOneWidget);
    expect(find.text('Onay bekliyor'), findsOneWidget);
  });

  testWidgets('Kuluplerim bos: kulupleri kesfet dugmesi', (tester) async {
    final b = FakeBackend()..on('/me/communities*', {'items': [], 'nextCursor': null});
    await _pump(tester, MyClubsPage(session: makeSession(b)));
    expect(find.text('Henüz bir kulübün yok'), findsOneWidget);
    expect(find.text('Kulüpleri keşfet'), findsOneWidget);
  });

  testWidgets('Etkinliklerim: durum etiketleri; bekleyen istek yalniz alan varsa', (tester) async {
    await _pump(tester, MyEventsPage(session: makeSession(_events(pending: true))));
    expect(find.text('Katılıyorum'), findsOneWidget);
    expect(find.text('İstek gönderildi'), findsOneWidget);
    expect(find.text('İlgileniyorum'), findsOneWidget);
    await tester.tap(find.text('Oluşturduklarım'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Kodlama Maratonu'), findsOneWidget);
    expect(find.text('3 bekleyen istek'), findsOneWidget);

    await _pump(tester, MyEventsPage(session: makeSession(_events())));
    await tester.tap(find.text('Oluşturduklarım'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Kodlama Maratonu'), findsOneWidget);
    expect(find.textContaining('bekleyen istek'), findsNothing);
  });

  testWidgets('Takip listesi: followsMe etiketleri alan varsa; yoksa yok; arama suzer', (tester) async {
    await _pump(tester, FollowListPage(session: makeSession(_follow(followsMe: true)), userId: 7, followers: true, name: 'Ayşe Demir'));
    expect(find.text('Takipçiler'), findsOneWidget);
    expect(find.text('128'), findsOneWidget); // sekme sayaç rozeti
    expect(find.text('Takip edilenler'), findsOneWidget);
    expect(find.text('Takipleşiyorsunuz'), findsOneWidget);
    expect(find.text('Seni takip ediyor'), findsOneWidget);
    expect(find.text('Takip et'), findsNWidgets(2));
    expect(find.text('Takipte'), findsOneWidget); // Emre: düğme "Takipte"
    await tester.enterText(find.byType(TextField), 'selin');
    await tester.pump();
    expect(find.text('Selin Kaya'), findsOneWidget);
    expect(find.text('Emre Yılmaz'), findsNothing);

    await _pump(tester, FollowListPage(session: makeSession(_follow(followsMe: false)), userId: 7, followers: true, name: 'Ayşe Demir'));
    expect(find.text('Takipleşiyorsunuz'), findsNothing);
    expect(find.text('Seni takip ediyor'), findsNothing);
  });

  testWidgets('Geri bildirim: tur cipleri, sayac, sabit Gonder', (tester) async {
    await _pump(tester, FeedbackPage(session: makeSession(_follow(followsMe: true))));
    expect(find.text('Öneri'), findsOneWidget);
    expect(find.text('Hata'), findsOneWidget);
    expect(find.text('Şikâyet'), findsOneWidget);
    expect(find.text('Teşekkür'), findsOneWidget);
    // "Gönder" hem sekme etiketi (form | gönderdiklerim) hem form düğmesi.
    expect(find.text('Gönder'), findsNWidgets(2));
    expect(find.text('Gönderdiklerim'), findsWidgets);
    await tester.enterText(find.byType(TextField).last, 'Merhaba');
    await tester.pump();
    expect(find.text('7 / 1000'), findsOneWidget);
  });
}
