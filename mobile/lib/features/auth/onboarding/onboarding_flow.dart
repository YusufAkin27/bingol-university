import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/academic_catalog.dart';
import '../../../core/api.dart';
import '../../../core/locale_controller.dart';
import '../../../core/platform/image_service.dart';
import '../../../core/session.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/bu.dart';
import '../../media_crop/media_crop.dart';
import '../../profile/avatar_upload.dart';
import '../data/onboarding_api.dart';
import '../widgets/auth_academic.dart' show AuthSelectCard;
import '../widgets/auth_motion.dart';
import '../widgets/auth_ref.dart';

/// Kullanıcı adı müsaitlik durumu (canlı).
enum UsernameState { idle, checking, available, taken, invalid, reserved, unknown }

/// Profil tamamlama (OAuth sonrası) 2 aşamalı onboarding. Profil bitmeden kabuğa geçilemez: sistem geri tuşu yalnız
/// 2. aşamadan 1. aşamaya döner; tek çıkış yolu "Çıkış yap" bağlantısıdır.
///
/// Aşama 1 "Önce tanışalım.": ad, soyad, kullanıcı adı (400 ms debounce ile canlı müsaitlik), isteğe bağlı fotoğraf.
/// Aşama 2 "Kampüste neredesin?": üniversite (sabit), fakülte, bölüm (fakülteye göre), sınıf, isteğe bağlı biyografi,
/// "BÜKampüs'e katıl" -> `PUT /users/me/onboarding`. Bilgiler kullanıcı beyanıdır.
///
/// Taslak (ad/soyad/kullanıcı adı/seçimler) yalnız güvenli yerel depoda ([OnboardingDraftStore]) tutulur; biyografi ve
/// fotoğraf saklanmaz. Başarıda taslak silinir.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.session,
    required this.onDone,
    this.api,
    this.usernameDebounce = const Duration(milliseconds: 400),
    this.cropPhoto,
    this.uploader,
    this.images,
  });

  final Session session;

  /// Profil sunucuda tamamlandı: kapı kabuğa geçer.
  final VoidCallback onDone;
  final OnboardingApi? api;
  final Duration usernameDebounce;

  /// Test kancaları (fotoğraf seç + kırp, yükleyici, görsel servisi).
  final CropPhotoPicker? cropPhoto;
  final MultipartUploader? uploader;
  final ImageService? images;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _nameMax = 50;
  static const _bioMax = 300;

  late final OnboardingApi _api = widget.api ?? OnboardingApi(widget.session.api);
  late final AcademicCatalog _catalog = AcademicCatalog.of(widget.session);

  final _first = TextEditingController();
  final _last = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();

  int _step = 0;
  bool _tried1 = false;
  bool _tried2 = false;
  bool _busy = false;
  String? _error;
  int _shake = 0;

  UsernameState _uState = UsernameState.idle;
  Timer? _debounce;
  int _seq = 0; // eski yanıtları yok sayar
  Completer<void>? _checkDone; // sürmekte olan kontrol bitince tamamlanır ([_next] bekler)

  Uint8List? _photo;
  bool _photoBusy = false;
  String? _photoError;

  AcademicFaculty? _faculty;
  AcademicDepartment? _dept;
  ClassYear? _class;
  OnboardingDraft? _draft; // katalog yüklenince kimlikler çözülür

  @override
  void initState() {
    super.initState();
    _catalog.addListener(_onCatalog);
    _catalog.load();
    unawaited(_prefill());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _catalog.removeListener(_onCatalog);
    _first.dispose();
    _last.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  /// Ön doldurma: önce yerel taslak (Apple'ın bir kez verdiği ad dahil), sonra sunucudaki profil (Google adı).
  /// Kullanıcı yazmaya başladıysa dokunulmaz.
  Future<void> _prefill() async {
    final d = await OnboardingDraftStore.load();
    if (!mounted) return;
    if (d != null) {
      _draft = d;
      if (_first.text.isEmpty) _first.text = d.firstName;
      if (_last.text.isEmpty) _last.text = d.lastName;
      if (_username.text.isEmpty && d.username.isNotEmpty) {
        _username.text = d.username;
        _scheduleCheck();
      }
      _class ??= d.classYear;
      setState(() => _step = d.step);
      _resolveDraftSelection();
    }
    if (_first.text.isNotEmpty && _last.text.isNotEmpty) return;
    try {
      final me = await widget.session.api.get('/users/me');
      if (!mounted || me is! Map) return;
      String? str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
      var f = str(me['firstName']), l = str(me['lastName']);
      if (f == null && l == null) {
        final full = str(me['displayName']);
        if (full != null) {
          final at = full.lastIndexOf(' ');
          f = at < 0 ? full : full.substring(0, at);
          l = at < 0 ? null : full.substring(at + 1);
        }
      }
      if (_first.text.isEmpty && f != null) _first.text = f;
      if (_last.text.isEmpty && l != null) _last.text = l;
      final u = str(me['username']);
      if (_username.text.isEmpty && u != null) {
        _username.text = u;
        _scheduleCheck();
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Profil okunamadı: alanlar boş kalır, kullanıcı doldurur.
    }
  }

  void _onCatalog() {
    if (!mounted) return;
    _resolveDraftSelection();
    setState(() {});
  }

  /// Taslaktaki fakülte/bölüm kimliklerini katalog yüklendikten sonra nesnelere çözer.
  void _resolveDraftSelection() {
    final d = _draft;
    if (d == null || !_catalog.ready || _faculty != null) return;
    for (final f in _catalog.faculties) {
      if (f.id == d.facultyId) {
        _faculty = f;
        for (final dep in f.departments) {
          if (dep.id == d.departmentId) _dept = dep;
        }
      }
    }
  }

  void _persist() {
    unawaited(OnboardingDraftStore.save(OnboardingDraft(
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      username: _username.text.trim(),
      facultyId: _faculty?.id,
      departmentId: _dept?.id,
      classYear: _class,
      step: _step,
    )));
  }

  // --------------------------------------------------------------------------------------------- kullanıcı adı

  String get _uname => _username.text.trim().toLowerCase();

  void _onUsernameChanged(String _) {
    _persist();
    _scheduleCheck();
  }

  void _finishCheck() {
    final c = _checkDone;
    _checkDone = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  void _scheduleCheck() {
    _debounce?.cancel();
    _seq++;
    _finishCheck(); // iptal edilen önceki kontrol bekleyeni asılı bırakmasın
    final u = _uname;
    if (u.length < 3 || !kUsernameRule.hasMatch(u)) {
      setState(() => _uState = UsernameState.idle);
      return;
    }
    setState(() => _uState = UsernameState.checking);
    final seq = _seq;
    _checkDone = Completer<void>();
    _debounce = Timer(widget.usernameDebounce, () async {
      try {
        final r = await _api.usernameAvailable(u);
        if (!mounted || seq != _seq) return;
        setState(() => _uState = r.available
            ? UsernameState.available
            : switch (r.reason) {
                'RESERVED' => UsernameState.reserved,
                'INVALID' => UsernameState.invalid,
                _ => UsernameState.taken,
              });
      } catch (_) {
        // Ağ/sunucu hatası: kullanıcıyı bloklama; kayıtta sunucu yine doğrular (409 USERNAME_TAKEN).
        if (mounted && seq == _seq) setState(() => _uState = UsernameState.unknown);
      } finally {
        if (seq == _seq) _finishCheck();
      }
    });
  }

  String? _usernameError(AppLocalizations l) {
    final u = _uname;
    switch (_uState) {
      case UsernameState.taken:
        return l.oaUserTaken;
      case UsernameState.invalid:
        return l.oaUserInvalid;
      case UsernameState.reserved:
        return l.oaUserReserved;
      default:
        break;
    }
    if (_tried1 && (u.isEmpty || !kUsernameRule.hasMatch(u))) return u.isEmpty ? l.oaUserRequired : l.oaUserInvalid;
    return null;
  }

  String _usernameHelper(AppLocalizations l) => switch (_uState) {
        UsernameState.checking => l.oaUserChecking,
        UsernameState.available => l.oaUserAvail,
        _ => l.oaUserRule,
      };

  // --------------------------------------------------------------------------------------------- fotoğraf

  Future<void> _pickPhoto() async {
    if (_photoBusy || _busy) return;
    final choice = await showPhotoSourceSheet(context);
    if (choice == null || choice == PhotoSource.remove || !mounted) return;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    try {
      final source = choice == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery;
      final name = '${_first.text} ${_last.text}'.trim();
      final bytes = widget.cropPhoto != null
          ? await widget.cropPhoto!(source)
          : await pickAndCrop(context, CropSpec.profile(previewName: name), source: source);
      if (!mounted) return;
      setState(() {
        _photoBusy = false;
        if (bytes != null) _photo = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _photoBusy = false;
        _photoError = avatarUploadErrorText(context, e);
      });
    }
  }

  // --------------------------------------------------------------------------------------------- adımlar

  Future<void> _next() async {
    if (_busy) return;
    setState(() => _tried1 = true);
    final l = context.l10n;
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      authHaptic(AuthHaptic.error);
      return;
    }
    if (_uname.isEmpty || !kUsernameRule.hasMatch(_uname)) {
      authHaptic(AuthHaptic.error);
      return;
    }
    if (_uState == UsernameState.checking && _checkDone != null) {
      setState(() => _busy = true);
      while (mounted && _uState == UsernameState.checking && _checkDone != null) {
        await _checkDone!.future;
      }
      if (!mounted) return;
      setState(() => _busy = false);
    }
    if (_usernameError(l) != null) {
      authHaptic(AuthHaptic.error);
      return;
    }
    authHaptic(AuthHaptic.tap);
    setState(() {
      _step = 1;
      _error = null;
    });
    _persist();
  }

  void _back() {
    if (_step == 0 || _busy) return;
    setState(() {
      _step = 0;
      _error = null;
    });
    _persist();
  }

  Future<void> _join() async {
    if (_busy) return;
    setState(() => _tried2 = true);
    if (_faculty == null || _dept == null || _class == null) {
      authHaptic(AuthHaptic.error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.submit(OnboardingForm(
        firstName: _first.text,
        lastName: _last.text,
        username: _uname,
        classYear: _class!,
        facultyId: _faculty!.id,
        facultyName: _faculty!.name,
        departmentId: _dept!.id,
        departmentName: _dept!.name,
        bio: _bio.text,
      ));
      // Fotoğraf profil kaydından SONRA yüklenir (profil bitmeden yazma uçları 403 verebilir); başarısızlık akışı bozmaz.
      final photo = _photo;
      if (photo != null) {
        try {
          final r = await uploadAvatarBytes(widget.session, photo, images: widget.images, uploader: widget.uploader);
          if (r.url != null) widget.session.avatarUrl.value = r.url;
        } catch (_) {}
      }
      authHaptic(AuthHaptic.success);
      unawaited(OnboardingDraftStore.clear());
      unawaited(widget.session.refreshName());
      if (!mounted) return;
      widget.onDone();
    } on ApiError catch (e) {
      if (!mounted) return;
      _failJoin(e);
    } catch (e) {
      if (mounted) _failJoin(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _failJoin(Object e) {
    authHaptic(AuthHaptic.error);
    if (e is ApiError && (e.code == 'USERNAME_TAKEN' || (e.status == 409 && e.code.startsWith('USERNAME')))) {
      setState(() {
        _step = 0; // kullanıcı adı 1. aşamada: oraya dön, alan altında hata
        _uState = UsernameState.taken;
        _error = null;
      });
      return;
    }
    setState(() {
      _error = errorText(e);
      _shake++;
    });
  }

  // --------------------------------------------------------------------------------------------- seçiciler

  Future<void> _pickFaculty() async {
    if (_busy) return;
    if (_catalog.state == CatalogState.error) {
      unawaited(_catalog.retry());
      return;
    }
    if (!_catalog.ready) return;
    final lang = uiLocale(context).languageCode;
    final r = await _showChoiceSheet<AcademicFaculty>(
      context,
      title: context.l10n.oaFaculty,
      selected: _faculty,
      items: [for (final f in _catalog.faculties) (f, f.label(lang))],
    );
    if (r == null || !mounted) return;
    setState(() {
      if (_faculty != r) {
        _dept = null; // bölüm fakülteye bağlıdır
      }
      _faculty = r;
      _error = null;
    });
    _persist();
  }

  Future<void> _pickDepartment() async {
    if (_busy) return;
    final f = _faculty;
    if (f == null) {
      setState(() => _tried2 = true);
      return;
    }
    final lang = uiLocale(context).languageCode;
    final r = await _showChoiceSheet<AcademicDepartment>(
      context,
      title: context.l10n.pickDepartment,
      selected: _dept,
      items: [for (final d in f.departments) (d, d.label(lang))],
    );
    if (r == null || !mounted) return;
    setState(() {
      _dept = r;
      // Bölümün süresi biliniyorsa uygun olmayan sınıf seçimi düşer.
      final allowed = classYearsFor(programYears: r.years);
      if (_class != null && !allowed.contains(_class)) _class = null;
      _error = null;
    });
    _persist();
  }

  Future<void> _pickClass() async {
    if (_busy) return;
    final l = context.l10n;
    final r = await _showChoiceSheet<ClassYear>(
      context,
      title: l.pickGrade,
      selected: _class,
      items: [for (final c in classYearsFor(programYears: _dept?.years)) (c, classYearLabel(l, c))],
    );
    if (r == null || !mounted) return;
    setState(() {
      _class = r;
      _error = null;
    });
    _persist();
  }

  // --------------------------------------------------------------------------------------------- arayüz

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final reduced = AppMotion.of(context, AppMotion.normal) == Duration.zero;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Column(
            children: [
              _Header(step: _step, onBack: _step == 1 && !_busy ? _back : null),
              Expanded(
                child: AnimatedSwitcher(
                  duration: reduced ? Duration.zero : const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(position: Tween(begin: const Offset(0, .02), end: Offset.zero).animate(anim), child: child),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey('ob-step-$_step'),
                    child: _step == 0 ? _buildStep1(context) : _buildStep2(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scroll(List<Widget> children) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsetsDirectional.fromSTEB(kRefPad, 8, kRefPad, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      );

  Widget _title(BuildContext context, String title, String sub) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: tx.displayMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w400, height: 1.1)),
        ),
        const SizedBox(height: 10),
        Text(sub, style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.4)),
      ],
    );
  }

  Widget _buildStep1(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final nameErr1 = _tried1 && _first.text.trim().isEmpty ? l.oaFirstRequired : null;
    final nameErr2 = _tried1 && _last.text.trim().isEmpty ? l.oaLastRequired : null;
    return _scroll([
      _title(context, l.oaOb1Title, l.oaOb1Sub),
      const SizedBox(height: 28),
      Center(child: _AvatarPicker(photo: _photo, busy: _photoBusy, name: '${_first.text} ${_last.text}', onTap: _pickPhoto)),
      const SizedBox(height: 8),
      Center(child: Text(l.oaPhotoOptional, style: tx.bodySmall!.copyWith(color: t.mut))),
      if (_photoError != null) Padding(padding: const EdgeInsets.only(top: 8), child: RefBanner(_photoError!)),
      const SizedBox(height: 24),
      RefTextField(
        key: const ValueKey('ob-first'),
        controller: _first,
        label: l.oaFirstName,
        enabled: !_busy,
        maxLength: _nameMax,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.givenName],
        forceError: nameErr1,
        onChanged: (_) {
          _persist();
          setState(() {});
        },
      ),
      const SizedBox(height: 20),
      RefTextField(
        key: const ValueKey('ob-last'),
        controller: _last,
        label: l.oaLastName,
        enabled: !_busy,
        maxLength: _nameMax,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.familyName],
        forceError: nameErr2,
        onChanged: (_) {
          _persist();
          setState(() {});
        },
      ),
      const SizedBox(height: 20),
      RefTextField(
        key: const ValueKey('ob-username'),
        controller: _username,
        label: l.oaUsername,
        enabled: !_busy,
        maxLength: 24,
        autocorrect: false,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.newUsername],
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
          TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toLowerCase())),
        ],
        forceError: _usernameError(l),
        helper: _usernameHelper(l),
        onChanged: _onUsernameChanged,
        onSubmitted: _next,
        trailing: _UsernameBadge(state: _uState),
      ),
      const SizedBox(height: 28),
      RefButton(key: const ValueKey('ob-next'), label: l.authNext, busy: _busy, onPressed: _next),
      const SizedBox(height: 8),
      Center(
        child: RefLink(
          key: const ValueKey('ob-signout'),
          label: l.profileSignOut,
          compact: true,
          color: t.mut,
          onPressed: _busy ? null : () => widget.session.signOut(),
        ),
      ),
    ]);
  }

  Widget _buildStep2(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final lang = uiLocale(context).languageCode;
    final loading = _catalog.state == CatalogState.loading || _catalog.state == CatalogState.idle;
    final failed = _catalog.state == CatalogState.error;
    return _scroll([
      _title(context, l.oaOb2Title, l.oaOb2Sub),
      const SizedBox(height: 28),
      _StaticField(label: l.oaUniversity, value: l.oaUniversityName),
      const SizedBox(height: 20),
      AuthSelectCard(
        key: const ValueKey('ob-faculty'),
        label: l.oaFaculty,
        value: _faculty?.label(lang),
        placeholder: loading ? l.pickLoading : l.oaPickFaculty,
        error: _tried2 && _faculty == null ? l.oaSelectFaculty : null,
        onTap: _busy ? null : _pickFaculty,
      ),
      if (failed)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(child: Text(l.pickListFailed, style: tx.bodySmall!.copyWith(color: t.danger))),
              RefLink(label: l.pickRetry, onPressed: _catalog.retry),
            ],
          ),
        ),
      const SizedBox(height: 20),
      AuthSelectCard(
        key: const ValueKey('ob-department'),
        label: l.pickDepartment,
        value: _dept?.label(lang),
        placeholder: _faculty == null ? l.oaPickFacultyFirst : l.pickSelectDepartment,
        error: _tried2 && _faculty != null && _dept == null ? l.authSelectDepartment : null,
        onTap: _busy ? null : _pickDepartment,
      ),
      const SizedBox(height: 20),
      AuthSelectCard(
        key: const ValueKey('ob-class'),
        label: l.pickGrade,
        value: _class == null ? null : classYearLabel(l, _class!),
        placeholder: l.pickSelectGrade,
        error: _tried2 && _class == null ? l.authSelectGrade : null,
        onTap: _busy ? null : _pickClass,
      ),
      const SizedBox(height: 24),
      RefTextField(
        key: const ValueKey('ob-bio'),
        controller: _bio,
        label: l.oaBio,
        enabled: !_busy,
        maxLength: _bioMax,
        minLines: 2,
        maxLines: 4,
        hint: l.oaBioHint,
        textInputAction: TextInputAction.newline,
      ),
      const SizedBox(height: 16),
      Text(l.oaDeclareNote, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.45)),
      const SizedBox(height: 24),
      RefButton(key: const ValueKey('ob-join'), label: l.oaJoin, busy: _busy, onPressed: _join),
      AnimatedSize(
        duration: BuMotion.of(context, BuMotion.short),
        curve: BuMotion.decelerate,
        alignment: Alignment.topCenter,
        child: _error == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 16),
                child: AuthShake(trigger: _shake, child: RefBanner(_error!, key: ValueKey('ob-error-$_error'))),
              ),
      ),
    ]);
  }
}

/// Sınıf seçeneğinin dile göre adı.
String classYearLabel(AppLocalizations l, ClassYear c) => switch (c) {
      ClassYear.prep => l.acadGradePrep,
      ClassYear.postgrad => l.oaClassPostgrad,
      ClassYear.other => l.oaClassOther,
      _ => l.acadGradeN('${c.year}'),
    };

class _Header extends StatelessWidget {
  const _Header({required this.step, required this.onBack});

  final int step;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return SizedBox(
      height: BuSize.appBar,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        child: Row(
          children: [
            if (step == 1)
              Semantics(
                button: true,
                label: l.authBack,
                excludeSemantics: true,
                onTap: onBack,
                child: IconButton(
                  key: const ValueKey('ob-back'),
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: Icon(buDirIcon(context, BuIcons.arrowLeft), color: t.ink, size: 24),
                  onPressed: onBack,
                ),
              )
            else
              const SizedBox(width: 48),
            const Spacer(),
            Semantics(
              label: l.oaStepOf('${step + 1}', '2'),
              child: ExcludeSemantics(
                child: Text('${step + 1}/2', style: tx.labelLarge!.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

/// Yuvarlak profil fotoğrafı seçici (96 dp): önizleme + küçük kamera rozeti.
class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.photo, required this.busy, required this.name, required this.onTap});

  final Uint8List? photo;
  final bool busy;
  final String name;
  final VoidCallback onTap;

  static const double size = 96;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Semantics(
      button: true,
      label: photo == null ? l.oaPhotoAdd : l.oaPhotoChange,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('ob-avatar'),
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: size + 8,
          height: size + 8,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(fit: StackFit.expand, children: [
                    BuAvatar(name: name.trim().isEmpty ? null : name, size: size),
                    if (photo != null)
                      Image.memory(photo!,
                          key: const ValueKey('ob-avatar-preview'),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    if (busy) ColoredBox(color: t.bg.withValues(alpha: .6), child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4)))),
                  ]),
                ),
              ),
              PositionedDirectional(
                end: 0,
                bottom: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle, border: Border.all(color: t.bg, width: 2)),
                  child: Icon(BuIcons.camera, size: 16, color: t.onPr),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Canlı kullanıcı adı rozeti: kontrol sırasında küçük çember, müsaitse işaret.
class _UsernameBadge extends StatelessWidget {
  const _UsernameBadge({required this.state});

  final UsernameState state;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    switch (state) {
      case UsernameState.checking:
        return const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
      case UsernameState.available:
        return Padding(padding: const EdgeInsets.all(8), child: Icon(BuIcons.check, size: 20, color: t.ok));
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Salt okunur alan (üniversite): çizgili alan görünümü, ok yok.
class _StaticField extends StatelessWidget {
  const _StaticField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      label: '$label, $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: tx.labelLarge!.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
          Container(
            constraints: const BoxConstraints(minHeight: 56),
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
            child: Row(
              children: [
                Expanded(child: Text(value, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400))),
                Icon(BuIcons.lock, size: 18, color: t.mut),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek seçimli alt sayfa (fakülte / bölüm / sınıf): başlık + kapat, seçili satır işaretli. İptalde null.
Future<T?> _showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> items,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final t = ctx.bu;
      final l = ctx.l10n;
      final tx = Theme.of(ctx).textTheme;
      return DecoratedBox(
        decoration: BoxDecoration(color: t.sf3, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: t.bd, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
                      ),
                    ),
                    IconButton(
                      tooltip: l.commonClose,
                      style: IconButton.styleFrom(backgroundColor: t.sf2),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      icon: Icon(BuIcons.x, size: 20, color: t.ink),
                      onPressed: () => Navigator.maybePop(ctx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  children: [
                    for (final (value, label) in items)
                      Semantics(
                        button: true,
                        selected: value == selected,
                        child: Material(
                          color: value == selected ? t.soft.withValues(alpha: .6) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(ctx, value),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 56),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(label, style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400))),
                                    if (value == selected) Icon(BuIcons.check, size: 20, color: t.ink),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
