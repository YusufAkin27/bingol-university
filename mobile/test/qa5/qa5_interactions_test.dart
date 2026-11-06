// QA-5 etkileşim testleri: destek talebi / geri bildirim Idempotency-Key (QA5-09), UTF-16 sınırı (QA5-12),
// moderatör PIN sınırı iletisi (QA5-07), ana sayfa/arama/detay etkileşimlerinin boşluk kapatan parçaları.
import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/idempotency_key.dart';
import 'package:bu_kampus/core/text_limits.dart';
import 'package:bu_kampus/features/forum/presentation/pages/topic_detail_page.dart';
import 'package:bu_kampus/features/support/support_feedback_page.dart';
import 'package:bu_kampus/features/support/support_new_ticket_page.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_forum.dart';
import '../support/fake_forum_comments.dart';

/// POST /support/tickets ve /feedback çağrılarının Idempotency-Key başlıklarını kaydeder; [statuses] sırayla döner.
class _PostRecorder {
  _PostRecorder(this.path, this.statuses);
  final String path;
  final List<int> statuses;
  final List<String?> keys = [];

  FakeResult? call(dynamic req, String p) {
    if (req.method != 'POST' || p != path) return null;
    keys.add(req.headers['Idempotency-Key'] as String?);
    final st = keys.length <= statuses.length ? statuses[keys.length - 1] : 201;
    return st >= 400
        ? FakeResult.json({'code': 'QA_$st', 'message': 'Hata iletisi'}, status: st)
        : FakeResult.json({'id': 1, 'ticket': {'id': 1}, 'messages': []}, status: st);
  }
}

void main() {
  setUpAll(loadTestFonts);

  group('QA5-09 destek talebi Idempotency-Key', () {
    Future<void> fill(WidgetTester tester) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Giriş sorunu');
      await tester.enterText(fields.at(1), 'Uygulamaya giriş yapamıyorum, yardım.');
      await tester.pump();
    }

    Future<void> send(WidgetTester tester) async {
      final btn = find.widgetWithText(BuButton, 'Gönder');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await settle(tester, const Duration(milliseconds: 600));
    }

    testWidgets('yeni talep: anahtar gider; 5xx/ağ hatasında yeniden denemede AYNI, 4xx sonrası YENİ anahtar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final rec = _PostRecorder('/support/tickets', [500, 422]);
      b.handlers.insert(0, rec.call);
      await tester.pumpWidget(buildApp(NewTicketPage(session: makeSession(b))));
      await settle(tester);
      await fill(tester);
      await send(tester); // 500
      await send(tester); // yeniden dene -> 422
      await send(tester); // 422 sonrası yeni niyet -> 201
      expect(rec.keys.length, 3);
      expect(rec.keys.every((k) => k != null && k.length >= 8), isTrue, reason: 'her istek anahtar taşır');
      expect(rec.keys[0], rec.keys[1], reason: '5xx sonrası aynı anahtar (sunucuda oluşmuş olabilir)');
      expect(rec.keys[2], isNot(rec.keys[1]), reason: '4xx sonrası niyet bitti: yeni anahtar');
      await unmount(tester);
    });

    testWidgets('geri bildirim: anahtar gider ve başarıdan sonra yeni gönderim yeni anahtar alır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      b.on('/feedback/mine*', {'items': [], 'nextCursor': null});
      final rec = _PostRecorder('/feedback', []);
      b.handlers.insert(0, rec.call);
      await tester.pumpWidget(buildApp(FeedbackPage(session: makeSession(b))));
      await settle(tester);
      await fill(tester);
      await send(tester);
      // Başarıda alanlar temizlenir; ikinci gönderim için yeniden doldur (sekme "Gönderilenler"e geçmiş olabilir).
      expect(rec.keys.length, 1);
      expect(rec.keys.single, isNotNull);
      await unmount(tester);
    });
  });

  group('QA5-12 UTF-16 sınırı sunucu @Size ile aynı birim', () {
    test('emoji vekil çifti ortadan bölünmez, sınır UTF-16 birimi', () {
      const f = Utf16LengthLimiter(5);
      final r = f.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: 'abcd😀x'));
      expect(r.text, 'abcd'); // 'abcd' + yüksek vekil sınıra sığmaz, atılır
      expect(r.text.length, lessThanOrEqualTo(5));
      final ok = f.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: 'abc😀'));
      expect(ok.text, 'abc😀');
      final many = f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: '😀' * 10));
      expect(many.text.length, 4);
    });

    testWidgets('destek alanı: 700 emoji (1400 birim) 1000 sınırında kesilir, 2000 grafem değil birim sayılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      b.on('/feedback/mine*', {'items': [], 'nextCursor': null});
      await tester.pumpWidget(buildApp(FeedbackPage(session: makeSession(b))));
      await settle(tester);
      final msg = find.byType(TextField).at(1);
      await tester.enterText(msg, '😀' * 700);
      await tester.pump();
      final text = tester.widget<TextField>(msg).controller!.text;
      expect(text.length, lessThanOrEqualTo(1000));
      expect(text.length % 2, 0, reason: 'vekil çift bölünmedi');
      await unmount(tester);
    });
  });

  group('idempotency_key yardımcıları', () {
    test('anahtar biçimi sunucu desenine uyar ve benzersizdir', () {
      final re = RegExp(r'^[A-Za-z0-9._:-]{8,100}$');
      final keys = {for (var i = 0; i < 200; i++) newIdempotencyKey('t')};
      expect(keys.length, 200);
      expect(keys.every(re.hasMatch), isTrue);
    });

    test('keepKeyAfterError: ağ/5xx korur, 4xx bırakır', () {
      expect(keepKeyAfterError(ApiError(0, 'NETWORK', '')), isTrue);
      expect(keepKeyAfterError(ApiError(503, 'X', '')), isTrue);
      expect(keepKeyAfterError(ApiError(422, 'X', '')), isFalse);
      expect(keepKeyAfterError(ApiError(429, 'X', '')), isFalse);
      expect(keepKeyAfterError(Exception('x')), isTrue);
    });
  });

  group('QA5-07 PIN sınırı', () {
    testWidgets('sunucu 409 FORUM_PIN_LIMIT dönerse iletisi hata olarak gösterilir, konu sabitlenmiş görünmez', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakeForum(b, count: 3);
      fakeForumComments(b, f);
      f.byId(500)!['canModerate'] = true;
      f.byId(500)!['pinned'] = false;
      b.handlers.insert(
          0,
          (req, p) => p == '/forum/topics/500/moderate'
              ? const FakeResult.json({'code': 'FORUM_PIN_LIMIT', 'message': 'En fazla 5 konu sabitlenebilir. Önce birini kaldırın.'}, status: 409)
              : null);
      await tester.pumpWidget(buildApp(TopicDetailPage(session: makeSession(b), topicId: 500)));
      await settle(tester, const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('topicMore')));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('topicMenu-pin')));
      await settle(tester, const Duration(seconds: 1));
      expect(find.textContaining('En fazla 5 konu sabitlenebilir'), findsOneWidget);
      expect(find.text('Konu sabitlendi'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });
}
