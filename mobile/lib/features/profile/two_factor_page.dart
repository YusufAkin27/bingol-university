import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/oauth/oauth_api.dart';
import '../../core/oauth/oauth_reauth.dart';
import '../../core/session.dart';
import '../../core/two_factor.dart';
import '../../widgets/bu.dart';
import '../auth/two_factor_code_page.dart';
import 'password_page.dart';
import 'profil_widgets.dart';

/// İki faktörlü doğrulama ayarı (Ayarlar > Hesap ve güvenlik > Giriş güvenliği): durum, açma (e-posta koduyla onay),
/// kapatma (şifreyle) ve güvenilen cihazlar. Sözleşme: docs/TWO_FACTOR_API.md.
class TwoFactorPage extends StatefulWidget {
  const TwoFactorPage({super.key, required this.session});

  final Session session;

  static const routeName = 'two_factor';

  @override
  State<TwoFactorPage> createState() => _TwoFactorPageState();
}

class _TwoFactorPageState extends State<TwoFactorPage> {
  late final TwoFactorApi _api = TwoFactorApi(widget.session.api);
  TwoFactorStatus? _status;
  List<TwoFactorDevice> _devices = const [];
  bool _loading = true;
  Object? _error;

  /// Açma/kapatma isteği sürüyor (anahtar kilitlenir).
  bool _busy = false;
  final Set<int> _removing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _api.status();
      final d = s.enabled ? await _api.devices() : const <TwoFactorDevice>[];
      if (!mounted) return;
      setState(() {
        _status = s;
        _devices = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _toast(String m, {BuToastKind kind = BuToastKind.info}) => BuToast.show(context, m, kind: kind);

  Future<void> _toggle(bool want) async {
    if (_busy || _status == null) return;
    want ? await _enable() : await _disable();
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    try {
      await _api.requestEnable();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(errorText(e), kind: BuToastKind.error);
      // Başka cihazdan zaten açılmış: durumu tazele.
      if (e is ApiError && e.code == 'TWO_FACTOR_ALREADY_ENABLED') _load();
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: TwoFactorEnablePage.routeName),
        builder: (_) => TwoFactorEnablePage(session: widget.session, api: _api),
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      _toast(context.l10n.tfEnabledToast, kind: BuToastKind.success);
      await _load();
    }
  }

  Future<void> _disable() async {
    if (widget.session.hasPassword == false) {
      await _disableWithProvider();
      return;
    }
    final ok = await BuDialog.show<bool>(context, builder: (_) => _DisableDialog(api: _api));
    if (!mounted || ok != true) return;
    _toast(context.l10n.tfDisabledToast, kind: BuToastKind.success);
    await _load();
  }

  /// Parolasız (Google/Apple) hesap: şifre sorulamaz; bağlı sağlayıcının taze kimliğiyle kapatılır. Bağlı sağlayıcı
  /// bulunamazsa kullanıcı şifre belirlemeye yönlendirilir (şifreyle de kapatılabilir).
  Future<void> _disableWithProvider() async {
    final l = context.l10n;
    final yes = await BuDialog.confirm(
      context,
      title: l.tfDisableTitle,
      message: l.qa1TfDisableReauthBody,
      confirmLabel: l.tfDisableConfirm,
      cancelLabel: l.commonCancel,
      destructive: true,
      icon: BuIcons.shieldX,
    );
    if (!yes || !mounted) return;
    setState(() => _busy = true);
    try {
      final ids = await OAuthApi(widget.session.api).identities();
      if (ids.isEmpty) {
        if (!mounted) return;
        setState(() => _busy = false);
        _toast(l.qa1TfNeedPassword, kind: BuToastKind.info);
        await Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: PasswordPage.routeName),
            builder: (_) => PasswordPage(session: widget.session),
          ),
        );
        return;
      }
      final re = await freshOAuthCredential(ids.first.provider);
      if (re == null) {
        if (mounted) setState(() => _busy = false); // iptal: sessiz
        return;
      }
      await _api.disableWithProvider(re.provider.wire, token: re.token, nonce: re.nonce);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e is ApiError ? errorText(e) : l.oaErrFailed, kind: BuToastKind.error);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(l.tfDisabledToast, kind: BuToastKind.success);
    await _load();
  }

  Future<void> _remove(TwoFactorDevice d) async {
    final l = context.l10n;
    final ok = await BuDialog.confirm(
      context,
      title: l.tfDeviceRemoveTitle,
      message: l.tfDeviceRemoveBody,
      confirmLabel: l.tfDeviceRemoveConfirm,
      cancelLabel: l.commonCancel,
      destructive: true,
      icon: BuIcons.trash2,
    );
    if (!ok || !mounted) return;
    setState(() => _removing.add(d.id));
    try {
      await _api.removeDevice(d.id);
      if (!mounted) return;
      setState(() {
        _removing.remove(d.id);
        _devices = _devices.where((x) => x.id != d.id).toList();
      });
      _toast(l.tfDeviceRemoved, kind: BuToastKind.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _removing.remove(d.id));
      _toast(errorText(e), kind: BuToastKind.error);
      // Cihaz zaten silinmiş olabilir (404): listeyi tazele.
      if (e is ApiError && e.status == 404) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    Widget body;
    if (_loading) {
      body = const _TwoFactorSkeleton();
    } else if (_error != null || _status == null) {
      body = BuErrorState(error: _error, onRetry: _load);
    } else {
      final on = _status!.enabled;
      body = ListView(
        key: const ValueKey('tf-list'),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Text(l.tfIntro, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
          ),
          ProfilFlatGroup(outlined: true, children: [
            ProfilFlatToggle(
              key: const ValueKey('tf-toggle'),
              label: l.tfTitle,
              sub: on ? l.tfToggleSubOn : l.tfToggleSubOff,
              value: on,
              onChanged: _busy ? null : _toggle,
            ),
          ]),
          if (on) ...[
            ProfilFlatSection(l.tfDevicesSection, top: 24, upper: true),
            if (_devices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(l.tfDevicesEmpty,
                    key: const ValueKey('tf-devices-empty'), style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
              )
            else
              ProfilFlatGroup(outlined: true, children: [
                for (final d in _devices)
                  _DeviceRow(
                    key: ValueKey('tf-device-${d.id}'),
                    device: d,
                    busy: _removing.contains(d.id),
                    onRemove: () => _remove(d),
                  ),
              ]),
          ],
        ],
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          ProfilTopBar(title: l.tfTitle),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Yükleniyor: iki satırlık iskelet.
class _TwoFactorSkeleton extends StatelessWidget {
  const _TwoFactorSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey('tf-loading'),
      padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BuSkeleton.line(width: 260),
        SizedBox(height: 10),
        BuSkeleton.line(width: 200),
        SizedBox(height: 24),
        BuSkeleton(height: 56, radius: 14),
      ]),
    );
  }
}

/// Güvenilen cihaz satırı: etiket, "Bu cihaz" + son kullanım, kaldır düğmesi.
class _DeviceRow extends StatelessWidget {
  const _DeviceRow({super.key, required this.device, required this.busy, required this.onRemove});

  final TwoFactorDevice device;
  final bool busy;
  final VoidCallback onRemove;

  static String _date(BuildContext context, DateTime d) {
    try {
      return DateFormat('d MMM y', Localizations.localeOf(context).toString()).format(d);
    } catch (_) {
      return d.toIso8601String().substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final used = device.lastUsedAt ?? device.createdAt;
    final parts = [
      if (device.current) l.tfDeviceThis,
      if (used != null) l.tfDeviceLastUsed(_date(context, used)),
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
        child: Row(children: [
          ExcludeSemantics(child: Icon(BuIcons.smartphone, size: 22, color: t.ink)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(device.label.isEmpty ? l.tfDeviceUnnamed : device.label,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(color: t.ink)),
              if (parts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(parts.join(' · '), style: tx.bodySmall!.copyWith(color: t.mut, height: 1.35)),
                ),
            ]),
          ),
          busy
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  key: ValueKey('tf-device-remove-${device.id}'),
                  tooltip: l.tfDeviceRemove,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: Icon(BuIcons.trash2, size: 20, color: t.danger),
                  onPressed: onRemove,
                ),
        ]),
      ),
    );
  }
}

/// Kapatma onayı: şifre ister (yanlışsa 400 INVALID_PASSWORD satır içinde gösterilir); başarıda `true` ile kapanır.
class _DisableDialog extends StatefulWidget {
  const _DisableDialog({required this.api});

  final TwoFactorApi api;

  @override
  State<_DisableDialog> createState() => _DisableDialogState();
}

class _DisableDialogState extends State<_DisableDialog> {
  final _password = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
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
      await widget.api.disable(_password.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiError && e.code == 'INVALID_PASSWORD'
            ? (e.message.isNotEmpty ? e.message : l.tfWrongPassword)
            : errorText(e);
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
      message: l.tfDisableBody,
      icon: BuIcons.shieldX,
      destructive: true,
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          key: const ValueKey('tf-disable-password'),
          controller: _password,
          obscureText: _hidden,
          autocorrect: false,
          enableSuggestions: false,
          enabled: !_busy,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: l.profil2SecCurrentLabel,
            errorText: _error,
            suffixIcon: IconButton(
              tooltip: _hidden ? l.authShowPassword : l.authHidePassword,
              icon: Icon(_hidden ? BuIcons.eye : BuIcons.eyeOff, size: 20, color: t.mut),
              onPressed: () => setState(() => _hidden = !_hidden),
            ),
          ),
          style: tx.bodyLarge!.copyWith(color: t.ink),
        ),
      ]),
      actions: [
        BuDialogAction(label: l.commonCancel, onPressed: _busy ? null : () => Navigator.of(context).pop(false)),
        BuDialogAction(
          key: const ValueKey('tf-disable-confirm'),
          label: l.tfDisableConfirm,
          kind: BuDialogActionKind.destructive,
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}
