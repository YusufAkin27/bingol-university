import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'legal_pages.dart';
import 'profil2_delete_account_page.dart';
import 'profil2_widgets.dart';

/// Verilerim (Stitch 08-1/2): KVKK veri indirme (`GET /users/me/export`, günde 3), aydınlatma metni, hesap silme girişi.
class MyDataPage extends StatefulWidget {
  const MyDataPage({super.key, required this.session});

  final Session session;

  @override
  State<MyDataPage> createState() => _MyDataPageState();
}

class _MyDataPageState extends State<MyDataPage> {
  bool _exporting = false;

  /// Günlük sınır aşıldı (429): düğme pasif, kırmızı kart gösterilir.
  String? _limitMessage;

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Future<void> _export() async {
    if (_exporting || _limitMessage != null) return;
    setState(() => _exporting = true);
    try {
      final data = await widget.session.api.get('/users/me/export');
      const enc = JsonEncoder.withIndent('  ');
      await Clipboard.setData(ClipboardData(text: enc.convert(data)));
      if (mounted) BuToast.show(context, context.l10n.profilePrefsDataCopied, kind: BuToastKind.success);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.status == 429) {
        setState(() => _limitMessage = e.message.isNotEmpty ? e.message : context.l10n.profilePrefsExportLimit);
      } else {
        BuToast.show(context, errorText(e), kind: BuToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final items = [
      l.profil2DataItemProfile,
      l.profil2DataItemPrefs,
      l.profil2DataItemClubs,
      l.profil2DataItemSaved,
      l.profil2DataItemSupport,
    ];
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: l.profil2DataTitle, onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(l.profil2DataIntro, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
                ),
                const SizedBox(height: 14),
                BuCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const P2IconTile(icon: LucideIcons.braces, neutral: true, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(l.profil2DataFileSub, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                    ),
                  ]),
                ),
                P2Heading(l.profil2DataContents, top: 20),
                BuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(children: [
                    for (final s in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(color: _limitMessage == null ? t.soft : t.sf2, shape: BoxShape.circle),
                            child: Icon(LucideIcons.check, size: 15, color: _limitMessage == null ? t.pr : t.mut),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(s, style: tx.bodyLarge!.copyWith(fontWeight: FontWeight.w600, color: t.ink))),
                        ]),
                      ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_limitMessage != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: ExcludeSemantics(child: Icon(LucideIcons.info, size: 15, color: t.mut)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: Text(l.profil2DataLimit, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4))),
                  ]),
                ),
                BuButton(
                  key: const ValueKey('my-data-download'),
                  label: l.profilePrefsDownloadData,
                  icon: LucideIcons.download,
                  busy: _exporting,
                  onPressed: (_exporting || _limitMessage != null) ? null : _export,
                ),
                if (_limitMessage != null) ...[
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    container: true,
                    child: Container(
                      key: const ValueKey('my-data-limit'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BuRadius.bMd),
                      child: Row(children: [
                        const P2IconTile(icon: LucideIcons.circleAlert, danger: true, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_limitMessage!,
                              style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onErrorContainer)),
                        ),
                      ]),
                    ),
                  ),
                ],
                P2Heading(l.profil2DataOther, top: 20),
                BuGroup(dividerIndent: 66, children: [
                  BuSettingsTile(
                    icon: LucideIcons.shieldUser,
                    title: l.profil2DataKvkk,
                    tint: t.tint(1),
                    onTap: () => _push(LegalListPage(session: widget.session)),
                  ),
                  BuSettingsTile(
                    key: const ValueKey('my-data-delete-row'),
                    icon: LucideIcons.trash2,
                    title: l.profilePrefsDeleteMyAccount,
                    danger: true,
                    trailing: ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.danger)),
                    onTap: () => _push(DeleteAccountPage(session: widget.session)),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
