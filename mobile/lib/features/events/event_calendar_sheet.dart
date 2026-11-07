import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/permission_service.dart';
import '../../widgets/bu.dart';
import '../academic/acad_ref_widgets.dart' show AcadAmberNote;
import 'event_calendar.dart';

/// Etkinlik için "Takvime ekle + hatırlat" alt sayfası. [prompt] true ise katılım sonrası öneridir: kısa metin,
/// "Şimdi değil" ve "Bir daha sorma" seçenekleri de görünür. Sonuç: true = takvimde (eklendi/güncellendi),
/// false = kaldırıldı, null = kapatıldı.
Future<bool?> showEventCalendarSheet(
  BuildContext context, {
  required int eventId,
  required String title,
  required DateTime startsAt,
  DateTime? endsAt,
  String location = '',
  bool prompt = false,
  EventCalendarService? service,
}) {
  return BuSheet.show<bool>(
    context,
    title: context.l10n.evCalSheetTitle,
    builder: (_) => EventCalendarSheetBody(
      service: service ?? EventCalendarService.instance,
      eventId: eventId,
      title: title,
      startsAt: startsAt,
      endsAt: endsAt,
      location: location,
      prompt: prompt,
    ),
  );
}

String evCalLeadLabel(BuildContext context, int min) {
  final l = context.l10n;
  return switch (min) {
    15 => l.evCalLead15,
    1440 => l.evCalLead1440,
    _ => l.evCalLead60,
  };
}

class EventCalendarSheetBody extends StatefulWidget {
  const EventCalendarSheetBody({
    super.key,
    required this.service,
    required this.eventId,
    required this.title,
    required this.startsAt,
    this.endsAt,
    this.location = '',
    this.prompt = false,
  });

  final EventCalendarService service;
  final int eventId;
  final String title, location;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool prompt;

  @override
  State<EventCalendarSheetBody> createState() => _EventCalendarSheetBodyState();
}

class _EventCalendarSheetBodyState extends State<EventCalendarSheetBody> {
  int _lead = kEventDefaultLead;
  bool _linked = false;
  bool _busy = false;
  String? _error;
  EventCalResult? _blocked;

  @override
  void initState() {
    super.initState();
    widget.service.linkOf(widget.eventId).then((l) {
      if (!mounted || l == null) return;
      setState(() {
        _linked = true;
        _lead = l.leadMin;
      });
    });
  }

  Future<void> _add() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
      _blocked = null;
    });
    final r = await widget.service.add(
      eventId: widget.eventId,
      title: widget.title,
      startsAt: widget.startsAt,
      endsAt: widget.endsAt,
      location: widget.location,
      leadMin: _lead,
    );
    if (!mounted) return;
    switch (r) {
      case EventCalResult.added:
      case EventCalResult.updated:
        BuToast.show(context, r == EventCalResult.added ? l.evCalAdded : l.evCalUpdated);
        Navigator.of(context).pop(true);
      case EventCalResult.denied:
      case EventCalResult.unavailable:
        setState(() {
          _busy = false;
          _blocked = r;
        });
      case EventCalResult.pastEvent:
        setState(() {
          _busy = false;
          _error = l.evCalPast;
        });
      case EventCalResult.failed:
        setState(() {
          _busy = false;
          _error = l.evCalFailed;
        });
    }
  }

  Future<void> _remove() async {
    final l = context.l10n;
    setState(() => _busy = true);
    await widget.service.remove(widget.eventId);
    if (!mounted) return;
    BuToast.show(context, l.evCalRemoved);
    Navigator.of(context).pop(false);
  }

  Future<void> _never() async {
    await widget.service.setDontAsk(true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.prompt && !_linked ? l.evCalPromptBody : l.evCalBody, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
      const SizedBox(height: 16),
      Semantics(header: true, child: Text(l.evCalRemind, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400))),
      const SizedBox(height: 4),
      for (final m in kEventLeadChoices)
        _LeadRow(
          key: ValueKey('evcal-lead-$m'),
          title: evCalLeadLabel(context, m),
          selected: _lead == m,
          onTap: _busy ? null : () => setState(() => _lead = m),
        ),
      if (_blocked == EventCalResult.denied) ...[
        const SizedBox(height: 12),
        AcadAmberNote(text: l.calSyncDenied, actionLabel: l.calSyncOpenSettings, onAction: () => PermissionService.instance.openSettings()),
      ],
      if (_blocked == EventCalResult.unavailable) ...[
        const SizedBox(height: 12),
        AcadAmberNote(text: l.calSyncUnavailable),
      ],
      if (_error != null) ...[
        const SizedBox(height: 12),
        AcadAmberNote(text: _error!),
      ],
      const SizedBox(height: 16),
      BuButton(
        key: const ValueKey('evcal-add'),
        label: _linked ? l.evCalUpdate : l.evCalAdd,
        icon: BuIcons.calendarPlus,
        busy: _busy,
        onPressed: _busy ? null : _add,
      ),
      if (_linked)
        TextButton(
          key: const ValueKey('evcal-remove'),
          onPressed: _busy ? null : _remove,
          style: TextButton.styleFrom(foregroundColor: t.danger, minimumSize: const Size.fromHeight(48)),
          child: Text(l.evCalRemove, style: tx.labelLarge!.copyWith(color: t.danger, fontWeight: FontWeight.w400)),
        ),
      if (widget.prompt && !_linked) ...[
        TextButton(
          key: const ValueKey('evcal-later'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(l.evCalLater, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
        ),
        TextButton(
          key: const ValueKey('evcal-never'),
          onPressed: _busy ? null : _never,
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(l.evCalNever, style: tx.labelLarge!.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
        ),
      ],
    ]);
  }
}

class _LeadRow extends StatelessWidget {
  const _LeadRow({super.key, required this.title, required this.selected, required this.onTap});

  final String title;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                buHaptic(BuHaptic.selection);
                onTap!();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(children: [
            Expanded(child: Text(title, style: tx.bodyLarge!.copyWith(fontSize: 16, color: t.ink, fontWeight: BuType.emphasisWeight))),
            SizedBox(width: 24, child: selected ? Icon(BuIcons.check, size: 20, color: t.ink) : null),
          ]),
        ),
      ),
    );
  }
}
