import 'package:flutter/widgets.dart';

import '../../core/locale_controller.dart';

/// Sunucunun sabit (yerelleştirilmeyen) yer tutucu metinleri (`MessagingDtos`): gizlenen/silinen mesajda
/// `text` bunlardan biridir. İstemci metni uygulama dilinde gösterir; tanınmayan metin olduğu gibi kalır
/// (engelli kullanıcı, çözülemeyen mesaj...).
const kAdminRemovedText = 'Bu mesaj yönetici tarafından kaldırıldı';
const kModRemovedText = 'Bu mesaj kaldırıldı';
const kDeletedText = 'Bu mesaj silindi';

/// Sunucu `placeholderKind` değerleri (C2): `text` bir yer tutucuysa hangisi olduğunu söyler; alan yoksa (eski sunucu)
/// `text` olduğu gibi gösterilir.
const kPlaceholderBlocked = 'BLOCKED';
const kPlaceholderUnreadable = 'UNREADABLE';

bool isAdminRemovedText(String? serverText) => serverText == kAdminRemovedText;

/// `placeholderKind`'a göre uygulama dilinde yer tutucu metni; alan yok/tanınmıyorsa null (çağıran `text`'e düşer).
String? placeholderKindText(BuildContext context, Object? kind) => switch (kind) {
      kPlaceholderBlocked => context.l10n.p31ChatPlaceholderBlocked,
      kPlaceholderUnreadable => context.l10n.p31ChatPlaceholderUnreadable,
      _ => null,
    };

/// Kaldırılmış/silinmiş mesajın (ya da yanıt önizlemesinin) görünecek yer tutucusu.
/// [serverText] sunucunun `text`'i, [deleted] `deleted` bayrağı, [removed] `removed` bayrağı, [kind] `placeholderKind`.
/// Yönetici kaldırması `deleted=true` ile de gelebilir (kalıcı silme): sunucu metni önceliklidir.
String removedPlaceholder(BuildContext context,
    {required String? serverText, required bool deleted, required bool removed, Object? kind}) {
  final l = context.l10n;
  final byKind = placeholderKindText(context, kind);
  if (byKind != null) return byKind;
  if (serverText == kAdminRemovedText) return l.chatAdminRemovedMsg;
  if (serverText == kModRemovedText) return l.chatModRemovedMsg;
  if (deleted || serverText == kDeletedText) return l.chatMiscThisMessageDeleted;
  return serverText ?? '';
}

/// Mesaj/yanıt haritası bir yer tutucu (silinmiş, gizlenmiş, yönetici kaldırması) mı?
bool isPlaceholderMessage(Map<String, dynamic> m) => m['deleted'] == true || m['removed'] == true;
