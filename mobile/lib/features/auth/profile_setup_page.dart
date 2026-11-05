import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart';
import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'profile_photo_setup_page.dart';
import 'widgets/auth_academic.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_ref.dart';

/// Profil "tamam" mı: bölüm ve sınıf dolu olmalı. Sınıf için eski sayısal `classYear` (1..6) da geçerlidir
/// (profil düzenleme ile aynı kural; eski kullanıcılar gereksiz yere tuzağa düşmez).
bool isProfileComplete(Map<dynamic, dynamic> p) {
  bool filled(Object? v) => v is String && v.trim().isNotEmpty;
  final g = p['grade'];
  final y = p['classYear'];
  final gradeOk = filled(g) || (g is num && g > 0) || (y is num && y >= 1 && y <= 6);
  return filled(p['department']) && gradeOk;
}

/// Oturum açıkken kabuğun önüne konan zorunlu "profilini tamamla" kapısı.
///
/// Açılışta `GET /users/me` bakılır: bölüm ya da sınıf boşsa kabuk yerine [ProfileSetupPage] gösterilir (kullanıcı hiçbir
/// ekrana geçemez); doluysa [child]. Karar verilirken kısa süre düz zemin görünür. Kullanıcıyı kilitlememek için:
/// - ağ yok / sunucu hatası / [loadTimeout] aşımı: kapı AÇILMAZ, [child] gösterilir; bağlantı gelince ve uygulama öne
///   gelince profil yeniden sorulur, eksikse o anda kapı kapanır (aşırı kısıtlama yok, ama atlanamaz);
/// - tamamlanınca bir daha sorulmaz (profil verisi dolu olur);
/// - bölüm + sınıf az önce ilk kez tamamlandıysa ve fotoğraf yoksa, kabuktan önce İSTEĞE BAĞLI [ProfilePhotoSetupPage] gelir
///   (atlanabilir; uygulama bu adımda kapatılırsa tekrar sorulmaz).
class ProfileCompletionGate extends StatefulWidget {
  const ProfileCompletionGate({
    super.key,
    required this.session,
    required this.child,
    this.loadTimeout = const Duration(seconds: 3),
  });

  final Session session;
  final Widget child;

  /// Yanıt bu sürede gelmezse kabuk açılır; yanıt sonradan "eksik" derse kapı o zaman kapanır.
  final Duration loadTimeout;

  @override
  State<ProfileCompletionGate> createState() => _ProfileCompletionGateState();
}

enum _GateState { checking, complete, incomplete, photo, unknown }

class _ProfileCompletionGateState extends State<ProfileCompletionGate> with WidgetsBindingObserver {
  _GateState _state = _GateState.checking;
  Timer? _timeout;
  bool _loading = false;
  bool _hasAvatar = false; // son profil yanıtında fotoğraf var mı (varsa "fotoğraf ekle" adımı atlanır)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.api.connectivity.reconnects.addListener(_onReconnect);
    _timeout = Timer(widget.loadTimeout, () {
      if (mounted && _state == _GateState.checking) setState(() => _state = _GateState.unknown);
    });
    _check();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.session.api.connectivity.reconnects.removeListener(_onReconnect);
    super.dispose();
  }

  void _onReconnect() {
    if (mounted && _state != _GateState.complete && _state != _GateState.photo) _check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed &&
        _state != _GateState.complete &&
        _state != _GateState.incomplete &&
        _state != _GateState.photo) {
      _check();
    }
  }

  Future<void> _check() async {
    if (_loading) return;
    _loading = true;
    try {
      final r = await widget.session.api.get('/users/me');
      // Fotoğraf adımı sürerken gelen geç yanıt adımı bozmaz.
      if (!mounted || _state == _GateState.photo) return;
      if (r is! Map) {
        _settle(_GateState.unknown);
        return;
      }
      widget.session.noteProfile(r); // açılışta e-posta doğrulama durumunu tazele
      final av = r['avatarUrl'];
      _hasAvatar = av is String && av.trim().isNotEmpty;
      _settle(isProfileComplete(r) ? _GateState.complete : _GateState.incomplete);
    } catch (_) {
      // Ağ yok, 5xx, 429 ya da yetki hatası: kapı açılmaz (yetki hatasını oturum katmanı zaten ele alır).
      if (mounted && _state != _GateState.photo) _settle(_GateState.unknown);
    } finally {
      _loading = false;
    }
  }

  void _settle(_GateState s) {
    _timeout?.cancel();
    if (_state == s) return;
    setState(() => _state = s);
  }

  /// Bölüm + sınıf az önce ilk kez tamamlandı: fotoğrafı yoksa İSTEĞE BAĞLI "fotoğraf ekle" adımı, varsa doğrudan kabuk.
  /// Adım yalnız bu geçişte gösterilir (sonraki açılışlarda bölüm + sınıf dolu olduğundan kapı zaten açıktır).
  void _done() {
    if (!mounted) return;
    final hasAvatar = _hasAvatar || (widget.session.avatarUrl.value ?? '').isNotEmpty;
    setState(() => _state = hasAvatar ? _GateState.complete : _GateState.photo);
  }

  void _photoDone() {
    if (mounted) setState(() => _state = _GateState.complete);
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _GateState.checking:
        // Milisaniyeler süren karar anı: düz zemin (tam sayfa çember yok).
        return Scaffold(backgroundColor: context.bu.bg);
      case _GateState.incomplete:
        return ProfileSetupPage(key: const ValueKey('profile-setup-gate'), session: widget.session, onDone: _done);
      case _GateState.photo:
        return ProfilePhotoSetupPage(key: const ValueKey('profile-photo-gate'), session: widget.session, onDone: _photoDone);
      case _GateState.complete:
      case _GateState.unknown:
        return widget.child;
    }
  }
}

/// Zorunlu, tek seferlik "Bölümünü seç" ekranı: bölüm + sınıf (ikisi de zorunlu; ad soyad kayıtta alınır). Atlanamaz: geri oku ve
/// kapatma yok, sistem geri tuşu kapalı. Tek çıkış yolu sakin bir "Çıkış yap" bağlantısıdır (kullanıcı tuzağa düşmesin).
/// Kayıt, mevcut profil ucuna (`PATCH /users/me`) tek istekte gider.
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key, required this.session, required this.onDone});

  final Session session;

  /// Kayıt başarılı olunca (kapı bir sonraki ekrana geçer).
  final VoidCallback onDone;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  late final AcademicCatalog _catalog = AcademicCatalog.of(widget.session);
  String? _faculty, _department, _grade;
  bool _tried = false;
  bool _busy = false;
  String? _error;
  int _shake = 0;

  @override
  void initState() {
    super.initState();
    _catalog.load();
  }

  String? get _departmentErr => _tried && (_department ?? '').isEmpty ? context.l10n.authSelectDepartment : null;
  String? get _gradeErr => _tried && (_grade ?? '').isEmpty ? context.l10n.authSelectGrade : null;

  Future<void> _submit() async {
    if (_busy) return;
    final academicOk = (_department ?? '').isNotEmpty && (_grade ?? '').isNotEmpty;
    setState(() {
      _tried = true;
      _error = !academicOk && _catalog.state == CatalogState.error ? context.l10n.authDepartmentsLoadFailed : null;
    });
    if (!academicOk) {
      authHaptic(AuthHaptic.error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.api.patch('/users/me', {
        'faculty': _faculty ?? '',
        'department': _department,
        'grade': _grade,
      });
      authHaptic(AuthHaptic.tap);
      unawaited(widget.session.refreshName()); // karşılama adı tazelenir
      if (!mounted) return;
      widget.onDone();
    } on ApiError catch (e) {
      if (!mounted) return;
      _fail(e);
    } catch (e) {
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(Object e) {
    authHaptic(AuthHaptic.error);
    setState(() {
      _error = errorText(e);
      _shake++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsetsDirectional.fromSTEB(kRefPad, 32, kRefPad, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        l.profileSetupTitle,
                        style: tx.displayMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.1),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(l.profileSetupSubtitle, style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.4)),
                    const SizedBox(height: 40),
                    AuthAcademicFields(
                      catalog: _catalog,
                      faculty: _faculty,
                      department: _department,
                      grade: _grade,
                      enabled: !_busy,
                      departmentError: _departmentErr,
                      gradeError: _gradeErr,
                      onChanged: (f, d, g) => setState(() {
                        _faculty = f;
                        _department = d;
                        _grade = g;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 32),
                    RefButton(key: const ValueKey('profile-setup-submit'), label: l.authNext, busy: _busy, onPressed: _submit),
                    AnimatedSize(
                      duration: BuMotion.of(context, BuMotion.short),
                      curve: BuMotion.decelerate,
                      alignment: Alignment.topCenter,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: AuthShake(trigger: _shake, child: RefBanner(_error!, key: ValueKey('setup-error-$_error'))),
                            ),
                    ),
                    const SizedBox(height: 16),
                    // Güvenlik çıkışı: sakin, küçük; oturumu kapatır ve giriş ekranına döner.
                    Center(
                      child: RefLink(
                        key: const ValueKey('profile-setup-signout'),
                        label: l.profileSignOut,
                        compact: true,
                        color: t.mut,
                        onPressed: _busy ? null : () => widget.session.signOut(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
