import 'package:flutter/material.dart';

import '../../widgets/bu_widgets.dart';
import '../theme.dart';
import '../typography.dart';
import 'permission_service.dart';

export 'permission_service.dart' show AppPermission, PermState, PermissionService;

/// İzin adı, simge ve varsayılan gerekçe (Türkçe).
class PermissionInfo {
  const PermissionInfo(this.title, this.icon, this.rationale);
  final String title;
  final IconData icon;
  final String rationale;
}

PermissionInfo permissionInfo(AppPermission p) => switch (p) {
      AppPermission.notifications => const PermissionInfo(
          'Bildirimler',
          LucideIcons.bell,
          'Mesaj, etkinlik ve duyurulardan anında haberdar olmak için bildirim göndermemize izin verin.'),
      AppPermission.location => const PermissionInfo(
          'Konum',
          LucideIcons.mapPin,
          'Yakındaki etkinlik ve duyuruları gösterebilmek için yaklaşık konumunuzu kullanırız.'),
      AppPermission.contacts => const PermissionInfo(
          'Rehber',
          LucideIcons.contact,
          'Rehberinizdeki Bingöl Üniversitesi kişilerini bulup sohbet başlatabilmeniz için gerekir. '
              'Rehberiniz sunucuya gönderilmez.'),
      AppPermission.camera => const PermissionInfo(
          'Kamera', LucideIcons.camera, 'QR kod okutmak ve fotoğraf çekmek için kameraya erişmemiz gerekir.'),
      AppPermission.microphone => const PermissionInfo(
          'Mikrofon', LucideIcons.mic, 'Ses ve görüntü kaydı yapabilmeniz için mikrofona erişmemiz gerekir.'),
      AppPermission.photos => const PermissionInfo(
          'Fotoğraflar', LucideIcons.image, 'Fotoğraf seçip paylaşabilmeniz için galerinize erişmemiz gerekir.'),
    };

/// Bir özelliğe girerken izni garanti eder: yoksa önce Türkçe gerekçe, sonra sistem istemi;
/// reddedilirse açık mesaj + "Ayarlardan aç". İzin kullanılabilirse true.
/// [service] verilmezse [PermissionService.instance].
Future<bool> ensurePermission(
  BuildContext context,
  AppPermission permission, {
  String? rationale,
  PermissionService? service,
}) async {
  final svc = service ?? PermissionService.instance;
  final info = permissionInfo(permission);
  final st = await svc.status(permission);
  if (st.usable) return true;
  if (!context.mounted) return false;
  if (st.needsSettings) {
    await _showSettingsSheet(context, svc, info);
    return false;
  }
  final go = await _showSheet(
    context,
    info: info,
    text: rationale ?? info.rationale,
    primary: 'Devam',
    secondary: 'Şimdi değil',
  );
  if (go != true) return false;
  final res = await svc.request(permission);
  if (res.usable) return true;
  if (context.mounted) await _showSettingsSheet(context, svc, info);
  return false;
}

Future<void> _showSettingsSheet(BuildContext context, PermissionService svc, PermissionInfo info) async {
  final open = await _showSheet(
    context,
    info: info,
    text: '${info.title} izni verilmedi, bu yüzden bu özellik kullanılamıyor. '
        'İzni Ayarlar > BÜ Kampüs bölümünden açabilirsiniz.',
    primary: 'Ayarlardan aç',
    secondary: 'Kapat',
  );
  if (open == true) await svc.openSettings();
}

Future<bool?> _showSheet(
  BuildContext context, {
  required PermissionInfo info,
  required String text,
  required String primary,
  required String secondary,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.bu.sf,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final t = ctx.bu;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                  child: Icon(info.icon, size: 23.5, color: t.onSoft),
                ),
              ),
              const SizedBox(height: 14),
              Text(info.title, textAlign: TextAlign.center, style: BuType.heading.copyWith(color: t.ink)),
              const SizedBox(height: 8),
              Text(text, textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut)),
              const SizedBox(height: 20),
              BuButton(label: primary, onPressed: () => Navigator.pop(ctx, true)),
              const SizedBox(height: 8),
              BuButton(label: secondary, kind: BuButtonKind.outline, onPressed: () => Navigator.pop(ctx, false)),
            ],
          ),
        ),
      );
    },
  );
}
