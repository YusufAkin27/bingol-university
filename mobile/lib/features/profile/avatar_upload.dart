import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../media_crop/media_crop.dart';

/// Başarılı avatar yüklemesi: sunucunun döndürdüğü [url] (yanıtta yoksa null) ve yüklenen (kırpılmış, sıkıştırılmış)
/// [bytes] (anında önizleme için).
class AvatarUploadResult {
  const AvatarUploadResult(this.url, this.bytes);

  final String? url;
  final Uint8List bytes;
}

/// Profil fotoğrafı hattı (profil düzenleme ve kayıt sonrası "fotoğraf ekle" adımı ortak kullanır):
/// seç -> 1:1 daire kırp -> doğrula/sıkıştır -> `POST /users/me/avatar`.
///
/// Kullanıcı seçimden ya da kırpmadan vazgeçerse null döner; hata olursa istisna fırlatır ([ImageException],
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
  final prepared = await (images ?? ImageService()).prepare(bytes, avatar: true);
  final r = await (uploader ?? MultipartUploader(session)).upload('/users/me/avatar', prepared);
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
