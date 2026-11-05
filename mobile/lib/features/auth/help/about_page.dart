import 'package:flutter/material.dart';

import '../../../core/app_gate.dart' show appVersion;
import '../../../core/locale_controller.dart';
import '../../../core/session.dart';
import '../../../widgets/bu.dart';
import '../../profile/legal_pages.dart';
import 'help_form_page.dart';
import 'help_track_page.dart';
import 'public_support_api.dart';

/// Hakkında (Stitch v3 "27", giriş öncesi herkese açık): ad, sürüm, tek paragraf; sözleşme satırları (herkese açık
/// `GET /api/legal/...`), "Yardım al" ve bu cihazda kayıtlı talep varsa "Talebim". Logo, üniversite adı başlığı,
/// "Resmî" ve iletişim bilgisi yoktur.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key, required this.session});

  final Session session;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final t = await TrackTokenStore.read();
    if (mounted) setState(() => _token = t);
  }

  void _push(Widget page, [String? screen]) => Navigator.push(context, MaterialPageRoute(settings: RouteSettings(name: screen), builder: (_) => page)).then((_) => _loadToken());

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final rows = <(String, VoidCallback)>[
      (l.legalReacceptTypeTerms, () => _push(LegalDocPage(session: widget.session, type: 'TERMS'), 'legal_doc')),
      (l.legalReacceptTypePrivacy, () => _push(LegalDocPage(session: widget.session, type: 'PRIVACY'), 'legal_doc')),
      (l.legalReacceptTypeKvkk, () => _push(LegalDocPage(session: widget.session, type: 'KVKK'), 'legal_doc')),
      (l.legalReacceptTypeRules, () => _push(LegalDocPage(session: widget.session, type: 'COMMUNITY_RULES'), 'legal_doc')),
      if (_token != null) (l.p66MyTicket, () => _push(HelpTrackPage(session: widget.session, token: _token!), 'help_track')),
      (l.p66HelpAction, () => _push(HelpFormPage(session: widget.session), 'help_form')),
    ];
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: l.profileAboutShort, onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                Text('BÜ Kampüs', style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
                const SizedBox(height: 4),
                Text(l.profileVersion(appVersion), style: tx.bodyMedium!.copyWith(color: t.mut)),
                const SizedBox(height: 16),
                Text(l.p66AboutBody, style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.5)),
                const SizedBox(height: 24),
                Divider(height: 1, color: t.bd),
                for (final r in rows) ...[
                  InkWell(
                    onTap: r.$2,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Row(
                        children: [
                          Expanded(child: Text(r.$1, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight))),
                          Icon(buDirIcon(context, BuIcons.chevronRight), size: 20, color: t.mut),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: t.bd),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
