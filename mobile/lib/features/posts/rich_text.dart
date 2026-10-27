import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../profile/user_profile_page.dart';
import 'hashtag_posts_page.dart';

/// Gönderi/yorum metni parçalayıcısı. Sunucu biçimleri:
///  - anma: `@[Ad Soyad](uid:123)`
///  - etiket: `#etiket` (harf/rakam/alt çizgi, en az bir harf)
enum RichKind { text, mention, hashtag }

class RichSpan {
  const RichSpan(this.kind, this.text, {this.userId, this.tag});

  final RichKind kind;

  /// Görünen metin: anma için `@Ad Soyad`, etiket için `#etiket`.
  final String text;
  final int? userId;
  final String? tag;

  @override
  bool operator ==(Object other) =>
      other is RichSpan && other.kind == kind && other.text == text && other.userId == userId && other.tag == tag;

  @override
  int get hashCode => Object.hash(kind, text, userId, tag);

  @override
  String toString() => 'RichSpan($kind, $text, $userId, $tag)';
}

final RegExp _rich = RegExp(
  r'@\[([^\]\n]{1,80})\]\(uid:(\d+)\)|(?<![\p{L}\p{N}_&/#])#([\p{L}\p{N}_]{1,50})',
  unicode: true,
);

final RegExp _hasLetter = RegExp(r'\p{L}', unicode: true);

/// Metni düz/anma/etiket parçalarına ayırır. Birleştirilince görünen metni verir.
List<RichSpan> parseRichText(String text) {
  final out = <RichSpan>[];
  var last = 0;
  void plain(String s) {
    if (s.isEmpty) return;
    if (out.isNotEmpty && out.last.kind == RichKind.text) {
      out[out.length - 1] = RichSpan(RichKind.text, out.last.text + s);
    } else {
      out.add(RichSpan(RichKind.text, s));
    }
  }

  for (final m in _rich.allMatches(text)) {
    plain(text.substring(last, m.start));
    last = m.end;
    final name = m.group(1);
    if (name != null) {
      out.add(RichSpan(RichKind.mention, '@$name', userId: int.tryParse(m.group(2)!)));
    } else {
      final tag = m.group(3)!;
      if (_hasLetter.hasMatch(tag)) {
        out.add(RichSpan(RichKind.hashtag, '#$tag', tag: tag));
      } else {
        plain(m.group(0)!);
      }
    }
  }
  plain(text.substring(last));
  return out;
}

/// Anma işaretlerini `@Ad` olarak açılmış, kırpma ölçümü/önizleme için düz metin.
String richPlain(String text) => parseRichText(text).map((e) => e.text).join();

/// Metne eklenecek anma işareti.
String mentionToken(int userId, String displayName) {
  final name = displayName.replaceAll(RegExp(r'[\[\]\n]'), ' ').trim();
  return '@[$name](uid:$userId)';
}

/// Anma ve etiketleri vurgulayan, dokununca profile / etiket akışına giden metin.
/// [onMention] / [onTag] verilmezse varsayılan yönlendirme kullanılır ([session] gerekir).
class RichPostText extends StatefulWidget {
  const RichPostText(
    this.text, {
    super.key,
    required this.style,
    this.session,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.onMention,
    this.onTag,
    this.prefix,
  });

  final String text;
  final TextStyle style;
  final Session? session;
  final int? maxLines;
  final TextOverflow overflow;
  final void Function(int userId, String name)? onMention;
  final ValueChanged<String>? onTag;

  /// Metnin önüne eklenen parça (yanıtlanan kullanıcı adı gibi).
  final InlineSpan? prefix;

  @override
  State<RichPostText> createState() => _RichPostTextState();
}

class _RichPostTextState extends State<RichPostText> {
  final List<TapGestureRecognizer> _recs = [];

  @override
  void dispose() {
    for (final r in _recs) {
      r.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _rec(VoidCallback f) {
    final r = TapGestureRecognizer()..onTap = f;
    _recs.add(r);
    return r;
  }

  void _mention(int id, String name) {
    final cb = widget.onMention;
    if (cb != null) return cb(id, name);
    final s = widget.session;
    if (s != null) openUserProfile(context, s, userId: id, name: name.replaceFirst('@', ''));
  }

  void _tag(String tag) {
    final cb = widget.onTag;
    if (cb != null) return cb(tag);
    final s = widget.session;
    if (s != null) openHashtagPosts(context, s, tag);
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recs) {
      r.dispose();
    }
    _recs.clear();
    final t = context.bu;
    final hi = widget.style.copyWith(color: t.pr, fontWeight: FontWeight.w600);
    final spans = <InlineSpan>[
      if (widget.prefix != null) widget.prefix!,
      for (final s in parseRichText(widget.text))
        switch (s.kind) {
          RichKind.text => TextSpan(text: s.text),
          RichKind.mention => TextSpan(
              text: s.text,
              style: hi,
              semanticsLabel: 'Kullanıcı ${s.text.substring(1)}',
              recognizer: _rec(() => _mention(s.userId ?? 0, s.text))),
          RichKind.hashtag => TextSpan(
              text: s.text,
              style: hi,
              semanticsLabel: 'Etiket ${s.tag}',
              recognizer: _rec(() => _tag(s.tag!))),
        },
    ];
    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
