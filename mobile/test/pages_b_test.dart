import 'dart:io';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/widgets/bu_skeleton.dart' show BuSkeleton;
import 'package:bu_kampus/widgets/bu_widgets.dart' show LucideIcons;
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/chatlist_widgets.dart';
import 'package:bu_kampus/features/chat/new_chat_page.dart';
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:bu_kampus/features/platform/qr_scan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// ---------------------------------------------------------------- örnek veri

String _iso(DateTime d) => d.toUtc().toIso8601String();

const _longTitle = 'Bingöl Üniversitesi Mühendislik Fakültesi Bilgisayar Mühendisliği Öğrenci Topluluğu Büyük Buluşma';
const _longWord = 'Superkalifragilistikekspiyalidokiyuslukarakterizasyonlarındanmış';

Map<String, dynamic> _conv(int id, String type, String title, {int unread = 0, String text = 'Merhaba'}) => {
      'id': id,
      'type': type,
      'title': title,
      if (type == 'DIRECT') 'peer': {'id': 10 + id, 'displayName': title},
      'unreadCount': unread,
      'muted': id == 3,
      'lastMessage': {
        'id': 100 + id,
        'conversationId': id,
        'senderId': 10 + id,
        'text': text,
        'createdAt': _iso(DateTime.now()),
      },
    };

Map<String, dynamic> _convPage() => {
      'items': [
        _conv(1, 'DIRECT', 'Ali Veli', unread: 3, text: 'Yarın $_longWord görüşelim mi?'),
        _conv(2, 'GROUP', _longTitle, unread: 120),
        _conv(3, 'CLUB', 'Robotik Kulübü', unread: 1),
        _conv(4, 'EVENT', 'Kariyer Günleri'),
      ],
      'nextCursor': null,
    };

Map<String, dynamic> _msg(int id, int sender, String text, {Map<String, dynamic>? extra}) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': _iso(DateTime.now().subtract(Duration(minutes: 30 - id))),
      ...?extra,
    };

Map<String, dynamic> _messagePage() => {
      'items': [
        _msg(5, 1, 'Tamamdır, görüşürüz $_longWord', extra: {
          'replyTo': {'id': 4, 'senderId': 11, 'text': 'Yarın görüşelim mi? $_longTitle', 'deleted': false},
          'reactions': [
            {'emoji': '👍', 'count': 2},
            {'emoji': '❤️', 'count': 1},
          ],
          'myReaction': '👍',
          'edited': true,
        }),
        _msg(4, 11, 'Yarın görüşelim mi? $_longTitle'),
        _msg(3, 11, 'Bu mesaj silindi', extra: {'deleted': true}),
        _msg(2, 1, 'Selam'),
        _msg(1, 11, 'Merhaba'),
      ],
      'nextCursor': null,
    };

Map<String, dynamic> _club({String status = 'ACTIVE', String? role, String policy = 'OPEN'}) => {
      'id': 7,
      'name': 'Robotik ve Yapay Zekâ Topluluğu',
      'description': 'Robot yarışmalarına hazırlanan öğrenciler. $_longWord',
      'category': 'Teknoloji',
      'memberCount': 42,
      'visibility': 'PUBLIC',
      'joinPolicy': policy,
      'myStatus': status,
      'myRole': role,
    };

Map<String, dynamic> _clubItem(int id, String name, {String status = 'NONE'}) => {
      'id': id,
      'name': name,
      'category': 'Teknoloji',
      'memberCount': 12 + id,
      'myStatus': status,
      'joinPolicy': 'OPEN',
    };

Map<String, dynamic> _event({String? rsvp, bool manage = false, int? capacity}) {
  final s = DateTime.now().add(const Duration(hours: 2));
  return {
    'id': 5,
    'title': _longTitle,
    'description': 'Etkinlik açıklaması. $_longWord',
    'startsAt': _iso(s),
    'endsAt': _iso(s.add(const Duration(hours: 2))),
    'location': 'Kongre ve Kültür Merkezi Büyük Salon $_longWord',
    'communityId': 7,
    'communityName': 'Robotik ve Yapay Zekâ Topluluğu',
    'goingCount': 8,
    'interestedCount': 3,
    'capacity': capacity,
    'myRsvp': rsvp,
    'canManage': manage,
  };
}

List<Map<String, dynamic>> _calendar() {
  final now = DateTime.now();
  final s = DateTime(now.year, now.month, now.day, 12);
  return [
    {
      'id': 5,
      'source': 'USER',
      'title': _longTitle,
      'startsAt': _iso(s),
      'endsAt': _iso(s.add(const Duration(hours: 1))),
      'location': 'Büyük Salon $_longWord',
      'communityName': 'Robotik Topluluğu',
      'goingCount': 4,
      'myRsvp': null,
    },
    {
      'id': 6,
      'source': 'USER',
      'title': 'Katıldığım etkinlik',
      'startsAt': _iso(s),
      'goingCount': 9,
      'myRsvp': 'GOING',
    },
    {
      'id': 9,
      'source': 'OFFICIAL',
      'title': 'Resmi duyuru etkinliği',
      'date': '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    },
  ];
}

// ------------------------------------------------------------- ortak yardımcı

typedef PageBuilder = Widget Function(Session s);

/// Sayfayı kurar, yerleştirir; istisna olmadığını doğrular.
Future<void> _pump(WidgetTester tester, Widget page, {Brightness b = Brightness.light, Size size = kPhoneMedium}) async {
  useScreen(tester, size);
  _capture();
  await tester.pumpWidget(buildApp(page, brightness: b, size: size));
  await settle(tester, const Duration(milliseconds: 600));
}

final _details = <String>[];

void _noErrors(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('$e\n${_details.join('\n---\n')}');
}

/// Hata ayrıntılarını (hangi widget taştı) kaydeder; _noErrors başarısızlıkta yazdırır.
void _capture() {
  _details.clear();
  final prev = FlutterError.onError;
  FlutterError.onError = (d) {
    final info = d.informationCollector?.call().map((n) => n.toStringDeep()).join('\n') ?? '';
    _details.add('${d.exception}\n$info');
    prev?.call(d);
  };
}

/// Ana dikey kaydırıcıyı sona kadar kaydırır: aşağıdaki içerikte de taşma/çökme olmamalı.
Future<void> _scrollThrough(WidgetTester tester) async {
  final f = find.byWidgetPredicate((w) => w is Scrollable && (w.axis == Axis.vertical));
  if (f.evaluate().isEmpty) return;
  for (var i = 0; i < 8; i++) {
    await tester.drag(f.first, const Offset(0, -260), warnIfMissed: false);
    await settle(tester, const Duration(milliseconds: 200));
    _noErrors(tester);
  }
}

/// Liste tembel kurulduğundan ekran dışındaki öğeye kaydırarak ulaşır.
Future<void> _reveal(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await tester.pump();
}

/// Açık/koyu x üç ekran boyutu: dolu durum çökme ve taşma vermemeli.
void _matrix(String name, FakeBackend Function() backend, PageBuilder page, {Finder Function()? expectFinder}) {
  for (final b in Brightness.values) {
    for (final size in kPhoneSizes) {
      testWidgets('$name dolu veri ${b.name} ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        final be = backend();
        final s = makeSession(be);
        await _pump(tester, page(s), b: b, size: size);
        _noErrors(tester);
        if (expectFinder != null) expect(expectFinder(), findsWidgets);
        await _scrollThrough(tester);
        await unmount(tester);
        _noErrors(tester);
      });
    }
  }
}

const _emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// Testte Inter yoktur: aynı metrikli Roboto'yu "Inter" adıyla yükler (BuType Inter ister).
Future<void> _loadTestFontsWithInter() async {
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

void main() {
  setUpAll(_loadTestFontsWithInter);

  // ============================================================== ChatTab
  group('ChatTab', () {
    FakeBackend full() => FakeBackend()..on('/conversations', _convPage());
    ChatTab build(Session s) => ChatTab(session: s, connectRealtime: false);

    _matrix('ChatTab', full, build, expectFinder: () => find.text('Ali Veli'));

    testWidgets('yukleniyor -> dolu', (tester) async {
      final be = full()..delay = const Duration(milliseconds: 300);
      final s = makeSession(be);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(build(s), size: kPhoneMedium));
      await tester.pump();
      expect(find.text('Ali Veli'), findsNothing); // iskelet
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Ali Veli'), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('bos durum', (tester) async {
      final be = FakeBackend()..on('/conversations', {'items': [], 'nextCursor': null});
      await _pump(tester, build(makeSession(be)));
      expect(find.text('Henüz sohbetiniz yok'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('500 hatasi -> yeniden dene -> dolu', (tester) async {
      final be = FakeBackend()..fail('/conversations');
      await _pump(tester, build(makeSession(be)));
      expect(find.text('Yeniden dene'), findsOneWidget);
      be.on('/conversations', _convPage());
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester);
      expect(find.text('Ali Veli'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('ag hatasi -> hata gorunumu', (tester) async {
      final be = FakeBackend()..network('/conversations');
      await _pump(tester, build(makeSession(be)), size: kPhoneSmall);
      expect(find.text('Yüklenemedi, tekrar dene'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    for (final size in [kPhoneSmall, kPhoneMedium, kPhoneLarge]) {
      testWidgets('4 suzgec cipi (Tumu/Kisiler/Kulupler/Etkinlikler) listelenir ${size.width.toInt()}', (tester) async {
        await _pump(tester, build(makeSession(full())), size: size);
        // Çipler yatay kayan satırdadır (referans 18): ilk üçü her boyutta görünür, dördüncü kaydırmayla.
        for (final l in ['Tümü', 'Kişiler', 'Kulüpler', 'Etkinlikler']) {
          expect(find.descendant(of: find.byKey(const ValueKey('chat-segment')), matching: find.text(l)), findsOneWidget, reason: l);
        }
        _noErrors(tester);
        await unmount(tester);
      });
    }

    testWidgets('arama + segment kaydirinca ekranda sabit kalir', (tester) async {
      final many = {
        'items': [for (var i = 1; i <= 30; i++) _conv(i + 20, 'DIRECT', 'Kisi $i')],
        'nextCursor': null,
      };
      final be = FakeBackend()..on('/conversations', many);
      await _pump(tester, build(makeSession(be)), size: kPhoneMedium);
      final seg = find.byKey(const ValueKey('chat-segment'));
      final before = tester.getTopLeft(seg);
      final search = tester.getTopLeft(find.byType(TextField));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await settle(tester, const Duration(milliseconds: 300));
      expect(tester.getTopLeft(seg).dy, lessThan(before.dy + 1));
      expect(tester.getTopLeft(seg).dy, greaterThanOrEqualTo(0));
      expect(tester.getTopLeft(find.byType(TextField)).dy, lessThan(search.dy));
      expect(tester.getTopLeft(find.byType(TextField)).dy, greaterThanOrEqualTo(0));
      expect(find.text('Sohbet'), findsNothing); // başlık kaydı
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('avatarlar daire; tikler duruma gore', (tester) async {
      Map<String, dynamic> withStatus(int id, String type, String? st) {
        final c = _conv(id, type, 'Satir $id');
        if (st != null) (c['lastMessage'] as Map<String, dynamic>)['status'] = st;
        return c;
      }

      final be = FakeBackend()
        ..on('/conversations', {
          'items': [
            withStatus(1, 'DIRECT', 'SENT'),
            withStatus(2, 'GROUP', 'DELIVERED'),
            withStatus(4, 'EVENT', 'READ'),
            withStatus(5, 'CLUB', null),
          ],
          'nextCursor': null,
        });
      await _pump(tester, build(makeSession(be)), size: kPhoneMedium);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(find.byIcon(LucideIcons.checkCheck), findsNWidgets(2));
      final read = tester.widget<Icon>(find.byIcon(LucideIcons.checkCheck).last);
      expect(read.color, isNot(equals(tester.widget<Icon>(find.byIcon(LucideIcons.checkCheck).first).color)));
      // Tüm sohbet avatarları 52 dp; fotoğrafsızlar varsayılan görselli, fotoğraflılar tam daire BuAvatar.
      final avatars = tester.widgetList<ChatlistAvatar>(find.byType(ChatlistAvatar));
      expect(avatars, isNotEmpty);
      for (final a in avatars) {
        expect(a.size, 52);
      }
      expect(tester.getSize(find.byType(ChatlistAvatar).first), const Size(52, 52));
      _noErrors(tester);
      await unmount(tester);
    });

    Future<void> longPress(WidgetTester tester, String text) async {
      await tester.longPress(find.text(text));
      await settle(tester, const Duration(milliseconds: 300));
    }

    testWidgets('uzun basis menusu: birebirde Sil var, kulup/etkinlikte yok', (tester) async {
      await _pump(tester, build(makeSession(full())));
      await longPress(tester, 'Ali Veli');
      expect(find.byKey(const ValueKey('act-delete')), findsOneWidget);
      expect(find.byKey(const ValueKey('act-mute')), findsOneWidget);
      expect(find.byKey(const ValueKey('act-archive')), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('act-delete')), findsNothing);
      await longPress(tester, 'Robotik Kulübü');
      expect(find.byKey(const ValueKey('act-archive')), findsOneWidget);
      expect(find.byKey(const ValueKey('act-delete')), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await settle(tester, const Duration(milliseconds: 300));
      await longPress(tester, 'Kariyer Günleri');
      expect(find.byKey(const ValueKey('act-delete')), findsNothing);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('Sil -> onay -> DELETE gonderilir, satir kalkar', (tester) async {
      final be = full();
      await _pump(tester, build(makeSession(be)));
      await longPress(tester, 'Ali Veli');
      await tester.tap(find.byKey(const ValueKey('act-delete')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Bu sohbet yalnızca senin için silinecek. Karşı taraf etkilenmez.'), findsOneWidget);
      expect(be.count('DELETE /conversations/1'), 0);
      await tester.tap(find.text('Sil'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(be.requests, contains('DELETE /conversations/1'));
      expect(find.text('Ali Veli'), findsNothing);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('grupta onay metni; Vazgec istek atmaz', (tester) async {
      final be = full();
      await _pump(tester, build(makeSession(be)));
      await longPress(tester, _longTitle);
      await tester.tap(find.byKey(const ValueKey('act-delete')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Gruptan çıkıp bu sohbeti sileceksin.'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(be.requests.where((r) => r.startsWith('DELETE')), isEmpty);
      expect(find.text('Ali Veli'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('DELETE hata verince satir geri gelir', (tester) async {
      final be = full()..fail('/conversations/1', status: 500, message: 'Silinemedi');
      await _pump(tester, build(makeSession(be)));
      await longPress(tester, 'Ali Veli');
      await tester.tap(find.byKey(const ValueKey('act-delete')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Sil'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(be.requests, contains('DELETE /conversations/1'));
      expect(find.text('Ali Veli'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('sessize al: sure secimi PUT; sessizde Sesi ac DELETE', (tester) async {
      final be = full();
      await _pump(tester, build(makeSession(be)));
      await longPress(tester, 'Ali Veli');
      await tester.tap(find.byKey(const ValueKey('act-mute')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('8 saat'), findsOneWidget); // varsayılan seçili süre
      await tester.tap(find.text('1 hafta'));
      await tester.pump();
      await tester.tap(find.text('8 saat'));
      await tester.pump();
      await tester.tap(find.text('Sessize al')); // referans 22-1: süre seçilir, sonra "Sessize al" ile onaylanır
      await settle(tester, const Duration(milliseconds: 400));
      expect(be.requests, contains('PUT /conversations/1/mute'));
      expect(be.bodies['PUT /conversations/1/mute'], {'durationMinutes': 480});
      expect(find.byIcon(LucideIcons.bellOff), findsWidgets);
      // Sohbet 3 zaten sessiz: Sesi aç.
      await longPress(tester, 'Robotik Kulübü');
      expect(find.byKey(const ValueKey('act-mute')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('act-unmute')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(be.requests, contains('DELETE /conversations/3/mute'));
      _noErrors(tester);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('menu tasma yok ${b.name} ${size.width.toInt()}', (tester) async {
          await _pump(tester, build(makeSession(full())), b: b, size: size);
          await longPress(tester, 'Ali Veli');
          expect(find.byKey(const ValueKey('act-delete')), findsOneWidget);
          _noErrors(tester);
          await tester.tapAt(const Offset(5, 5));
          await settle(tester, const Duration(milliseconds: 300));
          await longPress(tester, _longTitle);
          _noErrors(tester);
          await unmount(tester);
        });
      }
    }

    testWidgets('suzgec cipi ve arama', (tester) async {
      await _pump(tester, build(makeSession(full())), size: kPhoneSmall);
      await tester.tap(find.text('Kulüpler'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Robotik Kulübü'), findsOneWidget);
      expect(find.text('Ali Veli'), findsNothing);
      await tester.enterText(find.byType(TextField), 'zzz');
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Eşleşen sohbet bulunamadı'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });
  });

  // ======================================================== ChatDetailPage
  group('ChatDetailPage', () {
    FakeBackend full() => FakeBackend()
      ..on('/conversations/1/messages*', _messagePage())
      ..on('/conversations/1', {
        'conversation': {'id': 1},
        'members': [
          {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
          {'userId': 11, 'displayName': 'Ali Veli'},
        ],
      })
      ..on('/users/11/presence', {'online': true});
    ChatDetailPage build(Session s, {String type = 'DIRECT'}) => ChatDetailPage(
          session: s,
          connectRealtime: false,
          conversation: {
            'id': 1,
            'type': type,
            'title': type == 'DIRECT' ? 'Ali Veli' : _longTitle,
            if (type == 'DIRECT') 'peer': {'id': 11, 'displayName': 'Ali Veli'},
            if (type != 'DIRECT') 'memberCount': 12,
          },
        );

    _matrix('ChatDetail', full, build, expectFinder: () => find.textContaining('Tamamdır'));

    testWidgets('grup sohbeti uzun baslik 320', (tester) async {
      await _pump(tester, build(makeSession(full()), type: 'GROUP'), size: kPhoneSmall);
      expect(find.textContaining('Tamamdır'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('yukleniyor -> dolu, cevrimici durumu', (tester) async {
      final be = full()..delay = const Duration(milliseconds: 300);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(build(makeSession(be)), size: kPhoneMedium));
      await tester.pump();
      expect(find.byType(BuSkeleton), findsWidgets); // iskelet (dönen çember yok)
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Selam'), findsOneWidget);
      expect(find.text('Çevrimiçi'), findsOneWidget);
      expect(find.text('Bu mesaj silindi'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('bos durum', (tester) async {
      final be = FakeBackend()..on('/conversations/1/messages*', {'items': [], 'nextCursor': null});
      await _pump(tester, build(makeSession(be)));
      expect(find.textContaining('Henüz mesaj yok'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('500 -> yeniden dene', (tester) async {
      final be = FakeBackend()..fail('/conversations/1/messages*');
      await _pump(tester, build(makeSession(be)));
      expect(find.text('Yeniden dene'), findsOneWidget);
      be.on('/conversations/1/messages*', _messagePage());
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester);
      expect(find.text('Selam'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('ag hatasi', (tester) async {
      final be = FakeBackend()..network('/conversations/1/messages*');
      await _pump(tester, build(makeSession(be)), size: kPhoneSmall);
      expect(find.text('Yeniden dene'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('mesaj gonder (REST) ve basarisiz gonderim -> yeniden dene', (tester) async {
      final be = full();
      await _pump(tester, build(makeSession(be)), size: kPhoneSmall);
      be.fail('/conversations/1/messages'); // yükleme bittikten sonra: POST 500 döner
      await tester.enterText(find.byType(TextField), 'Deneme mesajı');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Gönder'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.textContaining('Yeniden dene'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('engelli sohbet', (tester) async {
      final be = full();
      await _pump(
        tester,
        ChatDetailPage(session: makeSession(be), connectRealtime: false, conversation: const {
          'id': 1,
          'type': 'DIRECT',
          'blocked': true,
          'peer': {'id': 11, 'displayName': 'Ali Veli'},
        }),
        size: kPhoneSmall,
      );
      // Engellenen kişiyle birebir sohbette yazma alanı yerine "Engeli kaldır" çubuğu çıkar.
      expect(find.byKey(const ValueKey('chatBlockedBar')), findsOneWidget);
      expect(find.text('Engellediğiniz kişiyle mesajlaşamazsınız.'), findsOneWidget);
      expect(find.byKey(const ValueKey('chatUnblockButton')), findsOneWidget);
      expect(find.byType(TextField), findsNothing); // composer yok
      _noErrors(tester);
      await unmount(tester);
    });

    // ---------------------------------------------------- mesaj eylem menüsü
    const card = ValueKey('msgActions.card');
    const bar = ValueKey('msgActions.reactions');
    FakeBackend withEmojis() => full()..on('/messages/reactions', {'emojis': _emojis});

    Future<void> openMenu(WidgetTester tester, Finder target, {bool tap = false}) async {
      if (tap) {
        await tester.tap(target);
      } else {
        await tester.longPress(target);
      }
      await settle(tester, const Duration(milliseconds: 500));
    }

    testWidgets('uzun basis menuyu acar (tepki cubugu + eylem karti)', (tester) async {
      await _pump(tester, build(makeSession(withEmojis())));
      await openMenu(tester, find.text('Selam'));
      expect(find.byKey(card), findsOneWidget);
      expect(find.byKey(bar), findsOneWidget);
      for (final e in _emojis) {
        expect(find.byKey(ValueKey('react-$e')), findsOneWidget);
      }
      expect(find.text('Yanıtla'), findsOneWidget);
      expect(find.text('Kopyala'), findsOneWidget);
      expect(find.text('Düzenle'), findsOneWidget);
      expect(find.text('Herkesten sil'), findsOneWidget);
      expect(find.text('Şikâyet et'), findsNothing);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('metin baloncuguna tek dokunus da menuyu acar', (tester) async {
      await _pump(tester, build(makeSession(withEmojis())));
      await openMenu(tester, find.text('Selam'), tap: true);
      expect(find.byKey(card), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('tepki secimi PUT gonderir ve cubukta vurgulanir; ayni tepki kaldirir', (tester) async {
      final be = withEmojis();
      await _pump(tester, build(makeSession(be)));
      await openMenu(tester, find.text('Selam'));
      expect(find.byKey(const ValueKey('react-😂-on')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('react-😂')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(be.bodies['PUT /messages/2/reaction'], {'emoji': '😂'});
      expect(find.byKey(card), findsNothing);
      expect(find.text('😂 1'), findsOneWidget); // iyimser sayaç baloncukta
      await openMenu(tester, find.text('Selam'));
      expect(find.byKey(const ValueKey('react-😂-on')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('react-😂-on')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(be.requests, contains('DELETE /messages/2/reaction'));
      expect(find.text('😂 1'), findsNothing);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('Kopyala panoya yazar ve Kopyalandi geri bildirimi verir', (tester) async {
      final clip = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clip.add((call.arguments as Map)['text'] as String?);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await _pump(tester, build(makeSession(withEmojis())));
      await openMenu(tester, find.text('Selam'));
      await tester.tap(find.text('Kopyala'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(clip, ['Selam']);
      expect(find.text('Kopyalandı'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('Yanitla yanit cubugunu acar', (tester) async {
      await _pump(tester, build(makeSession(withEmojis())));
      await openMenu(tester, find.text('Merhaba'));
      await tester.tap(find.text('Yanıtla'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(card), findsNothing);
      // Yanıt çubuğu: gönderen adı + alıntı metni (listedeki baloncuk dahil iki 'Merhaba').
      expect(find.text('Ali Veli'), findsWidgets);
      expect(find.text('Merhaba'), findsNWidgets(2));
      expect(find.byTooltip('Vazgeç'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('Duzenle yalniz kendi mesajinda; duzenleme moduna gecer', (tester) async {
      await _pump(tester, build(makeSession(withEmojis())));
      await openMenu(tester, find.text('Merhaba')); // başkasının mesajı
      expect(find.text('Düzenle'), findsNothing);
      expect(find.text('Herkesten sil'), findsNothing);
      expect(find.text('Mesajı sil'), findsNothing); // birebir sohbette yönetici silmesi yok
      expect(find.text('Şikâyet et'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(card), findsNothing);

      await openMenu(tester, find.text('Selam')); // kendi mesajım
      await tester.tap(find.text('Düzenle'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Mesaj düzenleniyor'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Selam');
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('Herkesten sil onay sonrasi DELETE gonderir', (tester) async {
      final be = withEmojis();
      await _pump(tester, build(makeSession(be)));
      await openMenu(tester, find.text('Selam'));
      await tester.tap(find.text('Herkesten sil'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Mesaj silinsin mi?'), findsOneWidget);
      await tester.tap(find.text('Sil'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(be.requests, contains('DELETE /messages/2'));
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('silinmis mesajda menu acilmaz', (tester) async {
      await _pump(tester, build(makeSession(withEmojis())));
      await tester.longPress(find.text('Bu mesaj silindi'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(card), findsNothing);
      expect(find.byKey(bar), findsNothing);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('menu geri tusu ve bos dokunusla kapanir', (tester) async {
      await _pump(tester, build(makeSession(withEmojis())));
      await openMenu(tester, find.text('Selam'));
      expect(find.byKey(card), findsOneWidget);
      await tester.binding.handlePopRoute(); // geri tuşu
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(card), findsNothing);
      expect(find.text('Selam'), findsOneWidget);

      await openMenu(tester, find.text('Selam'));
      expect(find.byKey(card), findsOneWidget);
      await tester.tapAt(const Offset(4, 4)); // boş yere dokunuş
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(card), findsNothing);
      _noErrors(tester);
      await unmount(tester);
    });

    // ------------------------------------------------ sürükleyerek yanıtlama
    testWidgets('saga surukleme yanit cubugunu acar', (tester) async {
      await _pump(tester, build(makeSession(withEmojis())));
      await tester.drag(find.text('Merhaba'), const Offset(100, 0));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byTooltip('Vazgeç'), findsOneWidget);
      expect(find.text('Merhaba'), findsNWidgets(2));
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('sola surukleme ve esik alti birakma yanit acmaz', (tester) async {
      await _pump(tester, build(makeSession(withEmojis())));
      await tester.drag(find.text('Merhaba'), const Offset(-100, 0));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byTooltip('Vazgeç'), findsNothing);
      await tester.drag(find.text('Merhaba'), const Offset(30, 0));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byTooltip('Vazgeç'), findsNothing);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('silinmis mesaj surukleyerek yanitlanmaz; 320 dp tasma yok', (tester) async {
      await _pump(tester, build(makeSession(withEmojis())), size: kPhoneSmall);
      await tester.drag(find.text('Bu mesaj silindi'), const Offset(100, 0));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byTooltip('Vazgeç'), findsNothing);
      await tester.drag(find.text('Selam'), const Offset(100, 0));
      await tester.pump(const Duration(milliseconds: 50));
      _noErrors(tester);
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byTooltip('Vazgeç'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      testWidgets('menu 320x640 tasmadan acilir (${b.name})', (tester) async {
        await _pump(tester, build(makeSession(withEmojis())), b: b, size: kPhoneSmall);
        for (final target in [find.text('Selam'), find.textContaining('Tamamdır'), find.text('Merhaba')]) {
          await openMenu(tester, target);
          _noErrors(tester);
          for (final k in [card, bar]) {
            final r = tester.getRect(find.byKey(k));
            expect(r.left, greaterThanOrEqualTo(0), reason: '$k');
            expect(r.top, greaterThanOrEqualTo(0), reason: '$k');
            expect(r.right, lessThanOrEqualTo(320), reason: '$k');
            expect(r.bottom, lessThanOrEqualTo(640), reason: '$k');
          }
          await tester.tapAt(const Offset(4, 4));
          await settle(tester, const Duration(milliseconds: 400));
          expect(find.byKey(card), findsNothing);
        }
        _noErrors(tester);
        await unmount(tester);
      });
    }
  });

  // ============================================================ NewChatPage
  group('NewChatPage', () {
    FakeBackend full() => FakeBackend()
      ..on('/users/search*', {
        'items': [
          {'id': 11, 'displayName': 'Ali Veli', 'department': 'Bilgisayar Mühendisliği'},
          {'id': 12, 'displayName': _longTitle, 'faculty': _longTitle},
        ],
        'nextCursor': null,
      });

    Future<void> search(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).last, 'al');
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester, const Duration(milliseconds: 400));
    }

    for (final b in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('dolu ${b.name} ${size.width.toInt()}', (tester) async {
          final s = makeSession(full());
          await _pump(tester, NewChatPage(session: s), b: b, size: size);
          expect(find.textContaining('en az 2 karakter'), findsOneWidget);
          await tester.tap(find.text('Yeni grup'));
          await tester.pump();
          await search(tester);
          expect(find.text('Ali Veli'), findsOneWidget);
          await tester.tap(find.text('Ali Veli'));
          await tester.pump();
          await tester.tap(find.text(_longTitle).first);
          await tester.pump();
          expect(find.text('Grubu oluştur'), findsOneWidget);
          _noErrors(tester);
          await unmount(tester);
          _noErrors(tester);
        });
      }
    }

    testWidgets('bos sonuc', (tester) async {
      final be = FakeBackend()..on('/users/search*', {'items': [], 'nextCursor': null});
      await _pump(tester, NewChatPage(session: makeSession(be)));
      await search(tester);
      expect(find.text('Eşleşen kişi bulunamadı.'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('500 -> yeniden dene', (tester) async {
      final be = FakeBackend()..fail('/users/search*');
      await _pump(tester, NewChatPage(session: makeSession(be)), size: kPhoneSmall);
      await search(tester);
      expect(find.text('Yeniden dene'), findsOneWidget);
      be.on('/users/search*', {
        'items': [
          {'id': 11, 'displayName': 'Ali Veli'}
        ]
      });
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Ali Veli'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('ag hatasi', (tester) async {
      final be = FakeBackend()..network('/users/search*');
      await _pump(tester, NewChatPage(session: makeSession(be)));
      await search(tester);
      expect(find.text('Yeniden dene'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('grup adi bos -> hata, yazilirken debounce zamanlayicisi dispose edilir', (tester) async {
      final s = makeSession(full());
      await _pump(tester, NewChatPage(session: s), size: kPhoneSmall);
      await tester.tap(find.text('Yeni grup'));
      await tester.pump();
      await search(tester);
      await tester.tap(find.text('Ali Veli'));
      await tester.pump();
      await tester.tap(find.text(_longTitle).first);
      await tester.pump();
      await tester.tap(find.text('Grubu oluştur'));
      await tester.pump();
      expect(find.text('Grup adı girin.'), findsOneWidget);
      // Bekleyen debounce ile kapat: zamanlayıcı kalmamalı.
      await tester.enterText(find.byType(TextField).last, 'ali');
      await unmount(tester);
      _noErrors(tester);
    });
  });

  // ================================================================ ClubsTab
  group('ClubsTab', () {
    FakeBackend full() => FakeBackend()
      ..on('/communities/categories', [
        {'category': 'Teknoloji'},
        {'category': 'Spor ve Açık Hava Etkinlikleri'},
      ])
      ..on('/communities', {
        'items': [
          _clubItem(1, _longTitle),
          _clubItem(2, 'Satranç', status: 'ACTIVE'),
          _clubItem(3, 'Tiyatro', status: 'PENDING'),
          _clubItem(4, 'Yasaklı', status: 'BANNED'),
        ],
        'nextCursor': null,
      });
    ClubsTab build(Session s) => ClubsTab(session: s);

    _matrix('ClubsTab', full, build, expectFinder: () => find.text('Satranç'));

    testWidgets('yukleniyor -> dolu', (tester) async {
      final be = full()..delay = const Duration(milliseconds: 300);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(build(makeSession(be)), size: kPhoneMedium));
      await tester.pump();
      expect(find.byType(BuSkeleton), findsWidgets); // iskelet (dönen çember yok)
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Satranç'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('bos', (tester) async {
      final be = FakeBackend()..on('/communities', {'items': [], 'nextCursor': null});
      await _pump(tester, build(makeSession(be)));
      expect(find.text('Kulüp bulunamadı.'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('500 -> yeniden dene', (tester) async {
      final be = FakeBackend()..fail('/communities');
      await _pump(tester, build(makeSession(be)));
      expect(find.text('Yeniden dene'), findsOneWidget);
      be.on('/communities', {'items': [_clubItem(2, 'Satranç')]});
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester);
      expect(find.text('Satranç'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('ag hatasi', (tester) async {
      final be = FakeBackend()..network('/communities');
      await _pump(tester, build(makeSession(be)), size: kPhoneSmall);
      expect(find.text('Yeniden dene'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('Kulupler: serit basligi + arama alani', (tester) async {
      await _pump(tester, build(makeSession(full())), size: kPhoneSmall);
      expect(find.text('Kulüplerim'), findsOneWidget); // şerit başlığı
      await tester.tap(find.byTooltip('Ara'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('Katil: acik kulup kaydi', (tester) async {
      final be = full();
      be.on('/communities/1/join', {'status': 'ACTIVE'});
      await _pump(tester, build(makeSession(be)));
      await tester.tap(find.text('Katıl').first);
      await settle(tester, const Duration(milliseconds: 300));
      expect(be.requests, contains('POST /communities/1/join'));
      expect(be.requests, contains('GET /me/communities?size=50')); // şerit yenilenir
      _noErrors(tester);
      await unmount(tester);
    });
  });

  // ============================================================ ClubDetailPage
  group('ClubDetailPage', () {
    FakeBackend full({String status = 'ACTIVE', String? role = 'OWNER'}) => FakeBackend()
      ..on('/communities/7', _club(status: status, role: role))
      ..on('/communities/7/posts*', {
        'items': [
          {
            'id': 1,
            'authorId': 11,
            'authorName': 'Ali Veli',
            'text': 'Toplantı yarın $_longWord',
            'createdAt': _iso(DateTime.now()),
            'pinned': true,
            'canDelete': true,
          },
          {'id': 2, 'authorId': 12, 'authorName': _longTitle, 'text': 'Merhaba', 'createdAt': _iso(DateTime.now())},
        ],
        'nextCursor': null,
      })
      ..on('/communities/7/requests*', {
        'items': [
          {
            'userId': 20,
            'displayName': _longTitle,
            'answers': [
              {'question': 'Neden katılmak istiyorsun?', 'answer': 'Robot yapmak istiyorum $_longWord'}
            ],
          }
        ],
        'nextCursor': null,
      })
      ..on('/communities/7/members*', {
        'items': [
          {'userId': 1, 'displayName': 'Ayşe Yılmaz', 'role': 'OWNER'},
          {'userId': 2, 'displayName': _longTitle, 'role': 'MODERATOR'},
        ],
        'nextCursor': null,
      })
      ..on('/events*', {
        'items': [
          {'id': 5, 'title': _longTitle, 'startsAt': _iso(DateTime.now()), 'location': 'Salon $_longWord'},
        ],
        'nextCursor': null,
      });
    ClubDetailPage build(Session s) => ClubDetailPage(session: s, communityId: 7);

    _matrix('ClubDetail', full, build, expectFinder: () => find.text('Robotik ve Yapay Zekâ Topluluğu'));

    testWidgets('uye olmayan kullanici (Katil)', (tester) async {
      await _pump(tester, build(makeSession(full(status: 'NONE', role: null))), size: kPhoneSmall);
      expect(find.text('Katıl'), findsOneWidget);
      expect(find.text('Kulüp sohbeti'), findsNothing);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('sekmeler: etkinlikler ve uyeler', (tester) async {
      await _pump(tester, build(makeSession(full())), size: kPhoneSmall);
      // Küçük ekranda kapak + kimlik alanı sabit sekme çubuğunu ilk görünümün altına iter: kaydırarak görünür kıl.
      await tester.scrollUntilVisible(find.text('Etkinlikler'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Etkinlikler'));
      await settle(tester, const Duration(milliseconds: 300));
      _noErrors(tester);
      await tester.tap(find.text('Üyeler'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Moderatör'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('yukleniyor -> dolu', (tester) async {
      final be = full()..delay = const Duration(milliseconds: 300);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(build(makeSession(be)), size: kPhoneMedium));
      await tester.pump();
      expect(find.byType(BuSkeleton), findsWidgets); // iskelet (dönen çember yok)
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Robotik ve Yapay Zekâ Topluluğu'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('bos sekme', (tester) async {
      final be = full()..on('/communities/7/posts*', {'items': [], 'nextCursor': null});
      await _pump(tester, build(makeSession(be)));
      expect(find.text('Henüz gönderi yok.'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('500 -> yeniden dene', (tester) async {
      final be = FakeBackend()..fail('/communities/7');
      await _pump(tester, build(makeSession(be)));
      expect(find.text('Yeniden dene'), findsOneWidget);
      final f = full();
      be.on('/communities/7', _club());
      be.on('/communities/7/posts*', {'items': [], 'nextCursor': null});
      expect(f, isNotNull);
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester);
      expect(find.text('Robotik ve Yapay Zekâ Topluluğu'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('ag hatasi', (tester) async {
      final be = FakeBackend()..network('/communities/7');
      await _pump(tester, build(makeSession(be)), size: kPhoneSmall);
      expect(find.text('Yeniden dene'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('gonderi sekmesi hatasi -> yeniden dene', (tester) async {
      final be = full()..fail('/communities/7/posts*');
      await _pump(tester, build(makeSession(be)));
      expect(find.text('Yeniden dene'), findsOneWidget);
      be.on('/communities/7/posts*', {'items': [], 'nextCursor': null});
      await _reveal(tester, find.text('Yeniden dene'));
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester);
      expect(find.text('Henüz gönderi yok.'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });
  });

  // ============================================================== EventsPage
  group('EventsPage', () {
    FakeBackend full() => FakeBackend()
      ..on('/events/calendar*', _calendar(), headers: {'x-truncated': 'true'})
      ..on('/me/events*', {
        'items': [
          {'id': 5, 'title': _longTitle, 'startsAt': _iso(DateTime.now()), 'myRsvp': 'GOING', 'goingCount': 3},
        ],
        'nextCursor': null,
      });
    EventsPage build(Session s) => EventsPage(session: s);

    _matrix('EventsPage', full, build, expectFinder: () => find.textContaining('Bingöl Üniversitesi'));

    testWidgets('yukleniyor -> dolu', (tester) async {
      final be = full()..delay = const Duration(milliseconds: 300);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(build(makeSession(be)), size: kPhoneMedium));
      await tester.pump();
      expect(find.text('Katıldığım etkinlik'), findsNothing); // iskelet gorunur
      expect(find.byType(BuSkeleton), findsWidgets);
      await settle(tester, const Duration(seconds: 2));
      // Resmi öğe artık rozetsiz tek satır (başlık + ok).
      await _reveal(tester, find.text('Resmi duyuru etkinliği'));
      expect(find.text('Katıldığım etkinlik'), findsOneWidget);
      expect(find.text('Resmi duyuru etkinliği'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('bos', (tester) async {
      final be = FakeBackend()..on('/events/calendar*', <Object>[]);
      await _pump(tester, build(makeSession(be)));
      expect(find.text('Bu ay için etkinlik yok.'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('500 -> yeniden dene', (tester) async {
      final be = FakeBackend()..fail('/events/calendar*');
      await _pump(tester, build(makeSession(be)));
      expect(find.text('Yeniden dene'), findsOneWidget);
      be.on('/events/calendar*', _calendar());
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester);
      expect(find.text('Katıldığım etkinlik'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('ag hatasi', (tester) async {
      final be = FakeBackend()..network('/events/calendar*');
      await _pump(tester, build(makeSession(be)), size: kPhoneSmall);
      expect(find.text('Yeniden dene'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('Etkinliklerim sekmesi bos ve hata', (tester) async {
      final be = FakeBackend()
        ..on('/events/calendar*', <Object>[])
        ..on('/me/events*', {'items': [], 'nextCursor': null});
      await _pump(tester, build(makeSession(be)));
      await tester.tap(find.text('Etkinliklerim'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Katılacağın bir etkinlik yok.'), findsOneWidget);
      be.fail('/me/events*');
      await tester.tap(find.text('Geçmiş'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Yeniden dene'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('RSVP: Katil sunucu hatasinda durum degismez, geri alma dugmesi yok', (tester) async {
      final be = full();
      be.fail('/events/5/rsvp');
      await _pump(tester, build(makeSession(be)), size: kPhoneSmall);
      expect(find.text('Katılıyorum'), findsNothing);
      // Küçük ekranda kart düğmesi görünüm dışında kalır: önce görünür kıl.
      await tester.ensureVisible(find.text('Katıl').first);
      await tester.pump();
      await tester.tap(find.text('Katıl').first);
      await settle(tester, const Duration(milliseconds: 300));
      expect(be.requests.any((r) => r.startsWith('PUT /events/5/rsvp')), isTrue);
      expect(find.text('Katıl'), findsWidgets); // hata sonrasi hala katilabilir
      expect(find.text('Vazgeç'), findsNothing);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('ay degistirme ve gun secme', (tester) async {
      await _pump(tester, build(makeSession(full())), size: kPhoneSmall);
      await tester.tap(find.byTooltip('Sonraki ay'));
      await settle(tester, const Duration(milliseconds: 300));
      _noErrors(tester);
      await tester.tap(find.byTooltip('Önceki ay'));
      await settle(tester, const Duration(milliseconds: 300));
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('Yoklama: elle kod girisi (kamera yok) check-in gonderir', (tester) async {
      final be = full();
      be.on('/events/5/check-in', {'present': true});
      await _pump(tester, build(makeSession(be)));
      await tester.tap(find.text('Yoklama'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(QrScanPage), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'bingol-checkin:5.123.abc');
      await tester.tap(find.text('Yoklamayı gönder').last);
      await settle(tester, const Duration(milliseconds: 500));
      expect(be.requests, contains('POST /events/5/check-in'));
      expect(be.bodies['POST /events/5/check-in'], {'code': '5.123.abc'});
      _noErrors(tester);
      await unmount(tester);
    });
  });

  // ========================================================== EventDetailPage
  group('EventDetailPage', () {
    FakeBackend full({String? rsvp = 'GOING', bool manage = true, int? capacity}) => FakeBackend()
      ..on('/events/5', _event(rsvp: rsvp, manage: manage, capacity: capacity))
      ..on('/events/5/attendees/preview', {
        'goingCount': 12,
        'avatars': [
          for (var i = 0; i < 8; i++) {'displayName': 'Kişi $i'},
        ],
      })
      ..on('/events/5/attendees*', {
        'items': [
          {'displayName': 'Ali Veli', 'status': 'GOING'},
          {'displayName': _longTitle, 'status': 'INTERESTED'},
        ],
        'nextCursor': 7,
      })
      ..on('/events/5/attendance', [
        {'present': true},
        {'present': false},
      ])
      ..on('/events/5/checkin-code', {
        'code': '5.123.abc',
        'qrPayload': 'bingol-checkin:5.123.abc',
        'validForSeconds': 30,
        'expiresAt': _iso(DateTime.now().add(const Duration(seconds: 30))),
      })
      ..on('/events/5/my-attendance', {'present': false, 'checkInOpen': true});
    EventDetailPage build(Session s) => EventDetailPage(session: s, eventId: 5);

    _matrix('EventDetail yonetici', () => full(), build, expectFinder: () => find.text(_longTitle));
    _matrix('EventDetail katilimci', () => full(manage: false), build, expectFinder: () => find.text(_longTitle));

    testWidgets('yukleniyor -> dolu', (tester) async {
      final be = full(manage: false, rsvp: null)..delay = const Duration(milliseconds: 300);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(build(makeSession(be)), size: kPhoneMedium));
      await tester.pump();
      expect(find.byType(BuSkeleton), findsWidgets); // iskelet (dönen çember yok)
      await settle(tester, const Duration(seconds: 2));
      expect(find.text(_longTitle), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('404 -> bulunamadi', (tester) async {
      final be = FakeBackend()..fail('/events/5', status: 404, code: 'NOT_FOUND');
      await _pump(tester, build(makeSession(be)));
      expect(find.text('Etkinlik bulunamadı'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('500 -> yeniden dene', (tester) async {
      final be = FakeBackend()..fail('/events/5');
      await _pump(tester, build(makeSession(be)));
      expect(find.text('Yeniden dene'), findsOneWidget);
      be.on('/events/5', _event());
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester);
      expect(find.text(_longTitle), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('ag hatasi', (tester) async {
      final be = FakeBackend()..network('/events/5');
      await _pump(tester, build(makeSession(be)), size: kPhoneSmall);
      expect(find.text('Yeniden dene'), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('kontenjan dolu uyarisi', (tester) async {
      final be = full(rsvp: null, manage: false, capacity: 8);
      await _pump(tester, build(makeSession(be)), size: kPhoneSmall);
      expect(find.textContaining('Kontenjan doldu'), findsWidgets);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('elle yoklama kodu', (tester) async {
      final be = full(manage: false);
      be.on('/events/5/check-in', {'present': true});
      await _pump(tester, build(makeSession(be)), size: kPhoneSmall);
      await _reveal(tester, find.text('Kodu elle gir'));
      await tester.tap(find.text('Kodu elle gir'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '5.123.abc');
      await _reveal(tester, find.text('Yoklamayı gönder'));
      await tester.tap(find.text('Yoklamayı gönder'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(be.requests, contains('POST /events/5/check-in'));
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('RSVP hatasi geri alinir', (tester) async {
      final be = full(rsvp: null, manage: false);
      be.fail('/events/5/rsvp');
      await _pump(tester, build(makeSession(be)), size: kPhoneSmall);
      await tester.tap(find.text('Katıl'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Etkinliklerimde'), findsNothing);
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('yonetici: sayfa kapaninca kod zamanlayicisi iptal edilir', (tester) async {
      await _pump(tester, build(makeSession(full())), size: kPhoneMedium);
      expect(find.text('Yoklama kodu'), findsOneWidget);
      await unmount(tester); // bekleyen 27 sn'lik Timer kalmamalı
      _noErrors(tester);
    });

    testWidgets('sayfa yuklenirken kapatilirsa setState hatasi olmaz', (tester) async {
      final be = full()..delay = const Duration(milliseconds: 400);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(build(makeSession(be)), size: kPhoneMedium));
      await tester.pump(const Duration(milliseconds: 450)); // /events/5 geldi, ek veriler yolda
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      _noErrors(tester);
    });
  });

  // ============================================================== QrScanPage
  group('QrScanPage', () {
    for (final b in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('elle giris yedegi ${b.name} ${size.width.toInt()}', (tester) async {
          await _pump(tester, const QrScanPage(), b: b, size: size);
          expect(find.text('Kodu elle gir'), findsWidgets);
          _noErrors(tester);
          await unmount(tester);
          _noErrors(tester);
        });
      }
    }

    testWidgets('elle girilen kod geri doner', (tester) async {
      String? result;
      useScreen(tester, kPhoneSmall);
      await tester.pumpWidget(buildApp(
        Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await Navigator.push<String>(c, MaterialPageRoute(builder: (_) => const QrScanPage()));
                },
                child: const Text('ac'),
              ),
            ),
          ),
        ),
        size: kPhoneSmall,
      ));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.enterText(find.byType(TextField).last, '  KOD-42 ');
      await tester.tap(find.text('Yoklamayı gönder'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(result, 'KOD-42');
      _noErrors(tester);
      await unmount(tester);
    });

    testWidgets('bos kod kabul edilmez', (tester) async {
      await _pump(tester, const QrScanPage(), size: kPhoneSmall);
      await tester.tap(find.text('Yoklamayı gönder'));
      await tester.pump();
      expect(find.byType(QrScanPage), findsOneWidget);
      _noErrors(tester);
      await unmount(tester);
    });
  });

  test('ApiError ag hatasi metni', () {
    expect(errorText(ApiError(0, 'NETWORK', '')), contains('Sunucuya ulaşılamadı'));
  });
}
