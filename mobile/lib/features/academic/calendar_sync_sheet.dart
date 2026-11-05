import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/platform/device_calendar.dart';
import '../../widgets/bu.dart';
import 'acad_ref_widgets.dart';
import 'academic_models.dart';
import 'calendar_sync.dart';

/// "Cihaz takvimine ekle" alt sayfası: izin -> (birden çok takvim varsa) takvim seçimi -> yazma -> sonuç özeti.
/// İkinci kez çalıştırmak mevcutları günceller (çift kayıt yok); "Takvimden kaldır" yalnız bizim yazdıklarımızı siler.
Future<bool?> showCalendarSyncSheet(
  BuildContext context, {
  required Future<List<AcademicEvent>> Function(DateTime from, DateTime to) loader,
  CalendarSyncService? service,
}) {
  final l = context.l10n;
  return BuSheet.show<bool>(
    context,
    title: l.calSyncRowTitle,
    builder: (_) => CalendarSyncSheetBody(loader: loader, service: service ?? CalendarSyncService.instance),
  );
}

const _newLocalId = '__new_local__';

class CalendarSyncSheetBody extends StatefulWidget {
  const CalendarSyncSheetBody({super.key, required this.loader, required this.service});

  final Future<List<AcademicEvent>> Function(DateTime from, DateTime to) loader;
  final CalendarSyncService service;

  @override
  State<CalendarSyncSheetBody> createState() => _CalendarSyncSheetBodyState();
}

class _CalendarSyncSheetBodyState extends State<CalendarSyncSheetBody> {
  CalendarSyncState _state = const CalendarSyncState();
  CalAccess? _access;
  List<DeviceCalendarInfo> _calendars = const [];
  String? _target; // seçili takvim kimliği ya da [_newLocalId]
  bool _busy = false;
  String? _error;
  List<String>? _result;

  DeviceCalendarBackend get _backend => widget.service.backend;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final st = await widget.service.state();
    final acc = await _backend.access();
    if (!mounted) return;
    setState(() {
      _state = st;
      _access = acc;
    });
    if (acc == CalAccess.granted) await _loadCalendars();
  }

  Future<void> _loadCalendars() async {
    final cals = await _backend.calendars();
    if (!mounted) return;
    setState(() {
      _calendars = cals;
      final prev = _state.calendarId;
      _target = cals.any((c) => c.id == prev)
          ? prev
          : (cals.where((c) => c.primary).firstOrNull ?? cals.firstOrNull)?.id;
    });
  }

  Future<void> _openSettings() => PermissionService.instance.openSettings();

  Future<void> _run() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    var acc = _access ?? await _backend.access();
    if (acc == CalAccess.notDetermined) {
      acc = await _backend.requestAccess();
      if (!mounted) return;
      setState(() => _access = acc);
      if (acc == CalAccess.granted) {
        await _loadCalendars();
        if (_calendars.length > 1) {
          // Birden çok takvim: yazmadan önce kullanıcı hedefi (seçici görünür) onaylasın.
          if (mounted) setState(() => _busy = false);
          return;
        }
      }
    }
    if (!mounted) return;
    if (acc != CalAccess.granted) {
      setState(() {
        _busy = false;
        _access = acc;
      });
      return;
    }
    if (_calendars.isEmpty) await _loadCalendars();
    if (!mounted) return;

    DeviceCalendarInfo? target;
    if (_target == _newLocalId || _calendars.isEmpty) {
      final id = await _backend.createCalendar('BÜ Kampüs');
      if (id == null) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = l.calSyncCreateFail;
          });
        }
        return;
      }
      target = DeviceCalendarInfo(id: id, name: 'BÜ Kampüs', local: true);
    } else {
      target = _calendars.where((c) => c.id == _target).firstOrNull ?? _calendars.first;
    }

    final today = istanbulWall(academicClock());
    final from = DateTime.utc(today.year, today.month, today.day);
    final to = from.add(const Duration(days: 365));
    List<AcademicEvent> events;
    try {
      events = await widget.loader(from, to);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.calSyncFetchError;
        });
      }
      return;
    }
    if (!mounted) return;
    if (events.isEmpty && _state.links.isEmpty) {
      setState(() {
        _busy = false;
        _error = l.calSyncEmpty;
      });
      return;
    }
    final r = await widget.service.sync(
      target: target,
      events: events,
      windowEnd: isoDate(to),
      notesOf: (e) => [
        eventKindLabelL(l, e.kind),
        if (e.note != null) e.note!,
      ].join('\n'),
    );
    final st = await widget.service.state();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _state = st;
      _result = [
        l.calSyncResult(r.added.toString(), r.updated.toString(), r.unchanged.toString()),
        if (r.removed > 0) l.calSyncRemovedN(r.removed.toString()),
        if (r.failed > 0) l.calSyncFailedN(r.failed.toString()),
      ];
    });
  }

  Future<void> _remove() async {
    final l = context.l10n;
    final n = _state.activeCount(widget.service.todayIso);
    final ok = await BuConfirmSheet.show(
      context,
      title: l.calSyncRemoveTitle,
      message: l.calSyncRemoveBody(n.toString()),
      confirmLabel: l.calSyncRemove,
      destructive: true,
      icon: BuIcons.calendarX,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final removed = await widget.service.removeAll();
    final st = await widget.service.state();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _state = st;
      _result = [l.calSyncRemoveDone(removed.toString())];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final res = _result;
    if (res != null) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final s in res) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(s, style: tx.bodyLarge!.copyWith(color: t.ink, height: 1.4))),
        const SizedBox(height: 8),
        BuButton(label: l.commonClose, onPressed: () => Navigator.of(context).pop(true)),
      ]);
    }
    final active = _state.activeCount(widget.service.todayIso);
    final denied = _access == CalAccess.denied;
    final unavailable = _access == CalAccess.unavailable;
    final showPicker = _access == CalAccess.granted && _calendars.length > 1;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (active > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(l.calSyncRowDone(active.toString()), style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
        ),
      Text(_access == CalAccess.notDetermined ? l.calSyncRationale : l.calSyncSheetBody, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
      if (_access == CalAccess.granted && _calendars.isEmpty)
        Padding(padding: const EdgeInsets.only(top: 12), child: Text(l.calSyncNoCalendar, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4))),
      if (showPicker) ...[
        const SizedBox(height: 16),
        Semantics(header: true, child: Text(l.calSyncTarget, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400))),
        const SizedBox(height: 4),
        for (final c in _calendars) _TargetRow(title: c.name, sub: c.account, selected: _target == c.id, onTap: () => setState(() => _target = c.id)),
        _TargetRow(title: l.calSyncNewLocal, selected: _target == _newLocalId, onTap: () => setState(() => _target = _newLocalId)),
      ],
      if (denied) ...[
        const SizedBox(height: 16),
        AcadAmberNote(text: l.calSyncDenied, actionLabel: l.calSyncOpenSettings, onAction: _openSettings),
      ],
      if (unavailable) ...[
        const SizedBox(height: 16),
        AcadAmberNote(text: l.calSyncUnavailable),
      ],
      if (_error != null) ...[
        const SizedBox(height: 16),
        AcadAmberNote(text: _error!),
      ],
      const SizedBox(height: 20),
      if (!unavailable)
        BuButton(
          label: active > 0 ? l.calSyncUpdate : l.calSyncAdd,
          icon: BuIcons.calendarPlus,
          busy: _busy,
          onPressed: (denied || _access == null) ? null : _run,
        ),
      if (active > 0)
        TextButton(
          onPressed: _busy ? null : _remove,
          style: TextButton.styleFrom(foregroundColor: t.danger, minimumSize: const Size.fromHeight(48)),
          child: Text(l.calSyncRemove, style: tx.labelLarge!.copyWith(color: t.danger, fontWeight: FontWeight.w400)),
        ),
    ]);
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.title, this.sub = '', required this.selected, required this.onTap});

  final String title, sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: sub.isEmpty ? title : '$title, $sub',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: () {
          buHaptic(BuHaptic.selection);
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(fontSize: 16, color: t.ink, fontWeight: selected ? FontWeight.w400 : BuType.emphasisWeight)),
                if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
              ]),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 24, child: selected ? Icon(BuIcons.check, size: 20, color: t.ink) : null),
          ]),
        ),
      ),
    );
  }
}
