import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/features/scan/domain/services/stamp_award_calculator.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_progress_ring.dart';
import 'package:mq_journey/shared/extensions/context_extensions.dart';
import 'package:mq_journey/shared/widgets/mq_bottom_sheet.dart';

enum StampSheetAction { viewPassport, keepExploring }

/// Shows the stamp-earned celebration sheet and returns the action the user
/// picked, or `null` if dismissed by tapping outside/back (callers should
/// treat `null` the same as [StampSheetAction.keepExploring]).
Future<StampSheetAction?> showStampEarnedSheet(
  BuildContext context,
  StampAward award,
) {
  final l10n = AppLocalizations.of(context)!;
  SemanticsService.sendAnnouncement(
    View.of(context),
    l10n.stampAnnouncementCongrats(
      award.stamp.title,
      award.collectedCount,
      award.total,
    ),
    Directionality.of(context),
    assertiveness: Assertiveness.assertive,
  );
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  return showModalBottomSheet<StampSheetAction>(
    context: context,
    isScrollControlled: true,
    builder: (_) => StampEarnedSheet(award: award, playEffects: !reduceMotion),
  );
}

class StampEarnedSheet extends StatefulWidget {
  const StampEarnedSheet({
    super.key,
    required this.award,
    required this.playEffects,
  });

  final StampAward award;
  final bool playEffects;

  @override
  State<StampEarnedSheet> createState() => _StampEarnedSheetState();
}

class _StampEarnedSheetState extends State<StampEarnedSheet> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 700),
    );
    if (widget.playEffects) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    final award = widget.award;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        MqBottomSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: widget.playEffects ? 0.6 : 1.0, end: 1.0),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Image.asset(
                    award.stamp.stampAsset,
                    width: 96,
                    height: 96,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.local_activity_outlined,
                      size: 96,
                      color: MqColors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MqSpacing.space4),
              Text(
                award.isComplete
                    ? l10n.stampCelebrationCompleteTitle
                    : l10n.stampCelebrationTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : MqColors.contentPrimary,
                ),
              ),
              const SizedBox(height: MqSpacing.space2),
              Text(
                l10n.stampCelebrationSubtitle(award.stamp.title),
                textAlign: TextAlign.center,
              ),
              if (award.isFirst) ...[
                const SizedBox(height: MqSpacing.space2),
                Text(
                  l10n.stampCelebrationFirstNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: MqSpacing.space4),
              StampProgressRing(
                collected: award.collectedCount,
                total: award.total,
              ),
              const SizedBox(height: MqSpacing.space6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        StampSheetAction.keepExploring,
                      ),
                      child: Text(l10n.stampCelebrationKeepExploring),
                    ),
                  ),
                  const SizedBox(width: MqSpacing.space3),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, StampSheetAction.viewPassport),
                      child: Text(l10n.stampCelebrationViewPassport),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (widget.playEffects)
          ExcludeSemantics(
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 24,
            ),
          ),
      ],
    );
  }
}
