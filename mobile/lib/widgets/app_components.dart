import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/theme/bu_shape.dart';
import '../core/theme/bu_sizes.dart';
import '../core/typography.dart';
import '../features/posts/post_card.dart' show PostCard;
import 'bu_list.dart' show BuListTile;
import 'bu_overlays.dart' show BuBottomSheet, BuDialog;
import 'bu_pressable.dart';
import 'bu_skeleton.dart' show BuSkeleton;
import 'bu_state.dart' show BuEmptyState;
import 'bu_widgets.dart' show BuAvatar, BuButton, BuCard, BuHeader;
import '../features/shell/floating_nav.dart' show FloatingNav;

/// PREMIUM MONOCHROME ortak bileşen adları (docs/MOBILE_DESIGN_SYSTEM.md "Bileşen eşlemesi").
///
/// Projede karşılığı olan `Bu*` bileşenler YENİDEN YAZILMAZ: aşağıdaki takma adlar aynı sınıfları gösterir, yeni
/// ekranlar bu adları ya da doğrudan `Bu*` adlarını kullanabilir (ikisi aynı şeydir). Eksik olanlar
/// ([AppTextField], [AppReactionBar]) burada tanımlıdır ve yalnız belirteçlerle (`context.bu`) çizilir.
typedef AppButton = BuButton;
typedef AppCard = BuCard;
typedef AppAvatar = BuAvatar;
typedef AppBottomSheet = BuBottomSheet;
typedef AppDialog = BuDialog;
typedef AppTopBar = BuHeader;
typedef AppBottomNavigation = FloatingNav;
typedef AppEmptyState = BuEmptyState;
typedef AppSkeleton = BuSkeleton;
typedef AppPostCard = PostCard;
typedef AppListTile = BuListTile;

/// Metin alanı: tema `InputDecorationTheme` (radius 12, ince kenarlık, odakta `ink` kenarlık) üstüne ince sarmalayıcı.
/// Etiket alanın ÜSTÜNDE (kayan etiket yok), hata/yardım metni altında; dokunma yüksekliği >= [BuSize.field].
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.error,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? error;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: tx.bodySmall!.copyWith(color: t.mut)),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: autofocus,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          maxLength: maxLength,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: tx.bodyLarge!.copyWith(color: t.ink),
          cursorColor: t.ink,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            errorText: error,
            prefixIcon: prefix,
            suffixIcon: suffix,
            counterText: maxLength == null ? null : '',
          ),
        ),
      ],
    );
  }
}

/// Bir tepki/eylem düğmesi tanımı ([AppReactionBar]).
@immutable
class AppReaction {
  const AppReaction({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.count,
    this.active = false,
    this.onTap,
    this.heart = false,
  });

  final IconData icon;

  /// Etkin durumda çizilecek (dolu) simge; yoksa [icon].
  final IconData? activeIcon;

  /// Ekran okuyucu etiketi (zorunlu: yalnız simge).
  final String label;
  final int? count;
  final bool active;
  final VoidCallback? onTap;

  /// Beğeni kalbi: etkinken `heart` (kırmızı) çizer; diğerleri `ink`.
  final bool heart;
}

/// Gönderi altı eylem çubuğu (beğen / yorum / paylaş / kaydet): simge + isteğe bağlı sayı, `ink`/`mut` renkli,
/// her düğme >= 48 dp dokunma alanı. Yalnız beğeni kalbi (`AppReaction.heart`) etkinken kırmızıdır.
class AppReactionBar extends StatelessWidget {
  const AppReactionBar({super.key, required this.items, this.trailing});

  final List<AppReaction> items;

  /// Sağa yaslı öğe (ör. kaydet).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Row(
      children: [
        for (final r in items)
          Semantics(
            button: true,
            label: r.label,
            selected: r.active,
            child: BuPressable(
              onTap: r.onTap,
              scale: .92,
              haptic: BuHaptic.selection,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: BuSize.touch, minWidth: BuSize.touch),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          r.active ? (r.activeIcon ?? r.icon) : r.icon,
                          size: 22,
                          color: r.active ? (r.heart ? t.heart : t.ink) : t.mut,
                        ),
                      ),
                      if (r.count != null && r.count! > 0) ...[
                        const SizedBox(width: 6),
                        ExcludeSemantics(
                          child: Text('${r.count}', style: tx.labelMedium!.copyWith(color: r.active && !r.heart ? t.ink : t.mut)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// İnce yatay ayraç (`bdSubtle`): liste/kart içi bölme; 1 fiziksel piksele yakın.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, indent: indent, color: context.bu.bdSubtle);
}

/// Radius belirteçleri kısayolu (kart 16, buton/input 12, çip pill): ekranlarda sihirli sayı yazmamak için.
abstract final class AppRadius {
  static const double card = BuRadius.md;
  static const double control = BuRadius.control;
  static const double sheet = BuRadius.lg;
}

/// Tek vurgu ağırlığı (bkz. [BuType.emphasisWeight]).
const FontWeight kAppEmphasis = BuType.emphasisWeight;
