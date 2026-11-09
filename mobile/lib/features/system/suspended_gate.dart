import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../auth/help/help_form_page.dart';
import 'gate_views.dart';

/// Destek e-postası sunucudan (`/app/info` `supportEmail`) okunamazsa kullanılan yedek adres.
const kFallbackSupportEmail = 'destek@bingol.edu.tr';

/// E-posta açıcı; testte sahte bir açıcıyla değiştirilir. Açamazsa false döner.
typedef SuspendedMailLauncher = Future<bool> Function(Uri uri);

Future<bool> _defaultMailLauncher(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

@visibleForTesting
SuspendedMailLauncher suspendedMailLauncher = _defaultMailLauncher;

/// Askıya alınmış hesap kapısı. `MaterialApp.builder` içinde, uygulamanın GERÇEK Navigator'ının (kabuk, derin
/// bağlantılar, bildirim dokunuşları, widget bağlantıları hep onu kullanır) YERİNE bu tek ekranı koyar: askı sürerken
/// kök Navigator hiç kurulmaz, bu yüzden hiçbir rota (geri tuşu, derin bağlantı, push, widget) uygulamanın başka
/// bölümünü açamaz. Askı yalnız bellekte tutulur ([Session.suspended]); uygulama yeniden açılınca karar yine sunucudan gelir.
class SuspendedGate extends StatelessWidget {
  const SuspendedGate({super.key, required this.session, required this.child});

  final Session session;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SuspendedState?>(
      valueListenable: session.suspended,
      child: child,
      builder: (context, state, child) =>
          state == null ? child! : _SuspendedHost(key: const ValueKey('suspended-host'), session: session, state: state),
    );
  }
}

/// Kendi küçük Navigator'ı: destek formu bu yığında açılır (Overlay/metin seçimi çalışır), kök yığına dokunulmaz.
class _SuspendedHost extends StatelessWidget {
  const _SuspendedHost({super.key, required this.session, required this.state});

  final Session session;
  final SuspendedState state;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'suspended'),
        builder: (_) => SuspendedAccountScreen(session: session, state: state),
      ),
    );
  }
}

/// Tek tam ekran "Hesabınız askıya alındı": kısa açıklama, destek talebi, iletişim ve farklı hesapla giriş.
/// Gerekçe gösterilmez (sunucu da göndermez). Marka rengi/kalın yazı yok; yalnız BuTokens.
class SuspendedAccountScreen extends StatefulWidget {
  const SuspendedAccountScreen({super.key, required this.session, required this.state});

  final Session session;
  final SuspendedState state;

  @override
  State<SuspendedAccountScreen> createState() => _SuspendedAccountScreenState();
}

class _SuspendedAccountScreenState extends State<SuspendedAccountScreen> {
  String _supportEmail = kFallbackSupportEmail;

  @override
  void initState() {
    super.initState();
    _loadSupportEmail();
  }

  Future<void> _loadSupportEmail() async {
    try {
      final r = await widget.session.api.get('/app/info');
      if (r is! Map) return;
      for (final k in const ['supportEmail', 'contactEmail']) {
        final v = r[k];
        if (v is String && v.contains('@') && !v.contains(RegExp(r'\s'))) {
          if (mounted) setState(() => _supportEmail = v.trim());
          return;
        }
      }
    } catch (_) {
      // Bilerek yutulur: yedek adres gösterilir.
    }
  }

  void _openTicket() {
    final l = context.l10n;
    final s = widget.state;
    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'suspended_ticket'),
      builder: (_) => HelpFormPage(
        session: widget.session,
        prefillName: s.displayName,
        prefillEmail: s.email,
        lockEmail: s.email != null && s.email!.isNotEmpty,
        initialCategory: 'ACCOUNT',
        initialMessage: l.suspMessagePrefill,
        title: l.suspFormTitle,
        subtitle: l.suspFormSub,
      ),
    ));
  }

  Future<void> _contact() async {
    final l = context.l10n;
    final uri = Uri.parse('mailto:$_supportEmail?subject=${Uri.encodeComponent(l.suspMailSubject)}');
    var ok = false;
    try {
      ok = await suspendedMailLauncher(uri);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.suspMailFailed(_supportEmail))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: t.bg,
        body: GateLayout(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GateIcon(icon: BuIcons.shieldX),
              const SizedBox(height: 24),
              GateText(title: l.suspTitle, body: l.suspBody),
              const SizedBox(height: 16),
              Directionality(
                textDirection: TextDirection.ltr,
                child: SelectableText(_supportEmail,
                    key: const ValueKey('susp-support-email'),
                    textAlign: TextAlign.center,
                    style: tx.bodyMedium!.copyWith(color: t.mut)),
              ),
            ],
          ),
          actions: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: BuButton(label: l.suspCreateTicket, icon: BuIcons.messageSquareText, onPressed: _openTicket),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: BuButton(label: l.suspContact, kind: BuButtonKind.outline, onPressed: _contact),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: BuButton(
                    label: l.suspSwitchAccount,
                    icon: BuIcons.logOut,
                    kind: BuButtonKind.text,
                    onPressed: widget.session.dismissSuspended),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
