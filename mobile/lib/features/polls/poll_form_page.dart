import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'anket_style.dart';
import 'anket_widgets.dart';
import 'poll_api.dart';
import 'poll_models.dart';

/// Kulüp yöneticisi için anket oluşturma formu (tasarım 31): başlık, açıklama, tür, seçenekler 2-12,
/// bitiş (hızlı süre + seçici), sonuç görünürlüğü, gizli oy ve bildirim anahtarları. Tek kaydırmalı sayfa.
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
  String? _error;
  bool _busy = false;

  /// Kullanıcının az önce eklediği seçenek alanı (odak alır, ekrana kaydırılır); ilk iki alan odak istemez.
  TextEditingController? _justAdded;

  @override
  void initState() {
    super.initState();
    _closesAt = DateTime.now().add(const Duration(days: 7));
    _title.addListener(() => setState(() {}));
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

  String _fmt(DateTime d) {
    return DateFormat('d MMMM y, HH:mm', Localizations.localeOf(context).toString()).format(d);
  }

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
    setState(() => _closesAt = DateTime(d.year, d.month, d.day, tm.hour, tm.minute));
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

  /// Dolu (sf2) girdi süsü: çerçevesiz, odakta marka halkası.
  InputDecoration _deco(BuTokens t, String? hint) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(borderRadius: BuRadius.bSm, borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      counterText: '',
      filled: true,
      fillColor: t.sf2,
      border: b(t.sf2, 0),
      enabledBorder: b(t.sf2, 0),
      focusedBorder: b(t.pr, 2),
      contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 14),
    );
  }

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
      (PollType.single, LucideIcons.circleDot, l.pollTypeSingle, l.p13PollTypeSingleHint),
      (PollType.multi, LucideIcons.listChecks, l.pollTypeMulti, l.p13PollTypeMultiHint),
      (PollType.rating, LucideIcons.star, l.pollTypeRating, l.p13PollTypeRatingHint),
      (PollType.ranked, LucideIcons.listOrdered, l.pollTypeRanked, l.p13PollTypeRankedHint),
    ];
    Widget typeCard(int i) {
      final (type, icon, label, hint) = types[i];
      return Expanded(
        child: _TypeCard(icon: icon, label: label, hint: hint, selected: _type == type, onTap: () => setState(() => _type = type)),
      );
    }

    final label = tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800);
    return BuPageScaffold(
      title: l.pollCreate,
      large: false,
      bottomInset: 24,
      bottomBar: _bottomBar(l),
      slivers: [
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              BuCard(
                padding: const EdgeInsetsDirectional.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text.rich(TextSpan(style: label, children: [
                          TextSpan(text: l.pollFieldTitle),
                          TextSpan(text: ' *', style: TextStyle(color: t.pr)),
                        ])),
                      ),
                    ),
                    Text('${_title.text.characters.length}/$_maxTitle', style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _title,
                    maxLength: _maxTitle,
                    textInputAction: TextInputAction.next,
                    decoration: _deco(t, l.pollTitleHint),
                  ),
                  const SizedBox(height: 18),
                  Text(l.pollFieldDesc, style: label),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _desc,
                    maxLines: 4,
                    minLines: 3,
                    maxLength: 1000,
                    decoration: _deco(t, l.pollDescHint),
                  ),
                  const SizedBox(height: 18),
                  Semantics(header: true, child: Text(l.p13PollFormType, style: label)),
                  const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [typeCard(0), const SizedBox(width: 10), typeCard(1)]),
                  ),
                  const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [typeCard(2), const SizedBox(width: 10), typeCard(3)]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: BuMotion.of(context, BuMotion.medium),
                child: _type == PollType.rating
                    ? const SizedBox(key: ValueKey('noOptions'), width: double.infinity)
                    : Padding(
                        key: const ValueKey('options'),
                        padding: const EdgeInsets.only(bottom: 16),
                        child: BuCard(
                          padding: const EdgeInsetsDirectional.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Semantics(header: true, child: Text(l.p13PollOptionsTitle, style: label)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
                                child: Text('${_opts.length} / $_maxOptions', style: tx.labelSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                              ),
                              const Spacer(),
                              Flexible(child: Text(l.p13PollMin2, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: t.mut))),
                            ]),
                            const SizedBox(height: 12),
                            for (var i = 0; i < _opts.length; i++)
                              _Appear(
                                key: ObjectKey(_opts[i]),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(children: [
                                    SizedBox(
                                      width: 20,
                                      child: ExcludeSemantics(
                                        child: Text('${i + 1}', textAlign: TextAlign.center, style: tx.labelLarge!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _opts[i],
                                        maxLength: 100,
                                        autofocus: identical(_opts[i], _justAdded),
                                        decoration: _deco(t, l.pollOptionHint('${i + 1}')).copyWith(
                                          suffixIcon: _opts.length > 1
                                              ? IconButton(
                                                  tooltip: l.pollRemoveOption,
                                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                                  icon: Icon(LucideIcons.trash2, size: 20, color: t.mut),
                                                  onPressed: () => _removeOption(i),
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                            if (_opts.length < _maxOptions)
                              Material(
                                color: t.sf2,
                                borderRadius: BuRadius.bSm,
                                child: InkWell(
                                  borderRadius: BuRadius.bSm,
                                  onTap: _addOption,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(minHeight: 52),
                                    child: Center(
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        ExcludeSemantics(child: Icon(LucideIcons.circlePlus, size: 20, color: t.pr)),
                                        const SizedBox(width: 8),
                                        Flexible(child: Text(l.pollAddOption, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800))),
                                      ]),
                                    ),
                                  ),
                                ),
                              ),
                          ]),
                        ),
                      ),
              ),
              _Heading(icon: LucideIcons.clock, title: l.pollFieldEnd),
              BuCard(
                padding: const EdgeInsetsDirectional.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Localizations.localeOf(context).languageCode == 'tr' ? trUpper(l.p13PollQuick) : l.p13PollQuick.toUpperCase(), style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w800, letterSpacing: .6)),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (final days in const [1, 3, 7]) ...[
                      if (days != 1) const SizedBox(width: 8),
                      Expanded(
                        child: _DurationButton(
                          label: l.pollDurDays('$days'),
                          selected: _closesAt != null && _daysLeft() == days,
                          onTap: () => setState(() => _closesAt = DateTime.now().add(Duration(days: days))),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 12),
                  Material(
                    color: t.sf2,
                    borderRadius: BuRadius.bSm,
                    child: InkWell(
                      borderRadius: BuRadius.bSm,
                      onTap: _pickEnd,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
                        child: Row(children: [
                          AnketIconTile(LucideIcons.calendarClock, bg: t.sf, fg: t.ink, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _closesAt == null
                                ? Text(l.pollPickDateTime, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800))
                                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(l.p13PollDateTime, style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
                                    Text(_fmt(_closesAt!), style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                                  ]),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bPill),
                            child: Text(l.pollChange, style: tx.labelMedium!.copyWith(color: t.onSoft, fontWeight: FontWeight.w800)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              _Heading(icon: LucideIcons.eye, title: l.anketVisTitle),
              BuCard(
                padding: const EdgeInsetsDirectional.all(8),
                child: Column(children: [
                  for (final o in visOptions)
                    _RadioRow(label: o.$2, sub: o.$3, selected: _showResults == o.$1, onTap: () => setState(() => _showResults = o.$1)),
                ]),
              ),
              const SizedBox(height: 20),
              _Heading(icon: LucideIcons.slidersHorizontal, title: l.p13PollPrefs),
              BuCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  BuSettingsTile.toggle(
                    icon: LucideIcons.lock,
                    title: l.pollAnonymous,
                    subtitle: l.pollAnonymousSub,
                    tint: t.tint(1),
                    value: _anonymous,
                    onChanged: (v) => setState(() => _anonymous = v),
                  ),
                  Padding(padding: const EdgeInsetsDirectional.symmetric(horizontal: 16), child: Divider(height: 1, color: t.bd)),
                  BuSettingsTile.toggle(
                    icon: LucideIcons.bellRing,
                    title: l.anketNotifyTitle,
                    subtitle: l.anketNotifySub,
                    tint: t.tint(1),
                    value: _notify,
                    onChanged: (v) => setState(() => _notify = v),
                  ),
                ]),
              ),
              AnimatedSize(
                duration: BuMotion.of(context, BuMotion.medium),
                curve: BuMotion.emphasized,
                alignment: Alignment.topCenter,
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        key: _errKey,
                        padding: const EdgeInsets.only(top: 20),
                        child: _ErrorBox(text: _error!),
                      ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  /// Sabit alt çubuk: Yayınla. Klavye açıkken de görünür kalır.
  Widget _bottomBar(AppLocalizations l) => AnketBottomBar(
        solid: true,
        child: BuButton(label: l.pollPublish, icon: LucideIcons.megaphone, busy: _busy, onPressed: _submit),
      );
}

/// Bölüm başlığı: solda marka renginde küçük simge.
class _Heading extends StatelessWidget {
  const _Heading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 2, bottom: 10),
        child: AnketHeading(title: title, icon: icon),
      );
}

/// Doğrulama/sunucu hatası kutusu (kırmızı çerçeveli).
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.danger.withValues(alpha: .35))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ExcludeSemantics(child: Padding(padding: const EdgeInsets.only(top: 1), child: Icon(LucideIcons.circleAlert, size: 18, color: t.danger))),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.danger, fontWeight: FontWeight.w600, height: 1.4))),
        ]),
      ),
    );
  }
}

/// Hızlı süre düğmesi: seçiliyken dolu marka rengi.
class _DurationButton extends StatelessWidget {
  const _DurationButton({required this.label, required this.selected, required this.onTap});

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
      child: AnimatedContainer(
        duration: BuMotion.of(context, BuMotion.short),
        decoration: BoxDecoration(color: selected ? t.pr : t.sf2, borderRadius: BuRadius.bSm),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BuRadius.bSm,
            onTap: () {
              if (!selected) buHaptic(BuHaptic.selection);
              onTap();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(color: selected ? t.onPr : t.ink, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tür kartı: simge + ad + kısa açıklama; seçiliyken marka tonu ve onay rozeti.
class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.icon, required this.label, required this.hint, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$label. $hint',
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        scale: .97,
        child: AnimatedContainer(
          duration: BuMotion.of(context, BuMotion.short),
          curve: BuMotion.standard,
          decoration: BoxDecoration(color: selected ? t.soft : t.sf2, borderRadius: BuRadius.bMd),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BuRadius.bMd,
              onTap: () {
                if (!selected) buHaptic(BuHaptic.selection);
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle),
                        child: Icon(icon, size: 19, color: selected ? t.pr : t.ink),
                      ),
                      if (selected)
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle),
                          child: Icon(LucideIcons.check, size: 15, color: t.onPr),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    Text(label, style: tx.titleSmall!.copyWith(color: selected ? t.pr : t.ink, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(hint, style: tx.bodySmall!.copyWith(color: selected ? t.onSoft.withValues(alpha: .85) : t.mut, height: 1.35)),
                  ],
                ),
              ),
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

/// Tek seçimli satır (sonuç görünürlüğü): solda radyo, başlık + alt metin; seçiliyken yumuşak marka zemini.
class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.label, required this.sub, required this.selected, required this.onTap});

  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: '$label. $sub',
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: BuMotion.of(context, BuMotion.short),
        decoration: BoxDecoration(color: selected ? t.soft.withValues(alpha: .6) : null, borderRadius: BuRadius.bSm),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BuRadius.bSm,
            onTap: () {
              if (!selected) buHaptic(BuHaptic.selection);
              onTap();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  AnketMark(on: selected, square: false),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 1),
                      Text(sub, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.35)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
