import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../core/push/push_service.dart';
import '../../core/session.dart';
import '../../core/theme_controller.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../chat/contacts_match_page.dart';
import '../support/support_page.dart';
import 'notification_prefs_page.dart';
import 'privacy_data_page.dart';
import '../../core/typography.dart';

const _langs = [('tr', 'Türkçe'), ('en', 'English'), ('ar', 'العربية')];

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.session, required this.themeController, this.push});

  final Session session;

  /// Verilirse push durumu buradan okunur; yoksa Firebase başlatılmış mı diye bakılır.
  final PushService? push;
  final ThemeController themeController;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _lang = 'tr';
  bool _showEmail = false;
  bool _loaded = false;
  String _pushStatus = '...';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPushStatus();
  }

  Future<void> _loadPushStatus() async {
    var text = 'Henüz yapılandırılmadı';
    try {
      final configured = (widget.push?.enabled ?? false) || Firebase.apps.isNotEmpty;
      if (configured) {
        final st = await FirebaseMessaging.instance.getNotificationSettings();
        text = switch (st.authorizationStatus) {
          AuthorizationStatus.authorized || AuthorizationStatus.provisional => 'Açık',
          AuthorizationStatus.denied => 'Kapalı (sistem ayarlarından açın)',
          _ => 'İzin verilmedi',
        };
      }
    } catch (_) {}
    if (mounted) setState(() => _pushStatus = text);
  }

  Future<void> _logoutAll() async {
    final t = context.bu;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: t.sf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Tüm cihazlardan çıkış', style: TextStyle(fontWeight: FontWeight.w800, color: t.ink)),
        content: Text('Hesabınız tüm cihazlarda kapatılacak ve yeniden giriş yapmanız gerekecek.',
            style: BuType.body.copyWith(height: 1.4, color: t.mut)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Vazgeç', style: TextStyle(color: t.mut, fontWeight: FontWeight.w700))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Çıkış yap', style: TextStyle(color: t.danger, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // Session.logoutAll henüz yoksa uç doğrudan çağrılır.
      await widget.session.api.post('/auth/logout-all');
    } catch (e) {
      if (mounted) _toast(errorText(e));
      return;
    }
    await widget.session.signOut(remote: false);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
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
          Text('Bildirim ve e-posta dili', style: BuType.heading.copyWith(color: t.ink)),
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

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        child: Text(s, style: BuType.label.copyWith(letterSpacing: .5, color: context.bu.mut)),
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
                      // Flexible: dar ekranda sağdaki metin kısalır, satır taşmaz.
                      trailing: Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(langName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BuType.label.copyWith(color: t.mut)),
                        ),
                      ),
                    ),
                  ]),
                ),
                _label('BİLDİRİMLER'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: NotificationPrefsGroup(session: widget.session),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: BuGroup(children: [
                    BuMenuRow(
                      icon: LucideIcons.bellRing,
                      label: 'Bildirim izni (push)',
                      showChevron: false,
                      onTap: () => _toast(_pushStatus == 'Açık'
                          ? 'Anlık bildirimler açık.'
                          : 'Anlık bildirimler: $_pushStatus'),
                      trailing: Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(_pushStatus,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BuType.label.copyWith(color: t.mut)),
                        ),
                      ),
                    ),
                  ]),
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
                        icon: LucideIcons.contact,
                        label: 'Rehberden kişi bul',
                        onTap: () => _push(ContactsMatchPage(session: widget.session))),
                    BuMenuRow(
                        icon: LucideIcons.shield,
                        label: 'Gizlilik ve veriler',
                        onTap: () => _push(PrivacyDataPage(session: widget.session))),
                    BuMenuRow(
                        icon: LucideIcons.circleQuestionMark,
                        label: 'Destek ve SSS',
                        onTap: () => _push(SupportPage(session: widget.session))),
                    BuMenuRow(
                        icon: LucideIcons.logOut,
                        label: 'Tüm cihazlardan çıkış yap',
                        showChevron: false,
                        onTap: _logoutAll),
                  ]),
                ),
                const SizedBox(height: 18),
                Center(child: Text('BÜ Kampüs · Sürüm 1.0.0', style: BuType.caption.copyWith(color: t.mut))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
