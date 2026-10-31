import 'dart:io';

import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/clubs/club_form_page.dart';
import 'package:bu_kampus/features/clubs/club_members_page.dart';
import 'package:bu_kampus/features/clubs/club_requests_page.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/profile/my_clubs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _longName = 'Bingöl Üniversitesi Mühendislik Fakültesi Bilgisayar Mühendisliği Öğrenci Topluluğu Büyük Buluşma';

Future<void> _fonts() async {
  await loadTestFonts();
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter';
  final loader = FontLoader('Inter');
  var any = false;
  for (final f in ['regular', 'medium', 'bold']) {
    final file = File('$root/bin/cache/artifacts/material_fonts/roboto-$f.ttf');
    if (!file.existsSync()) continue;
    any = true;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  if (any) await loader.load();
}

Map<String, dynamic> _club({String status = 'ACTIVE', String? role = 'OWNER', String name = 'Robotik Kulübü'}) => {
      'id': 7,
      'name': name,
      'description': 'Robot yarışmaları.',
      'category': 'Teknoloji',
      'memberCount': 42,
      'visibility': 'PUBLIC',
      'joinPolicy': 'OPEN',
      'myStatus': status,
      'myRole': role,
    };

FakeBackend _detailBackend({String status = 'ACTIVE', String? role = 'OWNER'}) => FakeBackend()
  ..on('/communities/7', _club(status: status, role: role))
  ..on('/communities/7/posts*', {'items': [], 'nextCursor': null})
  ..on('/communities/7/requests*', {
    'items': [
      {'userId': 20, 'displayName': 'Ali Veli', 'answers': []}
    ],
    'nextCursor': null,
  })
  ..on('/events*', {'items': [], 'nextCursor': null});

/// Sayfayı bir düğmeden iterek açar (Navigator.pop çalışsın diye).
Widget _launcher(Widget Function(BuildContext) page) => Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page(c))),
            child: const Text('AÇ'),
          ),
        ),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget w, {Brightness b = Brightness.light, Size size = kPhoneMedium}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(w, brightness: b, size: size));
  await settle(tester, const Duration(milliseconds: 600));
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('AÇ'));
  await settle(tester, const Duration(milliseconds: 600));
}

Future<void> _reveal(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
}

Future<void> _menu(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await settle(tester, const Duration(milliseconds: 400));
}

void main() {
  setUpAll(_fonts);

  // ---------------------------------------------------------------- kulüp kur
  group('Kulüp kur', () {

    Widget host(Session s) => Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () => openCreateClub(c, s), child: const Text('AÇ')),
            ),
          ),
        );

    FakeBackend base() => FakeBackend()
      ..on('/communities/categories', [
        {'category': 'Teknoloji'},
        {'category': 'Spor'},
      ])
      ..on('/communities/9', _club(role: 'OWNER', name: 'Yeni Kulüp'))
      ..on('/communities/9/posts*', {'items': [], 'nextCursor': null})
      ..on('/communities/9/requests*', {'items': [], 'nextCursor': null})
      ..on('/events*', {'items': [], 'nextCursor': null});

    testWidgets('dogrulama: ad en az 3 karakter', (tester) async {
      final be = base();
      await _pump(tester, host(makeSession(be)), size: kPhoneSmall);
      await _open(tester);
      await tester.ensureVisible(find.text('Listeden seç ya da yaz (isteğe bağlı)'));
      await tester.tap(find.text('Listeden seç ya da yaz (isteğe bağlı)'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Teknoloji'), findsOneWidget); // kategori satiri
      await tester.tap(find.text('Teknoloji'));
      await settle(tester, const Duration(milliseconds: 600));
      await _reveal(tester, find.text('Oluştur'));
      await tester.tap(find.text('Oluştur'));
      await tester.pump();
      expect(find.text('Kulüp adı en az 3 karakter olmalı.'), findsOneWidget);
      expect(be.requests.where((r) => r.startsWith('POST /communities')), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('gonderim govdesi + ACTIVE -> kulup sayfasi, sorular kaydedilir', (tester) async {
      final be = base()..on('/communities', {'id': 9, 'status': 'ACTIVE'}, status: 202);
      await _pump(tester, host(makeSession(be)));
      await _open(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Yeni Kulüp');
      await tester.enterText(find.byType(TextField).at(1), 'Açıklama');
      await tester.ensureVisible(find.text('Listeden seç ya da yaz (isteğe bağlı)'));
      await tester.tap(find.text('Listeden seç ya da yaz (isteğe bağlı)'));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.tap(find.text('Spor'));
      await settle(tester, const Duration(milliseconds: 600));
      await _reveal(tester, find.text('İstek ile'));
      await tester.tap(find.text('İstek ile'));
      await tester.pump();
      await _reveal(tester, find.text('+ Katılma sorusu ekle'));
      await tester.tap(find.text('+ Katılma sorusu ekle'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Sorunu yaz...'), 'Neden katılmak istiyorsun?');
      await _reveal(tester, find.text('Oluştur'));
      await tester.tap(find.text('Oluştur'));
      await settle(tester, const Duration(seconds: 1));
      expect(be.bodies['POST /communities'], {
        'name': 'Yeni Kulüp',
        'description': 'Açıklama',
        'category': 'Spor',
        'joinPolicy': 'APPROVAL',
        'visibility': 'PUBLIC',
      });
      expect(be.bodies['PUT /communities/9/join-questions'], {
        'questions': ['Neden katılmak istiyorsun?']
      });
      expect(be.requests, contains('GET /communities/9')); // ACTIVE: doğrudan kulüp sayfası
      expect(find.text('Yeni Kulüp'), findsWidgets);
      await unmount(tester);
    });

    testWidgets('PENDING -> onaya gonderildi bilgisi', (tester) async {
      final be = base()..on('/communities', {'id': 9, 'status': 'PENDING_REVIEW'}, status: 202);
      await _pump(tester, host(makeSession(be)));
      await _open(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Yeni Kulüp');
      await _reveal(tester, find.text('Oluştur'));
      await tester.tap(find.text('Oluştur'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Kulübün onaya gönderildi'), findsOneWidget);
      expect(be.requests, isNot(contains('GET /communities/9')));
      await tester.tap(find.text('Tamam'));
      await settle(tester, const Duration(milliseconds: 400));
      await unmount(tester);
    });

    testWidgets('sunucu dogrulama hatasi alanin altinda', (tester) async {
      final be = base()..fail('/communities', status: 400, code: 'VALIDATION_ERROR', message: 'name: boyut hatalı');
      await _pump(tester, host(makeSession(be)));
      await _open(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Yeni Kulüp');
      await _reveal(tester, find.text('Oluştur'));
      await tester.tap(find.text('Oluştur'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('boyut hatalı'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Kulupler sekmesinde + Kulup kur dugmesi formu acar', (tester) async {
      final be = base()..on('/communities', {'items': [], 'nextCursor': null});
      await _pump(tester, ClubsTab(session: makeSession(be)), size: kPhoneSmall);
      await tester.tap(find.text('Kulüp kur').first);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Oluştur'), findsOneWidget);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('form tasma yok ${b.name} ${size.width.toInt()}', (tester) async {
          final be = base();
          await _pump(tester, ClubFormPage(session: makeSession(be)), b: b, size: size);
          expect(tester.takeException(), isNull);
          await _reveal(tester, find.text('İstek ile'));
          await tester.tap(find.text('İstek ile'));
          await tester.pump();
          await _reveal(tester, find.text('+ Katılma sorusu ekle'));
          await tester.tap(find.text('+ Katılma sorusu ekle'));
          await tester.pump();
          await _reveal(tester, find.text('Oluştur'));
          await settle(tester, const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });

  // ------------------------------------------------------------ yönet menüsü
  group('Yönet menüsü', () {
    testWidgets('sahip: duzenle, basvurular, uyeler, sil + ayril', (tester) async {
      await _pump(tester, ClubDetailPage(session: makeSession(_detailBackend()), communityId: 7));
      await _menu(tester, 'Kulüp seçenekleri');
      expect(find.text('Kulübü düzenle'), findsOneWidget);
      expect(find.text('Başvurular'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // sayı hapı
      expect(find.text('Üyeleri yönet'), findsOneWidget);
      expect(find.text('Kulübü sil'), findsOneWidget);
      expect(find.text('Kulüpten ayrıl'), findsOneWidget);
      expect(find.text('Kulübü şikâyet et'), findsNothing);
      await unmount(tester);
    });

    testWidgets('moderator: yonet var, silme yok', (tester) async {
      await _pump(tester, ClubDetailPage(session: makeSession(_detailBackend(role: 'MODERATOR')), communityId: 7));
      await _menu(tester, 'Kulüp seçenekleri');
      expect(find.text('Kulübü düzenle'), findsOneWidget);
      expect(find.text('Kulübü sil'), findsNothing);
      await unmount(tester);
    });

    testWidgets('sade uye: yonet yok, ayril var', (tester) async {
      await _pump(tester, ClubDetailPage(session: makeSession(_detailBackend(role: 'MEMBER')), communityId: 7));
      await _menu(tester, 'Kulüp seçenekleri');
      expect(find.text('Kulübü düzenle'), findsNothing);
      expect(find.text('Başvurular'), findsNothing);
      expect(find.text('Kulübü sil'), findsNothing);
      expect(find.text('Kulüpten ayrıl'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('uye olmayan: yonet ve ayril yok', (tester) async {
      await _pump(tester, ClubDetailPage(session: makeSession(_detailBackend(status: 'NONE', role: null)), communityId: 7));
      await _menu(tester, 'Kulüp seçenekleri');
      expect(find.text('Kulübü düzenle'), findsNothing);
      expect(find.text('Kulüpten ayrıl'), findsNothing);
      expect(find.text('Kulübü şikâyet et'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kulup sil: ad yazmadan silinmez, yazinca DELETE', (tester) async {
      final be = _detailBackend();
      await _pump(tester, _launcher((c) => ClubDetailPage(session: makeSession(be), communityId: 7)));
      await _open(tester);
      await _menu(tester, 'Kulüp seçenekleri');
      await tester.tap(find.text('Kulübü sil'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.textContaining('Üyeler, etkinlikler ve sohbet silinir'), findsOneWidget);
      await tester.tap(find.text('Sil'));
      await tester.pump();
      expect(be.requests, isNot(contains('DELETE /communities/7')));
      await tester.enterText(find.byType(TextField).last, 'Robotik Kulübü');
      await tester.pump();
      await tester.tap(find.text('Sil'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(be.requests, contains('DELETE /communities/7'));
      expect(find.text('AÇ'), findsOneWidget); // sayfa kapandı
      await unmount(tester);
    });
  });

  // ------------------------------------------------------------------ ayrıl
  group('Kulüpten ayrıl', () {
    testWidgets('onay -> DELETE membership -> Katil durumu, sohbet kisayolu kalkar', (tester) async {
      final be = _detailBackend(role: 'MEMBER');
      final session = makeSession(be);
      await _pump(tester, ClubDetailPage(session: session, communityId: 7));
      expect(find.text('Kulüp sohbeti'), findsOneWidget);
      await _menu(tester, 'Kulüp seçenekleri');
      await tester.tap(find.text('Kulüpten ayrıl'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.textContaining('sohbet listenden silinecek'), findsOneWidget);
      be.on('/communities/7', _club(status: 'NONE', role: null)); // ayrıldıktan sonraki durum
      await tester.tap(find.text('Ayrıl'));
      await settle(tester, const Duration(seconds: 1));
      expect(be.requests, contains('DELETE /communities/7/membership'));
      expect(find.text('Katıl'), findsOneWidget);
      expect(find.text('Kulüp sohbeti'), findsNothing);
      expect(session.badges.conversationsDirty.value, 1);
      await unmount(tester);
    });

    testWidgets('vazgec: istek atilmaz', (tester) async {
      final be = _detailBackend(role: 'MEMBER');
      await _pump(tester, ClubDetailPage(session: makeSession(be), communityId: 7));
      await _menu(tester, 'Kulüp seçenekleri');
      await tester.tap(find.text('Kulüpten ayrıl'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(be.requests, isNot(contains('DELETE /communities/7/membership')));
      await unmount(tester);
    });

    testWidgets('sahip: ayrilma yerine aciklama, istek yok', (tester) async {
      final be = _detailBackend();
      await _pump(tester, ClubDetailPage(session: makeSession(be), communityId: 7));
      await _menu(tester, 'Kulüp seçenekleri');
      await tester.tap(find.text('Kulüpten ayrıl'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.textContaining('Önce sahipliği devret ya da kulübü sil'), findsOneWidget);
      expect(be.requests, isNot(contains('DELETE /communities/7/membership')));
      await unmount(tester);
    });

    testWidgets('sunucu OWNER_CANNOT_LEAVE dönerse aciklama gosterilir', (tester) async {
      final be = _detailBackend(role: 'MODERATOR')
        ..fail('/communities/7/membership', status: 400, code: 'OWNER_CANNOT_LEAVE', message: 'x');
      await _pump(tester, ClubDetailPage(session: makeSession(be), communityId: 7));
      await _menu(tester, 'Kulüp seçenekleri');
      await tester.tap(find.text('Kulüpten ayrıl'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Ayrıl'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.textContaining('Önce sahipliği devret ya da kulübü sil'), findsOneWidget);
      await unmount(tester);
    });
  });

  // -------------------------------------------------------------- başvurular
  group('Başvurular', () {
    FakeBackend be() => FakeBackend()
      ..on('/communities/7/requests*', {
        'items': [
          {
            'userId': 20,
            'displayName': _longName,
            'answers': [
              {'question': 'Neden?', 'answer': 'Robot yapmak istiyorum'}
            ],
          },
          {'userId': 21, 'displayName': 'Ayşe Demir'},
        ],
        'nextCursor': null,
      });

    testWidgets('onayla ve reddet istekleri', (tester) async {
      final b = be();
      await _pump(tester, ClubRequestsPage(session: makeSession(b), communityId: 7));
      expect(find.text('Robot yapmak istiyorum'), findsOneWidget);
      await tester.tap(find.text('Onayla').first);
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests, contains('POST /communities/7/requests/20/approve'));
      await tester.tap(find.text('Reddet').first);
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests, contains('POST /communities/7/requests/21/reject'));
      expect(find.text('Bekleyen başvuru yok.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('bos durum', (tester) async {
      final b = FakeBackend()..on('/communities/7/requests*', {'items': [], 'nextCursor': null});
      await _pump(tester, ClubRequestsPage(session: makeSession(b), communityId: 7));
      expect(find.text('Bekleyen başvuru yok.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kulup sayfasinda bekleyen sayisi rozeti', (tester) async {
      await _pump(tester, ClubDetailPage(session: makeSession(_detailBackend()), communityId: 7));
      expect(find.text('1 bekleyen katılma isteği'), findsOneWidget);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('tasma yok ${b.name} ${size.width.toInt()}', (tester) async {
          await _pump(tester, ClubRequestsPage(session: makeSession(be()), communityId: 7), b: b, size: size);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });

  // ------------------------------------------------------------------ üyeler
  group('Üye yönetimi', () {
    FakeBackend be() => FakeBackend()
      ..on('/communities/7/members*', {
        'items': [
          {'userId': 1, 'displayName': 'Ayşe Yılmaz', 'role': 'OWNER'},
          {'userId': 2, 'displayName': _longName, 'role': 'MEMBER'},
          {'userId': 3, 'displayName': 'Mehmet Kaya', 'role': 'MODERATOR'},
        ],
        'nextCursor': null,
      });

    testWidgets('cikar: onay sonrasi DELETE', (tester) async {
      final b = be();
      await _pump(tester, ClubMembersPage(session: makeSession(b), communityId: 7, myRole: 'OWNER'));
      expect(find.byTooltip('Üye işlemleri'), findsNWidgets(2)); // sahip satırında menü yok
      await tester.tap(find.byTooltip('Üye işlemleri').first);
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Kulüpten çıkar'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests, isNot(contains('DELETE /communities/7/members/2')));
      await tester.tap(find.text('Çıkar'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests, contains('DELETE /communities/7/members/2'));
      await unmount(tester);
    });

    testWidgets('yasakla ban=true, rol degistir PUT', (tester) async {
      final b = be();
      await _pump(tester, ClubMembersPage(session: makeSession(b), communityId: 7, myRole: 'OWNER'));
      await tester.tap(find.byTooltip('Üye işlemleri').first);
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Moderatör yap'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.bodies['PUT /communities/7/members/2/role'], {'role': 'MODERATOR'});
      await tester.tap(find.byTooltip('Üye işlemleri').first);
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Yasakla'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Yasakla').last);
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests, contains('DELETE /communities/7/members/2?ban=true'));
      await unmount(tester);
    });

    testWidgets('arama', (tester) async {
      await _pump(tester, ClubMembersPage(session: makeSession(be()), communityId: 7, myRole: 'OWNER'));
      await tester.enterText(find.byType(TextField), 'mehmet');
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Mehmet Kaya'), findsOneWidget);
      expect(find.text('Ayşe Yılmaz'), findsNothing);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('tasma yok ${b.name} ${size.width.toInt()}', (tester) async {
          await _pump(tester, ClubMembersPage(session: makeSession(be()), communityId: 7, myRole: 'OWNER'), b: b, size: size);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });

  // --------------------------------------------------------------- Kulüplerim
  group('Kulüplerim', () {
    FakeBackend be() => FakeBackend()
      ..on('/me/communities*', {
        'items': [
          {'id': 1, 'name': 'Kurduğum Kulüp', 'memberCount': 5, 'myStatus': 'ACTIVE', 'myRole': 'OWNER'},
          {'id': 2, 'name': 'Satranç', 'memberCount': 12, 'myStatus': 'ACTIVE', 'myRole': 'MEMBER'},
          {'id': 3, 'name': _longName, 'category': 'Sanat', 'myStatus': 'PENDING'},
        ],
        'nextCursor': null,
      });

    testWidgets('kurduklarim / uye olduklarim / bekleyen ayrimi', (tester) async {
      await _pump(tester, MyClubsPage(session: makeSession(be())));
      expect(find.text('KURDUKLARIM'), findsOneWidget);
      expect(find.text('ÜYE OLDUKLARIM'), findsOneWidget);
      expect(find.text('BEKLEYEN BAŞVURULAR'), findsOneWidget);
      expect(find.text('Onay bekliyor'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hizli ayril: onay + DELETE + listeden kalkar', (tester) async {
      final b = be();
      final s = makeSession(b);
      await _pump(tester, MyClubsPage(session: s));
      // Sıra: sahip (Yönet), üye, bekleyen.
      await tester.longPress(find.text('Satranç'));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.tap(find.text('Kulüpten ayrıl'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Ayrıl'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests, contains('DELETE /communities/2/membership'));
      expect(find.text('Satranç'), findsNothing);
      expect(s.badges.conversationsDirty.value, 1);
      await unmount(tester);
    });

    testWidgets('kurduklarimda Yonet menusu', (tester) async {
      await _pump(tester, MyClubsPage(session: makeSession(be())));
      await tester.tap(find.text('Yönet'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Yönet: düzenle'), findsOneWidget);
      expect(find.text('Yönet: başvurular'), findsOneWidget);
      expect(find.text('Kulüpten ayrıl'), findsOneWidget); // sahip ayrilmaya calisinca bilgi diyalogu cikar
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('tasma yok ${b.name} ${size.width.toInt()}', (tester) async {
          await _pump(tester, MyClubsPage(session: makeSession(be())), b: b, size: size);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });
}
