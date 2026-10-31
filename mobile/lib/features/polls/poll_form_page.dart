import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'anket_flat.dart';
import 'poll_api.dart';
import 'poll_models.dart';

/// Kulüp yöneticisi için anket oluşturma formu (Stitch v3 04): başlık, açıklama, tür (metin segmenti), seçenekler 2-12,
/// bitiş (1 / 3 / 7 gün ya da tarih seç), sonuç görünürlüğü (sağda radyo), gizli oy ve bildirim anahtarları (çizgili
/// satır), "Yayınla". Tek kaydırmalı sayfa; kart yok, etiketler alanın üstünde.
class PollFormPage extends StatefulWidget {
  const PollFormPage({super.key, required this.session, required this.communityId});

  final Session session;
  final int communityId;

  @override
  State<PollFormPage> createState() => _PollFormPageState();
}

class _PollFormPageState extends State<PollFormPage> {
  static const _maxOptions = 12;
  static const _maxTitle = 150;

  late final PollApi _api = PollApi(widget.session);
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final List<TextEditingController> _opts = [TextEditingController(), TextEditingController()];
  final _errKey = GlobalKey();
  PollType _type = PollType.single;
  bool _anonymous = true; // kulüp anketinde varsayılan gizli oy (sunucu da COMMUNITY için gizli varsayar)
  bool _notify = true;
  String _showResults = 'AFTER_VOTE';
  DateTime? _closesAt;
  bool _customEnd = false; // tarih seçiciyle belirlenen bitiş
  String? _error;
  bool _busy = false;

  /// Kullanıcının az önce eklediği seçenek alanı (odak alır); ilk iki alan odak istemez.
  TextEditingController? _justAdded;

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

  String _fmtShort(DateTime d) => '${anketDayLabel(context, d)} ${DateFormat('HH:mm').format(d)}';

  /// Bitiş tarihi (A30) ve saati (A31) seçicileri.
  Future<void> _pickEnd() async {
    final l = context.l10n;
    final now = DateTime.now();
    final base = _closesAt ?? now.add(const Duration(days: 7));
    final d = await showDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: l.p13PollPickEndDate,
    );
    if (d == null || !mounted) return;
    final tm = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: l.p13PollPickEndTime,
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (tm == null || !mounted) return;
    setState(() {
      _closesAt = DateTime(d.year, d.month, d.day, tm.hour, tm.minute);
      _customEnd = true;
    });
  }

  Future<void> _submit() async {
    final opts = [for (final c in _opts) c.text];
    final err = validatePollDraft(title: _title.text, type: _type, options: opts, closesAt: _closesAt, l10n: context.l10n);
    if (err != null) {
      buHaptic(BuHaptic.light);
      setState(() => _error = err);
      _showError();
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
        _showError();
      }
    }
  }

  void _showError() => WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _errKey.currentContext;
        if (c != null && mounted) Scrollable.ensureVisible(c, duration: BuMotion.of(context, BuMotion.medium), alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      });

  /// Seçili bitişe en yakın gün sayısı (hazır seçenek vurgusu için).
  int _daysLeft() => (_closesAt!.difference(DateTime.now()).inHours / 24).round();

  void _addOption() {
    final c = TextEditingController();
    setState(() {
      _opts.add(c);
      _justAdded = c;
    });
    buHaptic(BuHaptic.selection);
  }

  void _removeOption(int i) {
    setState(() => _opts.removeAt(i).dispose());
    buHaptic(BuHaptic.selection);
  }

  /// Seçenek sayısıyla ilgili doğrulama metni (alanların altında satır içi gösterilir).
  bool _isOptionError(String e, AppLocalizations l) => e == l.pollValMin2 || e == l.pollValMax12 || e == l.pollValDistinct;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final visOptions = [
      ('ALWAYS', l.anketVisAlways, l.p13PollVisAlwaysSub),
      ('AFTER_VOTE', l.anketVisAfterVote, l.p13PollVisAfterVoteSub),
      ('AFTER_CLOSE', l.anketVisAfterClose, l.p13PollVisAfterCloseSub),
    ];
    final types = [
      (PollType.single, l.pollTypeSingle, l.p13PollTypeSingleHint),
      (PollType.multi, l.p68TypeMulti, l.p13PollTypeMultiHint),
      (PollType.rating, l.pollTypeRating, l.p13PollTypeRatingHint),
      (PollType.ranked, l.p68TypeRanked, l.p13PollTypeRankedHint),
    ];
    final err = _error;
    final optErr = err != null && _isOptionError(err, l);
    final field = tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400);
    return BuPageScaffold(
      title: l.pollCreate,
      large: false,
      bottomInset: 32,
      slivers: [
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 16.5, kAnketPad, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              AnketFieldLabel(l.pollFieldTitle),
              TextField(
                controller: _title,
                maxLength: _maxTitle,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                style: field,
                decoration: anketFieldDeco(context, hint: l.pollTitleHint),
              ),
              AnketFieldLabel(l.pollFieldDesc, top: 25),
              TextField(
                controller: _desc,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                style: field,
                decoration: anketFieldDeco(context, hint: l.pollDescHint, pad: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 12.5)),
              ),
              AnketFieldLabel(l.p68FormKind, top: 26, bottom: 0),
              _TypeSegment(
                items: [for (final x in types) (x.$2, x.$3, _type == x.$1)],
                onTap: (i) => setState(() => _type = types[i].$1),
              ),
              AnimatedSize(
                duration: BuMotion.of(context, BuMotion.medium),
                curve: BuMotion.emphasized,
                alignment: Alignment.topCenter,
                child: _type == PollType.rating
                    ? const SizedBox(width: double.infinity)
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        AnketFieldLabel(l.p68OptionsLabel, top: 22, bottom: 8, trailing: '${_opts.length} / $_maxOptions'),
                        for (var i = 0; i < _opts.length; i++)
                          _Appear(
                            key: ObjectKey(_opts[i]),
                            child: Padding(
                              padding: EdgeInsets.only(bottom: i == _opts.length - 1 ? 0 : 10),
                              child: TextField(
                                controller: _opts[i],
                                maxLength: 100,
                                autofocus: identical(_opts[i], _justAdded),
                                style: field,
                                decoration: anketFieldDeco(
                                  context,
                                  hint: l.pollOptionHint('${i + 1}'),
                                  hasError: optErr && _opts[i].text.trim().isEmpty,
                                  pad: const EdgeInsetsDirectional.fromSTEB(16, 13, 0, 13),
                                  suffixIcon: _opts.length > 1
                                      ? IconButton(
                                          tooltip: l.pollRemoveOption,
                                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                          icon: Icon(LucideIcons.x, size: 20, color: t.mut),
                                          onPressed: () => _removeOption(i),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        Transform.translate(
                          offset: const Offset(0, -3.5), // 48 dp dokunma satırı referanstaki satıra hizalanır
                          child: Row(children: [
                          Expanded(
                            child: optErr
                                ? Semantics(
                                    key: _errKey,
                                    liveRegion: true,
                                    container: true,
                                    child: Text(err, style: tx.bodySmall!.copyWith(color: t.danger, height: 1.35)),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          if (_opts.length < _maxOptions)
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: const EdgeInsetsDirectional.only(start: 12)),
                              onPressed: _addOption,
                              child: Text('+ ${l.pollAddOption}', style: tx.titleSmall!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
                            ),
                        ])),
                      ]),
              ),
              AnketFieldLabel(l.pollFieldEnd, top: 9.5, bottom: 1.5),
              Wrap(spacing: 8, children: [
                for (final days in const [1, 3, 7])
                  _EndChip(
                    label: l.pollDurDays('$days'),
                    selected: !_customEnd && _closesAt != null && _daysLeft() == days,
                    onTap: () => setState(() {
                      _closesAt = DateTime.now().add(Duration(days: days));
                      _customEnd = false;
                    }),
                  ),
                _EndChip(
                  label: _customEnd && _closesAt != null ? _fmtShort(_closesAt!) : l.p68PickDate,
                  selected: _customEnd,
                  onTap: _pickEnd,
                ),
              ]),
              AnketFieldLabel(l.anketVisTitle, top: 19),
              for (final o in visOptions)
                _RadioRow(label: o.$2, sub: o.$3, selected: _showResults == o.$1, onTap: () => setState(() => _showResults = o.$1)),
              const SizedBox(height: 25),
              _SwitchRow(title: l.pollAnonymous, sub: l.pollAnonymousSub, value: _anonymous, onChanged: (v) => setState(() => _anonymous = v)),
              _SwitchRow(title: l.anketNotifyTitle, sub: l.anketNotifySub, value: _notify, onChanged: (v) => setState(() => _notify = v)),
              AnimatedSize(
                duration: BuMotion.of(context, BuMotion.medium),
                curve: BuMotion.emphasized,
                alignment: Alignment.topCenter,
                child: err == null || optErr
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        key: _errKey,
                        padding: const EdgeInsets.only(top: 16),
                        child: Semantics(liveRegion: true, container: true, child: Text(err, style: tx.bodyMedium!.copyWith(color: t.danger, height: 1.4))),
                      ),
              ),
              const SizedBox(height: 33),
              BuButton(label: l.pollPublish, busy: _busy, onPressed: _submit),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Tür seçimi: dört metin parçalı çerçeveli şerit (görünür 40 dp, dokunma alanı 48 dp); seçili parça `soft` zemin + `pr` metin.
class _TypeSegment extends StatelessWidget {
  const _TypeSegment({required this.items, required this.onTap});

  /// (etiket, ipucu, seçili)
  final List<(String, String, bool)> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return SizedBox(
      height: 48,
      child: Stack(children: [
        Positioned.fill(
          top: 4,
          bottom: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.bdStrong)),
          ),
        ),
        Row(children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: items[i].$3,
                inMutuallyExclusiveGroup: true,
                label: '${items[i].$1}. ${items[i].$2}',
                excludeSemantics: true,
                onTap: () => onTap(i),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!items[i].$3) buHaptic(BuHaptic.selection);
                    onTap(i);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
                    child: AnimatedContainer(
                      duration: BuMotion.of(context, BuMotion.short),
                      curve: BuMotion.standard,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(color: items[i].$3 ? t.soft : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(items[i].$1,
                            maxLines: 1,
                            style: tx.labelLarge!.copyWith(color: items[i].$3 ? t.onSoft : t.mut, fontWeight: items[i].$3 ? FontWeight.w700 : FontWeight.w500)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// Bitiş çipi: 34 dp görünür, 48 dp dokunma; seçili `soft` zemin + `pr` metin, değilse çerçeveli.
class _EndChip extends StatelessWidget {
  const _EndChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!selected) buHaptic(BuHaptic.selection);
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: BuMotion.of(context, BuMotion.short),
              curve: BuMotion.standard,
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: selected ? t.soft : t.sf,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: selected ? t.soft : t.bdStrong),
              ),
              child: Center(widthFactor: 1, child: Text(label, maxLines: 1, style: tx.labelLarge!.copyWith(color: selected ? t.onSoft : t.ink, fontWeight: FontWeight.w500))),
            ),
          ),
        ),
      ),
    );
  }
}

/// Seçenek satırı için tek seferlik giriş (solma + hafif kayma).
class _Appear extends StatelessWidget {
  const _Appear({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = BuMotion.of(context, BuMotion.medium);
    if (d == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: d,
      curve: BuMotion.emphasizedDecelerate,
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

/// Tek seçimli satır (sonuç görünürlüğü): solda 16 sp ad, sağda radyo; satırlar arası `bd` ayraç. Alt metin yalnız okuyucuya.
class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.label, required this.sub, required this.selected, required this.onTap});

  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: '$label. $sub',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: () {
          if (!selected) buHaptic(BuHaptic.selection);
          onTap();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 51),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
          child: Row(children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 16, color: t.ink, fontWeight: FontWeight.w400))),
            const SizedBox(width: 12),
            AnketMarkFlat(on: selected),
          ]),
        ),
      ),
    );
  }
}

/// Anahtar satırı: başlık 15 sp/700 + alt metin (muted), sağda anahtar; alt `bd` ayraç. Tüm satır dokunulabilir.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.sub, required this.value, required this.onChanged});

  final String title;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      toggled: value,
      label: '$title. $sub',
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: InkWell(
        onTap: () {
          buHaptic(BuHaptic.selection);
          onChanged(!value);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 71),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.35)),
              ]),
            ),
            const SizedBox(width: 12),
            ExcludeSemantics(child: Switch(value: value, onChanged: (v) {
              buHaptic(BuHaptic.selection);
              onChanged(v);
            })),
          ]),
        ),
      ),
    );
  }
}
