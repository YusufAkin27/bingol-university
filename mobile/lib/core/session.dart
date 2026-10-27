import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'analytics.dart';
import 'api.dart';
import 'badges.dart';
import 'identifier.dart';
import 'nav.dart';
import 'pending_verification.dart';
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
    realtime = ChatRealtime(this);
  }

  final ApiClient api;

  /// Alt gezinme/üst çan rozetleri; sayfalar okuyunca değerini düşürür.
  final badges = AppBadges();

  /// Kabuğun başlattığı tek sohbet gerçek zamanlı bağlantısı (ekranlar `session.realtime` ile erişir).
  ChatRealtime? realtime;

  /// Çıkışta (token hâlâ geçerliyken) çalışır: örn. FCM cihaz kaydını silme. Hatalar yutulur.
  final List<Future<void> Function()> beforeSignOut = [];
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

  Future<void> _loadMe() async {
    try {
      final me = await api.get('/auth/me');
      if (me is Map) {
        final id = me['id'];
        final dn = me['displayName'];
        final em = me['email'];
        userId = id is num ? id.toInt() : null;
        displayName = dn is String ? dn : null;
        email = em is String ? em : null;
      }
      _set(SessionState.signedIn);
    } on ApiError catch (e) {
      // Ağ yokken oturumu silmeyiz; yalnızca sunucudan gelen 401 oturumu bitirir.
      if (e.isNetwork) {
        _set(SessionState.signedIn);
      } else if (e.code == 'SESSION_REPLACED') {
        // forceSignOut zaten başlatıldı (bilgi bandıyla giriş ekranına düşer).
        return;
      } else {
        await signOut(remote: false);
      }
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

  Future<void> verifyEmail(String email, String code) async {
    final res = await api.post('/auth/verify-email', {'email': normalizeIdentifier(email), 'code': code.trim(), 'client': kClientMobile}, false);
    await pending.clear();
    final pw = _memPassword;
    final id = _memId;
    _memPassword = null;
    _memId = null;
    if (res is Map && res['accessToken'] != null) {
      await _accept(res);
    } else if (pw != null && id == fullEmail(email)) {
      await login(id!, pw); // sunucu token döndürmediyse bir kez giriş dene
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
        } catch (_) {}
      }
    }
    try {
      realtime?.stop();
    } catch (_) {}
    if (remote && refresh != null) {
      try {
        await api.post('/auth/logout', {'refreshToken': refresh}, false);
      } catch (_) {
        // Çıkış yerelde her durumda tamamlanır.
      }
    }
    await api.setTokens(null);
    badges.reset();
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

/// Hata kodlarına kullanıcı metni: sunucu zaten istek dilinde `message` döner; yalnızca ağ hatası yerelde.
String errorText(Object e) {
  if (e is ApiError) {
    if (e.isNetwork) return 'Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.';
    if (e.message.isNotEmpty) return e.message;
    if (e.status == 429) return 'Çok fazla deneme. Lütfen biraz bekleyin.';
  }
  return 'Bir sorun oluştu. Lütfen tekrar deneyin.';
}
