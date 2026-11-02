import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../core/app_gate.dart' show appVersion;
import '../../core/crash/crash_reporter.dart';
import '../../core/locale_controller.dart';
import '../../core/push/push_service.dart';
import '../../core/session.dart';
import '../../core/theme_controller.dart';
import '../../widgets/bu.dart';
import '../auth/help/about_page.dart';
import '../chat/chat_background_settings_page.dart';
import '../chat/contacts_match_page.dart';
import '../support/support_page.dart';
import 'account_security_page.dart';
import 'blocked_users_page.dart';
import 'notification_prefs_page.dart';
import 'privacy_data_page.dart';
import 'profil_widgets.dart';

const _langNames = {'tr': 'Türkçe', 'en': 'English', 'ar': 'العربية'};

/// Ayarlar (Stitch v3 kategori 5, birebir): üst çubuk (geri + başlık), bölüm etiketi 13/500 mut (büyük harf değil),
/// tam genişlik 56 dp satırlar (sf zemin, 1 dp bd ayırıcı; kutu/kart/simge karosu yok), satır yazısı 16 ink, değer 15 mut,
/// chevron 20 mut. Bölümler: Görünüm (Dil, Tema), Sohbet, Bildirimler, Gizlilik ve hesap. En altta soluk sürüm yazısı.
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
  String _pushStatus = '...'; // 'notConfigured' | 'on' | 'off' | 'notGranted'

  CrashReporter get _crash => CrashReporter.instance;

  LocaleController? get _lc => widget.localeController ?? LocaleController.current;

  @override
  void initState() {
    super.initState();
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
    final l = context.l10n;
    final ok = await BuDialog.confirm(
      context,
      title: l.settingsLogoutAllTitle,
      message: l.settingsLogoutAllBody,
      confirmLabel: l.settingsLogoutAllConfirm,
      cancelLabel: l.commonCancel,
      destructive: true,
      icon: BuIcons.logOut,
    );
    if (!ok) return;
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

  Future<void> _signOut() async {
    final l = context.l10n;
    final ok = await BuDialog.confirm(
      context,
      title: l.profileSignOutTitle,
      message: l.profileSignOutBody,
      confirmLabel: l.profileSignOut,
      cancelLabel: l.profileCancel,
      destructive: true,
      icon: BuIcons.logOut,
    );
    if (!ok) return;
    await widget.session.signOut();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _toast(String m, {BuToastKind kind = BuToastKind.info}) => BuToast.show(context, m, kind: kind);

  /// Dil seçici (Stitch v3 "Dil sheet"): Sistem / Türkçe / English / العربية; seçili satırda onay işareti.
  Future<void> _pickLang() async {
    final lc = _lc;
    if (lc == null) return;
    final l = context.l10n;
    final chosen = await showProfilChoiceSheet(
      context,
      title: l.settingsLanguage,
      selected: lc.pref,
      options: [
        ('system', l.languageSystem),
        for (final e in _langNames.entries) (e.key, e.value),
      ],
    );
    if (chosen == null || chosen == lc.pref) return;
    await lc.set(chosen);
    // Sunucu profil dili (bildirim/e-posta) uygulama diliyle eşitlenir; hata sessizdir.
    try {
      await widget.session.api.patch('/users/me', {'language': lc.locale.languageCode});
    } catch (_) {}
  }

  static const _modes = ['system', 'light', 'dark'];

  String _modeId() => switch (widget.themeController.mode) {
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
      };

  String _modeName(String id) => switch (id) {
        'light' => context.l10n.themeLight,
        'dark' => context.l10n.themeDark,
        _ => context.l10n.themeSystem,
      };

  Future<void> _pickTheme() async {
    final chosen = await showProfilChoiceSheet(
      context,
      title: context.l10n.profil1Theme,
      selected: _modeId(),
      options: [for (final m in _modes) (m, _modeName(m))],
    );
    if (chosen == null) return;
    widget.themeController.set(const {
      'system': ThemeMode.system,
      'light': ThemeMode.light,
      'dark': ThemeMode.dark,
    }[chosen]!);
  }

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final lc = _lc;
    final langName = lc == null ? '' : (lc.pref == 'system' ? l.languageSystem : (_langNames[lc.pref] ?? lc.pref));
    final pushText = switch (_pushStatus) {
      'notConfigured' => l.pushNotConfigured,
      'on' => l.pushOn,
      'off' => l.pushOff,
      'notGranted' => l.pushNotGranted,
      _ => _pushStatus,
    };
    // Değer kısa metin taşır (tek satır); uzun açıklama dokununca bildirimde.
    final pushValue = switch (_pushStatus) {
      'on' => l.pushOn,
      'notGranted' => l.pushNotGranted,
      _ => l.p19PushOffShort,
    };
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          ProfilTopBar(title: l.settingsTitle),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 32),
              children: [
                ProfilFlatSection(l.settingsSectionAppearance, top: 12),
                ProfilFlatGroup(children: [
                  ProfilFlatRow(
                    key: const ValueKey('settings-language'),
                    icon: BuIcons.globe,
                    label: l.settingsLanguage,
                    value: langName,
                    onTap: lc != null ? _pickLang : null,
                  ),
                  ProfilFlatRow(
                    key: const ValueKey('settings-theme'),
                    icon: BuIcons.palette,
                    label: l.profil1Theme,
                    value: _modeName(_modeId()),
                    onTap: _pickTheme,
                  ),
                ]),
                ProfilFlatSection(l.navChat),
                ProfilFlatGroup(children: [
                  ProfilFlatRow(
                    key: const ValueKey('settings-chats'),
                    icon: BuIcons.image,
                    label: l.p67ChatBgTitle,
                    onTap: () => _push(const ChatBackgroundSettingsPage()),
                  ),
                  ProfilFlatRow(
                    icon: BuIcons.users,
                    label: l.settingsFindContacts,
                    onTap: () => _push(ContactsMatchPage(session: widget.session)),
                  ),
                ]),
                ProfilFlatSection(l.settingsSectionNotifications),
                ProfilFlatGroup(children: [
                  ProfilFlatRow(
                    key: const ValueKey('settings-notif-prefs'),
                    icon: BuIcons.bell,
                    label: l.profil1Notifications,
                    onTap: () => _push(NotificationPrefsPage(session: widget.session)),
                  ),
                  ProfilFlatRow(
                    key: const ValueKey('settings-push'),
                    icon: BuIcons.bell,
                    label: l.p21HelpPermTitle,
                    value: pushValue,
                    onTap: () => _toast(_pushStatus == 'on' ? l.pushOnToast : l.pushStatusToast(pushText)),
                  ),
                ]),
                ProfilFlatSection(l.settingsSectionPrivacy),
                ListenableBuilder(
                  listenable: _crash,
                  builder: (_, __) => ProfilFlatGroup(children: [
                    ProfilFlatRow(
                      icon: BuIcons.lock,
                      label: l.settingsPrivacyData,
                      onTap: () => _push(PrivacyDataPage(session: widget.session)),
                    ),
                    ProfilFlatRow(
                      icon: BuIcons.shieldCheck,
                      label: l.profil1AccountSecurity,
                      onTap: () => _push(AccountSecurityPage(session: widget.session)),
                    ),
                    ProfilFlatRow(
                      icon: BuIcons.userX,
                      label: l.profilePrefsBlockedTitle,
                      onTap: () => _push(BlockedUsersPage(session: widget.session)),
                    ),
                    ProfilFlatRow(
                      icon: BuIcons.headset,
                      label: l.settingsSupport,
                      onTap: () => _push(SupportPage(session: widget.session)),
                    ),
                    ProfilFlatRow(
                      icon: BuIcons.info,
                      label: l.profileAboutShort,
                      onTap: () => _push(AboutPage(session: widget.session)),
                    ),
                    // Anonim hata raporu: açık/kapalı anahtarı (açıklama altında).
                    ProfilFlatToggle(
                      key: const ValueKey('crashReportsSwitch'),
                      label: l.settingsCrashReports,
                      sub: l.p19CrashReportsShort,
                      value: _crash.enabled,
                      onChanged: (v) => _crash.setEnabled(v),
                    ),
                    ProfilFlatRow(
                      key: const ValueKey('settings-logout-all'),
                      icon: BuIcons.logOut,
                      label: l.settingsLogoutAll,
                      danger: true,
                      onTap: _logoutAll,
                    ),
                    ProfilFlatRow(
                      key: const ValueKey('settings-sign-out'),
                      icon: BuIcons.logOut,
                      label: l.profileSignOut,
                      onTap: _signOut,
                      chevron: false,
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(l.settingsVersion(appVersion), style: tx.bodySmall!.copyWith(fontSize: 12, color: t.mut)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
