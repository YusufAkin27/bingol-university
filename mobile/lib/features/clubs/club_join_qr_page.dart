import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../profile/profile_qr_widgets.dart';

/// Kulüp katılım QR'ı (yönetici / üye yönetme yetkisi olan üye): bu kodu uygulamadaki tarayıcıyla okutan kişi
/// kulübe DOĞRUDAN katılır (onay beklemeden). Kod kısa ömürlüdür (sunucu 2-3 dk kabul eder); sayfa süre dolmadan
/// kendiliğinden yeniler. Paylaş/kaydet YOKTUR. Yetkiyi sunucu doğrular (403 → açıklayıcı durum).
class ClubJoinQrPage extends StatefulWidget {
  const ClubJoinQrPage({super.key, required this.session, required this.communityId, this.clubName});

  final Session session;
  final int communityId;
  final String? clubName;

  @override
  State<ClubJoinQrPage> createState() => _ClubJoinQrPageState();
}

class _ClubJoinQrPageState extends State<ClubJoinQrPage> {
  /// Kod gösterilirken geçerliliğinde en az bu kadar sn kalacak şekilde yenilenir.
  static const _margin = 75;
  static const _minGap = 20;
  static const _retryGap = 10;

  Timer? _tick;
  String? _code;
  int _validLeft = 0;
  int _refreshLeft = 0;
  bool _loading = true;
  Object? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    unawaited(_load());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _tick = null;
    _gen++; // uçuştaki isteğin sonucu yok sayılır
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {
      if (_validLeft > 0) _validLeft--;
      if (_validLeft == 0 && _code != null) _code = null; // süresi dolan kod gösterilmez
      if (_refreshLeft > 0) _refreshLeft--;
    });
    if (_refreshLeft == 0 && !_loading && !_forbidden) unawaited(_load(silent: true));
  }

  bool get _forbidden => _error is ApiError && (_error as ApiError).status == 403;

  Future<void> _load({bool silent = false}) async {
    final gen = ++_gen;
    if (!silent) setState(() => _loading = true);
    _loading = true;
    try {
      final r = await widget.session.api.get('/communities/${widget.communityId}/join-code');
      if (!mounted || gen != _gen) return;
      final m = r is Map ? r : const {};
      final code = m['code'];
      final valid = (m['validForSeconds'] as num?)?.toInt() ?? 0;
      if (code is! String || code.isEmpty || valid <= 0) throw StateError('bad join code');
      setState(() {
        _code = code;
        _validLeft = valid;
        _refreshLeft = (valid - _margin).clamp(_minGap, valid);
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
        _refreshLeft = _retryGap;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final qrSize = (width - 40 - 24).clamp(220.0, 320.0);
    final name = widget.clubName?.trim();
    final code = _code;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.clubJoinQrTitle, onBack: () => Navigator.maybePop(context)),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.paddingOf(context).bottom + 24),
            children: [
              if (name != null && name.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(name,
                      key: const ValueKey('cjq-name'),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight)),
                ),
              Center(
                child: code == null
                    ? SizedBox(
                        width: qrSize,
                        height: qrSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: kQrPaper, borderRadius: BorderRadius.circular(28)),
                          child: Center(
                            child: _error != null
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(_forbidden ? l.clubJoinQrNoAccess : l.clubJoinQrFailed,
                                        key: const ValueKey('cjq-error'),
                                        textAlign: TextAlign.center,
                                        style: tx.bodyMedium!.copyWith(color: kQrInk)),
                                  )
                                : SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: kQrInk)),
                          ),
                        ),
                      )
                    : ProfileQrPlate(key: const ValueKey('cjq-code'), data: code, size: qrSize, semanticLabel: l.clubJoinQrTitle),
              ),
              const SizedBox(height: 16),
              Text(l.clubJoinQrHint,
                  key: const ValueKey('cjq-hint'),
                  textAlign: TextAlign.center,
                  style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.4)),
              if (code != null) ...[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: false,
                  child: Text(l.clubJoinQrRefresh(_refreshLeft),
                      key: const ValueKey('cjq-countdown'),
                      textAlign: TextAlign.center,
                      style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13)),
                ),
              ],
              if (_error != null && !_forbidden) ...[
                const SizedBox(height: 20),
                BuButton(
                  key: const ValueKey('cjq-retry'),
                  label: l.commonRetry,
                  kind: BuButtonKind.soft,
                  busy: _loading,
                  onPressed: _loading ? null : () => _load(),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}
