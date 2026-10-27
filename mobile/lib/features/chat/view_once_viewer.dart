import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
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
        _error = switch (e.status) {
          410 => 'Bu fotoğraf artık görüntülenemez.',
          403 => 'Kendi gönderdiğiniz tek gösterimlik fotoğrafı açamazsınız.',
          0 =>
            'Fotoğraf yüklenemedi. Bağlantınızı kontrol edin. Tek gösterimlik olduğu için yeniden açılamayabilir.',
          _ => errorText(e),
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Fotoğraf gösterilemedi. Tek gösterimlik olduğu için yeniden açılamayabilir.';
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
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: _content()),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Container(
            padding: EdgeInsetsDirectional.fromSTEB(4, top + 4, 12, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: .7),
                  Colors.black.withValues(alpha: 0)
                ],
              ),
            ),
            child: Row(children: [
              IconButton(
                tooltip: 'Kapat',
                color: Colors.white,
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 4),
              const OnceBadge(color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Tek gösterimlik',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.label.copyWith(color: Colors.white)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    final err = _error;
    if (err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(err,
                textAlign: TextAlign.center,
                style: BuType.body.copyWith(color: Colors.white70)),
            if (_network) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: _load,
                child: Text('Yeniden dene',
                    style: BuType.bodyStrong.copyWith(color: Colors.white)),
              ),
            ],
          ]),
        ),
      );
    }
    final img = _image;
    if (img == null) return const SizedBox.shrink();
    return Center(
      child: Image(
        image: img,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
              'Fotoğraf gösterilemedi. Tek gösterimlik olduğu için yeniden açılamayabilir.',
              textAlign: TextAlign.center,
              style: BuType.body.copyWith(color: Colors.white70)),
        ),
      ),
    );
  }
}
