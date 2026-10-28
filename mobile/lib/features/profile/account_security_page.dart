import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../auth/auth_widgets.dart';
import 'profil2_widgets.dart';

/// Şifre güncelleme çağrısı: `POST /auth/change-password {currentPassword,newPassword}`.
/// Yanıt biçimi kesinleşene dek iki durum desteklenir: 204/boş gövde ya da yeni token çifti
/// (`accessToken`/`refreshToken`; varsa oturuma yazılır). Sözleşme değişirse yalnız bu metot uyarlanır.
Future<void> changePasswordRequest(Session session, {required String current, required String next}) async {
  final res = await session.api.post('/auth/change-password', {'currentPassword': current, 'newPassword': next});
  if (res is Map && res['accessToken'] is String && res['refreshToken'] is String) {
    await session.api.setTokens(Tokens.fromJson(res));
  }
}

/// Profil > Hesap ve güvenlik: e-posta, şifre güncelleme, tüm cihazlardan çıkış.
class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key, required this.session});

  final Session session;

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  bool _loggingOut = false;
  String? _currentError;
  String? _newError;

  @override
  void initState() {
    super.initState();
    _new.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String? _vCurrent(String? v) => (v == null || v.isEmpty) ? context.l10n.profilePrefsEnterPassword : null;

  String? _vNew(String? v) {
    final s = v ?? '';
    if (s.length < 8) return context.l10n.authPwMinErr;
    if (s.length > 72) return context.l10n.authPwMaxErr;
    if (s == _current.text) return context.l10n.profil2SecSame;
    return null;
  }

  String? _vRepeat(String? v) => v != _new.text ? context.l10n.profil2SecMismatch : null;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _currentError = null;
      _newError = null;
    });
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final l = context.l10n;
    try {
      await changePasswordRequest(widget.session, current: _current.text, next: _new.text);
      if (!mounted) return;
      _current.clear();
      _new.clear();
      _repeat.clear();
      setState(() => _busy = false);
      FocusManager.instance.primaryFocus?.unfocus();
      _toast(l.profil2SecUpdated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e is ApiError && e.status == 403 && e.code == 'WRONG_PASSWORD') {
          _currentError = e.message.isNotEmpty ? e.message : l.profil2SecWrongCurrent;
        } else if (e is ApiError && e.code == 'PASSWORD_UNCHANGED') {
          _newError = e.message.isNotEmpty ? e.message : l.profil2SecSame;
        } else if (e is ApiError && e.code == 'PASSWORD_TOO_LONG') {
          _newError = errorText(e);
        } else if (e is ApiError && (e.status == 429 || e.status == 422 || e.isNetwork || knownErrorText(e, l) != null)) {
          _toast(errorText(e));
        } else {
          // Uç yoksa (404) ya da beklenmeyen hata: genel mesaj.
          _toast(l.profil2SecFailed);
        }
      });
    }
  }

  Future<void> _logoutAll() async {
    final t = context.bu;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: t.sf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(context.l10n.settingsLogoutAllTitle, style: BuType.title.copyWith(color: t.ink)),
        content: Text(context.l10n.settingsLogoutAllBody, style: BuType.body.copyWith(height: 1.4, color: t.mut)),
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
    if (ok != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await widget.session.logoutAll();
    } catch (e) {
      if (mounted) {
        setState(() => _loggingOut = false);
        _toast(errorText(e));
      }
      return;
    }
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
        child: Text(s, style: BuType.label.copyWith(color: context.bu.ink, fontWeight: FontWeight.w700)),
      );

  Widget _err(String s, String key) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
        child: Semantics(
          liveRegion: true,
          child: Text(s, key: ValueKey(key), style: BuType.label.copyWith(color: P2Tones.of(context).dng, fontWeight: FontWeight.w600)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tone = P2Tones.of(context);
    final email = widget.session.email ?? '';
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: l.profil2SecTitle, onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                BuGroup(children: [
                  P2Row(
                    icon: LucideIcons.mail,
                    title: email,
                    subtitle: l.profil2SecEmailFixed,
                    trailing: P2Pill(
                        text: l.profil2SecVerified, fg: tone.okFg, bg: tone.okBg, icon: LucideIcons.check),
                  ),
                ]),
                P2SectionLabel(l.profil2SecPwSection, top: 16),
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(l.profil2SecCurrentLabel),
                      PasswordField(
                        key: const ValueKey('sec-current'),
                        controller: _current,
                        label: l.profil2SecCurrentHint,
                        validator: _vCurrent,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.password],
                      ),
                      if (_currentError != null) _err(_currentError!, 'sec-current-error'),
                      const SizedBox(height: 10),
                      _label(l.profil2SecNewLabel),
                      PasswordField(
                        key: const ValueKey('sec-new'),
                        controller: _new,
                        label: l.profil2SecNewHint,
                        validator: _vNew,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                      ),
                      if (_newError != null) _err(_newError!, 'sec-new-error'),
                      PasswordStrength(password: _new.text),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                        child: Text(l.profil2SecPwRule,
                            style: BuType.label.copyWith(color: t.mut, fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(height: 10),
                      _label(l.profil2SecRepeatLabel),
                      PasswordField(
                        key: const ValueKey('sec-repeat'),
                        controller: _repeat,
                        label: l.profil2SecRepeatHint,
                        validator: _vRepeat,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: _submit,
                      ),
                      const SizedBox(height: 16),
                      AuthButton(
                        key: const ValueKey('sec-submit'),
                        label: l.profil2SecPwButton,
                        busy: _busy,
                        onPressed: _busy ? null : _submit,
                      ),
                    ],
                  ),
                ),
                P2SectionLabel(l.profil2SecSessions, top: 18),
                BuGroup(children: [
                  P2Row(
                    key: const ValueKey('sec-logout-all'),
                    icon: LucideIcons.logOut,
                    iconColor: tone.dng,
                    iconBg: tone.dngBg,
                    title: l.settingsLogoutAll,
                    titleColor: tone.dng,
                    busy: _loggingOut,
                    onTap: _logoutAll,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
