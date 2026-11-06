import 'package:bu_kampus/features/share/share_links.dart';
import 'package:bu_kampus/features/share/share_models.dart';
import 'package:bu_kampus/features/widgets/widget_link.dart';
import 'package:bu_kampus/features/widgets/widget_snapshots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WidgetLink.parse', () {
    test('sade hedefler', () {
      expect(WidgetLink.parse('bukampus://home'), WidgetLink.home);
      expect(WidgetLink.parse('bukampus://menu'), WidgetLink.menu);
      expect(WidgetLink.parse('bukampus://timetable'), WidgetLink.timetable);
      expect(WidgetLink.parse('bukampus://events'), WidgetLink.events);
      expect(WidgetLink.parse('bukampus://clubs'), WidgetLink.clubs);
      expect(WidgetLink.parse('bukampus://chat'), WidgetLink.chat);
      expect(WidgetLink.parse('bukampus://qr'), WidgetLink.qr);
      expect(WidgetLink.parse('bukampus://news'), WidgetLink.news);
      expect(WidgetLink.parse('bukampus://search'), WidgetLink.search);
      expect(WidgetLink.parse('bukampus://notifications'), WidgetLink.notifications);
      expect(WidgetLink.parse('bukampus://discover'), WidgetLink.discover);
    });

    test('kimlikli hedefler', () {
      expect(WidgetLink.parse('bukampus://events/12'), WidgetLink.event(12));
      expect(WidgetLink.parse('bukampus://news/7'), WidgetLink.newsItem(7));
      expect(WidgetLink.parse('bukampus://poll/42'), WidgetLink.poll(42));
      expect(WidgetLink.parse(Uri.parse('bukampus://events/12')), WidgetLink.event(12));
    });

    test('anket kimliksiz Ana Sayfa', () {
      expect(WidgetLink.parse('bukampus://poll'), WidgetLink.home);
      expect(WidgetLink.poll(null), WidgetLink.home);
      expect(WidgetLink.poll(0), WidgetLink.home);
    });

    test('bicim toleransi: ucuncu slash, buyuk harf, kenar bosluk', () {
      expect(WidgetLink.parse('  bukampus:///menu '), WidgetLink.menu);
      expect(WidgetLink.parse('BUKAMPUS://Menu'), WidgetLink.menu);
      expect(WidgetLink.parse('bukampus:///events/5'), WidgetLink.event(5));
    });

    test('gecersizler null: bozuk kimlik, fazla segment, yabanci sema, bilinmeyen hedef, paylasim baglantisi', () {
      for (final bad in [
        null,
        '',
        'bukampus://',
        'bukampus://menu/1',
        'bukampus://events/abc',
        'bukampus://events/0',
        'bukampus://events/-3',
        'bukampus://events/99999999999999999',
        'bukampus://events/1/2',
        'bukampus://nope',
        'https://bukampus.com.tr/menu',
        'http://evil.example/home',
        'javascript:alert(1)',
        'bukampus://user:pw@menu',
        'bukampus://s/p/12', // paylasim baglantisi widget degil
        42,
      ]) {
        expect(WidgetLink.parse(bad), isNull, reason: '$bad');
      }
    });

    test('uri turetme parse ile gidis-donus', () {
      for (final l in [
        WidgetLink.home,
        WidgetLink.menu,
        WidgetLink.qr,
        WidgetLink.event(3),
        WidgetLink.newsItem(9),
        WidgetLink.poll(77),
      ]) {
        expect(WidgetLink.parse(l.uri), l, reason: l.uri);
      }
      expect(WidgetLink.event(3).uri, 'bukampus://events/3');
    });

    test('kisayol katalogundaki tum baglantilar gecerli', () {
      for (final c in kQuickAccessCatalog) {
        expect(WidgetLink.parse(c.link.uri), c.link, reason: c.id);
      }
    });
  });

  group('ShareLinks yonlendirme', () {
    setUp(() => ShareLinks.instance.reset());
    tearDown(() => ShareLinks.instance.reset());

    test('widget baglantisi pendingWidget olur, paylasim hedefi bos kalir', () {
      ShareLinks.instance.ingest(Uri.parse('bukampus://menu'));
      expect(ShareLinks.instance.pendingWidget.value, WidgetLink.menu);
      expect(ShareLinks.instance.pending.value, isNull);
      expect(ShareLinks.instance.takeWidget(), WidgetLink.menu);
      expect(ShareLinks.instance.pendingWidget.value, isNull);
    });

    test('paylasim baglantisi eskisi gibi calisir, widget kuyruguna girmez', () {
      ShareLinks.instance.ingest(Uri.parse('bukampus://s/p/12'));
      expect(ShareLinks.instance.pending.value, const ShareTarget(ShareType.post, 12));
      expect(ShareLinks.instance.pendingWidget.value, isNull);
    });

    test('ayni widget baglantisi 2 sn icinde tekrarlanirsa tek sayilir, sonra yeniden', () {
      final t0 = DateTime(2026, 11, 6, 10);
      var hits = 0;
      ShareLinks.instance.pendingWidget.addListener(() {
        if (ShareLinks.instance.pendingWidget.value != null) hits++;
      });
      ShareLinks.instance.ingest(Uri.parse('bukampus://chat'), now: t0);
      ShareLinks.instance.ingest(Uri.parse('bukampus://chat'), now: t0.add(const Duration(seconds: 1)));
      expect(hits, 1);
      ShareLinks.instance.ingest(Uri.parse('bukampus://chat'), now: t0.add(const Duration(seconds: 5)));
      expect(hits, 2);
    });

    test('bilinmeyen ya da yabanci baglanti yok sayilir', () {
      ShareLinks.instance.ingest(Uri.parse('bukampus://nope'));
      ShareLinks.instance.ingest(Uri.parse('https://example.com/menu'));
      expect(ShareLinks.instance.pendingWidget.value, isNull);
      expect(ShareLinks.instance.pending.value, isNull);
    });

    test('paylasim ayristiricisi widget baglantisini TANIMAZ', () {
      expect(parseShareLink('bukampus://menu'), isNull);
      expect(parseShareLink('bukampus://events/12'), isNull);
    });
  });
}
