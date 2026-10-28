import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'profil2_my_data_page.dart';
import 'profil2_widgets.dart';

/// Hesabı sil: uyarı, "neler olur", onay kutusu; "Devam et" şifre alt sayfasını açar.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, required this.session});

  final Session session;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _ack = false;

  Future<void> _continue() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x80171E33),
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
    final tone = P2Tones.of(context);
    final items = [l.profil2DelItem1, l.profil2DelItem2, l.profil2DelItem3, l.profil2DelItem4];
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: tone.dngBg,
                    border: Border.all(color: tone.dngBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: ExcludeSemantics(child: Icon(LucideIcons.triangleAlert, size: 20, color: tone.dng)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '${l.profil2DelWarnLead} ', style: const TextStyle(fontWeight: FontWeight.w800)),
                            TextSpan(text: l.profil2DelWarnBody),
                          ]),
                          style: BuType.body.copyWith(color: tone.dngText, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                BuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.profil2DelWhatHappens, style: BuType.bodyStrong.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      for (final s in items) P2BulletLine(text: s, icon: LucideIcons.x, color: tone.dng),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                  child: Text(l.profil2DelBackupHint, style: BuType.label.copyWith(color: t.mut, fontWeight: FontWeight.w500, height: 1.45)),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: const ValueKey('delete-backup-link'),
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => MyDataPage(session: widget.session))),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    child: Text(l.profilePrefsDownloadData,
                        style: BuType.bodyStrong.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 4),
                BuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Semantics(
                    container: true,
                    checked: _ack,
                    child: InkWell(
                      key: const ValueKey('delete-ack'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _ack = !_ack),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: ExcludeSemantics(
                              child: Checkbox(
                                value: _ack,
                                activeColor: tone.dng,
                                side: BorderSide(color: t.mut, width: 1.5),
                                onChanged: (v) => setState(() => _ack = v == true),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(l.profil2DelAck, style: BuType.bodyStrong.copyWith(color: t.ink, height: 1.35)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _DangerButton(
                key: const ValueKey('delete-continue'),
                label: l.profil2Continue,
                onPressed: _ack ? _continue : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 56 px, 18 yarıçaplı tehlike düğmesi (devre dışıyken soluk).
class _DangerButton extends StatelessWidget {
  const _DangerButton({super.key, required this.label, required this.onPressed, this.busy = false, this.height = 56});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tone = P2Tones.of(context);
    final enabled = onPressed != null && !busy;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: tone.dark ? const Color(0xFFD64541) : const Color(0xFFB3261E),
          foregroundColor: Colors.white,
          disabledBackgroundColor: tone.dngOff,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: BuType.heading.copyWith(fontWeight: FontWeight.w700),
        ),
        child: busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Şifre isteyen silme onayı alt sayfası (klavye açıkken yukarı kayar). Başarıda true döner.
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
    final tone = P2Tones.of(context);
    final hasError = _error != null;
    OutlineInputBorder b(Color c, [double w = 1.5]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: w));
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: const [BoxShadow(color: Color(0x73171E33), blurRadius: 40, offset: Offset(0, -12), spreadRadius: -16)],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: t.bd, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                Row(
                  children: [
                    P2IconTile(icon: LucideIcons.trash2, color: tone.dng, bg: tone.dngBg, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(l.profil2DelConfirmTitle, style: BuType.title.copyWith(color: t.ink)),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 12),
                  child: Text(l.profil2DelConfirmBody, style: BuType.body.copyWith(color: t.mut, height: 1.5)),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
                  child: Text(l.profilePrefsPassword, style: BuType.label.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
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
                  style: BuType.body.copyWith(color: t.ink, fontSize: 15),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: t.sf,
                    contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 16),
                    constraints: const BoxConstraints(minHeight: 52),
                    border: b(t.bd),
                    enabledBorder: b(hasError ? tone.dng : t.bd),
                    focusedBorder: b(hasError ? tone.dng : t.pr, 2),
                    disabledBorder: b(t.bd),
                    suffixIcon: IconButton(
                      tooltip: _hidden ? l.authShowPassword : l.authHidePassword,
                      icon: Icon(_hidden ? LucideIcons.eye : LucideIcons.eyeOff, size: 20, color: t.mut),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    ),
                  ),
                ),
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(_error!,
                          key: const ValueKey('delete-error'),
                          style: BuType.label.copyWith(color: tone.dng, fontWeight: FontWeight.w600)),
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 10,
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: t.ink,
                            side: BorderSide(color: t.bd, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            textStyle: BuType.heading.copyWith(fontWeight: FontWeight.w700),
                          ),
                          child: Text(l.commonCancel, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 14,
                      child: _DangerButton(
                        key: const ValueKey('delete-submit'),
                        label: l.profilePrefsDeleteMyAccount,
                        busy: _busy,
                        height: 52,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
