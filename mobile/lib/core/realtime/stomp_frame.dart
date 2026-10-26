/// STOMP 1.2 çerçevesi: kodlama ve ayrıştırma (saf Dart, ağ yok).
class StompFrame {
  StompFrame(this.command, {Map<String, String>? headers, this.body = ''})
      : headers = headers ?? <String, String>{};

  final String command;
  final Map<String, String> headers;
  final String body;

  /// CONNECT/CONNECTED başlıkları kaçışlanmaz (spec 1.2).
  static bool _noEscape(String c) => c == 'CONNECT' || c == 'CONNECTED' || c == 'STOMP';

  static String escape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('\r', '\\r')
      .replaceAll('\n', '\\n')
      .replaceAll(':', '\\c');

  static String unescape(String s) {
    if (!s.contains('\\')) return s;
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch == '\\' && i + 1 < s.length) {
        final n = s[++i];
        b.write(switch (n) { 'r' => '\r', 'n' => '\n', 'c' => ':', '\\' => '\\', _ => '\\$n' });
      } else {
        b.write(ch);
      }
    }
    return b.toString();
  }

  /// Tel biçimi: KOMUT\nbaşlık:değer\n...\n\ngövde\0
  String encode() {
    final b = StringBuffer(command)..write('\n');
    final esc = !_noEscape(command);
    headers.forEach((k, v) {
      b.write(esc ? escape(k) : k);
      b.write(':');
      b.write(esc ? escape(v) : v);
      b.write('\n');
    });
    b.write('\n');
    b.write(body);
    b.write('\x00');
    return b.toString();
  }

  /// Bir WebSocket iletisindeki (bir veya birkaç) çerçeveyi ayrıştırır.
  /// Kalp atışı satır sonları (\n) ve boş parçalar atlanır.
  static List<StompFrame> parse(String data) {
    final out = <StompFrame>[];
    for (final chunk in data.split('\x00')) {
      var s = chunk;
      var start = 0;
      while (start < s.length && (s[start] == '\n' || s[start] == '\r')) {
        start++;
      }
      s = s.substring(start);
      if (s.isEmpty) continue;
      final sep = s.indexOf('\n\n');
      final sepCrlf = s.indexOf('\r\n\r\n');
      String head;
      String body;
      if (sep < 0 && sepCrlf < 0) {
        head = s;
        body = '';
      } else if (sepCrlf >= 0 && (sep < 0 || sepCrlf < sep)) {
        head = s.substring(0, sepCrlf);
        body = s.substring(sepCrlf + 4);
      } else {
        head = s.substring(0, sep);
        body = s.substring(sep + 2);
      }
      final lines = head.split('\n').map((l) => l.endsWith('\r') ? l.substring(0, l.length - 1) : l).toList();
      final command = lines.first;
      final esc = !_noEscape(command);
      final headers = <String, String>{};
      for (final l in lines.skip(1)) {
        final i = l.indexOf(':');
        if (i < 0) continue;
        final k = esc ? unescape(l.substring(0, i)) : l.substring(0, i);
        final v = esc ? unescape(l.substring(i + 1)) : l.substring(i + 1);
        headers.putIfAbsent(k, () => v); // tekrarda ilk değer geçerli
      }
      out.add(StompFrame(command, headers: headers, body: body));
    }
    return out;
  }
}
