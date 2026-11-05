import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/locale_controller.dart';
import '../../../../widgets/bu.dart';
import '../../data/forum_compose_rules.dart';
import 'compose_widgets.dart';

/// Yeni konu formundaki anket oluşturucu: isteğe bağlı soru, 2-6 seçenek (her biri en çok 80 karakter; ekle/sil),
/// bitiş (süresiz / 1-3-7-30 gün / tarih seç, en çok 30 gün) ve "oy değiştirilebilir" anahtarı.
/// Durum [value] ile gelir, her değişiklikte [onChanged] çağrılır; "Anketi kaldır" için [onRemove].
class PollBuilder extends StatefulWidget {
  const PollBuilder({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onRemove,
    this.enabled = true,
    this.now,
  });

  final PollDraft value;
  final ValueChanged<PollDraft> onChanged;
  final VoidCallback onRemove;
  final bool enabled;

  /// Testler için sabit saat.
  final DateTime Function()? now;

  @override
  State<PollBuilder> createState() => _PollBuilderState();
}

class _Opt {
  _Opt(String text) : c = TextEditingController(text: text);
  final TextEditingController c;
  final FocusNode f = FocusNode();
  final Key key = UniqueKey();
  void dispose() {
    c.dispose();
    f.dispose();
  }
}

class _PollBuilderState extends State<PollBuilder> {
  late final TextEditingController _q = TextEditingController(text: widget.value.question);
  late final List<_Opt> _opts = [for (final o in widget.value.options) _Opt(o)];

  @override
  void dispose() {
    _q.dispose();
    for (final o in _opts) {
      o.dispose();
    }
    super.dispose();
  }

  DateTime _now() => (widget.now ?? DateTime.now)();

  PollDraft get _cur => widget.value.copyWith(question: _q.text, options: [for (final o in _opts) o.c.text]);

  void _emit([PollDraft? d]) => widget.onChanged(d ?? _cur);

  void _add() {
    if (_opts.length >= ForumComposeLimits.pollMaxOptions) return;
    final o = _Opt('');
    setState(() => _opts.add(o));
    _emit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) o.f.requestFocus();
    });
  }

  void _remove(int i) {
    if (_opts.length <= ForumComposeLimits.pollMinOptions) return;
    final o = _opts.removeAt(i);
    setState(() {});
    _emit();
    WidgetsBinding.instance.addPostFrameCallback((_) => o.dispose());
  }

  Future<void> _pickDate() async {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final cur = widget.value.endsInDays ?? 7;
    final d = await showDatePicker(
      context: context,
      initialDate: today.add(Duration(days: cur)),
      firstDate: today.add(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: ForumComposeLimits.pollMaxDays)),
    );
    if (d == null || !mounted) return;
    final days = DateTime(d.year, d.month, d.day).difference(today).inDays.clamp(1, ForumComposeLimits.pollMaxDays);
    _emit(_cur.copyWith(endsInDays: days));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final v = widget.value;
    final atMax = _opts.length >= ForumComposeLimits.pollMaxOptions;
    final days = v.endsInDays;
    const quick = [1, 3, 7, 30];
    final onDate = days != null && !quick.contains(days);
    final endsAt = v.endsAt(_now())?.toLocal();
    return Container(
      key: const ValueKey('pollBuilder'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 12),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(BuRadius.md),
        border: Border.all(color: t.bd),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(BuIcons.vote, size: 20, color: t.ink),
          const SizedBox(width: 8),
          Expanded(child: Text(l.forumPollTitle, style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w400))),
          IconButton(
            key: const ValueKey('pollRemove'),
            tooltip: l.forumPollRemove,
            constraints: const BoxConstraints(minWidth: BuSize.touch, minHeight: BuSize.touch),
            onPressed: widget.enabled ? widget.onRemove : null,
            icon: Icon(BuIcons.x, size: 20, color: t.mut),
          ),
        ]),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ComposeBox(
              minHeight: BuSize.touch,
              child: TextField(
                key: const ValueKey('pollQuestion'),
                controller: _q,
                enabled: widget.enabled,
                maxLength: ForumComposeLimits.pollQuestionMax,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => _emit(),
                style: tt.bodyLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w400),
                decoration: composeInputDecoration(context, hint: l.forumPollQuestionHint),
              ),
            ),
            for (var i = 0; i < _opts.length; i++) ...[
              const SizedBox(height: 8),
              KeyedSubtree(
                key: _opts[i].key,
                child: ComposeBox(
                  minHeight: BuSize.touch,
                  trailing: _opts.length > ForumComposeLimits.pollMinOptions
                      ? IconButton(
                          key: ValueKey('pollOptRemove$i'),
                          tooltip: l.forumPollRemoveOption,
                          constraints: const BoxConstraints(minWidth: BuSize.touch, minHeight: BuSize.touch),
                          onPressed: widget.enabled ? () => _remove(i) : null,
                          icon: Icon(BuIcons.minus, size: 18, color: t.mut),
                        )
                      : null,
                  child: TextField(
                    key: ValueKey('pollOpt$i'),
                    controller: _opts[i].c,
                    focusNode: _opts[i].f,
                    enabled: widget.enabled,
                    maxLength: ForumComposeLimits.pollOptionMax,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    textInputAction: i == _opts.length - 1 ? TextInputAction.done : TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\r\n]'))],
                    onChanged: (_) => _emit(),
                    style: tt.bodyLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w400),
                    decoration: composeInputDecoration(context, hint: l.forumPollOptionHint(i + 1)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('pollAddOption'),
                onPressed: widget.enabled && !atMax ? _add : null,
                style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, BuSize.touch)),
                icon: Icon(BuIcons.plus, size: 18, color: atMax ? t.mut : t.pr),
                label: Text(atMax ? l.forumPollMaxOptions(ForumComposeLimits.pollMaxOptions) : l.forumPollAddOption,
                    style: tt.labelLarge?.copyWith(color: atMax ? t.mut : t.pr, fontWeight: FontWeight.w400)),
              ),
            ),
            Text(l.forumPollEndsAt, style: tt.labelMedium?.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
            Wrap(spacing: 8, children: [
              BuChip(
                key: const ValueKey('pollEndsNone'),
                label: l.forumPollEndsNone,
                selected: days == null,
                onTap: widget.enabled ? () => _emit(_cur.copyWith(clearEnds: true)) : null,
              ),
              for (final d in quick)
                BuChip(
                  key: ValueKey('pollEnds$d'),
                  label: l.forumPollEndsDays(d),
                  selected: days == d,
                  onTap: widget.enabled ? () => _emit(_cur.copyWith(endsInDays: d)) : null,
                ),
              BuChip(
                key: const ValueKey('pollEndsPick'),
                label: l.forumPollEndsPickDate,
                icon: BuIcons.calendar,
                selected: onDate,
                onTap: widget.enabled ? _pickDate : null,
              ),
            ]),
            if (endsAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  l.forumPollEndsOn(DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(endsAt)),
                  key: const ValueKey('pollEndsLabel'),
                  style: tt.bodySmall?.copyWith(color: t.mut, fontWeight: FontWeight.w400),
                ),
              ),
            ComposeSwitchRow(
              key: const ValueKey('pollAllowChange'),
              label: l.forumPollAllowChange,
              value: v.allowChangeVote,
              onChanged: widget.enabled ? (b) => _emit(_cur.copyWith(allowChangeVote: b)) : null,
            ),
          ]),
        ),
      ]),
    );
  }
}
