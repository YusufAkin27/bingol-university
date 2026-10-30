import 'package:bu_kampus/features/news/news_detail_page.dart';
import 'package:bu_kampus/features/news/news_list_page.dart';
import 'package:bu_kampus/features/profile/saved_news_page.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:bu_kampus/features/search/search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Ic1-Ic5 tasarımları: arama, haber listesi, haber detayı, favoriler, kullanıcı profili.

Widget _wrap(Widget w, {bool rtl = false}) =>
    rtl ? Directionality(textDirection: TextDirection.rtl, child: w) : w;

void _ok(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('$e');
}

FakeBackend _newsBackend({bool maintenance = false, bool empty = false}) => FakeBackend()
  ..on('/news', newsPage(empty ? [] : [for (var i = 1; i <= 4; i++) newsItem(i, title: 'Kampüs genelinde ulaşım düzenlemesi yapıldı $i')]))
  ..on('/status', {
    'NEWS': {'maintenance': maintenance},
    'MENU': {'maintenance': false},
  })
  ..on('/bookmarks/news/ids', {'ids': []});

const _profile = {
  'id': 2,
  'displayName': 'Mert Kaya',
  'department': 'Bilgisayar Mühendisliği',
  'faculty': null,
  'classYear': null,
  'bio': null,
};

void main() {
  setUpAll(loadTestFonts);

  group('Haber listesi (Ic2)', () {
    for (final size in kPhoneSizes) {
      for (final b in Brightness.values) {
        for (final rtl in [false, true]) {
          testWidgets('${size.width.toInt()} dp ${b.name}${rtl ? ' rtl' : ''}: sekmeler, bant, kartlar', (tester) async {
            useScreen(tester, size);
            final be = _newsBackend(maintenance: true);
            await tester.pumpWidget(buildApp(_wrap(NewsListPage(session: makeSession(be)), rtl: rtl), brightness: b, size: size));
            await settle(tester);
            // Büyük başlık (SliverAppBar.large) hem açık hem daralmış başlığı çizer.
            expect(find.text('Haberler'), findsWidgets);
            expect(find.text('Haber'), findsWidgets);
            expect(find.text('Duyuru'), findsOneWidget);
            expect(find.text('Etkinlik'), findsOneWidget);
            expect(find.textContaining('Haber kaynağına şu an ulaşılamıyor'), findsOneWidget);
            expect(find.textContaining('Kampüs genelinde ulaşım'), findsWidgets);
            expect(find.byTooltip('Favori haberler'), findsOneWidget);
            _ok(tester);
            await unmount(tester);
          });
        }
      }
    }

    testWidgets('bakım yoksa bant görünmez; sekme değişince tür sorgusu gider', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = _newsBackend();
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(be)), size: kPhoneMedium));
      await settle(tester);
      expect(find.textContaining('ulaşılamıyor'), findsNothing);
      expect(be.count('/news?type=HABER'), greaterThan(0));
      await tester.tap(find.byKey(const ValueKey('news-tab-1')));
      await settle(tester);
      expect(be.count('/news?type=DUYURU'), greaterThan(0));
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('başlangıç türü: ETKINLIK sekmesi açılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = _newsBackend();
      await tester.pumpWidget(
          buildApp(NewsListPage(session: makeSession(be), initialType: 'ETKINLIK'), size: kPhoneMedium));
      await settle(tester);
      expect(be.count('/news?type=ETKINLIK'), greaterThan(0));
      expect(be.count('/news?type=HABER'), 0);
      await unmount(tester);
    });

    testWidgets('boş liste ve hata', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(_newsBackend(empty: true))), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Bu kategoride henüz içerik yok.'), findsOneWidget);
      await unmount(tester);

      final bad = _newsBackend()..fail('/news');
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(bad)), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 3));
      expect(find.text('Yeniden dene'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('karta dokununca haber detayı açılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = _newsBackend()..on('/news/1', {'id': 1, 'content': 'Gövde'});
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(be)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.textContaining('düzenlemesi yapıldı 1'));
      await settle(tester);
      expect(find.byType(NewsDetailPage), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Haber detayı (Ic3)', () {
    for (final size in kPhoneSizes) {
      for (final b in Brightness.values) {
        for (final rtl in [false, true]) {
          testWidgets('${size.width.toInt()} dp ${b.name}${rtl ? ' rtl' : ''}: kapaksız ve kapaklı', (tester) async {
            useScreen(tester, size);
            final be = FakeBackend()
              ..on('/news/1', {'id': 1, 'content': 'Yeni dönemle birlikte güncelleme yapıldı.\nDeğişiklikler hafta içi geçerlidir.', 'url': 'https://www.bingol.edu.tr/x'})
              ..on('/bookmarks/news/ids', {'ids': []});
            for (final img in [null, 'https://img.invalid/a.jpg']) {
              await tester.pumpWidget(buildApp(
                  _wrap(NewsDetailPage(session: makeSession(be), item: newsItem(1, imageUrl: img, title: 'Kampüs genelinde ulaşım düzenlemesi yapıldı')), rtl: rtl),
                  brightness: b,
                  size: size));
              await settle(tester);
              expect(find.text('Kaynak sayfada aç'), findsOneWidget);
              expect(find.byTooltip('Paylaş'), findsOneWidget);
              expect(find.byTooltip('Favorilere ekle'), findsOneWidget);
              expect(find.textContaining('hafta içi geçerlidir'), findsOneWidget);
              _ok(tester);
            }
            await unmount(tester);
          });
        }
      }
    }
  });

  group('Favoriler (Ic4)', () {
    for (final size in kPhoneSizes) {
      for (final b in Brightness.values) {
        testWidgets('${size.width.toInt()} dp ${b.name}: sayı, kartlar, ipucu kartı', (tester) async {
          useScreen(tester, size);
          final be = FakeBackend()
            ..on('/bookmarks', {
              'items': [
                for (var i = 1; i <= 3; i++) {'news': newsItem(i, title: 'Kayıtlı haber başlığı $i')}
              ],
              'nextCursor': null,
            });
          await tester.pumpWidget(buildApp(SavedNewsPage(session: makeSession(be)), brightness: b, size: size));
          await settle(tester);
          expect(find.text('Favori haberler'), findsWidgets);
          expect(find.text('3 kayıtlı haber'), findsOneWidget);
          expect(find.textContaining('Kayıtlı haber başlığı'), findsNWidgets(3));
          expect(find.text('Daha fazla haberi kaydet'), findsOneWidget);
          _ok(tester);
          await unmount(tester);
        });
      }
    }

    testWidgets('favoriden çıkarma DELETE gönderir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = FakeBackend()
        ..on('/bookmarks', {
          'items': [
            {'news': newsItem(1, title: 'Kayıtlı haber')}
          ],
          'nextCursor': null,
        })
        ..on('/bookmarks/news/1', {});
      await tester.pumpWidget(buildApp(SavedNewsPage(session: makeSession(be)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.byTooltip('Favorilerden çıkar'));
      await settle(tester);
      expect(be.count('DELETE /bookmarks/news/1'), 1);
      expect(find.text('Kayıtlı haber'), findsNothing);
      await unmount(tester);
    });
  });

  group('Arama (Ic1)', () {
    FakeBackend be() => FakeBackend()
      ..on('/search', {
        'groups': [
          {
            'type': 'NEWS',
            'items': [
              {'type': 'NEWS', 'targetId': 1, 'title': 'Kampüs genelinde ulaşım düzenlemesi', 'date': '2026-10-12'},
              {'type': 'ANNOUNCEMENT', 'targetId': 2, 'title': 'Güz dönemi kampüs etkinlik takvimi', 'date': '2026-10-09'},
              {'type': 'COMMUNITY', 'targetId': 3, 'title': 'Kampüs Fotoğraf Kulübü', 'snippet': '48 üye'},
            ],
          },
        ],
      })
      ..on('/users/search', {'items': []});

    for (final size in kPhoneSizes) {
      for (final b in Brightness.values) {
        for (final rtl in [false, true]) {
          testWidgets('${size.width.toInt()} dp ${b.name}${rtl ? ' rtl' : ''}: gruplu sonuçlar ve vurgu', (tester) async {
            useScreen(tester, size);
            await tester.pumpWidget(buildApp(_wrap(SearchPage(session: makeSession(be())), rtl: rtl), brightness: b, size: size));
            await tester.enterText(find.byType(TextField).first, 'kamp');
            await tester.pump(const Duration(milliseconds: 500));
            await settle(tester);
            expect(find.text('Tümü'), findsOneWidget);
            expect(find.text('Kişi', skipOffstage: false), findsOneWidget);
            expect(find.text('HABER'), findsOneWidget);
            expect(find.text('KULÜP'), findsOneWidget);
            expect(find.text('9 Ekim 2026'), findsOneWidget);
            _ok(tester);
            await unmount(tester);
          });
        }
      }
    }
  });

  group('Kullanıcı profili (Ic5)', () {
    for (final size in kPhoneSizes) {
      for (final b in Brightness.values) {
        for (final rtl in [false, true]) {
          testWidgets('${size.width.toInt()} dp ${b.name}${rtl ? ' rtl' : ''}: gizli alanlar, menü, ızgara', (tester) async {
            useScreen(tester, size);
            final fe = FakeBackend()
              ..on('/users/2', {..._profile, 'followerCount': 126, 'followingCount': 98, 'followedByMe': false, 'followsMe': false})
              ..on('/users/2/posts', {
                'items': [
                  for (var i = 1; i <= 3; i++)
                    {
                      'id': i,
                      'text': 'Kısa metin',
                      'media': [
                        {'id': i, 'type': 'IMAGE', 'url': 'https://img.invalid/$i.jpg', 'thumbUrl': 'https://img.invalid/t$i.jpg'}
                      ],
                    }
                ],
                'nextCursor': null,
              });
            await tester.pumpWidget(buildApp(
                _wrap(UserProfilePage(session: makeSession(fe), userId: 2, initialName: 'Mert'), rtl: rtl),
                brightness: b,
                size: size));
            await settle(tester, const Duration(milliseconds: 800));
            expect(find.text('Mert Kaya'), findsOneWidget);
            expect(find.text('Takip et'), findsOneWidget);
            expect(find.text('Mesaj gönder'), findsOneWidget);
            expect(tester.widget<Text>(find.byKey(const ValueKey('followerCount'))).data, '126');
            expect(find.text('Gizli'), findsNWidgets(2)); // fakülte + sınıf (bölüm görünür)
            expect(find.text('GÖNDERİLER'), findsOneWidget);
            await tester.tap(find.byKey(const ValueKey('profile-more')));
            await tester.pump(const Duration(milliseconds: 500));
            expect(find.text('Kullanıcıyı şikâyet et'), findsOneWidget);
            expect(find.text('Engelle'), findsOneWidget);
            _ok(tester);
            await unmount(tester);
          });
        }
      }
    }

    testWidgets('Takip et iyimser günceller, POST gönderir ve sunucu sayısını alır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final fe = FakeBackend()
        ..on('/users/2', {..._profile, 'followerCount': 5, 'followingCount': 1, 'followedByMe': false, 'followsMe': true})
        ..on('/users/2/follow', {'following': true, 'followerCount': 6});
      await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(fe), userId: 2), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('followButton')));
      await settle(tester);
      expect(fe.count('POST /users/2/follow'), 1);
      expect(fe.count('PUT '), 0);
      expect(fe.count('follow-stats'), 0);
      expect(find.text('Takipte'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('followerCount'))).data, '6');
      // Karşı taraf da beni takip ediyor: takipleşme rozeti.
      expect(find.byKey(const ValueKey('followRelationPill')), findsOneWidget);
      expect(find.text('Takipleşiyorsunuz'), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('Takipten çık: DELETE gönderilir, "Seni takip ediyor" rozeti', (tester) async {
      useScreen(tester, kPhoneMedium);
      final fe = FakeBackend()
        ..on('/users/2', {..._profile, 'followerCount': 5, 'followingCount': 1, 'followedByMe': true, 'followsMe': true})
        ..on('/users/2/follow', {'following': false, 'followerCount': 4});
      await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(fe), userId: 2), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Takipleşiyorsunuz'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('followButton')));
      await settle(tester);
      expect(fe.count('DELETE /users/2/follow'), 1);
      expect(tester.widget<Text>(find.byKey(const ValueKey('followerCount'))).data, '4');
      expect(find.text('Seni takip ediyor'), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });
  });
}
