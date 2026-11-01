import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/two_factor.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show niceDate, relativeTime;
import '../auth/otp_code_boxes.dart';
import '../auth/widgets/auth_controls.dart';
import '../auth/widgets/auth_motion.dart';
import '../auth/widgets/auth_ref.dart';
import 'profil_widgets.dart';

/// İki adımlı doğrulamayı açma, 2. adım: e-postaya giden 6 haneli kodu onayla (`enable/confirm`).
/// Kod ekrana gelmeden önce çağıran `enable/request` isteğini atmış olmalıdır. Başarıda `true` ile kapanır.
class TwoFactorEnablePage extends StatefulWidget {
  const TwoFactorEnablePage({super.key, required this.session});

  final Session session;

  @override
  State<TwoFactorEnablePage> createState() => _TwoFactorEnablePageState();
}

class _TwoFactorEnablePageState extends State<TwoFactorEnablePage> {
  final _code = TextEditingController();
  final _resendKey = GlobalKey<AuthResendRowState>();
  bool _busy = false;
  String? _error;
  String? _info;
  int _shake = 0;
  bool _ok = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _fail(String m) {
    authHaptic(AuthHaptic.error);
    setState(() {
      _error = m;
      _info = null;
      _shake++;
    });
  }

  Future<void> _confirm() async {
    if (_busy) return;
    if (_code.text.length != 6) {
      _fail(context.l10n.authRestEnterCode);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.session.twoFactor.confirmEnable(_code.text);
      if (!mounted) return;
      setState(() => _ok = true);
      authHaptic(AuthHaptic.success);
      if (!BuMotion.reduced(context)) await Future<void>.delayed(const Duration(milliseconds: 260));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _fail(errorText(e));
      _code.clear();
      if (e is ApiError && e.code == 'TOO_MANY_ATTEMPTS') _resendKey.currentState?.makeReady();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      await widget.session.twoFactor.requestEnable();
      if (!mounted) return;
      setState(() => _info = context.l10n.authNewCodeSent);
      _resendKey.currentState?.restart();
    } catch (e) {
      if (!mounted) return;
      _fail(errorText(e));
      if (e is ApiError && e.status == 429) _resendKey.currentState?.restart(e.retryAfter != null && e.retryAfter! > 0 ? e.retryAfter : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mail = widget.session.email ?? '';
    return RefPage(
      children: [
        RefHeading(
          title: l.tfEnableTitle,
          subtitle: mail.isEmpty ? l.authRestCodeLabel : l.tfEnableSubtitle(mail),
          emphasis: mail.isEmpty ? null : mail,
        ),
        const SizedBox(height: 32),
        OtpCodeBoxes(
          controller: _code,
          enabled: !_busy,
          hasError: _error != null,
          success: _ok,
          shakeTrigger: _shake,
          onCompleted: _confirm,
        ),
        AnimatedSize(
          duration: BuMotion.of(context, BuMotion.short),
          alignment: Alignment.topCenter,
          child: _error != null
              ? Padding(padding: const EdgeInsets.only(top: 16), child: RefPill(_error!, key: ValueKey('e$_error')))
              : _info != null
                  ? Padding(padding: const EdgeInsets.only(top: 16), child: RefPill(_info!, tone: RefTone.success))
                  : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 16),
        Wrap(
          children: [
            AuthResendRow(
              key: _resendKey,
              onResend: _busy ? () {} : _resend,
              waitingLabel: (s) => l.authResendIn('$s'),
              resendLabel: l.authResendCode,
            ),
          ],
        ),
        const SizedBox(height: 24),
        RefButton(label: l.tfEnableButton, busy: _busy, onPressed: _confirm),
      ],
    );
  }
}

/// Kapatma diyaloğu: şifre ister, `POST /auth/2fa/disable` çağırır. Başarıda `true` ile kapanır.
class TwoFactorDisableDialog extends StatefulWidget {
  const TwoFactorDisableDialog({super.key, required this.service});

  final TwoFactorService service;

  @override
  State<TwoFactorDisableDialog> createState() => _TwoFactorDisableDialogState();
}

class _TwoFactorDisableDialogState extends State<TwoFactorDisableDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l = context.l10n;
    if (_password.text.isEmpty) {
      setState(() => _error = l.profilePrefsEnterPassword);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.disable(_password.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final wrong = e is ApiError && (e.code == 'INVALID_PASSWORD' || e.code == 'WRONG_PASSWORD');
      setState(() {
        _busy = false;
        _error = wrong ? l.tfErrWrongPassword : errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return BuDialog(
      title: l.tfDisableTitle,
      icon: BuIcons.shield,
      message: l.tfDisableBody,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('tf-disable-password'),
            controller: _password,
            autofocus: true,
            obscureText: _hidden,
            enabled: !_busy,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: tx.bodyLarge!.copyWith(color: t.ink),
            decoration: InputDecoration(
              labelText: l.tfPasswordLabel,
              errorText: _error,
              errorMaxLines: 3,
              suffixIcon: IconButton(
                tooltip: _hidden ? l.authShowPassword : l.authHidePassword,
                icon: Icon(_hidden ? BuIcons.eye : BuIcons.eyeOff, size: 20, color: t.mut),
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
            ),
          ),
        ],
      ),
      actions: [
        BuDialogAction(label: l.commonCancel, onPressed: _busy ? null : () => Navigator.of(context).pop(false)),
        BuDialogAction(
          label: l.tfDisableConfirm,
          kind: BuDialogActionKind.primary,
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}

/// Güvenilen cihazlar: etiket, son kullanım, "Bu cihaz" rozeti; her satırda "Kaldır". Cihaz kaldırılınca o cihaz
/// bir sonraki girişte kod ister; mevcut oturum kapanmaz.
class TrustedDevicesPage extends StatefulWidget {
  const TrustedDevicesPage({super.key, required this.session});

  final Session session;

  @override
  State<TrustedDevicesPage> createState() => _TrustedDevicesPageState();
}

class _TrustedDevicesPageState extends State<TrustedDevicesPage> {
  List<TrustedDevice>? _devices;
  Object? _error;
  final Set<int> _removing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await widget.session.twoFactor.devices();
      if (mounted) setState(() => _devices = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _remove(TrustedDevice d) async {
    if (_removing.contains(d.id)) return;
    final l = context.l10n;
    final ok = await BuDialog.confirm(
      context,
      title: l.tfRemoveTitle,
      message: d.current ? l.tfRemoveCurrentBody : l.tfRemoveBody,
      confirmLabel: l.tfRemove,
      cancelLabel: l.commonCancel,
      destructive: true,
      icon: BuIcons.smartphone,
    );
    if (!ok || !mounted) return;
    setState(() => _removing.add(d.id));
    try {
      await widget.session.twoFactor.removeDevice(d.id);
      if (!mounted) return;
      setState(() {
        _removing.remove(d.id);
        _devices = [for (final x in _devices ?? const <TrustedDevice>[]) if (x.id != d.id) x];
      });
      BuToast.show(context, l.tfRemovedToast, kind: BuToastKind.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _removing.remove(d.id));
      // Cihaz zaten silinmişse (404) listeyi tazele.
      if (e is ApiError && e.status == 404) {
        _load();
      } else {
        BuToast.show(context, errorText(e), kind: BuToastKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final devices = _devices;
    Widget body;
    if (_error != null && devices == null) {
      body = BuErrorState(error: _error, onRetry: _load);
    } else if (devices == null) {
      body = const BuSkeletonList(key: ValueKey('tf-devices-loading'));
    } else if (devices.isEmpty) {
      body = BuEmptyState(
        key: const ValueKey('tf-devices-empty'),
        icon: BuIcons.smartphone,
        title: l.tfDevicesEmptyTitle,
        message: l.tfDevicesEmptyBody,
      );
    } else {
      body = ListView(
        key: const ValueKey('tf-devices-list'),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(l.tfDevicesIntro, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
          ),
          ProfilFlatGroup(children: [
            for (final d in devices) _DeviceRow(device: d, busy: _removing.contains(d.id), onRemove: () => _remove(d)),
          ]),
        ],
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          ProfilTopBar(title: l.tfDevicesTitle),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.busy, required this.onRemove});

  final TrustedDevice device;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final name = device.label.isEmpty ? l.tfDeviceUnknown : device.label;
    final used = device.lastUsedAt;
    final sub = used != null && used.isNotEmpty
        ? l.tfLastUsed(relativeTime(used, context: context))
        : (device.createdAt != null ? l.tfAddedOn(niceDate(device.createdAt, context: context)) : null);
    return ConstrainedBox(
      key: ValueKey('tf-device-${device.id}'),
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 8),
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(BuIcons.smartphone, size: 24, color: t.mut)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(fontSize: 16, color: t.ink, fontWeight: FontWeight.w600)),
                  if (device.current) ...[
                    const SizedBox(height: 4),
                    Container(
                      key: const ValueKey('tf-device-current'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.pill)),
                      child: Text(l.tfThisDevice, style: tx.bodySmall!.copyWith(fontSize: 12, color: t.onSoft, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub, style: tx.bodySmall!.copyWith(fontSize: 12, color: t.mut, height: 1.35)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            Semantics(
              button: true,
              label: l.tfRemoveDevice(name),
              excludeSemantics: true,
              onTap: busy ? null : onRemove,
              child: TextButton(
                key: ValueKey('tf-remove-${device.id}'),
                onPressed: busy ? null : onRemove,
                style: TextButton.styleFrom(foregroundColor: t.danger, minimumSize: const Size(64, 48)),
                child: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.tfRemove),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
