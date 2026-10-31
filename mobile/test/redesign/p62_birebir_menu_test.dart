import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/menu/menu_parts.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// MENU grubu Stitch v3 BIREBIR olcu testi (390 x 844, tr). Referans degerler `C:\bu_design\stitch\v3_home`
/// PNG'lerinden (706 px genislik -> 390 dp, olcek 1.8103) ve `_kaynak_html` Tailwind degerlerinden alindi.
/// Her satir: referans dp, uygulama dp; fark <= 2 dp olmali (BuHeader ortak parca oldugundan dikey konumlar
/// baslik dairesinin ustune gore goreli verilir). Cikti: `flutter test ... --reporter expanded` ile okunur
/// ve docs/design/BIREBIR_MENU.md tablosuna yazilir.
final _fails = <String>[];

void _row(String name, double ref, double impl, {double tol = 2}) {
  final d = impl - ref;
  // ignore: avoid_print
  print('BIREBIR | $name | ${ref.toStringAsFixed(1)} | ${impl.toStringAsFixed(1)} | ${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)}');
  if (d.abs() > tol) _fails.add('$name ref=$ref impl=$impl');
}

String _d(int o) {
  final n = DateTime.now().add(Duration(days: o));
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

Future<void> _mount(WidgetTester tester, Widget home) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
  addTearDown(() => LocaleController.current = null);
  await tester.pumpWidget(buildApp(home));
  await settle(tester, const Duration(milliseconds: 1200));
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('Yemek (10_yemek_light) olculeri', (tester) async {
    final b = FakeBackend()
      ..on('/menu', [
        for (var o = -2; o <= 6; o++)
          {
            'date': _d(o),
            'items': ['Mercimek çorbası', 'Orman kebabı', 'Pirinç pilavı', 'Cacık'],
            'dishes': [
              {'name': 'Mercimek çorbası', 'kcal': 160},
              {'name': 'Orman kebabı', 'kcal': 420},
              {'name': 'Pirinç pilavı', 'kcal': 280},
              {'name': 'Cacık', 'kcal': 70},
            ],
            'totalKcal': 930,
            'kcalComplete': true,
          },
      ]);
    await _mount(tester, MenuPage(session: makeSession(b)));
    await tester.pump(const Duration(seconds: 1));
    final head = tester.getRect(find.byType(BuHeader));
    final circle = tester.getRect(find.byType(BuIconButton).first);
    final n = DateTime.now();
    final key = find.byKey(ValueKey('yemek_day_${n.year}-${n.month}-${n.day}'));
    final pill = tester.getRect(find.descendant(of: key, matching: find.byType(AnimatedContainer)));
    final top = circle.top + 4; // 48 dp dokunma kutusu, gorsel daire 40 dp -> ust 4 dp ice
    _row('Gun hapi genislik', 42, pill.width);
    _row('Gun hapi yukseklik', 47.5, pill.height);
    _row('Gun hapi ust (baslik dairesi ustune gore)', 167 / 1.8103 - 52 / 1.8103, pill.top - top, tol: 8);
    final card = tester.getRect(find.byType(MenuMealCard));
    _row('Yuzey sol kenar', 20.4, card.left);
    _row('Yuzey sag kenar', 369, card.right);
    _row('Yuzey yukseklik (4 yemek + toplam)', 307.6, card.height);
    _row('Yuzey ust (baslik dairesi ustune gore)', 345 / 1.8103 - 52 / 1.8103, card.top - top, tol: 8);
    final title = tester.getRect(find.text('Öğle yemeği'));
    _row('Oge basligi sol (yuzeye gore)', 75 / 1.8103 - 37 / 1.8103, title.left - card.left, tol: 2);
    final time = tester.getRect(find.text('11:30–14:00'));
    _row('Saat sag kenari (yuzeye gore)', 369 - 348.6, card.right - time.right, tol: 2);
    final r1 = tester.getRect(find.text('Mercimek çorbası'));
    final r2 = tester.getRect(find.text('Orman kebabı'));
    _row('Yemek satir adimi', 49.2, r2.center.dy - r1.center.dy, tol: 2);
    final kc = tester.getRect(find.text('160 kcal'));
    _row('kcal sag kenari (yuzeye gore)', 369 - 348.6, card.right - kc.right, tol: 2);
    final total = tester.getRect(find.text('930 kcal'));
    _row('Toplam sag kenari (yuzeye gore)', 369 - 348.6, card.right - total.right, tol: 2);
    final lbl = tester.getRect(find.text('Bugün · ${n.day} ${['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'][n.month - 1]}'));
    _row('Gun etiketi sol', 20.4, lbl.left, tol: 1);
    _row('Gun etiketi merkezi (daireye gore)', (314 - 52) / 1.8103, lbl.center.dy - top, tol: 3);
    _row('Etiket -> yuzey bosluk', (345 - 327) / 1.8103, card.top - lbl.bottom, tol: 3);
    expect(head.height, greaterThan(40));
    expect(tester.takeException(), isNull);
    expect(_fails, isEmpty);
    _fails.clear();
  });

  testWidgets('Bildirimler (13_bildirimler_light) olculeri', (tester) async {
    final now = DateTime.now();
    final be = FakeBackend()
      ..on('/notifications', {
        'unreadCount': 2,
        'nextCursor': null,
        'items': [
          {'id': 1, 'type': 'ANNOUNCEMENT', 'title': 'Ders ekleme-bırakma tarihleri duyuruldu', 'body': 'Güz dönemi ders ekleme ve bırakma işlemleri başladı.', 'read': false, 'createdAt': now.toIso8601String()},
          {'id': 2, 'type': 'EVENT', 'title': 'Kariyer Günleri yarın başlıyor', 'body': 'Konferans salonunda düzenlenecek oturum detayları.', 'read': false, 'createdAt': now.subtract(const Duration(hours: 3)).toIso8601String()},
          {'id': 3, 'type': 'COMMUNITY', 'title': 'Müzik Kulübü isteğiniz onaylandı', 'body': 'Kulüp etkinliklerine artık katılabilirsiniz.', 'read': true, 'createdAt': now.subtract(const Duration(days: 1)).toIso8601String()},
        ],
      });
    await _mount(tester, NotificationsPage(session: makeSession(be)));
    final circle = tester.getRect(find.byType(BuIconButton).first);
    final top = circle.top + 4; // 48 dp dokunma kutusu, gorsel daire 40 dp -> ust 4 dp ice
    final r1 = tester.getRect(find.byKey(const ValueKey('notif-1')));
    final r2 = tester.getRect(find.byKey(const ValueKey('notif-2')));
    _row('Satir yuksekligi (adim)', 165 / 1.8103, r2.top - r1.top, tol: 2);
    _row('Satir sol/sag kenar (genislik)', 350, r1.width, tol: 1);
    final chipAll = tester.getRect(find.descendant(of: find.byKey(const ValueKey('notif-seg-all')), matching: find.byType(AnimatedContainer)));
    _row('Cip yuksekligi', 34, chipAll.height, tol: 2);
    _row('Tumu cipi genislik', (161 - 37) / 1.8103, chipAll.width, tol: 4);
    final chipUn = tester.getRect(find.descendant(of: find.byKey(const ValueKey('notif-seg-unread')), matching: find.byType(AnimatedContainer)));
    _row('Cip araligi', 8, chipUn.left - chipAll.right, tol: 2);
    _row('Cip ust (baslik dairesi ustune gore)', (131 - 52) / 1.8103, chipAll.top - top, tol: 8);
    final dot = tester.getRect(find.byKey(const ValueKey('notif-unread-dot')).first);
    _row('Nokta capi', 8, dot.width, tol: 0);
    final type = tester.getRect(find.text('Duyuru'));
    _row('Tur etiketi sol (satira gore)', (73 - 37) / 1.8103 + 20 - 20, type.left - r1.left, tol: 2);
    final titleR = tester.getRect(find.text('Ders ekleme-bırakma tarihleri duyuruldu'));
    _row('Baslik - tur etiketi dikey', (380 - 342) / 1.8103, titleR.center.dy - type.center.dy, tol: 3);
    expect(tester.takeException(), isNull);
    expect(_fails, isEmpty);
    _fails.clear();
  });

  testWidgets('Bildirim tercihleri (15_bildirim_tercihleri_light) olculeri', (tester) async {
    final be = FakeBackend()
      ..on('/notifications/preferences', {
        'news': true,
        'announcements': true,
        'events': true,
        'communities': false,
        'messages': true,
        'polls': true,
        'academicAnnouncements': true,
        'quietHours': {'enabled': true, 'start': '23:00', 'end': '07:00'},
        'subtypes': {'MESSAGE_DIRECT': true},
      });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
    addTearDown(() => LocaleController.current = null);
    await tester.pumpWidget(buildApp(NotificationPrefsPage(session: makeSession(be))));
    await settle(tester, const Duration(milliseconds: 1200));
    const s = 612 / 390; // 15_ PNG olcegi
    final circle = tester.getRect(find.byType(BuIconButton).first);
    final top = circle.top + 4; // 48 dp dokunma kutusu, gorsel daire 40 dp -> ust 4 dp ice
    final haber = tester.getRect(find.text('Haberler'));
    final duyuru = tester.getRect(find.text('Duyurular'));
    _row('Iki satirli satir adimi', (524 - 403) / s, duyuru.center.dy - haber.center.dy, tol: 2);
    final sw = tester.getRect(find.ancestor(of: find.byType(Switch).first, matching: find.byType(SizedBox)).first);
    _row('Anahtar genisligi', 48, sw.width, tol: 0);
    _row('Anahtar yuksekligi', 28, sw.height, tol: 0);
    final sub = tester.getRect(find.text('Üniversiteden yeni haberler'));
    _row('Baslik - alt metin dikey', (440 - 403) / s, sub.center.dy - haber.center.dy, tol: 2);
    _row('Anahtar sag kenari (ekrana gore)', 390 - 20 - 1 - 16, sw.right, tol: 2);
    expect(top, greaterThan(0));
    expect(tester.takeException(), isNull);
    expect(_fails, isEmpty);
    _fails.clear();
  });
}
