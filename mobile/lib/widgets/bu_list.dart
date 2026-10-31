import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/theme/bu_motion.dart';
import '../core/theme/bu_shape.dart';
import '../core/theme/bu_sizes.dart';
import 'bu_widgets.dart';

/// Bölüm başlığı: sol başlık (`titleMedium`) + sağda isteğe bağlı "Tümü" eylemi. Ekran okuyucuda başlık olarak okunur.
class BuSectionHeader extends StatelessWidget {
  const BuSectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 24, 12, 8),
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title, style: tx.titleMedium!.copyWith(color: t.ink))),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Sayı rozeti (okunmamış sayısı): 1-99, üstü "99+". 0 ise hiçbir şey çizmez. [muted] true: gri (sessize alınmış).
class BuCountBadge extends StatelessWidget {
  const BuCountBadge(this.count, {super.key, this.muted = false, this.max = 99});

  final int count;
  final bool muted;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final t = context.bu;
    final text = count > max ? '$max+' : '$count';
    return DecoratedBox(
      decoration: BoxDecoration(color: muted ? t.mut : t.pr, borderRadius: BuRadius.bPill),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall!
                      .copyWith(color: muted ? t.bg : t.onPr, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Genel liste satırı (M3 ListTile'ın marka sürümü): başa simge/avatar, başlık + alt metin, sona eylem/ok.
/// Satır en az 56 dp; dokunma dalgası kart köşesine uyar. Uzun başlık 2 satıra kadar sarar.
class BuListTile extends StatelessWidget {
  const BuListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.showChevron = false,
    this.danger = false,
    this.maxTitleLines = 2,
    this.padding = const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Seçili satır marka tonunda boyanır (çoklu seçim, geçerli sohbet).
  final bool selected;

  /// Sonda yön oku (RTL'de aynalanır).
  final bool showChevron;

  /// Silme/çıkış gibi yıkıcı eylem rengi.
  final bool danger;
  final int maxTitleLines;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final titleColor = danger ? t.danger : t.ink;
    return Material(
      color: selected ? t.soft : Colors.transparent,
      shape: selected ? BuRadius.rect(BuRadius.md) : const RoundedRectangleBorder(),
      clipBehavior: selected ? Clip.antiAlias : Clip.none,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          maxLines: maxTitleLines,
                          overflow: TextOverflow.ellipsis,
                          style: tx.bodyLarge!.copyWith(color: titleColor, fontWeight: FontWeight.w600)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.mut)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
                if (showChevron)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ayar satırı: yumuşak zeminli simge karosu + başlık (+ alt metin) + sağda değer/ok ya da anahtar.
/// Satırları [BuGroup] içinde dizin (`dividerIndent: 64`). Anahtarlı satır için [BuSettingsTile.toggle].
class BuSettingsTile extends StatelessWidget {
  const BuSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.tint,
  })  : switchValue = null,
        onSwitch = null;

  /// Anahtarlı (aç/kapat) ayar satırı. Satırın herhangi bir yerine dokunmak anahtarı çevirir.
  const BuSettingsTile.toggle({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.tint,
  })  : switchValue = value,
        onSwitch = onChanged,
        value = null,
        trailing = null,
        onTap = null,
        danger = false;

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Sağdaki soluk değer metni ("Türkçe", "Açık").
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  /// Simge karosu rengi (`context.bu.tint(i)`); null: marka tonu.
  final BuTint? tint;

  final bool? switchValue;
  final ValueChanged<bool>? onSwitch;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isSwitch = switchValue != null;
    final bg = danger ? cs.errorContainer : (tint?.bg ?? t.soft);
    final fg = danger ? t.danger : (tint?.fg ?? t.pr);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bSm),
                child: Icon(icon, size: 19, color: fg),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tx.bodyLarge!.copyWith(color: danger ? t.danger : t.ink, fontWeight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, maxLines: 3, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 10),
              Flexible(
                flex: 0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.mut)),
                ),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            if (isSwitch) ...[
              const SizedBox(width: 10),
              ExcludeSemantics(child: Switch(value: switchValue!, onChanged: onSwitch)),
            ] else if (onTap != null && !danger && trailing == null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut)),
              ),
          ],
        ),
      ),
    );
    if (isSwitch) {
      return Semantics(
        container: true,
        toggled: switchValue,
        label: subtitle == null ? title : '$title. $subtitle',
        onTap: onSwitch == null ? null : () => onSwitch!(!switchValue!),
        excludeSemantics: true,
        child: InkWell(onTap: onSwitch == null ? null : () => onSwitch!(!switchValue!), child: row),
      );
    }
    return InkWell(onTap: onTap, child: row);
  }
}

/// Yatay kaydırılan çip satırı (filtre/kategori). [selected] seçili indeks; [onSelected] indeks döner.
/// RTL'de sağdan başlar. Yüksekliği 48 dp'ye sabit (çipin 34 dp görünür kutusu + 48 dp dokunma alanı).
///
/// Seçili çip her zaman görünür kalır (seçim değişince / ilk açılışta yumuşakça ortalanır); içerik taşıyorsa
/// kaydırılabilir yönün kenarında ~24 dp solma ipucu çıkar (1.3x yazıda son çip kesik görünse de devam ettiği anlaşılır).
class BuChipRow extends StatefulWidget {
  const BuChipRow({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.icons,
    this.padding = const EdgeInsetsDirectional.symmetric(horizontal: 20),
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  /// İsteğe bağlı çip simgeleri ([labels] ile aynı uzunlukta).
  final List<IconData?>? icons;
  final EdgeInsetsGeometry padding;

  @override
  State<BuChipRow> createState() => _BuChipRowState();
}

class _BuChipRowState extends State<BuChipRow> {
  final _scroll = ScrollController();
  List<GlobalKey> _keys = const [];
  bool _startFade = false;
  bool _endFade = false;
  bool _first = true;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.labels.length, (_) => GlobalKey());
    _scroll.addListener(_updateFade);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: false));
  }

  @override
  void didUpdateWidget(BuChipRow old) {
    super.didUpdateWidget(old);
    if (_keys.length != widget.labels.length) {
      _keys = List.generate(widget.labels.length, (_) => GlobalKey());
    }
    if (old.selected != widget.selected || old.labels.length != widget.labels.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: true));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _updateFade() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final s = p.pixels > 4;
    final e = p.pixels < p.maxScrollExtent - 4;
    if (s != _startFade || e != _endFade) {
      setState(() {
        _startFade = s;
        _endFade = e;
      });
    }
  }

  void _reveal({required bool animate}) {
    if (!mounted) return;
    _updateFade();
    final i = widget.selected;
    if (i < 0 || i >= _keys.length) return;
    final ctx = _keys[i].currentContext;
    if (ctx == null || !_scroll.hasClients) return;
    // Zaten tamamen görünüyorsa kaydırma (gereksiz hareket olmasın).
    final box = ctx.findRenderObject() as RenderBox?;
    final vp = context.findRenderObject() as RenderBox?;
    if (box == null || vp == null || !box.hasSize || !vp.hasSize) return;
    final tl = box.localToGlobal(Offset.zero, ancestor: vp);
    final inView = tl.dx >= 8 && tl.dx + box.size.width <= vp.size.width - 8;
    if (inView) return;
    final d = (animate && !_first && !BuMotion.reduced(context)) ? BuMotion.medium : Duration.zero;
    _first = false;
    Scrollable.ensureVisible(ctx, alignment: .5, duration: d, curve: BuMotion.emphasized);
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    const w = 24.0;
    // dstIn maskesinde yalnız alfa önemli: renk belirtecinden türetilir (sihirli renk yok).
    final solid = context.bu.bg;
    final clear = solid.withValues(alpha: 0);
    Widget row = SizedBox(
      height: BuSize.touch,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        child: Row(
          children: [
            for (var i = 0; i < widget.labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              KeyedSubtree(
                key: _keys[i],
                child: BuChip(
                  label: widget.labels[i],
                  selected: i == widget.selected,
                  icon: widget.icons != null && i < widget.icons!.length ? widget.icons![i] : null,
                  onTap: () => widget.onSelected(i),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (_startFade || _endFade) {
      // Fiziksel sol/sağ: RTL'de başlangıç sağdadır.
      final leftFade = rtl ? _endFade : _startFade;
      final rightFade = rtl ? _startFade : _endFade;
      row = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => LinearGradient(
          colors: [clear, solid, solid, clear],
          stops: [0, leftFade ? w / r.width : 0, rightFade ? 1 - w / r.width : 1, 1],
        ).createShader(r),
        child: row,
      );
    }
    return row;
  }
}
