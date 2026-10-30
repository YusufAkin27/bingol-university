import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'etkinlik2_widgets.dart';
import 'event_cover.dart';
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
    _cap.addListener(() => setState(() {}));
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
    // Altı onaylı kişi sayısı: hata satırı zaten canlı görünür (_capError).
    if (cap != null && cap < _going) return;
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
    final ok = await BuDialog.show<bool>(
      context,
      builder: (c) => _CancelDialog(
        title: l.eventFormCancelTitle,
        message: l.eventFormCancelMessage,
        note: l.p16SetCancelNote('$_going'),
        cancelLabel: l.eventListDismiss,
        confirmLabel: l.eventFormCancelAction,
      ),
    );
    if (ok != true || !mounted) return;
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

  int? get _capValue {
    final txt = _cap.text.trim();
    return txt.isEmpty ? null : int.tryParse(txt);
  }

  /// Canlı kontenjan hatası: onaylı kişi sayısının altı olamaz.
  String? get _capError {
    final v = _capValue;
    if (v != null && v < _going) return context.l10n.etkinlik2SettingsCapTooLow('$_going');
    return null;
  }

  void _bump(int d) {
    final v = _capValue;
    final next = v == null ? (d > 0 ? (_going < 1 ? 1 : _going) : null) : v + d;
    setState(() => _cap.text = (next == null || next < 1) ? '' : '$next');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final approval = _policy == 'APPROVAL';
    final capErr = _capError;
    final cover = fileUrl(widget.event['coverUrl'] as String?);
    return PopScope<Object?>(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, const Etkinlik2SettingsResult());
      },
      child: BuPageScaffold(
        title: l.etkinlik2SettingsTitle,
        large: false,
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
              icon: LucideIcons.save,
              busy: _busy,
              onPressed: _busy ? null : _save,
            ),
          ]),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            sliver: SliverList.list(children: [
              BuCard(
                padding: const EdgeInsets.all(12),
                radius: 20,
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(BuRadius.sm),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: cover != null
                          ? EventCoverImage(url: cover, cacheWidth: 200)
                          : ColoredBox(color: t.soft, child: Icon(LucideIcons.calendarDays, size: 28, color: t.pr)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('${widget.event['title'] ?? ''}',
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                      const SizedBox(height: 4),
                      Row(children: [
                        ExcludeSemantics(child: Icon(LucideIcons.users, size: 14, color: t.mut)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(l.p16SetApproved('$_going'), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut))),
                      ]),
                    ]),
                  ),
                ]),
              ),
              Et2SectionTitle(l.etkinlik2SettingsPolicy),
              _policyCard(
                selected: !approval,
                title: l.etkinlik2PolicyOpen,
                sub: l.p16SetOpenSub,
                icon: LucideIcons.globe,
                keyName: 'et2-policy-open',
                onTap: () => setState(() => _policy = 'OPEN'),
              ),
              const SizedBox(height: 10),
              _policyCard(
                selected: approval,
                title: l.etkinlik2PolicyApprovalTag,
                sub: l.p16SetApprovalSub,
                icon: LucideIcons.shieldCheck,
                keyName: 'et2-policy-approval',
                onTap: () => setState(() => _policy = 'APPROVAL'),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, top: 22, bottom: 8),
                child: Row(children: [
                  Expanded(
                    child: Text(l.p16SetCapLabel, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                  ),
                  Text(l.p16SetCapCurrent('$_going'), style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.pr)),
                ]),
              ),
              BuCard(
                padding: const EdgeInsets.all(12),
                radius: 20,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
                    decoration: BoxDecoration(
                      color: capErr != null ? t.danger.withValues(alpha: .1) : t.sf2,
                      borderRadius: BorderRadius.circular(BuRadius.md),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('et2-settings-cap'),
                          controller: _cap,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: capErr != null ? t.danger : t.ink),
                          decoration: InputDecoration(
                            hintText: l.etkinlik2Unlimited,
                            hintStyle: tx.titleMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      _StepButton(icon: LucideIcons.minus, label: l.p16SetCapDec, onTap: _busy ? null : () => _bump(-1)),
                      const SizedBox(width: 2),
                      _StepButton(icon: LucideIcons.plus, label: l.p16SetCapInc, onTap: _busy ? null : () => _bump(1)),
                    ]),
                  ),
                  if (capErr != null) ...[
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        key: const ValueKey('et2-cap-error'),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: t.danger.withValues(alpha: .1), borderRadius: BorderRadius.circular(BuRadius.sm)),
                        child: Row(children: [
                          ExcludeSemantics(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(color: t.danger, shape: BoxShape.circle),
                              child: Icon(LucideIcons.info, size: 13, color: t.onPr),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(capErr, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.danger))),
                        ]),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 4, 2),
                    child: Text(l.etkinlik2SettingsCapMin('$_going'), style: tx.bodySmall!.copyWith(height: 1.4, color: t.mut)),
                  ),
                ]),
              ),
              Et2SectionTitle(l.etkinlik2SettingsRegChat),
              BuCard(
                padding: EdgeInsets.zero,
                radius: 20,
                child: Column(children: [
                  _switchRow(
                    icon: LucideIcons.userCheck,
                    title: l.etkinlik2SettingsRegOpen,
                    sub: l.etkinlik2SettingsRegHint,
                    value: _regOpen,
                    keyName: 'et2-reg-switch',
                    onChanged: (v) => setState(() => _regOpen = v),
                  ),
                  Divider(height: 1, color: t.bd),
                  _switchRow(
                    icon: LucideIcons.messageSquare,
                    title: l.etkinlik2SettingsChatOpen,
                    sub: l.etkinlik2SettingsChatHint,
                    value: _chatOpen,
                    keyName: 'et2-chat-switch',
                    tint: t.tint(1),
                    onChanged: _chatKnown ? (v) => setState(() => _chatOpen = v) : null,
                  ),
                ]),
              ),
              Et2SectionTitle(l.etkinlik2SettingsDanger),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.sf,
                  borderRadius: BorderRadius.circular(20),
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

  /// Katılım türü seçenek kartı: seçiliyken marka tonu, solda radyo, sağda simge.
  Widget _policyCard({
    required bool selected,
    required String title,
    required String sub,
    required IconData icon,
    required String keyName,
    required VoidCallback onTap,
  }) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$title, $sub',
      excludeSemantics: true,
      onTap: _busy ? null : onTap,
      child: BuPressable(
        key: ValueKey(keyName),
        onTap: _busy ? null : onTap,
        haptic: BuHaptic.selection,
        scale: .985,
        child: AnimatedContainer(
          duration: BuMotion.of(context, BuMotion.short),
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 16, 12),
          decoration: BoxDecoration(
            color: selected ? t.soft : t.sf,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Colors.transparent : t.bd),
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: BuMotion.of(context, BuMotion.short),
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? t.pr : t.sf2,
              ),
              child: selected ? Container(width: 8, height: 8, decoration: BoxDecoration(color: t.onPr, shape: BoxShape.circle)) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: selected ? t.onSoft : t.ink)),
                const SizedBox(height: 2),
                Text(sub, style: tx.bodySmall!.copyWith(height: 1.35, color: selected ? t.onSoft.withValues(alpha: .85) : t.mut)),
              ]),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 20, color: selected ? t.pr : t.mut),
          ]),
        ),
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
    BuTint? tint,
  }) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 8, top: 12, bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Et2IconBox(icon, size: 40, tint: tint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
          ),
          Et2Toggle(key: ValueKey(keyName), value: value, label: title, onChanged: _busy ? null : onChanged),
        ]),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 52, end: 8),
          child: Text(sub, style: tx.bodySmall!.copyWith(height: 1.35, color: t.mut)),
        ),
      ]),
    );
  }
}

/// Kontenjan artır/azalt düğmesi (48 dp hedef, 40 dp görsel).
class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        onTap: onTap,
        enabled: onTap != null,
        haptic: BuHaptic.selection,
        scale: .92,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.sm)),
              child: Icon(icon, size: 18, color: t.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Etkinliği iptal onayı: simge + başlık + gövde + not; Vazgeç / İptal et yan yana.
class _CancelDialog extends StatelessWidget {
  const _CancelDialog({
    required this.title,
    required this.message,
    required this.note,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String note;
  final String cancelLabel;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: t.danger.withValues(alpha: .12), shape: BoxShape.circle),
              child: Icon(LucideIcons.triangleAlert, size: 28, color: t.danger),
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(height: 1.4, color: t.mut)),
          const SizedBox(height: 6),
          Text(note, textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(height: 1.4, color: t.mut)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: Et2GreyButton(
                key: const ValueKey('et2-cancel-no'),
                label: cancelLabel,
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BuButton(
                key: const ValueKey('et2-cancel-yes'),
                label: confirmLabel,
                icon: LucideIcons.trash2,
                kind: BuButtonKind.danger,
                onPressed: () => Navigator.pop(context, true),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
