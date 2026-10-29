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
  bool _network = false;
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
      _network = false;
    });
    try {
      final bytes = await widget.api.getBytes(
          '/conversations/${widget.conversationId}/media/${widget.attachmentId}');
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
        _network = e.isNetwork;
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
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final showHint = !_loading && _error == null && _image != null;
    return ChatdMediaScaffold(
      body: Stack(children: [
        Positioned.fill(child: _content()),
        PositionedDirectional(
          start: 0,
          end: 0,
          top: 0,
          child: ChatdTopBar(
            child: Row(children: [
              ChatdRoundButton(
                  icon: LucideIcons.x,
                  tooltip: l.chatMiscClose,
                  onPressed: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              OnceBadge(color: t.onMedia, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.chatMiscOnceTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx.titleSmall!.copyWith(
                        color: t.onMedia, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
        if (showHint)
          PositionedDirectional(
            start: 24,
            end: 24,
            bottom: MediaQuery.paddingOf(context).bottom + 20,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: t.scrim.withValues(alpha: .58),
                    borderRadius: BuRadius.bPill),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.eyeOff,
                        size: 15, color: t.onMedia.withValues(alpha: .9)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(l.p08OnceHint,
                          style: tx.labelMedium!.copyWith(
                              color: t.onMedia.withValues(alpha: .92),
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _content() {
    final l = context.l10n;
    if (_loading) {
      return Center(
          child: ChatdRing(icon: LucideIcons.image, semantics: l.chatdPhotoLoading));
    }
    final err = _error;
    if (err != null) {
      return ChatdMediaMessage(
        icon: _errorIcon,
        text: err,
        actionLabel: _network ? l.chatMiscRetry : null,
        onAction: _network ? _load : null,
      );
    }
    final img = _image;
    if (img == null) return const SizedBox.shrink();
    return Center(
      child: Image(
        image: img,
        fit: BoxFit.contain,
        frameBuilder: (c, child, frame, sync) => sync
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: BuMotion.of(c, BuMotion.medium),
                curve: BuMotion.decelerate,
                child: child),
        errorBuilder: (c, e, s) => ChatdMediaMessage(
            icon: LucideIcons.imageOff, text: l.chatMiscOnceShowFailed),
      ),
    );
  }
}
