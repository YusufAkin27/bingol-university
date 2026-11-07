import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../widgets/widget_link.dart';

/// Kulüp derin bağlantısı: `bukampus://clubs/<id>` (gelen bağlantıyı [WidgetLink.parse] çözer ve kulüp sayfasını açar).
String clubShareLink(int communityId) => WidgetLink.club(communityId).uri;

/// Test kancası: sistem paylaşım sayfası çağrısı. Varsayılan `share_plus`.
@visibleForTesting
Future<void> Function(ShareParams params)? debugClubShare;

/// Kulübü sistem paylaşım sayfasıyla paylaşır (metin: kulüp adı + derin bağlantı).
Future<void> shareClub(BuildContext context, {required int communityId, required String name}) async {
  final text = context.l10n.clubShareMsg(name.trim(), clubShareLink(communityId));
  Analytics.instance.action('share', target: 'club');
  final p = ShareParams(text: text, subject: name.trim());
  await (debugClubShare ?? (x) => SharePlus.instance.share(x))(p);
}
