import 'package:flutter/material.dart';

import '../../core/icons/bu_icons.dart';
import '../../core/live/live_activity_service.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import 'etkinlik2_widgets.dart';

/// Etkinlik ayrıntısında "Canlı takip et": katılan kullanıcı geri sayımı kilit ekranına/Dynamic Island'a (iOS) ya da
/// canlı bildirime (Android) alır. Yalnız kullanıcı dokununca başlar; destek yoksa ya da etkinlik bittiyse görünmez.
class LiveTrackButton extends StatefulWidget {
  const LiveTrackButton({super.key, required this.session, required this.eventId, required this.title, required this.startsAt, required this.endsAt, this.location = ''});

  final Session session;
  final int eventId;
  final String title;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String location;

  @override
  State<LiveTrackButton> createState() => _LiveTrackButtonState();
}

class _LiveTrackButtonState extends State<LiveTrackButton> {
  bool _supported = false;
  bool _active = false;
  bool _busy = false;

  LiveActivityService get _svc => LiveActivityService.of(widget.session.api);

  LiveSpec? get _spec {
    final s = widget.startsAt, e = widget.endsAt;
    if (s == null || e == null) return null;
    return LiveSpec(kind: LiveKind.event, refId: widget.eventId, title: widget.title, startsAt: s, endsAt: e, detail: widget.location);
  }

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    final spec = _spec;
    if (spec == null || spec.phaseAt(DateTime.now()) == null) return;
    final ok = await _svc.supported();
    final active = ok && await _svc.isActive(LiveKind.event, widget.eventId);
    if (!mounted) return;
    setState(() {
      _supported = ok;
      _active = active;
    });
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final l = context.l10n;
    final spec = _spec;
    if (spec == null) return;
    setState(() => _busy = true);
    String? message;
    if (_active) {
      await _svc.stop(LiveKind.event, widget.eventId);
      _active = false;
    } else {
      final r = await _svc.start(spec, LiveLabels(startsIn: l.liveLabelStartsIn, endsIn: l.liveLabelEndsIn, channelName: l.liveChannelName));
      switch (r) {
        case LiveStartResult.started:
          _active = true;
          message = l.liveTrackStarted;
        case LiveStartResult.disabledByUser:
          message = l.liveTrackDisabled;
        default:
          message = l.liveTrackFailed;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();
    final l = context.l10n;
    return Et2GreyButton(
      key: const ValueKey('detail-live-track'),
      label: _active ? l.liveTrackStop : l.liveTrackStart,
      icon: BuIcons.clock,
      onPressed: _busy ? null : _toggle,
    );
  }
}
