import 'dart:convert';
import 'dart:io';

import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_info_page.dart';
import 'package:bu_kampus/features/chat/chat_security_page.dart';
import 'package:bu_kampus/features/profile/legal_pages.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

/// Sohbet güvenliği: konuşma başındaki "mesajların şifreli" bildirimi, "Sohbet güvenliği" sayfası, bilgi sayfası satırı.
///
/// DÜRÜSTLÜK DENETİMİ: uygulama uçtan uca şifreli DEĞİLDİR (docs/ENCRYPTION.md). Metinler bu iddiayı yapamaz; yalnızca
/// "değildir / not / غير" gibi olumsuz bağlamda anılabilir.

Map<String, dynamic> _msg(int id, int sender, String text, int minAgo) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': DateTime.now().subtract(Duration(minutes: minAgo)).toUtc().toIso8601String(),
      'attachments': const [],
      'reactions': const [],
    };

FakeBackend _backend({bool empty = false, bool cursor = false}) => FakeBackend()
  ..on('/conversations/1/messages*', {
    'items': empty
        ? <Map<String, dynamic>>[]
        : [
            _msg(3, 11, 'Yarınki sınav için kaynakları gördün mü?', 3),
            _msg(2, 1, 'Merhaba, yarın derste görüşelim mi?', 50),
            _msg(1, 11, 'Günaydın.', 1500),
          ],
    'nextCursor': cursor ? 1 : null,
  })
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Ali Veli'},
    ],
  })
  ..on('/users/11/presence', {'online': false})
  ..on('/messages/reactions', {'emojis': <String>[]});

const _dm = {
  'id': 1,
  'type': 'DIRECT',
  'title': 'Ali Veli',
  'peer': {'id': 11, 'displayName': 'Ali Veli'},
};
const _group = {'id': 1, 'type': 'GROUP', 'title': 'Proje Grubu', 'memberCount': 3};
const _club = {'id': 1, 'type': 'CLUB', 'title': 'Satranç Kulübü', 'communityId': 5, 'memberCount': 3};
const _event = {'id': 1, 'type': 'EVENT', 'title': 'Bahar Şenliği', 'eventId': 7, 'memberCount': 3};

ChatDetailPage _detail(FakeBackend be, Map<String, dynamic> conv) => ChatDetailPage(
      session: makeSession(be),
      connectRealtime: false,
      conversation: conv,
    );

Future<void> _pumpDetail(WidgetTester tester, Map<String, dynamic> conv,
    {FakeBackend? be, Size size = const Size(390, 3200), String lang = 'tr', bool dark = false, double scale = 1.0}) async {
  useScreen(tester, size);
  await tester.pumpWidget(p00App(_detail(be ?? _backend(), conv), lang: lang, dark: dark, scale: scale, scaffold: false));
  await settle(tester, const Duration(milliseconds: 600));
}

final _notice = find.byKey(const ValueKey('chatEncryptionNotice'));
final _lock = find.byKey(const ValueKey('chatSecurityLock'));

void main() {
  setUpAll(loadTestFonts);

  group('konuşma başındaki bildirim', () {
    final cases = <(String, Map<String, dynamic>, String)>[
      ('birebir', _dm, 'Mesajların aktarım sırasında ve sunucuda şifrelenir.'),
      ('grup', _group, 'Bu sohbetteki mesajlar'),
      ('kulüp odası', _club, 'Bu odadaki mesajlar'),
      ('etkinlik odası', _event, 'Bu odadaki mesajlar'),
    ];
    for (final c in cases) {
      testWidgets('${c.$1}: görünür, en üstte, doğru alt metin', (tester) async {
        await _pumpDetail(tester, c.$2);
        expect(_notice, findsOneWidget);
        expect(find.textContaining(c.$3, findRichText: true), findsOneWidget);
        expect(find.textContaining('Daha fazla bilgi', findRichText: true), findsOneWidget);
        // Mesajların ve gün hapının üstünde.
        final nTop = tester.getTopLeft(_notice).dy;
        final firstMsg = tester.getTopLeft(find.text('Günaydın.')).dy;
        expect(nTop, lessThan(firstMsg));
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }

    testWidgets('grup/oda metni üyelerin görebildiğini söyler; birebirde söylemez', (tester) async {
      await _pumpDetail(tester, _group);
      expect(find.textContaining('tüm üyeler görebilir', findRichText: true), findsOneWidget);
      await unmount(tester);
      await _pumpDetail(tester, _dm);
      expect(find.textContaining('tüm üyeler', findRichText: true), findsNothing);
      await unmount(tester);
    });

    testWidgets('boş konuşmada da görünür', (tester) async {
      await _pumpDetail(tester, _dm, be: _backend(empty: true), size: kPhoneMedium);
      expect(_notice, findsOneWidget);
      await unmount(tester);
    });

    testWidgets('daha eski sayfa varken (imleç) en üstte değildir; gösterilmez', (tester) async {
      await _pumpDetail(tester, _dm, be: _backend(cursor: true));
      expect(_notice, findsNothing);
      await unmount(tester);
    });

    testWidgets('dokununca sohbet güvenliği sayfası açılır; geri dönünce konuşma sağlam', (tester) async {
      await _pumpDetail(tester, _dm, size: kPhoneMedium);
      await tester.ensureVisible(_notice);
      await tester.tap(_notice);
      await settle(tester, const Duration(milliseconds: 600));
      expect(_lock, findsOneWidget);
      expect(find.byType(ChatSecurityPage), findsOneWidget);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.pop();
      await settle(tester, const Duration(milliseconds: 600));
      expect(_lock, findsNothing);
      expect(find.byType(ChatDetailPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('dokunma hedefi >= 48 dp ve anlamsal düğme etiketi', (tester) async {
      await _pumpDetail(tester, _dm, size: kPhoneMedium);
      expect(tester.getSize(_notice).height, greaterThanOrEqualTo(48));
      final h = tester.ensureSemantics();
      final sem = tester.getSemantics(find.descendant(of: find.ancestor(of: _notice, matching: find.byType(Semantics)).first, matching: find.byType(Material)).first);
      expect(sem.label, contains('Mesajların aktarım sırasında'));
      expect(sem.label, contains('Daha fazla bilgi'));
      h.dispose();
      await unmount(tester);
    });

    for (final lang in ['tr', 'en', 'ar']) {
      for (final dark in [false, true]) {
        for (final w in [320.0, 390.0]) {
          for (final scale in [1.0, 1.3]) {
            testWidgets('$lang ${dark ? 'koyu' : 'açık'} $w dp x$scale: taşma yok (grup, oda)', (tester) async {
              for (final conv in [_group, _club]) {
                await _pumpDetail(tester, conv, size: Size(w, 900), lang: lang, dark: dark, scale: scale);
                expect(_notice, findsOneWidget);
                expect(tester.takeException(), isNull);
                await unmount(tester);
              }
            });
          }
        }
      }
    }
  });

  group('sohbet güvenliği sayfası', () {
    Future<void> pumpPage(WidgetTester tester, {String lang = 'tr', bool dark = false, double scale = 1.0, double w = 390}) async {
      useScreen(tester, Size(w, 4200));
      await tester.pumpWidget(p00App(ChatSecurityPage(session: makeSession(FakeBackend())), lang: lang, dark: dark, scale: scale, scaffold: false));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('büyük kilit, doğrulanmış maddeler ve dürüst bölüm var', (tester) async {
      await pumpPage(tester);
      expect(_lock, findsOneWidget);
      for (final s in [
        'Mesajların şifreli',
        'Aktarım sırasında şifreli',
        'Sunucuda şifreli saklama',
        'Yönetici erişimi kayıt altında',
        'Engelle ve şikâyet et',
        'Tek gösterimlik fotoğraf',
        'Mesajı herkes için sil',
        'Fotoğraflardan konum temizlenir',
        'Verilerin sende',
        'Bilmen gerekenler',
        'Uçtan uca şifreli değildir',
        'Silinen içerik saklanabilir',
        'Ekran görüntüsü engellenemez',
        'Gizlilik Politikası',
        'Topluluk Kuralları',
      ]) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      // Yer tutucular gerçek eylem adlarıyla doldu.
      expect(find.textContaining('Şikâyet et seçeneğine dokun'), findsOneWidget);
      expect(find.textContaining('Engelle veya Kullanıcıyı şikâyet et'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yasak iddia yok: ekranda "uçtan uca" yalnız olumsuz bağlamda, "kimse okuyamaz" yok', (tester) async {
      await pumpPage(tester);
      final texts = tester.widgetList<Text>(find.byType(Text)).map((e) => e.data ?? e.textSpan?.toPlainText() ?? '').toList();
      for (final s in texts) {
        final low = s.toLowerCase();
        if (low.contains('uçtan uca')) expect(low, contains('değildir'), reason: s);
        expect(low, isNot(contains('kimse okuyamaz')));
        expect(low, isNot(contains('yalnızca siz')));
      }
      await unmount(tester);
    });

    testWidgets('Gizlilik Politikası satırı sözleşme sayfasını açar (>= 48 dp)', (tester) async {
      final be = FakeBackend()..on('/legal/PRIVACY', {'type': 'PRIVACY', 'title': 'Gizlilik Politikası', 'version': 3, 'content': 'x'});
      useScreen(tester, const Size(390, 4200));
      await tester.pumpWidget(p00App(ChatSecurityPage(session: makeSession(be)), scaffold: false));
      await tester.pump(const Duration(milliseconds: 400));
      final row = find.byKey(const ValueKey('chatSecPrivacy'));
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      await tester.tap(row);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(LegalDocPage), findsOneWidget);
      await unmount(tester);
    });

    for (final lang in ['tr', 'en', 'ar']) {
      for (final dark in [false, true]) {
        for (final w in [320.0, 390.0]) {
          for (final scale in [1.0, 1.3]) {
            testWidgets('$lang ${dark ? 'koyu' : 'açık'} $w dp x$scale: taşma yok', (tester) async {
              await pumpPage(tester, lang: lang, dark: dark, scale: scale, w: w);
              expect(_lock, findsOneWidget);
              expect(tester.takeException(), isNull);
              await unmount(tester);
            });
          }
        }
      }
    }
  });

  group('sohbet bilgisi satırı', () {
    Future<void> pumpInfo(WidgetTester tester, Map<String, dynamic> conv, {String lang = 'tr', double w = 390, double scale = 1.0}) async {
      final be = FakeBackend()
        ..on('/conversations/1', {'conversation': conv, 'members': <Map<String, dynamic>>[]})
        ..on('/conversations/1/media*', {'items': <Map<String, dynamic>>[], 'nextCursor': null});
      useScreen(tester, Size(w, 1400));
      await tester.pumpWidget(p00App(
          ChatInfoPage(session: makeSession(be), conversation: Map.of(conv), members: const [
            {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
            {'userId': 11, 'displayName': 'Ali Veli'},
          ]),
          lang: lang,
          scale: scale,
          scaffold: false));
      await tester.pump(const Duration(milliseconds: 600));
    }

    for (final c in <(String, Map<String, dynamic>)>[('birebir', _dm), ('grup', _group), ('kulüp odası', _club), ('etkinlik odası', _event)]) {
      testWidgets('${c.$1}: "Şifreleme ve güvenlik" satırı güvenlik sayfasını açar', (tester) async {
        await pumpInfo(tester, c.$2);
        final row = find.byKey(const ValueKey('info-security'));
        expect(row, findsOneWidget);
        expect(find.text('Şifreleme ve güvenlik'), findsOneWidget);
        expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
        await tester.ensureVisible(row);
        await tester.tap(row);
        await settle(tester, const Duration(milliseconds: 600));
        expect(find.byType(ChatSecurityPage), findsOneWidget);
        expect(_lock, findsOneWidget);
        await unmount(tester);
      });
    }

    for (final lang in ['en', 'ar']) {
      testWidgets('$lang 320 dp x1.3: satır taşmaz', (tester) async {
        await pumpInfo(tester, _group, lang: lang, w: 320, scale: 1.3);
        expect(find.byKey(const ValueKey('info-security')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  });

  group('metin denetimi (ARB)', () {
    // chatEnc* anahtarları: "uçtan uca" iddiası yalnız olumsuz bağlamda geçebilir; kesin güvence ifadeleri yasak.
    final dir = Directory('lib/l10n');
    final langs = {
      'tr': (RegExp(r'u[çc]tan uca', caseSensitive: false), RegExp(r'de[ğg]ildir')),
      'en': (RegExp(r'end[- ]to[- ]end', caseSensitive: false), RegExp(r'\bnot\b', caseSensitive: false)),
      'ar': (RegExp('من طرف إلى طرف'), RegExp('غير')),
    };
    final banned = <Pattern>[
      RegExp('kimse okuyamaz', caseSensitive: false),
      RegExp('yalnızca (siz|sen)', caseSensitive: false),
      RegExp('bizim dahil', caseSensitive: false),
      RegExp('nobody (can|else can) read', caseSensitive: false),
      RegExp(r'not even (we|us)', caseSensitive: false),
      RegExp(r'only you (and|can)', caseSensitive: false),
      RegExp('وحدك'),
      RegExp('military', caseSensitive: false),
    ];
    for (final e in langs.entries) {
      test('${e.key}: chatEnc* metinlerinde E2EE iddiası yok', () {
        final map = jsonDecode(File('${dir.path}/app_${e.key}.arb').readAsStringSync()) as Map<String, dynamic>;
        final keys = map.keys.where((k) => k.startsWith('chatEnc') && !k.startsWith('@')).toList();
        expect(keys.length, greaterThan(40));
        var negated = 0;
        for (final k in keys) {
          final v = map[k] as String;
          if (e.value.$1.hasMatch(v)) {
            expect(e.value.$2.hasMatch(v), isTrue, reason: '$k: "uçtan uca" yalnız olumsuz bağlamda anılabilir -> $v');
            negated++;
          }
          for (final b in banned) {
            expect(v.contains(b), isFalse, reason: '$k yasak ifade içeriyor: $v');
          }
        }
        expect(negated, greaterThanOrEqualTo(1), reason: 'dürüst "uçtan uca değil" maddesi bulunmalı');
      });
    }

    test('üç dilde aynı anahtar kümesi', () {
      Set<String> keys(String l) =>
          (jsonDecode(File('${dir.path}/app_$l.arb').readAsStringSync()) as Map<String, dynamic>).keys.where((k) => k.startsWith('chatEnc') && !k.startsWith('@')).toSet();
      expect(keys('en'), keys('tr'));
      expect(keys('ar'), keys('tr'));
    });

    test('yerelleştirme sınıfı üç dili üretir', () {
      for (final code in ['tr', 'en', 'ar']) {
        final l = lookupAppLocalizations(Locale(code));
        expect(l.chatEncHelpMessage('X'), contains('X'));
        expect(l.chatEncHelpPerson('A', 'B'), allOf(contains('A'), contains('B')));
      }
    });
  });
}
