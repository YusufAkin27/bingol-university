import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'campus_geo.dart';
import 'campus_map_page.dart';
import 'campus_models.dart';
import 'campus_repository.dart';

/// Uygulama içi rota adı (derin bağlantı: `/campus-map`). Push yönlendirmesi (`PushRouter`) bu rotaya DOKUNMAZ;
/// yalnız uygulama içi gezinme kullanır.
const campusMapRouteName = '/campus-map';

/// Kampüs haritasını açar. [categoryHint]: "Yemekhane" gibi çip etiketi (eşleşen kategori seçilir);
/// [placeId]: açılışta seçili yer; [repository]: yalnız test için.
Future<void> openCampusMap(
  BuildContext context,
  Session session, {
  String? categoryHint,
  int? placeId,
  bool openSearch = false,
  CampusMapRepository? repository,
}) {
  return Navigator.of(context).push<void>(MaterialPageRoute(
    settings: const RouteSettings(name: campusMapRouteName),
    builder: (_) => CampusMapPage(
      repository: repository ?? ApiCampusMapRepository(session.api),
      categoryHint: categoryHint,
      initialPlaceId: placeId,
      openSearch: openSearch,
    ),
  ));
}

bool get _ios => defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;

/// Cihazın harita uygulamasında YOL TARİFİ açar. Yalnız hedef koordinat gönderilir (kullanıcı konumu eklenmez).
Future<void> openDirections(BuildContext context, CampusPlace p) => _launch(context, directionsUri(p.point, ios: _ios), fallback: directionsUri(p.point, ios: false));

/// "Haritada aç": yeri cihazın harita uygulamasında gösterir.
Future<void> openPlaceInMaps(BuildContext context, CampusPlace p) => _launch(context, showOnMapUri(p.point, p.name, ios: _ios), fallback: directionsUri(p.point, ios: false));

Future<void> _launch(BuildContext context, Uri uri, {required Uri fallback}) async {
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && uri != fallback) ok = await launchUrl(fallback, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) BuToast.show(context, context.l10n.campusOpenFailed, kind: BuToastKind.error);
}

/// Paylaş: uygulamada başka yerde de olduğu gibi (haber) metin + bağlantı panoya kopyalanır.
Future<void> sharePlace(BuildContext context, CampusPlace p) async {
  final text = '${p.name} - BÜ Kampüs\n${shareUri(p.point)}';
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) BuToast.show(context, context.l10n.campusLinkCopied, kind: BuToastKind.success);
}
