import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'campus_map_controller.dart';

/// "Konumunuzu kullanalım mı?" kartı (tasarım: Konum izni ve durumlar). İzin yalnız ön planda ve yalnız ekranda
/// mesafe göstermek içindir; konum sunucuya gönderilmez.
class CampusPermissionCard extends StatelessWidget {
  const CampusPermissionCard({super.key, required this.onAllow, required this.onLater, this.framed = true});

  final VoidCallback onAllow;
  final VoidCallback onLater;

  /// false: çerçevesiz (alt sayfa içinde).
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: framed ? BoxDecoration(color: t.sf, borderRadius: BuRadius.bLg, border: Border.all(color: t.bd), boxShadow: BuElevation.of(context, 1)) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: ExcludeSemantics(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: t.soft.withValues(alpha: .6), shape: BoxShape.circle),
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                  child: Icon(BuIcons.mapPin, size: 24, color: t.pr),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(l.campusPermTitle, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 6),
        Text(l.campusPermBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          _Chip(icon: BuIcons.lock, label: l.campusPermChipLocal),
          _Chip(icon: BuIcons.zap, label: l.campusPermChipBattery),
        ]),
        const SizedBox(height: 14),
        BuButton(label: l.campusPermAllow, icon: BuIcons.locateFixed, onPressed: onAllow),
        TextButton(
          onPressed: onLater,
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: t.ink),
          child: Text(l.campusPermLater, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 12, 6),
      decoration: BoxDecoration(color: t.infoSoft, borderRadius: BuRadius.bPill),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: t.onInfoSoft),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: BuType.caption.copyWith(color: t.onInfoSoft, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

/// "Konum kapalı" bandı + "Ayarları aç" (izin reddedildi / kalıcı reddedildi).
class CampusLocationBand extends StatelessWidget {
  const CampusLocationBand({super.key, required this.state, required this.onOpenSettings, required this.onRetry});

  final CampusLocState state;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final forever = state == CampusLocState.deniedForever;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
      decoration: BoxDecoration(color: t.warnSoft, borderRadius: BuRadius.bMd),
      child: Row(children: [
        Icon(BuIcons.locateFixed, size: 20, color: t.onWarnSoft),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(l.campusLocOffBand, style: tx.titleSmall!.copyWith(color: t.onWarnSoft, fontWeight: FontWeight.w800)),
            Text(l.campusLocDeniedBody, style: tx.bodySmall!.copyWith(color: t.onWarnSoft)),
          ]),
        ),
        TextButton(
          onPressed: forever ? onOpenSettings : onRetry,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: t.onWarnSoft),
          child: Text(forever ? l.campusOpenSettings : l.campusPermAllow, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

/// "Konum Servisi Devre Dışı" kartı (cihaz konumu kapalı).
class CampusServiceOffCard extends StatelessWidget {
  const CampusServiceOffCard({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bLg, border: Border.all(color: t.bd), boxShadow: BuElevation.of(context, 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
          Text(l.campusLocServiceTitle, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
          BuBadge(l.campusLocServiceBadge, soft: true),
        ]),
        const SizedBox(height: 4),
        Text(l.campusLocServiceBody, style: tx.bodyMedium!.copyWith(color: t.mut)),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: BuButton(label: l.campusOpenSettings, icon: BuIcons.settings, kind: BuButtonKind.soft, compact: true, onPressed: onOpenSettings),
        ),
      ]),
    );
  }
}

/// Harita yüklenemedi (ağ/sunucu hatası): tasarımdaki hata kartı + "Yeniden dene".
class CampusMapErrorCard extends StatelessWidget {
  const CampusMapErrorCard({super.key, required this.onRetry, this.maintenance = false});

  final VoidCallback onRetry;
  final bool maintenance;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (maintenance) {
      return BuEmptyState(
        illustration: BuIllustration.alert,
        title: l.campusMaintenanceTitle,
        message: l.campusMaintenanceBody,
        actionLabel: l.commonRetry,
        onAction: onRetry,
      );
    }
    return BuErrorState(title: l.campusMapError, message: '', onRetry: onRetry);
  }
}

/// Karolar yüklenemiyor bandı (harita çerçevesi açık kalır; boş gri yüzey yerine açıklama).
class CampusTilesBand extends StatelessWidget {
  const CampusTilesBand({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
      decoration: BoxDecoration(color: t.dangerSoft, borderRadius: BuRadius.bMd, border: Border.all(color: t.danger.withValues(alpha: .3))),
      child: Row(children: [
        Icon(BuIcons.wifiOff, size: 20, color: t.danger),
        const SizedBox(width: 10),
        Expanded(child: Text(l.campusTilesFailing, style: tx.bodySmall!.copyWith(color: t.ink, fontWeight: FontWeight.w600))),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: t.danger),
          child: Text(l.commonRetry, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

/// Basit bilgi bandı (kampüs dışındasınız, kayıtlı liste gösteriliyor...).
class CampusInfoBand extends StatelessWidget {
  const CampusInfoBand({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: t.infoSoft, borderRadius: BuRadius.bMd),
      child: Row(children: [
        Icon(icon ?? BuIcons.info, size: 18, color: t.onInfoSoft),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.onInfoSoft))),
      ]),
    );
  }
}
