import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../media_crop/media_crop.dart';
import '../profile/avatar_upload.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_ref.dart';

/// Kayıttan sonra, bölüm + sınıf adımının ARDINDAN gösterilen İSTEĞE BAĞLI "Profil fotoğrafı eklemek ister misiniz?" adımı.
///
/// Atlanabilir: "Şimdilik atla" her zaman görünür ve çalışır; sistem geri tuşu da atlama sayılır (kullanıcı tuzağa düşmez).
/// Fotoğraf seçme/kırpma/yükleme profil düzenlemeyle ORTAK hattır ([uploadAvatarFrom]); yüklenince avatar önizlemesi
/// güncellenir, birincil düğme "Devam"a döner ve "Değiştir" bağlantısı çıkar. [onDone] hem atlayınca hem devam edince çağrılır.
class ProfilePhotoSetupPage extends StatefulWidget {
  const ProfilePhotoSetupPage({
    super.key,
    required this.session,
    required this.onDone,
    this.cropPhoto,
    this.uploader,
    this.images,
  });

  final Session session;

  /// Adım bitti (atlandı ya da fotoğrafla devam edildi): kapı kabuğa geçer.
  final VoidCallback onDone;

  /// Test için: seç + kırp işlemini değiştirir (profil düzenleme ile aynı kancalar).
  final CropPhotoPicker? cropPhoto;
  final MultipartUploader? uploader;
  final ImageService? images;

  @override
  State<ProfilePhotoSetupPage> createState() => _ProfilePhotoSetupPageState();
}

class _ProfilePhotoSetupPageState extends State<ProfilePhotoSetupPage> {
  static const _avatarSize = 160.0;

  bool _busy = false;
  String? _error;
  int _shake = 0;
  int _seq = 0; // atlanınca/yeniden denenince eski yüklemenin sonucunu yok sayar
  Uint8List? _preview; // yüklenen fotoğrafın anında önizlemesi
  String? _url;
  bool _finished = false;

  bool get _hasPhoto => _preview != null;

  void _finish() {
    if (_finished) return;
    _finished = true;
    _seq++; // bekleyen yükleme sonucu artık yok sayılır
    widget.onDone();
  }

  Future<void> _pick() async {
    if (_busy || _finished) return;
    final choice = await showPhotoSourceSheet(context);
    if (choice == null || choice == PhotoSource.remove || !mounted) return;
    await _upload(choice == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery);
  }

  Future<void> _upload(ImageSource source) async {
    final seq = ++_seq;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await uploadAvatarFrom(
        context,
        widget.session,
        source,
        previewName: widget.session.displayName ?? '',
        cropPhoto: widget.cropPhoto,
        images: widget.images,
        uploader: widget.uploader,
      );
      if (!mounted || seq != _seq) return;
      if (r == null) {
        setState(() => _busy = false); // seçimden/kırpmadan vazgeçildi
        return;
      }
      authHaptic(AuthHaptic.tap);
      if (r.url != null) widget.session.avatarUrl.value = r.url;
      setState(() {
        _busy = false;
        _preview = r.bytes;
        _url = r.url;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      authHaptic(AuthHaptic.error);
      setState(() {
        _busy = false;
        _error = avatarUploadErrorText(context, e);
        _shake++;
      });
    }
  }

  Widget _avatar(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Semantics(
      button: true,
      enabled: !_busy,
      label: l.photoSetupAvatarSemantic,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('photo-setup-avatar'),
        behavior: HitTestBehavior.opaque,
        onTap: _busy ? null : _pick,
        child: SizedBox(
          width: _avatarSize,
          height: _avatarSize,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: ClipOval(
                child: Stack(fit: StackFit.expand, children: [
                  if (_preview != null)
                    Image.memory(
                      _preview!,
                      key: const ValueKey('photo-setup-preview'),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      cacheWidth: (_avatarSize * MediaQuery.devicePixelRatioOf(context)).ceil(),
                      errorBuilder: (_, __, ___) => BuAvatar(name: widget.session.displayName, url: _url, size: _avatarSize),
                    )
                  else
                    BuAvatar(name: widget.session.displayName, size: _avatarSize),
                  if (_busy)
                    ColoredBox(
                      color: t.scrim.withValues(alpha: .6),
                      child: Center(
                        child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: t.onMedia)),
                      ),
                    ),
                ]),
              ),
            ),
            // Dekoratif kamera rozeti: dokunma hedefi avatarın tamamıdır.
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: ExcludeSemantics(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: t.prPressed, shape: BoxShape.circle, border: Border.all(color: t.bg, width: 3)),
                  child: Icon(BuIcons.camera, size: 22, color: t.onPr),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return PopScope(
      // Geri tuşu atlama sayılır: bu adımda kullanıcı tuzağa düşmez.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: SingleChildScrollView(
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
                        l.photoSetupTitle,
                        style: tx.displayMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.1),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(l.photoSetupSubtitle, style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.4)),
                    const SizedBox(height: 40),
                    Center(child: _avatar(context)),
                    const SizedBox(height: 40),
                    RefButton(
                      key: const ValueKey('photo-setup-primary'),
                      label: _hasPhoto ? l.authNext : l.photoSetupPick,
                      busy: _busy,
                      busyLabel: l.profileUploading,
                      onPressed: _hasPhoto ? _finish : _pick,
                    ),
                    AnimatedSize(
                      duration: BuMotion.of(context, BuMotion.short),
                      curve: BuMotion.decelerate,
                      alignment: Alignment.topCenter,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: AuthShake(trigger: _shake, child: RefBanner(_error!, key: ValueKey('photo-error-$_error'))),
                            ),
                    ),
                    if (_hasPhoto) ...[
                      const SizedBox(height: 4),
                      Center(
                        child: RefLink(
                          key: const ValueKey('photo-setup-change'),
                          label: l.photoSetupChange,
                          onPressed: _busy ? null : _pick,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Her zaman görünür ve çalışır (yükleme sürerken de): sakin, ikincil metin düğmesi.
                    Center(
                      child: RefLink(
                        key: const ValueKey('photo-setup-skip'),
                        label: l.photoSetupSkip,
                        color: t.mut,
                        onPressed: _finish,
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
