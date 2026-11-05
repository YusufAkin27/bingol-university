import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/secure_view.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'chat_media_parts.dart';
import 'chatd_parts.dart';
import 'message_bubble.dart' show OnceBadge;

/// Tek gösterimlik fotoğraf görüntüleyicisi: siyah zemin, yakınlaştırma/kopyalama/indirme/paylaşma YOK.
/// Bayt yetkili GET ile alınır (sunucu ilk istekte içeriği tüketir; sonrası 410), yalnız bellekte tutulur ve
/// sayfa kapanınca ya da uygulama arka plana gidince atılır (görüntü önbelleğinden de çıkarılır).
class ViewOnceViewer extends StatefulWidget {
  const ViewOnceViewer({
    super.key,
    required this.api,
    required this.conversationId,
    required this.attachmentId,
    this.onConsumed,
    this.caption,
    this.secureView,
  });

  final ApiClient api;
  final int conversationId;
  final int attachmentId;

  /// Sunucu içeriği tükettiğinde (200 ya da 410) bir kez çağrılır: baloncuk "Açıldı" olur.
  final VoidCallback? onConsumed;

  /// Gönderenin yazdığı açıklama: balonda/kartta ASLA çizilmez, yalnız alıcı fotoğrafı açınca burada görünür.
  final String? caption;

  /// Ekran koruması kanalı (varsayılan: [ChatSecureView.instance]); testlerde değiştirilir.
  final ChatSecureView? secureView;

  @override
  State<ViewOnceViewer> createState() => _ViewOnceViewerState();
}

class _ViewOnceViewerState extends State<ViewOnceViewer>
    with WidgetsBindingObserver {
  MemoryImage? _image;
  String? _error;
  IconData _errorIcon = BuIcons.circleAlert;
  bool _loading = true;
  bool _consumed = false;

  // Ekran koruması (iOS): kayıt/yansıtma sürerken ya da uygulama etkin değilken içerik opak örtüyle gizlenir;
  // ekran görüntüsü algılanırsa görüntü kapatılır. Android'de FLAG_SECURE pencere genelinde zaten devrede.
  late final ChatSecureView _secure = widget.secureView ?? ChatSecureView.instance;
  StreamSubscription<SecureEventKind>? _secureSub;
  bool _captured = false;
  bool _covered = false;
  bool _screenshot = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    _secureSub = _secure.events.listen(_onSecureEvent);
    final st = await _secure.enable();
    if (!mounted) return;
    if (st.captured) {
      // Kayıt sürerken içerik istenmez: tek gösterim tüketilmesin; kayıt bitince yüklenir.
      setState(() {
        _captured = true;
        _loading = false;
      });
      return;
    }
    unawaited(_load());
  }

  void _onSecureEvent(SecureEventKind k) {
    if (!mounted) return;
    switch (k) {
      case SecureEventKind.captureStarted:
        setState(() => _captured = true);
      case SecureEventKind.captureEnded:
        setState(() => _captured = false);
        if (_image == null && _error == null && !_screenshot && !_consumed) unawaited(_load());
      case SecureEventKind.screenshot:
        _drop();
        setState(() => _screenshot = true);
    }
  }

  void _consume() {
    if (_consumed) return;
    _consumed = true;
    widget.onConsumed?.call();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = '/conversations/${widget.conversationId}/media/${widget.attachmentId}';
      List<int> bytes;
      try {
        bytes = await widget.api.getBytes(path);
      } on ApiError catch (e) {
        // Ağ kopması: sunucu yanıt tamamen yazılmadan tüketmez ve aynı kullanıcıya 60 sn içinde yeniden verir (C4);
        // bu yüzden BİR kez yeniden dene; sunucu 2 sn'den önce gelen yinelenen isteği 410 sayar, bu yüzden 2,2 sn bekle.
        // Başka hata (403/410...) yeniden denenmez.
        if (e.status != 0 || !mounted) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 2200));
        if (!mounted) return;
        bytes = await widget.api.getBytes(path);
      }
      _consume(); // istek başarılı: içerik tüketildi, görüntülenemese de "Açıldı" sayılır
      if (!mounted) return;
      setState(() {
        _image = MemoryImage(Uint8List.fromList(bytes));
        _loading = false;
      });
    } on ApiError catch (e) {
      if (e.status == 410) _consume();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorIcon = switch (e.status) {
          410 => BuIcons.eyeOff,
          403 => BuIcons.lock,
          0 => BuIcons.wifiOff,
          _ => BuIcons.circleAlert,
        };
        _error = switch (e.status) {
          410 => context.l10n.chatMiscOnceGone,
          403 => context.l10n.chatMiscOnceOwn,
          0 => context.l10n.chatMiscOnceNetwork,
          _ => errorText(e),
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.l10n.chatMiscOnceShowFailed;
      });
    }
  }

  void _drop() {
    final img = _image;
    _image = null;
    if (img != null) img.evict();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama değiştirici / denetim merkezi: önizleme anlık görüntüsünde içerik görünmesin.
    final cover = state == AppLifecycleState.inactive;
    if (cover != _covered && mounted) setState(() => _covered = cover);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _drop();
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _secureSub?.cancel();
    unawaited(_secure.disable());
    _drop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final top = MediaQuery.paddingOf(context).top + 4 + 48 + 12;
    return ChatdMediaScaffold(
      body: Stack(children: [
        Positioned.fill(child: Padding(padding: EdgeInsets.only(top: top), child: _content())),
        if (_captured || _covered)
          Positioned.fill(
            key: const ValueKey('onceCover'),
            child: ColoredBox(
              color: t.scrim,
              child: Center(
                child: _captured
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(BuIcons.eyeOff, size: 32, color: t.onMedia.withValues(alpha: .8)),
                          const SizedBox(height: 12),
                          Text(l.chatSecureCaptured,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: t.onMedia)),
                        ]),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        PositionedDirectional(
          start: 0,
          end: 0,
          top: 0,
          child: ChatdTopBar(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 12),
            child: SizedBox(
              height: 48,
              child: Row(children: [
                ChatdRoundButton(icon: BuIcons.x, tooltip: l.chatMiscClose, onPressed: () => Navigator.of(context).maybePop()),
                const Spacer(),
                // "Tek gösterimlik" hapı: koyu kırmızı zemin, kesikli "1" simgesi (Stitch'teki "!" yerine).
                ChatdBarPill(
                  iconWidget: OnceBadge(color: t.onMedia, dashed: true, size: 20),
                  label: l.chatMiscOnceTitle,
                  color: Color.alphaBlend(t.pr.withValues(alpha: .38), t.scrim),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _content() {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final bottom = MediaQuery.paddingOf(context).bottom + 20;
    if (_loading) {
      return Center(child: ChatdRing(icon: BuIcons.image, semantics: l.chatdPhotoLoading));
    }
    if (_screenshot) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottom),
        child: ChatdNoteCard(
            key: const ValueKey('onceScreenshot'), text: l.chatSecureScreenshot, icon: BuIcons.shieldAlert),
      );
    }
    final err = _error;
    if (err != null) {
      // Tüketildi / kendi gönderdiğim / ağ hatası: koyu zeminde çerçeveli durum kartı.
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ChatdNoteCard(text: err, icon: _errorIcon),
        ]),
      );
    }
    final img = _image;
    if (img == null) return const SizedBox.shrink();
    final caption = (widget.caption ?? '').trim();
    // Fotoğraf, üst çubuk ile alt ipucu arasındaki alanın ORTASINDA durur (üste yapışmaz, kenara kaymaz): Expanded + Center.
    return Column(mainAxisAlignment: MainAxisAlignment.start, children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: ClipRRect(
            key: const ValueKey('onceImageBox'),
            borderRadius: BorderRadius.circular(20),
            child: Stack(children: [
              Image(
                image: img,
                fit: BoxFit.contain,
                frameBuilder: (c, child, frame, sync) => sync
                    ? child
                    : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: BuMotion.of(c, BuMotion.medium), curve: BuMotion.decelerate, child: child),
                errorBuilder: (c, e, s) => ChatdMediaMessage(icon: BuIcons.imageOff, text: l.chatMiscOnceShowFailed),
              ),
              // Gönderenin açıklaması: yalnız burada, fotoğrafın altında alttan koyulaşan zeminde (uzunsa kaydırılır).
              if (caption.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LayoutBuilder(
                    builder: (c, box) => DecoratedBox(
                      key: const ValueKey('onceCaption'),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [t.scrim.withValues(alpha: .85), t.scrim.withValues(alpha: .6), t.scrim.withValues(alpha: 0)],
                          stops: const [0, .6, 1],
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: box.maxHeight * .45),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                          child: Text(caption,
                              style: tx.bodyLarge!.copyWith(color: t.onMedia, height: 1.4)),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, bottom),
        child: Text(l.p26OnceCaption, textAlign: TextAlign.center, style: tx.labelLarge!.copyWith(color: t.onMedia, fontWeight: FontWeight.w400)),
      ),
    ]);
  }
}
