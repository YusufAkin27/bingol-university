import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';

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
                  Icon(Icons.system_update, size: 64, color: t.pr),
                  const SizedBox(height: 20),
                  Text('Güncelleme gerekli',
                      style: TextStyle(color: t.ink, fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text(
                    'Uygulamayı kullanmaya devam etmek için yeni sürüme güncellemeniz gerekiyor.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.mut, fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (canOpen)
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: t.pr, foregroundColor: t.onPr),
                      onPressed: () => openStore(storeUrl),
                      child: const Text('Mağazada aç'),
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
    final fg = danger ? Colors.white : t.onSoft;
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: fg, fontSize: 12.5, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
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
            Icon(Icons.system_update, color: t.pr, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                latest == null ? 'Yeni sürüm mevcut.' : 'Yeni sürüm mevcut ($latest).',
                style: TextStyle(color: t.ink, fontSize: 14),
              ),
            ),
            if (canOpen) TextButton(onPressed: () => openStore(storeUrl), child: const Text('Güncelle')),
            IconButton(
              tooltip: 'Kapat',
              icon: Icon(Icons.close, size: 18, color: t.mut),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
