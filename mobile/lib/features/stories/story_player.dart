import 'package:flutter/foundation.dart';

import '../posts/social_models.dart';

/// Görsel/metin hikâyesinin süresi.
const kStoryImageDuration = Duration(seconds: 5);

/// Videonun üst sınırı (oluştururken de en çok 30 sn).
const kStoryMaxVideo = Duration(seconds: 30);

/// Hikâyenin gösterim süresi: görsel/metin 5 sn; video süresi (en çok 30 sn), bilinmiyorsa 5 sn.
Duration storyDuration(Story s, {Duration? videoOverride}) {
  if (s.kind != StoryKind.video) return kStoryImageDuration;
  final ms = videoOverride?.inMilliseconds ?? s.media?.durationMs;
  if (ms == null || ms <= 0) return kStoryImageDuration;
  return Duration(milliseconds: ms > kStoryMaxVideo.inMilliseconds ? kStoryMaxVideo.inMilliseconds : ms);
}

/// Hikâye ilerleme mantığı (arayüzden bağımsız, birim test edilebilir). Dışarıdan [tick] ile beslenir.
/// Durdurma (basılı tutma) ve bekletme (medya yükleniyor) sayacı durdurur.
class StoryPlayer extends ChangeNotifier {
  StoryPlayer({required List<Duration> durations, int index = 0, this.onFinished})
      : _durations = List.of(durations),
        index = index.clamp(0, durations.isEmpty ? 0 : durations.length - 1);

  final List<Duration> _durations;
  int index;
  Duration elapsed = Duration.zero;
  bool _paused = false;
  bool _holding = false;
  bool finished = false;

  /// Son hikâyenin süresi dolunca (ya da sonuna "ileri" denince) bir kez çağrılır.
  final VoidCallback? onFinished;

  int get count => _durations.length;
  Duration get duration => _durations.isEmpty ? kStoryImageDuration : _durations[index];
  bool get paused => _paused;
  bool get holding => _holding;
  bool get running => !_paused && !_holding && !finished && _durations.isNotEmpty;

  /// 0..1 ilerleme (geçerli hikâye).
  double get progress =>
      duration.inMicroseconds == 0 ? 1 : (elapsed.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);

  /// Çubuk [i] için doluluk: öncekiler 1, geçerli [progress], sonrakiler 0.
  double fillOf(int i) => i < index ? 1 : (i == index ? progress : 0);

  /// Video süresi çözülünce geçerli ya da başka hikâyenin süresini günceller.
  void setDuration(int i, Duration d) {
    if (i < 0 || i >= _durations.length || _durations[i] == d) return;
    _durations[i] = d;
    notifyListeners();
  }

  void pause() {
    if (_paused) return;
    _paused = true;
    notifyListeners();
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    notifyListeners();
  }

  /// Medya hazır değilken sayaç ilerlemesin.
  void hold(bool value) {
    if (_holding == value) return;
    _holding = value;
    notifyListeners();
  }

  /// Geçen süreyi ilerletir; süre dolarsa sonrakine geçer.
  void tick(Duration dt) {
    if (!running) return;
    elapsed += dt;
    if (elapsed >= duration) {
      next();
    } else {
      notifyListeners();
    }
  }

  /// Sonraki hikâye; sonuncudaysa biter.
  void next() {
    if (finished) return;
    if (index + 1 >= _durations.length) {
      elapsed = duration;
      finished = true;
      notifyListeners();
      onFinished?.call();
      return;
    }
    index++;
    elapsed = Duration.zero;
    notifyListeners();
  }

  /// Önceki hikâye; ilk saniyeden sonraysa geçerliyi başa sarar, ilkteyse başa döner.
  void previous() {
    if (finished) return;
    if (elapsed > const Duration(seconds: 1) || index == 0) {
      elapsed = Duration.zero;
    } else {
      index--;
      elapsed = Duration.zero;
    }
    notifyListeners();
  }
}

/// Bir kullanıcının ilk görülmemiş hikâyesinin dizini (hepsi görüldüyse 0).
int firstUnseenIndex(List<Story> stories) {
  final i = stories.indexWhere((s) => !s.seen);
  return i < 0 ? 0 : i;
}
