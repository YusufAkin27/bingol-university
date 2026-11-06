import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:bu_kampus/features/chat/message_status_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _statuses = ['pending', 'failed', 'SENT', 'DELIVERED', 'READ'];

Widget _icon(String status, {bool rtl = false, Brightness b = Brightness.light, double size = 17.5}) => buildApp(
      Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 100,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Builder(
                  builder: (c) => MessageStatusIcon(
                    status: status,
                    size: size,
                    color: c.bu.mut,
                    readColor: c.bu.readSky,
                    failedColor: c.bu.danger,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      brightness: b,
    );

Map<String, dynamic> _m(String text, {String status = 'READ', Map<String, dynamic>? extra}) => {
      'id': 5,
      'conversationId': 1,
      'senderId': 1,
      'text': text,
      'status': status,
      'createdAt': DateTime(2026, 11, 6, 14, 5).toUtc().toIso8601String(),
      ...?extra,
    };

Widget _bubble(Map<String, dynamic> m, {double width = 390, double scale = 1, bool rtl = false, Brightness b = Brightness.light}) {
  Widget w = MessageBubble(
    message: m,
    mine: true,
    senderName: null,
    replyName: null,
    seen: false,
    authHeaders: const {},
    onMenu: () {},
    onRetry: () {},
    onOpenImage: (_) {},
    onReact: (_) {},
  );
  w = MediaQuery(
    data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(scale)),
    child: Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: w),
  );
  return buildApp(Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: w)), brightness: b, size: Size(width, 800));
}

void main() {
  setUpAll(loadTestFonts);

  group('MessageTickPainter geometri', () {
    for (final size in [14.0, 16.0, 17.5, 22.0]) {
      test('cizim kutuya sigar, sag kenar tek/cift tikte ayni, iki tik arasi sabit (size $size)', () {
        final box = MessageStatusIcon.boxFor(size);
        final single = MessageTickPainter.pathFor(box, isDouble: false, rtl: false).getBounds();
        final dbl = MessageTickPainter.pathFor(box, isDouble: true, rtl: false).getBounds();
        for (final r in [single, dbl]) {
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.top, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(box.width));
          expect(r.bottom, lessThanOrEqualTo(box.height));
        }
        expect(single.right, closeTo(dbl.right, 1e-6), reason: 'bitis kenari ayni');
        expect(single.top, closeTo(dbl.top, 1e-6));
        expect(dbl.left, lessThan(single.left));
        // iki tik arasi yatay mesafe 4.6 birim (17.5 referansta), cok yakin: tik genisliginin yarisindan az.
        final k = size / 17.5;
        expect(single.left - dbl.left, closeTo(4.6 * k, 1e-6));
        expect(single.width, greaterThan(4.6 * k * 2), reason: 'iki tik ust uste biner');
      });

      test('RTL: bitis kenari sol, ayni sabit mesafe (size $size)', () {
        final box = MessageStatusIcon.boxFor(size);
        final s = MessageTickPainter.pathFor(box, isDouble: false, rtl: true).getBounds();
        final d = MessageTickPainter.pathFor(box, isDouble: true, rtl: true).getBounds();
        expect(s.left, closeTo(d.left, 1e-6));
        expect(s.left, greaterThanOrEqualTo(0));
        expect(d.right, lessThanOrEqualTo(box.width));
      });
    }

    test('cift tik tek Path: tek alt-yol degil ama tek nesne, ikisi de ayni yukseklikte', () {
      final box = MessageStatusIcon.boxFor(17.5);
      final p = MessageTickPainter.pathFor(box, isDouble: true, rtl: false);
      expect(p.computeMetrics().length, 2);
      final b = p.getBounds();
      // gorsel boyut korunur: cift tik ~15 genis, ~8 yuksek (yaklasik 17.5 simgeye denk).
      expect(b.width, inInclusiveRange(14.0, 15.5));
      expect(b.height, inInclusiveRange(8.0, 8.6));
    });
  });

  group('MessageStatusIcon widget', () {
    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('tum durumlar sabit kutu, bitis kenari ayni (${b.name}, rtl=$rtl)', (tester) async {
          useScreen(tester, const Size(390, 800));
          final rights = <double>[];
          final lefts = <double>[];
          for (final st in _statuses) {
            await tester.pumpWidget(_icon(st, rtl: rtl, b: b));
            await tester.pump(const Duration(milliseconds: 400));
            final r = tester.getRect(find.byType(MessageStatusIcon));
            expect(r.size, MessageStatusIcon.boxFor(17.5), reason: st);
            rights.add(r.right);
            lefts.add(r.left);
            if (st == 'SENT' || st == 'DELIVERED' || st == 'READ') {
              final cp = find.byKey(ValueKey('msg-status-$st'));
              expect(cp, findsOneWidget);
              final cr = tester.getRect(cp);
              expect(cr, r, reason: 'cizim kutusu sinirlayici kutu ile ayni');
              final painter = tester.widget<CustomPaint>(cp).painter as MessageTickPainter;
              expect(painter.isDouble, st != 'SENT');
              expect(painter.rtl, rtl);
              final tk = b == Brightness.dark ? BuTokens.dark : BuTokens.light;
              expect(painter.color, st == 'READ' ? tk.readSky : tk.mut);
            }
          }
          expect(rights.toSet().length, 1);
          expect(lefts.toSet().length, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('gecis ara karesi: eski ve yeni ayni kutuda, sag kenarlari ayni', (tester) async {
      useScreen(tester, const Size(390, 800));
      await tester.pumpWidget(_icon('SENT'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(_icon('DELIVERED'));
      await tester.pump(const Duration(milliseconds: 60));
      final a = tester.getRect(find.byKey(const ValueKey('msg-status-SENT')));
      final c = tester.getRect(find.byKey(const ValueKey('msg-status-DELIVERED')));
      expect(a.right, closeTo(c.right, 0.01));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('msg-status-SENT')), findsNothing);
    });

    testWidgets('gorsel: tum durumlar PNG olarak yazilir (elle inceleme)', (tester) async {
      await tester.runAsync(() async {
        const scale = 8.0;
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec);
        canvas.scale(scale);
        final box = MessageStatusIcon.boxFor(17.5);
        canvas.drawRect(Rect.fromLTWH(0, 0, 6 * (box.width + 8), 2 * (box.height + 8)), Paint()..color = const Color(0xFF222222));
        var i = 0;
        for (final dark in [true, false]) {
          for (final st in ['SENT', 'DELIVERED', 'READ']) {
            canvas.save();
            canvas.translate(4 + i % 3 * (box.width + 8), 4 + (dark ? 0 : box.height + 8));
            canvas.drawRect(Offset.zero & box, Paint()..color = dark ? const Color(0xFF3A3A3A) : const Color(0xFFEFEFEF));
            MessageTickPainter(
              isDouble: st != 'SENT',
              color: st == 'READ' ? const Color(0xFF53BDEB) : const Color(0xFF9AA0A6),
            ).paint(canvas, box);
            canvas.restore();
            i++;
          }
        }
        final img = await rec.endRecording().toImage((6 * (box.width + 8) * scale).toInt(), (2 * (box.height + 8) * scale).toInt());
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        final out = File('${Directory.systemTemp.path}/tick_states.png');
        await out.writeAsBytes(data!.buffer.asUint8List());
        expect(out.existsSync(), isTrue);
      });
    });
  });

  group('Balon icinde saat+tik ayni grup', () {
    final cases = <String, Map<String, dynamic>>{
      'kisa': _m('Selam'),
      'uzun': _m('Bu oldukca uzun bir mesaj; birden fazla satira yayilacak kadar uzun bir metin yaziyorum burada, tikin yeri bozulmamali.'),
      'cok satir': _m('bir\niki\nuc\ndort\nbes'),
      'emoji': _m('Harika 😀🎉👍🏽 olmus'),
      'yanit': _m('Cevap', extra: {
        'replyTo': {'id': 3, 'senderId': 11, 'text': 'Eski mesaj metni', 'senderName': 'Ali'}
      }),
      'dosya': _m('', extra: {
        'attachments': [
          {'id': 70, 'kind': 'FILE', 'url': '/api/conversations/1/media/70', 'fileName': 'ders.pdf', 'sizeBytes': 2048, 'mime': 'application/pdf'}
        ]
      }),
    };
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final e in cases.entries) {
          for (final st in ['SENT', 'DELIVERED', 'READ']) {
            testWidgets('${e.key} w=$width x$scale $st', (tester) async {
              useScreen(tester, Size(width, 800));
              await tester.pumpWidget(_bubble({...e.value, 'status': st}, width: width, scale: scale));
              await tester.pump(const Duration(milliseconds: 500));
              final tickF = find.byKey(ValueKey('msg-status-$st'));
              expect(tickF, findsOneWidget);
              final icon = tester.getRect(find.byType(MessageStatusIcon));
              final tick = tester.getRect(tickF);
              expect(tick, icon, reason: 'iki tik parcasi ayni CustomPaint kutusunda');
              // Tik yalnizca bir tane (ayri widget'ta ikinci isaret yok).
              expect(find.byType(MessageStatusIcon), findsOneWidget);
              final bubble = tester.getRect(find.byType(MessageBubble));
              expect(bubble.left <= tick.left && tick.right <= bubble.right, isTrue, reason: 'tik balon icinde');
              // Saat metni: tikin hemen solunda, kucuk sabit bosluk (4) ve ayni satirda.
              final time = tester.getRect(find.textContaining(RegExp(r'\d\d:\d\d'), findRichText: true).last);
              expect(tick.left - time.right, closeTo(4, 1.0), reason: 'saat-tik boslugu');
              expect((tick.center.dy - time.center.dy).abs(), lessThan(tick.height / 2 + 4));
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }

    for (final rtl in [false, true]) {
      testWidgets('RTL=$rtl: tik sag/sol bitis kenarinda, saat tikin yaninda', (tester) async {
        useScreen(tester, const Size(390, 800));
        await tester.pumpWidget(_bubble(_m('Merhaba'), rtl: rtl));
        await tester.pump(const Duration(milliseconds: 500));
        final tick = tester.getRect(find.byType(MessageStatusIcon));
        final time = tester.getRect(find.textContaining(RegExp(r'\d\d:\d\d'), findRichText: true).last);
        if (rtl) {
          expect(tick.right, lessThanOrEqualTo(time.left + 5));
        } else {
          expect(tick.left, greaterThanOrEqualTo(time.right));
        }
      });
    }
  });
}
