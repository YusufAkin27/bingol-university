import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/bu_widgets.dart';
import '../locale_controller.dart';
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
  final go = await _showSheet(
    context,
    info: info,
    text: rationale ?? info.rationale,
    primary: context.l10n.permContinue,
    secondary: context.l10n.permNotNow,
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
    text: context.l10n.permDeniedText(info.title),
    primary: context.l10n.permOpenSettings,
    secondary: context.l10n.permClose,
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
