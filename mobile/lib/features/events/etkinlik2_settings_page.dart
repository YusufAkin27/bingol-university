import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
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
    final ok = await confirmEventDialog(
      context,
      title: l.eventFormCancelTitle,
      message: l.eventFormCancelMessage,
      confirmLabel: l.eventFormCancelAction,
      danger: true,
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
    final l = context.l10n;
    return PopScope<Object?>(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, const Etkinlik2SettingsResult());
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: Column(children: [
          BuHeader(
            title: l.etkinlik2SettingsTitle,
            subtitle: '${widget.event['title'] ?? ''}',
            onBack: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Et2Label(l.etkinlik2SettingsPolicy),
              Et2Segment<String>(
                value: _policy,
                enabled: !_busy,
                options: [('OPEN', l.etkinlik2PolicyOpen), ('APPROVAL', l.etkinlik2PolicyApproval)],
                onChanged: (v) => setState(() => _policy = v),
              ),
              const SizedBox(height: 12),
              Et2FieldLabel(l.etkinlik2CapacityOptional),
              TextField(
                key: const ValueKey('et2-settings-cap'),
                controller: _cap,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: BuType.body.copyWith(color: t.ink),
                decoration: InputDecoration(hintText: l.etkinlik2Unlimited),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 2, top: 6),
                child: Text(l.etkinlik2SettingsCapMin('$_going'), style: BuType.caption.copyWith(color: t.mut)),
              ),
              Et2Label(l.etkinlik2SettingsRegChat),
              BuCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  _switchRow(
                    title: l.etkinlik2SettingsRegOpen,
                    sub: l.etkinlik2SettingsRegHint,
                    value: _regOpen,
                    keyName: 'et2-reg-switch',
                    onChanged: (v) => setState(() => _regOpen = v),
                  ),
                  Divider(height: 1, color: t.bd),
                  _switchRow(
                    title: l.etkinlik2SettingsChatOpen,
                    sub: l.etkinlik2SettingsChatHint,
                    value: _chatOpen,
                    keyName: 'et2-chat-switch',
                    onChanged: _chatKnown ? (v) => setState(() => _chatOpen = v) : null,
                  ),
                ]),
              ),
              Et2Label(l.etkinlik2SettingsDanger),
              BuCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(LucideIcons.triangleAlert, size: 22, color: t.pr),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.eventFormCancelTitle, style: BuType.bodyStrong.copyWith(color: t.ink)),
                        Text(l.etkinlik2SettingsCancelBody('$_going'),
                            style: BuType.caption.copyWith(height: 1.35, color: t.mut)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Et2GhostButton(
                    key: const ValueKey('et2-cancel-event'),
                    label: l.eventFormCancelTitle,
                    danger: true,
                    onPressed: _busy ? null : _cancelEvent,
                  ),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: BuType.label.copyWith(color: t.danger)),
              ],
            ]),
          ),
          Et2BottomBar(child: BuButton(label: l.eventFormSave, busy: _busy, onPressed: _busy ? null : _save)),
        ]),
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required String sub,
    required bool value,
    required String keyName,
    required ValueChanged<bool>? onChanged,
  }) {
    final t = context.bu;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 8, top: 8, bottom: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: BuType.bodyStrong.copyWith(color: t.ink)),
            Text(sub, style: BuType.caption.copyWith(height: 1.35, color: t.mut)),
          ]),
        ),
        Et2Toggle(key: ValueKey(keyName), value: value, label: title, onChanged: _busy ? null : onChanged),
      ]),
    );
  }
}
