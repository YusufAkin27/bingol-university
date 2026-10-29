import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../core/crash/crash_reporter.dart';
import '../../core/locale_controller.dart';
import '../../core/push/push_service.dart';
import '../../core/session.dart';
import '../../core/theme_controller.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../academic/reminder_settings_page.dart';
import '../chat/contacts_match_page.dart';
import '../support/support_page.dart';
import 'notification_prefs_page.dart';
import 'privacy_data_page.dart';
import '../../core/typography.dart';

const _langNames = {'tr': 'Türkçe', 'en': 'English', 'ar': 'العربية'};

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.session, required this.themeController, this.push, this.localeController});

  /// Verilmezse uygulama genelindeki örnek kullanılır.
  final LocaleController? localeController;

  final Session session;

  /// Verilirse push durumu buradan okunur; yoksa Firebase başlatılmış mı diye bakılır.
  final PushService? push;
  final ThemeController themeController;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showEmail = false;
  bool _loaded = false;
  String _pushStatus = '...'; // 'notConfigured' | 'on' | 'off' | 'notGranted'

  CrashReporter get _crash => CrashReporter.instance;

  LocaleController? get _lc => widget.localeController ?? LocaleController.current;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPushStatus();
  }

  Future<void> _loadPushStatus() async {
    var text = 'notConfigured';
    try {
      final configured = (widget.push?.enabled ?? false) || Firebase.apps.isNotEmpty;
      if (configured) {
        final st = await FirebaseMessaging.instance.getNotificationSettings();
        text = switch (st.authorizationStatus) {
          AuthorizationStatus.authorized || AuthorizationStatus.provisional => 'on',
          AuthorizationStatus.denied => 'off',
          _ => 'notGranted',
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
        title: Text(context.l10n.settingsLogoutAllTitle, style: BuType.title.copyWith(color: t.ink)),
        content: Text(context.l10n.settingsLogoutAllBody,
            style: BuType.body.copyWith(height: 1.4, color: t.mut)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(context.l10n.commonCancel, style: BuType.bodyStrong.copyWith(color: t.mut))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(context.l10n.settingsLogoutAllConfirm, style: BuType.bodyStrong.copyWith(color: t.danger))),
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
    final lc = _lc;
    if (lc == null) return;
    final t = context.bu;
    final l10n = context.l10n;
    final options = <(String, String)>[
      ('system', l10n.languageSystem),
      for (final e in _langNames.entries) (e.key, e.value),
    ];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.sf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 16),
          Text(l10n.settingsLanguageHint, textAlign: TextAlign.center, style: BuType.heading.copyWith(color: t.ink)),
          const SizedBox(height: 8),
          for (final o in options)
            ListTile(
              title: Text(o.$2, style: BuType.bodyStrong.copyWith(color: t.ink)),
              selected: o.$1 == lc.pref,
              trailing: o.$1 == lc.pref ? Icon(LucideIcons.check, color: t.pr) : null,
              onTap: () => Navigator.pop(ctx, o.$1),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (chosen == null || chosen == lc.pref) return;
    await lc.set(chosen);
    // Sunucu profil dili (bildirim/e-posta) uygulama diliyle eşitlenir; hata sessizdir.
    try {
      await widget.session.api.patch('/users/me', {'language': lc.locale.languageCode});
    } catch (_) {}
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
    final l10n = context.l10n;
    final lc = _lc;
    final langName = lc == null
        ? ''
        : (lc.pref == 'system' ? l10n.languageSystem : (_langNames[lc.pref] ?? lc.pref));
    final pushText = switch (_pushStatus) {
      'notConfigured' => l10n.pushNotConfigured,
      'on' => l10n.pushOn,
      'off' => l10n.pushOff,
      'notGranted' => l10n.pushNotGranted,
      _ => _pushStatus,
    };
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: l10n.settingsTitle, onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
              children: [
                _label(l10n.settingsSectionAppearance),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListenableBuilder(
                    listenable: widget.themeController,
                    builder: (_, __) => BuSegmented(
                      items: [l10n.themeSystem, l10n.themeLight, l10n.themeDark],
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
                      label: l10n.settingsLanguage,
                      onTap: _lc != null ? _pickLang : null,
                      // Flexible: dar ekranda sağdaki metin kısalır, satır taşmaz.
                      trailing: Flexible(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 4),
                          child: Text(langName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BuType.label.copyWith(color: t.mut)),
                        ),
                      ),
                    ),
                  ]),
                ),
                _label(l10n.settingsSectionNotifications),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: NotificationPrefsGroup(session: widget.session),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: BuGroup(children: [
                    // Akademik: ders/sınav yerel hatırlatmaları (docs: lib/features/academic).
                    BuMenuRow(
                      icon: LucideIcons.alarmClock,
                      label: l10n.profileReminders,
                      onTap: () => _push(ReminderSettingsPage(session: widget.session)),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: BuGroup(children: [
                    BuMenuRow(
                      icon: LucideIcons.bellRing,
                      label: l10n.pushPermission,
                      showChevron: false,
                      onTap: () => _toast(_pushStatus == 'on'
                          ? l10n.pushOnToast
                          : l10n.pushStatusToast(pushText)),
                      trailing: Flexible(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 4),
                          child: Text(pushText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BuType.label.copyWith(color: t.mut)),
                        ),
                      ),
                    ),
                  ]),
                ),
                _label(l10n.settingsSectionPrivacy),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: BuGroup(children: [
                    PrefSwitchRow(
                        label: l10n.settingsShowEmail,
                        value: _showEmail,
                        onChanged: _loaded ? _toggleEmail : null),
                    BuMenuRow(
                        icon: LucideIcons.contact,
                        label: l10n.settingsFindContacts,
                        onTap: () => _push(ContactsMatchPage(session: widget.session))),
                    BuMenuRow(
                        icon: LucideIcons.shield,
                        label: l10n.settingsPrivacyData,
                        onTap: () => _push(PrivacyDataPage(session: widget.session))),
                    BuMenuRow(
                        icon: LucideIcons.circleQuestionMark,
                        label: l10n.settingsSupport,
                        onTap: () => _push(SupportPage(session: widget.session))),
                    BuMenuRow(
                        icon: LucideIcons.logOut,
                        label: l10n.settingsLogoutAll,
                        danger: true,
                        showChevron: false,
                        onTap: _logoutAll),
                  ]),
                ),
                // Anonim hata raporu: açık/kapalı anahtarı + ne gönderildiğini anlatan gizlilik metni.
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListenableBuilder(
                    listenable: _crash,
                    builder: (_, __) => BuGroup(children: [
                      PrefSwitchRow(
                          key: const ValueKey('crashReportsSwitch'),
                          label: l10n.settingsCrashReports,
                          value: _crash.enabled,
                          onChanged: (v) => _crash.setEnabled(v)),
                    ]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                  child: Text(l10n.settingsCrashReportsDesc,
                      key: const ValueKey('crashReportsDesc'),
                      style: BuType.caption.copyWith(color: t.mut, height: 1.4)),
                ),
                const SizedBox(height: 18),
                Center(child: Text(l10n.settingsVersion('1.0.0'), style: BuType.caption.copyWith(color: t.mut))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
