import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/locale_controller.dart';
import '../profile/profil_widgets.dart';
import 'widget_strings.dart';
import 'widget_sync_service.dart';

/// Ayarlar > Ana ekran widgetları: widget nasıl eklenir, ne gösterir, gizlilik + "kişisel ayrıntıları gizle" anahtarı.
class WidgetsInfoPage extends StatefulWidget {
  const WidgetsInfoPage({super.key});

  @override
  State<WidgetsInfoPage> createState() => _WidgetsInfoPageState();
}

class _WidgetsInfoPageState extends State<WidgetsInfoPage> {
  bool _hide = false;

  @override
  void initState() {
    super.initState();
    WidgetSyncService.instance.hidePersonal().then((v) {
      if (mounted && v != _hide) setState(() => _hide = v);
    });
  }

  Future<void> _toggle(bool v) async {
    setState(() => _hide = v); // iyimser; kayıt hatası widget'ı bozmaz
    await WidgetSyncService.instance.setHidePersonal(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final ws = WidgetStrings.of(Localizations.localeOf(context).languageCode);
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
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const ValueKey('widgets-hide-personal'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  value: _hide,
                  onChanged: _toggle,
                  title: Text(ws['ui.hideTitle'], style: tx.bodyLarge!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
                  subtitle: Text(ws['ui.hideSub'], style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w400, color: t.mut, height: 1.45)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
