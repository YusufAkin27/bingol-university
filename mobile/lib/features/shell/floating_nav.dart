import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/motion/bu_count_up.dart' show BuPop;
import '../../core/theme.dart';
import '../../core/theme/bu_motion.dart';
import '../../core/theme/bu_sizes.dart';
import '../../widgets/bu_list.dart' show BuCountBadge;
import '../../widgets/bu_pressable.dart' show BuHaptic, BuPressable, buHaptic;
import '../chat/chatlist_widgets.dart' show ChatlistAvatar;
import '../../core/icons/bu_icons.dart';

/// Yüzen alt gezinme (Stitch ana sayfa v5, `docs/MOBILE_MOTION_TABS.md`): kenarlardan ve alttan 16 dp boşluklu,
/// 64 dp yüksekliğinde beyaz hap (ince `bd` kenarlık, çok hafif gölge). Beş öğe: Ana Sayfa, Keşfet, ortada "+"
/// (`prPressed` daire, çubuktan yukarı taşar), Sohbet (okunmamış rozeti), Profil (kullanıcının avatarı).
///
/// Seçili sekmede `soft` zeminli "kayan hap" ve yanında etiket görünür (diğerlerinde yalnız ikon). Sekme değişince
/// hap yeni sekmeye yayılarak kayar (220 ms, `AppMotion.standard`; genişlik etiket uzunluğuna göre uzar/kısalır),
/// ikon çizgiden doluya geçer (140 ms) ve 1.0 -> 1.08 -> 1.0 ölçeklenir, etiket 140 ms solarak açılır/kapanır.
/// "+" basılınca 80 ms'de 0.94'e küçülür, bırakınca 140 ms'de döner (zıplama/dönme yok). Rozet ilk belirişte
/// 140 ms ölçeklenir. "Animasyonları azalt" açıkken hepsi anlıktır. İçerik kaydırılırken çubuk sabit kalır.
///
/// Sınıf adı ve zorunlu parametreler eski gezinmeyle aynıdır (kabuk ve testler değişmeden kullanır). Klavye açılınca
/// çubuk gizlenir. Erişilebilirlik: her sekme tek düğüm ("Sohbet, 3 okunmamış", seçili durumu, "Tab 3 of 5").
/// Yazı ölçeği etiketlerde en çok 1.15'e sınırlanır (hap taşmasın).
class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.chatBadge,
    this.avatarUrl,
    this.avatarName,
    this.onPublish,
  });

  final VoidCallback? onPublish;

  final int index;
  final ValueChanged<int> onChanged;
  final ValueNotifier<int> chatBadge;

  /// Profil sekmesi avatarının fotoğraf adresi (yok/null: varsayılan profil görseli).
  final ValueListenable<String?>? avatarUrl;

  /// Varsayılan görselin renk varyantı için ad (aynı kişi her yerde aynı rengi alır).
  final String? avatarName;

  /// Çubuğun nominal içerik yüksekliği.
  static const double height = BuSize.nav;

  /// Çubuğun kenarlardan ve alttan dış boşluğu.
  static const double gap = BuSize.navGap;

  /// "+" dairesinin çubuğun üstüne taşan kısmı için ayrılan şeffaf pay (dokunma alanı içinde kalsın).
  static const double lift = 12;

  static const double _hPad = 6; // çubuk iç yan boşluğu
  static const double _plusSlot = 48; // "+" hücresi
  static const double _plusSize = 52; // "+" dairesi çapı
  static const double _plusRise = 10; // dairenin çubuktan yukarı taşması
  static const double _minItem = 44; // seçili olmayan sekme hücresi (en az)
  static const double _maxSelected = 118; // seçili sekme hapı (en çok)
  static const double _pillHeight = 40;
  static const double _icon = 22;
  static const double _avatar = 22; // avatar çapı (halka dışı)

  static const _outline = [BuIcons.home, BuIcons.discover, BuIcons.chat, BuIcons.users];
  static const _filled = [BuIcons.homeFilled, BuIcons.discoverFilled, BuIcons.chatFilled, BuIcons.usersFilled];

  static List<String> _labels(BuildContext context) {
    final l = context.l10n;
    return [l.navHome, l.navDiscover, l.navChat, l.navClubs, l.navProfile];
  }

  @override
  Widget build(BuildContext context) {
    // Klavye açıkken çubuk yüzmez: yumuşakça kapanır (içerik alanı genişler).
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnimatedSize(
      duration: AppMotion.of(context, AppMotion.fast),
      curve: AppMotion.standard,
      alignment: Alignment.bottomCenter,
      child: keyboard ? const SizedBox(width: double.infinity) : _bar(context),
    );
  }

  Widget _bar(BuildContext context) {
    final t = context.bu;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = StadiumBorder(
        side: BorderSide(color: dark ? t.onMedia.withValues(alpha: .10) : t.bd));
    final surface = dark ? t.sf3 : t.sf;
    final shadows = dark
        ? [BoxShadow(color: t.scrim.withValues(alpha: .32), blurRadius: 20, offset: const Offset(0, 6))]
        : [BoxShadow(color: t.shadow.withValues(alpha: .08), blurRadius: 16, offset: const Offset(0, 4))];
    final slots = onPublish == null ? const [0, 1, 2, 3, 4] : const [0, 1, -1, 2, 4];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: gap),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(gap, 0, gap, 0),
        child: SizedBox(
          height: height + lift,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Cam yüzey: yalnız çubuğun kendisi (taşan "+" bunun dışında, üst katmanda).
              Positioned(
                top: lift,
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  key: const ValueKey('nav-pill'),
                  decoration: ShapeDecoration(color: surface, shape: shape, shadows: shadows),
                ),
              ),
              Positioned.fill(
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.15,
                  child: _NavRow(
                    index: index,
                    slots: slots,
                    labels: _labels(context),
                    onChanged: onChanged,
                    onPublish: onPublish,
                    chatBadge: chatBadge,
                    avatarUrl: avatarUrl,
                    avatarName: avatarName,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _chatIndex = 2; // AppTab.chat (döngüsel içe aktarmayı önlemek için)

/// Hücre yerleşimi: her slotun başlangıcı ve genişliği + seçili hapın en geniş hâli.
class _NavGeometry {
  _NavGeometry(double inner, List<int> slots, int selected) {
    final hasPlus = slots.contains(-1);
    final tabs = slots.where((i) => i >= 0).length;
    final remaining = inner - (hasPlus ? FloatingNav._plusSlot : 0);
    final others = tabs - 1;
    // Seçili hap, kalan alanın izin verdiği kadar (en çok 118) genişler; diğerleri en az 44 dp kalır.
    maxSelected = (remaining - others * FloatingNav._minItem).clamp(FloatingNav._minItem, FloatingNav._maxSelected).toDouble();
    final hasSel = selected >= 0 && slots.contains(selected);
    final tabW = hasSel ? (remaining - maxSelected) / others : remaining / tabs;
    var x = 0.0;
    for (final i in slots) {
      final w = i == -1 ? FloatingNav._plusSlot : (hasSel && i == selected ? maxSelected : tabW);
      lefts.add(x);
      widths.add(w);
      x += w;
    }
  }

  final lefts = <double>[];
  final widths = <double>[];
  late final double maxSelected;
}

/// Hücreleri ve kayan hapı yerleştirir; seçim değişince hepsi aynı süre/eğriyle (220 ms, standard) animasyonlanır.
class _NavRow extends StatefulWidget {
  const _NavRow({
    required this.index,
    required this.slots,
    required this.labels,
    required this.onChanged,
    required this.chatBadge,
    this.onPublish,
    this.avatarUrl,
    this.avatarName,
  });

  final int index;
  final List<int> slots;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  final ValueNotifier<int> chatBadge;
  final VoidCallback? onPublish;
  final ValueListenable<String?>? avatarUrl;
  final String? avatarName;

  @override
  State<_NavRow> createState() => _NavRowState();
}

class _NavRowState extends State<_NavRow> {
  /// Hap son seçili konumda kalır (seçili sekme çubukta yoksa yalnızca solar).
  int _pillSlot = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dur = AppMotion.of(context, AppMotion.normal);
    final slots = widget.slots;
    final selPos = slots.indexOf(widget.index);
    if (selPos >= 0) _pillSlot = selPos;
    return LayoutBuilder(builder: (context, c) {
      final geo = _NavGeometry(c.maxWidth - 2 * FloatingNav._hPad, slots, widget.index);
      final labelMax = geo.maxSelected - 16 - FloatingNav._icon - 4;
      const top = FloatingNav.lift;
      const pillTop = top + (FloatingNav.height - FloatingNav._pillHeight) / 2;
      Widget cell(int pos, Widget child) => AnimatedPositionedDirectional(
            duration: dur,
            curve: AppMotion.standard,
            start: FloatingNav._hPad + geo.lefts[pos],
            width: geo.widths[pos],
            top: top,
            height: FloatingNav.height,
            child: child,
          );
      return Stack(
        clipBehavior: Clip.none,
        children: [
          // Kayan hap: seçili hücrenin arkasında; hücrelerle birlikte genişler/daralır.
          AnimatedPositionedDirectional(
            duration: dur,
            curve: AppMotion.standard,
            start: FloatingNav._hPad + geo.lefts[_pillSlot],
            width: geo.widths[_pillSlot],
            top: pillTop,
            height: FloatingNav._pillHeight,
            child: ExcludeSemantics(
              child: AnimatedOpacity(
                duration: AppMotion.of(context, AppMotion.fast),
                opacity: selPos >= 0 ? 1 : 0,
                child: DecoratedBox(
                  key: const ValueKey('nav-indicator'),
                  decoration: ShapeDecoration(color: t.soft, shape: const StadiumBorder()),
                ),
              ),
            ),
          ),
          for (var pos = 0; pos < slots.length; pos++)
            if (slots[pos] == -1)
              AnimatedPositionedDirectional(
                duration: dur,
                curve: AppMotion.standard,
                start: FloatingNav._hPad + geo.lefts[pos] + (FloatingNav._plusSlot - FloatingNav._plusSize) / 2,
                width: FloatingNav._plusSize,
                top: top - FloatingNav._plusRise,
                height: FloatingNav._plusSize,
                child: _PlusButton(onPublish: widget.onPublish),
              )
            else
              cell(
                pos,
                _NavItem(
                  key: ValueKey('nav-${slots[pos]}'),
                  position: pos,
                  selected: slots[pos] == widget.index,
                  label: widget.labels[slots[pos]],
                  labelMax: labelMax,
                  onTap: () {
                    if (slots[pos] != widget.index) buHaptic(BuHaptic.selection);
                    widget.onChanged(slots[pos]);
                  },
                  outline: slots[pos] < 4 ? FloatingNav._outline[slots[pos]] : (widget.onPublish == null ? null : BuIcons.user),
                  filled: slots[pos] < 4 ? FloatingNav._filled[slots[pos]] : null,
                  badge: slots[pos] == _chatIndex ? widget.chatBadge : null,
                  avatarUrl: slots[pos] == 4 ? widget.avatarUrl : null,
                  avatarName: widget.avatarName,
                ),
              ),
        ],
      );
    });
  }
}

/// Ortadaki "+" düğmesi: `prPressed` daire; basınca 80 ms'de 0.94'e küçülür, bırakınca 140 ms'de döner.
class _PlusButton extends StatefulWidget {
  const _PlusButton({this.onPublish});

  final VoidCallback? onPublish;

  @override
  State<_PlusButton> createState() => _PlusButtonState();
}

class _PlusButtonState extends State<_PlusButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final pressed = _down && !BuMotion.reduced(context);
    return Semantics(
      button: true,
      label: l.discoverCompose,
      onTap: widget.onPublish,
      child: Tooltip(
        message: l.discoverCompose,
        excludeFromSemantics: true,
        child: ExcludeSemantics(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _set(true),
            onPointerUp: (_) => _set(false),
            onPointerCancel: (_) => _set(false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPublish,
              child: AnimatedScale(
                scale: pressed ? .94 : 1,
                duration: pressed ? AppMotion.instant : AppMotion.fast,
                curve: AppMotion.standard,
                child: DecoratedBox(
                  key: const ValueKey('nav-publish'),
                  decoration: BoxDecoration(
                    color: t.prPressed,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: t.prPressed.withValues(alpha: .22), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Center(child: Icon(BuIcons.plus, size: 26, color: t.onPr)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tek sekme: simge (Profil'de avatar) + yalnız seçiliyken etiket; tüm hücre dokunma alanıdır (en az 44 x 64 dp).
class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.position,
    required this.selected,
    required this.label,
    required this.labelMax,
    required this.onTap,
    this.outline,
    this.filled,
    this.badge,
    this.avatarUrl,
    this.avatarName,
  });

  final int position;
  final bool selected;
  final String label;

  /// Etiketin sığabileceği en geniş alan (seçili hap genişliği - iç boşluk - simge); sığmazsa küçülür.
  final double labelMax;
  final VoidCallback onTap;
  final IconData? outline;
  final IconData? filled;
  final ValueNotifier<int>? badge;
  final ValueListenable<String?>? avatarUrl;
  final String? avatarName;

  bool get _isProfile => outline == null || filled == null;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final color = selected ? t.onSoft : t.mut;
    final unread = badge;
    Widget glyph = _isProfile ? _profile(context, t) : _icon(context, color);
    if (unread != null) glyph = _withBadge(context, glyph, unread);
    final style = (tx.labelMedium ?? const TextStyle()).copyWith(fontSize: 12, height: 1.2, fontWeight: FontWeight.w600, color: t.onSoft);
    final visual = ExcludeSemantics(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              glyph,
              // Etiket: 140 ms solarak (60 ms gecikmeli) açılır/kapanır; genişlik hapla aynı eğriyle değişir.
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: selected ? 1 : 0),
                duration: AppMotion.of(context, AppMotion.normal),
                curve: AppMotion.standard,
                builder: (context, v, child) => v <= 0 && !selected
                    ? const SizedBox.shrink()
                    : ClipRect(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor: v,
                          child: Opacity(opacity: ((v - .3) / .7).clamp(0.0, 1.0), child: child),
                        ),
                      ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: labelMax < 0 ? 0 : labelMax),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label, maxLines: 1, softWrap: false, style: style),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final tab = MaterialLocalizations.of(context).tabLabel(tabIndex: position + 1, tabCount: 5);
    final Widget item = BuPressable(onTap: onTap, scale: .95, child: visual);
    // Ekran okuyucu: tek düğüm; rozet metni sekme etiketine eklenir ("Sohbet, 3 okunmamış").
    if (unread != null) {
      return ValueListenableBuilder<int>(
        valueListenable: unread,
        builder: (c, n, _) => _semantic(
          n > 0 && !selected ? '$label, ${c.l10n.p18NavUnread(n > 99 ? '99+' : '$n')}' : label,
          tab,
          item,
        ),
      );
    }
    return _semantic(label, tab, item);
  }

  Widget _semantic(String text, String hint, Widget child) => Semantics(
        container: true,
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: text,
        hint: hint,
        onTap: onTap,
        child: ExcludeSemantics(child: child),
      );

  Widget _icon(BuildContext context, Color color) {
    return _IconPop(
      selected: selected,
      child: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.fast),
        child: Icon(selected ? filled : outline, key: ValueKey(selected), size: FloatingNav._icon, color: color),
      ),
    );
  }

  Widget _profile(BuildContext context, BuTokens t) {
    final dur = AppMotion.of(context, AppMotion.fast);
    final source = avatarUrl;
    Widget avatar(String? url) => ChatlistAvatar(name: avatarName ?? '', url: url, size: FloatingNav._avatar, circle: true);
    return _IconPop(
      selected: selected,
      child: AnimatedContainer(
        duration: dur,
        curve: AppMotion.standard,
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? t.onSoft : t.mut.withValues(alpha: .45), width: selected ? 2 : 1.25),
        ),
        child: source == null
            ? avatar(null)
            : ValueListenableBuilder<String?>(valueListenable: source, builder: (_, url, __) => avatar(url)),
      ),
    );
  }

  Widget _withBadge(BuildContext context, Widget glyph, ValueNotifier<int> badge) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        glyph,
        PositionedDirectional(
          end: -12,
          top: -8,
          child: ValueListenableBuilder<int>(
            valueListenable: badge,
            builder: (_, n, __) {
              final show = n > 0 && !selected;
              return ExcludeSemantics(
                child: AnimatedScale(
                  scale: show ? 1 : 0,
                  duration: AppMotion.of(context, AppMotion.fast),
                  curve: Curves.easeOutBack,
                  child: n > 0 ? BuPop(trigger: n, child: BuCountBadge(n, key: const ValueKey('nav-badge'))) : const SizedBox.shrink(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Seçilince ölçek 1.0 -> 1.08 -> 1.0 (220 ms); seçimden çıkınca ya da "animasyonları azalt" açıkken oynamaz.
class _IconPop extends StatefulWidget {
  const _IconPop({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  State<_IconPop> createState() => _IconPopState();
}

class _IconPopState extends State<_IconPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.normal);
  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08).chain(CurveTween(curve: AppMotion.enter)), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0).chain(CurveTween(curve: AppMotion.standard)), weight: 50),
  ]);

  @override
  void didUpdateWidget(_IconPop old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected && !BuMotion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale.animate(_c), child: widget.child);
}
