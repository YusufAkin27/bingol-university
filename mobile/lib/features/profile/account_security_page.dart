import 'dart:convert' show utf8;

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/two_factor.dart';
import '../../widgets/bu.dart';
import 'profil_widgets.dart';
import 'two_factor_page.dart';

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

  /// İki faktörlü doğrulama durumu (satırın değeri). Sessizce yüklenir; alınamazsa satır değersiz kalır, sayfa bozulmaz.
  bool? _twoFactorOn;

  /// Hata özeti (kırmızı kart) ve hangi alanın hatalı olduğu.
  List<String> _errors = const [];
  final Set<String> _bad = {};

  @override
  void initState() {
    super.initState();
    _loadTwoFactor();
  }

  Future<void> _loadTwoFactor() async {
    try {
      final s = await TwoFactorApi(widget.session.api).status();
      if (mounted) setState(() => _twoFactorOn = s.enabled);
    } catch (_) {
      // Durum alınamadı: satır yine açılır, ayrıntı sayfası hatayı ve yeniden denemeyi gösterir.
    }
  }

  Future<void> _openTwoFactor() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: TwoFactorPage.routeName),
        builder: (_) => TwoFactorPage(session: widget.session),
      ),
    );
    if (mounted) _loadTwoFactor();
  }

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
    if (n.length < 6) {
      errors.add(l.authPwMinErr);
      bad.add('new');
    } else if (n.length > 72) {
      errors.add(l.authPwMaxErr);
      bad.add('new');
    } else if (utf8.encode(n).length > 72) {
      // Sunucu sınırı 72 BAYT: Türkçe/Arapça karakterler birden çok bayt tutar.
      errors.add(l.errPasswordTooLong);
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
      icon: BuIcons.logOut,
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
          ProfilTopBar(title: l.profil2SecTitle),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // Stitch v3: e-posta bloğu tam genişlik beyaz; etiket 13 mut, değer 16/600 ink, altında kilit + durum 12 mut.
                ColoredBox(
                  color: t.sf,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.profileEmail, style: tx.labelLarge!.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: t.mut)),
                      const SizedBox(height: 2),
                      Text(email,
                          key: const ValueKey('sec-email'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tx.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: t.ink)),
                      const SizedBox(height: 6),
                      Row(children: [
                        ExcludeSemantics(child: Icon(BuIcons.lock, size: 16, color: t.mut)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('${l.profil2SecVerified} · ${l.profil2SecEmailFixed}', style: tx.bodySmall!.copyWith(fontSize: 12, color: t.mut)),
                        ),
                      ]),
                    ]),
                  ),
                ),
                Divider(height: 1, thickness: 1, color: t.bd),
                ProfilFlatSection(l.profil2SecPwSection, top: 24, upper: true),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    const SizedBox(height: 16),
                    _PwField(
                      key: const ValueKey('sec-new'),
                      label: l.profil2SecNewLabel,
                      hint: l.profil2SecNewHint,
                      controller: _new,
                      bad: _bad.contains('new'),
                      action: TextInputAction.next,
                      hints: const [AutofillHints.newPassword],
                    ),
                    const SizedBox(height: 8),
                    Text(l.profil2SecPwRule, style: tx.bodySmall!.copyWith(fontSize: 12, color: t.mut, height: 1.4)),
                    const SizedBox(height: 16),
                    _PwField(
                      key: const ValueKey('sec-repeat'),
                      label: l.profil2SecRepeatLabel,
                      hint: l.profil2SecRepeatHint,
                      controller: _repeat,
                      bad: _bad.contains('repeat'),
                      hints: const [AutofillHints.newPassword],
                      onSubmitted: _submit,
                    ),
                    // Hata satırları: ikonsuz danger 12 sp (Stitch v3).
                    if (_errors.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Column(
                          key: const ValueKey('sec-errors'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final e in _errors)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(e, style: tx.bodySmall!.copyWith(fontSize: 12, color: t.danger)),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    BuButton(
                      key: const ValueKey('sec-submit'),
                      label: l.profil2SecPwButton,
                      background: t.prPressed, // Stitch profil-v4: #B93833
                      busy: _busy,
                      onPressed: _busy ? null : _submit,
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                Divider(height: 1, thickness: 1, color: t.bd),
                ProfilFlatSection(l.tfSecSection, top: 24, upper: true),
                ProfilFlatGroup(outlined: true, children: [
                  ProfilFlatRow(
                    key: const ValueKey('sec-2fa'),
                    icon: BuIcons.shieldCheck,
                    plainIcon: true,
                    label: l.tfTitle,
                    value: _twoFactorOn == null ? null : (_twoFactorOn! ? l.tfOn : l.tfOff),
                    onTap: _openTwoFactor,
                  ),
                ]),
                const SizedBox(height: 24),
                Divider(height: 1, thickness: 1, color: t.bd),
                ProfilFlatSection(l.profil2SecSessions, top: 24, upper: true),
                ProfilFlatGroup(outlined: true, children: [
                  ProfilFlatRow(
                    key: const ValueKey('sec-logout-all'),
                    icon: BuIcons.logOut,
                    plainIcon: true,
                    label: l.settingsLogoutAll,
                    danger: true,
                    trailing: _loggingOut ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null,
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

/// Şifre alanı: etiket üstte, 1 dp çizgili kutu (Stitch profil-v4), göz düğmesi; hatalıysa kırmızı çerçeve.
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
        child: Text(widget.label, style: tx.bodyLarge!.copyWith(fontSize: 15, fontWeight: BuType.emphasisWeight, color: t.ink)),
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
          fillColor: t.sf,
          contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 14, 4, 14),
          border: b(t.bd, 1),
          enabledBorder: widget.bad ? b(t.danger, 1.5) : b(t.bd, 1),
          focusedBorder: b(widget.bad ? t.danger : t.pr, 2),
          suffixIcon: IconButton(
            tooltip: _hidden ? l.authShowPassword : l.authHidePassword,
            icon: Icon(_hidden ? BuIcons.eye : BuIcons.eyeOff, size: 20, color: widget.bad ? t.danger : t.mut),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
      ),
    ]);
  }
}
