import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_navigation/app/l10n/generated/app_localizations.dart';
import 'package:campus_navigation/app/router/route_names.dart';
import 'package:campus_navigation/app/theme/mq_colors.dart';
import 'package:campus_navigation/app/theme/mq_spacing.dart';
import 'package:campus_navigation/shared/widgets/mq_tactile_button.dart';
import 'package:campus_navigation/features/settings/presentation/controllers/settings_controller.dart';

class _OnboardingSlideData {
  final IconData icon;
  final String title;
  final String body;
  final String? footnote;

  const _OnboardingSlideData({
    required this.icon,
    required this.title,
    required this.body,
    this.footnote,
  });
}

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _onNext(int totalSlides) async {
    if (_currentIndex == totalSlides - 1) {
      await _finishOnboarding();
    } else {
      // Page animation is fire-and-forget; we don't await it.
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _onSkip() async {
    await _finishOnboarding();
  }

  /// Persist onboarding completion *before* navigating. The settings
  /// controller's `_save` is optimistic (flips state in-memory
  /// synchronously), so the router redirect sees the new value
  /// immediately — but awaiting also ensures the secure-storage write
  /// has actually landed on disk before we change route. Without the
  /// await, a user who closes the app within the first few hundred
  /// milliseconds after tapping Done could relaunch and replay
  /// onboarding because the persisted flag never made it past the
  /// in-memory optimistic update.
  Future<void> _finishOnboarding() async {
    await ref.read(settingsControllerProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.goNamed(RouteNames.home);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;

    final List<_OnboardingSlideData> slides = [
      _OnboardingSlideData(
        icon: Icons.map_rounded,
        title: l10n.onboardingMapTitle,
        body: l10n.onboardingMapBody,
      ),
      _OnboardingSlideData(
        icon: Icons.train_rounded,
        title: l10n.onboardingTransitTitle,
        body: l10n.onboardingTransitBody,
        footnote: l10n.onboardingTransitDataAttribution,
      ),
      // Open Day is optional and opted into later (Settings → Open Day),
      // so first-run onboarding never asks for a study interest.
      _OnboardingSlideData(
        icon: Icons.security_rounded,
        title: l10n.onboardingPrivacyTitle,
        body: l10n.onboardingPrivacyBody,
      ),
    ];

    return Scaffold(
      backgroundColor: isDark ? MqColors.charcoal800 : MqColors.alabaster,
      body: Stack(
        children: [
          if (isDark)
            PositionedDirectional(
              top: -150,
              start: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      MqColors.red.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: MqSpacing.space4,
                    end: MqSpacing.space4,
                    top: MqSpacing.space2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Semantics(
                        label: l10n.onboardingSkipSemantic,
                        button: true,
                        child: TextButton(
                          onPressed: _onSkip,
                          child: Text(
                            l10n.onboardingSkip,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : MqColors.charcoal700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentIndex = index),
                    itemCount: slides.length,
                    itemBuilder: (context, index) {
                      return _buildSlideContent(
                        slide: slides[index],
                        isDark: isDark,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: MqSpacing.space6,
                    end: MqSpacing.space6,
                    bottom: bottomPadding > 0
                        ? bottomPadding
                        : MqSpacing.space6,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Semantics(
                            label: l10n.onboardingPageIndicator(
                              _currentIndex + 1,
                              slides.length,
                            ),
                            child: Row(
                              children: List.generate(slides.length, (index) {
                                return Semantics(
                                  label: l10n.onboardingGoToSlide(index + 1),
                                  button: true,
                                  child: GestureDetector(
                                    onTap: () => _goToPage(index),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      margin: const EdgeInsetsDirectional.only(
                                        end: MqSpacing.space2,
                                      ),
                                      height: 8,
                                      width: _currentIndex == index ? 24 : 8,
                                      decoration: BoxDecoration(
                                        color: _currentIndex == index
                                            ? (isDark
                                                  ? Colors.white
                                                  : MqColors.red)
                                            : Colors.grey.withValues(
                                                alpha: 0.3,
                                              ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          Semantics(
                            label: _currentIndex == slides.length - 1
                                ? l10n.onboardingStartSemantic
                                : l10n.onboardingNextSemantic,
                            button: true,
                            child: MqTactileButton(
                              onTap: () => _onNext(slides.length),
                              child: Container(
                                padding: const EdgeInsetsDirectional.symmetric(
                                  horizontal: MqSpacing.space8,
                                  vertical: MqSpacing.space4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? MqColors.brightRed
                                      : MqColors.red,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _currentIndex == slides.length - 1
                                      ? l10n.onboardingStart
                                      : l10n.onboardingNext,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideContent({
    required _OnboardingSlideData slide,
    required bool isDark,
  }) {
    final l10n = AppLocalizations.of(context)!;
    // Short screens (iPhone SE) and large text don't fit the full-size hero:
    // shrink it, and let the slide scroll as a last resort rather than
    // overflow. When everything fits it stays vertically centred.
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 520;
        return SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(MqSpacing.space6),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - MqSpacing.space6 * 2).clamp(
                0,
                double.infinity,
              ),
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    label: l10n.onboardingSlideIconLabel(slide.title),
                    child: Container(
                      padding: EdgeInsetsDirectional.all(
                        compact ? MqSpacing.space5 : MqSpacing.space8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? MqColors.charcoal700 : Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : MqColors.charcoal800.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Icon(
                        slide.icon,
                        size: compact ? 56 : 80,
                        color: isDark ? MqColors.brightRed : MqColors.red,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? MqSpacing.space6 : 48),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          label: slide.title,
                          header: true,
                          child: Text(
                            slide.title,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          label: slide.body,
                          child: Text(
                            slide.body,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: isDark
                                      ? Colors.white
                                      : MqColors.black87,
                                  height: 1.5,
                                ),
                          ),
                        ),
                        if (slide.footnote != null) ...[
                          const SizedBox(height: MqSpacing.space4),
                          Semantics(
                            label: slide.footnote,
                            child: Text(
                              slide.footnote!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isDark
                                        ? MqColors.contentSecondaryDark
                                        : MqColors.contentSecondary,
                                    height: 1.45,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
