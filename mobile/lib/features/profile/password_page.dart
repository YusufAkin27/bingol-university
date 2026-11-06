import 'dart:convert' show utf8;

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/identifier.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../auth/reset_code_page.dart';
import 'profil_widgets.dart';

/// Şifre güncelleme çağrısı: `POST /auth/change-password {currentPassword,newPassword}`.
/// Yanıt biçimi kesinleşene dek iki durum desteklenir: 204/boş gövde ya da yeni token çifti
/// (`accessToken`/`refreshToken`; varsa oturuma yazılır). Sözleşme değişirse yalnız bu metot uyarlanır.
Future<void> changePasswordRequest(Session session, {required String current, required String next}) async {
  final res = await session.api.post('/auth/change-password', {'currentPassword': current, 'newPassword': next});
  if (res is Map && res['accessToken'] is String && res['refreshToken'] is String) {
    await session.api.setTokens(Tokens.fromJson(res));
  }
}

/// Şifre (Hesap ve güvenlik > Şifre): iki yol sunar.
///  1) Şifreni güncelle: mevcut şifre + yeni şifre + tekrar (`POST /auth/change-password`).
///  2) Şifreni mi unuttun: hesabın kayıtlı e-postasına 6 haneli doğrulama kodu gider (`forgot-password`), kod girilir
///     (`verify-reset-code`), yeni şifre belirlenir (`reset-password`). Adımlar giriş ekranındaki şifre sıfırlama sayfalarıdır
///     ([ResetCodePage] / NewPasswordPage, `accountMode`); sunucu başarıda tüm oturumları kapatır, bu yüzden akış girişe döner.
class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key, required this.session});

  final Session session;

  static const routeName = 'password';

  /// Yeni şifre adımında anahtar süresi dolunca true yapılır; bu sayfa "Süre doldu" notunu bir kez gösterir.
  static final expiredNotice = ValueNotifier<bool>(false);

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;

  /// Hata özeti (danger satırları) ve hangi alanın hatalı olduğu.
  List<String> _errors = const [];
  final Set<String> _bad = {};

  /// "Şifreni mi unuttun?" bölümü: kod gönderiliyor, hata, süre doldu notu.
  bool _sending = false;
  String? _forgotError;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _expired = PasswordPage.expiredNotice.value;
    PasswordPage.expiredNotice.value = false;
    PasswordPage.expiredNotice.addListener(_onExpired);
  }

  void _onExpired() {
    if (!PasswordPage.expiredNotice.value) return;
    PasswordPage.expiredNotice.value = false;
    if (mounted) setState(() => _expired = true);
  }

  @override
  void dispose() {
    PasswordPage.expiredNotice.removeListener(_onExpired);
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
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e is ApiError && e.status == 403 && e.code == 'WRONG_PASSWORD') {
        _setErrors([e.message.isNotEmpty ? e.message : l.profil2SecWrongCurrent], {'current'});
      } else if (e is ApiError && e.code == 'PASSWORD_UNCHANGED') {
        _setErrors([e.message.isNotEmpty ? e.message : l.profil2SecSame], {'new'});
      } else if (e is ApiError && e.code == 'PASSWORD_TOO_LONG') {
        _setErrors([errorText(e)], {'new'});
      } else if (e is ApiError && (e.code == 'PASSWORD_TOO_WEAK' || e.code == 'PASSWORD_TOO_SHORT') && e.message.isNotEmpty) {
        // Yönetici hesaplarında sunucu daha sıkı parola politikası uygular (en az 12 karakter, yaygın şifre yasağı):
        // neden alanın altında gösterilir ("güncellenemedi" genel mesajı yanıltıcıydı).
        _setErrors([e.message], {'new'});
      } else if (e is ApiError && (e.status == 429 || e.status == 422 || e.isNetwork || knownErrorText(e, l) != null)) {
        _toast(errorText(e), kind: BuToastKind.error);
      } else if (e is ApiError && e.status >= 400 && e.status < 500 && e.status != 404 && e.message.isNotEmpty) {
        // Sunucunun istek dilindeki gerekçesi varsa genel metin yerine o gösterilir.
        _toast(e.message, kind: BuToastKind.error);
      } else {
        // Uç yoksa (404) ya da beklenmeyen hata: genel mesaj.
        _toast(l.profil2SecFailed, kind: BuToastKind.error);
      }
    }
  }

  /// Hesabın kayıtlı e-postasına kod gönderir; başarıda kod giriş sayfası açılır.
  Future<void> _sendCode() async {
    if (_sending) return;
    final email = normalizeIdentifier(widget.session.email);
    if (email.isEmpty) return;
    setState(() {
      _sending = true;
      _forgotError = null;
      _expired = false;
    });
    try {
      await widget.session.forgotPassword(email);
    } catch (e) {
      if (!mounted) return;
      // 180 sn bekleme (RESEND_COOLDOWN): kod zaten gönderilmiş ve geçerli; kod ekranına dönülebilmeli.
      if (e is ApiError && e.code == 'RESEND_COOLDOWN') {
        setState(() => _sending = false);
        await _openCodePage(email);
        return;
      }
      setState(() {
        _sending = false;
        _forgotError = errorText(e);
      });
      return;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    await _openCodePage(email);
  }

  Future<void> _openCodePage(String email) => Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'reset_code'),
          builder: (_) => ResetCodePage(session: widget.session, email: email, accountMode: true),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final email = widget.session.email ?? '';
    final noPassword = widget.session.hasPassword == false;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          ProfilTopBar(title: l.pwRowLabel),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                if (noPassword) ...[
                  // Parolasız (Google/Apple) hesap: "mevcut şifre" yoktur; tek yol e-posta koduyla şifre belirlemek.
                  ProfilFlatSection(l.profil2SecPwSection, top: 8, upper: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(l.qa1NoPasswordNote, key: const ValueKey('pw-none-note'), style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.4)),
                  ),
                  const SizedBox(height: 24),
                  Divider(height: 1, thickness: 1, color: t.bd),
                ] else ...[
                ProfilFlatSection(l.profil2SecPwSection, top: 8, upper: true),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(l.pwpIntro, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.4)),
                    const SizedBox(height: 16),
                    _PwField(
                      key: const ValueKey('pw-current'),
                      enabled: !_busy,
                      label: l.profil2SecCurrentLabel,
                      hint: l.profil2SecCurrentHint,
                      controller: _current,
                      bad: _bad.contains('current'),
                      action: TextInputAction.next,
                      hints: const [AutofillHints.password],
                    ),
                    const SizedBox(height: 16),
                    _PwField(
                      key: const ValueKey('pw-new'),
                      enabled: !_busy,
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
                      key: const ValueKey('pw-repeat'),
                      enabled: !_busy,
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
                          key: const ValueKey('pw-errors'),
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
                      key: const ValueKey('pw-submit'),
                      label: l.profil2SecPwButton,
                      busy: _busy,
                      onPressed: _busy ? null : _submit,
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                Divider(height: 1, thickness: 1, color: t.bd),
                ],
                ProfilFlatSection(noPassword ? l.qa1PwSetButton : l.pwpForgotTitle, top: 24, upper: true),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (!noPassword) Text(l.pwpForgotBody, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.4)),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      // Oturum açıkken kod, hesabın kendi adresine gider; adres değiştirilemez (salt okunur metin).
                      Text(l.pwpForgotTo(email),
                          key: const ValueKey('pw-forgot-to'),
                          textDirection: TextDirection.ltr,
                          style: tx.bodyMedium!.copyWith(color: t.ink, height: 1.4)),
                    ],
                    if (_expired || _forgotError != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(_forgotError ?? l.pwpExpired,
                            key: const ValueKey('pw-forgot-error'), style: tx.bodySmall!.copyWith(fontSize: 13, color: t.danger, height: 1.4)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    BuButton(
                      key: const ValueKey('pw-forgot-send'),
                      label: noPassword ? l.qa1PwSetButton : l.pwpForgotButton,
                      kind: BuButtonKind.outline,
                      busy: _sending,
                      onPressed: (_sending || email.isEmpty) ? null : _sendCode,
                    ),
                  ]),
                ),
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
    this.enabled = true,
  });

  /// Gönderim sürerken alanlar kilitlenir.
  final bool enabled;
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
        enabled: widget.enabled,
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
