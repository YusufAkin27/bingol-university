import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';

Future<void> openStore(String? url) async {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Tam ekran sistem durumlarının ortak iskeleti (04 grubu): üstte isteğe bağlı şerit, ortada içerik,
/// altta düğmeler. Dört durum ekranı da aynı düzeni kullanır (simge -> başlık -> metin -> düğme), böylece
/// geçişlerde yer değiştirmez. Sığmayan içerik (büyük yazı) kayar; düğmeler yerinde kalır.
class _GateLayout extends StatelessWidget {
  const _GateLayout({this.top, required this.content, this.actions = const []});

  final Widget? top;
  final Widget content;
  final List<Widget> actions;

  static const double _horizontal = 24;

  @override
  Widget build(BuildContext context) {
    // Giriş sırası: simge (0) -> başlık/metin (1) -> ek hap (2) -> eylemler (3). Kapsam her indeksi bir kez oynatır.
    Widget action(Widget a) => BuStaggerItem(index: 3, child: a);
    final body = Padding(padding: const EdgeInsetsDirectional.symmetric(horizontal: _horizontal), child: content);
    return BuStaggerScope(
      child: SafeArea(
        child: Column(
          children: [
            if (top != null) top!,
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight - 32),
                    child: Center(child: body),
                  ),
                ),
              ),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(_horizontal, 8, _horizontal, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(height: 12), action(actions[i])]],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tüm durum ekranlarının ortak simge karosu (88 dp, aynı köşe): [neutral] sakin gri (bakım, çevrimdışı),
/// aksi halde marka tonu (güncelleme, erişim engeli). Dekoratiftir; ekran okuyucudan gizlenir.
class _GateIcon extends StatefulWidget {
  const _GateIcon({required this.icon, this.neutral = false, this.breathe = false});

  final IconData icon;
  final bool neutral;

  /// Bakım / çevrimdışı: simge girişten sonra iki kez ince "nefes" alır (1 -> 1,06), sonra durur.
  /// Sürekli döngü yoktur; yalnız `transform`; "animasyonları azalt" açıksa hiç oynamaz.
  final bool breathe;

  @override
  State<_GateIcon> createState() => _GateIconState();
}

class _GateIconState extends State<_GateIcon> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null || !widget.breathe || BuMotion.reduced(context)) return;
    // Giriş animasyonu (400 ms) bitince başlar.
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true, count: 4, period: const Duration(milliseconds: 1600));
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final icon = widget.icon;
    final neutral = widget.neutral;
    final c = _c;
    Widget glyph = Icon(icon, size: 40, color: neutral ? t.mut : t.pr);
    if (c != null) {
      glyph = ScaleTransition(
        scale: Tween<double>(begin: 1, end: 1.06).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        child: glyph,
      );
    }
    return BuStaggerItem(
      index: 0,
      child: ExcludeSemantics(
        child: Container(
          width: 88,
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: neutral ? t.sf2 : t.soft, borderRadius: BuRadius.bXl),
          child: RepaintBoundary(child: glyph),
        ),
      ),
    );
  }
}

/// Başlık + açıklama (ortalı); açıklama ekran okuyucuya canlı bölge olarak duyurulur.
class _GateText extends StatelessWidget {
  const _GateText({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return BuStaggerItem(
      index: 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(title,
                textAlign: TextAlign.center,
                style: tx.headlineMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800, letterSpacing: Directionality.of(context) == TextDirection.rtl ? 0 : -.3)),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Semantics(
              liveRegion: true,
              child: Text(body, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.6)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiketin SONUNDA ok bulunan birincil düğme ("Başla →", "Yoklamayı gönder →"); ok okuma yönüne göre döner.
/// [BuButton] simgeyi hep başa koyar: satır sırası, yön tersine çevrilerek sona taşınır (etiket kendi yönünü korur).
class GateArrowButton extends StatelessWidget {
  const GateArrowButton({super.key, required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ambient = Directionality.of(context);
    return Directionality(
      textDirection: ambient == TextDirection.rtl ? TextDirection.ltr : TextDirection.rtl,
      child: BuButton(
        label: label,
        icon: ambient == TextDirection.rtl ? LucideIcons.arrowLeft : LucideIcons.arrowRight,
        busy: busy,
        onPressed: onPressed,
      ),
    );
  }
}

/// Düz (kenarlıksız) ikinci düğme: gri bağlantı biçimi ("Tekrar kontrol et").
class _GateLink extends StatelessWidget {
  const _GateLink({super.key, required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return TextButton.icon(
      onPressed: () {
        buHaptic(BuHaptic.selection);
        onPressed();
      },
      style: TextButton.styleFrom(
        foregroundColor: t.mut,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
    );
  }
}

/// Kapatılamaz zorunlu güncelleme ekranı (04/2). [latest] verilirse sürüm satırı gösterilir.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.storeUrl, this.latest, this.current, this.onRetry});

  final String? storeUrl;

  /// Gerekli (en yeni) sürüm.
  final String? latest;

  /// Yüklü sürüm.
  final String? current;

  /// "Tekrar kontrol et": mağaza adresi yoksa/çalışmıyorsa ve bayrak geri alındığında çıkış yolu.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final canOpen = storeUrl != null && Uri.tryParse(storeUrl!)?.scheme == 'https';
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: t.bg,
        body: _GateLayout(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _GateIcon(icon: LucideIcons.smartphone),
              const SizedBox(height: 24),
              _GateText(title: l.updateRequiredTitle, body: l.updateRequiredBody),
              if (latest != null && current != null) ...[
                const SizedBox(height: 24),
                BuStaggerItem(index: 2, child: _VersionPill(text: l.sistemuiUpdateVersions(current!, latest!))),
              ],
            ],
          ),
          actions: [
            if (canOpen) BuButton(label: l.commonUpdate, icon: LucideIcons.download, onPressed: () => openStore(storeUrl)),
            if (onRetry != null)
              if (canOpen)
                _GateLink(key: const ValueKey('update-recheck'), label: l.updateRequiredRecheck, icon: LucideIcons.refreshCw, onPressed: onRetry!)
              else
                BuButton(key: const ValueKey('update-recheck'), label: l.updateRequiredRecheck, icon: LucideIcons.refreshCw, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: t.mut, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// Tam ekran bakım görünümü (04/3): üstte uyarı şeridi, altında içerik akar; [message] yönetici metnidir.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key, required this.onRetry, this.message});

  final VoidCallback onRetry;

  /// Yönetici mesajı; yoksa varsayılan açıklama.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: _GateLayout(
        top: GateNoticeStrip(icon: LucideIcons.info, text: l.sistemuiMaintBand, kind: GateNoticeKind.maintenance, plain: true),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GateIcon(icon: LucideIcons.wrench, neutral: true, breathe: true),
            const SizedBox(height: 24),
            _GateText(title: l.sistemuiMaintTitle, body: message ?? l.sistemuiMaintBody),
          ],
        ),
        actions: [BuButton(label: l.commonRetry, icon: LucideIcons.rotateCw, onPressed: onRetry)],
      ),
    );
  }
}

/// Tam ekran "bağlantı yok" görünümü (04/4).
class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: _GateLayout(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GateIcon(icon: LucideIcons.cloudOff, neutral: true, breathe: true),
            const SizedBox(height: 24),
            _GateText(title: l.sistemuiOfflineTitle, body: l.sistemuiOfflineBody),
          ],
        ),
        actions: [BuButton(label: l.commonRetry, icon: LucideIcons.rotateCw, onPressed: onRetry)],
      ),
    );
  }
}

/// 403 ACCESS_BLOCKED (04/5): cihaz veya ağ erişimi kapatıldı. Oturum silinmiş olur; yeniden denemek giriş ekranına döner.
class AccessBlockedScreen extends StatelessWidget {
  const AccessBlockedScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: t.bg,
        body: _GateLayout(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _GateIcon(icon: LucideIcons.shieldX),
              const SizedBox(height: 24),
              _GateText(title: l.accessBlockedTitle, body: l.accessBlockedBody),
              const SizedBox(height: 24),
              BuStaggerItem(index: 2, child: _CodePill(text: l.sistemuiBlockedCode)),
            ],
          ),
          actions: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: BuButton(label: l.commonRetry, icon: LucideIcons.rotateCw, onPressed: onRetry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodePill extends StatelessWidget {
  const _CodePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bXs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(LucideIcons.terminal, size: 15, color: t.mut)),
          const SizedBox(width: 6),
          Flexible(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(text,
                  style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.mut, fontFamily: 'monospace', fontFamilyFallback: const ['Menlo', 'Courier New'], letterSpacing: .4, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Üst şerit: çevrimdışı ve bekleyen-gönderim şeritleri için ortak görünüm (05/1). Tam genişlik, köşesiz.
/// [danger] true = "bağlantı yok" şeridi (koyu gri zemin, kalın yazı); false = ince eşitleme şeridi.
class TopStrip extends StatelessWidget {
  const TopStrip({
    super.key,
    required this.icon,
    required this.text,
    this.danger = false,
    this.trailingText,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final bool danger;

  /// Sağ taraftaki soluk açıklama ("Kayıtlı veriler gösteriliyor").
  final String? trailingText;

  /// Sağdaki eylem ("Yeniden dene").
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final bg = danger ? t.bd : t.sf2;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: danger ? 40 : 38),
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: danger ? 18 : 16, color: danger ? t.ink : t.mut)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tx.labelMedium!
                    .copyWith(color: danger ? t.ink : t.mut, fontWeight: danger ? FontWeight.w700 : FontWeight.w500, decoration: TextDecoration.none)),
          ),
          if (trailingText != null) ...[
            const SizedBox(width: 8),
            ExcludeSemantics(child: Container(width: 6, height: 6, decoration: BoxDecoration(color: t.mut, shape: BoxShape.circle))),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(trailingText!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onAction,
              borderRadius: BuRadius.bXs,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Center(
                  widthFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(actionLabel!,
                        style: tx.labelMedium!.copyWith(color: t.pr, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum GateNoticeKind { maintenance, announcement }

/// Yuvarlak bildirim şeridi (05/2): solda beyaz simge karosu, kalın tek paragraf, sağda "!" ya da kapatma.
/// Bakım = sıcak sarı (uyarı belirteci), duyuru = mavi bilgi tonu.
class GateNoticeStrip extends StatelessWidget {
  const GateNoticeStrip({super.key, required this.icon, required this.text, required this.kind, this.onClose, this.plain = false});

  final IconData icon;
  final String text;
  final GateNoticeKind kind;

  /// Verilirse sağda kapatma düğmesi görünür (duyuru); yoksa bakım için "!" göstergesi.
  final VoidCallback? onClose;

  /// Sade biçim (04/3 bakım ekranı): simge karosu ve sağ gösterge yok, ince tek satır.
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final maint = kind == GateNoticeKind.maintenance;
    final tint = t.tint(1);
    final bg = maint ? t.warnSoft : tint.bg;
    final fg = maint ? t.onWarnSoft : tint.fg;
    final accent = maint ? t.warn : tint.fg;
    if (plain) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(icon, size: 18, color: accent)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: Theme.of(context).textTheme.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w500, height: 1.3, decoration: TextDecoration.none)),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 4, 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), boxShadow: BuElevation.of(context, 1)),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: accent),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w700, height: 1.3, decoration: TextDecoration.none)),
          ),
          if (onClose != null)
            IconButton(
              tooltip: context.l10n.commonClose,
              onPressed: onClose,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(LucideIcons.x, size: 18, color: fg),
            )
          else if (maint)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ExcludeSemantics(child: Icon(LucideIcons.info, size: 16, color: fg)),
            )
          else
            const SizedBox(width: 10),
        ],
      ),
    );
  }
}

/// Kapatılabilir "yeni sürüm var" alt bildirimi (05/3): yüzen kart; Güncelle + kapat.
class UpdateNotice extends StatelessWidget {
  const UpdateNotice({super.key, required this.latest, required this.storeUrl, required this.onClose});

  final String? latest;
  final String? storeUrl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final canOpen = storeUrl != null && Uri.tryParse(storeUrl!)?.scheme == 'https';
    return Material(
      color: t.sf3,
      elevation: 6,
      shadowColor: t.shadow.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 4, 10),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                child: Icon(LucideIcons.download, size: 18, color: t.pr),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.p01UpdateNoticeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(color: t.mut)),
                  Text(
                    latest == null ? l.updateAvailable : l.updateAvailableVersion(latest!),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (canOpen) ...[
              const SizedBox(width: 8),
              BuButton(label: l.commonUpdate, compact: true, onPressed: () => openStore(storeUrl)),
            ],
            IconButton(
              tooltip: l.commonClose,
              icon: Icon(LucideIcons.x, size: 18, color: t.mut),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
