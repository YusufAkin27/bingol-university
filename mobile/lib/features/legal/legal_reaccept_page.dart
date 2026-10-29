import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../auth/widgets/auth_art.dart';
import '../auth/widgets/auth_controls.dart';
import '../auth/widgets/auth_fields.dart';
import '../auth/widgets/auth_motion.dart';
import '../auth/widgets/auth_shell.dart';
import '../profile/legal_pages.dart';
import '../profile/profil2_delete_account_page.dart';
import 'legal_reaccept.dart';

/// Oturum açıkken kabuğun üstüne, onay bekleyen belge varsa tam ekran "Sözleşmeler güncellendi" ekranı koyar.
/// Kabuk ağaçta kalır (durumu bozulmaz); ekran kabul/"daha sonra" ile kapanınca olduğu gibi devam eder.
/// Açılışta ve uygulama öne gelince durum sorulur; ağ/sunucu hatasında kapı açılmaz (kullanıcı kilitlenmez).
class LegalReacceptGate extends StatefulWidget {
  const LegalReacceptGate({super.key, required this.session, required this.child});

  final Session session;
  final Widget child;

  @override
  State<LegalReacceptGate> createState() => _LegalReacceptGateState();
}

class _LegalReacceptGateState extends State<LegalReacceptGate> with WidgetsBindingObserver {
  static const _minGap = Duration(minutes: 5);
  DateTime? _last;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final last = _last;
    if (s == AppLifecycleState.resumed && (last == null || DateTime.now().difference(last) >= _minGap)) {
      _check();
    }
  }

  void _check() {
    _last = DateTime.now();
    widget.session.legal.check(userId: widget.session.userId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session.legal,
      builder: (context, _) {
        final state = widget.session.legal.current;
        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (state != null)
              Positioned.fill(
                child: LegalReacceptPage(key: ValueKey(state.signature), session: widget.session, state: state),
              ),
          ],
        );
      },
    );
  }
}

/// "Sözleşme güncellendi" ekranı: belge listesi (her biri tam metne açılır), tek onay kutusu, Kabul et.
/// `enforced` iken atlanamaz; değilse "Daha sonra" ile geçilebilir. "Kabul etmiyorum" → hesap silme / çıkış.
class LegalReacceptPage extends StatefulWidget {
  const LegalReacceptPage({super.key, required this.session, required this.state});

  final Session session;
  final LegalReaccept state;

  @override
  State<LegalReacceptPage> createState() => _LegalReacceptPageState();
}

class _LegalReacceptPageState extends State<LegalReacceptPage> {
  bool _ack = false;
  bool _busy = false;
  String? _error;
  // type -> yayımlanmış başlık (istek dilinde); alınamazsa yerel ad kullanılır.
  Map<String, String> _titles = const {};

  @override
  void initState() {
    super.initState();
    _loadTitles();
  }

  Future<void> _loadTitles() async {
    try {
      final r = await widget.session.api.get('/legal');
      if (!mounted || r is! List) return;
      final m = <String, String>{};
      for (final d in r) {
        if (d is Map && d['type'] is String && d['title'] is String) m[d['type'] as String] = d['title'] as String;
      }
      setState(() => _titles = m);
    } catch (_) {}
  }

  String _label(LegalItem i) {
    final l = context.l10n;
    final fromServer = _titles[i.type];
    if (fromServer != null && fromServer.trim().isNotEmpty) return fromServer;
    return switch (i.type) {
      'TERMS' => l.legalReacceptTypeTerms,
      'PRIVACY' => l.legalReacceptTypePrivacy,
      'KVKK' => l.legalReacceptTypeKvkk,
      'COMMUNITY_RULES' => l.legalReacceptTypeRules,
      _ => l.profileLegalDocFallback,
    };
  }

  Future<void> _accept() async {
    if (_busy || !_ack) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.legal.accept();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _ack = false;
        _error = e.code == 'VERSION_OUTDATED' ? context.l10n.legalReacceptOutdated : errorText(e);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
    // Başarıda denetleyici ekranı kapatır (bu widget ağaçtan kalkar).
  }

  Future<void> _later() => widget.session.legal.defer();

  void _open(LegalItem i) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => LegalDocPage(session: widget.session, type: i.type)));
  }

  Future<void> _decline() async {
    final l = context.l10n;
    final t = context.bu;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.legalReacceptDeclineTitle, style: BuType.title.copyWith(color: t.ink)),
            const SizedBox(height: 10),
            Text(l.legalReacceptDeclineBody, style: BuType.body.copyWith(color: t.mut, height: 1.4)),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: t.danger,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () {
                Navigator.pop(sheet);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DeleteAccountPage(session: widget.session)),
                );
              },
              child: Text(l.legalReacceptDeleteAccount),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () {
                Navigator.pop(sheet);
                widget.session.signOut();
              },
              child: Text(l.legalReacceptSignOut),
            ),
            TextButton(onPressed: () => Navigator.pop(sheet), child: Text(l.commonCancel)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final enforced = widget.state.enforced;
    return PopScope(
      canPop: false, // engelleyici ekran: geri tuşu kapatmaz
      child: AuthShell(
        art: AuthArtKind.shield,
        title: l.legalReacceptTitle,
        subtitle: enforced ? l.legalReacceptIntro : l.legalReacceptIntroSoft,
        body: [
          AuthFeedbackSlot(error: _error),
          Text(l.legalReacceptListTitle, style: BuType.label.copyWith(color: t.mut, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: .4)),
          const SizedBox(height: 10),
          for (final i in widget.state.items) ...[
            _DocCard(title: _label(i), version: l.profileVersion('${i.version}'), onTap: _busy ? null : () => _open(i)),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          // Açık rıza (EXPLICIT_CONSENT) ayrıdır: bu onayla verilmiş sayılmaz.
          AuthTrustNote(l.legalReacceptNoteExplicit, icon: LucideIcons.info),
          const SizedBox(height: 18),
          _AckCard(value: _ack, enabled: !_busy, label: l.legalReacceptCheck, onChanged: (v) => setState(() => _ack = v)),
        ],
        bottom: [
          AuthPrimaryButton(onPressed: (_busy || !_ack) ? null : _accept, busy: _busy, label: l.legalReacceptAccept),
          if (!enforced) Center(child: AuthTextAction(label: l.legalReacceptLater, onPressed: _busy ? null : _later)),
          Center(child: AuthTextAction(label: l.legalReacceptDecline, muted: true, onPressed: _busy ? null : _decline)),
        ],
      ),
    );
  }
}

/// Güncellenen belge kartı: sol simge karosu, başlık, sürüm hapı, sağda ok.
class _DocCard extends StatelessWidget {
  const _DocCard({required this.title, required this.version, required this.onTap});

  final String title;
  final String version;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      child: Material(
        color: t.sf,
        borderRadius: BorderRadius.circular(kAuthRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kAuthRadius),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kAuthRadius),
              border: Border.all(color: t.bd),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(14)),
                  child: Icon(LucideIcons.fileText, size: 20, color: t.pr),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: BuType.bodyStrong.copyWith(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(999)),
                        child: Text(version, style: BuType.caption.copyWith(color: t.mut, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                Icon(buDirIcon(context, LucideIcons.chevronRight), size: 20, color: t.mut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Onay kartı: tüm satır dokunulur; kutu dolarken yaylanır ve hafif titreşim verir.
class _AckCard extends StatelessWidget {
  const _AckCard({required this.value, required this.enabled, required this.label, required this.onChanged});

  final bool value;
  final bool enabled;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      checked: value,
      inMutuallyExclusiveGroup: false,
      child: Material(
        color: value ? t.soft : t.sf,
        borderRadius: BorderRadius.circular(kAuthRadius),
        child: InkWell(
          key: const ValueKey('legalReacceptAck'),
          borderRadius: BorderRadius.circular(kAuthRadius),
          onTap: enabled
              ? () {
                  authHaptic(AuthHaptic.tap);
                  onChanged(!value);
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kAuthRadius),
              border: Border.all(color: value ? t.pr : t.bd, width: value ? 1.6 : 1.2),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: value ? t.pr : Colors.transparent,
                    border: Border.all(color: value ? t.pr : t.mut, width: 2),
                  ),
                  child: AnimatedScale(
                    scale: value ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Icon(LucideIcons.check, size: 16, color: t.onPr),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: BuType.body.copyWith(color: t.ink, height: 1.4, fontSize: 14.5, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
