import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/locale_controller.dart';
import '../profile/profil_widgets.dart';

/// Ayarlar > Ana ekran widgetları: yalnız metin (önizleme görseli yok). Widget nasıl eklenir, ne gösterir, gizlilik.
class WidgetsInfoPage extends StatelessWidget {
  const WidgetsInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    Widget head(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
          child: Text(s, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
        );
    Widget para(String s) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(s, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w400, color: t.mut, height: 1.45)),
        );
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          ProfilTopBar(title: l.widgetsInfoTitle),
          Expanded(
            child: ListView(
              key: const ValueKey('widgets-info'),
              padding: EdgeInsets.only(top: 4, bottom: MediaQuery.paddingOf(context).bottom + 32),
              children: [
                para(l.widgetsIntro),
                head(l.widgetsListTitle),
                para(l.widgetsList),
                head(l.widgetsIosTitle),
                para(l.widgetsIosSteps),
                head(l.widgetsAndroidTitle),
                para(l.widgetsAndroidSteps),
                head(l.widgetsRefreshTitle),
                para(l.widgetsRefresh),
                head(l.widgetsPrivacyTitle),
                para(l.widgetsPrivacy),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
