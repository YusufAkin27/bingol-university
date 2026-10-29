import 'dart:io';

import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/clubs/club_form_page.dart';
import 'package:bu_kampus/features/clubs/club_members_page.dart';
import 'package:bu_kampus/features/clubs/club_requests_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

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

Map<String, dynamic> _club({String status = 'NONE', String? role, String policy = 'APPROVAL'}) => {
      'id': 7,
      'name': 'Fotoğraf Kulübü',
      'description': 'Kampüste fotoğraf gezileri, teknik atölyeler ve dönem sonu sergisi düzenleyen öğrenci topluluğu.',
      'category': 'Sanat',
      'memberCount': 128,
      'visibility': 'PUBLIC',
      'joinPolicy': policy,
      'myStatus': status,
      'myRole': role,
    };

FakeBackend _be({String status = 'NONE', String? role, int pending = 0}) => FakeBackend()
  ..on('/communities/7', _club(status: status, role: role))
  ..on('/communities/7/posts*', {
    'items': [
      {'id': 1, 'authorId': 5, 'authorName': 'Kulüp yönetimi', 'text': 'Cumartesi gezi var.', 'pinned': true, 'canDelete': true}
    ],
    'nextCursor': null
  })
  ..on('/communities/7/requests*', {
    'items': [for (var i = 0; i < pending; i++) {'userId': 20 + i, 'displayName': 'Kişi $i'}],
    'nextCursor': null
  })
  ..on('/communities/7/join-questions', [
    {'id': 1, 'question': 'Neden katılmak istiyorsun?'},
    {'id': 2, 'question': 'Hangi ekipmanla çekiyorsun?'},
  ])
  ..on('/events*', {'items': [], 'nextCursor': null});

Future<void> _pump(WidgetTester tester, Widget w, {Brightness b = Brightness.light, Size size = kPhoneMedium, bool rtl = false}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(rtl ? Directionality(textDirection: TextDirection.rtl, child: w) : w, brightness: b, size: size));
  await settle(tester, const Duration(milliseconds: 600));
}

void main() {
  setUpAll(_fonts);

  group('Kulup detay: ziyaretci', () {
    testWidgets('katilma istegi: sorular, zorunlu hata, gonderim', (tester) async {
      final be = _be()..on('/communities/7/join', {'status': 'PENDING'});
      await _pump(tester, ClubDetailPage(session: makeSession(be), communityId: 7));
      expect(find.text('Katılma isteği gönder'), findsOneWidget);
      expect(find.text('128 üye'), findsOneWidget); // çip satırı: kategori · üye · görünürlük
      await tester.tap(find.text('Katılma isteği gönder'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.textContaining('Neden katılmak istiyorsun?'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Öğrenmek istiyorum');
      await tester.tap(find.text('İstek gönder'));
      await tester.pump();
      expect(find.text('Bu soru zorunlu'), findsOneWidget); // ikinci soru boş
      expect(be.requests, isNot(contains('POST /communities/7/join')));
      await tester.enterText(find.byType(TextField).at(1), 'Telefon');
      await tester.tap(find.text('İstek gönder'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(be.bodies['POST /communities/7/join'], {
        'answers': [
          {'questionId': 1, 'answer': 'Öğrenmek istiyorum'},
          {'questionId': 2, 'answer': 'Telefon'},
        ]
      });
      await unmount(tester);
    });

    testWidgets('katilma sayfasi Vazgec: istek yok', (tester) async {
      final be = _be();
      await _pump(tester, ClubDetailPage(session: makeSession(be), communityId: 7));
      await tester.tap(find.text('Katılma isteği gönder'));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(be.requests, isNot(contains('POST /communities/7/join')));
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('ziyaretci + katilma sayfasi 320 ${b.name} ${rtl ? 'RTL' : 'LTR'} tasma yok', (tester) async {
          await _pump(tester, ClubDetailPage(session: makeSession(_be()), communityId: 7), b: b, size: kPhoneSmall, rtl: rtl);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Katılma isteği gönder'));
          await settle(tester, const Duration(milliseconds: 500));
          await tester.tap(find.text('İstek gönder'));
          await tester.pump();
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });

  group('Kulup detay: uye / yonetici', () {
    testWidgets('uye: Uyesin etiketi, sohbet, yazma kutusu kelime siniri', (tester) async {
      final be = _be(status: 'ACTIVE', role: 'MEMBER');
      await _pump(tester, ClubDetailPage(session: makeSession(be), communityId: 7));
      expect(find.text('Üyesin'), findsOneWidget);
      expect(find.text('Kulüp sohbeti'), findsOneWidget);
      expect(find.text('Sabit'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'bir iki üç dört beş altı yedi sekiz');
      await tester.pump();
      expect(find.text('En çok 7 kelime yazabilirsin.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'bir iki üç');
      await tester.pump();
      expect(find.text('3/7 kelime'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yonetici: bekleyen istek bandi + menude sayi', (tester) async {
      final be = _be(status: 'ACTIVE', role: 'OWNER', pending: 3);
      await _pump(tester, ClubDetailPage(session: makeSession(be), communityId: 7));
      expect(find.text('3 bekleyen katılma isteği'), findsOneWidget);
      await tester.tap(find.byTooltip('Kulüp seçenekleri'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Başvurular'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('yonetici 320 ${b.name} ${rtl ? 'RTL' : 'LTR'} menu acik tasma yok', (tester) async {
          await _pump(tester, ClubDetailPage(session: makeSession(_be(status: 'ACTIVE', role: 'OWNER', pending: 3)), communityId: 7),
              b: b, size: kPhoneSmall, rtl: rtl);
          await tester.tap(find.byTooltip('Kulüp seçenekleri'));
          await settle(tester, const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });

  group('Kulup uyeler / istekler / form', () {
    FakeBackend mb() => FakeBackend()
      ..on('/communities/7/members*', {
        'items': [
          {'userId': 1, 'displayName': 'Elif Y.', 'role': 'OWNER'},
          {'userId': 2, 'displayName': 'Mert K.', 'role': 'MODERATOR'},
          {'userId': 3, 'displayName': 'Zeynep A.', 'role': 'MEMBER'},
        ],
        'nextCursor': null,
      });

    testWidgets('uyeler: alt baslik + rol etiketleri + menu', (tester) async {
      await _pump(tester, ClubMembersPage(session: makeSession(mb()), communityId: 7, myRole: 'OWNER', clubName: 'Fotoğraf Kulübü', memberCount: 128));
      expect(find.text('Fotoğraf Kulübü · 128 üye'), findsOneWidget);
      expect(find.text('Yönetici'), findsOneWidget);
      expect(find.text('Moderatör'), findsOneWidget);
      await tester.tap(find.byTooltip('Üye işlemleri').first);
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Kulüpten çıkar'), findsOneWidget);
      expect(find.text('Yasakla'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('istekler: onaylaniyor etiketi', (tester) async {
      final be = FakeBackend()
        ..on('/communities/7/requests*', {
          'items': [
            {'userId': 20, 'displayName': 'Selin N.', 'answers': [{'question': 'Neden?', 'answer': 'Öğrenmek'}]}
          ],
          'nextCursor': null,
        })
        ..on('/communities/7/requests/20/approve', {}, status: 200);
      be.delay = const Duration(milliseconds: 300);
      await _pump(tester, ClubRequestsPage(session: makeSession(be), communityId: 7));
      expect(find.text('Başvurular'), findsWidgets); // büyük başlık: genişlemiş + daralmış
      await tester.tap(find.text('Onayla'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Onaylanıyor...'), findsOneWidget);
      await settle(tester, const Duration(seconds: 1));
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('uyeler/istekler/form 320 ${b.name} ${rtl ? 'RTL' : 'LTR'} tasma yok', (tester) async {
          await _pump(tester, ClubMembersPage(session: makeSession(mb()), communityId: 7, myRole: 'OWNER', clubName: 'Çok uzun bir kulüp adı Bingöl Fotoğraf', memberCount: 1280),
              b: b, size: kPhoneSmall, rtl: rtl);
          expect(tester.takeException(), isNull);
          await unmount(tester);
          final rb = FakeBackend()
            ..on('/communities/7/requests*', {
              'items': [
                {'userId': 20, 'displayName': 'Selin N.', 'answers': [{'question': 'Neden katılmak istiyorsun?', 'answer': 'Çekim teknikleri öğrenmek ve gezilere katılmak istiyorum.'}]}
              ],
              'nextCursor': null,
            });
          await _pump(tester, ClubRequestsPage(session: makeSession(rb), communityId: 7), b: b, size: kPhoneSmall, rtl: rtl);
          expect(tester.takeException(), isNull);
          await unmount(tester);
          final fb = FakeBackend()..on('/communities/categories', [{'category': 'Sanat'}, {'category': 'Spor'}, {'category': 'Teknoloji'}, {'category': 'Bilim'}]);
          await _pump(tester, ClubFormPage(session: makeSession(fb)), b: b, size: kPhoneSmall, rtl: rtl);
          expect(find.text('Kulüp kur'), findsOneWidget);
          expect(find.text('Kulübü oluştur'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });
}
