@Tags(['store-shots'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/realtime/chat_realtime.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// K6 ekran goruntuleri: sohbet baslik ve yazma alani (Stitch grup 20).
/// Varsayilan `flutter test`te ATLANIR. Uretim:
///   STORE_SHOTS_OUT='C:/Users/Toprak Çevik/bu-release/redesign/k6/uygulama' flutter test test/redesign/k6_shots_test.dart
/// Istege bagli: K6_LANG=tr|en|ar, K6_MODES=light,dark,x13, K6_ONLY=01,03
const _dpr = 1.0;
final _w = double.tryParse(Platform.environment['K6_W'] ?? '') ?? 390;
String _lang = 'tr';

String _iso(DateTime d) => d.toUtc().toIso8601String();

DateTime _today(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

Map<String, dynamic> _m(int id, int sender, String text, DateTime at, {Map<String, dynamic>? extra}) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': _iso(at),
      ...?extra,
    };

class _TypingRt extends ChatRealtime {
  _TypingRt(super.session);
  final ctl = StreamController<TypingEvent>.broadcast();
  @override
  Stream<TypingEvent> get typing => ctl.stream;
}

class _Sc {
  _Sc(this.file, this.conv,
      {this.msgs = const [],
      this.members = const [],
      this.presence = const {'online': true},
      this.typing = false,
      this.after});
  final String file;
  final Map<String, dynamic> conv;
  final List<Map<String, dynamic>> msgs;
  final List<Map<String, dynamic>> members;
  final Map<String, dynamic> presence;
  final bool typing;
  final Future<void> Function(WidgetTester t)? after;
}

Map<String, dynamic> _direct(String name, {int pid = 11, bool blocked = false}) => {
      'id': 1,
      'type': 'DIRECT',
      'title': name,
      'blocked': blocked,
      'peer': {'id': pid, 'displayName': name},
    };

Future<void> _tapMenu(WidgetTester t, String item) async {
  await t.tap(find.byIcon(LucideIcons.ellipsisVertical));
  await settle(t, const Duration(milliseconds: 500));
  await t.tap(find.text(item));
  await settle(t, const Duration(milliseconds: 500));
}

Future<void> _longPressAct(WidgetTester t, String text, String act) async {
  await t.longPress(find.text(text));
  await settle(t, const Duration(milliseconds: 500));
  await t.tap(find.byKey(ValueKey('act-$act')));
  await settle(t, const Duration(milliseconds: 500));
}

final _scenarios = <_Sc>[
  _Sc('01_baslik_yaziyor', _direct('Elif Yıldız'), typing: true, msgs: [
    _m(2, 1, 'Şimdi gördüm Elif, çok teşekkürler! 3. sayfadaki formül için kütüphanede misin?', _today(14, 19)),
    _m(1, 11, 'Ders notlarını laboratuvar panosuna astım, bakabildin mi?', _today(14, 18)),
  ]),
  _Sc('01b_baslik_cevrimici', _direct('Elif Yıldız'), msgs: [
    _m(1, 11, 'Ders notlarını laboratuvar panosuna astım, bakabildin mi?', _today(14, 18)),
  ]),
  _Sc('01c_baslik_son_gorulme', _direct('Elif Yıldız'), presence: {
    'online': false,
    'lastSeenAt': _iso(_today(14, 20)),
  }, msgs: [
    _m(1, 11, 'Ders notlarını laboratuvar panosuna astım, bakabildin mi?', _today(14, 18)),
  ]),
  _Sc('02_kulup_odasi', {
    'id': 1,
    'type': 'CLUB',
    'title': 'Robotik Kulübü',
    'communityId': 5,
    'memberCount': 86,
  }, members: [
    {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
    {'userId': 11, 'displayName': 'Alperen Kurt'},
    {'userId': 12, 'displayName': 'Seda Yılmaz'},
    {'userId': 13, 'displayName': 'Berkay Demir'},
  ], msgs: [
    _m(4, 13, "Akşam 18:00'de atölyede buluşup devre kartlarını lehimleyelim.", _today(11, 42)),
    _m(3, 1, "Harika haber! Ben de kod reposunu güncelledim, pull request'i onaylayabilirsiniz.", _today(11, 40)),
    _m(2, 12, 'Görüntü işleme algoritması test edildi, ilk deneme başarılı!', _today(11, 34)),
    _m(1, 11, 'TÜBİTAK projesinin mekanik parçaları atölyeye teslim edildi, montaja başlıyoruz.', _today(11, 30)),
  ]),
  _Sc('03_etkinlik_odasi', {
    'id': 1,
    'type': 'EVENT',
    'title': 'Bahar Şenliği',
    'eventId': 7,
    'memberCount': 42,
  }, members: [
    {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
    {'userId': 11, 'displayName': 'Caner Öz'},
    {'userId': 12, 'displayName': 'Melis Koç'},
  ], msgs: [
    _m(3, 1, "Program akışına göre prova 14.30'da başlıyor. Sahne arkası girişinden alınacak.", _today(10, 25)),
    _m(2, 12, 'Akustik prova saat kaçta planlandı?', _today(10, 20)),
    _m(1, 11, "Konser sahne kurulumu amfi tiyatroda saat 10.00'da başlayacak. Görevli arkadaşlar alanda olsun lütfen.",
        _today(9, 15).subtract(const Duration(days: 1))),
  ]),
  _Sc('04_arama_eslesme', _direct('Ali Kaya'), msgs: [
    _m(3, 11, 'Harika. Geçen haftaki kütüphane sunumunu da inceledim, kaynakça tam istediğin gibi.', _today(14, 35)),
    _m(2, 1, 'Tamamdır, kütüphane girişinde bekliyorum.', _today(14, 32)),
    _m(1, 11, 'Selam! Yarın kütüphane 3. katta buluşalım, notları getireceğim.', _today(14, 30)),
  ], after: (t) async {
    await _tapMenu(t, lookupAppLocalizations(Locale(_lang)).chatDetailSearchInChat);
    await t.enterText(find.byKey(const ValueKey('chatSearchField')), 'kütüphane');
    await settle(t, const Duration(milliseconds: 600));
  }),
  _Sc('04b_arama_bos', _direct('Ali Kaya'), msgs: [
    _m(1, 11, 'Selam! Yarın kütüphane 3. katta buluşalım.', _today(14, 30)),
  ], after: (t) async {
    await _tapMenu(t, lookupAppLocalizations(Locale(_lang)).chatDetailSearchInChat);
    await settle(t, const Duration(milliseconds: 300));
  }),
  _Sc('04c_arama_eslesme_yok', _direct('Ali Kaya'), msgs: [
    _m(1, 11, 'Selam! Yarın kütüphane 3. katta buluşalım.', _today(14, 30)),
  ], after: (t) async {
    await _tapMenu(t, lookupAppLocalizations(Locale(_lang)).chatDetailSearchInChat);
    await t.enterText(find.byKey(const ValueKey('chatSearchField')), 'xyz');
    await settle(t, const Duration(milliseconds: 600));
  }),
  _Sc('05_yanit_seridi', _direct('Mehmet Kaya'), msgs: [
    _m(3, 11, 'Yarın sınav kaçta? Hoca duyuru yaptı mı?', _today(14, 38)),
    _m(2, 1, 'Selam Mehmet, şimdi yükledim sisteme. Girişte buluşuruz o halde.', _today(14, 35)),
    _m(1, 11, 'Selam! Kütüphaneden çıktın mı? Ders notlarını gönderecektin.', _today(14, 32)),
  ], after: (t) async {
    await _longPressAct(t, 'Yarın sınav kaçta? Hoca duyuru yaptı mı?', 'reply');
    await t.enterText(find.byKey(const ValueKey('composerField')), "Saat 10.00'da Mühendislik Binası 204'te");
    await settle(t, const Duration(milliseconds: 300));
  }),
  _Sc('05b_duzenleme_seridi', _direct('Mehmet Kaya'), msgs: [
    _m(2, 1, 'Selam Mehmet, şimdi yükledim sisteme. Girişte buluşuruz o halde.', _today(14, 35)),
    _m(1, 11, 'Selam! Kütüphaneden çıktın mı? Ders notlarını gönderecektin.', _today(14, 32)),
  ], after: (t) async {
    await _longPressAct(t, 'Selam Mehmet, şimdi yükledim sisteme. Girişte buluşuruz o halde.', 'edit');
  }),
  _Sc('06_bos_sohbet', _direct('Ahmet Yılmaz')),
  _Sc('06b_engelli', _direct('Ahmet Yılmaz', blocked: true), msgs: [
    _m(1, 11, 'Selam!', _today(14, 30)),
  ]),
];

Widget _app(Widget home, bool dark, GlobalKey key, double scale) => RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: BuTheme.forLocale(Brightness.light, _lang),
        darkTheme: BuTheme.forLocale(Brightness.dark, _lang),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(_lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    );

Future<void> _loadFonts(bool arabic) async {
  if (!arabic) return loadTestFonts();
  final f = FontLoader('Inter');
  for (final n in ['arial.ttf', 'arialbd.ttf']) {
    final file = File('C:/Windows/Fonts/$n');
    if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await f.load();
  await loadIconFonts();
}

FakeBackend _backend(_Sc s) {
  final pid = (s.conv['peer'] as Map?)?['id'];
  final b = FakeBackend()
    ..on('/conversations/1/messages?size=30', {'items': s.msgs, 'nextCursor': null})
    ..on('/conversations/1', {
      'conversation': {'id': 1},
      'members': s.members.isNotEmpty
          ? s.members
          : [
              {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
              if (pid != null) {'userId': pid, 'displayName': (s.conv['peer'] as Map)['displayName']},
            ],
    })
    ..on('/messages/reactions', {'emojis': ['👍', '❤️']});
  if (pid != null) b.on('/users/$pid/presence', s.presence);
  return b;
}

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = Platform.environment['K6_LANG'] ?? 'tr';
  final only = (Platform.environment['K6_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['K6_MODES'] ?? 'light').split(',');
  final variants = <(String, bool, double)>[
    if (modes.contains('light')) ('', false, 1.0),
    if (modes.contains('dark')) ('_koyu', true, 1.0),
    if (modes.contains('x13')) ('_x1.3', false, 1.3),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final sc in _scenarios) {
      if (only.isNotEmpty && !only.any((o) => sc.file.startsWith(o))) continue;
      final name = '${sc.file}${v.$1}_$_lang${_w == 390 ? '' : '_w${_w.toInt()}'}';
      testWidgets('k6 $name', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(_w * _dpr, 844 * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);

        final s = makeSession(_backend(sc));
        final rt = _TypingRt(s);
        final key = GlobalKey();
        await tester.pumpWidget(_app(
            ChatDetailPage(
              session: s,
              conversation: sc.conv,
              connectRealtime: false,
              realtime: rt,
            ),
            v.$2,
            key,
            v.$3));
        await settle(tester, const Duration(milliseconds: 800));
        if (sc.typing) {
          rt.ctl.add(TypingEvent(1, (sc.conv['peer'] as Map)['id'] as int));
          await settle(tester, const Duration(milliseconds: 300));
        }
        if (sc.after != null) await sc.after!(tester);
        for (var i = 0; i < 3; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
          await settle(tester, const Duration(milliseconds: 200));
        }
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: _dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          File('${dir.path}/$name.png').writeAsBytesSync(data.buffer.asUint8List());
        });
        await unmount(tester);
        unawaited(rt.ctl.close());
      });
    }
  }
}
