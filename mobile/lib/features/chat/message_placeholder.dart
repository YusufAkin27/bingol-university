import 'package:flutter/widgets.dart';

import '../../core/locale_controller.dart';

/// Sunucunun sabit (yerelleştirilmeyen) yer tutucu metinleri (`MessagingDtos`): gizlenen/silinen mesajda
/// `text` bunlardan biridir. İstemci metni uygulama dilinde gösterir; tanınmayan metin olduğu gibi kalır
/// (engelli kullanıcı, çözülemeyen mesaj...).
const kAdminRemovedText = 'Bu mesaj yönetici tarafından kaldırıldı';
const kModRemovedText = 'Bu mesaj kaldırıldı';
const kDeletedText = 'Bu mesaj silindi';

bool isAdminRemovedText(String? serverText) => serverText == kAdminRemovedText;

/// Kaldırılmış/silinmiş mesajın (ya da yanıt önizlemesinin) görünecek yer tutucusu.
/// [serverText] sunucunun `text`'i, [deleted] `deleted` bayrağı, [removed] `removed` bayrağı.
/// Yönetici kaldırması `deleted=true` ile de gelebilir (kalıcı silme): sunucu metni önceliklidir.
String removedPlaceholder(BuildContext context,
    {required String? serverText, required bool deleted, required bool removed}) {
  final l = context.l10n;
  if (serverText == kAdminRemovedText) return l.chatAdminRemovedMsg;
  if (serverText == kModRemovedText) return l.chatModRemovedMsg;
  if (deleted || serverText == kDeletedText) return l.chatMiscThisMessageDeleted;
  return serverText ?? '';
}

/// Mesaj/yanıt haritası bir yer tutucu (silinmiş, gizlenmiş, yönetici kaldırması) mı?
bool isPlaceholderMessage(Map<String, dynamic> m) => m['deleted'] == true || m['removed'] == true;
