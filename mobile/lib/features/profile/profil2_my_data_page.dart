import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'legal_pages.dart';
import 'profil2_delete_account_page.dart';
import 'profil2_widgets.dart';

/// Verilerim: KVKK veri indirme (`GET /users/me/export`, günde 3), aydınlatma metni, hesap silme girişi.
class MyDataPage extends StatefulWidget {
  const MyDataPage({super.key, required this.session});

  final Session session;

  @override
  State<MyDataPage> createState() => _MyDataPageState();
}

class _MyDataPageState extends State<MyDataPage> {
  bool _exporting = false;

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final data = await widget.session.api.get('/users/me/export');
      const enc = JsonEncoder.withIndent('  ');
      await Clipboard.setData(ClipboardData(text: enc.convert(data)));
      if (mounted) _toast(context.l10n.profilePrefsDataCopied);
    } catch (e) {
      if (mounted) {
        _toast(e is ApiError && e.status == 429
            ? (e.message.isNotEmpty ? e.message : context.l10n.profilePrefsExportLimit)
            : errorText(e));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tone = P2Tones.of(context);
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
                Text(l.profil2DataIntro, style: BuType.body.copyWith(color: t.mut, height: 1.5)),
                const SizedBox(height: 14),
                BuCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          P2IconTile(icon: LucideIcons.download, bg: t.soft, color: t.onSoft, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('my-data.json', style: BuType.bodyStrong.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                                Text(l.profil2DataFileSub,
                                    style: BuType.label.copyWith(color: t.mut, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: t.bd),
                      const SizedBox(height: 10),
                      Text(l.profil2DataContents,
                          style: BuType.label.copyWith(color: t.mut, fontWeight: FontWeight.w700, letterSpacing: .6)),
                      const SizedBox(height: 4),
                      for (final s in items) P2BulletLine(text: s, icon: LucideIcons.check, color: tone.okFg),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                BuButton(
                  key: const ValueKey('my-data-download'),
                  label: l.profilePrefsDownloadData,
                  icon: LucideIcons.download,
                  busy: _exporting,
                  onPressed: _exporting ? null : _export,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                  child: Text(l.profil2DataLimit,
                      textAlign: TextAlign.center, style: BuType.label.copyWith(color: t.mut, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 20),
                P2SectionLabel(l.profil2DataOther),
                BuGroup(children: [
                  P2Row(
                    icon: LucideIcons.fileText,
                    iconColor: tone.blue,
                    title: l.profil2DataKvkk,
                    chevron: true,
                    minHeight: 56,
                    onTap: () => _push(LegalListPage(session: widget.session)),
                  ),
                  P2Row(
                    key: const ValueKey('my-data-delete-row'),
                    icon: LucideIcons.trash2,
                    iconColor: tone.dng,
                    title: l.profilePrefsDeleteMyAccount,
                    titleColor: tone.dng,
                    chevron: true,
                    minHeight: 56,
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
