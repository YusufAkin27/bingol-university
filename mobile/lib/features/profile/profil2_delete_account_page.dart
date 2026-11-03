import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../auth/widgets/pin_field.dart';
import 'profil2_my_data_page.dart';
import 'profil_widgets.dart' show ProfilFlatSection, ProfilTopBar;
import 'profil2_widgets.dart';

/// Hesabı sil (Stitch 08-3): uyarı kartı, "Neler olur", yedek ipucu, onay kutusu; "Devam et" şifre alt sayfasını açar.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, required this.session});

  final Session session;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _ack = false;

  Future<void> _continue() async {
    final done = await BuSheet.show<bool>(
      context,
      builder: (_) => DeleteConfirmSheet(session: widget.session),
    );
    if (done == true) {
      await widget.session.signOut(remote: false);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final items = <String>[
      l.profil2DelItem1,
      l.profil2DelItem2,
      l.profil2DelItem3,
      l.profil2DelItemClubOwner,
      l.profil2DelItemUsage,
      l.profil2DelItem4,
    ];
    // Stitch v3: dangerSoft not (ikonsuz), "Neler olur" + madde noktalı satırlar, mut ipucu, onay kutusu, "Devam et"
    // (danger dolu; onaysız %40 opak), "Vazgeç" metin düğmesi.
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          ProfilTopBar(title: l.profilePrefsDeleteAccountTitle),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BuRadius.bMd),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.profil2DelWarnLead, style: tx.titleSmall!.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: t.danger)),
                    const SizedBox(height: 2),
                    Text(l.profil2DelWarnBody, style: tx.bodyMedium!.copyWith(fontSize: 14, color: t.danger, height: 1.4)),
                  ]),
                ),
                ProfilFlatSection(l.profil2DelWhatHappens, top: 24, upper: true, horizontal: 0),
                for (final it in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 9, left: 4, right: 14),
                        child: Container(width: 6, height: 6, decoration: BoxDecoration(color: t.mut, shape: BoxShape.circle)),
                      ),
                      Expanded(child: Text(it, style: tx.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: t.ink, height: 1.35))),
                    ]),
                  ),
                const SizedBox(height: 8),
                InkWell(
                  key: const ValueKey('delete-backup-link'),
                  borderRadius: BuRadius.bXs,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyDataPage(session: widget.session))),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(l.profil2DelBackupHint, style: tx.bodyMedium!.copyWith(fontSize: 14, color: t.mut, height: 1.35)),
                    ),
                  ),
                ),
                Divider(height: 24, thickness: 1, color: t.bd),
                Semantics(
                  container: true,
                  checked: _ack,
                  child: InkWell(
                    key: const ValueKey('delete-ack'),
                    borderRadius: BuRadius.bSm,
                    onTap: () => setState(() => _ack = !_ack),
                    child: Row(children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: ExcludeSemantics(
                          child: Checkbox(value: _ack, onChanged: (v) => setState(() => _ack = v == true)),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(l.profil2DelAck, style: tx.bodyLarge!.copyWith(fontSize: 15, color: t.ink, height: 1.35)),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedOpacity(
                  duration: BuMotion.of(context, BuMotion.short),
                  opacity: _ack ? 1 : .4,
                  child: BuButton(
                    key: const ValueKey('delete-continue'),
                    label: l.profil2Continue,
                    kind: BuButtonKind.danger,
                    onPressed: _ack ? _continue : null,
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  key: const ValueKey('delete-cancel'),
                  style: TextButton.styleFrom(foregroundColor: t.ink, minimumSize: const Size(double.infinity, 48)),
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.profileCancel, style: tx.labelLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Şifre isteyen silme onayı alt sayfası içeriği (Stitch 08-4; `BuSheet` içinde, klavye açıkken yukarı kayar).
/// Başarıda true döner.
class DeleteConfirmSheet extends StatefulWidget {
  const DeleteConfirmSheet({super.key, required this.session});

  final Session session;

  @override
  State<DeleteConfirmSheet> createState() => _DeleteConfirmSheetState();
}

class _DeleteConfirmSheetState extends State<DeleteConfirmSheet> {
  final _pw = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_pw.text.isEmpty) {
      setState(() => _error = context.l10n.profilePrefsEnterPassword);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.api.delete('/users/me', {'password': _pw.text});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = (e is ApiError && e.code == 'WRONG_PASSWORD' && e.message.isEmpty)
            ? context.l10n.profilePrefsWrongPassword
            : errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final hasError = _error != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const P2IconTile(icon: BuIcons.trash2, danger: true, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(header: true, child: Text(l.profil2DelConfirmTitle, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
          ),
          IconButton(
            tooltip: l.commonClose,
            icon: Icon(BuIcons.x, color: t.mut),
            onPressed: _busy ? null : () => Navigator.pop(context, false),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 14),
          child: Text(l.profil2DelConfirmBody, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
        ),
        PinField(
          key: const ValueKey('delete-password'),
          controller: _pw,
          label: l.profilePrefsPassword,
          enabled: !_busy,
          invalid: hasError,
          autofocus: true,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: _submit,
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, top: 8),
            child: Semantics(
              liveRegion: true,
              child: Row(children: [
                Icon(BuIcons.circleAlert, size: 14, color: t.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_error!, key: const ValueKey('delete-error'), style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.danger)),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 16),
        BuButton(
          key: const ValueKey('delete-submit'),
          label: l.profilePrefsDeleteMyAccount,
          icon: BuIcons.trash2,
          kind: BuButtonKind.danger,
          busy: _busy,
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: 4),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: t.mut, minimumSize: const Size(double.infinity, 48)),
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l.profileCancel),
        ),
      ],
    );
  }
}
