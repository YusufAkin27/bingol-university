import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme_controller.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../support/support_page.dart';
import 'blocked_users_page.dart';
import 'legal_pages.dart';
import 'notification_prefs_page.dart';

const _langs = [('tr', 'Türkçe'), ('en', 'English'), ('ar', 'العربية')];

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.session, required this.themeController});

  final Session session;
  final ThemeController themeController;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _lang = 'tr';
  bool _showEmail = false;
  bool _loaded = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final r = await widget.session.api.get('/users/me') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        final l = r['language'] as String?;
        if (l != null && _langs.any((e) => e.$1 == l)) _lang = l;
        _showEmail = r['showEmail'] == true;
        _loaded = true;
      });
    } catch (_) {
      // Profil okunamazsa varsayılanlarla devam edilir; değişiklik yine denenebilir.
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  int get _modeIndex => switch (widget.themeController.mode) {
        ThemeMode.system => 0,
        ThemeMode.light => 1,
        ThemeMode.dark => 2,
      };

  Future<void> _patch(Map<String, dynamic> body, VoidCallback rollback) async {
    try {
      await widget.session.api.patch('/users/me', body);
    } catch (e) {
      if (!mounted) return;
      setState(rollback);
      _toast(errorText(e));
    }
  }

  Future<void> _pickLang() async {
    final t = context.bu;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.sf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 16),
          Text('Bildirim ve e-posta dili', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: t.ink)),
          const SizedBox(height: 8),
          for (final l in _langs)
            ListTile(
              title: Text(l.$2, style: TextStyle(fontWeight: FontWeight.w600, color: t.ink)),
              trailing: l.$1 == _lang ? Icon(LucideIcons.check, color: t.pr) : null,
              onTap: () => Navigator.pop(ctx, l.$1),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (chosen == null || chosen == _lang) return;
    final old = _lang;
    setState(() => _lang = chosen);
    await _patch({'language': chosen}, () => _lang = old);
  }

  Future<void> _toggleEmail(bool v) async {
    final old = _showEmail;
    setState(() => _showEmail = v);
    await _patch({'showEmail': v}, () => _showEmail = old);
  }

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

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        child: Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .5, color: context.bu.mut)),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final langName = _langs.firstWhere((e) => e.$1 == _lang).$2;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: 'Ayarlar', onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
              children: [
                _label('GÖRÜNÜM'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListenableBuilder(
                    listenable: widget.themeController,
                    builder: (_, __) => BuSegmented(
                      items: const ['Sistem', 'Açık', 'Koyu'],
                      index: _modeIndex,
                      onChanged: (i) => widget.themeController
                          .set(const [ThemeMode.system, ThemeMode.light, ThemeMode.dark][i]),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: BuGroup(children: [
                    BuMenuRow(
                      icon: LucideIcons.globe,
                      label: 'Bildirim ve e-posta dili',
                      onTap: _loaded ? _pickLang : null,
                      trailing: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(langName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.mut)),
                      ),
                    ),
                  ]),
                ),
                _label('BİLDİRİMLER'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: NotificationPrefsGroup(session: widget.session),
                ),
                _label('GİZLİLİK VE HESAP'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: BuGroup(children: [
                    PrefSwitchRow(
                        label: 'E-postamı diğerlerine göster',
                        value: _showEmail,
                        onChanged: _loaded ? _toggleEmail : null),
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
                    BuMenuRow(
                        icon: LucideIcons.circleQuestionMark,
                        label: 'Destek ve SSS',
                        onTap: () => _push(SupportPage(session: widget.session))),
                    BuMenuRow(
                        icon: LucideIcons.trash2,
                        label: 'Hesabımı sil',
                        danger: true,
                        showChevron: false,
                        onTap: _deleteAccount),
                  ]),
                ),
                const SizedBox(height: 18),
                Center(child: Text('BÜ Kampüs · Sürüm 1.0.0', style: TextStyle(fontSize: 12, color: t.mut))),
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
      title: Text('Hesabı sil', style: TextStyle(fontWeight: FontWeight.w800, color: t.ink)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hesabınız ve kişisel verileriniz silinecek. Bu işlem geri alınamaz. Onaylamak için şifrenizi girin.',
            style: TextStyle(fontSize: 14, height: 1.4, color: t.mut),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pw,
            obscureText: true,
            enabled: !_busy,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            style: TextStyle(color: t.ink),
            decoration: const InputDecoration(labelText: 'Şifre'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.danger)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text('Vazgeç', style: TextStyle(color: t.mut, fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Hesabı sil', style: TextStyle(color: t.danger, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
