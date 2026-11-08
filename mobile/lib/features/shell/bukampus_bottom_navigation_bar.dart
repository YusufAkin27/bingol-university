import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../core/icons/bu_icons.dart';
import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/theme/bu_motion.dart';
import '../../core/theme/bu_sizes.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu_pressable.dart' show BuHaptic, BuPressable, buHaptic;

/// Alt gezinme "SOFT GLOW PREMIUM": ekranın altında yüzen yatay kapsül (yükseklik 68, yan boşluk 16, köşe 34).
/// Koyu yarı saydam cam yüzey (yalnız çubuk alanında, sigma 10), ince kırmızımsı kenarlık (0.8) ve çok hafif kırmızı
/// ışık yansıması. Beş eşit bölüm: Ana Sayfa, Keşfet, ortada Paylaş ([PremiumCreateButton], 58 dp, çubuğun üstünden 8 dp
/// taşar), Sohbet (okunmamış varken kırmızı nokta), Profil (outline kullanıcı simgesi; fotoğraf DEĞİL).
///
/// Kırmızı YALNIZ bu çubukta kullanılır (kullanıcı kararı 2026-11-07; renkler `BuTokens.nav*`). Aktif sekme: kırmızı
/// simge + etiket, altında ince kısa çizgi ve simgenin arkasında hafif kırmızı yumuşak zemin; pasif simgede ışık YOK.
///
/// **Kayan zemin kararı:** eski "kayan hap" korunur ama yeni dile uyarlandı: aktif simgenin arkasında çok hafif
/// kırmızı yumuşak zemin/ışık sekmeler arasında 220 ms `easeOutCubic` ile kayar (aşım/ziplama yok, sürükle-esnet
/// kaldırıldı). Sayfa kaydırma ve sekme durumu korunması kabukta (`app_shell.dart`) kalır, burada değişmedi.
///
/// Klavye açılınca çubuk gizlenir (içeriği/alt eylem çubuğunu itmez). Tam ekran videoda (`immersive`) her zaman koyu
/// palet. "Animasyonları azalt": tüm geçişler anlıktır. Yazı ölçeği etiketlerde en çok 1.15.
class BukampusBottomNavigationBar extends StatelessWidget {
  const BukampusBottomNavigationBar({
    super.key,
    required this.index,
    required this.onChanged,
    required this.chatBadge,
    this.onPublish,
    this.immersive = false,
    this.glass = true,
    this.profileAvatar,
  });

  final int index;
  final ValueChanged<int> onChanged;

  /// Okunmamış sayaç: > 0 iken Sohbet simgesinde kırmızı nokta görünür.
  final ValueListenable<int> chatBadge;

  /// Ortadaki Paylaş düğmesi (null ise düğme ve boş orta bölüm yok: beş sekme yan yana).
  final VoidCallback? onPublish;

  /// Tam ekran video (Reels) üstünde: koyu palet.
  final bool immersive;

  /// Cam (bulanıklık) açık mı; false: opak yedek.
  final bool glass;

  /// Profil sekmesinin simgesi yerine kişinin fotoğrafı (boyut verilir); null ise çizgi kullanıcı simgesi.
  final Widget Function(double size)? profileAvatar;

  /// Çubuğun yüksekliği.
  static const double height = BuSize.nav;

  /// Çubuğun yan boşluğu.
  static const double gap = BuSize.navGap;

  /// Çubuk altı boşluk (SafeArea'nın üstüne eklenir).
  static const double bottomGap = 10;

  /// Paylaş düğmesinin çubuğun üst kenarından dışarı taşması.
  static const double lift = 8;

  static const double radius = 34;
  static const double borderWidth = .8;
  static const double iconSize = 28.8; // 24 x 1,2 (kullanıcı kararı 2026-11-08)
  static const double _hPad = 8;

  /// Beş sekme (Kulüpler yalnız Paylaş düğmesi yokken çubukta görünür). `tab` = `AppTab` dizini.
  static const _items = <BukampusNavItem>[
    BukampusNavItem(tab: 0, icon: BuIcons.home),
    BukampusNavItem(tab: 1, icon: BuIcons.discover),
    BukampusNavItem(tab: 2, icon: BuIcons.chat, hasBadge: true),
    BukampusNavItem(tab: 3, icon: BuIcons.users),
    BukampusNavItem(tab: 4, icon: BuIcons.user),
  ];

  static String _label(AppLocalizations l, int tab) => switch (tab) {
        0 => l.navHome,
        1 => l.navDiscover,
        2 => l.navChat,
        3 => l.navClubs,
        _ => l.navProfile,
      };

  /// Cam yerine opak yüzey: kapalı anahtar ya da yüksek karşıtlık.
  static bool opaqueFallback(BuildContext context, {bool glass = true}) =>
      !glass || (MediaQuery.maybeOf(context)?.highContrast ?? false);

  @override
  Widget build(BuildContext context) {
    // Klavye açıkken çubuk yüzmez: yumuşakça kapanır (içerik alanı genişler).
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnimatedSize(
      duration: AppMotion.of(context, AppMotion.fast),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: keyboard ? const SizedBox(width: double.infinity) : _bar(context),
    );
  }

  Widget _bar(BuildContext context) {
    final t = immersive ? BuTokens.dark : context.bu;
    final opaque = opaqueFallback(context, glass: glass);
    final bottom = MediaQuery.paddingOf(context).bottom + bottomGap;
    final l = context.l10n;
    // Sıra: Paylaş varken [0,1,+,2,4], yoksa 5 sekme.
    final order = onPublish == null ? const [0, 1, 2, 3, 4] : const [0, 1, -1, 2, 4];
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(gap, 0, gap, bottom),
        child: SizedBox(
          height: height + lift,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.15,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Cam yüzey: değişmeyen alt ağaç (const), sekme değişince yeniden kurulmaz.
                Positioned(
                  top: lift,
                  left: 0,
                  right: 0,
                  height: height,
                  child: _GlassSurface(key: const ValueKey('nav-pill'), tokens: t, opaque: opaque),
                ),
                Positioned(
                  top: lift,
                  left: 0,
                  right: 0,
                  height: height,
                  child: _TabsLayer(
                    tokens: t,
                    order: order,
                    selected: index,
                    onChanged: onChanged,
                    chatBadge: chatBadge,
                    labelOf: (tab) => _label(l, tab),
                    profileAvatar: profileAvatar,
                    tabCount: order.where((e) => e >= 0).length,
                  ),
                ),
                if (onPublish != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Center(child: PremiumCreateButton(tokens: t, onPressed: onPublish!)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Alt gezinme öğesi tanımı (Flutter'ın `NavigationBarItem`/`NavigationDestination` sınıflarından bağımsız).
@immutable
class BukampusNavItem {
  const BukampusNavItem({required this.tab, required this.icon, this.hasBadge = false});

  /// `AppTab` dizini.
  final int tab;
  final IconData icon;

  /// Okunmamış noktası taşır mı (Sohbet).
  final bool hasBadge;
}

/// Gezinme çubuğunun gölge/ışık tanımları (tek yer): çubuk dış yansıması, Paylaş arkası ışık, aktif sekme zemini.
abstract final class NavigationGlowDecoration {
  static bool _dark(BuTokens t) => t.navBase.computeLuminance() < .5;

  /// Çubuğun çevresinde çok hafif kırmızı dış yansıma + zemine oturan yumuşak gölge.
  static List<BoxShadow> bar(BuTokens t) => [
        BoxShadow(color: t.navGlow, blurRadius: 22, offset: const Offset(0, 4)),
        BoxShadow(color: t.shadow.withValues(alpha: _dark(t) ? .28 : .07), blurRadius: 16, offset: const Offset(0, 6)),
      ];

  /// Paylaş düğmesinin arkasındaki küçük kırmızı ışık (basılıyken biraz güçlenir).
  static List<BoxShadow> button(BuTokens t, {bool pressed = false}) => [
        BoxShadow(
          color: t.navAccent.withValues(alpha: pressed ? .36 : .22),
          blurRadius: 18,
          spreadRadius: 1,
          offset: const Offset(0, 4),
        ),
      ];

  /// Aktif sekmenin simgesi arkasındaki çok hafif yumuşak zemin + ışık (pasif simgede YOK).
  static BoxDecoration activeTab(BuTokens t) => BoxDecoration(
        color: t.navAccent.withValues(alpha: _dark(t) ? .10 : .07),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: t.navGlow, blurRadius: 14)],
      );
}

/// Cam kapsül: yalnız çubuk alanında hafif bulanıklık (sigma 10), yarı saydam yüzey, ince kenarlık, üstte hafif yansıma.
class _GlassSurface extends StatelessWidget {
  const _GlassSurface({super.key, required this.tokens, required this.opaque});

  final BuTokens tokens;
  final bool opaque;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final r = BorderRadius.circular(BukampusBottomNavigationBar.radius);
    // Zemin rengi ve parlama AYRI katman: BoxDecoration'da gradient varken color çizilmez (shader rengi ezer);
    // tek katmanda cam çubuk beyaz değil şeffaf koyu görünüyordu.
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        color: opaque ? t.navBase : t.navGlass,
        border: Border.all(color: t.navBorder, width: BukampusBottomNavigationBar.borderWidth),
      ),
      child: opaque
          ? const SizedBox.expand()
          : DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: r,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, .5],
                  colors: [t.onMedia.withValues(alpha: t.navBase.computeLuminance() < .5 ? .05 : .32), t.onMedia.withValues(alpha: 0)],
                ),
              ),
              child: const SizedBox.expand(),
            ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Dış ışık/gölge yalnız çubuğun DIŞINDA çizilir: yarı saydam camın içini kırmızıya boyamaz.
        Positioned.fill(
          child: ClipPath(
            clipper: const _OutsideRRectClipper(BukampusBottomNavigationBar.radius),
            child: DecoratedBox(decoration: BoxDecoration(borderRadius: r, boxShadow: NavigationGlowDecoration.bar(t))),
          ),
        ),
        Positioned.fill(child: _glass(r, surface)),
      ],
    );
  }

  Widget _glass(BorderRadius r, Widget surface) {
    return ClipRRect(
      borderRadius: r,
      child: opaque ? surface : BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: surface),
    );
  }
}

/// Yuvarlatılmış dikdörtgenin dışını bırakan kırpıcı (gölge iç yüzeyi lekelemesin).
class _OutsideRRectClipper extends CustomClipper<Path> {
  const _OutsideRRectClipper(this.radius);

  final double radius;

  @override
  Path getClip(Size size) {
    const pad = 80.0;
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTRB(-pad, -pad, size.width + pad, size.height + pad))
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
  }

  @override
  bool shouldReclip(_OutsideRRectClipper old) => old.radius != radius;
}

/// Sekme hücreleri + aktif simge arkasında kayan yumuşak zemin.
class _TabsLayer extends StatelessWidget {
  const _TabsLayer({
    required this.tokens,
    required this.order,
    required this.selected,
    required this.onChanged,
    required this.chatBadge,
    required this.labelOf,
    required this.tabCount,
    this.profileAvatar,
  });

  final BuTokens tokens;
  final List<int> order;
  final int selected;
  final ValueChanged<int> onChanged;
  final ValueListenable<int> chatBadge;
  final String Function(int tab) labelOf;
  final int tabCount;
  final Widget Function(double size)? profileAvatar;

  @override
  Widget build(BuildContext context) {
    final reduced = BuMotion.reduced(context);
    final dur = reduced ? Duration.zero : const Duration(milliseconds: 220);
    final selPos = order.indexOf(selected);
    return LayoutBuilder(builder: (context, c) {
      const hPad = BukampusBottomNavigationBar._hPad;
      final cellW = (c.maxWidth - 2 * hPad) / order.length;
      final glowW = (cellW - 4).clamp(40.0, 60.0);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          if (selPos >= 0)
            AnimatedPositionedDirectional(
              duration: dur,
              curve: Curves.easeOutCubic,
              start: hPad + selPos * cellW + (cellW - glowW) / 2,
              width: glowW,
              top: 7,
              height: BukampusBottomNavigationBar.height - 14,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey('nav-indicator'),
                  decoration: NavigationGlowDecoration.activeTab(tokens),
                ),
              ),
            ),
          for (var pos = 0; pos < order.length; pos++)
            if (order[pos] >= 0)
              PositionedDirectional(
                start: hPad + pos * cellW,
                width: cellW,
                top: 0,
                bottom: 0,
                child: _NavTab(
                  key: ValueKey('nav-${order[pos]}'),
                  item: BukampusBottomNavigationBar._items[order[pos]],
                  tokens: tokens,
                  label: labelOf(order[pos]),
                  position: pos,
                  count: tabCount,
                  selected: order[pos] == selected,
                  badge: BukampusBottomNavigationBar._items[order[pos]].hasBadge ? chatBadge : null,
                  profileAvatar: profileAvatar,
                  onTap: () {
                    if (order[pos] != selected) buHaptic(BuHaptic.selection);
                    onChanged(order[pos]);
                  },
                ),
              ),
        ],
      );
    });
  }
}

/// Tek sekme: simge (24, çizgi) + etiket + aktifte ince çizgi; tüm hücre dokunma alanıdır.
class _NavTab extends StatelessWidget {
  const _NavTab({
    super.key,
    required this.item,
    required this.tokens,
    required this.label,
    required this.position,
    required this.count,
    required this.selected,
    required this.onTap,
    this.badge,
    this.profileAvatar,
  });

  final BukampusNavItem item;
  final BuTokens tokens;
  final String label;
  final int position;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final ValueListenable<int>? badge;
  final Widget Function(double size)? profileAvatar;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final dur = AppMotion.of(context, const Duration(milliseconds: 200));
    final iconColor = selected ? t.navAccent : t.navIconIdle;

    final avatarBuilder = item.tab == 4 ? profileAvatar : null;
    Widget icon = AnimatedScale(
      scale: selected ? 1.05 : 1,
      duration: dur,
      curve: Curves.easeOutCubic,
      child: avatarBuilder != null
          // Profil sekmesi: kişinin fotoğrafı; aktifken ince vurgu halkası.
          ? AnimatedContainer(
              key: const ValueKey('nav-profile-avatar'),
              duration: dur,
              curve: Curves.easeOutCubic,
              width: BukampusBottomNavigationBar.iconSize,
              height: BukampusBottomNavigationBar.iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? t.navAccent : Colors.transparent, width: 1.5),
              ),
              child: ClipOval(child: avatarBuilder(BukampusBottomNavigationBar.iconSize - 3)),
            )
          : TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: iconColor),
              duration: dur,
              curve: Curves.easeOutCubic,
              builder: (_, c, __) => Icon(item.icon, size: BukampusBottomNavigationBar.iconSize, color: c),
            ),
    );
    final unread = badge;
    if (unread != null) {
      icon = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          icon,
          PositionedDirectional(
            end: -3,
            top: -2,
            child: ValueListenableBuilder<int>(
              valueListenable: unread,
              builder: (ctx, n, _) => n > 0 ? _UnreadDot(tokens: t) : const SizedBox.shrink(),
            ),
          ),
        ],
      );
    }

    final visual = ExcludeSemantics(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          // Etiket çizilmez (kullanıcı kararı 2026-11-08): ekran okuyucu etiketi [semantic] ile korunur.
          const SizedBox(height: 5),
          AnimatedContainer(
            key: selected ? const ValueKey('nav-underline') : null,
            duration: dur,
            curve: Curves.easeOutCubic,
            width: selected ? 14 : 0,
            height: 2,
            decoration: BoxDecoration(color: t.navAccent, borderRadius: BorderRadius.circular(1)),
          ),
        ],
      ),
    );

    final hint = MaterialLocalizations.of(context).tabLabel(tabIndex: position + 1, tabCount: count);
    Widget semantic(String text) => Semantics(
          container: true,
          button: true,
          selected: selected,
          inMutuallyExclusiveGroup: true,
          label: text,
          hint: hint,
          onTap: onTap,
          child: ExcludeSemantics(child: BuPressable(onTap: onTap, scale: .96, pressedOpacity: 1, child: Center(child: visual))),
        );
    if (unread != null) {
      return ValueListenableBuilder<int>(
        valueListenable: unread,
        builder: (c, n, _) => semantic(n > 0 && !selected ? '$label, ${c.l10n.p18NavUnread(n > 99 ? '99+' : '$n')}' : label),
      );
    }
    return semantic(label);
  }
}

/// Sohbet simgesinin sağ üstündeki küçük kırmızı nokta (yalnız okunmamış varken oluşturulur).
class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.tokens});

  final BuTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: AppMotion.of(context, AppMotion.fast),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          key: const ValueKey('nav-dot'),
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: t.navAccentHi,
            shape: BoxShape.circle,
            border: Border.all(color: t.navBase, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Ortadaki Paylaş düğmesi: 58 dp kırmızı daire, 30 dp beyaz "+", arkasında hafif kırmızı ışık. Basılınca 0.95'e
/// küçülür ve ışık biraz güçlenir, bırakınca normale döner; dokunuşta orta şiddette titreşim. Zıplama yok.
class PremiumCreateButton extends StatefulWidget {
  const PremiumCreateButton({super.key, required this.tokens, required this.onPressed});

  final BuTokens tokens;
  final VoidCallback onPressed;

  static const double size = 58;
  static const double iconSize = 30;

  @override
  State<PremiumCreateButton> createState() => _PremiumCreateButtonState();
}

class _PremiumCreateButtonState extends State<PremiumCreateButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final label = context.l10n.discoverCompose;
    final pressed = _down && !BuMotion.reduced(context);
    return Semantics(
      button: true,
      label: label,
      onTap: widget.onPressed,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: ExcludeSemantics(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _set(true),
            onPointerUp: (_) => _set(false),
            onPointerCancel: (_) => _set(false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                buHaptic(BuHaptic.medium);
                widget.onPressed();
              },
              child: AnimatedScale(
                scale: pressed ? .95 : 1,
                duration: pressed ? AppMotion.instant : AppMotion.fast,
                curve: Curves.easeOutCubic,
                child: DecoratedBox(
                  key: const ValueKey('nav-publish'),
                  decoration: BoxDecoration(
                    color: t.navAccent,
                    shape: BoxShape.circle,
                    boxShadow: NavigationGlowDecoration.button(t, pressed: pressed),
                  ),
                  child: SizedBox(
                    width: PremiumCreateButton.size,
                    height: PremiumCreateButton.size,
                    child: Center(child: Icon(BuIcons.plus, size: PremiumCreateButton.iconSize, color: t.onMedia)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
