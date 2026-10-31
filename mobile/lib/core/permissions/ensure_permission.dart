import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import '../locale_controller.dart';
import 'permission_service.dart';

export 'permission_service.dart' show AppPermission, PermState, PermissionService;

/// İzin adı, simge ve varsayılan gerekçe (Türkçe).
class PermissionInfo {
  const PermissionInfo(this.title, this.icon, this.rationale);
  final String title;
  final IconData icon;
  final String rationale;
}

/// [context] verilirse metinler uygulama diline göre gelir (verilmezse Türkçe).
PermissionInfo permissionInfo(AppPermission p, [BuildContext? context]) {
  final l = context?.l10n ?? lookupAppLocalizations(const Locale('tr'));
  return switch (p) {
    AppPermission.notifications =>
      PermissionInfo(l.permNotificationsTitle, LucideIcons.bell, l.permNotificationsText),
    AppPermission.contacts => PermissionInfo(l.permContactsTitle, LucideIcons.contact, l.permContactsText),
    AppPermission.camera => PermissionInfo(l.permCameraTitle, LucideIcons.camera, l.permCameraText),
    AppPermission.microphone => PermissionInfo(l.permMicrophoneTitle, LucideIcons.mic, l.permMicrophoneText),
    AppPermission.photos => PermissionInfo(l.permPhotosTitle, LucideIcons.image, l.permPhotosText),
  };
}

/// Bir özelliğe girerken izni garanti eder: yoksa önce Türkçe gerekçe, sonra sistem istemi;
/// reddedilirse açık mesaj + "Ayarlardan aç". İzin kullanılabilirse true.
/// [service] verilmezse [PermissionService.instance].
Future<bool> ensurePermission(
  BuildContext context,
  AppPermission permission, {
  String? rationale,
  PermissionService? service,
  bool direct = false,
}) async {
  final svc = service ?? PermissionService.instance;
  final info = permissionInfo(permission, context);
  final st = await svc.status(permission);
  if (st.usable) return true;
  if (!context.mounted) return false;
  if (st.needsSettings) {
    await _showSettingsSheet(context, svc, info);
    return false;
  }
  // [direct]: eylemin amacı ortada (örn. 'Fotoğraf çek') olduğundan uygulamanın kendi gerekçe penceresi atlanır;
  // kullanıcı yalnız TEK istem (sistem) görür. Kalıcı reddedilmişse yine ayarlar sayfası gösterilir.
  if (!direct) {
    final go = await _showSheet(
      context,
      icon: info.icon,
      title: info.title,
      text: rationale ?? info.rationale,
      primary: context.l10n.permContinue,
      secondary: context.l10n.permNotNow,
    );
    if (go != true) return false;
  }
  final res = await svc.request(permission);
  if (res.usable) return true;
  // [direct] iken ilk ret sessizdir (kullanıcı az önce kendisi reddetti); sonraki denemede ayarlar sayfası çıkar.
  if (direct && !res.needsSettings) return false;
  if (context.mounted) await _showSettingsSheet(context, svc, info);
  return false;
}

Future<void> _showSettingsSheet(BuildContext context, PermissionService svc, PermissionInfo info) async {
  final l = context.l10n;
  final open = await _showSheet(
    context,
    icon: _deniedIcon(info),
    title: l.p01PermDeniedTitle(info.title),
    text: l.permDeniedText(info.title),
    boldPath: true,
    primary: l.permOpenSettings,
    primaryIcon: LucideIcons.settings,
    secondary: l.permClose,
  );
  if (open == true) await svc.openSettings();
}

/// Reddedilen izin için kesik çizgili/kapalı simge (kamera, mikrofon); diğerlerinde olağan simge.
IconData _deniedIcon(PermissionInfo info) {
  if (info.icon == LucideIcons.camera) return LucideIcons.cameraOff;
  if (info.icon == LucideIcons.mic) return LucideIcons.micOff;
  return info.icon;
}

/// İzin alt sayfası (06/3): halkalı simge, başlık, açıklama, birincil düğme ve düz ikincil düğme.
/// [boldPath] açıkken açıklamadaki "Ayarlar > BÜ Kampüs" yolu kalın yazılır.
Future<bool?> _showSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String text,
  bool boldPath = false,
  required String primary,
  IconData? primaryIcon,
  required String secondary,
}) {
  return BuSheet.show<bool>(
    context,
    builder: (ctx) {
      final t = ctx.bu;
      final tx = Theme.of(ctx).textTheme;
      final body = tx.bodyMedium!.copyWith(color: t.mut, height: 1.55);
      final m = boldPath ? RegExp(r'\S+ > BÜ Kampüs').firstMatch(text) : null;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: ExcludeSemantics(
              child: Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.soft.withValues(alpha: .5), shape: BoxShape.circle),
                child: Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                  child: Icon(icon, size: 28, color: t.pr),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          if (m == null)
            Text(text, textAlign: TextAlign.center, style: body)
          else
            Text.rich(
              TextSpan(
                style: body,
                children: [
                  TextSpan(text: text.substring(0, m.start)),
                  TextSpan(text: m.group(0), style: TextStyle(color: t.ink, fontWeight: FontWeight.w600)),
                  TextSpan(text: text.substring(m.end)),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 24),
          BuButton(label: primary, icon: primaryIcon, onPressed: () => Navigator.pop(ctx, true)),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: t.ink, minimumSize: const Size.fromHeight(48)),
            child: Text(secondary, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
          ),
        ],
      );
    },
  );
}
