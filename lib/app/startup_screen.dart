import 'package:flutter/material.dart';
import 'package:campus_navigation/app/theme/mq_colors.dart';

/// Startup screen shown while services initialise (see `_SplashView` in
/// campus_navigation_app.dart). Continues the native launch screen exactly:
/// brand red, the canonical app tile at [iconSize] in the dead centre, then
/// the wordmark and progress fade in beneath it.
class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key, this.isLoading = true, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;

  /// Canonical app tile, derived from the app-icon artwork by
  /// tool/branding/build_icon_assets.py.
  static const iconAsset = 'assets/images/app_icon_tile.png';

  /// Must equal the native launch-screen icon size (iOS LaunchScreen,
  /// Android launch_background / Android 12 splash) so the hand-off is
  /// seamless.
  static const double iconSize = 112;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: MqColors.red,
      body: DecoratedBox(
        // Subtle depth: the flat native red at the centre, deepening toward
        // the edges, so the icon sits on a lit surface rather than a slab.
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.1),
            radius: 1.15,
            colors: [MqColors.red, MqColors.deepRed],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final centreY = constraints.maxHeight / 2;
            return Stack(
              children: [
                // Exactly centred — must line up with the native splash.
                Center(
                  child: Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      iconAsset,
                      width: iconSize,
                      height: iconSize,
                      filterQuality: FilterQuality.high,
                      semanticLabel: 'Campus Navigation',
                    ),
                  ),
                ),
                Positioned(
                  left: 32,
                  right: 32,
                  top: centreY + iconSize / 2 + 28,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    builder: (context, t, child) =>
                        Opacity(opacity: t, child: child),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Campus Navigation',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (isLoading)
                          Semantics(
                            label: 'Loading',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: SizedBox(
                                width: 120,
                                height: 3,
                                child: LinearProgressIndicator(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.22,
                                  ),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                ),
                              ),
                            ),
                          )
                        else ...[
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 28,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            errorMessage ?? 'Service initialisation failed.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
