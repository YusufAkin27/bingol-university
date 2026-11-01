import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/two_factor.dart';
import '../../widgets/bu.dart';
import 'profil_widgets.dart';
import 'two_factor_pages.dart';

/// Hesap ve güvenlik ekranındaki "İki adımlı doğrulama" bloğu: açık/kapalı anahtarı + (açıkken) güvenilen cihazlar.
/// Durum `GET /auth/2fa` ile yüklenir. Uç yoksa (404, eski sunucu) blok hiç gösterilmez.
class TwoFactorSection extends StatefulWidget {
  const TwoFactorSection({super.key, required this.session});

  final Session session;

  @override
  State<TwoFactorSection> createState() => _TwoFactorSectionState();
}

class _TwoFactorSectionState extends State<TwoFactorSection> {
  TwoFactorStatus? _status;
  Object? _error;
  bool _busy = false;

  TwoFactorService get _svc => widget.session.twoFactor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted && _error != null) setState(() => _error = null);
    try {
      final s = await _svc.status();
      if (mounted) setState(() => _status = s);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _toast(String m, {BuToastKind kind = BuToastKind.info}) => BuToast.show(context, m, kind: kind);

  Future<void> _toggle(bool want) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (want) {
        await _enable();
      } else {
        await _disable();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enable() async {
    final l = context.l10n;
    try {
      await _svc.requestEnable();
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.code == 'TWO_FACTOR_ALREADY_ENABLED') await _load();
      _toast(errorText(e), kind: BuToastKind.error);
      return;
    }
    if (!mounted) return;
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TwoFactorEnablePage(session: widget.session)),
    );
    if (!mounted) return;
    if (done == true) {
      await _load();
      if (mounted) _toast(l.tfEnabledToast, kind: BuToastKind.success);
    }
  }

  Future<void> _disable() async {
    final l = context.l10n;
    final done = await BuDialog.show<bool>(context, builder: (_) => TwoFactorDisableDialog(service: _svc));
    if (!mounted || done != true) return;
    await _load();
    if (mounted) _toast(l.tfDisabledToast, kind: BuToastKind.success);
  }

  Future<void> _openDevices() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => TrustedDevicesPage(session: widget.session)));
    if (mounted) _load(); // kaldırılan cihaz sayısı güncellensin
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = _status;
    final err = _error;
    if (s == null && err is ApiError && err.status == 404) return const SizedBox.shrink();
    final Widget group;
    if (s == null) {
      group = ProfilFlatGroup(children: [
        err == null
            ? ProfilFlatRow(
                key: const ValueKey('tf-loading'),
                label: l.tfSecTitle,
                chevron: false,
                trailing: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : ProfilFlatRow(
                key: const ValueKey('tf-retry'),
                label: l.tfSecLoadFailed,
                chevron: false,
                onTap: _load,
              ),
      ]);
    } else {
      group = ProfilFlatGroup(children: [
        ProfilFlatToggle(
          key: const ValueKey('tf-toggle'),
          label: l.tfSecTitle,
          sub: l.tfSecDesc,
          value: s.enabled,
          onChanged: _busy ? null : _toggle,
        ),
        if (s.enabled)
          ProfilFlatRow(
            key: const ValueKey('tf-devices'),
            label: l.tfDevicesRow,
            value: '${s.trustedDeviceCount}',
            onTap: _openDevices,
          ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 24),
      group,
    ]);
  }
}
