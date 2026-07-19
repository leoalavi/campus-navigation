import 'package:flutter/material.dart';
import 'package:mq_journey/shared/widgets/glass_surface.dart';

/// A floating glass "island" app bar for pages whose body is live media
/// (camera feed, 360° panorama). Pair with
/// `Scaffold.extendBodyBehindAppBar: true` so the media runs behind the
/// island and refracts through the glass.
///
/// Content-heavy pages keep the standard [AppBar] — glass is a
/// navigation/control-layer material, not a texture for everything.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    required this.title,
    this.leading,
    this.animated = true,
  });

  final Widget title;
  final Widget? leading;

  /// Living highlights (light sweep / tilt-tracked glare). Default on: these
  /// bars float over media, exactly where the animated material earns its
  /// per-frame cost.
  final bool animated;

  static const double _height = 52;
  static const double _topGap = 4;

  @override
  Size get preferredSize => const Size.fromHeight(_height + _topGap);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lead =
        leading ?? (Navigator.of(context).canPop() ? const BackButton() : null);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, _topGap, 16, 0),
        child: GlassSurface(
          variant: GlassVariant.control,
          borderRadius: BorderRadius.circular(_height / 2),
          animated: animated,
          child: SizedBox(
            height: _height,
            child: NavigationToolbar(
              leading: lead,
              middle: DefaultTextStyle(
                style:
                    theme.appBarTheme.titleTextStyle ??
                    theme.textTheme.titleLarge ??
                    const TextStyle(fontSize: 20),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: title,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
