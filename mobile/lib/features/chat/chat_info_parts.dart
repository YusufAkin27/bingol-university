import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';

/// Sohbet bilgisi / üyeler / medya ekranlarının ortak parçaları (Stitch grup 24, Paket 9).
/// Renkler yalnız `context.bu`; yazı boyutları referanstaki rollere göre.

/// Sayfa yan boşluğu (referans: 16).
const kChatInfoMargin = 16.0;

/// Türkçede belirtme hâli eki (`Mehmet Kaya'yı`): son ünlüye göre ı/i/u/ü, ünlüyle bitiyorsa `y` kaynaştırması.
/// Yalnız Türkçe arayüzde kullanılır; diğer dillerde ad olduğu gibi döner.
String chatInfoAccusative(String name, String lang) {
  final n = name.trim();
  if (lang != 'tr' || n.isEmpty) return n;
  const vowels = 'aeıioöuüAEIİOÖUÜ';
  var last = '';
  for (final r in n.runes.toList().reversed) {
    final ch = String.fromCharCode(r);
    if (vowels.contains(ch)) {
      // Büyük harfli adlar (ALİ, IŞIL): İ/I Türkçe kurallarıyla küçültülür.
      last = ch == 'İ' ? 'i' : (ch == 'I' ? 'ı' : ch.toLowerCase());
      break;
    }
  }
  if (last.isEmpty) return n;
  final suffix = switch (last) {
    'a' || 'ı' => 'ı',
    'e' || 'i' => 'i',
    'o' || 'u' => 'u',
    _ => 'ü',
  };
  final endsWithVowel = vowels.contains(n.characters.last);
  return "$n'${endsWithVowel ? 'y' : ''}$suffix";
}

/// Arama için Türkçe duyarlı katlama: İ/I doğru küçülür, ı→i ve Türkçe harfler ASCII'ye iner
/// ("ilker" araması "İlker" ve "ILKER" adlarını bulur).
String chatInfoFold(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    b.write(switch (ch) {
      'İ' || 'I' || 'ı' => 'i',
      'Ş' || 'ş' => 's',
      'Ç' || 'ç' => 'c',
      'Ğ' || 'ğ' => 'g',
      'Ö' || 'ö' => 'o',
      'Ü' || 'ü' => 'u',
      _ => ch.toLowerCase(),
    });
  }
  return b.toString();
}

TextStyle _s(BuildContext c, TextStyle base, {FontWeight? w, Color? color, double? height}) =>
    base.copyWith(fontWeight: w, color: color, height: height);

/// Satır başlığı: titleMedium rolü, 600 (referans title-md).
TextStyle chatInfoTitle16(BuildContext c, {Color? color}) =>
    _s(c, Theme.of(c).textTheme.titleMedium!, w: FontWeight.w600, color: color ?? c.bu.ink, height: 1.375);

/// Düğme/bağlantı yazısı: labelLarge rolü, 600 (referans label-lg).
TextStyle chatInfoLabel14(BuildContext c, {Color? color}) =>
    _s(c, Theme.of(c).textTheme.labelLarge!, w: FontWeight.w600, color: color ?? c.bu.ink, height: 1.43);

/// Küçük etiket: labelMedium rolü, 600 (referans label-md).
TextStyle chatInfoLabel12(BuildContext c, {Color? color}) =>
    _s(c, Theme.of(c).textTheme.labelMedium!, w: FontWeight.w600, color: color ?? c.bu.ink, height: 1.33);

/// Gövde: bodyMedium rolü (referans body-md).
TextStyle chatInfoBody14(BuildContext c, {Color? color}) =>
    _s(c, Theme.of(c).textTheme.bodyMedium!, w: FontWeight.w400, color: color ?? c.bu.mut, height: 1.43);

/// Alt satır: bodySmall rolü (referans body-sm).
TextStyle chatInfoBody12(BuildContext c, {Color? color}) =>
    _s(c, Theme.of(c).textTheme.bodySmall!, w: FontWeight.w400, color: color ?? c.bu.mut, height: 1.33);

/// Üst çubuk: geri oku + 18/600 başlık, 56 dp (referans). Durum çubuğu payı üstte eklenir.
class ChatInfoBar extends StatelessWidget {
  const ChatInfoBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      color: t.bg,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: SizedBox(
        height: 56,
        child: Row(children: [
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: context.l10n.commonBack,
              onPressed: () => Navigator.maybePop(context),
              icon: Icon(buDirIcon(context, LucideIcons.arrowLeft), size: 24, color: t.ink),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: kChatInfoMargin),
        ]),
      ),
    );
  }
}

/// Tam genişlik beyaz bant: üst/alt 1 dp `bd` çizgi, köşe ve gölge yok (Stitch v3 sohbet bilgisi).
class ChatInfoCard extends StatelessWidget {
  const ChatInfoCard({super.key, required this.child, this.padding = EdgeInsets.zero, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.sf,
        border: Border.symmetric(horizontal: BorderSide(color: t.bd)),
      ),
      child: child,
    );
  }
}

/// Çizgiyle ayrılmış satırları tek kartta toplar.
class ChatInfoRows extends StatelessWidget {
  const ChatInfoRows({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ChatInfoCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: t.bd),
          children[i],
        ],
      ]),
    );
  }
}

/// Kart satırı: 36 dp simge dairesi, 16/600 başlık, isteğe bağlı değer ve ok. Yükseklik en az 56.
class ChatInfoRow extends StatelessWidget {
  const ChatInfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.sub,
    this.onTap,
    this.danger = false,
    this.chevron = true,
    this.chevronDanger = false,
    this.soft = false,
    this.dotSize = 36,
    this.iconSize = 20,
    this.minHeight = 56,
    this.padding = 16,
  });

  final IconData icon;
  final String label;
  final String? value;

  /// Başlığın altında ikinci satır (uzun durum metinleri için; [value] kısa değerler içindir).
  final String? sub;
  final VoidCallback? onTap;
  final bool danger;
  final bool chevron;

  /// Ok da kırmızı ("Sohbetten çık").
  final bool chevronDanger;

  /// Simge dairesi marka tonunda ("Üye ekle").
  final bool soft;
  final double dotSize;
  final double iconSize;
  final double minHeight;

  /// Yatay iç boşluk.
  final double padding;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final fg = danger ? t.danger : t.ink;
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: padding, vertical: 8),
            child: Row(children: [
              if (soft) ...[
                ChatInfoIconDot(icon: icon, danger: danger, soft: soft, size: dotSize, iconSize: iconSize),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: chatInfoTitle16(context, color: fg).copyWith(fontWeight: FontWeight.w400)),
                  if (sub != null) Text(sub!, maxLines: 2, overflow: TextOverflow.ellipsis, style: chatInfoBody12(context)),
                ]),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  flex: 0,
                  child: Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis, style: chatInfoLabel14(context, color: t.mut)),
                ),
              ],
              if (chevron) ...[
                const SizedBox(width: 6),
                ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 20, color: chevronDanger ? t.danger : t.mut)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// 36 dp yuvarlak simge zemini (tehlikede kırmızı ton).
class ChatInfoIconDot extends StatelessWidget {
  const ChatInfoIconDot({super.key, required this.icon, this.danger = false, this.size = 36, this.iconSize = 20, this.soft = false});

  final IconData icon;
  final bool danger;
  final double size;
  final double iconSize;

  /// Marka tonu (soft) zemin: "Üye ekle" gibi eylem dairesi.
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bg = soft ? t.soft : (danger ? t.danger.withValues(alpha: .1) : t.sf2);
    final fg = soft ? t.onSoft : (danger ? t.danger : t.ink);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: iconSize, color: fg),
      ),
    );
  }
}

/// Hızlı eylem kartı: 48 dp daire + etiket. [dense] grup düzeni (dar kart, 12 dp etiket).
class ChatInfoQuickAction extends StatelessWidget {
  const ChatInfoQuickAction({super.key, required this.icon, required this.label, required this.onTap, this.dense = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: BuPressable(
        onTap: onTap,
        haptic: BuHaptic.selection,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BuSize.touch + 16),
          child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 24, color: t.ink),
            const SizedBox(height: 8),
            Text(label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: chatInfoLabel12(context).copyWith(fontWeight: FontWeight.w500, color: t.ink)),
          ]),
        ),
      ),
    );
  }
}

/// Üç hızlı eylem yan yana (grup/oda: en çok 320 dp genişlik).
class ChatInfoQuickRow extends StatelessWidget {
  const ChatInfoQuickRow({super.key, required this.actions, this.dense = false});

  final List<ChatInfoQuickAction> actions;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final row = IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: actions[i]),
        ],
      ]),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kChatInfoMargin),
      child: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: dense ? 320 : double.infinity), child: row)),
    );
  }
}

/// Küçük hap etiket: koyu (Yönetici/Sen) ya da marka tonu.
class ChatInfoTag extends StatelessWidget {
  const ChatInfoTag(this.text, {super.key, this.soft = false, this.roomRed = false, this.large = true});

  final String text;

  /// Marka tonu (soft/onSoft) zemin.
  final bool soft;

  /// Dolu kırmızı (etkinlik odası etiketi).
  final bool roomRed;

  /// Bilgi sayfası: 11 dp yazı, 10x4 boşluk; üyeler listesi için false: 14 dp yazı, 8x4 boşluk.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final (bg, fg) = roomRed ? (t.pr, t.onPr) : (soft ? (t.soft, t.onSoft) : (t.ink, t.bg));
    return Container(
      padding: EdgeInsetsDirectional.symmetric(horizontal: large ? 10 : 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bPill),
      child: Text(text,
          maxLines: 1,
          style: large
              ? Theme.of(context).textTheme.labelSmall!.copyWith(color: fg, fontWeight: FontWeight.w700, height: 1.3)
              : chatInfoLabel14(context, color: fg).copyWith(height: 1.3)),
    );
  }
}

/// Sayı hapı ("12"): ikincil zemin.
class ChatInfoCount extends StatelessWidget {
  const ChatInfoCount(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
    );
  }
}

/// Kart başlığı: 16/600 ad + isteğe bağlı sayı hapı ya da düz metin + sağda kırmızı bağlantı.
class ChatInfoSectionHead extends StatelessWidget {
  const ChatInfoSectionHead(
      {super.key, required this.title, this.count, this.actionLabel, this.onAction, this.largeAction = false});

  final String title;
  final String? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Bağlantı 14/600 (birebir medya kartı); varsayılan 12/600.
  final bool largeAction;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Row(children: [
      Expanded(
        child: Row(children: [
          Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: chatInfoTitle16(context))),
          if (count != null) ...[const SizedBox(width: 8), ChatInfoCount(count!)],
        ]),
      ),
      if (actionLabel != null)
        Semantics(
          button: true,
          child: InkWell(
            onTap: onAction,
            borderRadius: BuRadius.bXs,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  widthFactor: 1,
                  child: Text(actionLabel!,
                      maxLines: 1,
                      style: largeAction ? chatInfoLabel14(context, color: t.pr) : chatInfoLabel12(context, color: t.pr)),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Onay penceresi düzeni: ortalı (üye çıkar 24-5), simge başlığın yanında (ayrıl 22-3), simge üstte solda (sohbeti sil 22-2).
enum ChatConfirmLayout { centered, iconBeside, iconAbove }

/// Onay penceresi (referans A20): üstte 56 dp tonlu simge, ortalı başlık ve gövde, yan yana iki düğme.
/// [bold] gövdede kalın yazılacak parça (ad). `true` dönerse onaylandı.
Future<bool> showChatInfoConfirm(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String body,
  String? bold,
  required String confirmLabel,
  required String cancelLabel,
  IconData? confirmIcon,
  ChatConfirmLayout layout = ChatConfirmLayout.centered,
}) async {
  final t = context.bu;
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: t.ink.withValues(alpha: .45),
    builder: (c) => Dialog(
      backgroundColor: Theme.of(c).brightness == Brightness.dark ? t.sf3 : t.sf,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(kChatInfoMargin),
      shape: const RoundedRectangleBorder(borderRadius: BuRadius.bMd),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ..._confirmHead(c, layout, icon, title, body, bold),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: ChatDialogButton(label: cancelLabel, onTap: () => Navigator.pop(c, false))),
              const SizedBox(width: 8),
              Expanded(child: ChatDialogButton(label: confirmLabel, icon: confirmIcon, destructive: true, onTap: () => Navigator.pop(c, true))),
            ]),
          ]),
        ),
      ),
    ),
  );
  return ok == true;
}

List<Widget> _confirmHead(BuildContext c, ChatConfirmLayout layout, IconData icon, String title, String body, String? bold) {
  final t = c.bu;
  final titleStyle = Theme.of(c).textTheme.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w600, height: 1.33);
  switch (layout) {
    case ChatConfirmLayout.centered:
      return [
        Center(child: ChatInfoIconDot(icon: icon, size: 56, iconSize: 28, danger: true)),
        const SizedBox(height: 12),
        Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: titleStyle)),
        const SizedBox(height: 4),
        _boldBody(c, body, bold, TextAlign.center),
      ];
    case ChatConfirmLayout.iconBeside:
      return [
        Row(children: [
          ChatInfoIconDot(icon: icon, size: 48, iconSize: 24, danger: true),
          const SizedBox(width: 16),
          Expanded(child: Semantics(header: true, child: Text(title, style: titleStyle))),
        ]),
        const SizedBox(height: 16),
        _boldBody(c, body, bold, TextAlign.start),
      ];
    case ChatConfirmLayout.iconAbove:
      return [
        Align(alignment: AlignmentDirectional.centerStart, child: ChatInfoIconDot(icon: icon, size: 48, iconSize: 24, danger: true)),
        const SizedBox(height: 16),
        Semantics(header: true, child: Text(title, style: titleStyle)),
        const SizedBox(height: 8),
        _boldBody(c, body, bold, TextAlign.start),
      ];
  }
}

Widget _boldBody(BuildContext c, String body, String? bold, TextAlign align) {
  final t = c.bu;
  final base = chatInfoBody14(c, color: t.mut);
  final i = (bold == null || bold.isEmpty) ? -1 : body.indexOf(bold);
  if (i < 0) return Text(body, textAlign: align, style: base);
  return Text.rich(
    TextSpan(style: base, children: [
      TextSpan(text: body.substring(0, i)),
      TextSpan(text: bold, style: base.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
      TextSpan(text: body.substring(i + bold!.length)),
    ]),
    textAlign: align,
  );
}

/// Pencere düğmesi (tek tanım): ikincil zeminli ya da [destructive] dolu kırmızı; [onTap] null ise pasif.
class ChatDialogButton extends StatelessWidget {
  const ChatDialogButton({super.key, required this.label, required this.onTap, this.icon, this.destructive = false, this.minHeight = BuSize.button});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool destructive;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final off = onTap == null;
    final bg = destructive ? (off ? t.danger.withValues(alpha: .5) : t.danger) : t.sf2;
    final fg = destructive ? Theme.of(context).colorScheme.onError : t.ink;
    return Semantics(
      button: true,
      enabled: !off,
      child: BuPressable(
        scale: .98,
        enabled: !off,
        child: Material(
          color: bg,
          borderRadius: BuRadius.bMd,
          child: InkWell(
            borderRadius: BuRadius.bMd,
            onTap: off
                ? null
                : () {
                    buHaptic(BuHaptic.selection);
                    onTap!();
                  },
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 4)],
                  Flexible(
                    child: Text(label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: chatInfoLabel14(context, color: fg)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
