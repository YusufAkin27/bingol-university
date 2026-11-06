import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../core/app_gate.dart' show appVersion;
import '../../core/analytics.dart';
import '../../core/crash/crash_reporter.dart';
import '../../core/locale_controller.dart';
import '../../core/permissions/permission_service.dart';
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
import '../widgets/widgets_info_page.dart';
import 'privacy_data_page.dart';
import 'profil_widgets.dart';

const _langNames = {'tr': 'Türkçe', 'en': 'English', 'ar': 'العربية'};

/// Ayarlar: üst çubuk (geri + başlık), bölüm etiketi 13 mut (büyük harf değil), ince çerçeveli 16 dp gruplar
/// (56 dp satırlar, 1 dp ince ayırıcı; simge karosu yok), satır yazısı 16 ink, değer 15 mut, chevron 20 mut.
/// Bölümler: Görünüm (Dil, Tema: önizlemeli Sistem/Açık/Koyu seçici), Sohbet, Bildirimler, Gizlilik ve hesap.
/// En altta soluk sürüm yazısı.
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

  void _push(Widget page, [String? screen]) => Navigator.push(context, MaterialPageRoute(settings: RouteSettings(name: screen), builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final lc = _lc;
    final langName = lc == null ? '' : (lc.pref == 'system' ? l.languageSystem : (_langNames[lc.pref] ?? lc.pref));
    // Değer kısa metin taşır (tek satır).
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
                ProfilFlatGroup(outlined: true, children: [
                  ProfilFlatRow(
                    plainIcon: true,
                    key: const ValueKey('settings-language'),
                    icon: BuIcons.globe,
                    label: l.settingsLanguage,
                    value: langName,
                    onTap: lc != null ? _pickLang : null,
                  ),
                  // Tema: Sistem / Açık / Koyu tek dokunuşla (önizlemeli seçici; alt sayfa yok).
                  Column(
                    key: const ValueKey('settings-theme'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 12),
                        child: Row(children: [
                          ExcludeSemantics(child: Icon(BuIcons.palette, size: 22, color: t.ink)),
                          const SizedBox(width: 14),
                          Expanded(child: Text(l.profil1Theme, style: tx.bodyLarge!.copyWith(fontSize: 16, color: t.ink))),
                        ]),
                      ),
                      ListenableBuilder(
                        listenable: widget.themeController,
                        builder: (_, __) => ProfilThemePicker(
                          mode: widget.themeController.mode,
                          onChanged: widget.themeController.set,
                          systemLabel: l.themeSystem,
                          lightLabel: l.themeLight,
                          darkLabel: l.themeDark,
                        ),
                      ),
                    ],
                  ),
                ]),
                ProfilFlatSection(l.navChat),
                ProfilFlatGroup(outlined: true, children: [
                  ProfilFlatRow(
                    plainIcon: true,
                    key: const ValueKey('settings-chats'),
                    icon: BuIcons.image,
                    label: l.p67ChatBgTitle,
                    onTap: () => _push(const ChatBackgroundSettingsPage(), 'chat_background_settings'),
                  ),
                  ProfilFlatRow(
                    plainIcon: true,
                    icon: BuIcons.users,
                    label: l.settingsFindContacts,
                    onTap: () => _push(ContactsMatchPage(session: widget.session), 'contacts_match'),
                  ),
                ]),
                ProfilFlatSection(l.settingsSectionNotifications),
                ProfilFlatGroup(outlined: true, children: [
                  ProfilFlatRow(
                    plainIcon: true,
                    key: const ValueKey('settings-notif-prefs'),
                    icon: BuIcons.bell,
                    label: l.profil1Notifications,
                    onTap: () => _push(NotificationPrefsPage(session: widget.session), 'notification_prefs'),
                  ),
                  ProfilFlatRow(
                    plainIcon: true,
                    key: const ValueKey('settings-push'),
                    icon: BuIcons.bellRing,
                    label: l.p21HelpPermTitle,
                    value: pushValue,
                    // Bildirim izni işletim sistemindedir: dokununca sistem ayarları açılır (toast yok).
                    onTap: () => PermissionService.instance.openSettings(),
                  ),
                ]),
                ProfilFlatSection(l.settingsSectionPrivacy),
                ListenableBuilder(
                  listenable: Listenable.merge([_crash, Analytics.instance]),
                  builder: (_, __) => ProfilFlatGroup(outlined: true, children: [
                    ProfilFlatRow(
                    plainIcon: true,
                      icon: BuIcons.lock,
                      label: l.settingsPrivacyData,
                      onTap: () => _push(PrivacyDataPage(session: widget.session), 'privacy_data'),
                    ),
                    ProfilFlatRow(
                    plainIcon: true,
                      icon: BuIcons.shieldCheck,
                      label: l.profil1AccountSecurity,
                      onTap: () => _push(AccountSecurityPage(session: widget.session), 'account_security'),
                    ),
                    ProfilFlatRow(
                    plainIcon: true,
                      icon: BuIcons.userX,
                      label: l.profilePrefsBlockedTitle,
                      onTap: () => _push(BlockedUsersPage(session: widget.session), 'blocked_users'),
                    ),
                    ProfilFlatRow(
                    plainIcon: true,
                      icon: BuIcons.headset,
                      label: l.settingsSupport,
                      onTap: () => _push(SupportPage(session: widget.session), 'support'),
                    ),
                    ProfilFlatRow(
                    plainIcon: true,
                      icon: BuIcons.info,
                      label: l.profileAboutShort,
                      onTap: () => _push(AboutPage(session: widget.session), 'about'),
                    ),
                    // Anonim hata raporu: açık/kapalı anahtarı (açıklama altında).
                    ProfilFlatToggle(
                      key: const ValueKey('crashReportsSwitch'),
                      label: l.settingsCrashReports,
                      sub: l.p19CrashReportsShort,
                      value: _crash.enabled,
                      onChanged: (v) => _crash.setEnabled(v),
                    ),
                    // Kullanım analizi: kapatınca olay toplama durur, bekleyen kuyruk silinir.
                    ProfilFlatToggle(
                      key: const ValueKey('analyticsSwitch'),
                      label: l.settingsAnalytics,
                      sub: l.settingsAnalyticsSub,
                      value: Analytics.instance.enabled,
                      onChanged: (v) => Analytics.instance.setEnabled(v),
                    ),
                    ProfilFlatRow(
                    plainIcon: true,
                      key: const ValueKey('settings-sign-out'),
                      icon: BuIcons.logOut,
                      label: l.profileSignOut,
                      onTap: _signOut,
                      chevron: false,
                    ),
                  ]),
                ),
                ProfilFlatSection(l.widgetsRowTitle),
                ProfilFlatGroup(outlined: true, children: [
                  ProfilFlatRow(
                    plainIcon: true,
                    key: const ValueKey('settings-widgets'),
                    icon: BuIcons.smartphone,
                    label: l.widgetsRowTitle,
                    onTap: () => _push(const WidgetsInfoPage(), 'widgets_info'),
                  ),
                ]),
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
