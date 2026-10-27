import 'package:flutter/material.dart';
import '../../core/locale_controller.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';

Future<void> openStore(String? url) async {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Kapatılamaz zorunlu güncelleme ekranı.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.storeUrl});

  final String? storeUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final canOpen = storeUrl != null && Uri.tryParse(storeUrl!)?.scheme == 'https';
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.system_update, size: 57.5, color: t.pr),
                  const SizedBox(height: 20),
                  Text(context.l10n.updateRequiredTitle,
                      style: BuType.title.copyWith(color: t.ink)),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.updateRequiredBody,
                    textAlign: TextAlign.center,
                    style: BuType.body.copyWith(color: t.mut, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (canOpen)
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: t.pr, foregroundColor: t.onPr),
                      onPressed: () => openStore(storeUrl),
                      child: Text(context.l10n.commonOpenInStore),
                    ),
                ],
              ),
            ),
          ),
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

/// 403 ACCESS_BLOCKED: cihaz veya ağ erişimi kapatıldı. Oturum silinmiş olur; yeniden denemek giriş ekranına döner.
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block, size: 57.5, color: t.pr),
                  const SizedBox(height: 20),
                  Text(context.l10n.accessBlockedTitle, style: BuType.title.copyWith(color: t.ink)),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.accessBlockedBody,
                    textAlign: TextAlign.center,
                    style: BuType.body.copyWith(color: t.mut, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(onPressed: onRetry, child: Text(context.l10n.commonRetryShort)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
