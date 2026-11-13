import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../share/share_models.dart';
import '../share/share_sheet.dart';
import '../widgets/widget_link.dart';

/// Ana ekran widget'ı derin bağlantısı: `bukampus://clubs/<id>` ([WidgetLink.parse] çözer, kulüp sayfasını açar).
String clubShareLink(int communityId) => WidgetLink.club(communityId).uri;

/// Test kancası: sistem paylaşım sayfası çağrısı. Varsayılan `share_plus`.
@visibleForTesting
Future<void> Function(ShareParams params)? debugClubShare;

/// Kulübü sistem paylaşım sayfasıyla paylaşır (metin: kulüp adı + derin bağlantı). Eski yol; yeni arayüz [shareClubSheet].
Future<void> shareClub(BuildContext context, {required int communityId, required String name}) async {
  final text = context.l10n.clubShareMsg(name.trim(), clubShareLink(communityId));
  Analytics.instance.action('share', target: 'club');
  final p = ShareParams(text: text, subject: name.trim());
  await (debugClubShare ?? (x) => SharePlus.instance.share(x))(p);
}

/// Kulüp için paylaşım içeriği: bağlantı `https://bukampus.com.tr/s/c/{id}`. Özel (PRIVATE) kulüp yalnız kişiyle
/// mesajla paylaşılır ([ShareContent.restricted]); herkese açık sayfa özel kulüpte zaten nötrdür.
ShareContent shareContentForClub(Map<String, dynamic> club, int communityId) {
  String? str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  return ShareContent(
    type: ShareType.club,
    id: communityId,
    title: str(club['name']),
    source: str(club['category']),
    imageUrl: str(club['logoUrl']) ?? str(club['coverUrl']),
    restricted: club['visibility'] == 'PRIVATE',
  );
}

/// "Kulübü paylaş": ortak paylaşım sayfası (mesaj kartı, bağlantıyı kopyala, sistem paylaşımı).
Future<void> shareClubSheet(BuildContext context, Session session, Map<String, dynamic> club, int communityId) =>
    showShareSheet(context, session, shareContentForClub(club, communityId));
