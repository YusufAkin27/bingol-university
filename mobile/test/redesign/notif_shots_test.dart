@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/push/push_banner.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Bildirim tasarimi (uygulama ici serit + liste) ekran goruntuleri.
/// Varsayilan `flutter test` ile CALISMAZ (STORE_SHOTS_OUT yoksa atlanir). Uretim (C:\bu_notif icinde):
///   STORE_SHOTS_OUT='C:/.../notif' flutter test test/redesign/notif_shots_test.dart
const _dpr = 2.0;

String _iso(Duration ago) => DateTime.now().subtract(ago).toIso8601String();

FakeBackend _be() => FakeBackend()
  ..on('/notifications', {
    'unreadCount': 2,
    'nextCursor': null,
    'items': [
      {'id': 1, 'type': 'FOLLOW_REQUEST', 'title': 'Can Öztürk', 'body': 'Sana takip isteği gönderdi.', 'read': false, 'createdAt': _iso(const Duration(minutes: 12)), 'data': {'senderId': '33', 'senderName': 'Can Öztürk'}},
      {'id': 2, 'type': 'SYSTEM', 'subtype': 'NEW_DEVICE_LOGIN', 'title': 'Yeni cihazdan giriş', 'body': 'Samsung Galaxy S24 · 09:41 tarihinde oturum açıldı', 'read': false, 'createdAt': _iso(const Duration(minutes: 45))},
      {'id': 3, 'type': 'ANNOUNCEMENT', 'subtype': 'ACADEMIC_ANNOUNCEMENT', 'title': 'Akademik duyuru', 'body': 'Öğrenci İşleri Daire Başkanlığı ek kontenjan kılavuzunu paylaştı.', 'read': true, 'createdAt': _iso(const Duration(minutes: 70))},
      {'id': 4, 'type': 'ANNOUNCEMENT', 'subtype': 'MENU_DAILY', 'title': 'Yemekhane Menüsü', 'body': 'Dünün menüsü arşivlendi: Mercimek Çorbası, Orman Kebabı, Pilav.', 'read': true, 'createdAt': _iso(const Duration(days: 1, hours: 2))},
      {'id': 5, 'type': 'EVENT', 'subtype': 'EVENT_ADMISSION', 'title': 'Başvurunuz onaylandı', 'body': 'Takım başvurunuz jüri kurulu tarafından onaylandı.', 'read': true, 'createdAt': _iso(const Duration(days: 1, hours: 5))},
    ],
  });

PushBannerCenter? _center;

Widget _app(Widget home, bool dark, GlobalKey key) => RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: rootNavigatorKey,
        theme: BuTheme.light(),
        darkTheme: BuTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    );

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;

  setUpAll(() async {
    mockSecureStorage();
    await loadTestFonts();
  });

  for (final dark in [false, true]) {
    for (final scene in ['liste', 'serit']) {
      final name = 'notif_${scene}_${dark ? 'koyu' : 'acik'}';
      testWidgets(name, skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = const Size(390 * _dpr, 844 * _dpr);
        tester.view.padding = const FakeViewPadding(top: 24 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 24 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(_app(NotificationsPage(session: makeSession(_be())), dark, key));
        await settle(tester, const Duration(milliseconds: 900));
        if (scene == 'serit') {
          final c = _center = PushBannerCenter(duration: const Duration(hours: 1));
          c.show(BannerItem(key: 'conv-1', title: 'Ayşe Yılmaz', body: 'Yarınki derse geliyor musun?', data: const {'conversationId': '1'}), onTap: (_) {});
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));
          // Tasarım 08'deki üç şerit yan yana değil; yalnız en üsttekini gösterir (aynı anda tek şerit kuralı).
        }
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: _dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          final f = File('${dir.path}/$name.png')..writeAsBytesSync(data.buffer.asUint8List());
          // ignore: avoid_print
          print('YAZILDI ${f.path} ${image.width}x${image.height}');
        });
        _center?.hide();
        _center = null;
        await unmount(tester);
        await tester.pump(const Duration(seconds: 2));
        tester.takeException();
      });
    }
  }
}
