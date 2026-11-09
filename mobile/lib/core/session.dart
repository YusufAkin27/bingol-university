import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../l10n/app_localizations.dart';
import 'accounts/account_store.dart';
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

/// [Session.switchAccount] sonucu.
enum SwitchResult { switched, same, needsLogin, busy }

/// Oturumun neden zorla kapandığı.
enum SignOutReason { expired, replaced, blocked }

/// Tek cihaz kuralı: sunucunun mobil istemci işareti (her girişte gönderilir).
const kClientMobile = 'mobile';

/// Oturum durumu + kimlik uçları. Token'lar Keychain/Keystore'da tutulur.
class Session extends ChangeNotifier {
  Session(this.api, {AccountStore? accounts}) : accounts = accounts ?? AccountStore() {
    api.onTokensChanged = _persist;
    api.onSessionExpired = () => forceSignOut(force: true);
    avatarUrl.addListener(_onAvatarChanged);
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

  /// Cihazdaki hesaplar (en çok [AccountStore.maxAccounts]); belirteçler güvenli depoda hesap başına ayrı durur.
  final AccountStore accounts;

  /// Her hesap geçişinde/girişinde artar: kabuk alt ağacı bu değerle anahtarlanır (önceki hesabın durumu kalmaz).
  int accountEpoch = 0;
  bool _switching = false;
  int? _previousId;

  /// Hesap geçişi sürüyor (süresi dolma işleyicisi bu sırada sessizdir).
  bool get switching => _switching;

  /// Etkin hesap yerine başka hesaba otomatik geçildiğinde (oturum süresi doldu) süresi dolan hesabın adı; kabuk bir kez gösterir.
  final accountNotice = ValueNotifier<String?>(null);

  /// Yalnız bu süreçte, bellekte: oturum süresi dolan hesabın tam e-postası (giriş ekranını önceden doldurmak için).
  final Map<int, String> _knownEmails = {};
  String? knownEmailOf(int id) => _knownEmails[id];

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

  /// Sınıf/bölüm değişince artar: resmi ders programı sunucuda yeni profile göre yenilenir; ders programı, sınav,
  /// akademik merkez ve ana sayfa bunu dinleyip kendiliğinden yeniden yükler (bkz. `notifyAcademicProfileChanged`).
  final academicRevision = ValueNotifier<int>(0);

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

  /// Hesapta kullanılabilir parola var mı (`GET /auth/me` `hasPassword`)? Yalnız Google/Apple ile açılan hesapta false:
  /// hesap silme, hesap bağlama ve 2FA kapatma parola yerine sağlayıcı yeniden doğrulaması ister. Null: bilinmiyor
  /// (eski sunucu ya da `/auth/me` henüz gelmedi) = parola varmış gibi davranılır.
  bool? hasPassword;
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
      await accounts.load();
      final r = await Future.wait([
        _storage.read(key: 'access'),
        _storage.read(key: 'refresh'),
        _storage.read(key: _signedOutKey),
      ]);
      var a = r[0], rf = r[1];
      if (a == null || rf == null) {
        // Etkin belirteç anahtarı yoksa (örn. hesap geçişi yarıda kaldı) etkin hesabın kayıtlı belirteçleri kullanılır.
        final aid = accounts.activeId;
        final st = aid == null ? null : accounts.tokensOf(aid);
        if (st != null && r[2] != '1') {
          a = st.access;
          rf = st.refresh;
        }
      }
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
        final uid = userId;
        if (uid != null && accounts.has(uid)) {
          displayName ??= accounts.byId(uid)?.displayName;
          unawaited(accounts.updateTokens(uid, Tokens(a, rf)));
          unawaited(accounts.setActive(uid));
        }
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
        await forceSignOut(force: true);
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
      final hp = me['hasPassword'];
      hasPassword = hp is bool ? hp : null;
      final uid = userId;
      if (uid != null && em is String) _knownEmails[uid] = em;
      unawaited(_syncAccount());
    }
  }

  /// Etkin hesabı hesap listesine yazar/günceller (eski sürümden gelen tek oturum da burada listeye alınır).
  Future<void> _syncAccount() async {
    final t = api.tokens, id = userId;
    if (_switching || t == null || id == null) return;
    try {
      if (!accounts.has(id)) {
        await accounts.upsert(id, t, displayName: displayName, email: email);
      } else {
        await accounts.updateProfile(id, displayName: displayName, email: email);
      }
      await accounts.setActive(id);
    } on AccountLimitException {
      // Liste dolu: bu hesap yalnız etkin oturum olarak çalışır.
    } catch (_) {
      // Bilerek yutulur: en iyi çaba.
    }
  }

  /// `GET /users/me` yanıtından hesap satırının kullanıcı adı/avatar bilgisini tazeler (profil sekmesi çağırır).
  void noteMyProfile(Map<dynamic, dynamic> p) {
    final id = userId;
    if (id == null || _switching || !accounts.has(id)) return;
    String? s(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
    unawaited(accounts.updateProfile(id, displayName: s(p['displayName']), username: s(p['username']), avatarUrl: s(p['avatarUrl'])));
  }

  void _onAvatarChanged() {
    final id = userId, v = avatarUrl.value;
    if (id == null || v == null || _switching) return;
    unawaited(accounts.updateProfile(id, avatarUrl: v));
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
            await forceSignOut(force: true);
            return;
          }
          if (e.code == 'SESSION_REPLACED' || e.code == 'SESSION_CHANGED') return;
        } catch (_) {
          // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
        }
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
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
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

  /// Etkin hesaba ait yerel alanlar sıfırlanır (hesap değişiminde bir sonraki hesaba sızmasın).
  void _resetFields() {
    badges.reset();
    legal.reset();
    userId = null;
    displayName = null;
    email = null;
    hasPassword = null;
    avatarUrl.value = null;
    emailUnverified.value = false;
    profileCompletedHint = null;
  }

  /// Sunucu oturumu zaten bitirdi (örn. başka cihazda giriş): sunucuya hiçbir istek atmadan yerel oturumu
  /// kapatır. Etkin hesap listede "oturum süresi doldu" olarak kalır; geçilebilecek başka hesap varsa ona geçilir
  /// (önce geçişten önceki hesap), yoksa giriş ekranına dönülür. Eşzamanlı çağrılarda tek sefer çalışır;
  /// oturum yoksa (çıkış yapılmış) yok sayılır. [force]: durum signedOut iken de (giriş sırasında `/auth/me` reddi) çalışır.
  Future<void> forceSignOut({SignOutReason reason = SignOutReason.expired, bool force = false}) async {
    if (_forcing || _switching) return;
    if (!force && state == SessionState.signedOut) return;
    if (state == SessionState.loading && api.tokens == null) return;
    _forcing = true;
    try {
      final id = userId ?? jwtSubjectId(api.tokens?.access ?? '');
      final dead = id == null ? null : accounts.byId(id);
      if (id != null && reason != SignOutReason.blocked) {
        final em = email;
        if (em != null) _knownEmails[id] = em;
      }
      // Eşzamanlı kısım: sonraki istekler token taşımasın, gerçek zamanlı yeniden bağlanmasın.
      api.tokens = null;
      try {
        realtime?.stop();
      } catch (_) {
        // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
      }
      Analytics.instance.discard();
      if (id != null) {
        if (reason == SignOutReason.blocked) {
          await accounts.setActive(null); // cihaz engeli: hesap listede kalır, açılışta otomatik açılmaz
        } else {
          await accounts.markExpired(id);
        }
      }
      final next = reason == SignOutReason.blocked ? null : accounts.nextSwitchable(except: id, prefer: _previousId);
      if (next != null) {
        _switching = true;
        _set(SessionState.loading);
        await api.setTokens(null);
        _resetFields();
        await _enter(next.userId, accounts.tokensOf(next.userId)!);
        _switching = false;
        accountNotice.value = dead?.displayName ?? dead?.username ?? '';
        rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
        return;
      }
      if (reason == SignOutReason.replaced) replacedNotice.value = true;
      await api.setTokens(null);
      _resetFields();
      _set(SessionState.signedOut); // push yerel temizliği kancadan (token yok: sunucu çağrısı atlanır)
      rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    } finally {
      _forcing = false;
      _switching = false;
    }
  }

  /// Yalnız ETKİN hesabı çıkarır: sunucuda o hesabın oturumu kapanır, yerel verisi temizlenir, listeden silinir.
  /// Cihazda geçilebilecek başka hesap varsa ona geçilir ([switchToOther]); yoksa giriş ekranına dönülür.
  Future<void> signOut({bool remote = true, bool switchToOther = true}) async {
    if (_forcing || _switching) return;
    final refresh = api.tokens?.refresh;
    final id = userId ?? jwtSubjectId(api.tokens?.access ?? '');
    final fcm = pushToken?.call(); // kancalar jetonu sıfırlamadan önce okunur
    // Önce yerel kancalar (push token silme); token geçerliyken, kısa zaman aşımıyla.
    if (remote) {
      for (final h in List.of(beforeSignOut)) {
        try {
          await h().timeout(const Duration(seconds: 5));
        } catch (_) {
          // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
        }
      }
    }
    try {
      realtime?.stop();
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
    if (remote && refresh != null) {
      try {
        await api.post('/auth/logout', {'refreshToken': refresh, if (fcm != null && fcm.isNotEmpty) 'fcmToken': fcm}, false);
      } catch (_) {
        // Çıkış yerelde her durumda tamamlanır.
      }
    }
    if (id != null) {
      _knownEmails.remove(id);
      await accounts.remove(id);
    }
    final next = switchToOther ? accounts.nextSwitchable(except: id) : null;
    if (next != null) {
      _switching = true;
      try {
        _set(SessionState.loading);
        await api.setTokens(null);
        _resetFields();
        await _enter(next.userId, accounts.tokensOf(next.userId)!);
      } finally {
        _switching = false;
      }
      rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    await accounts.setActive(null);
    await api.setTokens(null);
    _resetFields();
    _set(SessionState.signedOut);
    // Süresi dolan oturum (401, geçersiz refresh) ekranlardan biri açıkken kapanabilir: üstte kalan sayfalar
    // (Ayarlar, Şifre...) giriş ekranını örtmesin. Çağıranların kendi popUntil'i zararsızdır.
    rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  /// "Tüm hesaplardan çık": cihazdaki her hesabın oturumu sunucuda kapatılır (en iyi çaba), liste temizlenir.
  Future<void> signOutAll() async {
    if (_forcing || _switching) return;
    final activeId = userId ?? jwtSubjectId(api.tokens?.access ?? '');
    for (final a in accounts.accounts.toList()) {
      if (a.userId == activeId) continue;
      await _remoteLogout(a.userId);
      await accounts.remove(a.userId);
    }
    _knownEmails.clear();
    await signOut(switchToOther: false);
    await accounts.clear();
  }

  /// Etkin olmayan hesabın sunucu oturumunu kapatır (yalnız yenileme belirteci; ağ hatası yutulur).
  Future<void> _remoteLogout(int id) async {
    final t = accounts.tokensOf(id);
    if (t == null) return;
    try {
      await api.post('/auth/logout', {'refreshToken': t.refresh}, false).timeout(const Duration(seconds: 6));
    } catch (_) {
      // Yerelde her durumda kaldırılır.
    }
  }

  /// "Bu cihazdan kaldır": etkin hesapsa normal çıkış, değilse yalnız o hesabın oturumu kapatılıp listeden silinir.
  Future<void> removeAccount(int id) async {
    if (id == userId) return signOut();
    await _remoteLogout(id);
    _knownEmails.remove(id);
    await accounts.remove(id);
  }

  /// Etkin hesabı yerelde bırakır (sunucuda ÇIKIŞ yapılmaz): push cihaz kaydı eski hesaptan silinir, gerçek zamanlı
  /// bağlantı kapanır, önbellek/yerel kullanıcı verisi temizlenir. Belirteçler hesap deposunda kalır.
  Future<void> _leaveActive() async {
    for (final h in List.of(beforeSignOut)) {
      try {
        await h().timeout(const Duration(seconds: 5));
      } catch (_) {
        // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
      }
    }
    try {
      realtime?.stop();
    } catch (_) {
      // Bilerek yutulur: en iyi çaba.
    }
    Analytics.instance.discard();
    _set(SessionState.loading); // kabuk kaldırılır; yeni hesap temiz bir kabukla açılır
    api.tokens = null; // uçuştaki istekler SESSION_CHANGED alır, yenileme bırakılır
    await api.setTokens(null); // ETag/disk önbelleği, giden kutusu ve tüm kullanıcı verisi temizleyicileri
    _resetFields();
  }

  /// Hesaba girer: belirteçler yazılır, kabuk yeniden kurulur (kancalar: push kaydı yeni hesaba, widget, dil).
  Future<void> _enter(int id, Tokens t) async {
    await api.setTokens(t);
    userId = id;
    displayName = accounts.byId(id)?.displayName;
    email = _knownEmails[id];
    replacedNotice.value = false;
    await accounts.setActive(id);
    accountEpoch++;
    _set(SessionState.signedIn);
    unawaited(_loadMe());
  }

  /// Kayıtlı başka hesaba geçer. Sunucuda çıkış YAPILMAZ. [SwitchResult.needsLogin]: oturumu dolmuş hesap.
  Future<SwitchResult> switchAccount(int id) async {
    if (_switching || _forcing) return SwitchResult.busy;
    if (id == userId) return SwitchResult.same;
    final a = accounts.byId(id);
    final t = accounts.tokensOf(id);
    if (a == null || a.expired || t == null) return SwitchResult.needsLogin;
    if (api.tokens == null) return SwitchResult.busy;
    _switching = true;
    try {
      await _storeActive(); // etkin oturum listede yoksa önce yazılır (kaybolmasın)
      _previousId = userId;
      await _leaveActive();
      await _enter(id, accounts.tokensOf(id) ?? t);
    } finally {
      _switching = false;
    }
    rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    return SwitchResult.switched;
  }

  Future<void> _storeActive() async {
    final t = api.tokens, id = userId;
    if (t == null || id == null || accounts.has(id)) return;
    try {
      await accounts.upsert(id, t, displayName: displayName, email: email);
    } catch (_) {
      // Liste dolu / depo hatası: geçiş yine yapılır.
    }
  }

  Future<void> _accept(dynamic res) async {
    replacedNotice.value = false;
    // Ertelenmiş hesap girişinde yanıt `emailVerified:false, verificationDeferred:true` taşır (normal girişte alan yok).
    noteProfile(res);
    final t = Tokens.fromJson(res);
    final newId = jwtSubjectId(t.access);
    final curTokens = api.tokens;
    final curId = userId ?? (curTokens == null ? null : jwtSubjectId(curTokens.access));
    final name = res is Map && res['displayName'] is String ? res['displayName'] as String : null;
    if (newId != null && !accounts.has(newId) && accounts.isFull) {
      // Cihaz sınırı: açılan sunucu oturumu yetim kalmasın.
      try {
        await api.post('/auth/logout', {'refreshToken': t.refresh}, false);
      } catch (_) {
        // en iyi çaba
      }
      throw ApiError(0, 'ACCOUNT_LIMIT', '');
    }
    if (curTokens != null && curId != null && newId != null && curId != newId) {
      // "Hesap ekle": mevcut hesap çıkış yapılmadan bırakılır, yeni hesaba geçilir.
      if (_switching || _forcing) return;
      _switching = true;
      try {
        await _storeActive();
        _previousId = curId;
        await _leaveActive();
        await accounts.upsert(newId, t, displayName: name);
        await _enter(newId, t);
      } finally {
        _switching = false;
      }
      rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    await api.setTokens(t);
    if (newId != null) {
      userId = newId;
      try {
        await accounts.upsert(newId, t, displayName: name ?? displayName);
        await accounts.setActive(newId);
      } on AccountLimitException {
        // yukarıda elenir
      }
    }
    await _loadMe();
    // Giriş ekranından itilmiş rotalar (e-posta girişi, kayıt, kod adımları) kapanır: kök ana sayfaya/kapıya geçer.
    rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  // Tembel: kurucu anında Future üretilmez (testlerde FakeAsync bölgesi ile runAsync bölgesi karışmasın).
  Future<void>? _persistChain;

  /// Belirteç yazma/silme işlemleri TEK sıraya dizilir: çıkıştaki silme, kendinden önce başlamış bir yenileme
  /// yazmasının ardından çalışır (sıra bozulup çıkış yapılmış oturumun diske geri yazılması olmaz).
  Future<void> _persist(Tokens? t) {
    if (t != null) {
      // Yenilenen belirteç çifti hesap deposuna da yansır (hesap geçişinde güncel çift kullanılır).
      final id = jwtSubjectId(t.access);
      if (id != null && accounts.has(id)) unawaited(accounts.updateTokens(id, t));
    }
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
            } catch (_) {
              // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
            }
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
      } catch (_) {
        // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
      }
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
    case 'ACCOUNT_LIMIT':
      return l.accLimit;
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
