import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../media_crop/media_crop.dart';
import 'avatar_crop_page.dart';

/// Başarılı avatar yüklemesi: sunucunun döndürdüğü [url] (yanıtta yoksa null) ve yüklenen (düzenlenmiş, sıkıştırılmış)
/// [bytes] (anında önizleme için).
class AvatarUploadResult {
  const AvatarUploadResult(this.url, this.bytes);

  final String? url;
  final Uint8List bytes;
}

/// Test kancaları (üretimde hepsi null): seç, seç+kırp (kırpma ekranını atlar), yükleyici, görsel servisi.
class AvatarHooks {
  const AvatarHooks({this.pickPhoto, this.cropPhoto, this.uploader, this.images});

  /// Kaynaktan ham fotoğraf baytı seçer (null = vazgeçildi); sonra gerçek kırpma ekranı açılır.
  final CropPhotoPicker? pickPhoto;

  /// Seç + kırp tek adımda (kırpma ekranı açılmaz; null = vazgeçildi).
  final CropPhotoPicker? cropPhoto;
  final MultipartUploader? uploader;
  final ImageService? images;
}

/// Profil fotoğrafı hattı (profil düzenleme, kayıt sonrası fotoğraf adımı ve Profil sekmesi ortak kullanır):
/// seç -> profil fotoğrafı düzenleyicisi (kırp/filtre) -> doğrula/sıkıştır -> `POST /users/me/avatar`.
///
/// Kullanıcı seçimden ya da düzenlemeden vazgeçerse null döner; hata olursa istisna fırlatır ([ImageException],
/// [ApiError]); metne çevirmek için [avatarUploadErrorText].
Future<AvatarUploadResult?> uploadAvatarFrom(
  BuildContext context,
  Session session,
  ImageSource source, {
  String previewName = '',
  CropPhotoPicker? cropPhoto,
  ImageService? images,
  MultipartUploader? uploader,
}) async {
  final bytes = cropPhoto != null
      ? await cropPhoto(source)
      : await pickAndCrop(context, CropSpec.profile(previewName: previewName), source: source);
  if (bytes == null) return null; // kullanıcı vazgeçti
  return _prepareAndUpload(session, bytes, images, uploader);
}

/// Sade akış: [source]'tan seç (galeri: sistem fotoğraf seçicisi) -> [AvatarCropPage] (Onayla/İptal) -> küçült/doğrula ->
/// `POST /users/me/avatar`. Vazgeçilirse null; hata istisna fırlatır (metin için [avatarUploadErrorText]).
/// Yükleme başarısız olursa çağıran mevcut fotoğrafı hiç değiştirmemiştir (yalnız başarıdan sonra uygulanır).
Future<AvatarUploadResult?> pickCropUploadAvatar(
  BuildContext context,
  Session session,
  ImageSource source, {
  AvatarHooks hooks = const AvatarHooks(),
}) async {
  Uint8List? bytes;
  if (hooks.cropPhoto != null) {
    bytes = await hooks.cropPhoto!(source);
  } else {
    final raw = hooks.pickPhoto != null ? await hooks.pickPhoto!(source) : await (await ImageService().pick(source))?.readAsBytes();
    if (raw == null || !context.mounted) return null;
    bytes = await AvatarCropPage.open(context, raw);
  }
  if (bytes == null) return null;
  return _prepareAndUpload(session, bytes, hooks.images, hooks.uploader);
}

/// `DELETE /users/me/avatar` (varsayılan görsele döner) ve profil önbelleğini bayatlatır.
Future<void> removeAvatar(Session session) async {
  await session.api.delete('/users/me/avatar');
  session.api.invalidate('/users/me');
}

/// Zaten seçilmiş/kırpılmış baytları yükler (profil tamamlama: fotoğraf seçilince hemen değil, profil kaydedilince gider).
Future<AvatarUploadResult> uploadAvatarBytes(Session session, Uint8List bytes, {ImageService? images, MultipartUploader? uploader}) =>
    _prepareAndUpload(session, bytes, images, uploader);

Future<AvatarUploadResult> _prepareAndUpload(Session session, Uint8List bytes, ImageService? images, MultipartUploader? uploader) async {
  final prepared = await (images ?? ImageService()).prepare(bytes, avatar: true);
  final r = await (uploader ?? MultipartUploader(session)).upload('/users/me/avatar', prepared);
  session.api.invalidate('/users/me'); // çok parçalı yükleme api katmanından geçmez: profil yanıtı bayat sayılır
  final url = r is Map && r['avatarUrl'] is String ? r['avatarUrl'] as String : null;
  return AvatarUploadResult(url, prepared.bytes);
}

/// [uploadAvatarFrom] hatasını kullanıcıya gösterilecek metne çevirir (boyut/tür/okunamadı/413/ağ).
String avatarUploadErrorText(BuildContext context, Object e) {
  final l = context.l10n;
  if (e is ImageException) {
    switch (e.code) {
      case 'TOO_LARGE':
        return l.profilePhotoTooLargeHint;
      case 'UNSUPPORTED_TYPE':
        return l.profilePhotoUnsupported;
      default:
        return l.profilePhotoUnreadable;
    }
  }
  if (e is ApiError && e.status == 413) return l.profilePhotoTooLarge;
  return errorText(e);
}
