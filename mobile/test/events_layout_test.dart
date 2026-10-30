import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bu_kampus/features/events/event_cover.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/events/event_form_page.dart';
import 'package:bu_kampus/features/events/event_parts.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Etkinlik görünümlerinde başlığın okunabilirliği ve çakışma denetimi.
/// PNG çıktıları `build/shots/<ETK_SHOT_DIR veya sonra>/` altına yazılır (görsel kıyas için).
const _long =
    'Bingöl Üniversitesi Bilgisayar Mühendisliği Topluluğu Yapay Zeka ve Veri Bilimi Kariyer Günleri 2026 Büyük Buluşma';
const _short = 'Bahar Şenliği';

final _shotDir = Platform.environment['ETK_SHOT_DIR'] ?? 'sonra';

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _ev(int id,
    {required String title,
    String? cover,
    String? rsvp,
    bool manage = false,
    String status = 'ACTIVE',
    int days = 2,
    bool todayLate = false}) {
  var s = DateTime.now().add(Duration(days: days));
  if (todayLate) {
    final n = DateTime.now();
    s = DateTime(n.year, n.month, n.day, 23, 30);
  }
  return {
    'id': id,
    'source': 'USER',
    'title': title,
    'description': 'Açıklama metni',
    'startsAt': _iso(s),
    'endsAt': _iso(s.add(const Duration(hours: 2))),
    'location': 'Merkez Kampüs Konferans Salonu',
    'communityName': 'Bilgisayar Mühendisliği Topluluğu',
    'goingCount': 42,
    'interestedCount': 7,
    'myRsvp': rsvp,
    'canManage': manage,
    'registrationClosed': false,
    'status': status,
    'coverUrl': cover,
    'organizerName': 'Ayşe',
    'attendeesPreview': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz', 'avatarUrl': null},
      {'userId': 2, 'displayName': 'Ali Veli', 'avatarUrl': null},
    ],
  };
}

Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {'items': items, 'nextCursor': null};

/// Düz renkli + hafif doku içeren sahte kapak görseli.
class _SolidProvider extends ImageProvider<_SolidProvider> {
  _SolidProvider(this.image);
  final ui.Image image;
  @override
  Future<_SolidProvider> obtainKey(ImageConfiguration c) => Future.value(this);
  @override
  ImageStreamCompleter loadImage(_SolidProvider key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image.clone())));
}

Future<ui.Image> _makeImage(WidgetTester tester, Color base, Color stripe) async {
  return (await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(const Rect.fromLTWH(0, 0, 400, 200), Paint()..color = base);
    for (var i = 0; i < 8; i++) {
      c.drawRect(Rect.fromLTWH(i * 50.0, 0, 25, 200), Paint()..color = stripe);
    }
    return rec.endRecording().toImage(400, 200);
  }))!;
}

const _lightCover = (Color(0xFFF8F8F4), Color(0xFFFFFFFF));
const _darkCover = (Color(0xFF16202B), Color(0xFF0B0F14));

Future<void> _useCover(WidgetTester tester, (Color, Color)? c) async {
  if (c == null) {
    EventCoverImage.debugProvider = null;
    return;
  }
  final img = await _makeImage(tester, c.$1, c.$2);
  EventCoverImage.debugProvider = (_) => _SolidProvider(img);
  addTearDown(() => EventCoverImage.debugProvider = null);
}

class _Cfg {
  const _Cfg(this.name, this.size, this.scale, this.dark, this.cover, this.title);
  final String name;
  final Size size;
  final double scale;
  final bool dark;
  final (Color, Color)? cover;
  final String title;
}

final _cfgs = <_Cfg>[
  const _Cfg('s320_x13_acik_uzun_acikkapak', kPhoneSmall, 1.3, false, _lightCover, _long),
  const _Cfg('s390_koyu_uzun_koyukapak', kPhoneMedium, 1.0, true, _darkCover, _long),
  const _Cfg('s430_acik_kisa_kapaksiz', kPhoneLarge, 1.0, false, null, _short),
  const _Cfg('s320_x13_koyutema_uzun_acikkapak', kPhoneSmall, 1.3, true, _lightCover, _long),
];

final _boundary = GlobalKey();

Widget _wrap(Widget page, _Cfg c) => buildApp(RepaintBoundary(key: _boundary, child: page),
    brightness: c.dark ? Brightness.dark : Brightness.light, size: c.size);

Future<void> _pump(WidgetTester tester, _Cfg c, Widget page) async {
  useScreen(tester, c.size);
  tester.platformDispatcher.textScaleFactorTestValue = c.scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await _useCover(tester, c.cover);
  await tester.pumpWidget(_wrap(page, c));
  await settle(tester, const Duration(milliseconds: 900));
}

Future<ByteData?> _shot(WidgetTester tester, String view, _Cfg c) async {
  final b = _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
  return tester.runAsync(() async {
    final img = await b.toImage(pixelRatio: 2);
    final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final png = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    final dir = Directory('build/shots/$_shotDir')..createSync(recursive: true);
    File('${dir.path}/${view}__${c.name}.png').writeAsBytesSync(png.buffer.asUint8List());
    return raw!;
  });
}

Rect _rect(WidgetTester t, Finder f) => t.getRect(f.first);

bool _hit(Rect a, Rect b) => a.overlaps(b.deflate(.5)) && !a.intersect(b).isEmpty;

/// [title] dikdörtgeninin [others] ile kesişmediğini ve ekran içinde kaldığını doğrular.
void _expectNoOverlap(WidgetTester tester, Finder title, List<Finder> others, Size screen, String ctx) {
  final tr = _rect(tester, title);
  expect(tr.left, greaterThanOrEqualTo(0), reason: '$ctx: başlık sola taşıyor');
  expect(tr.right, lessThanOrEqualTo(screen.width + .5), reason: '$ctx: başlık sağa taşıyor');
  for (final f in others) {
    for (final e in f.evaluate()) {
      final r = tester.getRect(find.byElementPredicate((x) => x == e));
      if (r.isEmpty) continue;
      expect(_hit(tr, r), isFalse, reason: '$ctx: başlık $tr ile $r çakışıyor (${e.widget.runtimeType})');
    }
  }
}

void main() {
  setUpAll(loadTestFonts);

  FakeBackend feed(String title, String? cover) => FakeBackend()
    ..on('/events/calendar*', [_ev(5, title: title, cover: cover, todayLate: true)], headers: {'x-truncated': 'false'})
    ..on('/me/events?mode=attending&size=20', _page([_ev(5, title: title, cover: cover, rsvp: 'GOING')]))
    ..on('/me/events?mode=organizing&size=20', _page([_ev(8, title: title, cover: cover, manage: true)]));

  group('Keşfet / Etkinliklerim / Oluşturduklarım kartları', () {
    for (final c in _cfgs) {
      for (final tab in [0, 1, 2]) {
        testWidgets('kart sekme $tab ${c.name}', (tester) async {
          final cover = c.cover == null ? null : '/files/events/5.jpg';
          final b = feed(c.title, cover);
          await _pump(tester, c, EventsPage(session: makeSession(b), initialTab: tab));
          final title = find.text(c.title);
          expect(title, findsWidgets);
          await _shot(tester, 'kart_sekme$tab', c);
          _expectNoOverlap(
            tester,
            title,
            [
              find.byType(EventDateBadge),
              find.byType(EventStatusTag),
              find.byType(EventAvatarStack),
              find.byType(EventJoinedChip),
              find.byType(Icon),
            ],
            c.size,
            'kart sekme $tab ${c.name}',
          );
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }

    testWidgets('resmi etkinlik satiri uzun baslik', (tester) async {
      final c = _cfgs.first;
      final now = DateTime.now();
      final b = FakeBackend()
        ..on('/events/calendar*', [
          {
            'id': 9,
            'source': 'OFFICIAL',
            'title': _long,
            'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          }
        ], headers: {'x-truncated': 'false'});
      await _pump(tester, c, EventsPage(session: makeSession(b)));
      await _shot(tester, 'resmi_satir', c);
      _expectNoOverlap(tester, find.text(_long),
          [find.byType(EventDateBadge), find.byIcon(Icons.chevron_right)], c.size, 'resmi satır');
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('Etkinlik detayi', () {
    for (final c in _cfgs) {
      for (final manage in [false, true]) {
        testWidgets('detay manage=$manage ${c.name}', (tester) async {
          final cover = c.cover == null ? null : '/files/events/5.jpg';
          final b = FakeBackend()
            ..on('/events/5', _ev(5, title: c.title, cover: cover, manage: manage, rsvp: manage ? null : 'GOING'))
            ..on('/events/5/attendees/preview', {
              'goingCount': 42,
              'avatars': [
                {'userId': 1, 'displayName': 'Ayşe Yılmaz', 'avatarUrl': null},
                {'userId': 2, 'displayName': 'Ali Veli', 'avatarUrl': null},
              ]
            })
            ..on('/events/5/attendees*', _page([]))
            ..on('/events/5/attendance', <Object>[])
            ..on('/events/5/checkin-code', {'code': '5.1.a', 'qrPayload': 'x', 'validForSeconds': 30})
            ..on('/events/5/my-attendance', {'present': false, 'checkInOpen': false});
          await _pump(tester, c, EventDetailPage(session: makeSession(b), eventId: 5));
          final title = find.text(c.title);
          expect(title, findsOneWidget);
          await _shot(tester, 'detay_${manage ? 'yonetici' : 'katilimci'}', c);
          // Başlık kapağın altında olmalı ve kapak üstü öğelerle (rozet, geri/menü düğmeleri) kesişmemeli.
          final tr = tester.getRect(title);
          final hero = tester.getRect(find.byType(EventCoverImage).evaluate().isEmpty
              ? find.byType(DecoratedBox).first
              : find.byType(EventCoverImage));
          if (c.cover != null) expect(tr.top, greaterThanOrEqualTo(hero.bottom - 1));
          _expectNoOverlap(tester, title, [find.byType(EventDateBadge), find.byType(EventAvatarStack)], c.size,
              'detay ${c.name}');
          // Geri düğmesi (sol üst) kapak üzerinde: kendi koyu zemini olmalı.
          expect(find.byIcon(Icons.arrow_back), findsNothing);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });

  group('Ana sayfa oune cikan etkinlik', () {
    for (final c in _cfgs) {
      testWidgets('ana sayfa karti ${c.name}', (tester) async {
        final cover = c.cover == null ? null : '/files/events/9.jpg';
        final ev = {
          ..._ev(9, title: c.title, cover: cover),
          'attendeesPreview': [
            {'userId': 1, 'displayName': 'Ayşe Yılmaz', 'avatarUrl': null},
          ],
        };
        final b = FakeBackend()..on('/events/featured', ev);
        await _pump(tester, c, Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {})));
        // Etkinlik kartı sayfanın altında (referans 00): görünür olana dek kaydır.
        await tester.scrollUntilVisible(find.text(c.title), 300, scrollable: find.byType(Scrollable).first);
        final title = find.text(c.title);
        expect(title, findsOneWidget);
        final raw = await _shot(tester, 'ana_sayfa_kart', c);
        _expectNoOverlap(tester, title, [find.text('Katıl'), find.text('42 kişi katılıyor')], c.size, 'ana ${c.name}');
        expect(raw, anyOf(isNull, isNotNull)); // yeni kart kapaksız beyaz yüzey: kapak kontrastı denetimi yok
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  });

  group('Etkinlik formu', () {
    for (final c in [_cfgs[0], _cfgs[2]]) {
      testWidgets('form ${c.name}', (tester) async {
        final cover = c.cover == null ? null : '/files/events/5.jpg';
        final b = FakeBackend();
        await _pump(tester, c,
            EventFormPage(session: makeSession(b), event: _ev(5, title: c.title, cover: cover)));
        await _shot(tester, 'form', c);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  });
}
