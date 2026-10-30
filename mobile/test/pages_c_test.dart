import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/profile/blocked_users_page.dart';
import 'package:bu_kampus/features/profile/edit_profile_page.dart';
import 'package:bu_kampus/features/profile/legal_pages.dart';
import 'package:bu_kampus/features/profile/my_clubs_page.dart';
import 'package:bu_kampus/features/profile/my_events_page.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/profile/saved_news_page.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/features/search/search_page.dart';
import 'package:bu_kampus/features/support/support_feedback_page.dart';
import 'package:bu_kampus/features/support/support_new_ticket_page.dart';
import 'package:bu_kampus/features/support/support_page.dart';
import 'package:bu_kampus/features/support/support_suggestions_page.dart';
import 'package:bu_kampus/features/support/support_ticket_page.dart';
import 'package:bu_kampus/widgets/report_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

typedef Seed = void Function(FakeBackend b);

/// Bir sayfa senaryosu: tam veri, boş veri, hata anahtarları ve işaretçi metinler.
class PageCase {
  PageCase(
    this.name,
    this.build, {
    required this.full,
    required this.marker,
    this.empty,
    this.emptyMarker,
    this.failKeys = const [],
    this.act,
    this.checkLoading = true,
  });

  final String name;
  final Widget Function(FakeBackend b, ThemeController tc) build;
  final Seed full;
  final Seed? empty;
  final String marker;
  final String? emptyMarker;
  final List<String> failKeys;

  /// Sayfa açıldıktan sonra yapılacak etkileşim (örn. arama kutusuna yazmak).
  final Future<void> Function(WidgetTester tester)? act;
  final bool checkLoading;
}

String _today() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _page(List<Object> items) => {'items': items, 'nextCursor': null};

final kPageCases = <PageCase>[
  PageCase(
    'ProfileTab',
    (b, tc) => ProfileTab(session: makeSession(b), themeController: tc),
    full: (b) => b
      ..on('/users/me', {
        'id': 1,
        'email': 'ayse.cok.uzun.bir.eposta.adresi@ogr.bingol.edu.tr',
        'displayName': 'Ayşe Yılmaz Çok Uzun Bir Soyadı Olan Öğrenci',
        'faculty': 'Mühendislik-Mimarlık Fakültesi',
        'department': 'Bilgisayar Mühendisliği',
        'classYear': 3,
        'bio': 'Merhaba, ben bir öğrenciyim. ' * 6,
      })
      ..on('/me/summary', {'communities': 2, 'events': 3, 'bookmarks': 4}),
    marker: 'Ayşe Yılmaz',
    failKeys: ['/users/me'],
    checkLoading: false, // iskelet kart (UI-N1)
  ),
  PageCase(
    'MyClubsPage',
    (b, tc) => MyClubsPage(session: makeSession(b)),
    full: (b) => b.on('/me/communities', _page([
      {'id': 1, 'name': 'Yazılım Kulübü', 'category': 'Teknoloji', 'memberCount': 12, 'myStatus': 'ACTIVE'},
      {'id': 2, 'name': 'Çok Uzun İsimli Bir Topluluk ' * 3, 'category': 'Sanat', 'memberCount': 3, 'myStatus': 'PENDING'},
    ])),
    empty: (b) => b.on('/me/communities', _page([])),
    marker: 'Yazılım Kulübü',
    emptyMarker: 'Henüz bir kulübün yok',
    failKeys: ['/me/communities'],
    checkLoading: false, // iskelet (K7)
  ),
  PageCase(
    'MyEventsPage',
    (b, tc) => MyEventsPage(session: makeSession(b)),
    full: (b) => b.on('/me/events', _page([
      {
        'id': 1,
        'title': 'Kariyer Günleri ve Çok Uzun Bir Etkinlik Başlığı ' * 2,
        'startsAt': '2098-12-01T10:00:00',
        'location': 'Konferans Salonu',
        'myRsvp': 'GOING',
      },
      {'id': 2, 'title': 'Yaklaşan Etkinlik', 'startsAt': '2099-01-01T10:00:00', 'location': ''},
    ])),
    empty: (b) => b.on('/me/events', _page([])),
    marker: 'Yaklaşan Etkinlik',
    emptyMarker: 'Henüz etkinliğin yok',
    failKeys: ['/me/events'],
    checkLoading: false, // iskelet kartlar gosterilir
  ),
  PageCase(
    'SavedNewsPage',
    (b, tc) => SavedNewsPage(session: makeSession(b)),
    full: (b) => b.on('/bookmarks', _page([
      {'news': newsItem(1, title: 'Kayıtlı haber bir')},
      {'news': newsItem(2, type: 'DUYURU', title: 'Kayıtlı duyuru iki')},
    ])),
    empty: (b) => b.on('/bookmarks', _page([])),
    marker: 'Kayıtlı haber bir',
    emptyMarker: 'Henüz kaydettiğiniz bir haber yok.',
    failKeys: ['/bookmarks'],
    checkLoading: false, // iskelet (K3)
  ),
  PageCase(
    'SettingsPage',
    (b, tc) => SettingsPage(session: makeSession(b), themeController: tc),
    full: (b) => b
      ..on('/users/me', {'id': 1, 'language': 'tr', 'showEmail': true})
      ..on('/notifications/preferences',
          {'news': true, 'announcements': true, 'events': false, 'communities': true, 'messages': true}),
    // Bildirim anahtarları artık "Bildirim tercihleri" sayfasında (NotificationPrefsPage senaryosu); ayarlar sayfası
    // profil okunamazsa hata ekranı değil varsayılanlarla açılır (aşağıdaki "yükleme hatası" testi).
    marker: 'E-postamı diğerlerine göster',
    checkLoading: false,
  ),
  PageCase(
    'NotificationPrefsPage',
    (b, tc) => NotificationPrefsPage(session: makeSession(b)),
    full: (b) => b.on('/notifications/preferences',
        {'news': true, 'announcements': false, 'events': false, 'communities': true, 'messages': true}),
    marker: 'Duyurular',
    failKeys: ['/notifications/preferences'],
    checkLoading: false, // iskelet (K10)
  ),
  PageCase(
    'BlockedUsersPage',
    (b, tc) => BlockedUsersPage(session: makeSession(b)),
    full: (b) => b.on('/users/me/blocks', [
      {'id': 5, 'displayName': 'Engellenen Kişi'},
      {'id': 6, 'displayName': 'Çok Uzun İsimli Engellenmiş Kullanıcı Adı Soyadı'},
    ]),
    empty: (b) => b.on('/users/me/blocks', <Object>[]),
    marker: 'Engellenen Kişi',
    emptyMarker: 'Kimseyi engellemedin',
    failKeys: ['/users/me/blocks'],
  ),
  PageCase(
    'LegalListPage',
    (b, tc) => LegalListPage(session: makeSession(b)),
    full: (b) => b.on('/legal', [
      {'type': 'TERMS', 'title': 'Kullanım Koşulları', 'version': 2, 'publishedAt': '2026-01-01T00:00:00'},
      {'type': 'KVKK', 'title': 'KVKK Aydınlatma Metni ve Kişisel Verilerin Korunması', 'version': 1},
    ]),
    empty: (b) => b.on('/legal', <Object>[]),
    marker: 'Kullanım Koşulları',
    emptyMarker: 'Yayımlanmış sözleşme yok.',
    failKeys: ['/legal'],
  ),
  PageCase(
    'LegalDocPage',
    (b, tc) => LegalDocPage(session: makeSession(b), type: 'TERMS'),
    full: (b) => b.on('/legal/TERMS', {
      'type': 'TERMS',
      'title': 'Kullanım Koşulları',
      'version': 2,
      'publishedAt': '2026-01-01T00:00:00',
      'content': 'Madde 1. ' * 200,
    }),
    marker: 'Sürüm 2',
    failKeys: ['/legal/TERMS'],
  ),
  PageCase(
    'NotificationsPage',
    (b, tc) => NotificationsPage(session: makeSession(b)),
    full: (b) => b.on('/notifications', {
      'unreadCount': 1,
      'nextCursor': null,
      'items': [
        {
          'id': 1,
          'type': 'NEWS',
          'title': 'Yeni haber yayımlandı ve çok uzun bir bildirim başlığı',
          'body': 'Ayrıntılar için dokunun. ' * 8,
          'read': false,
          'createdAt': DateTime.now().toIso8601String(),
          'data': '{"newsId": 3}',
        },
        {'id': 2, 'type': 'MESSAGE', 'title': 'Okunmuş bildirim', 'read': true, 'createdAt': '2020-01-01T10:00:00'},
      ],
    }),
    empty: (b) => b.on('/notifications', _page([])),
    marker: 'Okunmuş bildirim',
    emptyMarker: 'Henüz bildiriminiz yok',
    failKeys: ['/notifications'],
    checkLoading: false, // iskelet (K3)
  ),
  PageCase(
    'SearchPage',
    (b, tc) => SearchPage(session: makeSession(b)),
    full: (b) => b
      ..on('/search', {
        'groups': [
          {
            'type': 'NEWS',
            'items': [
              {'type': 'NEWS', 'targetId': 1, 'title': 'Sonuç haberi', 'snippet': 'özet ' * 30, 'date': '2026-10-01'},
              {'type': 'COMMUNITY', 'targetId': 2, 'title': 'Sonuç kulübü'},
              {'type': 'EVENT', 'targetId': 3, 'title': 'Sonuç etkinliği'},
            ],
          },
        ],
      })
      ..on('/users/search', _page([
        {'id': 9, 'displayName': 'Sonuç Kişisi', 'faculty': 'Fen-Edebiyat Fakültesi', 'classYear': 2},
      ])),
    empty: (b) => b
      ..on('/search', {'groups': <Object>[]})
      ..on('/users/search', _page([])),
    marker: 'Sonuç haberi',
    emptyMarker: 'Sonuç bulunamadı.',
    failKeys: ['/search'],
    checkLoading: false,
    act: (tester) async {
      await tester.enterText(find.byType(TextField).first, 'sonuc');
      await tester.pump(const Duration(milliseconds: 400));
    },
  ),
  PageCase(
    'SupportPage',
    (b, tc) => SupportPage(session: makeSession(b)),
    full: (b) => b
      ..on('/faq', [
        {
          'category': 'Hesap',
          'items': [
            {'question': 'Şifremi nasıl değiştiririm?', 'answer': 'Ayarlar sayfasından.'},
          ],
        },
        {
          'category': 'Genel',
          'items': [
            {'question': 'Uygulama ücretsiz mi?', 'answer': 'Evet.'},
          ],
        },
      ])
      ..on('/support/tickets', _page([
        {'id': 5, 'subject': 'Giriş yapamıyorum, çok uzun bir konu başlığı ' * 2, 'status': 'OPEN', 'createdAt': '2026-10-01T10:00:00'},
      ])),
    empty: (b) => b
      ..on('/faq', <Object>[])
      ..on('/support/tickets', _page([])),
    marker: 'Şifremi nasıl değiştiririm?',
    emptyMarker: 'Henüz destek talebiniz yok.',
    failKeys: ['/faq', '/support/tickets'],
    checkLoading: false, // iskelet (P13)
  ),
  PageCase(
    'FeedbackPage',
    (b, tc) => FeedbackPage(session: makeSession(b)),
    full: (b) => b.on('/feedback/mine', _page([
      {
        'id': 1,
        'subject': 'Hata bildirimi',
        'message': 'Uygulama çöküyor. ' * 10,
        'category': 'BUG',
        'status': 'NEW',
        'createdAt': '2026-10-01T10:00:00',
        'adminResponse': 'Teşekkürler, inceleniyor.',
      },
    ])),
    empty: (b) => b.on('/feedback/mine', _page([])),
    marker: 'Hata bildirimi',
    emptyMarker: 'Henüz geri bildirim göndermediniz.',
    failKeys: ['/feedback/mine'],
    checkLoading: false,
    // Sayfa "Gönder" sekmesiyle açılır; liste "Gönderdiklerim" sekmesindedir.
    act: (tester) async {
      await tester.tap(find.text('Gönderdiklerim'));
      await tester.pump();
    },
  ),
  PageCase(
    'SuggestionsPage',
    (b, tc) => SuggestionsPage(session: makeSession(b)),
    full: (b) => b.on('/suggestions', {
      'totalPages': 1,
      'items': [
        {
          'id': 1,
          'subject': 'Karanlık tema geliştirilsin ve başlık biraz uzun olsun',
          'message': 'Detay ' * 30,
          'status': 'PLANNED',
          'voteCount': 7,
          'votedByMe': false,
          'adminResponse': 'Planlandı.',
        },
      ],
    }),
    empty: (b) => b.on('/suggestions', {'totalPages': 0, 'items': <Object>[]}),
    marker: 'Karanlık tema geliştirilsin ve başlık biraz uzun olsun',
    emptyMarker: 'Henüz yayımlanmış öneri yok. İlk öneriyi siz ekleyin.',
    failKeys: ['/suggestions'],
    checkLoading: false, // iskelet (P13)
  ),
  PageCase(
    'SupportTicketPage',
    (b, tc) => SupportTicketPage(session: makeSession(b), ticketId: 5),
    full: (b) => b.on('/support/tickets/5', {
      'ticket': {
        'id': 5,
        'subject': 'Giriş sorunu',
        'status': 'OPEN',
        'category': 'ACCOUNT',
        'createdAt': '2026-10-01T10:00:00',
      },
      'messages': [
        {'id': 1, 'text': 'Giriş yapamıyorum. ' * 10, 'fromStaff': false, 'createdAt': '2026-10-01T10:00:00'},
        {'id': 2, 'text': 'Yardımcı olalım.', 'fromStaff': true, 'createdAt': '2026-10-01T11:00:00'},
      ],
    }),
    marker: 'Yardımcı olalım.',
    failKeys: ['/support/tickets/5'],
    checkLoading: false, // iskelet (P13)
  ),
  PageCase(
    'NewTicketPage',
    (b, tc) => NewTicketPage(session: makeSession(b)),
    full: (b) {},
    marker: 'Gönder',
    checkLoading: false,
  ),
  PageCase(
    'MenuPage',
    (b, tc) => MenuPage(session: makeSession(b)),
    full: (b) => b.on('/menu', [
      for (var d = 1; d <= DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day; d++)
        {
          'date': '${_today().substring(0, 8)}${d.toString().padLeft(2, '0')}',
          'items': ['Mercimek çorbası', 'Tavuk sote ve çok uzun bir yemek adı bu', 'Pilav', 'Ayran'],
        },
    ]),
    empty: (b) => b.on('/menu', <Object>[]),
    marker: 'Mercimek çorbası',
    emptyMarker: 'Yemek listesi yok.',
    failKeys: ['/menu'],
    checkLoading: false, // iskelet (K3)
  ),
];

final _retryFinder = find.text('Yeniden dene');

Future<void> _open(WidgetTester tester, PageCase c, FakeBackend b,
    {Brightness br = Brightness.light, Size size = kPhoneMedium, ThemeController? tc}) async {
  useScreen(tester, size);
  _traceErrors();
  await tester.pumpWidget(buildApp(c.build(b, tc ?? ThemeController()), brightness: br, size: size));
  if (c.act != null) await c.act!(tester);
}

void main() {
  // Ahem yazı tipi sahte taşma üretir; gerçek Roboto yüklenir.
  setUpAll(loadTestFonts);

  for (final c in kPageCases) {
    group(c.name, () {
      testWidgets('yükleniyor -> dolu veri', (tester) async {
        final b = FakeBackend(delay: const Duration(milliseconds: 300));
        c.full(b);
        await _open(tester, c, b);
        if (c.checkLoading) {
          await tester.pump(const Duration(milliseconds: 50));
          expect(find.byType(CircularProgressIndicator), findsWidgets);
        }
        await settle(tester, const Duration(seconds: 2));
        expect(find.textContaining(c.marker), findsWidgets);
        noErr(tester);
        await unmount(tester);
        noErr(tester);
      });

      if (c.empty != null) {
        testWidgets('boş durum', (tester) async {
          final b = FakeBackend();
          c.empty!(b);
          await _open(tester, c, b);
          await settle(tester, const Duration(seconds: 2));
          expect(find.text(c.emptyMarker!), findsOneWidget);
          noErr(tester);
          await unmount(tester);
        });
      }

      if (c.failKeys.isNotEmpty) {
        for (final mode in ['500', 'ağ']) {
          testWidgets('hata ($mode) + yeniden dene', (tester) async {
            final b = FakeBackend();
            c.full(b);
            for (final k in c.failKeys) {
              mode == '500' ? b.fail(k) : b.network(k);
            }
            await _open(tester, c, b);
            await settle(tester, const Duration(seconds: 2));
            noErr(tester);
            // Çökmeyen ama hatayı gizleyen sayfa da kabul edilmez: dolu veri görünmemeli.
            expect(find.textContaining(c.marker), findsNothing, reason: 'hata durumunda veri gösterilmemeli');
            final retry = _retryFinder.evaluate().isNotEmpty ? _retryFinder : find.textContaining('Yeniden denemek için');
            expect(retry, findsWidgets, reason: 'yeniden dene eylemi bulunamadı');
            c.full(b); // sunucu düzeldi
            await tester.ensureVisible(retry.first); // sabit alt çubuğun arkasında kalmasın
            await tester.pump();
            await tester.tap(retry.first);
            await settle(tester, const Duration(seconds: 2));
            expect(find.textContaining(c.marker), findsWidgets);
            noErr(tester);
            await unmount(tester);
          });
        }
      }

      for (final br in Brightness.values) {
        for (final size in kPhoneSizes) {
          testWidgets('${br.name} ${size.width.toInt()}x${size.height.toInt()} taşma yok', (tester) async {
            final b = FakeBackend();
            c.full(b);
            await _open(tester, c, b, br: br, size: size);
            await settle(tester, const Duration(seconds: 2));
            expect(find.textContaining(c.marker), findsWidgets);
            noErr(tester);
            await unmount(tester);
            noErr(tester);
          });
        }
      }
    });
  }

  group('SettingsPage yükleme hatası', () {
    for (final mode in ['500', 'ağ']) {
      testWidgets('profil okunamazsa ($mode) sayfa çökmeden varsayılanlarla açılır', (tester) async {
        final b = FakeBackend();
        mode == '500' ? b.fail('/users/me') : b.network('/users/me');
        mode == '500' ? b.fail('/notifications/preferences') : b.network('/notifications/preferences');
        useScreen(tester, kPhoneMedium);
        await tester.pumpWidget(buildApp(SettingsPage(session: makeSession(b), themeController: ThemeController())));
        await settle(tester, const Duration(seconds: 2));
        expect(find.text('Ayarlar'), findsWidgets);
        expect(find.text('E-postamı diğerlerine göster'), findsWidgets);
        noErr(tester);
        await unmount(tester);
      });
    }
  });

  group('SettingsPage etkileşim', () {
    FakeBackend backend() => FakeBackend()
      ..on('/users/me', {'id': 1, 'language': 'tr', 'showEmail': false})
      ..on('/notifications/preferences',
          {'news': true, 'announcements': true, 'events': true, 'communities': true, 'messages': true});

    Future<void> openDelete(WidgetTester tester, FakeBackend b) async {
      b.on('/users/me/privacy', {});
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(
          buildApp(SettingsPage(session: makeSession(b), themeController: ThemeController())));
      await settle(tester);
      // Ana ayar listesinde görünmez; Gizlilik ve veriler sayfasının en altındadır.
      expect(find.text('Hesabımı sil'), findsNothing);
      await tester.scrollUntilVisible(find.text('Gizlilik ve veriler'), 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Gizlilik ve veriler'));
      await tester.pump(); // kaydırma çerçevesi uygulansın (liste uzadıkça öğe ekran dışında kalıyordu)
      await tester.tap(find.text('Gizlilik ve veriler'));
      await settle(tester, const Duration(milliseconds: 500));
      // Gizlilik > Verilerim ve hesap > Hesabımı sil > onay kutusu > Devam et > şifre alt sayfası.
      await tester.scrollUntilVisible(find.text('Verilerim ve hesap'), 200, scrollable: find.byType(Scrollable).last);
      await tester.pump();
      await tester.tap(find.text('Verilerim ve hesap'));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.scrollUntilVisible(find.text('Hesabımı sil'), 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Hesabımı sil'));
      await tester.pump();
      await tester.tap(find.text('Hesabımı sil'));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('delete-ack')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('delete-continue')));
      await settle(tester, const Duration(milliseconds: 600));
    }

    testWidgets('hesap silme: yanlış şifrede sunucu mesajı gösterilir', (tester) async {
      final b = backend();
      await openDelete(tester, b);
      b.fail('/users/me', status: 403, code: 'WRONG_PASSWORD', message: 'Şifre yanlış (sunucu).');
      await tester.enterText(find.byType(TextField), 'yanlis');
      await tester.tap(find.byKey(const ValueKey('delete-submit')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Şifre yanlış (sunucu).'), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-password')), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('hesap silme: sunucu mesajı boşsa yerel metin', (tester) async {
      final b = backend();
      await openDelete(tester, b);
      b.fail('/users/me', status: 403, code: 'WRONG_PASSWORD');
      await tester.enterText(find.byType(TextField), 'yanlis');
      await tester.tap(find.byKey(const ValueKey('delete-submit')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Şifre hatalı.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hesap silme: boş şifre doğrulanır, istek atılmaz', (tester) async {
      final b = backend();
      await openDelete(tester, b);
      await tester.tap(find.byKey(const ValueKey('delete-submit')));
      await tester.pump();
      expect(find.text('Şifrenizi girin.'), findsOneWidget);
      expect(b.requests.where((r) => r.startsWith('DELETE')), isEmpty);
      await unmount(tester);
    });
  });

  group('ReportSheet', () {
    Future<void> openSheet(WidgetTester tester, FakeBackend b) async {
      useScreen(tester, kPhoneSmall);
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => ReportSheet.show(context, s, targetType: 'USER', targetId: 7),
              child: const Text('aç'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('aç'));
      await settle(tester, const Duration(milliseconds: 600));
    }

    testWidgets('gönderim başarılı: kapanır ve teşekkür görünür', (tester) async {
      final b = FakeBackend();
      await openSheet(tester, b);
      expect(find.text('Şikâyet et'), findsOneWidget);
      await tester.tap(find.text('Taciz veya zorbalık'));
      await tester.pump();
      await tester.tap(find.text('Gönder'));
      await settle(tester, const Duration(milliseconds: 800));
      expect((b.bodies['POST /reports'] as Map)['reason'], 'HARASSMENT');
      expect(find.text('Şikâyetiniz alındı. Teşekkürler.'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('sunucu hatasında sayfa açık kalır ve hata gösterilir', (tester) async {
      final b = FakeBackend()..fail('/reports');
      await openSheet(tester, b);
      await tester.tap(find.text('Taciz veya zorbalık')); // onsecim yok: once neden secilir
      await tester.pump();
      await tester.tap(find.text('Gönder'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Bir sorun oluştu. Lütfen tekrar deneyin.'), findsOneWidget);
      expect(find.text('Gönder'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    for (final br in Brightness.values) {
      testWidgets('${br.name} 320x640 taşma yok', (tester) async {
        useScreen(tester, kPhoneSmall);
        final s = makeSession(FakeBackend());
        await tester.pumpWidget(buildApp(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => ReportSheet.showForMessage(context, s, messageId: 3), child: const Text('aç')),
            ),
          ),
          brightness: br,
          size: kPhoneSmall,
        ));
        await tester.tap(find.text('aç'));
        await settle(tester, const Duration(milliseconds: 600));
        noErr(tester);
        await unmount(tester);
      });
    }
  });

  group('Diğer etkileşimler', () {
    testWidgets('bildirimler: tümünü okundu yap sunucuya gider', (tester) async {
      final b = FakeBackend();
      kPageCases.firstWhere((c) => c.name == 'NotificationsPage').full(b);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(b))));
      await settle(tester);
      await tester.tap(find.text('Tümünü okundu yap'));
      await settle(tester);
      expect((b.bodies['POST /notifications/read'] as Map)['all'], true);
      expect(find.text('Tümünü okundu yap'), findsNothing);
      await unmount(tester);
    });

    testWidgets('arama: kısa sorguda istek yok, debounce zamanlayıcısı dispose edilir', (tester) async {
      final b = FakeBackend();
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(b))));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'a');
      await tester.pump(const Duration(seconds: 1));
      expect(b.count('/search'), 0);
      // Zamanlayıcı bekleyen halde sayfa kaldırılır; "Timer still pending" hatası olmamalı.
      await tester.enterText(find.byType(TextField).first, 'ab');
      await tester.pump(const Duration(milliseconds: 100));
      await unmount(tester);
      noErr(tester);
    });

    testWidgets('öneriler: oy verme uyarlanır, hatada geri alınır', (tester) async {
      final b = FakeBackend();
      kPageCases.firstWhere((c) => c.name == 'SuggestionsPage').full(b);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(SuggestionsPage(session: makeSession(b))));
      await settle(tester);
      expect(find.text('7'), findsOneWidget);
      b.fail('/suggestions/1/vote');
      await tester.tap(find.text('7'));
      await settle(tester);
      expect(find.text('7'), findsOneWidget, reason: 'hatada oy geri alınmalı');
      noErr(tester);
      await unmount(tester);
    });

    for (final br in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('EditProfilePage ${br.name} ${size.width.toInt()} taşma yok', (tester) async {
          final b = FakeBackend()..on('/faculties', ['Mühendislik-Mimarlık Fakültesi', 'Fen-Edebiyat Fakültesi']);
          useScreen(tester, size);
          await tester.pumpWidget(buildApp(
            EditProfilePage(session: makeSession(b), profile: {
              'displayName': 'Ayşe Yılmaz Çok Uzun Bir Soyadı Olan Öğrenci',
              'faculty': 'Mühendislik-Mimarlık Fakültesi',
              'department': 'Bilgisayar Mühendisliği',
              'classYear': 3,
              'bio': 'Biyografi ' * 20,
              'showEmail': true,
              'language': 'tr',
            }),
            brightness: br,
            size: size,
          ));
          await settle(tester);
          expect(find.text('Profili düzenle'), findsWidgets);
          noErr(tester);
          await unmount(tester);
        });
      }
    }

    testWidgets('EditProfilePage: kaydetme hatası gösterilir ve sayfa açık kalır', (tester) async {
      final b = FakeBackend()
        ..on('/faculties', ['Fen-Edebiyat Fakültesi'])
        ..fail('/users/me');
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(EditProfilePage(
          session: makeSession(b), profile: const {'displayName': 'Ayşe', 'department': 'Bilgisayar Mühendisliği', 'faculty': 'Mühendislik Fakültesi', 'language': 'tr'})));
      await settle(tester);
      await tester.tap(find.text('Kaydet').last);
      await settle(tester);
      expect(find.text('Bir sorun oluştu. Lütfen tekrar deneyin.'), findsWidgets);
      expect(find.byType(EditProfilePage), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });
  });
}

/// Yakalanan çerçeve hatasını (taşma vb.) ayrıntısıyla yazdırıp testi başarısız kılar.
void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e == null) return;
  // ignore: avoid_print
  print('HATA>> ${e is FlutterError ? e.toStringDeep() : e}');
  fail('çerçeve hatası: ${e.runtimeType}');
}

/// Çerçeve hatalarının ayrıntısını (hangi widget taştı) test çıktısına yazar.
void _traceErrors() {
  final prev = FlutterError.onError;
  FlutterError.onError = (d) {
    final txt = d.toString().replaceAll(RegExp(r'\s+'), ' ');
    final m = RegExp(r'creator: [^<]{0,200}|Row:file[^ ]*|Column:file[^ ]*|Text:file[^ ]*').allMatches(txt);
    // ignore: avoid_print
    print('TRACE>> ${d.exceptionAsString()} ${m.map((x) => x.group(0)).join(' | ')}');
    prev?.call(d);
  };
}
