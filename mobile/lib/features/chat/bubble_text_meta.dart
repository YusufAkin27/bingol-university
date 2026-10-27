import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// WhatsApp tekniği: [meta] (saat + tik) metnin SON satırında yer varsa metnin yanında (satır sonunda),
/// yoksa metnin altında bir satır ayrılarak durur; hiçbir durumda metinle çakışmaz.
///
/// Ölçüm, çocuk metnin gerçek yerleşiminden (son satırın genişliği) alınır; RTL'de meta sola, metin sağa yaslanır.
/// İlk çocuk metin ([Text] ya da [RichText]; `textWidthBasis: longestLine` önerilir), ikincisi [meta]'dır.
class BubbleTextMeta extends MultiChildRenderObjectWidget {
  BubbleTextMeta({super.key, required Widget text, required Widget meta, this.gap = 8})
      : super(children: [text, meta]);

  /// Metin ile meta arasındaki en küçük yatay boşluk.
  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderBubbleTextMeta(textDirection: Directionality.of(context), gap: gap);

  @override
  void updateRenderObject(BuildContext context, RenderBubbleTextMeta renderObject) {
    renderObject
      ..textDirection = Directionality.of(context)
      ..gap = gap;
  }
}

class _MetaParentData extends ContainerBoxParentData<RenderBox> {}

class RenderBubbleTextMeta extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _MetaParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _MetaParentData> {
  RenderBubbleTextMeta({required TextDirection textDirection, required double gap})
      : _textDirection = textDirection,
        _gap = gap;

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsLayout();
  }

  double _gap;
  double get gap => _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  RenderBox get _text => firstChild!;
  RenderBox get _meta => childAfter(firstChild!)!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MetaParentData) child.parentData = _MetaParentData();
  }

  static RenderParagraph? _paragraphOf(RenderObject o) {
    if (o is RenderParagraph) return o;
    RenderParagraph? found;
    o.visitChildren((c) => found ??= _paragraphOf(c));
    return found;
  }

  /// Son satırın başlangıç kenarından ölçülen kapladığı genişlik (kutular satır bazında gruplanır).
  double _lastLineExtent(RenderParagraph p, double fallback) {
    final len = p.text.toPlainText().length;
    if (len == 0) return 0;
    final boxes = p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: len));
    if (boxes.isEmpty) return fallback;
    final bottom = boxes.map((b) => b.bottom).reduce(math.max);
    final last = boxes.where((b) => b.bottom >= bottom - 0.5);
    if (_textDirection == TextDirection.rtl) {
      return p.size.width - last.map((b) => b.left).reduce(math.min);
    }
    return last.map((b) => b.right).reduce(math.max);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(_text.getMinIntrinsicWidth(height), _meta.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _text.getMaxIntrinsicWidth(height) + _gap + _meta.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(_text.getMinIntrinsicHeight(width), _meta.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _text.getMaxIntrinsicHeight(width) + _meta.getMaxIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final loose = BoxConstraints(maxWidth: constraints.maxWidth);
    final t = _text.getDryLayout(loose);
    final m = _meta.getDryLayout(loose);
    final inline = t.width + _gap + m.width <= constraints.maxWidth;
    return constraints.constrain(Size(
      inline ? t.width + _gap + m.width : math.max(t.width, m.width),
      inline ? math.max(t.height, m.height) : t.height + m.height,
    ));
  }

  @override
  void performLayout() {
    final maxW = constraints.maxWidth;
    final loose = BoxConstraints(maxWidth: maxW);
    _meta.layout(loose, parentUsesSize: true);
    _text.layout(loose, parentUsesSize: true);
    final mw = _meta.size.width;
    final mh = _meta.size.height;
    final tw = _text.size.width;
    final th = _text.size.height;

    final p = _paragraphOf(_text);
    final lastW = p == null ? tw : _lastLineExtent(p, tw);
    final inline = lastW + _gap + mw <= maxW + 0.01;

    final w = math.min(maxW, math.max(tw, inline ? lastW + _gap + mw : mw));
    final h = inline ? math.max(th, mh) : th + mh;
    size = constraints.constrain(Size(w, h));

    final rtl = _textDirection == TextDirection.rtl;
    (_text.parentData! as _MetaParentData).offset = Offset(rtl ? size.width - tw : 0, 0);
    (_meta.parentData! as _MetaParentData).offset = Offset(rtl ? 0 : size.width - mw, size.height - mh);
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
