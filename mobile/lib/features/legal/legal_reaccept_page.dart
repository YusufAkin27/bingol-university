import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../auth/auth_widgets.dart';
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
      child: AuthScaffold(
        icon: LucideIcons.fileText,
        title: l.legalReacceptTitle,
        subtitle: enforced ? l.legalReacceptIntro : l.legalReacceptIntroSoft,
        children: [
          if (_error != null) Notice(_error!),
          Text(l.legalReacceptListTitle, style: BuType.bodyStrong.copyWith(color: t.ink)),
          const SizedBox(height: 8),
          BuGroup(children: [
            for (final i in widget.state.items)
              InkWell(
                onTap: _busy ? null : () => _open(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Icon(LucideIcons.fileText, size: 20, color: t.pr),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_label(i), style: BuType.bodyStrong.copyWith(color: t.ink)),
                        const SizedBox(height: 2),
                        Text(l.profileVersion('${i.version}'), style: BuType.caption.copyWith(color: t.mut)),
                      ]),
                    ),
                    Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: t.mut),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          // Açık rıza (EXPLICIT_CONSENT) ayrıdır: bu onayla verilmiş sayılmaz.
          Text(l.legalReacceptNoteExplicit, style: BuType.caption.copyWith(color: t.mut, height: 1.35)),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _busy ? null : () => setState(() => _ack = !_ack),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    key: const ValueKey('legalReacceptAck'),
                    value: _ack,
                    onChanged: _busy ? null : (v) => setState(() => _ack = v ?? false),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(l.legalReacceptCheck, style: BuType.body.copyWith(color: t.ink, height: 1.35)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          AuthButton(onPressed: (_busy || !_ack) ? null : _accept, busy: _busy, label: l.legalReacceptAccept),
          const SizedBox(height: 4),
          if (!enforced)
            Center(
              child: TextButton(onPressed: _busy ? null : _later, child: Text(l.legalReacceptLater)),
            ),
          Center(
            child: TextButton(
              onPressed: _busy ? null : _decline,
              child: Text(l.legalReacceptDecline, style: TextStyle(color: t.mut)),
            ),
          ),
        ],
      ),
    );
  }
}
