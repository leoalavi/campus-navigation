import 'package:flutter/material.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/shared/widgets/glass_surface.dart';

/// Frosted-glass container. Thin wrapper over [GlassSurface] (control tier) so
/// existing call sites keep working while sharing one glass implementation.
///
/// `isDark` is retained for API compatibility and debug-asserted against the
/// ambient theme; [GlassSurface] derives brightness from [Theme].
class GlassPane extends StatelessWidget {
  const GlassPane({
    super.key,
    required this.isDark,
    required this.child,
    this.borderRadius = MqSpacing.radiusXl,
  });

  final bool isDark;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    assert(
      isDark == (Theme.of(context).brightness == Brightness.dark),
      'GlassPane.isDark ($isDark) disagrees with the ambient theme; '
      'GlassSurface derives brightness from Theme — pass the matching value.',
    );
    return GlassSurface(
      variant: GlassVariant.control,
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
  }
}
