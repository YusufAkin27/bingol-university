import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'anket_style.dart';
import 'poll_api.dart';
import 'poll_models.dart';

/// Kulüp yöneticisi için anket oluşturma formu (tasarım An4): soru, açıklama, tür, seçenekler 2-12,
/// bitiş, sonuç görünürlüğü, gizli oy ve bildirim anahtarları.
class PollFormPage extends StatefulWidget {
  const PollFormPage({super.key, required this.session, required this.communityId});

  final Session session;
  final int communityId;

  @override
  State<PollFormPage> createState() => _PollFormPageState();
}

class _PollFormPageState extends State<PollFormPage> {
  static const _maxOptions = 12;

  late final PollApi _api = PollApi(widget.session);
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final List<TextEditingController> _opts = [TextEditingController(), TextEditingController()];
  PollType _type = PollType.single;
  bool _anonymous = false;
  bool _notify = true;
  String _showResults = 'AFTER_VOTE';
  DateTime? _closesAt;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _closesAt = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    for (final c in _opts) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final base = _closesAt ?? now.add(const Duration(days: 7));
    final d = await showDatePicker(
        context: context, initialDate: base.isBefore(now) ? now : base, firstDate: now, lastDate: now.add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final tm = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (tm == null || !mounted) return;
    setState(() => _closesAt = DateTime(d.year, d.month, d.day, tm.hour, tm.minute));
  }

  Future<void> _submit() async {
    final opts = [for (final c in _opts) c.text];
    final err = validatePollDraft(title: _title.text, type: _type, options: opts, closesAt: _closesAt, l10n: context.l10n);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final p = await _api.createCommunity(
        communityId: widget.communityId,
        title: _title.text,
        description: _desc.text,
        type: _type,
        anonymous: _anonymous,
        closesAt: _closesAt!,
        options: [for (final o in opts) if (o.trim().isNotEmpty) o],
        showResults: _showResults,
        notify: _notify,
      );
      if (mounted) Navigator.pop(context, p);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = pollErrorText(e, context.l10n);
          _busy = false;
        });
      }
    }
  }

  /// Seçili bitişe en yakın gün sayısı (hazır seçenek vurgusu için).
  int _daysLeft() => (_closesAt!.difference(DateTime.now()).inHours / 24).round();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final visOptions = [
      ('ALWAYS', l.anketVisAlways),
      ('AFTER_VOTE', l.anketVisAfterVote),
      ('AFTER_CLOSE', l.anketVisAfterClose),
    ];
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          BuHeader(title: l.pollCreate, onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                _label(t, l.anketFieldQuestion),
                TextField(
                  controller: _title,
                  maxLength: 140,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(hintText: l.pollTitleHint, counterText: ''),
                ),
                _label(t, l.pollFieldDesc),
                TextField(
                  controller: _desc,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(hintText: l.pollDescHint, counterText: ''),
                ),
                _label(t, l.pollFieldType),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _Pick(label: l.pollTypeSingle, selected: _type == PollType.single, onTap: () => setState(() => _type = PollType.single)),
                  _Pick(label: l.pollTypeMulti, selected: _type == PollType.multi, onTap: () => setState(() => _type = PollType.multi)),
                  _Pick(label: l.pollTypeRanked, selected: _type == PollType.ranked, onTap: () => setState(() => _type = PollType.ranked)),
                  _Pick(label: l.pollTypeRating, selected: _type == PollType.rating, onTap: () => setState(() => _type = PollType.rating)),
                ]),
                if (_type != PollType.rating) ...[
                  _label(t, l.pollFieldOptions('$_maxOptions')),
                  for (var i = 0; i < _opts.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _opts[i],
                            maxLength: 80,
                            decoration: InputDecoration(hintText: l.pollOptionHint('${i + 1}'), counterText: ''),
                          ),
                        ),
                        if (_opts.length > 2) ...[
                          const SizedBox(width: 8),
                          BuIconButton(
                            icon: LucideIcons.x,
                            size: 44,
                            tooltip: l.pollRemoveOption,
                            onTap: () => setState(() => _opts.removeAt(i).dispose()),
                          ),
                        ],
                      ]),
                    ),
                  if (_opts.length < _maxOptions)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Semantics(
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _opts.add(TextEditingController())),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(LucideIcons.plus, size: 18, color: t.pr),
                                const SizedBox(width: 8),
                                Text(l.pollAddOption, style: anketText(14, FontWeight.w700, t.pr)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                _label(t, l.pollFieldEnd),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final days in const [1, 3, 7])
                    _Pick(
                        label: l.pollDurDays('$days'),
                        selected: _closesAt != null && _daysLeft() == days,
                        onTap: () => setState(() => _closesAt = DateTime.now().add(Duration(days: days)))),
                ]),
                const SizedBox(height: 8),
                Material(
                  color: t.sf,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.bd, width: 1.5)),
                  child: InkWell(
                    customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onTap: _pickEnd,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          Icon(LucideIcons.clock, size: 16, color: t.mut),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(_closesAt == null ? l.pollPickDateTime : _fmt(_closesAt!),
                                  style: anketText(14, FontWeight.w600, t.ink))),
                          Text(l.pollChange, style: anketText(12.5, FontWeight.w700, t.pr)),
                        ]),
                      ),
                    ),
                  ),
                ),
                _label(t, l.anketVisTitle),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: anketCardDeco(t),
                  child: Column(children: [
                    for (var i = 0; i < visOptions.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: t.sf2),
                      Semantics(
                        inMutuallyExclusiveGroup: true,
                        checked: _showResults == visOptions[i].$1,
                        label: visOptions[i].$2,
                        excludeSemantics: true,
                        onTap: () => setState(() => _showResults = visOptions[i].$1),
                        child: InkWell(
                          onTap: () => setState(() => _showResults = visOptions[i].$1),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 56),
                            child: Row(children: [
                              const SizedBox(width: 4),
                              AnketMark(on: _showResults == visOptions[i].$1, square: false),
                              const SizedBox(width: 12),
                              Expanded(child: Text(visOptions[i].$2, style: anketText(13.5, FontWeight.w600, t.ink))),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 16),
                _SwitchCard(
                    title: l.pollAnonymous,
                    sub: l.pollAnonymousSub,
                    value: _anonymous,
                    onChanged: (v) => setState(() => _anonymous = v)),
                const SizedBox(height: 12),
                _SwitchCard(
                    title: l.anketNotifyTitle,
                    sub: l.anketNotifySub,
                    value: _notify,
                    onChanged: (v) => setState(() => _notify = v)),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                        liveRegion: true, child: Text(_error!, style: BuType.body.copyWith(color: t.danger))),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          AnketBottomBar(child: AnketPrimaryButton(label: l.pollPublish, busy: _busy, onPressed: _busy ? null : _submit)),
    );
  }

  Widget _label(BuTokens t, String s) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 0, 6),
      child: Text(s, style: anketText(13, FontWeight.w700, t.ink)));
}

/// 44 dp hap seçici (tür / bitiş).
class _Pick extends StatelessWidget {
  const _Pick({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? t.soft : t.sf,
        shape: StadiumBorder(side: BorderSide(color: selected ? t.pr : t.bd, width: 1.5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: anketText(13, FontWeight.w700, selected ? t.pr : t.mut)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Başlık + açıklama + anahtar kartı.
class _SwitchCard extends StatelessWidget {
  const _SwitchCard({required this.title, required this.sub, required this.value, required this.onChanged});

  final String title;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      decoration: anketCardDeco(t),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
      child: MergeSemantics(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: anketText(14, FontWeight.w700, t.ink)),
              const SizedBox(height: 1),
              Text(sub, style: anketText(12, FontWeight.w500, t.mut, height: 1.3)),
            ]),
          ),
          Switch(value: value, onChanged: onChanged),
        ]),
      ),
    );
  }
}
