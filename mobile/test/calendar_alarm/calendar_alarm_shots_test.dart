@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/core/platform/device_calendar.dart';
import 'package:bu_kampus/features/academic/academic_calendar_page.dart';
import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/calendar_sync.dart';
import 'package:bu_kampus/features/academic/exams_page.dart';
import 'package:bu_kampus/features/academic/timetable_page.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'fakes.dart';

/// "Takvime ekle", sinav alarmi ve ders alarmi ekran goruntuleri. Varsayilan `flutter test` ile CALISMAZ.
/// Uretim: `CALALARM_OUT=C:/bu_qa/shots/calendar_alarm flutter test test/calendar_alarm/calendar_alarm_shots_test.dart`
const _dpr = 2.5;
final _nov = DateTime.utc(2026, 11, 5, 6, 0); // Persembe 09:00 Istanbul

Map<String, dynamic> _ev(int id, String kind, String title, String startsAt, {String? endsAt}) =>
    {'id': id, 'kind': kind, 'title': title, 'startsAt': startsAt, if (endsAt != null) 'endsAt': endsAt};

FakeBackend _backend() {
  final b = FakeBackend();
  final f = fakeAcademic(b);
  f.semester = {'id': 3, 'name': '2026-2027 Güz', 'startDate': '2026-09-28', 'endDate': '2027-01-15', 'current': true};
  f.addCourse('Algoritma Analizi', 3, '09:00', '10:45', room: 'B-204');
  f.addCourse('Ayrık Matematik', 3, '15:30', '17:15');
  f.addCourse('Fizik', 4, '10:00', '11:00');
  f.addCourse('Veri Yapıları', 1, '08:15', '09:45');
  f.addCourse('Elektronik', 2, '13:00', '14:00');
  f.addExam('Veri Yapıları Vize', '2026-11-18T10:30:00+03:00');
  f.addExam('Fizik Vize', '2026-11-18T12:30:00+03:00');
  f.addExam('Algoritma Final', '2026-12-21T14:00:00+03:00', type: 'FINAL');
  f.events = [
    _ev(1, 'VIZE', 'Ara sınavlar', '2026-11-17T21:00:00Z', endsAt: '2026-11-21T21:00:00Z'),
    _ev(2, 'DERS_KAYIT', 'Ders kayıt son günü', '2026-11-29T21:00:00Z'),
    _ev(3, 'TATIL', 'Yarıyıl tatili', '2027-01-17T21:00:00Z', endsAt: '2027-01-30T21:00:00Z'),
  ];
  return b;
}

Widget _app(Widget home, bool dark, GlobalKey key, String lang) => RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: BuTheme.forLocale(Brightness.light, lang),
        darkTheme: BuTheme.forLocale(Brightness.dark, lang),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(lang),
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

class _Board {
  const _Board(this.name, this.build, {this.after, this.ios = false, this.cal = CalAccess.notDetermined, this.calendars});
  final String name;
  final Widget Function() build;
  final Future<void> Function(WidgetTester, AppLocalizations)? after;
  final bool ios;
  final CalAccess cal;
  final List<DeviceCalendarInfo>? calendars;
}

Future<void> _tap(WidgetTester t, String text) async {
  final f = find.text(text).first;
  await t.dragUntilVisible(f, find.byType(Scrollable).first, const Offset(0, -200)).catchError((_) {});
  await t.ensureVisible(f);
  await t.tap(f);
  await settle(t, const Duration(milliseconds: 700));
}

void main() {
  final out = Platform.environment['CALALARM_OUT'];
  final skip = out == null ? 'CALALARM_OUT tanimli degil' : null;
  setUpAll(loadTestFonts);

  Widget cal() => AcademicCalendarPage(session: makeSession(_backend()));
  Widget exams() => ExamsPage(session: makeSession(_backend()));
  Widget tt() => TimetablePage(session: makeSession(_backend()));

  final boards = <_Board>[
    _Board('01_takvim_sayfasi', cal),
    _Board('02_takvim_ekle_izin_gerekcesi', cal, after: (t, l) => _tap(t, l.calSyncRowTitle)),
    _Board('03_takvim_ekle_sonuc', cal, cal: CalAccess.granted, after: (t, l) async {
      await _tap(t, l.calSyncRowTitle);
      await _tap(t, l.calSyncAdd);
    }),
    _Board('04_takvim_ekle_reddedildi', cal, cal: CalAccess.denied, after: (t, l) => _tap(t, l.calSyncRowTitle)),
    _Board('05_takvim_ekle_coklu_takvim', cal, cal: CalAccess.granted, calendars: const [
      DeviceCalendarInfo(id: 'c1', name: 'Kişisel', account: 'ayse@gmail.com', primary: true),
      DeviceCalendarInfo(id: 'c2', name: 'Okul', account: 'ayse@bingol.edu.tr'),
    ], after: (t, l) => _tap(t, l.calSyncRowTitle)),
    _Board('06_sinavlar', exams),
    _Board('07_sinav_alarm_android', exams, after: (t, l) => _tap(t, l.alarmExamAction)),
    _Board('08_sinav_alarm_sonuc_android', exams, after: (t, l) async {
      await _tap(t, l.alarmExamAction);
      await _tap(t, l.alarmSetCount('2'));
    }),
    _Board('09_sinav_alarm_ios', exams, ios: true, after: (t, l) => _tap(t, l.alarmExamActionIos)),
    _Board('10_ders_programi', tt, after: (t, l) async {
      final f = find.text(l.alarmClassAction);
      await t.dragUntilVisible(f, find.byType(ListView).first, const Offset(0, -200));
      await settle(t, const Duration(milliseconds: 400));
    }),
    _Board('11_ders_alarm_android', tt, after: (t, l) => _tap(t, l.alarmClassAction)),
    _Board('12_ders_alarm_ios', tt, ios: true, after: (t, l) => _tap(t, l.alarmClassActionIos)),
  ];

  final sizes = <(String, Size, double)>[
    ('390', const Size(390, 844), 1.0),
    ('320x13', const Size(320, 640), 1.3),
  ];

  for (final lang in ['tr', 'ar']) {
    for (final dark in [false, true]) {
      for (final sz in sizes) {
        for (final b in boards) {
          if (lang == 'ar' && sz.$1 == '320x13' && dark) continue;
          final name = '${b.name}_${lang}_${dark ? 'koyu' : 'acik'}_${sz.$1}';
          testWidgets('calalarm $name', skip: skip != null, (tester) async {
            academicClock = () => _nov;
            useFakeAlarms(clock: !b.ios, now: () => _nov);
            final be = FakeDeviceCalendarBackend(state: b.cal, calendars: b.calendars);
            CalendarSyncService.instance = CalendarSyncService(backend: be, store: MemoryCalendarSyncStore(), clock: () => _nov);
            DeviceCalendarBackend.instance = be;
            PermissionService.instance = FakePermissionService();
            addTearDown(() {
              academicClock = DateTime.now;
              resetAlarms();
              CalendarSyncService.instance = CalendarSyncService();
              DeviceCalendarBackend.instance = ChannelDeviceCalendarBackend();
              PermissionService.instance = SystemPermissionService();
              tester.view.reset();
              tester.platformDispatcher.clearTextScaleFactorTestValue();
            });
            tester.view.devicePixelRatio = _dpr;
            tester.view.physicalSize = Size(sz.$2.width * _dpr, sz.$2.height * _dpr);
            tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
            tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
            tester.platformDispatcher.textScaleFactorTestValue = sz.$3;
            final key = GlobalKey();
            await tester.pumpWidget(_app(b.build(), dark, key, lang));
            await settle(tester, const Duration(milliseconds: 900));
            if (b.after != null) await b.after!(tester, lookupAppLocalizations(Locale(lang)));
            await tester.pump(const Duration(milliseconds: 500));
            final err = tester.takeException();
            if (err != null) fail('Istisna: $err');
            await tester.runAsync(() async {
              final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
              final image = await ro.toImage(pixelRatio: _dpr);
              final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
              final dir = Directory(out!)..createSync(recursive: true);
              File('${dir.path}/$name.png').writeAsBytesSync(Uint8List.view(data.buffer));
            });
          });
        }
      }
    }
  }
}
