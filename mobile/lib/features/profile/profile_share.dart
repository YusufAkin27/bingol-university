import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../share/share_models.dart';
import '../share/share_sheet.dart';
import 'profile_qr_page.dart';
import 'profile_qr_scan_page.dart';

/// Profil için paylaşım içeriği: başlık = görünen ad, kaynak = @kullanıcı adı (yoksa null), görsel = avatar.
/// Bağlantı `https://bukampus.com.tr/s/u/{kimlik}`; sunucu sayfası her kimlik için aynı nötr sayfadır, hesap
/// gizliliği/engel profil açılınca uygulamada uygulanır. Gizli hesabın da bağlantısı paylaşılabilir (içerik kilidi sürer).
ShareContent shareContentForUser({required int id, String? displayName, String? username, String? avatarUrl}) {
  String? clean(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
  final un = clean(username);
  return ShareContent(
    type: ShareType.user,
    id: id,
    title: clean(displayName),
    source: un == null ? null : '@${un.replaceFirst(RegExp(r'^@'), '')}',
    imageUrl: clean(avatarUrl),
  );
}

/// "Profili paylaş" (kendi ya da başkasının profili): ortak paylaşım sayfası.
Future<void> shareUserProfile(BuildContext context, Session session,
    {required int id, String? displayName, String? username, String? avatarUrl}) {
  return showShareSheet(
    context,
    session,
    shareContentForUser(id: id, displayName: displayName, username: username, avatarUrl: avatarUrl),
  );
}

/// "QR kodum" ekranını açar.
Future<void> openMyQr(BuildContext context, Session session) {
  return Navigator.of(context).push<void>(MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'profile_qr'),
    builder: (_) => ProfileQrPage(session: session),
  ));
}

/// "QR tara" ekranını açar; geçerli profil kodu okunursa profil o ekranda açılır.
Future<void> openProfileScanner(BuildContext context, Session session) {
  return Navigator.of(context).push<void>(MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'profile_qr_scan'),
    builder: (_) => ProfileQrScanPage(session: session),
  ));
}
