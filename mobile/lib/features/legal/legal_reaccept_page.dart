import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../auth/widgets/auth_motion.dart';
import '../auth/widgets/auth_ref.dart';
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) {
        final t = sheet.bu;
        final tx = Theme.of(sheet).textTheme;
        return DecoratedBox(
          decoration: BoxDecoration(color: t.sf3, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: t.bd, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                      child: Icon(LucideIcons.triangleAlert, size: 30, color: t.pr),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(l.legalReacceptDeclineTitle,
                        textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 10),
                  Text(l.legalReacceptDeclineBody,
                      textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
                  const SizedBox(height: 20),
                  RefButton(
                    label: l.legalReacceptDeleteAccount,
                    kind: RefButtonKind.danger,
                    icon: LucideIcons.trash2,
                    onPressed: () {
                      Navigator.pop(sheet);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => DeleteAccountPage(session: widget.session)));
                    },
                  ),
                  const SizedBox(height: 10),
                  RefButton(
                    label: l.legalReacceptSignOut,
                    kind: RefButtonKind.secondary,
                    icon: LucideIcons.logOut,
                    onPressed: () {
                      Navigator.pop(sheet);
                      widget.session.signOut();
                    },
                  ),
                  RefLink(label: l.p01LgReview, muted: true, onPressed: () => Navigator.pop(sheet)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final enforced = widget.state.enforced;
    return PopScope(
      canPop: false, // engelleyici ekran: geri tuşu kapatmaz
      child: RefPage(
        showBack: false,
        children: [
          if (_error != null) ...[
            RefBanner(_error!, key: ValueKey('reaccept-error-$_error'), tone: RefTone.warn, boldText: true),
            const SizedBox(height: 16),
          ],
          RefHeading(title: l.legalReacceptTitle, subtitle: enforced ? l.legalReacceptIntro : l.legalReacceptIntroSoft),
          const SizedBox(height: 24),
          Text(l.legalReacceptListTitle, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          // Kart yok (Stitch v3 "15"): düz satırlar + ince ayırıcı.
          Column(
            children: [
              for (var n = 0; n < widget.state.items.length; n++) ...[
                if (n > 0) Divider(height: 1, color: t.bd),
                _DocRow(
                  type: widget.state.items[n].type,
                  title: _label(widget.state.items[n]),
                  version: l.profileVersion('${widget.state.items[n].version}'),
                  onTap: _busy ? null : () => _open(widget.state.items[n]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Açık rıza (EXPLICIT_CONSENT) ayrıdır: bu onayla verilmiş sayılmaz.
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
            child: Text(l.legalReacceptNoteExplicit, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.5)),
          ),
          const SizedBox(height: 20),
          _AckCard(value: _ack, enabled: !_busy, label: l.legalReacceptCheck, onChanged: (v) => setState(() => _ack = v)),
          const SizedBox(height: 16),
          RefButton(
            label: l.legalReacceptAccept,
            icon: LucideIcons.circleCheck,
            busy: _busy,
            onPressed: (_busy || !_ack) ? null : _accept,
          ),
          if (!enforced) ...[
            const SizedBox(height: 8),
            RefButton(label: l.legalReacceptLater, kind: RefButtonKind.ghost, onPressed: _busy ? null : _later),
          ],
          Center(child: RefLink(label: l.legalReacceptDecline, color: t.mut, onPressed: _busy ? null : _decline)),
        ],
      ),
    );
  }
}

/// Güncellenen belge satırı: tonlu simge karosu, başlık, sürüm, sağda ok.
class _DocRow extends StatelessWidget {
  const _DocRow({required this.type, required this.title, required this.version, required this.onTap});

  final String type;
  final String title;
  final String version;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
                      Text(version, style: tx.bodySmall!.copyWith(color: t.mut)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(buDirIcon(context, LucideIcons.chevronRight), size: 20, color: t.mut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Onay kartı: tüm satır dokunulur; kutu dolarken hafif titreşim verir.
class _AckCard extends StatelessWidget {
  const _AckCard({required this.value, required this.enabled, required this.label, required this.onChanged});

  final bool value;
  final bool enabled;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      checked: value,
      child: DecoratedBox(
        decoration: const BoxDecoration(),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('legalReacceptAck'),
            borderRadius: BorderRadius.circular(20),
            onTap: enabled
                ? () {
                    authHaptic(AuthHaptic.tap);
                    onChanged(!value);
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: value ? t.pr : t.sf2,
                    ),
                    child: value ? Icon(LucideIcons.check, size: 18, color: t.onPr) : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(label, style: tx.bodyLarge!.copyWith(color: t.ink, height: 1.4))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
