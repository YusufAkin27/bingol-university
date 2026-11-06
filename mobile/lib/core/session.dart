import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../l10n/app_localizations.dart';
import 'analytics.dart';
import 'api.dart';
import 'badges.dart';
import 'identifier.dart';
import 'locale_controller.dart';
import 'nav.dart';
import 'pending_verification.dart';
import 'two_factor.dart';
import 'oauth/oauth_services.dart';
import '../features/auth/data/onboarding_api.dart' show OnboardingDraftStore;
import '../features/auth/verify_email_sheet.dart' show VerifyPrompt;
import '../features/legal/legal_reaccept.dart';
import 'realtime/chat_realtime.dart';
import 'secure_store.dart';

enum SessionState { loading, signedOut, signedIn }

/// Oturumun neden zorla kapandığı.
enum SignOutReason { expired, replaced, blocked }

/// Tek cihaz kuralı: sunucunun mobil istemci işareti (her girişte gönderilir).
const kClientMobile = 'mobile';

/// Oturum durumu + kimlik uçları. Token'lar Keychain/Keystore'da tutulur.
class Session extends ChangeNotifier {
  Session(this.api) {
    api.onTokensChanged = _persist;
    api.onSessionExpired = () => signOut(remote: false);
    api.onSessionReplaced = () => forceSignOut(reason: SignOutReason.replaced);
    api.onAccessBlocked = _onAccessBlocked;
    legal = LegalReacceptController(api);
    api.onLegalReaccept = legal.onRequired;
    api.onEmailVerificationRequired = _onVerificationRequired;
    api.onProfileIncomplete = _onProfileIncomplete;
    api.onRealEmailRequired = _onRealEmailRequired;
    realtime = ChatRealtime(this);
  }

  final ApiClient api;

  /// Sözleşme yeniden onayı (acceptance-status + 403 LEGAL_REACCEPT_REQUIRED): kabuk bu durumu dinler.
  late final LegalReacceptController legal;

  /// Alt gezinme/üst çan rozetleri; sayfalar okuyunca değerini düşürür.
  final badges = AppBadges();

  /// Kabuğun başlattığı tek sohbet gerçek zamanlı bağlantısı (ekranlar `session.realtime` ile erişir).
  ChatRealtime? realtime;

  /// E-posta doğrulanmamış hesap (günlük posta kotası aşılınca kayıt doğrulaması ertelenir). Yalnız sunucudan gelen
  /// bilgiyle değişir (kayıt yanıtı, `GET /users/me`, doğrulama, 403 EMAIL_VERIFICATION_REQUIRED); varsayılan false:
  /// doğrulanmış kullanıcıda arayüzde iz yoktur.
  final emailUnverified = ValueNotifier<bool>(false);

  /// Sunucunun söylediği doğrulama durumunu işler; alan yoksa (eski sunucu) durum değişmez.
  void noteEmailVerified(Object? verified) {
    if (verified is bool && emailUnverified.value == verified) emailUnverified.value = !verified;
  }

  /// Profil (`GET /users/me`) ve giriş/kayıt yanıtlarından doğrulama durumunu alır. Sözleşme: kart yalnız
  /// `emailVerified==false && verificationDeferred==true` iken; ertelenmiş değil ama doğrulanmamış hesap sisteme
  /// zaten giremez (girişte 403 EMAIL_NOT_VERIFIED). `verificationDeferred` alanı hiç yoksa ertelenmiş sayılır.
  void noteProfile(Object? profile) {
    if (profile is! Map) return;
    final v = profile['emailVerified'];
    if (v is! bool) return;
    noteEmailVerified(v || profile['verificationDeferred'] == false ? true : false);
  }

  void _onVerificationRequired() {
    emailUnverified.value = true;
    VerifyPrompt.show(this);
  }

  /// OAuth (Google/Apple) girişinden gelen "profil tamam mı" bilgisi; `GET /users/me` yanıtında `profileCompleted`
  /// alanı yoksa kapı bunu kullanır. Çıkışta silinir. Null: bilinmiyor (eski sunucu = tamamlanmış sayılır).
  bool? profileCompletedHint;

  /// 403 `PROFILE_INCOMPLETE` sayacı: her yakalamada artar; profil kapısı ([ProfileCompletionGate]) dinler ve
  /// kabuk yerine "Profilini tamamla" akışını gösterir. Normal akışa erişim profil tamamlanmadan açılmaz.
  final profileIncompleteSignal = ValueNotifier<int>(0);

  void _onProfileIncomplete() {
    profileCompletedHint = false;
    profileIncompleteSignal.value++;
  }

  /// 403 `REAL_EMAIL_REQUIRED` sayacı: yeni Apple gizli-adresli hesap gerçek e-postasını doğrulamadan yazmayı denedi.
  /// Profil kapısı ([ProfileCompletionGate]) dinler ve kabuk yerine zorunlu "Gerçek e-posta adresiniz" adımını gösterir.
  final realEmailRequiredSignal = ValueNotifier<int>(0);

  void _onRealEmailRequired() => realEmailRequiredSignal.value++;

  /// Gerçek e-posta doğrulandı: hesabın tek e-postası artık [newEmail] (karşılama/profil ekranları tazelenir).
  void realEmailVerified(String newEmail) {
    email = newEmail;
    emailUnverified.value = false;
    notifyListeners();
  }

  /// Sunucuda kapalı (404 `OAUTH_DISABLED`) sağlayıcılar: bu uygulama oturumu boyunca düğmeler gizlenir.
  final oauthDisabled = ValueNotifier<Set<OAuthProvider>>(const {});

  void disableOAuth(OAuthProvider p) {
    if (oauthDisabled.value.contains(p)) return;
    oauthDisabled.value = {...oauthDisabled.value, p};
  }

  /// Çıkışta (token hâlâ geçerliyken) çalışır: örn. FCM cihaz kaydını silme. Hatalar yutulur.
  final List<Future<void> Function()> beforeSignOut = [];

  /// Bu cihazın FCM jetonu (PushService bağlar). Çıkış isteğine eklenir: erişim jetonu süresi dolmuş olsa bile
  /// sunucu cihaz kaydını siler ve çıkış yapan kullanıcının bildirimi telefonda kalmaz.
  String? Function()? pushToken;
  final FlutterSecureStorage _storage = kDeviceSecureStorage;

  /// Başka cihazda giriş yapıldı bilgisi: giriş ekranında bir kez gösterilir, kapatılınca silinir.
  final replacedNotice = ValueNotifier<bool>(false);
  bool _forcing = false;

  /// 403 ACCESS_BLOCKED: cihaz/ağ engeli. Ana uygulama bu bayrakla engel ekranını gösterir.
  final accessBlocked = ValueNotifier<bool>(false);

  void _onAccessBlocked() {
    accessBlocked.value = true;
    // Oturum varsa sunucuya hiçbir istek atmadan yerel olarak kapatılır (refresh/logout denenmez).
    forceSignOut(reason: SignOutReason.blocked);
  }

  /// Engel ekranından "tekrar dene": bayrağı kaldırır, giriş ekranına dönülür.
  void dismissAccessBlocked() => accessBlocked.value = false;

  /// Doğrulaması bekleyen kayıt (şifresiz, 72 sa). Testler bellek içi depo atar.
  PendingVerificationStore pending = PendingVerificationStore();

  // Kayıt/girişte girilen şifre yalnızca bellekte, doğrulama sonrası otomatik giriş için tutulur.
  String? _memId, _memPassword;
  void rememberCredentials(String identifier, String password) {
    _memId = normalizeIdentifier(identifier);
    _memPassword = password;
  }

  SessionState state = SessionState.loading;
  int? userId;
  String? displayName;
  String? email;

  /// Kullanıcının kendi profil fotoğrafı (alt gezinmedeki Profil sekmesi avatarı). Kabuk açılışta, profil sekmesi
  /// ve profil düzenleme fotoğraf değişince günceller; çıkışta temizlenir. Null: fotoğraf yok (varsayılan görsel).
  final avatarUrl = ValueNotifier<String?>(null);

  /// Çıkışta belirteçler silinemediyse bırakılan işaret (bkz. [_persistNow]): sonraki açılışta oturum AÇILMAZ.
  static const _signedOutKey = 'signed_out';
  bool _signedOutMarker = false;

  /// Açılışta kayıtlı oturumu yükler. Belirteç varsa kabuk HEMEN açılır (state signedIn); `/auth/me` arka planda
  /// yenilenir ve oturum yalnız KESİN yetki reddinde (401, geçersiz refresh, askı) kapanır. Böylece kötü ağda
  /// splash `/auth/me` yanıtını beklemez.
  Future<void> restore() async {
    try {
      final r = await Future.wait([
        _storage.read(key: 'access'),
        _storage.read(key: 'refresh'),
        _storage.read(key: _signedOutKey),
      ]);
      final a = r[0], rf = r[1];
      if (r[2] == '1') {
        // Önceki çıkışta silme başarısız olmuştu: belirteçleri bir kez daha silmeyi dene, oturumsuz başla.
        _signedOutMarker = true;
        await _persistNow(null);
        _set(SessionState.signedOut);
        return;
      }
      if (a != null && rf != null) {
        api.tokens = Tokens(a, rf);
        userId ??= jwtSubjectId(a); // çevrimdışı açılışta /auth/me gelmese de sohbet kendi mesajlarını doğru çizer
        _set(SessionState.signedIn);
        unawaited(_loadMe());
        return;
      }
    } catch (_) {
      // Depo okunamazsa oturumsuz başla.
    }
    _set(SessionState.signedOut);
  }

  /// Geçici hatada (ağ, 5xx, 429, 408) `/auth/me` yeniden denemeleri arasındaki bekleme.
  /// Testler kısaltabilir.
  @visibleForTesting
  List<Duration> meRetryDelays = const [Duration(seconds: 3), Duration(seconds: 10), Duration(seconds: 30)];
  bool _meRetrying = false;

  Future<void> _loadMe() async {
    try {
      await _fetchMe();
      _set(SessionState.signedIn);
    } on ApiError catch (e) {
      if (e.code == 'SESSION_REPLACED' || e.code == 'SESSION_CHANGED') {
        // forceSignOut zaten başlatıldı (bilgi bandıyla giriş ekranına düşer) ya da oturum bu arada kapandı/değişti:
        // eski oturumun yanıtı durumu geri "açık" yapmasın.
        return;
      }
      if (e.isAuthRejected) {
        // Yalnız kesin yetki reddi (401, geçersiz/kullanılmış refresh, askı) oturumu bitirir.
        await signOut(remote: false);
        return;
      }
      // Ağ yok, 5xx, 429, 408 ya da beklenmeyen yanıt: oturum (token'lar) KORUNUR, çevrimdışı modda
      // açılır; kullanıcı bilgisi arka planda kısa gecikmeyle yeniden denenir.
      _set(SessionState.signedIn);
      unawaited(_retryMe());
    }
  }

  Future<void> _fetchMe() async {
    final me = await api.get('/auth/me');
    noteProfile(me);
    if (me is Map) {
      final id = me['id'];
      final dn = me['displayName'];
      final em = me['email'];
      userId = id is num ? id.toInt() : null;
      displayName = dn is String ? dn : null;
      email = em is String ? em : null;
    }
  }

  Future<void> _retryMe() async {
    if (_meRetrying) return;
    _meRetrying = true;
    try {
      for (final d in meRetryDelays) {
        await Future<void>.delayed(d);
        if (state != SessionState.signedIn || api.tokens == null) return;
        try {
          await _fetchMe();
          notifyListeners();
          return;
        } on ApiError catch (e) {
          if (e.isAuthRejected) {
            await signOut(remote: false);
            return;
          }
          if (e.code == 'SESSION_REPLACED' || e.code == 'SESSION_CHANGED') return;
        } catch (_) {}
      }
    } finally {
      _meRetrying = false;
    }
  }

  /// Profil düzenlendikten sonra karşılama adını tazeler.
  Future<void> refreshName() async {
    try {
      final me = await api.get('/auth/me');
      if (me is! Map) return;
      final dn = me['displayName'];
      displayName = dn is String ? dn : displayName;
      notifyListeners();
    } catch (_) {}
  }

  /// Giriş. Normal akışta oturum açılır ve null döner. Hesapta iki faktörlü doğrulama açık ve cihaz tanınmıyorsa
  /// sunucu 202 + `twoFactorRequired:true` + `challengeToken` döner (token YOK, kod e-postaya gitti): oturum açılmaz,
  /// [TwoFactorChallenge] döner ve çağıran kod adımını gösterip [loginTwoFactor] ile tamamlar.
  Future<TwoFactorChallenge?> login(String email, String password) async {
    final res = await api.post('/auth/login', {'email': normalizeIdentifier(email), 'password': password, 'client': kClientMobile}, false);
    final challenge = TwoFactorChallenge.tryParse(res);
    if (challenge != null) return challenge;
    await _accept(res);
    return null;
  }

  /// Giriş ikinci adımı: e-postadaki kod. `trustDevice` açıkça gönderilir (sunucu varsayılanı false; arayüzde de
  /// varsayılan kapalı). Başarıda normal girişle aynı şekilde oturum açılır; challenge tek kullanımlıktır.
  Future<void> loginTwoFactor(TwoFactorChallenge challenge, String code, {bool trustDevice = false}) async {
    final res = await api.post(
      '/auth/login/2fa',
      {'challengeToken': challenge.token, 'code': code.trim(), 'trustDevice': trustDevice},
      false,
    );
    await _accept(res);
  }

  /// Aynı challenge için yeni kod (en çok 3 / 10 dk). Dönen değer: challenge'ın kalan ömrü (sn); yoksa varsayılan.
  Future<int> resendTwoFactor(TwoFactorChallenge challenge) async {
    final res = await api.post('/auth/login/2fa/resend', {'challengeToken': challenge.token}, false);
    final ttl = res is Map ? res['expiresInSeconds'] : null;
    return ttl is num && ttl > 0 ? ttl.toInt() : challenge.expiresInSeconds;
  }

  /// Google ile giriş/kayıt: `POST /auth/oauth/google`. Sonuç [OAuthLoginResult]; iki faktörlü hesapta oturum AÇILMAZ ve
  /// [OAuthLoginResult.challenge] ile mevcut kod adımı ([loginTwoFactor]) kullanılır. Hatalar [ApiError]:
  /// 400 `OAUTH_TOKEN_INVALID`/`OAUTH_EMAIL_MISSING`, 403 `OAUTH_EMAIL_UNVERIFIED`, 409 `OAUTH_LINK_REQUIRED`,
  /// 404 `OAUTH_DISABLED`, 429.
  Future<OAuthLoginResult> loginWithGoogle(GoogleCredential c) =>
      _oauthLogin('/auth/oauth/google', {'idToken': c.idToken}, fallbackName: c.displayName);

  /// Apple ile giriş/kayıt: `POST /auth/oauth/apple`. Apple yalnız ilk yetkilendirmede ad/soyad verir: istek başarısız
  /// olsa bile güvenli yerel depoya yazılır (onboarding ön doldurması) ve istekle birlikte sunucuya da gider.
  Future<OAuthLoginResult> loginWithApple(AppleCredential c) async {
    await OnboardingDraftStore.savePrefill(firstName: c.firstName, lastName: c.lastName);
    final f = c.firstName?.trim() ?? '', l = c.lastName?.trim() ?? '';
    return _oauthLogin('/auth/oauth/apple', {
      'identityToken': c.identityToken,
      'nonce': c.nonce, // HAM nonce (Apple'a SHA-256 özeti verilmişti)
      if (f.isNotEmpty) 'firstName': f,
      if (l.isNotEmpty) 'lastName': l,
    });
  }

  Future<OAuthLoginResult> _oauthLogin(String path, Map<String, Object?> body, {String? fallbackName}) async {
    final res = await api.post(path, {...body, 'client': kClientMobile}, false);
    final challenge = TwoFactorChallenge.tryParse(res);
    if (challenge != null) return OAuthLoginResult(challenge: challenge);
    final map = res is Map ? res : const {};
    final completed = map['profileCompleted'] is bool ? map['profileCompleted'] as bool : null;
    profileCompletedHint = completed;
    if (completed != true) await _savePrefillFrom(map, fallbackName);
    await _accept(res);
    if (completed == true) unawaited(OnboardingDraftStore.clear());
    return OAuthLoginResult(profileCompleted: completed, isNewUser: map['isNewUser'] == true);
  }

  /// Sunucu yanıtındaki profil alanlarından (Google) ad/soyadı onboarding ön doldurmasına yazar.
  Future<void> _savePrefillFrom(Map<dynamic, dynamic> res, String? fallbackName) async {
    String? str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
    for (final m in [res, if (res['user'] is Map) res['user'] as Map, if (res['profile'] is Map) res['profile'] as Map]) {
      final f = str(m['firstName']), l = str(m['lastName']);
      if (f != null || l != null) return OnboardingDraftStore.savePrefill(firstName: f, lastName: l);
    }
    final full = str(res['displayName']) ?? str((res['user'] is Map ? (res['user'] as Map)['displayName'] : null)) ?? str(fallbackName);
    if (full == null) return;
    final at = full.lastIndexOf(' ');
    await OnboardingDraftStore.savePrefill(
      firstName: at < 0 ? full : full.substring(0, at),
      lastName: at < 0 ? '' : full.substring(at + 1),
    );
  }

  /// Tam e-postayı döndürür (sunucu yanıtındaki ya da numaradan türetilen). Doğrulaması ertelenen kayıtta
  /// ([registerAccount] `deferred`) jetonlar da kabul edilir; bkz. [registerAccount].
  Future<String> register({
    required String email,
    required String password,
    String? displayName,
    String? faculty,
    String? department,
    String? grade,
  }) async =>
      (await registerAccount(
        email: email,
        password: password,
        displayName: displayName,
        faculty: faculty,
        department: department,
        grade: grade,
        autoSignIn: false,
      ))
          .email;

  /// Kayıt. Normal akış 202 (doğrulama kodu e-postayla gider). Günlük posta kotası aşılmışsa sunucu 201 + jetonlar +
  /// `verificationDeferred:true` döner: hesap doğrulanmamış kalır ama kullanıcı sisteme alınır. `autoSignIn` açıksa
  /// jetonlar kabul edilir (oturum açılır, [emailUnverified] true olur); kapalıysa yalnız sonuç döner.
  Future<RegisterResult> registerAccount({
    required String email,
    required String password,
    String? displayName,
    String? faculty,
    String? department,
    String? grade,
    bool autoSignIn = true,
  }) async {
    final res = await api.post(
      '/auth/register',
      {
        'email': normalizeIdentifier(email),
        'password': password,
        // Kayıt yalnız numara + şifre ile yapılır; ad/bölüm/sınıf doğrulamadan sonra profil tamamlamada alınır.
        if (displayName != null && displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
        'acceptTerms': true,
        'language': api.lang,
        'client': kClientMobile, // ertelenmiş doğrulamada dönen jetonların etiketi (verify-email ile aynı)
        if (faculty != null && faculty.isNotEmpty) 'faculty': faculty,
        if (department != null && department.isNotEmpty) 'department': department,
        if (grade != null && grade.isNotEmpty) 'grade': grade,
      },
      false,
    );
    final server = res is Map ? res['email'] : null;
    // Kayıtta numara kısayolu yok: yazılan adres olduğu gibi (normalize) kullanılır.
    final full = server is String && server.isNotEmpty ? server : normalizeIdentifier(email);
    final deferred = res is Map && res['verificationDeferred'] == true && res['accessToken'] != null;
    if (deferred && autoSignIn) {
      emailUnverified.value = true;
      await pending.clear();
      await _accept(res);
    }
    return RegisterResult(full, deferred: deferred);
  }

  /// Kimlik doğrulamalı kod yeniden gönderimi (ertelenen doğrulama). Kota doluysa 429 MAIL_QUOTA_EXCEEDED fırlatır.
  Future<void> resendVerification() => api.post('/auth/verification/resend');

  /// Kimlik doğrulamalı kod doğrulama; başarıda [emailUnverified] kalkar ve profil önbelleği bayatlar.
  Future<void> verifyVerification(String code) async {
    await api.post('/auth/verification/verify', {'code': code.trim()});
    emailUnverified.value = false;
    api.invalidate('/users/me');
  }

  Future<void> resendCode(String email) =>
      api.post('/auth/resend-code', {'email': normalizeIdentifier(email)}, false);

  /// Kayıt sırasında girilen şifre bellekte duruyor mu (doğrulama adımı parola kanıtı için)?
  bool hasRememberedPassword(String email) => _memPassword != null && _memId == normalizeIdentifier(email);

  /// `password`: parola kanıtı (sunucu bekleyen kaydın şifre özetiyle karşılaştırır; uyuşmazsa genel
  /// INVALID_CODE). Verilmezse kayıt/girişte bellekte tutulan şifre kullanılır.
  Future<void> verifyEmail(String email, String code, {String? password}) async {
    final remembered = hasRememberedPassword(email) ? _memPassword : null;
    final proof = (password != null && password.isNotEmpty) ? password : remembered;
    final res = await api.post(
      '/auth/verify-email',
      {
        'email': normalizeIdentifier(email),
        'code': code.trim(),
        'client': kClientMobile,
        if (proof != null) 'password': proof,
      },
      false,
    );
    await pending.clear();
    final id = _memId ?? normalizeIdentifier(email);
    _memPassword = null;
    _memId = null;
    if (res is Map && res['accessToken'] != null) {
      await _accept(res);
    } else if (proof != null) {
      await login(id, proof); // sunucu token döndürmediyse bir kez giriş dene
    }
  }

  Future<void> forgotPassword(String email) =>
      api.post('/auth/forgot-password', {'email': normalizeIdentifier(email)}, false);

  /// Kodu doğrular; doğruysa yeni şifre adımı için tek kullanımlık anahtar döner.
  Future<String> verifyResetCode(String email, String code) async {
    final res = await api.post(
      '/auth/verify-reset-code',
      {'email': normalizeIdentifier(email), 'code': code.trim()},
      false,
    );
    final token = res is Map ? res['resetToken'] : null;
    if (token is! String || token.isEmpty) throw ApiError(0, 'BAD_RESPONSE', '');
    return token;
  }

  Future<void> resetPassword(String email, String resetToken, String newPassword) => api.post(
        '/auth/reset-password',
        {'email': normalizeIdentifier(email), 'resetToken': resetToken, 'newPassword': newPassword, 'client': kClientMobile},
        false,
      );

  /// Tüm cihazlardaki oturumları kapatır (POST /auth/logout-all), ardından yerel çıkış yapar.
  /// Sunucu hatasında (ağ dahil) fırlatır ve yerel oturumu KORUR; 401 ise oturum zaten bitmiştir.
  Future<void> logoutAll() async {
    try {
      await api.post('/auth/logout-all');
    } on ApiError catch (e) {
      if (e.status != 401) rethrow;
    }
    await signOut(remote: false);
  }

  /// Bilgi bandını kapatır.
  void dismissReplacedNotice() => replacedNotice.value = false;

  /// Sunucu oturumu zaten bitirdi (örn. başka cihazda giriş): sunucuya hiçbir istek atmadan yerel oturumu
  /// kapatır, rotaları temizleyip giriş ekranına döner. Eşzamanlı çağrılarda tek sefer çalışır;
  /// oturum yoksa (çıkış yapılmış) yok sayılır.
  Future<void> forceSignOut({SignOutReason reason = SignOutReason.expired}) async {
    if (_forcing || state == SessionState.signedOut) return;
    if (state == SessionState.loading && api.tokens == null) return;
    _forcing = true;
    try {
      // Eşzamanlı kısım: sonraki istekler token taşımasın, gerçek zamanlı yeniden bağlanmasın.
      api.tokens = null;
      try {
        realtime?.stop();
      } catch (_) {}
      Analytics.instance.discard();
      if (reason == SignOutReason.replaced) replacedNotice.value = true;
      await api.setTokens(null);
      badges.reset();
      legal.reset();
      userId = null;
      displayName = null;
      email = null;
      avatarUrl.value = null;
      emailUnverified.value = false;
      profileCompletedHint = null;
      _set(SessionState.signedOut); // push yerel temizliği kancadan (token yok: sunucu çağrısı atlanır)
      rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    } finally {
      _forcing = false;
    }
  }

  Future<void> signOut({bool remote = true}) async {
    if (_forcing) return;
    final refresh = api.tokens?.refresh;
    final fcm = pushToken?.call(); // kancalar jetonu sıfırlamadan önce okunur
    // Önce yerel kancalar (push token silme); token geçerliyken, kısa zaman aşımıyla.
    if (remote) {
      for (final h in List.of(beforeSignOut)) {
        try {
          await h().timeout(const Duration(seconds: 5));
        } catch (_) {}
      }
    }
    try {
      realtime?.stop();
    } catch (_) {}
    if (remote && refresh != null) {
      try {
        await api.post('/auth/logout', {'refreshToken': refresh, if (fcm != null && fcm.isNotEmpty) 'fcmToken': fcm}, false);
      } catch (_) {
        // Çıkış yerelde her durumda tamamlanır.
      }
    }
    await api.setTokens(null);
    badges.reset();
    legal.reset();
    userId = null;
    displayName = null;
    email = null;
    avatarUrl.value = null;
    emailUnverified.value = false;
    profileCompletedHint = null;
    _set(SessionState.signedOut);
  }

  Future<void> _accept(dynamic res) async {
    replacedNotice.value = false;
    // Ertelenmiş hesap girişinde yanıt `emailVerified:false, verificationDeferred:true` taşır (normal girişte alan yok).
    noteProfile(res);
    await api.setTokens(Tokens.fromJson(res));
    await _loadMe();
    // Giriş ekranından itilmiş rotalar (e-posta girişi, kayıt, kod adımları) kapanır: kök ana sayfaya/kapıya geçer.
    rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  // Tembel: kurucu anında Future üretilmez (testlerde FakeAsync bölgesi ile runAsync bölgesi karışmasın).
  Future<void>? _persistChain;

  /// Belirteç yazma/silme işlemleri TEK sıraya dizilir: çıkıştaki silme, kendinden önce başlamış bir yenileme
  /// yazmasının ardından çalışır (sıra bozulup çıkış yapılmış oturumun diske geri yazılması olmaz).
  Future<void> _persist(Tokens? t) {
    final prev = _persistChain;
    late Future<void> f;
    // Boştaysa yazma hemen başlar; doluysa öncekinin ardına eklenir.
    f = (prev == null ? _persistNow(t) : prev.then((_) => _persistNow(t))).whenComplete(() {
      if (identical(_persistChain, f)) _persistChain = null;
    });
    return _persistChain = f;
  }

  Future<void> _persistNow(Tokens? t) async {
    if (t == null) {
      // Silme başarısız olursa (Keychain/Keystore geçici hatası) kısa aralıklarla yeniden denenir; yine olmazsa
      // "çıkış yapıldı" işareti bırakılır ve sonraki açılış kayıtlı belirteçle otomatik giriş YAPMAZ.
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await _storage.delete(key: 'access');
          await _storage.delete(key: 'refresh');
          if (_signedOutMarker) {
            try {
              await _storage.delete(key: _signedOutKey);
            } catch (_) {}
            _signedOutMarker = false;
          }
          return;
        } catch (_) {
          if (attempt < 2) await Future<void>.delayed(Duration(milliseconds: 150 * (attempt + 1)));
        }
      }
      try {
        await _storage.write(key: _signedOutKey, value: '1');
        _signedOutMarker = true;
      } catch (_) {}
      return;
    }
    try {
      await _storage.write(key: 'access', value: t.access);
      await _storage.write(key: 'refresh', value: t.refresh);
      if (_signedOutMarker) {
        await _storage.delete(key: _signedOutKey); // yeni giriş: eski çıkış işareti geçersiz
        _signedOutMarker = false;
      }
    } catch (_) {
      // Depo yazılamazsa oturum yalnızca bellekte kalır.
    }
  }

  void _set(SessionState s) {
    state = s;
    notifyListeners();
  }
}

/// [Session.loginWithGoogle] / [Session.loginWithApple] sonucu. [challenge] doluysa oturum AÇILMADI (iki faktörlü
/// hesap): çağıran kod adımını gösterir. Aksi halde oturum açıldı; [profileCompleted] false ise kapı "Profilini
/// tamamla" akışını gösterir (null: sunucu bildirmedi).
class OAuthLoginResult {
  const OAuthLoginResult({this.challenge, this.profileCompleted, this.isNewUser = false});

  final TwoFactorChallenge? challenge;
  final bool? profileCompleted;
  final bool isNewUser;
}

/// [Session.registerAccount] sonucu: tam e-posta + doğrulamanın ertelenip ertelenmediği.
class RegisterResult {
  const RegisterResult(this.email, {this.deferred = false});

  final String email;

  /// Posta kotası aşıldı: hesap açıldı, oturum verildi, e-posta henüz DOĞRULANMADI.
  final bool deferred;
}

/// Hata kodlarına kullanıcı metni: sunucu zaten istek dilinde `message` döner; bilinen kodlar için
/// yerelde (uygulama dilinde) sabit metin kullanılır, böylece mesaj boş/proxy yanıtı olsa da anlaşılır kalır.
String errorText(Object e) {
  // Bağlamsız çağrılar için etkin uygulama dili (yoksa Türkçe).
  final l = lookupAppLocalizations(LocaleController.current?.locale ?? const Locale('tr'));
  if (e is ApiError) {
    if (e.isNetwork) return l.coreErrNetwork;
    final known = knownErrorText(e, l);
    if (known != null) return known;
    if (e.message.isNotEmpty) {
      // 429: sunucu metni süre içermiyorsa Retry-After eklenir.
      if (e.status == 429 && !RegExp(r'\d').hasMatch(e.message)) {
        final h = retryAfterText(e.retryAfter, l);
        if (h != null) return '${e.message} $h';
      }
      return e.message;
    }
    if (e.status == 429) return _withRetry(l.coreErrTooMany, e, l);
  }
  return l.coreErrGeneric;
}

String _withRetry(String text, ApiError e, AppLocalizations l) {
  final h = retryAfterText(e.retryAfter, l);
  return h == null ? text : '$text $h';
}

/// `Retry-After` saniyesini "N sn / N dk sonra tekrar deneyin" metnine çevirir (yoksa/0 ise null).
String? retryAfterText(int? seconds, AppLocalizations l) {
  if (seconds == null || seconds <= 0) return null;
  if (seconds < 90) return l.coreErrRetryAfterSec('$seconds');
  return l.coreErrRetryAfterMin('${(seconds / 60).ceil()}');
}

/// Backend'in sonradan eklenen hata kodları için yerel metin; bilinmiyorsa null.
String? knownErrorText(ApiError e, AppLocalizations l) {
  // Kodsuz 413 (proxy/nginx); kodlu 413'ler (VIDEO_TOO_LARGE, FILE_TOO_LARGE...) kendi sunucu metnini korur.
  if (e.status == 413 && e.code.startsWith('HTTP_')) return l.errPayloadTooLarge;
  switch (e.code) {
    case 'EMAIL_ALIAS_NOT_ALLOWED':
      return l.errEmailAliasNotAllowed;
    case 'PASSWORD_TOO_LONG':
      return l.errPasswordTooLong;
    case 'PAYLOAD_TOO_LARGE':
      return l.errPayloadTooLarge;
    case 'UPLOAD_BUSY':
      return _withRetry(l.errUploadBusy, e, l);
    case 'UPLOAD_QUOTA_EXCEEDED':
      return _withRetry(l.errUploadQuota, e, l);
    case 'MAIL_QUOTA_EXHAUSTED':
    case 'MAIL_QUOTA_EXCEEDED':
      return _withRetry(l.errMailQuota, e, l);
    // İki faktörlü doğrulama (sunucu zaten istek dilinde döner; yerel metin proxy/boş gövde için güvence).
    case 'TWO_FACTOR_CODE_INVALID':
      return l.tfErrCodeInvalid;
    case 'TWO_FACTOR_CHALLENGE_EXPIRED':
      return l.tfErrChallengeExpired;
    case 'TWO_FACTOR_LOCKED':
      return l.tfErrLocked;
    case 'TWO_FACTOR_ALREADY_ENABLED':
      return l.tfErrAlreadyEnabled;
    case 'TWO_FACTOR_NOT_ENABLED':
      return l.tfErrNotEnabled;
    case 'EMAIL_VERIFICATION_REQUIRED':
      return l.errEmailVerificationRequired;
    case 'DB_TIMEOUT':
      return _withRetry(l.errServiceBusy, e, l);
    // Google / Apple ile giriş (sunucu zaten istek dilinde döner; yerel metin proxy/boş gövde için güvence).
    case 'OAUTH_TOKEN_INVALID':
      return l.oaErrTokenInvalid;
    case 'OAUTH_EMAIL_UNVERIFIED':
      return l.oaErrEmailUnverified;
    case 'OAUTH_EMAIL_MISSING':
      return l.oaErrEmailMissing;
    case 'OAUTH_DISABLED':
      return l.oaErrDisabled;
    case 'OAUTH_LAST_LOGIN_METHOD':
      return l.oaErrLastMethod;
    case 'PROFILE_INCOMPLETE':
      return l.oaErrProfileIncomplete;
    case 'LEGAL_REACCEPT_REQUIRED':
      return l.errLegalReaccept;
    case 'CONVERSATION_CLOSED': // P08: yönetici sohbeti kapattı (sebep istemciye gelmez)
      return l.chatClosedBanner;
    case 'CERTIFICATE_REVOKED': // P07: yönetici sertifikayı iptal etti, yeniden alınamaz
      return l.errCertificateRevoked;
    // Tepki: eski sunucu 5 emojilik beyaz liste uygular; yeni sunucu geçersiz emojiyi/farklı emoji sınırını reddeder.
    case 'REACTION_NOT_ALLOWED':
    case 'REACTION_INVALID':
    case 'INVALID_REACTION':
    case 'REACTION_EMOJI_INVALID':
      return l.chatReactionUnsupported;
    case 'REACTION_LIMIT':
    case 'REACTION_LIMIT_REACHED':
    case 'REACTION_TOO_MANY':
    case 'TOO_MANY_REACTIONS':
      return l.chatReactionLimit;
    case 'COMMUNITY_NOT_FOUND': // P06: kulüp kapatıldı (HIDDEN) / silindi
      return l.clubUnavailable;
  }
  return null;
}
