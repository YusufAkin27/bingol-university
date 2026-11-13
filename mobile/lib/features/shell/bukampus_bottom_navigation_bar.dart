import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../core/icons/bu_icons.dart';
import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/theme/bu_motion.dart';
import '../../core/theme/bu_sizes.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu_pressable.dart' show BuHaptic, BuPressable, buHaptic;

/// Alt gezinme (monokrom): ekranın altında yüzen yatay kapsül (yükseklik 68, yan boşluk 16, köşe 34). Yüzey OPAK:
/// light'ta beyaz, dark'ta koyu yüzey; ince kenarlık, blur/gradient/gölge/ışık YOK. Beş eşit bölüm: Ana Sayfa, Keşfet,
/// ortada Paylaş ([PremiumCreateButton], 58 dp, çubuğun üstünden 8 dp taşar), Sohbet (okunmamış varken nokta), Profil
/// (outline kullanıcı simgesi; fotoğraf DEĞİL).
///
/// Aktif sekme: tam kontrast simge (`navAccent`: light'ta siyah, dark'ta beyaz), altında kısa çizgi ve simgenin arkasında
/// düz `navAccent` %8 zemin (sekmeler arasında 220 ms `easeOutCubic` ile kayar, ziplama yok); pasif simge soluk gri.
///
/// Klavye açılınca çubuk gizlenir. Tam ekran videoda (`immersive`) her zaman koyu palet. "Animasyonları azalt":
/// tüm geçişler anlıktır. Yazı ölçeği etiketlerde en çok 1.15.
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

  /// Eski parametre: yüzey artık her zaman opaktır (yok sayılır).
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

  /// Yüzey her zaman opaktır (geriye uyum için korunur).
  static bool opaqueFallback(BuildContext context, {bool glass = true}) => true;

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

/// Gezinme çubuğunun düz tanımları (gölge/ışık YOK): aktif sekme zemini.
abstract final class NavigationGlowDecoration {
  /// Aktif sekmenin simgesi arkasındaki düz yumuşak zemin (pasif simgede YOK).
  static BoxDecoration activeTab(BuTokens t) => BoxDecoration(
        color: t.navAccent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(22),
      );
}

/// Opak kapsül: düz yüzey + ince kenarlık (blur, gradient, gölge yok).
class _GlassSurface extends StatelessWidget {
  const _GlassSurface({super.key, required this.tokens, required this.opaque});

  final BuTokens tokens;
  final bool opaque;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BukampusBottomNavigationBar.radius),
        color: t.navBase,
        border: Border.all(color: t.navBorder, width: BukampusBottomNavigationBar.borderWidth),
      ),
      child: const SizedBox.expand(),
    );
  }
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

/// Sohbet simgesinin sağ üstündeki küçük nokta (yalnız okunmamış varken oluşturulur).
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
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Transform.scale(scale: v.clamp(0.0, 1.15), child: Opacity(opacity: v.clamp(0.0, 1.0), child: child)),
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

/// Ortadaki Paylaş düğmesi: 58 dp düz `navAccent` daire, 30 dp "+" (gölge yok). Basılınca 0.95'e
/// küçülür, bırakınca normale döner; dokunuşta orta şiddette titreşim. Zıplama yok.
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
                  ),
                  child: SizedBox(
                    width: PremiumCreateButton.size,
                    height: PremiumCreateButton.size,
                    child: Center(child: Icon(BuIcons.plus, size: PremiumCreateButton.iconSize, color: t.onPr)),
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
