import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'rich_text.dart';
import 'social_api.dart';
import 'social_models.dart';

/// İmlecin bulunduğu yerdeki `@anma` ya da `#etiket` taslağı.
class AssistTrigger {
  const AssistTrigger(this.char, this.query, this.start, this.end);

  /// `@` ya da `#`.
  final String char;
  final String query;

  /// Tetikleyici karakterin dizini ve imlecin dizini (değiştirilecek aralık).
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is AssistTrigger && other.char == char && other.query == query && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(char, query, start, end);
}

final RegExp _nameChar = RegExp(r'[\p{L}\p{N}_ .\-]', unicode: true);

/// [cursor] konumundan geriye bakıp açık bir `@`/`#` taslağı bulur; yoksa null.
/// `@`: başta ya da boşluktan sonra, en çok 25 karakter ve bir boşluk (ad soyad). Zaten biçimli
/// `@[..](uid:..)` içinde tetiklenmez. `#`: harf/rakam/alt çizgi.
AssistTrigger? findAssistTrigger(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  var i = cursor - 1;
  var spaces = 0;
  while (i >= 0 && cursor - i <= 26) {
    final ch = text[i];
    if (ch == '@' || ch == '#') {
      final before = i == 0 ? ' ' : text[i - 1];
      if (!RegExp(r'\s').hasMatch(before) && i != 0) return null;
      final q = text.substring(i + 1, cursor);
      if (ch == '@' && q.startsWith('[')) return null;
      if (ch == '#' && q.contains(' ')) return null;
      return AssistTrigger(ch, q, i, cursor);
    }
    if (ch == '\n') return null;
    final tagMode = !_nameChar.hasMatch(ch);
    if (tagMode) return null;
    if (ch == ' ') {
      spaces++;
      if (spaces > 1) return null;
    }
    i--;
  }
  return null;
}

/// Metne öneri yerleştirir: tetikleyici aralığını [replacement] + boşlukla değiştirir.
({String text, int cursor}) applySuggestion(String text, AssistTrigger t, String replacement) {
  final out = '${text.substring(0, t.start)}$replacement ${text.substring(t.end)}';
  return (text: out, cursor: t.start + replacement.length + 1);
}

/// Yazı alanının altında/üstünde `@` ve `#` önerilerini gösterir. [controller] yazı alanınınkidir.
/// Anma: `GET /users/mention-suggest?q=`; etiket: `GET /hashtags/suggest?q=` (olmazsa trend etiketler süzülür).
class MentionAssist extends StatefulWidget {
  const MentionAssist({super.key, required this.session, required this.controller, this.maxLength});

  final Session session;
  final TextEditingController controller;

  /// Ekleme sonrası toplam uzunluk bunu aşacaksa öneri uygulanmaz.
  final int? maxLength;

  @override
  State<MentionAssist> createState() => _MentionAssistState();
}

class _MentionAssistState extends State<MentionAssist> {
  AssistTrigger? _trig;
  List<SocialUser> _users = const [];
  List<TrendingTag> _tags = const [];
  Timer? _debounce;
  int _gen = 0;
  bool _loading = false;
  String _lastText = '';
  List<TrendingTag>? _trendCache;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(MentionAssist old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final v = widget.controller.value;
    final sel = v.selection;
    final next = (sel.isValid && sel.isCollapsed) ? findAssistTrigger(v.text, sel.baseOffset) : null;
    if (next == _trig && v.text == _lastText) return;
    _lastText = v.text;
    _debounce?.cancel();
    if (next == null) {
      if (_trig != null) setState(() => _clear());
      return;
    }
    final sameQuery = next.char == _trig?.char && next.query == _trig?.query;
    setState(() => _trig = next);
    if (sameQuery) return;
    _debounce = Timer(const Duration(milliseconds: 250), () => _fetch(next));
  }

  void _clear() {
    _trig = null;
    _users = const [];
    _tags = const [];
    _loading = false;
    _gen++;
  }

  Future<void> _fetch(AssistTrigger t) async {
    final gen = ++_gen;
    setState(() => _loading = true);
    final api = SocialApi(widget.session);
    try {
      if (t.char == '@') {
        final r = await api.mentionSuggest(t.query);
        if (!mounted || gen != _gen) return;
        setState(() {
          _users = r.take(6).toList();
          _loading = false;
        });
      } else {
        List<TrendingTag> r;
        try {
          r = await api.hashtagSuggest(t.query);
        } catch (_) {
          _trendCache ??= await api.trending();
          final q = t.query.toLowerCase();
          r = [for (final e in _trendCache!) if (e.tag.toLowerCase().startsWith(q)) e];
        }
        if (!mounted || gen != _gen) return;
        setState(() {
          _tags = r.take(6).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && gen == _gen) setState(() => _loading = false);
    }
  }

  void _apply(String replacement) {
    final t = _trig;
    if (t == null) return;
    final c = widget.controller;
    final r = applySuggestion(c.text, t, replacement);
    final max = widget.maxLength;
    if (max != null && r.text.characters.length > max) return;
    c.value = TextEditingValue(text: r.text, selection: TextSelection.collapsed(offset: r.cursor));
    setState(_clear);
  }

  @override
  Widget build(BuildContext context) {
    final t = _trig;
    if (t == null) return const SizedBox.shrink();
    final bu = context.bu;
    final isMention = t.char == '@';
    final empty = isMention ? _users.isEmpty : _tags.isEmpty;
    if (empty && !_loading) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('assistList'),
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: bu.sf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bu.bd),
      ),
      clipBehavior: Clip.antiAlias,
      child: empty
          ? const Padding(
              padding: EdgeInsets.all(14),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          : ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: isMention
                  ? [
                      for (final u in _users)
                        Semantics(
                          button: true,
                          label: 'Anma ekle ${u.displayName}',
                          child: InkWell(
                            key: ValueKey('mention-${u.id}'),
                            onTap: () => _apply(mentionToken(u.id, u.displayName)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(children: [
                                BuAvatar(name: u.displayName, url: u.avatarUrl, size: 32),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(u.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: BuType.bodyStrong.copyWith(color: bu.ink)),
                                    if ((u.department ?? '').isNotEmpty)
                                      Text(u.department!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: BuType.caption.copyWith(color: bu.mut)),
                                  ]),
                                ),
                              ]),
                            ),
                          ),
                        ),
                    ]
                  : [
                      for (final g in _tags)
                        Semantics(
                          button: true,
                          label: 'Etiket ekle ${g.tag}',
                          child: InkWell(
                            key: ValueKey('tag-${g.tag}'),
                            onTap: () => _apply('#${g.tag}'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              child: Row(children: [
                                Icon(LucideIcons.hash, size: 16, color: bu.pr),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(g.tag,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: BuType.bodyStrong.copyWith(color: bu.ink))),
                                if (g.postCount > 0)
                                  Text('${g.postCount} gönderi', style: BuType.caption.copyWith(color: bu.mut)),
                              ]),
                            ),
                          ),
                        ),
                    ],
            ),
    );
  }
}
