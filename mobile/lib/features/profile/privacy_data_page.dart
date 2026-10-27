import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'blocked_users_page.dart';
import 'legal_pages.dart';

/// Ayarlar > Gizlilik ve veriler. Hesap silme bilerek burada, en altta ve sönük tutulur.
class PrivacyDataPage extends StatefulWidget {
  const PrivacyDataPage({super.key, required this.session});

  final Session session;

  @override
  State<PrivacyDataPage> createState() => _PrivacyDataPageState();
}

class _PrivacyDataPageState extends State<PrivacyDataPage> {
  bool _exporting = false;

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final data = await widget.session.api.get('/users/me/export');
      const enc = JsonEncoder.withIndent('  ');
      await Clipboard.setData(ClipboardData(text: enc.convert(data)));
      if (mounted) _toast('Verileriniz panoya kopyalandı');
    } catch (e) {
      if (mounted) {
        _toast(e is ApiError && e.status == 429
            ? (e.message.isNotEmpty ? e.message : 'Günde en fazla 3 kez veri indirebilirsiniz.')
            : errorText(e));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _deleteAccount() async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteAccountDialog(session: widget.session),
    );
    if (done == true) {
      await widget.session.signOut(remote: false);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: 'Gizlilik ve veriler', onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                BuGroup(children: [
                  BuMenuRow(
                      icon: LucideIcons.ban,
                      label: 'Engellenen kullanıcılar',
                      onTap: () => _push(BlockedUsersPage(session: widget.session))),
                  BuMenuRow(
                      icon: LucideIcons.fileText,
                      label: 'Sözleşmeler ve gizlilik',
                      onTap: () => _push(LegalListPage(session: widget.session))),
                  BuMenuRow(
                    icon: LucideIcons.download,
                    label: 'Verilerimi indir',
                    onTap: _export,
                    trailing: _exporting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : null,
                  ),
                ]),
                const SizedBox(height: 56),
                Divider(color: t.bd, height: 1),
                const SizedBox(height: 14),
                Text('Hesap yönetimi', style: BuType.caption.copyWith(color: t.mut)),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: _deleteAccount,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(44, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: AlignmentDirectional.centerStart,
                    ),
                    child: Text('Hesabımı sil',
                        style: BuType.caption.copyWith(color: t.mut)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
/// Şifre isteyen hesap silme onayı. Başarıda true döner.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.session});

  final Session session;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _pw = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pw.text.isEmpty) {
      setState(() => _error = 'Şifrenizi girin.');
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
        _error = (e is ApiError && e.code == 'WRONG_PASSWORD' && e.message.isEmpty) ? 'Şifre hatalı.' : errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return AlertDialog(
      backgroundColor: t.sf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text('Hesabı sil', style: BuType.title.copyWith(color: t.ink)),
      content: SingleChildScrollView(
       child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hesabınız ve kişisel verileriniz silinecek. Bu işlem geri alınamaz. Onaylamak için şifrenizi girin.',
            style: BuType.body.copyWith(height: 1.4, color: t.mut),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pw,
            obscureText: true,
            enabled: !_busy,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            style: BuType.body.copyWith(color: t.ink),
            decoration: const InputDecoration(labelText: 'Şifre'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: BuType.label.copyWith(color: t.danger)),
          ],
        ],
       ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text('Vazgeç', style: BuType.bodyStrong.copyWith(color: t.mut)),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Hesabı sil', style: BuType.bodyStrong.copyWith(color: t.danger)),
        ),
      ],
    );
  }
}