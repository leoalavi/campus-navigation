import 'package:flutter/material.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';

/// "Visited" / "Reward earned" pill shown on a location card once the user has
/// been there. Uses the MQ Open Day pink ([MqColors.brightRed]) in both light
/// and dark mode so the visited state reads consistently — a white/amber badge
/// disappeared on the dark card.
class CardVisitBadge extends StatelessWidget {
  const CardVisitBadge({super.key, required this.state});
  final VisitedState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!state.visited) return const SizedBox.shrink();
    const pink = MqColors.brightRed;
    return Chip(
      avatar: const Icon(Icons.check_circle_rounded, size: 18, color: pink),
      label: Text(
        state.rewardEarned ? l10n.scanBadgeEarned : l10n.scanBadgeVisited,
        style: const TextStyle(color: pink, fontWeight: FontWeight.w700),
      ),
      backgroundColor: pink.withValues(alpha: 0.12),
      side: BorderSide(color: pink.withValues(alpha: 0.40)),
    );
  }
}
