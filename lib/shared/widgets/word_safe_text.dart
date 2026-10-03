import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Text that wraps between words but never *inside* one.
///
/// Flutter splits a word mid-way when that single word is wider than the
/// available width — on a small phone with large accessibility text a tile
/// label like "Student Services" rendered as "Student Service / s". This
/// measures the longest word against the real width at layout time and, only
/// when it cannot fit, shrinks the font just enough that it does. At normal
/// sizes it lays out exactly like a [Text].
///
/// Implemented as a render object (not a `LayoutBuilder`) so it supports
/// intrinsic sizing — the Quick Access tiles sit inside an `IntrinsicHeight`
/// that equalises their heights.
class WordSafeText extends LeafRenderObjectWidget {
  const WordSafeText(
    this.data, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
  });

  final String data;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;

  @override
  RenderWordSafeText createRenderObject(BuildContext context) {
    return RenderWordSafeText(
      text: data,
      style: DefaultTextStyle.of(context).style.merge(style),
      textAlign: textAlign,
      maxLines: maxLines,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderWordSafeText renderObject,
  ) {
    renderObject
      ..text = data
      ..style = DefaultTextStyle.of(context).style.merge(style)
      ..textAlign = textAlign
      ..maxLines = maxLines
      ..textScaler = MediaQuery.textScalerOf(context)
      ..textDirection = Directionality.of(context);
  }
}

class RenderWordSafeText extends RenderBox {
  RenderWordSafeText({
    required String text,
    required TextStyle style,
    required TextAlign textAlign,
    required int? maxLines,
    required TextScaler textScaler,
    required TextDirection textDirection,
  }) : _text = text,
       _style = style,
       _textAlign = textAlign,
       _maxLines = maxLines,
       _textScaler = textScaler,
       _textDirection = textDirection;

  String _text;
  set text(String value) {
    if (value == _text) return;
    _text = value;
    _invalidate();
  }

  TextStyle _style;
  set style(TextStyle value) {
    if (value == _style) return;
    _style = value;
    _invalidate();
  }

  TextAlign _textAlign;
  set textAlign(TextAlign value) {
    if (value == _textAlign) return;
    _textAlign = value;
    _invalidate();
  }

  int? _maxLines;
  set maxLines(int? value) {
    if (value == _maxLines) return;
    _maxLines = value;
    _invalidate();
  }

  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _invalidate();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    _invalidate();
  }

  final TextPainter _painter = TextPainter();

  /// The font scale actually used at the last layout (1.0 = as requested).
  @visibleForTesting
  double appliedFactor = 1;

  void _invalidate() {
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  /// Width of the widest single word at the requested size.
  double _longestWord() {
    var longest = 0.0;
    for (final word in _text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final p = TextPainter(
        text: TextSpan(text: word, style: _style),
        textDirection: _textDirection,
        textScaler: _textScaler,
        maxLines: 1,
      )..layout();
      longest = math.max(longest, p.width);
      p.dispose();
    }
    return longest;
  }

  /// Lays the painter out for [maxWidth], shrinking only if a word won't fit.
  void _layoutFor(double maxWidth) {
    var factor = 1.0;
    if (maxWidth.isFinite && maxWidth > 0) {
      final longest = _longestWord();
      if (longest > maxWidth) factor = (maxWidth / longest) * 0.98;
    }
    appliedFactor = factor;
    final fontSize = _style.fontSize;
    _painter
      ..text = TextSpan(
        text: _text,
        style: factor < 1 && fontSize != null
            ? _style.copyWith(fontSize: fontSize * factor)
            : _style,
      )
      ..textAlign = _textAlign
      ..textDirection = _textDirection
      ..textScaler = _textScaler
      ..maxLines = _maxLines
      ..ellipsis = _maxLines == null ? null : '…'
      ..layout(maxWidth: maxWidth.isFinite ? maxWidth : double.infinity);
  }

  @override
  double computeMinIntrinsicWidth(double height) => _longestWord();

  @override
  double computeMaxIntrinsicWidth(double height) {
    _layoutFor(double.infinity);
    return _painter.maxIntrinsicWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _layoutFor(width);
    return _painter.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    _layoutFor(constraints.maxWidth);
    return constraints.constrain(
      Size(
        _textAlign == TextAlign.start || _textAlign == TextAlign.left
            ? _painter.width
            : constraints.hasBoundedWidth
            ? constraints.maxWidth
            : _painter.width,
        _painter.height,
      ),
    );
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
    // computeDryLayout ran _layoutFor with these constraints; re-run so the
    // painter state used for painting matches this exact layout.
    _layoutFor(constraints.maxWidth);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final dx = switch (_textAlign) {
      TextAlign.center => (size.width - _painter.width) / 2,
      TextAlign.right || TextAlign.end => size.width - _painter.width,
      _ => 0.0,
    };
    _painter.paint(context.canvas, offset + Offset(dx, 0));
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..label = _text
      ..textDirection = _textDirection;
  }

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }
}
