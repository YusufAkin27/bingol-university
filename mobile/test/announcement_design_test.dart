import 'package:bu_kampus/features/news/announcement_parts.dart';
import 'package:bu_kampus/features/news/news_list_page.dart';
import 'package:bu_kampus/features/news/unit_news.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Duyuru sayfası yeniden tasarımı: tarih grupları, kart, ek satırı; boyut x tema x yön x yazı ölçeği matrisi.

Widget _wrap(Widget w, {bool rtl = false, double scale = 1}) => MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: w),
    );

String _day(int back) {
  final d = DateTime.now().subtract(Duration(days: back));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _ann(int id, int back, {String? title}) =>
    {...newsItem(id, type: 'DUYURU', title: title ?? 'Güz dönemi ders kayıt ve danışman onay duyurusu $id'), 'publishedDate': _day(back)};

void main() {
  setUpAll(loadTestFonts);

  test('groupAnnouncements: bugün / bu hafta / daha eski, sıra korunur', () {
    final now = DateTime(2026, 11, 9, 12);
    final rows = groupAnnouncements([
      {'publishedDate': '2026-11-09'},
      {'publishedDate': '2026-11-05'},
      {'publishedDate': '2026-10-01'},
      {'publishedDate': null},
    ], now);
    expect(rows.whereType<AnnouncementGroup>().toList(), [AnnouncementGroup.today, AnnouncementGroup.week, AnnouncementGroup.older]);
    expect(rows.length, 7);
    expect(announcementGroupLabel('tr', AnnouncementGroup.week), 'Bu hafta');
    expect(announcementGroupLabel('en', AnnouncementGroup.today), 'Today');
  });

  group('Duyuru listesi matrisi', () {
    for (final size in kPhoneSizes) {
      for (final b in Brightness.values) {
        for (final rtl in [false, true]) {
          for (final scale in [1.0, 1.3]) {
            testWidgets('${size.width.toInt()} dp ${b.name}${rtl ? ' rtl' : ''} x$scale', (tester) async {
              useScreen(tester, size);
              final be = FakeBackend()
                ..on('/news', {'items': [_ann(1, 0), _ann(2, 3), _ann(3, 40, title: 'Çok uzun bir başlık ' * 8)], 'totalPages': 1})
                ..on('/news/unit', [])
                ..on('/status', {})
                ..on('/bookmarks/news/ids', {'ids': []});
              await tester.pumpWidget(
                  buildApp(_wrap(NewsListPage(session: makeSession(be), initialType: 'DUYURU'), rtl: rtl, scale: scale), brightness: b, size: size));
              await settle(tester);
              expect(find.text('Today'), findsOneWidget);
              expect(find.text('This week'), findsOneWidget);
              expect(find.text('Earlier'), findsOneWidget);
              expect(find.byType(AnnouncementTile), findsWidgets);
              final e = tester.takeException();
              if (e != null) fail('$e');
              await unmount(tester);
            });
          }
        }
      }
    }
  });

  testWidgets('birim duyuru detayı: ek satırı ad + tür gösterir, yükleniyor iskeleti taşmaz', (tester) async {
    useScreen(tester, kPhoneSmall);
    final u = {
      'id': 1,
      'title': 'Vize programı',
      'unitName': 'Mühendislik Fakültesi',
      'publishedDate': _day(1),
      'url': 'https://mmf.bingol.edu.tr/d/1',
    };
    final be = FakeBackend(delay: const Duration(milliseconds: 200))
      ..on('/news/unit/1', {
        ...u,
        'body': 'Birinci paragraf.',
        'attachments': [
          {'name': 'program.pdf', 'url': 'https://mmf.bingol.edu.tr/media/1/program.pdf', 'type': 'PDF'},
        ],
      });
    await tester.pumpWidget(buildApp(_wrap(UnitNewsDetailPage(session: makeSession(be), item: u), scale: 1.3), size: kPhoneSmall));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Vize programı'), findsOneWidget);
    await settle(tester, const Duration(seconds: 2));
    expect(find.text('program.pdf'), findsOneWidget);
    expect(find.textContaining('PDF'), findsWidgets);
    expect(find.text('Mühendislik Fakültesi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
