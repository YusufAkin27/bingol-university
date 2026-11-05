import '../../core/api.dart';
import '../../core/oauth/oauth_services.dart';
import '../../core/session.dart';
import '../../core/two_factor.dart';

enum OAuthOutcomeKind {
  /// Kullanıcı sağlayıcı sayfasını kapattı: sessiz dönülür, hata gösterilmez.
  cancelled,

  /// Oturum açıldı (kök ekran ana sayfa ya da "Profilini tamamla" kapısına geçer).
  signedIn,

  /// İki faktörlü hesap: oturum açılmadı, mevcut kod adımı gösterilir.
  twoFactor,

  /// 409 `OAUTH_LINK_REQUIRED`: aynı e-postayla zaten bir hesap var; otomatik birleşme YOK.
  linkRequired,

  /// Sunucuda bu yöntem kapalı (404 `OAUTH_DISABLED`): düğme bu oturum boyunca gizlendi.
  disabled,

  /// Diğer hatalar (ağ yok, geçersiz token, doğrulanmamış e-posta, hız sınırı...).
  failed,
}

class OAuthOutcome {
  const OAuthOutcome(this.kind, {this.challenge, this.provider, this.emailMasked, this.error});

  final OAuthOutcomeKind kind;
  final TwoFactorChallenge? challenge;
  final OAuthProvider? provider;
  final String? emailMasked;
  final Object? error;
}

/// Bir Google/Apple girişini baştan sona yürütür: sağlayıcı sayfası -> sunucu -> sonuç. Hiçbir istisna sızdırmaz.
Future<OAuthOutcome> runOAuthSignIn(Session session, OAuthProvider provider, {OAuthServices? services}) async {
  final svc = services ?? OAuthServices.current;
  try {
    final OAuthLoginResult r;
    switch (provider) {
      case OAuthProvider.google:
        final c = await svc.google.signIn();
        if (c == null) return const OAuthOutcome(OAuthOutcomeKind.cancelled);
        r = await session.loginWithGoogle(c);
      case OAuthProvider.apple:
        final c = await svc.apple.signIn();
        if (c == null) return const OAuthOutcome(OAuthOutcomeKind.cancelled);
        r = await session.loginWithApple(c);
    }
    final ch = r.challenge;
    if (ch != null) return OAuthOutcome(OAuthOutcomeKind.twoFactor, challenge: ch, provider: provider);
    return OAuthOutcome(OAuthOutcomeKind.signedIn, provider: provider);
  } on ApiError catch (e) {
    if (e.status == 409 && e.code == 'OAUTH_LINK_REQUIRED') {
      final m = e.data?['emailMasked'];
      return OAuthOutcome(
        OAuthOutcomeKind.linkRequired,
        provider: OAuthProvider.tryParse(e.data?['provider']) ?? provider,
        emailMasked: m is String && m.isNotEmpty ? m : null,
        error: e,
      );
    }
    if (e.code == 'OAUTH_DISABLED') {
      session.disableOAuth(provider);
      return OAuthOutcome(OAuthOutcomeKind.disabled, provider: provider, error: e);
    }
    return OAuthOutcome(OAuthOutcomeKind.failed, provider: provider, error: e);
  } catch (e) {
    return OAuthOutcome(OAuthOutcomeKind.failed, provider: provider, error: e);
  }
}
