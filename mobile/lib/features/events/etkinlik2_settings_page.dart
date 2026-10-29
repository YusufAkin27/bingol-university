import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'etkinlik2_widgets.dart';
import 'event_parts.dart';

/// Sayfadan dönüş: `true` = kaydedildi/iptal edildi (detay yenilensin), `cancelled` ayrıca iptali bildirir.
class Etkinlik2SettingsResult {
  const Etkinlik2SettingsResult({this.cancelled = false});

  final bool cancelled;
}

/// Etkinlik ayarları (organizatör): katılım türü, kontenjan, kayıtları aç/kapat, sohbeti aç/kapat, iptal.
class Etkinlik2SettingsPage extends StatefulWidget {
  const Etkinlik2SettingsPage({super.key, required this.session, required this.event});

  final Session session;
  final Map<String, dynamic> event;

  @override
  State<Etkinlik2SettingsPage> createState() => _Etkinlik2SettingsPageState();
}

class _Etkinlik2SettingsPageState extends State<Etkinlik2SettingsPage> {
  late String _policy;
  late bool _regOpen;
  bool _chatOpen = true;
  bool _chatKnown = false;
  late final bool _initRegOpen;
  late final String _initPolicy;
  late final int? _initCap;
  bool _initChatOpen = true;
  List<String> _questions = const [];
  final _cap = TextEditingController();
  bool _busy = false;
  bool _changed = false;
  String? _error;

  int get _id => (widget.event['id'] as num).toInt();
  int get _going => (widget.event['goingCount'] as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _policy = e['joinPolicy'] == 'APPROVAL' ? 'APPROVAL' : 'OPEN';
    _initPolicy = _policy;
    _regOpen = !eventIsClosed(e);
    _initRegOpen = _regOpen;
    _initCap = (e['capacity'] as num?)?.toInt();
    if (_initCap != null) _cap.text = '$_initCap';
    _loadExtras();
  }

  @override
  void dispose() {
    _cap.dispose();
    super.dispose();
  }

  Future<void> _loadExtras() async {
    final api = widget.session.api;
    try {
      final r = await api.get('/events/$_id/admission');
      if (mounted && r is Map) {
        _questions = (r['questions'] as List? ?? const []).map((e) => '$e').toList();
      }
    } catch (_) {}
    try {
      final r = await api.get('/events/$_id/chat-room');
      if (mounted && r is Map) {
        setState(() {
          _chatOpen = r['closed'] != true;
          _initChatOpen = _chatOpen;
          _chatKnown = true;
        });
      }
    } catch (_) {}
  }

  void _toast(String m) {
    if (!mounted) return;
    BuToast.show(context, m, kind: BuToastKind.success);
  }

  Future<void> _save() async {
    if (_busy) return;
    final l = context.l10n;
    final capText = _cap.text.trim();
    final cap = capText.isEmpty ? null : int.tryParse(capText);
    if (capText.isNotEmpty && (cap == null || cap < 1)) {
      setState(() => _error = l.eventFormCapInvalid);
      return;
    }
    if (cap != null && cap < _going) {
      setState(() => _error = l.etkinlik2SettingsCapTooLow('$_going'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = widget.session.api;
    final nav = Navigator.of(context);
    final saved = l.etkinlik2SettingsSaved;
    try {
      if (_policy != _initPolicy) {
        await api.put('/events/$_id/admission', {'mode': _policy, 'questions': _questions});
      }
      if (cap != _initCap) {
        await api.patch('/events/$_id', {'capacity': cap ?? 0});
      }
      if (_regOpen != _initRegOpen) {
        await api.post('/events/$_id/${_regOpen ? 'reopen' : 'close'}', {});
      }
      if (_chatKnown && _chatOpen != _initChatOpen) {
        await api.put('/events/$_id/chat-room/closed', {'closed': !_chatOpen});
      }
      if (!mounted) return;
      _toast(saved);
      nav.pop(const Etkinlik2SettingsResult());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = eventErrorText(e);
        _changed = true; // kısmi kayıt olmuş olabilir
      });
    }
  }

  Future<void> _cancelEvent() async {
    final l = context.l10n;
    final ok = await BuDialog.confirm(
      context,
      title: l.eventFormCancelTitle,
      message: l.eventFormCancelMessage,
      confirmLabel: l.eventFormCancelAction,
      cancelLabel: l.eventListDismiss,
      destructive: true,
      icon: LucideIcons.triangleAlert,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final done = l.eventFormCancelledToast;
    try {
      await widget.session.api.delete('/events/$_id');
      if (!mounted) return;
      _toast(done);
      nav.pop(const Etkinlik2SettingsResult(cancelled: true));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = eventErrorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final approval = _policy == 'APPROVAL';
    return PopScope<Object?>(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, const Etkinlik2SettingsResult());
      },
      child: BuPageScaffold(
        title: l.etkinlik2SettingsTitle,
        bottomInset: 24,
        bottomBar: Et2BottomBar(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  liveRegion: true,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: ExcludeSemantics(child: Icon(LucideIcons.circleAlert, size: 18, color: t.danger)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: tx.bodyMedium!.copyWith(color: t.danger, fontWeight: FontWeight.w600))),
                  ]),
                ),
              ),
            BuButton(
              key: const ValueKey('et2-settings-save'),
              label: l.eventFormSave,
              busy: _busy,
              onPressed: _busy ? null : _save,
            ),
          ]),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
            sliver: SliverList.list(children: [
              Et2EventStrip(event: widget.event),
              Et2Label(l.etkinlik2SettingsPolicy),
              Et2Segment<String>(
                value: _policy,
                enabled: !_busy,
                options: [('OPEN', l.etkinlik2PolicyOpen), ('APPROVAL', l.etkinlik2PolicyApproval)],
                onChanged: (v) => setState(() => _policy = v),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 2, top: 10),
                child: AnimatedSwitcher(
                  duration: BuMotion.of(context, BuMotion.medium),
                  child: Row(
                    key: ValueKey(approval),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: ExcludeSemantics(child: Icon(approval ? LucideIcons.userCheck : LucideIcons.users, size: 16, color: t.mut)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(approval ? l.etkinlik2PolicyApprovalHint : l.p16PolicyOpenHint,
                            style: tx.bodyMedium!.copyWith(height: 1.4, color: t.mut)),
                      ),
                    ],
                  ),
                ),
              ),
              Et2Label(l.etkinlik2CapacityOptional),
              TextField(
                key: const ValueKey('et2-settings-cap'),
                controller: _cap,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: tx.titleMedium!.copyWith(color: t.ink),
                decoration: InputDecoration(
                  hintText: l.etkinlik2Unlimited,
                  prefixIcon: Icon(LucideIcons.ticket, size: 20, color: t.mut),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 2, top: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: ExcludeSemantics(child: Icon(LucideIcons.info, size: 16, color: t.mut)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l.etkinlik2SettingsCapMin('$_going'), style: tx.bodySmall!.copyWith(height: 1.4, color: t.mut))),
                ]),
              ),
              Et2Label(l.etkinlik2SettingsRegChat),
              BuCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  _switchRow(
                    icon: _regOpen ? LucideIcons.lockOpen : LucideIcons.lock,
                    title: l.etkinlik2SettingsRegOpen,
                    sub: l.etkinlik2SettingsRegHint,
                    value: _regOpen,
                    keyName: 'et2-reg-switch',
                    onChanged: (v) => setState(() => _regOpen = v),
                  ),
                  Divider(height: 1, indent: 64, color: t.bd),
                  _switchRow(
                    icon: LucideIcons.messageCircle,
                    title: l.etkinlik2SettingsChatOpen,
                    sub: l.etkinlik2SettingsChatHint,
                    value: _chatOpen,
                    keyName: 'et2-chat-switch',
                    onChanged: _chatKnown ? (v) => setState(() => _chatOpen = v) : null,
                  ),
                ]),
              ),
              Et2Label(l.etkinlik2SettingsDanger),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.sf,
                  borderRadius: BorderRadius.circular(BuRadius.lg),
                  border: Border.all(color: t.danger.withValues(alpha: .4)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: t.danger.withValues(alpha: .12), borderRadius: BorderRadius.circular(BuRadius.xs + 4)),
                        child: Icon(LucideIcons.triangleAlert, size: 22, color: t.danger),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.eventFormCancelTitle, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(l.etkinlik2SettingsCancelBody('$_going'), style: tx.bodySmall!.copyWith(height: 1.4, color: t.mut)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Et2GhostButton(
                    key: const ValueKey('et2-cancel-event'),
                    label: l.eventFormCancelTitle,
                    danger: true,
                    onPressed: _busy ? null : _cancelEvent,
                  ),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String title,
    required String sub,
    required bool value,
    required String keyName,
    required ValueChanged<bool>? onChanged,
  }) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 8, top: 10, bottom: 10),
      child: Row(children: [
        Et2IconBox(icon, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
            Text(sub, style: tx.bodySmall!.copyWith(height: 1.35, color: t.mut)),
          ]),
        ),
        Et2Toggle(key: ValueKey(keyName), value: value, label: title, onChanged: _busy ? null : onChanged),
      ]),
    );
  }
}
