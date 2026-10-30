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
import '../features/legal/legal_reaccept.dart';
import 'realtime/chat_realtime.dart';

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
    realtime = ChatRealtime(this);
  }

  final ApiClient api;

  /// Sözleşme yeniden onayı (acceptance-status + 403 LEGAL_REACCEPT_REQUIRED): kabuk bu durumu dinler.
  late final LegalReacceptController legal;

  /// Alt gezinme/üst çan rozetleri; sayfalar okuyunca değerini düşürür.
  final badges = AppBadges();

  /// Kabuğun başlattığı tek sohbet gerçek zamanlı bağlantısı (ekranlar `session.realtime` ile erişir).
  ChatRealtime? realtime;

  /// Çıkışta (token hâlâ geçerliyken) çalışır: örn. FCM cihaz kaydını silme. Hatalar yutulur.
  final List<Future<void> Function()> beforeSignOut = [];

  /// Bu cihazın FCM jetonu (PushService bağlar). Çıkış isteğine eklenir: erişim jetonu süresi dolmuş olsa bile
  /// sunucu cihaz kaydını siler ve çıkış yapan kullanıcının bildirimi telefonda kalmaz.
  String? Function()? pushToken;
  final _storage = const FlutterSecureStorage();

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
    _memId = fullEmail(identifier);
    _memPassword = password;
  }

  SessionState state = SessionState.loading;
  int? userId;
  String? displayName;
  String? email;

  Future<void> restore() async {
    try {
      final a = await _storage.read(key: 'access');
      final r = await _storage.read(key: 'refresh');
      if (a != null && r != null) {
        api.tokens = Tokens(a, r);
        await _loadMe();
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
      if (e.code == 'SESSION_REPLACED') {
        // forceSignOut zaten başlatıldı (bilgi bandıyla giriş ekranına düşer).
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
          if (e.code == 'SESSION_REPLACED') return;
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

  Future<void> login(String email, String password) async {
    final res = await api.post('/auth/login', {'email': normalizeIdentifier(email), 'password': password, 'client': kClientMobile}, false);
    await _accept(res);
  }

  /// Tam e-postayı döndürür (sunucu yanıtındaki ya da numaradan türetilen).
  Future<String> register({
    required String email,
    required String password,
    required String displayName,
    String? faculty,
    String? department,
    String? grade,
  }) async {
    final res = await api.post(
      '/auth/register',
      {
        'email': normalizeIdentifier(email),
        'password': password,
        'displayName': displayName.trim(),
        'acceptTerms': true,
        'language': api.lang,
        if (faculty != null) 'faculty': faculty,
        if (department != null) 'department': department,
        if (grade != null) 'grade': grade,
      },
      false,
    );
    final server = res is Map ? res['email'] : null;
    return server is String && server.isNotEmpty ? server : fullEmail(email);
  }

  Future<void> resendCode(String email) =>
      api.post('/auth/resend-code', {'email': normalizeIdentifier(email)}, false);

  /// Kayıt sırasında girilen şifre bellekte duruyor mu (doğrulama adımı parola kanıtı için)?
  bool hasRememberedPassword(String email) => _memPassword != null && _memId == fullEmail(email);

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
    final id = _memId ?? fullEmail(email);
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
      _set(SessionState.signedOut); // push yerel temizliği kancadan (token yok: sunucu çağrısı atlanır)
      rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    } finally {
      _forcing = false;
    }
  }

  Future<void> signOut({bool remote = true}) async {
    if (_forcing) return;
    final refresh = api.tokens?.refresh;
    // Önce yerel kancalar (push token silme); token geçerliyken, kısa zaman aşımıyla.
    if (remote) {
      for (final h in List.of(beforeSignOut)) {
        try {
          await h().timeout(const Duration(seconds: 5));
    final fcm = pushToken?.call(); // kancalar jetonu sıfırlamadan önce okunur
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
    _set(SessionState.signedOut);
  }

  Future<void> _accept(dynamic res) async {
    replacedNotice.value = false;
    await api.setTokens(Tokens.fromJson(res));
    await _loadMe();
  }

  Future<void> _persist(Tokens? t) async {
    try {
      if (t == null) {
        await _storage.delete(key: 'access');
        await _storage.delete(key: 'refresh');
      } else {
        await _storage.write(key: 'access', value: t.access);
        await _storage.write(key: 'refresh', value: t.refresh);
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
      return _withRetry(l.errMailQuota, e, l);
    case 'DB_TIMEOUT':
      return _withRetry(l.errServiceBusy, e, l);
    case 'LEGAL_REACCEPT_REQUIRED':
      return l.errLegalReaccept;
    case 'CONVERSATION_CLOSED': // P08: yönetici sohbeti kapattı (sebep istemciye gelmez)
      return l.chatClosedBanner;
    case 'CERTIFICATE_REVOKED': // P07: yönetici sertifikayı iptal etti, yeniden alınamaz
      return l.errCertificateRevoked;
    case 'COMMUNITY_NOT_FOUND': // P06: kulüp kapatıldı (HIDDEN) / silindi
      return l.clubUnavailable;
  }
  return null;
}
