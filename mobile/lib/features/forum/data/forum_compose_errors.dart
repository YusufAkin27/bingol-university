import '../../../core/api.dart';
import '../../../core/platform/image_service.dart';
import '../../../core/session.dart' show knownErrorText;
import '../../../l10n/app_localizations.dart';

/// Konu yayınlama hatasını kısa, çevrilmiş mesaja çevirir. Kullanıcının yazdıkları HER durumda korunur;
/// mesajlar bunu belirtir (ağ/genel).
String forumPublishErrorText(Object e, AppLocalizations l) {
  if (e is ImageException) return forumImageErrorText(e, l);
  if (e is ApiError) {
    if (e.isNetwork) return l.forumComposeErrNetwork;
    switch (e.code) {
      case 'FORUM_DUPLICATE_CONTENT':
        return l.forumComposeErrDuplicate;
      case 'CONTENT_PROFANITY':
        return l.forumComposeErrProfanity;
      case 'FORUM_CATEGORY_NOT_FOUND':
      case 'FORUM_CATEGORY_ARCHIVED':
      case 'FORUM_CATEGORY_INACTIVE':
        return l.forumComposeErrCategory;
      case 'MEDIA_TOO_LARGE':
        return l.forumComposeErrImageTooLarge;
    }
    if (e.code.startsWith('FORUM_CATEGORY')) return l.forumComposeErrCategory;
    if (e.status == 429) return l.forumComposeErrRate;
    final known = knownErrorText(e, l);
    if (known != null) return known;
    if (e.status == 400 || e.status == 422) return l.forumComposeErrInvalid;
  }
  return l.forumComposeErrGeneric;
}

/// Görsel seçme / hazırlama / yükleme hatası.
String forumImageErrorText(Object e, AppLocalizations l) {
  if (e is ImageException) {
    return switch (e.code) {
      'TOO_LARGE' => l.forumComposeErrImageTooLarge,
      'UNSUPPORTED_TYPE' => l.forumComposeErrImageType,
      _ => l.forumComposeErrImageRead,
    };
  }
  if (e is ApiError) {
    if (e.isNetwork) return l.forumComposeErrNetwork;
    if (e.status == 413 || e.code == 'MEDIA_TOO_LARGE') return l.forumComposeErrImageTooLarge;
    if (e.status == 415 || e.code == 'MEDIA_UNSUPPORTED' || e.code == 'FORUM_MEDIA_INVALID') {
      return l.forumComposeErrImageType;
    }
    if (e.status == 429) return l.forumComposeErrRate;
  }
  return l.forumComposeErrImageUpload;
}

/// Konu düzenleme hatası. `FORUM_TOPIC_LOCKED` -> kilitli; 404/409 -> konu artık yok; 403 -> sahip değil.
/// [gone] true dönerse konu kalıcı olarak yok sayılır (Kaydet pasif olur).
({String text, bool gone, bool locked}) forumEditErrorText(Object e, AppLocalizations l) {
  if (e is ApiError) {
    if (e.isNetwork) return (text: l.forumComposeErrNetwork, gone: false, locked: false);
    if (e.code == 'FORUM_TOPIC_LOCKED') return (text: l.forumComposeEditLocked, gone: false, locked: true);
    if (e.code == 'CONTENT_PROFANITY') return (text: l.forumComposeErrProfanity, gone: false, locked: false);
    if (e.code == 'FORUM_DUPLICATE_CONTENT') return (text: l.forumComposeErrDuplicate, gone: false, locked: false);
    if (e.code.startsWith('FORUM_CATEGORY')) return (text: l.forumComposeErrCategory, gone: false, locked: false);
    if (e.status == 404 || e.status == 409 || e.status == 410) {
      return (text: l.forumComposeEditGone, gone: true, locked: false);
    }
    if (e.status == 403) return (text: l.forumComposeEditNotOwner, gone: false, locked: false);
    if (e.status == 429) return (text: l.forumComposeErrRate, gone: false, locked: false);
    if (e.status == 400 || e.status == 422) return (text: l.forumComposeErrInvalid, gone: false, locked: false);
  }
  return (text: l.forumComposeEditErrGeneric, gone: false, locked: false);
}
