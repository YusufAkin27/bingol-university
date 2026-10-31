import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
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
  });

  final ApiClient api;
  final int conversationId;
  final int attachmentId;

  /// Sunucu içeriği tükettiğinde (200 ya da 410) bir kez çağrılır: baloncuk "Açıldı" olur.
  final VoidCallback? onConsumed;

  @override
  State<ViewOnceViewer> createState() => _ViewOnceViewerState();
}

class _ViewOnceViewerState extends State<ViewOnceViewer>
    with WidgetsBindingObserver {
  MemoryImage? _image;
  String? _error;
  IconData _errorIcon = LucideIcons.circleAlert;
  bool _loading = true;
  bool _consumed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
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
          410 => LucideIcons.eyeOff,
          403 => LucideIcons.lock,
          0 => LucideIcons.wifiOff,
          _ => LucideIcons.circleAlert,
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
        PositionedDirectional(
          start: 0,
          end: 0,
          top: 0,
          child: ChatdTopBar(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 12),
            child: SizedBox(
              height: 48,
              child: Row(children: [
                ChatdRoundButton(icon: LucideIcons.x, tooltip: l.chatMiscClose, onPressed: () => Navigator.of(context).maybePop()),
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
      return Center(child: ChatdRing(icon: LucideIcons.image, semantics: l.chatdPhotoLoading));
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
    return Column(mainAxisAlignment: MainAxisAlignment.start, children: [
      Flexible(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image(
              image: img,
              fit: BoxFit.contain,
              frameBuilder: (c, child, frame, sync) => sync
                  ? child
                  : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: BuMotion.of(c, BuMotion.medium), curve: BuMotion.decelerate, child: child),
              errorBuilder: (c, e, s) => ChatdMediaMessage(icon: LucideIcons.imageOff, text: l.chatMiscOnceShowFailed),
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, bottom),
        child: Text(l.p26OnceCaption, textAlign: TextAlign.center, style: tx.labelLarge!.copyWith(color: t.onMedia, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}
