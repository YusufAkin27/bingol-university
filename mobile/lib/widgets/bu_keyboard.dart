import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/theme/bu_motion.dart';
import 'bu_overlays.dart';

/// Klavye (ekran klavyesi) için ortak yardımcılar. Amaç: hiçbir Oluştur/Paylaş/Kaydet/Gönder düğmesi klavyenin
/// arkasında kalmasın, form her zaman kaydırılabilsin, klavye kolayca kapansın, çift boşluk (Scaffold + elle padding) olmasın.
///
/// Kural: `Scaffold.resizeToAvoidBottomInset` AÇIK kalır (gövde klavye kadar küçülür, `viewInsets` gövdede sıfırlanır);
/// gövdeye ayrıca `viewInsets` EKLENMEZ. Sabit alt eylem `Scaffold.bottomNavigationBar` olarak [BuFormActionBar] ile verilir
/// (ham `bottomNavigationBar` klavyenin ARKASINDA kalır; çubuk bunu kendi içinde çözer). Scaffold DIŞINDA (alt sayfa/diyalog)
/// boşluk [BuKeyboard.bottomPadding] ile eklenir.
abstract final class BuKeyboard {
  /// Klavyenin kapladığı alt yükseklik. Yalnız `viewInsets` bağımlılığı kurar: klavye animasyonunda tüm `MediaQuery`
  /// kullanıcıları değil yalnız bunu çağıran alt ağaç yeniden kurulur.
  static double inset(BuildContext context) => MediaQuery.viewInsetsOf(context).bottom;

  static bool isOpen(BuildContext context) => inset(context) > 0;

  /// Odağı bırakır, klavyeyi kapatır.
  static void dismiss([BuildContext? context]) {
    if (context != null) {
      FocusScope.of(context).unfocus();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  /// Odaklı alanı (veya [context]'in alt ağacındaki öğeyi) kaydırılabilir üst öğede görünür kılar. Klavye animasyonu bitince
  /// da çalışsın diye iki kare sonra tekrar dener. Kaydırılabilir üst yoksa sessizce çıkar.
  static void ensureVisible(BuildContext context, {double alignment = .85, Duration duration = const Duration(milliseconds: 220)}) {
    void run() {
      if (!context.mounted) return;
      if (Scrollable.maybeOf(context) == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: alignment,
        duration: BuMotion.of(context, duration),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      run();
      // Klavye animasyonu sürerken ölçü değişir; bittikten sonra bir kez daha hizala.
      Future<void>.delayed(const Duration(milliseconds: 280), run);
    });
  }

  /// Scaffold DIŞINDA (alt sayfa, özel katman) klavye için alt boşluk. Scaffold içinde KULLANMAYIN (çift boşluk).
  static EdgeInsets bottomPadding(BuildContext context, {double extra = 0}) =>
      EdgeInsets.only(bottom: inset(context) + extra);
}

/// Boş alana dokununca odağı bırakır (klavyeyi kapatır). Alt öğelerin kendi dokunuşlarını ENGELLEMEZ
/// (`HitTestBehavior.translucent`, yalnız tıklamayı dinler; kaydırma/sürükleme etkilenmez).
class BuTapOutsideUnfocus extends StatelessWidget {
  const BuTapOutsideUnfocus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        // Anlamsal düğüm üretmez: ekran okuyucuda "etiketsiz dokunma hedefi" oluşmasın.
        excludeFromSemantics: true,
        onTap: BuKeyboard.dismiss,
        child: child,
      );
}

/// Odak alanında ise (tipik: yeni eklenen satır) kaydırılabilir üst öğede görünür tutar.
class BuEnsureVisibleOnFocus extends StatelessWidget {
  const BuEnsureVisibleOnFocus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (has) {
          if (has) BuKeyboard.ensureVisible(context);
        },
        child: child,
      );
}

/// `Scaffold.bottomNavigationBar` içeriğini klavyenin hemen üstüne çıkarır: alta klavye yüksekliği kadar boşluk ekler ve alt
/// ağaçta `viewInsets.bottom` değerini sıfırlar (iç içe kullanımda çift boşluk oluşmaz). Ham `bottomNavigationBar` klavyenin
/// arkasında kalır; klavye açıkken görünmesi gereken her alt çubuk (yazma alanı, Kaydet) bununla sarılır.
class BuKeyboardLift extends StatelessWidget {
  const BuKeyboardLift({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: BuKeyboard.inset(context)),
        child: MediaQuery.removeViewInsets(context: context, removeBottom: true, child: child),
      );
}

/// Sabit alt eylem çubuğu: üstte ince çizgi, içinde tek (ya da birkaç) düğme. `Scaffold.bottomNavigationBar` olarak verilir.
///
/// DİKKAT: Scaffold `bottomNavigationBar`'ı ekranın en altına koyar, klavyenin üstüne TAŞIMAZ (klavye onu örter). Bu yüzden
/// çubuk kendi altına klavye yüksekliği kadar boşluk ekler: çubuk klavyenin hemen üstüne çıkar ve Scaffold gövdeyi çubuğun
/// üstüne sığdırır. Klavye açıkken `SafeArea` alt payı zaten sıfırdır (home indicator klavyenin altında kalır; çift boşluk yok).
class BuFormActionBar extends StatelessWidget {
  const BuFormActionBar({super.key, required this.child, this.top});

  final Widget child;

  /// Düğmenin üstünde isteğe bağlı satır (hata metni vb.).
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return BuKeyboardLift(
      child: Material(
        color: t.bg,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: t.bdSubtle))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [if (top != null) ...[top!, const SizedBox(height: 8)], child],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Klavye uyumlu form iskeleti: kaydırılabilir gövde (sürükleyince klavye kapanır, boşluğa dokununca odak bırakılır) +
/// klavyenin hemen üstünde yapışan alt eylem çubuğu. Gövde yüksekliği sabitlenmez; kısa ekranda kaydırılır.
class BuFormScaffold extends StatelessWidget {
  const BuFormScaffold({
    super.key,
    this.appBar,
    required this.children,
    this.action,
    this.actionTop,
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 24),
    this.controller,
  });

  final PreferredSizeWidget? appBar;
  final List<Widget> children;

  /// Sabit alt düğme (örn. `BuButton`); null ise çubuk çizilmez.
  final Widget? action;
  final Widget? actionTop;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: appBar,
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: action == null ? null : BuFormActionBar(top: actionTop, child: action!),
      // SizedBox.expand: Scaffold gövdeye gevşek kısıt verir; kısa formda kaydırma alanı küçülüp boşluğu ölü bırakmasın.
      body: BuTapOutsideUnfocus(
        child: SizedBox.expand(
          child: SingleChildScrollView(
            controller: controller,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: padding,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ),
    );
  }
}

/// Sayfa rotası değişince (itme/geri/değiştirme) odağı bırakır: önceki sayfadaki klavye yeni sayfada açık kalmaz.
/// Yalnız [PageRoute]; alt sayfa/diyalog (PopupRoute) odaklı alanı bozmaz (sohbet çubuğu vb.).
class BuFocusRouteObserver extends NavigatorObserver {
  void _release(Route<dynamic>? r) {
    if (r is! PageRoute) return;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _release(route);

  // Önceki sayfanın odağı didPush'ta bırakıldığı için geri dönüşte klavye kendiliğinden yeniden açılmaz.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _release(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _release(newRoute);
}

/// Klavye uyumlu form alt sayfası ([BuSheet] çerçevesi): `isScrollControlled`, güvenli alan, klavyeye göre küçülen
/// kaydırılabilir gövde, SABİT [actions] (klavyenin hemen üstünde), kapanınca odak temizlenir (klavye açık kalmaz).
Future<T?> showBuFormSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  String? subtitle,
  List<Widget>? actions,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  // Kapanışta odağı temizleme [BuSheet.show] içindedir.
  return BuSheet.show<T>(
    context,
    title: title,
    subtitle: subtitle,
    actions: actions,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    builder: (ctx) => BuTapOutsideUnfocus(child: builder(ctx)),
  );
}
