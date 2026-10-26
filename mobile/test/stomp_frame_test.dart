import 'package:bu_kampus/core/realtime/stomp_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SEND kodlama', () {
    final f = StompFrame('SEND', headers: {'destination': '/app/chat.send'}, body: '{"a":1}');
    expect(f.encode(), 'SEND\ndestination:/app/chat.send\n\n{"a":1}\x00');
  });

  test('CONNECT basliklari kacislanmaz, SEND basliklari kacislanir', () {
    expect(StompFrame('CONNECT', headers: {'a': 'x:y'}).encode(), contains('a:x:y'));
    expect(StompFrame('SEND', headers: {'a': 'x:y\nz\\'}).encode(), contains('a:x\\cy\\nz\\\\'));
  });

  test('kacis geri alma', () {
    expect(StompFrame.unescape('a\\cb\\nc\\\\d\\r'), 'a:b\nc\\d\r');
  });

  test('MESSAGE ayristirma + kalp atisi + coklu cerceve', () {
    const raw = '\nMESSAGE\nsubscription:sub-0\ndestination:/user/queue/messages\n\n{"id":2}\x00'
        '\nMESSAGE\nsubscription:sub-1\nx:a\\cb\n\n{"n":3}\x00';
    final fs = StompFrame.parse(raw);
    expect(fs.length, 2);
    expect(fs[0].command, 'MESSAGE');
    expect(fs[0].headers['subscription'], 'sub-0');
    expect(fs[0].body, '{"id":2}');
    expect(fs[1].headers['x'], 'a:b');
    expect(fs[1].body, '{"n":3}');
  });

  test('CONNECTED ve bos govdeli ERROR', () {
    final c = StompFrame.parse('CONNECTED\nversion:1.2\nheart-beat:10000,10000\n\n\x00');
    expect(c.single.command, 'CONNECTED');
    expect(c.single.headers['heart-beat'], '10000,10000');
    final e = StompFrame.parse('ERROR\r\nmessage:TOKEN_EXPIRED\r\n\r\n\x00');
    expect(e.single.headers['message'], 'TOKEN_EXPIRED');
  });

  test('yalniz kalp atisi cerceve uretmez', () {
    expect(StompFrame.parse('\n'), isEmpty);
  });

  test('kodla-ayristir gidis donus', () {
    final f = StompFrame('SEND', headers: {'k:1': 'v\n2'}, body: 'merhaba');
    final r = StompFrame.parse(f.encode()).single;
    expect(r.headers['k:1'], 'v\n2');
    expect(r.body, 'merhaba');
  });
}
