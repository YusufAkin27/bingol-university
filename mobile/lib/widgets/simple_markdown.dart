import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/typography.dart';

/// Sözleşme metinleri için küçük Markdown çizicisi (paket eklemeden).
/// Desteklenenler: `#`/`##`/`###` başlık, `>` alıntı, `- `/`* ` madde, `1. ` numaralı madde,
/// `| a | b |` tablo (`|---|` ayırıcılı), `---` ayraç, `**kalın**`, `*italik*`, `` `kod` ``.
/// HTML yorumlanmaz. Metin seçilebilir.
class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown(this.source, {super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final blocks = parseMarkdown(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final b in blocks) _block(context, t, b)],
    );
  }

  Widget _block(BuildContext context, BuTokens t, MdBlock b) {
    switch (b.kind) {
      case MdKind.heading:
        final style = switch (b.level) {
          1 => BuType.title,
          2 => BuType.heading,
          _ => BuType.bodyStrong,
        };
        return Padding(
          padding: EdgeInsets.only(top: b.level == 1 ? 8 : 16, bottom: 6),
          child: Semantics(
            header: true,
            child: SelectableText.rich(_inline(b.text, style.copyWith(color: t.ink), t)),
          ),
        );
      case MdKind.quote:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: t.soft,
              borderRadius: BorderRadius.circular(12),
              border: BorderDirectional(start: BorderSide(color: t.pr, width: 3)),
            ),
            child: SelectableText.rich(
                _inline(b.text, BuType.body.copyWith(height: 1.55, color: t.onSoft), t)),
          ),
        );
      case MdKind.bullet:
      case MdKind.numbered:
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, top: 3, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: b.kind == MdKind.numbered ? 26 : 16,
                child: Text(b.kind == MdKind.numbered ? '${b.index}.' : '•',
                    style: BuType.body.copyWith(height: 1.55, color: t.mut)),
              ),
              Expanded(
                child: SelectableText.rich(_inline(b.text, BuType.body.copyWith(height: 1.55, color: t.ink), t)),
              ),
            ],
          ),
        );
      case MdKind.rule:
        return Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: t.bd));
      case MdKind.table:
        return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: _MdTable(rows: b.rows, header: b.header));
      case MdKind.paragraph:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SelectableText.rich(_inline(b.text, BuType.body.copyWith(height: 1.6, color: t.ink), t)),
        );
    }
  }
}

/// Tablo: dar ekranda her satır, "Başlık: değer" çiftleri olan bir kart olarak çizilir
/// (yatay kaydırma gerektirmez, büyük yazıda da okunur).
class _MdTable extends StatelessWidget {
  const _MdTable({required this.rows, required this.header});

  final List<List<String>> rows;
  final List<String> header;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Column(
      children: [
        for (final r in rows)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.sf2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.bd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < r.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                    child: SelectableText.rich(TextSpan(children: [
                      if (i < header.length && header[i].isNotEmpty && i > 0)
                        TextSpan(text: '${header[i]}: ', style: BuType.label.copyWith(color: t.mut)),
                      ..._inline(r[i], i == 0 ? BuType.bodyStrong.copyWith(color: t.ink) : BuType.body.copyWith(height: 1.45, color: t.ink), t)
                          .children!,
                    ])),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

enum MdKind { heading, quote, bullet, numbered, rule, table, paragraph }

class MdBlock {
  MdBlock(this.kind, {this.text = '', this.level = 0, this.index = 0, this.rows = const [], this.header = const []});

  final MdKind kind;
  final String text;
  final int level;
  final int index;
  final List<List<String>> rows;
  final List<String> header;
}

List<String> _cells(String line) {
  var s = line.trim();
  if (s.startsWith('|')) s = s.substring(1);
  if (s.endsWith('|')) s = s.substring(0, s.length - 1);
  return s.split('|').map((c) => c.trim()).toList();
}

bool _isSep(String line) => RegExp(r'^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$').hasMatch(line);

/// Markdown metnini bloklara ayırır (test edilebilir).
List<MdBlock> parseMarkdown(String src) {
  final lines = src.replaceAll('\r\n', '\n').split('\n');
  final out = <MdBlock>[];
  final para = StringBuffer();
  void flush() {
    final s = para.toString().trim();
    if (s.isNotEmpty) out.add(MdBlock(MdKind.paragraph, text: s));
    para.clear();
  }

  var i = 0;
  while (i < lines.length) {
    final raw = lines[i];
    final line = raw.trimRight();
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      flush();
      i++;
      continue;
    }
    final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    if (h != null) {
      flush();
      out.add(MdBlock(MdKind.heading, text: h.group(2)!, level: h.group(1)!.length.clamp(1, 3)));
      i++;
      continue;
    }
    if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
      flush();
      out.add(MdBlock(MdKind.rule));
      i++;
      continue;
    }
    if (trimmed.startsWith('>')) {
      flush();
      final q = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        q.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
        i++;
      }
      out.add(MdBlock(MdKind.quote, text: q.join('\n').trim()));
      continue;
    }
    if (trimmed.startsWith('|') && i + 1 < lines.length && _isSep(lines[i + 1])) {
      flush();
      final header = _cells(trimmed);
      i += 2;
      final rows = <List<String>>[];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        rows.add(_cells(lines[i]));
        i++;
      }
      out.add(MdBlock(MdKind.table, rows: rows, header: header));
      continue;
    }
    final b = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
    if (b != null) {
      flush();
      out.add(MdBlock(MdKind.bullet, text: b.group(1)!));
      i++;
      continue;
    }
    final n = RegExp(r'^(\d{1,3})[.)]\s+(.*)$').firstMatch(trimmed);
    if (n != null) {
      flush();
      out.add(MdBlock(MdKind.numbered, text: n.group(2)!, index: int.parse(n.group(1)!)));
      i++;
      continue;
    }
    if (para.isNotEmpty) para.write('\n');
    para.write(trimmed);
    i++;
  }
  flush();
  return out;
}

/// `**kalın**`, `*italik*`, `` `kod` `` içeren satır içi biçimleme.
TextSpan _inline(String text, TextStyle base, BuTokens t) {
  final spans = <InlineSpan>[];
  final re = RegExp(r'\*\*(.+?)\*\*|`(.+?)`|(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])');
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
    if (m.group(1) != null) {
      spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
    } else if (m.group(2) != null) {
      spans.add(TextSpan(text: m.group(2), style: TextStyle(backgroundColor: t.sf2, fontFamily: 'monospace')));
    } else {
      spans.add(TextSpan(text: m.group(3), style: const TextStyle(fontStyle: FontStyle.italic)));
    }
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return TextSpan(style: base, children: spans);
}
