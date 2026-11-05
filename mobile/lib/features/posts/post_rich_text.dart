import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../profile/user_profile_page.dart' show openUserProfile;
import 'post_models.dart';

/// Metnin bir parçası: düz yazı ya da etiketlenen kişiye bağlı `@Ad Soyad`.
class PostTextPart {
  const PostTextPart(this.text, [this.mention]);

  final String text;
  final PostMention? mention;
}

/// [text] içindeki `@Ad Soyad` parçalarını (yalnız [mentions] listesindeki adlarla eşleşenler) ayırır. Ad, harf/rakamla
/// devam ediyorsa (`@Ali` / `@Alim`) eşleşmez. En uzun ad önce denenir (`Ali Can` / `Ali`).
List<PostTextPart> splitMentions(String text, List<PostMention> mentions) {
  if (text.isEmpty || mentions.isEmpty) return [PostTextPart(text)];
  final byName = <String, PostMention>{};
  for (final m in mentions) {
    byName.putIfAbsent(m.displayName, () => m);
  }
  final names = byName.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  final re = RegExp('@(${names.map(RegExp.escape).join('|')})(?![\\p{L}\\p{N}_])', unicode: true);
  final out = <PostTextPart>[];
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) out.add(PostTextPart(text.substring(last, m.start)));
    final name = m.group(1)!;
    out.add(PostTextPart('@$name', byName[name]));
    last = m.end;
  }
  if (last < text.length) out.add(PostTextPart(text.substring(last)));
  return out;
}

/// Gönderi metni: etiketler marka renginde (kalın değil) ve dokununca kişinin profilini açar. Etiket yoksa düz [Text].
class PostRichText extends StatefulWidget {
  const PostRichText({
    super.key,
    required this.session,
    required this.text,
    required this.mentions,
    required this.style,
    this.mentionColor,
    this.mentionUnderline = false,
    this.maxLines,
    this.overflow,
    this.onMention,
  });

  final Session session;
  final String text;
  final List<PostMention> mentions;
  final TextStyle? style;

  /// Verilmezse `t.ink` (açık/koyu temada okunur marka rengi); koyu zeminde (Reels) çağıran açık bir renk verir.
  final Color? mentionColor;

  /// Koyu görüntü üstünde (Reels) renk yetmediği için etiketi alt çizgiyle ayırır.
  final bool mentionUnderline;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Testler/çağıran için: varsayılan davranış kişinin profilini açmaktır.
  final void Function(PostMention mention)? onMention;

  @override
  State<PostRichText> createState() => _PostRichTextState();
}

class _PostRichTextState extends State<PostRichText> {
  final _recognizers = <TapGestureRecognizer>[];

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

  void _open(PostMention m) {
    final cb = widget.onMention;
    if (cb != null) {
      cb(m);
    } else {
      openUserProfile(context, widget.session, userId: m.userId, name: m.displayName);
    }
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final parts = splitMentions(widget.text, widget.mentions);
    if (parts.every((p) => p.mention == null)) {
      return Text(widget.text, maxLines: widget.maxLines, overflow: widget.overflow, style: widget.style);
    }
    final color = widget.mentionColor ?? context.bu.ink;
    final spans = <InlineSpan>[];
    for (final p in parts) {
      final m = p.mention;
      if (m == null) {
        spans.add(TextSpan(text: p.text));
        continue;
      }
      final rec = TapGestureRecognizer()..onTap = () => _open(m);
      _recognizers.add(rec);
      spans.add(TextSpan(
        text: p.text,
        recognizer: rec,
        semanticsLabel: context.l10n.postMentionOpen(m.displayName),
        style: TextStyle(
            color: color,
            fontWeight: FontWeight.w400,
            decoration: widget.mentionUnderline ? TextDecoration.underline : null,
            decorationColor: color),
      ));
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      style: widget.style,
    );
  }
}
