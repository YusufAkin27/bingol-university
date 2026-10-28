import 'package:flutter/material.dart';
import '../../core/locale_controller.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/sistem_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Future<void> openStore(String? url) async {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Kapatılamaz zorunlu güncelleme ekranı (Sm5). [latest] verilirse sürüm satırı gösterilir.
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
    final canOpen = storeUrl != null && Uri.tryParse(storeUrl!)?.scheme == 'https';
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: SistemStatusView(
            icon: LucideIcons.download,
            title: context.l10n.updateRequiredTitle,
            body: context.l10n.updateRequiredBody,
            extras: [
              if (latest != null && current != null)
                Text(context.l10n.sistemuiUpdateVersions(current!, latest!),
                    textAlign: TextAlign.center, style: BuType.label.copyWith(color: t.mut)),
            ],
            footer: [
              if (canOpen) SistemButton(label: context.l10n.commonOpenInStore, onPressed: () => openStore(storeUrl)),
              if (onRetry != null) ...[
                if (canOpen) const SizedBox(height: 10),
                SistemButton(
                  key: const ValueKey('update-recheck'),
                  label: context.l10n.updateRequiredRecheck,
                  onPressed: onRetry,
                  kind: canOpen ? SistemButtonKind.link : SistemButtonKind.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tam ekran bakım görünümü (Sm4): bakım modu açıkken kullanılabilir; [band] ek uyarı bandıdır.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key, required this.onRetry, this.message});

  final VoidCallback onRetry;

  /// Yönetici mesajı; yoksa varsayılan açıklama.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SistemStatusView(
          icon: LucideIcons.wrench,
          title: context.l10n.sistemuiMaintTitle,
          body: message ?? context.l10n.sistemuiMaintBody,
          extras: [MaintenanceBand(text: context.l10n.sistemuiMaintBand)],
          footer: [SistemButton(label: context.l10n.commonRetry, onPressed: onRetry)],
        ),
      ),
    );
  }
}

/// Tam ekran "bağlantı yok" görünümü (Sm3).
class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SistemStatusView(
          icon: LucideIcons.wifiOff,
          title: context.l10n.sistemuiOfflineTitle,
          body: context.l10n.sistemuiOfflineBody,
          footer: [SistemButton(label: context.l10n.commonRetry, onPressed: onRetry)],
        ),
      ),
    );
  }
}

/// Üst şerit: bakım, duyuru ve çevrimdışı için ortak görünüm.
class TopStrip extends StatelessWidget {
  const TopStrip({super.key, required this.icon, required this.text, this.danger = false});

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bg = danger ? t.danger : t.soft;
    // Koyu temada danger açık tondur (FF8A82): sabit beyaz yazı okunmazdı; zemin rengi (t.bg) her iki temada AA verir.
    final fg = danger ? t.bg : t.onSoft;
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14.5, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: BuType.label.copyWith(color: fg, decoration: TextDecoration.none)),
          ),
        ],
      ),
    );
  }
}

/// Kapatılabilir "yeni sürüm var" alt bildirimi.
class UpdateNotice extends StatelessWidget {
  const UpdateNotice({super.key, required this.latest, required this.storeUrl, required this.onClose});

  final String? latest;
  final String? storeUrl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final canOpen = storeUrl != null && Uri.tryParse(storeUrl!)?.scheme == 'https';
    return Material(
      color: t.sf,
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
        child: Row(
          children: [
            Icon(Icons.system_update, color: t.pr, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                latest == null ? context.l10n.updateAvailable : context.l10n.updateAvailableVersion(latest!),
                style: BuType.body.copyWith(color: t.ink),
              ),
            ),
            if (canOpen) TextButton(onPressed: () => openStore(storeUrl), child: Text(context.l10n.commonUpdate)),
            IconButton(
              tooltip: context.l10n.commonClose,
              icon: Icon(Icons.close, size: 16, color: t.mut),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// 403 ACCESS_BLOCKED (Sm6): cihaz veya ağ erişimi kapatıldı. Oturum silinmiş olur; yeniden denemek giriş ekranına döner.
class AccessBlockedScreen extends StatelessWidget {
  const AccessBlockedScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: SistemStatusView(
            icon: LucideIcons.shieldOff,
            title: context.l10n.accessBlockedTitle,
            body: context.l10n.accessBlockedBody,
            extras: [
              Text(context.l10n.sistemuiBlockedCode,
                  textAlign: TextAlign.center, style: BuType.label.copyWith(color: t.mut)),
            ],
            footer: [SistemButton(label: context.l10n.commonRetryShort, onPressed: onRetry)],
          ),
        ),
      ),
    );
  }
}
