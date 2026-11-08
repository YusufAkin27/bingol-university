import '../chat/emoji_presentation.dart';
import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:video_player/video_player.dart';
import 'package:image/image.dart' as img;

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/platform/video_service.dart';
import '../../core/platform/video_frame.dart' show VideoFrameSource;
import '../../core/platform/video_trim.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../media_crop/media_crop.dart';
import 'mention_picker_sheet.dart';
import '../chat/chat_media.dart' show formatMediaDuration;
import '../chat/media_library.dart' show MediaLibrary;
import 'post_api.dart';
import 'post_gallery_picker_page.dart';
import 'post_media_uploader.dart';
import 'post_models.dart';
import 'post_text_rules.dart';
import 'post_video.dart';
import 'post_video_limits.dart';
import 'social_models.dart' show SocialUser;
import 'video_trim_page.dart';

/// Galeriden ya da kameradan tek fotoğraf baytı döndürür (iptalde null); testlerde sahtesi verilir.
typedef PostPhotoPicker = Future<Uint8List?> Function(ImageSource source);

/// Seçilen fotoğrafı 4:5 kırptırır (vazgeçilirse null); testlerde sahtesi verilir.
typedef PostPhotoCropper = Future<CropOutcome?> Function(BuildContext context, Uint8List bytes, CropSpec spec);

/// Galeriden en çok [limit] fotoğraf seçtirir (çoklu seçim; iptalde boş liste); testlerde sahtesi verilir.
typedef PostPhotosPicker = Future<List<Uint8List>> Function(int limit);

/// Bir gönderideki en çok fotoğraf sayısı (sunucu sınırıyla aynı: 422 `POST_MEDIA_LIMIT`).
const int kPostMaxPhotos = 10;

Future<List<Uint8List>> _defaultMultiPicker(int limit) async {
  if (limit <= 0) return const [];
  if (limit == 1) {
    final one = await ImageService().pick(ImageSource.gallery);
    return one == null ? const [] : [await one.readAsBytes()];
  }
  final files = await ImagePicker().pickMultiImage(
      limit: limit, maxWidth: ImageService.maxEdge, maxHeight: ImageService.maxEdge, imageQuality: ImageService.quality, requestFullMetadata: false);
  return [for (final f in files.take(limit)) await f.readAsBytes()];
}

/// Gönderideki fotoğraf (sıralı liste öğesi); yüklenince [uploaded] doldurulur (yeniden denemede tekrar yüklenmez).
class _Shot {
  _Shot(this.bytes, this.aspect, {this.uploaded, this.orig});

  final Uint8List bytes;
  final double aspect;
  final Uint8List? orig;
  PostMedia? uploaded;
}

Future<Uint8List?> _defaultPicker(ImageSource source) async {
  final f = await ImageService().pick(source);
  return f?.readAsBytes();
}

/// Paylaşım türü: fotoğraf ya da video/Reels (metin-only gönderi backend'de yoktur: menüde de yok).
enum ComposeKind { photo, video }

/// Paylaş girişi (alt çubuk "+", Keşfet "+", Profil "Gönderi ekle"...): seçenek sayfası YOK; doğrudan galeri seçici
/// ([PostGalleryPickerPage]: ilk karede kamera, fotoğraf + video ızgarası) açılır, seçilen öğe oluşturucuya geçer.
/// [kind] verilirse ya da [menu] false ise seçici atlanıp boş oluşturucu açılır (eski doğrudan yol). Vazgeçilirse null.
Future<Post?> openComposePost(BuildContext context, Session session, {ComposeKind? kind, bool menu = true, MediaLibrary? library}) {
  if (kind == null && menu) return openPostGalleryPicker(context, session, library: library);
  return Navigator.of(context).push<Post>(
    MaterialPageRoute(settings: const RouteSettings(name: 'compose_post'), fullscreenDialog: true, builder: (_) => ComposePostPage(session: session, initialKind: kind)),
  );
}

enum _Err { none, generic, profanity, rate, network }

/// Önizleme / boş alan köşesi (Stitch v3: 24 dp).
const double kComposeRadius = 16;

/// Gönderi oluşturucu: tam 1 fotoğraf (4:5 kırpılır) VEYA 1 video (en çok [PostVideoLimits.maxDurationMs] / 50 MB;
/// daha uzunsa uygulamada kırpılır) + isteğe bağlı, istenen uzunlukta çok satırlı metin (sayaç/sınır metni YOK; sunucunun
/// gizli sınırında giriş sessizce durur) + takip ettiğim kişilerden etiketler (`@Ad Soyad`, en çok 10). Medya
/// `POST /posts/media` ile yüklenir (video: ilerleme çubuğu, poster karesiyle), sonra gönderi
/// `mediaIds: [id]` + `mentionUserIds` ile oluşturulur.
class ComposePostPage extends StatefulWidget {
  const ComposePostPage({
    super.key,
    required this.session,
    this.pickPhoto,
    this.pickPhotos,
    this.cropPhoto,
    this.uploader,
    this.api,
    this.videoService,
    this.videoUploader,
    this.initialKind,
    this.initialPhoto,
    this.initialVideoPath,
    this.trimService,
    this.trimFrames,
    this.mentionFetch,
  });

  final Session session;

  /// Açılışta doğrudan ilgili kaynak seçiciyi aç (eski doğrudan yol).
  final ComposeKind? initialKind;

  /// Galeri seçiciden gelen öğe: fotoğraf baytı (hemen kırpma düzenleyicisi açılır) ya da video yolu (süre sınırı
  /// aşılıyorsa zorunlu kırpma, değilse hazırlama). Bu kipte "Değiştir"/vazgeçme galeri seçiciye geri döner.
  final Uint8List? initialPhoto;
  final String? initialVideoPath;

  /// Testler için: video seçme/hazırlama ve yükleme enjeksiyonu.
  final VideoService? videoService;
  final VideoUploader? videoUploader;

  /// Testler için: kırpma motoru, kırpma ekranının küçük resim kaynağı ve takip listesi sayfası.
  final VideoTrimService? trimService;
  final VideoFrameSource? trimFrames;
  final FollowingFetcher? mentionFetch;

  /// Testler için: seçici/kırpıcı/yükleyici/API enjeksiyonu.
  final PostPhotoPicker? pickPhoto;
  final PostPhotosPicker? pickPhotos;
  final PostPhotoCropper? cropPhoto;
  final PostMediaUploader? uploader;
  final PostApi? api;

  @override
  State<ComposePostPage> createState() => _ComposePostPageState();
}

class _ComposePostPageState extends State<ComposePostPage> {
  final _text = EmojiTextEditingController();
  final _focus = FocusNode();
  late final PostMediaUploader _uploader = widget.uploader ?? PostMediaUploader(widget.session);
  late final PostApi _api = widget.api ?? PostApi(widget.session);
  late final VideoService _videoSvc = widget.videoService ??
      VideoService(limitBytes: PostVideoLimits.maxBytes, limitMs: PostVideoLimits.maxDurationMs);
  late final VideoTrimService _trimSvc = widget.trimService ?? VideoTrimService.instance;
  late final VideoUploader _videoUp = widget.videoUploader ?? VideoUploader(widget.session);

  // Video: seçildi + hazırlandı (en çok 60 sn / 50 MB), yüklendi mi, ilerleme (0..1).
  PreparedVideo? _video;
  PostMedia? _uploadedVideo;
  VideoCancel? _prepCancel;
  List<Uint8List> _frames = const []; // kapak karesi adayları (video başına en çok 6)
  int _coverIndex = 0;
  bool _preparing = false;
  bool _trimming = false; // hazırlama etiketi: "Video kırpılıyor…"
  double _progress = 0;

  // Video kırpma: seçilen özgün dosya (yeniden düzenleme için tutulur), son aralık, kesimle üretilen geçici dosya ve
  // sınırdan uzun olup henüz kırpılmamış video (paylaşım kapalı, "Videoyu kırp" gösterilir).
  String? _srcPath;
  int _srcMs = 0;
  VideoTrimRange? _range;
  String? _trimmedPath;
  ({String path, int durationMs})? _longPending;

  // Etiketler: seçilen kişiler; metinde `@Ad Soyad` olarak durdukları sürece geçerlidir.
  final _mentions = <SocialUser>[];
  String _prevText = '';

  Uint8List? _original; // kırpılmamış seçim (yeniden kırpmak için)
  Uint8List? _photo; // düzenlenmiş fotoğraf (varsayılan 4:5; düzenleyicide oran seçilebilir)
  double _photoAspect = 4 / 5; // önizleme oranı: düzenlenmiş fotoğrafın gerçek oranı (0.5-1.91)
  final String _idemKey = PostApi.newIdempotencyKey(); // bu paylaşma niyeti için tek anahtar (yeniden denemede aynı)
  PostMedia? _uploaded; // aynı fotoğraf için yeniden yüklemeyi önler (metin hatasından sonra tekrar dene)
  bool _publishing = false;

  // Gelişmiş ayarlar (varsayılan kapalı): beğeni sayısını başkalarından gizle, yorumları kapat.
  bool _advOpen = false;
  bool _hideLikes = false;
  bool _commentsOff = false;

  /// Ek fotoğraflar (ilk fotoğraf `_photo`dadır): toplam en çok [kPostMaxPhotos].
  final _extras = <_Shot>[];
  int _upDone = 0; // yükleme ilerlemesi (çoklu fotoğraf): biten / toplam
  int _upTotal = 0;
  _Err _err = _Err.none;
  String _errText = '';
  int _wait = 0; // hız sınırı geri sayımı (sn)
  Timer? _timer;

  /// Galeri seçiciden açıldı: medya değiştirme/silme ve vazgeçme galeriye geri döner (boş seçici ekranı yok).
  bool get _fromGallery => widget.initialPhoto != null || widget.initialVideoPath != null;

  @override
  void initState() {
    super.initState();
    final photo = widget.initialPhoto;
    final video = widget.initialVideoPath;
    if (photo != null || video != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (photo != null) {
          await _startPhoto(photo);
        } else {
          await _acceptVideo(video!);
        }
      });
    }
    final k = widget.initialKind;
    if (k != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (k == ComposeKind.photo) {
          await _chooseSource();
        } else {
          final src = await showPhotoSourceSheet(context, simple: true);
          if (src != null && mounted) await _pickVideo(src == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery);
        }
      });
    }
  }

  @override
  void dispose() {
    _prepCancel?.cancel();
    final tmp = _trimmedPath;
    if (tmp != null) unawaited(_trimSvc.discard(tmp));
    _timer?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _dirty => _photo != null || _video != null || _preparing || _longPending != null || _text.text.trim().isNotEmpty;
  bool get _canShare => !_publishing && !_preparing && (_photo != null || _video != null);

  CropSpec get _spec => CropSpec.post(
        previewName: widget.session.displayName,
        previewCaption: _text.text.trim(),
        allowChange: true,
      );

  Future<CropOutcome?> _crop(Uint8List bytes) => (widget.cropPhoto ?? ((c, b, s) => editPhoto(c, b, s)))(context, bytes, _spec);

  void _setError(Object e) {
    final l = context.l10n;
    _errText = postErrorText(e, l);
    _timer?.cancel();
    _wait = 0;
    if (e is ApiError && e.code == 'CONTENT_PROFANITY') {
      _err = _Err.profanity;
    } else if (e is ApiError && e.status == 429) {
      _err = _Err.rate;
      _wait = e.retryAfter ?? 0;
      if (_wait > 0) {
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted || _wait <= 1) {
            t.cancel();
            if (mounted) setState(() => _wait = 0);
            return;
          }
          setState(() => _wait--);
        });
      }
    } else if (e is ApiError && e.isNetwork) {
      _err = _Err.network;
    } else {
      _err = _Err.generic;
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_publishing) return;
    FocusScope.of(context).unfocus();
    try {
      var src = source;
      while (true) {
        final bytes = await (widget.pickPhoto ?? _defaultPicker)(src);
        if (bytes == null || !mounted) return;
        final out = await _crop(bytes);
        if (out == null || !mounted) return;
        if (out.changeRequested) {
          src = ImageSource.gallery;
          continue;
        }
        final cropped = out.bytes;
        if (cropped == null) return;
        setState(() {
          _original = bytes;
          _photo = cropped;
          _photoAspect = _aspectOf(cropped);
          _uploaded = null;
          _err = _Err.none;
        });
        return;
      }
    } catch (e) {
      if (mounted) setState(() => _setError(e));
    }
  }

  /// Galeri seçiciden gelen fotoğraf: kırpma düzenleyicisi hemen açılır; vazgeçilir ya da "Değiştir" denirse galeriye dönülür.
  Future<void> _startPhoto(Uint8List bytes) async {
    try {
      final out = await _crop(bytes);
      if (!mounted) return;
      final cropped = out?.bytes;
      if (out == null || out.changeRequested || cropped == null) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        _original = bytes;
        _photo = cropped;
        _photoAspect = _aspectOf(cropped);
        _uploaded = null;
        _err = _Err.none;
      });
    } catch (e) {
      if (mounted) setState(() => _setError(e));
    }
  }

  /// Galeriye dön (oluşturucuyu kapat); yazılmış metin varsa önce vazgeçme onayı sorulur.
  Future<void> _backToGallery() async {
    if (_publishing || _preparing) return;
    if (_text.text.trim().isNotEmpty) {
      final ok = await showDialog<bool>(context: context, builder: (c) => const _DiscardDialog());
      if (ok != true || !mounted) return;
    }
    unawaited(_discardTrimmed());
    Navigator.pop(context);
  }

  /// "Fotoğraf seç": iki satırlık kaynak sayfası (Galeri / Kamera); kamera izni tek istemle ImageService'te istenir.
  Future<void> _chooseSource() async {
    if (_publishing) return;
    final src = await showPhotoSourceSheet(context, simple: true);
    if (src == null || !mounted) return;
    await _pick(src == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery);
  }

  /// Video seç/çek. Süre ölçülür: sınırdan uzunsa kırpma ekranı ZORUNLU açılır (kırpılmadan paylaşılamaz); değilse
  /// doğrudan hazırlanır (Android'de gerekirse 720p'ye sıkıştırılır). "Düzenle" ile istenirse yine kırpılabilir.
  Future<void> _pickVideo(ImageSource source) async {
    if (_publishing || _preparing) return;
    FocusScope.of(context).unfocus();
    try {
      final picked = await _videoSvc.pick(source);
      if (picked == null || !mounted) return;
      await _acceptVideo(picked.path);
    } catch (e) {
      if (mounted) setState(() => _setError(e));
    }
  }

  /// Seçilen/çekilen videoyu işler (sistem seçicisi, kamera ya da galeri ızgarası ortak yolu): süre sınırı aşılıyorsa
  /// kırpma zorunlu, değilse doğrudan hazırlanır.
  Future<void> _acceptVideo(String path) async {
    try {
      final info = await _videoSvc.info(path);
      if (!mounted) return;
      final dur = info?.durationMs ?? 0;
      _srcPath = path;
      _srcMs = dur;
      _range = null;
      if (PostVideoLimits.needsTrim(dur)) {
        setState(() {
          _longPending = (path: path, durationMs: dur);
          _video = null;
          _uploadedVideo = null;
          _frames = const [];
          _photo = null;
          _original = null;
          _uploaded = null;
          _extras.clear();
          _err = _Err.none;
        });
        await _openTrim(mandatory: true);
        return;
      }
      await _prepareVideo(path);
    } catch (e) {
      if (mounted) setState(() => _setError(e));
    }
  }

  /// Kırpma ekranını açar; aralık seçilirse videoyu keser ve hazırlama hattına sokar.
  Future<void> _openTrim({required bool mandatory}) async {
    final path = _srcPath;
    if (path == null || _publishing || _preparing) return;
    if (!_trimSvc.supported) {
      setState(() => _setError(VideoException('UNSUPPORTED')));
      return;
    }
    FocusScope.of(context).unfocus();
    final range = await Navigator.of(context).push<VideoTrimRange>(MaterialPageRoute(
      settings: const RouteSettings(name: 'video_trim'),
      fullscreenDialog: true,
      builder: (_) => VideoTrimPage(
        path: path,
        durationMs: _srcMs,
        maxDurationMs: PostVideoLimits.maxDurationMs,
        mandatory: mandatory,
        initial: _range,
        frames: widget.trimFrames,
      ),
    ));
    if (range == null || !mounted) return;
    if (range.coversAll(_srcMs) && !PostVideoLimits.needsTrim(_srcMs)) {
      // Tüm video seçildi ve sınıra sığıyor: kesmeye gerek yok.
      _range = null;
      await _discardTrimmed();
      await _prepareVideo(path);
      return;
    }
    setState(() {
      _preparing = true;
      _trimming = true;
      _progress = 0;
      _err = _Err.none;
    });
    try {
      final out = await _trimSvc.trim(
        path: path,
        startMs: range.startMs,
        endMs: range.endMs,
        maxMs: PostVideoLimits.maxDurationMs,
      );
      if (!mounted) {
        unawaited(_trimSvc.discard(out));
        return;
      }
      await _discardTrimmed();
      _trimmedPath = out;
      _range = range;
      await _prepareVideo(out);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _trimming = false;
        _setError(e);
      });
    }
  }

  Future<void> _discardTrimmed() async {
    final tmp = _trimmedPath;
    _trimmedPath = null;
    if (tmp != null) await _trimSvc.discard(tmp);
  }

  Future<void> _editVideo() => _openTrim(mandatory: false);

  /// Sıkıştırma/doğrulama (süre ve boyut sınırı) ve poster; sonuç `_video` olur.
  Future<void> _prepareVideo(String path) async {
    final cancel = VideoCancel();
    try {
      setState(() {
        _preparing = true;
        _trimming = false;
        _prepCancel = cancel;
        _progress = 0;
        _err = _Err.none;
      });
      final prepared = await _videoSvc.prepare(PickedVideo(path), cancel: cancel, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() {
        _video = prepared;
        _longPending = null;
        _uploadedVideo = null;
        _frames = const [];
        _coverIndex = 0;
        _photo = null; // gönderi = 1..10 fotoğraf YA DA 1 video
        _original = null;
        _uploaded = null;
        _extras.clear();
        _preparing = false;
        _trimming = false;
        _prepCancel = null;
      });
      unawaited(_loadFrames(prepared));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _trimming = false;
        _prepCancel = null;
        if (!(e is VideoException && e.code == 'CANCELLED')) _setError(e);
      });
    }
  }

  /// Kapak karesi adaylarını videodan eşit aralıklı alır (kare çıkarma desteklenmiyorsa — iOS — şerit hiç görünmez).
  Future<void> _loadFrames(PreparedVideo v) async {
    final path = v.path;
    if (path == null || v.durationMs <= 0) return;
    const n = 6;
    final out = <Uint8List>[];
    for (var i = 0; i < n; i++) {
      final at = (v.durationMs * (i + .5) / n).round();
      final f = await _videoSvc.frameAt(path, at);
      if (!mounted || _video != v) return;
      if (f != null && f.isNotEmpty) out.add(f);
    }
    if (!mounted || _video != v || out.length < 2) return;
    setState(() {
      _frames = out;
      // Varsayılan kapak: hazırlama adımındaki ilk anlamlı kare (poster) zaten seçili; şeritte ilk kare işaretlenmez.
      _coverIndex = -1;
    });
  }

  void _pickCover(int i) {
    final v = _video;
    if (v == null || _publishing || i < 0 || i >= _frames.length) return;
    setState(() {
      _coverIndex = i;
      _video = v.withPoster(_frames[i]);
      _uploadedVideo = null; // poster videoyla birlikte yüklenir
    });
  }

  Widget _coverStrip(BuTokens t) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      key: const ValueKey('composeCoverStrip'),
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.l10n.kesCoverTitle, style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
        Text(context.l10n.kesCoverHint, style: tt.bodySmall?.copyWith(color: t.mut)),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _frames.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => GestureDetector(
              key: ValueKey('composeCover-$i'),
              onTap: () => _pickCover(i),
              child: Semantics(
                button: true,
                selected: i == _coverIndex,
                label: '${context.l10n.kesCoverTitle} ${i + 1}',
                child: AnimatedContainer(
                  duration: BuMotion.of(context, BuMotion.short),
                  width: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(BuRadius.sm),
                    border: Border.all(color: i == _coverIndex ? t.pr : t.bd, width: i == _coverIndex ? 2.5 : 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(BuRadius.sm - 1),
                    child: Image.memory(_frames[i], fit: BoxFit.cover, gaplessPlayback: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  void _removeVideo() {
    if (_publishing) return;
    unawaited(_discardTrimmed());
    setState(() {
      _frames = const [];
      _video = null;
      _uploadedVideo = null;
      _longPending = null;
      _srcPath = null;
      _srcMs = 0;
      _range = null;
      _err = _Err.none;
    });
  }

  Future<PostMedia> _uploadVideo(PreparedVideo v) async {
    final json = await _videoUp.upload(PostMediaUploader.path, v, onProgress: (p) {
      if (mounted) setState(() => _progress = p);
    });
    if (json is! Map) throw ApiError(500, 'BAD_RESPONSE', '');
    final m = json['media'] is Map ? json['media'] as Map : json;
    return PostMedia.fromJson(Map<String, dynamic>.from(m));
  }

  /// Düzenlenmiş fotoğrafın en/boy oranı (başlıktan okunur, çözümlenmez); okunamazsa 4:5.
  static double _aspectOf(Uint8List b) {
    try {
      final i = img.findDecoderForData(b)?.startDecode(b);
      if (i == null || i.width <= 0 || i.height <= 0) return 4 / 5;
      return (i.width / i.height).clamp(0.5, 1.91).toDouble();
    } catch (_) {
      return 4 / 5;
    }
  }

  // ---- Çoklu fotoğraf --------------------------------------------------------------------------------------------------

  int get _photoCount => (_photo != null ? 1 : 0) + _extras.length;

  List<_Shot> _shots() => [
        if (_photo != null) _Shot(_photo!, _photoAspect, uploaded: _uploaded, orig: _original),
        ..._extras,
      ];

  /// Sıralı listeyi ilk fotoğraf + ekler olarak geri yazar (boşsa hepsi temizlenir).
  void _applyShots(List<_Shot> l) {
    if (l.isEmpty) {
      _photo = null;
      _original = null;
      _uploaded = null;
      _extras.clear();
      return;
    }
    final f = l.first;
    _photo = f.bytes;
    _original = f.orig ?? f.bytes;
    _photoAspect = f.aspect;
    _uploaded = f.uploaded;
    _extras
      ..clear()
      ..addAll(l.skip(1));
  }

  /// "Fotoğraf ekle": galeriden çoklu seçim, kalan hakkı aşmaz. Ek fotoğraflar 4:5 kutuya ortadan kırpılarak gösterilir.
  Future<void> _addPhotos() async {
    if (_publishing || _photo == null) return;
    final room = kPostMaxPhotos - _photoCount;
    if (room <= 0) return;
    FocusScope.of(context).unfocus();
    try {
      final picked = await (widget.pickPhotos ?? _defaultMultiPicker)(room);
      if (!mounted || picked.isEmpty) return;
      setState(() {
        for (final b in picked.take(room)) {
          _extras.add(_Shot(b, _aspectOf(b)));
        }
        _err = _Err.none;
      });
    } catch (e) {
      if (mounted) setState(() => _setError(e));
    }
  }

  void _removeShot(int i) {
    if (_publishing) return;
    final l = _shots();
    if (i < 0 || i >= l.length) return;
    setState(() {
      l.removeAt(i);
      _applyShots(l);
    });
  }

  void _reorderShot(int from, int to) {
    if (_publishing) return;
    final l = _shots();
    if (from == to || from < 0 || from >= l.length) return;
    setState(() {
      l.insert(to, l.removeAt(from));
      _applyShots(l);
    });
  }

  Future<void> _recrop() async {
    final orig = _original;
    if (orig == null || _publishing) return;
    final out = await _crop(orig);
    final cropped = out?.bytes;
    if (cropped == null || !mounted) return;
    setState(() {
      _photo = cropped;
      _photoAspect = _aspectOf(cropped);
      _uploaded = null;
    });
  }

  // ---- Etiketler ------------------------------------------------------------------------------------------------------

  /// Gönderilecek kimlikler: yalnız metinde hâlâ `@Ad Soyad` olarak duranlar (silinen düşer), en çok 10.
  List<int> _mentionIds() {
    final text = _text.text;
    final ids = <int>[];
    for (final u in _mentions) {
      if (u.displayName.isNotEmpty && text.contains('@${u.displayName}') && !ids.contains(u.id)) ids.add(u.id);
    }
    return ids.take(kPostMaxMentions).toList();
  }

  void _syncMentions() => _mentions.removeWhere((u) => !_text.text.contains('@${u.displayName}'));

  /// Metinden ilk `@ad` (ve ardındaki bir boşluk) çıkar.
  static String _removeToken(String text, String name) {
    final token = '@$name';
    final i = text.indexOf(token);
    if (i < 0) return text;
    var end = i + token.length;
    if (end < text.length && text[end] == ' ') end++;
    return text.substring(0, i) + text.substring(end);
  }

  void _onTextChanged(String v) {
    final sel = _text.selection;
    // Boşluktan/satırbaşından sonra tek `@` yazıldıysa seçici kendiliğinden açılır.
    final typedAt = v.length == _prevText.length + 1 &&
        sel.isValid &&
        sel.isCollapsed &&
        sel.baseOffset > 0 &&
        sel.baseOffset <= v.length &&
        v[sel.baseOffset - 1] == '@' &&
        (sel.baseOffset == 1 || RegExp(r'\s').hasMatch(v[sel.baseOffset - 2]));
    _prevText = v;
    setState(_syncMentions);
    if (typedAt && !_publishing) unawaited(_openMentionPicker(atIndex: sel.baseOffset - 1));
  }

  void _setText(String text, int caret) {
    final clamped = clampPostText(text);
    _text.value = TextEditingValue(text: clamped, selection: TextSelection.collapsed(offset: caret.clamp(0, clamped.length).toInt()));
    _prevText = clamped;
    _syncMentions();
  }

  /// Takip ettiklerimden seçici: seçilenler metne `@Ad Soyad ` olarak eklenir, çıkarılanların etiketi metinden silinir.
  Future<void> _openMentionPicker({int? atIndex}) async {
    if (_publishing) return;
    FocusScope.of(context).unfocus();
    final res = await showMentionPicker(context, widget.session, selected: List.of(_mentions), fetch: widget.mentionFetch);
    if (res == null || !mounted) return;
    var text = _text.text;
    final removed = [for (final u in _mentions) if (!res.any((r) => r.id == u.id)) u];
    final added = [for (final r in res) if (r.displayName.isNotEmpty && !_mentions.any((m) => m.id == r.id)) r];
    for (final u in removed) {
      text = _removeToken(text, u.displayName);
    }
    final names = added.map((u) => '@${u.displayName}').join(' ');
    var caret = text.length;
    final trigger = atIndex != null && removed.isEmpty && atIndex < text.length && text[atIndex] == '@';
    if (names.isNotEmpty) {
      if (trigger) {
        text = '${text.substring(0, atIndex)}$names ${text.substring(atIndex + 1)}';
        caret = atIndex + names.length + 1;
      } else {
        final sep = text.isEmpty || text.endsWith(' ') || text.endsWith('\n') ? '' : ' ';
        text = '$text$sep$names ';
        caret = text.length;
      }
    } else if (trigger) {
      // Seçici `@` ile açıldı ama kimse seçilmedi: yazılan `@` silinir.
      text = text.substring(0, atIndex) + text.substring(atIndex + 1);
      caret = atIndex;
    }
    setState(() {
      _mentions
        ..clear()
        ..addAll(res);
      _setText(text, caret);
    });
  }

  void _removeMention(SocialUser u) {
    if (_publishing) return;
    setState(() {
      _mentions.removeWhere((m) => m.id == u.id);
      _setText(_removeToken(_text.text, u.displayName), _text.selection.baseOffset);
    });
  }

  Future<void> _publish() async {
    final bytes = _photo;
    final video = _video;
    if (!_canShare || (bytes == null && video == null)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _publishing = true;
      _progress = 0;
      _err = _Err.none;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final List<int> ids;
      if (video != null) {
        ids = [(_uploadedVideo ??= await _uploadVideo(video)).id];
      } else {
        // Sıralı yükleme; yüklenenler saklanır, hata sonrası "Paylaş" yalnız eksikleri yeniden dener.
        final shots = _shots();
        setState(() {
          _upDone = shots.where((s) => s.uploaded != null).length;
          _upTotal = shots.length;
        });
        for (var i = 0; i < shots.length; i++) {
          final s = shots[i];
          if (s.uploaded == null) {
            final up = await _uploader.upload(s.bytes);
            s.uploaded = up;
            if (i == 0) _uploaded = up;
          }
          if (mounted) setState(() => _upDone = i + 1);
        }
        ids = [for (final s in shots) s.uploaded!.id];
      }
      final post = await _api.create(
          text: withEmojiPresentation(_text.text),
          mediaIds: ids,
          mentionUserIds: _mentionIds(),
          hideLikeCount: _hideLikes,
          commentsDisabled: _commentsOff,
          idempotencyKey: _idemKey);
      if (!mounted) return;
      if (messenger != null) {
        messenger.showSnackBar(SnackBar(
            content: BuToastGuard(duration: BuToast.defaultDuration, messenger: messenger, child: Text(context.l10n.postComposeShared)),
            duration: BuToast.defaultDuration,
            persist: false));
      }
      Navigator.pop(context, post);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.code == 'POST_MEDIA_INVALID') {
        _uploaded = null;
        _uploadedVideo = null;
        for (final s in _extras) {
          s.uploaded = null;
        }
      }
      setState(() {
        _publishing = false;
        _setError(e);
      });
    }
  }

  Future<void> _close() async {
    if (_preparing) {
      // Hazırlama sürüyorsa sıkıştırma durdurulur, sonra onay sorusu normal akışla sorulur.
      await _prepCancel?.cancel();
      if (!mounted) return;
    }
    if (_dirty) {
      final ok = await showDialog<bool>(context: context, builder: (c) => const _DiscardDialog());
      if (ok != true || !mounted) return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return PopScope(
      // Yükleme sürerken geri engellenir (yarım kalan yükleme/gönderi sessizce arka planda bitmesin).
      canPop: !_dirty && !_publishing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_publishing) _close();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(t),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(BuSpace.page, 4, BuSpace.page, 24),
                  children: [
                    // Seçici -> önizleme geçişi anında "zıplamaz": kısa solma (hareket azaltılmışsa anlık).
                    AnimatedSwitcher(
                      duration: BuMotion.of(context, BuMotion.medium),
                      switchInCurve: BuMotion.standard,
                      switchOutCurve: BuMotion.standard,
                      child: KeyedSubtree(
                          key: ValueKey('${_photo != null}-${_video != null}-$_preparing-${_longPending != null}'), child: _photoArea(t)),
                    ),
                    if (_photo != null && _video == null) _photoStrip(t),
                    const SizedBox(height: 16),
                    if (_video != null && _frames.length >= 2 && !_publishing) _coverStrip(t),
                    const SizedBox(height: 16),
                    _textField(t),
                    _tagSection(t),
                    _advancedSection(t),
                    // Uyarı/hata satırları açılırken yükseklik yumuşakça büyür, satır solarak belirir.
                    AnimatedSize(
                      duration: BuMotion.of(context, BuMotion.short),
                      curve: BuMotion.standard,
                      alignment: Alignment.topCenter,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _errors(t)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuTokens t) {
    final tt = Theme.of(context).textTheme;
    final enabled = _canShare;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('composeClose'),
            tooltip: context.l10n.postComposeClose,
            icon: Icon(BuIcons.x, size: 24, color: t.ink),
            onPressed: _publishing ? null : _close,
          ),
          Expanded(
            // Başlık metni görünmez (tasarım sadeleştirmesi); yalnız ekran okuyucu için anlamsal etiket.
            child: Semantics(header: true, label: context.l10n.postComposeNewPost, child: const SizedBox.shrink()),
          ),
          // Küçük pr düğme (radius 12): görünür 36 dp, dokunma alanı 48 dp; hazır değilken %40 opak (150 ms geçiş).
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: AnimatedOpacity(
              opacity: enabled || _publishing ? 1 : .4,
              duration: BuMotion.of(context, BuMotion.short),
              child: Material(
                key: const ValueKey('composeShare'),
                color: Colors.transparent,
                child: InkWell(
                  customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: enabled ? _publish : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: BuSize.touch, minWidth: 64),
                    child: Center(
                      widthFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: t.pr, borderRadius: BorderRadius.circular(12)),
                        child: SizedBox(
                          height: 36,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Center(
                              widthFactor: 1,
                              child: AnimatedSwitcher(
                                duration: BuMotion.of(context, BuMotion.short),
                                child: _publishing
                                    ? Semantics(
                                        key: const ValueKey('sharing'),
                                        label: context.l10n.p04PostSharing,
                                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: t.onPr)),
                                      )
                                    : Text(context.l10n.postComposeShare,
                                        key: const ValueKey('share'),
                                        style: tt.labelLarge?.copyWith(color: t.onPr, fontSize: 14, fontWeight: FontWeight.w400)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Video hazırlama/yükleme ilerlemesi: ön izleme üstünde ince çubuk + yüzde.
  Widget _progressOverlay(BuTokens t, String label, {bool indeterminate = false}) {
    final tt = Theme.of(context).textTheme;
    return ColoredBox(
      key: const ValueKey('composeVideoProgress'),
      color: t.scrim.withValues(alpha: .45),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label, textAlign: TextAlign.center, style: tt.labelLarge?.copyWith(color: t.onMedia, fontWeight: FontWeight.w400)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: indeterminate || _progress <= 0 ? null : _progress.clamp(0.0, 1.0),
                minHeight: 6,
                color: t.onMedia,
                backgroundColor: t.onMedia.withValues(alpha: .25),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _pct() => '${(_progress.clamp(0.0, 1.0) * 100).round()}%';

  Widget _photoArea(BuTokens t) {
    final tt = Theme.of(context).textTheme;
    final video = _video;
    if (video != null) {
      return Container(
        key: const ValueKey('composeVideoPreview'),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(kComposeRadius), border: Border.all(color: t.bd)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kComposeRadius),
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(fit: StackFit.expand, children: [
              ColoredBox(color: t.sf2),
              if (video.poster != null)
                Image.memory(video.poster!, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              if (video.path != null) _LocalVideoPreview(path: video.path!),
              if (!_publishing) const Center(child: PostPlayBadge(size: 56)),
              if (video.durationMs > 0) PositionedDirectional(start: 12, top: 12, child: DurationChip(durationMs: video.durationMs)),
              if (!_publishing) ...[
                // Belirgin giriş noktası: "Düzenle" (kırp), marka renginde dolu hap. Kırpma bu cihazda yoksa gizlenir.
                if (_trimSvc.supported && _srcPath != null)
                  PositionedDirectional(
                    start: 12,
                    bottom: 12,
                    child: _editPill(t),
                  ),
                PositionedDirectional(
                  end: 6,
                  top: 6,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _roundBtn(const ValueKey('composeVideoChange'), BuIcons.video, context.l10n.kesVideoChange,
                        _fromGallery ? _backToGallery : () => _pickVideo(ImageSource.gallery)),
                    _roundBtn(const ValueKey('composeVideoRemove'), BuIcons.x, context.l10n.postComposeDelete, _fromGallery ? _backToGallery : _removeVideo),
                  ]),
                ),
              ],
              if (_publishing) _progressOverlay(t, context.l10n.kesVideoUploading(_pct())),
            ]),
          ),
        ),
      );
    }
    if (_preparing) {
      return DecoratedBox(
        key: const ValueKey('composePreparing'),
        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(kComposeRadius)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kComposeRadius),
          child: AspectRatio(
              aspectRatio: 4 / 5,
              child: _progressOverlay(t, _trimming ? context.l10n.composeTrimming : context.l10n.kesVideoPreparing(_pct()), indeterminate: _trimming)),
        ),
      );
    }
    final long = _longPending;
    if (long != null) return _longCard(t, tt, long.durationMs);
    final bytes = _photo;
    if (bytes != null) {
      return Container(
        key: const ValueKey('composePreview'),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(kComposeRadius), border: Border.all(color: t.bd)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kComposeRadius),
          child: AspectRatio(
            aspectRatio: _photoAspect,
            child: Stack(fit: StackFit.expand, children: [
              ColoredBox(color: t.sf2),
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => Center(child: Icon(BuIcons.image, color: t.mut))),
              if (!_publishing)
                PositionedDirectional(
                  start: 12,
                  end: 12,
                  bottom: 12,
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Flexible(
                        child: _pill(const ValueKey('composeChange'), BuIcons.images, context.l10n.gonderiChangePhoto,
                            _fromGallery ? _backToGallery : () => _pick(ImageSource.gallery))),
                    const SizedBox(width: 8),
                    Flexible(child: _pill(const ValueKey('composeRecrop'), BuIcons.crop, context.l10n.p04Recrop, _recrop)),
                  ]),
                ),
              if (_publishing)
                Positioned.fill(child: ColoredBox(color: t.bg.withValues(alpha: .4))),
            ]),
          ),
        ),
      );
    }
    final hint = _text.text.trim().isNotEmpty; // metin yazıldı ama fotoğraf yok: kısa ipucu
    return DecoratedBox(
      key: const ValueKey('composePicker'),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(kComposeRadius)),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BuSpace.xxxl),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Tek birincil eylem; ikincil: Kamera (metin düğmesi). Başka öğe yok (Stitch v3 01).
            BuButton(
                key: const ValueKey('composeGallery'),
                label: context.l10n.gonderiPickPhoto,
                onPressed: _chooseSource),
            const SizedBox(height: 12),
            // İkincil eylemler: Kamera (fotoğraf) · Video seç · Video çek.
            Wrap(alignment: WrapAlignment.center, children: [
              for (final (key, label, onTap) in <(String, String, VoidCallback)>[
                ('composeCamera', context.l10n.postComposeCamera, () => _pick(ImageSource.camera)),
                ('composeVideoGallery', context.l10n.kesPickVideo, () => _pickVideo(ImageSource.gallery)),
                ('composeVideoCamera', context.l10n.kesRecordVideo, () => _pickVideo(ImageSource.camera)),
              ])
                TextButton(
                  key: ValueKey(key),
                  onPressed: onTap,
                  style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, BuSize.touch), foregroundColor: t.mut),
                  child: Text(label, style: tt.labelLarge?.copyWith(color: t.mut, fontSize: 15, fontWeight: BuType.emphasisWeight)),
                ),
            ]),
            Text(context.l10n.composeVideoLimitsHint((PostVideoLimits.maxDurationMs ~/ 1000).toString()), key: const ValueKey('composeVideoLimits'), textAlign: TextAlign.center, style: tt.bodySmall?.copyWith(color: t.mut, fontSize: 12)),
            if (hint) ...[
              const SizedBox(height: 8),
              Text(context.l10n.gonderiPhotoRequired,
                  key: const ValueKey('composePhotoHint'),
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(color: t.mut)),
            ],
          ]),
        ),
      ),
    );
  }

  /// Sınırdan uzun video: kırpılmadan paylaşılamaz. Kırpma ekranı kapatıldıysa buradan yeniden açılır.
  Widget _longCard(BuTokens t, TextTheme tt, int durationMs) {
    final l = context.l10n;
    return DecoratedBox(
      key: const ValueKey('composeVideoTooLong'),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(kComposeRadius)),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BuSpace.xxxl),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ExcludeSemantics(child: Icon(BuIcons.crop, size: 32, color: t.mut)),
            const SizedBox(height: 12),
            Text(l.composeTooLongTitle, textAlign: TextAlign.center, style: tt.titleMedium?.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
            const SizedBox(height: 6),
            Text(l.composeTooLongBody(formatMediaDuration(durationMs), formatMediaDuration(PostVideoLimits.maxDurationMs)),
                key: const ValueKey('composeTooLongBody'), textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: t.mut)),
            const SizedBox(height: 16),
            BuButton(key: const ValueKey('composeTrimCta'), label: l.composeTrimCta, icon: BuIcons.crop, onPressed: () => _openTrim(mandatory: true)),
            TextButton(
              key: const ValueKey('composeVideoOther'),
              onPressed: _fromGallery ? _backToGallery : _removeVideo,
              style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, BuSize.touch), foregroundColor: t.mut),
              child: Text(l.composeTooLongOther, style: tt.labelLarge?.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _editPill(BuTokens t) {
    return Semantics(
      button: true,
      label: context.l10n.composeTrimEdit,
      child: Material(
        key: const ValueKey('composeVideoEdit'),
        color: t.pr,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onTap: _editVideo,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BuSize.touch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(BuIcons.crop, size: 18, color: t.onPr),
                const SizedBox(width: 8),
                Text(context.l10n.composeTrimEdit,
                    maxLines: 1, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: t.onPr, fontWeight: FontWeight.w400)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// Önizleme köşesi: 48 dp dokunma alanlı yuvarlak, yarı saydam koyu düğme.
  Widget _roundBtn(Key key, IconData icon, String label, VoidCallback onTap) {
    final t = context.bu;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox(
          width: BuSize.touch,
          height: BuSize.touch,
          child: Center(
            child: Material(
              key: key,
              color: t.scrim.withValues(alpha: .45),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 18, color: t.onMedia)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Gelişmiş ayarlar": açılır bölüm, iki anahtar (varsayılan kapalı). Paylaşım isteğine `hideLikeCount` / `commentsDisabled` gider.
  Widget _advancedSection(BuTokens t) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          button: true,
          enabled: !_publishing,
          expanded: _advOpen,
          label: l.postSettingsAdvanced,
          child: Material(
            key: const ValueKey('composeAdvancedToggle'),
            color: t.sf,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.md), side: BorderSide(color: t.bdStrong)),
            child: InkWell(
              customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.md)),
              onTap: _publishing ? null : () => setState(() => _advOpen = !_advOpen),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    ExcludeSemantics(child: Icon(BuIcons.slidersHorizontal, size: 20, color: t.ink)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l.postSettingsAdvanced, style: tt.bodyLarge?.copyWith(color: t.ink, fontSize: 15))),
                    ExcludeSemantics(child: Icon(_advOpen ? BuIcons.chevronUp : BuIcons.chevronDown, size: 20, color: t.mut)),
                  ]),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: BuMotion.of(context, BuMotion.short),
          curve: BuMotion.standard,
          alignment: Alignment.topCenter,
          child: !_advOpen
              ? const SizedBox(width: double.infinity)
              : Column(key: const ValueKey('composeAdvancedBody'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _switchRow(t, tt,
                      key: const ValueKey('composeHideLikes'),
                      title: l.postSettingsHideLikes,
                      subtitle: l.postSettingsHideLikesDesc,
                      value: _hideLikes,
                      onChanged: (v) => setState(() => _hideLikes = v)),
                  Divider(height: 1, color: t.bd),
                  _switchRow(t, tt,
                      key: const ValueKey('composeCommentsOff'),
                      title: l.postSettingsCommentsOff,
                      subtitle: l.postSettingsCommentsOffDesc,
                      value: _commentsOff,
                      onChanged: (v) => setState(() => _commentsOff = v)),
                ]),
        ),
      ]),
    );
  }

  Widget _switchRow(BuTokens t, TextTheme tt,
      {required Key key,
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return MergeSemantics(
      child: InkWell(
        onTap: _publishing ? null : () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: tt.bodyLarge?.copyWith(color: t.ink, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: tt.bodySmall?.copyWith(color: t.mut)),
                ]),
              ),
              const SizedBox(width: 12),
              Switch(key: key, value: value, onChanged: _publishing ? null : onChanged),
            ]),
          ),
        ),
      ),
    );
  }

  /// "Kişi etiketle" satırı + seçilenler çip olarak (✕ ile kaldırılır).
  Widget _tagSection(BuTokens t) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          button: true,
          enabled: !_publishing,
          label: l.composeTagPerson,
          child: Material(
            key: const ValueKey('composeTagButton'),
            color: t.sf,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.md), side: BorderSide(color: t.bdStrong)),
            child: InkWell(
              customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.md)),
              onTap: _publishing ? null : () => _openMentionPicker(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    ExcludeSemantics(child: Icon(BuIcons.atSign, size: 20, color: t.ink)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l.composeTagPerson, style: tt.bodyLarge?.copyWith(color: t.ink, fontSize: 15))),
                    ExcludeSemantics(child: Icon(buDirIcon(context, BuIcons.chevronRight), size: 20, color: t.mut)),
                  ]),
                ),
              ),
            ),
          ),
        ),
        if (_mentions.isNotEmpty)
          Padding(
            key: const ValueKey('composeTagChips'),
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 8, children: [for (final u in _mentions) _tagChip(t, tt, u)]),
          ),
      ]),
    );
  }

  Widget _tagChip(BuTokens t, TextTheme tt, SocialUser u) {
    return Semantics(
      button: true,
      label: context.l10n.composeTagRemove(u.displayName),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BuSize.touch),
        child: Center(
          widthFactor: 1,
          child: Material(
            key: ValueKey('composeTagChip-${u.id}'),
            color: t.soft,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: _publishing ? null : () => _removeMention(u),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 12, 6),
                child: ExcludeSemantics(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    BuAvatar(name: u.displayName, url: u.avatarUrl, size: 24, headers: postAuthHeaders(widget.session)),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(u.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelLarge?.copyWith(color: t.onSoft, fontWeight: FontWeight.w400)),
                    ),
                    const SizedBox(width: 6),
                    Icon(BuIcons.x, size: 16, color: t.onSoft),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Önizleme altı küçük şerit: sayaç, basılı tutup sürükleyerek sıralama, silme ve "ekle".
  Widget _photoStrip(BuTokens t) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final shots = _shots();
    final n = shots.length;
    final full = n >= kPostMaxPhotos;
    return Padding(
      key: const ValueKey('composePhotoStrip'),
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              _publishing && _upTotal > 1
                  ? l.composeUploadingN(_upDone.toString(), _upTotal.toString())
                  : l.composePhotoCount(n.toString(), kPostMaxPhotos.toString()),
              key: const ValueKey('composePhotoCount'),
              style: tt.bodySmall?.copyWith(color: t.mut),
            ),
          ),
          if (n > 1 && !_publishing) Flexible(child: Text(l.composeReorderHint, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall?.copyWith(color: t.mut, fontSize: 12))),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 76,
          child: Row(children: [
            if (n > 1)
              Expanded(
                child: ReorderableListView.builder(
                  key: const ValueKey('composeReorder'),
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  itemCount: n,
                  onReorderItem: _reorderShot,
                  proxyDecorator: (child, _, __) => Material(type: MaterialType.transparency, child: child),
                  itemBuilder: (_, i) => ReorderableDelayedDragStartListener(
                    key: ObjectKey(shots[i]),
                    index: i,
                    enabled: !_publishing,
                    child: _shotTile(t, shots[i], i),
                  ),
                ),
              )
            else
              _shotTile(t, shots.first, 0),
            if (!full && !_publishing)
              Semantics(
                button: true,
                label: l.composeAddPhotos,
                child: InkWell(
                  key: const ValueKey('composeAddPhotos'),
                  borderRadius: BorderRadius.circular(BuRadius.sm),
                  onTap: _addPhotos,
                  child: Container(
                    width: 64,
                    height: 76,
                    decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.sm), border: Border.all(color: t.bd)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(BuIcons.imagePlus, size: 22, color: t.ink),
                      const SizedBox(height: 4),
                      Text(l.composeAddPhotosShort, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelSmall?.copyWith(color: t.mut)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _shotTile(BuTokens t, _Shot s, int i) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: SizedBox(
        width: 64,
        height: 76,
        child: Stack(fit: StackFit.expand, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(BuRadius.sm),
            child: Image.memory(s.bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: 192,
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => ColoredBox(color: t.sf2, child: Icon(BuIcons.image, color: t.mut))),
          ),
          if (_photoCount > 1 && !_publishing)
            PositionedDirectional(
              top: 0,
              end: 0,
              child: Semantics(
                button: true,
                label: l.composeRemovePhoto,
                child: GestureDetector(
                  key: ValueKey('composeRemove-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _removeShot(i),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: t.scrim.withValues(alpha: .6), shape: BoxShape.circle),
                        child: Padding(padding: const EdgeInsets.all(3), child: Icon(BuIcons.x, size: 14, color: t.onMedia)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _pill(Key key, IconData icon, String label, VoidCallback onTap) {
    final t = context.bu;
    // Fotoğraf üstünde yarı saydam koyu hap (scrim/onMedia); gölge yok, dokunma alanı 48 dp.
    return Material(
      key: key,
      color: t.scrim.withValues(alpha: .45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BuSize.touch),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: t.onMedia),
              const SizedBox(width: 6),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.onMedia, fontWeight: FontWeight.w400))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _textField(BuTokens t) {
    final tt = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(BuRadius.md),
        border: Border.all(color: t.bdStrong),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
      // Sayaç, kelime sınırı ya da uyarı YOK: sunucunun gizli üst sınırında giriş sessizce durur.
      child: TextField(
        key: const ValueKey('composeText'),
        controller: _text,
        focusNode: _focus,
        enabled: !_publishing,
        minLines: 4,
        maxLines: 10,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: const [PostTextLimiter()],
        onChanged: _onTextChanged,
        style: tt.bodyLarge?.copyWith(color: t.ink, fontSize: 15, height: 1.4),
        decoration: InputDecoration(
          hintText: context.l10n.gonderiTextHint,
          hintStyle: tt.bodyLarge?.copyWith(color: t.mut, fontSize: 15),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  /// Gönderim hataları (referans 10/3): içerik uyarısı kartı, hız sınırı, ağ, genel.
  List<Widget> _errors(BuTokens t) {
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    Widget row(IconData icon, Widget child, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Icon(icon, size: 18, color: color ?? t.ink),
            const SizedBox(width: 8),
            Expanded(child: child),
          ]),
        );
    final items = <Widget>[
      if (_err == _Err.profanity)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: DecoratedBox(
            key: const ValueKey('composeError'),
            decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.md), border: Border.all(color: t.bd)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(BuIcons.triangleAlert, size: 20, color: t.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.p04ContentWarning, style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 2),
                    Text(_errText, style: tt.bodyMedium?.copyWith(color: t.ink)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      if (_err == _Err.rate)
        row(
            BuIcons.hourglass,
            Row(children: [
              Expanded(child: Text(_errText, key: const ValueKey('composeError'), style: tt.bodyMedium?.copyWith(color: t.ink))),
              if (_wait > 0) Text('${_wait}s', key: const ValueKey('composeWait'), style: tt.labelLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
            ])),
      if (_err == _Err.network)
        row(
            BuIcons.wifiOff,
            Row(children: [
              Expanded(child: Text(_errText, key: const ValueKey('composeError'), style: tt.bodyMedium?.copyWith(color: t.ink))),
              GestureDetector(
                key: const ValueKey('composeRetry'),
                behavior: HitTestBehavior.opaque,
                onTap: _canShare ? _publish : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Center(
                    widthFactor: 1,
                    child: Text(l.commonRetryShort,
                        style: tt.labelLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w400, decoration: TextDecoration.underline)),
                  ),
                ),
              ),
            ])),
      if (_err == _Err.generic)
        row(BuIcons.circleAlert, Text(_errText, key: const ValueKey('composeError'), style: tt.labelLarge?.copyWith(color: t.danger)),
            color: t.danger),
    ];
    return [for (final w in items) _Appear(child: w)];
  }
}

/// Seçilen videonun yerel, sessiz ve döngülü ön izlemesi. Oynatıcı kurulamazsa (platform yok/bozuk dosya) sessizce
/// yalnız poster kalır.
class _LocalVideoPreview extends StatefulWidget {
  const _LocalVideoPreview({required this.path});

  final String path;

  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  VideoPlayerController? _c;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.file(File(widget.path), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      _c = c;
      await c.initialize();
      await c.setVolume(0);
      await c.setLooping(true);
      await c.play();
      if (mounted) setState(() {});
    } catch (_) {
      final c = _c;
      _c = null;
      try {
        await c?.dispose();
      } catch (_) {
        // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
      }
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
    );
  }
}

/// Eklenince bir kez solarak belirir (250 ms, yalnız opacity); hareket azaltılmışsa anında.
class _Appear extends StatefulWidget {
  const _Appear({required this.child});

  final Widget child;

  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null || BuMotion.reduced(context)) return;
    _c = AnimationController(vsync: this, duration: BuMotion.medium)..forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return c == null ? widget.child : FadeTransition(opacity: CurvedAnimation(parent: c, curve: BuMotion.standard), child: widget.child);
  }
}

/// "Gönderiden vazgeçilsin mi?" onayı (referans 10/4): Devam (kırmızı dolu) + Vazgeç (kırmızı metin). `true` = vazgeç.
class _DiscardDialog extends StatelessWidget {
  const _DiscardDialog();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Dialog(
      backgroundColor: t.sf3,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.gonderiDiscardTitle, textAlign: TextAlign.center, style: tt.titleLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
          const SizedBox(height: 10),
          Text(l.gonderiDiscardBody, textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: t.mut)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: BuButton(key: const ValueKey('composeKeep'), label: l.postComposeContinue, onPressed: () => Navigator.pop(context, false)),
          ),
          TextButton(
            key: const ValueKey('composeDiscard'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: t.ink),
            child: Text(l.gonderiDiscardYes, style: const TextStyle(fontWeight: FontWeight.w400)),
          ),
        ]),
      ),
    );
  }
}
