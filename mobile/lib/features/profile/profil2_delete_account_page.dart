import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'profil2_my_data_page.dart';
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
    final items = <(IconData, String)>[
      (LucideIcons.userX, l.profil2DelItem1),
      (LucideIcons.bellOff, l.profil2DelItem2),
      (LucideIcons.users, l.profil2DelItem3),
      (LucideIcons.shieldUser, l.profil2DelItemClubOwner),
      (LucideIcons.fileX, l.profil2DelItemUsage),
      (LucideIcons.logOut, l.profil2DelItem4),
    ];
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: l.profilePrefsDeleteAccountTitle, onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BuRadius.bMd),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: t.danger.withValues(alpha: .16), shape: BoxShape.circle),
                      child: Icon(LucideIcons.triangleAlert, size: 22, color: t.danger),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.profil2DelWarnLead, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: cs.onErrorContainer)),
                        const SizedBox(height: 2),
                        Text(l.profil2DelWarnBody, style: tx.bodyMedium!.copyWith(color: cs.onErrorContainer, height: 1.4)),
                      ]),
                    ),
                  ]),
                ),
                P2Heading(l.profil2DelWhatHappens, top: 20),
                BuGroup(dividerIndent: 64, children: [
                  for (final it in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        P2IconTile(icon: it.$1, neutral: true),
                        const SizedBox(width: 14),
                        Expanded(child: Text(it.$2, style: tx.bodyMedium!.copyWith(color: t.ink, height: 1.4))),
                      ]),
                    ),
                ]),
                const SizedBox(height: 14),
                Material(
                  color: t.sf2,
                  borderRadius: BuRadius.bMd,
                  child: InkWell(
                    key: const ValueKey('delete-backup-link'),
                    borderRadius: BuRadius.bMd,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyDataPage(session: widget.session))),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(children: [
                          ExcludeSemantics(
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle),
                              child: Icon(LucideIcons.circleArrowDown, size: 18, color: t.ink),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(l.profil2DelBackupHint, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: t.ink, height: 1.35)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                BuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Semantics(
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
                            child: Text(l.profil2DelAck, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink, height: 1.35)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                BuButton(
                  key: const ValueKey('delete-continue'),
                  label: l.profil2Continue,
                  kind: BuButtonKind.danger,
                  onPressed: _ack ? _continue : null,
                ),
                const SizedBox(height: 4),
                TextButton(
                  key: const ValueKey('delete-cancel'),
                  style: TextButton.styleFrom(foregroundColor: t.mut, minimumSize: const Size(double.infinity, 48)),
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.profileCancel),
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
  bool _hidden = true;
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
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(borderRadius: BuRadius.bMd, borderSide: BorderSide(color: c, width: w));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const P2IconTile(icon: LucideIcons.trash2, danger: true, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(header: true, child: Text(l.profil2DelConfirmTitle, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
          ),
          IconButton(
            tooltip: l.commonClose,
            icon: Icon(LucideIcons.x, color: t.mut),
            onPressed: _busy ? null : () => Navigator.pop(context, false),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 14),
          child: Text(l.profil2DelConfirmBody, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 6),
          child: Text(l.profilePrefsPassword, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
        ),
        TextField(
          key: const ValueKey('delete-password'),
          controller: _pw,
          obscureText: _hidden,
          enabled: !_busy,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          style: tx.bodyLarge!.copyWith(color: t.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: hasError ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: .6) : t.sf2,
            contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 14, 4, 14),
            border: b(t.sf2, 0),
            enabledBorder: b(hasError ? t.danger : t.sf2, hasError ? 1.5 : 0),
            focusedBorder: b(hasError ? t.danger : t.pr, 2),
            disabledBorder: b(t.sf2, 0),
            suffixIcon: IconButton(
              tooltip: _hidden ? l.authShowPassword : l.authHidePassword,
              icon: Icon(_hidden ? LucideIcons.eye : LucideIcons.eyeOff, size: 20, color: hasError ? t.danger : t.mut),
              onPressed: () => setState(() => _hidden = !_hidden),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, top: 8),
            child: Semantics(
              liveRegion: true,
              child: Row(children: [
                Icon(LucideIcons.circleAlert, size: 14, color: t.danger),
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
          icon: LucideIcons.trash2,
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
