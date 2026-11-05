import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/nav.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'otp_code_boxes.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_ref.dart';

/// E-posta doğrulama alt sayfası (kota aşımında doğrulaması ertelenen hesap): 6 kutulu kod + yeniden gönder.
/// Kimlik doğrulamalı uçları kullanır (`/auth/verification/resend|verify`); kayıt akışındaki [VerifyCodePage] gibi
/// e-posta/şifre istemez, çünkü kullanıcı zaten oturum açıktır. Doğrulanınca `true` döner ve "E-postanız doğrulandı"
/// bildirimi gösterilir. Her yerden açılabilir (Profil kartı, kısıtlı işlem bildirimi).
Future<bool> showVerifyEmailSheet(BuildContext context, Session session) async {
  final l = context.l10n;
  final ok = await BuSheet.show<bool>(
    context,
    title: l.verifySheetTitle,
    subtitle: l.verifySheetBody,
    builder: (_) => VerifyEmailSheetBody(session: session),
  );
  if (ok == true) {
    // Doğrulanınca çağıran (Profil kartı) kapanıp ağaçtan çıkabilir: bildirim kök gezginin bağlamından gösterilir.
    final ctx = context.mounted ? context : rootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) BuToast.show(ctx, l.verifyDone, kind: BuToastKind.success);
  }
  return ok == true;
}

/// 403 EMAIL_VERIFICATION_REQUIRED için tek yerden yönlendirme: "Bu işlem için e-postanızı doğrulayın" bildirimi +
/// "Doğrula" eylemi doğrulama sayfasını açar. Butonlar önceden kapatılmaz; sunucu tek doğruluk kaynağıdır.
abstract final class VerifyPrompt {
  static Timer? _debounce;
  static DateTime? _last;

  /// Üst üste gelen reddler (aynı ekranda birkaç istek) tek bildirim gösterir.
  static const _quiet = Duration(seconds: 4);

  /// Çağıran kodun kendi hata bildirimini (aynı mesaj, eylemsiz) ezmesi için kısa gecikmeyle gösterilir.
  static const _delay = Duration(milliseconds: 120);

  static void show(Session session) {
    final now = DateTime.now();
    final last = _last;
    if (last != null && now.difference(last) < _quiet) return;
    _last = now;
    _debounce?.cancel();
    _debounce = Timer(_delay, () {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      final l = ctx.l10n;
      BuToast.show(
        ctx,
        l.errEmailVerificationRequired,
        kind: BuToastKind.warning,
        actionLabel: l.authVerify,
        duration: const Duration(seconds: 6),
        onAction: () {
          final c = rootNavigatorKey.currentContext;
          if (c != null && c.mounted) unawaited(showVerifyEmailSheet(c, session));
        },
      );
    });
  }

  /// Testler: gecikme/sessiz pencere durumunu sıfırlar.
  static void resetForTest() {
    _debounce?.cancel();
    _debounce = null;
    _last = null;
  }
}

class VerifyEmailSheetBody extends StatefulWidget {
  const VerifyEmailSheetBody({super.key, required this.session});

  final Session session;

  @override
  State<VerifyEmailSheetBody> createState() => _VerifyEmailSheetBodyState();
}

class _VerifyEmailSheetBodyState extends State<VerifyEmailSheetBody> {
  final _code = TextEditingController();
  final _resendKey = GlobalKey<AuthResendRowState>();
  bool _busy = false;
  bool _ok = false;
  String? _error;
  String? _info;

  /// Sunucu sürekli gönderim kotasında 429 MAIL_QUOTA_EXCEEDED döndü: bilgi notu (kod girişi yine açık).
  bool _quota = false;
  int _shake = 0;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _fail(String m) {
    authHaptic(AuthHaptic.error);
    setState(() {
      _error = m;
      _info = null;
      _shake++;
    });
  }

  Future<void> _verify() async {
    if (_busy || _ok) return;
    if (_code.text.length != 6) {
      _fail(context.l10n.authRestEnterCode);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.session.verifyVerification(_code.text);
      if (!mounted) return;
      setState(() => _ok = true);
      authHaptic(AuthHaptic.success);
      if (!BuMotion.reduced(context)) await Future<void>.delayed(const Duration(milliseconds: 260));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _fail(errorText(e));
      if (e is ApiError && e.code == 'TOO_MANY_ATTEMPTS') {
        _code.clear();
        _resendKey.currentState?.makeReady();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _info = null;
      _quota = false;
    });
    try {
      await widget.session.resendVerification();
      if (!mounted) return;
      setState(() => _info = context.l10n.authNewCodeSent);
      _resendKey.currentState?.restart();
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'EMAIL_ALREADY_VERIFIED') {
        // Başka yoldan (yönetici/başka cihaz) doğrulanmış: durum güncellenir, sayfa başarıyla kapanır.
        widget.session.noteEmailVerified(true);
        widget.session.api.invalidate('/users/me');
        Navigator.of(context).pop(true);
      } else if (e.code == 'MAIL_QUOTA_EXCEEDED' || e.code == 'MAIL_QUOTA_EXHAUSTED') {
        // Hata değil bilgi: iş sunucuda sıraya alınır, kod daha sonra otomatik gönderilir; kod girişi açık kalır.
        setState(() => _quota = true);
        _resendKey.currentState?.restart();
      } else {
        _fail(errorText(e));
        if (e.code == 'RESEND_COOLDOWN') _resendKey.currentState?.restart(e.retryAfter != null && e.retryAfter! > 0 && e.retryAfter! <= 600 ? e.retryAfter : null);
      }
    } catch (e) {
      if (mounted) _fail(errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        OtpCodeBoxes(
          controller: _code,
          enabled: !_busy && !_ok,
          hasError: _error != null,
          success: _ok,
          shakeTrigger: _shake,
          onCompleted: _verify,
        ),
        AnimatedSize(
          duration: BuMotion.of(context, BuMotion.short),
          alignment: Alignment.topCenter,
          child: _error != null
              ? Padding(padding: const EdgeInsets.only(top: 12), child: RefPill(_error!, key: ValueKey('e$_error')))
              : _info != null
                  ? Padding(padding: const EdgeInsets.only(top: 12), child: RefPill(_info!, tone: RefTone.success))
                  : const SizedBox(width: double.infinity),
        ),
        if (_quota)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              key: const ValueKey('verify-quota-info'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: t.warnSoft, borderRadius: BorderRadius.circular(12)),
              child: Semantics(
                liveRegion: true,
                child: Text(l.verifyQuotaInfo, style: tx.bodyMedium!.copyWith(color: t.onWarnSoft, height: 1.4)),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AuthResendRow(
            key: _resendKey,
            startReady: true,
            onResend: _resend,
            waitingLabel: (s) => l.authResendInTime('${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'),
            resendLabel: l.authResendCode,
          ),
        ),
        const SizedBox(height: 12),
        BuButton(label: l.authVerify, busy: _busy, onPressed: _verify),
        const SizedBox(height: 8),
      ],
    );
  }
}
