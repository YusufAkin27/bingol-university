import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Sohbet listesi bileşenleri (referans 18).

/// "Yeni sohbet" kırmızı yuvarlak düğme (48 dp, yumuşak kırmızı gölge).
class ChatlistNewButton extends StatelessWidget {
  const ChatlistNewButton({super.key, required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: BuPressable(
          onTap: onTap,
          haptic: BuHaptic.light,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: t.pr,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: t.pr.withValues(alpha: .38), blurRadius: 16, offset: const Offset(0, 8), spreadRadius: -6)],
            ),
            child: Icon(LucideIcons.plus, size: 24, color: t.onPr),
          ),
        ),
      ),
    );
  }
}

/// Beyaz yuvarlak simge düğmesi (Arşiv): 48 dp dokunma alanı, ince çizgi.
class ChatlistRoundButton extends StatelessWidget {
  const ChatlistRoundButton({super.key, required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: BuPressable(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle, border: Border.all(color: t.bd)),
            child: Icon(icon, size: 20, color: t.ink),
          ),
        ),
      ),
    );
  }
}

/// Arama kutusu: 52 dp, 18 dp köşe, yüzey rengi + ince çizgi; yazı varken temizle düğmesi.
class ChatlistSearch extends StatelessWidget {
  const ChatlistSearch({super.key, required this.hint, required this.onChanged, this.controller});

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      height: 52,
      padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.bd),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 18, color: t.mut),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: tx.bodyLarge!.copyWith(color: t.ink),
              cursorColor: t.pr,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: hint,
                hintStyle: tx.bodyLarge!.copyWith(color: t.mut),
              ),
            ),
          ),
          if (controller != null)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller!,
              builder: (c, v, _) => v.text.isEmpty
                  ? const SizedBox(width: 8)
                  : IconButton(
                      tooltip: MaterialLocalizations.of(c).deleteButtonTooltip,
                      onPressed: () {
                        controller!.clear();
                        onChanged('');
                      },
                      icon: Icon(LucideIcons.x, size: 16, color: t.mut),
                    ),
            ),
        ],
      ),
    );
  }
}

/// Segment: sf2 zemin, 16 px köşe, seçili öğe yüzey rengi + gölge. (Eski görünüm; liste artık [BuChipRow] kullanır.)
class ChatlistSegment extends StatelessWidget {
  const ChatlistSegment({super.key, required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return BuSegmented(items: labels, index: selected, onChanged: onSelect);
  }
}

/// Satır avatarı: 52 dp yuvarlatılmış kare; fotoğraf varsa foto, yoksa baş harfli tonlu kare.
/// [badge] kulüp/etkinlik odası için köşe işareti, [online] çevrimiçi noktası.
class ChatlistAvatar extends StatelessWidget {
  const ChatlistAvatar({
    super.key,
    required this.name,
    this.url,
    this.group = false,
    this.size = 52,
    this.online = false,
    this.badge,
    this.badgeAtTop = false,
    this.circle = false,
  });

  /// true: yuvarlak (sohbet içi 28 dp gönderen avatarı); false: yuvarlatılmış kare (liste).
  final bool circle;

  final String name;
  final String? url;
  final bool group;
  final double size;
  final bool online;

  /// Köşe işareti simgesi (kulüp: megafon, etkinlik: takvim).
  final IconData? badge;

  /// true: işaret üst başta (kulüp), false: alt sonda (etkinlik).
  final bool badgeAtTop;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final a = String.fromCharCode(parts.first.runes.first);
    final b = parts.length > 1 ? String.fromCharCode(parts.last.runes.first) : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final radius = circle ? size / 2 : size * .34;
    // Baş harfli tonlu kare her zaman altta durur: görsel yüklenirken, hata verince ya da url yokken görünür.
    final tint = t.tint(name.runes.fold<int>(0, (a, r) => (a + r) % 9973));
    final initialsTile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint.bg, borderRadius: BorderRadius.circular(radius)),
      child: Text(initials(name), style: (size < 40 ? Theme.of(context).textTheme.labelSmall! : Theme.of(context).textTheme.titleMedium!).copyWith(color: tint.fg, fontWeight: FontWeight.w800)),
    );
    final full = fileUrl(url);
    final Widget base;
    if (full == null) {
      base = ExcludeSemantics(child: initialsTile);
    } else {
      final px = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
      base = ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(fit: StackFit.expand, children: [
            initialsTile,
            ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Image.network(
                full,
                width: size,
                height: size,
                cacheWidth: px,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: (c, child, frame, sync) =>
                    sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: BuMotion.of(c, BuMotion.medium), curve: BuMotion.decelerate, child: child),
                // Yüklenemezse alttaki baş harfli kare kalır.
                errorBuilder: (c, e, st) => const SizedBox.shrink(),
              ),
            ),
          ]),
        ),
      );
    }
    if (!online && badge == null) return base;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        base,
        if (badge != null)
          PositionedDirectional(
            start: badgeAtTop ? -4 : null,
            end: badgeAtTop ? null : -4,
            top: badgeAtTop ? -4 : null,
            bottom: badgeAtTop ? null : -4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: badgeAtTop ? BuTokens.light.ink : t.ok,
                shape: BoxShape.circle,
                border: Border.all(color: t.sf, width: 2),
              ),
              child: Icon(badge, size: 11, color: BuTokens.light.onPr),
            ),
          ),
        if (online)
          PositionedDirectional(
            end: -3,
            bottom: -3,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: t.ok, shape: BoxShape.circle, border: Border.all(color: t.sf, width: 2.5)),
            ),
          ),
      ]),
    );
  }
}
