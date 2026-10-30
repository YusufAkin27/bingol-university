import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'chatlist_widgets.dart';

/// Sohbet listesi satırına uzun basınca açılan alt sayfa (referans 18: ad başlıkta; Sessize al, Arşivle, Sil).
/// Dönüş: `mute` | `unmute` | `archive` | `unarchive` | `delete`; kapatılırsa null.
/// [canDelete] false ise (kulüp/etkinlik odaları) "Sil" satırı hiç gösterilmez.
Future<String?> showConversationMenu(
  BuildContext context, {
  required String title,
  String? avatarUrl,
  bool group = false,
  required bool muted,
  required bool archived,
  required bool canDelete,
}) {
  final l = context.l10n;
  return BuSheet.show<String>(
    context,
    builder: (c) {
      final tx = Theme.of(c).textTheme;
      final t = c.bu;
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 12),
          child: Row(children: [
            ChatlistAvatar(name: title, url: avatarUrl, group: group, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(color: t.ink)),
              ),
            ),
          ]),
        ),
        _ActionRow(
          id: muted ? 'unmute' : 'mute',
          icon: muted ? LucideIcons.bell : LucideIcons.bellOff,
          label: muted ? l.chatInfoUnmute : l.chatInfoMute,
          onTap: () => Navigator.pop(c, muted ? 'unmute' : 'mute'),
        ),
        _ActionRow(
          id: archived ? 'unarchive' : 'archive',
          icon: LucideIcons.archive,
          label: archived ? l.chatInfoUnarchive : l.chatInfoArchive,
          onTap: () => Navigator.pop(c, archived ? 'unarchive' : 'archive'),
        ),
        if (canDelete) ...[
          Divider(height: 16, color: t.bd),
          _ActionRow(id: 'delete', icon: LucideIcons.trash2, label: l.p06MenuDeleteChat, danger: true, onTap: () => Navigator.pop(c, 'delete')),
        ],
      ]);
    },
  );
}

/// Alt sayfa satırı: yuvarlak tonlu simge + etiket (48 dp'den yüksek dokunma hedefi).
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.onTap, this.danger = false, this.id});

  /// Test/erişim anahtarı: `act-<id>`.
  final String? id;

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final color = danger ? t.danger : t.ink;
    return BuPressable(
      key: id == null ? null : ValueKey('act-$id'),
      onTap: onTap,
      scale: .99,
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: danger ? t.soft : t.sf2, shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: danger ? t.danger : t.ink),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: tx.titleSmall!.copyWith(color: color, fontWeight: FontWeight.w600))),
          if (!danger) Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut),
        ]),
      ),
    );
  }
}
