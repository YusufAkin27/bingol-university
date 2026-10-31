import 'package:flutter/material.dart';

import '../../widgets/bu.dart';
import 'chatlist_widgets.dart';

// Yeni sohbet / grup oluştur / rehberden kişi bul ekranlarının ortak parçaları (referans 23).
// Yalnız tasarım sistemi bileşenleri ve belirteçler kullanılır.

/// Üst başlık: geri oku (48 dp) + başlık.
class NcHeader extends StatelessWidget {
  const NcHeader({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 16, 6),
        child: Row(children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
            icon: Icon(buDirIcon(context, LucideIcons.arrowLeft), color: t.ink),
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Beyaz yuvarlatılmış kart (20 dp, ince çizgi).
class NcCard extends StatelessWidget {
  const NcCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 20, this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: color ?? t.sf, borderRadius: BorderRadius.circular(radius), border: Border.all(color: t.bd)),
      child: child,
    );
    return onTap == null ? box : BuPressable(onTap: onTap, scale: .99, child: box);
  }
}

/// Simge karosu (14 dp köşe): yumuşak zemin + simge.
class NcTile extends StatelessWidget {
  const NcTile({super.key, required this.icon, required this.bg, required this.fg, this.size = 48});

  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, size: size * .46, color: fg),
      );
}

/// Başlık + alt başlık + sağda yuvarlak ok (Yeni grup / Rehberden kişi bul kartı).
class NcActionCard extends StatelessWidget {
  const NcActionCard({super.key, required this.cardKey, required this.tile, required this.title, required this.subtitle, required this.onTap, this.trailing});

  final Key cardKey;
  final Widget tile;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: NcCard(
        key: cardKey,
        onTap: onTap,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
        child: Row(children: [
          tile,
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
            ]),
          ),
          const SizedBox(width: 8),
          trailing ??
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: t.mut),
              ),
        ]),
      ),
    );
  }
}

/// Kişi satırı: yuvarlak baş harfli/fotoğraflı avatar + ad + alt metin + sağda [trailing].
class NcPersonRow extends StatelessWidget {
  const NcPersonRow({super.key, required this.name, this.sub = '', this.avatarUrl, this.trailing, this.onTap, this.onAvatarTap, this.rowKey});

  final String name;
  final String sub;
  final String? avatarUrl;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onAvatarTap;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final avatar = ChatlistAvatar(name: name, url: avatarUrl, size: 48, circle: true);
    return NcCard(
      key: rowKey,
      onTap: onTap,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(children: [
          onAvatarTap == null ? avatar : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onAvatarTap, child: avatar),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                // Sağdaki hap genişlik yer: bölüm adı kesilmek yerine 2 satıra iner.
                Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.25)),
              ],
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      ),
    );
  }
}

/// Küçük "Mesaj" / "Sohbet başlat" hapı (soluk zemin, simge + etiket; en az 44 dp yükseklik).
class NcPillButton extends StatelessWidget {
  const NcPillButton({super.key, required this.label, required this.onTap, this.busy = false, this.soft = true, this.pillKey});

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  /// true: kırmızı tonlu (Sohbet başlat); false: nötr (Mesaj).
  final bool soft;
  final Key? pillKey;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final bg = soft ? t.soft : t.sf2;
    final fg = soft ? t.onSoft : t.ink;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        key: pillKey,
        color: bg,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: busy ? null : onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: busy
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.messageSquare, size: 14, color: fg),
                    const SizedBox(width: 6),
                    Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w700))),
                  ]),
          ),
        ),
      ),
    );
  }
}

/// Yuvarlak onay kutusu (grup seçimi).
class NcCheck extends StatelessWidget {
  const NcCheck({super.key, required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return AnimatedContainer(
      duration: BuMotion.of(context, BuMotion.short),
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: on ? t.pr : t.sf2, shape: BoxShape.circle),
      child: on ? Icon(LucideIcons.check, size: 16, color: t.onPr) : null,
    );
  }
}

/// Küçük bölüm etiketi (BÜYÜK HARF, soluk).
class NcLabel extends StatelessWidget {
  const NcLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 4, 8),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w700, letterSpacing: .6)),
    );
  }
}

/// Yumuşak kırmızı/amber uyarı kutusu (simge + metin).
class NcNote extends StatelessWidget {
  const NcNote({super.key, required this.icon, required this.text, this.warn = false, this.noteKey});

  final IconData icon;
  final String text;
  final bool warn;
  final Key? noteKey;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bg = warn ? t.warnSoft : t.soft;
    final fg = warn ? t.onWarnSoft : t.onSoft;
    return Container(
      key: noteKey,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: fg)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: fg, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

/// Durum kartı: halkalı simge + başlık + metin (+ ek içerik).
class NcStateCard extends StatelessWidget {
  const NcStateCard({super.key, required this.icon, required this.title, this.text, this.children = const []});

  final IconData icon;
  final String title;
  final String? text;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return NcCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
          child: Icon(icon, size: 44, color: t.pr),
        ),
        const SizedBox(height: 20),
        Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800))),
        if (text != null) ...[
          const SizedBox(height: 8),
          Text(text!, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
        ],
        ...children,
      ]),
    );
  }
}
