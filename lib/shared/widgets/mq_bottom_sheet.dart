import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mq_navigation/app/theme/mq_colors.dart';
import 'package:mq_navigation/app/theme/mq_spacing.dart';
import 'package:mq_navigation/shared/extensions/context_extensions.dart';

/// A styled bottom sheet container that follows the MQ design system.
///
/// Handles handle-bar rendering, consistent padding, and background
/// colors for both light and dark modes.
class MqBottomSheet extends StatelessWidget {
  const MqBottomSheet({super.key, required this.child, this.showHandle = true});

  final Widget child;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(MqSpacing.radiusXl),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: dark
                    ? MqColors.charcoal800.withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(MqSpacing.radiusXl),
                ),
                border: Border(
                  top: BorderSide(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.80),
                  ),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showHandle)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: MqSpacing.space3,
                          ),
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: dark
                                  ? Colors.white.withAlpha(45)
                                  : MqColors.charcoal800.withAlpha(35),
                              borderRadius: BorderRadius.circular(
                                MqSpacing.radiusFull,
                              ),
                            ),
                          ),
                        ),
                      // Loose-fit so the content yields when the sheet's own
                      // chrome (handle + padding + safe-area inset) plus the
                      // child's preferred height exceed what the modal route
                      // allows. Without this the Column overflows by exactly
                      // that chrome height instead of letting the child's
                      // scrollable shrink.
                      Flexible(
                        fit: FlexFit.loose,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            MqSpacing.space5,
                            MqSpacing.space4,
                            MqSpacing.space5,
                            MqSpacing.space6,
                          ),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
