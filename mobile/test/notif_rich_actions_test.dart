import 'dart:io';
import 'dart:typed_data';

import 'package:bu_kampus/core/api.dart' show ApiError;
import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:bu_kampus/core/push/rich/rich_actions.dart';
import 'package:bu_kampus/core/push/rich/rich_card.dart';
import 'package:bu_kampus/core/push/rich/rich_images.dart';
import 'package:bu_kampus/core/push/rich/rich_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Eylem -> istek eşlemesi, iş akışı (başarı/başarısızlık/oturum yok), avatar yedeği ve görsel güvenliği.

Map<String, dynamic> _chat({String? messageId}) => {
      'richChat': '1',
      'type': 'MESSAGE',
      'title': 'Ayşe',
      'body': 'selam',
      'senderName': 'Ayşe',
      'conversationId': '7',
      'tag': 'conv:7',
      'channelId': 'chat',
      'actions': 'reply,mark_read,mute_1h',
      if (messageId != null) 'messageId': messageId,
    };

Uint8List _jpeg(int w, int h) {
  final i = img.Image(width: w, height: h);
  img.fill(i, color: img.ColorRgb8(200, 30, 30));
  return Uint8List.fromList(img.encodeJpg(i));
}

void main() {
  group('eylem -> istek eşlemesi', () {
    test('reply: POST /conversations/{id}/messages {text, clientId}', () {
      final p = planRichAction('reply', _chat(), input: '  Geliyorum  ', clientId: 'rn-1') as HttpPlan;
      expect(p.method, 'POST');
      expect(p.path, '/conversations/7/messages');
      expect(p.body, {'text': 'Geliyorum', 'clientId': 'rn-1'});
    });

    test('reply: metin boşsa ya da sohbet yoksa istek yok', () {
      expect(planRichAction('reply', _chat(), input: '   '), isA<NoopPlan>());
      expect(planRichAction('reply', _chat()), isA<NoopPlan>());
      expect(planRichAction('reply', {'richChat': '1', 'title': 'x'}, input: 'a'), isA<NoopPlan>());
    });

    test('reply: sohbet kimliği targetType/targetId ile de gelebilir', () {
      final p = planRichAction('reply', {'targetType': 'CONVERSATION', 'targetId': '12'}, input: 'ok') as HttpPlan;
      expect(p.path, '/conversations/12/messages');
    });

    test('clientId üretimi 64 karakteri aşmaz ve her seferinde farklıdır', () {
      final a = richClientId();
      final b = richClientId();
      expect(a.length, lessThanOrEqualTo(64));
      expect(a, isNot(b));
    });

    test('mark_read: messageId varsa POST /read {lastMessageId}; yoksa sohbeti açar', () {
      final p = planRichAction('mark_read', _chat(messageId: '99')) as HttpPlan;
      expect([p.method, p.path, p.body], ['POST', '/conversations/7/read', {'lastMessageId': 99}]);
      final o = planRichAction('mark_read', _chat()) as OpenPlan;
      expect(resolvePushTarget(o.data), const PushTarget(PushDest.conversation, id: 7));
    });

    test('mute_1h: PUT /conversations/{id}/mute {durationMinutes: 60}', () {
      final p = planRichAction('mute_1h', _chat()) as HttpPlan;
      expect([p.method, p.path, p.body], ['PUT', '/conversations/7/mute', {'durationMinutes': 60}]);
    });

    test('follow_back: POST /users/{id}/follow (targetId kullanıcı)', () {
      final p = planRichAction('follow_back', {'targetType': 'USER', 'targetId': '33'}) as HttpPlan;
      expect([p.method, p.path], ['POST', '/users/33/follow']);
    });

    test('accept/reject: follow-requests uçları (istek sahibi senderId)', () {
      final a = planRichAction('accept', {'senderId': '33'}) as HttpPlan;
      final r = planRichAction('reject', {'senderId': '33'}) as HttpPlan;
      expect(a.path, '/users/me/follow-requests/33/accept');
      expect(r.path, '/users/me/follow-requests/33/decline');
      expect(planRichAction('accept', {'title': 'x'}), isA<NoopPlan>());
    });

    test('not_me: POST /security/not-me ve onay bildirimi istenir', () {
      final p = planRichAction('not_me', {'richChat': '1'}) as HttpPlan;
      expect([p.method, p.path, p.confirmation], ['POST', '/security/not-me', true]);
    });

    test('arayüz açan eylemler doğru ekrana çözülür', () {
      PushTarget t(String id, Map<String, dynamic> d) => resolvePushTarget((planRichAction(id, d) as OpenPlan).data);
      expect(t('view', {'targetType': 'ANNOUNCEMENT', 'targetId': '12'}), const PushTarget(PushDest.news, id: 12));
      expect(t('calendar', {'eventId': '3'}), const PushTarget(PushDest.event, id: 3));
      expect(t('qr_checkin', {'targetType': 'EVENT', 'targetId': '3'}), const PushTarget(PushDest.event, id: 3));
      expect(t('vote', {'pollId': '2'}), const PushTarget(PushDest.poll, id: 2));
      expect(t('exam_card', {}), const PushTarget(PushDest.exams));
      expect(t('open_schedule', {}), const PushTarget(PushDest.timetable));
      expect(t('view_ticket', {'targetType': 'TICKET', 'targetId': '41'}), const PushTarget(PushDest.ticket, id: 41));
      expect(t('reset_password', {}), const PushTarget(PushDest.accountSecurity));
      expect(t('enable_2fa', {}), const PushTarget(PushDest.accountSecurity));
      expect(t('sign_out_device', {}), const PushTarget(PushDest.accountSecurity));
    });

    test('bilinmeyen eylem yok sayılır', () {
      expect(planRichAction('teleport', _chat()), isA<NoopPlan>());
      expect(routeDataFor('teleport', _chat()), isNull);
    });
  });

  group('iş akışı (RichActionRunner)', () {
    late List<String> calls;
    late List<String> events;

    RichActionRunner runner({RichExec? exec, bool withExec = true}) => RichActionRunner(
          exec: withExec ? (exec ?? (m, p, b) async => {'ok': true}) : null,
          remove: (c) async => events.add('remove ${c.tag}'),
          fail: (c) async => events.add('fail ${c.tag}'),
          confirm: (c) async => events.add('confirm ${c.tag}'),
        );

    setUp(() {
      calls = [];
      events = [];
    });

    test('başarılı yanıt: istek atılır, bildirim kaldırılır', () async {
      final r = await runner(exec: (m, p, b) async {
        calls.add('$m $p ${b ?? ''}');
        return null;
      }).run('reply', _chat(), input: 'Tamam', clientId: 'rn-9');
      expect(r.outcome, RichOutcome.done);
      expect(calls, ['POST /conversations/7/messages {text: Tamam, clientId: rn-9}']);
      expect(events, ['remove conv:7']);
    });

    test('ApiError ve ağ hatası: bildirim hata kartına dönüşür, kaldırılmaz', () async {
      for (final err in <Object>[ApiError(500, 'X', ''), ApiError(0, 'NETWORK', ''), StateError('boom')]) {
        events.clear();
        final r = await runner(exec: (m, p, b) async => throw err).run('mark_read', _chat(messageId: '5'));
        expect(r.outcome, RichOutcome.failed);
        expect(events, ['fail conv:7']);
      }
    });

    test('oturum yok: istek atılmaz, hata kartı gösterilir', () async {
      final r = await runner(withExec: false).run('mute_1h', _chat());
      expect(r.outcome, RichOutcome.failed);
      expect(events, ['fail conv:7']);
    });

    test('not_me başarısında onay bildirimi de gösterilir', () async {
      final r = await runner().run('not_me', {'richChat': '1', 'title': 'Yeni cihazdan giriş', 'body': 'x', 'tag': 'sec:1', 'channelId': 'security'});
      expect(r.outcome, RichOutcome.done);
      expect(events, ['remove sec:1', 'confirm sec:1']);
    });

    test('arayüz açan eylem: ağ çağrısı yok, açma verisi döner', () async {
      final r = await runner(exec: (m, p, b) async => throw StateError('çağrılmamalı')).run('vote', {'richChat': '1', 'title': 'a', 'pollId': '2'});
      expect(r.outcome, RichOutcome.open);
      expect(r.openData, {'pollId': '2'});
    });

    test('bilinmeyen eylem ve eksik veri: hiçbir şey yapılmaz', () async {
      expect((await runner().run('teleport', _chat())).outcome, RichOutcome.ignored);
      expect((await runner().run('reply', _chat(), input: '')).outcome, RichOutcome.ignored);
      expect((await runner().run('follow_back', {'richChat': '1', 'title': 'x'})).outcome, RichOutcome.ignored);
      expect(events, isEmpty);
    });
  });

  group('görseller: güvenlik, avatar yedeği, kırpma', () {
    test('güvenilir adres: https + aynı alan adı', () {
      const o = 'https://api.bingol.edu.tr';
      expect(isTrustedMediaUrl('https://api.bingol.edu.tr/files/a.jpg', origin: o, allowInsecure: false), isTrue);
      expect(isTrustedMediaUrl('http://api.bingol.edu.tr/files/a.jpg', origin: o, allowInsecure: false), isFalse);
      expect(isTrustedMediaUrl('https://evil.example/a.jpg', origin: o, allowInsecure: false), isFalse);
      expect(isTrustedMediaUrl('https://user:pw@api.bingol.edu.tr/a.jpg', origin: o, allowInsecure: false), isFalse);
      expect(isTrustedMediaUrl('file:///etc/passwd', origin: o, allowInsecure: false), isFalse);
      expect(isTrustedMediaUrl('data:image/png;base64,AAAA', origin: o, allowInsecure: false), isFalse);
      expect(isTrustedMediaUrl('', origin: o), isFalse);
      expect(isTrustedMediaUrl(null, origin: o), isFalse);
      // Yerel/elden test derlemesi (http origin + izin) http'yi kabul eder.
      expect(isTrustedMediaUrl('http://10.0.2.2:8080/files/a.jpg', origin: 'http://10.0.2.2:8080', allowInsecure: true), isTrue);
      expect(isTrustedMediaUrl('http://10.0.2.2:8080/files/a.jpg', origin: 'http://10.0.2.2:8080', allowInsecure: false), isFalse);
    });

    test('baş harfler: Türkçe ve boş ad', () {
      expect(initialsOf('Ayşe Yılmaz'), 'AY');
      expect(initialsOf('ışık'), 'I');
      expect(initialsOf('  '), '?');
      expect(initialsOf(null), '?');
      expect(foldAscii('ŞÜĞİÖÇ'), 'SUGIOC');
      expect(foldAscii('أحمد'), '');
    });

    test('indirme başarısız/zaman aşımı/bozuk veri: baş harf avatarı (asla null)', () async {
      for (final fetch in <MediaFetcher>[
        (u) async => null,
        (u) async => throw StateError('ağ yok'),
        (u) async => Uint8List.fromList([1, 2, 3, 4]),
        (u) async => Uint8List(0),
      ]) {
        final images = RichImages(fetch: fetch, origin: 'https://api.bingol.edu.tr', allowInsecure: false);
        final bytes = await images.avatar('https://api.bingol.edu.tr/files/u.jpg', 'Ayşe Yılmaz');
        final d = img.decodePng(bytes)!;
        expect([d.width, d.height], [kAvatarSize, kAvatarSize]);
        // Yuvarlak: köşe şeffaf, merkez dolu.
        expect(d.getPixel(0, 0).a, 0);
        expect(d.getPixel(kAvatarSize ~/ 2, kAvatarSize ~/ 2).a, greaterThan(0));
      }
    });

    test('güvenilmez adres hiç indirilmez', () async {
      var hits = 0;
      final images = RichImages(fetch: (u) async {
        hits++;
        return _jpeg(64, 64);
      }, origin: 'https://api.bingol.edu.tr', allowInsecure: false);
      await images.avatar('https://evil.example/a.jpg', 'X');
      expect(await images.picture('http://api.bingol.edu.tr/a.jpg', wide: true), isNull);
      expect(hits, 0);
    });

    test('geçerli avatar yuvarlak kırpılır; ikinci istek önbellekten (indirme tekrarlanmaz)', () async {
      var hits = 0;
      final images = RichImages(fetch: (u) async {
        hits++;
        return _jpeg(300, 200);
      }, origin: 'https://api.bingol.edu.tr', allowInsecure: false);
      final a = await images.avatar('https://api.bingol.edu.tr/files/u.jpg', 'Ayşe');
      final b = await images.avatar('https://api.bingol.edu.tr/files/u.jpg', 'Ayşe');
      expect(hits, 1);
      expect(a, b);
      final d = img.decodePng(a)!;
      expect(d.getPixel(0, 0).a, 0);
      final c = d.getPixel(kAvatarSize ~/ 2, kAvatarSize ~/ 2);
      expect(c.r, greaterThan(150)); // kaynak kırmızıydı
    });

    test('disk önbelleği: yeni örnek aynı dosyadan okur', () async {
      final dir = await Directory.systemTemp.createTemp('rich_img_test');
      addTearDown(() => dir.delete(recursive: true));
      var hits = 0;
      Future<Uint8List?> f(Uri u) async {
        hits++;
        return _jpeg(100, 100);
      }

      final a = RichImages(fetch: f, cacheDir: dir, origin: 'https://api.bingol.edu.tr', allowInsecure: false);
      await a.picture('https://api.bingol.edu.tr/n.jpg', wide: false);
      await Future<void>.delayed(const Duration(milliseconds: 200)); // unawaited disk yazımı
      final b = RichImages(fetch: f, cacheDir: dir, origin: 'https://api.bingol.edu.tr', allowInsecure: false);
      final t = await b.picture('https://api.bingol.edu.tr/n.jpg', wide: false);
      expect(t, isNotNull);
      expect(hits, 1);
    });

    test('sayaç ve grup rozeti avatarı değiştirir; sayaç yoksa aynen döner', () {
      final base = initialsAvatar('Zeynep Arslan');
      expect(badgeAvatar(base), base);
      expect(badgeAvatar(base, count: 1), base);
      expect(badgeAvatar(base, count: 3), isNot(base));
      expect(badgeAvatar(base, group: true), isNot(base));
      final d = img.decodePng(badgeAvatar(base, count: 12, group: true))!;
      expect(d.width, kAvatarSize);
    });

    test('küçük görsel yuvarlatılmış köşeli kare, geniş görsel 1024 px ile sınırlı', () {
      final t = img.decodePng(roundedThumb(_jpeg(400, 300))!)!;
      expect([t.width, t.height], [192, 192]);
      expect(t.getPixel(0, 0).a, 0); // yuvarlak köşe
      expect(t.getPixel(96, 96).a, greaterThan(0));
      final w = img.decodeJpg(widePicture(_jpeg(2000, 1000))!)!;
      expect(w.width, 1024);
      expect(roundedThumb(Uint8List.fromList([9, 9])), isNull);
      expect(widePicture(Uint8List.fromList([9, 9])), isNull);
    });
  });

  test('RichKind: bilinmeyen alt tür eylemlerden çözülür (backend adları değişse de)', () {
    RichKind k(Map<String, String> m) => RichCard.tryParse({'richChat': '1', 'title': 't', 'body': 'b', ...m})!.kind;
    expect(k({'actions': 'not_me'}), RichKind.newDeviceLogin);
    expect(k({'actions': 'reset_password'}), RichKind.passwordChanged);
    expect(k({'actions': 'enable_2fa'}), RichKind.twoFaChanged);
    expect(k({'actions': 'sign_out_device'}), RichKind.sessionReplaced);
    expect(k({'actions': 'view_ticket'}), RichKind.supportReply);
    expect(k({'actions': 'qr_checkin', 'type': 'EVENT'}), RichKind.eventSoon);
  });
}
