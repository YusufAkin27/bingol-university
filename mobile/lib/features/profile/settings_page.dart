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
import '../chat/contacts_match_page.dart';
import '../chat/photo_autosave.dart';
import '../support/support_page.dart';
import 'notification_prefs_page.dart';
import 'privacy_data_page.dart';
import 'profil2_widgets.dart';

const _langNames = {'tr': 'Türkçe', 'en': 'English', 'ar': 'العربية'};

/// Ayarlar (Stitch 49-1, 49-6): GÖRÜNÜM (dil), BİLDİRİMLER, GİZLİLİK VE HESAP; tonlu simge karolu gruplu kartlar.
/// Tema seçimi Profil sekmesindedir.
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
  bool _saveToGallery = true; // p22: sohbet fotoğraflarını galeriye kaydet (varsayılan açık)
  String _pushStatus = '...'; // 'notConfigured' | 'on' | 'off' | 'notGranted'

  CrashReporter get _crash => CrashReporter.instance;

  LocaleController? get _lc => widget.localeController ?? LocaleController.current;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPushStatus();
    PhotoAutoSave.instance.enabled().then((v) {
      if (mounted) setState(() => _saveToGallery = v);
    });
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
      icon: LucideIcons.logOut,
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

  void _toast(String m, {BuToastKind kind = BuToastKind.info}) => BuToast.show(context, m, kind: kind);

  Future<void> _patch(Map<String, dynamic> body, VoidCallback rollback) async {
    try {
      await widget.session.api.patch('/users/me', body);
    } catch (e) {
      if (!mounted) return;
      setState(rollback);
      _toast(errorText(e), kind: BuToastKind.error);
    }
  }

  /// Dil seçici (Stitch 49-6): Sistem / Türkçe / English / العربية; seçili satır tonlu + onay işareti.
  Future<void> _pickLang() async {
    final lc = _lc;
    if (lc == null) return;
    final l = context.l10n;
    final options = <(String, String, String, IconData)>[
      ('system', l.languageSystem, l.p19LangSystemDesc, LucideIcons.smartphone),
      ('tr', _langNames['tr']!, 'Uygulama dili Türkçe', LucideIcons.languages),
      ('en', _langNames['en']!, 'Interface and notifications in English', LucideIcons.globe),
      ('ar', _langNames['ar']!, 'الواجهة والإشعارات باللغة العربية', LucideIcons.earth),
    ];
    final chosen = await BuSheet.show<String>(
      context,
      title: l.settingsLanguage,
      subtitle: l.settingsLanguageHint,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        for (final o in options) _LangOption(id: o.$1, name: o.$2, desc: o.$3, icon: o.$4, selected: o.$1 == lc.pref),
      ]),
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
    // Hap kısa metin taşır (tek satır); uzun açıklama dokununca bildirimde.
    final pillText = switch (_pushStatus) {
      'on' => l.pushOn,
      'notGranted' => l.pushNotGranted,
      _ => l.p19PushOffShort,
    };
    final blue = t.tint(1);
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: l.settingsTitle, onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                P2SectionLabel(l.settingsSectionAppearance),
                BuGroup(dividerIndent: 66, children: [
                  BuSettingsTile(
                    key: const ValueKey('settings-language'),
                    icon: LucideIcons.languages,
                    title: l.settingsLanguage,
                    subtitle: l.settingsLanguageHint,
                    value: langName,
                    tint: blue,
                    onTap: _lc != null ? _pickLang : null,
                  ),
                ]),
                P2SectionLabel(l.settingsSectionNotifications, top: 18),
                BuGroup(dividerIndent: 66, children: [
                  BuSettingsTile(
                    key: const ValueKey('settings-notif-prefs'),
                    icon: LucideIcons.bell,
                    title: l.profil1Notifications,
                    onTap: () => _push(NotificationPrefsPage(session: widget.session)),
                  ),
                  BuSettingsTile(
                    key: const ValueKey('settings-push'),
                    icon: LucideIcons.bellRing,
                    title: l.pushPermission,
                    tint: blue,
                    trailing: Flexible(
                      child: P2Pill(
                        text: pillText,
                        tone: _pushStatus == 'on' ? P2PillTone.ok : P2PillTone.mute,
                        dot: _pushStatus == 'on',
                      ),
                    ),
                    onTap: () => _toast(_pushStatus == 'on' ? l.pushOnToast : l.pushStatusToast(pushText)),
                  ),
                ]),
                P2SectionLabel(l.settingsSectionPrivacy, top: 18),
                ListenableBuilder(
                  listenable: _crash,
                  builder: (_, __) => BuGroup(dividerIndent: 66, children: [
                    BuSettingsTile.toggle(
                      key: const ValueKey('settings-show-email'),
                      icon: LucideIcons.atSign,
                      title: l.settingsShowEmail,
                      value: _showEmail,
                      tint: blue,
                      onChanged: _loaded ? _toggleEmail : null,
                    ),
                    BuSettingsTile(
                      icon: LucideIcons.contact,
                      title: l.settingsFindContacts,
                      tint: blue,
                      onTap: () => _push(ContactsMatchPage(session: widget.session)),
                    ),
                    BuSettingsTile(
                      icon: LucideIcons.shield,
                      title: l.settingsPrivacyData,
                      tint: blue,
                      onTap: () => _push(PrivacyDataPage(session: widget.session)),
                    ),
                    BuSettingsTile(
                      icon: LucideIcons.circleQuestionMark,
                      title: l.settingsSupport,
                      onTap: () => _push(SupportPage(session: widget.session)),
                    ),
                    // Anonim hata raporu: açık/kapalı anahtarı.
                    BuSettingsTile.toggle(
                      key: const ValueKey('crashReportsSwitch'),
                      icon: LucideIcons.bug,
                      title: l.settingsCrashReports,
                      subtitle: l.p19CrashReportsShort,
                      value: _crash.enabled,
                      tint: blue,
                      onChanged: (v) => _crash.setEnabled(v),
                    ),
                    BuSettingsTile(
                      key: const ValueKey('settings-logout-all'),
                      icon: LucideIcons.logOut,
                      title: l.settingsLogoutAll,
                      danger: true,
                      trailing: ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.danger)),
                      onTap: _logoutAll,
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                BuGroup(dividerIndent: 66, children: [
                  BuSettingsTile.toggle(
                      key: const ValueKey('settings-save-to-gallery'),
                      icon: LucideIcons.imageDown,
                      title: l.p22SaveGalleryTitle,
                      subtitle: l.p22SaveGalleryDesc,
                      value: _saveToGallery,
                      tint: blue,
                      onChanged: (v) {
                        setState(() => _saveToGallery = v);
                        PhotoAutoSave.instance.setEnabled(v);
                      },
                    ),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                  child: Text(l.p22SaveGalleryCloud, key: const ValueKey('settings-save-to-gallery-note'), style: tx.bodySmall!.copyWith(color: t.mut)),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(l.settingsVersion(appVersion), style: tx.bodySmall!.copyWith(color: t.mut)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dil seçeneği satırı: simge karosu, ad, açıklama, sağda seçim halkası/onay.
class _LangOption extends StatelessWidget {
  const _LangOption({required this.id, required this.name, required this.desc, required this.icon, required this.selected});

  final String id;
  final String name;
  final String desc;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: '$name. $desc',
        excludeSemantics: true,
        child: Material(
          color: selected ? t.soft : t.sf2,
          borderRadius: BuRadius.bMd,
          child: InkWell(
            key: ValueKey('lang-$id'),
            borderRadius: BuRadius.bMd,
            onTap: () => Navigator.pop(context, id),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 14, 8),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bSm),
                    child: Icon(icon, size: 20, color: selected ? t.pr : t.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(name, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                      const SizedBox(height: 1),
                      Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  selected
                      ? Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle),
                          child: Icon(LucideIcons.check, size: 15, color: t.onPr),
                        )
                      : Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(color: t.bd.withValues(alpha: .6), shape: BoxShape.circle),
                        ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
