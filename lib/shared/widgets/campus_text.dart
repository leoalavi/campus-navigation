import 'package:flutter/material.dart';

/// Renders campus data that is authored in Latin script — building names,
/// street addresses, building codes — so its internal reading order survives
/// inside a right-to-left interface.
///
/// **Why this exists.** Strings like `11 Wally's Walk` or `Theatre G03, 1
/// Wally's Walk` mix Latin letters (strong LTR) with digits (weak/neutral).
/// Dropped into an RTL paragraph, the Unicode bidirectional algorithm resolves
/// the neutrals against the paragraph direction and the leading number is
/// pushed to the far end of the line — Persian users saw
/// `Wally's Walk (Tutorial Rooms) 11`. The building number is no longer
/// attached to its street.
///
/// The fix is to give the run its own LTR paragraph rather than to reorder
/// characters by hand: the text is laid out left-to-right internally, while
/// [textAlign] keeps the *block* on the ambient locale's reading side, so an
/// RTL row still reads right-aligned. Latin punctuation and parentheses keep
/// their intended positions for free.
///
/// Use this only for Latin-script campus data. Localised prose must stay in
/// the ambient direction — forcing LTR there would break Persian, Arabic,
/// Hebrew and Urdu text.
class CampusText extends StatelessWidget {
  const CampusText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.semanticsLabel,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    // Captured *before* the override, so the block still sits on the side the
    // reader expects.
    final ambient = Directionality.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        data,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        semanticsLabel: semanticsLabel,
        textAlign: ambient == TextDirection.rtl
            ? TextAlign.right
            : TextAlign.left,
      ),
    );
  }
}

/// Wraps [text] in Unicode isolate marks (U+2066 LRI … U+2069 PDI).
///
/// For Latin campus data that has to live *inside* a localised sentence — a
/// building code after a translated "Building code:" label, for instance —
/// there is no separate widget to give an LTR paragraph to. The isolate marks
/// are the Unicode-level equivalent: the run resolves its own direction and
/// contributes a single neutral character to the surrounding paragraph, so
/// `4ER` cannot be dragged to the far end of a Persian line and the label's
/// own order is left untouched. The marks are zero-width.
///
/// Prefer [CampusText] when the value is its own widget; reach for this only
/// when the text is a span within localised prose.
String ltrIsolate(String text) => '\u2066$text\u2069';

/// The directional "drill into this row" chevron.
///
/// [Icons.chevron_right] does not mirror on its own, so in RTL it pointed away
/// from the direction the row actually navigates. Movement arrows are one of
/// the few glyph families that *should* mirror; universal icons (a map pin, a
/// close cross) must not, so this is deliberately narrow rather than a blanket
/// icon-mirroring rule.
class DirectionalChevron extends StatelessWidget {
  const DirectionalChevron({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      rtl ? Icons.chevron_left : Icons.chevron_right,
      size: size,
      color: color,
    );
  }
}

/// The directional "go back one level" arrow.
///
/// Like [DirectionalChevron], this is a movement arrow and must mirror:
/// [Icons.arrow_back] always draws a left-pointing glyph, which in an RTL
/// hierarchy points *forward*, not back. Placement is already handled by
/// `Row`/`EdgeInsetsDirectional`; only the glyph needs choosing.
class DirectionalBackIcon extends StatelessWidget {
  const DirectionalBackIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      rtl ? Icons.arrow_forward : Icons.arrow_back,
      size: size,
      color: color,
    );
  }
}
