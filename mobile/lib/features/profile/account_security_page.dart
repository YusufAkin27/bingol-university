import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
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

/// Hesap ve güvenlik (Stitch 49-2): e-posta kartı, şifre güncelleme, tüm cihazlardan çıkış.
class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key, required this.session});

  final Session session;

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  bool _loggingOut = false;

  /// Hata özeti (kırmızı kart) ve hangi alanın hatalı olduğu.
  List<String> _errors = const [];
  final Set<String> _bad = {};

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _toast(String m, {BuToastKind kind = BuToastKind.info}) => BuToast.show(context, m, kind: kind);

  void _setErrors(List<String> errors, Set<String> bad) => setState(() {
        _errors = errors;
        _bad
          ..clear()
          ..addAll(bad);
      });

  /// Yerel doğrulama: kurallar ve eşleşmeler. Boşsa gönderilebilir.
  (List<String>, Set<String>) _validate() {
    final l = context.l10n;
    final errors = <String>[];
    final bad = <String>{};
    if (_current.text.isEmpty) {
      errors.add(l.profilePrefsEnterPassword);
      bad.add('current');
    }
    final n = _new.text;
    if (n.length < 8) {
      errors.add(l.authPwMinErr);
      bad.add('new');
    } else if (n.length > 72) {
      errors.add(l.authPwMaxErr);
      bad.add('new');
    } else if (n == _current.text) {
      errors.add(l.profil2SecSame);
      bad.add('new');
    }
    if (_repeat.text != n) {
      errors.add(l.profil2SecMismatch);
      bad.add('repeat');
    }
    return (errors, bad);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final (errors, bad) = _validate();
    if (errors.isNotEmpty) {
      _setErrors(errors, bad);
      return;
    }
    _setErrors(const [], const {});
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
      _toast(l.profil2SecUpdated, kind: BuToastKind.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e is ApiError && e.status == 403 && e.code == 'WRONG_PASSWORD') {
        _setErrors([e.message.isNotEmpty ? e.message : l.profil2SecWrongCurrent], {'current'});
      } else if (e is ApiError && e.code == 'PASSWORD_UNCHANGED') {
        _setErrors([e.message.isNotEmpty ? e.message : l.profil2SecSame], {'new'});
      } else if (e is ApiError && e.code == 'PASSWORD_TOO_LONG') {
        _setErrors([errorText(e)], {'new'});
      } else if (e is ApiError && (e.status == 429 || e.status == 422 || e.isNetwork || knownErrorText(e, l) != null)) {
        _toast(errorText(e), kind: BuToastKind.error);
      } else {
        // Uç yoksa (404) ya da beklenmeyen hata: genel mesaj.
        _toast(l.profil2SecFailed, kind: BuToastKind.error);
      }
    }
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
    if (!ok || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await widget.session.logoutAll();
    } catch (e) {
      if (mounted) {
        setState(() => _loggingOut = false);
        _toast(errorText(e), kind: BuToastKind.error);
      }
      return;
    }
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final email = widget.session.email ?? '';
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: l.profil2SecTitle, onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                BuCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const P2IconTile(icon: LucideIcons.atSign, neutral: true, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(trUpper(l.profileEmail),
                              style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, letterSpacing: .6, color: t.mut)),
                          Text(email,
                              key: const ValueKey('sec-email'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      P2Pill(text: l.profil2SecVerified, tone: P2PillTone.ok, icon: LucideIcons.circleCheck),
                      P2Pill(text: l.profil2SecEmailFixed, icon: LucideIcons.lock),
                    ]),
                  ]),
                ),
                P2Heading(l.profil2SecPwSection, top: 20),
                BuCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _PwField(
                      key: const ValueKey('sec-current'),
                      label: l.profil2SecCurrentLabel,
                      hint: l.profil2SecCurrentHint,
                      controller: _current,
                      bad: _bad.contains('current'),
                      action: TextInputAction.next,
                      hints: const [AutofillHints.password],
                    ),
                    const SizedBox(height: 14),
                    _PwField(
                      key: const ValueKey('sec-new'),
                      label: l.profil2SecNewLabel,
                      hint: l.profil2SecNewHint,
                      controller: _new,
                      bad: _bad.contains('new'),
                      action: TextInputAction.next,
                      hints: const [AutofillHints.newPassword],
                    ),
                    const SizedBox(height: 14),
                    _PwField(
                      key: const ValueKey('sec-repeat'),
                      label: l.profil2SecRepeatLabel,
                      hint: l.profil2SecRepeatHint,
                      controller: _repeat,
                      bad: _bad.contains('repeat'),
                      hints: const [AutofillHints.newPassword],
                      onSubmitted: _submit,
                    ),
                    const SizedBox(height: 12),
                    Text(l.profil2SecPwRule, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4)),
                    if (_errors.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      P2NoticeCard(key: const ValueKey('sec-errors'), lines: _errors, bullets: true),
                    ],
                    const SizedBox(height: 16),
                    BuButton(
                      key: const ValueKey('sec-submit'),
                      label: l.profil2SecPwButton,
                      busy: _busy,
                      onPressed: _busy ? null : _submit,
                    ),
                  ]),
                ),
                P2Heading(l.profil2SecSessions, top: 20),
                BuGroup(children: [
                  BuSettingsTile(
                    key: const ValueKey('sec-logout-all'),
                    icon: LucideIcons.logOut,
                    title: l.settingsLogoutAll,
                    subtitle: l.p19LogoutAllSub,
                    danger: true,
                    trailing: _loggingOut
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut)),
                    onTap: _loggingOut ? null : _logoutAll,
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

/// Şifre alanı: küçük etiket üstte, dolgulu kutu, göz düğmesi; hatalıysa kırmızı çerçeve.
class _PwField extends StatefulWidget {
  const _PwField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.bad = false,
    this.action = TextInputAction.done,
    this.hints,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool bad;
  final TextInputAction action;
  final Iterable<String>? hints;
  final VoidCallback? onSubmitted;

  @override
  State<_PwField> createState() => _PwFieldState();
}

class _PwFieldState extends State<_PwField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    OutlineInputBorder b(Color c, double w) =>
        OutlineInputBorder(borderRadius: BuRadius.bMd, borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 2, bottom: 6),
        child: Text(widget.label, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
      ),
      TextField(
        controller: widget.controller,
        obscureText: _hidden,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: widget.hints,
        textInputAction: widget.action,
        onSubmitted: widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
        style: tx.bodyLarge!.copyWith(color: t.ink),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: tx.bodyLarge!.copyWith(color: t.mut),
          filled: true,
          fillColor: t.sf2,
          contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 14, 4, 14),
          border: b(t.sf2, 0),
          enabledBorder: widget.bad ? b(t.danger, 1.5) : b(t.sf2, 0),
          focusedBorder: b(widget.bad ? t.danger : t.pr, 2),
          suffixIcon: IconButton(
            tooltip: _hidden ? l.authShowPassword : l.authHidePassword,
            icon: Icon(_hidden ? LucideIcons.eye : LucideIcons.eyeOff, size: 20, color: t.mut),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
      ),
    ]);
  }
}
