import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';

/// Metin içindeki web adreslerini (`https://…`, `http://…`, `www.…`) bulur.
/// Cümle sonu noktalama (`.` `,` `;` `:` `!` `?` ve kapanan parantez) bağlantıya dahil edilmez.
final RegExp _urlPattern = RegExp(r'''(?:https?://|www\.)[^\s<>"']+''', caseSensitive: false);

/// Bir metin parçası: düz yazı ya da bağlantı (`uri` doluysa).
class LinkSegment {
  const LinkSegment(this.text, {this.uri});

  final String text;
  final Uri? uri;
}

/// Metni düz yazı ve bağlantı parçalarına ayırır. Yalnız `https` açılır: `http://` ve `www.` adresleri
/// `https://`'e çevrilir (kaynak sitelerdeki bağlantı kuralı ile aynı).
List<LinkSegment> splitLinks(String text) {
  final out = <LinkSegment>[];
  var last = 0;
  for (final m in _urlPattern.allMatches(text)) {
    var raw = m.group(0)!;
    // Sondaki noktalama bağlantıya ait değildir; parantez yalnız eşi yoksa atılır.
    while (raw.isNotEmpty) {
      final c = raw[raw.length - 1];
      if ('.,;:!?'.contains(c)) {
        raw = raw.substring(0, raw.length - 1);
      } else if (c == ')' && !raw.contains('(')) {
        raw = raw.substring(0, raw.length - 1);
      } else {
        break;
      }
    }
    final lower = raw.toLowerCase();
    // Yalnızca şema/ön ek kaldıysa bağlantı sayma.
    if (raw.length <= 4 || lower == 'http://' || lower == 'https://') continue;
    final start = m.start;
    final end = start + raw.length;
    if (start > last) out.add(LinkSegment(text.substring(last, start)));
    out.add(LinkSegment(raw, uri: normalizeHref(raw)));
    last = end;
  }
  if (last < text.length) out.add(LinkSegment(text.substring(last)));
  return out;
}

/// Açılacak adresi üretir: `http://` ve `www.` → `https://`; geçersizse `null`.
Uri? normalizeHref(String raw) {
  var s = raw.trim();
  if (s.toLowerCase().startsWith('http://')) {
    s = 'https://${s.substring(7)}';
  } else if (s.toLowerCase().startsWith('www.')) {
    s = 'https://$s';
  }
  final uri = Uri.tryParse(s);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || !uri.host.contains('.')) return null;
  return uri;
}

/// Metin içindeki bağlantıları tıklanabilir gösterir (dış tarayıcıda açılır). Açılamazsa [onOpenFailed] çağrılır.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText(this.text, {super.key, required this.style, this.onOpenFailed});

  final String text;
  final TextStyle style;
  final VoidCallback? onOpenFailed;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  Future<void> _open(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) widget.onOpenFailed?.call();
    } catch (_) {
      widget.onOpenFailed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final t = context.bu;
    final linkStyle = widget.style.copyWith(
      color: t.prText,
      decoration: TextDecoration.underline,
      decorationColor: t.prText,
    );
    final spans = <InlineSpan>[];
    for (final seg in splitLinks(widget.text)) {
      final uri = seg.uri;
      if (uri == null) {
        spans.add(TextSpan(text: seg.text));
        continue;
      }
      final rec = TapGestureRecognizer()..onTap = () => _open(uri);
      _recognizers.add(rec);
      spans.add(TextSpan(text: seg.text, style: linkStyle, recognizer: rec, semanticsLabel: seg.text));
    }
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}
