import 'dart:typed_data';

import 'package:flutter/painting.dart';

/// Kırpılan görselin kullanım yeri; başlık, önizleme ve çıktı boyutu buna göre seçilir.
enum CropKind { profile, post, logo, cover, chat }

/// Kırpma biçimi: sabit oran (null = görselin kendi oranı) + çıktı üst sınırı. Hazır biçimler: [CropSpec.profile],
/// [CropSpec.post], [CropSpec.logo], [CropSpec.cover], [CropSpec.chat].
class CropSpec {
  const CropSpec({
    required this.kind,
    required this.aspect,
    required this.maxEdge,
    this.circle = false,
    this.previewName,
    this.previewCaption,
    this.previewTitle,
    this.previewSubtitle,
    this.previewDate,
    this.allowChange = false,
    this.allowRemove = false,
  });

  /// Profil fotoğrafı: 1:1, daire önizleme.
  const CropSpec.profile({String? previewName})
      : this(kind: CropKind.profile, aspect: 1, maxEdge: 512, circle: true, previewName: previewName);

  /// Gönderi fotoğrafı: 4:5 dikey tek biçim. [previewName]/[previewCaption] akış kartı önizlemesinde görünür.
  const CropSpec.post({String? previewName, String? previewCaption, bool allowChange = false})
      : this(
            kind: CropKind.post,
            aspect: 4 / 5,
            maxEdge: 1350,
            previewName: previewName,
            previewCaption: previewCaption,
            allowChange: allowChange);

  /// Kulüp logosu: 1:1, daire kılavuzu. [previewName] kulüp adı.
  const CropSpec.logo({String? previewName})
      : this(kind: CropKind.logo, aspect: 1, maxEdge: 512, circle: true, previewName: previewName);

  /// Kulüp/etkinlik kapağı: 16:9. [previewTitle] etkinlik/kulüp başlığı, [previewSubtitle] kulüp adı.
  const CropSpec.cover({String? previewTitle, String? previewSubtitle, String? previewDate, bool allowRemove = false})
      : this(
            kind: CropKind.cover,
            aspect: 16 / 9,
            maxEdge: 1280,
            previewTitle: previewTitle,
            previewSubtitle: previewSubtitle,
            previewDate: previewDate,
            allowRemove: allowRemove);

  /// Sohbet görseli: oran serbest (görselin kendi oranı; yalnız kaydır/yakınlaştır/döndür).
  const CropSpec.chat() : this(kind: CropKind.chat, aspect: null, maxEdge: 1600);

  final CropKind kind;

  /// Genişlik / yükseklik; null: görselin (döndürülmüş) kendi oranı.
  final double? aspect;

  /// Çıktının en uzun kenarı (piksel); kırpılan bölge daha küçükse büyütülmez.
  final int maxEdge;

  /// Daire önizleme/kılavuz (çıktı yine kare, dairesel maske sunucu/arayüzde uygulanır).
  final bool circle;

  final String? previewName;
  final String? previewCaption;
  final String? previewTitle;
  final String? previewSubtitle;

  /// Kapak önizlemesindeki tarih çipi metni (örn. "23 Mayıs"); null ise çip yok.
  final String? previewDate;

  /// "Fotoğrafı değiştir" bağlantısı (post).
  final bool allowChange;

  /// "Kapağı kaldır" bağlantısı (cover).
  final bool allowRemove;

  /// Kırpma çerçevesinin sanal boyutu (en uzun kenar [side]); [imageAspect] yalnız serbest oranda kullanılır.
  Size frame(double imageAspect, {double side = 300}) {
    final a = aspect ?? imageAspect;
    return a >= 1 ? Size(side, side / a) : Size(side * a, side);
  }
}

/// Kırpma sayfasının sonucu: kırpılmış JPEG baytları, ya da kullanıcının istediği yan eylem.
class CropOutcome {
  const CropOutcome.cropped(Uint8List this.bytes)
      : removed = false,
        changeRequested = false;
  const CropOutcome.removed()
      : bytes = null,
        removed = true,
        changeRequested = false;
  const CropOutcome.change()
      : bytes = null,
        removed = false,
        changeRequested = true;

  final Uint8List? bytes;

  /// "Kapağı kaldır" seçildi.
  final bool removed;

  /// "Fotoğrafı değiştir" seçildi (çağıran yeni fotoğraf seçtirip yeniden açmalı).
  final bool changeRequested;
}
